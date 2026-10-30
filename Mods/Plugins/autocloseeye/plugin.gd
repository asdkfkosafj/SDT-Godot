extends SDTExtension
## Port of sby's autocloseeyeV4 Loader mod: she closes her eyes while the penis is in her mouth, after a delay (shorter
## the deeper it is), and opens them again, looking at his face, once it is out. Switched on per character with the
## Behaviour > Reactions toggle or the button by the mood selector (classic Scene menu: red = on, yellow = off but her
## eyes still closed from it, white = the game's own behaviour); saved in the character code as
## autoCloseEye:CloseEye / Normal, like the Loader mod.
## Adapted: her eyes close and open through the game's own closeEye / openEye (so they ease shut, and extensions that
## veto Her.openEye still can); looking at his face is a MOOD modifier of the value point Her.lookTarget instead of the
## mod's overwriting her look target every tick, so dialogue look triggers and passing out still win over it and the
## game's own glances are left alone.

var on := false
var closingperiod := false
var mytimer := 0.0
var mytimer2 := 0.0
var _look_him := false   # he is out of her mouth: she looks at his face
var _button: ExtButton


func _init() -> void:
	title = "Auto close eyes"
	description = "She closes her eyes while sucking."


func _setup() -> void:
	setting("defaultmode", false, {"label": "On for new characters"})
	setting("closeeyedist", 0, {"label": "Depth before closing", "min": 0, "max": 400})
	setting("bufferdist", 50, {"label": "Buffer around that depth", "min": 0, "max": 200})
	setting("closeeyedelay", 20, {"label": "Delay before closing / opening (frames)", "min": 0, "max": 1000})
	setting("delaydistmult", 3.0, {"label": "Faster the further past that depth", "min": 0.0, "max": 20.0})
	setting("enablevanillasaving", true, {"label": "Save on/off in the character code"})


func _enable() -> void:
	on = get_setting("defaultmode")
	_button = menu_button("sceneMenu", -330 + 100 + 1 + 22 + 2, 40, "ὄ1", func(): on = not on; g.saveData.saveCharData())
	# the Loader mod ran after both her breathing and her elements update, so twice per tick
	hook_after(&"Her.animateBreathing", func(_c): _adjust())
	hook_after(&"Her.updateElements", func(_c): _adjust())
	modify(&"Her.lookTarget", {"phase": Hooks.MOOD, "op": "fn", "when": func(_her): return on and _look_him,
		"fn": func(_v, her): return her.hisFace})
	on_late_tick(_update_button)
	menu_control("behaviour", "Reactions", MenuSchema.toggle("Close her eyes while sucking",
		"She closes her eyes while the penis is in her mouth and opens them, looking at him, once it is out. Saved with the character.",
		func(): return on, func(v: bool): on = v; g.saveData.saveCharData(), {"keywords": "eyes close autocloseeye"}))
	if get_setting("enablevanillasaving"):
		charcode_field("autoCloseEye", func(): return "CloseEye" if on else "Normal", _load_code,
			func(_l): on = get_setting("defaultmode"))


func _load_code(v: String, _l) -> void:
	if v == "Normal":
		on = false
	elif v == "CloseEye":
		on = true


func _adjust() -> void:
	if not on and not closingperiod:
		return
	var her = g.her
	var depth: float = her.penisInMouthDist
	var closed: bool = her.eyelidMotion["isClosed"]
	var dist: int = get_setting("closeeyedist")
	var buffer: int = get_setting("bufferdist")
	var mult: float = get_setting("delaydistmult")
	var delay: int = get_setting("closeeyedelay")
	var deep := dist - buffer <= depth if closed else dist + buffer <= depth
	if her.mouthFull and deep:
		mytimer = minf(mytimer + 1 + mult * maxf(0, depth - dist - buffer) / 100, 30000)
		mytimer2 = 0
		_look_him = false
		if not closed and mytimer >= delay:
			her.closeEye()
			closingperiod = true
	else:
		mytimer = 0
		mytimer2 = minf(mytimer2 + 1 + mult * maxf(0, dist - buffer - depth) / 100, 30000)
		if closed and mytimer2 >= delay:
			her.openEye()
		closingperiod = false
		_look_him = true


func _update_button() -> void:
	if _button != null:
		_button.set_color(0xFF0000 if on else (0xFFFF00 if closingperiod else 0xFFFFFF))
