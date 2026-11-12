extends FlashDisplayObject
## The x-ray cutaway (see plugin.gd), rebuilt every tick in its own local space from her lips, the outline of her
## neck and his penis, so it can sit anywhere in the display list.
##
## A centre line leaves her lips along him and bends once, smoothly, down through her neck into her chest: it ends
## past the base of her throat (a part of the way from the front of her neck to its back), heading along her neck. Along it: the throat wall, the inside of her
## throat (around him where he is, closed past his tip), and his penis, taken from his offscreen render and bent
## along the line, as long as the part of him inside her.
##
## Drawn in the main pass as a canvas group (its opacity applies to the whole cutaway at once), not in a render
## target of its own: that one could be drawn before his render in a frame and show his previous frame.

const STEP := 3.0          # spacing of the samples along the centre line (local units)
const DEPTH := 0.32        # where her throat runs, from the front of her neck (0) to its back (1)
const JOIN := 0.5          # the point along her throat (0 jaw .. 1 chest) the curve's end is measured from
const TAIL := 20.0         # how far past the base of her neck the curve ends (towards her chest)
const PULL_IN := 0.45      # how far the curve keeps going in along him (times the distance from her lips to its end)
const PULL_DOWN := 0.45    # how far up her neck it comes down along her neck (same)
const SMOOTH := 12         # smoothing passes on the centre line
const WALL := 6.0          # thickness of the throat wall
const GLOW := 10.0         # a soft red glow around her throat
const CLOSED := 2.5        # half width of her throat where he is not
const ROOM := 3.0          # her throat around him
const EDGE := 3.0          # penis-local margin around his outline in the strip taken from his render
const PAST_TIP := 12.0     # penis-local length taken past his tip point (the rounded end of the art)
const FOLD := 0.85         # inside a bend, nothing reaches further than this times the bend's radius
const FADE := 0.25         # per tick, in and out
## The fade behind the start edge, per pixel (set per vertex, it would follow the strips' rows: a wide strip's
## triangles blend it straight across, cut off where it reaches full). `behind` is linear in the position, so
## interpolating it is exact; the clamp happens per pixel. Premultiplied, as his render is.
const FADE_SHADER := """
shader_type canvas_item;
render_mode blend_premul_alpha;
uniform vec2 edge_at;
uniform vec2 edge_in;
uniform float start_len;
uniform float fade_len;
varying float behind;
// > 1: it builds up slowly at first, so it is half in further along (at 0.5 ^ (1 / FADE_CURVE) of fade_len)
const float FADE_CURVE = 1.5;
void vertex() {
	behind = dot(VERTEX - edge_at, edge_in) - start_len;
}
void fragment() {
	// COLOR already holds the texture (his render) times the vertex colour
	COLOR *= pow(clamp(behind / fade_len, 0.0, 1.0), FADE_CURVE);
}
"""
const START_OUT := 30.0    # the centre line starts this far outside her lips (a multiple of STEP): the cutaway's
                           # start edge is turned along her face, so one side of it lies further out

var opacity := 0.6
var start_len := 0.0       # the cutaway begins this far behind her lips, along her face (the plugin's Start)
var fade_len := 8.0        # and fades in over this length from there (the plugin's Fade setting)
var shown := 0.0
var _with_penis := false   # off while fading out: his render no longer matches the last shape
var _painter := Node2D.new()
var _path := PackedVector2Array()    # centre line samples, STEP apart, from her lips
var _norm := PackedVector2Array()    # unit normals, all on the same side
var _kappa := PackedFloat32Array()   # signed curvature of the centre line (> 0: bends towards +normal)
var _e0 := PackedFloat32Array()      # his outline at each sample: offsets from the centre line (e0 < e1)
var _e1 := PackedFloat32Array()
var _y0 := PackedFloat32Array()      # the strip taken from his render at each sample, penis-local y
var _y1 := PackedFloat32Array()
var _inside := 0.0                   # length of him inside her, along the centre line
var _drawn := 0.0                    # length of the strip taken from his render (a little past his tip)
var _x_lips := 0.0                   # penis-local x at her lips
var _tip_x := 0.0
var _len_scale := 1.0                # local units per penis-local unit, along him / across him
var _wid_scale := 1.0
var _side := 1.0                     # which side of the line his penis-local +y goes
var _penis_xf := Transform2D()       # penis-local -> his local space (UVs into his render)
var _bounds := Rect2()
var _half_px := 0.5                  # half a screen pixel in local units (_paint)
var _edge_at := Vector2.ZERO         # the cutaway's start edge at Start 0: through here, along her lips,
var _edge_in := Vector2.RIGHT        # and its unit normal into her
var _fade_mat := ShaderMaterial.new()
var _wall_col := Color(0.8, 0.45, 0.45)
var _lumen_col := Color(0.42, 0.1, 0.14)
var _glow_col := Color(0.85, 0.15, 0.2, 0.55)


func _init() -> void:
	super()
	mouseEnabled = false
	var sh := Shader.new()
	sh.code = FADE_SHADER
	_fade_mat.shader = sh
	_painter.material = _fade_mat
	_painter.draw.connect(_paint)
	add_child(_painter)


func _ready() -> void:
	RenderingServer.canvas_item_set_canvas_group_mode(get_canvas_item(),
		RenderingServer.CANVAS_GROUP_MODE_TRANSPARENT, 4.0, true, 4.0)


func _local_bounds() -> Rect2:
	return _bounds


## Called every tick; `want`: he is in her mouth and the x-ray is on.
func update_shape(want: bool) -> void:
	shown = clampf(shown + (FADE if want else -FADE), 0.0, 1.0)
	visible = shown > 0.0
	alpha = opacity * shown
	if not want:   # fading out: keeps the last shape, without him
		if _with_penis:
			_with_penis = false
			_painter.queue_redraw()
		return
	_with_penis = true
	var her: Her = g.her
	var him: Him = g.him
	var inv := flash_global_transform().affine_inverse()
	var pen: FlashDisplayObject = him.penis
	var pen_g := pen.flash_global_transform()
	var pv := inv * pen_g
	_penis_xf = him.flash_global_transform().affine_inverse() * pen_g
	var top_lip: Vector2 = her.localToGlobal(her.topLipA)
	var bottom_lip: Vector2 = her.head.jaw.localToGlobal(her.bottomLipA)
	var x_at_lips: float = pen.globalToLocal((top_lip + bottom_lip) * 0.5).x
	_tip_x = him.currentPenis._tip.x
	_len_scale = pv.x.length()
	_wid_scale = pv.y.length()
	var start := pv * Vector2(x_at_lips, 0.0)
	var dir := -pv.x.normalized()   # into her, towards his tip
	# The cutaway's start edge runs along her lips (parallel to her face, whatever the angle he goes in at), through
	# the point of the centre line between them; Start and Fade are measured from it, square to her face.
	var along := inv * bottom_lip - inv * top_lip
	_edge_at = start
	_edge_in = Vector2(-along.y, along.x).normalized()
	if _edge_in.dot(dir) < 0.0:
		_edge_in = -_edge_in
	_x_lips = x_at_lips + START_OUT / _len_scale   # the centre line begins START_OUT outside that point
	_inside = maxf(0.0, (_x_lips - _tip_x) * _len_scale)
	_drawn = _inside + PAST_TIP * _len_scale if _inside > 0.0 else 0.0
	var throat := _throat(her, inv)
	if throat.size() < 3:
		return
	# one bend: from her lips along him, down into her chest along her neck (from her neck towards her torso) through
	# the base of her throat; past its end it goes straight on
	var neck_at: Vector2 = inv * her.head.localToGlobal(Vector2(her.head.neck.x, her.head.neck.y))
	var axis: Vector2 = (inv * her.torso.localToGlobal(Vector2.ZERO) - neck_at).normalized()
	var q: Vector2 = throat[int(JOIN * (throat.size() - 1))]
	var e: Vector2 = q + axis * (q.distance_to(throat[-1]) + TAIL)
	var d := start.distance_to(e)
	var raw := PackedVector2Array([start - dir * START_OUT])   # straight on into the curve (its tangent there)
	for k in 33:
		raw.append(_cubic(start, start + dir * d * PULL_IN, e - axis * d * PULL_DOWN, e, k / 32.0))
	_resample(raw)
	_side = 1.0 if _norm[0].dot(pv.y) >= 0.0 else -1.0
	_outline(him)
	_colours()
	_bounds = Rect2(_path[0], Vector2.ZERO)
	for i in _path.size():
		_bounds = _bounds.expand(_at(i, _e0[i] - WALL - GLOW)).expand(_at(i, _e1[i] + WALL + GLOW))
	_bounds = _bounds.grow(4.0)
	_painter.queue_redraw()


## Her throat, from her jaw down to her chest: a part of the way (DEPTH) from the front of her neck to its back.
func _throat(her: Her, inv: Transform2D) -> PackedVector2Array:
	var neck = her.head.neck
	var nv := inv * (neck as FlashDisplayObject).flash_global_transform()
	var pts: Array = neck.renderedPoints
	var n: int = neck.frontEndPoint
	if pts.size() <= n + 2 or n < 4:
		return PackedVector2Array()
	var back := PackedVector2Array()
	for i in range(n, pts.size()):
		back.append(nv * (pts[i] as Vector2))
	var out := PackedVector2Array()
	for i in n:
		var p: Vector2 = nv * (pts[i] as Vector2)
		var nearest := back[0]
		for b in back:
			if p.distance_squared_to(b) < p.distance_squared_to(nearest):
				nearest = b
		out.append(p.lerp(nearest, DEPTH))
	return out


static func _cubic(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * (u * u * u) + b * (3.0 * u * u * t) + c * (3.0 * u * t * t) + d * (t * t * t)


## The centre line: the polyline sampled every STEP and smoothed, and past its end straight on as far as he
## reaches.
func _resample(raw: PackedVector2Array) -> void:
	var p := _even(raw)
	var q := p.duplicate()
	for _pass in SMOOTH:
		for i in range(2, p.size() - 1):
			q[i] = (p[i - 1] + p[i] * 2.0 + p[i + 1]) * 0.25
		p = q.duplicate()
	_path = _even(p)
	var end_dir := (_path[-1] - _path[-2]).normalized() if _path.size() > 1 else Vector2.DOWN
	while (_path.size() - 1) * STEP < _drawn + STEP:
		_path.append(_path[-1] + end_dir * STEP)
	var n := _path.size()
	_norm.resize(n)
	_kappa.resize(n)
	for i in n:
		var t := (_path[mini(i + 1, n - 1)] - _path[maxi(i - 1, 0)]).normalized()
		_norm[i] = Vector2(-t.y, t.x)
		_kappa[i] = 0.0
		if i > 0 and i < n - 1:
			_kappa[i] = (_path[i] - _path[i - 1]).normalized().angle_to((_path[i + 1] - _path[i]).normalized()) / STEP
	var k := _kappa.duplicate()
	for i in range(1, n - 1):
		_kappa[i] = (k[i - 1] + k[i] + k[i + 1]) / 3.0


static func _even(raw: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([raw[0]])
	var want := STEP
	var walked := 0.0
	for i in range(1, raw.size()):
		var a := raw[i - 1]
		var seg := a.distance_to(raw[i])
		while seg > 0.0 and walked + seg >= want:
			out.append(a.lerp(raw[i], (want - walked) / seg))
			want += STEP
		walked += seg
	return out


## A point `d` off the centre line at sample i (along its normal), pulled in on the inside of a bend so nothing
## folds over itself.
func _at(i: int, d: float) -> Vector2:
	var kp := _kappa[i]
	if d * kp > 0.0:
		d = signf(d) * minf(absf(d), FOLD / absf(kp))
	return _path[i] + _norm[i] * d


## His outline along the line (from the penis's width profile), closing to CLOSED past his tip.
func _outline(him: Him) -> void:
	var n := _path.size()
	for a in [_e0, _e1, _y0, _y1]:
		a.resize(n)
	var cp: Penis = him.currentPenis
	var tip_e := Vector2.ZERO
	for i in n:
		var s := i * STEP
		var x := _x_lips - minf(s, _drawn) / _len_scale
		var w: Array = cp._widthAt(maxf(x, _tip_x - PAST_TIP))
		_y0[i] = float(w[1]) - EDGE
		_y1[i] = float(w[1]) + float(w[0]) + EDGE
		var a := _side * float(w[1]) * _wid_scale
		var b := _side * (float(w[1]) + float(w[0])) * _wid_scale
		var e := Vector2(minf(a, b) - ROOM, maxf(a, b) + ROOM)
		if s <= _inside:
			tip_e = e
		else:   # closing past his tip
			e = tip_e.lerp(Vector2(-CLOSED, CLOSED), clampf((s - _inside) / 15.0, 0.0, 1.0))
		_e0[i] = e.x
		_e1[i] = e.y


func _colours() -> void:
	var pal: SkinPalette = g.characterControl.currentSkinPalette
	if pal == null:
		return
	var skin := Color.hex((pal.shade2.rgb << 8) | 0xFF)
	_wall_col = skin.lerp(Color(0.78, 0.36, 0.4), 0.45)
	_lumen_col = skin.lerp(Color(0.36, 0.06, 0.1), 0.75)


func _paint() -> void:
	if shown <= 0.0 or _path.size() < 2:
		return
	# MSAA does not reach into a canvas group: the strips' edges fade out over one screen pixel instead
	var screen := _painter.get_viewport().get_final_transform() * _painter.get_global_transform_with_canvas()
	_half_px = 0.5 / maxf(maxf(screen.x.length(), screen.y.length()), 0.01)
	_fade_mat.set_shader_parameter(&"edge_at", _edge_at)
	_fade_mat.set_shader_parameter(&"edge_in", _edge_in)
	_fade_mat.set_shader_parameter(&"start_len", start_len)
	_fade_mat.set_shader_parameter(&"fade_len", maxf(fade_len, 2.0 * _half_px))
	var ci := _painter.get_canvas_item()
	_glow(ci, _e0, -WALL, -WALL - GLOW)
	_glow(ci, _e1, WALL, WALL + GLOW)
	_band(ci, -WALL, WALL, _wall_col)
	_band(ci, 0.0, 0.0, _lumen_col)
	_penis(ci)


## A premultiplied colour (the fade behind the start edge is FADE_SHADER's).
static func _pm(col: Color) -> Color:
	return Color(col.r * col.a, col.g * col.a, col.b * col.a, col.a)


## A strip along the centre line from his outline's e0 + lo to e1 + hi, in one colour (premultiplied), its edges
## fading out across one screen pixel centred on them.
func _band(ci: RID, lo: float, hi: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var h := _half_px
	var c := _pm(col)
	for i in _path.size():
		var d0 := _e0[i] + lo
		var d1 := _e1[i] + hi
		var m0 := minf(d0 + h, (d0 + d1) * 0.5)   # a strip thinner than a pixel: no solid middle
		var m1 := maxf(d1 - h, (d0 + d1) * 0.5)
		pts.append_array([_at(i, d0 - h), _at(i, m0), _at(i, m1), _at(i, d1 + h)])
		cols.append_array([Color(0, 0, 0, 0), c, c, Color(0, 0, 0, 0)])
		if i > 0:
			var b := (i - 1) * 4
			for k in 3:   # the fade in, the solid middle, the fade out
				idx.append_array([b + k, b + k + 1, b + k + 4, b + k + 1, b + k + 5, b + k + 4])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)


## A strip from edge + inner (glow colour) to edge + outer (transparent). It starts half a pixel under the wall,
## so the wall's faded edge has the glow under it (no light seam between the two).
func _glow(ci: RID, edge: PackedFloat32Array, inner: float, outer: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var gc := _glow_col
	var under := -signf(outer - inner) * _half_px
	for i in _path.size():
		pts.append(_at(i, edge[i] + inner + under))
		pts.append(_at(i, edge[i] + outer))
		cols.append(_pm(gc))
		cols.append(Color(0, 0, 0, 0))
		if i > 0:
			var b := (i - 1) * 2
			idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)


## His penis from his render, bent along the centre line: each sample takes the penis-local cross-section at the
## same distance from her lips.
func _penis(ci: RID) -> void:
	var grp := FlashGroupProxy.of(g.him)
	if grp == null or _drawn <= 0.0 or not _with_penis:
		return
	var rect := grp.render_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var last := mini(int(ceil(_drawn / STEP)), _path.size() - 1)
	var h := _half_px / _wid_scale   # half a screen pixel, penis-local
	for i in last + 1:
		var x := _x_lips - minf(i * STEP, _drawn) / _len_scale
		# the strip's sides fade out across a pixel, like the bands
		var ys := [_y0[i] - h, _y0[i] + h, _y1[i] - h, _y1[i] + h]
		for j in 4:
			pts.append(_at(i, _side * ys[j] * _wid_scale))
			uvs.append((_penis_xf * Vector2(x, ys[j]) - rect.position) / rect.size)
			cols.append(Color.WHITE if j == 1 or j == 2 else Color(0, 0, 0, 0))
		if i > 0:
			var b := (i - 1) * 4
			for k in 3:
				idx.append_array([b + k, b + k + 1, b + k + 4, b + k + 1, b + k + 5, b + k + 4])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(),
		grp.render_texture().get_rid())
