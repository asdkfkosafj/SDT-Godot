extends RefCounted
## armoverhaul's restrained mode and struggling (the mod's restrainedType, strugglePercent and the restrained parts
## of move(), passOutPre and setLeft/RightArmPositionPost): loose mode ties her hands to her thighs, tight and fixed
## behind her back. A struggle percent builds up while she can't breathe, passes out, gets vigorous, winces, coughs or
## wakes, and moves her tied hands; past struggleShiftArmsThreshold she pulls an arm free now and then (tight mode,
## and loose with restrainedType0Struggle) and her head jerks along him. Her hands clench and open as she struggles.

const LOOSE := 0
const TIGHT := 1
const FIXED := 2
const OFF := 3
const NAMES := ["Loose", "Tight", "Fixed", "Off"]

var x            # the plugin
var V: Dictionary
var percent := 0.0          # strugglePercent (0..1)
var ex_percent := 0.0       # ... less her exhaustion
var chance := 0.0           # struggleChance: what happened since the last tick
var _timer := 0             # struggleTimer
var _hand_timer := 0        # closeHandTimer
var _pause := 0             # strugglePauseTimer (after waking)
var _left_chance := 0.0     # leftArmChance: which arm she struggles with next
var _last_move := 0.0       # lastStruggleMovement: her head's jerk, half of it undone when she rests
var _rot := 0.0             # passedOutRotationCurrent: her tied hands turn as she goes limp
var _woke := false


func _init(plugin) -> void:
	x = plugin
	V = x.V


func m() -> Dictionary:
	return x.dyn.m


## The mod's cycleRestrainedMode / RESTRAINED_MODE_n: loose puts both hands on her thighs, tight and fixed behind her
## back; off leaves them where they are (dynamic arms takes over again).
func set_type(t: int, smooth: bool) -> void:
	var her: Her = g.her
	var was: bool = x.restrained
	x.restrained_type = clampi(t, 0, 3)
	x.restrained = x.restrained_type != OFF
	if x.restrained:
		var n := "Gripping Thigh" if x.restrained_type == LOOSE else "Back"
		x.transition(true, n, smooth)
		x.transition(false, n, smooth)
	elif was:   # hands open again unless the position closes them
		x._close(her, true, x._left_name() in x.CLOSED_LEFT)
		x._close(her, false, x._right_name() in x.CLOSED_RIGHT)
		if x._left_name() not in x.CLOSED_LEFT:
			her.leftHandOver.visible = false
		g.characterControl.setArmSkin()


func gain(k: float) -> void:
	percent += m()["struggleGainMultiplier"] * k
	chance += k


## Every tick before the arms are updated: the struggle percent
func tick() -> void:
	var her: Her = g.her
	if _woke:
		percent += m()["struggleGainMultiplier"] * V["struggleWakeMinGain"] + randf() * (V["struggleWakeMaxGain"] - V["struggleWakeMinGain"])
		chance += V["struggleWakeMinGain"] + randf() * (V["struggleWakeMaxGain"] - V["struggleWakeMinGain"])
		_pause = int(V["struggleWakePauseTime"] * chance)
		_woke = false
	if _pause < 0:
		if not her.passedOut:
			var peak: float = V["strugglePassOutPeak"]
			var diff: float = her.passOutFactor / her.passOutMax - peak
			if her.mouthFull:
				if diff <= 0:
					percent += m()["struggleGainMultiplier"] * V["strugglePassoutGain"] * (1.0 + diff / peak)
				else:
					percent -= V["strugglePassoutGain"] * V["strugglePassOutPeakMultiplier"] * (diff / (1.0 - peak)) * (1.0 / (1.0 - peak))
				chance += her.passOutFactor / her.passOutMax * V["strugglePassoutGain"]
			if her.held:
				gain(V["struggleNoBreathingGain"])
			if her.winceTimer > 0:
				gain(V["struggleWinceGain"])
			gain(her.vigour / 1050.0 * V["struggleVigorGain"])
		else:
			percent -= V["strugglePassedOutLoss"]
		percent -= V["struggleLoss"]
	_pause -= 1
	if V["struggleRandomLossChance"] > randf():
		percent *= V["struggleRandomLossFactor"]
	elif V["struggleRandomGainChance"] > randf():
		percent *= V["struggleRandomGainFactor"]
	percent = clampf(percent, 0.0, 1.0)
	ex_percent = percent * (1.0 - x.dyn.exh("struggleGain"))
	if not x.restrained:
		return
	var gripping: bool = x._left_name() == "Gripping Thigh" or x._right_name() == "Gripping Thigh"
	if her.passedOut and gripping:
		var off: float = V["passoutRotationOffset1"] if _first_phase() else V["passoutRotationOffset2"]
		_rot = move_toward(_rot, off, absf((V["struggleLoss"] + V["strugglePassedOutLoss"]) * off * V["passoutRotationSpeedMultiplier"]))
	if her.leftArmIK.s3Mass == 1 and her.rightArmIK.s3Mass == 1:
		for left in [true, false]:
			if (x._left_name() if left else x._right_name()) == "Gripping Thigh":
				aim(her, left)


func _first_phase() -> bool:
	return ex_percent < V["strugglePhaseThreshold"] and x.restrained_type == LOOSE


## Her tied hand on her thigh, where the struggle percent puts it (loose: range 1 to 2, then 2 to 3; tight: 2 to 3)
func aim(her: Her, left: bool) -> void:
	var side := "Left" if left else "Right"
	var a: float
	var lo := "1"
	var hi := "2"
	var phase: float = V["strugglePhaseThreshold"]
	var shift: float = V["struggleShiftArmsThreshold"]
	if _first_phase():
		a = 1.0 - (phase - ex_percent) / phase
	else:
		lo = "2"
		hi = "3"
		if x.restrained_type == LOOSE:
			a = 1.0 - (1.0 - ex_percent) / (1.0 - phase)
			if not her.passedOut and (x._left_name() == "Back" or x._right_name() == "Back") and a < shift:
				a = shift
		else:
			a = shift + (1.0 - shift) * ex_percent
	var k := pow(maxf(0.0, a), V["struggleCurveExponent" + ("1" if lo == "1" else "2")])
	var p := Vector2(lerpf(V["restrainedThighXOffset" + lo + side], V["restrainedThighXOffset" + hi + side], k),
		lerpf(V["restrainedThighYOffset" + lo + side], V["restrainedThighYOffset" + hi + side], k))
	var rot: float = lerpf(V["restrainedThighRotation" + lo + side], V["restrainedThighRotation" + hi + side], k)
	if her.passedOut:
		rot += _rot
	var ik: IKController = her.leftArmIK if left else her.rightArmIK
	ik.newTarget(Vector2(105, -90) + p, her.torsoBack.backside, true)
	ik.setEndRotationTarget(-22 + rot, [her.torsoBack])


## After dynamic arms: she struggles (pulls one arm free, then rests) and clenches her hands
func act() -> void:
	var her: Her = g.her
	if x.restrained and not her.passedOut:
		var type: int = x.restrained_type
		var mood := m()
		if type == LOOSE and V["restrainedType0Struggle"] == 1 or type == TIGHT and V["restrainedType1Struggle"] == 1:
			var loose_mul: float = V["struggleLooseTimeMultiplier"] if type == LOOSE else 1.0
			var rest_pos := "Gripping Thigh" if type == LOOSE else "Back"
			var free_pos := "Back" if type == LOOSE else "Gripping Thigh"
			var struggling: bool = x._left_name() == free_pos or x._right_name() == free_pos
			if _timer < 0 or type == LOOSE and ex_percent < V["struggleShiftArmsThreshold"]:
				if struggling:   # back to rest
					x.transition(true, rest_pos, false)
					x.transition(false, rest_pos, false)
					_timer = int(mood["struggleTimeMultipler"] * loose_mul * (V["struggleRestTimeScale"] + (1.0 - V["struggleRestTimeScale"])
						* (1.0 - percent)) * (V["struggleRestMinTime"] + randf() * (V["struggleRestMaxTime"] - V["struggleRestMinTime"])))
					her.pos -= _last_move * V["struggleMovementReturnMultiplier"]
				elif type == TIGHT or ex_percent > V["struggleShiftArmsThreshold"]:
					var c: float = randf() * (V["struggleBaseChance"] + maxf(mood["struggleIdleChance"], chance * mood["struggleChanceMultiplier"]))
					if c >= V["struggleThreshold"]:
						if randf() > x.dyn.exh("struggleChance"):
							if randf() > 0.5 + _left_chance:
								x.transition(true, "Back", false)
								x.transition(false, "Gripping Thigh", false)
								_left_chance = maxf(0.0, _left_chance) + V["struggleOtherArmChance"]
							else:
								x.transition(true, "Gripping Thigh", false)
								x.transition(false, "Back", false)
								_left_chance = minf(0.0, _left_chance) - V["struggleOtherArmChance"]
							_last_move = (V["struggleMovementScale"] + (1.0 - V["struggleMovementScale"]) * (1.0 - percent)) \
								* (-V["struggleMovementRange"] + 2.0 * randf() * V["struggleMovementRange"])
							her.pos += _last_move
						_timer = int(mood["struggleTimeMultipler"] * loose_mul * (V["struggleTimeScale"] + (1.0 - V["struggleTimeScale"])
							* (1.0 - percent)) * (V["struggleMinTime"] + randf() * (V["struggleMaxTime"] - V["struggleMinTime"])))
		var hc: float = randf() * (V["struggleCloseHandChance"] + maxf(mood["struggleIdleChance"], chance * V["struggleCloseHandMultiplier"]))
		if _hand_timer < 0:
			if hc >= V["struggleThreshold"]:
				if x._left_name() == "Gripping Thigh":
					x._close(her, true, true)
				her.rightHandClosed = true
				_hand_timer = int(mood["struggleTimeMultipler"] * (V["struggleCloseHandTimeScale"] + (1.0 - V["struggleCloseHandTimeScale"])
					* (1.0 - percent)) * (V["struggleCloseHandMinTime"] + randf() * (V["struggleCloseHandMaxTime"] - V["struggleCloseHandMinTime"])))
			else:
				if her.leftHandClosed or her.rightHandClosed:
					_hand_timer = int(mood["struggleTimeMultipler"] * (V["struggleOpenHandTimeScale"] + (1.0 - V["struggleOpenHandTimeScale"])
						* (1.0 - percent)) * (V["struggleOpenHandMinTime"] + randf() * (V["struggleOpenHandMaxTime"] - V["struggleOpenHandMinTime"])))
				else:
					_hand_timer = 0
				her.leftHandClosed = false
				her.rightHandClosed = false
				her.leftHandOver.visible = false
			g.characterControl.setArmSkin()
		_timer -= 1
		_hand_timer -= 1
	chance = 0.0


func cough(f: float) -> void:
	gain(V["struggleCoughGain"] * f)


func clench() -> void:
	chance += V["struggleClenchTeethGain"]


## Before she passes out (passOutPre): loose mode takes both hands to her thighs
func before_pass_out() -> void:
	if x.restrained:
		_rot = 0.0
		if x.restrained_type == LOOSE:
			x.transition(true, "Gripping Thigh", false)
			x.transition(false, "Gripping Thigh", false)


func woke() -> void:
	if x.restrained:
		_woke = true
