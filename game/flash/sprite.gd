class_name FlashSprite
extends FlashDisplayObject
## flash.display.Sprite / DisplayObjectContainer.
##
## _children is the authoritative Flash child list (index 0 = bottom). The Godot tree is derived from it by
## _sync_tree(), which wraps children in proxies for masks / blend groups. Syncing is deferred to the end of
## the tick, so all Flash-space queries go through _children and _flash_parent, never the Godot tree.

var _children: Array = []
var mouseChildren: bool = true
var buttonMode: bool = false
var useHandCursor: bool = true
## Rectangle used instead of children for hit testing, if set (Flash hitArea).
var hitArea: FlashDisplayObject = null
var _tree_dirty := false
var _graphics: FlashGraphics = null
var _clip_proxies: Dictionary = {}   # clip mask object -> FlashProxy
var _mask_holder: Node2D = null      # hidden node holding children used as masks (kept in tree, not drawn)


var graphics: FlashGraphics:
	get:
		if _graphics == null:
			_graphics = FlashGraphics.new(self)
		return _graphics


func _draw() -> void:
	if _graphics != null:
		_graphics._render(self)


# ---------------------------------------------------------------- child list API

var numChildren: int:
	get:
		return _children.size()


func addChild(child: FlashDisplayObject) -> FlashDisplayObject:
	return addChildAt(child, _children.size() if child._flash_parent != self else _children.size() - 1)


func addChildAt(child: FlashDisplayObject, index: int) -> FlashDisplayObject:
	if child._flash_parent != null:
		child._flash_parent._detach(child)
	index = clampi(index, 0, _children.size())
	# Fast path: a plain child appended on top of an up-to-date tree just goes to the end of the Godot children.
	var append := index == _children.size() and not _tree_dirty and child._clip_depth == 0 \
		and child._masking.is_empty() and (child._depth < 0 or _clip_proxies.is_empty())
	_children.insert(index, child)
	child._flash_parent = self
	xf_epoch += 1
	if append:
		var n := child._tree_node()
		var pre: Node = n.get_meta("bbc") if n.has_meta("bbc") else null
		for m in [pre, n]:
			if m != null:
				if m.get_parent() == self:
					move_child(m, -1)   # lazily detached from here earlier this tick
				else:
					if m.get_parent() != null:
						m.get_parent().remove_child(m)
					add_child(m)
		_bounds_changed()
	else:
		_mark_tree_dirty()
		_sync_tree()
	_hb_child_added(child)
	if _in_render_state_chain():
		child._render_state_changed()
	child._on_added()
	return child


func _hb_child_added(child: FlashDisplayObject) -> void:
	if _hb_gen != hb_gen:
		return
	if child is FlashSprite and child.is_inside_tree():
		child._hit_bounds()
	child._hb_notify_parent()


func _render_state_changed() -> void:
	for c in _children:
		c._render_state_changed()
	if _graphics != null and _graphics.has_content():
		queue_redraw()


func removeChild(child: FlashDisplayObject) -> FlashDisplayObject:
	if child._flash_parent != self:
		push_error("remove_child_flash: not a child")
		return child
	if _listener_types.get(FlashEvent.REMOVED_FROM_STAGE, 0) > 0 and get_root() == Flash.stage:
		child._dispatch_stage_event(FlashEvent.REMOVED_FROM_STAGE)
	_detach(child)
	child._on_removed()
	return child


func removeChildAt(index: int) -> FlashDisplayObject:
	return removeChild(_children[index])


func removeChildren() -> void:
	while not _children.is_empty():
		removeChildAt(_children.size() - 1)


func _detach(child: FlashDisplayObject) -> void:
	_children.erase(child)
	child._flash_parent = null
	xf_epoch += 1
	if child._clip_depth > 0 and _clip_proxies.has(child):
		var p: Node2D = _clip_proxies[child]
		_clip_proxies.erase(child)
		p._release_children()
		p.queue_free()
	var n := child._tree_node()
	# A plain child directly under this node: removing it (and its backdrop copy) keeps the tree in sync.
	var plain: bool = child._clip_depth == 0 and child._masking.is_empty() and n.get_parent() == self
	var pre: Node = n.get_meta("bbc") if n.has_meta("bbc") else null
	if plain and (pre == null or pre.get_parent() == self):
		if Flash.in_tick:
			# Scripts often remove a child and re-add it within the tick (sweat droplets do it every tick); nothing
			# is drawn mid-tick, so the Godot node stays until the end of the tick unless it comes back.
			Flash.lazy_detach(child, self)
		else:
			remove_child(n)
			if pre != null:
				remove_child(pre)
		_bounds_changed()
	else:
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		_mark_tree_dirty()


func getChildAt(index: int) -> FlashDisplayObject:
	return _children[index] if index >= 0 and index < _children.size() else null


func getChildIndex(child: FlashDisplayObject) -> int:
	return _children.find(child)


func setChildIndex(child: FlashDisplayObject, index: int) -> void:
	var i := _children.find(child)
	if i < 0:
		return
	_children.remove_at(i)
	_children.insert(clampi(index, 0, _children.size()), child)
	_mark_tree_dirty()
	_sync_tree()


func swapChildren(a: FlashDisplayObject, b: FlashDisplayObject) -> void:
	var ia := _children.find(a)
	var ib := _children.find(b)
	if ia < 0 or ib < 0:
		return
	_children[ia] = b
	_children[ib] = a
	_mark_tree_dirty()
	_sync_tree()


func getChildByName(n: String) -> FlashDisplayObject:
	for c in _children:
		if c.flash_name == n:
			return c
	return null


func contains(o: FlashDisplayObject) -> bool:
	while o != null:
		if o == self:
			return true
		o = o._flash_parent
	return false


# ---------------------------------------------------------------- Godot tree sync

func _mark_tree_dirty() -> void:
	_tree_dirty = true
	_bounds_changed()


## Rebuilds the Godot child order (with mask / group proxies) from _children.
func _sync_tree() -> void:
	if not _tree_dirty:
		return
	_tree_dirty = false
	var seq: Array = []          # nodes directly under self, in order
	var masks: Array = []        # mask objects (go into the hidden holder)
	var clip_owner = null        # active clip mask object
	var clip_seq: Array = []
	var used_clips := {}
	for c in _children:
		if not c._masking.is_empty() and c._clip_depth == 0:
			masks.append(c._tree_node())
			continue
		if clip_owner != null and (c._depth < 0 or c._depth > clip_owner._clip_depth):
			_clip_proxies[clip_owner]._set_content(clip_seq)
			clip_owner = null
		if c._clip_depth > 0 and Flash.debug_no_masks:   # (the masked siblings go on unclipped)
			masks.append(c._tree_node())
			continue
		if c._clip_depth > 0:
			var p: Node2D = _clip_proxies.get(c)
			if p == null:
				p = FlashProxy.new_clip(self, c)
				_clip_proxies[c] = p
			used_clips[c] = true
			masks.append(c._tree_node())
			seq.append(p)
			clip_owner = c
			clip_seq = []
			continue
		if clip_owner != null:
			clip_seq.append(c._tree_node())
		else:
			seq.append(c._tree_node())
	if clip_owner != null:
		_clip_proxies[clip_owner]._set_content(clip_seq)
	for k in _clip_proxies.keys():
		if not used_clips.has(k):
			var p: Node2D = _clip_proxies[k]
			_clip_proxies.erase(k)
			p._release_children()
			if p.get_parent() != null:
				p.get_parent().remove_child(p)
			p.queue_free()
	if not masks.is_empty() or _mask_holder != null:
		if _mask_holder == null:
			_mask_holder = Node2D.new()
			_mask_holder.name = "_masks"
			_mask_holder.visible = false
		FlashProxy.reconcile(_mask_holder, masks)
		seq.push_front(_mask_holder)
	FlashProxy.reconcile(self, seq)


# ---------------------------------------------------------------- bounds / hit testing

func _local_bounds() -> Rect2:
	var r := Rect2()
	var first := true
	if _graphics != null and _graphics.has_content():
		r = _graphics.bounds()
		first = false
	for c in _children:
		var cb: Rect2 = c._bounds_through(c.transform)
		if cb.size == Vector2.ZERO and cb.position == Vector2.ZERO:
			continue
		if first:
			r = cb
			first = false
		else:
			r = r.merge(cb)
	return r


func _bounds_through(t: Transform2D) -> Rect2:
	# Tighter than transforming the local bounds: transform each child's bounds individually.
	var r := Rect2()
	var first := true
	if _graphics != null and _graphics.has_content():
		r = _xform_rect(t, _graphics.bounds())
		first = false
	for c in _children:
		var cb: Rect2 = c._bounds_through(t * c.transform)
		if cb.size == Vector2.ZERO and cb.position == Vector2.ZERO:
			continue
		if first:
			r = cb
			first = false
		else:
			r = r.merge(cb)
	return r


func _bounds_through_mark(t: Transform2D) -> Rect2:
	_gclean = true
	var r := Rect2()
	var first := true
	if _graphics != null and _graphics.has_content():
		r = _xform_rect(t, _graphics.bounds())
		first = false
	for c in _children:
		var cb: Rect2 = c._bounds_through_mark(t * c.transform)
		if cb.size == Vector2.ZERO and cb.position == Vector2.ZERO:
			continue
		if first:
			r = cb
			first = false
		else:
			r = r.merge(cb)
	return r


## Loose local bounds of everything below (children's cached bounds transformed, so a superset of the exact
## bounds when children are rotated); cheap to keep up to date, used to reject hit tests early.
func _hit_bounds() -> Rect2:
	if _hb_gen == hb_gen:
		return _hb
	var r := Rect2()
	var first := true
	if _graphics != null and _graphics.has_content():
		r = _graphics.bounds()
		first = false
	for c in _children:
		var cb: Rect2
		if c is FlashSprite:
			cb = c._hit_bounds()
		else:
			cb = c._local_bounds()
		if cb.size == Vector2.ZERO and cb.position == Vector2.ZERO:
			continue
		cb = _xform_rect(c.transform, cb)
		if first:
			r = cb
			first = false
		else:
			r = r.merge(cb)
	r = r.grow(1.0)
	if is_inside_tree():
		_hb = r
		_hb_gen = hb_gen
	return r


func _hit_shape(p: Vector2) -> bool:
	if not _hit_bounds().has_point(p):
		return false
	if _graphics != null and _graphics.hit(p):
		return true
	# Like Flash's hitTestPoint: invisible children count, masks do not.
	for i in range(_children.size() - 1, -1, -1):
		var c: FlashDisplayObject = _children[i]
		if c._clip_depth > 0 or not c._masking.is_empty() or c == hit_exclude:
			continue
		if c._hit_shape(c.transform.affine_inverse() * p):
			if _clip_allows(c, p):
				return true
	return false


## hitTestVisible: as _hit_shape, but only children that show (visible, not see-through, their masks cut them).
func _hit_visible(p: Vector2) -> bool:
	if not _hit_bounds().has_point(p):
		return false
	if _graphics != null and _graphics.hit(p):
		return true
	for i in range(_children.size() - 1, -1, -1):
		var c: FlashDisplayObject = _children[i]
		if c._clip_depth > 0 or not c._masking.is_empty() or c == hit_exclude or not c.visible or c.alpha <= 0.01:
			continue
		var cp := c.transform.affine_inverse() * p
		if c._mask != null and not c._mask.hitTestPoint(c.localToGlobal(cp).x, c.localToGlobal(cp).y, true):
			continue
		if c._hit_visible(cp) and _clip_allows(c, p):
			return true
	return false


## For children under a timeline clip mask, a hit only counts inside the mask.
func _clip_allows(c: FlashDisplayObject, p: Vector2) -> bool:
	if c._depth < 0:
		return true
	for m in _clip_proxies:
		if c._depth > m._depth and c._depth <= m._clip_depth:
			return m._hit_shape(m.transform.affine_inverse() * p)
	return true


## Finds the deepest interactive object under p (local space) for mouse dispatch.
func _mouse_target(p: Vector2) -> FlashDisplayObject:
	if not visible or _mask_hidden:
		return null
	if hitArea != null:
		var gp := flash_global_transform() * p
		return self if mouseEnabled and hitArea.hitTestPoint(gp.x, gp.y, true) else null
	if not _hit_bounds().has_point(p):
		return null
	for i in range(_children.size() - 1, -1, -1):
		var c: FlashDisplayObject = _children[i]
		if not c.visible or c._clip_depth > 0 or not c._masking.is_empty():
			continue
		var lp: Vector2 = c.transform.affine_inverse() * p
		if c._mask != null:
			var gp := flash_global_transform() * p
			if not c._mask.hitTestPoint(gp.x, gp.y, true):
				continue
		if not _clip_allows(c, p):
			continue
		if c is FlashSprite:
			var t: FlashDisplayObject = c._mouse_target(lp)
			if t != null:
				if not mouseChildren:
					return self if mouseEnabled else null
				return t
		elif c._hit_shape(lp):
			if c is FlashTextField and c.mouseEnabled:
				return c if mouseChildren else (self if mouseEnabled else null)
			return self if mouseEnabled else _first_enabled_ancestor()
	if _graphics != null and _graphics.hit(p):
		return self if mouseEnabled else _first_enabled_ancestor()
	return null


func _first_enabled_ancestor() -> FlashDisplayObject:
	var o := _flash_parent
	while o != null:
		if o.mouseEnabled:
			return o
		o = o._flash_parent
	return null
