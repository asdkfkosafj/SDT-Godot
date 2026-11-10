class_name Hotkeys
extends RefCounted
## Port addition (not in the original game): every hotkey as a named action that the player can rebind
## (Settings › Hotkeys). The game's own keys (DT.registerHotkeys) and extension keys (SDTExtension.on_key) register
## here with their default key; changed keys are kept in port.cfg, section [hotkeys] (only those that differ from
## the default).
##
## A binding is an int: the Flash key code, plus SHIFT / CTRL / ALT for a key that needs them. A key press runs the
## actions bound to exactly that key and modifiers; when none is, the ones bound to the key alone (the game ignores
## modifiers on its keys: Shift+A is still auto mode, while Shift+/ is Shuffle and / a screenshot). Several actions
## can share a key (they all run; the menu shows the clash).

const SHIFT := 1 << 16
const CTRL := 1 << 17
const ALT := 1 << 18
const KEY_MASK := 0xFFFF
const SECTION := "hotkeys"
const GAME := "game"   # owner of the game's own keys

## Actions in registration order: {id, owner, label, default, fn}.
static var actions: Array = []
static var by_id: Dictionary = {}
## Bumped when the action list changes (the menu rebuilds its rows).
static var version := 0
static var _capture := Callable()


## Registers an action (again: replaces it). `default_binding` 0 = no key.
static func add(id: String, owner: String, label: String, default_binding: int, fn: Callable) -> void:
	if by_id.has(id):
		actions.erase(by_id[id])
	var a := {"id": id, "owner": owner, "label": label, "default": default_binding, "fn": fn}
	actions.append(a)
	by_id[id] = a
	version += 1


## Drops every action (the game quitting: no Callables into plugin scripts may outlive them).
static func clear() -> void:
	actions.clear()
	by_id.clear()
	_capture = Callable()
	version += 1


static func remove_owner(owner: String) -> void:
	var keep: Array = []
	for a in actions:
		if a["owner"] == owner:
			by_id.erase(a["id"])
		else:
			keep.append(a)
	if keep.size() != actions.size():
		actions = keep
		version += 1


## The action's current key (the player's, else the default).
static func binding(id: String) -> int:
	var a: Dictionary = by_id.get(id, {})
	if a.is_empty():
		return 0
	return int(PortSettings.get_value(SECTION, id, a["default"]))


static func set_binding(id: String, b: int) -> void:
	var a: Dictionary = by_id.get(id, {})
	if a.is_empty():
		return
	if b == a["default"]:
		PortSettings.erase_value(SECTION, id)
	else:
		PortSettings.set_value(SECTION, id, b)


static func reset(id: String) -> void:
	PortSettings.erase_value(SECTION, id)


## A key press during play (DT.keyPressed: not while typing or with controls locked). Extensions' actions run
## first, then the game's (as before the registry).
static func pressed(keycode: int, shift: bool, ctrl: bool, alt: bool) -> void:
	var mods := (SHIFT if shift else 0) | (CTRL if ctrl else 0) | (ALT if alt else 0)
	var hits := _bound_to(keycode | mods)
	if hits.is_empty() and mods != 0:
		hits = _bound_to(keycode)
	for a in hits.filter(func(x): return x["owner"] != GAME):
		if a["fn"].is_valid():
			var prev := Extensions.enter(a["owner"])
			a["fn"].call()
			Extensions.leave(prev)
	for a in hits.filter(func(x): return x["owner"] == GAME):
		if a["fn"].is_valid():
			a["fn"].call()


static func _bound_to(b: int) -> Array:
	return actions.filter(func(a): return binding(a["id"]) == b)


## The other actions on the same key (for the menu's clash mark).
static func clashes(id: String) -> Array:
	var b := binding(id)
	if b == 0:
		return []
	return actions.filter(func(a): return a["id"] != id and binding(a["id"]) == b)


# ---------------------------------------------------------------- capturing a key (the menu's key buttons)

## The next key press goes to fn(binding) instead of the game: Esc cancels (fn not called), Delete or Backspace
## gives 0 (no key). Shift / Ctrl / Alt alone are waited past.
static func begin_capture(fn: Callable) -> void:
	_capture = fn


static func cancel_capture() -> void:
	_capture = Callable()


static func capturing() -> bool:
	return _capture.is_valid()


## Called by the Flash runtime for every key event while capturing; true = taken (the game does not see it).
## The capture ends after this frame's input, so the menu's own Esc handling sees it as taken too.
static func capture_event(k: InputEventKey) -> bool:
	if not k.pressed or k.echo:
		return true
	var code := FlashKeys.to_flash(k.physical_keycode if k.keycode == KEY_NONE else k.keycode)
	if code in [16, 17, 18] or code == 0:
		return true
	var fn := _capture
	_end_capture.call_deferred()
	if code == 27:
		return true
	if code == 46 or code == 8:
		fn.call(0)
		return true
	fn.call(code | (SHIFT if k.shift_pressed else 0) | (CTRL if k.ctrl_pressed else 0) | (ALT if k.alt_pressed else 0))
	return true


static func _end_capture() -> void:
	_capture = Callable()


# ---------------------------------------------------------------- names

const _NAMES := {8: "Backspace", 9: "Tab", 13: "Enter", 19: "Pause", 20: "Caps Lock", 27: "Esc", 32: "Space",
	33: "Page Up", 34: "Page Down", 35: "End", 36: "Home", 37: "Left", 38: "Up", 39: "Right", 40: "Down",
	45: "Insert", 46: "Delete", 106: "Numpad *", 107: "Numpad +", 109: "Numpad -", 110: "Numpad .",
	111: "Numpad /", 186: ";", 187: "=", 188: ",", 189: "-", 190: ".", 191: "/", 192: "`", 219: "[", 220: "\\",
	221: "]", 222: "'"}


## "Shift+M", "Numpad 7", "" for no key.
static func key_name(b: int) -> String:
	var code := b & KEY_MASK
	if code == 0:
		return ""
	var n: String
	if code >= 65 and code <= 90:
		n = char(code)
	elif code >= 48 and code <= 57:
		n = char(code)
	elif code >= 96 and code <= 105:
		n = "Numpad %d" % (code - 96)
	elif code >= 112 and code <= 126:
		n = "F%d" % (code - 111)
	else:
		n = _NAMES.get(code, "Key %d" % code)
	if b & ALT:
		n = "Alt+" + n
	if b & SHIFT:
		n = "Shift+" + n
	if b & CTRL:
		n = "Ctrl+" + n
	return n
