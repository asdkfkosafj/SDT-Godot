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
##
## The stomach (stomach_part.gd) is a display object of its own, above her near arm; this one gives it her throat's
## line every tick (update_stomach). While both show, its pipe takes over from this one a little past his tip, along
## this one's centre line (this one fades out there as the pipe fades in), so the pipe goes on over her arm. Its part
## low on her neck is then drawn by a second painter (_lower) in the stomach's layer, over her arm too (her
## shoulder would cut him off); both draw the same row of the centre line there, so they meet without a seam. His
## penis there is drawn by a third painter (_lower_top), above what flows down the pipe (the stomach part's _flow).

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
const CLOSE_LEN := 15.0    # past his tip her throat closes over this length
const HAND_FADE := 6       # samples over which the stomach's pipe takes over, past that (its PIPE_TOP)
const SPLIT_AT := 0.7      # the lower painter takes over this far down her neck (0 jaw .. 1 chest): above her
                           # shoulder, below her earrings
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
## Her mouth: behind her lips the inside widens into a pocket, most towards her jaw, back to where her throat starts.
## What is in her mouth (the game's cumInMouth) lies in it, its surface level on the screen, sloshing as the stomach's.
const MOUTH_DEEP := 14.0   # how far the pocket goes out towards her jaw
const MOUTH_UP := 2.0      # and to the other side
const LIPS_MEET := Vector2(148, 61)   # her mouth closed: the floor's inside starts here (her jaw's space: where her
                                      # lips meet, between the game's bottomLipA and bottomLipB)
const MOUTH_SMOOTH := 8   # smoothing passes where her mouth hands over to her throat round him
const MOUTH_GIVE := 4     # where he pushes her mouth's wall out, it bulges round that over this many samples each way
const MOUTH_ROOF_TURN := 1.05   # her mouth closed: the roof meets her throat where the centre line has turned this far
const MOUTH_ROUND := 0.8  # her mouth closed: the roof goes straight back from her upper lip and turns down into her
                           # throat in a rounded corner, the more square the nearer this is to 1
const MOUTH_TURN := 0.6    # her mouth ends where the centre line has turned this far (radians) down into her throat
const MOUTH_BACK := 6      # samples before her throat over which the pool closes (to the pocket's floor)
const REJOIN := 10        # past what is drawn of him, the centre line goes over to her throat at rest over at least
                          # this many samples (along him only where he is: her throat stays in its place past his tip)
const REJOIN_BEND := 50.0 # and over as many more as it takes for the bend that adds to be no tighter than this radius
const MOUTH_FULL := 0.8    # her mouth at the game's most (maxCumInMouth) fills this share of the room around him
const MOUTH_OVER := 0.35   # the pool shows through him this much (it lies round him: in front of him too)
const MOUTH_EASE := 0.3    # how much of a change in what is in her mouth shows each tick
const FILL_DARK := 0.82    # the bottom of the pool, times its colour (darker with depth)
const SURFACE := 2.0       # the darker line along its surface, its width
const SLOSH_PUSH := 0.12   # the surface's tilt (radians) per scene unit per tick per tick her head speeds up sideways
const SLOSH_SMOOTH := 0.2  # how much of each tick's speeding up counts at once
const SLOSH_K := 0.06      # how hard it springs back level, per tick
const SLOSH_DAMP := 0.45   # and how fast its swing dies down
const SLOSH_MAX := 0.45    # the most it tilts
const SPLASH := 0.03       # what comes into her mouth sets it swinging (tilt speed)

var opacity := 0.6
var start_len := 0.0       # the cutaway begins this far behind her lips, along her face (the plugin's Start)
var fade_len := 8.0        # and fades in over this length from there (the plugin's Fade setting)
var shown := 0.0
var stomach_shown := 0.0             # the stomach part's pipe's fade, last tick (update_stomach)
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
var _curve_n := 0                    # samples of the centre line's curve (past it, it goes straight on)
var _hand := 0.0                     # the sample where the stomach's pipe has taken over
var _mouth_end := 0                  # the sample where her mouth's roof and floor have come into her throat
var _w := PackedFloat32Array()       # how much of this part shows at each sample (1, but where the pipe takes over)
var _lower := Node2D.new()           # draws the part past _split, in the stomach's layer (attach_lower)
var _lower_top := Node2D.new()       # and his penis there, over what flows down the pipe
var _split := -1                     # the sample low on her neck where the lower painter takes over (-1: none)
var _half_px := 0.5                  # half a screen pixel in local units (_paint)
var _edge_at := Vector2.ZERO         # the cutaway's start edge at Start 0: through here, along her lips,
var _edge_in := Vector2.RIGHT        # and its unit normal into her
var _fade_mat := ShaderMaterial.new()
var _wall_col := Color(0.8, 0.45, 0.45)
var _lumen_col := Color(0.42, 0.1, 0.14)
var _glow_col := Color(0.85, 0.15, 0.2, 0.55)
var mouth_only := false              # it shows her mouth and throat without him (the plugin's Keep mouth)
var _p0 := PackedFloat32Array()      # his outline at each sample, without the room around him (0 past his tip)
var _p1 := PackedFloat32Array()
var _m0 := 0                         # her mouth's pocket: from this sample (her lips)
var _m1 := 0                         # to this one (where her throat starts)
var _to_jaw := true                  # her jaw (the pocket's floor) is on the e1 side
var _mouth_amt := 0.0                # what is in her mouth, as it shows (eased)
var _pool_parts: Array = []          # the pool's bands: [polygons, from, to (depth along _pool_gd), colour, colour]
var _pool_gd := Vector2.DOWN         # down for the pool (local): square to its surface
var _back_dir := Vector2.LEFT        # back into her mouth at its end (local), and how far its end is along that
var _back_at := 0.0
var _tilt := 0.0                     # the surface's tilt from level (radians) and how fast it changes
var _tilt_v := 0.0
var _last_pos := Vector2.ZERO        # where her mouth was last tick (in the scene), and how fast it went
var _last_vel := Vector2.ZERO
var _acc := Vector2.ZERO             # how fast it speeds up, smoothed
var _moving := false                 # _last_pos / _last_vel hold something
var _last_cim := 0                   # cumInMouth last tick


func _init() -> void:
	super()
	mouseEnabled = false
	var sh := Shader.new()
	sh.code = FADE_SHADER
	_fade_mat.shader = sh
	_painter.material = _fade_mat
	_painter.draw.connect(_paint)
	add_child(_painter)
	_lower.material = _fade_mat
	_lower.draw.connect(_paint_lower)
	_lower_top.material = _fade_mat
	_lower_top.draw.connect(_paint_lower_top)


func _ready() -> void:
	RenderingServer.canvas_item_set_canvas_group_mode(get_canvas_item(),
		RenderingServer.CANVAS_GROUP_MODE_TRANSPARENT, 4.0, true, 4.0)


func _local_bounds() -> Rect2:
	return _bounds


## The lower painters go into the stomach part, on top of its own drawing, what flows down its pipe between them.
## Their local space is this one's: both are her space (the plugin keeps the stomach part there).
func attach_lower(stomach: FlashDisplayObject) -> void:
	stomach.add_child(_lower)
	stomach.move_child(stomach._flow, -1)
	stomach.add_child(_lower_top)


## The lower painter takes the part low on her neck and on while it can show (the stomach part shows).
func _splitting() -> bool:
	return _split > 0 and _lower.is_inside_tree() and _lower.is_visible_in_tree()


## Called every tick (after update_shape): updates the stomach part (stomach_part.gd), with her throat's line in its
## local space. `want`: the stomach should show.
func update_stomach(stomach: FlashDisplayObject, want: bool, want_pipe: bool) -> void:
	var her: Her = g.her
	var inv := stomach.flash_global_transform().affine_inverse()
	var throat := _throat(her, inv)
	if throat.size() < 3:
		return
	_colours()
	stomach.wall_col = _wall_col
	stomach.lumen_col = _lumen_col
	stomach.glow_col = _glow_col
	var line: PackedVector2Array   # what the pipe follows before it bends down into the stomach
	var bend: Vector2              # and the way it goes on from there
	if shown > 0.0 and _path.size() >= 2:   # this part's centre line, as far as its curve or the hand-over
		var last := clampi(maxi(_curve_n, int(ceil(_hand)) + 1), 2, _path.size())
		line = (inv * flash_global_transform()) * _path.slice(0, last)
		bend = (line[-1] - line[-2]).normalized()
	else:   # her throat, and on along its tail
		var axis := _neck_axis(her, inv)
		var join := int(JOIN * (throat.size() - 1))
		line = throat.slice(0, join + 1)
		line.append(_tail(throat, join, axis))
		bend = axis
	# what flows down shows past his tip, but not over what of him the upper painter draws (under that layer)
	var flow_from := 0.0
	if shown > 0.0:
		flow_from = maxf(_inside, minf(_split * STEP, _drawn)) if _splitting() else maxf(_inside, _drawn)
	# (while this part fades, the pipe shows under it as much as it does not: not through her mouth)
	stomach.update(want, want_pipe, her, line, bend, _hand, shown, flow_from,
		float(_mouth_end) if shown > 0.0 else 0.0)
	stomach_shown = stomach.shown * stomach.pipe_shown   # (its pipe takes over from this part only while it shows)


## Where the centre line's curve ends: past the base of her throat, on along her neck from its point `join`.
func _tail(throat: PackedVector2Array, join: int, axis: Vector2) -> Vector2:
	return throat[join] + axis * (throat[join].distance_to(throat[-1]) + TAIL)


## Down her neck, from where it joins her head towards her torso (local).
func _neck_axis(her: Her, inv: Transform2D) -> Vector2:
	var neck_at: Vector2 = inv * her.head.localToGlobal(Vector2(her.head.neck.x, her.head.neck.y))
	return (inv * her.torso.localToGlobal(Vector2.ZERO) - neck_at).normalized()


## Called every tick; `want`: he is in her mouth and the x-ray is on; `keep_mouth`: while he is not, it shows her
## mouth and throat without him (cum in her mouth, the plugin's Keep mouth).
func update_shape(want: bool, keep_mouth := false) -> void:
	var was := shown
	# he leaves her mouth (or comes in) with his tip at her lips: the shape hardly changes, it goes over at once
	var alone := keep_mouth and not want
	if alone or want:   # (fading out: as it was)
		mouth_only = alone
	shown = clampf(shown + (FADE if want or alone else -FADE), 0.0, 1.0)
	visible = shown > 0.0
	# its opacity (and fade) on the whole cutaway, not on each layer in it (with `alpha`, modulate, which every
	# child takes, each layer would show the ones under it through it): the plugin's group shader
	alpha = 1.0
	if material is ShaderMaterial:
		material.set_shader_parameter(&"opacity", opacity * shown)
	for lp in [_lower, _lower_top]:   # in the stomach part's group (its opacity): only this part's fade
		lp.self_modulate = Color(1, 1, 1, shown)
	var her: Her = g.her
	if not want and not alone:   # fading out: keeps the last shape, without him
		_with_penis = false
		if was > 0.0:
			_slosh(her, false)
			_pool()
			_painter.queue_redraw()
			_lower.queue_redraw()
			_lower_top.queue_redraw()
		return
	var him: Him = g.him
	var inv := flash_global_transform().affine_inverse()
	var throat := _throat(her, inv)
	if throat.size() < 3:
		return
	var top_lip: Vector2 = inv * her.localToGlobal(her.topLipA)
	var bottom_lip: Vector2 = inv * her.head.jaw.localToGlobal(her.bottomLipA)
	var jaw_at: Vector2 = inv * her.head.jaw.localToGlobal(Vector2.ZERO)
	var lips_meet: Vector2 = inv * her.head.jaw.localToGlobal(LIPS_MEET)
	var lips_mid := (top_lip + bottom_lip) * 0.5
	# The cutaway's start edge runs along her lips (parallel to her face, whatever the angle he goes in at), through
	# the point of the centre line between them; Start and Fade are measured from it, square to her face.
	var along := bottom_lip - top_lip
	_edge_in = Vector2(-along.y, along.x).normalized()
	if _edge_in.dot(throat[0] - lips_mid) < 0.0:   # into her
		_edge_in = -_edge_in
	var axis := _neck_axis(her, inv)
	var tail := _tail(throat, int(JOIN * (throat.size() - 1)), axis)
	# her mouth at rest (as closed, without him): its walls, which stay where he does not push them out
	_with_penis = false
	_inside = 0.0
	_drawn = 0.0
	_hand = CLOSE_LEN / STEP + HAND_FADE
	_line(lips_mid, _edge_in, tail, axis)
	_outline(him)
	_pocket(top_lip, bottom_lip, jaw_at)
	_rest_mouth(top_lip, lips_meet)
	var start := lips_mid
	var pv := Transform2D()
	if want:
		var rest := _rest_walls()
		var rest_path := _path.duplicate()
		_with_penis = true
		var pen: FlashDisplayObject = him.penis
		var pen_g := pen.flash_global_transform()
		pv = inv * pen_g
		_penis_xf = him.flash_global_transform().affine_inverse() * pen_g
		var x_at_lips: float = pen.globalToLocal(her.localToGlobal(her.topLipA).lerp(
			her.head.jaw.localToGlobal(her.bottomLipA), 0.5)).x
		_tip_x = him.currentPenis._tip.x
		_len_scale = pv.x.length()
		_wid_scale = pv.y.length()
		start = pv * Vector2(x_at_lips, 0.0)
		_x_lips = x_at_lips + START_OUT / _len_scale   # the centre line begins START_OUT outside that point
		_inside = maxf(0.0, (_x_lips - _tip_x) * _len_scale)
		_drawn = _inside + PAST_TIP * _len_scale if _inside > 0.0 else 0.0
		_hand = (_inside + CLOSE_LEN) / STEP + HAND_FADE
		# along him, towards his tip; past what is drawn of him, her throat at rest
		_line(start, -pv.x.normalized(), tail, axis, rest_path, _drawn / STEP + 1.0)
		_side = 1.0 if _norm[0].dot(pv.y) >= 0.0 else -1.0
		_outline(him)
		_pocket(top_lip, bottom_lip, jaw_at)
		_fit_mouth(rest)
	_edge_at = start
	# the stomach's pipe (a closed tube) takes over only past her mouth: not through it, his tip near her lips
	_hand = maxf(_hand, _mouth_end + HAND_FADE)
	_slosh(her, true)
	_pool()
	_w.resize(_path.size())
	for i in _path.size():
		_w[i] = 1.0 - stomach_shown * smoothstep(_hand - HAND_FADE, _hand, i)
	_split = -1
	var base: Vector2 = throat[int(SPLIT_AT * (throat.size() - 1))]
	for i in _path.size():
		if (_path[i] - base).dot(axis) >= 0.0:
			_split = i
			break
	_colours()
	_bounds = Rect2(_path[0], Vector2.ZERO)
	for i in _path.size():
		_bounds = _bounds.expand(_at(i, _e0[i] - WALL - GLOW)).expand(_at(i, _e1[i] + WALL + GLOW))
	_bounds = _bounds.grow(4.0)
	_painter.queue_redraw()
	_lower.queue_redraw()
	_lower_top.queue_redraw()


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


## The centre line: the polyline sampled every STEP and smoothed (from sample `from` going over to the line `rest`:
## REJOIN), and past its end straight on as far as he reaches (or the stomach's pipe takes over,
## while it shows).
func _resample(raw: PackedVector2Array, rest := PackedVector2Array(), from := INF) -> void:
	var p := _even(raw)
	var q := p.duplicate()
	for _pass in SMOOTH:
		for i in range(2, p.size() - 1):
			q[i] = (p[i - 1] + p[i] * 2.0 + p[i + 1]) * 0.25
		p = q.duplicate()
	if rest.size() >= 2 and from < p.size():
		var n := maxi(p.size(), rest.size())
		var p_dir := (p[-1] - p[-2]).normalized()
		var r_dir := (rest[-1] - rest[-2]).normalized()
		var a := PackedVector2Array()
		var b := PackedVector2Array()
		a.resize(n)
		b.resize(n)
		var apart := 0.0   # how far apart the two are, at most, from there on
		for i in n:
			a[i] = p[i] if i < p.size() else p[-1] + p_dir * STEP * (i - p.size() + 1)
			b[i] = rest[i] if i < rest.size() else rest[-1] + r_dir * STEP * (i - rest.size() + 1)
			if i >= from:
				apart = maxf(apart, a[i].distance_to(b[i]))
		# (a smoothstep over L bends at most 6 * apart / L^2)
		var span := maxf(REJOIN, sqrt(6.0 * apart * REJOIN_BEND) / STEP)
		q.resize(n)
		for i in n:
			q[i] = a[i].lerp(b[i], smoothstep(from, from + span, i))
		p = q
	_path = _even(p)
	_curve_n = _path.size()
	var end_dir := (_path[-1] - _path[-2]).normalized() if _path.size() > 1 else Vector2.DOWN
	var reach := _drawn if stomach_shown <= 0.0 else maxf(_drawn, _hand * STEP)
	while (_path.size() - 1) * STEP < reach + STEP:
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
	_p0.resize(n)
	_p1.resize(n)
	if not _with_penis:   # her mouth alone: closed all along
		_e0.fill(-CLOSED)
		_e1.fill(CLOSED)
		_p0.fill(0.0)
		_p1.fill(0.0)
		return
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
		_p0[i] = minf(a, b) if s <= _inside else 0.0
		_p1[i] = maxf(a, b) if s <= _inside else 0.0
		if s <= _inside:
			tip_e = e
		else:   # closing past his tip
			e = tip_e.lerp(Vector2(-CLOSED, CLOSED), clampf((s - _inside) / CLOSE_LEN, 0.0, 1.0))
		_e0[i] = e.x
		_e1[i] = e.y


## The centre line: from `start` (between her lips) along `dir` (into her), one bend down into her chest along her
## neck (`axis`) through `tail` (past the base of her throat); past its end it goes straight on. From sample `from`
## on it goes over to the line `rest` (see _resample).
func _line(start: Vector2, dir: Vector2, tail: Vector2, axis: Vector2, rest := PackedVector2Array(),
		from := INF) -> void:
	var d := start.distance_to(tail)
	var raw := PackedVector2Array([start - dir * START_OUT])   # straight on into the curve (its tangent there)
	for k in 33:
		raw.append(_cubic(start, start + dir * d * PULL_IN, tail - axis * d * PULL_DOWN, tail, k / 32.0))
	_resample(raw, rest, from)


## Her mouth along the centre line: from her lips (`top_lip`, `bottom_lip`: their outer points; sample _m0) back to
## where the line turns down into her throat (MOUTH_TURN), or the pivot of her jaw (`back`, below her ear) (_m1), and
## on to where her roof and floor have come into her throat (MOUTH_ROOF_TURN: _mouth_end); which side her jaw is.
func _pocket(top_lip: Vector2, bottom_lip: Vector2, back: Vector2) -> void:
	var n := mini(_path.size(), _curve_n)
	_m0 = int(START_OUT / STEP)
	_m1 = _m0
	var dir := (_path[mini(_m0 + 1, n - 1)] - _path[_m0]).normalized()
	var reach := (back - _path[_m0]).dot(dir)
	for i in range(_m0 + 1, n):
		_m1 = i
		if (_path[i] - _path[i - 1]).normalized().dot(dir) < cos(MOUTH_TURN) or (_path[i] - _path[_m0]).dot(dir) >= reach:
			break
	_m1 = mini(maxi(_m1, _m0 + 2 * MOUTH_BACK + 2), _path.size() - 1)
	_to_jaw = (bottom_lip - top_lip).dot(_norm[_m0]) >= 0.0
	_mouth_end = _m1
	while _mouth_end < n - 2 and (_path[_mouth_end + 1] - _path[_mouth_end]).normalized().dot(dir) > cos(MOUTH_ROOF_TURN):
		_mouth_end += 1


## Her mouth at rest (on the line in from between her lips, closed round it): a round pocket (see MOUTH_DEEP),
## deepest in the middle, and out from that, its roof and floor each to an arc from her lips into her throat: the
## roof from her upper lip (`top_lip`: the wall's outer edge there), the floor from where her lips meet (`lips_meet`:
## its inside's edge there).
func _rest_mouth(top_lip: Vector2, lips_meet: Vector2) -> void:
	for i in range(_m0, _m1 + 1):
		var b := pow(sin(PI * float(i - _m0) / float(_m1 - _m0)), 0.6)   # round, deepest in the middle
		_e0[i] -= (MOUTH_UP if _to_jaw else MOUTH_DEEP) * b
		_e1[i] += (MOUTH_DEEP if _to_jaw else MOUTH_UP) * b
	_lip_arc(top_lip, -1.0 if _to_jaw else 1.0, _mouth_end, WALL)
	_lip_arc(lips_meet, 1.0 if _to_jaw else -1.0, _mouth_end, 0.0)


## Her mouth at rest as two lines (local): [its roof's inside edge, its floor's], from outside her lips down her throat.
func _rest_walls() -> Array:
	var roof := PackedVector2Array()
	var flr := PackedVector2Array()
	for i in _path.size():
		roof.append(_at(i, _e0[i] if _to_jaw else _e1[i]))
		flr.append(_at(i, _e1[i] if _to_jaw else _e0[i]))
	return [roof, flr]


## With him in her mouth: its walls stay where they are at rest (`rest`, _rest_walls), and only where the room round
## him reaches past them do they go out, bulging smoothly round where he pushes (MOUTH_GIVE); into her throat they
## follow him, as before.
func _fit_mouth(rest: Array) -> void:
	var n := mini(_mouth_end + 1, _path.size())
	var room0 := _e0.duplicate()   # the room round him
	var room1 := _e1.duplicate()
	var roof_side := -1.0 if _to_jaw else 1.0
	for wall in [[rest[0], roof_side], [rest[1], -roof_side]]:
		var side: float = wall[1]
		var at_rest := PackedFloat32Array()
		var push := PackedFloat32Array()   # how far past the wall at rest the room round him reaches (out from it)
		at_rest.resize(n)
		push.resize(n)
		for i in n:
			at_rest[i] = _cross(i, wall[0], side, REJOIN)
		_fill_gaps(at_rest)
		for i in n:
			var tube: float = _e0[i] if side < 0.0 else _e1[i]
			if is_nan(at_rest[i]):   # (it meets the wall nowhere at all)
				at_rest[i] = tube
			push[i] = maxf(0.0, (tube - at_rest[i]) * side)
		for i in n:
			var p := 0.0   # the most any push near reaches here, less the further it is (it still clears him)
			for j in range(maxi(0, i - MOUTH_GIVE), mini(n, i + MOUTH_GIVE + 1)):
				p = maxf(p, push[j] * (0.5 + 0.5 * cos(PI * absf(i - j) / float(MOUTH_GIVE + 1))))
			var w := 1.0 - smoothstep(_mouth_end - MOUTH_BACK, _mouth_end, i)   # (handing over to her throat)
			var tube: float = _e0[i] if side < 0.0 else _e1[i]
			var e := lerpf(tube, at_rest[i] + p * side, w)
			if side < 0.0:   # (packed arrays are copied when assigned: each written by its own name)
				_e0[i] = e
			else:
				_e1[i] = e
	# where her mouth hands over to her throat round him, the two need not meet in line (her mouth at rest is on
	# another centre line): smoothed across, never in closer to him than the room round him
	var i0 := maxi(1, _mouth_end - 2 * MOUTH_BACK)
	var i1 := mini(_path.size() - 2, _mouth_end + 2 * MOUTH_BACK)
	var last := mini(i1, int(_inside / STEP))   # (where he is)
	for _pass in MOUTH_SMOOTH:
		var a0 := _e0.duplicate()
		var a1 := _e1.duplicate()
		for i in range(i0, i1 + 1):
			_e0[i] = (a0[i - 1] + a0[i] * 2.0 + a0[i + 1]) * 0.25
			_e1[i] = (a1[i - 1] + a1[i] * 2.0 + a1[i + 1]) * 0.25
			if i <= last:
				_e0[i] = minf(_e0[i], room0[i])
				_e1[i] = maxf(_e1[i], room1[i])


## NAN values filled in from the nearest values each side (straight between them; at an end, the nearest one).
static func _fill_gaps(v: PackedFloat32Array) -> void:
	var last := -1
	for i in v.size():
		if is_nan(v[i]):
			continue
		if last < 0:
			for j in i:
				v[j] = v[i]
		else:
			for j in range(last + 1, i):
				v[j] = lerpf(v[last], v[i], float(j - last) / float(i - last))
		last = i
	if last >= 0:
		for j in range(last + 1, v.size()):
			v[j] = v[last]


## Where the normal at sample i meets the line `poly` on `side` of the centre line, nearest it: its offset (NAN:
## nowhere). `near`: only along its points that many each side of i (a line sampled as the centre line).
func _cross(i: int, poly: PackedVector2Array, side: float, near := -1) -> float:
	var p := _path[i]
	var nrm := _norm[i]
	var best := NAN
	var j0 := 0 if near < 0 else maxi(0, i - near)   # (`near` >= 0: its points i - near .. i + near only)
	var j1 := poly.size() - 1 if near < 0 else mini(poly.size() - 1, i + near)
	for j in range(j0, j1):
		var a := (poly[j] - p).cross(nrm)
		var b := (poly[j + 1] - p).cross(nrm)
		if (a <= 0.0) == (b <= 0.0):
			continue
		var off := (poly[j].lerp(poly[j + 1], a / (a - b)) - p).dot(nrm)   # (the crossing is on the normal)
		if off * side > 0.0 and (is_nan(best) or absf(off) < absf(best)):
			best = off
	return best


## Her mouth at rest: the inside on `side` of the centre line (the sign of its offsets there) goes out to one smooth
## arc from `lip_at` (`inset` in from it), straight back from it, to her throat's wall on that side at sample k, along
## it there; each sample's edge is where its normal meets the arc (outside her lips too, where the cutaway fades in:
## the arc goes on out from her lip).
func _lip_arc(lip_at: Vector2, side: float, k: int, inset: float) -> void:
	var q := _at(k, _e0[k] if side < 0.0 else _e1[k])
	var tk := (_path[mini(k + 1, _path.size() - 1)] - _path[k - 1]).normalized()
	var lip := lip_at - _norm[_m0] * side * inset
	# a rounded corner: towards where the line straight back from her lip meets the line of her throat's wall
	var c = Geometry2D.line_intersects_line(lip, _edge_in, q, tk)
	if c == null or (c - lip).dot(_edge_in) <= 0.0 or (q - c).dot(tk) <= 0.0:
		c = (lip + q) * 0.5   # (no such corner ahead: a plain curve)
	var arc := PackedVector2Array([lip - _edge_in * (START_OUT + STEP)])
	for j in 33:
		arc.append(_cubic(lip, lip.lerp(c, MOUTH_ROUND), q.lerp(c, MOUTH_ROUND), q, j / 32.0))
	for i in range(0, k):
		var off := _cross(i, arc, side)
		if is_nan(off):
			continue
		if side < 0.0:   # out from what is there only (packed arrays are copied when assigned: each by its own name)
			_e0[i] = minf(_e0[i], off)
		else:
			_e1[i] = maxf(_e1[i], off)


## The pool's surface tilt: a damped spring pulled towards how fast her mouth speeds up sideways (as the stomach's).
func _slosh(her: Her, live: bool) -> void:
	var pos := her.transform * (transform * _edge_at)   # in the scene, whatever the zoom
	if live:
		var vel := pos - _last_pos if _moving else Vector2.ZERO
		var acc := vel - _last_vel if _moving else Vector2.ZERO
		_acc += (acc - _acc) * SLOSH_SMOOTH
		_last_pos = pos
		_last_vel = vel
	_moving = live
	if her.cumInMouth > _last_cim:
		_tilt_v += SPLASH * (1.0 if randf() < 0.5 else -1.0)
	_last_cim = her.cumInMouth
	var target := clampf(_acc.x * SLOSH_PUSH, -SLOSH_MAX, SLOSH_MAX) if live else 0.0
	_tilt_v += (target - _tilt) * SLOSH_K - _tilt_v * SLOSH_DAMP
	_tilt = clampf(_tilt + _tilt_v, -SLOSH_MAX, SLOSH_MAX)
	_pool_gd = flash_global_transform().affine_inverse().basis_xform(Vector2.DOWN.rotated(_tilt)).normalized()


## The pool in her mouth's pocket: its surface where the room in the pocket below it (round him) holds what is in her
## mouth; drawn as bands across it (_pool_parts), each with its colour changing evenly with depth.
func _pool() -> void:
	_pool_parts.clear()
	var her: Her = g.her
	_mouth_amt += (float(her.cumInMouth) - _mouth_amt) * MOUTH_EASE
	if _mouth_amt < 0.2 or _m1 <= _m0 or _m1 >= _path.size():
		return
	# the pocket, half a wall into its wall (the wall is drawn over its edge); towards her throat its roof comes down
	# to its floor (her tongue holds it back), so the pool ends there in a point, not straight across her throat
	var cav := PackedVector2Array()
	var floor_e := _e1 if _to_jaw else _e0
	var roof_e := _e0 if _to_jaw else _e1
	var out := WALL * 0.5 * (1.0 if _to_jaw else -1.0)   # out of the floor's side
	for i in range(_m0, _m1 + 1):
		cav.append(_at(i, floor_e[i] + out))
	for i in range(_m1, _m0 - 1, -1):
		cav.append(_at(i, lerpf(roof_e[i] - out, floor_e[i] + out, smoothstep(_m1 - MOUTH_BACK, _m1, i))))
	var pen := PackedVector2Array()
	if _with_penis:
		var last := mini(_m1, int(_inside / STEP))
		for i in range(_m0, last + 1):
			pen.append(_at(i, _p0[i]))
		for i in range(last, _m0 - 1, -1):
			pen.append(_at(i, _p1[i]))
		if pen.size() < 4:
			pen.clear()
	var gd := _pool_gd
	var top := INF
	var bottom := -INF
	for p in cav:
		top = minf(top, p.dot(gd))
		bottom = maxf(bottom, p.dot(gd))
	var want := _room(cav, pen, gd, top - 1.0, bottom + 1.0) * MOUTH_FULL \
		* clampf(_mouth_amt / float(her.maxCumInMouth), 0.0, 1.0)
	var a := top
	var b := bottom
	for _i in 14:
		var m := (a + b) * 0.5
		if _room(cav, pen, gd, m, bottom + 1.0) > want:
			a = m
		else:
			b = m
	var level := (a + b) * 0.5
	var fill := Color.hex((g.cumRGB << 8) | 0xFF)
	var c0 := _pm(fill)
	var c1 := _pm(Color(fill.r * FILL_DARK, fill.g * FILL_DARK, fill.b * FILL_DARK, fill.a))
	var sc := _pm(fill.darkened(0.15))
	var h := _half_px
	# it fades out over the pocket's last MOUTH_BACK samples: each band in two, before that and over it (so its
	# colour changes evenly inside each piece, as the triangles draw it)
	_back_dir = (_path[_m1] - _path[_m1 - 1]).normalized()
	_back_at = _path[_m1].dot(_back_dir)
	var fade_from := _back_at - MOUTH_BACK * STEP
	var zones := [_slab(_back_dir, fade_from - 1000.0, fade_from, cav[0]),
		_slab(_back_dir, fade_from, _back_at + 1.0, cav[0])]
	for band in [[level - h, level + h, Color(0, 0, 0, 0), sc], [level + h, level + SURFACE, sc, sc],
			[level + SURFACE, level + 2.0 * SURFACE, sc, c0], [level + 2.0 * SURFACE, bottom + 1.0, c0, c1]]:
		if band[1] <= band[0]:
			continue
		var polys := []
		for piece in Geometry2D.intersect_polygons(cav, _slab(gd, band[0], band[1], cav[0])):
			for zone in zones:
				polys.append_array(Geometry2D.intersect_polygons(piece, zone))
		if polys.is_empty():
			continue
		var over := []   # its part over him
		if not pen.is_empty():
			for poly in polys:
				over.append_array(Geometry2D.intersect_polygons(poly, pen))
		_pool_parts.append([polys, band[0], band[1], band[2], band[3], over])


## The room in the pocket `cav` between depths d0 and d1 along gd, not taken by him (`pen`).
static func _room(cav: PackedVector2Array, pen: PackedVector2Array, gd: Vector2, d0: float, d1: float) -> float:
	var area := 0.0
	for piece in Geometry2D.intersect_polygons(cav, _slab(gd, d0, d1, cav[0])):
		area += absf(_area(piece))
		if not pen.is_empty():
			for q in Geometry2D.intersect_polygons(piece, pen):
				area -= absf(_area(q))
	return maxf(area, 0.0)


## A long quad across gd, between depths d0 and d1 along it (`at`: any point near where it is needed).
static func _slab(gd: Vector2, d0: float, d1: float, at: Vector2) -> PackedVector2Array:
	var t := Vector2(-gd.y, gd.x) * 1000.0
	var base := at - gd * at.dot(gd)
	return PackedVector2Array([base + gd * d0 - t, base + gd * d0 + t, base + gd * d1 + t, base + gd * d1 - t])


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


## The pool's bands (`over`: their parts over him, at MOUTH_OVER), each colour changing evenly with depth.
func _paint_pool_bands(ci: RID, over: bool) -> void:
	for part in _pool_parts:
		var d0: float = part[1]
		var d1: float = part[2]
		for poly: PackedVector2Array in (part[5] if over else part[0]):   # (no holes: a band across a pocket has none)
			var tri := Geometry2D.triangulate_polygon(poly)
			if tri.is_empty():
				continue
			var cols := PackedColorArray()
			for p in poly:
				var c := (part[3] as Color).lerp(part[4], clampf((p.dot(_pool_gd) - d0) / (d1 - d0), 0.0, 1.0))
				c *= clampf((_back_at - p.dot(_back_dir)) / (MOUTH_BACK * STEP), 0.0, 1.0)   # fading out at the back
				cols.append(c * MOUTH_OVER if over else c)
			RenderingServer.canvas_item_add_triangle_array(ci, tri, poly, cols)


## The pool, and her mouth's wall drawn again over its edge.
func _paint_pool(ci: RID) -> void:
	if _pool_parts.is_empty():
		return
	_paint_pool_bands(ci, false)
	var h := _half_px
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for i in range(_m0, _m1 + 1):
			var e: float = _e0[i] if side < 0.0 else _e1[i]
			var c := _pm(_wall_col) * _w[i]
			pts.append_array([_at(i, e + side * WALL * 0.75), _at(i, e + side * h), _at(i, e - side * h)])
			cols.append_array([c, c, Color(0, 0, 0, 0)])
			if i > _m0:
				var b := (i - _m0 - 1) * 3
				for k in 2:
					idx.append_array([b + k, b + k + 1, b + k + 3, b + k + 1, b + k + 4, b + k + 3])
		RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)


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
	var last := _split if _splitting() else _path.size() - 1
	_paint_range(_painter.get_canvas_item(), 0, last)
	_paint_pool(_painter.get_canvas_item())
	_penis(_painter.get_canvas_item(), 0, last)
	if _with_penis:
		_paint_pool_bands(_painter.get_canvas_item(), true)


func _paint_lower() -> void:
	if shown <= 0.0 or not _splitting() or _split >= _path.size():
		return
	_paint_range(_lower.get_canvas_item(), _split, _path.size() - 1)


func _paint_lower_top() -> void:
	if shown <= 0.0 or not _splitting() or _split >= _path.size():
		return
	_penis(_lower_top.get_canvas_item(), _split, _path.size() - 1)


## Her throat at the samples i0 to i1 (both drawn: the painters share the row where they meet).
func _paint_range(ci: RID, i0: int, i1: int) -> void:
	_glow(ci, _e0, -WALL, -WALL - GLOW, i0, i1)
	_glow(ci, _e1, WALL, WALL + GLOW, i0, i1)
	_band(ci, -WALL, WALL, _wall_col, i0, i1)
	_band(ci, 0.0, 0.0, _lumen_col, i0, i1)


## A premultiplied colour (the fade behind the start edge is FADE_SHADER's).
static func _pm(col: Color) -> Color:
	return Color(col.r * col.a, col.g * col.a, col.b * col.a, col.a)


## A strip along the centre line from his outline's e0 + lo to e1 + hi, in one colour (premultiplied), its edges
## fading out across one screen pixel centred on them.
func _band(ci: RID, lo: float, hi: float, col: Color, i0: int, i1: int) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var h := _half_px
	var c0 := _pm(col)
	for i in range(i0, i1 + 1):
		var c := c0 * _w[i]
		var d0 := _e0[i] + lo
		var d1 := _e1[i] + hi
		var m0 := minf(d0 + h, (d0 + d1) * 0.5)   # a strip thinner than a pixel: no solid middle
		var m1 := maxf(d1 - h, (d0 + d1) * 0.5)
		pts.append_array([_at(i, d0 - h), _at(i, m0), _at(i, m1), _at(i, d1 + h)])
		cols.append_array([Color(0, 0, 0, 0), c, c, Color(0, 0, 0, 0)])
		if i > i0:
			var b := (i - i0 - 1) * 4
			for k in 3:   # the fade in, the solid middle, the fade out
				idx.append_array([b + k, b + k + 1, b + k + 4, b + k + 1, b + k + 5, b + k + 4])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)


## A strip from edge + inner (glow colour) to edge + outer (transparent). It starts half a pixel under the wall,
## so the wall's faded edge has the glow under it (no light seam between the two).
func _glow(ci: RID, edge: PackedFloat32Array, inner: float, outer: float, i0: int, i1: int) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var gc := _pm(_glow_col)
	var under := -signf(outer - inner) * _half_px
	for i in range(i0, i1 + 1):
		pts.append(_at(i, edge[i] + inner + under))
		pts.append(_at(i, edge[i] + outer))
		cols.append(gc * _w[i])
		cols.append(Color(0, 0, 0, 0))
		if i > i0:
			var b := (i - i0 - 1) * 2
			idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)


## His penis from his render, bent along the centre line: each sample takes the penis-local cross-section at the
## same distance from her lips.
func _penis(ci: RID, i0: int, i1: int) -> void:
	var grp := FlashGroupProxy.of(g.him)
	if grp == null or _drawn <= 0.0 or not _with_penis:
		return
	var rect := grp.render_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var pts := PackedVector2Array()
	# he shows at the cutaway's opacity over her throat's inside, a little of it through him (as when the opacity was
	# on each of the cutaway's layers); premultiplied
	var pen_col := Color(opacity, opacity, opacity, opacity)
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var last := mini(mini(int(ceil(_drawn / STEP)), _path.size() - 1), i1)
	if last <= i0:
		return
	var h := _half_px / _wid_scale   # half a screen pixel, penis-local
	for i in range(i0, last + 1):
		var x := _x_lips - minf(i * STEP, _drawn) / _len_scale
		# the strip's sides fade out across a pixel, like the bands
		var ys := [_y0[i] - h, _y0[i] + h, _y1[i] - h, _y1[i] + h]
		for j in 4:
			pts.append(_at(i, _side * ys[j] * _wid_scale))
			uvs.append((_penis_xf * Vector2(x, ys[j]) - rect.position) / rect.size)
			cols.append(pen_col if j == 1 or j == 2 else Color(0, 0, 0, 0))
		if i > i0:
			var b := (i - i0 - 1) * 4
			for k in 3:
				idx.append_array([b + k, b + k + 1, b + k + 4, b + k + 1, b + k + 5, b + k + 4])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(),
		grp.render_texture().get_rid())
