class_name SDTExtension
extends RefCounted
## Port extension (not in the original game): base class of every extension, built in (src/ext/<name>/) or a
## plugin (Mods/Plugins/<name>/). Extensions change the game only through this API (hooks, tick callbacks,
## settings), so all of them can be switched off at once ("Vanilla mode") and the 1:1 game code stays as it was.
##
## A minimal extension:
##
##     extends SDTExtension
##
##     func _init() -> void:
##         id = "example"
##         title = "Example"
##
##     func _setup() -> void:                       # declare settings (called once, before loading saved values)
##         setting("strength", 0.5, {"label": "Strength", "min": 0.0, "max": 1.0})
##
##     func _enable() -> void:                      # register hooks and tick callbacks
##         on_tick(_tick)
##         hook_after(&"Her.passOut", func(c): print("passed out"))
##
##     func _tick() -> void:
##         pass
##
## Everything registered with on_tick / on_late_tick / hook_before / hook_after / on_event / charcode_field is removed
## automatically when the extension is disabled; _disable() only has to undo changes it made to the game itself.

var id := ""
var title := ""
var description := ""
var author := ""
var version := ""
## Built-in extensions ship with the game; plugins come from Mods/Plugins.
var builtin := true
## A plugin's folder (absolute path); "" for built-in extensions.
var folder := ""
## Whether the extension is on when the player has not chosen yet.
var default_enabled := false
## Set by Extensions while the extension is on.
var enabled := false

var _settings: Dictionary = {}   # key -> {"value", "default", "label", "desc", "min", "max", "step", "options"}
var _setting_order: Array = []


# ---------------------------------------------------------------- overridable

## Declare settings here with setting().
func _setup() -> void:
	pass


## Called when the extension is switched on (at startup if it is enabled).
func _enable() -> void:
	pass


## Called when the extension is switched off, after its hooks and tick callbacks were removed.
func _disable() -> void:
	pass


## Called after a setting changed (from the options screen or set_setting()).
func _setting_changed(_key: String, _value) -> void:
	pass


# ---------------------------------------------------------------- tick and hooks

## Runs `fn` every game tick, before the game's own tick (timelines, then the game's ENTER_FRAME logic).
func on_tick(fn: Callable) -> void:
	Extensions._add_tick(self, fn, false)


## Runs `fn` every game tick, after the game's own logic (before masks follow moved objects).
func on_late_tick(fn: Callable) -> void:
	Extensions._add_tick(self, fn, true)


## Runs `fn(call: Hooks.Call)` before the game method `name` ("Class.method"); see Hooks.
func hook_before(name: StringName, fn: Callable, priority := 0, target: Object = null) -> void:
	_check_point(name, false)
	Hooks.add_before(name, fn, id, priority, target)


func hook_after(name: StringName, fn: Callable, priority := 0, target: Object = null) -> void:
	_check_point(name, false)
	Hooks.add_after(name, fn, id, priority, target)


## Adds a modifier to the value point `name` ("Class.target"); see Hooks (value points). Returns its id for
## Hooks.remove_modifier(); all of an extension's modifiers go when it is switched off.
func modify(name: StringName, spec: Dictionary) -> int:
	_check_point(name, true)
	return Hooks.add_modifier(name, spec, id)


## Names this extension registered that the game has no hook point / value point for ("hook point X", "value point
## Y"): their handlers never run. Shown in the Extensions list and logged once each.
var unknown_points: Array[String] = []

## Why this plugin was stopped ("" while it is fine): an error in its code switches it off for the session, a crash
## of the game while its code ran switches it off at the next start (see Extensions, "guard"). Shown in the
## Extensions list; cleared when the player switches it on again.
var fault := ""


## Declares a hook point / value point this extension runs itself (see Hooks.declare_hook_point), so other
## extensions can use it without a warning.
func declare_hook_point(name: StringName) -> void:
	Hooks.declare_hook_point(name)


func declare_value_point(name: StringName) -> void:
	Hooks.declare_value_point(name)


func _check_point(name: StringName, value: bool) -> void:
	if Hooks.is_value_point(name) if value else Hooks.is_hook_point(name):
		return
	var what := "%s %s" % ["value point" if value else "hook point", name]
	if what in unknown_points:
		return
	unknown_points.append(what)
	push_warning("extension %s: the game has no %s (a typo, or a point that was removed): it never runs" % [id, what])


## Removes this extension's modifiers from the value point `name`, or from every point when no name is given (e.g.
## when a setting that added them is switched off).
func unmodify(name: StringName = &"") -> void:
	Hooks.remove_modifiers(id, name)


## Her mood, including extended moods (see Moods).
func mood() -> String:
	return Moods.current()


## Runs `fn(...)` when the event `name` happens (see Extensions.EVENTS).
func on_event(name: String, fn: Callable) -> void:
	Extensions._add_event(self, name, fn)


## Adds a field to the character code (see CharCode): `getter()` returns the value String (or null to leave it
## out), `setter(value: String, load: CharCode.Load)` applies it, `reset(load)` applies the default when a full
## code lacks the field. after_mods: apply once the code's mods have loaded.
func charcode_field(key: String, getter: Callable, setter: Callable, reset := Callable(), after_mods := false) -> void:
	CharCode.add_field(key, id, getter, setter, reset, after_mods)


## Adds triggers and variables to DialogueActions: `setup(da)` runs now if DialogueActions is on, and again each time
## it is switched on. What it registers (da.register_trigger, da.vars.register / register_read / register_write /
## add_listener) is removed when this extension is disabled. To register more later (e.g. from a trigger), wrap it in
## `da.run_addon(id, func(d): ...)`.
func on_dialogueactions(setup: Callable) -> void:
	Extensions._add_da_addon(self, setup)


## Adds a small button (ExtButton) to a game menu at (x, y): `menu` is the name of an InGameMenu member such as
## "optionsMenu", "sceneMenu", "costumeMenu". `on_click()` runs when it is clicked. Removed when disabled.
func menu_button(menu: String, x: float, y: float, text: String, on_click: Callable, w := 16.0, h := 16.0) -> ExtButton:
	var parent = g.inGameMenu.get(menu) if g.inGameMenu != null else null
	if not parent is FlashSprite:
		push_error("extension %s: no menu '%s'" % [id, menu])
		return null
	var b := ExtButton.new(w, h, text)
	b.x = x
	b.y = y
	b.on_click = guarded(on_click)
	parent.addChild(b)
	Extensions._add_widget(self, b)
	return b


## Adds any display object (an ExtSlider, ExtList, text field, ...) to a game menu at (x, y); removed when the
## extension is disabled. Returns the object, or null if there is no such menu.
func menu_add(menu: String, obj: FlashDisplayObject, x: float, y: float) -> FlashDisplayObject:
	var parent = g.inGameMenu.get(menu) if g.inGameMenu != null else null
	if not parent is FlashSprite:
		push_error("extension %s: no menu '%s'" % [id, menu])
		return null
	obj.x = x
	obj.y = y
	parent.addChild(obj)
	Extensions._add_widget(self, obj)
	return obj


## A slider (ExtSlider) in a game menu; `on_change(value)` while it is dragged.
func menu_slider(menu: String, x: float, y: float, w: float, h: float, value: float, on_change: Callable) -> ExtSlider:
	var sl := ExtSlider.new(w, h)
	sl.set_value(value)
	sl.on_change = guarded(on_change)
	return menu_add(menu, sl, x, y)


## A text label in a game menu.
func menu_label(menu: String, x: float, y: float, w: float, text: String, size := 11.0, align := "left") -> FlashTextField:
	var t := FlashTextField.new()
	t.mouseEnabled = false
	t.selectable = false
	t._box = Rect2(0, 0, w, size + 8)
	t.setTextFormat({"size": size, "align": align, "color": 0x000000})
	t.text = text
	return menu_add(menu, t, x, y)


## Adds a control to the new in-game menu (SDTMenu): `spec` is a control spec (MenuWidgets: type, label, tip, get /
## set, ...), shown in `section` ("her", "behaviour", "effects", ...) under `group` (one of the section's groups, such
## as "Face", or a new group), at the group's end or, with "after": "<label>", after that row. Tagged with the
## extension's name; removed when the extension is disabled.
func menu_control(section: String, group: String, spec: Dictionary) -> void:
	var s := spec.duplicate()
	s["owner"] = id
	s["section"] = section
	s["group"] = group
	SDTMenu.add_control(s)


## Runs `fn()` when the key with Flash key code `keycode` is pressed during play (not while typing in a text field
## or while controls are locked). It is an action the player can rebind in Settings › Hotkeys: `keycode` is its
## default (add Hotkeys.SHIFT / CTRL / ALT for a combination, 0 for none), `label` names it there. `id` keeps a
## changed key when the label is reworded (default: the label).
func on_key(keycode: int, fn: Callable, label := "", id := "") -> void:
	Extensions._add_key(self, keycode, fn, label, id)


## A plugin's own script (path relative to its folder), compiled like its main script. Built-in extensions use
## preload() instead.
func load_script(rel_path: String) -> GDScript:
	return Extensions.compile_script(folder.path_join(rel_path))


## Absolute path of a file in the plugin's folder.
func file_path(rel_path: String) -> String:
	return folder.path_join(rel_path)


# ---------------------------------------------------------------- settings

## Declares a setting. The default's type is the setting's type (bool, int, float, String). `info` keys, all
## optional: "label", "desc", "min", "max", "step" (numbers), "options" (Array of allowed values). The options
## screen is generated from these declarations.
func setting(key: String, default, info: Dictionary = {}) -> void:
	var s := info.duplicate()
	s["default"] = default
	s["value"] = default
	if not _settings.has(key):
		_setting_order.append(key)
	_settings[key] = s


func get_setting(key: String):
	var s = _settings.get(key)
	if s == null:
		push_error("extension %s: unknown setting '%s'" % [id, key])
		return null
	return s["value"]


## Changes a setting, saves it and calls _setting_changed().
func set_setting(key: String, value) -> void:
	var s = _settings.get(key)
	if s == null:
		push_error("extension %s: unknown setting '%s'" % [id, key])
		return
	value = _coerce(s, value)
	if typeof(value) == typeof(s["value"]) and value == s["value"]:
		return
	s["value"] = value
	Extensions._save_setting(self, key, value)
	var prev := Extensions.enter(id)
	_setting_changed(key, value)
	Extensions.leave(prev)


## `fn` wrapped so that errors in it count as this extension's (see `fault`): for callbacks the game's UI calls
## directly, such as a widget's. The menu helpers here already do it; up to two arguments.
func guarded(fn: Callable) -> Callable:
	var eid := id
	return func(a = null, b = null):
		var prev := Extensions.enter(eid)
		var r
		match fn.get_argument_count():
			0: r = fn.call()
			1: r = fn.call(a)
			_: r = fn.call(a, b)
		Extensions.leave(prev)
		return r


## Setting keys in declaration order, with their info ("value", "default", "label", ...).
func settings() -> Array:
	var out := []
	for k in _setting_order:
		var s: Dictionary = _settings[k].duplicate()
		s["key"] = k
		out.append(s)
	return out


func _coerce(s: Dictionary, value):
	match typeof(s["default"]):
		TYPE_BOOL:
			value = bool(value) if not value is String else value.to_lower() in ["1", "true", "yes", "on"]
		TYPE_INT:
			value = int(value)
		TYPE_FLOAT:
			value = float(value)
		TYPE_STRING:
			value = str(value)
		TYPE_COLOR:
			if value is String:
				value = Color.from_string(value, s["default"])
			elif not value is Color:
				value = s["default"]
	if (value is int or value is float) and s.has("min"):
		value = maxf(value, s["min"]) if value is float else maxi(value, s["min"])
	if (value is int or value is float) and s.has("max"):
		value = minf(value, s["max"]) if value is float else mini(value, s["max"])
	if s.has("options") and not value in s["options"]:
		value = s["default"]
	return value


# ---------------------------------------------------------------- files

## Folder for this extension's own files (created on first use). It lives with the save files, so test runs
## with --save-dir never touch the player's data.
func data_dir() -> String:
	var d := Extensions.data_root().path_join(id)
	DirAccess.make_dir_recursive_absolute(d)
	return d
