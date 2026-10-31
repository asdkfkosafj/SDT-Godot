extends RefCounted
## armoverhaul's dynamic arms (the mod's DYNAMIC ARMS part of move(), addWeight, updateWeights and its event hooks):
## each arm keeps a positive, a negative and a neutral weight for every position; what happens in the scene adds
## to them, scaled by her mood's factors (values.cfg [mood_...]), they decay every tick, and the arm moves to the
## heaviest one when it is heavy enough and the arm's cooldown is over. Spank reactions: spank.gd.

const POS := 0
const NEG := 1
const NEU := 2
## positions with weights, in the mod's order (animtools' "Custom" is not ported)
const LEFT := ["Back", "On Legs", "On His Legs", "Hand Job", "Loose", "Cupping Breast", "Holding Breast",
	"On His Waist", "On His Chest", "Gripping Breast", "Gripping Thigh", "On Her Ass", "On Hips", "On Neck", "In Face",
	"In Air", "Holding Stomach", "Cupping Balls", "On His Ass", "On His Hand", "Masturbating"]
const RIGHT := ["Back", "On Legs", "On His Legs", "Hand Job", "Loose", "Cupping Breast", "Holding Breast",
	"On His Waist", "On His Chest", "Gripping Breast", "Gripping Thigh", "On Her Ass", "On Hips", "On Neck", "In Face",
	"In Air", "Holding Stomach", "Cupping Balls", "On His Ass", "In His Hand", "Holding Hand"]
const MODES := ["Off", "Both arms", "Left arm", "Right arm"]

var x            # the plugin
var V: Dictionary
var mode := 1    # 0 off, 1 both arms, 2 left arm, 3 right arm (the mod's dynamicArmsMode)
var wl := {}     # left arm: position -> [positive, negative, neutral]
var wr := {}
var left_type := "Neutral"    # the kind of weight that put each arm where it is
var right_type := "Neutral"
var cooldown := [0, 0]
var post_wake := 0            # her arms stay loose a while after she wakes
var exhaustion := 0.0         # progressiveExhaustion's (not ported yet)
var m: Dictionary             # her mood's factors
var custom := {}              # a "Custom" mood from the character code (the mod's 34-value armOverhaul field)
var _custom_mood := ""        # ... used until her mood changes from this one
var f_pos := 1.0              # the mood's factors, with exhaustion
var f_neg := 1.0
var f_neu := 1.0

var after_spank := 0          # afterSpankFrames
var _deepthroat := false
var _look_down := -1
var _look_face := -1
var _released_before := true
var _nose_spray := false
var _wake_pos := [-1, -1]
var _auto_before := false     # auto mode before her hand went on him
var _auto_on := false         # ... and it is to come back when her hands leave him
var _hand_job := false
var _debug := 0


func _init(plugin) -> void:
	x = plugin
	V = x.V
	reset_weights()


func reset_weights() -> void:
	wl.clear()
	wr.clear()
	for n in LEFT:
		wl[n] = [0.0, 0.0, 0.0]
	for n in RIGHT:
		wr[n] = [0.0, 0.0, 0.0]
	for w in [wl, wr]:
		w["Back"][POS] = V["backBaseWeight"]
		w["On Legs"][NEU] = V["onLegsBaseWeight"]
		w["On His Legs"][NEG] = V["onHisLegsBaseWeight"]


func on(left: bool) -> bool:
	return mode == 1 or mode == (2 if left else 3)


func mood_name() -> String:
	return x.mood()


## Her mood's factors, every tick before anything uses them (the start of the mod's move())
func update_mood() -> void:
	var name: String = mood_name()
	if _custom_mood == "*":   # loaded with the character: her mood then
		_custom_mood = name
	if _custom_mood != "" and name != _custom_mood:
		_custom_mood = ""
	if _custom_mood != "":
		m = custom
	else:
		m = x.moods.get(name, x.moods.get("Normal", {}))
	f_pos = maxf(0.0, m["positiveFactor"] + m["positiveExhaustionFactor"] * exhaustion)
	f_neg = maxf(0.0, m["negativeFactor"] + m["negativeExhaustionFactor"] * exhaustion)
	f_neu = maxf(0.0, m["neutralFactor"] + m["neutralExhaustionFactor"] * exhaustion)


func exh(key: String) -> float:
	return minf(V[key + "Max"], V[key + "Rate"] * exhaustion)


func add(n: String, w: float, kind: int, cond := "", left := true, right := true) -> void:
	var lw: float = w + randf() * w * 2.0 * V["randomFactor"] - w * V["randomFactor"]
	var c: float = 1.0 - V["armCorrelation"]
	var rw: float = lw + randf() * lw * 2.0 * c - lw * c
	if left and wl.has(n) and (cond == "" or cond == "him" and on_him(true) or cond == "her" and on_her(true)):
		wl[n][kind] += lw
	if right and wr.has(n) and (cond == "" or cond == "him" and on_him(false) or cond == "her" and on_her(false)):
		wr[n][kind] += rw


func on_him(left: bool) -> bool:
	var n: String = x._left_name() if left else x._right_name()
	return n in ["On His Legs", "On His Waist", "On His Chest", "Cupping Balls", "On His Ass"] or \
		(n in ["Hand Job", "On His Hand"] if left else n == "Holding Hand")


func on_her(left: bool) -> bool:
	var n: String = x._left_name() if left else x._right_name()
	return n in ["Back", "On Legs", "Cupping Breast", "Holding Breast", "Gripping Breast", "Gripping Thigh",
		"On Her Ass", "On Hips", "On Neck", "Holding Stomach"] or left and n == "Masturbating"


func _mas() -> float:
	return m["masSpeedFactor"]


func _hand() -> float:
	return m["handHoldingFactor"]


## The mod's hand job auto mode: an arm on him (dynamic arms on) turns auto mode on, in the mood's style; a negative
## hand job holds him down. When no arm is on him any more, auto mode is back to what it was.
func hand_job_tick() -> void:
	var her: Her = g.her
	var on_him: bool = x._left_name() == "Hand Job" or x._right_name() == "Hand Job"
	var use: bool = mode != 0 and V["handJobUseAuto"] == 1
	if on_him and not _hand_job and use:   # auto mode starts over in the mood's style
		_auto_before = g.autoModeOn
		_auto_on = true
		g.autoModeOn = false
	elif not on_him and _auto_on:
		g.autoModeOn = _auto_before
		_auto_on = false
	_hand_job = on_him
	var hj: bool = x._left_name() == "Hand Job" and not her.leftArmIK.dropping or \
		x._right_name() == "Hand Job" and not her.rightArmIK.dropping
	if use and hj and not g.autoModeOn:
		if g.him.currentArmPosition == 0:
			var next := int(m["handJobAutoMode"])
			if exhaustion >= V["handJobAutoModeSoftStart"]:
				next = 1
			elif exhaustion >= V["handJobAutoModeNormalStart"] and next != 1:
				next = 0
			g.setAuto(next)
		else:
			g.setAuto(3)
		g.toggleAutoMode()
	if left_type == "Negative" and x._left_name() == "Hand Job" or right_type == "Negative" and x._right_name() == "Hand Job":
		g.automaticControl.currentMode = g.automaticControl.holdDown
		g.automaticControl.waitingForSingleAction = true


## Every tick: what's happening adds weight, the weights decay, and the arms go to the heaviest position
func tick() -> void:
	if mode == 0:
		return
	var her: Her = g.her
	var him: Him = g.him
	var pass_out: float = her.passOutFactor / her.passOutMax
	var breath: float = g.currentBreathLevel / g.breathLevelMax
	var vigour: float = her.vigour / 1050.0
	var in_throat: bool = her.pos > Her.maxPos * V["inThroatDistanceMultiplier"] and her.mouthFull
	var loose_ex: float = 1.0 + exh("looseWeight")
	# idle
	if absf(her.speed) < V["idleSpeed"]:
		if not in_throat:
			add("Back", V["backIdleWeight"] * f_pos, POS)
			add("Hand Job", V["handJobIdleWeight"] * f_pos, POS)
			add("Cupping Breast", V["cuppingBreastIdleNegWeight"] * f_neg, NEG)
			add("Gripping Breast", V["grippingBreastIdleWeight"] * f_neg, NEG)
			add("Holding Breast", V["holdingBreastIdlePosWeight"] * f_pos, POS)
			add("On Hips", V["onHipsIdleWeight"] * f_pos, POS)
		add("Cupping Breast", V["cuppingBreastIdlePosWeight"] * f_pos, POS)
		add("Masturbating", V["masturbatingIdleWeight"] * f_pos * _mas(), POS)
	# passing out
	var loose_po := (1.0 - pass_out) if m["looseWeightInverse"] == 1 else pass_out
	add("Loose", m["spankLooseFactor"] * V["loosePassoutWeight"] * loose_po * loose_ex, NEU)
	add("On His Legs", V["onHisLegsPassoutWeight"] * pass_out * f_neu, NEU)
	add("On His Waist", V["onHisWaistPassoutWeight"] * pass_out * f_neu, NEU)
	add("On His Chest", V["onHisChestPassoutWeight"] * pass_out * f_neu, NEU)
	if him.currentArmPosition == 0:
		add("On His Hand", V["onHisHandPassoutWeight"] * pass_out * f_neg, NEG)
	add("On His Ass", V["onHisAssInversePassOutWeight"] * (1.0 - pass_out) * f_pos, POS)
	add("In Air", V["inAirPassoutWeight"] * pass_out * f_neu, NEU)
	add("Masturbating", V["masturbatingPassoutWeight"] * pass_out * f_pos * _mas(), POS)
	# breath
	add("Back", V["backBreathInverseWeight"] * (1.0 - breath) * f_pos, POS)
	add("On Legs", V["onLegsBreathInverseWeight"] * (1.0 - breath) * f_neu, NEU)
	add("On His Legs", V["onHisLegsBreathWeight"] * breath * f_neu, NEU)
	add("On His Waist", V["onHisWaistBreathWeight"] * breath * f_neu, NEU)
	add("On His Chest", V["onHisChestBreathWeight"] * breath * f_neu, NEU)
	if her.breathing and after_spank > V["onHipsPauseAfterSpankFrames"]:
		add("On Hips", V["onHipsBreathWeight"] * breath * f_neu, NEU)
	after_spank += 1
	# vigour
	add("On His Legs", V["onHisLegsVigorWeight"] * vigour * f_neu, NEU)
	add("On His Waist", V["onHisWaistVigorWeight"] * vigour * f_neu, NEU)
	add("In Air", V["inAirVigorWeight"] * vigour * f_neu, NEU)
	add("Cupping Balls", V["cuppingBallsVigorWeight"] * vigour * f_pos, POS)
	if him.currentArmPosition == 0:
		add("On His Hand", V["onHisHandVigorWeight"] * vigour * f_neg, NEG)
	# how close she is to him
	if her.penisInMouthDist > V["distanceFromPenisMin"]:
		var d: float = V["distanceFromPenisMultiplier"] * clampf(1.0 - (her.penisInMouthDist - V["distanceFromPenisMax"])
			/ (V["distanceFromPenisMin"] - V["distanceFromPenisMax"]), 0.0, 1.0)
		add("On His Legs", V["onHisLegsDistanceWeight"] * d * f_neg, NEG)
		add("On His Waist", V["onHisWaistDistanceWeight"] * d * f_neg, NEG)
		add("On His Chest", V["onHisChestDistanceWeight"] * d * f_neg, NEG)
		add("Back", V["backDistanceWeight"] * d * f_pos, POS)
		add("Holding Hand", V["holdingHandDistanceWeight"] * f_pos * _hand(), POS)
	# in her mouth
	if her.mouthFull:
		add("Cupping Balls", V["cuppingBallsInMouthWeight"] * f_pos, POS)
		add("Holding Hand", V["holdingHandInMouthWeight"] * f_pos * _hand(), POS)
		add("On His Legs", V["onHisLegsInMouthWeight"] * f_pos, POS)
		add("On His Waist", V["onHisWaistInMouthWeight"] * f_pos, POS)
		add("On His Chest", V["onHisChestInMouthWeight"] * f_pos, POS)
	# going deep
	if not _deepthroat and her.penisInMouthDist > Her.deepthroatDistance and her.mouthFull:
		add("On Neck", V["onNeckThroatWeight"] * f_neu, NEU)
		add("In Air", V["inAirThroatWeight"] * f_neu, NEU)
		_deepthroat = true
	elif her.penisInMouthDist <= Her.deepthroatDistance:
		_deepthroat = false
	# in her throat
	if in_throat:
		add("On His Ass", V["onHisAssInThroatWeight"] * f_pos, POS)
		add("Hand Job", V["handJobInThroatWeight"] * f_neg, NEG)
		add("In Air", V["inAirInThroatWeight"] * f_neu, NEU)
	if her.pos < Her.maxPos * V["inThroatDistanceMultiplier"]:
		for w in [wl, wr]:
			w["Hand Job"][NEG] *= V["handJobInThroatWeightDecay"]
			w["On His Ass"][POS] *= V["onHisAssInThroatWeightDecay"]
	# where she looks
	if her.lookChangeTimer == 0 and her.currentLookTarget != her.nextLookTarget and her.winceTimer <= 0:
		if her.nextLookTarget == her.hisFace:
			_look_face = int(V["lookTargetChangeTime"])
		elif her.nextLookTarget == her.eyesDown:
			_look_down = int(V["lookTargetChangeTime"])
	if _look_down == 0 and her.currentLookTarget == her.eyesDown and not her.mouthFull:
		add("Masturbating", V["masturbatingLookDownWeight"] * f_pos * _mas(), POS)
	if _look_face == 0 and her.currentLookTarget == her.hisFace:
		if her.penisInMouthDist < Her.deepthroatDistance:
			add("Hand Job", V["handJobLookAtFaceWeight"] * f_pos, POS)
		add("Holding Hand", V["holdingHandLookAtFaceWeight"] * f_pos * _hand(), POS)
	_look_down -= 1
	_look_face -= 1
	if her.currentLookTarget == her.hisFace:
		if her.penisInMouthDist < Her.deepthroatDistance:
			add("Hand Job", V["handJobLookingWeight"] * f_pos, POS)
		add("Holding Hand", V["holdingHandLookingWeight"] * f_pos * _hand(), POS)
	if her.currentLookTarget == her.eyesDown and not her.mouthFull:
		add("Masturbating", V["masturbatingLookingWeight"] * f_pos * _mas(), POS)
	# how her head is tilted
	if not her.mouthFull or her.penisInMouthDist < Her.deepthroatDistance:
		var a: float = her.headTiltAngle
		add("On His Legs", V["onHisLegsHeadAngleWeight"] * a * f_pos, POS)
		add("Hand Job", V["handJobHeadAngleWeight"] * a * f_pos, POS)
		add("Cupping Breast", V["cuppingBreastHeadAngleNegWeight"] * a * f_neg, NEG)
		add("Holding Breast", V["holdingBreastHeadAngleWeight"] * a * f_pos, POS)
		add("On His Waist", V["onHisWaistHeadAngleWeight"] * a * f_pos, POS)
		add("On His Chest", V["onHisChestHeadAngleWeight"] * a * f_pos, POS)
		add("Gripping Breast", V["grippingBreastHeadAngleWeight"] * a * f_neg, NEG)
		add("On Hips", V["onHipsHeadAngleWeight"] * a * f_neu, NEU)
		add("On His Hand", V["onHisHandHeadAngleWeight"] * a * f_neg, NEG)
		add("Back", V["backHeadAngleWeight"] * a * f_pos, POS)
		add("On Legs", V["onLegsHeadAngleWeight"] * a * f_neu, NEU)
		add("Cupping Breast", V["cuppingBreastHeadAnglePosWeight"] * a * f_pos, POS)
		add("Masturbating", V["masturbatingHeadAngleWeight"] * a * f_pos * _mas(), POS)
	# he grabs her head
	if her.released:
		wl["On His Hand"][NEG] *= V["onHisHandReleasedDecay"]
	elif _released_before:
		add("Back", V["backHeadGrabWeight"] * f_pos, POS)
		add("On His Legs", V["onHisLegsHeadGrabWeight"] * f_neg, POS)   # the mod's mix of factor and kind
		add("Masturbating", V["masturbatingHeadGrabWeight"] * f_pos * _mas(), POS)
		add("On His Hand", V["onHisHandHeadGrabWeight"] * f_neg, NEG)
	_released_before = her.released
	# he comes
	if him.ejaculating:
		if not her.mouthFull:
			add("Holding Breast", V["holdingBreastCumOutsideWeight"] * f_pos, POS)
			add("Gripping Breast", V["grippingBreastCumOutsideWeight"] * f_pos, POS)
			add("On Neck", V["onNeckCumOutsideWeight"] * f_pos, POS)
			add("In Face", V["inFaceCumOutsideWeight"] * f_neg, NEG)
			add("Hand Job", V["handJobCumOutsideWeight"] * f_pos, POS)
		else:
			add("Cupping Balls", V["cuppingBallsCumInsideWeight"] * f_pos, POS)
			add("Holding Hand", V["holdingHandCumInsideWeight"] * f_pos * _hand(), POS)
		add("On His Waist", V["onHisWaistCummingWeight"] * f_neg, NEG)
		add("Masturbating", V["masturbatingCummingWeight"] * f_pos * _mas(), POS)
	if her.droolingCum:
		add("On Neck", V["onNeckCumDroolWeight"] * f_neu, NEU)
		add("In Face", V["inFaceCumDroolWeight"] * f_neg, NEG)
		add("Holding Breast", V["holdingBreastCumDroolWeight"] * f_pos, POS)
		add("Gripping Breast", V["grippingBreastCumDroolWeight"] * f_pos, POS)
	if her.nostrilSpraying:
		if not _nose_spray:
			add("In Face", V["inFaceCumOutNoseInitWeight"] * f_neu, NEU)
			_nose_spray = true
		add("In Face", V["inFaceCumOutNoseWeight"] * f_neu, NEU)
	else:
		_nose_spray = false
	if her.winceTimer > 0:
		add("On His Legs", V["onHisLegsWinceWeight"] * f_neu, NEU)
		add("On His Waist", V["onHisWaistWinceWeight"] * f_neu, NEU)
		add("On Neck", V["onNeckWinceWeight"] * f_neu, NEU)
		add("In Air", V["inAirWinceWeight"] * f_neu, NEU)
	if her.swallowing:
		add("On Neck", V["onNeckSwallowWeight"] * f_neu, NEU)
		add("In Face", V["inFaceSwallowWeight"] * f_neg, NEG)
		add("Holding Stomach", V["holdingStomachSwallowWeight"] * f_neu, NEU)
	add("On Neck", V["onNeckBulgeWeight"] * x.neck_bulge() * f_neu, NEU)
	add("Masturbating", V["masturbatingSpeedWeight"] * x.mas_final * f_pos * _mas(), POS)
	if x._right_name() == "Holding Hand" and x.hold_released:
		wr["Holding Hand"][POS] *= V["holdingHandDroppedDecay"]
	# far enough along him, some go faster
	if her.pos >= V["inFaceCancelPos"]:
		for w in [wl, wr]:
			w["In Face"][NEG] *= V["inFaceCancelDecay"]
			w["In Face"][NEU] *= V["inFaceCancelDecay"]
	if her.pos >= V["handJobCancelPos"] and her.mouthFull:
		for w in [wl, wr]:
			w["Hand Job"][POS] *= V["handJobCancelDecay"]
	if (x._to_hand_job[0] or x._left_name() == "Hand Job") and left_type == "Negative":
		wr["Hand Job"][NEG] = 0.0
	elif (x._to_hand_job[1] or x._right_name() == "Hand Job") and right_type == "Negative":
		wl["Hand Job"][NEG] = 0.0
	_decide(her)


func _heaviest(w: Dictionary, order: Array) -> Array:
	var best := ""
	var kind := ""
	var most := -999.0
	for n in order:
		var a: Array = w[n]
		if a[POS] > most:
			best = n; kind = "Positive"; most = a[POS]
		if a[NEG] > most:
			best = n; kind = "Negative"; most = a[NEG]
		if a[NEU] > most:
			best = n; kind = "Neutral"; most = a[NEU]
	return [best, kind, most]


func _decay(w: Dictionary, k: float) -> void:
	for n in w:
		var a: Array = w[n]
		a[POS] = maxf(0.0, a[POS] * k)
		a[NEG] = maxf(0.0, a[NEG] * k)
		a[NEU] = maxf(0.0, a[NEU] * k)
	w["Back"][POS] = maxf(V["backBaseWeight"] * f_pos, w["Back"][POS])
	w["On His Legs"][NEG] = maxf(V["onHisLegsBaseWeight"] * f_neg, w["On His Legs"][NEG])
	w["On His Waist"][NEG] = maxf(V["onHisWaistBaseWeight"] * f_neg, w["On His Waist"][NEG])
	w["On His Chest"][NEG] = maxf(V["onHisChestBaseWeight"] * f_neg, w["On His Chest"][NEG])
	w["On Legs"][NEU] = maxf(V["onLegsBaseWeight"] * f_neu, w["On Legs"][NEU])


func _decide(her: Her) -> void:
	var decay: float = m["weightDecay"] + (1.0 - m["weightDecay"]) * minf(V["weightDecayMax"], V["weightDecayRate"] * exhaustion)
	var l := _heaviest(wl, LEFT)
	var r := _heaviest(wr, RIGHT)
	_decay(wl, decay)
	_decay(wr, decay)
	var loose: float = V["extraLooseWeightDecay"] + (1.0 - V["extraLooseWeightDecay"]) * exh("extraLooseWeightDecay")
	for w in [wl, wr]:
		w["Loose"][NEU] *= loose
		w["In Face"][NEU] *= V["extraInFaceWeightDecay"]
		w["In Face"][NEG] *= V["extraInFaceWeightDecay"]
		w["Hand Job"][NEG] *= V["extraHandJobNegativeWeightDecay"]
	cooldown[0] -= 1
	cooldown[1] -= 1
	var smooth: bool = V["dynamicArmsTransitions"] == 1
	var awkward: bool = V["disableNonTransitions"] == 1
	if not x.restrained and post_wake <= 0:
		var cur: String = x._left_name()
		if mode != 3 and not her.passedOut and cooldown[0] <= 0 and (l[0] != cur or l[1] != left_type) \
				and l[2] >= V["minimumWeightThreshold"]:
			if not awkward or not (cur == "On His Hand" and l[0] in ["Back", "On Legs", "On Her Ass", "On Hips", "Masturbating"]):
				if not (l[0] != "Loose" and r[0] == "Loose"):
					x.transition(true, l[0], smooth)
					_spank_rub(0)
					left_type = l[1]
					wl[l[0]][_kind(l[1])] += V["extraWeightOnTransition"]
			else:
				wl[l[0]] = [0.0, 0.0, 0.0]
		cur = x._right_name()
		if mode != 2 and not her.passedOut and cooldown[1] <= 0 and (r[0] != cur or r[1] != right_type) \
				and r[2] >= V["minimumWeightThreshold"] and not (cur == "In His Hand" and not her.rightArmIK.dropping):
			if not (l[0] == "Loose" and r[0] != "Loose"):
				if not awkward or not (cur == "Back" and r[0] in ["Holding Breast", "Gripping Thigh", "Holding Stomach", "On Hips"]
						or cur == "Holding Breast" and r[0] in ["Gripping Breast", "Holding Stomach"]):
					x.transition(false, r[0], smooth)
					_spank_rub(1)
					right_type = r[1]
					wr[r[0]][_kind(r[1])] += V["extraWeightOnTransition"]
				else:
					wr[r[0]] = [0.0, 0.0, 0.0]
		x.hands.rub_tick()
	post_wake = maxi(0, post_wake - 1)
	if V["debugMode"] == 1:
		_debug -= 1
		if _debug < 0:
			print("armoverhaul: left %s %.2f %s, right %s %.2f %s" % [l[0], l[2], l[1], r[0], r[2], r[1]])
			_debug = int(V["debugRefresh"])
	if x._right_name() == "Hand Job" and right_type == "Negative" or x._left_name() == "Hand Job" and left_type == "Negative":
		var p: Dictionary = her.pullOffPower
		p["current"] = minf(p["max"], V["handJobNegativePullOffFactor"] * (p["current"] + p["increase"]))


## An arm moved by a hit starts rubbing where it lands (spankRub)
func _spank_rub(s: int) -> void:
	if x.spank.hit_now and V["spankRub"] == 1 and V["dynamicRubbing"] == 1:
		x.hands.rub_timer = int(V["spankRubTimeMin"] + randf() * (V["spankRubTimeMax"] - V["spankRubTimeMin"]))
		x.hands.rubbing[s] = true


static func _kind(t: String) -> int:
	return POS if t == "Positive" else (NEG if t == "Negative" else NEU)


## An arm starts moving (any transition, also hotkeys): its cooldown starts and it lets go of where it was
func moved(left: bool) -> void:
	cooldown[0 if left else 1] = int(V["minimumCooldown"] * (1.0 + exh("dynamicArmsMinCooldown")))
	var w := wl if left else wr
	var n: String = x._left_name() if left else x._right_name()
	if w.has(n):
		for k in 3:
			w[n][k] -= V["prevWeightLossOnTransition"]


## A position key held down: that position gets the hotkey weight (all three kinds)
func key_weight(left: bool, n: String) -> void:
	var w := wl if left else wr
	if w.has(n):
		for k in 3:
			w[n][k] += V["hotkeyWeight"]


# ---------------------------------------------------------------- events

func cough() -> void:
	var her: Her = g.her
	if her.pos > Her.maxPos * V["inThroatDistanceMultiplier"] and her.mouthFull:
		add("Hand Job", V["handJobInThroatCoughWeight"] * f_neg, NEG)
	add("On Neck", V["onNeckCoughWeight"] * f_neu, NEU)
	add("In Air", V["inAirCoughWeight"] * f_neu, NEU)
	add("Holding Stomach", V["holdingStomachCoughWeight"] * f_neu, NEU)


func open_cough() -> void:
	add("On Neck", V["onNeckCoughWeight"] * f_neu, NEU)
	add("In Face", V["inFaceCoughWeight"] * f_neu, NEU)
	add("On Hips", V["onHipsCoughWeight"] * f_pos, POS)
	add("In Air", V["inAirCoughWeight"] * f_neu, NEU)
	add("Holding Stomach", V["holdingStomachCoughWeight"] * f_neu, NEU)


func eye_hit() -> void:
	add("On His Waist", V["onHisWaistCumEyeWeight"] * f_neu, NEU)
	add("In Face", V["inFaceCumEyeWeight"] * f_neu, NEU)


func fill_mouth() -> void:
	if g.her.held:
		add("Hand Job", V["handJobCumThroatWeight"] * f_neg, NEG)
		add("In Air", V["inAirCumThroatWeight"] * f_neu, NEU)
		add("On His Ass", V["onHisAssCumThroatWeight"] * f_pos, POS)
	else:
		add("Hand Job", V["handJobCumMouthWeight"] * f_pos, POS)
	add("Holding Stomach", V["holdingStomachCumThroatWeight"] * f_neu, NEU)


func ejaculate() -> void:
	var her: Her = g.her
	if her.mouthFull:
		add("Holding Hand", V["holdingHandCumInsideInitWeight"] * f_pos * _hand(), POS)
		add("Cupping Balls", V["cuppingBallsCumInsideInitWeight"] * f_pos, POS)
		if not her.held:
			add("Hand Job", V["handJobCumMouthInitWeight"] * f_pos, POS)
	add("On His Waist", V["onHisWaistCummingInitWeight"] * f_neg, NEG)
	add("Masturbating", V["masturbatingCummingInitWeight"] * f_pos * _mas(), POS)


func pleasure() -> void:
	add("Masturbating", V["masturbatingPleasureWeight"] * f_pos * _mas(), POS)


## Before she wakes (the mod's wakeUpPre): with wakeArmTransitionFix her arms wake loose and travel back to where
## they were; dynamic arms may keep them loose a while (delayArmsOnWake).
func before_wake() -> void:
	var her: Her = g.her
	if x.restrained:
		return
	var keep_hand: bool = x._right_name() == "In His Hand" and not x.hold_released
	_wake_pos = [-1, -1]
	if V["wakeArmTransitionFix"] == 1:
		_wake_pos[0] = her.currentLeftArmPosition
		her.currentLeftArmPosition = 4
		if not keep_hand:
			_wake_pos[1] = her.currentRightArmPosition
			her.currentRightArmPosition = 4
	if mode != 0 and randf() <= V["delayArmsOnWakeChance"] + (1.0 - V["delayArmsOnWakeChance"]) * exh("delayArmsOnWakeChance"):
		post_wake = int((randf() * (V["delayArmsOnWakeMaxTime"] - V["delayArmsOnWakeMinTime"]) + V["delayArmsOnWakeMinTime"])
			* (1.0 + exh("delayArmsOnWakeTime")))
		if mode != 3:
			her.currentLeftArmPosition = 4
		if mode != 2 and not keep_hand:
			her.currentRightArmPosition = 4


## After she woke (wakeUpPost): arms that dynamic arms doesn't move go back to where they were; the wake weights
func after_wake() -> void:
	if not x.restrained:
		if _wake_pos[0] >= 0 and not on(true):
			x.transition(true, Her.armPositions[_wake_pos[0]], true)
		if _wake_pos[1] >= 0 and not on(false):
			x.transition(false, Her.armPositions[_wake_pos[1]], true)
	_wake_pos = [-1, -1]
	add("On Legs", V["onLegsWakeWeight"] * f_neu, NEU)
	add("On His Legs", V["onHisLegsWakeWeight"] * f_neg, NEG)
	add("Cupping Breast", V["cuppingBreastWakeWeight"] * f_neu, NEU)
	add("On Neck", V["onNeckWakeWeight"] * f_neu, NEU)
	add("In Air", V["inAirWakeWeight"] * f_neu, NEU)
	add("Masturbating", V["masturbatingWakeWeight"] * f_pos * _mas(), POS)


# ---------------------------------------------------------------- character code

## The mod's armOverhaul field: "mode,restrained type" or, with a custom mood, those and the mood's 32 values
func code() -> String:
	var s := "%d,%d" % [mode, x.restrained_type]
	if _custom_mood != "":
		for k in x.mood_keys:
			s += "," + str(custom[k])
	return s


func load_code(v: String) -> void:
	var parts := v.split(",")
	if parts.size() >= 1 and parts[0].is_valid_int():
		mode = clampi(int(parts[0]), 0, 3)
	if parts.size() >= 2 and parts[1].is_valid_int():
		x.set_restrained(clampi(int(parts[1]), 0, 3), false)
	_custom_mood = ""
	if parts.size() == 34:
		custom = {}
		for i in x.mood_keys.size():
			custom[x.mood_keys[i]] = float(parts[i + 2])
		_custom_mood = "*"


func clear_custom() -> void:
	_custom_mood = ""
