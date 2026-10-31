class_name FlashDisplayObject
extends Node2D
## Base of every node that takes part in the Flash-style display list.
##
## Mirrors flash.display.DisplayObject: Flash name, alpha / color transform, blend mode, filters, masks,
## events and coordinate conversion. Transform properties use Godot's Node2D directly
## (position, rotation_degrees, scale, skew); Flash's per-axis scale maps to scale.x / scale.y.
##
## The "Flash tree" can differ from the Godot tree: masks, filters and blend groups insert proxy nodes
## (see FlashProxy) between a container and its child. Always navigate with parent /
## FlashSprite.getChildAt() etc., never with get_parent()/get_child() directly.

## Instance name as used by ActionScript (getChildByName, timeline property binding).
var flash_name: String = ""
## Timeline bookkeeping (set by FlashMovieClip when the timeline owns this child).
var _depth: int = -1
var _birth: int = -1
var _place_index: int = -1
var _char_id: int = -1
var _library = null
## Flash parent container (independent of proxies in the Godot tree).
var _flash_parent: FlashDisplayObject = null

var mouseEnabled: bool = true
## Flash bitmap caching hint; rendering here does not need it, kept so game code can set it.
var cacheAsBitmap: bool = false

var _color_transform: FlashColorTransform = FlashColorTransform.new()
var _blend_mode: String = "normal"
var _filters: Array = []
var _mask: FlashDisplayObject = null
## Set when this object is used as another object's mask (it is then not rendered itself).
var _masking: Array = []
## Clip-depth (timeline) mask: masks siblings with depth in (_depth, _clip_depth].
var _clip_depth: int = 0
var _proxy: CanvasItem = null

var _listeners: Dictionary = {}


# ---------------------------------------------------------------- tree helpers

## Flash parent container (DisplayObject.parent).
var parent: FlashSprite:
	get:
		return _flash_parent as FlashSprite

## The stage, if this object is on the display list (DisplayObject.stage).
var stage: FlashSprite:
	get:
		return Flash.stage if is_inside_tree() and get_root() == Flash.stage else null

## Flash-style transform aliases (rotation stays Godot's rotation_degrees: 'rotation' is radians in Godot).
var x: float:
	get:
		return position.x
	set(value):
		position.x = value

var y: float:
	get:
		return position.y
	set(value):
		position.y = value

var scaleX: float:
	get:
		return scale.x
	set(value):
		scale.x = value

var scaleY: float:
	get:
		return scale.y
	set(value):
		scale.y = value


## Topmost node actually inserted in the Godot tree for this object (itself or its outermost proxy).
func _tree_node() -> CanvasItem:
	var n: CanvasItem = self
	var p: CanvasItem = _proxy
	while p != null:
		n = p
		p = p.get(&"_proxy")
	return n


func _on_added() -> void:
	if _listener_types.get(FlashEvent.ADDED, 0) > 0:
		dispatchEvent(FlashEvent.new(FlashEvent.ADDED, true))
	if _listener_types.get(FlashEvent.ADDED_TO_STAGE, 0) > 0 and get_root() == Flash.stage:
		_dispatch_stage_event(FlashEvent.ADDED_TO_STAGE)


## ADDED_TO_STAGE / REMOVED_FROM_STAGE go to the object and every descendant (they do not bubble).
func _dispatch_stage_event(type: String) -> void:
	if not _listeners.is_empty():
		dispatchEvent(FlashEvent.new(type))
	var kids = get("_children")
	if kids != null:
		for c in kids.duplicate():
			c._dispatch_stage_event(type)


func _on_removed() -> void:
	if _listener_types.get(FlashEvent.REMOVED, 0) > 0:
		dispatchEvent(FlashEvent.new(FlashEvent.REMOVED, true))


func get_root() -> FlashDisplayObject:
	var o: FlashDisplayObject = self
	while o._flash_parent != null:
		o = o._flash_parent
	return o


# ---------------------------------------------------------------- appearance

var alpha: float:
	get:
		return _color_transform.alphaMultiplier
	set(value):
		_color_transform.alphaMultiplier = value
		_apply_color_transform()


var colorTransform: FlashColorTransform:
	get:
		return _color_transform.clone()
	set(value):
		if value == null:   # Flash throws a TypeError, which the release player ignores (mod frame scripts do this)
			return
		_color_transform = value.clone()
		_apply_color_transform()


func _apply_color_transform() -> void:
	var ct := _color_transform
	var c := Color(ct.redMultiplier, ct.greenMultiplier, ct.blueMultiplier, ct.alphaMultiplier)
	if _proxy is FlashGroupProxy:
		# Offscreen group: multipliers apply to the composited image (Flash layer semantics).
		_proxy.modulate = c
		modulate = Color.WHITE
	else:
		modulate = c
	if ct.has_offsets() or _had_offsets:
		_had_offsets = ct.has_offsets()
		_render_state_changed()

var _had_offsets := false

## Port extension (no Flash equivalent): a texture laid over the stage (paint_transform: stage coordinates -> its
## UV) that every shape under this object composites onto its own pixels with hardlight (shape_paint.gdshader); null
## for none. The nearest object's paint applies. Marks painted onto her skin (spankanywhere).
var paint: Texture2D = null:
	set(value):
		if value == paint:
			return
		paint = value
		_render_state_changed()
var paint_transform := Transform2D.IDENTITY


## Called when inherited render state (color offsets, blend mode, color-matrix filters) may have changed for
## this object or an ancestor. Shapes rebuild their material; containers forward to their children.
func _render_state_changed() -> void:
	pass


## True if this object carries render state that its descendants inherit.
func _has_own_render_state() -> bool:
	if _color_transform.has_offsets() or paint != null:
		return true
	if _blend_mode != "normal" and _blend_mode != "layer":
		return true
	for f in _filters:
		if f is FlashFilter and f.type == "ColorMatrix":
			return true
	return false


## True if this object or any ancestor carries inherited render state.
func _in_render_state_chain() -> bool:
	var o: FlashDisplayObject = self
	while o != null:
		if o._has_own_render_state():
			return true
		o = o._flash_parent
	return false


## Sum of additive offsets (0..255 units) that apply to content drawn by this node, accounting for the
## multipliers of ancestors: Flash applies child transform first, then each parent in turn.
func effective_color_offset() -> Color:
	var off := Color(0, 0, 0, 0)
	var o: FlashDisplayObject = self
	while o != null:
		var ct := o._color_transform
		off = Color(off.r * ct.redMultiplier + ct.redOffset, off.g * ct.greenMultiplier + ct.greenOffset,
			off.b * ct.blueMultiplier + ct.blueOffset, off.a * ct.alphaMultiplier + ct.alphaOffset)
		o = o._flash_parent
	return off


var blendMode: String:
	get:
		return _blend_mode
	set(value):
		_blend_mode = value
		FlashProxy.update_for(self)


var filters: Array:
	get:
		return _filters.duplicate()
	set(value):
		_filters = value.duplicate() if value != null else []
		FlashProxy.update_for(self)


var mask: FlashDisplayObject:
	get:
		return _mask
	set(value):
		if _mask != null:
			_mask._masking.erase(self)
			_mask._update_mask_visibility()
		_mask = value
		if _mask != null:
			_mask._masking.append(self)
			_mask._update_mask_visibility()
		FlashProxy.update_for(self)


func _update_mask_visibility() -> void:
	# Masks are never rendered directly; the proxy of the masked object draws them as a clip region.
	# The container keeps mask objects under a hidden holder node (see FlashSprite._sync_tree).
	var was := _mask_hidden
	_mask_hidden = not (_masking.is_empty() and _clip_depth == 0)
	if was != _mask_hidden and _flash_parent != null:
		_flash_parent._mark_tree_dirty()
		_flash_parent._sync_tree()


var _mask_hidden := false


func _all_descendants() -> Array:
	var out: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if c is CanvasItem:
				out.append(c)
				stack.append(c)
	return out


# ---------------------------------------------------------------- transform helpers

## Flash 'transform.matrix' as Transform2D.
var matrix: Transform2D:
	get:
		return transform
	set(value):
		transform = value


func set_flash_matrix(m: Array) -> void:
	transform = Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5]))


## Global (stage) transform in Flash coordinates (the stage root sits at the canvas origin).
func flash_global_transform() -> Transform2D:
	if _gxf_epoch == xf_epoch:
		return _gxf
	var t := transform
	if _flash_parent != null:
		t = _flash_parent.flash_global_transform() * t
	if is_inside_tree():   # transform changes are only reported in the tree
		_gxf = t
		_gxf_epoch = xf_epoch
	return t


## Global transforms are cached until any display object moves or is re-parented (xf_epoch changes), which makes
## repeated coordinate conversions / hit tests within a script step cheap.
static var xf_epoch := 0
var _gxf := Transform2D()
var _gxf_epoch := -1


func localToGlobal(p: Vector2) -> Vector2:
	return flash_global_transform() * p


func globalToLocal(p: Vector2) -> Vector2:
	return flash_global_transform().affine_inverse() * p


var mouseX: float:
	get:
		return globalToLocal(Flash.mouse_position()).x

var mouseY: float:
	get:
		return globalToLocal(Flash.mouse_position()).y


# ---------------------------------------------------------------- bounds

## Bounds of this object's own drawn content in its local space (overridden by shapes / containers).
func _local_bounds() -> Rect2:
	return Rect2()


## Flash getBounds(target): axis-aligned bounds in target's coordinate space.
func getBounds(target: FlashDisplayObject = null) -> Rect2:
	var t := flash_global_transform()
	if target != null:
		t = target.flash_global_transform().affine_inverse() * t
	if _gclean and _gb_ok and t == _gb_xf:
		return _gb
	if not is_inside_tree():
		return _bounds_through(t)
	_gb = _bounds_through_mark(t)
	_gb_xf = t
	_gb_ok = true
	return _gb


# Bounds caches. Hit tests and getBounds() run many times per tick over large subtrees (sweat, strands, mouse), so
# objects cache them. Caches are only kept for objects in the scene tree, because Godot only reports transform
# changes there; entering the tree invalidates them.
#
# Exact cache (getBounds): any change below an object (a transform, shape frame, graphics, text box or child list)
# calls _bounds_changed(), which marks it and its ancestors dirty, stopping at the first ancestor that is already
# dirty (a dirty object's ancestors are always dirty).
var _gclean := false
var _gb := Rect2()               # last getBounds() result ...
var _gb_xf := Transform2D()      # ... and the transform it was computed through
var _gb_ok := false

# Loose cache (FlashSprite._hit_bounds, for rejecting hit tests early): a superset of the content's local bounds.
# Moved / added / reshaped children only grow it (_hb_include), removals leave it as is, and every cache is rebuilt
# tight when the runtime bumps hb_gen (twice a second). Valid when _hb_gen == hb_gen; an invalid object's
# ancestors are always invalid.
static var hb_gen := 0

## Display objects currently outside the scene tree (created but never added, or removed). Flash's garbage
## collector would eventually free the unreachable ones; here they stay alive, so at shutdown the runtime frees
## whatever is still off the tree (Flash.free_orphans_at_exit) - leaked nodes crash the engine's final cleanup.
static var off_tree: Dictionary = {}
var _hb := Rect2()
var _hb_gen := -1


func _bounds_changed() -> void:
	_gclean = false
	_gb_ok = false
	var o := _flash_parent
	while o != null and o._gclean:
		o._gclean = false
		o._gb_ok = false
		o = o._flash_parent


## _bounds_through() that also marks the visited subtree clean (its changes now propagate to the caller's cache).
func _bounds_through_mark(t: Transform2D) -> Rect2:
	_gclean = true
	return _bounds_through(t)


func _hb_invalidate() -> void:
	var o: FlashDisplayObject = self
	while o != null and o._hb_gen == hb_gen:
		o._hb_gen = -1
		o = o._flash_parent


## Grows the loose bounds of self and its ancestors to include r (in self's space).
func _hb_include(r: Rect2) -> void:
	var o: FlashDisplayObject = self
	while o != null and o._hb_gen == hb_gen:
		if o._hb.encloses(r):
			return
		o._hb = o._hb.merge(r)
		r = _xform_rect(o.transform, r)
		o = o._flash_parent


## Makes the parent's loose bounds cover this object (after it moved, changed shape or was added).
func _hb_notify_parent() -> void:
	var p := _flash_parent
	if p == null or p._hb_gen != hb_gen:
		return
	var b: Rect2
	if self is FlashSprite:
		if _hb_gen != hb_gen:
			p._hb_invalidate()
			return
		b = _hb
	else:
		b = _local_bounds().grow(1.0)
	if b.size == Vector2.ZERO and b.position == Vector2.ZERO:
		return
	p._hb_include(_xform_rect(transform, b))


## Content of this (leaf) object changed shape.
func _content_changed() -> void:
	_bounds_changed()
	_hb_notify_parent()


func _bounds_through(t: Transform2D) -> Rect2:
	var b := _local_bounds()
	if b.size == Vector2.ZERO and b.position == Vector2.ZERO:
		return Rect2()
	return _xform_rect(t, b)


static func _xform_rect(t: Transform2D, r: Rect2) -> Rect2:
	var p0 := t * r.position
	var out := Rect2(p0, Vector2.ZERO)
	out = out.expand(t * Vector2(r.end.x, r.position.y))
	out = out.expand(t * Vector2(r.position.x, r.end.y))
	out = out.expand(t * r.end)
	return out


var width: float:
	get:
		return _get_width()
	set(value):
		_set_width(value)

var height: float:
	get:
		return _get_height()
	set(value):
		_set_height(value)


func _get_width() -> float:
	return getBounds(_flash_parent).size.x if _flash_parent else _bounds_through(transform).size.x


func _get_height() -> float:
	return getBounds(_flash_parent).size.y if _flash_parent else _bounds_through(transform).size.y


func _set_width(value: float) -> void:
	var w := _local_bounds().size.x
	if w > 0.0:
		scale.x = value / w


func _set_height(value: float) -> void:
	var h := _local_bounds().size.y
	if h > 0.0:
		scale.y = value / h


# ---------------------------------------------------------------- hit testing

## Flash hitTestPoint: (x, y) in stage coordinates. shape_flag tests actual drawn pixels instead of bounds.
func hitTestPoint(x: float, y: float, shape_flag: bool = false) -> bool:
	if not shape_flag:
		return getBounds(null).has_point(Vector2(x, y))
	var lp := flash_global_transform().affine_inverse() * Vector2(x, y)
	if hit_exclude != null:
		if native_exclude:
			return ClassDB.class_call_static(&"SDTNative", &"hit_shape_excluding", self, lp, hb_gen, hit_exclude)
		return _hit_shape(lp)
	if native:
		return ClassDB.class_call_static(&"SDTNative", &"hit_shape", self, lp, hb_gen)
	return _hit_shape(lp)


## The native extension (native/, game/bin/) is used for hot paths when loaded; --nonative forces the GDScript code.
static var native: bool = ClassDB.class_exists(&"SDTNative") and not "--nonative" in OS.get_cmdline_user_args()
static var native_exclude: bool = native and ClassDB.class_has_method(&"SDTNative", &"hit_shape_excluding")

## Port addition: an object shape hit tests skip while set (a sweat droplet testing the body part it sits on; the
## original took the droplet off the display list for that, which is slow here).
static var hit_exclude: FlashDisplayObject = null


## p is in this object's local space.
func _hit_shape(_p: Vector2) -> bool:
	return false


# ---------------------------------------------------------------- events

func addEventListener(type: String, listener: Callable, use_capture: bool = false, priority: int = 0) -> void:
	if type == FlashEvent.ENTER_FRAME:
		Flash.add_enter_frame(self, listener)
		return
	var list: Array = _listeners.get(type, [])
	for l in list:
		if l[0] == listener and l[1] == use_capture:
			return
	list.append([listener, use_capture, priority])
	list.sort_custom(func(a, b): return a[2] > b[2])
	_listeners[type] = list
	_listener_types[type] = _listener_types.get(type, 0) + 1


## Number of display-object listeners registered per event type (never decremented for freed objects, so it may
## over-count): dispatching a type nobody listens to is skipped (ADDED / REMOVED fire for every add and remove).
static var _listener_types: Dictionary = {}


func removeEventListener(type: String, listener: Callable, use_capture: bool = false) -> void:
	if type == FlashEvent.ENTER_FRAME:
		Flash.remove_enter_frame(self, listener)
		return
	var list: Array = _listeners.get(type, [])
	for i in range(list.size() - 1, -1, -1):
		if list[i][0] == listener and list[i][1] == use_capture:
			list.remove_at(i)
			_listener_types[type] = maxi(0, _listener_types.get(type, 0) - 1)


func hasEventListener(type: String) -> bool:
	if type == FlashEvent.ENTER_FRAME:
		return Flash.has_enter_frame(self)
	return not _listeners.get(type, []).is_empty()


## Dispatches with Flash semantics: capture phase (root→parent), target, then bubble (parent→root).
func dispatchEvent(event: FlashEvent) -> bool:
	event.target = self
	if _listener_types.get(event.type, 0) == 0:
		return not event.defaultPrevented
	var chain: Array = []
	var p := _flash_parent
	while p != null:
		chain.append(p)
		p = p._flash_parent
	for i in range(chain.size() - 1, -1, -1):
		if event._stop:
			return true
		event.eventPhase = FlashEvent.CAPTURING_PHASE
		chain[i]._invoke_listeners(event, true)
	if not event._stop:
		event.eventPhase = FlashEvent.AT_TARGET
		_invoke_listeners(event, false)
	if event.bubbles:
		for o in chain:
			if event._stop:
				break
			event.eventPhase = FlashEvent.BUBBLING_PHASE
			o._invoke_listeners(event, false)
	return not event.defaultPrevented


func _invoke_listeners(event: FlashEvent, capture: bool) -> void:
	var list: Array = _listeners.get(event.type, [])
	if list.is_empty():
		return
	event.currentTarget = self
	for l in list.duplicate():
		if l[1] != capture:
			continue
		var cb: Callable = l[0]
		if not cb.is_valid():
			continue
		var t0 := Time.get_ticks_usec()
		if cb.get_argument_count() == 0:
			cb.call()
		else:
			cb.call(event)
		var dt := Time.get_ticks_usec() - t0
		if dt > 10000:
			var obj := cb.get_object()
			Flash.hitch_note("%s listener %s.%s %.0f ms" % [event.type,
				obj.get_script().get_global_name() if obj != null and obj.get_script() != null else str(obj),
				cb.get_method(), dt / 1000.0])
		if event._stop_immediate:
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		xf_epoch += 1
		if is_physics_interpolated():   # it glides there between ticks: its render target must redraw every frame
			Flash.note_moved(get_viewport())
		if _flash_parent != null:
			_flash_parent._bounds_changed()
			_hb_notify_parent()
		_gb_ok = false
		return
	if what == NOTIFICATION_POSTINITIALIZE or what == NOTIFICATION_EXIT_TREE:
		off_tree[get_instance_id()] = true
	elif what == NOTIFICATION_PREDELETE:
		off_tree.erase(get_instance_id())
	if what == NOTIFICATION_ENTER_TREE:
		off_tree.erase(get_instance_id())
		set_notify_local_transform(true)
		xf_epoch += 1
		_bounds_changed()
		_hb_invalidate()
	# Debug guard: a display object must never be freed while a live Flash parent still lists it.
	# (On shutdown whole trees are freed after leaving the scene tree, so only in-tree frees are reported.)
	if what == NOTIFICATION_PREDELETE and is_inside_tree() and _flash_parent != null and is_instance_valid(_flash_parent) \
			and not _flash_parent.is_queued_for_deletion() and _flash_parent.get("_children") != null \
			and _flash_parent._children.has(self):
		var path := ""
		var p: FlashDisplayObject = _flash_parent
		while p != null:
			path = "%s#%d/" % [p.flash_name, p._char_id] + path
			p = p._flash_parent
		push_error("Freed while still listed by its parent: %s%s#%d (%s)" % [path, flash_name, _char_id,
			get_script().get_global_name()])
