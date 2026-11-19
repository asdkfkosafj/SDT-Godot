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
const HIT_POINTS := 16     # points round the bulb tested against her
const HIT_OUT := 0.35      # how much of its depth in her it comes out per physics step (out within a tick)
const SACK_MAX_LEN := 2.5  # it never stretches further than this many full-weight stretches
const HIT_OUT_MAX := 1.5   # ... but no more than this (units) per step
const HIT_MU := 0.6        # held: the rubbing on her skin slows its sliding over her by this x gravity
const SACK_IN := 0.6       # he is in her mouth, the sack still out: the latex over her lip pulls it up to her lip, and
                           # it squeezes in once his tip is past her lip by its rest length and this many full
                           # stretches (SACK_L)
# In her mouth the sack is a soft bag of cum in front of his tip, pressed into the room there: her mouth, then past
# her throat ring her throat (narrower). It is on one side of the ring or the other, never across it.
const MOUTH_ROOM := 1.5    # the room in her mouth in front of his tip: this many half widths of his glans
const THROAT_ROOM := 0.8   # in her throat: this many (it opens round the sack only so far)
const POP_BASE := 6.0      # pulled out, it is stuck behind her ring while the latex to it stretches: it pops out at
const POP_K := 1.2         #   this stretch (units) plus this many times its radius (a bigger one: stuck longer)
const PULL_MAX := 0.04     # the stretched latex pulls her head back to him: this much (her speed per tick) at the pop
                           #   for a full one, growing with the square of the stretch (soft at first: a steep pull
                           #   stops her head in a tick and it bounces back, a shiver); the grip holds her
const IN_AT := 0.35        # pushed in, it goes through her ring once pressed this much of its length
const PUSH_MAX := 0.02     # and holds her head back that far (her speed per tick) just before, for a full one (also
                           #   with the square: soft at first)
const PUSH_CUM_TICKS := 10.0  # while he cums it pushes her head back not at all: its push goes away / comes back over
                              #   this many ticks (no jerk)
const HOLD := 0.5          # while stuck or pressed it also slows her head that way by this much (no shaking)
const LUMP := 1.4          # a full one in her throat: this many swallow lumps (Neck.bumps, size 10 each)
const LIP_TICKS := 10.0    # squeezing in through her lips and sliding along under him to his tip takes this many ticks
const LIP_ROOM := 0.6      # under him in her mouth it is this many glans half widths high (squeezed by her tongue)
const PASS_TICKS := 6.0    # going through her throat ring (out or in) takes this many ticks: through, then the latex
                           #   springs back
const POP_HOLD := 5.0      # pulled past its limit it pops only once it stays there this many ticks, plus
const POP_HOLD_K := 14.0   #   this many for a full one (a quick yank drags her head along instead)
const POP_SNAP := 2.6      # pulled this far past its limit (times it) it pops at once
const HOLD_PAST := 1.2     # past its limit it holds her head still (away from him) this much more per unit past it
                           #   (up to 0.95)
const RELEASE_TICKS := 12.0  # through her ring (out or in) its hold on her head lets go over this many ticks (no jerk:
                             #   her head eases to where it is pulled, also once he is out of her mouth)
const PRESS_RISE := 8.0    # pressed against her ring its hold on her head builds up over at least this many ticks
const DAMP_IN := 0.6       # stuck, it slows her head's spring back towards him by this much (no bouncing)
const PROF_STEP := 1.5     # its shape in her mouth: half widths every this many units ahead of his tip
const BASE_W := 0.55       # where it leaves his tip it is this many of his glans' half widths wide (the latex there)
const RING_W := 0.3        # through her throat ring: this many
const NECK_LEAVE := 0.7   # the empty latex from his glans to her ring leaves his glans where it is this many of its
                           #   half widths wide, along it, and curves in (concave) to lie along him at her ring
const NECK_JOIN := 0.3     # his tip in her throat: the curve from his glans joins the sack's side this share of the
                           #   way to its widest line
const NECK_W := 0.2        # stuck past her ring: the empty latex from his glans to it is pulled tight: at her ring
                           #   this many glans half widths (held tight there; 30 % thinner at the pop)
const BUNCH := 0.15        # pulled up against her ring the cum bunches up: this much shorter at the pop (so wider: the
const BUNCH_TOP := 0.4     #   same cum), its widest line moving up from its middle to this share of its length
const EXTRA_R := 4.0       # the x-ray view gets its outline as circles this big (Him.tipExtra)
const PROF_SMOOTH := 4     # smoothing passes over its shape (soft, no corners where its parts meet)
const PASS_FREE_TICKS := 10  # a held sack let go on her bounces off her again once off her this many ticks in a row
const PASS_MARGIN := 1.2   # ... "off her": nothing of her within this many bulb radii of its middle (and its neck)
const HIT_FRICTION := 0.15 # how much of its sliding along her it loses per physics step
const SQUASH_PRESS := 1.2  # this much pushing into her (as a share of gravity, per tick) squashes it fully
const SQUASH_MAX := 0.35   # fully squashed it is flat this far in (share of its radius)
const JET_K := 0.3         # a spurt's cum shoots into the sack this much as fast as it would fly out (the latex in the
#   way), in penis units per tick for the game's stage pixels per tick (its speed: 25 to 40)
const JET_REF := 40.0      # ... in a sack this long from his tip to the cum (in any other the same time: shares of it)
const JET_DRAG := 0.9      # ... and keeps this much of its speed each tick (the latex and the cum in it slow it)
const JET_V_MIN := 2.0     # ... but goes on at least this fast
const JET_W := 1.0         # the stream's half width: this many of the neck's half widths for a strand link as thick as
#   1 (a link's thickness as cum strands draw it: its mass and the cum strand thickness setting)
const RIPPLE_HIT := 0.35   # a stream going into the cum sets its level rippling: this much (of the most) per link,
const RIPPLE_DECAY := 0.9  #   dying down to this much each tick;
const RIPPLE_A := 0.06     #   the most: waves this high (share of the bulb's radius),
const RIPPLE_L := 0.7      #   this long (share of it),
const RIPPLE_W := 1.2      #   moving out from where it went in this fast (radians per tick)
const SACK_STRETCH := 1.5  # past this much of the full weight's stretch the latex gets much stiffer

var sprite: FlashSprite
var bulb: FlashSprite      # the cum in its tip (its own sprite: drawn again only when the cum or the colour changes)
var tipline: FlashSprite   # the sack's outline where it runs along the sleeve round his tip: in his penis (with it under
                           # her head while he is), the rest of the sack above her head (bulb)
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
var hit_n := Vector2()                 # her contact (_her_contact): out of her, stage coordinates
var hit_d := 0.0                       # how deep in her, stage pixels (0: free)
var hit_p := Vector2()                 # where the weight was then
var mouth_state := 0                   # 0: he is out of her mouth; 1: in, the sack still out (it hangs from her lower
                                       # lip, the latex over it); 2: the sack is in her mouth too (in front of his tip)
var _lt0 := Vector2(NAN, NAN)          # state 1: her lower lip on his penis, last tick and this tick (else NAN)
var _lt1 := Vector2(NAN, NAN)
var past := false                      # state 2: it is past her throat ring (in her throat)
var stretch := 0.0                     # stuck behind her ring as he pulls out: how far the latex to it is stretched
var press := 0.0                       # pushed against her ring from her mouth: how far it is pressed
var drag_add := 0.0                    # this tick's pull on her head (Her.drag: < 0 back to him, > 0 away)
var grip_out := 0.0                    # this tick's share of her head's speed away from him it takes (Her.drag)
var grip_in := 0.0                     # and towards him
var bumps := []                        # its lump in her neck (Neck.bumps)
var pops := 0                          # how often it went through her throat ring (out or in)
var _web_reach := INF                  # _fillet: webs only this near his tip
var _cum_polys := []                   # state 2, apart from his tip: where its cum is (penis-local; empty: all of it)
var _pass_t := -1.0                    # going through her throat ring: 0..1 (-1: not)
var _pass_out := false                 # ... out into her mouth (else in, down her throat)
var _hold := Vector3()                 # stuck or pressed: its hold on her head this tick (drag_add, grip_out, grip_in)
var _rel := Vector3()                  # that as it went through her ring, let go over RELEASE_TICKS
var _rel_t := 0.0                      # ticks of letting go left
var _push_k := 1.0                     # how much of its push on her head it gives (0 while he cums)
var _press_f := 0.0                    # pressed: its hold on her head so far (0..1, PRESS_RISE)
var _strain := 0.0                     # stuck: ticks it has been pulled past its limit
var _lip_t := -1.0                     # state 1: squeezing in through her lips: 0..1 (-1: not yet)
var lip_a := 0.0                       # ... how far along him the part in her mouth is (0 her lip .. 1 ahead of his tip)
var _in_bag := PackedVector2Array()    # state 1: the part in her mouth (penis-local)
var _neck_tan := PackedVector2Array() # the neck's lines leave his glans here, top and bottom (penis-local; empty: none)
var _neck_top := PackedVector2Array() # ... and run on from there to his tip (top and bottom, back to front)
var _neck_bot := PackedVector2Array()
var cum_from := 0.0                    # state 2: the cum in it starts this far ahead of his tip (stuck: past her ring)
var in_share := 0.0                    # state 1: how much of it is in her mouth already (0..1: it goes in bit by bit)
var _sh0 := 0.0                        # that, last tick and this tick
var _sh1 := 0.0
var prof := PackedFloat32Array()       # state 2: its half width every PROF_STEP units ahead of his tip (empty: none)
var _free_ticks := 0                   # ticks the let-go sack has been off her
var passing := false                   # held, or let go while still on her: no push out, it rubs over her
var on_her := false                    # some of the bulb lies over her (_her_contact)
var _face_prev := Vector2()            # her face last tick (stage coordinates): what the held bulb rubs against
var squash := 0.0                      # how flat the bulb is pressed against her (0..1)
var _hn0 := Vector2()                  # the contact's direction on his penis, last tick and this tick
var _hn1 := Vector2()
var _sq0 := 0.0                        # the squash, last tick and this tick
var _sq1 := 0.0
var _drawn_at := Vector4()
var _pe0 := Vector2()                  # the weight on his penis last tick and this tick (drawn between them)
var _pe1 := Vector2()
var _g0 := Vector2(0, 1)               # what the cum feels, on his penis, last tick and this tick
var _g1 := Vector2(0, 1)
var _bulb_args := []                   # set_bulb's
var _bulb_need := false
var _drawn_us := 0
var _refresh_us := -1
var jets := []             # the links of spurts in the sack, flying to the cum, oldest first: [along the path last tick,
#   this tick, speed (shares of the path), half width (share of the neck's), spurt (one stream), ticks since it came]
var _rip0 := 0.0           # the cum's level rippling (0..1), last tick and this tick
var _rip1 := 0.0
var _rip_t := 0.0          # ticks it has been rippling (the waves move on with it)
var _jet_top := Vector2()  # their path (penis-local, as last drawn): from the sack's top along _jet_ax,
var _jet_ax := Vector2()
var _jet_len := 0.0        #   this far to the cum's level (0: no sack drawn hanging free: none shown)
var _jet_f := 1.0          # (this frame's share of the way from last tick to this tick)
var _drawer: Node = null             # where the bulb was last drawn (penis units) and gravity there


func _init() -> void:
	sprite = FlashSprite.new()
	sprite.mouseEnabled = false
	sprite.mouseChildren = false
	bulb = FlashSprite.new()
	bulb.mouseEnabled = false
	bulb.mouseChildren = false
	tipline = FlashSprite.new()
	tipline.mouseEnabled = false
	tipline.mouseChildren = false


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
	if tipline.parent != penis:
		if tipline.parent != null:
			tipline.parent.removeChild(tipline)
		penis.addChildAt(tipline, penis.getChildIndex(sprite) + 1)
	elif penis.getChildIndex(tipline) != penis.getChildIndex(sprite) + 1:
		penis.setChildIndex(tipline, mini(penis.numChildren - 1, penis.getChildIndex(sprite) + 1))
	# the sack: above her head, moved with his penis (he is below her head while his penis is not out over her face,
	# but the sack outside her mouth is always in front of her: lying on her chin it shows): in the front layer where
	# the game puts him when his penis is out, right above him then (under her right arm, front hair and his arm)
	var host: FlashSprite = g.frontLayer if g.frontLayer != null else penis.parent
	var fresh := bulb.parent != host
	if fresh and bulb.parent != null:
		bulb.parent.removeChild(bulb)
	var bi := -1 if fresh else host.getChildIndex(bulb)
	var want := 0
	if g.him != null and g.him.parent == host:
		var hi := host.getChildIndex(g.him)
		want = hi if bi >= 0 and bi < hi else hi + 1   # (right above him; taken out from below him, he moves down one)
	if fresh:
		host.addChildAt(bulb, want)
	elif bi != want:
		host.setChildIndex(bulb, want)
	bulb.transform = host.flash_global_transform().affine_inverse() * penis.flash_global_transform()   # (Flash space: x-ray draws him offscreen)
	if fresh:
		bulb.reset_physics_interpolation()


func detach() -> void:
	_bulb_args = []
	for sp in [sprite, bulb, tipline]:
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
		offs: Array, cs: Array, before := Vector2(NAN, NAN), after := Vector2(NAN, NAN)) -> void:
	var o := pts.size()
	var n := p.size()
	var w := offs.size()
	for i in n:   # (before / after: the line's points past its ends, for its ends' directions where it goes on)
		var a := p[i - 1] if i > 0 else (before if not is_nan(before.x) else p[0])
		var b := p[i + 1] if i < n - 1 else (after if not is_nan(after.x) else p[n - 1])
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
		mouth_state = 2 if _him_in_mouth() else 0   # (his first cum in her mouth: the sack starts in it)
	# in her mouth: while the sack is still out it hangs from her lower lip (the latex runs from his tip over it, the
	# part in her mouth used up); it goes in once he is in deep enough, and then sits in front of his tip. When he
	# comes out it slips out after him over her lip, and lies on her until it is off her (no push out).
	var st0 := mouth_state
	var mouth := _him_in_mouth()
	var lip := _lip()
	var used := 0.0
	if mouth and mouth_state == 0:
		mouth_state = 1
		_lip_t = -1.0
		sack_a0 = lip   # (the link now ends at her lip: no sweep from his tip)
	elif not mouth and mouth_state != 0:
		if mouth_state == 2:
			var outw := (_penis.localToGlobal(neck[0] + Vector2(1, 0)) - a).normalized()   # along him, away from her
			sack_p = lip + (outw * 0.5 + Vector2(0, 1)) * r * unit   # (just out, below her lower lip)
			sack_v = a - sack_a0
		mouth_state = 0
		_lip_t = -1.0
		_pass_t = -1.0
		sack_a0 = a
		passing = true
		_free_ticks = 0
	in_share = 0.0
	lip_a = 0.0
	var hoist := 0.0   # state 1: how far the latex over her lip has pulled it up to her lip (0..1)
	if mouth_state == 1:   # as he goes in, the latex over her lip pulls it up to her lip; then it squeezes in
		used = a.distance_to(lip)
		hoist = clampf((used - l0) / maxf(1.0, SACK_L * unit * SACK_IN), 0.0, 1.0)
		if _lip_t < 0.0 and hoist >= 1.0:
			_lip_t = 0.0
			_squeeze_sound(mass)
		if _lip_t >= 0.0:
			_lip_t += 1.0 / LIP_TICKS
			in_share = smoothstep(0.0, 0.55, _lip_t)   # through her lips, then along under him to his tip
			lip_a = smoothstep(0.15, 1.0, _lip_t)
			if _lip_t >= 1.0:
				mouth_state = 2
				in_share = 0.0
				lip_a = 0.0
				_lip_t = -1.0
			else:
				m *= 1.0 - in_share * 0.9   # (what is still out is lighter)
	var anc := lip if mouth_state == 1 else a
	var va := anc - sack_a0   # how far the link's end moved this tick (moved in steps)
	var v0 := sack_v
	var dt := 1.0 / SACK_STEPS
	var push := 0.0         # how much motion into her the contact took this tick
	# held (left click): it does not bounce off her but slides over her face, rubbing (friction against her skin,
	# which moves with her head); let go while it lies on her, it goes on so until it is off her (no push out)
	if _held():
		passing = true
		_free_ticks = 0
	elif passing:
		_free_ticks = 0 if _near_her(near_points(a, r, neck[1], unit)) else _free_ticks + 1
		if _free_ticks >= PASS_FREE_TICKS:
			passing = false   # off her for a while: it bounces off her again
	var held := passing
	var fp := _face_at()
	var vface := fp - _face_prev if not fresh else Vector2.ZERO
	_face_prev = fp
	var rub := HIT_MU * g * dt
	var cap := HIT_OUT_MAX * unit
	var l_rest := maxf(0.0, l0 - used)
	var steps := SACK_STEPS
	if mouth_state == 2:   # in her mouth: in front of his tip, pressed into the room there (_throat)
		steps = 0
	for i in steps:
		var an := sack_a0 + va * (float(i + 1) / SACK_STEPS)
		var d := sack_p - an
		var l := maxf(0.001, d.length())
		var dir := d / l
		var f := Vector2(0, m * g) - sack_v * c_air
		var st := l - l_rest
		if st > 0.0:   # (latex only pulls)
			var fs := k * st
			var over := st - SACK_L * unit * SACK_STRETCH
			if over > 0.0:
				fs += k * over * 3.0   # stretched very far it gets much stiffer
			f -= dir * (fs + c_link * (sack_v - va).dot(dir))
		sack_v += f / m * dt
		sack_p += sack_v * dt
		var dl := sack_p - an
		var lmax := maxf(0.0, l0 + SACK_L * unit * SACK_MAX_LEN - used)
		if hoist > 0.0:   # (pulled up to her lip)
			lmax = minf(lmax, lerpf(SACK_L * unit * SACK_MAX_LEN, r * unit * 0.8, hoist))
		if dl.length() > lmax:   # (a safety net: the latex never stretches further than this)
			var dd := dl.normalized()
			sack_p = an + dd * lmax
			var vo := (sack_v - va).dot(dd)
			if vo > 0.0:
				sack_v -= dd * vo
		if mouth_state == 0:
			_contact(r)
		if held:
			if on_her:
				var vr := sack_v - vface
				sack_v = vface if vr.length() <= rub else sack_v - vr.normalized() * rub
		elif hit_d > 0.0:   # her: as deep as found this tick, less what it moved out since; out over the tick, no deeper
			var deep := hit_d - (sack_p - hit_p).dot(hit_n)
			if deep > 0.0:
				sack_p += hit_n * minf(deep * HIT_OUT, cap)   # (deep in her after a held click: glides out)
				var vn := sack_v.dot(hit_n)
				if vn < 0.0:
					sack_v -= hit_n * vn
					push -= vn
				sack_v -= (sack_v - hit_n * sack_v.dot(hit_n)) * HIT_FRICTION
	sack_a0 = anc
	_her_contact(r * unit)
	# the squash: how hard it pressed against her this tick, for its weight, eased
	var press := clampf(push / maxf(0.001, g * SQUASH_PRESS), 0.0, 1.0) if hit_d > 0.0 and not held else 0.0
	squash = lerpf(squash, press, 0.35)
	# what the cum inside feels: gravity less the sack's own acceleration (it sloshes when it swings), eased a little
	sack_g = sack_g.lerp(Vector2(0, g) - (sack_v - v0), 0.5)
	# on his penis, for drawing between this tick and the last
	_throat(r, unit)
	fresh = fresh or mouth_state != st0   # (in or out of her mouth: drawn at once where it is now, no gliding over her)
	var pe1: Vector2 = _penis.globalToLocal(sack_p)
	var g1: Vector2 = (_penis.globalToLocal(sack_g) - _penis.globalToLocal(Vector2.ZERO)).normalized()
	_pe0 = pe1 if fresh else _pe1
	_g0 = g1 if fresh else _g1
	_pe1 = pe1
	_g1 = g1
	var hn1: Vector2 = (_penis.globalToLocal(hit_n) - _penis.globalToLocal(Vector2.ZERO)).normalized() 		if hit_n != Vector2.ZERO else _hn1
	_hn0 = hn1 if fresh else _hn1
	_hn1 = hn1
	_sq0 = squash if fresh else _sq1
	_sq1 = squash
	var lt1: Vector2 = _penis.globalToLocal(lip) if mouth_state == 1 else Vector2(NAN, NAN)
	_lt0 = lt1 if fresh or is_nan(_lt1.x) else _lt1
	_lt1 = lt1
	_sh0 = in_share if fresh else _sh1
	_sh1 = in_share


## The sack in her mouth (state 2): a soft bag of cum (area pi r^2, units) in front of his tip, pressed into the room
## there; on one side of her throat ring (RING_DEPTH) or the other. In her mouth it is a blob; pushed against her ring
## it is pressed flat and holds her head back a little, until pressed IN_AT of its length: then it goes through at
## once. In her throat it is pressed long and thin and goes along with his tip; as he pulls out past her ring it is
## stuck behind it, and the latex from his tip to it stretches, pulling her head back to him the more it is
## stretched (a bigger one harder, and further); stretched POP_BASE + POP_K r it pops out at once (a wet sound; a full
## one makes her wince, and gag if gagging is on). In her throat it makes a swallow lump in her neck. Sets prof (its
## shape) and sack_p (its middle). r: its radius (units); unit: stage px per unit.
func _throat(r: float, unit: float) -> void:
	grip_out = 0.0
	grip_in = 0.0
	drag_add = 0.0
	stretch = 0.0
	press = 0.0
	bumps = []
	var her = g.her
	cum_from = 0.0
	_cum_polys = []
	_in_bag = PackedVector2Array()
	_neck_tan = PackedVector2Array()
	_neck_top = PackedVector2Array()
	_neck_bot = PackedVector2Array()
	if _rel_t > 0.0:   # just through her ring: its hold lets go bit by bit
		_rel_t -= 1.0
		var kk := smoothstep(0.0, RELEASE_TICKS, _rel_t)
		drag_add = _rel.x * kk
		grip_out = _rel.y * kk
		grip_in = _rel.z * kk
	var cumming: bool = g.him != null and g.him.ejaculating
	_push_k = move_toward(_push_k, 0.0 if cumming else 1.0, 1.0 / PUSH_CUM_TICKS)
	var press_was := _press_f   # (set again below while it is pressed)
	_press_f = 0.0
	var part_in := mouth_state == 2 or (mouth_state == 1 and in_share > 0.0)   # (state 1: what is in her mouth so far)
	if not part_in or her == null or r <= 0.0:
		past = false
		_pass_t = -1.0
		_strain = 0.0
		prof.clear()
		return
	var hs: float = her.localToGlobal(Vector2(1, 0)).distance_to(her.localToGlobal(Vector2.ZERO))   # px per her unit
	var k := hs / maxf(0.001, unit)                  # units per her unit
	var d: float = maxf(0.0, her.penisInMouthDist) * k   # his tip's depth in her
	var ring: float = her.throatRing() * k
	var e := edges_at(tip_x + 12.0)
	var glans := maxf(2.0, (e.y - e.x) * 0.5)
	var full := minf(1.0, r * r / (BULB_R * BULB_R))
	var v := PI * r * r
	var wm := minf(r, glans * MOUTH_ROOM)            # the half widths it takes in her mouth / her throat
	var wt := minf(r, glans * THROAT_ROOM)
	var len_m := _len(v, wm)
	var len_t := _len(v, wt)
	if mouth_state == 1:   # squeezing in through her lips: under him, from her lip along to his tip
		prof.clear()
		past = false
		var vb := v * in_share
		var wb := lerpf(minf(r, glans * LIP_ROOM), wm, smoothstep(0.6, 1.0, lip_a))
		var lb := _len(vb, wb)
		var hb := vb / (PI * lb * 0.5)
		var lip_l := _penis.globalToLocal(_lip())
		var xc := lerpf(lip_l.x - lb * 0.5, tip_x - len_m * 0.5, lip_a)
		var ey := edges_at(clampf(xc, tip_x, lip_l.x)).y
		var yc := lerpf(ey, tip_y, smoothstep(tip_x + 15.0, tip_x - len_m * 0.25, xc))   # (round his tip to its front)
		for q in 72:   # (close enough together for the x-ray view's circles: no gaps)
			var th := TAU * q / 72.0
			_in_bag.append(Vector2(xc + cos(th) * lb * 0.5, yc + sin(th) * hb))
		return
	var l := ring - d                                # the room between his tip and her ring (< 0: his tip past it)
	var pop_at := POP_BASE + POP_K * r
	if _pass_t >= 0.0:   # going through her ring
		_pass_t += 1.0 / PASS_TICKS
		if _pass_t >= 1.0:
			_pass_t = -1.0
	elif past and l > 0.0:   # stuck behind her ring: the latex to it stretches as he pulls out
		stretch = maxf(0.0, l - len_m * (1.0 - IN_AT))   # (its slack: the room it had as it went in)
		var f := stretch / pop_at
		_strain = _strain + 1.0 if f >= 1.0 else maxf(0.0, _strain - 1.0)
		if f >= POP_SNAP or _strain >= POP_HOLD + POP_HOLD_K * full:   # held past its limit (or yanked): out
			_let_go()
			past = false
			_strain = 0.0
			_pass_t = 0.0
			_pass_out = true
			_pop(her, full, true)
		elif stretch > 0.0:   # past its limit it holds her head nearly still: a quick pull drags her along
			drag_add = -PULL_MAX * pow(full, 0.7) * pow(minf(f, 1.0), 2.0)   # (no stronger past it, and not eased: no rocking)
			grip_out = minf(0.95, HOLD * minf(f, 1.0) + HOLD_PAST * maxf(0.0, f - 1.0))
			grip_in = DAMP_IN * minf(f, 1.0)
			_hold = Vector3(drag_add, grip_out, grip_in)
	elif not past:
		_strain = 0.0
		if l <= 0.0:
			past = true   # (his tip is past her ring: it is too)
			_pop(her, full, false)
		elif len_m > l:   # pushed against her ring
			press = len_m - l
			if press >= IN_AT * len_m:
				_let_go()
				past = true
				press = 0.0
				_pass_t = 0.0
				_pass_out = false
				_pop(her, full, false)
			else:   # (it may come in already pressed: its hold builds up over PRESS_RISE ticks, no bounce)
				var f := minf(press / (IN_AT * len_m), press_was + 1.0 / PRESS_RISE)
				_press_f = f
				drag_add = PUSH_MAX * pow(full, 0.7) * f * f * _push_k   # (none while he cums)
				grip_in = HOLD * f
				_hold = Vector3(drag_add, grip_out, grip_in)
	# its shape along him: bags [from, length, half width, widest at (share of its length)] ahead of his tip, and a
	# funnel [to, widest, at her ring, how much] from his tip into her ring: what is pressed into it, still this side
	var base := 0.0                                  # where it leaves his tip: the latex there
	var bags := []
	var funnel := []
	var pull := minf(1.0, stretch / pop_at)          # stuck: how hard it is pulled (1: its limit)
	var below := -1                                  # the bag past her ring, if any
	var w_ring := maxf(1.0, glans * NECK_W)          # held tight in her ring
	var lr := maxf(PROF_STEP * 2.0, l)               # the room to her ring
	var fp := clampf(press / maxf(0.001, IN_AT * len_m), 0.0, 1.0)   # how hard it is pressed (1: it goes through)
	if _pass_t >= 0.0:   # going through: what has gone through on the other side, the rest still this side
		var t := _pass_t
		var sv := smoothstep(0.0, 0.6, t)            # the share through
		var vb := v * (sv if not _pass_out else 1.0 - sv)   # past her ring
		var va := v - vb                             # her mouth's side
		if vb > 1.0:
			var lb := _len(vb, wt)
			bags.append([lr, lb, vb / (PI * lb * 0.5), 0.5])
			below = 0
		if va > 1.0 and _pass_out:
			var la := _len(va, wm)
			var from_a := lerpf(maxf(0.0, lr - la), 0.0, smoothstep(0.35, 1.0, t))   # against her ring, then the
			bags.append([from_a, la, va / (PI * la * 0.5), 0.5])                    # latex springs back to his tip
		elif va > 1.0:   # going in: the rest a funnel into her ring, thinner and thinner
			funnel = [lr, _funnel_w(va, lr, w_ring, glans), w_ring, 1.0]
	elif past:
		var lt := len_t * (1.0 - BUNCH * pull)       # pulled up against her ring: shorter and wider, the same cum
		bags = [[maxf(0.0, l), lt, v / (PI * lt * 0.5), lerpf(0.5, BUNCH_TOP, pull)]]
		below = 0
	elif press > 0.0:   # pressed flat against her ring: shorter and wider, and the harder, the more a funnel into it
		bags = [[0.0, lr, minf(glans * MOUTH_ROOM * 1.15, v / (PI * lr * 0.5)), 0.5]]
		funnel = [lr, _funnel_w(v, lr, w_ring, glans), w_ring, smoothstep(0.0, 1.0, fp)]
	else:
		bags = [[0.0, len_m, minf(wm, sqrt(v / PI)), 0.5]]
	var gap := INF                                   # how far past his tip it starts
	var end := 0.0
	for bg in bags:
		gap = minf(gap, bg[0])
		end = maxf(end, bg[0] + bg[1])
	if not funnel.is_empty():
		gap = 0.0
		end = maxf(end, funnel[0])
	if gap <= 0.0:
		base = minf(glans * BASE_W, bags[-1][2] if not bags.is_empty() else funnel[1])
	prof.clear()
	var sx := 0.0
	while sx <= end + 0.001:
		var h := 0.0
		for bg in bags:
			if sx >= bg[0]:
				h = maxf(h, bg[2] * _bag((sx - bg[0]) / bg[1], bg[3]))
		if gap <= 0.0 and sx <= end * 0.5 and bags.size() == 1 and below < 0:
			h = maxf(h, base)
		if not funnel.is_empty() and sx <= funnel[0]:
			var q: float = sx / funnel[0]
			h = lerpf(h, lerpf(funnel[2], funnel[1], 1.0 - q * q), funnel[3])
		prof.append(h)
		sx += PROF_STEP
	for _k in PROF_SMOOTH:   # soft: no corners where the parts meet (its ends stay)
		var sm := prof.duplicate()
		for i in range(1, prof.size() - 1):
			sm[i] = (prof[i - 1] + prof[i] * 2.0 + prof[i + 1]) * 0.25
		prof = sm
	var neck_to := gap if gap > 0.0 else (lr if _pass_t >= 0.0 else 0.0)
	if neck_to > 0.0:
		# from his glans to it the latex is empty and pulled tight: straight from her ring, where it is held tight, to
		# where it touches his glans (none of its cum spreads this way); going through her ring, what is still this
		# side lies in it
		var w_tube := maxf(1.0, glans * NECK_W * (1.0 - 0.3 * pull))
		var rx := tip_x - neck_to
		# each side curves in from his glans to lie along him at her ring
		var curves := _neck_curves(glans, [Vector2(rx, tip_y - w_tube), Vector2(rx, tip_y + w_tube)], [Vector2(-1, 0),
			Vector2(-1, 0)])
		var past_ring := true   # (just past her ring the bag is no thinner than the ring: no notch)
		for i in prof.size():
			var x := PROF_STEP * i
			if x <= neck_to:
				var w := maxf(_curve_w(curves[0], tip_x - x), _curve_w(curves[1], tip_x - x))
				prof[i] = w if gap > 0.0 and _pass_t < 0.0 else maxf(prof[i], w)
			elif past_ring and prof[i] < w_tube:
				prof[i] = w_tube
			else:
				past_ring = false
		if _pass_t >= 0.0:   # going through: no thinner than her ring, from his tip on through it
			for i in prof.size():
				if PROF_STEP * i > lr and prof[i] >= w_tube:
					break
				prof[i] = maxf(prof[i], w_tube)
		for bg in bags:   # its cum: each part's own
			_cum_polys.append(_bag_poly(bg))
		if not funnel.is_empty():
			_cum_polys.append(_funnel_poly(funnel))
	elif past and gap <= 0.0 and not bags.is_empty() and prof.size() >= 4:
		# his tip in her throat, the sack right ahead of it: each side curves in from his glans and out again into the
		# sack's side (a waist, concave)
		var bg: Array = bags[0]
		var it := clampi(int(round((bg[0] + bg[1] * bg[3] * NECK_JOIN) / PROF_STEP)), 2, prof.size() - 2)
		var xt := PROF_STEP * it
		var slope := (prof[it + 1] - prof[it - 1]) / (2.0 * PROF_STEP)   # (its widening, forward)
		var curves := _neck_curves(glans, [Vector2(tip_x - xt, tip_y - prof[it]), Vector2(tip_x - xt, tip_y + prof[it])],
			[Vector2(-1, -slope), Vector2(-1, slope)])
		for i in it:
			var x := PROF_STEP * i
			prof[i] = maxf(_curve_w(curves[0], tip_x - x), _curve_w(curves[1], tip_x - x))
	var cs := 0.0
	var ca := 0.0
	for i in prof.size():
		cs += PROF_STEP * i * prof[i]
		ca += prof[i]
	var mid := cs / maxf(0.001, ca)                  # its middle, along him
	cum_from = gap
	sack_p = _penis.localToGlobal(Vector2(tip_x - mid, tip_y))
	sack_v = Vector2.ZERO
	if below >= 0:   # in her throat: a swallow lump in her neck at its widest (bigger as it bunches up)
		var bb: Array = bags[below]
		var share: float = bb[2] * bb[1] * 0.5 * PI / v
		var dm: float = d + bb[0] + bb[1] * bb[3]
		bumps = [{"at": dm / k / 400.0, "size": 10.0 * LUMP * sqrt(full * share) * (1.0 + 0.6 * pull)}]


## The latex's sides from his glans on ahead of his tip, top and bottom: each leaves his glans where that is
## NECK_LEAVE of its half width wide, along it, and curves (quadratic: no corner at either end) to ends[i], arriving
## along dirs[i] (forward). Sets _neck_tan / _neck_top / _neck_bot (the parts behind his tip go with the shape's start).
func _neck_curves(glans: float, ends: Array, dirs: Array) -> Array:
	var curves := []
	for k in 2:
		var sd := -1.0 if k == 0 else 1.0
		var gx := tip_x + 0.5
		var ge := edges_at(gx)
		while gx < tip_x + 60.0 and gx < base_x:
			ge = edges_at(gx)
			if absf((ge.x if sd < 0.0 else ge.y) - tip_y) >= glans * NECK_LEAVE:
				break
			gx += 0.5
		var ea := edges_at(gx + 1.0)
		var eb := edges_at(gx - 1.0)
		var p0 := Vector2(gx, ge.x if sd < 0.0 else ge.y)
		var t0 := Vector2(-2.0, (eb.x - ea.x) if sd < 0.0 else (eb.y - ea.y))   # (forward, along his glans)
		var p2: Vector2 = ends[k]
		var t2: Vector2 = dirs[k]
		var p1 := p0.lerp(p2, 0.5)   # (where the two ways meet; else halfway)
		var den := t0.cross(t2)
		if absf(den) > 0.0001:
			var a := (p2 - p0).cross(t2) / den
			var q := p0 + t0 * a
			if a > 0.0 and (p2 - q).dot(t2) > 0.0:
				p1 = q
		p1.x = clampf(p1.x, p2.x, p0.x)
		var cv := PackedVector2Array()
		for q in 41:
			var u := q / 40.0
			cv.append(p0.lerp(p1, u).lerp(p1.lerp(p2, u), u))
		curves.append(cv)
	_neck_tan = PackedVector2Array([curves[0][0], curves[1][0]])
	_neck_top = PackedVector2Array()
	_neck_bot = PackedVector2Array()
	for q in curves[0]:
		if q.x > tip_x:
			_neck_top.append(q)
	for q in curves[1]:
		if q.x > tip_x:
			_neck_bot.append(q)
	return curves


## A neck curve's half width (from tip_y) at x (penis-local; the curve runs from back to front).
func _curve_w(cv: PackedVector2Array, x: float) -> float:
	for i in range(1, cv.size()):
		if cv[i].x <= x:
			var a := cv[i - 1]
			var b := cv[i]
			var t := (a.x - x) / maxf(0.0001, a.x - b.x)
			return absf(lerpf(a.y, b.y, t) - tip_y)
	return absf(cv[cv.size() - 1].y - tip_y)


## A bag's outline (penis-local, ahead of his tip), a unit bigger all round: bg as in _throat.
func _bag_poly(bg: Array) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for q in 25:
		var u := q / 24.0
		var hh: float = bg[2] * _bag(u, bg[3]) + 1.0
		var xx: float = tip_x - bg[0] - u * (bg[1] + 1.0)
		top.append(Vector2(xx, tip_y - hh))
		bot.append(Vector2(xx, tip_y + hh))
	bot.reverse()
	top.append_array(bot)
	return top


## A funnel's widest (at his tip) for the cum vol in it, to `to`, wr wide at her ring (_throat).
static func _funnel_w(vol: float, to: float, wr: float, glans: float) -> float:
	return clampf(wr + (vol / (2.0 * to) - wr) * 1.5, wr, glans * MOUTH_ROOM * 1.15)


## A funnel's outline (penis-local, ahead of his tip), a unit bigger all round: fn as in _throat.
func _funnel_poly(fn: Array) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for q in 25:
		var u := q / 24.0
		var hh: float = lerpf(fn[2], fn[1], 1.0 - u * u) + 1.0
		var xx: float = tip_x + 1.0 - u * (fn[0] + 1.0)
		top.append(Vector2(xx, tip_y - hh))
		bot.append(Vector2(xx, tip_y + hh))
	bot.reverse()
	top.append_array(bot)
	return top


## It went through her ring: its last hold on her head lets go over RELEASE_TICKS (from this tick on).
func _let_go() -> void:
	_rel = _hold
	_rel_t = RELEASE_TICKS
	drag_add = _rel.x
	grip_out = _rel.y
	grip_in = _rel.z
	_hold = Vector3()


## A bag's half width along it (u: 0 at its front .. 1 its back), widest (1) at c: a quarter ellipse each side of c.
static func _bag(u: float, c: float) -> float:
	var q := (u - c) / c if u <= c else (u - c) / (1.0 - c)
	return sqrt(maxf(0.0, 1.0 - q * q))


## The length a blob of area v takes with at most half width w (an ellipse).
static func _len(v: float, w: float) -> float:
	var b := minf(w, sqrt(v / PI))
	return 2.0 * v / (PI * maxf(0.001, b))


## It went through her throat ring at once: out (popped back into her mouth) or in (on down her throat).
func _pop(her, full: float, out: bool) -> void:
	pops += 1
	if out:
		g.soundControl.playUp(her.pos, 20.0 + 25.0 * full)
		if full > 0.4 and not her.passedOut:
			her.wince()
			if full > 0.6 and g.gagging:
				g.soundControl.playGag(her.pos)
	else:
		g.soundControl.playDown(her.pos, 15.0 + 25.0 * full)


## Something of it is in her mouth (state 1 squeezing in, or state 2).
func has_inside() -> bool:
	return (mouth_state == 1 and _in_bag.size() >= 3) or (mouth_state == 2 and not prof.is_empty())


## Its outline in her mouth (state 2): from prof, along him from his tip (penis-local), closed.
func _inside_shape() -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var n := prof.size()
	if _neck_tan.size() == 2:   # its neck leaves his glans along its curves
		top.append_array(_neck_top if not _neck_top.is_empty() else PackedVector2Array([_neck_tan[0]]))
		bot.append_array(_neck_bot if not _neck_bot.is_empty() else PackedVector2Array([_neck_tan[1]]))
	for i in n:
		var x := tip_x + 3.0 - PROF_STEP * i if i == 0 and _neck_tan.is_empty() else tip_x - PROF_STEP * i   # (starts
		top.append(Vector2(x, tip_y - prof[i]))   # inside the glans)
		bot.append(Vector2(x, tip_y + prof[i]))
	var cap := tip_x - PROF_STEP * (n - 1)
	bot.reverse()
	top.append(Vector2(cap - 0.6, tip_y))
	top.append_array(bot)
	return top


## Its outline for the x-ray view (Him.tipExtra), penis-local: small circles along both its sides (a big circle in
## its middle would reach past its ends).
func tip_extra() -> Array:
	var out := []
	if mouth_state == 1:   # squeezing in: round its outline
		_loop_circles(_in_bag, out)
		return out
	for i in prof.size():
		var h: float = prof[i]
		var rr := minf(h, EXTRA_R)
		var x := tip_x - PROF_STEP * i
		out.append({"x": x, "y": tip_y - h + rr, "r": rr})
		if h > rr:
			out.append({"x": x, "y": tip_y + h - rr, "r": rr})
	return out


## Circles (EXTRA_R at most) just inside the closed loop poly, one per point (Him.tipExtra), appended to out.
static func _loop_circles(poly: PackedVector2Array, out: Array) -> void:
	if poly.size() < 3:
		return
	var c := Vector2.ZERO
	for q in poly:
		c += q / poly.size()
	for q in poly:
		var dv := q - c
		var rr := minf(dv.length(), EXTRA_R)
		out.append({"x": q.x - dv.normalized().x * rr, "y": q.y - dv.normalized().y * rr, "r": rr})


## The wet sound of it squeezing in through her lips (mass: 0..1 full).
static func _squeeze_sound(mass: float) -> void:
	if g.her != null:
		g.soundControl.playDown(g.her.pos, 8.0 + 15.0 * mass)


## He is in her mouth.
static func _him_in_mouth() -> bool:
	return g.him != null and g.him.inMouth


## Her lower lip, stage coordinates (where the game's mouth line ends).
static func _lip() -> Vector2:
	return g.her.head.jaw.localToGlobal(g.her.bottomLipA) if g.her != null else Vector2.ZERO


## The left button is held (she is held on him).
static func _held() -> bool:
	return g.her != null and g.her.mouseHeld


## A point of her face, stage coordinates (how her head moves).
static func _face_at() -> Vector2:
	return g.her.head.face.localToGlobal(Vector2.ZERO) if g.her != null else Vector2.ZERO


## Her body parts that can touch the sack, those whose bounds meet `box` (stage coordinates): her whole head (not
## only the strands' face and jaw: with her mouth open her cheek and jaw-back parts make her chin), eyewear, worn
## costume parts, breast and chest.
static func _her_parts(box: Rect2) -> Array:
	var h = g.her
	var out := []
	var all := [h.head, h.eyewear, h.torso.midLayer.rightBreast.hitArea, h.torso.midLayer.chest]
	for e in g.costumeHitElements:
		if e.showing:
			all.append(e)
	for o in all:
		if o != null and o.visible and (o.getBounds(Flash.stage) as Rect2).intersects(box):
			out.append(o)
	return out


## The points tested for "the let-go sack is still on her": a ring a little outside the bulb, its middle, and
## points down its neck (not the top, at his tip: that is at her lips). a: his tip (stage coordinates); r, rn: the
## bulb's and the neck's radius (units); unit: stage px per unit.
func near_points(a: Vector2, r: float, _rn: float, unit: float) -> PackedVector2Array:
	var pts := PackedVector2Array([sack_p])
	for i in HIT_POINTS:
		pts.append(sack_p + Vector2.from_angle(TAU * float(i) / HIT_POINTS) * r * unit * PASS_MARGIN)
	for t in [0.4, 0.55, 0.7, 0.85]:
		pts.append(a.lerp(sack_p, t))
	return pts


## Some of her lies under one of the points pts (stage coordinates). Always true while he is in her mouth (no test:
## it may still lie on her chin; it lets go once he is out).
func _near_her(pts: PackedVector2Array) -> bool:
	if g.her == null:
		return false
	if g.him.inMouth:
		return true
	var box := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		box = box.expand(q)
	var parts := _her_parts(box)
	for q in pts:
		for o in parts:
			if o.hitTestPoint(q.x, q.y, true):
				return true
	return false


## Her body against the bulb (a circle of radius rr, stage pixels, round sack_p): 16 points round its rim tested
## against her face, jaw, eyewear, worn costume parts, breast and chest (those whose bounds come near it). Sets
## hit_n (out of her, towards the free side), hit_d (how deep the rim is in her: from the share of points inside, as
## for a straight surface) and hit_p (where it was then); hit_d 0: free. None while he is in her mouth.
func _her_contact(rr: float) -> void:
	hit_d = 0.0
	on_her = false
	var h = g.her
	if h == null or g.him.inMouth:
		return
	var parts := _her_parts(Rect2(sack_p - Vector2(rr, rr), Vector2(rr, rr) * 2.0))
	if parts.is_empty():
		return
	var sum := Vector2()
	var n := 0
	for i in HIT_POINTS:
		var u := Vector2.from_angle(TAU * float(i) / HIT_POINTS)
		var q := sack_p + u * rr
		for o in parts:
			if o.hitTestPoint(q.x, q.y, true):
				sum += u
				n += 1
				break
	if n == 0 or n == HIT_POINTS:
		for o in parts:
			if o.hitTestPoint(sack_p.x, sack_p.y, true):
				on_her = true   # (all of it on her: no way out found; the middle tells it is not round her)
				break
		if not on_her:
			return
	on_her = true
	if n == 0:
		return
	hit_n = -sum.normalized() if sum.length() > 0.001 else (hit_n if hit_n != Vector2.ZERO else Vector2(0, -1))
	hit_d = rr * (1.0 - cos(PI * float(n) / HIT_POINTS))
	hit_p = sack_p


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


## A link of a spurt shoots into the sack: speed as the game's spurt (stage pixels per tick), thickness as cum strands
## draw the link, sid: its spurt (the links of one spurt make one stream).
func spurt(speed: float, thick: float, sid: int) -> void:
	jets.append([0.0, 0.0, speed * JET_K / JET_REF, JET_W * clampf(thick, 0.4, 3.0), sid, 0])
	_bulb_need = true


## Moves the spurts in the sack on (each tick); one reaching the cum's level is gone into it.
func step_jets() -> void:
	if jets.is_empty() and _rip1 <= 0.0 and _rip0 <= 0.0:
		return
	if _jet_len <= 0.0 or mouth_state != 0:
		jets.clear()
		_rip0 = 0.0
		_rip1 = 0.0
		return
	_rip0 = _rip1
	_rip1 *= RIPPLE_DECAY
	if _rip1 < 0.01:
		_rip1 = 0.0
	_rip_t += 1.0
	var keep := []
	for j in jets:
		j[0] = j[1]
		if j[0] >= 1.0:
			continue
		j[1] = j[0] + j[2]
		j[5] += 1
		if j[1] >= 1.0:   # (into the cum: its level ripples)
			if _rip1 <= 0.0 and _rip0 <= 0.0:
				_rip_t = 0.0
			_rip1 = minf(1.0, _rip1 + RIPPLE_HIT * clampf(j[3] / JET_W, 0.4, 2.0))
		j[2] = maxf(JET_V_MIN / JET_REF, j[2] * JET_DRAG)
		keep.append(j)
	jets = keep
	_bulb_need = true


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
	var sq := lerpf(_sq0, _sq1, f)
	var hn := _hn0.lerp(_hn1, f).normalized() if _hn0 != Vector2.ZERO else _hn1
	var lt := _lt0.lerp(_lt1, f)
	var sh := lerpf(_sh0, _sh1, f)
	_jet_f = f
	if not jets.is_empty() or _rip0 > 0.0 or _rip1 > 0.0:
		_bulb_need = true   # (spurts in it, or its level rippling: every frame)
	var key := Vector4(pe.x, pe.y, dn.x * 50.0 + sq * 40.0, dn.y * 50.0 + mouth_state * 1000.0 + sh * 300.0)   # (a turn of about a
	# degree counts like a unit)
	if not is_nan(lt.x):
		key += Vector4(lt.x, lt.y, 0.0, 0.0) * 0.5
	if mouth_state == 2:   # (in her mouth its shape changes too while it stays where it is)
		var ps := 0.0
		for w in prof:
			ps += w
		key.z += ps * 0.1
	var now := Time.get_ticks_usec()
	if not _bulb_need:
		if key.distance_squared_to(_drawn_at) < 0.0025:
			return   # (still)
		if now - _drawn_us < _frame_us():
			return   # (the screen would not show it)
	_drawn_at = key
	_drawn_us = now
	_bulb_need = false
	draw_bulb(_bulb_args[0], _bulb_args[1], _bulb_args[2], _bulb_args[3], pe, dn, sq, hn, lt, mouth_state == 2, sh)


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
## above it clear). col / alpha: the latex's, as in draw(). lip: he is in her mouth, the sack still out (its neck runs
## over her lower lip there); inside: all of it is in her mouth (drawn with his penis: hidden by her, x-ray shows it).
func draw_bulb(r: float, col: Color, alpha: float, cum: Color, pe: Vector2, down: Vector2, sq := 0.0,
		hn := Vector2(), lip := Vector2(NAN, NAN), inside := false, share := 0.0) -> void:
	var gr := bulb.graphics
	gr.clear()
	tipline.graphics.clear()
	if r <= 0.0 or _outline.size() < 8 or not sack_ok:
		return
	var neck := _neck(r)
	var tip_o: Vector2 = neck[0]
	var rn: float = neck[1]
	if share > 0.0 and not is_nan(lip.x):   # going in: what is still out of her mouth (less and less, up to her lip)
		r = maxf(rn * 1.3, r * sqrt(1.0 - share))
		pe = lip.lerp(pe, 1.0 - share * share)
	# a teardrop (like a hanging glass drop): a thin neck from the tip (it starts inside the glans, so it comes out of
	# the latex over the tip), widening in an S-curve to its widest line round the weight, then a round bottom
	var top := tip_o + Vector2(rn + 1.5, 0.0)
	var from_lip := not is_nan(lip.x)   # he is in her mouth, the sack still out: its neck runs over her lower lip
	var start := lip if from_lip else top   # where the teardrop's own profile starts
	var ax := pe - start
	var zc := maxf(r, ax.length())
	ax = ax.normalized() if ax.length() > 0.001 else down
	var pp := Vector2(-ax.y, ax.x)
	var n := 20
	var wid := PackedFloat32Array()
	for i in n + 1:
		var u := pow(float(i) / n, TEAR_K)
		wid.append(lerpf(rn, r, (1.0 - cos(PI * u)) * 0.5))   # parallel at the neck and at the widest line
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	if from_lip:   # first from his tip to her lip, as thin as the neck; the sides meet on the mean of both normals
		var d1 := lip - top
		var l1 := d1.length()
		if l1 > 0.5:
			var p1 := Vector2(-d1.y, d1.x) / l1
			var m1 := maxi(2, int(l1 / 3.0))
			for i in m1:
				var c := top + d1 * float(i) / m1
				left.append(c + p1 * rn)
				right.append(c - p1 * rn)
			var pm := (p1 + pp).normalized() if (p1 + pp).length() > 0.01 else pp
			var k := rn / maxf(0.4, pm.dot(pp))
			left.append(lip + pm * k)
			right.append(lip - pm * k)
	for i in range(0 if left.is_empty() else 1, n + 1):
		left.append(start + ax * zc * float(i) / n + pp * wid[i])
		right.append(start + ax * zc * float(i) / n - pp * wid[i])
	var sack := left
	var cn := maxi(16, int(r * 1.6))
	for j in range(1, cn):
		var th := PI * float(j) / cn   # round the bottom from one side to the other
		sack.append(pe + (pp * cos(th) + ax * sin(th)) * r)
	right.reverse()
	sack.append_array(right)
	var pressed := inside and prof.size() >= 2   # in her mouth: pressed into the room there (_throat), full of cum
	if pressed:
		sack = _inside_shape()
		pe = Vector2(tip_x - PROF_STEP * (prof.size() - 1), tip_y)
	var going_in := share > 0.0 and from_lip and _in_bag.size() >= 3   # and what is in her mouth already (under him)
	var in_shape := _in_bag if going_in else PackedVector2Array()
	if going_in:
		sack = _biggest(Geometry2D.merge_polygons(sack, in_shape))
	if sq > 0.01 and hn != Vector2.ZERO and not pressed:   # pressed against her: flat on her side, a little wider along her
		var into := -hn
		var lim := r * (1.0 - SQUASH_MAX * sq)
		for i in sack.size():
			var q := sack[i] - pe
			if q.length() > r * 1.4:
				continue   # (the neck stays)
			var dd := q.dot(into)
			var tq := q - into * dd
			if dd > lim:
				dd = lim
			sack[i] = pe + into * dd + tq * (1.0 + SQUASH_MAX * sq * 0.4)
	if _signed_area(sack) * _signed_area(_outline) < 0.0:
		sack.reverse()   # the same way round as the outline (outwards normals on the same side)
	for _k in 2:   # rounds the corners where the sides meet the bulb
		var sm := sack.duplicate()
		var m := sack.size()
		for i in m:
			sm[i] = (sack[(i + m - 1) % m] + sack[i] * 2.0 + sack[(i + 1) % m]) * 0.25
		sack = sm
	# the latex inside it, outside the penis
	var cut := Geometry2D.clip_polygons(sack, _tip_poly)
	var fill := _biggest(cut)
	if fill.size() < 3:
		return
	var fill_all := [fill]   # (going in: what is still out and what is in her mouth can be apart, round his tip)
	if going_in:
		var fcw := Geometry2D.is_polygon_clockwise(fill)
		for q in cut:
			if q != fill and q.size() >= 3 and Geometry2D.is_polygon_clockwise(q) == fcw:
				fill_all.append(q)
	# in her mouth (above her lower lip, in from it along him): drawn with his penis, which her face hides there
	# (x-ray shows it with him); the rest above her head
	var mouth := PackedVector2Array()
	if from_lip:
		mouth = PackedVector2Array([lip + Vector2(0.5, 0.0), lip + Vector2(0.5, -1000.0), lip + Vector2(-3000.0, -1000.0),
			lip + Vector2(-3000.0, 0.0)])
		if going_in:   # (and what is in her mouth already)
			mouth = _biggest(Geometry2D.merge_polygons(mouth, _biggest(Geometry2D.offset_polygon(in_shape, 2.0))))
	var pts := PackedVector2Array()   # above her head (bulb)
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var tp := PackedVector2Array()    # with his penis (tipline)
	var tc := PackedColorArray()
	var tix := PackedInt32Array()
	# the cum: what of it lies below a flat level a little above the bulb's middle
	var side := Vector2(-down.y, down.x) * 400.0
	var lv := pe - down * r * 0.45
	var below := PackedVector2Array([lv - side, lv + side, lv + side + down * 400.0, lv - side + down * 400.0])
	var rip := lerpf(_rip0, _rip1, _jet_f) * RIPPLE_A * r   # (rippling: how high its waves are now)
	if rip > 0.05 and not pressed and not from_lip:
		below = _rippled(lv, down, r, rip, (top + ax * _jet_len - lv).dot(Vector2(-down.y, down.x)))
	var pools := []
	if pressed:   # all of it from where the cum starts (stuck behind her throat ring: past it, the latex this side clear)
		pools = [fill]
		if not _cum_polys.is_empty():   # each bag's own part (apart from it the latex is clear)
			pools = []
			for cp in _cum_polys:
				pools.append_array(Geometry2D.intersect_polygons(fill, cp))
	elif not going_in:
		pools = [_biggest(Geometry2D.intersect_polygons(fill, below))]
	else:   # with what is in her mouth already (one pool where they meet)
		var regions := []
		var merged := Geometry2D.merge_polygons(below, in_shape)
		var rcw := Geometry2D.is_polygon_clockwise(_biggest(merged))   # (the outer ones' way round)
		for q in merged:
			if Geometry2D.is_polygon_clockwise(q) == rcw:   # (no holes)
				regions.append(q)
		for f in fill_all:
			for rg in regions:
				pools.append_array(Geometry2D.intersect_polygons(f, rg))
	for pool in pools:
		if pool.size() < 3:
			continue
		var parts := _split(pool, mouth)
		for q in parts[1]:
			_pool(pts, cols, idx, q, pe, down, r, cum, lv, alpha, rip)
		for q in parts[0]:
			_pool(tp, tc, tix, q, pe, down, r, cum, lv, alpha, rip)
	# spurts shooting from his tip down the sack to the cum (hanging free only)
	_jet_len = 0.0
	if not from_lip and not pressed and not going_in:
		_jet_top = top
		_jet_ax = ax
		_jet_len = maxf(0.0, (lv - top).dot(down) / maxf(0.2, ax.dot(down)))
		var jw := rn * JET_W
		var blobs := []
		var streams := {}   # one stream per spurt: its links along the path, front first
		for j in jets:
			if not streams.has(j[4]):
				streams[j[4]] = []
			streams[j[4]].append(j)
		for sid in streams:
			var ls: Array = streams[sid]
			var at := PackedFloat32Array()   # along the path, front to back
			var ws := PackedFloat32Array()   # half widths there
			for j in ls:
				at.append(lerpf(j[0], j[1], _jet_f) * _jet_len)
				ws.append(rn * j[3])
			var last: Array = ls[ls.size() - 1]
			if last[5] <= 2:   # (still spurting: the stream goes on back to his tip)
				at.append(0.0)
				ws.append(rn * last[3])
			var tail := at[at.size() - 1]
			var front := at[0]
			if front - tail < 0.5:
				tail = maxf(0.0, front - ws[0] * 2.0)
				at[at.size() - 1] = tail
			var side_a := PackedVector2Array()   # the stream: its two sides, round at its front
			var side_b := PackedVector2Array()
			for i in at.size():
				side_a.append(top + ax * at[i] + pp * ws[i])
				side_b.append(top + ax * at[i] - pp * ws[i])
			var cap := PackedVector2Array()
			var hw := ws[0]   # (its front round, as wide as the stream)
			for i in 9:
				cap.append(top + ax * front + (-pp * cos(PI * i / 8.0) + ax * sin(PI * i / 8.0)) * hw)
			var body := side_a.duplicate()
			for i in range(1, 6):   # (a round back end)
				body.append(top + ax * tail + (pp * cos(PI * i / 6.0) - ax * sin(PI * i / 6.0)) * ws[ws.size() - 1])
			side_b.reverse()
			body.append_array(side_b)
			blobs.append(cap)
			blobs.append(body)
		for cap in blobs:
			for q in Geometry2D.intersect_polygons(cap, fill):   # (in the sack, above the cum's level)
				for q2 in Geometry2D.clip_polygons(q, below):
					if q2.size() >= 3:
						_pool(pts, cols, idx, q2, pe, down, r, cum, lv - down * 4000.0, alpha)
	var latex := _a(col, 0.5 * alpha)   # (as dense as the sleeve's latex: no step where they meet)
	var fills := _split(fill, mouth)
	for k in range(1, fill_all.size()):
		var more := _split(fill_all[k], mouth)
		fills[0].append_array(more[0])
		fills[1].append_array(more[1])
	# the edge and outline: one line round the sleeve and the sack together, near the tip (where the sleeve leaves
	# its own out) and along the sack
	var webs := []
	var stuck := pressed and cum_from > 0.0   # (the tube leaves his tip in a wide web; none at her ring)
	_web_reach = cum_from * 0.5 if stuck else INF
	var outer := _joined_edge(sack, tip_o, top, pe, r * (2.5 if stuck else 1.0), webs)
	_web_reach = INF
	for w in webs:   # the latex stretched into the corners
		var wp := _split(w, mouth)
		fills[0].append_array(wp[0])
		fills[1].append_array(wp[1])
	for q in fills[1]:
		_poly(pts, cols, idx, q, latex)
	for q in fills[0]:
		_poly(tp, tc, tix, q, latex)
	var line := Color(col.r * 0.45, col.g * 0.45, col.b * 0.5, 0.85 * alpha)
	var edge := _a(col, 0.55 * alpha)
	if outer.size() >= 2:
		# the parts along the sleeve round his tip go with his penis (tipline), the sack's own with the sack (but in
		# her mouth with his penis too); each run takes the point where the next one starts too (no gap)
		var near := _biggest(Geometry2D.offset_polygon(sack, 1.5))
		var on_sack := PackedByteArray()
		on_sack.resize(outer.size())
		for i in outer.size():
			var q := outer[i]
			on_sack[i] = 1 if Geometry2D.is_point_in_polygon(q, near) and not (from_lip
				and Geometry2D.is_point_in_polygon(q, mouth)) else 0
		var i0 := 0
		while i0 < outer.size() - 1:
			var i1 := i0
			while i1 < outer.size() - 1 and on_sack[i1 + 1] == on_sack[i0]:
				i1 += 1
			var j1 := mini(outer.size(), i1 + 2)
			var run := outer.slice(i0, j1)
			var bf := outer[i0 - 1] if i0 > 0 else Vector2(NAN, NAN)
			var af := outer[j1] if j1 < outer.size() else Vector2(NAN, NAN)
			if run.size() >= 2:
				if on_sack[i0] == 1:
					_strip(pts, cols, idx, run, [-EDGE_W, 0.0], [_a(edge, 0.0), edge], bf, af)
					_strip(pts, cols, idx, run, [0.0, 0.25, LINE, LINE + FADE], [_a(line, 0.0), line, line,
						_a(line, 0.0)], bf, af)
				else:
					_strip(tp, tc, tix, run, [-EDGE_W, 0.0], [_a(edge, 0.0), edge], bf, af)
					_strip(tp, tc, tix, run, [0.0, 0.25, LINE, LINE + FADE], [_a(line, 0.0), line, line,
						_a(line, 0.0)], bf, af)
			i0 = i1 + 1
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
	if inside:   # all with his penis: the sack under the line round his tip
		var o2 := pts.size()
		pts.append_array(tp)
		cols.append_array(tc)
		for k in tix:
			idx.append(o2 + k)
		tipline.graphics.setMesh(pts, cols, idx)
		return
	if tp.size() > 0:
		tipline.graphics.setMesh(tp, tc, tix)
	gr.setMesh(pts, cols, idx)


## The polygon q split by the region `cut` (none: all outside): [the pieces in it, the pieces outside it].
static func _split(q: PackedVector2Array, cut: PackedVector2Array) -> Array:
	if cut.is_empty():
		return [[], [q]]
	var cw := Geometry2D.is_polygon_clockwise(q)
	var ins := []
	var outs := []
	for a in Geometry2D.intersect_polygons(q, cut):
		if a.size() >= 3 and Geometry2D.is_polygon_clockwise(a) == cw:
			ins.append(a)
	for a in Geometry2D.clip_polygons(q, cut):
		if a.size() >= 3 and Geometry2D.is_polygon_clockwise(a) == cw:   # (not a hole)
			outs.append(a)
	return [ins, outs]


## The polygon q in one colour into a mesh.
static func _poly(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, q: PackedVector2Array,
		c: Color) -> void:
	var tri := Geometry2D.triangulate_polygon(q)
	var o := pts.size()
	pts.append_array(q)
	for _k in q.size():
		cols.append(c)
	for k in tri:
		idx.append(o + k)


## The cum pool q into a mesh: shaded down to its bottom, a light line along its level lv.
func _pool(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, q: PackedVector2Array, pe: Vector2,
		down: Vector2, r: float, cum: Color, lv: Vector2, alpha: float, rip := 0.0) -> void:
	var tri := Geometry2D.triangulate_polygon(q)
	var o := pts.size()
	for v in q:
		var sh := clampf(1.0 - 0.15 * (v - pe).dot(down) / r, 0.7, 1.0)   # linear: no streaks along the triangles
		pts.append(v)
		cols.append(Color(cum.r * sh, cum.g * sh, cum.b * sh, 0.85))
	for k in tri:
		idx.append(o + k)
	var surf := PackedVector2Array()
	for v in q:
		if absf((v - lv).dot(down)) < 0.2 + rip:
			surf.append(v)
	if rip > 0.0 and surf.size() > 2:   # (rippling: along it, side to side)
		var sd := Vector2(-down.y, down.x)
		var arr := Array(surf)
		arr.sort_custom(func(a, b): return a.dot(sd) < b.dot(sd))
		surf = PackedVector2Array(arr)
	if surf.size() == 2 or (rip > 0.0 and surf.size() > 2):
		_strip(pts, cols, idx, surf, [-1.2, 0.0, 1.2], [Color(1, 1, 1, 0), Color(1, 1, 1, 0.5 * alpha), Color(1, 1, 1, 0)])


## Below the cum's level lv as it ripples: waves `rip` high moving out from x0 (along the level, from lv), dying out
## away from it.
func _rippled(lv: Vector2, down: Vector2, r: float, rip: float, x0: float) -> PackedVector2Array:
	var sd := Vector2(-down.y, down.x)
	var out := PackedVector2Array([lv - sd * 400.0])
	var k := TAU / maxf(2.0, r * RIPPLE_L)
	var n := 28
	for i in n + 1:
		var x := lerpf(-r * 1.3, r * 1.3, float(i) / n)
		var d := absf(x - x0)
		var h := rip * sin(k * d - RIPPLE_W * (_rip_t + _jet_f)) * exp(-d / (r * 1.2))
		out.append(lv + sd * x - down * h)
	out.append(lv + sd * 400.0)
	out.append(lv + sd * 400.0 + down * 400.0)
	out.append(lv - sd * 400.0 + down * 400.0)
	return out


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
		if p[i].distance_to(top) > _web_reach:
			continue   # (stuck: only where the tube leaves his tip, not at her ring)
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
