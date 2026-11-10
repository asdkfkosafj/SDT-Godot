extends SDTExtension
## Built-in reimplementation of the Loader mod DialogueActions (Pim_gd / WeeWillie, later forked by sby): more
## triggers, variables and line types for dialogue files, so dialogues written for it play in the port. Written
## from its documentation and behaviour; dialogue files use exactly the same syntax.
##
## Other extensions add to it through this object (Extensions.get_extension("dialogueactions")):
##   register_trigger(name, arg_count, fn)   fn(args: Array); arg_count -1 = any number of arguments
##   vars.register(name, getter, setter)      a variable dialogues can read / write ("mod variable")
##   vars.add_listener(name, fn)              fn(old, new) after a local variable was written
##   add_line_change_listener(fn)             fn() once, when the next line starts
##   run_code("[TRIGGER_a][OTHER]")           runs triggers from code
## An extension registers these inside SDTExtension.on_dialogueactions(setup) (or run_addon), so they come back
## when DialogueActions is switched on again and go away when that extension is disabled.

const VarsScript := preload("res://src/ext/dialogueactions/da_variables.gd")
const VarTriggers := preload("res://src/ext/dialogueactions/da_var_triggers.gd")
const GameTriggers := preload("res://src/ext/dialogueactions/da_game_triggers.gd")
const WorldTriggers := preload("res://src/ext/dialogueactions/da_world_triggers.gd")

## Line types DialogueActions adds: name -> [max build, priority]
const LINE_TYPES := {"start": [180, 3], "orgasm": [240, 3], "passed_out": [240, 3], "choking": [240, 3]}
const BUTTON_LINES := 10
const BUTTON_PRIORITY := 3 + 1
const START_DELAY := 60
const CLEAN_INTERVAL := 200

var vars = null
var game = null   # da_game_triggers.gd
var world = null  # da_world_triggers.gd
var _triggers: Dictionary = {}   # name -> {arg_count: Callable}
var _owned: Dictionary = {}      # extension id -> [[name, arg_count]]: triggers other extensions registered
var _owner := ""                 # extension whose additions are being registered (run_addon)
var _line_listeners: Array = []
var _current_line := ""          # line type being chosen by sayRandomPhrase
var _start_pending := false
var _start_delay := 0
var _clean_delay := CLEAN_INTERVAL
var _has_passed_out := false
var _has_choking := false


func _init() -> void:
	id = "dialogueactions"
	title = "DialogueActions"
	description = "Triggers, variables and line types for dialogues written for the Loader mod DialogueActions."
	default_enabled = true


func _enable() -> void:
	vars = VarsScript.new()
	_triggers.clear()
	VarTriggers.register(self)
	game = GameTriggers.new(self)
	game.register()
	world = WorldTriggers.new(self)
	world.register()
	hook_before(&"Dialogue.checkWordAction", _on_word)
	hook_before(&"AdvancedDialogueController.customValueReplacer", _on_insert)
	hook_before(&"AdvancedDialogueController.setValues", _on_set_values)
	hook_before(&"AdvancedDialogueController.canPlay", func(c): vars.before_check(c.args[0]))
	hook_after(&"AdvancedDialogueController.canPlay", func(_c): vars.after_check())
	hook_after(&"Dialogue.startSpeakingPhrase", func(_c): _on_line_started())
	hook_before(&"Dialogue.sayRandomPhrase", func(c): _current_line = str(c.args[0]))
	hook_after(&"Dialogue.sayRandomPhrase", func(_c): _current_line = "")
	hook_before(&"Dialogue.loadCustomDialogue", func(_c): _before_dialogue_load())
	hook_after(&"Dialogue.loadCustomDialogue", func(_c): _setup_line_types())
	on_late_tick(_tick)
	_setup_line_types()
	_owned.clear()
	for a in Extensions.da_addons():
		if a[0] != self:
			run_addon(a[0].id, a[1])


func _disable() -> void:
	if game != null:
		game.remove()
	game = null
	if world != null:
		world.remove()
	world = null
	vars = null


# ---------------------------------------------------------------- triggers

## Runs `setup(self)` with what it registers recorded as `owner`'s (removed again by remove_owner).
func run_addon(owner: String, setup: Callable) -> void:
	var before := _owner
	_owner = owner
	vars.owner = owner
	var prev := Extensions.enter(owner)
	setup.call(self)
	Extensions.leave(prev)
	_owner = before
	vars.owner = before


## Removes the triggers, variables and listeners extension `owner` added.
func remove_owner(owner: String) -> void:
	for t in _owned.get(owner, []):
		if _triggers.has(t[0]):
			_triggers[t[0]].erase(t[1])
			if _triggers[t[0]].is_empty():
				_triggers.erase(t[0])
	_owned.erase(owner)
	if vars != null:
		vars.remove_owner(owner)


func register_trigger(name: String, arg_count: int, fn: Callable) -> void:
	if not _triggers.has(name):
		_triggers[name] = {}
	if _triggers[name].has(arg_count):
		push_error("DialogueActions: trigger [%s] with %d arguments registered twice" % [name, arg_count])
		return
	_triggers[name][arg_count] = fn
	if _owner != "":
		if not _owned.has(_owner):
			_owned[_owner] = []
		_owned[_owner].append([name, arg_count])


func has_trigger(name: String, arg_count: int) -> bool:
	return _triggers.has(name) and _triggers[name].has(arg_count)


## Runs "[A_x][B]" or "A_x" from code. True if every trigger was recognised.
func run_code(code: String) -> bool:
	if code.begins_with("[") and code.ends_with("]"):
		var ok := true
		while code.begins_with("[") and code.ends_with("]"):
			var end := code.find("]")
			ok = _run(Array(code.substr(1, end - 1).split("_"))) and ok
			code = code.substr(end + 1)
		return ok
	return _run(Array(code.split("_")))


## The trigger name "[RAW_args]" would run as, or "" if DialogueActions does not know it (nothing is run).
func recognises(raw: String) -> String:
	var parts := Array(raw.trim_prefix("[").trim_suffix("]").split("_"))
	while not parts.is_empty():
		var t: Dictionary = _triggers.get(parts[0], {})
		if t.has(-1) or t.has(parts.size() - 1):
			return parts[0]
		if parts.size() == 1:
			return ""
		parts[1] = parts[0] + "_" + parts[1]
		parts.remove_at(0)
	return ""


## Matches a trigger split at "_": the first part is the name; a trigger taking any number of arguments wins, then
## one taking exactly the remaining parts; otherwise the first argument joins the name and it tries again
## (so [ARMS_BREAST] finds the trigger "ARMS_BREAST").
func _run(parts: Array) -> bool:
	if parts.is_empty():
		return false
	var name: String = parts[0]
	var args: Array = parts.slice(1)
	var t: Dictionary = _triggers.get(name, {})
	var fn = t.get(-1)
	if fn == null:
		fn = t.get(args.size())
	if fn == null:
		if args.is_empty():
			return false
		args[0] = name + "_" + args[0]
		return _run(args)
	vars.dlog("trigger %s with %d arguments (%s)" % [name, args.size(), ",".join(PackedStringArray(args.map(func(a): return str(a))))])
	fn.call(args)
	return true


## Dialogue.checkWordAction: a recognised trigger runs and the line goes on with the next word, without the pause
## vanilla makes for its own actions; anything else is left to the game (vanilla triggers, queued line names).
func _on_word(c: Hooks.Call) -> void:
	var raw: String = c.args[0]
	if raw.length() < 2:
		return
	if _run(Array(raw.substr(1, raw.length() - 2).split("_"))):
		g.dialogueControl.nextWord()
		c.cancel()


func _on_insert(c: Hooks.Call) -> void:
	var v = vars.insert(c.args[0])
	if v != null:
		c.cancel(v)


func _on_set_values(c: Hooks.Call) -> void:
	vars.write(c.args[0])
	c.cancel()


# ---------------------------------------------------------------- lines

func add_line_change_listener(fn: Callable) -> void:
	_line_listeners.append(fn)


func _before_dialogue_load() -> void:
	vars.unlink_all()


## States for the line types DialogueActions adds, for the lines the loaded dialogue has.
func _setup_line_types() -> void:
	var dc = g.dialogueControl
	var lib = dc.library
	for t in LINE_TYPES:
		if lib.getPhrases(t).size() > 0:
			dc.states[t] = DialogueState.new(LINE_TYPES[t][0], LINE_TYPES[t][1])
	for i in range(1, BUTTON_LINES + 1):
		if lib.getPhrases("button%d" % i).size() > 0:
			dc.states["button%d" % i] = DialogueState.new(240, BUTTON_PRIORITY)
	_has_passed_out = lib.getPhrases("passed_out").size() > 0
	_has_choking = lib.getPhrases("choking").size() > 0
	_start_pending = lib.getPhrases("start").size() > 0
	_start_delay = START_DELAY


func _tick() -> void:
	game.tick()
	if g.gamePaused:
		return
	var dc = g.dialogueControl
	var her = g.her
	_clean_delay -= 1
	if _clean_delay <= 0:
		_clean_unused_states()
	if _start_pending and g.gameRunning:
		if _start_delay <= 0:
			var lines: Array = dc.library.getPhrases("start")
			if lines.size() > 0:
				var idx: int = dc.states["start"].randomPhrase(lines) if dc.states.has("start") else 0
				dc.startSpeakingPhrase(lines[clampi(idx, 0, lines.size() - 1)])
			_start_pending = false
			_clean_delay = CLEAN_INTERVAL
		else:
			_start_delay -= 1
	if _has_passed_out and her.passedOut:
		dc.buildState("passed_out", 120)
		_clean_delay = CLEAN_INTERVAL
	if _has_choking and not her.passedOut and her.passOutFactor != 0 and her.mouthFull:
		dc.buildState("choking", 120)
		_clean_delay = CLEAN_INTERVAL


## Clears the build of states that have no lines (DialogueActions' periodic cleanup).
func _clean_unused_states() -> void:
	var dc = g.dialogueControl
	if not dc.showingText:
		for s in dc.states:
			if dc.library.getPhrases(s).size() == 0 and dc.states[s].build > 0:
				dc.states[s].clearBuild()
	_clean_delay = CLEAN_INTERVAL


## After a line started: line-change listeners, then instant lines. A line that is a single trigger naming a line
## type plays that line type at once; a line type ending in "_INSTANT" whose words are all triggers runs them all
## at once and goes straight on to the queued line.
func _on_line_started() -> void:
	var listeners := _line_listeners
	_line_listeners = []
	for fn in listeners:
		if fn.is_valid():
			fn.call()
	var dc = g.dialogueControl
	var words: Array = dc.words
	if words.size() == 1:
		if words[0].actionWord:
			var action: String = words[0].action
			if dc.library.getPhrases(action).size() > 0:
				dc.stopSpeaking()
				dc.sayRandomPhrase(action)
	elif _current_line.ends_with("_INSTANT"):
		if words.all(func(w): return w.actionWord):
			var queued = dc.states["queued"]
			var before: float = queued.build
			while dc.sayingWord < words.size():
				dc.nextChar()
			if before < queued.build or queued.build == queued.max:
				queued.clearBuild()
				dc.stopSpeaking()
				dc.sayRandomPhrase(dc.queuedPhrase)
