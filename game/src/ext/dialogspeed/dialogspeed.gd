extends SDTExtension
## Built-in reimplementation of the Loader mod dialogspeed (sby, v1): how fast her lines are typed out (lower is
## faster; the default is the game's own 55, sby's Loader pack used 40).

const GAME_SPEED := 55


func _init() -> void:
	id = "dialogspeed"
	title = "dialogspeed"
	description = "How fast dialogue lines are typed out."
	default_enabled = true


func _setup() -> void:
	setting("dialogspeed", GAME_SPEED, {"label": "Text speed", "min": 20, "max": 100,
		"desc": "Time per letter; lower is faster. The game's own speed is 55. Lines with a voice clip keep its pace."})


func _enable() -> void:
	_apply(get_setting("dialogspeed"))
	# the setting is the Loader's (ms per letter, lower is faster); the slider shows letters per second, so that
	# right is faster
	menu_control("dialogue", "Dialogue", {"type": "slider", "label": "Text speed",
		"tip": "Letters per second. The game's own speed is 18. Lines with a voice clip keep its pace.",
		"min": 10.0, "max": 50.0, "step": 1.0,
		"get": func(): return roundf(1000.0 / float(get_setting("dialogspeed"))),
		"set": func(v: float): set_setting("dialogspeed", int(roundf(1000.0 / maxf(v, 1.0)))),
		"reset": func(): set_setting("dialogspeed", GAME_SPEED),
		"format": func(v): return "%d / s" % int(v)})


func _disable() -> void:
	_apply(GAME_SPEED)


func _setting_changed(_key: String, value) -> void:
	_apply(value)


func _apply(speed: int) -> void:
	var dc = g.dialogueControl
	if dc == null:
		return
	if dc.typingSpeed == dc.DEFAULT_TYPING_SPEED:   # a line typing at the default speed changes too
		dc.typingSpeed = speed
	dc.DEFAULT_TYPING_SPEED = speed
