extends SDTExtension
## Built-in reimplementation of the Loader mod dialogpatch (sby, v6): fixes for how she picks dialogue lines.
##
## - "!=" in a line's "check" ({"check":{"myVar":"!=3"}}); the game knows ==, >, >=, <, <=.
## - Priority fix: the game could play a lower priority line type with a higher build ahead of a higher priority
##   one, depending on the order it went through them (e.g. a long "held" over "first_dt").
## - Cascade: when the chosen line type has no line that can play right now (checks, mood, she cannot speak), try the
##   next ones instead of saying nothing.
## Written from its documentation and behaviour.

var _started := 0      # lines started (to see whether sayRandomPhrase played one)
var _say_stack: Array = []   # _started when each running sayRandomPhrase began


func _init() -> void:
	id = "dialogpatch"
	title = "dialogpatch"
	description = "Dialogue fixes: \"!=\" in line checks, the game's line priority bug, and trying other line types when the chosen one has nothing to say."
	default_enabled = true


func _setup() -> void:
	setting("applyprioritypatch", true, {"label": "Fix line priorities",
		"desc": "Higher priority lines always go first (the game sometimes let a lower priority line with more build win)."})
	setting("cascadepriorities", true, {"label": "Try other lines when one cannot play",
		"desc": "If no line of the chosen type can play right now, try the next line types."})
	setting("skiplimit", 6, {"label": "Cascade: line types to try", "min": 0, "max": 20})
	setting("skipprioritylimit", 1, {"label": "Cascade: priority levels below the first", "min": 0, "max": 5})


func _enable() -> void:
	hook_after(&"AdvancedDialogueController.canPlay", _can_play, -10)   # before DialogueActions removes its values
	hook_before(&"Dialogue.checkForSpeechStart", _check_for_speech_start)
	hook_after(&"Dialogue.startSpeakingPhrase", func(_c): _started += 1)
	hook_before(&"Dialogue.sayRandomPhrase", func(_c): _say_stack.append(_started))
	hook_after(&"Dialogue.sayRandomPhrase", _after_say)


# ---------------------------------------------------------------- "!=" in checks

## The game fails a check like "!=3"; if a line has one, it is checked again here with "!=" understood.
func _can_play(c: Hooks.Call) -> void:
	if c.result:
		return
	var line: DialogueLine = c.args[0]
	var checks = line.settings.get("check") if line.settings else null
	if not checks is Dictionary or not checks.values().any(func(v): return v is String and v.begins_with("!=")):
		return
	c.result = _checks_pass(c.obj, checks)


func _checks_pass(adc, checks: Dictionary) -> bool:
	var st: Dictionary = adc._dialogueDataStore
	for k in checks:
		var want = checks[k]
		var text := AS3.toString(want)
		var target := AS3.Number(text.trim_prefix(">=").trim_prefix("<=").trim_prefix("!=").trim_prefix(">")
			.trim_prefix("<").trim_prefix("=="))
		var numeric: bool = AS3.isNumber(want) or (want is String and not is_nan(target))
		var have = st[k] if st.has(k) else (0.0 if numeric else false)
		if AS3.isNumber(have) and want is String and numeric:
			var ok: bool
			if text.begins_with(">="):
				ok = have >= target
			elif text.begins_with(">"):
				ok = have > target
			elif text.begins_with("<="):
				ok = have <= target
			elif text.begins_with("<"):
				ok = have < target
			elif text.begins_with("!="):
				ok = have != target
			else:
				ok = have == target
			if not ok:
				return false
			continue
		if typeof(have) == TYPE_BOOL and want is String and (want == "true" or want == "false"):
			want = want == "true"
		if want is String and want.begins_with("!="):
			if AS3.looseEquals(have, want.substr(2)):
				return false
		elif not AS3.looseEquals(have, want):
			return false
	return true


# ---------------------------------------------------------------- priorities

## Dialogue.checkForSpeechStart with the priority fix: only line types of the highest priority with enough build
## compete (the game also let in lower priority ones it had met after the highest one).
func _check_for_speech_start(c: Hooks.Call) -> void:
	if not get_setting("applyprioritypatch"):
		return
	c.cancel()
	var dc: Dialogue = c.obj
	if not g.dialogue:
		return
	if dc.interruptTimer > 0:
		if dc.waitingToContinue:
			if g.her.canSpeak():
				if dc.continueDelay > 0:
					dc.continueDelay -= 1
				else:
					dc.continueSpeaking()
		elif dc.continueDelay > 0:
			dc.continueDelay -= 1
		else:
			dc.continueSpeaking()
	dc.nextLineTimer += maxf(randf() * 0.2, dc.speechUrgency())
	if dc.nextLineTimer > Dialogue.SPEAK_DELAY and not dc.speaking and not dc.waitingToContinue:
		var best := _best_state(dc, [], -1)
		if best != "":
			if best == Dialogue.QUEUED:
				dc.states[Dialogue.QUEUED].clearBuild()
				dc.sayRandomPhrase(dc.queuedPhrase)
			else:
				dc.sayRandomPhrase(best, true)
		elif randf() < Dialogue.GENERAL_PHRASE_FREQ:
			dc.sayRandomPhrase(Dialogue.GENERAL)
		else:
			dc.nextLineTimer = 0


## The line type to say: of those with build over the threshold (not in `skip`, priority >= min_priority), the
## highest priority, then the highest build; "intro" while her intro runs and nothing else is built. "" = none.
func _best_state(dc: Dialogue, skip: Array, min_priority: int) -> String:
	var top := 0
	var candidates: Array = []
	for k in dc.states:
		var s: DialogueState = dc.states[k]
		if s.build <= Dialogue.STATE_THRESHOLD or k in skip or s.priority < min_priority:
			continue
		if s.priority > top:
			top = s.priority
			candidates = [k]
		elif s.priority == top:
			candidates.append(k)
	var best := Dialogue.ZERO_STATE
	var found := false
	for k in candidates:
		if dc.states[k].build > dc.states[best].build:
			best = k
			found = found or dc.states[best].build > 0
	if g.her.introRunning() and dc.states[best].build < Dialogue.STATE_THRESHOLD:
		return Dialogue.INTRO
	return best if found else ""


# ---------------------------------------------------------------- cascade

## After sayRandomPhrase found no line it could play: try up to `skiplimit` other line types, not more than
## `skipprioritylimit` priority levels below the first one.
func _after_say(c: Hooks.Call) -> void:
	var before: int = _say_stack.pop_back() if not _say_stack.is_empty() else _started
	if not get_setting("cascadepriorities") or _started != before:
		return
	var dc: Dialogue = c.obj
	var first: String = c.args[0]
	if first == Dialogue.QUEUED or not dc.states.has(first) or dc.states[first].priority <= 0:
		return
	var min_priority: int = dc.states[first].priority - get_setting("skipprioritylimit")
	var tried: Array = [first]
	for i in get_setting("skiplimit") - 1:
		var next := _best_state(dc, tried, min_priority)
		if next == "" or next == Dialogue.INTRO and Dialogue.INTRO in tried:
			return
		tried.append(next)
		if next == Dialogue.QUEUED:
			dc.states[Dialogue.QUEUED].clearBuild()
			dc.sayRandomPhrase(dc.queuedPhrase)
		else:
			dc.sayRandomPhrase(next, true)   # the game's own: hooks do not run inside a hook's handler
		if _started != before:
			return
