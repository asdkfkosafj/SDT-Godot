class_name FlashGraphics
extends RefCounted
## flash.display.Graphics: records drawing commands and renders them on the owner sprite.
##
## Each fill becomes its own RenderingServer canvas item (drawn under the sprite's children) with a pooled
## gradient material, so solid / linear / radial / focal fills render exactly and can be redrawn every tick.

const FILL_SHADER := preload("res://flash/shaders/graphics_fill.gdshader")

var _owner: FlashSprite
var _fills: Array = []      # [{style: Dictionary, paths: Array[PackedVector2Array]}]
var _lines: Array = []      # [{width, color, alpha, points: PackedVector2Array}]
var _cur_fill = null
var _cur_line = null
var _pen := Vector2.ZERO
var _items: Array = []      # RID per fill
var _materials: Array = []  # ShaderMaterial per fill
var _dirty := false
var _bounds := Rect2()
var _bounds_ok := false
## Set once the owner's bounds caches have been invalidated for the current change; cleared when bounds are read
## again (so drawing a long path invalidates once instead of once per point).
var _inval_sent := false
var _mat_state: Array = []  # per fill material: last parameters set, to skip unchanged ones
# A pre-triangulated, vertex-coloured mesh drawn after the fills (set by native code, e.g. strands).
var _mesh_points := PackedVector2Array()
var _mesh_colors := PackedColorArray()
var _mesh_indices := PackedInt32Array()
var _mesh_rect := Rect2()     # the mesh points' bounds when its maker passed them (no per-vertex loop for bounds)
var _mesh_rect_ok := false
var _mesh_item := RID()
var _mesh_mat: ShaderMaterial = null
var _mesh_state: Dictionary = {}


func _init(owner: FlashSprite) -> void:
	_owner = owner


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for rid in _items:
			RenderingServer.free_rid(rid)
		if _mesh_item.is_valid():
			RenderingServer.free_rid(_mesh_item)


## flash.geom.Matrix.createGradientBox: maps the -819.2..819.2 gradient square onto a w x h box at (tx, ty).
static func createGradientBox(w: float, h: float, rot: float = 0.0, tx: float = 0.0, ty: float = 0.0) -> Transform2D:
	# Flash's formula: a = cos*w, b = sin*h, c = -sin*w, d = cos*h (all / 1638.4).
	var c := cos(rot)
	var s := sin(rot)
	return Transform2D(Vector2(c * w / 1638.4, s * h / 1638.4), Vector2(-s * w / 1638.4, c * h / 1638.4),
		Vector2(tx + w / 2.0, ty + h / 2.0))


func clear() -> void:
	_fills.clear()
	_lines.clear()
	_cur_fill = null
	_cur_line = null
	_pen = Vector2.ZERO
	_mesh_points = PackedVector2Array()
	_mesh_colors = PackedColorArray()
	_mesh_indices = PackedInt32Array()
	_mesh_rect_ok = false
	_mark()


## Adds a ready-made triangle mesh with per-vertex colours (drawn on top of this Graphics' fills). Used by native
## code that builds whole drawings at once (Strand); not part of the Flash API. rect: the points' bounds, exactly as
## _points_rect computes them (native code returns them), or null to compute them when needed.
func setMesh(points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, rect = null) -> void:
	_mesh_points = points
	_mesh_colors = colors
	_mesh_indices = indices
	_mesh_rect_ok = rect != null
	if _mesh_rect_ok:
		_mesh_rect = rect
	_mark()


func beginFill(color: int, alpha: float = 1.0) -> void:
	_end_current_fill()
	var c := Color.hex((color << 8) | 0xFF)
	c.a = alpha
	_cur_fill = {"style": {"mode": 0, "color": c}, "paths": [PackedVector2Array([_pen])]}


## type: "linear" or "radial". colors: RGB ints; alphas: 0..1; ratios: 0..255; m: Transform2D gradient box.
func beginGradientFill(type: String, colors: Array, alphas: Array, ratios: Array, m: Transform2D = Transform2D.IDENTITY,
		_spread: String = "pad", _interp: String = "rgb", focal_point_ratio: float = 0.0) -> void:
	_end_current_fill()
	var cols: Array = []
	for i in colors.size():
		var c := Color.hex((int(colors[i]) << 8) | 0xFF)
		c.a = alphas[i] if i < alphas.size() else 1.0
		cols.append(c)
	var rs: Array = []
	for r in ratios:
		rs.append(float(r) / 255.0)
	_cur_fill = {"style": {"mode": 1 if type == "linear" else 2, "colors": cols, "ratios": rs, "matrix": m,
		"focal": focal_point_ratio}, "paths": [PackedVector2Array([_pen])]}


func endFill() -> void:
	_end_current_fill()
	_mark()


func lineStyle(thickness = null, color: int = 0, alpha: float = 1.0) -> void:
	if thickness == null or (thickness is float and is_nan(thickness)):
		_cur_line = null
		return
	var c := Color.hex((color << 8) | 0xFF)
	c.a = alpha
	_cur_line = {"width": maxf(float(thickness), 1.0), "color": c, "points": PackedVector2Array([_pen])}
	_lines.append(_cur_line)


func moveTo(x: float, y: float) -> void:
	_pen = Vector2(x, y)
	if _cur_fill != null:
		_cur_fill["paths"].append(PackedVector2Array([_pen]))
	if _cur_line != null:
		_cur_line = {"width": _cur_line["width"], "color": _cur_line["color"], "points": PackedVector2Array([_pen])}
		_lines.append(_cur_line)


func lineTo(x: float, y: float) -> void:
	_pen = Vector2(x, y)
	_add_point(_pen)


func curveTo(cx: float, cy: float, ax: float, ay: float) -> void:
	var p0 := _pen
	var c := Vector2(cx, cy)
	var p1 := Vector2(ax, ay)
	var n := clampi(int((p0.distance_to(c) + c.distance_to(p1)) / 3.0), 2, 24)
	var pts := PackedVector2Array()
	pts.resize(n)
	var inv := 1.0 / n
	for i in n:
		var t := (i + 1) * inv
		var u := 1.0 - t
		pts[i] = p0 * (u * u) + c * (2.0 * u * t) + p1 * (t * t)
	_add_points(pts)
	_pen = p1


func drawRect(x: float, y: float, w: float, h: float) -> void:
	moveTo(x, y)
	lineTo(x + w, y)
	lineTo(x + w, y + h)
	lineTo(x, y + h)
	lineTo(x, y)


func drawCircle(x: float, y: float, r: float) -> void:
	moveTo(x + r, y)
	for i in range(1, 33):
		var a := TAU * i / 32.0
		lineTo(x + cos(a) * r, y + sin(a) * r)


func copyFrom(other: FlashGraphics) -> void:
	_fills = other._fills.duplicate(true)
	_lines = other._lines.duplicate(true)
	_cur_fill = null
	_cur_line = null
	_pen = other._pen
	_mesh_points = other._mesh_points
	_mesh_colors = other._mesh_colors
	_mesh_indices = other._mesh_indices
	_mesh_rect = other._mesh_rect
	_mesh_rect_ok = other._mesh_rect_ok
	_mark()


func _add_points(pts: PackedVector2Array) -> void:
	if _cur_fill != null:
		var paths: Array = _cur_fill["paths"]
		var last: PackedVector2Array = paths[paths.size() - 1]
		last.append_array(pts)
		paths[paths.size() - 1] = last
	if _cur_line != null:
		var lp: PackedVector2Array = _cur_line["points"]
		lp.append_array(pts)
		_cur_line["points"] = lp
	_mark()


func _add_point(p: Vector2) -> void:
	if _cur_fill != null:
		var paths: Array = _cur_fill["paths"]
		paths[paths.size() - 1].append(p)
	if _cur_line != null:
		_cur_line["points"].append(p)
	_mark()


## The current path is a band: two edges from its first point to the last point added so far, and back. Its triangles
## then need no general triangulation (triangulate_polygon took 0.7 ms for her neck's outline, every tick).
func markBandTip() -> void:
	if _cur_fill != null and not _cur_fill["paths"].is_empty():
		_cur_fill["band_tip"] = _cur_fill["paths"][-1].size() - 1


## Triangles between the two edges of a band: walks both, always taking the shorter step across.
static func band_triangles(path: PackedVector2Array, tip: int) -> PackedInt32Array:
	var n := path.size()
	var idx := PackedInt32Array()
	idx.resize(3 * (n - 1))
	var a := 0
	var b := n - 1
	var k := 0
	while a < tip or b > tip:
		idx[k] = a
		idx[k + 1] = b
		if b == tip or (a < tip and path[a + 1].distance_squared_to(path[b]) <= path[a].distance_squared_to(path[b - 1])):
			a += 1
			idx[k + 2] = a
		else:
			b -= 1
			idx[k + 2] = b
		k += 3
	return idx


func _end_current_fill() -> void:
	if _cur_fill != null:
		_fills.append(_cur_fill)
		_cur_fill = null


func _mark() -> void:
	_bounds_ok = false
	if not _inval_sent:
		_inval_sent = true
		_owner._bounds_changed()
		_owner._hb_invalidate()
	if not _dirty:
		_dirty = true
		_owner.queue_redraw()


func has_content() -> bool:
	return not _fills.is_empty() or not _lines.is_empty() or _cur_fill != null or not _mesh_indices.is_empty()


func bounds() -> Rect2:
	_inval_sent = false
	if not _bounds_ok:
		_compute_bounds()
		_bounds_ok = true
	return _bounds


func _compute_bounds() -> void:
	var first := true
	var r := Rect2()
	for f in _all_fills():
		for path in f["paths"]:
			for p in path:
				if first:
					r = Rect2(p, Vector2.ZERO)
					first = false
				else:
					r = r.expand(p)
	for l in _lines:
		for p in l["points"]:
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
	if not _mesh_points.is_empty():
		var mb := _mesh_rect if _mesh_rect_ok else _points_rect(_mesh_points)
		r = mb if first else r.merge(mb)
	_bounds = r


static func _points_rect(pts: PackedVector2Array) -> Rect2:
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)


func _all_fills() -> Array:
	if _cur_fill != null:
		return _fills + [_cur_fill]
	return _fills


func hit(p: Vector2) -> bool:
	for f in _all_fills():
		var inside := false
		for path in f["paths"]:
			if path.size() >= 3 and Geometry2D.is_point_in_polygon(p, path):
				inside = not inside
		if inside:
			return true
	var mi := _mesh_indices
	var mp := _mesh_points
	for k in range(0, mi.size() - 2, 3):
		if Geometry2D.point_is_inside_triangle(p, mp[mi[k]], mp[mi[k + 1]], mp[mi[k + 2]]):
			return true
	return false


## Called from the owner's _draw (or by a mask proxy drawing onto 'canvas').
func _render(canvas: CanvasItem) -> void:
	_dirty = false
	if canvas != _owner:
		# Mask rendering: shape only, colour irrelevant.
		for f in _all_fills():
			for path in f["paths"]:
				var tri := Geometry2D.triangulate_polygon(path)
				if tri.size() >= 3:
					canvas.draw_colored_polygon(path, Color.WHITE)
		if not _mesh_indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), _mesh_indices, _mesh_points,
				PackedColorArray([Color.WHITE]))
		return
	var fills := _all_fills()
	var parent_rid := _owner.get_canvas_item()
	while _items.size() < fills.size():
		var rid := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, parent_rid)
		RenderingServer.canvas_item_set_draw_behind_parent(rid, false)
		_items.append(rid)
		var m := ShaderMaterial.new()
		m.shader = FILL_SHADER
		_materials.append(m)
		_mat_state.append({})
		RenderingServer.canvas_item_set_material(rid, m.get_rid())
	for i in _items.size():
		var rid: RID = _items[i]
		RenderingServer.canvas_item_clear(rid)
		# Keep fills underneath the sprite's children, in fill order.
		RenderingServer.canvas_item_set_draw_index(rid, -1000 + i)
		if i >= fills.size():
			continue
		var f: Dictionary = fills[i]
		_configure_material(_materials[i], f["style"], _mat_state[i])
		for path in f["paths"]:
			if path.size() < 3:
				continue
			var idx: PackedInt32Array
			if f.has("band_tip") and path == f["paths"][-1]:
				idx = band_triangles(path, f["band_tip"])
			else:
				idx = Geometry2D.triangulate_polygon(path)
			if idx.is_empty():
				continue
			RenderingServer.canvas_item_add_triangle_array(rid, idx, path, PackedColorArray([Color.WHITE]))
	_render_mesh(parent_rid, fills.size())
	for l in _lines:
		if l["points"].size() >= 2:
			canvas.draw_polyline(l["points"], l["color"], l["width"], true)


func _render_mesh(parent_rid: RID, after: int) -> void:
	if _mesh_indices.is_empty():
		if _mesh_item.is_valid():
			RenderingServer.canvas_item_clear(_mesh_item)
		return
	if not _mesh_item.is_valid():
		_mesh_item = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(_mesh_item, parent_rid)
		_mesh_mat = ShaderMaterial.new()
		_mesh_mat.shader = FILL_SHADER
		RenderingServer.canvas_item_set_material(_mesh_item, _mesh_mat.get_rid())
	RenderingServer.canvas_item_clear(_mesh_item)
	RenderingServer.canvas_item_set_draw_index(_mesh_item, -1000 + after)
	# solid white fill: the vertex colours carry the colour; the shader still applies colour-transform offsets
	_configure_material(_mesh_mat, {"mode": 0, "color": Color.WHITE}, _mesh_state)
	RenderingServer.canvas_item_add_triangle_array(_mesh_item, _mesh_indices, _mesh_points, _mesh_colors)


func _configure_material(m: ShaderMaterial, style: Dictionary, state: Dictionary) -> void:
	var off := _owner.effective_color_offset() / 255.0
	_set_param(m, state, "offset", Vector4(off.r, off.g, off.b, off.a))
	_set_param(m, state, "fill_mode", style["mode"])
	if style["mode"] == 0:
		_set_param(m, state, "solid", style["color"])
		return
	var sm: Transform2D = style["matrix"]
	if absf(sm.determinant()) < 1e-12:
		sm = Transform2D(Vector2(1e-4, 0.0), Vector2(0.0, 1e-4), sm.origin)   # zero-size gradient box
	var mt: Transform2D = sm.affine_inverse()
	_set_param(m, state, "inv_matrix", Basis(Vector3(mt.x.x, mt.x.y, 0), Vector3(mt.y.x, mt.y.y, 0),
		Vector3(mt.origin.x, mt.origin.y, 1)))
	_set_param(m, state, "focal", style.get("focal", 0.0))
	var cols: Array = style["colors"]
	var rs: Array = style["ratios"]
	# stops rarely change: compare the source arrays before rebuilding the packed uniforms
	if state.get("cols") != cols or state.get("rs") != rs:
		state["cols"] = cols.duplicate()
		state["rs"] = rs.duplicate()
		var n := mini(cols.size(), 8)
		var pc := PackedVector4Array()
		var pr := PackedFloat32Array()
		for i in 8:
			var c: Color = cols[mini(i, n - 1)]
			pc.append(Vector4(c.r, c.g, c.b, c.a))
			pr.append(rs[mini(i, n - 1)])
		m.set_shader_parameter("stop_count", n)
		m.set_shader_parameter("stop_colors", pc)
		m.set_shader_parameter("stop_ratios", pr)


static func _set_param(m: ShaderMaterial, state: Dictionary, key: StringName, v) -> void:
	if state.get(key) != v:
		state[key] = v
		m.set_shader_parameter(key, v)
