extends SDTExtension
## Built-in, after sby's Loader mod chokerCollarResistance (V4), on the throat ring model (ThroatRings.collar): while
## she wears a collar, it holds her throat. Behaviour > Resistance, "Collar holds her throat", off by default. Through
## value points:
##   - Her.resistance: like her throat entrance, a wall across the collar's band: past its top edge pushing in gets
##     harder, up to the collar's wall at its bottom edge; once he is through, only a squeeze (SQUEEZE of it);
##   - Her.pushBack: while he is in the band her head is pushed back, by how far he is into it and how much the ring
##     holds - like the game's intro limit;
##   - Her.limpResistance: the wall holds while she is passed out too (the game holds nothing then);
##   - Neck.band: under the collar her neck may push out only as far as the collar gives, so the throat bulge does not
##     go through it; above and below it her neck bulges, with a soft step at each edge.
## "Collar stiffness" (0 a soft band .. 1 metal, one setting for every collar) sets everything that holds him back:
## the wall, the push-back, how far the collar's front gives way and how fast it stretches (ThroatRings). 0 holds
## nothing: the collar rides along with her neck. The wall can be set apart from code (ThroatRings.set_wall, for
## dialogue or automation) and in Developer mode (Body > Throat rings).
## "Collar stretches": the collar's front is a fast spring pushed out by her throat - it gives way at once as far as
## its softness lets it, more as the ring stretches - and its picture follows; the back, at her nape, stays put.
## "Wince when it holds": she winces while it holds him back (the mod's option). "Collar can break" (off: collars
## never break): a worn out collar snaps, then holds nothing and rides along until repaired.
## Pressure comes from what he does, not from holding the mouse button (the mod's), so auto mode works the same.
## Not taken: the dialogue line "collarresistance", the breath option during the intro, reactions when it snaps.

const PUSH := 0.0015          # pos pushed back per pixel into the band, at hold 1 (the game's intro: 0.0015)
const SQUEEZE := 0.1          # share of the wall left past its bottom edge (through it: it only squeezes)
const GIVE := 6.0             # px the front gives way at stiffness 0.5; GIVE x (1 - k) / k (0: free, 1: none)
const SPRING := 1.0           # the collar's front: pull toward her throat per tick per px
const DAMP := 0.6             # share of its speed lost per tick (it settles in about 3 ticks, a little overshoot)
const SLACK := 3.0            # px her throat may press into the collar before it gives way
const WINCE_RES := 0.1        # the collar resists at least this much while he pushes: she winces
const BAND_GAP := 2.0         # px the outline may push out under the collar (the collar sits on the skin)
const BAND_WIDEN := 70.0 * 0.25   # px more fully stretched (the mod's 25 % of 70 px)
const BAND_SOFT := 0.08       # depth past each edge over which the held outline blends into the free bulge

var _push_fn := Callable()
var _resist_fn := Callable()
var _limp_fn := Callable()
var _band_fn := Callable()
var _widened := false
var _collar_x := 0.0
var _back := {}               # collar name -> [back edge, width] in its own space (back: its left side, her nape)
var band = null               # the band the collar holds her neck with now (Neck.band), or null; refresh_band()
var push_px := 0.0            # how far the collar's front is pushed out now (px, a spring pushed by her throat)
var push_speed := 0.0


func _init() -> void:
	id = "chokercollarresistance"
	title = "chokerCollarResistance"
	description = "chokerCollarResistance (sby): her collar holds her throat and stretches (Behaviour > Resistance)."
	default_enabled = true


func _setup() -> void:
	setting("on", false, {"label": "Collar holds her throat",
		"desc": "While she wears a collar it holds like her throat: past its top edge going deeper is harder and her head is pushed back, and her neck stays narrow under it as far as it gives."})
	setting("widen", true, {"label": "Collar stretches", "desc": "The collar's front gives way after her throat."})
	setting("wince", true, {"label": "Wince when it holds", "desc": "She winces while the collar holds him back."})
	setting("breaks", false, {"label": "Collar can break",
		"desc": "Pressed long and hard enough the collar snaps; then it holds nothing and only rides along with her neck. Off: collars never break."})


func _enable() -> void:
	_push_fn = func(v, _her) -> float:
		return v + _band_past() * ThroatRings.DEPTH_SCALE * PUSH * ThroatRings.collar["hold"]
	_resist_fn = func(v, _her) -> float:
		return v + wall()
	_limp_fn = func(v, _her) -> float:
		return v + wall()
	_band_fn = func(v, _neck):
		return Neck.narrower(v, band)
	on_late_tick(_tick)
	var on := func(): return get_setting("on")
	var after := {"after": "Throat resistance"}
	menu_control("behaviour", "Resistance", MenuSchema.setting_control(self, "on", after))
	menu_control("behaviour", "Resistance", {"type": "slider", "label": "Collar stiffness", "after": "Throat resistance",
		"tip": "One setting for every collar. 0: holds nothing, rides along with her neck. Higher: holds harder and gives less. 1: metal - a wall, never gives.",
		"min": 0.0, "max": 1.0, "step": 0.05, "get": func(): return ThroatRings.stiffness,
		"set": func(v: float): ThroatRings.set_stiffness(v), "format": func(v): return "%.2f" % v, "visible": on,
		"reset": func(): ThroatRings.set_stiffness(ThroatRings.DEFAULT_STIFFNESS),
		"wide": true})   # the label above the slider: beside the extension's tag it would not fit
	for key in ["widen", "wince", "breaks"]:
		menu_control("behaviour", "Resistance", MenuSchema.setting_control(self, key, {"after": "Throat resistance", "visible": on}))
	menu_control("behaviour", "Resistance", MenuSchema.actions("", "", [["Repair collar", func(): ThroatRings.repair(),
		"A snapped collar holds again."]], {"after": "Throat resistance",
		"visible": func(): return get_setting("on") and get_setting("breaks")}))
	ThroatRings.load_stiffness()
	_apply()


func _disable() -> void:
	_release()
	ThroatRings.collar_breaks = false
	ThroatRings._apply_stiffness()


func _setting_changed(_key: String, _value) -> void:
	_apply()


func _apply() -> void:
	unmodify()
	if ThroatRings.collar_breaks != bool(get_setting("breaks")):
		ThroatRings.collar_breaks = get_setting("breaks")
		ThroatRings._apply_stiffness()
	if get_setting("on"):
		modify(&"Her.pushBack", {"phase": Hooks.MOOD, "op": "fn", "fn": _push_fn})
		modify(&"Her.resistance", {"phase": Hooks.MOOD, "op": "fn", "fn": _resist_fn, "order": 10})
		modify(&"Her.limpResistance", {"phase": Hooks.MOOD, "op": "fn", "fn": _limp_fn, "order": 10})
		modify(&"Neck.band", {"phase": Hooks.CLAMP, "op": "fn", "fn": _band_fn})
	else:
		_release()
	if not get_setting("widen"):
		_unwiden()
	refresh_band()


func _release() -> void:
	unmodify()
	_unwiden()


## True while the collar holds nothing and rides along with her neck: stiffness 0, or snapped.
func rides_free() -> bool:
	var c: Dictionary = ThroatRings.collar
	return c["snapped"] or ThroatRings.collar_stiffness() <= 0.0


## How far (px) the collar's front may give way now: from its softness at once, plus what the ring has stretched;
## INF when it rides free, 0 when its picture does not widen ("Collar stretches" off).
func room() -> float:
	if not get_setting("widen"):
		return 0.0
	if rides_free():
		return INF
	var k := ThroatRings.collar_stiffness()
	return GIVE * (1.0 - k) / k + ThroatRings.collar["stretch"] * BAND_WIDEN


## The band (Neck.band) the collar holds her neck with, worked out once a tick (and when a setting changes): between
## the collar's edges her neck may push out as far as the collar has given way (plus the slack); null while it does
## not hold (off, no collar, riding free).
func refresh_band() -> void:
	var c: Dictionary = ThroatRings.collar
	if not (get_setting("on") and c["on"] and not rides_free()):
		band = null
		return
	band = {"top": c["top"], "bottom": c["bottom"], "inside": BAND_GAP + minf(room(), push_px + SLACK), "soft": BAND_SOFT}


## How far (depth units) his tip is into the collar's band (0 above it, the band's height once through) while it holds:
## where her head is now (ThroatRings.tip_now), not a tick late, so she rests on the band instead of swinging on it.
func _band_past() -> float:
	var c: Dictionary = ThroatRings.collar
	if not c["on"] or c["snapped"] or g.penisOut:
		return 0.0
	return clampf(ThroatRings.tip_now(g.her) - c["top"], 0.0, c["bottom"] - c["top"])


## What the collar adds to her resistance now: like her throat entrance, rising across its band up to its wall (less
## what the ring has stretched) at the bottom edge; once he is through, a little squeeze.
func wall() -> float:
	var c: Dictionary = ThroatRings.collar
	var past := _band_past()
	if past <= 0.0:
		return 0.0
	var w: float = ThroatRings.collar_wall * (1.0 - c["stretch"])
	if ThroatRings.tip_now(g.her) >= c["bottom"]:
		return SQUEEZE * w
	return w * past / maxf(0.001, c["bottom"] - c["top"])


func _tick() -> void:
	var her = g.her
	if not get_setting("on") or her == null or g.gamePaused:
		return
	ThroatRings.tick(her)
	var c: Dictionary = ThroatRings.collar
	if get_setting("widen") and c["on"]:
		_spring(_throat_push(her.head.neck, c))
		_widen(her)
	else:
		push_px = 0.0
		push_speed = 0.0
		if _widened:
			_unwiden()
	if get_setting("wince") and ThroatRings.push > 0.2 and wall() >= WINCE_RES:
		her.wince()
	refresh_band()


## The collar's front: a fast spring pulled toward where her throat pushes it, no further out than it can give and
## never into her neck.
func _spring(target: float) -> void:
	push_speed = (push_speed + (target - push_px) * SPRING) * (1.0 - DAMP)
	push_px += push_speed
	var most := room()
	if push_px > most or push_px < 0.0:
		push_px = clampf(push_px, 0.0, most)
		push_speed = 0.0


## How far her throat pushes out under the collar this tick (px past the gap, from the drawn neck).
func _throat_push(neck, c: Dictionary) -> float:
	var pts: Array = neck.renderedPoints
	var n: int = neck.frontEndPoint
	if pts.size() != neck.neckPoints.size() or n < 2:
		return 0.0
	var most := 0.0
	for i in range(int(ceil(c["top"] * n)), mini(n, int(floor(c["bottom"] * n)) + 1)):
		most = maxf(most, (pts[i] as Vector2).x - (neck.neckPoints[i] as Vector2).x)
	return maxf(0.0, most - BAND_GAP)


## The collar's picture pushed out by push_px at its front; its back edge stays put.
func _widen(her) -> void:
	var col = her.collarContainer.collar
	if not _widened:
		_widened = true
		_collar_x = col.x
	var cname := ThroatRings.current_collar()
	if not _back.has(cname):
		var sx: float = col.scaleX
		col.scaleX = 1.0
		var b: Rect2 = col.getBounds(col)
		_back[cname] = [b.position.x, maxf(1.0, b.size.x)]
		col.scaleX = sx
	col.scaleX = 1.0 + push_px / _back[cname][1]
	col.x = _collar_x + _back[cname][0] * (1.0 - col.scaleX)   # the back edge stays put, the front moves out


func _unwiden() -> void:
	if not _widened or g.her == null:
		_widened = false
		return
	var col = g.her.collarContainer.collar
	col.scaleX = 1.0
	col.x = _collar_x
	_widened = false
