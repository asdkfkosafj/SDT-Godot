extends SDTExtension
## Built-in reimplementation of the Loader mod aimpenis (sby, V2): aim his penis up and down with the mouse, as in
## bukkake mode, without bukkake mode's cumming (Him > Penis, "Aim with the mouse", off by default like the mod).
## While his penis is out of her mouth, mouse up / down tilts it up / down, further than the game allows (10 more up,
## 30 more down, the mod's settings file as shipped). Shift+M switches it on and off (port addition; M alone is
## the game's Mute). Written from its source.
## Port change: the mod ran his penis physics a second time each frame (pulling against the game's own step, hence
## its "speedrange" boost, and calling her tongue's push twice); here the aim goes into his tilt target once
## (value point Him.penisTiltTarget) at the strength the mod's two steps settled at, and the wider limits into
## Him.penisAngle.

const KEY_M := 77
const BONUS_UP := 10.0
const BONUS_DOWN := 30.0
## The mod's auto "speedrange" (2 + (up + down) / 12) over its two steps a frame: about half of it in one step.
const AIM := (2.0 + (BONUS_UP + BONUS_DOWN) / 12.0) / 2.0


func _init() -> void:
	id = "aimpenis"
	title = "aimpenis"
	description = "aimpenis (sby): aim his penis with the mouse, as in bukkake mode (Him > Penis)."
	default_enabled = true


func _setup() -> void:
	setting("on", false, {"label": "Aim with the mouse",
		"desc": "Out of her mouth, his penis tilts up and down with the mouse, as in bukkake mode, and further. "
			+ "Key: Shift+M."})


func _enable() -> void:
	menu_control("him", "Penis", MenuSchema.setting_control(self, "on", {"after": "Width"}))
	on_key(KEY_M | Hotkeys.SHIFT, toggle, "aim with the mouse")   # Shift: M alone is the game's Mute
	modify(&"Him.penisTiltTarget", {"phase": Hooks.MOOD, "op": "fn", "when": _aiming, "fn": func(v, _him):
		# bukkake mode already aims (the game adds this once)
		return v if g.bukkakeMode else v + (-2.5 - g.currentPos.y * 15.0) * AIM})
	modify(&"Him.penisAngle", {"phase": Hooks.CLAMP, "op": "fn", "when": _aiming, "fn": func(_v, him):
		return clampf(him.penisTilt, -10.0 - BONUS_DOWN, 25.0 + BONUS_UP)})


func _aiming(him) -> bool:
	return get_setting("on") and not him.inMouth


func toggle() -> void:
	set_setting("on", not get_setting("on"))
