extends SDTExtension
## Port of sby's armOverhaulV1 Loader mod: her arms get animtools' extra positions (Cupping Breast to On Her Ass)
## and the mod's own (On Hips to Holding Hand), in Her > Arms and the "arms:" field of the character code;
## In Air, Holding Stomach, Cupping Balls, On Neck and Masturbating move every tick; In His Hand / Holding Hand put her
## hand in his left hand; hotkeys cycle her arms, his arms and his leg layer, with the mod's arm transitions.
## Dynamic arms (dynamic_arms.gd): her arms move by themselves, following what happens and her mood.
## Restrained mode (restrained.gd): her hands tied to her thighs or behind her back, and her struggling.
## Later stages: jitter / resistance / tapping / rubbing, spank reactions.
## The mod's numbers are in values.cfg (its own key names); the menu has only the switches.

## animtools' positions, then the mod's own, in the Loader's order (animtools' "Custom" pose editor is not ported)
const ANIMTOOLS := ["Cupping Breast", "Holding Breast", "On His Waist", "On His Chest", "Gripping Breast", "Gripping Thigh",
	"On Her Ass"]
const OWN := ["On Hips", "On Neck", "In Face", "In Air", "Holding Stomach", "Cupping Balls", "On His Ass", "On His Hand",
	"Masturbating", "In His Hand", "Holding Hand"]
const LEFT_ONLY := ["On His Hand", "Masturbating"]
const RIGHT_ONLY := ["In His Hand", "Holding Hand"]
## positions whose hand may tap him while she's held (the mod's allowleftarmtap / allowrightarmtap)
const TAPS := ["On His Waist", "On His Chest", "On Hips", "On His Hand"]
## the Loader's list, for the mod's position numbers in values.cfg (backTransitionPosition...)
const LOADER_ORDER := ["Back", "On Legs", "On His Legs", "Hand Job", "Loose", "Cupping Breast", "Holding Breast",
	"On His Waist", "On His Chest", "Gripping Breast", "Gripping Thigh", "On Her Ass", "Custom", "On Hips", "On Neck",
	"In Face", "In Air", "Holding Stomach", "Cupping Balls", "On His Ass", "On His Hand", "Masturbating", "In His Hand",
	"Holding Hand"]
## positions the hand turns over for (the mod reverses the hand after the transition)
const REVERSED := ["Cupping Breast", "Holding Breast", "On Her Ass", "On Neck", "Cupping Balls", "On His Ass"]
## positions with a closed hand: it opens while the arm travels there and closes when it arrives (hand job's grip is
## the game's own, from hand job mode)
const CLOSED_LEFT := ["Gripping Breast", "Gripping Thigh", "Holding Stomach", "On His Hand"]
const CLOSED_RIGHT := ["Gripping Breast", "Gripping Thigh", "Holding Stomach", "Holding Hand"]
## the menu's restrained choice, in its order (restrained_type 3, 0, 1, 2)
const RESTRAINED_MENU := ["Off", "Loose", "Tight", "Fixed"]

var V := {}                   # values.cfg: the mod's key -> number
var moods := {}               # values.cfg [mood_...]: mood name -> {key: number}
var mood_keys: Array = []     # a mood's keys, in the file's (and the character code's) order
var dyn                       # dynamic_arms.gd
var res                       # restrained.gd
var restrained := false       # restrained mode
var restrained_type := 3      # 0 loose, 1 tight, 2 fixed, 3 off
var _keys := {}               # Flash key code -> [[left: bool, position name]] (values.cfg [keys])
var _key_lists := {}          # values.cfg [keys] as read: the mod's key name -> "76,77"

var in_air := 0.0             # In Air: how far up her hands are (0..1)
var mas_speed := 0.0          # Masturbating: her hand's speed
var mas_final := 0.0          # ... with her mood and the random bursts
var _random_mas_speed := 0.0
var _random_mas_interval := 0
var _random_mas_duration := 0
var _mas_angle := 0.0
var _breath_rest := 0.0
var hold_released := false    # In His Hand / Holding Hand: her hand let go of his
var leg_on_top := false       # his left leg drawn over her (and her arms)
var _leg_by_arm := false      # ... because her right arm went to Cupping Balls / On His Ass
var _leg_spot := {}           # his leg pieces -> [parent, index] before they went on top

# arm transitions (hotkeys): flags done when the arm arrives
var _reverse := [false, false]
var _to_back := [false, false]
var _to_hand_job := [false, false]
var _to_his_legs := [false, false]
var _close_hand := [false, false]


func _init() -> void:
	title = "Arm overhaul"
	description = "More arm positions for her (animtools' and armOverhaul's), moving hands, hand holding, arm hotkeys."


func _setup() -> void:
	setting("hotkeys", true, {"label": "Arm hotkeys", "desc": "Numpad 7 / 9 and 4 / 6: her left / right arm, numpad 5: "
		+ "she lets go of his hand, numpad 2: his leg in front, [ / ]: his right / left arm, plus the keys in values.cfg [keys]."})
	setting("cycleLeftArmKeyLeft", 103, {"label": "Left arm back key", "group": "Keys", "min": 0, "max": 255})
	setting("cycleLeftArmKeyRight", 105, {"label": "Left arm on key", "group": "Keys", "min": 0, "max": 255})
	setting("cycleRightArmKeyLeft", 100, {"label": "Right arm back key", "group": "Keys", "min": 0, "max": 255})
	setting("cycleRightArmKeyRight", 102, {"label": "Right arm on key", "group": "Keys", "min": 0, "max": 255})
	setting("toggleReleaseHandKey", 101, {"label": "Let go of his hand key", "group": "Keys", "min": 0, "max": 255})
	setting("toggleHimLegLayerKey", 98, {"label": "His leg in front key", "group": "Keys", "min": 0, "max": 255})
	setting("cycleHisLeftArmKey", 221, {"label": "His left arm key", "group": "Keys", "min": 0, "max": 255})
	setting("cycleHisRightArmKey", 219, {"label": "His right arm key", "group": "Keys", "min": 0, "max": 255})
	setting("himLegLayerDefault", false, {"label": "His leg in front at the start"})
	setting("toggleDynamicArmsKey", 56, {"label": "Dynamic arms key", "group": "Keys", "min": 0, "max": 255})
	setting("cycleRestrainedModeKey", 57, {"label": "Restrained mode key", "group": "Keys", "min": 0, "max": 255})


func _enable() -> void:
	_load_values()
	var her: Her = g.her
	for n in ANIMTOOLS + OWN:
		var key := _key(n)
		Her.addArmPosition(n, Callable() if n in RIGHT_ONLY else _set_up.bind(n, true),
			Callable() if n in LEFT_ONLY else _set_up.bind(n, false), id,
			{"tap": n in TAPS, "slip": V.get(key + "SlipTime", 15.0), "pass_out": _pass_out.bind(n)})
	for k in _key_lists:
		_add_keys(k, _key_lists[k])
	_random_mas_interval = _rand_int("randomMasMinInterval", "randomMasMaxInterval")
	dyn = load_script("dynamic_arms.gd").new(self)
	dyn.mode = clampi(int(V["dynamicArms"]), 0, 1)
	dyn.update_mood()
	res = load_script("restrained.gd").new(self)
	restrained_type = clampi(int(V["restrainedType"]), 0, 3)
	on_tick(_tick)
	hook_before(&"Her.wakeUp", func(_c): dyn.before_wake())
	hook_after(&"Her.wakeUp", func(_c): _woke())
	hook_before(&"Her.passOut", func(_c): res.before_pass_out())
	hook_before(&"Her.startClenchingTeeth", func(_c): res.clench())
	hook_after(&"Her.cough", _coughed.bind(false))
	hook_after(&"Her.openCough", _coughed.bind(true))
	hook_after(&"Her.eyeHit", func(_c): dyn.eye_hit())
	hook_after(&"Her.fillMouth", func(_c): dyn.fill_mouth())
	hook_before(&"Him.ejaculate", func(_c): dyn.ejaculate())
	charcode_field("armOverhaul", dyn.code, func(v: String, _l): dyn.load_code(v), func(_l): dyn.clear_custom())
	on_dialogueactions(func(da):
		da.register_trigger("DYNAMIC_ARMS_MODE", 1, func(args): set_dynamic(int(args[0])))
		da.register_trigger("RESTRAINED_MODE", 1, func(args): set_restrained(int(args[0]))))
	hook_after(&"Him.givePleasure", _pleasure)
	hook_after(&"Him.setLeftArmPosition", _his_left_arm)
	hook_after(&"Him.setBody", func(_c): _his_body())
	hook_after(&"g.setPenisOut", func(_c): _penis_out())
	menu_control("her", "Arms", MenuSchema.choice("Dynamic arms", "Her arms move by themselves, following what "
		+ "happens and her mood (armOverhaul). Saved with the character.", dyn.MODES, func(): return dyn.MODES[dyn.mode],
		func(v: String): set_dynamic(dyn.MODES.find(v)), {"after": "Right arm", "keywords": "dynamic arms armoverhaul"}))
	menu_control("her", "Arms", MenuSchema.choice("Restrained", "Loose: her hands tied to her thighs. Tight: behind her "
		+ "back, she struggles to free them. Fixed: behind her back, no struggling (armOverhaul). Saved with the character.",
		RESTRAINED_MENU, func(): return RESTRAINED_MENU[(restrained_type + 1) % 4],
		func(v: String): set_restrained((RESTRAINED_MENU.find(v) + 3) % 4), {"after": "Dynamic arms", "keywords": "restrained tied struggle"}))
	menu_control("her", "Arms", MenuSchema.toggle("His leg in front", "His left leg over her and her arms "
		+ "(armOverhaul). Cupping Balls and On His Ass put it there for her right arm.", func(): return leg_on_top,
		_set_leg, {"after": "Restrained", "keywords": "leg layer armoverhaul"}))
	menu_control("her", "Arms", MenuSchema.actions("", "", [["Let go of his hand", func(): _toggle_release(),
		"In His Hand / Holding Hand: she lets go of his hand, or takes it again."]],
		{"after": "His leg in front", "visible": func(): return _right_name() in RIGHT_ONLY}))
	if get_setting("hotkeys"):
		on_key(get_setting("cycleLeftArmKeyLeft"), func(): _cycle(true, -1), "her left arm back")
		on_key(get_setting("cycleLeftArmKeyRight"), func(): _cycle(true, 1), "her left arm on")
		on_key(get_setting("cycleRightArmKeyLeft"), func(): _cycle(false, -1), "her right arm back")
		on_key(get_setting("cycleRightArmKeyRight"), func(): _cycle(false, 1), "her right arm on")
		on_key(get_setting("toggleReleaseHandKey"), _toggle_release, "let go of his hand")
		on_key(get_setting("toggleHimLegLayerKey"), _toggle_leg, "his leg in front")
		on_key(get_setting("toggleDynamicArmsKey"), func(): set_dynamic((dyn.mode + 1) % 4), "dynamic arms")
		on_key(get_setting("cycleRestrainedModeKey"), func(): set_restrained((restrained_type + 1) % 4), "restrained mode")
		on_key(get_setting("cycleHisLeftArmKey"), func():
			g.him.setLeftArmPosition((g.him.currentLeftArmPosition + 1) % Him.leftArmPositions.size()), "his left arm")
		on_key(get_setting("cycleHisRightArmKey"), func():
			g.him.setArmPosition((g.him.currentArmPosition + 1) % Him.armPositions.size()), "his right arm")
		for k in _keys:
			on_key(k, _position_key.bind(k), "arm position key")
		menu_control("help", "Keys", MenuSchema.note("Arm overhaul: numpad 7 / 9 her left arm, 4 / 6 her right arm, "
			+ "5 she lets go of his hand (or takes it), 2 his leg in front, 8 dynamic arms (off, both, left, right), "
			+ "9 restrained mode (loose, tight, fixed, off) · "
			+ "[ / ] his right / left arm"))
	if get_setting("himLegLayerDefault") and not leg_on_top:
		_toggle_leg()
	her.setLeftArmPosition()
	her.setRightArmPosition()
	if restrained_type != 3:
		res.set_type(restrained_type, false)
	g.inGameMenu.updateArmsList()


func _disable() -> void:
	if dyn != null and dyn._auto_on:
		g.autoModeOn = dyn._auto_before
	if leg_on_top:
		_toggle_leg()
	Her.removeArmPositions(id)
	g.inGameMenu.updateArmsList()


func _load_values() -> void:
	V.clear()
	moods.clear()
	mood_keys.clear()
	_keys.clear()
	_key_lists.clear()
	var cf := ConfigFile.new()
	var err := cf.load(file_path("values.cfg"))
	if err != OK:
		push_error("armoverhaul: values.cfg could not be read (%s)" % error_string(err))
		return
	for section in cf.get_sections():
		if section.begins_with("mood_"):
			var mood := {}
			for k in cf.get_section_keys(section):
				mood[k] = float(cf.get_value(section, k))
			moods[section.substr(5).capitalize()] = mood
			if mood_keys.is_empty():
				mood_keys = Array(cf.get_section_keys(section))
			continue
		for k in cf.get_section_keys(section):
			if section == "keys":
				_key_lists[k] = str(cf.get_value(section, k))
			else:
				V[k] = float(cf.get_value(section, k))


## values.cfg [keys]: leftMasturbatingKeys="76" (the mod's names: left / right + position without spaces + Keys,
## comma-separated Flash key codes)
func _add_keys(k: String, codes: String) -> void:
	var left := k.begins_with("left")
	var bare := k.trim_prefix("left").trim_prefix("right").trim_suffix("Keys")
	for n in Her.armPositions:
		if n.replace(" ", "") == bare:
			for c in codes.split(",", false):
				var code := int(c)
				if code > 0:
					if not _keys.has(code):
						_keys[code] = []
					_keys[code].append([left, n])


## The mod's key prefix for a position: "On Hips" -> "onHips"
static func _key(n: String) -> String:
	var s := n.replace(" ", "")
	return s.left(1).to_lower() + s.substr(1)


func _rand_int(lo: String, hi: String) -> int:
	return int(round(randf() * (V[hi] - V[lo]) + V[lo]))


func _left_name() -> String:
	return Her.armPositions[g.her.currentLeftArmPosition]


func _right_name() -> String:
	return Her.armPositions[g.her.currentRightArmPosition]


# ---------------------------------------------------------------- setting her arm up

func _set_up(her: Her, n: String, left: bool) -> void:
	var ik: IKController = her.leftArmIK if left else her.rightArmIK
	var side := "Left" if left else "Right"
	var on_him: Vector2 = Her.leftHandOnHim if left else Her.rightHandOnHim
	var bs: float = g.characterControl.breastSize
	ik.stopDropping()
	if left:
		# animtools first puts the arm in her own layer, by her leg; the mod's positions go behind
		if n in ANIMTOOLS and n not in ["On His Waist", "On His Chest"]:
			g.changeLayer(her.leftArmContainer, her, her.leftLegContainer)
		elif n == "On Neck" or n == "On His Hand":
			g.changeLayer(her.leftArmContainer, g.backLayer, null, true)
		elif n == "Masturbating":
			g.changeLayer(her.leftArmContainer, her, her.leftLegContainer)
		else:
			g.changeLayer(her.leftArmContainer, g.backLayer)
	var breast = her.torsoBack.leftBreast if left else her.torso.midLayer.rightBreast
	var breast_chain: Array = [breast.nipple, breast, her.torsoBack] if left else \
		[breast.nipple, breast, her.torso.midLayer, her.torso, her]
	match n:
		"Cupping Breast":
			ik.newTarget(Vector2(-40 + bs / 10.0, 95 - bs / 8.0), breast.nipple, true)
			ik.reversedEnd = true
			ik.setEndRotationTarget(-168 + bs / 12.0, breast_chain)
			(her.leftBreastController if left else her.rightBreastController).updateFirmness(bs, true)
		"Holding Breast":
			ik.newTarget(Vector2(-50 - minf(110, bs), 80 - bs / 2.65), breast.nipple, true)
			ik.reversedEnd = true
			ik.setEndRotationTarget((-160.0 if left else -165.0) + minf(75.0 if left else 80.0, bs * 1.2), breast_chain)
		"On His Waist":
			ik.newTarget(on_him + (Vector2(-20, -106) if left else Vector2(-12, -36)), g.him.rightLeg, true)
			ik.setEndRotationTarget(-185 if left else -183, [g.him.rightLeg, g.him])
		"On His Chest":
			ik.newTarget(on_him + (Vector2(136, -246) if left else Vector2(144, -176)), g.him.torsoLayer, true)
			ik.setEndRotationTarget(-175 if left else -173, [g.him.torsoLayer, g.him])
		"Gripping Breast":
			ik.newTarget(Vector2(-150 + bs / 1.8, -25 + bs / 13.0), breast.nipple, true)
			ik.setEndRotationTarget(-70, breast_chain)
			_close(her, left, true)
		"Gripping Thigh":
			if restrained:   # tied: where her struggling puts the hand, open
				if left:
					g.changeLayer(her.leftArmContainer, g.backLayer)
				res.aim(her, left)
			else:
				ik.newTarget(Vector2(105, -90) if left else Vector2(95, -75), her.torsoBack.backside, true)
				ik.setEndRotationTarget(-22, [her.torsoBack.backside, her.torsoBack] + ([] if left else [her]))
				_close(her, left, true)
		"On Her Ass":
			ik.reversedEnd = true
			ik.newTarget(Vector2(-5, -80), her.torsoBack.backside, true)
			ik.setEndRotationTarget(36, [her.torsoBack.backside, her.torsoBack] + ([] if left else [her]))
		"On Hips":
			var p := on_him + Vector2(V["onHipsXOffset" + side], -V["onHipsYOffset" + side])
			if left:
				ik.newTarget(p, her.leftLegContainer.leg, true)
				ik.setEndRotationTarget(V["onHipsRotationLeft"], [her.leftLegContainer.leg, her.torso, her])
			else:
				ik.newTarget(p, her.torso.leg, true)
				ik.setEndRotationTarget(V["onHipsRotationRight"], [her.torso.leg, her.torso, her])
		"On Neck":
			ik.reversedEnd = true
			ik.newTarget(on_him + Vector2(V["onNeckXOffset" + side], -V["onNeckYOffset" + side]), her.head.neck, true)
			ik.setEndRotationTarget(V["onNeckRotation" + side], [her.head.neck, her])
		"In Face":
			ik.newTarget(on_him + Vector2(V["inFaceXOffset" + side], -V["inFaceYOffset" + side]), her.head, true)
			ik.setEndRotationTarget(V["inFaceRotation" + side], [her.head, her])
		"In Air":
			_in_air_target(her, left)
		"Holding Stomach":
			ik.newTarget(_stomach_point(her, left), her.torso.midLayer.chest, true)
			ik.setEndRotationTarget(V["holdingStomachRotation" + side], [her.torso, her] if left else [her.torso])
			_close(her, left, true)
		"Cupping Balls":
			ik.reversedEnd = true
			_balls_target(her, left)
			if not left and V["cuppingBallsUnderLeg"] == 1 and not leg_on_top:
				_toggle_leg()
				_leg_by_arm = true
		"On His Ass":
			ik.reversedEnd = true
			ik.newTarget(on_him + Vector2(V["onHisAssXOffset" + side], -V["onHisAssYOffset" + side]), g.him.rightLeg, true)
			ik.setEndRotationTarget(V["onHisAssRotation" + side], [g.him.leftLeg if left else g.him.rightLeg, g.him])
			if not left and V["onHisAssUnderLeg"] == 1 and not leg_on_top:
				_toggle_leg()
				_leg_by_arm = true
		"On His Hand":
			g.changeLayer(her.leftHandOver, g.backLayer, null, true)
			her.leftHandOver.visible = true
			her.leftHandClosed = true
			ik.newTarget(on_him + Vector2(V["onHisHandXOffsetLeft"], -V["onHisHandYOffsetLeft"]), g.him.armContainer.arm.hand, true)
			ik.setEndRotationTarget(V["onHisHandRotationLeft"], [g.him.armContainer.arm.hand, g.him])
		"Masturbating":
			ik.setEndRotationTarget(45, [her.torso.back, her.torso])
			ik.newTarget(Vector2(-70 + cos(_mas_angle) * 10, 260 + sin(_mas_angle) * 10), her.torso.back, true)
		"In His Hand", "Holding Hand":
			_his_hand_target(her, n)
			if leg_on_top:
				_toggle_leg()
				_leg_by_arm = true
			if g.him.currentLeftArmPosition != 1:
				g.him.setLeftArmPosition(1)
			hold_released = false
			if n == "Holding Hand":
				her.rightHandClosed = true


## A closed hand; the left one also shows the hand drawn over her breast (her.leftHandOver)
func _close(her: Her, left: bool, closed: bool) -> void:
	if left:
		her.leftHandClosed = closed
		if closed:
			g.changeLayer(her.leftHandOver, her.leftHandOverContainer)
			her.leftHandOver.visible = true
	else:
		her.rightHandClosed = closed


func _in_air_target(her: Her, left: bool) -> void:
	var side := "Left" if left else "Right"
	var k := pow(in_air, V["inAirCurveExponent"])
	var p := Vector2(lerpf(V["inAirXMin" + side], V["inAirXMax" + side], k), -lerpf(V["inAirYMin" + side], V["inAirYMax" + side], k))
	var ik: IKController = her.leftArmIK if left else her.rightArmIK
	ik.newTarget((Her.leftHandOnHim if left else Her.rightHandOnHim) + p, her.torso, true)
	ik.setEndRotationTarget(lerpf(V["inAirRotationMin" + side], V["inAirRotationMax" + side], k), [her.torso, her])


func _stomach_point(her: Her, left: bool) -> Vector2:
	var side := "Left" if left else "Right"
	return (Her.leftHandOnHim if left else Her.rightHandOnHim) + Vector2(V["holdingStomachXOffset" + side]
		- her.breathingFactor * V["holdingStomachBreathingRate"], -V["holdingStomachYOffset" + side])


func _balls_target(her: Her, left: bool) -> void:
	var side := "Left" if left else "Right"
	var balls = g.him.balls
	var grow: float = balls.scaleX - 1.0
	var pos: Vector2 = balls.rightBallPos if left else balls.leftBallPos
	var ik: IKController = her.leftArmIK if left else her.rightArmIK
	ik.newTarget(Vector2(pos.x + V["cuppingBallsXOffset" + side], pos.y - V["cuppingBallsYOffset" + side]
		- round(grow * V["cuppingBallsYOffsetScaleFactor"])), balls.rightOutline if left else balls.leftOutline, true)
	ik.setEndRotationTarget(V["cuppingBallsRotation" + side] + round(grow * V["cuppingBallsRotationScaleFactor"]), [balls, g.him])


func _his_hand_target(her: Her, n: String) -> void:
	var k := "inHisHand" if n == "In His Hand" else "holdingHand"
	var hand = g.him.leftArmContainer.arm.foreArm.hand
	var off := Vector2(V[k + "FemaleXOffset"], -V[k + "FemaleYOffset"]) if g.him.currentBodyID == 1 else \
		Vector2(V[k + "XOffsetRight"], -V[k + "YOffsetRight"])
	her.rightArmIK.newTarget(Her.rightHandOnHim + off, hand, true)
	her.rightArmIK.setEndRotationTarget(V[k + "FemaleRotation"] if g.him.currentBodyID == 1 else V[k + "RotationRight"],
		[hand, g.him])


func _pass_out(her: Her, left: bool, n: String) -> void:
	var ik: IKController = her.leftArmIK if left else her.rightArmIK
	if n == "In His Hand" and V["inHisHandHoldAfterPassout"] == 1 or n == "Holding Hand" and V["holdingHandHoldAfterPassout"] == 1:
		return
	if restrained and n == "Gripping Thigh":   # tied there
		return
	ik.startDropping(V.get(_key(n) + "SlipTime", 15.0))
	if left:
		if n in ["Gripping Breast", "Gripping Thigh"]:
			g.changeLayer(her.leftArmContainer, g.backLayer)
		g.changeLayer(her.leftHandOver, g.backLayer)


# ---------------------------------------------------------------- every tick

func _tick() -> void:
	if g.gamePaused or not g.gameRunning:
		return
	var her: Her = g.her
	dyn.update_mood()
	dyn.hand_job_tick()
	_arrivals(her)
	# In Air
	in_air -= V["inAirLoss"]
	if not her.passedOut:
		if her.held:
			in_air += V["inAirNoBreathingGain"]
		in_air += her.vigour / 1050.0 * V["inAirVigorGain"]
		in_air += her.passOutFactor / her.passOutMax * V["inAirPassoutGain"]
	if V["inAirRandomLossChance"] > randf():
		in_air *= V["inAirRandomLossFactor"]
	elif V["inAirRandomGainChance"] > randf():
		in_air *= V["inAirRandomGainFactor"]
	in_air = clampf(in_air, 0.0, 1.0)
	_mas_tick(her)
	for left in [true, false]:
		var ik: IKController = her.leftArmIK if left else her.rightArmIK
		if ik.s3Mass != 1 or ik.dropping:
			continue
		var n: String = _left_name() if left else _right_name()
		match n:
			"On Neck":
				if V["onNeckMoveWithBulge"] == 1:
					ik.setEndRotationTarget(V["onNeckRotation" + ("Left" if left else "Right")]
						+ round(V["onNeckDrawPointRate"] * neck_bulge() * g.throatBulgeAmount), [her.head.neck, her])
			"In Air":
				_in_air_target(her, left)
			"Holding Stomach":
				ik.newTarget(_stomach_point(her, left), her.torso.midLayer.chest, true)
			"Cupping Balls":
				_balls_target(her, left)
			"Masturbating":
				if not her.passedOut:
					ik.newTarget(Vector2(-70 + cos(_mas_angle) * 10, 260 + sin(_mas_angle) * 10), her.torso.back, true)
					ik.setEndRotationTarget(45, [her.torso.back, her.torso])
	res.tick()
	dyn.tick()
	res.act()


## How far the bulge pushes her neck out where On Neck holds it (the mod's neckXDifference)
func neck_bulge() -> float:
	var neck = g.her.head.neck
	var i := int(V["onNeckDrawPoint"])
	if i < neck.renderedPoints.size():
		return neck.renderedPoints[i].x - neck.neckPoints[i].x
	return 0.0


## Masturbating: her hand's speed (the mod's calcMasSpeed and its random bursts), her breath while she does it
func _mas_tick(her: Her) -> void:
	var masturbating := _left_name() == "Masturbating"
	if masturbating and her.leftArmIK.s3Mass == 1 and mas_speed < V["randomMasEnableThreshold"]:
		if _random_mas_interval == 0:
			_random_mas_duration = _rand_int("randomMasMinDuration", "randomMasMaxDuration")
			_random_mas_speed = randf() * (V["randomMasMaxSpeed"] - V["randomMasMinSpeed"]) + V["randomMasMinSpeed"]
		if _random_mas_duration == 0:
			_random_mas_interval = _rand_int("randomMasMinInterval", "randomMasMaxInterval")
			_random_mas_speed = 0.0
		_random_mas_interval -= 1
		_random_mas_duration -= 1
	mas_speed -= V["passiveMasSpeedLoss"]
	mas_speed += V["vigorMasSpeed"] * her.vigour / 1050.0
	var peak: float = V["passOutMasSpeedPeak"]
	var diff: float = her.passOutFactor / her.passOutMax - peak
	if diff <= 0:
		mas_speed += V["passOutMasSpeed"] * (1.0 + diff / peak)
	else:
		mas_speed -= V["passOutMasSpeed"] * (diff / (1.0 - peak)) * (1.0 / (1.0 - peak))
	mas_speed = maxf(V["minMasSpeed"], mas_speed)
	if _random_mas_speed <= mas_speed:
		_random_mas_speed = 0.0
	var speed: float = clampf(maxf(mas_speed, _random_mas_speed) * dyn.m["masSpeedFactor"], V["minMasSpeed"],
		V["maxMasSpeed"]) * (1.0 - dyn.exh("masSpeed"))
	mas_final = speed
	if masturbating and not her.passedOut:
		_breath_rest += V["breathLossAmount"] * (speed - V["minMasSpeed"]) / (V["maxMasSpeed"] - V["minMasSpeed"])
		var lose := roundf(_breath_rest)
		g.addBreath(lose)
		_breath_rest -= lose
	_mas_angle = fmod(_mas_angle + speed, 360.0)


func _woke() -> void:
	dyn.after_wake()
	in_air = V["inAirWakeMinGain"] + randf() * (V["inAirWakeMaxGain"] - V["inAirWakeMinGain"])
	mas_speed += V["wakeMasSpeedMin"] + randf() * (V["wakeMasSpeedMax"] - V["wakeMasSpeedMin"])


func _coughed(c: Hooks.Call, open: bool) -> void:
	in_air += V["inAirCoughGain"] * c.obj.coughFactor
	if open:
		dyn.open_cough()
	else:
		dyn.cough()
	res.cough(c.obj.coughFactor)


func _pleasure(c: Hooks.Call) -> void:
	if c.args[0] > 0 and g.handJobMode:
		mas_speed += c.args[0] * V["hjPleasureMasSpeed"]
	dyn.pleasure()


## Dynamic arms: 0 off, 1 both arms, 2 left arm, 3 right arm (hotkey, menu, [DYNAMIC_ARMS_MODE_n])
func set_dynamic(mode: int) -> void:
	dyn.mode = clampi(mode, 0, 3)
	g.saveData.saveCharData()


## Restrained mode: 0 loose, 1 tight, 2 fixed, 3 off (hotkey, menu, [RESTRAINED_MODE_n], character code)
func set_restrained(t: int, save := true) -> void:
	res.set_type(t, V["restrainedModeTransitions"] == 1)
	g.inGameMenu.updateArmsList()
	if save:
		g.saveData.saveCharData()


# ---------------------------------------------------------------- him

## He hid his left arm: her hand lets go of it
func _his_left_arm(c: Hooks.Call) -> void:
	if c.args[0] != 1 and _right_name() in RIGHT_ONLY and not hold_released:
		g.her.rightArmIK.startDropping(V[_key(_right_name()) + "SlipTime"])
		hold_released = true


func _his_body() -> void:
	if _right_name() in RIGHT_ONLY and not hold_released:
		_his_hand_target(g.her, _right_name())
	if leg_on_top:   # his leg pieces may be new ones
		_toggle_leg()
		_toggle_leg()


func _toggle_release() -> void:
	var her: Her = g.her
	if _right_name() not in RIGHT_ONLY:
		return
	if not hold_released:
		her.rightArmIK.startDropping(V[_key(_right_name()) + "SlipTime"])
		hold_released = true
	else:
		her.rightArmIK.stopDropping()
		transition(false, _right_name(), V["hotkeyTransitions"] == 1)
		hold_released = false


## His left leg (and its costume) over her and her arms, or back in its place in him
func _toggle_leg() -> void:
	var him: Him = g.him
	if not leg_on_top:
		_leg_spot.clear()
		for piece in [him.leftLegCostume, him.leftLeg]:
			_leg_spot[piece] = [piece.parent, piece.parent.getChildIndex(piece)]
			g.changeLayer(piece, him.overLayer, null, true)
	else:
		for piece in [him.leftLeg, him.leftLegCostume]:
			var spot = _leg_spot.get(piece)
			if spot == null or not is_instance_valid(spot[0]):
				continue
			piece.parent.removeChild(piece)
			spot[0].addChildAt(piece, mini(spot[1], spot[0].numChildren))
		_leg_spot.clear()
	leg_on_top = not leg_on_top


func _set_leg(on: bool) -> void:
	if on != leg_on_top:
		_toggle_leg()
	_leg_by_arm = false


func _penis_out() -> void:
	var her: Her = g.her
	if _left_name() in ["Holding Stomach", "Gripping Breast", "Gripping Thigh"]:
		g.changeLayer(her.leftHandOver, her.leftHandOverContainer)
	elif _left_name() == "On His Hand":
		g.changeLayer(her.leftHandOver, g.backLayer, null, true)
		her.leftHandOver.visible = true
		g.changeLayer(her.leftArmContainer, g.backLayer, null, true)


# ---------------------------------------------------------------- hotkeys and transitions

func _cycle(left: bool, dir: int) -> void:
	var her: Her = g.her
	var cur: int = her.currentLeftArmPosition if left else her.currentRightArmPosition
	var nxt := Her.stepArmPosition(cur, dir, left)
	if nxt == cur:   # the mod wraps around
		nxt = Her.stepArmPosition(Her.armPositions.size() if dir < 0 else -1, dir, left)
	transition(left, Her.armPositions[nxt], V["hotkeyTransitions"] == 1)
	g.inGameMenu.updateArmsList()
	g.saveData.saveCharData()


func _position_key(code: int) -> void:
	for pair in _keys[code]:
		if Her.armPositionAllowed(Her.armPositions.find(pair[1]), pair[0]):
			transition(pair[0], pair[1], V["hotkeyTransitions"] == 1)
			dyn.key_weight(pair[0], pair[1])
	g.inGameMenu.updateArmsList()
	g.saveData.saveCharData()


## Moves her arm to a position: snaps there, or (smooth) the hand travels from where it is (the mod's transitionLeftArm /
## transitionRightArm); hand job and On His Legs are taken when the hand arrives, Back from a spot behind her.
func transition(left: bool, n: String, smooth: bool) -> void:
	var her: Her = g.her
	var i := Her.armPositions.find(n)
	var cur: int = her.currentLeftArmPosition if left else her.currentRightArmPosition
	var cur_name: String = Her.armPositions[cur]
	var ik: IKController = her.leftArmIK if left else her.rightArmIK
	var s := 0 if left else 1
	if i < 0:
		return
	dyn.moved(left)
	ik.tapping = false
	ik.tapDist = 0
	if not smooth or (i == cur and n not in RIGHT_ONLY):
		_put(her, left, i)
		return
	if n == "Loose":
		her.startArmsPassOut(left, not left)
		if left:
			her.currentLeftArmPosition = 4
			g.leftHandJobMode = false
		else:
			her.currentRightArmPosition = 4
			g.rightHandJobMode = false
		_close(her, left, false)
		g.characterControl.setArmSkin()
		return
	if left and cur_name == "On His Hand" and n in ["Back", "On Legs", "On Her Ass", "On Hips", "Masturbating"] or \
			not left and (cur_name == "Back" and n in ["Holding Breast", "Gripping Thigh", "Holding Stomach", "On Hips"]
			or cur_name == "Holding Breast" and n in ["Gripping Breast", "Holding Stomach"]):
		_put(her, left, i)
		return
	ik.stopDropping()
	if cur_name == "Back":
		_put(her, left, maxi(0, Her.armPositions.find(LOADER_ORDER[int(V["fromBackTransitionPosition"])])))
		her.updateArms()
	var hand = her.leftArmContainer.upperArm.foreArm.hand if left else her.rightForeArmContainer.upperArm.foreArm.hand
	var from: Vector2 = hand.localToGlobal(Vector2())
	if n == "Hand Job":
		ik.newTarget(Vector2(-25.0 * g.him.penisLengthScale - her.handJobDistance + her.workingHandJobDistance
			* g.currentHandJobPos.x + her.workingHandJobOffset, 90.0 * her.bodyScale / g.him.getPenisWidthWithTwitch()
			+ 40.0 - 35.0 * g.him.getPenisWidthWithTwitch()), g.him.penis, true)
		_to_hand_job[s] = true
		ik.reversedEnd = false
	elif n == "On His Legs":
		ik.newTarget(Vector2(-125, 300 if left else 240), g.him.rightLeg if left else g.him.leftLeg, true)
		_to_his_legs[s] = true
	else:
		if n == "Back":
			_put(her, left, maxi(0, Her.armPositions.find(LOADER_ORDER[int(V["backTransitionPosition"])])), false)
			_to_back[s] = true
		else:
			_put(her, left, i, false)
		ik.reversedEnd = false
		_reverse[s] = n in REVERSED
	ik.jumpTo(from)
	ik.startTrackingTarget(true)
	ik.s3Mass = dyn.m["transitionHandMassFactor"] * V["transitionHandMass"] * (1.0 + dyn.exh("transitionHandMass"))
	ik.mass = dyn.m["transitionMassFactor"] * V["transitionMass"] * (1.0 if n == "In His Hand" else 1.0 + dyn.exh("transitionMass"))
	if n in (CLOSED_LEFT if left else CLOSED_RIGHT):
		_close(her, left, false)
		if left:
			her.leftHandOver.visible = false
		_close_hand[s] = true
	g.characterControl.setArmSkin()


func _put(her: Her, left: bool, i: int, update := true) -> void:
	if left:
		her.setLeftArmPosition(i, update)
	else:
		if _leg_by_arm and leg_on_top:
			_toggle_leg()
		_leg_by_arm = false
		her.setRightArmPosition(i, update)


## Transitions: what happens when her hand arrives (the mod's flags, checked every tick)
func _arrivals(her: Her) -> void:
	for s in 2:
		var left := s == 0
		var ik: IKController = her.leftArmIK if left else her.rightArmIK
		if _reverse[s] and ik.s3Mass == 1:
			ik.reversedEnd = not ik.reversedEnd
			_reverse[s] = false
		if _to_back[s] and ik.mass <= V["backTransitionSpeed"]:
			_put(her, left, 0)
			_to_back[s] = false
		if ik.mass == 1:
			if _to_hand_job[s]:
				_put(her, left, 3)
				_to_hand_job[s] = false
			if _close_hand[s]:
				var n: String = _left_name() if left else _right_name()
				if n in (CLOSED_LEFT if left else CLOSED_RIGHT) and not restrained:
					_close(her, left, true)
					g.characterControl.setArmSkin()
				_close_hand[s] = false
			if _to_his_legs[s]:
				_put(her, left, 2)
				_to_his_legs[s] = false
