extends SDTExtension
## Port of sby's breastfirmnessV5 Loader mod: how firmly her breasts spring back and how hard her movement throws
## them, set with the Her > Body sliders; their reset buttons give the game's own back (the default). Saved in the
## character code as breastfirmness:<Normal|Manual>,<firmness> and breastforce:<Normal|Manual>,<force>, like the
## Loader mod. Dialogue words [BREASTFIRMNESS_STIFFER] / [BREASTFIRMNESS_LOOSER] make them firmer / looser.
## Adapted: the Loader mod replaced the breasts' update method; here it changes the value points
## BreastController.firmness, .push and .damping, so the game's own spring stays and other extensions combine.
## Its mode buttons and by-size mode are left out: the Loader's "Auto" codes load as the game's own.

var manual := false         # firmness set by hand
var firmness := 0.4         # 0.01 - 1
var force_manual := false   # force set by hand
var force := 0.25           # 0 - 1: the movement's push times 4 x this (0.25: the game's)


func _init() -> void:
	title = "Breast firmness"
	description = "How firmly her breasts spring back and how much her movement throws them."


func _setup() -> void:
	setting("extrafirmnessforcostume", 0.1, {"label": "Extra firmness with a top or bra on", "min": 0.0, "max": 1.0,
		"desc": "Added to the firmness set by hand (the game adds 0.1 to its own)."})
	setting("dialogchangerate", 0.1, {"label": "Change per dialogue word", "min": 0.0, "max": 1.0})
	setting("speedreturn", 0.7, {"label": "Speed kept each frame (the game: 0.7)", "min": 0.0, "max": 0.9})
	setting("enablevanillasaving", true, {"label": "Save in the character code"})


func _enable() -> void:
	modify(&"BreastController.firmness", {"op": "fn", "when": func(_c): return manual,
		"fn": func(_v, c): return _limit(firmness + (get_setting("extrafirmnessforcostume") if c._costumeOn else 0.0))})
	modify(&"BreastController.push", {"op": "fn", "when": func(_c): return force_manual,
		"fn": func(v, _c): return v * force * 4.0})
	var damping: float = get_setting("speedreturn")
	if damping != 0.7:
		modify(&"BreastController.damping", {"op": "set", "value": damping})
	hook_before(&"Dialogue.checkWordAction", _on_word)
	menu_control("her", "Body", {"type": "slider", "label": "Breast firmness", "min": 0.01, "max": 1.0,
		"after": "Breast size", "keywords": "breast firmness bounce jiggle breastfirmness",
		"tip": "How firmly her breasts spring back (0.01 floppy, 1 stiff). Reset: the game's own, which depends on breast size. Saved with the character.",
		"get": func(): return firmness if manual else g.her.leftBreastController._breastFirmness,
		"set": func(v: float): _set_firmness(v), "release": func(): g.saveData.saveCharData(),
		"reset": func(): _set_game(); g.saveData.saveCharData()})
	menu_control("her", "Body", {"type": "slider", "label": "Breast bounce", "min": 0.0, "max": 1.0,
		"after": "Breast size", "keywords": "breast force bounce jiggle breastfirmness",
		"tip": "How much her movement throws her breasts. Reset: the game's own (0.25). Saved with the character.",
		"get": func(): return force if force_manual else 0.25,
		"set": func(v: float): force = v; force_manual = true, "release": func(): g.saveData.saveCharData(),
		"reset": func(): force_manual = false; g.saveData.saveCharData()})
	if get_setting("enablevanillasaving"):
		charcode_field("breastfirmness", func(): return "%s,%.5f" % ["Manual" if manual else "Normal", firmness],
			func(v: String, _l): _load_code(v, false), func(_l): _set_game())
		charcode_field("breastforce", func(): return "%s,%.5f" % ["Manual" if force_manual else "Normal", force],
			func(v: String, _l): _load_code(v, true), func(_l): force_manual = false)
	g.her.updateBreastFirmness()


func _disable() -> void:
	if g.her != null:
		g.her.updateBreastFirmness()   # the game's firmness back (the modifiers are gone)


static func _limit(v: float) -> float:
	return clampf(v, 0.01, 1.0)


func _set_firmness(v: float) -> void:
	firmness = _limit(v)
	manual = true
	g.her.updateBreastFirmness()


func _set_game() -> void:
	manual = false
	if g.her != null:
		g.her.updateBreastFirmness()


func _load_code(v: String, is_force: bool) -> void:
	var parts := v.split(",")
	var on := parts[0] == "Manual"
	var val := float(parts[1]) if parts.size() > 1 and parts[1].is_valid_float() else -1.0
	if is_force:
		force_manual = on and val >= 0
		if force_manual:
			force = clampf(val, 0, 1)
	elif on and val >= 0:
		_set_firmness(val)
	else:
		_set_game()


## [BREASTFIRMNESS_STIFFER] / [BREASTFIRMNESS_LOOSER]: from the current firmness (the game's, if not set by hand).
func _on_word(h) -> void:
	var raw: String = h.args[0]
	var step: float = get_setting("dialogchangerate")
	if raw == "[BREASTFIRMNESS_LOOSER]":
		step = -step
	elif raw != "[BREASTFIRMNESS_STIFFER]":
		return
	var lc = g.her.leftBreastController
	var current: float = firmness if manual else lc._breastFirmness - (0.1 if lc._costumeOn else 0.0)
	_set_firmness(current + step)
	g.dialogueControl.nextWord()
	h.cancel()
