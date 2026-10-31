extends RefCounted
## armoverhaul's spank reactions, with the spankanywhere plugin (the mod's HIS ARM / SPANK STUFF part of move() and
## the `if (hit)` part of its dynamic arms): while a hit builds up she wants her arms in front of her face (or behind
## her back) and lets go of his hand; a hit speeds up (or, punched, slows down) her masturbating hand, lifts her arms,
## makes her struggle, tap and give up resistance by where it lands, and moves her arms' weights: towards covering
## the part that was hit, away from him, and so on (values.cfg [spank], her mood's spank factors). Weights only build
## up while dynamic arms is on, as everywhere in the port. His left arm (when it shows) winds up while the hit
## builds up, his hand lands where she is hit and swings back (moveHisArmWithSpankPower).

const POS := 0
const NEG := 1
const NEU := 2
## where his loose left hand hangs (the game's HimMaleBody.leftArmDefaultPoint)
const HIS_HAND := Vector2(65, 720)
## The mod reads where a hit lands in its own "smackzone" sprites, placed turned inside each part (SpankAnywhereForked's
## art); the hit's place in the part is taken there before the mod's limits between back, chest, stomach and ass.
const ZONES := {
	"back": Transform2D(Vector2(0.1457977, -0.9892425), Vector2(0.9892425, 0.1457977), Vector2(-1.45, -61.3)),
	"chest": Transform2D(Vector2(-0.0165100, -0.9998474), Vector2(0.9998474, -0.0165100), Vector2(58.2, -64.65)),
	"thigh": Transform2D(Vector2(-0.8314972, -0.5555267), Vector2(0.5555267, -0.8314972), Vector2(101.3, 100.45)),
}

var x            # the plugin
var V: Dictionary
var hit_now := false          # a hit this tick (the mod's `hit`: rubbing starts when it moves an arm)
var _pending: Array = []      # hits from spankanywhere, taken at the start of the next tick
var _charge_added := 0.0      # chargeModeWeightAdded: the face weight the build-up added, taken back at the hit
var f_pos := 1.0              # her mood's spank factors
var f_neg := 0.0
var f_neu := 0.0
var f_punch := 1.0


func _init(plugin) -> void:
	x = plugin
	V = x.V


## spankanywhere's hit signal
func on_hit(part: String, power: int, punch: bool, local: Vector2, node: FlashDisplayObject) -> void:
	_pending.append([part, power, punch, local])
	_slap(node.localToGlobal(local))   # at once: his hand lands with her mark


## Every tick, after her mood's factors and before the arms decide
func tick(sp) -> void:
	var dyn = x.dyn
	var m: Dictionary = dyn.m
	f_pos = maxf(0.0, m["spankPositiveFactor"] + m["positiveExhaustionFactor"] * dyn.exhaustion)
	f_neg = maxf(0.0, m["spankNegativeFactor"] + m["negativeExhaustionFactor"] * dyn.exhaustion)
	f_neu = maxf(0.0, m["spankNeutralFactor"] + m["neutralExhaustionFactor"] * dyn.exhaustion)
	f_punch = maxf(f_neu, maxf(f_neg, f_pos))
	hit_now = false
	if sp != null and sp.power > 0:
		_charge(sp.punch)
	_wind_up(sp.power if sp != null else 0)
	for h in _pending:
		_hit(h[0], h[1], h[2], h[3])
		hit_now = true
	_pending.clear()


## His left hand goes up and back as the hit builds up (back where it hangs once his hand has swung back)
func _wind_up(power: int) -> void:
	var him: Him = g.him
	if him.currentLeftArmPosition != 1 or not (him.currentBody is HimMaleBody):
		return
	var body: HimMaleBody = him.currentBody
	if V["moveHisArmWithSpankPower"] == 1:
		body.leftArmDefaultPoint = HIS_HAND + Vector2(roundf(V["xMovePerPower"] * power),
			roundf(V["yMovePerPower"] * power))
	elif body.leftArmIK.mass == 1:
		body.leftArmDefaultPoint = HIS_HAND


## The hit: his hand is where she was hit, and swings back from there
func _slap(at: Vector2) -> void:
	var him: Him = g.him
	if V["moveHisArmWithSpankPower"] != 1 or not (him.currentBody is HimMaleBody):
		return
	var ik: IKController = him.currentBody.leftArmIK
	ik.jumpTo(at + Vector2(V["hitHandOffsetX"], V["hitHandOffsetY"]))
	ik.startTrackingTarget(true)
	ik.mass = V["hisArmMass"]
	ik.s3Mass = V["hisHandMass"]


## A hit building up: her hands want to go in front of her face, or behind her back; she lets go of his hand
func _charge(punch: bool) -> void:
	var m: Dictionary = x.dyn.m
	if x.dyn.mode != 0:
		var face: float = V["spankChargeFaceWeight"]
		if punch:
			face *= V["punchModeFactor"]
		var f := f_punch if punch and m["punchUseNegative"] == 1 else f_neg
		_add("In Face", f * face, NEG)
		_charge_added += f * face * m["weightDecay"]
		if not (punch and m["punchUseNegative"] == 1):
			_add("Back", f_pos * V["spankChargeBackWeight"], POS)
	if not x.hold_released and V["releaseHandOnSpank"] == 1:
		x._toggle_release()


func _hit(part: String, power: int, punch: bool, local: Vector2) -> void:
	var m: Dictionary = x.dyn.m
	var negative: bool = punch and m["punchUseNegative"] == 1
	# her masturbating hand
	var mas: float = V["spankMasSpeed"] + V["spankMasPowerSpeed"] * power
	if negative:
		x.mas_speed -= mas
		x._random_mas_interval = x._rand_int("randomMasMinInterval", "randomMasMaxInterval")
		x._random_mas_duration = 0
	else:
		x.mas_speed += mas
	x.mas_pause = int(V["spankMasSpeedStopTime"])
	# where it landed
	var loc := _location(part, local)
	var in_air: float = (V["inAirSpankBasePowerBonus"] + power) * (V["inAirPunchMultiplier"] if punch else 1.0)
	var struggle: float = (V["struggleSpankBasePowerBonus"] + power) * (V["strugglePunchMultiplier"] if punch else 1.0)
	x.in_air += V["inAirSpankGain" + loc] * in_air
	x.res.gain(V["struggleSpankGain" + loc] * struggle)
	x.hands.tap((V["tappingPunchMultiplier"] if punch else 1.0)
		* (V["tappingSpankBaseStrength"] + V["tappingSpankGain" + loc] * power))
	x.hands.resistance = maxf(-V["resistanceLossBuffer"], x.hands.resistance - (V["resistancePunchMultiplier"] if punch
		else 1.0) * (V["resistanceSpankBaseStrength"] + V["resistanceSpankLoss" + loc] * power))
	x.dyn.after_spank = 0
	if x.dyn.mode == 0:
		_charge_added = 0.0
		return
	_add("In Face", minf(0.0, -_charge_added), NEG)
	_charge_added = 0.0
	var w: float = (V["baseSpankWeight"] + power * V["spankWeightPerPower"]) * (V["punchModeFactor"] if punch else 1.0)
	var fn := f_punch if negative else f_neg
	var mas_f: float = m["masSpeedFactor"]
	var loose: float = 0.0   # punches only; some moods (looseWeightInverse) take it away instead
	if punch:
		loose = m["spankLooseFactor"] * w * V["spankLoosePowerFactor"] * (1.0 + x.dyn.exh("looseWeight"))
		if m["looseWeightInverse"] == 1:
			loose = -loose
	match loc:
		"Face":
			_add("In Face", fn * w * V["spankFaceFaceWeight"], NEG)
			if not negative:
				_add("In Face", f_neu * w * V["spankFaceFaceNeutralWeight"], NEU)
			if g.him.currentArmPosition == 0:
				_add("On His Hand", fn * w * V["spankFaceHandWeight"], NEG)
			if not negative:
				_add("Masturbating", f_pos * w * V["spankFaceMasturbatingWeight"] * mas_f, POS)
				_add("Back", f_pos * w * V["spankFaceBackWeight"], POS)
			_add("In Air", f_neu * w * V["spankFaceInAirWeight"], NEU)
			_add("Loose", loose * V["spankFaceLooseWeight"], NEU)
		"Upperarm", "Forearm":
			_arm_hit(loc, w, mas_f)
			_add("Loose", loose * V["spank%sLooseWeight" % loc], NEU, false, true)   # her right arm only
		"Breast":
			_add("Gripping Breast", fn * w * V["spankBreastGrippingWeight"], NEG)
			if not negative:
				_add("Gripping Breast", f_neu * w * V["spankBreastNeutralGrippingWeight"], NEU)
			_add("Cupping Breast", fn * w * V["spankBreastCuppingWeight"], NEG)
			if not negative:
				_add("Masturbating", f_pos * w * V["spankBreastMasturbatingWeight"] * mas_f, POS)
				_add("Back", f_pos * w * V["spankBreastBackWeight"], POS)
				_add("Holding Breast", f_pos * w * V["spankBreastHoldingWeight"], POS)
				_add("Holding Stomach", f_pos * w * V["spankBreastStomachWeight"], POS)
			_add("In Air", f_neu * w * V["spankBreastInAirWeight"], NEU)
			_add("Loose", loose * V["spankBreastLooseWeight"], NEU)
		"Chest":
			_add("Cupping Breast", fn * w * V["spankChestCuppingWeight"], NEG)
			if not negative:
				_add("Masturbating", f_pos * w * V["spankChestMasturbatingWeight"] * mas_f, POS)
				_add("Back", f_pos * w * V["spankChestBackWeight"], POS)
				_add("Holding Stomach", f_pos * w * V["spankChestStomachWeight"], POS)
			_add("In Air", f_neu * w * V["spankChestInAirWeight"], NEU)
			_add("Loose", loose * V["spankChestLooseWeight"], NEU)
		"Calf", "Thigh":
			_add("On Legs", fn * w * V["spank%sLegsWeight" % loc], NEG)
			if not negative:
				_add("Masturbating", f_pos * w * V["spank%sMasturbatingWeight" % loc] * mas_f, POS)
				_add("Back", f_pos * w * V["spank%sBackWeight" % loc], POS)
		"Back":
			_add("Gripping Thigh", fn * w * V["spankTorsoThighWeight"], NEG)
			if not negative:
				_add("Masturbating", f_pos * w * V["spankTorsoMasturbatingWeight"] * mas_f, POS)
				_add("Back", f_pos * w * V["spankTorsoBackWeight"], POS)
				_add("On Hips", f_pos * w * V["spankTorsoHipsWeight"], POS)
			_add("In Air", f_neu * w * V["spankTorsoInAirWeight"], NEU)
			_add("Loose", loose * V["spankTorsoLooseWeight"], NEU)
		"Stomach":
			_add("Holding Stomach", fn * w * V["spankStomachStomachWeight"], NEG)
			if not negative:
				_add("Holding Stomach", f_neu * w * V["spankStomachNeutralStomachWeight"], NEU)
				_add("Gripping Breast", f_pos * w * V["spankStomachGrippingWeight"], POS)
				_add("Masturbating", f_pos * w * V["spankStomachMasturbatingWeight"] * mas_f, POS)
				_add("Back", f_pos * w * V["spankStomachBackWeight"], POS)
				_add("On Hips", f_pos * w * V["spankStomachHipsWeight"], POS)
			_add("In Air", f_neu * w * V["spankStomachInAirWeight"], NEU)
			_add("Loose", loose * V["spankStomachLooseWeight"], NEU)
		"Ass":
			_add("On Her Ass", fn * w * V["spankAssAssWeight"], NEG)
			if not negative:
				_add("Masturbating", f_pos * w * V["spankAssMasturbatingWeight"] * mas_f, POS)
				_add("Back", f_pos * w * V["spankAssBackWeight"], POS)
				_add("On Hips", f_pos * w * V["spankAssHipsWeight"], POS)


## A hit on her arm: away from where her arm is (off him, off herself), towards her back, his balls, a hand job...
func _arm_hit(loc: String, w: float, mas_f: float) -> void:
	var red: float = w * V["spank%sReduceWeight" % loc]
	var right: String = x._right_name()
	var left: String = x._left_name()
	if right == "Hand Job":
		_add("Back", f_pos * w * V["spank%sBackWeight" % loc], POS)
		_add("On Legs", f_neu * w * V["spank%sLegsWeight" % loc], NEU)
		_add("Cupping Balls", f_pos * w * V["spank%sCuppingBallsWeight" % loc], POS)
		_reduce("Hand Job", red)
	elif x.dyn.on_him(false):
		_add("Back", f_pos * w * V["spank%sBackWeight" % loc], POS)
		_add("On Legs", f_neu * w * V["spank%sLegsWeight" % loc], NEU)
		_add("Hand Job", f_pos * w * V["spank%sHandJobWeight" % loc], POS)
		for n in ["On His Legs", "On His Waist", "On His Chest", "Cupping Balls", "On His Ass", "On His Hand"]:
			_reduce(n, red)
		_reduce("Holding Hand", red * x.dyn.m["handHoldingFactor"])
	elif x.dyn.on_her(false):
		_add("Hand Job", f_pos * w * V["spank%sHandJobWeight" % loc], POS)
		_add("Cupping Balls", f_pos * w * V["spank%sCuppingBallsWeight" % loc], POS)
		if right != "Back":
			_add("Back", f_pos * w * V["spank%sBackWeight" % loc], POS)
			_reduce("On Legs", red)
		else:
			_add("On Legs", f_neu * w * V["spank%sLegsWeight" % loc], NEU)
			_reduce("Back", red)
		if loc == "Upperarm":   # (the mod's forearm hit leaves this one out)
			_reduce("On Legs", red)
		for n in ["Cupping Breast", "Holding Breast", "Gripping Breast", "Gripping Thigh", "On Her Ass", "On Hips",
				"On Neck", "Holding Stomach"]:
			_reduce(n, red)
	else:
		_reduce(left, red)
		if left != right:
			_reduce(right, red)
	if left != "Masturbating":
		_add("Masturbating", f_pos * w * V["spank%sMasturbatingWeight" % loc] * mas_f, POS)
	else:
		_add("Masturbating", -f_pos * red * mas_f, POS)


## All three weights of a position go down
func _reduce(n: String, amount: float) -> void:
	_add(n, -f_pos * amount, POS)
	_add(n, -f_neu * amount, NEU)
	_add(n, -f_neg * amount, NEG)


func _add(n: String, w: float, kind: int, left := true, right := true) -> void:
	x.dyn.add(n, w, kind, "", left, right)


## The mod's hit locations: its parts, with the stomach (lower front of her chest and back) and her ass (the back of
## her thigh) told apart by where the hit landed
func _location(part: String, local: Vector2) -> String:
	var p := local
	if ZONES.has(part):
		p = ZONES[part].affine_inverse() * local
	match part:
		"chest":
			return "Stomach" if p.x <= -70 else "Chest"
		"thigh":
			return "Ass" if p.x > 80 else "Thigh"
		"back":
			if p.x < -190 and p.y > -20:
				return "Stomach"
			if p.x + p.y > -30:
				return "Chest"
			return "Back"
	return part.capitalize()
