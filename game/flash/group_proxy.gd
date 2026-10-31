class_name FlashGroupProxy
extends Node2D
## Offscreen group for one display object: Flash BlendMode.LAYER (needed for ERASE / ALPHA children) and
## Blur / DropShadow / Glow / Shader filters.
##
## The object is rendered into a SubViewport sized to its bounds, in the object's own local space at screen
## resolution; this node takes the object's transform and draws the result (applying filters). SubViewports
## nest reliably and masks (clip_children) work inside them, unlike CanvasGroup.

const DISPLAY_SHADER := preload("res://flash/shaders/group_display.gdshader")
const LIQUID_HIGHLIGHT_SHADER := preload("res://flash/shaders/highlight.gdshader")
const SALIVA_OPACITY := 0.85
const MAX_SIZE := 4096
## Blend modes applied when compositing the group (0 = normal); see group_display.gdshader.
const BLEND_IDS := {"overlay": 1, "hardlight": 2, "screen": 3, "lighten": 4, "darken": 5, "difference": 6,
	"invert": 7, "multiply": 8, "add": 9, "subtract": 10}

var _proxy: CanvasItem = null
var _obj: FlashDisplayObject = null
var _vp: SubViewport
var _rect := Rect2()          # obj-local area captured
var _px_scale := 1.0          # render-target pixels per obj-local unit
var _margin := 0.0            # obj-local margin for filters
var _mat := ShaderMaterial.new()


func _init() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vp.msaa_2d = FlashProxy.msaa_level   # the game's MSAA setting (FlashProxy.msaa_level)
	_vp.size = Vector2i(2, 2)
	add_child(_vp)
	_mat.shader = DISPLAY_SHADER
	material = _mat


func configure(obj: FlashDisplayObject) -> void:
	_obj = obj
	name = "group_" + obj.flash_name
	_margin = 0.0
	_mat.shader = DISPLAY_SHADER
	_mat.set_shader_parameter("mode", 0)
	_mat.set_shader_parameter("blend_mode", BLEND_IDS.get(obj._blend_mode, 0))
	var shader_filter: FlashFilter = null
	for f in obj._filters:
		if f is FlashFilter and f.type == "Shader":
			shader_filter = f
	if shader_filter != null:
		# A shader filter owns the material; a following inner drop shadow is folded into it (the highlight
		# shader supports that), other filters are dropped.
		_apply_filter(shader_filter)
		for f in obj._filters:
			if f is FlashFilter and f.type == "DropShadow":
				_mat.set_shader_parameter("has_shadow", true)
				var a := deg_to_rad(f.angle)
				_mat.set_shader_parameter("shadow_offset_px", Vector2(cos(a), sin(a)) * f.distance)
				_mat.set_shader_parameter("shadow_blur_px", Vector2(f.blurX, f.blurY))
				var c := Color.hex((f.color << 8) | 0xFF)
				c.a = f.alpha
				_mat.set_shader_parameter("shadow_color", c)
				_mat.set_shader_parameter("shadow_strength", f.strength)
				_margin = maxf(_margin, maxf(f.blurX, f.blurY) + f.distance + 2.0)
	else:
		for f in obj._filters:
			if not (f is FlashFilter) or f.type == "ColorMatrix":
				continue
			_apply_filter(f)
	Flash.register_group(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(Flash):   # at quit the runtime can go first
		Flash.unregister_group(self)


func content_parent() -> Node:
	return _vp


func add_child_content(n: Node) -> void:
	_vp.add_child(n)


func _apply_filter(f: FlashFilter) -> void:
	if f.type == "Shader":
		_mat.shader = f.shader
		for k in f.shaderParams:
			_mat.set_shader_parameter(k, f.shaderParams[k])
		_margin = maxf(_margin, 8.0)
		return
	_mat.set_shader_parameter("passes", float(maxi(f.quality, 1)))
	_mat.set_shader_parameter("blur_px", Vector2(f.blurX, f.blurY))
	if f.type == "Blur":
		_mat.set_shader_parameter("mode", 1)
	else:
		_mat.set_shader_parameter("mode", 2)
		var a := deg_to_rad(f.angle)
		_mat.set_shader_parameter("offset_px", Vector2(cos(a), sin(a)) * f.distance)
		var c := Color.hex((f.color << 8) | 0xFF)
		c.a = f.alpha
		_mat.set_shader_parameter("shadow_color", c)
		_mat.set_shader_parameter("strength", f.strength)
		_mat.set_shader_parameter("inner", f.inner)
		_mat.set_shader_parameter("knockout", f.knockout)
		_mat.set_shader_parameter("hide_object", f.hideObject)
	_margin = maxf(_margin, maxf(f.blurX, f.blurY) + f.distance + 2.0)
	_filter_px = Vector2(f.blurX, f.blurY)
	_filter_offset = f.distance


var _filter_px := Vector2.ZERO
var _filter_offset := 0.0


## Called by the runtime every tick: follows the object's transform and resizes the render target.
func update_layout() -> void:
	if _obj == null or not is_instance_valid(_obj) or not is_inside_tree() or not _vp.is_inside_tree():
		return
	transform = _obj.transform
	visible = _obj.visible
	# hidden or transparent (a closed menu dropdown at alpha 0): stop rendering the target every frame
	var on := FlashProxy.shown(self)
	_vp.render_target_update_mode = FlashProxy.target_mode(_vp, on)
	if not on:
		return
	var b := _obj._local_bounds()
	if b.size.x <= 0.0 or b.size.y <= 0.0:
		_rect = Rect2()
		queue_redraw()
		return
	# Filters are specified in screen pixels; convert the margin into obj-local units.
	var screen := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	# screen pixels per unit along each axis (a uniform max of the two made stretched groups far too big)
	var sc := Vector2(maxf(screen.x.length(), 0.01), maxf(screen.y.length(), 0.01))
	b = b.grow_individual(_margin / sc.x, _margin / sc.y, _margin / sc.x, _margin / sc.y)
	# Without rotation / skew on screen, start the render target on a whole screen pixel so its texels land on
	# pixels 1:1 (a fractional offset makes the linear filter blur everything, e.g. text).
	if is_zero_approx(screen.x.y) and is_zero_approx(screen.y.x) and screen.x.x > 0.0 and screen.y.y > 0.0:
		var p0 := screen * b.position
		var d := p0.floor() - p0
		b.position += Vector2(d.x / screen.x.x, d.y / screen.y.y)
		b.size -= Vector2(d.x / screen.x.x, d.y / screen.y.y)
	var want := (b.size * sc).ceil()
	if want.x > MAX_SIZE or want.y > MAX_SIZE:
		sc *= minf(MAX_SIZE / want.x, MAX_SIZE / want.y)
		want = (b.size * sc).ceil()
	var cur := Vector2(_vp.size)
	# Resize with hysteresis: grow with slack, shrink only when much too large.
	if want.x > cur.x or want.y > cur.y or want.x < cur.x * 0.5 or want.y < cur.y * 0.5:
		_vp.size = Vector2i(mini(int(want.x * 1.15) + 2, MAX_SIZE), mini(int(want.y * 1.15) + 2, MAX_SIZE))
	_rect = Rect2(b.position, Vector2(_vp.size) / sc)
	# Text inside is rasterized at the render target's scale instead of being drawn at its point size and
	# magnified (blurry), like 2D oversampling does in the main viewport. A stretched group uses at most twice its
	# smaller scale (a dropdown window stretched 11x tall had its text rasterized 11x too big).
	# Quantized up to 1/8 steps so an animated scale does not re-rasterize the glyphs every tick.
	var os := ceilf(minf(maxf(sc.x, sc.y), 2.0 * minf(sc.x, sc.y)) * 8.0) / 8.0
	if _vp.oversampling_override != os:
		_vp.oversampling_override = os
	_px_scale = maxf(sc.x, sc.y)
	# Shadow / blur parameters are in render-target pixels (= screen pixels).
	var stretch := Flash.screen_scale()
	if _mat.shader == LIQUID_HIGHLIGHT_SHADER:
		# render-target pixels per local unit, scene zoom included
		_mat.set_shader_parameter("px_scale", _px_scale)
		# these two layers carry the saliva; other highlight groups keep their opacity
		var is_saliva: bool = _obj == g.strandBackLayer or _obj == g.strandFrontLayer
		_mat.set_shader_parameter("opacity", SALIVA_OPACITY if is_saliva else 1.0)
	elif _mat.shader != DISPLAY_SHADER:
		_mat.set_shader_parameter("px_scale", stretch)
	if _mat.shader == DISPLAY_SHADER:
		_mat.set_shader_parameter("blur_px", _filter_px * stretch)
		var a: float = deg_to_rad(_obj._filters[0].angle) if not _obj._filters.is_empty() and _obj._filters[0] is FlashFilter else 0.0
		_mat.set_shader_parameter("offset_px", Vector2(cos(a), sin(a)) * _filter_offset * stretch)
	# Inside the viewport the object is drawn with its own transform; cancel it and map obj-local -> pixels.
	_vp.canvas_transform = Transform2D(0.0, sc, 0.0, -b.position * sc) * _obj.transform.affine_inverse()
	queue_redraw()


## The target at the current MSAA level (after the setting changed).
func refresh_msaa() -> void:
	FlashProxy.set_msaa(_vp)


func _draw() -> void:
	if _rect.size == Vector2.ZERO:
		return
	draw_texture_rect(_vp.get_texture(), _rect, false)
