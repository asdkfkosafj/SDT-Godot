extends SDTExtension
## X-ray: while he is in her mouth, a cutaway of her mouth and throat shows his penis inside her. Nothing is drawn in
## advance (a Loader mod did this with drawn frames of one penis, and set his look to match them): the cutaway
## follows her lips and the live outline of her neck, and the penis inside is his own, from his offscreen render (any
## size, type or colour, lipstick and wetness included), bent along her throat.
##
## His penis is drawn whole into that render while the x-ray shows: the game's mask, which cuts off its far end when
## he is deep (so it never pokes out behind her head), becomes a cut where his render is drawn on screen
## (FlashGroupProxy.set_cut), so the scene looks the same.

const MASK_SHOWS_ALL := {"x": -100.0, "scale": 4.0}   # the mask's rect then covers any penis length
const FADE_BASE := 8.0       # the length the cutaway fades in over behind her lips at Fade 0
const FADE_PER_STEP := 3.0   # and how much each step of Fade adds to it

var on := false
var _view: FlashDisplayObject
var _view_script: GDScript
var _game_mask := {"x": -100.0, "scale": 1.0}   # what the game asked of the mask this tick
var _cut_set := false
var _lifted := false   # the mask was lifted this tick (the cut must hide the far end on screen)


func _init() -> void:
	title = "X-ray"
	description = "A cutaway of her mouth and throat that shows him inside her."


func _setup() -> void:
	setting("on", false, {"label": "X-ray", "desc": "While he is in her mouth, a cutaway of her mouth and throat "
		+ "shows him inside her."})
	setting("opacity", 0.8, {"label": "Opacity", "min": 0.1, "max": 1.0, "step": 0.01, "desc": "How strongly the "
		+ "cutaway shows over her."})
	setting("start", 0, {"label": "Start", "min": 0, "max": 100, "desc": "How far behind her lips the cutaway "
		+ "begins: nothing of it shows before that point."})
	setting("fade", 0, {"label": "Fade", "min": 0, "max": 100, "desc": "How far behind her lips the cutaway fades in: "
		+ "more brings it in more gradually from where it begins (Start)."})


func _enable() -> void:
	_view_script = load_script("xray_view.gd")
	on = get_setting("on")
	menu_control("effects", "X-ray", MenuSchema.toggle("X-ray", "While he is in her mouth, a cutaway of her mouth "
		+ "and throat shows him inside her.", func(): return on, func(v): set_setting("on", v)))
	menu_control("effects", "X-ray", MenuSchema.setting_control(self, "opacity", {"wide": true}))
	menu_control("effects", "X-ray", MenuSchema.setting_control(self, "start", {"wide": true}))
	menu_control("effects", "X-ray", MenuSchema.setting_control(self, "fade", {"wide": true}))
	on_key(0, func(): set_setting("on", not on), "X-ray on / off")
	modify(&"Him.penisMask", {"phase": Hooks.FINAL, "op": "fn", "fn": _mask})
	on_late_tick(_tick)


func _disable() -> void:
	_clear_cut()
	if _view != null and _view._flash_parent != null:
		_view._flash_parent.removeChild(_view)
	_view = null


func _setting_changed(key: String, value) -> void:
	if key == "on":
		on = value


## The game's mask stays where the game wants it, except while the x-ray shows (_tick sets the cut instead).
func _mask(m: Dictionary, _him) -> Dictionary:
	_game_mask = m
	_lifted = _showing()
	return MASK_SHOWS_ALL if _lifted else m


func _showing() -> bool:
	return _view != null and _view.shown > 0.0


func _tick() -> void:
	var her: Her = g.her
	var him: Him = g.him
	if her == null or him == null:
		return
	if _view == null:
		if not on:
			return
		_view = _view_script.new()
		_place_view()
	_view.opacity = get_setting("opacity")
	_view.start_len = float(get_setting("start"))
	_view.fade_len = FADE_BASE + FADE_PER_STEP * float(get_setting("fade"))
	_view.update_shape(on and her.mouthFull and not g.penisOut)
	if _showing() or _lifted:
		_set_cut()
	else:
		_clear_cut()


## Where the cutaway goes in the display list: just above her torso, so it shows down into her chest (over her
## collar; under her ear, earrings, eyewear, the hair in front and her arms). Another host only changes this.
func _place_view() -> void:
	var her: Her = g.her
	her.addChildAt(_view, her.getChildIndex(her.torso) + 1)


## Hides on screen what the game's mask would have hidden of his penis: inside a band around the penis, outside
## the mask's rect where the game put it.
func _set_cut() -> void:
	var him: Him = g.him
	var grp := FlashGroupProxy.of(him)
	if grp == null:
		return
	var him_inv := him.flash_global_transform().affine_inverse()
	var to_penis: Transform2D = (him_inv * him.penis.flash_global_transform()).affine_inverse()
	var mask: FlashDisplayObject = him.penisMask
	var mask_xf := Transform2D(0.0, Vector2(_game_mask.get("scale", 1.0), mask.scaleY), 0.0,
		Vector2(_game_mask["x"], mask.y))
	grp.set_cut(to_penis, Rect2(-5000, -150, 5000, 300), mask_xf.affine_inverse(), FlashRectClip.rect_of(mask))
	_cut_set = true


func _clear_cut() -> void:
	if not _cut_set:
		return
	_cut_set = false
	var grp := FlashGroupProxy.of(g.him) if g.him != null else null
	if grp != null:
		grp.clear_cut()
