class_name ThroatRings
extends RefCounted
## The throat ring model: her throat as a path by depth with rings on it, the throat entrance and, when she wears
## one, her collar. Every tick it works out how hard he presses on each ring, how far the ring has stretched and how
## much it would hold him back. It changes nothing by itself: throatresiststretch (the entrance ring) and
## chokercollarresistance (the collar ring) act on the game through value points. Ticked by those extensions while
## they are on, and read only while Developer mode is on (its Body section).
##
## Depth is the neck's own: 0 at her lips, 1 = 400 deep (penisInMouthDist / 400, what Neck.render uses), so a ring's
## edges are where they are drawn on the neck. The collar ring's edges are where the collar's picture covers the
## front of her neck: every BOUNDS_EVERY ticks the front outline points are hit tested against the picture, and the
## first run of covered points is the band (a hanging part below it, like the tie's, is left out). That works for
## collars from mods too, without fitting them by hand.
##
## How a collar holds and gives is one number, its stiffness (0: a soft band .. 1: metal; one setting for every
## collar). It sets how tight the ring holds, how hard it is to stretch, how much it takes to break and the wall the
## collar puts up against him (set_wall: code, dialogue or automation may set the wall apart; the menu has only the
## stiffness). PROFILES are named stiffnesses ("Metal"); a collar's tags may name its profile or set its own.
##
## Pressure comes from what he does, not from the mouse: his width while he is past the ring's top edge, more while
## he pushes in, plus the swallow wave passing through the ring. Under pressure a ring stretches (faster when it is
## tight, slower when it is stiff) and wears down if it can break; without pressure it recovers.

const DEPTH_SCALE := 400.0
const ENTRANCE_TOP := 75.0 / DEPTH_SCALE      # Her.deepthroatStartDistance: the resistance at the throat entrance
const ENTRANCE_BOTTOM := 150.0 / DEPTH_SCALE  # Her.deepthroatDistance: past it he is in her throat
const STRETCH_RATE := 0.016   # per tick, at pressure 1 on a fully tight, fully stretchy ring
const RECOVER_RATE := 0.002   # per tick without pressure (halved for a fully stiff ring)
const WEAR_REST := 0.1        # durability back per tick without pressure (none for a fully stiff ring)
const PUSH_FULL := 10.0       # his movement per tick that counts as a full push (the game's "fast" threshold)
const WAVE_PRESSURE := 0.05   # pressure per unit of swallow size while the wave is inside a ring
const BOUNDS_EVERY := 15      # ticks between finding the collar's edges again
const HIT_INSET := 2.0        # px inside the front outline where the collar's picture is tested
const HIT_REFINE := 5         # halvings of the step between a covered and an uncovered outline point
## named stiffnesses, for code, dialogue and collar tags ("profile")
const PROFILES := {"Band": 0.2, "Leather": 0.6, "Metal": 1.0}
const METAL := 0.95           # this stiff or more: does not give and does not break
const WALL_MAX := 0.3         # the strongest collar wall (the game's throat at resistance 100: 0.2)
const DEFAULT_STIFFNESS := 0.6
const SECTION := "throat_rings"   # port.cfg: stiffness
## Collar tags: what the picture alone does not tell. "stiffness": the collar's own (else the setting), or
## "profile": one of PROFILES; "can_snap": false for a collar that never breaks (even with "Collar can break" on).
## Collars loaded from mods add theirs here, by name.
static var collar_tags := {}

static var entrance := _ring("Throat entrance", ENTRANCE_TOP, ENTRANCE_BOTTOM, 0.5, 0.5, INF)
static var collar := _ring("Collar", 0.55, 0.75, 0.6, 0.6, 200.0)
static var stiffness := DEFAULT_STIFFNESS   # the setting (0 soft band .. 1 metal)
static var collar_breaks := false            # collars may snap ("Collar can break"; off: they never do)
static var collar_wall := WALL_MAX * DEFAULT_STIFFNESS   # how hard the collar's wall holds at its bottom edge
static var tip := 0.0                   # his tip, in depth units (0 while outside her mouth)
static var push := 0.0                  # how hard he pushes in this tick, 0..1
static var collar_name := ""            # the collar the ring is for ("Leather", "Tie", ...; "Custom" for a mod's)
static var _tick_done := -1             # the game tick last worked out (several extensions may ask)
static var _edges_tick := -1000000
static var _edges_collar = null


static func _ring(label: String, top: float, bottom: float, tight: float, stiff: float, durability: float) -> Dictionary:
	return {"label": label, "on": true, "top": top, "bottom": bottom, "tight": tight, "stiff": stiff,
		"max_durability": durability, "durability": durability, "stretch": 0.0, "pressure": 0.0, "hold": 0.0,
		"snapped": false, "recover": 1.0}


static func rings() -> Array:
	return [entrance, collar]


## True once the rings have been worked out this game tick (their values are this tick's).
static func worked_out_this_tick() -> bool:
	return _tick_done == Flash.tick_count


## Worked out read only while Developer mode is on (for its Body section).
static func active() -> bool:
	return SDTMenu.dev != null and SDTMenu.dev._enabled()


static func tick(her) -> void:
	if Flash.tick_count == _tick_done:
		return
	_tick_done = Flash.tick_count
	var neck = her.head.neck
	tip = 0.0 if g.penisOut else maxf(0.0, her.penisInMouthDist / DEPTH_SCALE)
	push = 0.0 if g.penisOut else clampf(her.movement / PUSH_FULL, 0.0, 1.0)
	entrance["tight"] = clampf(g.throatResistance / 100.0, 0.0, 1.0)
	_update_collar(her, neck)
	var width: float = g.him.getPenisWidthWithTwitch()
	for r in rings():
		_step(r, width, neck)


static func _step(r: Dictionary, width: float, neck) -> void:
	if not r["on"]:
		r["pressure"] = 0.0
		r["hold"] = 0.0
		r["stretch"] = 0.0
		return
	var p := 0.0
	if tip > r["top"]:
		p = width * (0.3 + 0.7 * push)
	if neck.swallowing and neck.swallowProgress >= r["top"] and neck.swallowProgress <= r["bottom"]:
		p += WAVE_PRESSURE * neck.swallowSize
	r["pressure"] = p
	if p > 0.0:
		r["stretch"] = minf(1.0, r["stretch"] + p * r["tight"] * (1.0 - r["stiff"]) * STRETCH_RATE)
	else:
		r["stretch"] = maxf(0.0, r["stretch"] - RECOVER_RATE * r["recover"] * (1.0 - 0.5 * r["stiff"]))
	if is_finite(r["max_durability"]) and not r["snapped"]:
		if p > 0.0:
			r["durability"] = maxf(0.0, r["durability"] - p * (0.2 + r["stretch"]))
			r["snapped"] = r["durability"] <= 0.0
		else:
			r["durability"] = minf(r["max_durability"], r["durability"] + WEAR_REST * (1.0 - r["stiff"]))
	r["hold"] = 0.0 if r["snapped"] or tip <= r["top"] else r["tight"] * (1.0 - r["stretch"])


## The collar ring follows what she wears: on while a collar is shown, its edges where its picture covers her neck.
static func _update_collar(her, neck) -> void:
	var c = her.collarContainer.collar
	var worn: bool = c.visible and (g.characterControl.collarControl.selection != 0 or c.numChildren > 0)
	if not worn:
		collar["on"] = false
		_edges_collar = null
		return
	_sync_collar()
	var sel = [g.characterControl.collarControl.selection, c.numChildren]
	if sel == _edges_collar and Flash.tick_count - _edges_tick < BOUNDS_EVERY:
		return
	_edges_collar = sel
	_edges_tick = Flash.tick_count
	var e := collar_edges(neck, c)
	collar["on"] = e.x >= 0.0
	if collar["on"]:
		collar["top"] = e.x
		collar["bottom"] = maxf(e.y, e.x + 0.01)


## Where the collar's picture `c` covers the front of her neck: (top, bottom) in depth units, the first run of front
## outline points it covers (tested HIT_INSET px inside the outline), each edge refined between its covered and
## uncovered point; (-1, -1) when it covers none.
static func collar_edges(neck, c) -> Vector2:
	var pts: Array = neck.neckPoints
	var n: int = neck.frontEndPoint
	var first := -1
	var last := -1
	for i in n:
		if _covered(neck, c, pts[i]):
			if first < 0:
				first = i
			last = i
		elif first >= 0:
			break   # the band ends here; anything covered further down hangs from it
	if first < 0:
		return Vector2(-1.0, -1.0)
	var top := float(first)
	if first > 0:
		top = first - _refine(neck, c, pts[first], pts[first - 1])
	var bottom := float(last)
	if last < n - 1:
		bottom = last + _refine(neck, c, pts[last], pts[last + 1])
	return Vector2(top / n, bottom / n)


static func _covered(neck, c, p: Vector2) -> bool:
	var gp: Vector2 = neck.localToGlobal(p - Vector2(HIT_INSET, 0.0))
	return c.hitTestPoint(gp.x, gp.y, true)


## How far (0..1 of the step) from covered point `a` towards uncovered point `b` the picture still covers.
static func _refine(neck, c, a: Vector2, b: Vector2) -> float:
	var lo := 0.0
	var hi := 1.0
	for i in HIT_REFINE:
		var m := (lo + hi) * 0.5
		if _covered(neck, c, a.lerp(b, m)):
			lo = m
		else:
			hi = m
	return lo


## The collar she wears now ("Leather", "Tie", "Gem Choker"; "Custom" for a mod's).
static func current_collar() -> String:
	var sel_id: int = g.characterControl.collarControl.selection
	return g.characterControl.collarNameList[sel_id] if sel_id != 0 else "Custom"


## The collar she wears changed: its tags may give it its own stiffness.
static func _sync_collar() -> void:
	if g.characterControl != null and current_collar() != collar_name:
		collar_name = current_collar()
		_apply_stiffness()
		_edges_collar = null


## The collar's tags (collar_tags; {} for one without).
static func tags(cname: String) -> Dictionary:
	return collar_tags.get(cname, {})


## The stiffness setting (0 a soft band .. 1 metal), for every collar; kept in port.cfg. It also sets the collar's
## wall to match (WALL_MAX x stiffness).
static func set_stiffness(k: float) -> void:
	stiffness = clampf(k, 0.0, 1.0)
	PortSettings.set_value(SECTION, "stiffness", stiffness)
	collar_wall = WALL_MAX * stiffness
	_apply_stiffness()


## One of PROFILES by name ("Band", "Leather", "Metal"); false if there is none of that name.
static func apply_profile(pname: String) -> bool:
	if not PROFILES.has(pname):
		return false
	set_stiffness(PROFILES[pname])
	return true


## How hard the collar's wall holds at its bottom edge (0 .. WALL_MAX), apart from the stiffness: for code
## (dialogue, automation) and the developer panel. Until the stiffness is set again; not kept.
static func set_wall(w: float) -> void:
	collar_wall = clampf(w, 0.0, WALL_MAX)


static func load_stiffness() -> void:
	stiffness = clampf(float(PortSettings.get_value(SECTION, "stiffness", DEFAULT_STIFFNESS)), 0.0, 1.0)
	collar_wall = WALL_MAX * stiffness
	_apply_stiffness()


## The collar she wears: its stiffness (its tags' own or profile, else the setting).
static func collar_stiffness() -> float:
	var t := tags(collar_name)
	if t.has("stiffness"):
		return clampf(float(t["stiffness"]), 0.0, 1.0)
	if PROFILES.has(t.get("profile", "")):
		return PROFILES[t["profile"]]
	return stiffness


## How tight the collar ring holds (0 holds nothing, 1 fully), how hard it is to stretch and, when collars may break,
## how much it takes before it does.
static func _apply_stiffness() -> void:
	var k := collar_stiffness()
	collar["tight"] = k
	collar["stiff"] = k
	var unbreakable: bool = not collar_breaks or k >= METAL or not tags(collar_name).get("can_snap", true)
	collar["max_durability"] = INF if unbreakable else lerpf(60.0, 300.0, k)
	repair()


static func repair() -> void:
	for r in rings():
		r["durability"] = r["max_durability"]
		r["snapped"] = false


static func reset_stretch() -> void:
	for r in rings():
		r["stretch"] = 0.0
