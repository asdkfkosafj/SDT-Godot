extends RefCounted
## armoverhaul's hands: tapping (the mod's tapHandsReplace and its tapping triggers), rubbing (animtools' hand rub,
## started by the mod's checkHandRub), jitter and resistance (the start of the mod's move()) and the drop of her arms
## when she passes out (startArmsPassOutReplace, with the mod's slip times).

## positions whose hand may tap him (the mod's allowleftarmtap / allowrightarmtap)
const TAPPING := ["On Legs", "On His Legs", "On His Waist", "On His Chest", "On Hips", "On His Hand"]
## positions whose hand rubs (animtools' isrubbingposition)
const RUBBING := ["On Legs", "On His Legs", "Cupping Breast", "Holding Breast", "On His Waist", "On His Chest", "On Her Ass"]
## arms on him that make her jitter and resist more (unless she wants them there)
const ON_HIM := ["On His Legs", "On His Waist", "On His Chest"]

var x            # the plugin
var V: Dictionary
var resistance := 1.0       # resistancePercent
var _tap_timer := 0
var _open_after_tap := [false, false]    # a tap closed the hand: it opens again after tapClosedHandOpenDelay
var _open_timer := [0, 0]
var rubbing := [false, false]            # the mod's comm.rubhandleft / rubhandright
var _finishing := [false, false]         # rubbing stopped: the hand goes back to its place first
var _rub_target := [null, null]          # where the hand rubs around (animtools' lefthandtarget / righthandtarget)
var _rub_pos := [-1, -1]
var _rub_cycle := 0.0
var _rub_wait := 0                       # animtools' handrubtimer: she stops rubbing while she moves a lot
var rub_timer := 0
var _deepthroat := false
var _nose_spray := false


func _init(plugin) -> void:
	x = plugin
	V = x.V


func m() -> Dictionary:
	return x.dyn.m


func _name(left: bool) -> String:
	return x._left_name() if left else x._right_name()


func can_tap(left: bool) -> bool:
	var her: Her = g.her
	var i: int = her.currentLeftArmPosition if left else her.currentRightArmPosition
	var n := _name(left)
	if n in Her.armPositions.slice(0, Her.GAME_ARM_POSITIONS) or n in x.ANIMTOOLS or n in x.OWN:
		return n in TAPPING and not (x.restrained and n == "Gripping Thigh")
	return her._armCanTap(i)


# ---------------------------------------------------------------- tapping

## The mod's tapHandsReplace: strength 0 does nothing (the game's own call while he holds her), NAN is her
## being held (the mod's held tapping), anything else a tap of that strength
func tap(strength: float) -> void:
	var her: Her = g.her
	if strength == 0.0 or m()["handTapRate"] <= randf():
		return
	var po: float = her.passOutFactor / her.passOutMax
	var point: float = 2.0 - po - g.currentBreathLevel / g.breathLevelMax
	var peak: float = V["tappingCustomHeldPeak"]
	var power: float
	if is_nan(strength):
		if V["tappingUseCustomHeld"] == 0:
			power = randf() + (1.0 - po) * V["tappingPassOutStrength"] * m()["handTapMultiplier"]
		else:
			var close := 1.0 - (absf((peak - point) / (2.0 - peak)) if point > peak else absf((peak - point) / peak))
			power = V["tapThreshold"] * randf() + pow(maxf(0.0, close), V["tapCurveExponent"]) * V["tappingCustomStrength"] * m()["handTapMultiplier"]
	else:
		power = V["tapThreshold"] * randf() + strength * m()["handTapMultiplier"]
		if V["tappingScaleWithPassout"] == 1:
			if V["tappingUseCustomHeld"] == 0:
				power *= 1.0 - po
			elif point <= peak:
				power *= absf((peak - point) / peak)
	if power <= V["tapThreshold"] or randf() <= x.dyn.exh("tapChance"):
		return
	var left: bool = randf() <= V["leftToRightHandTapRatio"]
	var kind: String = x.dyn.left_type if left else x.dyn.right_type
	if x.dyn.mode != 0 and not (kind == "Positive" and randf() <= V["positiveTappingChance"]
			or kind == "Neutral" and randf() <= V["neutralTappingChance"] or kind == "Negative" and randf() <= V["negativeTappingChance"]):
		return
	var ik: IKController = her.leftArmIK if left else her.rightArmIK
	if not can_tap(left) or ik.mass != 1:
		return
	ik.tap(power / (V["tapStrengthDivisor"] * (1.0 + x.dyn.exh("tapStrengthDivisor"))),
		V["tapAlternateRotation"] if randf() < V["tapAlternateRatio"] else V["tapRotation"])
	var mul := 1.0
	if x.dyn.mode != 0:   # the mod reads the right arm's kind here for both hands
		mul = V["closedHand" + x.dyn.right_type + "Multiplier"]
	if randf() > x.dyn.exh("tapClosedHandChance") and \
			V["tapClosedHandChanceGrowth"] * (power - V["tapThreshold"]) * m()["closedHandMultiplier"] * mul > randf():
		if left:
			her.leftHandClosed = true
			if _name(true) != "On Legs":
				g.changeLayer(her.leftHandOver, g.backLayer, null, true)
				g.changeLayer(her.leftArmContainer, g.backLayer, null, true)
			else:
				g.changeLayer(her.leftHandOver, her.leftHandOverContainer)
			her.leftHandOver.visible = true
		else:
			her.rightHandClosed = true
		g.characterControl.setArmSkin()
	_tap_timer = int(V["tapCooldown"] * (1.0 + x.dyn.exh("tapCooldown")))


## Every tick: what makes her tap, hands closed by a tap open again; jitter and resistance; rubbing
func tick() -> void:
	var her: Her = g.her
	if not her.passedOut:
		_jitter(her)
		_resist(her)
	if V["dynamicTapping"] == 1:
		if _tap_timer < 0 and her.vigour / 1050.0 > V["tappingVigorThreshold"]:
			tap(her.vigour / 1050.0 * V["tappingVigorStrength"])
		if her.held and m()["handTapMultiplier"] > 0:
			if V["tappingUseCustomHeld"] == 0:
				if randf() + V["tappingHeldTriggerChance"] < g.currentBreathLevel / g.breathLevelMax:
					tap(NAN)
			elif randf() + V["tappingCustomChance"] < 1.0:
				tap(NAN)
		if not her.held and m()["randomTapChance"] > randf():
			tap(m()["randomTapStrength"])
		if g.him.ejaculating and not her.mouthFull and V["tappingCumOutsideChance"] > randf():
			tap(V["tappingCumOutsideStrength"])
		if not _deepthroat and her.penisInMouthDist > Her.deepthroatDistance and her.mouthFull:
			if V["tappingThroatChance"] > randf():
				tap(V["tappingThroatStrength"])
			_deepthroat = true
		elif her.penisInMouthDist <= Her.deepthroatDistance:
			_deepthroat = false
		if her.nostrilSpraying and V["tappingNostrilSprayChance"] > randf():
			tap(V["tappingNostrilSprayStrength"])
		if her.swallowing and V["tappingSwallowingChance"] > randf():
			tap(V["tappingSwallowingStrength"])
		for s in 2:
			var left := s == 0
			var ik: IKController = her.leftArmIK if left else her.rightArmIK
			if not can_tap(left):
				_open_after_tap[s] = false
			if not ik.tapping and _open_after_tap[s] and _open_timer[s] < 0 and _name(left) != "On His Hand":
				if left:
					her.leftHandClosed = false
					her.leftHandOver.visible = false
				else:
					her.rightHandClosed = false
				_open_after_tap[s] = false
				g.characterControl.setArmSkin()
			if ik.tapping and (her.leftHandClosed if left else her.rightHandClosed):
				_open_after_tap[s] = true
				_open_timer[s] = int(V["tapClosedHandOpenDelay"])
			_open_timer[s] -= 1
		_tap_timer -= 1
	_rub(her)


func cough(f: float) -> void:
	if V["dynamicTapping"] == 1 and f > V["tappingCoughThreshold"]:
		tap(V["tappingCoughStrength"] * f)


func eye_hit() -> void:
	if V["dynamicTapping"] == 1 and _tap_timer < 0:
		tap(V["tappingCumInEyeStrength"])


func fill_mouth() -> void:
	var her: Her = g.her
	if her.held:
		if V["tappingCumInThroatChance"] >= randf():
			tap(V["tappingCumInThroatStrength"])
	elif V["dynamicTapping"] == 1:
		var full: float = float(her.cumInMouth) / her.maxCumInMouth
		if V["tappingCumInMouthBaseChance"] + V["tappingCumInMouthChance"] * full >= randf():
			tap(V["tappingCumInMouthBaseStrength"] + full * V["tappingCumInMouthStrength"])


# ---------------------------------------------------------------- jitter and resistance

func _arms_on_him(factor: float) -> float:
	var k := 0.0
	if x.dyn.left_type != "Positive" and _name(true) in ON_HIM:
		k += factor
	if x.dyn.right_type != "Positive" and _name(false) in ON_HIM:
		k += factor
	return k


func _jitter(her: Her) -> void:
	if V["enableJitter"] != 1 or V["jitterRate"] <= randf():
		return
	var d := 0.0
	var dist: float = her.penisInMouthDist
	if dist > V["jitterDistMin"]:
		if dist < V["jitterDistMax"]:
			d = 1.0 - (dist - V["jitterDistMax"]) / (V["jitterDistMin"] - V["jitterDistMax"])
		elif dist < V["jitterDistFallOff"]:
			d = (V["jitterDistFallOff"] - dist) / (V["jitterDistFallOff"] - V["jitterDistMax"])
	var amount: float = randf() * (V["maxJitter"] - V["minJitter"]) + V["minJitter"]
	her.pos -= maxf(0.0, (1.0 + _arms_on_him(V["jitterArmFactor"])) * amount * (m()["jitterFactor"]
		+ m()["jitterExhaustionFactor"] * x.dyn.exhaustion + m()["jitterDistanceFactor"] * d * (1.0 - x.dyn.exh("jitterDistance"))))


func _resist(her: Her) -> void:
	if V["enableResistance"] != 1:
		return
	var at: float = her.pos if V["resistanceDistMode"] == 1 else her.penisInMouthDist
	var d: float = clampf(1.0 - (at - V["resistanceDistMax"]) / (V["resistanceDistMin"] - V["resistanceDistMax"]), 0.0, 1.0)
	var floor_: float = -V["resistanceLossBuffer"]
	if her.breathing:
		resistance = minf(1.0, resistance + V["resistanceRecovery"])
	if her.acceleration > 0:
		resistance = maxf(floor_, resistance - V["resistanceAccelerationLoss"] * her.acceleration * V["resistanceAccelerationFactor"])
	if her.mouseHeld:
		resistance = maxf(floor_, resistance - V["resistanceHeldLoss"])
	resistance = maxf(floor_, resistance - V["resistancePassoutLoss"] * her.passOutFactor / her.passOutMax)
	var arms := maxf(1.0, _arms_on_him(V["resistanceArmFactor"]))
	her.speed -= (1.0 - x.dyn.exh("resistance")) * arms * maxf(0.0, resistance) * V["resistanceAmount"] \
		* (m()["resistanceFactor"] + m()["resistanceDistanceFactor"] * d * (1.0 - x.dyn.exh("resistanceDistance")))


# ---------------------------------------------------------------- rubbing

## The mod's checkHandRub: after an arm moves and when rub_timer runs out, she starts or stops rubbing (more
## likely in a position she wants); one hand or both
func check_rub() -> void:
	if (not rubbing[0] or not rubbing[1]) and randf() > x.dyn.exh("rubChance"):
		var types := [x.dyn.left_type, x.dyn.right_type]
		var kind := "Negative" if "Negative" in types else ("Neutral" if "Neutral" in types else "Positive")
		var k := kind.to_lower()
		if V[k + "RubChance"] > randf():
			rub_timer = int(V[k + "RubTimeMultiplier"] * (V["rubOnTimeMin"] + randf() * (V["rubOnTimeMax"] - V["rubOnTimeMin"])))
			if V["rubOneArmChance"] > randf():
				_start_rub(0 if V["rubLeftArmChance"] > randf() else 1)
			else:
				_start_rub(0)
				_start_rub(1)
			return
	rub_timer = int(V["rubOffTimeMin"] + randf() * (V["rubOffTimeMax"] - V["rubOffTimeMin"]))
	stop_rub(0)
	stop_rub(1)


func _start_rub(s: int) -> void:
	rubbing[s] = true
	_finishing[s] = false


## Rubbing stops: the hand finishes its stroke back to its place (the mod just let go of it wherever it was)
func stop_rub(s: int) -> void:
	if rubbing[s]:
		rubbing[s] = false
		_finishing[s] = true


## animtools' updatehandrub: the rubbing hand goes back and forth along its end rotation, slower as she passes out,
## and pauses while she moves a lot
func _rub(her: Her) -> void:
	for s in 2:
		var i: int = her.currentLeftArmPosition if s == 0 else her.currentRightArmPosition
		if i != _rub_pos[s]:   # a new position: a new place to rub around
			_rub_pos[s] = i
			_rub_cycle = 0.0
			_finishing[s] = false
			var ik: IKController = her.leftArmIK if s == 0 else her.rightArmIK
			_rub_target[s] = ik.originalTarget if Her.armPositions[i] in RUBBING else null
	if not (rubbing[0] or rubbing[1] or _finishing[0] or _finishing[1]):
		return
	var speed: float = 0.05 * (1.0 - x.dyn.exh("rubSpeed"))
	var done := false
	if _finishing[0] or _finishing[1]:
		_rub_cycle += speed
	elif her.absMovement > 4 or her.passedOut:
		_rub_wait = mini(60, _rub_wait + 2)
	else:
		_rub_wait = maxi(0, _rub_wait - 1)
		_rub_cycle += maxf(0.0, speed * minf(1.0, 1.0 - _rub_wait / 30.0) * (1.0 - her.passOutFactor / her.passOutMax))
	if _rub_cycle > TAU:
		done = _finishing[0] or _finishing[1]
		_rub_cycle -= TAU
	if (_finishing[0] or _finishing[1]) and absf(_rub_cycle - PI) <= speed:
		done = true
	for s in 2:
		if not (rubbing[s] or _finishing[s]) or _rub_target[s] == null:
			_finishing[s] = false
			continue
		var ik: IKController = her.leftArmIK if s == 0 else her.rightArmIK
		if ik.dropping or ik.mass != 1:
			continue
		var k := sin(_rub_cycle)
		if _finishing[s] and done:
			k = 0.0
			_finishing[s] = false
		var a := deg_to_rad(ik.endRotationAngle - 90.0)
		ik.targetPoint = _rub_target[s] + Vector2(cos(a), sin(a)) * 50.0 * k


## Each tick with dynamic arms on (and not restrained or just woken): the rubbing timer
func rub_tick() -> void:
	if V["dynamicRubbing"] == 1:
		if rub_timer < 0:
			check_rub()
	rub_timer -= 1


# ---------------------------------------------------------------- passing out

## The mod's startArmsPassOutReplace for the game's own positions: its slip times, and an arm behind her back slips
## down to her thigh (unless she is tied)
func drop(her: Her, left: bool) -> void:
	var n := _name(left)
	var ik: IKController = her.leftArmIK if left else her.rightArmIK
	match n:
		"Back":
			if x.restrained:
				return
			if left:
				her.setLeftArmFree(true)
				g.changeLayer(her.leftArmContainer, g.backLayer)
				g.changeLayer(her.leftArmContainer, her, her.leftLegContainer)
			else:
				her.setRightArmFree(true)
			if her._tan:
				her._tan.updateSkin()
			ik.stopDropping()
			ik.newTarget(Vector2(105, -90) if left else Vector2(95, -75), her.torsoBack.backside, true)
			ik.setEndRotationTarget(-22, [her.torsoBack.backside, her.torsoBack, her])
			ik.startDropping(V["backSlipTime"])
		"On Legs":
			ik.startDropping(V["onLegsSlipTime"])
		"On His Legs":
			ik.startDropping(V["onHislegsSlipTime"])
		"Hand Job":
			ik.startDropping(V["handJobSlipTime"])
		_:
			ik.startDropping(V["defaultSlipTime"])
	if left:
		g.changeLayer(her.leftHandOver, g.backLayer)
