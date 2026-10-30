class_name Journal
extends RefCounted
## Port addition: the event log of the developer panel (Tools > Log). Read only: it changes nothing in the game.
## It only exists while Developer mode is on (DevMenu.apply_mode): its hooks and its per-tick check are added then and
## removed when it goes off, so normal play pays nothing for it. With it on it records while the panel is closed too.
##
## Where the events come from:
##   - the behaviour tabs' observer (DevBehaviour, first on each hook point of its table): a behaviour ran, was
##     called from the panel, or was vetoed and by whom (Hooks.Call.cancelled_by), read at the end of the tick;
##   - after points of the game (Her.swallow, Her.gulp, Him.nextSpurt, Dialogue.startSpeakingPhrase) and a last
##     before handler on Her.lastSpurt;
##   - states compared once per tick (in her mouth, holding her breath, mood ...): a line when one changes;
##   - extensions: Journal.log(group, text), which costs nothing while the log is off.
## Extensions react to the game through Hooks, not through the log: it has no listeners of its own.
## The same line again right away is folded into the last one ("x N"). The last MAX lines are kept.

const OWNER := "journal"
const MAX := 500
## group id -> name, in the order of the filter buttons
const GROUPS := {"swallow": "Swallowing", "mouth": "Mouth", "breath": "Breath", "him": "Him", "other": "Other"}
const TAGS := {"swallow": "swallow", "mouth": "mouth", "breath": "breath", "him": "him", "other": "other"}
## behaviour table hook -> group, for the lines its observer gives (a run is logged only for these; a veto always)
## (not Him.openHand: in auto mode his hand opens on every stroke)
const RUNS := {&"Her.cough": "mouth", &"Her.openCough": "mouth", &"Her.startClenchingTeeth": "mouth",
	&"Her.passOut": "breath", &"Her.wakeUp": "breath"}
## (Him.ejaculate: a state line instead - J calls it on every press, also while he cums)
## Ticks a state must keep its new value before it is a line (0.5 s at 30 fps), so a stroke that only touches her
## lips, or her breath level shaking at a threshold, makes no line each time. Mood, hand and auto: at once.
const HOLD := 15

static var active := false
static var paused := false
static var lines: Array = []          # [tick, group, text, count]
static var version := 0               # changes with every new or folded line (the tab redraws on a change)
static var shown := {"swallow": true, "mouth": true, "breath": true, "him": true, "other": true}
static var _tick_fn := Callable()
static var _pending: Array = []       # [hook, Hooks.Call, manual] seen by the observer this tick
static var _prev := {}                # state name -> last value logged
static var _since := {}               # state name -> [new value, tick it first had it] while it is held
static var _labels := {}              # behaviour table hook -> its row's name
static var _gulp_from := -1           # cum in her mouth before this tick's gulp (-1: none)
static var _fns := {}


## Adds a line (extensions too). Nothing while the log is off or paused.
static func log(group: String, text: String) -> void:
	if not active or paused:
		return
	if not GROUPS.has(group):
		group = "other"
	var t := Flash.tick_count
	if not lines.is_empty():
		var last: Array = lines[-1]
		if last[1] == group and last[2] == text:
			last[0] = t
			last[3] += 1
			version += 1
			return
	lines.append([t, group, text, 1])
	if lines.size() > MAX:
		lines.pop_front()
	version += 1


static func clear() -> void:
	lines.clear()
	version += 1


## Developer mode came on or went off (DevMenu.apply_mode).
static func sync(enabled: bool) -> void:
	if enabled == active:
		return
	active = enabled
	Hooks.remove_owner(OWNER)
	if _tick_fn.is_valid():
		Flash.tick_after.erase(_tick_fn)
		_tick_fn = Callable()
	_pending.clear()
	_prev.clear()
	_since.clear()
	_gulp_from = -1
	if not active:
		return
	_labels.clear()
	for e in DevBehaviour.entries():
		if e[2] != &"":
			_labels[e[2]] = e[1]
	_tick_fn = func(): Journal._tick()
	Flash.tick_after.append(_tick_fn)
	_fns = {
		"swallow": func(c): Journal._on_swallow(c),
		"gulp_before": func(c): Journal._gulp_from = c.obj.cumInMouth,
		"spurt": func(c): Journal._on_spurt(c),
		"last": func(_c): Journal.log("him", "Last spurt"),
		"line": func(c): Journal._on_line(c),
	}
	Hooks.add_after(&"Her.swallow", _fns["swallow"], OWNER, -100000)   # first: before an extension queues it
	Hooks.add_before(&"Her.gulp", _fns["gulp_before"], OWNER, 100000)
	Hooks.add_after(&"Him.nextSpurt", _fns["spurt"], OWNER, 100000)
	Hooks.add_before(&"Her.lastSpurt", _fns["last"], OWNER, 100000)   # last: only when nothing vetoed it
	Hooks.add_after(&"Dialogue.startSpeakingPhrase", _fns["line"], OWNER, 100000)


## DevBehaviour's observer saw a call of `hook`; how it ended is read at the end of the tick.
static func observed(hook: StringName, c, manual: bool) -> void:
	if active and not paused:
		_pending.append([hook, c, manual])


## The log as text, oldest first (newest first if `newest_first`; only the groups shown, if `filtered`).
static func as_text(filtered := true, newest_first := false) -> String:
	var out := PackedStringArray()
	for l in lines:
		if filtered and not shown.get(l[1], true):
			continue
		out.append(line_text(l))
	if newest_first:
		out.reverse()
	return "\n".join(out)


static func line_text(l: Array) -> String:
	var s: float = float(l[0]) / maxf(1.0, Flash.frame_rate)
	var t := "%02d:%04.1f" % [int(s / 60.0), fmod(s, 60.0)]
	return "%s  %-7s %s%s" % [t, TAGS.get(l[1], l[1]), l[2], "" if l[3] == 1 else "  x%d" % l[3]]


## Writes the whole log to a file in the save folder (journal/); returns its path ("" if it failed).
static func save() -> String:
	var dir := FlashSharedObject.save_dir.path_join("journal")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("journal_%s.txt" % Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(as_text(false) + "\n")
	f.close()
	return path


# ---------------------------------------------------------------- sources

static func _on_swallow(c) -> void:
	var her = c.obj
	if c.result:
		if _prev.get("swallowing", false):   # the last one ended and this one started before the log's tick saw it
			Journal.log("swallow", "Swallow ends")
		Journal.log("swallow", "Swallow starts (strength %.2f, %d in her mouth)" % [float(her.swallowSequence.get("intensity", 0.0)), her.cumInMouth])
	else:
		var why := "already swallowing" if her.swallowing else ("passed out" if her.passedOut else ("speaking" if her.speaking else "?"))
		Journal.log("swallow", "Asked to swallow: dropped, " + why)


static func _on_spurt(_c) -> void:
	var her = g.her
	var where := "outside"
	if her != null and her.penisInMouthDist > 0.0:
		where = "held deep" if her.held else "in her mouth"
	Journal.log("him", "Spurt, " + where)


static func _on_line(c) -> void:
	var p: String = str(c.obj.sayingPhrase).strip_edges()
	if p.length() > 80:
		p = p.substr(0, 77) + "..."
	Journal.log("other", "Says: " + p)


static func _tick() -> void:
	if not active:
		return
	if paused:
		_pending.clear()
		_gulp_from = -1
		return
	for p in _pending:
		_resolve(p[0], p[1], p[2])
	_pending.clear()
	var her = g.her
	if her == null:
		return
	if _gulp_from >= 0:
		Journal.log("swallow", "Gulp: took %d, %d left" % [maxi(0, _gulp_from - her.cumInMouth), her.cumInMouth])
		_gulp_from = -1
	_edge("swallowing", her.swallowing, "swallow", "", "Swallow ends", 0)
	_edge("teeth", her.clenchTeeth, "mouth", "Clenches her teeth", "Unclenches her teeth", 0)
	_edge("tongue", her.tongue.tongueOut, "mouth", "Tongue out", "Tongue in")
	if g.him != null:
		_edge("him_cums", g.him.ejaculating, "him", "He starts to cum", "He is done", 0)
	_edge("in_mouth", her.penisInMouthDist > 0.0, "mouth", "He is in her mouth", "He is out of her mouth")
	_edge("deep", her.penisInMouthDist > Her.deepthroatDistance, "mouth", "Past her throat entrance", "Back above her throat entrance")
	_edge("full", her.cumInMouth >= her.maxCumInMouth, "mouth", "Her mouth is full of cum", "", 0)
	if ThroatRings.worked_out_this_tick() and ThroatRings.collar["on"]:
		var col: Dictionary = ThroatRings.collar
		_edge("collar_holds", col["hold"] > 0.0, "mouth", "Collar holds", "Collar lets go")
		_edge("collar_snapped", col["snapped"], "mouth", "Collar snapped", "Collar repaired", 0)
	_edge("breathing", her.breathing, "breath", "Breathes again", "Holds her breath")
	_edge("out_of_breath", g.breathLevel > g.outOfBreathPoint, "breath", "Out of breath (half her air used)", "Got her breath back")
	_edge("no_air", g.breathLevel >= g.breathLevelMax, "breath", "No air left: she starts to pass out", "")
	_edge("mood", Moods.current(), "other", "Mood: %s", "", 0)
	_edge("hand", g.handJobMode, "other", "Hand mode on", "Hand mode off", 0)
	_edge("auto", g.autoModeOn, "other", "Auto on", "Auto off", 0)


## A behaviour of the table ended: vetoed (always logged) or ran (logged for RUNS).
static func _resolve(hook: StringName, c, manual: bool) -> void:
	var group: String = RUNS.get(hook, "swallow" if hook == &"Her.swallow" else "other")
	var label: String = _labels.get(hook, String(hook).get_slice(".", 1))
	if c.cancelled:
		var who: String = c.cancelled_by
		who = "Developer mode" if who == DevBehaviour.OWNER else (who if who != "" else "?")
		Journal.log(group, "%s vetoed by %s" % [label, who])
	elif RUNS.has(hook) or (manual and hook != &"Her.swallow"):
		Journal.log(group, label + (" (from the panel)" if manual else ""))


## A state compared with the last line about it: `on` / `off` text when it has changed and kept the new value for
## `hold` ticks ("" = no line; %s = the new value). The first look only remembers it.
static func _edge(key: String, v, group: String, on: String, off: String, hold := HOLD) -> void:
	if not _prev.has(key):
		_prev[key] = v
		return
	if _prev[key] == v:
		_since.erase(key)
		return
	if hold > 0:
		var s = _since.get(key)
		if s == null or s[0] != v:
			_since[key] = [v, Flash.tick_count]
			return
		if Flash.tick_count - int(s[1]) < hold:
			return
	_since.erase(key)
	_prev[key] = v
	if v is bool:
		var text := on if v else off
		if text != "":
			Journal.log(group, text)
	elif on != "":
		Journal.log(group, on % str(v))
