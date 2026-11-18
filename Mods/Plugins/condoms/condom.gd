extends RefCounted
## The condom drawn over his penis: a see-through latex sleeve that follows the outline of the penis art (found by
## hit tests, so it fits every penis type, size and mod), a rolled rim where it ends. A
## sprite inside his penis clip, above the art and below the wet shine and lipstick, so it turns, scales and
## hides in her mouth with the penis. Drawn again only when something changes (rolling it on, the colour, a new penis).
## All in penis-local units: the art points towards -x, his body is at +x.

const STEP := 2.0          # units between outline columns
const OUT := 0.7           # the latex lies this far outside the penis outline
const LINE := 0.9          # width of its outline
const EDGE_W := 3.5        # the latex's denser sides fade out inwards over this
const FADE := 0.8          # the outline fades out over this (smooth edges without antialiasing)
const FRONT := 25.0        # the smoothing below leaves the glans front alone (units from its tip)
const ROUND_R := 10.0      # peaks of the latex's edge round off with this radius
const BRIDGE := 0.4        # behind the glans the latex falls back to the shaft no steeper than this (y per x)
const FLARE_H := 12.0      # the shine strips start where the glans is this far above / below its tip
const TIP_SMOOTH := 19.0   # the outline is smoothed this far along it each side of the glans tip
const RING_OUT := 1.6      # the rim stands out this far past the sleeve's outline (unrolled)
const RING_R := 2.4        # half thickness of the rolled rim once it is unrolled
const RING_MAX := 6.5      # half thickness of the rim while it is still rolled up at the tip
const BULB_R := 25.0       # radius of the cum bulb at the end of the sack when it is full (it grows no more)
const BULB_MIN := 4.0      # ... with the first drop in it
const SACK_L := 45.0       # the teardrop's neck (tip to the round bottom's middle, past 1.3 x its radius), full
const TIP_POLY_R := 130.0  # the sack is joined to the outline within this of the tip (past cut_r and the sack)
const WEB := 0.12         # the latex web in the corners where the sack meets the sleeve: radius, share of the bulb's
const WEB_MIN := 2.0       # ... and at least this
const TEAR_K := 1.25       # the teardrop's flare: higher keeps the neck thin longer and widens it later
const GRAVITY_CM := 981.0  # gravity, cm per second per second
const CM_PER_UNIT := 0.05  # the size of a penis unit (his penis is about 315 units: 16 cm)
const SACK_MASS0 := 0.12   # the empty sack's weight, as a share of a full one
const SACK_ZETA := 0.12    # damping of its bounce along the latex (full; lighter is damped more)
const SACK_AIR := 0.12     # air drag on its swing
const SACK_STEPS := 10     # physics steps per tick (the latex is stiff)
const SACK_STRETCH := 1.5  # past this much of the full weight's stretch the latex gets much stiffer

var sprite: FlashSprite
var bulb: FlashSprite      # the cum in its tip (its own sprite: drawn again only when the cum or the colour changes)
var tip_x := 0.0           # x of the glans tip
var tip_y := 0.0           # y of the glans tip (the middle of the last column)
var base_x := 0.0          # the far end of the art (his body)
var _xs := PackedFloat32Array()    # columns from the tip towards his body
var _tops := PackedFloat32Array()  # top edge of the latex (the art's, bridged behind the glans)
var _bots := PackedFloat32Array()
var _penis: FlashDisplayObject
var _art: FlashDisplayObject
var _outline := PackedVector2Array()   # the latex's outline as last drawn (rim, top, round the tip, bottom, rim)
var _arc := PackedFloat32Array()       # along the outline from the glans tip
var _ti := 0                           # the outline's point at the glans tip
var _tip_poly := PackedVector2Array()  # the outline within TIP_POLY_R of the tip, closed across the penis
var sack_p := Vector2()                # the bulb's middle, stage coordinates (step_sack)
var sack_v := Vector2()                # its speed, stage pixels per tick
var sack_a0 := Vector2()               # his tip last tick (stage coordinates)
var sack_g := Vector2(0, 1)            # what the cum feels: gravity less the sack's acceleration
var sack_ok := false                   # sack_p is set (false: it starts hanging straight down)
var cut_r := 0.0                       # while the sack is drawn: the sleeve's outline leaves out this much round its
                                       # tip, the bulb draws the outline of the sleeve and sack together there
var _drawn_at := Vector4()
var _pe0 := Vector2()                  # the weight on his penis last tick and this tick (drawn between them)
var _pe1 := Vector2()
var _g0 := Vector2(0, 1)               # what the cum feels, on his penis, last tick and this tick
var _g1 := Vector2(0, 1)
var _bulb_args := []                   # set_bulb's
var _bulb_need := false
var _drawn_us := 0
var _refresh_us := -1
var _drawer: Node = null             # where the bulb was last drawn (penis units) and gravity there


func _init() -> void:
	sprite = FlashSprite.new()
	sprite.mouseEnabled = false
	sprite.mouseChildren = false
	bulb = FlashSprite.new()
	bulb.mouseEnabled = false
	bulb.mouseChildren = false


## Puts the sprite into his penis clip, right above the art.
func attach(penis: FlashDisplayObject, art: FlashDisplayObject) -> void:
	_penis = penis
	_art = art
	if sprite.parent != penis:
		if sprite.parent != null:
			sprite.parent.removeChild(sprite)
		penis.addChildAt(sprite, penis.getChildIndex(art) + 1)
	elif penis.getChildIndex(sprite) != penis.getChildIndex(art) + 1:
		penis.setChildIndex(sprite, mini(penis.numChildren - 1, penis.getChildIndex(art) + 1))
	if bulb.parent != penis:
		if bulb.parent != null:
			bulb.parent.removeChild(bulb)
		penis.addChildAt(bulb, penis.getChildIndex(sprite) + 1)
	elif penis.getChildIndex(bulb) != penis.getChildIndex(sprite) + 1:
		penis.setChildIndex(bulb, mini(penis.numChildren - 1, penis.getChildIndex(sprite) + 1))


func detach() -> void:
	_bulb_args = []
	for sp in [sprite, bulb]:
		if sp.parent != null:
			sp.parent.removeChild(sp)
		sp.graphics.clear()


func _hit(p: Vector2) -> bool:
	var gp: Vector2 = _penis.localToGlobal(p)
	return _art.hitTestPoint(gp.x, gp.y, true)


## Between an inside and an outside point: the outline (8 halvings: a fifth of a unit or better here).
func _edge(inside: Vector2, outside: Vector2) -> Vector2:
	for i in 8:
		var m := (inside + outside) * 0.5
		if _hit(m):
			inside = m
		else:
			outside = m
	return (inside + outside) * 0.5


## Finds the penis outline: columns from his body to the tip, each with the top and bottom edge of the art.
func scan() -> bool:
	_xs = PackedFloat32Array()
	_tops = PackedFloat32Array()
	_bots = PackedFloat32Array()
	var b: Rect2 = _art.getBounds(_penis)
	if b.size.x < 10.0 or b.size.y < 4.0:
		return false
	var mid := b.get_center().y
	var xs := PackedFloat32Array()
	var tops := PackedFloat32Array()
	var bots := PackedFloat32Array()
	var x := b.end.x - 1.0
	while x > b.position.x - 1.0:
		var c := Vector2(x, mid)
		var found := _hit(c)
		if not found:
			for d in [3.0, -3.0, 6.0, -6.0]:
				if _hit(Vector2(x, mid + d)):
					c = Vector2(x, mid + d)
					found = true
					break
		if not found:
			if xs.size() > 4:
				break   # past the tip
			x -= STEP
			continue
		var top := _edge(c, Vector2(x, b.position.y - 1.0)).y
		var bot := _edge(c, Vector2(x, b.end.y + 1.0)).y
		xs.append(x)
		tops.append(top)
		bots.append(bot)
		mid = (top + bot) * 0.5
		x -= STEP
	if xs.size() < 6:
		return false
	var last := xs.size() - 1
	tip_y = (tops[last] + bots[last]) * 0.5
	tip_x = _edge(Vector2(xs[last], tip_y), Vector2(xs[last] - STEP - 1.0, tip_y)).x
	base_x = xs[0]
	# tip first, smoothed a little (the hit masks are pictures: their edges step)
	var n := xs.size()
	for i in range(n - 1, -1, -1):
		var a := maxi(0, i - 1)
		var z := mini(n - 1, i + 1)
		_xs.append(xs[i])
		_tops.append((tops[a] + tops[i] * 2.0 + tops[z]) * 0.25)
		_bots.append((bots[a] + bots[i] * 2.0 + bots[z]) * 0.25)
	# stretched latex does not follow the dip behind the glans: from each column back towards his body it falls no
	# steeper than BRIDGE (only what lies nearer the tip carries back, so the round tip keeps its shape)
	var reach := int(40.0 / STEP)
	var t2 := _tops.duplicate()
	var b2 := _bots.duplicate()
	for i in n:
		for j in range(maxi(0, i - reach), i):
			var d := (_xs[i] - _xs[j]) * BRIDGE
			t2[i] = minf(t2[i], _tops[j] + d)
			b2[i] = maxf(b2[i], _bots[j] - d)
	# hollow corners (where the bridge meets the shaft) fill in: smoothing passes that only ever lift the latex off
	# the penis
	# (both only behind the glans front, FRONT units from its tip: its own steep round front keeps its shape)
	var f0 := 0
	while f0 < n - 1 and _xs[f0] < tip_x + FRONT:
		f0 += 1
	for _k in 8:
		for i in range(f0 + 1, n - 1):
			t2[i] = minf(t2[i], (t2[i - 1] + t2[i] * 2.0 + t2[i + 1]) * 0.25)
			b2[i] = maxf(b2[i], (b2[i - 1] + b2[i] * 2.0 + b2[i + 1]) * 0.25)
	# peaks (the glans rim) get a round top: the edge widened by a disk of radius ROUND_R, then moved back in by it
	# (round over a peak, still outside the penis everywhere)
	var w := int(ceil(ROUND_R / STEP))
	_tops = t2.duplicate()
	_bots = b2.duplicate()
	for i in range(f0, n):
		var tt := t2[i]
		var bb := b2[i]
		for j in range(maxi(f0, i - w), mini(n, i + w + 1)):
			var dx := absf(_xs[i] - _xs[j])
			if dx >= ROUND_R:
				continue
			var rise := ROUND_R - sqrt(ROUND_R * ROUND_R - dx * dx)
			tt = minf(tt, t2[j] + rise)
			bb = maxf(bb, b2[j] - rise)
		_tops[i] = tt
		_bots[i] = bb
	return true


## The latex's top and bottom edge at x (between columns: interpolated).
func edges_at(x: float) -> Vector2:
	if _xs.is_empty():
		return Vector2()
	if x <= _xs[0]:
		return Vector2(_tops[0], _bots[0])
	for i in range(1, _xs.size()):
		if _xs[i] >= x:
			var t := (x - _xs[i - 1]) / (_xs[i] - _xs[i - 1])
			return Vector2(lerpf(_tops[i - 1], _tops[i], t), lerpf(_bots[i - 1], _bots[i], t))
	return Vector2(_tops[-1], _bots[-1])


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## Draws the condom from the tip to x = cover_x (rolled rim there). roll: 0 at the tip .. 1 rolled on (the rim's
## thickness). col: its colour; alpha: how dense the latex is (0..1).
func draw(cover_x: float, roll: float, col: Color, alpha: float) -> void:
	var gr := sprite.graphics
	gr.clear()
	if _xs.is_empty():
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var line := Color(col.r * 0.45, col.g * 0.45, col.b * 0.5, 0.85 * alpha)
	var fill := _a(col, 0.5 * alpha)
	var edge := _a(col, 0.55 * alpha)
	var shine := Color(1, 1, 1, 0.9 * alpha)
	# the outline of the latex: top edge from the rim to the tip, round the tip, bottom edge back to the rim
	var xs := PackedFloat32Array()
	for x in _xs:
		if x < cover_x:
			xs.append(x)
	xs.append(cover_x)
	var n := xs.size()
	var tops := PackedVector2Array()
	var bots := PackedVector2Array()
	for x in xs:
		var e := edges_at(x)
		tops.append(Vector2(x, e.x))
		bots.append(Vector2(x, e.y))
	var tip := Vector2(tip_x, tip_y)
	var contour := PackedVector2Array()
	for i in range(n - 1, -1, -1):
		contour.append(tops[i])
	contour.append(tip)
	for i in n:
		contour.append(bots[i])
	contour = _offset(contour, OUT)
	var top_o := contour.slice(0, n)
	top_o.reverse()                       # tip first again
	var tip_o: Vector2 = contour[n]
	var bot_o := contour.slice(n + 1)
	# the whole outline (top edge from the rim, round the tip, bottom edge back); it has a small corner at the glans tip
	# (where the last column meets the tip point): there its points are at most a unit apart and smoothed
	var outline := _subdivide(contour, 1.0, tip_o, TIP_SMOOTH * 1.5)
	var ti := 0
	for k in outline.size():
		if outline[k].distance_squared_to(tip_o) < outline[ti].distance_squared_to(tip_o):
			ti = k
	var arc := PackedFloat32Array()
	arc.resize(outline.size())
	for k in range(ti + 1, outline.size()):
		arc[k] = arc[k - 1] + outline[k].distance_to(outline[k - 1])
	for k in range(ti - 1, -1, -1):
		arc[k] = arc[k + 1] + outline[k].distance_to(outline[k + 1])
	for _k in 12:
		var sm := outline.duplicate()
		for k in range(1, outline.size() - 1):
			if arc[k] < TIP_SMOOTH:
				sm[k] = (outline[k - 1] + outline[k] * 2.0 + outline[k + 1]) * 0.25
		outline = sm
	_outline = outline
	_arc = arc
	_ti = ti
	# the outline's part round the tip, closed across the penis (the sack needs only this: less work every tick)
	_tip_poly = PackedVector2Array()
	var a0 := ti
	var a1 := ti
	while a0 > 0 and outline[a0 - 1].distance_to(outline[ti]) < TIP_POLY_R:
		a0 -= 1
	while a1 < outline.size() - 1 and outline[a1 + 1].distance_to(outline[ti]) < TIP_POLY_R:
		a1 += 1
	_tip_poly = outline.slice(a0, a1 + 1)
	# where the shine strips start: past the glans tip's round front
	var i0 := n - 1
	for i in n:
		if tip_y - tops[i].y >= FLARE_H and bots[i].y - tip_y >= FLARE_H:
			i0 = i
			break
	# the fill: one polygon (closed across the rim), all one density
	var tri := Geometry2D.triangulate_polygon(outline)
	var po := pts.size()
	pts.append_array(outline)
	for q in outline:
		cols.append(fill)
	for k in tri:
		idx.append(po + k)
	# the latex looks denser towards its sides (seen at a slant): a band inside the outline fading inwards
	var runs := _cut(outline, outline[ti], cut_r)   # (round the tip the bulb draws them, round the sack and the sleeve)
	for q in runs:
		_strip(pts, cols, idx, q, [-EDGE_W, 0.0], [_a(edge, 0.0), edge])
	# the shine: a strip along the top (and a faint one along the bottom), fading in from the glans and out towards
	# the rim
	var len_x := maxf(1.0, cover_x - tip_x)
	for band in [[0.09, 0.15, 0.22, 0.31, 1.0], [0.8, 0.85, 0.87, 0.91, 0.3]]:
		var so := pts.size()
		for i in range(i0, n):
			var u := (xs[i] - tip_x) / len_x
			var sh: float = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.75, 1.0, u)) * (0.75 + 0.25 * sin(u * 9.0)) * band[4]
			var cs := [_a(shine, 0.0), _a(shine, shine.a * 0.5 * sh), _a(shine, shine.a * sh), _a(shine, 0.0)]
			for k in 4:
				pts.append(top_o[i].lerp(bot_o[i], band[k]))
				cols.append(cs[k])
		for i in n - 1 - i0:
			for k in 3:
				var a := so + i * 4 + k
				idx.append_array([a, a + 4, a + 1, a + 1, a + 4, a + 5])
	# the outline: a band along it (line -> fade)
	for q in runs:
		_strip(pts, cols, idx, q, [0.0, 0.25, LINE, LINE + FADE], [_a(line, 0.0), line, line, _a(line, 0.0)])
	# the rolled rim: thicker the less is unrolled
	var rr := lerpf(RING_MAX, RING_R, clampf(roll, 0.0, 1.0))
	_ring(pts, cols, idx, cover_x, rr, col, alpha)
	gr.setMesh(pts, cols, idx)


## The polyline with points added so no two neighbours within r of c are more than d apart.
static func _subdivide(p: PackedVector2Array, d: float, c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in p.size():
		if i > 0 and (p[i].distance_to(c) < r or p[i - 1].distance_to(c) < r):
			var steps := int(ceil(p[i].distance_to(p[i - 1]) / d))
			for k in range(1, steps):
				out.append(p[i - 1].lerp(p[i], float(k) / steps))
		out.append(p[i])
	return out


## The polyline moved d outwards along its normals (outside: the side on the right going along it, y down; the
## contours here run along the top edge towards the tip, round it and back along the bottom).
static func _offset(p: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := p.size()
	for i in n:
		var a := p[maxi(0, i - 1)]
		var b := p[mini(n - 1, i + 1)]
		var t := (b - a).normalized()
		out.append(p[i] + Vector2(-t.y, t.x) * d)
	return out


## A band along a polyline: at each point, vertices at these distances along its outward normal, in these colours.
func _strip(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, p: PackedVector2Array,
		offs: Array, cs: Array) -> void:
	var o := pts.size()
	var n := p.size()
	var w := offs.size()
	for i in n:
		var a := p[maxi(0, i - 1)]
		var b := p[mini(n - 1, i + 1)]
		var t := (b - a).normalized()
		var nv := Vector2(-t.y, t.x)
		for k in w:
			pts.append(p[i] + nv * offs[k])
			cols.append(cs[k])
	for i in n - 1:
		for k in w - 1:
			var a := o + i * w + k
			idx.append_array([a, a + w, a + 1, a + 1, a + w, a + w + 1])


## The rolled rim at x: a tube round the penis seen from the side, half thickness rr: a straight band across it that
## stands out past the sleeve's outline (more while it is still rolled up), its ends rounded.
func _ring(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, x: float, rr: float, col: Color,
		alpha: float) -> void:
	var e := edges_at(x)
	var stick := OUT + LINE + RING_OUT + (rr - RING_R) * 0.5
	var t := e.x - stick
	var bt := e.y + stick
	var body := Color(col.r * 0.9, col.g * 0.9, col.b * 0.9, 0.95 * alpha)
	var dark := Color(col.r * 0.45, col.g * 0.45, col.b * 0.5, alpha)
	var lit := Color(lerpf(col.r, 1.0, 0.7), lerpf(col.g, 1.0, 0.7), lerpf(col.b, 1.0, 0.7), alpha)
	var clear := _a(dark, 0.0)
	# across x: fade, dark edge, lit, body, dark edge, fade (the tube's shading)
	var xs := [-rr - FADE, -rr, -rr * 0.35, rr * 0.3, rr, rr + FADE]
	var cs := [clear, dark, lit, body, dark, clear]
	# along y: a half circle of radius rr at each end, straight between
	var ys := PackedFloat32Array()
	var ws := PackedFloat32Array()   # the band's half width there, as a share of rr
	var cap := 6
	for j in cap + 1:
		var a := PI * 0.5 * (1.0 - float(j) / cap)
		ys.append(t + rr - rr * sin(a))
		ws.append(cos(a))
	for j in cap + 1:
		var a := PI * 0.5 * float(j) / cap
		ys.append(bt - rr + rr * sin(a))
		ws.append(cos(a))
	var o := pts.size()
	var nn := xs.size()
	for j in ys.size():
		for k in nn:
			var off: float = xs[k]
			var w := ws[j]
			# the fade keeps its width as the cap narrows (soft edge all round)
			var px := signf(off) * (minf(absf(off), rr) * w + maxf(0.0, absf(off) - rr))
			var py := ys[j] + (FADE * (-1.0 if j < cap + 1 else 1.0) if absf(off) > rr and w < 0.5 else 0.0)
			pts.append(Vector2(x + px, py))
			cols.append(cs[k])
	for j in ys.size() - 1:
		for k in nn - 1:
			var a := o + j * nn + k
			idx.append_array([a, a + nn, a + 1, a + 1, a + nn, a + nn + 1])


## The sack's weight: a mass (the latex and the cum in it, `mass`: 0..1 is empty..full) on an elastic latex link
## from his tip, in stage coordinates. Real gravity for the size of his penis; the latex stretches under the weight
## (a full one hangs SACK_L units further than its rest length `length`, units), damped along the link and by the
## air, so a heavy one hangs lower, bounces slower and swings longer. It cannot go up through his penis (contact
## stops the motion into it). Call once per tick while there is cum in it; r: the bulb's radius (units).
func step_sack(length: float, r: float, mass: float) -> void:
	if _outline.size() < 8:
		return
	var neck := _neck(r)
	var a: Vector2 = _penis.localToGlobal(neck[0])
	var unit := _penis.localToGlobal(neck[0] + Vector2(-1, 0)).distance_to(a)   # stage pixels per penis unit
	var g := GRAVITY_CM / CM_PER_UNIT * unit / 900.0   # stage pixels per tick per tick (30 ticks a second)
	var m := SACK_MASS0 + (1.0 - SACK_MASS0) * clampf(mass, 0.0, 1.0)
	var k := g / (SACK_L * unit)                       # the latex: the full weight (1) stretches it SACK_L units
	var l0 := maxf(0.5, length) * unit
	var c_link := 2.0 * SACK_ZETA * sqrt(k)            # damping along the link (lighter: more damped)
	var c_air := SACK_AIR * sqrt(g / (l0 + SACK_L * unit)) * (0.3 + 0.7 * r / BULB_R)   # drag grows with its size
	var fresh := not sack_ok
	if not sack_ok:
		sack_p = a + Vector2(0, l0 + m * g / k)
		sack_v = Vector2.ZERO
		sack_a0 = a
		sack_g = Vector2(0, g)
		sack_ok = true
	var va := a - sack_a0   # how far his tip moved this tick (the link's far end, moved in steps)
	var v0 := sack_v
	var dt := 1.0 / SACK_STEPS
	for i in SACK_STEPS:
		var an := sack_a0 + va * (float(i + 1) / SACK_STEPS)
		var d := sack_p - an
		var l := maxf(0.001, d.length())
		var dir := d / l
		var f := Vector2(0, m * g) - sack_v * c_air
		var st := l - l0
		if st > 0.0:   # (latex only pulls)
			var fs := k * st
			var over := st - SACK_L * unit * SACK_STRETCH
			if over > 0.0:
				fs += k * over * 3.0   # stretched very far it gets much stiffer
			f -= dir * (fs + c_link * (sack_v - va).dot(dir))
		sack_v += f / m * dt
		sack_p += sack_v * dt
		_contact(r)
	sack_a0 = a
	# what the cum inside feels: gravity less the sack's own acceleration (it sloshes when it swings), eased a little
	sack_g = sack_g.lerp(Vector2(0, g) - (sack_v - v0), 0.5)
	# on his penis, for drawing between this tick and the last
	var pe1: Vector2 = _penis.globalToLocal(sack_p)
	var g1: Vector2 = (_penis.globalToLocal(sack_g) - _penis.globalToLocal(Vector2.ZERO)).normalized()
	_pe0 = pe1 if fresh else _pe1
	_g0 = g1 if fresh else _g1
	_pe1 = pe1
	_g1 = g1


## Keeps the weight from going up through his penis: behind his tip it stays below the shaft's bottom edge (plus
## most of the bulb's radius); the motion into the shaft stops there, and some of the motion along it.
func _contact(r: float) -> void:
	var p: Vector2 = _penis.globalToLocal(sack_p)
	var e := edges_at(p.x)
	if p.x <= tip_x - r * 0.3 or p.y >= e.y + r * 0.8:
		return
	p.y = e.y + r * 0.8
	var np: Vector2 = _penis.localToGlobal(p)
	var nrm := (_penis.localToGlobal(p + Vector2(0, 1)) - np).normalized()   # out of the shaft, downwards
	sack_p = np
	var vn := sack_v.dot(nrm)
	if vn < 0.0:
		sack_v -= nrm * vn
		sack_v -= (sack_v - nrm * sack_v.dot(nrm)) * 0.2   # friction


## The sack drawn on every rendered frame between the last two ticks (like his penis, which Godot glides between
## ticks): its weight and what the cum feels, eased between their tick values on his penis. Drawn again only when
## that moved or set_bulb changed something, and at most once per screen refresh (more frames do not show).
class _Drawer:
	extends Node
	var c

	func _process(_delta: float) -> void:
		c._frame()


## What draw_bulb draws with (the plugin calls this when one of them changes); r 0: nothing.
func set_bulb(r: float, col: Color, alpha: float, cum: Color) -> void:
	_bulb_args = [r, col, alpha, cum]
	_bulb_need = true
	if _drawer == null:
		_drawer = _Drawer.new()
		_drawer.c = self
		(Engine.get_main_loop() as SceneTree).root.add_child(_drawer)


## Takes the per-frame drawing away (the plugin is switched off).
func free_drawer() -> void:
	if _drawer != null:
		_drawer.queue_free()
		_drawer = null


func _frame() -> void:
	if _bulb_args.is_empty() or bulb.parent == null:
		return
	var f := Engine.get_physics_interpolation_fraction() if FlashRectClip.smooth and not g.gamePaused else 1.0
	var pe := _pe0.lerp(_pe1, f)
	var dn := _g0.lerp(_g1, f).normalized()
	var key := Vector4(pe.x, pe.y, dn.x * 50.0, dn.y * 50.0)   # (a turn of about a degree counts like a unit)
	var now := Time.get_ticks_usec()
	if not _bulb_need:
		if key.distance_squared_to(_drawn_at) < 0.0025:
			return   # (still)
		if now - _drawn_us < _frame_us():
			return   # (the screen would not show it)
	_drawn_at = key
	_drawn_us = now
	_bulb_need = false
	draw_bulb(_bulb_args[0], _bulb_args[1], _bulb_args[2], _bulb_args[3], pe, dn)


## The shortest time between two drawings: one screen refresh (a little less, so none is missed).
func _frame_us() -> int:
	if _refresh_us < 0:
		var hz := DisplayServer.screen_get_refresh_rate()
		_refresh_us = int(1000000.0 / clampf(hz if hz > 0.0 else 144.0, 30.0, 500.0) * 0.9)
	return _refresh_us


## Where the sack hangs from: the glans tip (the penis's outermost point; the latex wraps it tightly). Returns that
## point and the neck's half width.
func _neck(r: float) -> Array:
	return [_outline[_ti], clampf(r * 0.16, 1.8, 4.0)]


## Draws the cum in the tip: the latex sack, a pear from the lowest point of the glans front to the weight
## (step_sack), round at the bottom (radius r; 0: none), the cum pooled there (cum: its colour; level flat, the sack
## above it clear). col / alpha: the latex's, as in draw().
func draw_bulb(r: float, col: Color, alpha: float, cum: Color, pe: Vector2, down: Vector2) -> void:
	var gr := bulb.graphics
	gr.clear()
	if r <= 0.0 or _outline.size() < 8 or not sack_ok:
		return
	var neck := _neck(r)
	var tip_o: Vector2 = neck[0]
	var rn: float = neck[1]
	# a teardrop (like a hanging glass drop): a thin neck from the tip (it starts inside the glans, so it comes out of
	# the latex over the tip), widening in an S-curve to its widest line round the weight, then a round bottom
	var top := tip_o + Vector2(rn + 1.5, 0.0)
	var ax := pe - top
	var zc := maxf(r, ax.length())
	ax = ax.normalized() if ax.length() > 0.001 else down
	var pp := Vector2(-ax.y, ax.x)
	var n := 20
	var wid := PackedFloat32Array()
	for i in n + 1:
		var u := pow(float(i) / n, TEAR_K)
		wid.append(lerpf(rn, r, (1.0 - cos(PI * u)) * 0.5))   # parallel at the neck and at the widest line
	var sack := PackedVector2Array()
	for i in n + 1:
		sack.append(top + ax * zc * float(i) / n + pp * wid[i])
	var cn := maxi(16, int(r * 1.6))
	for j in range(1, cn):
		var th := PI * float(j) / cn   # round the bottom from one side to the other
		sack.append(pe + (pp * cos(th) + ax * sin(th)) * r)
	for i in range(n, -1, -1):
		sack.append(top + ax * zc * float(i) / n - pp * wid[i])
	if _signed_area(sack) * _signed_area(_outline) < 0.0:
		sack.reverse()   # the same way round as the outline (outwards normals on the same side)
	for _k in 2:   # rounds the corners where the sides meet the bulb
		var sm := sack.duplicate()
		var m := sack.size()
		for i in m:
			sm[i] = (sack[(i + m - 1) % m] + sack[i] * 2.0 + sack[(i + 1) % m]) * 0.25
		sack = sm
	# the latex inside it, outside the penis
	var fill := _biggest(Geometry2D.clip_polygons(sack, _tip_poly))
	if fill.size() < 3:
		return
	# the cum: what of it lies below a flat level a little above the bulb's middle
	var side := Vector2(-down.y, down.x) * 400.0
	var lv := pe - down * r * 0.45
	var below := PackedVector2Array([lv - side, lv + side, lv + side + down * 400.0, lv - side + down * 400.0])
	var pool := _biggest(Geometry2D.intersect_polygons(fill, below))
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	if pool.size() >= 3:
		var tri := Geometry2D.triangulate_polygon(pool)
		for q in pool:
			var sh := clampf(1.0 - 0.15 * (q - pe).dot(down) / r, 0.7, 1.0)   # linear: no streaks along the triangles
			pts.append(q)
			cols.append(Color(cum.r * sh, cum.g * sh, cum.b * sh, 0.85))
		for k in tri:
			idx.append(k)
		# its surface: a light line along the level
		var surf := PackedVector2Array()
		for q in pool:
			if absf((q - lv).dot(down)) < 0.2:
				surf.append(q)
		if surf.size() == 2:
			_strip(pts, cols, idx, surf, [-1.2, 0.0, 1.2], [Color(1, 1, 1, 0), Color(1, 1, 1, 0.5 * alpha),
				Color(1, 1, 1, 0)])
	var tri2 := Geometry2D.triangulate_polygon(fill)
	var po := pts.size()
	pts.append_array(fill)
	for q in fill:
		cols.append(_a(col, 0.5 * alpha))   # (as dense as the sleeve's latex: no step where they meet)
	for k in tri2:
		idx.append(po + k)
	# the edge and outline: one line round the sleeve and the sack together, near the tip (where the sleeve leaves
	# its own out) and along the sack
	var webs := []
	var outer := _joined_edge(sack, tip_o, top, pe, r, webs)
	for w in webs:   # the latex stretched into the corners
		var wt := Geometry2D.triangulate_polygon(w)
		var wo := pts.size()
		pts.append_array(w)
		for q in w:
			cols.append(_a(col, 0.5 * alpha))
		for kk in wt:
			idx.append(wo + kk)
	var line := Color(col.r * 0.45, col.g * 0.45, col.b * 0.5, 0.85 * alpha)
	var edge := _a(col, 0.55 * alpha)
	if outer.size() >= 2:
		_strip(pts, cols, idx, outer, [-EDGE_W, 0.0], [_a(edge, 0.0), edge])
		_strip(pts, cols, idx, outer, [0.0, 0.25, LINE, LINE + FADE], [_a(line, 0.0), line, line, _a(line, 0.0)])
	# a shine on the bulb, on its side away from gravity
	var sc := pe - down * r * 0.45 + Vector2(-down.y, down.x) * r * 0.35
	var o := pts.size()
	pts.append(sc)
	cols.append(Color(1, 1, 1, 0.7 * alpha))
	var m2 := 14
	for i in m2:
		var f := TAU * float(i) / m2
		pts.append(sc + Vector2(cos(f) * r * 0.14, sin(f) * r * 0.3).rotated(atan2(down.y, down.x) - PI * 0.5 + 0.4))
		cols.append(Color(1, 1, 1, 0.0))
	for i in m2:
		idx.append_array([o, o + 1 + i, o + 1 + (i + 1) % m2])
	gr.setMesh(pts, cols, idx)


## The line p with its inner corners near the sack (within r + 2 of the line from top to pe) bridged the way
## stretched latex bridges them: each sharp inner corner is cut off by a smooth curve, a web of radius WEB x r (at
## least WEB_MIN). The webs (the latex between corner and curve) go into webs as polygons.
func _fillet(p: PackedVector2Array, r: float, top: Vector2, pe: Vector2, webs: Array) -> PackedVector2Array:
	var n := p.size()
	if n < 5:
		return p
	var rad := maxf(WEB_MIN, r * WEB)
	var arc := PackedFloat32Array()
	arc.resize(n)
	for i in range(1, n):
		arc[i] = arc[i - 1] + p[i].distance_to(p[i - 1])
	# the corners: where the line turns outwards (an inner corner of the shape) by more than 20 degrees, measured over
	# 3 units each side; the sharpest of each bunch
	var corners := []   # [index, turn]
	var j := 0
	var k := 0
	for i in range(1, n - 1):
		while j < i and arc[i] - arc[j + 1] >= 3.0:
			j += 1
		while k < n - 1 and arc[k] - arc[i] < 3.0:
			k += 1
		if arc[i] - arc[j] < 1.5 or arc[k] - arc[i] < 1.5:
			continue
		var a := (p[i] - p[j]).normalized()
		var b := (p[k] - p[i]).normalized()
		if b.dot(Vector2(-a.y, a.x)) <= 0.0:
			continue   # turns inwards: an outer corner
		var turn := acos(clampf(a.dot(b), -1.0, 1.0))
		if turn < 0.35:
			continue
		if Geometry2D.get_closest_point_to_segment(p[i], top, pe).distance_to(p[i]) > r + 2.0:
			continue
		if not corners.is_empty() and arc[i] - arc[corners[-1][0]] < 6.0:
			if turn > corners[-1][1]:
				corners[-1] = [i, turn]
			continue
		corners.append([i, turn])
	if corners.is_empty():
		return p
	var out := p
	corners.reverse()   # (from the end: the indices before stay right)
	for cn in corners:
		var i: int = cn[0]
		var wedge: float = PI - cn[1]   # the empty angle in the corner
		var l := minf(rad / tan(wedge * 0.5), rad * 2.0)
		l = minf(l, minf(arc[i], arc[n - 1] - arc[i]) * 0.9)
		var i1 := i
		while i1 > 0 and arc[i] - arc[i1] < l:
			i1 -= 1
		var i2 := i
		while i2 < n - 1 and arc[i2] - arc[i] < l:
			i2 += 1
		var t1 := out[i1]
		var t2 := out[i2]
		var d1 := (out[mini(i1 + 1, i)] - t1).normalized()        # along the line towards the corner
		var d2 := (t2 - out[maxi(i2 - 1, i)]).normalized()        # and away from it
		var cl := t1.distance_to(t2) * 0.45
		var curve := PackedVector2Array()
		var steps := maxi(4, int(t1.distance_to(t2) / 1.5))
		for s2 in range(1, steps):
			var t := float(s2) / steps
			var u := 1.0 - t
			curve.append(t1 * u * u * u + (t1 + d1 * cl) * 3.0 * u * u * t + (t2 - d2 * cl) * 3.0 * u * t * t + t2 * t * t * t)
		var web := out.slice(i1, i2 + 1)
		var back := curve.duplicate()
		back.reverse()
		web.append_array(back)
		webs.append(web)
		var nw := out.slice(0, i1 + 1)
		nw.append_array(curve)
		nw.append_array(out.slice(i2))
		out = nw
	return out


## The outline of the sleeve and the sack as one shape (their union), the part of it within cut_r of the tip c or
## along the sack (near the line from top to pe), as an open line ending where it meets the sleeve's own outline
## on the circle of radius cut_r; its inner corners rounded.
func _joined_edge(sack: PackedVector2Array, c: Vector2, top: Vector2, pe: Vector2, r: float,
		webs: Array) -> PackedVector2Array:
	var u0 := _biggest(Geometry2D.merge_polygons(_tip_poly, sack))
	var u := PackedVector2Array()
	for q in u0:   # (the union has points very close together here and there: they would make the line jagged)
		if u.is_empty() or q.distance_squared_to(u[-1]) > 0.25:
			u.append(q)
	var m := u.size()
	if m < 3:
		return PackedVector2Array()
	if _signed_area(u) * _signed_area(_outline) < 0.0:
		u.reverse()
	var keep := PackedByteArray()
	keep.resize(m)
	var start := -1
	var rr := cut_r * cut_r
	for i in m:
		var q := u[i]
		var k := q.distance_squared_to(c) <= rr 			or Geometry2D.get_closest_point_to_segment(q, top, pe).distance_to(q) <= r + 1.5
		keep[i] = 1 if k else 0
		if not k:
			start = i
	if start < 0:
		return PackedVector2Array()
	var best := PackedVector2Array()
	var cur := PackedVector2Array()
	var prev := u[start]
	for k in range(1, m + 1):
		var i := (start + k) % m
		if keep[i] == 1:
			if cur.is_empty():
				cur.append(_on_circle(prev, u[i], c))
			cur.append(u[i])
		elif not cur.is_empty():
			cur.append(_on_circle(u[i], cur[-1], c))
			if cur.size() > best.size():
				best = cur
			cur = PackedVector2Array()
		prev = u[i]
	var w0 := webs.size()
	best = _fillet(best, r, top, pe, webs)
	for i in range(webs.size() - 1, w0 - 1, -1):   # only what is outside the sleeve and sack (no fill drawn twice)
		var parts := Geometry2D.clip_polygons(webs[i], u0)
		webs.remove_at(i)
		for q in parts:
			if q.size() >= 3:
				webs.append(q)
	for _k in 2:   # small corners left: rounded (the ends stay on the sleeve's line)
		var sm := best.duplicate()
		for i in range(1, best.size() - 1):
			sm[i] = (best[i - 1] + best[i] * 2.0 + best[i + 1]) * 0.25
		best = sm
	return best


## Where the segment from a (outside the circle of radius cut_r round c) to b (inside) crosses that circle; a when
## a is not outside it.
func _on_circle(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var da := a.distance_to(c)
	var db := b.distance_to(c)
	if da <= cut_r or db >= cut_r:
		return a if da <= cut_r else b
	return a.lerp(b, (da - cut_r) / (da - db))


## The open line p without what lies within rad of c: the pieces outside, each ending exactly on that circle.
static func _cut(p: PackedVector2Array, c: Vector2, rad: float) -> Array:
	if rad <= 0.0:
		return [p]
	var out := []
	var cur := PackedVector2Array()
	for i in p.size():
		var inside := p[i].distance_to(c) < rad
		if i > 0 and inside != (p[i - 1].distance_to(c) < rad):
			var a := p[i - 1]
			var b := p[i]
			var da := a.distance_to(c) - rad
			var db := b.distance_to(c) - rad
			var x := a.lerp(b, da / (da - db))
			cur.append(x)
			if inside:
				out.append(cur)
				cur = PackedVector2Array()
		if not inside:
			cur.append(p[i])
	if cur.size() >= 2:
		out.append(cur)
	return out.filter(func(q): return q.size() >= 2)


static func _biggest(parts: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	for q in parts:
		if absf(_signed_area(q)) > absf(_signed_area(best)):
			best = q
	return best


static func _signed_area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		s += p[i].x * q.y - q.x * p[i].y
	return s
