class_name DevBehaviour
extends RefCounted
## Port addition: the behaviour tabs of the developer panel (DevMenu). One row per behaviour of hers or his: call it now,
## and switch the game doing it by itself on or off. "Off" is a veto on the behaviour's before hook point, so the
## game code stays as it is; a call from the panel passes that veto (other extensions' vetoes still apply).
## The rows come from ENTRIES: a new behaviour is one more entry.
##
## Only while Developer mode is on (and not in Vanilla mode or with the classic menu): an observer on every hook
## point of the table notes each call and whether something vetoed it (Hooks.Call.cancelled_by), for the row's
## status, also while the panel is closed. Automation switched off is kept for the session; with "Remember" on (Panel
## tab) it is also kept in port.cfg and comes back at the next start. Developer mode off removes every veto and
## observer; with it off nothing here is registered.

const OWNER := "devmode"
const SECTION := "dev_behaviour"   # port.cfg section

## group id -> tab name, in tab order
const GROUPS := {"eyes": "Eyes", "mouth": "Mouth", "fluids": "Fluids", "state": "State", "him": "Him"}

## [group, label, hook point ("" = no automation switch), what the call button does, tip, optional: which calls the
## automation switch vetoes, fn(call) -> bool (all of them without it)]
static func entries() -> Array:
	var her := func(): return g.her
	return [
		["eyes", "Blink", &"Her.blink", func(): her.call().blink(false), "Her blinking: every few seconds, and when she is startled."],
		["eyes", "Look around", &"Her.changeLookTarget", func(): her.call().changeLookTarget(her.call().hisFace, 0, 1),
			"Her gaze moving by itself (at his face, down, around). The button: look at his face."],
		["eyes", "Eyebrow waggle", &"Her.waggleEyebrows", func(): her.call().waggleEyebrows(), "Happy mood between actions, auto mode."],
		["eyes", "Wince", &"Her.wince", func(): her.call().wince(), "Squeezing her eyes: a fast pace, a swallow, coughs."],
		["eyes", "Close eye", &"", func(): her.call().closeEye(), "Closes her eye (as cum in her eye does). No automation of its own."],
		["eyes", "Open eye", &"Her.openEye", func(): her.call().openEye(), "A closed eye opens when it is clean or after 40 s."],
		["eyes", "Tears appear", &"Tears.addTearSpot", func(): her.call().tears.addTearSpot(), "New tears: held deep, the hilt, coughs (needs Tears on)."],
		["eyes", "Tears run", &"Tears.releaseTears", func(): her.call().tears.releaseTears(), "Tears running down: on a blink or a wince."],
		["mouth", "Swallow", &"Her.swallow", func(): her.call().swallow(), "With cum in her mouth and her head up, a while after; the key; dialogue."],
		["mouth", "Gulp", &"Her.gulp", func(): her.call().gulp(),
			"The moment of a swallow: squint, the gulp sound, the wave down her neck, what leaves her mouth. Auto off: her swallows still play, without the gulp."],
		["mouth", "Gulp, no squint", &"", func(): _gulp_without_squint(her.call()),
			"The same gulp without her squint (as Behaviour > Reactions > Squint when swallowing off). No automation of its own."],
		["mouth", "Clench teeth", &"Her.startClenchingTeeth", func(): her.call().startClenchingTeeth(),
			"Angry mood: after a hard pull-off, between actions, when he comes. Clenched teeth keep him out."],
		["mouth", "Release teeth", &"", func(): her.call().releaseTeeth(),
			"Unclenches her teeth now (the game only lets the clench time run out). No automation of its own."],
		["mouth", "Tongue out", &"Tongue.startMovingTongue", func(): her.call().tongue.startMovingTongue("out"),
			"Her tongue coming out by itself (near his tip, licking, when he comes). Auto off: it never comes out by itself (a veto on its \"out\" only).",
			func(c): return c.args[0] == "out"],
		["mouth", "Hang tongue out", &"", func(): her.call().tongue.hangOut(),
			"Her tongue out and staying out (as in the Ahegao mood). No automation of its own."],
		["mouth", "Tongue in", &"", func(): her.call().tongue.stopHangingOut(),
			"Her tongue back in now, and no longer hanging out. No automation of its own."],
		["mouth", "Cough", &"Her.cough", func(): her.call().cough(), "Held deep for a while (needs Coughing on)."],
		["mouth", "Open-mouth cough", &"Her.openCough", func(): her.call().openCough(), "Coughing it out after he pulls out (needs Coughing on)."],
		["fluids", "Spit strands", &"Her.generateRandomStrand", func(): her.call().generateRandomStrand("random"),
			"Strands between her lips and him: a fast pull back, letting go of a mouthful (needs Spit on)."],
		["fluids", "Spit drool", &"Her.randomSpitDrool", func(): her.call().randomSpitDrool(), "Gagged or Ahegao (needs Spit on)."],
		["fluids", "Cum drool", &"Her.startDroolingCum", func(): her.call().startDroolingCum(true),
			"Mouth open with her head tilted and more than 5 in her mouth. The button adds some if needed."],
		["fluids", "Sweat", &"Sweat.spawn", func():
			var h = her.call()
			Sweat.spawn(h.head, Vector2(21, -65), Vector2(150, 100), [h.rightArmContainer.upperArm, h.torso.back,
				h.torso.midLayer.chest, h.torso.midLayer.rightBreast.hitArea, h.torso.leg]),
			"Droplets by her breath level (needs Sweat on)."],
		["state", "Pass out", &"Her.passOut", func(): her.call().passOut(), "Out of breath for too long."],
		["state", "Wake up", &"Her.wakeUp", func(): her.call().wakeUp(), "Breathing again after passing out."],
		["state", "Tap hands", &"Her.tapHands", func(): her.call().tapHands(), "Tapping him to be let go; also with clenched teeth."],
		["him", "Ejaculate", &"Him.ejaculate", func(): g.him.ejaculate(),
			"At full pleasure for 2 s. Off: he stays at the edge, his pleasure kept."],
		["him", "Let go of her head", &"Him.openHand", func(): g.him.openHand(), "His hand opens when she pulls off or he lets go."],
	]


## The panel's "Gulp, no squint": one gulp with Her.swallowWince false for its length.
static func _gulp_without_squint(her) -> void:
	var id := Hooks.add_modifier(&"Her.swallowWince", {"phase": Hooks.FINAL, "op": "set", "value": false}, OWNER)
	call_now(&"Her.gulp", func(): her.gulp())
	Hooks.remove_modifier(id)


static var _off: Dictionary = {}        # hook name -> true: automation switched off
static var _filters: Dictionary = {}    # hook name -> fn(call) -> bool: which of its calls the switch vetoes
static var _allow: Dictionary = {}      # hook name -> true while the panel's own call runs
static var _seen: Dictionary = {}       # hook name -> [Hooks.Call, tick, manual]
static var _active := false
static var _veto_fn := Callable()
static var _watch_fns: Dictionary = {}  # hook name -> observer Callable
static var _loaded := false


static func remember() -> bool:
	return bool(PortSettings.get_value(SECTION, "remember", false))


static func set_remember(on: bool) -> void:
	PortSettings.set_value(SECTION, "remember", on)
	_save()


static func hooks() -> Array:
	var out: Array = []
	for e in entries():
		if e[2] != &"":
			out.append(e[2])
	return out


static func is_off(hook: StringName) -> bool:
	return _off.has(hook)


static func off_count() -> int:
	return _off.size()


## Automation of `hook` on (the game does it by itself) or off (vetoed).
static func set_auto(hook: StringName, on: bool) -> void:
	if on:
		_off.erase(hook)
	else:
		_off[hook] = true
	_save()
	_apply()


static func set_all(on: bool, group := "") -> void:
	for e in entries():
		if e[2] != &"" and (group == "" or e[0] == group):
			if on:
				_off.erase(e[2])
			else:
				_off[e[2]] = true
	_save()
	_apply()


## The panel's call button: runs the behaviour now, past the panel's own veto.
static func call_now(hook: StringName, fn: Callable) -> void:
	if hook != &"":
		_allow[hook] = true
	fn.call()
	_allow.erase(hook)


## Developer mode came on or went off (or Vanilla mode / the classic menu changed): add or remove the vetoes and
## observers.
static func sync(enabled: bool) -> void:
	if enabled and not _loaded:
		_loaded = true
		if remember():
			for h in PortSettings.get_value(SECTION, "off", []):
				_off[StringName(h)] = true
	_active = enabled
	if not enabled:
		DevTuning.reset()   # hand settings exist only while Developer mode is on
	_apply()


static func _apply() -> void:
	Hooks.remove_owner(OWNER)
	_watch_fns.clear()
	if not _active:
		return
	_filters.clear()
	for e in entries():
		if e.size() > 5 and e[2] != &"":
			_filters[e[2]] = e[5]
	_veto_fn = func(c):
		if _off.has(c.name) and not _allow.has(c.name) and (not _filters.has(c.name) or _filters[c.name].call(c)):
			c.cancel()
	for h in hooks():
		var watch := func(c): _seen[h] = [c, Flash.tick_count, _allow.has(h)]
		_watch_fns[h] = watch
		Hooks.add_before(h, watch, OWNER, -100000)   # first: sees every call, then reads how it ended
		if _off.has(h):
			Hooks.add_before(h, _veto_fn, OWNER, -99999)


static func _save() -> void:
	if remember():
		PortSettings.set_value(SECTION, "off", _off.keys().map(func(k): return String(k)))
	else:
		PortSettings.set_value(SECTION, "off", [])


## The row's status line: when the behaviour last ran or who vetoed it.
static func status(hook: StringName) -> String:
	if hook == &"":
		return ""
	var s = _seen.get(hook)
	var off := "off · " if _off.has(hook) else ""
	if s == null:
		return off + "not seen yet"
	var ago := (Flash.tick_count - int(s[1])) / 30.0
	var when := "%.0f s ago" % ago if ago >= 1.0 else "just now"
	var c: Hooks.Call = s[0]
	if c.cancelled:
		var who: String = c.cancelled_by
		who = "Developer mode" if who == OWNER else (who if who != "" else "?")
		return off + "vetoed by %s, %s" % [who, when]
	return off + ("called from here, " if s[2] else "ran, ") + when


# ---------------------------------------------------------------- tabs

static func sections() -> Array:
	var out: Array = []
	for gid in GROUPS:
		var rows: Array = [MenuSchema.actions("", "", [
			["All off", func(): set_all(false, gid), "Switch off everything in this tab: she does none of it by herself."],
			["All on", func(): set_all(true, gid), "Back to the game doing all of it by itself."]],
			{"keywords": "automation freeze"})]
		for e in entries():
			if e[0] == gid:
				rows.append(_row(e))
		rows.append_array(DevTuning.controls(gid))   # the tab's hand settings
		out.append({"id": "dev_" + gid, "name": GROUPS[gid], "groups": [{"title": GROUPS[gid], "controls": rows}]})
	return out


## One behaviour: name, call button, "auto" switch, status line under it.
static func _row(e: Array) -> Dictionary:
	var hook: StringName = e[2]
	var label: String = e[1]
	var tip: String = e[4] + ("" if hook == &"" else " Auto off: a veto on " + String(hook) + "; the button still works.")
	return {"type": "custom", "label": "", "tip": tip, "keywords": label + " " + String(hook) + " automation",
		"label_text": label, "build": func():
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 0)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 6)
			box.add_child(line)
			var title := Label.new()
			title.text = label
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.clip_text = true
			line.add_child(title)
			var go := Button.new()
			go.text = "▶"
			go.tooltip_text = "Do it now"
			go.focus_mode = Control.FOCUS_NONE
			go.custom_minimum_size = Vector2(22, 16)
			go.pressed.connect(func(): call_now(hook, e[3]))
			line.add_child(go)
			var sw := CheckButton.new()
			sw.focus_mode = Control.FOCUS_NONE
			sw.tooltip_text = "The game does it by itself"
			sw.visible = hook != &""
			sw.toggled.connect(func(on: bool): set_auto(hook, on))
			line.add_child(sw)
			var st := Label.new()
			st.add_theme_font_size_override("font_size", MenuTheme.SMALL)
			st.add_theme_color_override("font_color", MenuTheme.MUTED)
			st.clip_text = true
			st.visible = hook != &""
			box.add_child(st)
			box.set_meta("refresh", func():
				sw.set_pressed_no_signal(not is_off(hook))
				var t := status(hook)
				st.text = t
				st.add_theme_color_override("font_color", MenuTheme.PLUGIN if is_off(hook) else MenuTheme.MUTED))
			return box}
