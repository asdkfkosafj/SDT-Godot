extends SDTExtension
## Body contact (animtools' non-oral simulation, written from its behaviour): while a body position that is not oral
## runs (tit fuck, vaginal, anal, other; or an oral one with pleasure from contact), his tip touching her body is
## contact. In contact: pleasure for him, her vigour from her movement, entry / exit / hilt sounds, his penis hidden
## inside her as far as it is in (the mask), his spurts kept inside her (the inside cum sound, no strands), and her
## resistance: past the entry point she pushes back, more the deeper he is; it wears down while he is in her and
## comes back while he is out. How much depends on her sexual experience (the position's own values, or one of
## animtools' six presets for vaginal and anal positions).
## Cleaner than the mod: distances in the scene (not on the screen, so zooming changes nothing; the file's distances
## count at the position's own zoom), the resistance slows her within the game's movement step (Her.drag) instead of
## a second step, and her vigour through Her.vigourGain.
## Dialogue: animtools' line types (each also with a type suffix, e.g. bodyentered_anal, which goes first when the
## dialogue has it): bodyentered, bodyexited, vigorousbodyexited, vigorousbodyexitedrelax, inbody, bodycontacthilt,
## bodycontactresistive, bodycontactloose, bodycontactmovementvigour, bodycontactspaceheldpush(inhilt) and cuminher,
## with animtools' life, priority and delay. The game's "vigorous" lines stay quiet in contact when the dialogue has
## its own movement vigour lines. Holding the "Hold her" key (space) while she resists pushes: her vigour and the
## push lines. Auto mode: in non-oral positions it goes by the contact depth and the meeting point, and it does not
## aim his penis at her mouth. Character code: animtoolsSexExperience. animtools' voices are not ported.

const Fields := preload("res://src/ext/positions/position_fields.gd")
const EXPERIENCE := ["Position's own", "No Resistance", "Porn Star", "Experienced", "Average", "Tight", "Virgin"]
## Each preset: [starting resistance, decrease rate, normalize rate, movement resistance mult] for anal, then for the
## others, then [continuous resistive vigour mult, resistive vigour mult, resistive vigour speed mult].
const PRESETS := {
	"No Resistance": [[-0.1, 0.0005, 0.003, 0.008], [-0.1, 0.0005, 0.003, 0.008], [0.0, 0.0, 0.0]],
	"Porn Star": [[5.0, 0.0004, 0.0015, 0.007], [3.0, 0.0003, 0.0012, 0.0035], [5.0, 0.05, 0.3]],
	"Experienced": [[7.5, 0.00045, 0.0021, 0.0075], [4.0, 0.00035, 0.0015, 0.0039], [5.0, 0.05, 0.3]],
	"Average": [[10.0, 0.0005, 0.003, 0.008], [5.0, 0.0004, 0.0018, 0.0043], [6.0, 0.07, 0.4]],
	"Tight": [[12.5, 0.00055, 0.0045, 0.0075], [6.0, 0.00045, 0.0021, 0.0046], [7.0, 0.09, 0.5]],
	"Virgin": [[15.0, 0.0006, 0.006, 0.007], [7.0, 0.0005, 0.0024, 0.005], [7.0, 0.09, 0.5]],
}
## Three points on her backside (her torsoBack.backside's space) the depth is measured from (vaginal, anal).
const DEPTH_POINTS := [Vector2(-128, 107), Vector2(-99, 172), Vector2(-42, 218)]
const ORAL := 0
const TIT := 1
const TYPE_NAMES := ["oral", "tit", "vaginal", "anal", "other", "alt pleasure"]
## animtools' line types: [name, how much a tick builds it].
const LINES := {"bodycontactmovementvigour": 4, "bodycontacthilt": 8000, "bodyentered": 8000, "vigorousbodyexited": 8000,
	"bodyexited": 8000, "bodycontactresistive": 4, "bodycontactspaceheldpushinhilt": 4, "bodycontactspaceheldpush": 4,
	"bodycontactloose": 4, "inbody": 4, "vigorousbodyexitedrelax": 8000, "cuminher": 16}
const ANAL := 3
const ALT_PLEASURE := 5

var positions = null      # the positions extension
var v := {}               # the position's contact values (the file's, the experience preset's over them)
var active := false       # a position with body contact runs
var contact := false      # his tip is on or in her body
var inside_guess := false # no hit, but she is past the point where he met her before (animtools' body override)
var depth := 0.0          # how deep his tip is past her entry point, scene px (vaginal / anal: from her backside)
var resistance := 0.0     # her resistance now (from the starting resistance down by its range)
var meet := INF           # her position where he met her body (the median of the last 6 first contacts)
var deepest := -INF       # her deepest position in contact

var _type := ORAL
var _zoom := 1.0           # the position's zoom: the file's distances count at it
var _range := 0.0          # how far the resistance can wear down (with his penis's width)
var _width := NAN
var _meets: Array[float] = []
var _contact_set := false
var _contact_point := Vector2()   # scene space (other positions: the depth is measured from it)
var _entered := false             # past the entry point (resistposstartset)
var _resist_start := INF
var _lowered := false
var _hilt_played := false
var _past: Array[float] = []      # her position, the last 6 ticks
var _buildup := 0.0
var _drag := 0.0                  # applied to her speed in her next move
var _vigour := 0.0                # added to her vigour in her next move
var _mask := -100.0
var in_body := false      # in contact for a while (atv_inbody)
var loose := false        # her resistance worn down (atv_inbodycontactloose)
var _move_vigour := 0.0   # her vigour from movement in contact (animtools' body movement vigour)
var _hilt_said := false
var _vigour_reached := false
var _relax := false
var _time_in := 0
var _time_out := 0
var _push := 0            # ticks the push lasts (the hold key)
var _lines := {}          # line type (with suffix) -> true, for the lines the dialogue has
var _own_vigour_lines := false
var _lines_dirty := true
var _hold_key := -1       # Godot key of the "Hold her" hotkey, -1: not looked up
var _hold_binding := -1


func _init() -> void:
	id = "bodycontact"
	title = "Body contact"
	description = "animtools' body contact: resistance, sounds, pleasure and cum inside her in non-oral body positions."
	default_enabled = true


func _setup() -> void:
	setting("experience", "Average", {"label": "Sexual experience", "options": EXPERIENCE,
		"desc": "How much she resists in vaginal and anal positions (animtools' presets; \"Position's own\": the values in the position's file)."})


func _enable() -> void:
	positions = Extensions.get_extension("positions")
	on_late_tick(_tick)
	modify(&"Her.drag", {"op": "fn", "fn": func(d: float, _her) -> float: return d + _drag, "when": func(_her): return active})
	modify(&"Her.vigourGain", {"op": "fn", "fn": _vigour_gain, "when": func(_her): return active})
	modify(&"Him.penisMask", {"op": "fn", "fn": func(m: Dictionary, him) -> Dictionary:
		return {"x": _mask, "scale": him.currentPenisLengthScale}, "when": func(_him): return active and contact and _type > TIT})
	modify(&"Him.cumCaught", {"op": "fn", "fn": func(c: bool, _him) -> bool: return c or _hides_cum(),
		"when": func(_him): return active})
	modify(&"AnimationControl.estimateTipPos", {"op": "fn", "fn": func(_p: float, _ac) -> float: return 0.15 if meet == INF else meet,
		"when": func(_ac): return active and _type > ORAL})
	for h in [&"Dialogue.loadCustomDialogue", &"DialogueLibrary.loadDialogueMod", &"DialogueLibrary.loadFromDialogueEditor"]:
		hook_after(h, func(_c): _lines_dirty = true)
	hook_after(&"Dialogue.sayRandomPhrase", _said)
	for n in [&"hiltMove", &"tipHold", &"outsideLickBalls", &"oneDeep", &"adjustAim"]:
		hook_before(StringName("AutomaticControl." + n), _auto.bind(String(n)))
	charcode_field("animtoolsSexExperience", _code_get, _code_set)
	_lines_dirty = true


func _disable() -> void:
	active = false
	_reset()
	_drop_lines()


func _setting_changed(_key: String, _value) -> void:
	_load(true)


## The position's values (again when the position or the experience changes); the resistance starts full.
func _load(fresh: bool) -> void:
	var cur = positions.current if positions != null and positions.enabled else null
	var t: int = int(cur.values["positiontype"]) if cur != null else ORAL
	var on: bool = cur != null and (t > ORAL or cur.values["pleasurefromcontact"] == 1)
	if not on:
		active = false
		_reset()
		return
	if not fresh and active and cur == _source:
		return
	_source = cur
	_type = t
	_zoom = maxf(0.05, float(cur.values["zoom"]))
	v = cur.values.duplicate()
	var exp: String = get_setting("experience")
	if _type > TIT and PRESETS.has(exp):
		_apply_preset(PRESETS[exp])
	_reset()
	resistance = v["startingresistance"]
	_width = NAN
	active = true


var _source = null   # the position v came from


func _apply_preset(p: Array) -> void:
	var r: Array = p[0] if _type == ANAL else p[1]
	v.merge({"resistancestartingdistance": 10.0, "undovanillavigourmovechanges": 1, "undoallvanillavigourincreases": 1,
		"bodycontactvigour": 1, "bodycontactvigourspeedmult": 1.0, "bodycontactvigourcontinuousamount": 3.0,
		"bodycontactsounds": 1, "bodycontactsoundsinspeed": 0.1 if _type == ANAL else 0.02,
		"bodycontactsoundsoutspeed": -0.1 if _type == ANAL else -0.02, "hidestrandsinbodycontact": 1,
		"spaceholdresist": 1, "usepenisrangebodycontactmask": 1, "pleasurefromcontact": 1, "pleasurefromcontactmult": 1.5,
		"resistancewithbodycontact": 1, "minresistance": -0.3, "resistoverriderate": 0.01, "resistoverridereturnrate": 0.2,
		"resistoverridemax": 200.0, "resistivevigor": 1, "resistivevigourspaceheldmult": 0.05,
		"startingresistance": r[0], "resistdecreaserate": r[1], "resistnormalizerate": r[2], "movementresistancemult": r[3],
		"adjustspeedinbodycontact": 0, "continuousresistivevigourmult": p[2][0], "resistivevigourmult": p[2][1],
		"resistivevigourspeedmult": p[2][2]}, true)


func _reset() -> void:
	contact = false
	inside_guess = false
	depth = 0.0
	meet = INF
	deepest = -INF
	_meets.clear()
	_contact_set = false
	_entered = false
	_resist_start = INF
	_lowered = false
	_hilt_played = false
	_past.clear()
	_buildup = 0.0
	_drag = 0.0
	_vigour = 0.0
	_mask = -100.0
	in_body = false
	loose = false
	_move_vigour = 0.0
	_hilt_said = false
	_vigour_reached = false
	_relax = false
	_time_in = 0
	_time_out = 0
	_push = 0


## Her resistance scaled: 0 when it wore down all its range, the starting resistance / 10 when full.
func resistance_scaled() -> float:
	if _range == 0.0:
		return 0.0
	var start: float = v["startingresistance"]
	return (resistance - (start - _range)) / _range * (start / 10.0)


func _set_resistance(r: float) -> void:
	var start: float = v["startingresistance"]
	resistance = maxf(start - _range, minf(start, r))


## Every tick after the game's: contact, depth, sounds, resistance (applied in her next move).
func _tick() -> void:
	if _lines_dirty:
		_update_lines()
	_load(false)
	_drag = 0.0
	in_body = false
	loose = false
	if not active:
		return
	var her: Her = g.her
	var him: Him = g.him
	if g.gamePaused:
		return
	if _type == ALT_PLEASURE:
		him.givePleasure(her.movement)
		_move_vigour = clampf(_move_vigour - 20.0, 0.0, 1050.0)
		return
	if _holding_key():
		_push = 5
	if him.currentPenisWidthScale != _width:
		_width = him.currentPenisWidthScale
		_range = (v["startingresistance"] - v["minresistance"]) / 3.0 * minf(3.0, _width)
	var sl: SceneLayer = g.sceneLayer
	var tip: Vector2 = sl.globalToLocal(him.getPenisTipPoint())
	if _hits(him.getPenisTipPoint()):
		contact = true
		inside_guess = false
	elif meet != INF and deepest != -INF and (meet + deepest) / 2.0 < her.pos:
		contact = true
		inside_guess = true
	else:
		contact = false
		inside_guess = false
	if _setting_global("disablevanillavigourdialogwhenbodycontact") == 1 \
			or (_setting_global("disablevanillavigourdialogwhenbodycontact") == 2 and _type > ORAL and _own_vigour_lines):
		var vs = g.dialogueControl.states.get(Dialogue.VIGOROUS)
		if vs != null:
			vs.clearBuild()
	if contact:
		_move_vigour += her.absMovement * v["bodycontactvigourspeedmult"]
	_move_vigour = clampf(_move_vigour - 20.0, 0.0, 1050.0)
	if _move_vigour > 600.0:
		_line("bodycontactmovementvigour")
	if contact:
		_in_contact(her, him, tip, sl)
	else:
		_out_of_contact(her)
	_push = maxi(0, _push - 1)
	_past.append(her.pos)
	if _past.size() > 6:
		_past.pop_front()


func _in_contact(her: Her, him: Him, tip: Vector2, sl: SceneLayer) -> void:
	deepest = maxf(her.pos, deepest)
	if v["pleasurefromcontact"] == 1:
		him.givePleasure(maxf(her.absMovement * v["pleasurefromcontactmult"], randf() * 4.0 + 4.0))
	if not _hilt_said and her.pos > 1.0:
		_hilt_said = true
		_line("bodycontacthilt")
	var w := float(Her.VIGOUR_WINCE_LEVEL)
	var mv: bool = _setting_global("usemovementvigourforvigorousbodyexited") == 1
	if (_move_vigour if mv else her.vigour) >= w:
		_vigour_reached = true
		_relax = true
	if her.pos > 1.0 and _setting_global("bodycontacthiltsounds") == 1 and v["bodycontactsounds"] == 1:
		_hilt_sound(her)
	elif her.pos <= 1.0:
		_hilt_played = false
	if not _contact_set and not inside_guess:
		_first_contact(her, tip)
	if _type > TIT:
		var d: float
		var off: float
		if _type == 2 or _type == ANAL:
			var bs: FlashDisplayObject = her.torsoBack.backside
			d = INF
			for p in DEPTH_POINTS:
				d = minf(d, sl.globalToLocal(bs.localToGlobal(p)).distance_to(tip))
			d = maxf(0.0, d - 60.0)
			off = 120.0
		else:
			d = _contact_point.distance_to(tip)
			off = 80.0
		depth = d
		var len: float = 300.0 * him.currentPenisLengthScale
		var m := clampf(d - off, 0.0, len)
		_mask = -100.0 if m == 0.0 else m
	var start: float = v["resistancestartingdistance"] / _zoom
	if not _entered and depth - start > 0.0:
		_line("bodyentered")
		_entry_sound(her)
		if v["resistancewithbodycontact"] != 1:
			_entered = true
	elif _entered and depth - start <= 0.0:
		_exit_sound(her)
		_lowered = false
		_hilt_played = false
		if v["resistancewithbodycontact"] != 1:
			_entered = false
	if v["resistancewithbodycontact"] == 1:
		_resist(her, start)
	if v["bodycontactvigour"] == 1 and _setting_global("allowvigourchanges") == 1:
		_vigour += her.absMovement * v["bodycontactvigourspeedmult"] + v["bodycontactvigourcontinuousamount"]
	if g.him.spurting and v["hidestrandsinbodycontact"] == 1 and _hides_cum():
		_line("cuminher")
	if v["adjustspeedinbodycontact"] == 1:
		_buildup = minf(_buildup + 0.05, 1.0)
		var to := minf(her.speed, maxf(-0.06, her.speed - (w - her.vigour) / w * _buildup))
		_drag += her.speed - to
	_time_in += 1
	_time_out = 0
	if _time_in > _setting_global("inbodytimerequirement"):
		in_body = true
		_line("inbody")


## Her resistance past the entry point (animtools' resistancewithbodycontact): it pushes her back the deeper he is
## (the more she resists), wears down while he pushes in, and eases in over the first px past the entry point.
func _resist(her: Her, start: float) -> void:
	if depth - start <= 0.0:
		_lowered = false
		_entered = false
		if not (g.autoModeOn and g.autoMode == 3):
			_set_resistance(resistance + v["resistnormalizerate"])
		return
	if not _entered:
		_resist_start = minf(her.pos, _resist_start)
		_entered = true
	var amount := maxf(0.0, (her.pos - _resist_start - 0.02) / (Her.maxPos - _resist_start) * (resistance_scaled() * 10.0))
	var vig: bool = v["resistivevigor"] == 1 and _setting_global("allowvigourchanges") == 1
	var w := float(Her.VIGOUR_WINCE_LEVEL)
	if amount > 0.0:
		if not _lowered:
			if vig:
				_vigour += w * v["resistivevigourmult"] + w * absf(her.speed) * v["resistivevigourspeedmult"]
			_set_resistance(resistance - maxf(0.0, minf(40.0, her.movement)) * v["movementresistancemult"])
			_lowered = true
		if amount > _setting_global("bodycontactresistivethreshhold"):
			_line("bodycontactresistive")
		if _push > 0:
			if vig:
				_vigour += w * v["resistivevigourspaceheldmult"]
			if her.pos > 1.0 and _has_line("bodycontactspaceheldpushinhilt"):
				_line("bodycontactspaceheldpushinhilt")
			else:
				_line("bodycontactspaceheldpush")
		_set_resistance(resistance - v["resistdecreaserate"] * (1.0 + amount))
		if vig:
			_vigour += amount * amount * v["continuousresistivevigourmult"]
	else:
		_set_resistance(resistance - v["resistdecreaserate"] / 10.0)
		_lowered = false
	if resistance_scaled() < 0.1:
		loose = true
		_line("bodycontactloose")
	var push := 0.0
	if amount > 0.0:
		push = amount / (20.0 if her.speed > 0.0 else 30.0) + her.armsPushPower * 0.001
	var past := depth - start
	if past < 50.0:
		if _type == ANAL:
			var k := past / 30.0 if past < 30.0 else (20.0 - (past - 30.0)) / 20.0
			if her.speed < 0.0:
				k /= 2.0
			var ring := minf(resistance_scaled(), 1.0) / 5.0 * k + her.armsPushPower * 0.001
			if resistance_scaled() > 0.0:
				_drag += maxf(ring, push)
		else:
			_drag += push * past / 50.0
	else:
		_drag += push


func _first_contact(her: Her, tip: Vector2) -> void:
	_contact_set = true
	_buildup = 0.0
	var before := meet
	_meets.append(her.pos)
	_meets.sort()
	if _meets.size() > 6:
		if her.pos > _meets[0]:
			_meets.pop_front()
		else:
			_meets.pop_back()
	var n := _meets.size()
	meet = _meets[n / 2] if n % 2 == 1 else (_meets[n / 2 - 1] + _meets[n / 2]) / 2.0
	if before == INF or (before != meet and absf(her.pos - meet) < 0.015):
		_contact_point = tip


func _out_of_contact(her: Her) -> void:
	if not (g.autoModeOn and g.autoMode == 3):
		_set_resistance(resistance + v["resistnormalizerate"])
	_contact_set = false
	_entered = false
	_lowered = false
	_hilt_played = false
	_mask = -100.0
	_time_in = 0
	_time_out += 1
	if _time_out > 20:
		_line("vigorousbodyexited" if _vigour_reached else "bodyexited")
		_vigour_reached = false
	var mv: bool = _setting_global("usemovementvigourforvigorousbodyexited") == 1
	if _relax and _time_out > _setting_global("vigorousbodyexitedrelaxtimerequirement") \
			and (_move_vigour if mv else her.vigour) == 0.0:
		_line("vigorousbodyexitedrelax")
		_relax = false


## His tip on her body: her breast, backside, back, chest, head, thigh or calf (bounds first).
func _hits(p: Vector2) -> bool:
	var her: Her = g.her
	for o in [her.torsoBack.leftBreast.getChildAt(0), her.torso.backside, her.torso.back, her.torso.midLayer.chest,
			her.head, her.torso.leg.thigh, her.torso.rightCalfContainer.calf]:
		if o.hitTestPoint(p.x, p.y, false) and o.hitTestPoint(p.x, p.y, true):
			return true
	return false


func _hides_cum() -> bool:
	return contact and v["hidestrandsinbodycontact"] == 1 and not (inside_guess and v["usepenisrangebodycontactmask"] == 0)


func _vigour_gain(gain: float, _her) -> float:
	var add := _vigour
	_vigour = 0.0
	return (0.0 if v["undovanillavigourmovechanges"] == 1 or v["undoallvanillavigourincreases"] == 1 else gain) + add


func _entry_sound(her: Her) -> void:
	if not _sounds() or her.speed <= v["bodycontactsoundsinspeed"]:
		return
	var sc: SoundControl = g.soundControl
	var diff: float = _setting_global("bodycontactentryexitspeeddiff")
	match int(_setting_global("bodycontactentrysoundtype")):
		1:
			sc.playDown(her.pos, her.movement)
		2:
			sc.playTouch()
		3:
			sc.playLick()
		4:
			if her.speed > v["bodycontactsoundsinspeed"] + diff * 2.0:
				sc.playDown(her.pos, her.movement)
			elif her.speed > v["bodycontactsoundsinspeed"] + diff:
				sc.playTouch()
			else:
				sc.playLick()


func _exit_sound(her: Her) -> void:
	if not _sounds() or her.speed >= v["bodycontactsoundsoutspeed"]:
		return
	var sc: SoundControl = g.soundControl
	var diff: float = _setting_global("bodycontactentryexitspeeddiff")
	match int(_setting_global("bodycontactexitsoundtype")):
		1:
			sc.playUp(her.pos, her.movement)
		2:
			sc.playTouch()
		3:
			sc.playLick()
		4:
			if her.speed < v["bodycontactsoundsoutspeed"] - diff * 2.0:
				sc.playUp(her.pos, her.movement)
			elif her.speed < v["bodycontactsoundsoutspeed"] - diff:
				sc.playTouch()
			else:
				sc.playLick()


## At the hilt: a sound by how fast she got there (her position now against the least of the last 4 ticks).
func _hilt_sound(her: Her) -> void:
	if _hilt_played or her.pos <= 1.01 or _past.size() < 4:
		return
	var sp: float = her.pos - _past.slice(_past.size() - 4).min()
	var sc: SoundControl = g.soundControl
	var played := false
	if _setting_global("bodycontacthiltsplatsound") == 1 and _in(sp, "splat"):
		sc.playSplat()
		played = true
	if _setting_global("bodycontacthilttouchsound") == 1 and _in(sp, "touch"):
		sc.playTouch()
		played = true
	if _setting_global("bodycontacthiltgrabsound") == 1 and _in(sp, "grab"):
		sc.playGrab()
		played = true
	if _setting_global("bodycontacthiltlicksound") == 1 and _in(sp, "lick"):
		sc.playLick()
		played = true
	_hilt_played = played


func _in(sp: float, kind: String) -> bool:
	return sp > _setting_global(kind + "soundbodycontacthiltspeedtarget") \
		and sp < _setting_global(kind + "soundbodycontacthiltspeedtargetcap")


func _sounds() -> bool:
	return _setting_global("disablebodycontactsounds") == 0 and v["bodycontactsounds"] == 1


# ---------------------------------------------------------------- dialogue

## States for animtools' line types the loaded dialogue has (with and without a type suffix).
func _update_lines() -> void:
	_lines_dirty = false
	var dc = g.dialogueControl
	if dc == null:
		_lines_dirty = true
		return
	_drop_lines()
	_own_vigour_lines = false
	for t in LINES:
		for suffix in [""] + TYPE_NAMES.map(func(n): return "_" + n):
			var n: String = t + suffix
			if dc.library.customLibrary.has(n):
				dc.states[n] = DialogueState.new(_setting_global(t + "life"), _setting_global(t + "priority"))
				_lines[n] = true
				if t == "bodycontactmovementvigour":
					_own_vigour_lines = true


func _drop_lines() -> void:
	var dc = g.dialogueControl
	if dc != null:
		for n in _lines:
			dc.states.erase(n)
	_lines.clear()


func _has_line(t: String) -> bool:
	return _lines.has(t + "_" + TYPE_NAMES[_type]) or _lines.has(t)


## Builds a line type: the one for this position's type when the dialogue has it, else the general one.
func _line(t: String) -> void:
	var n: String = t + "_" + TYPE_NAMES[_type]
	if not _lines.has(n):
		n = t
	if _lines.has(n):
		g.dialogueControl.buildState(n, LINES[t])


## After she said one of these lines: its type waits its delay before it builds again.
func _said(c) -> void:
	var dc = g.dialogueControl
	var s: String = dc.sayingState
	if not _lines.has(s) or dc.states.get(s) == null:
		return
	var t := s
	for n in TYPE_NAMES:
		t = t.trim_suffix("_" + n)
	if Fields.SETTINGS.has(t + "delaybuild"):
		dc.states[s].delayBuild(int(_setting_global(t + "delaybuild")))


## The "Hold her" hotkey held down (the game runs it once per press; animtools' push lasts while space is held).
func _holding_key() -> bool:
	if g.inTextField or g.controlLocked:
		return false
	var b := Hotkeys.binding("game:hold")
	if b != _hold_binding:
		_hold_binding = b
		_hold_key = -1
		var code := b & Hotkeys.KEY_MASK
		for k in range(32, 128):
			if code != 0 and FlashKeys.to_flash(k) == code:
				_hold_key = k
				break
	return _hold_key >= 0 and Input.is_key_pressed(_hold_key)


# ---------------------------------------------------------------- auto mode, character code

## Auto mode in non-oral positions: the hilt is her deepest position, "deep" is past the entry point, her tip hold
## goes by the contact depth, licking his balls is a deep stroke, and there is no aiming at her mouth.
func _auto(c, n: String) -> void:
	if not active or _type == ORAL:
		return
	var ac = g.automaticControl
	var her: Her = g.her
	match n:
		"adjustAim":
			c.cancel()
		"hiltMove":
			if g.penisOut:
				return
			if her.pos > 1.0:
				ac.currentPos.x = ac.lastPos.x + randf() * 0.04 - 0.02
			else:
				ac.currentPos.x = minf(ac.lastPos.x + 0.1, 1.2)
			if randf() > 0.6:
				her.activeHold(false)
			c.cancel(ac.currentPos)
		"tipHold":
			ac.currentPos.x -= (depth + 10.0) * 0.001
			ac.currentPos.y = ac.offTilt
			her.tongueContainer.tongue.encourage()
			c.cancel(ac.currentPos)
		"outsideLickBalls":
			c.cancel(ac.singleDeepthroat())
		"oneDeep":
			ac.nextModeTimer = 0
			ac.singleActionTime = 120
			ac.deepthroatTarget = randf() * 0.1 + 0.1 + ac.deepthroatProgress
			if depth > 40.0 and not ac.usingDeepSlow:
				ac.usingDeepSlow = true
				ac.currentSelfModes.append(ac.deepSlow)
			if her.pos > 0.95 and not ac.usingFullSlow:
				ac.usingFullSlow = true
				ac.currentSelfModes.append(ac.fullSlow)
			ac.currentMode = ac.singleDeepthroat
			her.lookDown()
			c.cancel()


func _code_get():
	if _setting_global("enablesexexpsaving") != 1:
		return null
	var e: String = get_setting("experience")
	return "1,Average" if e == EXPERIENCE[0] else "0," + e


func _code_set(value: String, _load) -> void:
	var p := value.split(",")
	if p.size() >= 2 and p[0] == "1":
		set_setting("experience", EXPERIENCE[0])
	elif p.size() >= 2 and PRESETS.has(p[1]):
		set_setting("experience", p[1])


func _setting_global(key: String) -> float:
	return float(Fields.SETTINGS[key])
