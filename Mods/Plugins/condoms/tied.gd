extends RefCounted
## The condom he took off, in his left hand: held by its knot at the bottom of his fist, the cum in a teardrop sack
## hanging from it (the same weight on stretchy latex as on his penis: real gravity, heavier the more cum, swinging
## and sloshing with his hand). While he pulls it off his penis the empty sleeve runs from his glans to his fist as
## a stretched tube; tied, a short end of it sticks out over the knot. A sprite in his hand, under the fist's art
## (the fist hides the knot), drawn on every rendered frame between the last two ticks like the sack on his penis.
## Physics in stage coordinates, drawing in the hand's own.

const GRIP := Vector2(-40, 176)   # the knot, in his hand: the bottom of his fist (the hand art's own units)
const STUB := 9.0                 # tied: the end over the knot is this long (penis units)

var c                             # condom.gd (its constants and drawing helpers)
var sprite: FlashSprite
var hand: FlashDisplayObject
var r := 0.0                      # the bulb's radius (penis units)
var length := 0.0                 # the sack's rest length (penis units)
var mass := 0.0                   # 0..1: empty .. full
var unit := 1.0                   # stage px per penis unit (taken from his penis)
var p := Vector2()                # the weight, stage coordinates
var v := Vector2()                # its speed, stage px per tick
var gfelt := Vector2(0, 1)        # what the cum feels: gravity less the sack's acceleration
var tail := Vector2(NAN, NAN)     # the other end of the sleeve (stage coordinates; NAN: none): on his glans while he
var tail_w := 0.0                 #   pulls it off, then the tied end; and its half width there (penis units)
var tied := false                 # tied: the tail is the short end over the knot (it moves with his hand)
var col := Color.WHITE
var alpha := 0.8
var cum_col := Color.WHITE
var _a0 := Vector2()              # the knot last tick (stage coordinates)
var _ok := false
var _pe0 := Vector2()             # per frame: the weight, gravity and the tail's end in the hand, last tick and this
var _pe1 := Vector2()
var _g0 := Vector2(0, 1)
var _g1 := Vector2(0, 1)
var _t0 := Vector2(NAN, NAN)
var _t1 := Vector2(NAN, NAN)
var _hs := 1.0                    # hand units per stage px
var _need := true
var _drawn_at := Vector4(INF, 0, 0, 0)
var _drawn_us := 0
var _drawer: Node = null


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
	_drawer = _Drawer.new()
	_drawer.t = self
	(Engine.get_main_loop() as SceneTree).root.add_child(_drawer)


## Takes over the sack from his penis: its weight where it was (stage coordinates), moving as it moved.
func take(at: Vector2, speed: Vector2, radius: float, rest: float, m: float, px_per_unit: float) -> void:
	r = radius
	length = rest
	mass = m
	unit = px_per_unit
	p = at
	v = speed
	_ok = false


## The knot, stage coordinates.
func knot() -> Vector2:
	return hand.localToGlobal(GRIP)


## The tied end's tip (stage coordinates): STUB up out of his fist from the knot.
func stub_point() -> Vector2:
	var kn := knot()
	var up := (hand.localToGlobal(GRIP + Vector2(0, -1)) - kn).normalized()
	return kn + up.rotated(-0.5) * STUB * unit


## Keeps the sprite in his hand, under the fist's art.
func attach(h: FlashDisplayObject) -> void:
	hand = h
	if sprite.parent != h:
		if sprite.parent != null:
			sprite.parent.removeChild(sprite)
		h.addChildAt(sprite, 0)
		_need = true
	elif h.getChildIndex(sprite) != 0:
		h.setChildIndex(sprite, 0)


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
	if hand == null or sprite.parent == null:
		return
	var a := knot()
	if tied:
		tail = stub_point()
	var g: float = c.GRAVITY_CM / c.CM_PER_UNIT * unit / 900.0
	var m: float = c.SACK_MASS0 + (1.0 - c.SACK_MASS0) * clampf(mass, 0.0, 1.0)
	var k: float = g / (c.SACK_L * unit)
	var l0 := maxf(0.5, length) * unit
	var c_link: float = 2.0 * c.SACK_ZETA * sqrt(k)
	var c_air: float = c.SACK_AIR * sqrt(g / (l0 + c.SACK_L * unit)) * (0.3 + 0.7 * r / c.BULB_R)
	var fresh := not _ok
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
	# in his hand, for drawing between this tick and the last
	var o := hand.localToGlobal(Vector2.ZERO)
	_hs = 1.0 / maxf(0.0001, hand.localToGlobal(Vector2(1, 0)).distance_to(o))
	var pe1 := hand.globalToLocal(p)
	var g1 := (hand.globalToLocal(o + gfelt) - hand.globalToLocal(o)).normalized()
	var t1 := hand.globalToLocal(tail) if not is_nan(tail.x) else Vector2(NAN, NAN)
	_pe0 = pe1 if fresh else _pe1
	_g0 = g1 if fresh else _g1
	_t0 = t1 if fresh or is_nan(_t1.x) or is_nan(t1.x) else _t1
	_pe1 = pe1
	_g1 = g1
	_t1 = t1


func _frame() -> void:
	if hand == null or sprite.parent == null or not _ok:
		return
	var f := Engine.get_physics_interpolation_fraction() if FlashRectClip.smooth and not g.gamePaused else 1.0
	var pe := _pe0.lerp(_pe1, f)
	var dn := _g0.lerp(_g1, f).normalized()
	var tl := _t0.lerp(_t1, f)
	var key := Vector4(pe.x, pe.y, dn.x * 50.0 + (tl.x if not is_nan(tl.x) else 0.0), dn.y * 50.0
		+ (tl.y if not is_nan(tl.y) else 0.0))
	var now := Time.get_ticks_usec()
	if not _need:
		if key.distance_squared_to(_drawn_at) < 0.0025:
			return
		if now - _drawn_us < c._frame_us():
			return
	_drawn_at = key
	_drawn_us = now
	_need = false
	draw(pe, dn, tl)


## Draws it in his hand: the teardrop from the knot to the weight pe (hand units), gravity felt dn, the sleeve's
## other end tl (NAN: none).
func draw(pe: Vector2, dn: Vector2, tl: Vector2) -> void:
	var gr := sprite.graphics
	gr.clear()
	var s := unit * _hs                         # hand units per penis unit
	var rr := r * s
	var rn: float = clampf(r * 0.16, 1.8, 4.0) * s
	var kn := GRIP
	var ax := pe - kn
	var zc := maxf(rr, ax.length())
	ax = ax.normalized() if ax.length() > 0.001 else dn
	var pp := Vector2(-ax.y, ax.x)
	var n := 20
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n + 1:
		var u := pow(float(i) / n, c.TEAR_K)
		var w := lerpf(rn, rr, (1.0 - cos(PI * u)) * 0.5)
		left.append(kn + ax * zc * float(i) / n + pp * w)
		right.append(kn + ax * zc * float(i) / n - pp * w)
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
	# the sleeve's other end: a tube from the knot (stretched to his glans, or the short tied end)
	if not is_nan(tl.x) and tl.distance_to(kn) > 1.0:
		var d := tl - kn
		var dl := d.length()
		var dir := d / dl
		var nv := Vector2(-dir.y, dir.x)
		var tw := maxf(rn, tail_w * s)
		var tube := PackedVector2Array()
		var back := PackedVector2Array()
		var steps := 8
		for i in steps + 1:
			var u := float(i) / steps
			var w := lerpf(rn * 1.2, tw, u * u)
			tube.append(kn + d * u + nv * w)
			back.append(kn + d * u - nv * w)
		var cap := 6
		for j in range(1, cap):
			var th := PI * float(j) / cap
			tube.append(tl + (nv * cos(th) + dir * sin(th)) * tw)
		back.reverse()
		tube.append_array(back)
		c._poly(pts, cols, idx, tube, latex)
		var loop := tube.duplicate()
		loop.append(tube[0])
		_outline(pts, cols, idx, loop, s, line, edge)
	if sack.size() < 3:
		return
	# the cum, then the latex over it (seen through the latex, as on his penis: draw_bulb's order)
	var side := Vector2(-dn.y, dn.x) * 4000.0
	var lv := pe - dn * rr * 0.45
	var below := PackedVector2Array([lv - side, lv + side, lv + side + dn * 4000.0, lv - side + dn * 4000.0])
	for q in Geometry2D.intersect_polygons(sack, below):
		if q.size() >= 3:
			c._pool(pts, cols, idx, q, pe, dn, rr, cum_col, lv, alpha)
	c._poly(pts, cols, idx, sack, latex)
	var loop2 := sack.duplicate()
	loop2.append(sack[0])
	if c._signed_area(sack) < 0.0:
		loop2.reverse()
	_outline(pts, cols, idx, loop2, s, line, edge)
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


## Its outline: the latex denser at the edge, a dark line (condom.gd's widths, in hand units).
func _outline(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, loop: PackedVector2Array,
		s: float, line: Color, edge: Color) -> void:
	if c._signed_area(loop) > 0.0:
		loop.reverse()
	c._strip(pts, cols, idx, loop, [-c.EDGE_W * s, 0.0], [c._a(edge, 0.0), edge])
	c._strip(pts, cols, idx, loop, [0.0, 0.25 * s, c.LINE * s, (c.LINE + c.FADE) * s], [c._a(line, 0.0), line, line,
		c._a(line, 0.0)])
