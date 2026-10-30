extends SDTExtension
## Port of sby's darkenpassoutV1 Loader mod: dark rings close in and the screen darkens as she starts to pass out.
## A button next to the breath option (Options menu) switches it on (green) and off.

var on := true
var _blackover: FlashSprite
var _flash: ScreenEffects
var _target := 0.0
var _button: ExtButton


func _init() -> void:
	title = "Darken pass out"
	description = "Dark rings and darkening as she starts to pass out."


func _setup() -> void:
	setting("defaultmode", true, {"label": "On for new characters"})
	setting("fadetarget", 0.12, {"label": "Darkening while fading", "min": 0.0, "max": 1.0})
	setting("fadepassouttarget", 0.15, {"label": "Darkening while passed out", "min": 0.0, "max": 1.0})
	setting("darkringalpha", 1.0, {"label": "Ring opacity", "min": 0.0, "max": 1.0})
	setting("darkringpulsealpha", 0.3, {"label": "Ring pulse opacity", "min": 0.0, "max": 1.0})
	setting("pulseonpassedout", true, {"label": "Pulse when she passes out"})
	setting("pulseonpassoutcough", false, {"label": "Pulse on coughs while fading"})
	setting("enablevanillasaving", false, {"label": "Save on/off in the character code"})


func _enable() -> void:
	on = get_setting("defaultmode")
	var c: FlashSprite = g.container
	_blackover = FlashSprite.new()
	_blackover.graphics.beginFill(0x000000, 1.0)
	_blackover.graphics.drawRect(0, 0, 900, 700)
	_blackover.graphics.endFill()
	_blackover.alpha = 0
	_blackover.mouseEnabled = false
	_blackover.mouseChildren = false
	c.addChildAt(_blackover, c.getChildIndex(g.screenEffects))
	_flash = ScreenEffects.new()
	_flash.blendMode = "subtract"
	_flash.mouseEnabled = false
	_flash.mouseChildren = false
	c.addChildAt(_flash, c.getChildIndex(g.screenEffects))
	_flash.whiteout.alpha = get_setting("darkringalpha")
	_match_screen()
	_button = menu_button("optionsMenu", 90, -38, "☀", func(): on = not on; _match_screen(); g.saveData.saveCharData())
	on_late_tick(_tick)
	hook_after(&"Her.passOut", func(_c): _passed_out())
	if get_setting("enablevanillasaving"):
		charcode_field("darkenpassout", func(): return "1" if on else "0",
			func(v, _l): on = v == "1"; _match_screen(),
			func(_l): on = get_setting("defaultmode"))


func _disable() -> void:
	for o in [_blackover, _flash]:
		if o != null and o._flash_parent != null:
			o._flash_parent.removeChild(o)
	_blackover = null
	_flash = null


func _setting_changed(key: String, value) -> void:
	if key == "darkringalpha" and _flash != null:
		_flash.whiteout.alpha = value


func _tick() -> void:
	var her = g.her
	if on:
		_button.set_color(0x00FF00)
		var perc: float = her.passOutFactor / her.passOutMax * 100.0
		perc = perc * 2.0 if perc < 25.0 else perc * 2.0 / 3.0 + 100.0 / 3.0
		_flash.showWhiteout(perc)
		_flash.whiteFlash.alpha = her.passOutFactor / her.passOutMax * get_setting("darkringpulsealpha")
		if her.passedOut:
			_target = get_setting("fadepassouttarget")
		else:
			_target = her.passOutFactor / her.passOutMax * get_setting("fadetarget")
			if get_setting("pulseonpassoutcough") and her.passOutFactor > 0 and her.coughFactor > 0.5:
				_flash.showPulse()
				_flash.stopPulse()
	else:
		_button.set_color(0xFFFFFF)
		_target = 0.0
		_flash.whiteFlash.alpha = 0
		_flash.showWhiteout(1)
	_blackover.alpha = _blackover.alpha + (_target - _blackover.alpha) / 5.0


func _passed_out() -> void:
	if on and get_setting("pulseonpassedout"):
		_flash.showPulse()
		_flash.stopPulse()


## The game's screen effects are scaled to the screen size; match them.
func _match_screen() -> void:
	var se: ScreenEffects = g.screenEffects
	_flash.whiteFlash.scaleX = se.whiteFlash.scaleX
	_flash.whiteFlash.x = se.whiteFlash.x
	_flash.whiteout.scaleX = se.whiteout.scaleX
	_flash.whiteout.x = se.whiteout.x
	_blackover.scaleX = se.whiteFlash.scaleX
	_blackover.x = se.whiteFlash.x
