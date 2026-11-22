extends RefCounted
## A condom he took off and tied: hanging from its knot, the cum in a teardrop sack below it (the same weight on
## stretchy latex as on his penis: real gravity, heavier the more cum, swinging and sloshing as the knot moves). The
## knot is in his left hand (at the bottom of his fist), pinned on a part of her (it follows the part), or falling
## (dropped). While he pulls it off his penis the empty sleeve runs from his glans to his fist as a stretched tube;
## tied, a short end of it sticks out over the knot, opening into an upside-down triangle (the flattened open end)
## whose top edge is the rolled rim. A sprite in his hand under the fist's art
## (the fist hides the knot), or in a layer above her; drawn on every rendered frame between the last two ticks like
## the sack on his penis. Physics in the scene layer's coordinates ("world": zooming does not change them), drawing
## in the sprite's parent's; knot(), stub_point() and tail are in stage coordinates.

const GRIP := Vector2(-40, 176)   # the knot, in his hand: the bottom of his fist (the hand art's own units)
const STUB := 6.5                 # tied: the end over the knot is this long (penis units)
const TIE_W := 2.0                # ... and this wide each side at its end
const PIN_UP := Vector2(0, -1)    # pinned (or off his hand): the tied end points this way, straight up
const KNOT_WIDE := 1.35           # tied: the knot this many times as wide as the sleeve there,
const KNOT_DENSE := 0.90          #   its latex this opaque (the rest: 0.5)
const SACK_UP := 5.0              # tied: the sack drawn this far up, its top inside the knot (penis units)
const TRI_UP := 2.0               # the open end over it this far up from the knot's top (penis units),
const TRI_H := 13.0               # the open end over it: an upside-down triangle this tall (penis units),
const TRI_W := 11.0               #   this wide each side at its top edge (the rim),
const TRI_SAG := 0.3              #   its other two sides bent in this much (share of the way to its middle line),
const TRI_BULGE := 0.8            #   its top edge bent out this much in the middle (penis units),
const RIM_END := 1.4              #   the rim's two ends round knobs this many times its thickness
const BUDGET_US := 1500           # all of them together redraw for at most this long in a frame (us),
const LATE_FRAMES := 4            #   but each one at most this many frames late
const FLY_TICKS := 6.0            # pinned: the knot goes from his hand to its place on her in this many ticks

var c                             # condom.gd (its constants and drawing helpers)
var sprite: FlashSprite
var host: FlashDisplayObject       # the sprite's parent (what it is drawn in): his hand, or the layer above her
var anchor: FlashDisplayObject     # what the knot is on (his hand, or a part of her; null: falling), and where on it
var anchor_local := GRIP
var _chain: Array = []             # pinned: what the knot goes on if `anchor` leaves her (its parents, nearest first)
var falling := false               # dropped: the knot falls freely
var _fly_from := Vector2()         # pinned: where the knot was as it left his hand (world), and the ticks
var _fly_t := FLY_TICKS            #   since (FLY_TICKS: there)
var _fall_p := Vector2()           # ... where it is and how fast (world, per tick)
var _fall_v := Vector2()
var r := 0.0                      # the bulb's radius (penis units)
var length := 0.0                 # the sack's rest length (penis units)
var mass := 0.0                   # its weight: 0 empty .. 1 half full .. 2 full (condom.step_sack's mass)
var unit := 1.0                   # world units per penis unit (taken from his penis)
var p := Vector2()                # the weight (world)
var v := Vector2()                # its speed (world, per tick)
var gfelt := Vector2(0, 1)        # what the cum feels: gravity less the sack's acceleration
var tail := Vector2(NAN, NAN)     # the other end of the sleeve (stage coordinates; NAN: none): on his glans while he
var tail_w := 0.0                 #   pulls it off, then the tied end; and its half width there (penis units)
var tied := false                 # tied: the tail is the open end over the knot (it moves with the knot)
var closed := false               # off his penis: the open end is drawn,
var bow := 1.0                    #   this far open (0..1: it opens as he ties it)
var col := Color.WHITE
var alpha := 0.8
var cum_col := Color.WHITE
var _a0 := Vector2()              # the knot last tick (world)
var _ok := false
var _pe0 := Vector2()             # per frame: the weight, gravity, the tail's end and the knot in the host, last tick
var _pe1 := Vector2()             #   and this
var _k0 := GRIP
var _k1 := GRIP
var _g0 := Vector2(0, 1)
var _g1 := Vector2(0, 1)
var _t0 := Vector2(NAN, NAN)
var _t1 := Vector2(NAN, NAN)
var _hs := 1.0                    # host units per world unit
var _need := true
var _drawn_at := Vector4(INF, 0, 0, 0)
var _drawn_us := 0
var _drawer: Node = null
var _rehost := false               # a new host: this tick's drawing places are not eased from the last
var _drawn_frame := 0              # the frame it was last drawn in
static var _budget_frame := -1     # this frame's redraws so far (all of them)
static var _budget_us := 0


class _Drawer:
	extends Node
	var t

	func _process(_delta: float) -> void:
		t._frame()


func _init(condom) -> void:
	c = condom
	sprite = FlashSprite.new()
	sprite.mouseEnabled = false
	sprite.mouseChildren = false
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # (placed on every frame: _frame)
	_drawer = _Drawer.new()
	_drawer.t = self
	(Engine.get_main_loop() as SceneTree).root.add_child(_drawer)


static func _w(st: Vector2) -> Vector2:
	return g.sceneLayer.globalToLocal(st)


static func _s(w: Vector2) -> Vector2:
	return g.sceneLayer.localToGlobal(w)


## Takes over the sack from his penis: its weight where it was (stage coordinates), moving as it moved (stage px per
## tick); px_per_unit: stage px per penis unit.
func take(at: Vector2, speed: Vector2, radius: float, rest: float, m: float, px_per_unit: float) -> void:
	r = radius
	length = rest
	mass = m
	p = _w(at)
	v = _w(at + speed) - p
	unit = px_per_unit * (_w(at + Vector2(1, 0)) - p).length()
	_ok = false


## The knot, stage coordinates.
func knot() -> Vector2:
	return _s(_knot_w())


func _knot_w() -> Vector2:
	if falling or anchor == null:
		return _fall_p
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		if not _next_anchor():
			return _a0
	var at := _w(anchor.localToGlobal(anchor_local))
	if _fly_t < FLY_TICKS:
		return _fly_from.lerp(at, smoothstep(0.0, 1.0, _fly_t / FLY_TICKS))
	return at


## The tied end's tip (stage coordinates): STUB out of his fist, a little to his back (or straight up, off his hand)
## from the knot.
func stub_point() -> Vector2:
	var kn := _knot_w()
	var up := PIN_UP
	if not falling and anchor != null and is_instance_valid(anchor) and anchor_local == GRIP:
		up = (_w(anchor.localToGlobal(GRIP + Vector2(0, -1))) - kn).normalized().rotated(-0.5)
	return _s(kn + up * STUB * unit)


## Where the knot goes for the tied end's middle to be at the stage point `at` once pinned.
func pin_knot(at: Vector2) -> Vector2:
	return _s(_w(at) - PIN_UP * STUB * 0.5 * unit)


## Keeps the sprite in his hand, under the fist's art, the knot in his fist.
func attach(h: FlashDisplayObject) -> void:
	anchor = h
	anchor_local = GRIP
	_put(h, 0)


## Pins it on her: the knot stays at the stage point `at` on `part` (what shows there, the deepest); drawn in `layer`.
## chain: part's parents to go on if it leaves her (a frame change, the hair taken off).
func pin(part: FlashDisplayObject, at: Vector2, layer: FlashDisplayObject, chain: Array = []) -> void:
	_fly_from = _knot_w()
	_fly_t = 0.0
	anchor = part
	anchor_local = part.globalToLocal(at)
	_chain = chain.duplicate()
	_put(layer, -1)


## The anchor left her: the knot goes on the next of _chain still on her, where it was. False: none (it falls).
func _next_anchor() -> bool:
	while not _chain.is_empty():
		var n = _chain.pop_front()
		if is_instance_valid(n) and n.is_inside_tree():
			anchor = n
			anchor_local = n.globalToLocal(_s(_a0))
			return true
	anchor = null
	return false


## Lets go of it (from his hand or her): it falls, moving as the knot moved; drawn in `layer`.
func drop(layer: FlashDisplayObject) -> void:
	var at := _knot_w()
	_fall_v = at - _a0 if _ok else Vector2.ZERO
	_fall_p = at
	falling = true
	anchor = null
	_put(layer, -1)


## Where the knot is falling it is gone (off the bottom of the stage, stage coordinates).
func gone(bottom: float) -> bool:
	return falling and _s(_fall_p - Vector2(0, (r * 3.0 + length * 2.0) * unit)).y > bottom


## The sprite in `h` at index i (-1: on top). In a new host its drawing starts fresh where it is (no gliding).
func _put(h: FlashDisplayObject, i: int) -> void:
	if sprite.parent != h:
		if sprite.parent != null:
			sprite.parent.removeChild(sprite)
		if i < 0:
			h.addChild(sprite)
		else:
			h.addChildAt(sprite, i)
		host = h
		_need = true
		_rehost = true
	elif i >= 0 and h.getChildIndex(sprite) != i:
		h.setChildIndex(sprite, i)


func release() -> void:
	if sprite.parent != null:
		sprite.parent.removeChild(sprite)
	sprite.graphics.clear()
	if _drawer != null:
		_drawer.queue_free()
		_drawer = null


func set_look(latex: Color, a: float, cum: Color) -> void:
	if latex != col or a != alpha or cum != cum_col:
		col = latex
		alpha = a
		cum_col = cum
		_need = true


## One tick: the weight on its latex from the knot (as condom.step_sack, without her: his hand is in front of her).
func step() -> void:
	if host == null or sprite.parent == null:
		return
	if anchor != null and not falling and (not is_instance_valid(anchor) or not anchor.is_inside_tree()) 			and not _next_anchor():
		drop(host)   # (all it was on is gone)
	var g: float = c.GRAVITY_CM / c.CM_PER_UNIT * unit / 900.0
	if falling:
		_fall_v.y += g
		_fall_v *= 0.99
		_fall_p += _fall_v
	if _fly_t < FLY_TICKS:
		_fly_t += 1.0
	var a := _knot_w()
	if tied:
		tail = stub_point()
	var m: float = c.SACK_MASS0 + (1.0 - c.SACK_MASS0) * clampf(mass, 0.0, c.MASS_MAX)
	var k: float = g / (c.SACK_L * unit)
	var l0 := maxf(0.5, length) * unit
	var c_link: float = 2.0 * c.SACK_ZETA * sqrt(k)
	var c_air: float = c.SACK_AIR * sqrt(g / (l0 + c.SACK_L * unit)) * (0.3 + 0.7 * r / c.BULB_R)
	var fresh := not _ok or _rehost
	_rehost = false
	if not _ok:
		_a0 = a
		gfelt = Vector2(0, g)
		_ok = true
	var va := a - _a0
	var v0 := v
	var dt: float = 1.0 / c.SACK_STEPS
	var lmax: float = l0 + c.SACK_L * unit * c.SACK_MAX_LEN
	for i in c.SACK_STEPS:
		var an: Vector2 = _a0 + va * (float(i + 1) / c.SACK_STEPS)
		var d: Vector2 = p - an
		var l := maxf(0.001, d.length())
		var dir: Vector2 = d / l
		var f := Vector2(0, m * g) - v * c_air
		var st := l - l0
		if st > 0.0:
			var fs := k * st
			var over: float = st - c.SACK_L * unit * c.SACK_STRETCH
			if over > 0.0:
				fs += k * over * 3.0
			f -= dir * (fs + c_link * (v - va).dot(dir))
		v += f / m * dt
		p += v * dt
		var dl: Vector2 = p - an
		if dl.length() > lmax:
			var dd: Vector2 = dl.normalized()
			p = an + dd * lmax
			var vo := (v - va).dot(dd)
			if vo > 0.0:
				v -= dd * vo
	_a0 = a
	gfelt = gfelt.lerp(Vector2(0, g) - (v - v0), 0.5)
	# in its host, for drawing between this tick and the last
	var pe1 := host.globalToLocal(_s(p))
	_hs = host.globalToLocal(_s(p + Vector2(1, 0))).distance_to(pe1)
	var g1 := (host.globalToLocal(_s(p + gfelt.normalized())) - pe1).normalized()
	var t1 := host.globalToLocal(tail) if not is_nan(tail.x) else Vector2(NAN, NAN)
	var k1 := host.globalToLocal(_s(a))
	_k0 = k1 if fresh else _k1
	_k1 = k1
	sprite.visible = falling or anchor == null or anchor.is_visible_in_tree()   # (on a part of her that is hidden)
	_pe0 = pe1 if fresh else _pe1
	_g0 = g1 if fresh else _g1
	_t0 = t1 if fresh or is_nan(_t1.x) or is_nan(t1.x) else _t1
	_pe1 = pe1
	_g1 = g1
	_t1 = t1


func _frame() -> void:
	if host == null or sprite.parent == null or not _ok:
		return
	var f := Engine.get_physics_interpolation_fraction() if FlashRectClip.smooth and not g.gamePaused else 1.0
	var pe := _pe0.lerp(_pe1, f)
	var dn := _g0.lerp(_g1, f).normalized()
	var tl := _t0.lerp(_t1, f)
	var kn := _k0.lerp(_k1, f)
	# drawn round its knot: when only the knot moves (she breathes, his hand moves slowly) it is only moved there
	if sprite.x != kn.x or sprite.y != kn.y:
		sprite.x = kn.x
		sprite.y = kn.y
	var rel_t := tl - kn
	var key := Vector4(pe.x - kn.x, pe.y - kn.y, dn.x * 50.0 + (rel_t.x if not is_nan(tl.x) else 0.0),
		dn.y * 50.0 + (rel_t.y if not is_nan(tl.y) else 0.0))
	var now := Time.get_ticks_usec()
	if not _need:
		if key.distance_squared_to(_drawn_at) < 0.0025:
			return
		if now - _drawn_us < c._frame_us():
			return
	# all of them share a time budget per frame; one that waited LATE_FRAMES frames goes anyway
	var fr := Engine.get_process_frames()
	if fr != _budget_frame:
		_budget_frame = fr
		_budget_us = 0
	if _budget_us >= BUDGET_US and fr - _drawn_frame < LATE_FRAMES and not _need:
		return
	_drawn_at = key
	_drawn_us = now
	_drawn_frame = fr
	_need = false
	draw(pe - kn, dn, tl - kn if not is_nan(tl.x) else tl, Vector2.ZERO)
	_budget_us += Time.get_ticks_usec() - now


## Draws it: the teardrop from the knot kn to the weight pe (in the sprite's units: its host's, the sprite at the knot
## draws with kn 0), gravity felt dn, the sleeve's other end tl (NAN: none).
func draw(pe: Vector2, dn: Vector2, tl: Vector2, kn := GRIP) -> void:
	var gr := sprite.graphics
	gr.clear()
	var s := unit * _hs                         # host units per penis unit
	var rr := r * s
	var rn: float = clampf(r * 0.16, 1.8, 4.0) * s
	var ax := pe - kn
	var zc := maxf(rr, ax.length())
	ax = ax.normalized() if ax.length() > 0.001 else dn
	var pp := Vector2(-ax.y, ax.x)
	var tied_up := closed and bow > 0.0 and not is_nan(tl.x) and tl.distance_to(kn) > 1.0
	var k0 := kn   # where the sack starts: tied, up inside the knot (the part in it not drawn)
	if tied_up:
		k0 = kn - ax * SACK_UP * s * bow
		pe -= ax * SACK_UP * s * bow
	var n := 20
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n + 1:
		var u := pow(float(i) / n, c.TEAR_K)
		var w := lerpf(rn, rr, (1.0 - cos(PI * u)) * 0.5)
		left.append(k0 + ax * zc * float(i) / n + pp * w)
		right.append(k0 + ax * zc * float(i) / n - pp * w)
	var sack := left
	var cn := maxi(16, int(r * 1.6))
	for j in range(1, cn):
		var th := PI * float(j) / cn
		sack.append(pe + (pp * cos(th) + ax * sin(th)) * rr)
	right.reverse()
	sack.append_array(right)
	for _k in 2:
		var sm := sack.duplicate()
		var m := sack.size()
		for i in m:
			sm[i] = (sack[(i + m - 1) % m] + sack[i] * 2.0 + sack[(i + 1) % m]) * 0.25
		sack = sm
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var latex: Color = c._a(col, 0.5 * alpha)
	var line := Color(col.r * 0.45, col.g * 0.45, col.b * 0.5, 0.85 * alpha)
	var edge: Color = c._a(col, 0.55 * alpha)
	var knot := PackedVector2Array()   # (the tied end's outline, the sack cut by it)
	# the sleeve's other end: a tube from the knot (stretched to his glans; tied: the open end, flaring out to its rim)
	if not is_nan(tl.x) and tl.distance_to(kn) > 1.0:
		var d := tl - kn
		var dl := d.length()
		var dir := d / dl
		var nv := Vector2(-dir.y, dir.x)
		var tw := maxf(rn, tail_w * s)
		var wk := lerpf(1.0, KNOT_WIDE, bow) if tied_up else 1.0   # (tied: the knot wider)
		tw *= wk
		if closed and bow > 0.0:   # the open end: an upside-down triangle of flat latex, the rolled rim its top edge (under
			#   the tied end: its point is drawn over by it)
			var tip := tl + dir * (TRI_UP * s * bow - tw * 0.5)
			var top := tip + dir * TRI_H * s * bow
			var a := top + nv * TRI_W * s * bow
			var b := top - nv * TRI_W * s * bow
			# only the part out of the tied end's round end (a circle tw round tl): none of it seen through the knot
			var ea := _out_of(tip, a, tl, tw)
			var eb := _out_of(tip, b, tl, tw)
			var sa := _sag(ea, a, tip, dir)   # (its sides a little concave)
			var sb := _sag(eb, b, tip, dir)
			var tri := sb.duplicate()
			var ra := sa.duplicate()
			ra.reverse()
			var bulge := dir * TRI_BULGE * s * bow   # (its top edge a very little convex)
			for i in range(1, 8):
				tri.append(_bent(b, a, bulge, i / 8.0))
			tri.append_array(ra)
			var a0 := (ea - tl).angle()
			var da := wrapf((eb - tl).angle() - a0, -PI, PI)
			for i in range(1, 6):   # (back along the round end, on the triangle's side)
				tri.append(tl + Vector2.from_angle(a0 + da * i / 6.0) * tw)
			c._poly(pts, cols, idx, tri, latex)
			for sl: PackedVector2Array in [sa, sb]:   # its two sides: the latex's edge and line
				if (sl[sl.size() - 1] - sl[0]).cross(top - sl[0]) > 0.0:   # (the inside on its right, as the strips want)
					sl.reverse()
				c._strip(pts, cols, idx, sl, [-c.EDGE_W * s * 0.6, 0.0], [c._a(edge, 0.0), edge])
				c._strip(pts, cols, idx, sl, [0.0, 0.25 * s, c.LINE * s, (c.LINE + c.FADE) * s], [c._a(line, 0.0),
					line, line, c._a(line, 0.0)])
			_rim_arm(pts, cols, idx, b, a, c.RING_R * 0.7 * s, bulge)
		var tube := PackedVector2Array()   # (latex over latex: the triangle above stops at its edge)
		var back := PackedVector2Array()
		var steps := 8
		for i in steps + 1:
			var u := float(i) / steps
			var w := lerpf(rn * 1.2 * wk, tw, u * u)
			tube.append(kn + d * u + nv * w)
			back.append(kn + d * u - nv * w)
		var cap := 6   # (a round end)
		for j in range(1, cap):
			var th := PI * float(j) / cap
			tube.append(tl + (nv * cos(th) + dir * sin(th)) * tw)
		back.reverse()
		tube.append_array(back)
		if tied_up:   # tied: its bottom round too (the sack goes up into it)
			var wb := rn * 1.2 * wk
			for j in range(1, cap):
				var th := PI * float(j) / cap
				tube.append(kn + (-nv * cos(th) - dir * sin(th)) * wb)
		c._poly(pts, cols, idx, tube, c._a(col, lerpf(0.5, KNOT_DENSE, bow) * alpha) if tied_up else latex)
		if tied_up:
			knot = tube
		var loop := tube.duplicate()
		loop.append(tube[0])
		_outline(pts, cols, idx, loop, s, line, edge)
	if sack.size() < 3:
		return
	# the cum, then the latex over it (seen through the latex, as on his penis: draw_bulb's order)
	var side := Vector2(-dn.y, dn.x) * 4000.0
	var lv: Vector2 = pe - dn * rr * c.LEVEL
	var below := PackedVector2Array([lv - side, lv + side, lv + side + dn * 4000.0, lv - side + dn * 4000.0])
	for q in Geometry2D.intersect_polygons(sack, below):
		if q.size() >= 3:
			c._pool(pts, cols, idx, q, pe, dn, rr, cum_col, lv, alpha)
	var loop2 := sack.duplicate()
	loop2.append(sack[0])
	if c._signed_area(sack) < 0.0:
		loop2.reverse()
	if knot.size() < 3:
		c._poly(pts, cols, idx, sack, latex)
		_outline(pts, cols, idx, loop2, s, line, edge)
	else:   # its top inside the knot: only what is out of it
		for q in Geometry2D.clip_polygons(sack, knot):
			if q.size() >= 3:
				c._poly(pts, cols, idx, q, latex)
		if c._signed_area(loop2) > 0.0:   # (the way _outline goes round)
			loop2.reverse()
		for q in Geometry2D.clip_polyline_with_polygon(loop2, knot):
			if q.size() >= 2:
				c._strip(pts, cols, idx, q, [-c.EDGE_W * s, 0.0], [c._a(edge, 0.0), edge])
				c._strip(pts, cols, idx, q, [0.0, 0.25 * s, c.LINE * s, (c.LINE + c.FADE) * s], [c._a(line, 0.0),
					line, line, c._a(line, 0.0)])
	var sc := pe - dn * rr * 0.45 + Vector2(-dn.y, dn.x) * rr * 0.35
	var o := pts.size()
	pts.append(sc)
	cols.append(Color(1, 1, 1, 0.7 * alpha))
	var m2 := 14
	for i in m2:
		var fa := TAU * float(i) / m2
		pts.append(sc + Vector2(cos(fa) * rr * 0.14, sin(fa) * rr * 0.3).rotated(atan2(dn.y, dn.x) - PI * 0.5 + 0.4))
		cols.append(Color(1, 1, 1, 0.0))
	for i in m2:
		idx.append_array([o, o + 1 + i, o + 1 + (i + 1) % m2])
	gr.setMesh(pts, cols, idx)


## A short piece of the rolled rim from a to b, rt thick, shaded like condom.gd's _ring, a round end past each.
func _rim_arm(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, a: Vector2, b: Vector2,
		rt: float, bulge := Vector2.ZERO) -> void:
	var body := Color(col.r * 0.9, col.g * 0.9, col.b * 0.9, 0.95 * alpha)
	var dark := Color(col.r * 0.45, col.g * 0.45, col.b * 0.5, alpha)
	var lit := Color(lerpf(col.r, 1.0, 0.7), lerpf(col.g, 1.0, 0.7), lerpf(col.b, 1.0, 0.7), alpha)
	var fade: float = c.FADE * rt / c.RING_R
	var d := b - a
	if d.length() < 0.3:
		return
	var line := PackedVector2Array()   # along it (bent out by bulge in the middle); past each end a round end: every
	var ang := PackedFloat32Array()    #   band of its shading a half circle round the end (ang: how far round, signed)
	var tan := PackedVector2Array()    # (its way there)
	var big := PackedFloat32Array()    # (its thickness there, as a share of rt: RIM_END at the ends)
	var ta := (_bent(a, b, bulge, 0.01) - a).normalized()
	var tb := (b - _bent(a, b, bulge, 0.99)).normalized()
	var ce := 10
	for i in ce:
		line.append(a)
		ang.append(-PI * 0.5 * (1.0 - float(i) / ce))
		tan.append(ta)
		big.append(RIM_END)
	var mid := 8
	for i in mid + 1:
		var u := float(i) / mid
		line.append(_bent(a, b, bulge, u))
		ang.append(0.0)
		big.append(lerpf(1.0, RIM_END, smoothstep(0.5, 1.0, absf(u * 2.0 - 1.0))))
		tan.append((_bent(a, b, bulge, minf(u + 0.01, 1.0)) - _bent(a, b, bulge, maxf(u - 0.01, 0.0))).normalized())
	for i in range(1, ce + 1):
		line.append(b)
		ang.append(PI * 0.5 * float(i) / ce)
		tan.append(tb)
		big.append(RIM_END)
	var n := line.size() - 1
	var o := pts.size()
	var offs := [-rt - fade, -rt, -rt * 0.35, rt * 0.3, rt, rt + fade]
	var cs := [c._a(dark, 0.0), dark, lit, body, dark, c._a(dark, 0.0)]
	for i in n + 1:
		var nv := Vector2(-tan[i].y, tan[i].x)
		for k in offs.size():
			var off: float = offs[k] * big[i]
			pts.append(line[i] + nv * off * cos(ang[i]) + tan[i] * absf(off) * sin(ang[i]))
			cols.append(cs[k])
	var w := offs.size()
	for i in n:
		for k in w - 1:
			var j := o + i * w + k
			idx.append_array([j, j + w, j + 1, j + 1, j + w, j + w + 1])


## The point u of the way from a to b on a curve whose middle is bulge off the straight line.
static func _bent(a: Vector2, b: Vector2, bulge: Vector2, u: float) -> Vector2:
	return a.lerp(b, u) + bulge * 4.0 * u * (1.0 - u)


## A side of the open end from p to q, bent in towards its middle line (from tip along dir) by TRI_SAG.
func _sag(p: Vector2, q: Vector2, tip: Vector2, dir: Vector2) -> PackedVector2Array:
	var m := (p + q) * 0.5
	var k := m.lerp(tip + dir * (m - tip).dot(dir), TRI_SAG * 2.0)   # (the curve's middle goes half that way)
	var out := PackedVector2Array()
	var n := 6
	for i in n + 1:
		var u := float(i) / n
		out.append(p.lerp(k, u).lerp(k.lerp(q, u), u))
	return out


## Where the line from p (in the circle cen, rad round) to q goes out of that circle (q when it does not).
func _out_of(p: Vector2, q: Vector2, cen: Vector2, rad: float) -> Vector2:
	var u := q - p
	var f := p - cen
	var aa := u.dot(u)
	var bb := 2.0 * f.dot(u)
	var dd := bb * bb - 4.0 * aa * (f.dot(f) - rad * rad)
	if aa < 1e-6 or dd < 0.0:
		return q
	return p + u * clampf((-bb + sqrt(dd)) / (2.0 * aa), 0.0, 1.0)


## Its outline: the latex denser at the edge, a dark line (condom.gd's widths, in hand units).
func _outline(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, loop: PackedVector2Array,
		s: float, line: Color, edge: Color) -> void:
	if c._signed_area(loop) > 0.0:
		loop.reverse()
	c._strip(pts, cols, idx, loop, [-c.EDGE_W * s, 0.0], [c._a(edge, 0.0), edge])
	c._strip(pts, cols, idx, loop, [0.0, 0.25 * s, c.LINE * s, (c.LINE + c.FADE) * s], [c._a(line, 0.0), line, line,
		c._a(line, 0.0)])
