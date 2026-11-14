extends SDTExtension
## X-ray: while he is in her mouth, a cutaway of her mouth and throat shows his penis inside her. Nothing is drawn in
## advance (a Loader mod did this with drawn frames of one penis, and set his look to match them): the cutaway
## follows her lips and the live outline of her neck, and the penis inside is his own, from his offscreen render (any
## size, type or colour, lipstick and wetness included), bent along her throat.
##
## His penis is drawn whole into that render while the x-ray shows: the game's mask, which cuts off its far end when
## he is deep (so it never pokes out behind her head), becomes a cut where his render is drawn on screen
## (FlashGroupProxy.set_cut), so the scene looks the same.
##
## Stomach (its own switch): a cutaway of her stomach, in her torso, and of the food pipe down to it from her throat
## (stomach_part.gd), drawn over her near arm. What she swallows goes down to it (Her.gulp: what it took from her
## mouth), and so does his cum when he comes while she is held deep (Her.fillMouth while held: the game puts none in
## her mouth then, it goes down her throat); it fills up to Capacity and empties by Digest.

const MASK_SHOWS_ALL := {"x": -100.0, "scale": 4.0}   # the mask's rect then covers any penis length
const FADE_BASE := 8.0       # the length the cutaway fades in over behind her lips at Fade 0
const FADE_PER_STEP := 3.0   # and how much each step of Fade adds to it
const STOMACH_SHOW := ["When in use", "Always", "While he is in her mouth"]   # "in use": he is in her mouth, or
                                                                              # there is cum in it or on its way
const PER_FINISH := 35.0   # about what one finish in her mouth puts there (the game's units: one per spurt tick)
## How both parts (canvas groups) draw their image onto her, at their opacity: opacity x its colour + (1 - opacity^2)
## x what is under it (as it looked when the opacity was each layer's, before they were drawn as one image).
const CUTAWAY_SHADER := """shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float opacity = 1.0;
void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);   // the group's image, premultiplied
	COLOR = vec4(c.rgb * opacity, c.a * opacity * opacity);
}
"""

var on := false
var stomach_on := false
var _view: FlashDisplayObject
var _view_script: GDScript
var _stomach_script: GDScript
var _stomach: FlashDisplayObject
var _in_mouth_before := 0   # cum in her mouth before a swallow
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
	setting("stomach", false, {"label": "Stomach", "desc": "A cutaway of her stomach and of the pipe down to it from "
		+ "her throat."})
	setting("stomach_show", STOMACH_SHOW[0], {"label": "Show stomach", "options": STOMACH_SHOW, "desc": "When the "
		+ "stomach shows: when in use (while he is in her mouth), always, or only while he is in her mouth."})
	setting("stomach_size", 100, {"label": "Stomach size", "min": 50, "max": 200, "desc": "How big the stomach is "
		+ "(percent)."})
	setting("stomach_capacity", 2, {"label": "Capacity", "min": 1, "max": 10, "desc": "About how many finishes it "
		+ "takes to fill her stomach."})
	setting("stomach_digest", 5, {"label": "Digest", "min": 0, "max": 100, "desc": "How fast her stomach empties: "
		+ "percent of a full stomach per minute (0: never)."})


func _enable() -> void:
	_view_script = load_script("xray_view.gd")
	_stomach_script = load_script("stomach_part.gd")
	on = get_setting("on")
	stomach_on = get_setting("stomach")
	menu_control("effects", "X-ray", MenuSchema.toggle("X-ray", "While he is in her mouth, a cutaway of her mouth "
		+ "and throat shows him inside her.", func(): return on, func(v): set_setting("on", v)))
	menu_control("effects", "X-ray", MenuSchema.setting_control(self, "opacity", {"wide": true}))
	menu_control("effects", "X-ray", MenuSchema.setting_control(self, "start", {"wide": true}))
	menu_control("effects", "X-ray", MenuSchema.setting_control(self, "fade", {"wide": true}))
	for k in ["stomach", "stomach_show"]:
		menu_control("effects", "X-ray", MenuSchema.setting_control(self, k))
	for k in ["stomach_size", "stomach_capacity", "stomach_digest"]:
		menu_control("effects", "X-ray", MenuSchema.setting_control(self, k, {"wide": true}))
	on_key(0, func(): set_setting("on", not on), "X-ray on / off")
	on_key(0, func(): set_setting("stomach", not stomach_on), "X-ray stomach on / off", "stomach")
	modify(&"Him.penisMask", {"phase": Hooks.FINAL, "op": "fn", "fn": _mask})
	hook_before(&"Her.gulp", func(_c): _in_mouth_before = g.her.cumInMouth)
	hook_after(&"Her.gulp", func(_c): _swallowed(_in_mouth_before - g.her.cumInMouth))
	hook_after(&"Her.fillMouth", func(_c): _cum_in_throat())
	on_late_tick(_tick)


func _disable() -> void:
	_clear_cut()
	for o in [_view, _stomach]:
		if o != null and o._flash_parent != null:
			o._flash_parent.removeChild(o)
	_view = null
	_stomach = null


func _setting_changed(key: String, value) -> void:
	if key == "on":
		on = value
	elif key == "stomach":
		stomach_on = value


## The game's mask stays where the game wants it, except while the x-ray shows (_tick sets the cut instead).
func _mask(m: Dictionary, _him) -> Dictionary:
	_game_mask = m
	_lifted = _showing()
	return MASK_SHOWS_ALL if _lifted else m


## A swallow of `units` goes down to her stomach.
func _swallowed(units: int) -> void:
	if units > 0 and stomach_on and _stomach != null:
		_stomach.add_lump(float(units))


## He comes while she is held deep: it goes down her throat from his tip (not into her mouth).
func _cum_in_throat() -> void:
	if g.her.held and stomach_on and _stomach != null:
		_stomach.add_stream(_view._inside if _view.shown > 0.0 else -1.0, 1.0)


func _showing() -> bool:
	return _view != null and _view.shown > 0.0


func _tick() -> void:
	var her: Her = g.her
	var him: Him = g.him
	if her == null or him == null:
		return
	if _view == null:
		if not on and not stomach_on:
			return
		_view = _view_script.new()
		_stomach = _stomach_script.new()
		var sh := Shader.new()
		sh.code = CUTAWAY_SHADER
		for o in [_view, _stomach]:
			var mat := ShaderMaterial.new()
			mat.shader = sh
			o.material = mat
		_view.attach_lower(_stomach)
		_place_view()
	_place_stomach()
	var in_mouth := her.mouthFull and not g.penisOut
	_view.opacity = get_setting("opacity")
	_view.start_len = float(get_setting("start"))
	_view.fade_len = FADE_BASE + FADE_PER_STEP * float(get_setting("fade"))
	_view.update_shape(on and in_mouth)
	_stomach.opacity = get_setting("opacity")
	_stomach.size = get_setting("stomach_size") / 100.0
	_stomach.fill_col = Color.hex((g.cumRGB << 8) | 0xFF)
	_stomach.capacity = PER_FINISH * float(get_setting("stomach_capacity"))
	_stomach.digest = _stomach.capacity * float(get_setting("stomach_digest")) / 100.0 / (60.0 * 30.0)
	var show: String = get_setting("stomach_show")
	_view.update_stomach(_stomach, stomach_on and (show == "Always" or in_mouth
		or (show == "When in use" and _stomach.in_use())), in_mouth)
	if _showing() or _lifted:
		_set_cut()
	else:
		_clear_cut()


## Where the cutaway goes in the display list: just above her torso, so it shows down into her chest (over her
## collar; under her ear, earrings, eyewear, the hair in front and her arms). Another host only changes this.
func _place_view() -> void:
	var her: Her = g.her
	her.addChildAt(_view, her.getChildIndex(her.torso) + 1)


## The stomach goes just above her near (right) arm, so the arm does not hide it: in the front layer, under the hair
## that hangs in front of her. Checked every tick (the layer's order may change). Its local space is hers (as the
## arm's), so its sizes match the throat part's.
func _place_stomach() -> void:
	var fore: FlashDisplayObject = g.her.rightForeArmContainer
	var layer = fore._flash_parent
	if layer == null:
		return
	var at: int = layer.getChildIndex(fore)
	var arm: FlashDisplayObject = g.her.rightArmContainer
	if arm._flash_parent == layer:
		at = maxi(at, layer.getChildIndex(arm))
	var placed := false
	if _stomach._flash_parent == layer:
		var i: int = layer.getChildIndex(_stomach)
		placed = i == at + 1
		if i < at:
			at -= 1
	if not placed:
		layer.addChildAt(_stomach, at + 1)
	_stomach.transform = layer.flash_global_transform().affine_inverse() * g.her.flash_global_transform()
	if not placed:   # no gliding in from where it was
		_stomach.reset_physics_interpolation()


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
