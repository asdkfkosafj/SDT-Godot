class_name FlashProxy
extends Node2D
## Helper node inserted in the Godot tree (never in the Flash tree) to implement masks.
##
## A clip proxy (timeline clipDepth mask) sits after its mask object and contains the masked siblings.
## A mask proxy (script 'mask' property) wraps a single object. The masked content is rendered into an offscreen
## viewport covering the mask's bounds, the mask's shapes into a second one, and the two are multiplied when drawn.
## (Godot's clip_children cannot be nested, and the game nests masks inside masked containers.) Rectangular masks
## use the cheaper FlashRectClip instead.
##
## Static helpers also maintain the other wrappers an object can need: a FlashGroupProxy (offscreen group for
## 'layer' blend and blur / drop shadow / glow / shader filters) and a BackBufferCopy placed in front of objects
## using backdrop-reading blend modes (overlay, hardlight, screen ...).

const SCREEN_BLENDS := ["overlay", "hardlight", "screen", "lighten", "darken", "difference", "invert"]
const GROUP_FILTERS := ["DropShadow", "Glow", "Blur", "Shader", "Bevel"]
const DISPLAY_SHADER := preload("res://flash/shaders/mask_display.gdshader")
const MAX_SIZE := 4096

var _proxy: CanvasItem = null
var _container = null                   # FlashSprite whose space the mask is drawn in
var _mask_obj: FlashDisplayObject = null
var _wrapped: FlashDisplayObject = null  # for script masks
var _vp: SubViewport
var _mask_vp: SubViewport
var _drawer: _MaskDrawer
var _rect := Rect2()
var _mat := ShaderMaterial.new()


## Draws the mask object's shapes (in container space) inside the mask viewport.
class _MaskDrawer:
	extends Node2D
	var owner_proxy: FlashProxy

	func _draw() -> void:
		owner_proxy._draw_mask(self)


func _init() -> void:
	_vp = _make_viewport()
	_vp.name = "content"
	add_child(_vp)
	_mask_vp = _make_viewport()
	_mask_vp.name = "mask"
	add_child(_mask_vp)
	_drawer = _MaskDrawer.new()
	_drawer.owner_proxy = self
	_mask_vp.add_child(_drawer)
	_mat.shader = DISPLAY_SHADER
	_mat.set_shader_parameter("mask_tex", _mask_vp.get_texture())
	material = _mat


static func _make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	vp.msaa_2d = msaa_level
	vp.size = Vector2i(2, 2)
	return vp


## Whether a canvas item is drawn at all: visible up to the root (across render targets) and not fully
## transparent. Hidden or transparent render targets stop updating (they would redraw every frame for nothing).
static func shown(n: Node) -> bool:
	var a := 1.0
	while n != null:
		if n is CanvasItem:
			var ci: CanvasItem = n
			if not ci.visible:
				return false
			a *= ci.modulate.a * ci.self_modulate.a
			if a < 0.004:
				return false
		n = n.get_parent()
	return true


## The MSAA level of the screen and of every render target; the game's MSAA setting changes it
## (PortSettings.apply_msaa). Render targets need it as much as the screen: a rotated shape whose image is cut off at
## its border shows that border as a hard polygon edge (the end of her collar, eyeliner), which only MSAA smooths.
static var msaa_level: Viewport.MSAA = ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", 0)


static func set_msaa(vp: SubViewport) -> void:
	if vp.msaa_2d != msaa_level:
		vp.msaa_2d = msaa_level


## Creates the node that clips a container's content to mask_obj (timeline clipDepth mask).
static func new_clip(container: FlashSprite, mask_obj: FlashDisplayObject) -> Node2D:
	var p := FlashProxy.new()
	p.name = "clip_%s" % mask_obj.flash_name if mask_obj.flash_name != "" else "clip"
	p._container = container
	p._mask_obj = mask_obj
	Flash.register_mask_proxy(p)
	return p


func content_parent() -> Node:
	return _vp


func _set_content(nodes: Array) -> void:
	FlashProxy.reconcile(_vp, nodes)


func _release_children() -> void:
	for c in _vp.get_children():
		_vp.remove_child(c)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(Flash):   # at quit the runtime can go first
		Flash.unregister_mask_proxy(self)


func _space_object() -> FlashDisplayObject:
	return _container if _container != null else (_wrapped._flash_parent if _wrapped else null)


## How a render target updates after a tick: off while hidden, every frame while an interpolated object inside it
## moves (Flash.moved_viewports), else once (nothing in it changes until the next tick).
static func target_mode(vp: SubViewport, on: bool) -> SubViewport.UpdateMode:
	if not on:
		return SubViewport.UPDATE_DISABLED
	return SubViewport.UPDATE_ALWAYS if Flash.moved_viewports.has(vp) else SubViewport.UPDATE_ONCE


## Called by the runtime every tick: sizes both viewports to the mask's bounds (in container space).
func refresh() -> void:
	if _mask_obj == null or not is_instance_valid(_mask_obj) or not is_inside_tree():
		return
	var on := FlashProxy.shown(self)
	_vp.render_target_update_mode = FlashProxy.target_mode(_vp, on)
	# the mask's shapes are drawn at their tick positions (not interpolated): once per tick is enough
	_mask_vp.render_target_update_mode = SubViewport.UPDATE_ONCE if on else SubViewport.UPDATE_DISABLED
	if not on:
		return
	var cont := _space_object()
	var b: Rect2 = _mask_obj.getBounds(cont) if cont != null else _mask_obj.getBounds(null)
	if b.size.x <= 0.0 or b.size.y <= 0.0:
		_rect = Rect2()
		queue_redraw()
		return
	var screen := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	# screen pixels per unit along each axis (a uniform max of the two made stretched masks far too big)
	var sc := Vector2(maxf(screen.x.length(), 0.01), maxf(screen.y.length(), 0.01))
	b = b.grow_individual(1.0 / sc.x, 1.0 / sc.y, 1.0 / sc.x, 1.0 / sc.y)
	var want := (b.size * sc).ceil()
	if want.x > MAX_SIZE or want.y > MAX_SIZE:
		sc *= minf(MAX_SIZE / want.x, MAX_SIZE / want.y)
		want = (b.size * sc).ceil()
	var cur := Vector2(_vp.size)
	if want.x > cur.x or want.y > cur.y or want.x < cur.x * 0.5 or want.y < cur.y * 0.5:
		var sz := Vector2i(mini(int(want.x * 1.15) + 2, MAX_SIZE), mini(int(want.y * 1.15) + 2, MAX_SIZE))
		_vp.size = sz
		_mask_vp.size = sz
	_rect = Rect2(b.position, Vector2(_vp.size) / sc)
	var ct := Transform2D(0.0, sc, 0.0, -b.position * sc)
	_vp.canvas_transform = ct
	_mask_vp.canvas_transform = ct
	_drawer.queue_redraw()
	queue_redraw()


## Both targets at the current MSAA level (after the setting changed).
func refresh_msaa() -> void:
	FlashProxy.set_msaa(_vp)
	FlashProxy.set_msaa(_mask_vp)


func _draw() -> void:
	if _rect.size == Vector2.ZERO:
		return
	if Flash.debug_flags.has("--proxyoutline"):
		draw_rect(_rect, Color(1, 0, 0), false, 2.0)
		return
	draw_texture_rect(_vp.get_texture(), _rect, false)


func _draw_mask(d: Node2D) -> void:
	if _mask_obj == null or not is_instance_valid(_mask_obj):
		return
	var cont := _space_object()
	var base := cont.flash_global_transform() if cont != null else Transform2D.IDENTITY
	FlashProxy.draw_mask_object(d, _mask_obj, base.affine_inverse())


## Draws a display object's shapes / graphics / bitmaps onto canvas item d, mapped by inv * global transform.
static func draw_mask_object(d: CanvasItem, o: FlashDisplayObject, inv: Transform2D) -> void:
	if o is FlashShape:
		var s: FlashShape = o
		if s._texture == null:
			return
		d.draw_set_transform_matrix(inv * s.flash_global_transform())
		var sc: float = s._library.scale
		# Flash masks with the geometry: a fill below full alpha ("ma", from the converter) still masks fully
		d.draw_texture_rect(s._texture, Rect2(s._draw_entry["x"], s._draw_entry["y"], s._texture.get_width() / sc,
			s._texture.get_height() / sc), false, Color(1, 1, 1, 1.0 / s._draw_entry.get("ma", 1.0)))
	elif o is FlashSprite:
		var sp: FlashSprite = o
		if sp._graphics != null and sp._graphics.has_content():
			d.draw_set_transform_matrix(inv * sp.flash_global_transform())
			sp._graphics._render(d)
		for c in sp._children:
			if c.visible:
				draw_mask_object(d, c, inv)
	elif o is FlashBitmap:
		var b: FlashBitmap = o
		if b.bitmapData != null:
			d.draw_set_transform_matrix(inv * b.flash_global_transform())
			d.draw_texture(b.bitmapData.get_texture(), Vector2.ZERO)


# ---------------------------------------------------------------- backdrop copies

## BackBufferCopy -> the object it is for. A copy is a sibling in front of the object, so hiding the object did not
## hide it: hidden objects' copies (her tan lines when no tan is shown) still copied the whole screen every frame.
static var _backdrops: Dictionary = {}


## Called by the runtime every tick: each copy shows with its object. (Copies stay whole-screen: copying only the
## object's bounds broke the title screen's silhouette, whose blend reads outside them.)
static func update_backdrops() -> void:
	for bbc in _backdrops.keys():
		var obj = _backdrops[bbc]
		if not is_instance_valid(bbc) or not is_instance_valid(obj):
			_backdrops.erase(bbc)
			continue
		var outer: Node = obj._tree_node()
		var on: bool = bbc.get_parent() != null and outer.get_parent() == bbc.get_parent() and FlashProxy.shown(outer)
		if bbc.visible != on:
			bbc.visible = on


# ---------------------------------------------------------------- tree reconciliation

## Makes parent's Godot children exactly 'seq' (in order). Nodes are moved from wherever they are.
static func reconcile(parent: Node, seq: Array) -> void:
	var expanded: Array = []
	for n in seq:
		var pre = n.get_meta("bbc", null) if n.has_meta("bbc") else null
		if pre != null:
			expanded.append(pre)
		expanded.append(n)
	for i in expanded.size():
		var n: Node = expanded[i]
		var cur := n.get_parent()
		if cur != parent:
			if cur != null:
				cur.remove_child(n)
			parent.add_child(n)
		if n.get_index() != i:
			parent.move_child(n, i)
	var extra := parent.get_child_count() - expanded.size()
	for _i in maxi(extra, 0):
		var last := parent.get_child(parent.get_child_count() - 1)
		parent.remove_child(last)


## Rebuilds the wrapper chain of obj after its mask / blend mode / filters changed.
static func update_for(obj: FlashDisplayObject) -> void:
	var need_group := obj._blend_mode == "layer"
	# Flash composites a container with any other blend mode as one group as well. That matters when it holds
	# ERASE / ALPHA pieces, which cut only the group (her bikini tan lines: an overlay clip with an erase child).
	# Other blended containers draw their pieces one by one: a group costs a render target.
	if not need_group and obj._blend_mode != "normal" and obj is FlashSprite and obj._library != null \
			and obj._library.has_cutout(obj._char_id):
		need_group = true
	for f in obj._filters:
		if f is Dictionary and GROUP_FILTERS.has(f.get("type", "")):
			need_group = true
		elif f is FlashFilter and GROUP_FILTERS.has(f.type):
			need_group = true
	if Flash.debug_no_groups:
		need_group = false
	var need_mask := obj._mask != null and not Flash.debug_no_masks
	var prev_outer := obj._tree_node()
	var old_bbc: Node = null
	if prev_outer.has_meta("bbc"):
		old_bbc = prev_outer.get_meta("bbc")
		prev_outer.remove_meta("bbc")
	# Tear down the existing chain (keeping nodes we can reuse).
	var old_group: FlashGroupProxy = null
	var old_mask: CanvasItem = null
	var p: CanvasItem = obj._proxy
	while p != null:
		if p is FlashGroupProxy:
			old_group = p
		elif p is FlashProxy or p is FlashRectClip:
			old_mask = p
		p = p.get(&"_proxy")
	var outer_parent: Node = obj._tree_node().get_parent()
	for n in [old_group, old_mask]:
		if n != null:
			# Only the wrapped content is detached; the wrapper keeps its own viewports.
			var holder: Node = n.content_parent() if (n is FlashRectClip or n is FlashProxy or n is FlashGroupProxy) else n
			for c in holder.get_children():
				holder.remove_child(c)
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
	if obj.get_parent() != null:
		obj.get_parent().remove_child(obj)
	obj._proxy = null
	var inner: CanvasItem = obj
	if need_group:
		var g := old_group if old_group != null else FlashGroupProxy.new()
		g.configure(obj)
		g.add_child_content(inner)
		inner._proxy = g
		inner = g
		# Inside its viewport the object's transform is cancelled per tick; it must not be interpolated.
		obj.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		g.transform = obj.transform
		g.reset_physics_interpolation()
	elif old_group != null:
		old_group.queue_free()
		obj.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	if need_mask:
		var rect := FlashRectClip.rect_of(obj._mask)
		if rect.size != Vector2.ZERO:
			# Rectangle masks (ScreenMask): scissor clip, which can contain further masks.
			var rc: FlashRectClip = old_mask if old_mask is FlashRectClip else FlashRectClip.new()
			if old_mask != null and old_mask != rc:
				old_mask.queue_free()
			rc.name = "rectmask_" + obj.flash_name
			rc._wrapped = obj
			rc._mask_obj = obj._mask
			rc._local_rect = rect
			rc._container = obj._flash_parent as FlashSprite
			Flash.register_mask_proxy(rc)
			rc.content_parent().add_child(inner)
			rc.refresh()
			inner._proxy = rc
			inner = rc
		else:
			var m: FlashProxy = old_mask if old_mask is FlashProxy else FlashProxy.new()
			if old_mask != null and old_mask != m:
				old_mask.queue_free()
			m.name = "mask_" + obj.flash_name
			m._wrapped = obj
			m._mask_obj = obj._mask
			m._container = obj._flash_parent as FlashSprite
			Flash.register_mask_proxy(m)
			m.content_parent().add_child(inner)
			inner._proxy = m
			inner = m
	elif old_mask != null:
		old_mask.queue_free()
	# Backdrop copy for blend modes that read what is behind the object.
	var outer := obj._tree_node()
	if SCREEN_BLENDS.has(obj._blend_mode) or (need_group and FlashGroupProxy.BLEND_IDS.has(obj._blend_mode)):
		if old_bbc == null:
			var bbc := BackBufferCopy.new()
			bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
			old_bbc = bbc
		outer.set_meta("bbc", old_bbc)
		_backdrops[old_bbc] = obj
	elif old_bbc != null:
		if old_bbc.get_parent() != null:
			old_bbc.get_parent().remove_child(old_bbc)
		old_bbc.queue_free()
	obj._render_state_changed()
	obj._apply_color_transform()
	if obj._flash_parent != null:
		obj._flash_parent._mark_tree_dirty()
		obj._flash_parent._sync_tree()
	elif outer_parent != null:
		outer_parent.add_child(outer)
