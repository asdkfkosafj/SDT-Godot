extends SDTExtension
## Port of sby's ignoreherclothingpenisV3 Loader mod: her penis sticks out through her clothes, as if from a hole,
## instead of lying against her body under her waistband; optionally it rises with her arousal (her pace, him in her
## throat, hilting) and droops again as she calms down, and she cums with him. Her > Body, per character (saved in the
## character code as ignoreherclothingpenis:Normal / IgnoreClothing / IgnoreClothingWangle, like the Loader mod);
## off by default (the game's own). The arousal numbers are the Loader pack's (Mods > Extensions > this plugin).
## Adapted:
## - "through clothes" is the value point HerPenisControl.throughClothes instead of replacing the game's clothing
##   listeners and costume visibility;
## - the angle goes through HerPenisControl.restAngle (where her penis swings back to) and minAngle (how far it rises)
##   instead of the mod's writing the game's lowest angle every frame: she hangs at the arousal angle and still swings
##   with her body (the mod pinned it rigidly above the torso line);
## - her cum is the game's cum strands from her penis tip, as the mod's (from roztoow's MakeHerCum), and follows his
##   orgasm's numbers (morecumspurts' Him > Cum): her spurts are longer or shorter as his shortest / longest spurt are
##   (the mod's 10 +-5 ticks at the game's 6 / 21), and skip the pause before a spurt as often as his do; she cums as
##   long as he does, so his cum amount and edging reach her through that. With the game's numbers she cums as in the
##   Loader mod. The Loader's reset options are left out (the port has no mod reset).

const MODES := ["Normal", "IgnoreClothing", "IgnoreClothingWangle"]   # character code values
const START_MODES := ["Off", "Through clothes", "Rising with arousal"]
const CUM_MODES := ["Never", "With the arousal angle", "Always"]
const STRAPON := 1   # HerPenisControl.penisNameList index
## the mod's spurts
const SPURT_DELAY := [15.0, 5.0]       # average, deviation (ticks)
const SPURT_LENGTH := [10.0, 5.0]
const SPURT_VELOCITY := [25.0, 5.0]
const STRAND_OFFSET := Vector2(-320, -13)   # from her penis's origin to its tip
const ANCHOR_DELAY := 5
const LINK_DELAY := 2
const MASS_MULT := 0.2
const MASS_MIN := 0.05
const HIS_SPURTS := 27.0   # the game's shortest + longest spurt (6 + 21)
const CUM_UP := 0.1
const CUM_DOWN := 0.1

var mode := 0
var arousal := 0.0   # 0..100
var _timer := 0      # ticks until her arousal starts falling
var _angle := 0.0    # the arousal angle this tick
var _cum_angle := 0.0
var _strand = null
var _spurting := false
var _spurt_delay := 0.0
var _spurt_length := 0.0
var _spurt_velocity := 0.0
var _anchor_delay := 0
var _direction := Vector2.ZERO
var _his := {"min_spurt": 6, "max_spurt": 21, "pause": 1.0}   # his orgasm's numbers (Him.EJACULATION, morecumspurts')


func _init() -> void:
	title = "Her penis through clothes"
	description = "Her penis sticks out through her clothes, optionally rising with her arousal; she can cum with him."


func _setup() -> void:
	setting("start_mode", START_MODES[0], {"label": "For new characters", "options": START_MODES,
		"desc": "For characters whose code doesn't say. The Loader pack: through clothes."})
	setting("cum", CUM_MODES[1], {"label": "She cums with him", "options": CUM_MODES,
		"desc": "Her penis cums while he does. The Loader pack: with the arousal angle."})
	setting("strapon", false, {"label": "Strap-on too", "desc": "A strap-on also rises and cums. The Loader pack: off."})
	var grp := {"group": "Arousal"}
	setting("low_angle", 45.0, grp.merged({"label": "Angle, not aroused", "min": -40.0, "max": 90.0, "step": 1.0,
		"desc": "45 is about the angle of her thighs, -25 about her torso's."}))
	setting("high_angle", -7.0, grp.merged({"label": "Angle, fully aroused", "min": -40.0, "max": 90.0, "step": 1.0}))
	setting("by_pace", 0.2, grp.merged({"label": "From her pace", "min": 0.0, "max": 2.0, "step": 0.05,
		"desc": "How fast her arousal follows her pace (vigour) per tick. 0: off."}))
	setting("pace_min", 100, grp.merged({"label": "Pace for no arousal", "min": 0, "max": 1000}))
	setting("pace_max", 500, grp.merged({"label": "Pace for full arousal", "min": 0, "max": 1000}))
	setting("by_depth", 0.0, grp.merged({"label": "From how deep he is", "min": 0.0, "max": 1.0, "step": 0.01,
		"desc": "Arousal per tick by how far her head is down on him. 0: off (the Loader pack: off, 0.1)."}))
	setting("by_throat", 0.05, grp.merged({"label": "From him in her throat", "min": 0.0, "max": 1.0, "step": 0.01,
		"desc": "Arousal per tick while he is in her throat. 0: off."}))
	setting("by_hilt", 0.25, grp.merged({"label": "From hilting", "min": 0.0, "max": 2.0, "step": 0.01,
		"desc": "Arousal per tick while he is all the way in. 0: off."}))
	setting("fall_delay", 200, grp.merged({"label": "Falls after (ticks)", "min": 0, "max": 1000}))
	setting("fall_speed", 0.005, grp.merged({"label": "Fall speed", "min": 0.0, "max": 0.1, "step": 0.001}))
	setting("fall_max", 0.05, grp.merged({"label": "Fastest fall", "min": 0.0, "max": 1.0, "step": 0.01}))
	setting("cum_angle", -7.0, grp.merged({"label": "Rises while cumming", "min": -30.0, "max": 30.0, "step": 1.0,
		"desc": "Degrees her penis tilts while she cums (negative: up)."}))


func _enable() -> void:
	mode = _start_mode()
	_timer = int(get_setting("fall_delay"))
	modify(&"HerPenisControl.throughClothes", {"phase": Hooks.MOOD, "op": "set", "value": true,
		"when": func(_pc): return mode > 0})
	modify(&"HerPenisControl.restAngle", {"phase": Hooks.MOOD, "op": "fn", "when": func(pc): return _angled(pc),
		"fn": func(_v, _pc): return _angle + _cum_angle})
	modify(&"HerPenisControl.minAngle", {"phase": Hooks.MOOD, "op": "fn", "when": func(pc): return _angled(pc),
		"fn": func(v, _pc): return minf(v, _angle + _cum_angle)})
	var has_penis := func(): return g.her != null and g.her._penisControl.currentPenisID != 0
	menu_control("her", "Body", MenuSchema.toggle("Penis through clothes",
		"Her penis sticks out through her clothes instead of lying against her body under them. Saved with the character.",
		func(): return mode > 0, func(on: bool): _set_by_hand(1 if on else 0),
		{"after": "Penis width", "visible": has_penis, "keywords": "futa ignoreherclothingpenis"}))
	menu_control("her", "Body", MenuSchema.toggle("Rises with her arousal",
		"Her penis rises as she gets aroused (her pace, him in her throat, hilting) and droops as she calms down. Settings: Mods > Extensions.",
		func(): return mode == 2, func(on: bool): _set_by_hand(2 if on else 1),
		{"after": "Penis through clothes", "visible": func(): return has_penis.call() and mode > 0, "keywords": "futa arousal"}))
	charcode_field("ignoreherclothingpenis", func(): return MODES[mode] if mode > 0 else null, _load_code,
		func(_l): _set_mode(_start_mode()))
	on_late_tick(_tick)
	# his orgasm's numbers as it starts, after morecumspurts set them (its handler has priority 0)
	hook_before(&"Him.ejaculate", _his_numbers, 100)
	_apply()


func _disable() -> void:
	mode = 0
	_end_spurt()
	_cum_angle = 0.0
	_apply()


func _his_numbers(c) -> void:
	if not g.him.ejaculating:
		_his = c.args[0].duplicate()


func _start_mode() -> int:
	return maxi(0, START_MODES.find(get_setting("start_mode")))


func _load_code(v: String, _l) -> void:
	var i := MODES.find(v)
	if i >= 0:
		_set_mode(i)


## From the menu: the character is saved, as after any change to her in the game's menus.
func _set_by_hand(m: int) -> void:
	_set_mode(m)
	g.saveData.saveCharData()


func _set_mode(m: int) -> void:
	mode = clampi(m, 0, 2)
	_apply()


## The game re-reads her clothes (through clothes or not) and her penis's costume shapes.
func _apply() -> void:
	if g.her != null and g.her._penisControl != null:
		g.her._penisControl.clothingChanged()


func _counts(pc) -> bool:
	return pc.currentPenisID != 0 and (pc.currentPenisID != STRAPON or get_setting("strapon"))


func _angled(pc) -> bool:
	return mode == 2 and _counts(pc)


func _cums() -> bool:
	var c: String = get_setting("cum")
	return mode > 0 and (c == CUM_MODES[2] or (c == CUM_MODES[1] and mode == 2))


func _tick() -> void:
	var her = g.her
	if her == null or mode == 0:
		return
	var pc = her._penisControl
	if not _counts(pc):
		_end_spurt()
		return
	if mode == 2:
		_arouse(her)
	if _cums():
		_cum(her, pc)


## The mod's arousal: up with her pace, him deep in her, hilting; down after a delay without any of them.
func _arouse(her) -> void:
	var up := false
	var down := false
	var pace: float = get_setting("by_pace")
	if pace > 0.0:
		var lo := float(get_setting("pace_min"))
		var hi := maxf(lo + 1.0, float(get_setting("pace_max")))
		var percent := int((clampf(her.vigour, lo, hi) - lo) / (hi - lo) * 100.0)
		if arousal < percent - 1:
			arousal += pace
			up = true
		elif arousal > percent + 1 and her.vigour < 50:
			down = true
	var full: bool = her.mouthFull
	for src in [["by_depth", full, maxf(0.0, her.pos)], ["by_throat", full and her.penisInMouthDist > her.deepthroatDistance, 1.0],
			["by_hilt", full and her.penisInMouthDist > her.hiltDistance, 1.0]]:
		var k: float = get_setting(src[0])
		if k <= 0.0:
			continue
		if src[1]:
			arousal += k * src[2]
			up = true
		else:
			down = true
	if up:
		_timer = int(get_setting("fall_delay"))
	elif down:
		_timer -= 1
		if _timer < 0:
			arousal -= minf(float(get_setting("fall_max")), float(get_setting("fall_speed")) * sqrt(-_timer))
	arousal = clampf(arousal, 0.0, 100.0)
	var p := arousal / 100.0
	var lo_a: float = get_setting("low_angle")
	var hi_a: float = get_setting("high_angle")
	var curve := 2.0 * p * p if arousal < 50.0 else -1.0 / (2.0 * p) + 1.5
	_angle = lo_a + (hi_a - lo_a) * curve


## Her spurts while he cums: the game's cum strands from her penis tip (the mod's timing).
func _cum(her, pc) -> void:
	if not g.him.ejaculating:
		_spurting = false
		_cum_angle -= _cum_angle * CUM_DOWN
		return
	_timer = int(get_setting("fall_delay"))
	var deg: float = -(-90.0 + her.rotation_degrees + her.torso.rotation_degrees + pc.penisContainer.rotation_degrees) + 10.0
	var rad := deg_to_rad(deg)
	_direction = Vector2(sin(rad), cos(rad))
	if not _spurting and _spurt_delay == 0.0:
		_strand = g.strandControl.newCumStrand(STRAND_OFFSET, pc.penis)
		_strand.myGravity = g.gravity
		var scale := float(_his["min_spurt"] + _his["max_spurt"]) / HIS_SPURTS
		_spurt_length = _dev([SPURT_LENGTH[0] * scale, SPURT_LENGTH[1] * scale])
		_spurt_delay = _dev(SPURT_DELAY)
		var pause: float = _his["pause"]
		if pause < 1.0 and randf() > pause:   # as his: no pause before the next spurt
			_spurt_delay = 0.0
		_spurt_velocity = _dev(SPURT_VELOCITY)
		_anchor_delay = ANCHOR_DELAY + 1
		_spurting = true
		pc.angSpeed -= 1.5   # the kick of a spurt
	var target: float = get_setting("cum_angle")
	if _spurting:
		_anchor_delay = maxi(0, _anchor_delay - 1)
		if _anchor_delay == 0:
			_strand.insertLink(_direction * _spurt_velocity, LINK_DELAY, g.randomCumMass() * MASS_MULT + MASS_MIN)
		_cum_angle += (target - _cum_angle) * CUM_UP
		if _spurt_length <= 0.0:
			_end_spurt()
		else:
			_spurt_length = maxf(0.0, _spurt_length - 1.0)
	else:
		_spurt_delay = maxf(0.0, _spurt_delay - 1.0)
		_cum_angle -= _cum_angle * CUM_DOWN


func _dev(a: Array) -> float:
	return a[0] + randf() * a[1] - randf() * a[1]


func _end_spurt() -> void:
	if _spurting and _strand != null:
		_strand.detachSourceLink(_direction * _spurt_velocity, 0)
	_spurting = false
	_strand = null
