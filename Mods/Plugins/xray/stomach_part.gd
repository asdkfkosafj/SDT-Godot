extends FlashDisplayObject
## The stomach part of the x-ray (see plugin.gd): a cutaway of her stomach, in her torso, and of the food pipe from
## her throat down into it. Its own display object, above her near arm (the plugin places it), drawn as a canvas
## group like the throat part (xray_view.gd, which gives it her throat's line every tick).
##
## The stomach is an oval, built once in its own space and placed in her torso every tick by her navel, upright along
## her spine, so it moves with her body. The pipe is rebuilt every tick along a line the throat part gives it (her
## throat, or while the throat part shows, its centre line), then bending down into the top of the stomach. While the
## throat part shows, the pipe fades in only a little past his tip, where the throat part fades out: nothing shows
## twice, and from there on the pipe shows over her arm.
##
## What is in it (amount, of capacity: fill, 0 to 1 of the inside's area) lies at the bottom, its surface level on the
## screen whichever way she turns; it sloshes (the surface tilts on a damped spring) when her body speeds up or slows
## down sideways, and when something lands in it. It empties by `digest` per tick.
##
## What goes down the pipe (the plugin adds it): a swallow, as a lump that goes down as fast as the game's swallow
## wave down her neck, the pipe bulging around it; his cum when he comes deep, as a stream from his tip, one piece per
## spurt tick, end to end. Drawn by a painter of its own (_flow), over the throat part's lower painter (it shows where
## her throat closes past his tip too) and under its top one (his penis there), and only past what of him the upper
## painter draws (that one is under this layer).
##
## Pipe and stomach are one shape: one outline down one side of the pipe, out along a flare into the oval, round it
## and back up the other side, with one wall and one glow along it, and one inside. The pipe comes into the stomach
## straight down (STRAIGHT, the same in the stomach's own space every tick), and widens into it along the flare.
##
## The game glides her body parts between ticks (physics interpolation): her head with her (her space), her torso
## swaying against her (up to some 20 px a tick at her belly while he thrusts). Drawn where her torso is at the tick,
## the stomach would lead her body by up to a tick's motion (a flicker). So everything is one mesh per painter, built
## each tick in her space, skinned on two bones (_skel): bone 0 stays (her space: the pipe in her neck, in step with
## the throat part and her head), bone 1 follows her torso between ticks (the stomach; set every frame, _process, as
## the game glides her torso). The pipe goes over from the one to the other along its bend in her chest (_pipe_b).
##
## What comes out at the bottom of the pipe pours into the stomach as liquid: bits of it (_drops, one per tick while it
## comes, each with what came that tick), falling (screen down) from the pipe's speed, sliding down the inside of the
## wall where they meet it, and adding to the contents where they reach their surface; drawn as one stream through
## the bits of each run, thinner where it falls faster. Where they land the surface ripples (a damped wave along it)
## and sometimes splashes a droplet up.
##
## Painters, bottom to top: _painter (pipe and stomach: their insides, the contents, what pours in, the glow and the
## wall), the throat part's lower painter, _flow (what is in the pipe), the throat part's top painter (attach_lower).

const STEP := 3.0          # spacing of the outline and pipe samples (local units)
const WALL := 6.0          # thickness of the walls (as her throat's)
const GLOW := 10.0         # the soft red glow around them
const PIPE := 2.5          # half width of the inside of the pipe (closed, as her throat past his tip)
const PIPE_DOWN := 0.15    # how far the pipe keeps going down past the tail before it bends (times its length)
const PIPE_IN := 0.4       # and from how far above the stomach it comes straight down into it (same)
const PIPE_TOP := 6        # samples over which the pipe fades in at its top, and takes over from the throat part
const FADE := 0.25         # per tick, in and out
## The oval, in torso units at Size 100: its half width (across her body) and half height (along her spine).
const RADII := Vector2(44, 68)
const AT_NAVEL := Vector2(-10, -137)   # its middle from her navel, in her torso's space
const FILL_DARK := 0.82    # the bottom of the contents, times their colour (shading, darker with depth)
const SURFACE := 2.0       # the darker line along their surface, its width
const SLOSH_PUSH := 0.12   # the surface's tilt (radians) for each scene unit per tick per tick she speeds up sideways
const SLOSH_SMOOTH := 0.2  # how much of each tick's speeding up counts at once (the rest comes in over the next ticks)
const SLOSH_K := 0.06      # how hard the surface springs back level, per tick
const SLOSH_DAMP := 0.45   # and how fast its swing dies down: near critical, so a thrusting rhythm cannot build it up
const SLOSH_MAX := 0.45    # the most it tilts
const LUMP_START := 0.2    # a swallowed lump starts this share of the way down her throat (as the game's swallow wave)
const LUMP_SPEED := 0.025  # and goes down this share of it per tick (half the game's swallow wave)
const LUMP_LEN := 22.0     # its half length
const LUMP_WIDE := 0.8     # its half width: PIPE + this times how much she swallowed
const STREAM_SPEED := 9.0  # his cum down the pipe, per tick
const STREAM_W := 3.5      # its half width (the pipe bulges a little around it, as around a lump)
const SPLASH := 0.004      # what lands in it sets the surface swinging: tilt speed per unit
const FLARE_W := 16.0      # the pipe widens into the stomach: it meets the oval this far out from the pipe's wall
const FLARE_H := 18.0      # widening from this far above the oval
const STRAIGHT := 9.0      # the pipe's straight stretch down into the flare (three samples)
const GRAVITY := 0.8       # what pours in falls: speed gained per tick (local units)
const DRAG := 0.02         # and lost to the air in it, share per tick
const WALL_SLIDE := 0.9    # speed kept per tick while it runs down the wall
const RIPPLE_N := 40       # the surface's ripples: points along it
const RIPPLE_C := 0.3      # how fast they spread
const RIPPLE_DAMP := 0.92  # and die down (kept per tick)
const RIPPLE_MAX := 4.0    # the highest (local units)
const RIPPLE_HIT := 0.1    # how deep something landing pushes it, per unit landing at one unit per tick
const DROP_R := 1.2        # a droplet splashed up: its radius
const RUN_GAP := 3         # ticks without anything coming out that still keep a run going (his spurts come apart)

var opacity := 0.6
var shown := 0.0
var size := 1.0            # the plugin's Stomach size
var fill := 0.0            # how full it is (0 to 1 of its inside's area): amount / capacity
var amount := 0.0          # what is in it (the game's units of cum in her mouth)
var capacity := 80.0       # the amount that fills it (it stays full past that)
var digest := 0.0          # what it empties by per tick
var fill_col := Color(1.0, 0.98, 0.97)   # the cum's colour
var bounds := Rect2()
var wall_col := Color(0.8, 0.45, 0.45)
var lumen_col := Color(0.42, 0.1, 0.14)
var glow_col := Color(0.85, 0.15, 0.2, 0.55)
var _painter := Node2D.new()
var _skel := RID()                     # bone 0: her space; bone 1: her torso, between ticks (see the top)
var _xf := Transform2D()               # own space -> local, this tick, and the tick before
var _xf_prev := Transform2D()
var _mesh := ArrayMesh.new()           # what _painter / _flow draw, rebuilt every tick
var _flow_mesh := ArrayMesh.new()
var _surfs: Array = []                 # surfaces for the mesh being drawn
var _space := Transform2D()            # what the points given to _tri are in (-> local): identity, or _xf (own)
var _bw := 0.0                         # and their bone weight (on bone 1), when none is given per point
var _bones4 := PackedInt32Array()      # 0, 1, 0, 0 for each vertex, as many as needed
var _pipe_b := PackedFloat32Array()    # each pipe sample's weight on bone 1
var _mouth_cache := []                 # _mouth_parts, kept while _mouth_key holds
var _mouth_key := []
var _idx_cache := {}                   # _strip_idx
var _shape := PackedVector2Array()     # the outline in its own space, STEP apart, closed
var _shape_n := PackedVector2Array()   # its outward unit normals
var _inlet := Vector2.ZERO             # the top of the oval, where the pipe comes in (own space)
var _k := 1.0                          # local units per own unit (lengths given in local units are divided by it)
var _mouth := PackedVector2Array()     # the outline of the stomach and the pipe's last stretch as one (own space; open
var _mouth_n := PackedVector2Array()   # at the top of that stretch, where the pipe hands over), its outward normals
var _mouth_in := PackedVector2Array()  # the inside, from where the hand-over ends (its edge under the wall)
var _mouth_tri := PackedInt32Array()
var _mouth_src := PackedInt32Array()   # the _mouth sample each point of the inside comes from (-1: its two top ones)
var _mouth_y := Vector2.ZERO           # where the flare starts and where it meets the oval (own y)
var _mouth_k := -1.0                   # _k they were built for
var _mouth_top := 0.0                  # where the hand-over starts (own y)
var _i_hand := 0                       # the pipe's sample there
var _down := Vector2.DOWN              # down on the screen (own space)
var _drops: Array[Dictionary] = []     # pouring in, oldest first: p, v (own space), q (what it carries), run, drop
var _run := 0                          # the run the bits poured last are in (a new one after RUN_GAP ticks without)
var _pouring := false                  # bits came out this tick (the newest run hangs from the pipe)
var _quiet := 99                       # ticks since bits last came out
var _landed := {}                      # runs whose front reached the surface
var _ripple_h := PackedFloat32Array()  # the ripples' heights along the surface (local), and how fast they change
var _ripple_v := PackedFloat32Array()
var _surf := PackedVector2Array()      # the surface's ends (own space), last drawn
var _pipe := PackedVector2Array()      # the pipe's centre line, local, STEP apart
var _pipe_n := PackedVector2Array()
var _pipe_w := PackedFloat32Array()    # how much of the pipe shows at each sample (its top, its part in her throat)
var _inner := PackedVector2Array()     # the inside's outline, own space (its edge under the wall)
var _level_dir := Vector2.DOWN         # down for the contents (own space): square to their surface
var _tilt := 0.0                       # the surface's tilt from level (radians) and how fast it changes
var _tilt_v := 0.0
var _last_pos := Vector2.ZERO          # where its middle was last tick (in the scene), and how fast it went
var _acc := Vector2.ZERO               # how fast it speeds up, smoothed
var _last_vel := Vector2.ZERO
var _moving := false                   # _last_pos / _last_vel hold something
var _flows: Array[Dictionary] = []     # going down the pipe: s (its front, along the pipe), len (behind it), amount,
                                       # lump, speed, from (where a stream piece started), out (share poured in)
var _line_len := 0.0                   # the pipe's length along the line it follows (to the end of her throat)
var _pipe_len := 0.0                   # and its whole length
var _flow_from := 0.0                  # along the pipe: what flows shows from here (above: his tip and penis)
var _pipe_g := PackedFloat32Array()    # how much the pipe bulges at each sample (around a lump)
var _cum_w := PackedFloat32Array()     # the half width of what is in the pipe at each sample
var _level := 0.0                      # the contents' surface (along _level_dir, own space; past the bottom when empty)
var _flow := Node2D.new()
var _half_px := 0.5


func _init() -> void:
	super()
	mouseEnabled = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_painter.material = mat
	_painter.draw.connect(_paint)
	add_child(_painter)
	_flow.material = mat
	_flow.draw.connect(_paint_flow)
	add_child(_flow)
	_skel = RenderingServer.skeleton_create()
	RenderingServer.skeleton_allocate_data(_skel, 2, true)
	RenderingServer.skeleton_bone_set_transform_2d(_skel, 0, Transform2D())
	RenderingServer.skeleton_bone_set_transform_2d(_skel, 1, Transform2D())
	RenderingServer.canvas_item_attach_skeleton(_painter.get_canvas_item(), _skel)
	RenderingServer.canvas_item_attach_skeleton(_flow.get_canvas_item(), _skel)
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _skel.is_valid():
		RenderingServer.free_rid(_skel)


## Every frame: bone 1 where her torso is between ticks against where it was at this tick (the game glides it from
## the tick before to this one).
func _process(_delta: float) -> void:
	if shown <= 0.0 or not _skel.is_valid():
		return
	var m := Transform2D()
	if is_physics_interpolated_and_enabled():
		m = _xf_prev.interpolate_with(_xf, Engine.get_physics_interpolation_fraction()) * _xf.affine_inverse()
	RenderingServer.skeleton_bone_set_transform_2d(_skel, 1, m)


func _ready() -> void:
	RenderingServer.canvas_item_set_canvas_group_mode(get_canvas_item(),
		RenderingServer.CANVAS_GROUP_MODE_TRANSPARENT, 4.0, true, 4.0)


func _local_bounds() -> Rect2:
	return bounds


## A swallow of `units` starts down her throat.
func add_lump(units: float) -> void:
	_flows.append({"s": LUMP_START * _line_len, "len": LUMP_LEN, "amount": units, "lump": true,
		"speed": LUMP_SPEED * _line_len, "from": 0.0, "out": 0.0})


## A spurt tick's `units` start down from his tip (`from`, along the pipe; < 0: from the end of her throat).
func add_stream(from: float, units: float) -> void:
	if from < 0.0:
		from = _line_len
	_flows.append({"s": from, "len": 0.0, "amount": units, "lump": false, "speed": STREAM_SPEED, "from": from,
		"out": 0.0})


## Something is in it or on its way.
func in_use() -> bool:
	return amount > 0.01 or not _flows.is_empty() or not _drops.is_empty()


## Moves what is in the pipe on (shown or not), pours what comes out at its bottom in (straight into the contents
## while the stomach does not show), and empties it by `digest`.
func _advance() -> void:
	amount = maxf(0.0, amount - digest)
	var q := 0.0
	var speed := 0.0
	var keep: Array[Dictionary] = []
	for f in _flows:
		f["s"] += f["speed"]
		if not f["lump"]:
			f["len"] = minf(f["s"] - f["from"], 2.0 * STREAM_SPEED + 6.0)   # a little over the next piece: one line
		# how much of it is out at the bottom: over its length (a stream piece's reaches the next one: it comes out
		# as one stream, not a bit every spurt tick)
		var span: float = 2.0 * LUMP_LEN if f["lump"] else maxf(f["len"], f["speed"])
		var head: float = f["s"] + (LUMP_LEN if f["lump"] else 0.0)
		var out := clampf((head - _pipe_len) / span, 0.0, 1.0)
		if out > f["out"]:
			q += f["amount"] * (out - f["out"])
			speed = maxf(speed, f["speed"])
			f["out"] = out
		if out < 1.0 or f["s"] - f["len"] < _pipe_len + LUMP_LEN:
			keep.append(f)
	_flows = keep
	if shown <= 0.0:
		for d in _drops:
			_land(d["q"])
		_drops.clear()
		if q > 0.0:
			_land(q)
		_pouring = false
	else:
		_ripple_step()
		_move_drops()
		if q > 0.0:
			if _quiet > RUN_GAP:
				_run += 1
			_quiet = 0
			_drops.append({"p": _inlet + Vector2.DOWN * (WALL / _k), "v": Vector2.DOWN * (speed / _k), "q": q,
				"run": _run, "drop": false, "age": 0})
		else:
			_quiet += 1
		_pouring = q > 0.0
	fill = clampf(amount / capacity, 0.0, 1.0) if capacity > 0.0 else 0.0


func _land(q: float) -> void:
	if q <= 0.0:
		return
	amount = minf(capacity, amount + q)
	_tilt_v += SPLASH * q * (1.0 if randf() < 0.5 else -1.0)


## What pours in: falls, runs down the inside of the wall where it meets it, and lands where it reaches the surface.
func _move_drops() -> void:
	if _drops.is_empty():
		_landed.clear()
		return
	var g := _down * (GRAVITY / _k)
	var c := (WALL + 1.5) / _k   # it runs this far in from the outline (inside the wall)
	var ea := RADII.x - c
	var eb := RADII.y - c
	var gd := _level_dir
	var level := minf(_level, sqrt(ea * ea * gd.x * gd.x + eb * eb * gd.y * gd.y) - 0.5 / _k)   # empty: the bottom
	var keep: Array[Dictionary] = []
	var live := {}
	for d in _drops:
		var p: Vector2 = d["p"]
		var v: Vector2 = (d["v"] + g) * (1.0 - DRAG)
		p += v
		var f := (p.x / ea) * (p.x / ea) + (p.y / eb) * (p.y / eb)
		if f > 1.0:   # the wall: back onto it, sliding along it
			p /= sqrt(f)
			var nrm := Vector2(p.x / (ea * ea), p.y / (eb * eb)).normalized()
			var vn := v.dot(nrm)
			if vn > 0.0:
				v = (v - nrm * vn) * WALL_SLIDE
		d["p"] = p
		d["v"] = v
		d["age"] += 1
		if (v.dot(gd) > 0.0 and p.dot(gd) >= level) or d["age"] > 150:
			_land(d["q"])
			if not d["drop"]:
				_landed[d["run"]] = true
				var hit: float = d["q"] * v.length() * _k
				_ripple_at(p, hit)
				if hit > 6.0 and randf() < 0.35:
					_splash(p, gd)
			continue
		keep.append(d)
		live[d["run"]] = true
	_drops = keep
	for r in _landed.keys():
		if not live.has(r):
			_landed.erase(r)


## A droplet thrown up from where something lands.
func _splash(p: Vector2, gd: Vector2) -> void:
	_run += 1
	var side := Vector2(-gd.y, gd.x) * randf_range(-1.5, 1.5)
	_drops.append({"p": p - gd * (1.0 / _k), "v": (-gd * randf_range(1.8, 3.2) + side) / _k, "q": 0.0, "run": _run,
		"drop": true, "age": 0})
	_run += 1   # the stream goes on in a run of its own


## The ripples along the surface: a damped wave, its ends where the surface meets the wall.
func _ripple_step() -> void:
	if _ripple_h.size() != RIPPLE_N:
		_ripple_h.resize(RIPPLE_N)
		_ripple_v.resize(RIPPLE_N)
		_ripple_h.fill(0.0)
		_ripple_v.fill(0.0)
	var h := _ripple_h.duplicate()
	for k in RIPPLE_N:
		var l := h[maxi(k - 1, 0)]
		var r := h[mini(k + 1, RIPPLE_N - 1)]
		_ripple_v[k] = (_ripple_v[k] + RIPPLE_C * (l + r - 2.0 * h[k])) * RIPPLE_DAMP
		_ripple_h[k] = clampf(h[k] + _ripple_v[k], -RIPPLE_MAX, RIPPLE_MAX)


## Something lands on the surface at p (own space), with `hit` (what it carries times its speed): pushes it down there.
func _ripple_at(p: Vector2, hit: float) -> void:
	if _surf.size() != 2 or _ripple_h.size() != RIPPLE_N:
		return
	var s := _surf[1] - _surf[0]
	var u := clampf((p - _surf[0]).dot(s) / maxf(s.length_squared(), 1e-6), 0.0, 1.0)
	var at := u * (RIPPLE_N - 1)
	for k in RIPPLE_N:
		var d := k - at
		_ripple_v[k] -= minf(hit * RIPPLE_HIT, 1.5) * exp(-d * d * 0.5)


## Called every tick by the throat part; `want`: the stomach should show. line: what the pipe follows before it bends
## down into the stomach (local), going on along `bend` from its end; hand: the sample where the pipe has taken over
## from the throat part (its fade: throat_shown); flow_from: what flows shows from here along the line (his tip, or
## past the end of his penis where the throat part's upper painter draws it).
func update(want: bool, her: Her, line: PackedVector2Array, bend: Vector2, hand: float,
		throat_shown: float, flow_from: float) -> void:
	_advance()
	var was := shown
	shown = clampf(shown + (FADE if want else -FADE), 0.0, 1.0)
	visible = shown > 0.0
	# its opacity (and fade) on the whole cutaway, not on each layer in it (with `alpha`, modulate, which every
	# child takes, each layer would show the ones under it through it): the plugin's group shader
	alpha = 1.0
	if material is ShaderMaterial:
		material.set_shader_parameter(&"opacity", opacity * shown)
	if shown <= 0.0:
		_moving = false
		if was > 0.0:
			_redraw()
		return
	_flow_from = flow_from
	var tor: FlashDisplayObject = her.torso
	var cc: FlashDisplayObject = tor.chestCostume
	var bp: FlashDisplayObject = cc.bellyPiercing
	var navel: Vector2 = tor.globalToLocal(cc.localToGlobal(Vector2(bp.x, bp.y)))
	var leg: FlashDisplayObject = tor.leg
	var spine := Vector2.DOWN.angle_to(Vector2(leg.x, leg.y))   # from her shoulders (the torso's origin) to her hip
	var xf: Transform2D = flash_global_transform().affine_inverse() * tor.flash_global_transform() \
		* Transform2D(spine, Vector2(size, size), 0.0, navel + AT_NAVEL)
	_xf_prev = _xf if was > 0.0 else xf   # it shows again: no gliding in from where it was
	_xf = xf
	RenderingServer.skeleton_set_base_transform_2d(_skel, _painter.get_global_transform())   # bones in local space
	_k = xf.x.length()
	var n := _shape.size()
	_inner.resize(n)
	for i in n:
		_inner[i] = _shape[i] - _shape_n[i] * (WALL * 0.5 / _k)
	_slosh(xf)
	if absf(_k - _mouth_k) > 1e-4:
		_build_mouth()
	# the pipe: along the line, then bending down to the top of its last stretch, from straight above it (along her
	# spine), and straight down that into the stomach, to where its inside begins
	var down := xf.basis_xform(Vector2.DOWN).normalized()
	var top := xf * Vector2(0.0, _mouth_top)
	var end := xf * (_inlet + Vector2.DOWN * (WALL / _k))
	_pipe = _even(line)
	var n_line := _pipe.size()
	_line_len = (n_line - 1) * STEP
	var a := _pipe[-1]
	var d := a.distance_to(top)
	var raw := PackedVector2Array()
	for k in 33:
		raw.append(_cubic(a, a + bend * d * PIPE_DOWN, top - down * d * PIPE_IN, top, k / 32.0))
	_pipe.append_array(_even(raw).slice(1))
	if _pipe[-1].distance_to(top) > 0.1:
		_pipe.append(top)
	_i_hand = _pipe.size() - 1
	for k in range(1, int(top.distance_to(end) / STEP) + 1):
		_pipe.append(top + down * (k * STEP))
	if _pipe[-1].distance_to(end) > 0.1:
		_pipe.append(end)
	for _pass in 4:   # rounds the bend (the line stays as given: the throat part's centre line runs along it)
		var p := _pipe.duplicate()
		for i in range(n_line, _i_hand):
			_pipe[i] = (p[i - 1] + p[i] * 2.0 + p[i + 1]) * 0.25
	_pipe_n.resize(_pipe.size())
	_pipe_w.resize(_pipe.size())
	_pipe_b.resize(_pipe.size())
	for i in _pipe.size():
		var t := (_pipe[mini(i + 1, _pipe.size() - 1)] - _pipe[maxi(i - 1, 0)]).normalized()
		_pipe_n[i] = Vector2(-t.y, t.x)
		_pipe_w[i] = smoothstep(0.0, PIPE_TOP, i) * lerpf(1.0 - throat_shown, 1.0, smoothstep(hand - PIPE_TOP, hand, i))
		_pipe_b[i] = smoothstep(n_line - 1, _i_hand, i)   # her space along her throat, her torso from the straight
	_pipe_len = (_pipe.size() - 1) * STEP
	_in_pipe()
	bounds = Rect2(_pipe[0], Vector2.ZERO)
	for p in _shape:
		bounds = bounds.expand(xf * p)
	for p in _pipe:
		bounds = bounds.expand(p)
	bounds = bounds.grow(PIPE + WALL + GLOW + 12.0 + 30.0)   # and the torso's glide between ticks
	_redraw()


func _redraw() -> void:
	for p in [_painter, _flow]:
		p.queue_redraw()


## What is in the pipe at each sample (_cum_w), and how much the pipe bulges around it (_pipe_g). Stream pieces
## that touch make one run, its ends rounded (not each piece's: they would pinch where the pieces meet).
func _in_pipe() -> void:
	var n := _pipe.size()
	_cum_w.resize(n)
	_pipe_g.resize(n)
	_cum_w.fill(0.0)
	_pipe_g.fill(0.0)
	var runs := []
	for f in _flows:
		var head: float = f["s"]
		if not f["lump"]:
			runs.append([head - f["len"], head])
			continue
		var i0 := maxi(0, int(floor((head - LUMP_LEN) / STEP)))
		var i1 := mini(n - 1, int(ceil((head + LUMP_LEN) / STEP)))
		for i in range(i0, i1 + 1):
			var d: float = (i * STEP - head) / f["len"]
			_widen(i, (PIPE + LUMP_WIDE * f["amount"]) * exp(-d * d * 2.0))
	runs.sort_custom(func(a, b): return a[0] < b[0])
	var joined := []
	for r in runs:
		if not joined.is_empty() and r[0] <= joined[-1][1] + 2.0:
			joined[-1][1] = maxf(joined[-1][1], r[1])
		else:
			joined.append([r[0], r[1]])
	for r in joined:
		var back: float = r[0]
		var head: float = r[1]
		if head >= _pipe_len - 1.0:   # coming out at the bottom: on into the pour there, not rounded off
			head = _pipe_len + 2.0 * STEP
		for i in range(maxi(0, int(floor(back / STEP))), mini(n - 1, int(ceil(head / STEP))) + 1):
			var s := i * STEP
			_widen(i, STREAM_W * smoothstep(back - 1.0, back + 3.0, s) * (1.0 - smoothstep(head - 3.0, head + 1.0, s)))


func _widen(i: int, w: float) -> void:
	_pipe_g[i] = maxf(_pipe_g[i], w + 1.0 - PIPE)
	_cum_w[i] = maxf(_cum_w[i], w)


## The surface's tilt: a damped spring pulled towards how fast her body speeds up sideways (the contents lag behind).
func _slosh(xf: Transform2D) -> void:
	var gx := flash_global_transform() * xf   # its own space -> the stage
	var pos := transform * (xf * Vector2.ZERO)   # in the layer it is in: the scene, whatever the zoom
	var vel := pos - _last_pos if _moving else Vector2.ZERO
	var acc := vel - _last_vel if _moving else Vector2.ZERO
	_acc += (acc - _acc) * SLOSH_SMOOTH
	_last_pos = pos
	_last_vel = vel
	_moving = true
	var target := clampf(_acc.x * SLOSH_PUSH, -SLOSH_MAX, SLOSH_MAX)
	_tilt_v += (target - _tilt) * SLOSH_K - _tilt_v * SLOSH_DAMP
	_tilt = clampf(_tilt + _tilt_v, -SLOSH_MAX, SLOSH_MAX)
	_level_dir = gx.affine_inverse().basis_xform(Vector2.DOWN.rotated(_tilt)).normalized()
	_down = gx.affine_inverse().basis_xform(Vector2.DOWN).normalized()


## The outline: the oval sampled evenly, with its outward normals.
func _build() -> void:
	var fine := PackedVector2Array()
	for k in 361:
		var a := TAU * k / 360.0
		fine.append(Vector2(cos(a) * RADII.x, sin(a) * RADII.y))
	_shape = _even(fine)
	if _shape[-1].distance_to(_shape[0]) < STEP * 0.5:
		_shape.remove_at(_shape.size() - 1)
	var n := _shape.size()
	_shape_n.resize(n)
	_inlet = Vector2(0.0, -RADII.y)
	for i in n:
		var p := _shape[i]
		_shape_n[i] = Vector2(p.x / (RADII.x * RADII.x), p.y / (RADII.y * RADII.y)).normalized()   # its gradient


## The outline of the stomach with the pipe's last stretch (see the top), for _k: the pipe's outer edges straight down
## from where the hand-over starts, each curving out into the oval (a cubic, smooth both ends), and the oval round
## the bottom between them. Its inside is everything from where the hand-over ends.
func _build_mouth() -> void:
	_mouth_k = _k
	var fine_step := STEP * 0.5
	var r := (PIPE + WALL) / _k
	var xa := minf(r + FLARE_W / _k, RADII.x * 0.8)
	var ya := -RADII.y * sqrt(1.0 - (xa / RADII.x) * (xa / RADII.x))
	var ct := -xa / RADII.x   # the left meeting point's angle on the oval: cos, sin
	var st := ya / RADII.y
	var tl := Vector2(RADII.x * st, -RADII.y * ct).normalized()   # along the oval there, going down its left side
	var y1 := ya - FLARE_H / _k
	_mouth_top = y1 - STRAIGHT / _k
	var h := 0.6 * maxf(FLARE_W, FLARE_H) / _k
	var p0 := Vector2(-r, y1)
	var p3 := Vector2(-xa, ya)
	var flare := PackedVector2Array()
	for k in 25:
		flare.append(_cubic(p0, p0 + Vector2.DOWN * h, p3 - tl * h, p3, k / 24.0))
	var raw := PackedVector2Array([Vector2(-r, _mouth_top)])
	raw.append_array(flare)
	var t0 := atan2(st, ct)
	var t1 := atan2(st, -ct) - TAU
	for k in range(1, 720):
		var t := lerpf(t0, t1, k / 720.0)
		raw.append(Vector2(cos(t) * RADII.x, sin(t) * RADII.y))
	for k in range(24, -1, -1):
		raw.append(Vector2(-flare[k].x, flare[k].y))
	raw.append(Vector2(r, _mouth_top))
	_mouth = _even(raw, fine_step)
	if _mouth[-1].distance_to(raw[-1]) > 0.01:
		_mouth.append(raw[-1])
	var n := _mouth.size()
	_mouth_n.resize(n)
	for i in n:
		var t := (_mouth[mini(i + 1, n - 1)] - _mouth[maxi(i - 1, 0)]).normalized()
		_mouth_n[i] = Vector2(-t.y, t.x)
	_mouth_y = Vector2(y1, ya)
	_mouth_in.clear()
	_mouth_src.clear()
	var ri := r - WALL * 0.5 / _k
	_mouth_in.append(Vector2(-ri, y1))   # exactly where the pipe's inside ends
	_mouth_src.append(-1)
	for i in n:
		if _mouth[i].y > y1 + 1e-4:
			_mouth_in.append(_mouth[i] - _mouth_n[i] * (WALL * 0.5 / _k))
			_mouth_src.append(i)
	_mouth_in.append(Vector2(ri, y1))
	_mouth_src.append(-1)
	_mouth_tri = Geometry2D.triangulate_polygon(_mouth_in)


## How far out (own units) the pipe's last stretch bulges at each _mouth sample, around what passes down it (as the
## pipe does above it: _pipe_g), fading out down the flare; empty when nothing does.
func _mouth_bulge() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var any := false
	for i in range(_i_hand, _pipe_g.size()):
		if _pipe_g[i] > 0.01:
			any = true
			break
	if not any:
		return out
	out.resize(_mouth.size())
	out.fill(0.0)
	var reach := (PIPE + WALL + FLARE_W) / _k
	for i in _mouth.size():
		var p := _mouth[i]
		if p.y >= _mouth_y.y or absf(p.x) > reach:
			continue
		var k := _i_hand + (p.y - _mouth_top) * _k / STEP   # the pipe sample level with it
		var k0 := clampi(int(k), 0, _pipe_g.size() - 1)
		var k1 := mini(k0 + 1, _pipe_g.size() - 1)
		var gl := lerpf(_pipe_g[k0], _pipe_g[k1], k - floorf(k))
		out[i] = gl / _k * (1.0 - smoothstep(_mouth_y.x, _mouth_y.y, p.y))
	return out


static func _cubic(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * (u * u * u) + b * (3.0 * u * u * t) + c * (3.0 * u * t * t) + d * (t * t * t)


static func _even(raw: PackedVector2Array, step := STEP) -> PackedVector2Array:
	var out := PackedVector2Array([raw[0]])
	var want := step
	var walked := 0.0
	for i in range(1, raw.size()):
		var a := raw[i - 1]
		var seg := a.distance_to(raw[i])
		while seg > 0.0 and walked + seg >= want:
			out.append(a.lerp(raw[i], (want - walked) / seg))
			want += step
		walked += seg
	return out


## Half a screen pixel in a painter's units: MSAA does not reach into a canvas group, so edges fade out over one
## screen pixel instead (as the throat's).
func _half_px_of(p: Node2D) -> float:
	var screen := p.get_viewport().get_final_transform() * p.get_global_transform_with_canvas()
	return 0.5 / maxf(maxf(screen.x.length(), screen.y.length()), 0.01)


## Pipe and stomach (see the top), one mesh: their insides (the pipe's a little into the stomach's: no edge between
## them), the contents and what pours in, then the glow and the wall along their one outline: down the pipe's one
## side to where the flare starts, round the stomach (own space, _mouth_parts), up the pipe's other side; the parts
## share their points where they meet, so they join as one line.
func _paint() -> void:
	if shown <= 0.0 or _pipe.size() < 2 or _mouth.size() < 3 or _inner.size() < 3:
		return
	var ci := _painter.get_canvas_item()
	var half_local := _half_px_of(_painter)
	var j := mini(_i_hand + int(round(STRAIGHT / STEP)), _pipe.size() - 1)   # the pipe sample where the flare starts
	var i0 := 0   # from where the pipe shows (while the throat part shows, the pipe takes over only low on her neck)
	while i0 < j and _pipe_w[i0] <= 0.001:
		i0 += 1
	i0 = maxi(0, i0 - 1)
	var mouth := _mouth_parts(half_local)
	# the insides: the stomach's, the pipe's down into it
	_add_own(mouth[0])
	_half_px = half_local
	_space = Transform2D.IDENTITY
	var m := j + 2
	var line := _pipe.slice(i0, m)
	if line.size() >= 2:
		line[-1] += (line[-1] - line[-2]).normalized() * 1.5
	_band(ci, line, _pipe_n.slice(i0, m), false, -PIPE, PIPE, lumen_col, _pipe_w.slice(i0, m), _pipe_g.slice(i0, m),
		_pipe_b.slice(i0, m))
	# what is in the stomach (own space)
	_half_px = half_local / _k
	_space = _xf
	_bw = 1.0
	_level = -INF
	for p in _inner:
		_level = maxf(_level, p.dot(_level_dir))
	_surf.clear()
	if fill > 0.001:
		_contents(ci)
	if not _drops.is_empty():
		_paint_drops(ci)
	# the pipe's sides (local), to where the flare starts
	_half_px = half_local
	_space = Transform2D.IDENTITY
	var sides := []
	for side: float in [1.0, -1.0]:
		var out := PackedVector2Array()
		var glow := PackedVector2Array()   # round the bulge it would fold where the flare curves in: none there
		var nrm := PackedVector2Array()
		for i in range(i0, j + 1):
			var g := _pipe_g[i]
			var n := _pipe_n[i] * side
			out.append(_pipe[i] + n * (PIPE + WALL + g))
			glow.append(_pipe[i] + n * (PIPE + WALL + g * (1.0 - smoothstep(_i_hand, j, i))))
			nrm.append(n)
		sides.append([out, glow, nrm])
	var w := _pipe_w.slice(i0, j + 1)
	var bw := _pipe_b.slice(i0, j + 1)
	for sd in sides:
		_glow(ci, sd[1], sd[2], false, 0.0, 0.0, GLOW, w, PackedFloat32Array(), bw)
	_add_own(mouth[1])
	for sd in sides:
		_band(ci, sd[0], sd[2], false, -WALL, 0.0, wall_col, w, PackedFloat32Array(), bw)
	_add_own(mouth[2])
	_flush(ci, _mesh)


## The stomach's part of the mesh, in its own space: [inside, glow, wall] (lists of surfaces), from where the flare
## starts round to where it starts on the other side. The same every tick (kept) unless something passing down the
## pipe bulges the flare.
func _mouth_parts(half_local: float) -> Array:
	var bulge := _mouth_bulge()
	var key := [_k, wall_col, glow_col, lumen_col, snappedf(half_local, 0.001)]
	if bulge.is_empty() and key == _mouth_key:
		return _mouth_cache
	_half_px = half_local / _k
	_space = Transform2D.IDENTITY
	_bw = 1.0
	var parts := []
	# the inside
	var inside := _mouth_in
	if not bulge.is_empty():
		inside = _mouth_in.duplicate()
		for k in inside.size():
			var src := _mouth_src[k]
			if src >= 0:
				inside[k] += _mouth_n[src] * bulge[src]
			else:   # its top corners: as the points next to them
				inside[k].x += signf(inside[k].x) * bulge[_mouth_src[1 if k == 0 else inside.size() - 2]]
	var cols := PackedColorArray()
	cols.resize(inside.size())
	cols.fill(_pm(lumen_col))
	var at := _surfs.size()
	_tri(_mouth_tri if not _mouth_tri.is_empty() else _fan(inside.size()), inside, cols)
	parts.append(_surfs.slice(at))
	# the outline, its ends exactly where the pipe's sides end (the flare's start, as the bulge there)
	var r := (PIPE + WALL) / _k
	var j := mini(_i_hand + int(round(STRAIGHT / STEP)), _pipe_g.size() - 1)
	var b0 := (_pipe_g[j] / _k) if not bulge.is_empty() and j >= 0 else 0.0
	var line := PackedVector2Array([Vector2(-r - b0, _mouth_y.x)])
	var glow := PackedVector2Array([Vector2(-r, _mouth_y.x)])
	var nrm := PackedVector2Array([Vector2.LEFT])
	for i in _mouth.size():
		var p := _mouth[i]
		if p.y <= _mouth_y.x + 1e-4:
			continue
		glow.append(p)
		line.append(p + _mouth_n[i] * (bulge[i] if not bulge.is_empty() else 0.0))
		nrm.append(_mouth_n[i])
	line.append(Vector2(r + b0, _mouth_y.x))
	glow.append(Vector2(r, _mouth_y.x))
	nrm.append(Vector2.RIGHT)
	at = _surfs.size()
	_glow(RID(), glow, nrm, false, 0.0, 0.0, GLOW / _k)
	parts.append(_surfs.slice(at))
	at = _surfs.size()
	_band(RID(), line, nrm, false, -WALL / _k, 0.0, wall_col)
	parts.append(_surfs.slice(at))
	_surfs.resize(at - parts[0].size() - parts[1].size())   # kept apart: _add_own puts them in where they go
	_mouth_key = key if bulge.is_empty() else []
	_mouth_cache = parts
	return parts


## Puts surfaces built in the stomach's own space into the mesh, where it is this tick.
func _add_own(surfaces: Array) -> void:
	for arr in surfaces:
		var a2: Array = arr.duplicate()
		a2[Mesh.ARRAY_VERTEX] = _xf * (arr[Mesh.ARRAY_VERTEX] as PackedVector2Array)
		_surfs.append(a2)


## What pours in (own space): each run of bits as one stream through them (smoothed), as wide as what they carry
## at their speed makes it (a stream thins as it falls faster), hanging from the pipe while it still comes, reaching
## down to the surface once its front got there, rounded at its free ends; a droplet as a dot.
func _paint_drops(ci: RID) -> void:
	var runs := {}
	for d in _drops:
		if not runs.has(d["run"]):
			runs[d["run"]] = []
		runs[d["run"]].append(d)
	var gd := _level_dir
	for r in runs:
		var ds: Array = runs[r]
		var pts := PackedVector2Array()
		var hw := PackedFloat32Array()
		var front: Dictionary = ds[0]
		var fv: Vector2 = front["v"]
		var down_to := _landed.has(r) and fv.dot(gd) > 1e-4
		if down_to:
			var t := clampf((_level - (front["p"] as Vector2).dot(gd)) / fv.dot(gd), 0.0, 1.5)
			pts.append(front["p"] + fv * t)
			hw.append(_drop_w(front))
		for d in ds:
			pts.append(d["p"])
			hw.append(_drop_w(d))
		var hangs: bool = r == _run and _pouring
		if pts.size() == 1:
			_dot(ci, pts[0], hw[0])
			continue
		var line := PackedVector2Array()
		var lw := PackedFloat32Array()
		for i in pts.size() - 1:   # Catmull-Rom through the bits
			var p0 := pts[maxi(i - 1, 0)]
			var p1 := pts[i]
			var p2 := pts[i + 1]
			var p3 := pts[mini(i + 2, pts.size() - 1)]
			for k in 4:
				var t := k / 4.0
				var t2 := t * t
				line.append(0.5 * (p1 * 2.0 + (p2 - p0) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2
					+ (p1 * 3.0 - p0 - p2 * 3.0 + p3) * t2 * t))
				lw.append(lerpf(hw[i], hw[i + 1], t))
		line.append(pts[-1])
		lw.append(hw[-1])
		var nrm := PackedVector2Array()
		for i in line.size():
			var tng := (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]).normalized()
			nrm.append(Vector2(-tng.y, tng.x))
		_band(ci, line, nrm, false, 0.0, 0.0, fill_col, PackedFloat32Array(), lw)
		if not down_to:   # its front: a round drop, gathering what comes behind it
			_dot(ci, line[0], lw[0] * 1.3)
		if not hangs:
			_dot(ci, line[-1], lw[-1])


## A bit's half width (own space).
func _drop_w(d: Dictionary) -> float:
	if d["drop"]:
		return DROP_R / _k
	var speed: float = (d["v"] as Vector2).length() * _k
	return clampf(STREAM_W * pow(d["q"] * STREAM_SPEED / maxf(speed, 1.5), 0.3), 1.2, 5.0) / _k


## A round blob (own space), its edge fading out across a pixel.
func _dot(ci: RID, p: Vector2, r: float) -> void:
	var h := _half_px
	var c := _pm(fill_col)
	var n := 16
	var pts := PackedVector2Array([p])
	var cols := PackedColorArray([c])
	var idx := PackedInt32Array()
	for k in n:
		var dir := Vector2.from_angle(TAU * k / n)
		pts.append_array([p + dir * maxf(r - h, 0.0), p + dir * (r + h)])
		cols.append_array([c, Color(0, 0, 0, 0)])
	for k in n:
		var a := 1 + k * 2
		var b := 1 + ((k + 1) % n) * 2
		idx.append_array([0, a, b, a, a + 1, b, b, a + 1, b + 1])
	_tri(idx, pts, cols)


## What is in the pipe: on top of everything (her throat closes past his tip: it shows there too), where the pipe
## shows or past his tip; on the pipe's bones.
func _paint_flow() -> void:
	if shown <= 0.0 or _cum_w.size() != _pipe.size() or _flows.is_empty():
		return
	_half_px = _half_px_of(_flow)
	_space = Transform2D.IDENTITY
	var w := PackedFloat32Array()
	w.resize(_pipe.size())
	for i in _pipe.size():
		w[i] = clampf(_cum_w[i] * 2.0, 0.0, 1.0) * (1.0 if i * STEP >= _flow_from else _pipe_w[i])
	var ci := _flow.get_canvas_item()
	_band(ci, _pipe, _pipe_n, false, 0.0, 0.0, fill_col, w, _cum_w, _pipe_b)
	_flush(ci, _flow_mesh)


## Triangles fanning out from the first point (the outlines are convex).
static func _fan(n: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for i in range(1, n - 1):
		idx.append_array([0, i, i + 1])
	return idx


## The contents: the part of the inside below a line square to _level_dir, as much of its area as `fill`, darker
## deeper down, with a darker line along their surface, rippled (_ripple_h). The level comes from the oval itself (in a circle the oval
## maps to, the share of a segment's area is known), not from the inside's outline: close enough, and found at once.
func _contents(ci: RID) -> void:
	var gd := _level_dir
	var top := INF
	var bottom := -INF
	for p in _inner:
		top = minf(top, p.dot(gd))
		bottom = maxf(bottom, p.dot(gd))
	var level := top - 1.0
	var surf := PackedVector2Array()
	if fill < 0.999:
		# p = RADII * u, u in the unit circle: the line p . gd = level is u . w = s there
		var w := Vector2(gd.x * RADII.x, gd.y * RADII.y)
		level = _segment_at(fill) * w.length()
	_level = level
	var poly := _below(_inner, gd, level, surf)
	if poly.size() < 3:
		return
	var up := -gd
	var wave := PackedVector2Array()   # the surface, rippled; its ends where it meets the wall
	var rippled := surf.size() == 2 and _ripple_h.size() == RIPPLE_N
	if surf.size() == 2:
		_surf = surf.duplicate()
		for k in RIPPLE_N:
			var u := k / float(RIPPLE_N - 1)
			var rh := _ripple_h[k] * sin(PI * u) if rippled else 0.0   # held at the wall
			wave.append(surf[0].lerp(surf[1], u) + up * (rh / _k))
		# in place of the straight edge between the two crossings
		var i0 := poly.find(surf[0])
		var i1 := poly.find(surf[1])
		var mid := wave.slice(1, RIPPLE_N - 1)
		if poly[(i0 + 1) % poly.size()] == surf[1]:
			for k in mid.size():
				poly.insert(i0 + 1 + k, mid[k])
		else:
			mid.reverse()
			for k in mid.size():
				poly.insert(i1 + 1 + k, mid[k])
	var cols := PackedColorArray()
	var deep := maxf(bottom - level, 1.0)
	var c0 := _pm(fill_col)
	var c1 := _pm(Color(fill_col.r * FILL_DARK, fill_col.g * FILL_DARK, fill_col.b * FILL_DARK, fill_col.a))
	for p in poly:
		cols.append(c0.lerp(c1, clampf((p.dot(gd) - level) / deep, 0.0, 1.0)))
	var tri := Geometry2D.triangulate_polygon(poly) if wave.size() > 0 else PackedInt32Array()
	_tri(tri if not tri.is_empty() else _fan(poly.size()), poly, cols)
	if wave.is_empty():
		return
	# the surface line: darker, its top edge fading out across a pixel; its ends go on under the wall
	var along := (surf[1] - surf[0]).normalized() * (WALL * 0.4 / _k)
	wave[0] -= along
	wave[-1] += along
	var h := _half_px
	var sc := _pm(fill_col.darkened(0.15))
	var pts := PackedVector2Array()
	var rows := [[-SURFACE * 2.0 / _k, c0], [-SURFACE / _k, sc], [-h, sc], [h, Color(0, 0, 0, 0)]]
	var scols := PackedColorArray()
	for r in rows:
		for p in wave:
			pts.append(p + up * float(r[0]))
			scols.append(r[1])
	var n := wave.size()
	var idx := PackedInt32Array()
	for row in 3:
		for k in n - 1:
			var a := row * n + k
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	_tri(idx, pts, scols)


## Where a line cuts a unit circle (its distance from the middle, -1 to 1) so that the part past it is `share` of the
## circle's area.
static func _segment_at(share: float) -> float:
	var a := -1.0
	var b := 1.0
	for _i in 30:
		var s := (a + b) * 0.5
		var th := 2.0 * acos(s)
		if (th - sin(th)) / TAU > share:
			a = s
		else:
			b = s
	return (a + b) * 0.5


## The part of a convex outline at or past `level` along gd (deeper), and in `surf` the two points where the line
## crosses it.
static func _below(poly: PackedVector2Array, gd: Vector2, level: float, surf: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	surf.clear()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var da := a.dot(gd) - level
		var db := b.dot(gd) - level
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			var x := a.lerp(b, da / (da - db))
			out.append(x)
			surf.append(x)
	return out


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


static func _pm(col: Color) -> Color:
	return Color(col.r * col.a, col.g * col.a, col.b * col.a, col.a)


## A strip along a line from lo to hi off it, in one colour (times `w` at each sample, if given), its edges fading
## out across one screen pixel.
func _band(_ci: RID, line: PackedVector2Array, norm: PackedVector2Array, closed: bool, lo: float, hi: float,
		col: Color, w := PackedFloat32Array(), grow := PackedFloat32Array(), bw := PackedFloat32Array()) -> void:
	var n := line.size()
	if n < 2:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.resize(n * 4)
	cols.resize(n * 4)
	cols.fill(Color(0, 0, 0, 0))   # transparent where not set
	var wts := PackedFloat32Array()
	if not bw.is_empty():
		wts.resize(n * 16)
	var h := _half_px
	var c := _pm(col)
	var has_g := not grow.is_empty()
	var has_w := not w.is_empty()
	for i in n:
		var g := grow[i] if has_g else 0.0
		var d0 := lo - g
		var d1 := hi + g
		var mid := (d0 + d1) * 0.5
		var p := line[i]
		var nr := norm[i]
		var v := i * 4
		pts[v] = p + nr * (d0 - h)
		pts[v + 1] = p + nr * minf(d0 + h, mid)
		pts[v + 2] = p + nr * maxf(d1 - h, mid)
		pts[v + 3] = p + nr * (d1 + h)
		var cw := c * w[i] if has_w else c
		cols[v + 1] = cw
		cols[v + 2] = cw
		if not wts.is_empty():
			var b1 := bw[i]
			var b0 := 1.0 - b1
			var o := i * 16
			wts[o] = b0
			wts[o + 1] = b1
			wts[o + 4] = b0
			wts[o + 5] = b1
			wts[o + 8] = b0
			wts[o + 9] = b1
			wts[o + 12] = b0
			wts[o + 13] = b1
	_tri(_strip_idx(n, 4, closed), pts, cols, wts)


## A strip from base + inner (glow colour) to base + outer (transparent), starting half a pixel under the wall.
func _glow(_ci: RID, line: PackedVector2Array, norm: PackedVector2Array, closed: bool, base: float, inner: float,
		outer: float, w := PackedFloat32Array(), grow := PackedFloat32Array(), bw := PackedFloat32Array()) -> void:
	var n := line.size()
	if n < 2:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.resize(n * 2)
	cols.resize(n * 2)
	cols.fill(Color(0, 0, 0, 0))
	var wts := PackedFloat32Array()
	if not bw.is_empty():
		wts.resize(n * 8)
	var under := -signf(outer - inner) * _half_px
	var gc := _pm(glow_col)
	var has_g := not grow.is_empty()
	var has_w := not w.is_empty()
	for i in n:
		var b0 := base + signf(base) * (grow[i] if has_g else 0.0)
		var v := i * 2
		pts[v] = line[i] + norm[i] * (b0 + inner + under)
		pts[v + 1] = line[i] + norm[i] * (b0 + outer)
		cols[v] = gc * w[i] if has_w else gc
		if not wts.is_empty():
			var b1 := bw[i]
			var o := i * 8
			wts[o] = 1.0 - b1
			wts[o + 1] = b1
			wts[o + 4] = 1.0 - b1
			wts[o + 5] = b1
	_tri(_strip_idx(n, 2, closed), pts, cols, wts)


## The triangles of a strip of n samples, `per` points across each (kept: the same for the same sizes).
func _strip_idx(n: int, per: int, closed: bool) -> PackedInt32Array:
	var key := n * 8 + per * 2 + int(closed)
	if _idx_cache.has(key):
		return _idx_cache[key]
	var idx := PackedInt32Array()
	for i in (n if closed else n - 1):
		var a := i * per
		var b := ((i + 1) % n) * per
		for k in per - 1:
			idx.append_array([a + k, a + k + 1, b + k, a + k + 1, b + k + 1, b + k])
	if _idx_cache.size() > 256:
		_idx_cache.clear()
	_idx_cache[key] = idx
	return idx


## Adds triangles to the mesh being drawn: points in _space (-> local), bone weights per vertex (4 each: on bones 0,
## 1) or else all _bw on bone 1.
func _tri(idx: PackedInt32Array, pts: PackedVector2Array, cols: PackedColorArray,
		wts := PackedFloat32Array()) -> void:
	var n := pts.size()
	if n == 0 or idx.is_empty():
		return
	if wts.size() != n * 4:
		wts = PackedFloat32Array([1.0 - _bw, _bw, 0.0, 0.0])
		while wts.size() < n * 4:
			wts.append_array(wts.slice(0, mini(wts.size(), n * 4 - wts.size())))
	while _bones4.size() < n * 4:
		_bones4.append_array(_bones4 if not _bones4.is_empty() else PackedInt32Array([0, 1, 0, 0]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _space * pts if _space != Transform2D.IDENTITY else pts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	arr[Mesh.ARRAY_BONES] = _bones4.slice(0, n * 4)
	arr[Mesh.ARRAY_WEIGHTS] = wts
	_surfs.append(arr)


## Draws what _tri gathered, as one mesh.
func _flush(ci: RID, mesh: ArrayMesh) -> void:
	mesh.clear_surfaces()
	for arr in _surfs:
		if mesh.get_surface_count() < RenderingServer.MAX_MESH_SURFACES:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	_surfs.clear()
	if mesh.get_surface_count() > 0:
		RenderingServer.canvas_item_add_mesh(ci, mesh.get_rid())
