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
## Her mouth: its shape at rest (closed), pushed out only where he touches it; her throat closed below it (a ring:
## GATE_LEN), opening round him and as she swallows. Cum in her mouth lies in it as a pool down to that ring (_pool);
## his spurts come out of his tip into it (_move_shots); what she swallows goes down through the ring (the stomach
## part's lumps, her throat bulging round them: _bulge). While his tip is past the ring's middle, her throat is open
## round him down to it: the pool goes on down there, and runs on down (drain: the plugin takes it out of her mouth).
##
## The stomach (stomach_part.gd) is a display object of its own, above her near arm; this one gives it her throat's
## line every tick (update_stomach). This one ends a little past the ring, or past his tip, at the first sample where
## her throat is the pipe as it is (_seam): while the stomach shows, its pipe goes on from that sample, along this
## one's centre line, so the pipe goes on over her arm; both draw that sample, so they meet without a seam (no
## cross-fade: nothing shows twice). Without the pipe this one fades out past there. Its part
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
const ROOM_TIP := 0.8      # and round what sits on his tip (Him.tipExtra: soft, it fills her throat)
const EDGE := 3.0          # penis-local margin around his outline in the strip taken from his render
const PAST_TIP := 12.0     # penis-local length taken past his tip point (the rounded end of the art)
const CLOSE_LEN := 15.0    # past his tip her throat closes over this length
const CLOSE_SOFT := 36.0   # past what sits on his tip (Him.tipExtra) her throat is the pipe's width at once, on that
                           # one's middle (_mid); her ring closes over this length past it
const HAND_FADE := 6       # where the stomach's pipe does not show, this part fades out over this many samples past
                           # its seam (_seam)
const SEAM_EPS := 0.05     # her throat is the pipe where its walls are this near the pipe's (local units: no step)
const TIP_ROUND := 6       # her throat is rounded round his tip this many samples past it (what sits on his tip)
const SPLIT_AT := 0.7      # the lower painter takes over this far down her neck (0 jaw .. 1 chest): above her
                           # shoulder, below her earrings
const SPLIT_MIN := 0.4     # ... or higher, where her near arm covers her throat above that (_split_above_arm), but
const SPLIT_MARGIN := 5    #   not above this; this many samples above the highest it covers
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
const MOUTH_BACK := 6      # samples before her throat over which her mouth's walls hand over to her throat's round him
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
const SPLASH := 0.03       # what lands in it sets it swinging (tilt speed)
const SHOT_SPEED := 9.0    # his cum leaves his tip this fast (local units per tick), along him
const SHOT_SPREAD := 0.08  # give or take this much (radians, at random)
const SHOT_G := 0.8        # it falls (down for the pool): speed gained per tick
const SHOT_DRAG := 0.03    # and loses this share of its speed per tick
const SHOT_SLIDE := 0.85   # speed kept per tick while it runs along her mouth's wall
const SHOT_W := 2.6        # half the width of the stream
const SHOT_HOLD := 3       # a spurt tick keeps it coming out this many ticks (the game's come a few ticks apart: one
                           # stream while he spurts)
const SHOT_FROM := 3.0     # it comes out this far past his tip point (from under the end of his render)
const SHOT_LIFE := 45      # ticks: past that, it is in the pool wherever it is
const SHOT_RUN := 6        # it runs along her mouth's wall at most this many ticks (then it is in the pool: the pool is
const SHOT_REST := 0.6     # one level, it does not keep what lies in a hollow apart), less where it comes to rest (this
                           # slow: local units per tick)
## The ring (where her mouth meets her throat): everything there follows its middle (_gate_f): where the pool ends,
## where her walls close round it, where swallows start down, where the food pipe takes over, from where what is in
## her mouth runs down while he holds it open. To move it all up or down her throat, change GATE_SHIFT.
const GATE_SHIFT := 0.0    # the ring's middle this far (local units) on down her throat (> 0) or up towards her lips
                           # (< 0) from where her mouth at rest ends (MOUTH_ROOF_TURN); STEP units per sample
const GATE_LEN := 5        # her throat is closed there (what is in her mouth stays there) over this many samples each
                           # way from its middle (in her, not on the centre line, which follows him)
const GATE_MIN := 0.5      # to this half width (a seam)
const GATE_RING := 5.0     # and its wall is this much thicker there, out from it (a ring of muscle)
const GATE_OVER := 0.6     # a condom's neck in it (gripped): the ring shows over it, in from its edges, this share of
const GATE_OVER_MAX := 0.4 #   GATE_RING, but not over more than this share of its half width (it is round: in front)
const GATE_OVER_OUT := 2.0 # and out over the wall this far (it covers the rim of his art there)
const GATE_PRE := 0.5      # as she gets ready to swallow it opens this much (of the way to her throat's own width);
                           # what she swallows opens it the rest of the way (the lump: _bulge)
const DRAIN := 0.25        # while he holds the ring open, what is in her mouth runs down her throat round him this
                           # fast (the game's units per tick: a full mouth in some 5 s), while it reaches down there
                           # (her throat goes down from her mouth); from his tip at the ring's middle, faster as he
                           # goes on through it, full speed past it

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
var _reach := 0.0                    # the same to the end of what sits on his tip (Him.tipExtra), if anything does
var _extra := []                     # that ({x, y, r} circles, penis-local)
var _gate_rest_t := 0.0              # _gate_point's sample (between samples) on the line it was called on
var _ring_rest := -1.0               # her throat ring's depth along her throat at rest (her units: Her.throatRing; < 0:
                                     # not known yet). From her alone, not him: no loop through his pull on her head
var _close := CLOSE_LEN               # how far past his tip (or what sits on it) her throat closes
var _drawn := 0.0                    # length of the strip taken from his render (a little past his tip)
var _x_lips := 0.0                   # penis-local x at her lips
var _tip_x := 0.0
var _len_scale := 1.0                # local units per penis-local unit, along him / across him
var _wid_scale := 1.0
var _side := 1.0                     # which side of the line his penis-local +y goes
var _penis_xf := Transform2D()       # penis-local -> his local space (UVs into his render)
var _bounds := Rect2()
var _curve_n := 0                    # samples of the centre line's curve (past it, it goes straight on)
var _seam := 0                       # the first sample where her throat is the stomach's pipe as it is (closed round its
                                     # middle, _mid; no ring, none of him): this part ends there and the pipe goes on
                                     # from there (both draw that sample: no seam shows)
var _pipe_k := 0.0                   # how much the stomach's pipe shows (past _seam this part fades out the rest)
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
var _mid := PackedFloat32Array()     # past what sits on his tip, her throat's middle off the centre line (the stomach's
                                     # pipe follows it); 0 elsewhere
var _m0 := 0                         # her mouth's pocket: from this sample (her lips)
var _m1 := 0                         # to this one (where her throat starts)
var _to_jaw := true                  # her jaw (the pocket's floor) is on the e1 side
var _mouth_amt := 0.0                # what is in her mouth, as it shows (eased)
var _pool_parts: Array = []          # the pool's bands: [polygons, from, to (depth along _pool_gd), colour, colour]
var _pool_gd := Vector2.DOWN         # down for the pool (local): square to its surface
var _back_dir := Vector2.LEFT        # down her throat at the pool's end (local), and how far its end is along that
var _back_at := 0.0
var _tilt := 0.0                     # the surface's tilt from level (radians) and how fast it changes
var _tilt_v := 0.0
var _last_pos := Vector2.ZERO        # where her mouth was last tick (in the scene), and how fast it went
var _last_vel := Vector2.ZERO
var _acc := Vector2.ZERO             # how fast it speeds up, smoothed
var _moving := false                 # _last_pos / _last_vel hold something
var _shots: Array[Dictionary] = []   # his cum on its way into the pool, oldest first: p, v (local), q (cumInMouth
                                     # units it carries), run, age
var _shot_queue := 0                 # spurt ticks since last tick (add_shot)
var _shot_left := 0                  # ticks it keeps coming out (SHOT_HOLD)
var _shot_run := 0                   # the run of ticks it comes out in (one stream), and ticks since it last did
var _shot_quiet := 99
var _in_flight := 0                  # cumInMouth not in the pool yet (on its way)
var _lumen := PackedVector2Array()   # her mouth and throat down to where it is closed: their inside edges
var _level := INF                    # the pool's surface (depth along _pool_gd; with no pool, the bottom)
var _pool_end := 0                   # the sample the pool reaches down to: the ring, or past it his tip while he holds
                                     # it open (then what is in her mouth runs down round him: drain)
var _gate := 0                       # the sample in the middle of the closed stretch (GATE_LEN), and exactly
var _gate_f := 0.0                   # (between samples)
var _thick := PackedFloat32Array()   # how much thicker the wall is at each sample (GATE_RING)
var _grip := PackedFloat32Array()    # how far in the ring shows over what it grips (GATE_OVER)
var _gripped := PackedByteArray()    # 1 where what sits on his tip is marked "grip" (a condom's neck: her ring grips it)
var _grip_f := -1.0                  # the last of those samples (where the sack is held), -1: none
var _b0 := PackedFloat32Array()      # _e0 / _e1 without the bulge round what she swallows (_bulge)
var _b1 := PackedFloat32Array()


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
	var seam := -1                 # the pipe goes on from this sample of the line (-1: no seam, the line is her throat)
	var seam_t := Vector2.ZERO     # this part's way along its centre line there
	if shown > 0.0 and _path.size() >= 2:   # this part's centre line, as far as its curve or the seam
		var last := clampi(maxi(_curve_n, _seam + 2), 2, _path.size())
		line = _path.slice(0, last)
		if _mid.size() == _path.size():   # (past what sits on his tip: along her throat's middle, off the centre line)
			for i in last:
				line[i] += _norm[i] * _mid[i]
		var xf := inv * flash_global_transform()
		line = xf * line
		bend = (line[-1] - line[-2]).normalized()
		seam = mini(_seam, last - 1)
		seam_t = xf.basis_xform(_path[mini(seam + 1, _path.size() - 1)] - _path[maxi(seam - 1, 0)]).normalized()
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
	stomach.update(want, want_pipe, her, line, bend, seam, seam_t, shown, flow_from, _gate_f if shown > 0.0 else 0.0)
	_fade_end(stomach.shown * stomach.pipe_shown)
	_bulge(stomach)


## How much of this part shows at each sample (_w): all of it down to the seam; past it, as much as the stomach's pipe
## does not show (pipe_k), fading out over HAND_FADE samples.
func _fade_end(pipe_k: float) -> void:
	_pipe_k = pipe_k
	_w.resize(_path.size())
	for i in _path.size():
		_w[i] = 1.0 if i <= _seam else (1.0 - pipe_k) * (1.0 - smoothstep(float(_seam), float(_seam + HAND_FADE), i))


## The last sample this part draws: the seam while the pipe shows all of it (it draws on from there), else on past it
## as far as this part fades out.
func _end() -> int:
	return mini(_path.size() - 1, _seam if _pipe_k >= 0.999 else _seam + HAND_FADE)


## Where what she swallows starts down (along the centre line): the back of the pool in her mouth, above where her
## throat is closed (it goes on down through there).
func swallow_from() -> float:
	return maxf(float(_m0), _gate_f - 2.0 * GATE_LEN) * STEP


## How much of what is in her mouth runs down her throat this tick (the game's units; 0 while none does): he holds
## the ring open (his tip past its middle: the more, the further on through it), and the pool reaches down to its
## end (her throat goes down from her mouth).
func drain() -> float:
	var through := clampf(_inside / STEP - _gate_f, 0.0, GATE_LEN) / GATE_LEN
	if shown <= 0.0 or not _with_penis or mouth_only or _mouth_amt < 0.2 or _pool_end <= _gate or through <= 0.0:
		return 0.0
	var e := _pool_end
	if maxf(_at(e, _e0[e]).dot(_pool_gd), _at(e, _e1[e]).dot(_pool_gd)) <= _level:
		return 0.0
	return DRAIN * through


## Her throat closed where her mouth meets it (GATE_LEN), but round him, and opening a little as she gets ready to
## swallow (the game's swallow: from its build-up to the moment she swallows, closing again as she relaxes). A condom's
## neck (Him.tipExtra marked "grip") it grips where the neck ends, at the sack it holds back: its walls right on it, the
## ring of muscle round it as thick as when closed and over its edges (_grip).
func _close_gate(her: Her) -> void:
	var open := 0.0
	if her.swallowing:
		var t := float(her.swallowTimer)
		var seq: Dictionary = her.swallowSequence
		open = GATE_PRE * smoothstep(float(seq["build"]), float(seq["swallow"]), t) 			* (1.0 - smoothstep(float(seq["relax"]), float(seq["end"]), t))
	_thick.resize(_path.size())
	_thick.fill(0.0)
	_grip.resize(_path.size())
	_grip.fill(0.0)
	var held := maxf(_inside, _reach)   # (what sits on his tip holds it open too)
	for i in range(maxi(1, ceili(_gate_f - GATE_LEN)), mini(_path.size(), floori(_gate_f + GATE_LEN) + 1)):
		var ring := 0.5 + 0.5 * cos(PI * (i - _gate_f) / GATE_LEN)
		var k := ring * (1.0 - open)
		if _with_penis:   # held open where he is, and ahead of his tip as her throat closes past it (CLOSE_LEN)
			k *= smoothstep(held, held + _close, i * STEP)
		var c := (_e0[i] + _e1[i]) * 0.5
		var a := lerpf(_e0[i], c - GATE_MIN, k)
		var b := lerpf(_e1[i], c + GATE_MIN, k)
		_e0[i] = a
		_e1[i] = b
		_thick[i] = GATE_RING * ring * lerpf(1.0, 0.5, clampf(((b - a) * 0.5 - GATE_MIN) / CLOSED, 0.0, 1.0))
	# a condom's neck: gripped over GATE_LEN up from its end, where the sack is held
	_grip_f = -1.0
	for i in _gripped.size():
		if _gripped[i] == 1 and _with_penis:
			_grip_f = i
	if _grip_f < 0.0:
		return
	for i in range(maxi(1, ceili(_grip_f - GATE_LEN)), mini(_path.size(), floori(_grip_f + GATE_LEN) + 1)):
		var ring := 0.5 + 0.5 * cos(PI * (i - _grip_f) / GATE_LEN)
		_thick[i] = maxf(_thick[i], GATE_RING * ring)   # (out from it on past the neck's end too: no step)
		if _gripped[i] != 1:
			continue
		var k := ring * (1.0 - open)
		var a := lerpf(_e0[i], _p0[i], k)
		var b := lerpf(_e1[i], _p1[i], k)
		_e0[i] = a
		_e1[i] = b
		_grip[i] = k * minf(GATE_RING * GATE_OVER, (b - a) * 0.5 * GATE_OVER_MAX)


## How far along the centre line her throat is closed past him (_outline): past his bare tip once it has closed over
## CLOSE_LEN, past what sits on his tip at once.
func _closed_at() -> float:
	return maxf(_inside, _reach) + (CLOSE_LEN if _extra.is_empty() else 0.0)


## The seam (_seam): past her ring and past what of him is drawn, the first sample from which on her throat is the
## pipe as it is (closed round its middle, _mid, its wall no thicker), whatever shaped it above (his tip and its
## closing, her mouth handing over to her throat, what sits on his tip); its walls there exactly the pipe's.
func _find_seam() -> void:
	var from := mini(ceili(maxf(_gate_f + GATE_LEN + 1.0, _drawn / STEP)), _path.size() - 2)
	_seam = _path.size() - 2
	for i in range(_path.size() - 2, from - 1, -1):   # (from the end up, while it is)
		var m := _mid[i] if _mid.size() == _path.size() else 0.0
		if absf(_e0[i] - (m - CLOSED)) > SEAM_EPS or absf(_e1[i] - (m + CLOSED)) > SEAM_EPS or _thick[i] > 0.0:
			break
		_seam = i
	var m := _mid[_seam] if _mid.size() == _path.size() else 0.0
	_e0[_seam] = m - CLOSED
	_e1[_seam] = m + CLOSED


## The ring's middle (called on her throat at rest, without him, so it stays in her): where the centre line has turned
## MOUTH_ROOF_TURN from its way in at her lips (between samples, so it moves smoothly as she does), then GATE_SHIFT on
## along it.
func _gate_point() -> Vector2:
	var n := mini(_path.size(), _curve_n)
	var dir := (_path[_m0 + 1] - _path[_m0]).normalized()
	var c := cos(MOUTH_ROOF_TURN)
	var prev := 1.0
	var t := float(n - 1)
	for i in range(_m0, n - 1):
		var d := (_path[i + 1] - _path[i]).normalized().dot(dir)
		if d <= c:   # (each segment's way at its middle: the turn crosses c between i - 0.5 and i + 0.5)
			t = i - 0.5 + (prev - c) / maxf(prev - d, 1e-6)
			break
		prev = d
	t = clampf(t + GATE_SHIFT / STEP, _m0 + 1.0, _path.size() - 1.001)
	_gate_rest_t = t
	return _path[int(t)].lerp(_path[int(t) + 1], t - int(t))


## Her throat ring's depth in her (Her.penisInMouthDist units: Her.throatRing) where this draws it, or v while it does
## not show or his depth has not been seen yet.
func ring_depth(v: float) -> float:
	if shown <= 0.0 or _ring_rest < 0.0:
		return v
	return _ring_rest


## The centre line's sample nearest `p` (between samples).
func _index_near(p: Vector2) -> float:
	var best := INF
	var at := 0.0
	for i in _path.size() - 1:
		var a := _path[i]
		var ab := _path[i + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d := (a + ab * t).distance_squared_to(p)
		if d < best:
			best = d
			at = i + t
	return at


## Her throat bulges round what goes down it (what she swallows, his cum past his tip) as the stomach part's pipe
## does round it, along the same line (its samples are this part's), round her throat's middle there.
func _bulge(stomach: FlashDisplayObject) -> void:
	if shown <= 0.0 or _b0.size() != _path.size():
		return
	var bw: PackedFloat32Array = stomach.bulge_w()
	_e0 = _b0.duplicate()
	_e1 = _b1.duplicate()
	for i in mini(bw.size(), _path.size()):
		if bw[i] <= 0.0:
			continue
		var hw := bw[i]
		var m := _mid[i] if _mid.size() == _path.size() else 0.0
		_e0[i] = minf(_e0[i], m - hw)
		_e1[i] = maxf(_e1[i], m + hw)
		_bounds = _bounds.expand(_at(i, m - hw - WALL - GLOW)).expand(_at(i, m + hw + WALL + GLOW))


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
			_move_shots()
			if shown <= 0.0:   # (gone: what was on its way is in the pool)
				_shots.clear()
				_in_flight = 0
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
	_reach = 0.0
	_extra = []
	_close = CLOSE_LEN
	_drawn = 0.0
	_seam = ceili(CLOSE_LEN / STEP)   # (as far as it reaches at least, for the line's length: set below)
	_line(lips_mid, _edge_in, tail, axis)
	_outline(him)
	_pocket(top_lip, bottom_lip, jaw_at)
	var gate_at := _gate_point()
	var her_k := (inv * her.localToGlobal(Vector2(1, 0))).distance_to(inv * her.localToGlobal(Vector2.ZERO))   # local per her unit
	_ring_rest = maxf(0.0, _gate_rest_t * STEP - START_OUT) / maxf(0.001, her_k)   # (from between her lips, as his depth)
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
		_extra = him.tipExtra()
		_close = CLOSE_SOFT if not _extra.is_empty() else CLOSE_LEN
		var ahead := 0.0   # how far that reaches past his tip point (penis-local)
		for c in _extra:
			ahead = maxf(ahead, _tip_x - (float(c["x"]) - float(c["r"])))
		_reach = _inside + ahead * _len_scale if _inside > 0.0 else 0.0
		_drawn = _inside + maxf(PAST_TIP, ahead + 2.0) * _len_scale if _inside > 0.0 else 0.0
		_seam = ceili(maxf(_closed_at(), _drawn) / STEP) + TIP_ROUND + 1   # (as far as it reaches at least: set below)
		# along him, towards his tip; past what is drawn of him, her throat at rest
		# (only his own art is stiff: what sits on his tip is soft and follows her throat)
		var stiff := minf(_drawn, _inside + PAST_TIP * _len_scale) if not _extra.is_empty() else _drawn
		_line(start, -pv.x.normalized(), tail, axis, rest_path, stiff / STEP + 1.0)
		_side = 1.0 if _norm[0].dot(pv.y) >= 0.0 else -1.0
		_outline(him)
		_pocket(top_lip, bottom_lip, jaw_at)
		_fit_mouth(rest)
	_edge_at = start
	_gate_f = minf(_index_near(gate_at), float(_path.size() - 1 - GATE_LEN))
	_gate = int(round(_gate_f))
	_close_gate(her)
	_find_seam()
	_b0 = _e0.duplicate()
	_b1 = _e1.duplicate()
	_split = -1   # (before the pool: its part past here is drawn by the lower painter too)
	var base: Vector2 = throat[int(SPLIT_AT * (throat.size() - 1))]
	for i in _path.size():
		if (_path[i] - base).dot(axis) >= 0.0:
			_split = i
			break
	_split_above_arm(her, throat, axis)
	_slosh(her, true)
	_pool()
	_move_shots()
	_fade_end(_pipe_k)   # (update_stomach sets it again with the pipe as it is now)
	_colours()
	_bounds = Rect2(_path[0], Vector2.ZERO)
	for i in _path.size():
		var out := WALL + GLOW + _thick[i]
		_bounds = _bounds.expand(_at(i, _e0[i] - out)).expand(_at(i, _e1[i] + out))
	_bounds = _bounds.grow(4.0)
	_painter.queue_redraw()
	_lower.queue_redraw()
	_lower_top.queue_redraw()


## Her near arm can come up over her throat above _split (her head down low on him): the lower painter (over her arm)
## then takes over higher, from where her arm no longer covers the centre line (SPLIT_MARGIN samples above that), so
## her sleeve does not cut straight across what is in her throat there. Not above SPLIT_MIN down her neck.
func _split_above_arm(her: Her, throat: PackedVector2Array, axis: Vector2) -> void:
	if _split <= 0 or her.rightArmContainer == null:
		return
	var arms := [her.rightArmContainer, her.rightForeArmContainer]
	var top: Vector2 = throat[int(SPLIT_MIN * (throat.size() - 1))]
	var covered := -1
	var i := _split - 1
	while i > 0 and (_path[i] - top).dot(axis) >= 0.0:
		var p := localToGlobal(_path[i])
		var hit := false
		for a in arms:
			if a is FlashDisplayObject and a.is_visible_in_tree() and a.hitTestVisible(p.x, p.y):
				hit = true
				break
		if not hit:
			break
		covered = i
		i -= 1
	if covered >= 0:
		_split = maxi(1, covered - SPLIT_MARGIN)


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
	var reach := maxf(_drawn, (_seam + HAND_FADE) * STEP)
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
	_mid.resize(n)
	_mid.fill(0.0)
	_gripped.resize(n)
	_gripped.fill(0)
	if not _with_penis:   # her mouth alone: closed all along
		_e0.fill(-CLOSED)
		_e1.fill(CLOSED)
		_p0.fill(0.0)
		_p1.fill(0.0)
		return
	var cp: Penis = him.currentPenis
	var tip_e := Vector2.ZERO
	var end_mid := NAN   # what sits on his tip: the middle of its last covered sample (its round end closes there)
	var cov := []   # what sits on his tip (Him.tipExtra): the circles that reach each sample
	if not _extra.is_empty():
		cov.resize(n)
		for c in _extra:
			var sc := (_x_lips - float(c["x"])) * _len_scale
			var rr := float(c["r"]) * _len_scale
			for j in range(maxi(0, floori((sc - rr) / STEP)), mini(n - 1, ceili((sc + rr) / STEP)) + 1):
				if cov[j] == null:
					cov[j] = []
				cov[j].append(c)
	for i in n:
		var s := i * STEP
		var x := _x_lips - minf(s, _drawn) / _len_scale
		var w: Array = cp._widthAt(maxf(x, _tip_x - PAST_TIP))
		var lo := float(w[1])
		var hi := float(w[1]) + float(w[0])
		if x < _tip_x - PAST_TIP:
			lo = INF   # (past his art's end: only what sits on his tip)
			hi = -INF
		for c in (cov[i] if not cov.is_empty() and cov[i] != null else []):   # what sits on his tip: its width here too
			var dx := x - float(c["x"])
			if absf(dx) < float(c["r"]):
				if c.get("grip", false):
					_gripped[i] = 1
				var hc := sqrt(float(c["r"]) * float(c["r"]) - dx * dx)
				lo = minf(lo, float(c["y"]) - hc)
				hi = maxf(hi, float(c["y"]) + hc)
		if lo <= hi and not _extra.is_empty():
			end_mid = (lo + hi) * 0.5
		if lo > hi:
			lo = float(w[1]) if is_nan(end_mid) else end_mid   # (between its circles' ends: on its middle)
			hi = lo
		_y0[i] = lo - EDGE
		_y1[i] = hi + EDGE
		var a := _side * lo * _wid_scale
		var b := _side * hi * _wid_scale
		var room := lerpf(ROOM, ROOM_TIP, clampf((_tip_x - 2.0 - x) / 6.0, 0.0, 1.0)) if not _extra.is_empty() else ROOM
		var e := Vector2(minf(a, b) - room, maxf(a, b) + room)
		var on := s <= maxf(_inside, _reach)
		_p0[i] = minf(a, b) if on else 0.0
		_p1[i] = maxf(a, b) if on else 0.0
		if on:
			tip_e = e
		else:   # closing past his tip
			var kc := clampf((s - maxf(_inside, _reach)) / _close, 0.0, 1.0)
			if not _extra.is_empty() and not is_nan(end_mid):   # past what sits on it: as wide as the pipe on from its
				var m := _side * end_mid * _wid_scale             #   round end's point (not from the last sample's width,
				e = Vector2(m - CLOSED, m + CLOSED)               #   which jumps as it moves), and on there: back to
				_mid[i] = m                                       #   the centre line it would jog (the pipe follows it)
			else:
				e = tip_e.lerp(Vector2(-CLOSED, CLOSED), kc if _extra.is_empty() else smoothstep(0.0, 1.0, kc))
		_e0[i] = e.x
		_e1[i] = e.y
	if not is_nan(end_mid) and _reach > _inside:   # the pipe under what sits on his tip goes over to its middle along it
		var m := _side * end_mid * _wid_scale
		for i in mini(n, ceili(_reach / STEP) + 1):
			_mid[i] = m * smoothstep(_inside, _reach, i * STEP)
	if not _extra.is_empty():   # round where her throat goes from his glans to what sits on it (no notch; only out)
		var i0 := maxi(1, int(_inside / STEP) - 4)
		var i1 := mini(n - 2, int(_inside / STEP) + TIP_ROUND)   # (round his tip only)
		for _k in 4:
			var a0 := _e0.duplicate()
			var a1 := _e1.duplicate()
			for i in range(i0, i1 + 1):
				a0[i] = minf(_e0[i], (_e0[i - 1] + 2.0 * _e0[i] + _e0[i + 1]) * 0.25)
				a1[i] = maxf(_e1[i], (_e1[i - 1] + 2.0 * _e1[i] + _e1[i + 1]) * 0.25)
			_e0 = a0
			_e1 = a1


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
	var last := mini(i1, int(maxf(_inside, _reach) / STEP))   # (where he is)
	for _pass in MOUTH_SMOOTH:
		var a0 := _e0.duplicate()
		var a1 := _e1.duplicate()
		for i in range(i0, i1 + 1):
			_e0[i] = (a0[i - 1] + a0[i] * 2.0 + a0[i + 1]) * 0.25
			_e1[i] = (a1[i - 1] + a1[i] * 2.0 + a1[i + 1]) * 0.25
			if i <= last:
				_e0[i] = minf(_e0[i], room0[i])
				_e1[i] = maxf(_e1[i], room1[i])
	if not _extra.is_empty():   # what sits on his tip fills her throat ahead of him: it closes round it, and past it
		# as her throat does past his tip (no room left open by the smoothing above), then lets go. Not in her mouth:
		# there its walls stay at rest, out only where it pushes them (above), handing over as her mouth does
		var free := maxf(_inside, _reach) + _close
		for i in mini(_path.size(), int((free + CLOSE_LEN) / STEP) + 1):
			var k := smoothstep(_inside, _inside + CLOSE_LEN, i * STEP) * (1.0 - smoothstep(free, free + CLOSE_LEN, i * STEP))
			k *= smoothstep(_mouth_end - MOUTH_BACK, _mouth_end, i)
			if k > 0.0:
				_e0[i] = lerpf(_e0[i], room0[i], k)
				_e1[i] = lerpf(_e1[i], room1[i], k)


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
	var target := clampf(_acc.x * SLOSH_PUSH, -SLOSH_MAX, SLOSH_MAX) if live else 0.0
	_tilt_v += (target - _tilt) * SLOSH_K - _tilt_v * SLOSH_DAMP
	_tilt = clampf(_tilt + _tilt_v, -SLOSH_MAX, SLOSH_MAX)
	_pool_gd = flash_global_transform().affine_inverse().basis_xform(Vector2.DOWN.rotated(_tilt)).normalized()


## The pool in her mouth's pocket: its surface where the room in the pocket below it (round him) holds what is in her
## mouth; drawn as bands across it (_pool_parts), each with its colour changing evenly with depth.
func _pool() -> void:
	_pool_parts.clear()
	var her: Her = g.her
	_mouth_amt += (float(maxi(0, her.cumInMouth - _in_flight)) - _mouth_amt) * MOUTH_EASE
	var end := mini(_gate, _path.size() - 1)
	if _with_penis:   # with his tip past the ring, her throat is open round him down to it: the pool goes on down there,
		# and as he holds the ring open, on past his tip through where her throat closes (its end fades out past that,
		# where her throat is as narrow as what runs on down the pipe: not round his glans, not in the funnel below it)
		# (all of it once his tip is a quarter of the way on through: the drain has started at its middle)
		var past := (CLOSE_LEN + GATE_LEN * 0.5 * STEP) \
			* clampf(4.0 * (_inside / STEP - _gate_f) / GATE_LEN, 0.0, 1.0)
		end = clampi(int((_inside + past) / STEP), end, _path.size() - 1)
	_pool_end = end
	_lumen.clear()
	_level = INF
	if end <= _m0 + 1:
		return
	var floor_e := _e1 if _to_jaw else _e0
	var roof_e := _e0 if _to_jaw else _e1
	for i in range(_m0, end + 1):
		_lumen.append(_at(i, floor_e[i]))
	for i in range(end, _m0 - 1, -1):
		_lumen.append(_at(i, roof_e[i]))
	var lowest := -INF
	for p in _lumen:
		lowest = maxf(lowest, p.dot(_pool_gd))
	_level = lowest - 1.0   # (with no pool: what comes in lands at the bottom)
	if _mouth_amt < 0.2:
		return
	# her mouth and on down her throat to where it is closed (GATE_LEN: what is in her mouth lies on that), half a wall
	# into its walls (the wall is drawn over its edge)
	var cav := PackedVector2Array()
	var out := WALL * 0.5 * (1.0 if _to_jaw else -1.0)   # out of the floor's side
	for i in range(_m0, end + 1):
		cav.append(_at(i, floor_e[i] + out))
	for i in range(end, _m0 - 1, -1):
		cav.append(_at(i, roof_e[i] - out))
	# him: his outline (the room he takes), and the whole strip taken from his render (_penis: what the pool shows
	# over), past his tip point too (his art's rounded end; where he is not, it is the pool's own colour over the pool)
	var pen := PackedVector2Array()
	var strip := PackedVector2Array()
	if _with_penis:
		var last := mini(end, int(maxf(_inside, _reach) / STEP))
		for i in range(_m0, last + 1):
			pen.append(_at(i, _p0[i]))
		for i in range(last, _m0 - 1, -1):
			pen.append(_at(i, _p1[i]))
		if pen.size() < 4:
			pen.clear()
		var drawn := mini(int(ceil(_drawn / STEP)), _path.size() - 1)
		for i in range(_m0, drawn + 1):
			strip.append(_at(i, _side * _y0[i] * _wid_scale))
		for i in range(drawn, _m0 - 1, -1):
			strip.append(_at(i, _side * _y1[i] * _wid_scale))
		if strip.size() < 4:
			strip.clear()
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
	_level = level
	var fill := Color.hex((g.cumRGB << 8) | 0xFF)
	var c0 := _pm(fill)
	var c1 := _pm(Color(fill.r * FILL_DARK, fill.g * FILL_DARK, fill.b * FILL_DARK, fill.a))
	var sc := _pm(fill.darkened(0.15))
	var h := _half_px
	# it fades out over the last GATE_LEN / 2 samples (where he holds her throat open, it does not end straight across
	# him): each band in two, before that and over it (so its colour changes evenly inside each piece, as drawn)
	_back_dir = (_path[end] - _path[end - 1]).normalized()
	_back_at = _path[end].dot(_back_dir)
	var fade_from := _back_at - GATE_LEN * 0.5 * STEP
	var zones := [_slab(_back_dir, fade_from - 1000.0, fade_from, cav[0]),
		_slab(_back_dir, fade_from, _back_at + 1.0, cav[0])]
	# its part low on her neck, past _split, is drawn again by the lower painter (that one draws her throat there over
	# this painter's drawing)
	var low := PackedVector2Array()
	if _splitting() and end > _split + 1:
		for i in range(_split, end + 1):
			low.append(_at(i, floor_e[i] + out))
		for i in range(end, _split - 1, -1):
			low.append(_at(i, roof_e[i] - out))
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
		if not strip.is_empty():
			for poly in polys:
				over.append_array(Geometry2D.intersect_polygons(poly, strip))
		var lower := []   # and both past _split
		var lower_over := []
		if not low.is_empty():
			for poly in polys:
				lower.append_array(Geometry2D.intersect_polygons(poly, low))
			for poly in over:
				lower_over.append_array(Geometry2D.intersect_polygons(poly, low))
		_pool_parts.append([polys, band[0], band[1], band[2], band[3], over, lower, lower_over])


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


## The pool's bands (`over`: their parts over him, at MOUTH_OVER; `lower`: only their parts past _split), each colour
## changing evenly with depth.
func _paint_pool_bands(ci: RID, over: bool, lower := false) -> void:
	for part in _pool_parts:
		var d0: float = part[1]
		var d1: float = part[2]
		# (no holes: a band across a pocket has none)
		for poly: PackedVector2Array in part[(7 if over else 6) if lower else (5 if over else 0)]:
			var tri := Geometry2D.triangulate_polygon(poly)
			if tri.is_empty():
				continue
			var cols := PackedColorArray()
			for p in poly:
				var c := (part[3] as Color).lerp(part[4], clampf((p.dot(_pool_gd) - d0) / (d1 - d0), 0.0, 1.0))
				c *= clampf((_back_at - p.dot(_back_dir)) / (GATE_LEN * 0.5 * STEP), 0.0, 1.0)   # fading out at its end
				cols.append(c * MOUTH_OVER if over else c)
			RenderingServer.canvas_item_add_triangle_array(ci, tri, poly, cols)


## The pool, and her mouth's wall drawn again over its edge (`lower`: their parts past _split).
func _paint_pool(ci: RID, lower := false) -> void:
	if _pool_parts.is_empty():
		return
	_paint_pool_bands(ci, false, lower)
	var h := _half_px
	var i0 := _split if lower else _m0
	for side: float in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for i in range(i0, mini(_pool_end, _path.size() - 1) + 1):
			var e: float = _e0[i] if side < 0.0 else _e1[i]
			var c := _pm(_wall_col) * _w[i]
			pts.append_array([_at(i, e + side * WALL * 0.75), _at(i, e + side * h), _at(i, e - side * h)])
			cols.append_array([c, c, Color(0, 0, 0, 0)])
			if i > i0:
				var b := (i - i0 - 1) * 3
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
	var last := mini(_split, _end()) if _splitting() else _end()
	_paint_range(_painter.get_canvas_item(), 0, last)
	_paint_pool(_painter.get_canvas_item())
	_paint_shots(_painter.get_canvas_item())   # (under him: out from under his tip)
	_penis(_painter.get_canvas_item(), 0, last)
	_paint_grip(_painter.get_canvas_item(), 0, last)
	if _with_penis:
		_paint_pool_bands(_painter.get_canvas_item(), true)


## He comes in her mouth (a spurt tick: one unit of cumInMouth): it comes out of his tip (and goes on coming out
## for SHOT_HOLD ticks).
func add_shot() -> void:
	_shot_queue += 1


## His cum on its way: out of his tip along him, falling, running along her mouth's walls where it meets them, into
## the pool where it reaches its surface (only then does the pool take it: _in_flight).
func _move_shots() -> void:
	if _shot_queue > 0:
		_shot_left = SHOT_HOLD
	if _shot_left > 0 and _with_penis and _inside > 0.0 and _path.size() >= 2:
		var t := minf((_inside + SHOT_FROM) / STEP, _path.size() - 1.001)
		var i := int(t)
		var tip := _path[i].lerp(_path[i + 1], t - i)
		var dir := (_path[i + 1] - _path[i]).normalized()
		if _shot_quiet > 0:
			_shot_run += 1
		_shots.append({"p": tip, "v": dir.rotated(randf_range(-SHOT_SPREAD, SHOT_SPREAD)) * SHOT_SPEED,
			"q": _shot_queue, "run": _shot_run, "age": 0, "wall": 0})
		_in_flight += _shot_queue
		_shot_left -= 1
		_shot_quiet = 0
	else:
		_shot_left = 0
		_shot_quiet += 1
	_shot_queue = 0
	var keep: Array[Dictionary] = []
	var grav := _pool_gd * SHOT_G
	for d in _shots:
		if d["age"] == 0:   # (new: at his tip this tick)
			d["age"] = 1
			keep.append(d)
			continue
		var v: Vector2 = (d["v"] + grav) * (1.0 - SHOT_DRAG)
		var p: Vector2 = d["p"] + v
		if _lumen.size() >= 3 and not Geometry2D.is_point_in_polygon(p, _lumen):   # the wall: onto it, along it
			var q := _nearest_on(_lumen, p)
			var nrm := (p - q).normalized()
			p = q
			var vn := v.dot(nrm)
			if vn > 0.0:
				v = (v - nrm * vn) * SHOT_SLIDE
			d["wall"] += 1
		d["p"] = p
		d["v"] = v
		d["age"] += 1
		var on_wall: int = d["wall"]
		if p.dot(_pool_gd) >= _level or d["age"] > SHOT_LIFE or _lumen.size() < 3 or on_wall >= SHOT_RUN \
				or (on_wall > 0 and v.length() < SHOT_REST):   # in the pool
			_in_flight = maxi(0, _in_flight - int(d["q"]))
			if d["q"] > 0:
				_tilt_v += SPLASH * (1.0 if randf() < 0.5 else -1.0)
			continue
		keep.append(d)
	_shots = keep


## The point of the closed outline `poly` nearest `p`.
static func _nearest_on(poly: PackedVector2Array, p: Vector2) -> Vector2:
	var best := poly[0]
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		if q.distance_squared_to(p) < best.distance_squared_to(p):
			best = q
	return best


## His cum on its way: each run one stream through its bits, newest (at his tip) to oldest, its edge a little darker.
func _paint_shots(ci: RID) -> void:
	if _shots.is_empty():
		return
	var fill := Color.hex((g.cumRGB << 8) | 0xFF)
	var runs := {}
	for d in _shots:
		if not runs.has(d["run"]):
			runs[d["run"]] = PackedVector2Array()
		runs[d["run"]].append(d["p"])
	for pts: PackedVector2Array in runs.values():
		pts.reverse()
		for pass_ in [[SHOT_W, fill.darkened(0.15)], [SHOT_W - 0.6, fill]]:
			_stream(ci, pts, pass_[0], _pm(pass_[1]))


## A line through `pts`, `w` each side, round at both ends, in one colour (premultiplied), its edges fading out across
## one screen pixel.
func _stream(ci: RID, pts: PackedVector2Array, w: float, c: Color) -> void:
	var h := _half_px
	var n := pts.size()
	if n >= 2:
		var vs := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for j in n:
			var t := (pts[mini(j + 1, n - 1)] - pts[maxi(j - 1, 0)])
			var nrm := Vector2(-t.y, t.x).normalized() if t.length() > 0.001 else Vector2.UP
			for o in [-w - h, -w + h, w - h, w + h]:
				vs.append(pts[j] + nrm * o)
			cols.append_array([Color(0, 0, 0, 0), c, c, Color(0, 0, 0, 0)])
			if j > 0:
				var b := (j - 1) * 4
				for k in 3:
					idx.append_array([b + k, b + k + 1, b + k + 4, b + k + 1, b + k + 5, b + k + 4])
		RenderingServer.canvas_item_add_triangle_array(ci, idx, vs, cols)
	for e in ([pts[0], pts[n - 1]] if n >= 2 else [pts[0]]):
		_round(ci, e, w, c)


## A round dot (its edge fading out across one screen pixel).
func _round(ci: RID, at: Vector2, r: float, c: Color) -> void:
	var h := _half_px
	var vs := PackedVector2Array([at])
	var cols := PackedColorArray([c])
	var idx := PackedInt32Array()
	var seg := 12
	for k in seg:
		var u := Vector2.RIGHT.rotated(TAU * k / seg)
		vs.append_array([at + u * (r - h), at + u * (r + h)])
		cols.append_array([c, Color(0, 0, 0, 0)])
		var a := 1 + 2 * k
		var b := 1 + 2 * ((k + 1) % seg)
		idx.append_array([0, a, b, a, a + 1, b, a + 1, b + 1, b])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, vs, cols)


func _paint_lower() -> void:
	if shown <= 0.0 or not _splitting() or _split >= _end():
		return
	_paint_range(_lower.get_canvas_item(), _split, _end())
	if _pool_end > _split + 1:   # the pool run down there
		_paint_pool(_lower.get_canvas_item(), true)


func _paint_lower_top() -> void:
	if shown <= 0.0 or not _splitting() or _split >= _path.size():
		return
	_penis(_lower_top.get_canvas_item(), _split, _path.size() - 1)
	_paint_grip(_lower_top.get_canvas_item(), _split, _end())
	if _with_penis and _pool_end > _split + 1:
		_paint_pool_bands(_lower_top.get_canvas_item(), true, true)


## Her throat at the samples i0 to i1 (both drawn: the painters share the row where they meet).
func _paint_range(ci: RID, i0: int, i1: int) -> void:
	_glow(ci, _e0, -WALL, -WALL - GLOW, i0, i1)
	_glow(ci, _e1, WALL, WALL + GLOW, i0, i1)
	_band(ci, -WALL, WALL, _wall_col, i0, i1, true)
	_band(ci, 0.0, 0.0, _lumen_col, i0, i1)


## Her ring over what it grips (_grip): its wall in from each edge, over him (it goes round him: in front of him).
func _paint_grip(ci: RID, i0: int, i1: int) -> void:
	var from := maxi(i0, ceili(_grip_f - GATE_LEN))
	var to := mini(i1, mini(floori(_grip_f) + 1, _path.size() - 1))   # (one past: its edge fades out there)
	if not _with_penis or _grip_f < 0.0 or _grip.size() != _path.size() or from >= to:
		return
	for side: float in [-1.0, 1.0]:
		var edge: PackedFloat32Array = _e0 if side < 0.0 else _e1
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		var c0 := _pm(_wall_col)
		for i in range(from, to + 1):
			var c := c0 * _w[i]
			var g := _grip[i]
			var out := edge[i] + side * minf(GATE_OVER_OUT, 2.0 * g)   # (over the rim of his art past his outline)
			var inn := edge[i] - side * g
			var soft := edge[i] - side * maxf(g - 2.0 * _half_px, 0.0)
			pts.append_array([_at(i, out), _at(i, soft), _at(i, inn)])
			cols.append_array([c, c * minf(g / (2.0 * _half_px), 1.0), Color(0, 0, 0, 0)])
			if i > from:
				var b := (i - from - 1) * 3
				for k in 2:
					idx.append_array([b + k, b + k + 1, b + k + 3, b + k + 1, b + k + 4, b + k + 3])
		RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)


## A premultiplied colour (the fade behind the start edge is FADE_SHADER's).
static func _pm(col: Color) -> Color:
	return Color(col.r * col.a, col.g * col.a, col.b * col.a, col.a)


## A strip along the centre line from his outline's e0 + lo to e1 + hi (`ring`: and out by _thick), in one colour
## (premultiplied), its edges fading out across one screen pixel centred on them.
func _band(ci: RID, lo: float, hi: float, col: Color, i0: int, i1: int, ring := false) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var h := _half_px
	var c0 := _pm(col)
	for i in range(i0, i1 + 1):
		var c := c0 * _w[i]
		var t := _thick[i] if ring else 0.0
		var d0 := _e0[i] + lo - t
		var d1 := _e1[i] + hi + t
		var m0 := minf(d0 + h, (d0 + d1) * 0.5)   # a strip thinner than a pixel: no solid middle
		var m1 := maxf(d1 - h, (d0 + d1) * 0.5)
		pts.append_array([_at(i, d0 - h), _at(i, m0), _at(i, m1), _at(i, d1 + h)])
		cols.append_array([Color(0, 0, 0, 0), c, c, Color(0, 0, 0, 0)])
		if i > i0:
			var b := (i - i0 - 1) * 4
			for k in 3:   # the fade in, the solid middle, the fade out
				idx.append_array([b + k, b + k + 1, b + k + 4, b + k + 1, b + k + 5, b + k + 4])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)


## A strip from edge + inner (glow colour) to edge + outer (transparent), out by _thick (round the thicker wall). It
## starts half a pixel under the wall, so the wall's faded edge has the glow under it (no light seam between the two).
func _glow(ci: RID, edge: PackedFloat32Array, inner: float, outer: float, i0: int, i1: int) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var gc := _pm(_glow_col)
	var under := -signf(outer - inner) * _half_px
	for i in range(i0, i1 + 1):
		var t := signf(outer - inner) * _thick[i]
		pts.append(_at(i, edge[i] + inner + under + t))
		pts.append(_at(i, edge[i] + outer + t))
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
