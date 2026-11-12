class_name FlashGroupProxy
extends Node2D
## Offscreen group for one display object: Flash BlendMode.LAYER (needed for ERASE / ALPHA children) and
## Blur / DropShadow / Glow / Shader filters.
##
## The object is rendered into a SubViewport sized to its bounds, in the object's own local space at screen
## resolution; this node takes the object's transform and draws the result (applying filters). SubViewports
## nest reliably and masks (clip_children) work inside them, unlike CanvasGroup.
##
## Direct mode: while the group would change nothing on screen but the sharpness of rotated outlines (a layer group at
## full alpha whose ERASE / ALPHA pieces are all hidden: his body with her right arm away from him; see _plain), the
## object is moved out of the viewport and drawn straight under this node, which then has an identity transform: no
## render target to lay out and redraw. Any change that needs the group again (a blended piece showing, alpha, a cut,
## an extension reading the render) switches back the same tick, or before the next frame when it happens outside a
## tick.

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

## Ticks a group must have been passthrough before it goes direct: moving the object between the viewport and this
## node takes its whole subtree out of the tree and back, so a piece that blinks does not do that every tick.
const DIRECT_AFTER := 30
## Ticks the target stays after an extension last read it (render_texture / render_rect).
const WANT_TICKS := 30
var _direct := false          # the object is drawn straight under this node (no render target)
var _passthrough := false     # normal composite blend, no filter applied (configure)
var _cut := false
var _plain_since := -1        # first tick of the current passthrough run
var _need_tick := -1          # last tick a blended piece inside showed (scan / blended_shown)
var _wanted_tick := -1000
var _wake_queued := false
var _xf_tick := -1            # the object's transform at the last two ticks (the glide across a switch)
var _cur_xf := Transform2D.IDENTITY
var _prev_xf := Transform2D.IDENTITY
var _snap_items: Array = []   # while direct: the canvas items inside and their transforms at the start of the tick
var _snap_xf: Array = []
var _snap_tick := -1

## Set while a group moves its object in or out of its viewport: display objects then ignore leaving and entering
## the tree (their caches and the playing clips' order stay as they are; nothing about them changed).
static var moving := false
## Objects drawn with a blend that needs their group (shapes with ERASE / ALPHA, from Flash.shape_material, see
## needs_group) -> that group; or -> null for an object whose own group composites with a blend
## (its enclosing group is looked up when needed). Kept up to date where materials and groups are made, so a tick
## only checks these few objects instead of walking the groups' trees.
static var blending: Dictionary = {}
static var _scan_tick := -1
static var _going: Dictionary = {}   # groups that go direct at the start of the next tick (_start_tick)
static var _direct_groups: Dictionary = {}
## --no-direct-groups: groups always render through their target (A/B comparisons).
static var direct_ok := not OS.get_cmdline_user_args().has("--no-direct-groups")


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


## The grouped object itself must not be interpolated (its transform is cancelled per tick), but what moves inside it
## must glide, or it snaps to each tick ahead of the parts around it. Children would inherit the object's OFF.
static func children_glide(obj: Node, on: bool) -> void:
	for c in obj.get_children():
		c.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON if on else Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	if on and not obj.child_entered_tree.is_connected(_child_glides):
		obj.child_entered_tree.connect(_child_glides)
	elif not on and obj.child_entered_tree.is_connected(_child_glides):
		obj.child_entered_tree.disconnect(_child_glides)


static func _child_glides(c: Node) -> void:
	c.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


func configure(obj: FlashDisplayObject) -> void:
	_obj = obj
	name = "group_" + obj.flash_name
	# FlashProxy.update_for took the object out (of the viewport or of this node): it goes back into the target
	_direct = false
	_plain_since = -1
	_margin = 0.0
	_mat.shader = DISPLAY_SHADER
	_mat.set_shader_parameter("mode", 0)
	_mat.set_shader_parameter("blend_mode", BLEND_IDS.get(obj._blend_mode, 0))
	# composited with a blend: it reads what is under it, so a group around it is needed
	if BLEND_IDS.get(obj._blend_mode, 0) != 0:
		blending[obj] = null
	elif blending.has(obj) and blending[obj] == null:
		blending.erase(obj)
	_passthrough = BLEND_IDS.get(obj._blend_mode, 0) == 0
	var shader_filter: FlashFilter = null
	for f in obj._filters:
		if f is FlashFilter and f.type == "Shader":
			shader_filter = f
	if shader_filter != null:
		_passthrough = false
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
			_passthrough = false
	Flash.register_group(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(Flash):   # at quit the runtime can go first
		Flash.unregister_group(self)
		if is_instance_valid(_obj) and blending.has(_obj) and blending[_obj] == null:
			blending.erase(_obj)


func content_parent() -> Node:
	return _vp


func add_child_content(n: Node) -> void:
	_vp.add_child(n)


## Port (for extensions): the group that renders `obj` offscreen, or null when it is drawn directly.
static func of(obj: FlashDisplayObject) -> FlashGroupProxy:
	var p: CanvasItem = obj._proxy
	while p != null:
		if p is FlashGroupProxy:
			return p
		p = p.get(&"_proxy")
	return null


## The render target (updated every frame while the group shows) and the area of the object's local space it covers
## (empty while nothing of it shows): an extension may draw it again elsewhere (the x-ray plugin). Reading either
## keeps the group a render target for WANT_TICKS; the first read from a direct group gets an empty rect (the render
## resumes before the frame is drawn, see _want).
func render_texture() -> Texture2D:
	_want()
	return _vp.get_texture()


func render_rect() -> Rect2:
	_want()
	return _rect


## Reading the render keeps the group a render target (a direct group starts rendering again before the next frame).
func _want() -> void:
	_wanted_tick = Flash.tick_count
	if _direct:
		_queue_wake()


## Leaves out of what this group draws on screen whatever lies inside rect `a` and outside rect `b` (each in its own
## space, reached from the object's local space by `to_a` / `to_b`; no `b`: all of `a`). It is still rendered into
## the target, so render_texture() keeps it. Not with a shader filter (that filter owns the material).
func set_cut(to_a: Transform2D, a: Rect2, to_b := Transform2D.IDENTITY, b := Rect2()) -> void:
	_cut = true
	if _direct:
		_queue_wake()
	_mat.set_shader_parameter("cut_on", true)
	_mat.set_shader_parameter("cut_a_x", to_a.x)
	_mat.set_shader_parameter("cut_a_y", to_a.y)
	_mat.set_shader_parameter("cut_a_o", to_a.origin)
	_mat.set_shader_parameter("cut_a", Vector4(a.position.x, a.position.y, a.end.x, a.end.y))
	_mat.set_shader_parameter("cut_b_x", to_b.x)
	_mat.set_shader_parameter("cut_b_y", to_b.y)
	_mat.set_shader_parameter("cut_b_o", to_b.origin)
	_mat.set_shader_parameter("cut_b", Vector4(b.position.x, b.position.y, b.end.x, b.end.y))


func clear_cut() -> void:
	_cut = false
	_mat.set_shader_parameter("cut_on", false)


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
	var tick := Flash.tick_count
	if _xf_tick != tick:
		_prev_xf = _cur_xf if _xf_tick == tick - 1 else _obj.transform
		_cur_xf = _obj.transform
		_xf_tick = tick
	if _scan_tick != tick:
		_scan()
	if not _plain():
		_plain_since = -1
		if _direct:
			_set_direct(false)
	elif not _direct:
		if _plain_since < 0:
			_plain_since = tick
		elif tick - _plain_since >= DIRECT_AFTER and not _going.has(self):
			_going[self] = true
			if not Flash.tick_before.has(_start_tick):
				Flash.tick_before.append(_start_tick)
	if visible != _obj.visible:
		visible = _obj.visible
		FlashProxy.forget_shown()
	if _direct:
		return
	transform = _obj.transform
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
	# only what can show on screen (a filter's margin beyond the edge, so a blur there still reads its neighbours)
	b = FlashProxy.clip_to_view(self, screen, b, _margin)
	if b.size.x <= 0.0 or b.size.y <= 0.0:   # off-screen
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_rect = Rect2()
		queue_redraw()
		return
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


## Whether drawing the object directly gives the group's picture: it composites with the normal blend, unfiltered,
## uncut, at full alpha, nothing inside it cuts its alpha, and no extension reads the render.
## Not exactly the same pixels everywhere: the target lands on the screen's pixels 1:1 only while the object is
## neither rotated, skewed nor flipped on screen (update_layout); otherwise it is resampled when drawn (as it is when
## a huge group is capped at MAX_SIZE), which softens its outlines by a fraction of a pixel. Drawn directly, those
## outlines are as sharp as an ungrouped object's (about 0.15% of the pixels in the vanilla scene, where his body is
## rotated), in exchange for not redrawing a screen-sized target every frame. Scale alone changes nothing: the target
## follows it at screen resolution.
func _plain() -> bool:
	return direct_ok and _passthrough and not _cut and _need_tick != Flash.tick_count and modulate == Color.WHITE \
		and Flash.tick_count - _wanted_tick > WANT_TICKS


## Moving the object in or out of the viewport resets the physics interpolation of everything inside it (each canvas
## item does that as it enters the tree): what moved in the current tick would be drawn where the tick left it for
## the rest of it instead of gliding there (a jump of a few pixels while he moves). So a group goes direct only at
## the start of a tick, where that reset changes nothing; and as it may have to switch back at any moment, the start
## of every tick notes where the canvas items inside a direct group are (_snap), which is where their glide starts.
static func _start_tick() -> void:
	var going := _going.keys()
	_going.clear()
	for grp in going:
		if is_instance_valid(grp) and not grp._direct and grp._plain_since >= 0 and grp._plain() \
				and grp.is_inside_tree() and is_instance_valid(grp._obj) and not grp._blend_shows():
			grp._prev_xf = grp._obj.transform   # glides on from here (update_layout sets the tick's own pair)
			grp._set_direct(true)
	for grp in _direct_groups.keys():
		if is_instance_valid(grp) and grp._direct and is_instance_valid(grp._obj):
			grp._snap()
		else:
			_direct_groups.erase(grp)


## Where the canvas items inside the object are at the start of this tick (the glide's start; ~0.04 ms for his body).
func _snap() -> void:
	_snap_items = _obj.find_children("*", "CanvasItem", true, false)
	_snap_xf.resize(_snap_items.size())
	for i in _snap_items.size():
		_snap_xf[i] = _snap_items[i].get_transform()
	_snap_tick = Flash.tick_count


## After the move back into the viewport: the canvas items inside glide from where they were at the start of the tick
## again (the move reset that), as they would have without the switch.
func _restore_glide() -> void:
	if _snap_tick != Flash.tick_count:
		return
	for i in _snap_items.size():
		var c = _snap_items[i]
		# what did not move this tick lost nothing
		if is_instance_valid(c) and c.get_transform() != _snap_xf[i] and c.is_physics_interpolated() \
				and _obj.is_ancestor_of(c):
			var ci: RID = c.get_canvas_item()
			RenderingServer.canvas_item_set_transform(ci, _drawn_xf(c, _snap_xf[i]))
			RenderingServer.canvas_item_reset_physics_interpolation(ci)
			RenderingServer.canvas_item_set_transform(ci, _drawn_xf(c, c.get_transform()))
	_snap_items = []


## The transform a canvas item hands the RenderingServer for `xf`: a Control's origin snaps to whole pixels (Godot's
## Control._update_canvas_item_transform, with snap_controls_to_pixels on and the control unrotated).
static func _drawn_xf(c: CanvasItem, xf: Transform2D) -> Transform2D:
	if c is Control and absf(sin((c as Control).rotation * 4.0)) < 0.00001 \
			and c.get_viewport().is_snap_controls_to_pixels_enabled():
		xf.origin = (xf.origin + Vector2(0.5, 0.5)).floor()
	return xf


## Whether a blended piece inside this group shows now (one shown outside a tick since it was last scanned).
func _blend_shows() -> bool:
	for o in blending:
		if is_instance_valid(o) and o.is_visible_in_tree():
			var grp = blending[o]
			if not is_instance_valid(grp):
				grp = _enclosing(o)
			if grp == self:
				return true
	return false


func _set_direct(on: bool) -> void:
	if on == _direct:
		return
	_direct = on
	moving = true
	if on:
		_vp.remove_child(_obj)
		add_child(_obj)
	else:
		remove_child(_obj)
		_vp.add_child(_obj)
	moving = false
	var obj_ci := _obj.get_canvas_item()
	if on:
		_direct_groups[self] = true
		_snap()
		# the object glides itself now (as an ungrouped object does), from _prev_xf
		_obj.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
		children_glide(_obj, false)
		transform = Transform2D.IDENTITY
		RenderingServer.canvas_item_reset_physics_interpolation(get_canvas_item())
		RenderingServer.canvas_item_set_transform(obj_ci, _prev_xf)
		RenderingServer.canvas_item_reset_physics_interpolation(obj_ci)
		RenderingServer.canvas_item_set_transform(obj_ci, _obj.transform)
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_vp.size = Vector2i(2, 2)
		_rect = Rect2()
		queue_redraw()
	else:
		_direct_groups.erase(self)
		# back as FlashProxy.update_for sets it up; this node glides on from where the object was last tick
		_obj.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		children_glide(_obj, FlashRectClip.smooth)
		_restore_glide()
		transform = _prev_xf
		RenderingServer.canvas_item_reset_physics_interpolation(get_canvas_item())
		transform = _obj.transform
		Flash.note_moved(_vp)   # what moved this tick moved outside it: redraw every frame until the next one
	FlashProxy.forget_shown()


## Switches back to a render target before the next frame (a change outside a tick, or from inside a notification).
func _queue_wake() -> void:
	if not _wake_queued:
		_wake_queued = true
		_wake.call_deferred()


func _wake() -> void:
	_wake_queued = false
	if _direct:
		update_layout()


## Once per tick: the groups whose blended pieces show.
static func _scan() -> void:
	var tick: int = Flash.tick_count
	_scan_tick = tick
	for o in blending.keys():
		if not is_instance_valid(o):
			blending.erase(o)
			continue
		var grp = blending[o]
		if not is_instance_valid(grp):
			grp = _enclosing(o)
		if grp != null and grp._need_tick != tick and o.is_visible_in_tree():
			grp._need_tick = tick


## The group that object o is drawn into (its nearest grouped ancestor), or null.
static func _enclosing(o: FlashDisplayObject) -> FlashGroupProxy:
	var p := o._flash_parent
	while p != null:
		if p._proxy is FlashGroupProxy:
			return p._proxy as FlashGroupProxy
		p = p._flash_parent
	return null


## Blends that need the group: ERASE / ALPHA cut the group's own alpha. Other blends (his feet's SUBTRACT shading)
## give the same picture drawn directly wherever what lies under them inside the group is opaque.
static func needs_group(blend: String) -> bool:
	return blend == "erase" or blend == "alpha"


## From Flash.shape_material: shape s blends inside group grp (null: it draws normally, or outside any group).
static func note_blend(s: FlashDisplayObject, grp: FlashGroupProxy) -> void:
	if grp == null:
		blending.erase(s)
		return
	blending[s] = grp
	if grp._direct:
		blended_shown(s)


## A blended object entered the tree or changed visibility: a direct group it now shows in needs its target back.
static func blended_shown(o: FlashDisplayObject) -> void:
	var grp = blending.get(o)
	if not is_instance_valid(grp):
		grp = _enclosing(o)
	if grp != null and grp._direct and o.is_visible_in_tree():
		grp._need_tick = Flash.tick_count
		grp._queue_wake()


## The object's colour multipliers changed (FlashDisplayObject._apply_color_transform).
func color_changed() -> void:
	if _direct and modulate != Color.WHITE:
		_queue_wake()


func _draw() -> void:
	if _rect.size == Vector2.ZERO:
		return
	draw_texture_rect(_vp.get_texture(), _rect, false)
