class_name Her
extends FlashMovieClip
## Port of obj.Her: the female character. Drives head position / tilt from the controls, mouth, eyes, breathing,
## coughing, swallowing, drool and arm IK, and keeps the separate layers (hair, arms, costume) in sync.

const NORMAL_MOOD := "Normal"
const HAPPY_MOOD := "Happy"
const ANGRY_MOOD := "Angry"
const AHEGAO_MOOD := "Ahegao"
const fullUp := -40.0
const fullDown := 250.0
const range := fullDown - fullUp
## Her arm positions: the game's five, then the ones extensions add (addArmPosition), in the order they were added.
static var armPositions: Array = ["Back", "On Legs", "On His Legs", "Hand Job", "Loose"]
const GAME_ARM_POSITIONS := 5
const randomArmPositions := ["Back", "On Legs", "On His Legs", "Loose"]
const MouthShapeAH := {"name": "AH", "upperLip": 51, "lowerLip": 61, "jaw": -4.6}
const MouthShapeOO := {"name": "OO", "upperLip": 59, "lowerLip": 64, "jaw": -6.6}
const MouthShapeUH := {"name": "UH", "upperLip": 60, "lowerLip": 69, "jaw": -7}
const MouthShapeOH := {"name": "OH", "upperLip": 45, "lowerLip": 51, "jaw": -2.6}
const MouthShapeEE := {"name": "EE", "upperLip": 71, "lowerLip": 67, "jaw": -8.4}
const MouthShapeFF := {"name": "FF", "upperLip": 65, "lowerLip": 75, "jaw": -9}
const MouthShapeMM := {"name": "MM", "upperLip": 79, "lowerLip": 75, "jaw": -11.6}
const allMouthShapes := [MouthShapeAH, MouthShapeOO, MouthShapeUH, MouthShapeOH, MouthShapeEE, MouthShapeFF, MouthShapeMM]

# Timeline instances (bound by name from the Her symbol)
var earrings
var gagBack
var torsoBackCostume
var hairTop
var torso
var gagFront
var eye
var bottomLipstick
var hairMidContainer
var collarContainer
var rightEyebrow
var freckles
var tongueContainer
var leftEyebrow
var hairCostumeUnderLayer
var topLipTongue
var leftLegContainer
var blush
var head
var ear
var leftHandOverContainer
var topLipstickContainer
var torsoUnderCostume
var tears
var torsoBack
var eyewear
var hairBetweenLayer

var initialised := false
var hairBackContainer
var rightArmContainer
var rightArmEraseContainer
var rightForeArmContainer
var leftArmContainer
var leftHandOver
var backModContainer: FlashSprite
var userHasClicked: int = 0
var heldTimer: int = 0
var _tan: Tan
var _penisControl: HerPenisControl
var currentMood := "Normal"
const deepthroatDistance := 150.0
const deepthroatStartDistance := 75.0
var hiltDistance: float = 0.0
const releasedPos := -0.15
const maxPos := 1.02
const minPos := -0.25
var pos: float = 0.0
var speed: float = 0.0
var acceleration: float = 0.0
var speedFriction: float = 0.5
var moveSmoothing: float = 3.0
var mouseHeld := false
var penisOutDelay: int = 0
var lastPenisDirection: float = -1.0
var penisInMouthDist: float = 0.0
var currentPenisTipPos: float = 0.0
var mouthLength: float = 0.0
var penisTipMouthOffset: float = 0.0
var intro := true
var introStartDist: float = 80.0
var maxIntroDist: float = 0.0
var introRelaxDist: float = 15.0
var introPosToBeMoved := false
var firstDT := true
var movement: float = 0.0
var absMovement: float = 0.0
var previousMovement: float = 0.0
var lastYPos: float = NAN
var absYMovement: float = 0.0
var vigour: float = 0.0
const VIGOUR_WINCE_LEVEL := 1000
var downTravel: float = 0.0
var upTravel: float = 0.0
var HAND_JOB_HAND_WIDTH: float = 70.0
var movingHeadWithHandJob := false
var handJobDistance: float = 0.0
var doubleHandJobDistance: float = 0.0
var workingHandJobDistance: float = 0.0
var workingHandJobOffset: float = 0.0
var handJobPenisWidth: float = 100.0
var handJobHeadPadding: float = 0.0
var lastHeadPos := Vector2()
var rightHandAngleOffset: float = 0.0
var leftHandAngleOffset: float = 0.0
var torsoJointAng: float = 0.0
var torsoJointDist: float = 0.0
const minBodyScale := 0.95
const maxBodyScale := 1.075
var bodyScale: float = 1.0
var headTilt: float = 0.0
var headTiltScaling: float = 1.0
var headTiltTarget: float = 0.0
var headTiltAngle: float = 0.0
var breathingFactor: float = 0.0
var randomMotion := {"pos": 0.0, "speed": 0.0, "target": 0.0, "next": 0}
var previousPos: float = 0.0
var cheekBulgeTarget: float = 0.0
var cheekSuckTarget: float = 0.0
var suckPower: float = 0.0
var neckSkinOffset: float = 2.0
var offActionTimer: int = 0
var offActionTime: int = 9000
var noseSquashUp: LinearTween
var noseSquashDown: LinearTween
var currentNoseSquash: LinearTween
var noseSquashAmount: float = 0.0
var lastNoseSquash := false
var torsoIK: IKController
var leftLegStartPoint := Vector2()
var mHer := Transform2D.IDENTITY
var mZero := Transform2D.IDENTITY
var currentLeftArmPosition: int = 0
var currentRightArmPosition: int = 0
var leftArmFree := false
var rightArmFree := false
## A hand closed in a fist (the hand art's grip frame, no nail polish shown), set by an extension's arm position.
var leftHandClosed := false
var rightHandClosed := false
var leftIsFirstHandJobHand := false
var armsPushing := false
var armsPushPower: float = 0.0
var armsPushPowerMax: float = 40.0
var armsPushTimer: int = 0
const rightHandOnLegs := Vector2(150, 60)
const leftHandOnLegs := Vector2(140, 40)
const rightHandOnHim := Vector2(-125, 240)
const leftHandOnHim := Vector2(-125, 300)
var leftArmIK: IKController
var rightArmIK: IKController
var leftShoulderPos := Vector2()
var rightShoulderPos := Vector2()
var foreArmPos := Vector2()
var armIKOffset := Vector2()
var armIKOffsetSpeed := Vector2()
var gagged := true
var gaggedRotation: float = 6.0
var resistance := {"upper": 0.01, "boundary": 0.1, "lower": 0.0, "multiplier": 5.0}
var previousResistance: float = 0.01
var pullOff: float = 0.0
var pullOffPower := {"start": 0.001, "current": 0.0, "increase": 0.00005, "max": 0.008}
var pullingOff := true
var released := true
var coughing := false
var coughFactor: float = 0.0
var coughBuild: float = 0.0
var nextCoughTime: int = 0
var justCoughed := false
var startSwallowTimer: int = 0
var startSwallowTime: int = 30
const closedJawAngle := -12.0
const swallowTilt := -0.2
var aboveSwallowTilt := false
var jawAngleTarget: float = 0.0
## Port: his penis holds her jaw open over a closed sound while she speaks (her lips then open with the jaw).
var jawHeldOpen := false
var swallowing := false
var lipSkinOffset: int = 0
var jawBulgeTarget: int = 0
var swallowTimer: int = 0
var swallowPoint: float = 0.0
# "intensity" is deliberately absent until the first swallow (the original reads it before setting it).
var swallowSequence := {"build": 20, "swallow": 30, "relax": 40, "end": 60}
var tongue
var topTeethTween: LinearTween
var bottomTeethTween: LinearTween
var clenchTeeth := false
var clenchTeethRatio: float = 0.0
var clenchedTeethTimer: int = 0
var clenchedTeethTime: int = 0
var speaking := false
var speakStopDelay: int = 0
var targetPhoneme: Dictionary = MouthShapeUH
var phonemeDelay: int = 0
var lastUpperLipPos: int = 0
var lastLowerLipPos: int = 0
var eyeMotion := {"ang": 83.0, "target": 83.0}
var eyelidMotion := {"pos": 50.0, "shock": 0, "target": 50.0, "isClosed": false, "closedTimer": 0}
var eyePosBlink: int = 150
var eyePosWince: int = 200
var blinkTime: int = 1
var blinkTimer: int = 0
var winceTimer: int = 0
var lookChangeTimer: int = -1
var cumInEye: int = 0
var leftEyebrowNormalTween: LinearTween
var rightEyebrowNormalTween: LinearTween
var rightEyebrowAngryTween: LinearTween
var leftEyebrowAngryTween: LinearTween
## Vector.<uint> in the original: negative offsets wrap and are added with uint overflow, i.e. they subtract.
var eyebrowOffsets: Array = []
var passedOut := false
var passOutFactor: float = 0.0
var passOutMax: float = PASS_OUT_MAX   # port: the value point Her.passOutMax's result (g.resolveBreath)
const PASS_OUT_MAX := 40.0
var leftBreastController: BreastController
var rightBreastController: BreastController
var breastCostumeOn := false
var braStrapController: BraStrap
var shoulderStrapController: BraStrap
var topStrapController: BraStrap
var cumInMouth: int = 0
var maxCumInMouth: int = 40
var droolingCum := false
var startedCumDrool := false
var currentCumDrool   # Strand, or NativeStrand with the native fluid system (StrandControl)
var cumDroolTimer: int = 0
var cumDrool: int = 0
var cumDroolNum: int = 0
var cumDroolLinkFreq: int = 4
var droolingSpit := false
var startedSpitDrool := false
var currentSpitDrool   # Strand or NativeStrand
var spitDroolTimer: int = 0
var spitDroolLinkFreq: int = 8
var gagDroolTimer: int = 0
var wetGenerate: float = 0.0
var fullCumInMouth: int = 25
var minNostrilSpray: int = 5
var nostrilSpraying := false
var nostrilSprayToggle := false
var currentNostrilSpray   # Strand or NativeStrand
var mouthFull := false
var held := false
var hilt := false
var justHilt := false
var downPlayed := false
var upPlayed := false
var breatheDelay: int = 0
var breatheDelayTime: int = 10
var breathing := true
var topLipA := Vector2(141, -60)
var topLipB := Vector2(121, -52)
var midMouth := Vector2(122, -28)
var bottomLipA := Vector2(138, 74)
var bottomLipB := Vector2(146, 33)
var offBottomLip := Vector2(144, 68)
var eyelidEnd := Vector2(84, -115)
var eyelidStart := Vector2(41, -136)
var nostril := Vector2(135, 68)
var armConnection := Vector2(-7, -221)
var hairLimits: Array = [-0.5, -1.0, 0.5]
var eyeAim := Vector2(16, -138)
var hisFace := Vector2(800, -270)
var eyesDown := Vector2(800, 160)
var eyesUnfocused := Vector2(900, 0)
var currentLookTarget := Vector2(800, -270)
var nextLookTarget := Vector2(800, -270)
## Port: the point she actually looks at this tick (currentLookTarget after the Her.lookTarget value point).
var lookPoint := Vector2(800, -270)
## Port: her eyes' shock this tick (eyelidMotion["shock"] after the Her.eyelidShock value point), and the eyelid
## frames last shown (after Her.upperEyelid / Her.lowerEyelid; frame 2 open, 150 closed, up to 200 squeezed shut).
var eyelidShock: float = 0.0
var upperLid: int = 50
var lowerLid: int = 50
var blankEyed := false


func _init() -> void:
	super()
	backModContainer = FlashSprite.new()
	previousResistance = resistance["upper"]
	leftBreastController = BreastController.new(torsoBack.leftBreast, torsoBackCostume.breastCostume)
	rightBreastController = BreastController.new(torso.midLayer.rightBreast, torso.breastCostume, torso.topContainer.breastTop)
	torso.back.mask = torso.backMask
	backModContainer.flash_name = "backModContainer"
	backModContainer.name = "backModContainer"
	backModContainer.x = torso.back.x
	backModContainer.y = torso.back.y
	backModContainer.rotation_degrees = torso.back.rotation_degrees
	torso.addChildAt(backModContainer, torso.getChildIndex(torso.back) + 1)
	leftEyebrowNormalTween = LinearTween.new(leftEyebrow)
	rightEyebrowNormalTween = LinearTween.new(rightEyebrow, eye.eyebrowMask)
	leftEyebrowAngryTween = LinearTween.new(leftEyebrow)
	rightEyebrowAngryTween = LinearTween.new(rightEyebrow, eye.eyebrowMask)
	leftEyebrowAngryTween.skewStart(-4.2, -71.9, 0.627, 0.997)
	leftEyebrowAngryTween.offsetStart(1, -2.25)
	leftEyebrowAngryTween.skewEnd(0, -63.4, 1, 0.557)
	leftEyebrowAngryTween.offsetEnd(-2.25, 15.25)
	rightEyebrowAngryTween.offsetStart(0, 0, 26)
	rightEyebrowAngryTween.offsetEnd(14, 8, 38)
	topTeethTween = LinearTween.new(head.teeth)
	topTeethTween.offsetEnd(-8.2, 13.44)
	bottomTeethTween = LinearTween.new(head.jaw.teeth)
	bottomTeethTween.offsetEnd(5.1, -8.2)
	noseSquashUp = LinearTween.new(head.face.nose, head.headTan.face.nose)
	noseSquashUp.skewEnd(2.9, -11.6, 0.762, 1.041)
	noseSquashUp.offsetEnd(1.75, 2)
	noseSquashDown = LinearTween.new(head.face.nose, head.headTan.face.nose)
	noseSquashDown.skewEnd(-2, 11.5, 0.712, 1.02)
	noseSquashDown.offsetEnd(3.5, 2)
	currentNoseSquash = noseSquashUp
	x = fullUp
	y = 275
	tongue = tongueContainer.tongue
	torsoIK = IKController.new(self, torso, torso.leg, torso.rightCalfContainer.calf)
	updateKneeTarget()
	torsoIK.rescale(bodyScale)
	leftLegStartPoint = Vector2(leftLegContainer.leg.x, leftLegContainer.leg.y)
	# port fix: the lower eyelid's mascara drawn under the eyeball (in Flash it is in eye.lowerEyelid.mascaraContainer,
	# over the eyeball): the game clears what would show on the eyeball as her eye opens, but moremoods redraws it
	# for a raised lower eyelid, and part of it then lay on the white of her eye. Same place, just below the ball.
	var lowerMascara := FlashSprite.new()
	lowerMascara.flash_name = "lowerEyelidMascara"
	lowerMascara.transform = eye.lowerEyelid.transform * eye.lowerEyelid.mascaraContainer.transform
	eye.addChildAt(lowerMascara, 0)
	tears.addLowerEyelidMascaraLayer(lowerMascara)
	g.hairUnderLayer = hairMidContainer.hairUnderLayer
	g.hairBetweenLayer = hairBetweenLayer
	g.hairUnder = hairMidContainer.hairUnder
	g.hairBottom = hairMidContainer.hairBottom
	g.hairCostumeUnder = hairCostumeUnderLayer
	g.characterControl.addBreastSizeChangeListener(breastSizeChanged)
	g.characterControl.braControl.registerListener(breastCostumeChanged)
	g.characterControl.topControl.registerListener(breastCostumeChanged)
	braStrapController = BraStrap.new(torso.braStrap, torso.breastCostume.bra, "strapPoint", g.characterControl.braControl)
	shoulderStrapController = BraStrap.new(torso.shoulderStrap, torso.breastCostume.bra, "shoulderStrapPoint", g.characterControl.braControl)
	topStrapController = BraStrap.new(torso.topContainer.topStrap, torso.topContainer.breastTop, "strapPoint", g.characterControl.topControl)
	torso.nipplePiercing.setLimit(20)
	torso.leftNipplePiercing.setLimit(20)
	torso.chestCostume.bellyPiercing.setLimit(30)
	head.face.gotoAndStop("Normal")
	head.headTan.face.gotoAndStop("Normal")
	EventBus.addListener("penisTipPosChanged", updatePenisTipPos)


func getDataString() -> String:
	return _penisControl.getDataString()


func loadDataPairs(pairs: Array) -> void:
	_penisControl.loadDataPairs(pairs)


func updatePenisTipPos() -> void:
	currentPenisTipPos = g.animationControl.estimateTipPos()


func updateKneeTarget() -> void:
	torsoIK.newTarget(g.animationControl.getHerKneeTarget(), g.sceneLayer, true)


func setupTan() -> void:
	_tan = Tan.new()


func setMenu(menu, items: Array) -> void:
	_penisControl = HerPenisControl.new()
	_penisControl.setMenu(menu, items)


func initialise() -> void:
	setIntroResistance(g.defaultResistance)
	startIntro()
	hisPenisSizeChanged(g.him.currentPenisLength)
	updatePenisTipPos()
	initialised = true


func giveArmContainers(left, right, rightFore, rightErase, leftHand) -> void:
	rightArmContainer = right
	rightArmEraseContainer = rightErase
	rightForeArmContainer = rightFore
	leftArmContainer = left
	leftHandOver = leftHand
	leftHandOver.visible = false
	rightArmContainer.blendMode = "layer"
	rightArmEraseContainer.visible = false
	leftArmIK = IKController.new(torso, leftArmContainer.upperArm, leftArmContainer.upperArm.foreArm, leftArmContainer.upperArm.foreArm.hand)
	rightArmIK = IKController.new(torso, rightArmContainer.upperArm, rightForeArmContainer.upperArm.foreArm, rightForeArmContainer.upperArm.foreArm.hand)
	leftArmIK.rescale(0.95)
	leftShoulderPos = Vector2(leftArmContainer.upperArm.x, leftArmContainer.upperArm.y)
	rightShoulderPos = Vector2(rightArmContainer.upperArm.x, rightArmContainer.upperArm.y)
	foreArmPos = Vector2(rightForeArmContainer.upperArm.foreArm.x, rightForeArmContainer.upperArm.foreArm.y)
	setLeftArmPosition(currentLeftArmPosition)
	setRightArmPosition(currentRightArmPosition)


func getPositionLength(p) -> float:
	return p.x * p.x + p.y * p.y


func mousePressed(_e: FlashEvent = null) -> void:
	mouseHeld = true


func movementHeld() -> void:
	if not mouthFull and not g.shiftDown:
		g.setPenisOut(true)


func mouseReleased(_e: FlashEvent) -> void:
	movementRelease()


func movementRelease() -> void:
	penisOutDelay = 0
	if mouseHeld:
		mouseHeld = false
	if movingHeadWithHandJob:
		movingHeadWithHandJob = false


func activeHold(fromUser: bool = true) -> void:
	if mouthFull:
		pullOff /= 2.0
	if clenchTeeth:
		clenchedTeethTimer += 25
	if held:
		if fromUser:
			userHasClicked += 1
			if userHasClicked >= 3:
				g.clickPrompt.fadeOut()
		g.dialogueControl.buildState(Dialogue.HELD, Dialogue.TICK_BUILD)


var bodySize: float:
	get:
		return (bodyScale - minBodyScale) / (maxBodyScale - minBodyScale)


func setDefaultBodyScale() -> void:
	bodyScale = 1.0
	setBodyScale(bodyScale)


func setBodyScaleFromSlider(v: float) -> void:
	bodyScale = minBodyScale + v * (maxBodyScale - minBodyScale)
	setBodyScale(bodyScale)


func setBodyScale(v) -> void:
	bodyScale = maxf(minBodyScale, minf(maxBodyScale, float(v)))
	var s := 1.0 + (bodyScale - 1.0) * 0.5
	head.neck.scaleX = s
	head.neck.scaleY = s
	collarContainer.scaleX = s
	collarContainer.scaleY = s
	torsoIK.rescale(bodyScale)
	updateTorso()
	updateArms()
	updateNeck()


func setLipSkinOffset(v: int) -> void:
	lipSkinOffset = v


func setSpeaking(v: bool) -> void:
	if v:
		g.automaticControl.dialogueStarting()
		tongue.startFastIn()
		clenchTeeth = false
		changeLookTarget(hisFace, 0, 1)
		if not speaking:
			# port fix: a line starts from her mouth as it is. The game kept the previous line's last mouth shape (often
			# MM, closed) as the target with no delay, so her mouth snapped to it until the line's first sound came.
			targetPhoneme = {"name": "", "upperLip": lastUpperLipPos, "lowerLip": lastLowerLipPos,
				"jaw": head.jaw.rotation_degrees}
			phonemeDelay = 0
	elif speaking:
		speakStopDelay = 3
	speaking = v
	if Hooks.has(&"Her.setSpeaking"):   # HOOK
		Hooks.after(&"Her.setSpeaking", self, [v])


func isSpeaking() -> bool:
	return speaking


func canSpeak() -> bool:
	if Hooks.has(&"Her.canSpeak"):   # HOOK
		var h := Hooks.before(&"Her.canSpeak", self, [])
		if h.cancelled:
			return bool(h.result)
	return not gagged and not speaking and not mouthFull and not passedOut and not swallowing and not clenchTeeth


var teethClenched: bool:
	get:
		return clenchTeeth


func setTargetPhoneme(word: Dictionary, delay: int = 0) -> void:
	if Hooks.has(&"Her.setTargetPhoneme"):   # HOOK
		var h := Hooks.before(&"Her.setTargetPhoneme", self, [word, delay])
		if h.cancelled:
			return
	if word.get("phoneme"):
		targetPhoneme = word["phoneme"]
		phonemeDelay = delay
		if g.tongue and word.get("sayL") and not tongue.tongueOut and topLipTongue.currentFrameLabel == "Hidden":
			topLipTongue.gotoAndPlay("SayL")


func findLeftArmPosition(n: String) -> void:
	for i in armPositions.size():
		if g.dataName(armPositions[i]) == g.dataName(n):
			setLeftArmPosition(i)
			break


func findRightArmPosition(n: String) -> void:
	for i in armPositions.size():
		if g.dataName(armPositions[i]) == g.dataName(n):
			setRightArmPosition(i)
			break


func setArmPosition(p: int = -1, update: bool = true) -> void:
	setLeftArmPosition(p, update)
	setRightArmPosition(p, update)


func setRandomArmPosition() -> void:
	if armPositions[currentLeftArmPosition] != "Hand Job":
		setLeftArmPosition(int(floor(randf() * (randomArmPositions.size() - 1))), true)
	if armPositions[currentRightArmPosition] != "Hand Job":
		setRightArmPosition(int(floor(randf() * (randomArmPositions.size() - 1))), true)


# ---------------------------------------------------------------- arm positions added by extensions

## name -> {"left": Callable(her) or null, "right": Callable(her) or null, "tap": bool, "owner": String}
static var _extraArms: Dictionary = {}


## Adds an arm position to the end of the list (Her > Left arm / Right arm, the "arms:" field of the character code,
## dialogue arm triggers by name). left / right set her arm up when she takes the position, called with her
## (leftArmIK.newTarget, setEndRotationTarget, layers, leftHandClosed...); an empty Callable leaves the position out of
## that arm's list. spec: "tap" (false: that hand doesn't tap him while she's held), "slip" (ticks the arm takes to
## drop when she passes out, from where it is; default 15), "pass_out" (Callable(her, left: bool) run instead of the
## drop). Returns its index; a name already added is replaced in place.
static func addArmPosition(n: String, left: Callable, right: Callable, owner := "", spec := {}) -> int:
	var i := armPositions.find(n)
	if i < 0:
		armPositions.append(n)
		i = armPositions.size() - 1
	elif i < GAME_ARM_POSITIONS:
		push_error("Her.addArmPosition: %s is one of the game's positions" % n)
		return i
	_extraArms[n] = {"left": left if left.is_valid() else null, "right": right if right.is_valid() else null,
		"tap": spec.get("tap", true), "slip": float(spec.get("slip", 15.0)), "pass_out": spec.get("pass_out", Callable()),
		"owner": owner}
	return i


## Takes out the positions an extension added; an arm in one of them goes behind her back.
static func removeArmPositions(owner: String) -> void:
	var her: Her = g.her if g else null
	var left_name: String = armPositions[her.currentLeftArmPosition] if her else ""
	var right_name: String = armPositions[her.currentRightArmPosition] if her else ""
	for n in _extraArms.keys():
		if _extraArms[n]["owner"] == owner:
			_extraArms.erase(n)
			armPositions.erase(n)
	if her:
		her.currentLeftArmPosition = maxi(0, armPositions.find(left_name))
		her.currentRightArmPosition = maxi(0, armPositions.find(right_name))
		her.setLeftArmPosition()
		her.setRightArmPosition()


## Whether that arm can take position i (extension positions can be for one arm only).
static func armPositionAllowed(i: int, left: bool) -> bool:
	if i < GAME_ARM_POSITIONS:
		return i >= 0
	if i >= armPositions.size():
		return false
	return _extraArms[armPositions[i]]["left" if left else "right"] != null


## The positions that arm can take, in list order (the new menu's Left arm / Right arm lists).
static func armPositionsFor(left: bool) -> Array:
	var out := []
	for i in armPositions.size():
		if armPositionAllowed(i, left):
			out.append(armPositions[i])
	return out


## The next position that arm can take from `from` in direction dir (+1 / -1), or `from` at the end of the list.
static func stepArmPosition(from: int, dir: int, left: bool) -> int:
	var i := from + dir
	while i >= 0 and i < armPositions.size():
		if armPositionAllowed(i, left):
			return i
		i += dir
	return from


func _setUpExtraArm(p: int, left: bool) -> void:
	if p < GAME_ARM_POSITIONS or p >= armPositions.size():
		return
	var fn = _extraArms[armPositions[p]]["left" if left else "right"]
	if fn != null:
		fn.call(self)


## She passed out with that arm in an extension position: it drops from where it is (or the position's own pass_out).
func _dropExtraArm(p: int, left: bool) -> bool:
	if p < GAME_ARM_POSITIONS or p >= armPositions.size():
		return false
	var spec: Dictionary = _extraArms[armPositions[p]]
	if spec["pass_out"].is_valid():
		spec["pass_out"].call(self, left)
	elif left:
		leftArmIK.startDropping(spec["slip"])
		g.changeLayer(leftHandOver, g.backLayer)
	else:
		rightArmIK.startDropping(spec["slip"])
	return true


func _armCanTap(p: int) -> bool:
	return p < GAME_ARM_POSITIONS or p >= armPositions.size() or _extraArms[armPositions[p]]["tap"]


func setLeftArmPosition(p: int = -1, update: bool = true) -> void:
	if p == -1:
		p = currentLeftArmPosition
	leftHandOver.visible = false
	leftArmIK.reversedEnd = false
	leftHandClosed = false
	match p:
		1:
			g.changeLayer(leftArmContainer, self, leftLegContainer)
			leftArmIK.stopDropping()
			leftArmIK.newTarget(leftHandOnLegs, leftLegContainer.leg, true)
			leftArmIK.setEndRotationTarget(-50, [g.her.torso.leg, g.her.torso])
		2:
			g.changeLayer(leftArmContainer, g.backLayer)
			leftArmIK.stopDropping()
			leftArmIK.newTarget(leftHandOnHim, g.him.rightLeg, true)
			leftArmIK.setEndRotationTarget(-170, [g.him.rightLeg])
		3:
			g.changeLayer(leftArmContainer, g.backLayer)
			if g.penisOut:
				g.frontLayer.addChildAt(leftHandOver, g.frontLayer.getChildIndex(g.himOverLayer))
			else:
				g.changeLayer(leftHandOver, leftHandOverContainer)
			leftArmIK.stopDropping()
			leftHandOver.visible = true
			update = true
		4:
			if currentLeftArmPosition != 4:
				leftArmIK.newTarget(leftHandOnLegs, leftLegContainer.leg, false)
				leftArmIK.setEndRotationTarget(-50, [g.her.torso.leg, g.her.torso])
			startArmsPassOut(true, false)
		_:
			_setUpExtraArm(p, true)
	currentLeftArmPosition = p
	checkHandJobMode()
	if passedOut:
		startArmsPassOut()
	if update:
		setLeftArmFree(currentLeftArmPosition > 0)
		updateTorso()
		updateArms()
	if _tan:
		_tan.updateSkin()
	g.characterControl.setNailPolish(g.characterControl.nailPolishRGB)


func setRightArmPosition(p: int = -1, update: bool = true) -> void:
	if p == -1:
		p = currentRightArmPosition
	rightArmIK.reversedEnd = false
	rightHandClosed = false
	match p:
		1:
			rightArmIK.stopDropping()
			rightArmIK.newTarget(rightHandOnLegs, torso.leg, true)
			rightArmIK.setEndRotationTarget(-50, [g.her.torso.leg, g.her.torso, g.her])
		2:
			rightArmIK.stopDropping()
			rightArmIK.newTarget(rightHandOnHim, g.him.leftLeg, true)
			rightArmIK.setEndRotationTarget(-170, [g.him.leftLeg])
		3:
			rightArmIK.stopDropping()
			update = true
		4:
			if currentRightArmPosition != 4:
				rightArmIK.newTarget(rightHandOnLegs, torso.leg, false)
				rightArmIK.setEndRotationTarget(-50, [g.her.torso.leg, g.her.torso, g.her])
			startArmsPassOut(false, true)
		_:
			_setUpExtraArm(p, false)
	currentRightArmPosition = p
	checkHandJobMode()
	if passedOut:
		startArmsPassOut()
	if update:
		setRightArmFree(currentRightArmPosition > 0)
		updateTorso()
		updateArms()
	if _tan:
		_tan.updateSkin()
	g.characterControl.setNailPolish(g.characterControl.nailPolishRGB)


func setLeftArmFree(v: bool) -> void:
	leftArmFree = v
	leftArmContainer.upperArm.visible = leftArmFree
	leftArmContainer.upperArmCostume.visible = leftArmFree
	torso.cuffs.visible = not leftArmFree
	torso.nailPolish.visible = not leftArmFree
	torso.leftGlove.visible = not leftArmFree
	torso.midLayer.leftArm.visible = not leftArmFree
	g.characterControl.setArmSkin()
	g.characterControl.armwearControl.resetElement()


func setRightArmFree(v: bool) -> void:
	rightArmFree = v
	if rightArmFree:
		updateArms()
	else:
		rightArmContainer.upperArm.rotation_degrees = 53
		rightArmContainer.upperArmCostume.rotation_degrees = 53
		rightArmContainer.upperArmMask.rotation_degrees = 53
	rightForeArmContainer.upperArm.foreArm.visible = rightArmFree
	rightForeArmContainer.upperArmCostume.foreArmCostume.visible = rightArmFree
	torso.rightGlove.visible = not rightArmFree
	torso.behindBackRightArm.visible = not rightArmFree
	g.characterControl.setArmSkin()
	g.characterControl.armwearControl.resetElement()


func checkHandJobMode() -> void:
	leftIsFirstHandJobHand = g.leftHandJobMode
	g.leftHandJobMode = armPositions[currentLeftArmPosition] == "Hand Job"
	g.rightHandJobMode = armPositions[currentRightArmPosition] == "Hand Job"
	if g.leftHandJobMode or g.rightHandJobMode:
		g.soundControl.startRub()
		handJobHeadPadding = 0.4 if g.leftHandJobMode and g.rightHandJobMode else 0.25
	else:
		g.soundControl.stopRub()
	rightArmEraseContainer.visible = g.rightHandJobMode


func isRightArmFree() -> bool:
	return rightArmFree


func isLeftArmFree() -> bool:
	return leftArmFree


func setMood(m: String) -> void:
	if Hooks.has(&"Her.setMood"):   # HOOK (moremoods-style extended moods take over here)
		var h := Hooks.before(&"Her.setMood", self, [m])
		if h.cancelled:
			return
		m = h.args[0]
	currentMood = m
	head.face.gotoAndStop(m)
	head.headTan.face.gotoAndStop(m)
	topLipstickContainer.gotoAndStop(m)
	updateLips()
	updateEyes()
	g.characterControl.setLipFills()
	if currentMood == AHEGAO_MOOD:
		tongue.hangOut()
	else:
		tongue.stopHangingOut()
	if currentMood != ANGRY_MOOD:
		clenchTeeth = false
	Moods.vanilla_mood_set(m)   # HOOK port extension: shared mood for extensions (src/ext/moods.gd)


func setGagged(v: bool) -> void:
	gagged = v
	if gagged:
		head.jaw.rotation_degrees = gaggedRotation
		head.jawBack.rotation_degrees = gaggedRotation
		head.headTan.jaw.rotation_degrees = gaggedRotation
		head.headTan.jawBack.rotation_degrees = gaggedRotation
		updateLips()
		randomGagDroolTimer()


func isGagged() -> bool:
	return gagged


func tongueToggled() -> void:
	if g.tongue:
		tongue.startMovingTongue("out")
	else:
		tongue.startMovingTongue("in")


func throatBulgeChanged() -> void:
	head.neck.throatBulge = g.throatBulgeAmount
	updateNeck()


func breathingToggled() -> void:
	if not g.breathing and breathing:
		breathing = g.soundControl.stopBreathing()
	elif not breathing:
		g.setBreathTo(0)
		checkBreathing(true)


func breastCostumeChanged(_n: String = "") -> void:
	breastCostumeOn = not (g.characterControl.braControl.selectedName == "None" and g.characterControl.topControl.selectedName == "None")
	var braOn: bool = g.characterControl.braControl.selectedName != "None"
	torsoBack.leftBreast.nipple.visible = not braOn
	torso.midLayer.rightBreast.nipple.visible = not braOn
	torso.nipplePiercing.visible = not braOn
	torso.leftNipplePiercing.visible = not braOn
	updateBreastFirmness()
	if Hooks.has(&"Her.breastCostumeChanged"):   # HOOK
		Hooks.after(&"Her.breastCostumeChanged", self, [])


func startIntro() -> void:
	if passedOut:
		wakeUp()
	pullingOff = true
	firstDT = true
	intro = true
	maxIntroDist = introStartDist
	g.automaticControl.resetSelfMode()
	g.dialogueControl.reset()


func setHandsFree() -> void:
	pullingOff = true


func setIntroResistance(v: float) -> void:
	introRelaxDist = maxf(0.25, 25.0 - v * 0.25)
	g.introResistance = v


func setThroatResistance(v: float) -> void:
	resistance["boundary"] = maxf(0.0, minf(100.0, v)) * 0.002
	g.throatResistance = v
	if Hooks.has(&"Her.setThroatResistance"):   # HOOK
		Hooks.after(&"Her.setThroatResistance", self, [v])


func setFreckleAmount(v: float) -> void:
	freckles.setFreckleAmount(v)


func giveHairBackContainer(c) -> void:
	hairBackContainer = c


func clearMascara() -> void:
	tears.clearMascara()


func clearTearSpots() -> void:
	tears.clearTearSpots()


func isInMouth() -> bool:
	return mouthFull


func isActingOff() -> bool:
	return speaking or tongue.block() or (swallowing and not mouthFull)


func isReleased() -> bool:
	if Hooks.has(&"Her.isReleased"):   # HOOK
		var h := Hooks.before(&"Her.isReleased", self, [])
		if h.cancelled:
			return h.result
	return pullingOff or released


func getHeadTilt() -> float:
	return headTilt


func getPenisMouthOffset() -> float:
	return penisTipMouthOffset - mouthLength * 0.5


func getPenisMouthDist() -> float:
	return penisInMouthDist


func hisPenisSizeChanged(length: float) -> void:
	hiltDistance = length - 25.0
	handJobDistance = g.him.currentPenisFullLength
	doubleHandJobDistance = handJobDistance - HAND_JOB_HAND_WIDTH / g.him.penisLengthScale
	if initialised:
		updateElements()
		updateArms()


func getPenisTiltInterp() -> float:
	if gagged:
		if penisInMouthDist > 100:
			return 1.0
		if penisInMouthDist < 0:
			return 0.0
		return penisInMouthDist * 0.01
	if penisInMouthDist > 25:
		return 1.0
	if penisInMouthDist < -25:
		return 0.0
	return (penisInMouthDist + 25.0) * 0.02


func pushPenisTilt() -> float:
	var push: float = tongue.getPush()
	var tip: Vector2 = tongue.localToGlobal(tongue.tip)
	if g.him.penis.hitTestPoint(tip.x, tip.y, true):
		if tongue.touched():
			if randf() > 0.8:
				generateTongueStrand()
			g.dialogueControl.buildState(Dialogue.LICK_PENIS, Dialogue.ONE_OFF_BUILD)
	if g.him.balls.hitTestPoint(tip.x, tip.y, true):
		tongue.touched()
		g.him.balls.pushBalls(-1 * push, push * 20)
		g.dialogueControl.buildState(Dialogue.LICK_BALLS, Dialogue.FRAME_BUILD)
	var tiltPush := 0.0
	if g.penisOut and penisInMouthDist > 0:
		tiltPush = (headTilt - 0.5) * (0.2 + absMovement * 0.01)
	var handPush: float = -g.currentHandJobPos.y * 1.2 if g.handJobMode and not passedOut else 0.0
	return push + tiltPush + handPush


func ejaculating() -> void:
	if Hooks.has(&"Her.ejaculating"):   # HOOK
		var h := Hooks.before(&"Her.ejaculating", self, [])
		if h.cancelled:
			return
	shock(10)
	if randf() > 0.5:
		changeLookTarget(eyesDown, 5, 5)
		if currentMood == ANGRY_MOOD and not mouthFull:
			startClenchingTeeth()
	if held and randf() > 0.5 and aboveSwallowTilt:
		swallow()
	if Hooks.has(&"Her.ejaculating"):   # HOOK
		Hooks.after(&"Her.ejaculating", self)


func suck() -> void:
	suckPower += 0.3


func shock(amount: int) -> void:
	if Hooks.has(&"Her.shock"):   # HOOK
		var h := Hooks.before(&"Her.shock", self, [amount])
		if h.cancelled:
			return
		amount = h.args[0]
	eyelidMotion["shock"] = amount
	if randf() > 0.5:
		blink(false)


func cumOnFace() -> void:
	g.dialogueControl.buildState(Dialogue.CUM_ON_FACE, Dialogue.TICK_BUILD * 2)
	if currentMood == HAPPY_MOOD or currentMood == AHEGAO_MOOD:
		# Reads 'intensity' which is undefined before the first swallow in the original (-> NaN).
		wetGenerate += float(swallowSequence.get("intensity", NAN)) * 10.0
	if Hooks.has(&"Her.cumOnFace"):   # HOOK
		Hooks.after(&"Her.cumOnFace", self)


func eyeHit() -> void:
	cumInEye += 1
	closeEye()
	if Hooks.has(&"Her.eyeHit"):   # HOOK
		Hooks.after(&"Her.eyeHit", self)


func eyeClearHit() -> void:
	if cumInEye > 0:
		cumInEye -= 1
		if cumInEye == 0:
			openEye()


func closeEye() -> void:
	eyelidMotion["pos"] = eyePosBlink + 20
	eyelidMotion["isClosed"] = true
	eyelidMotion["closedTimer"] = 0
	lookChangeTimer = -1


func openEye() -> void:
	if Hooks.has(&"Her.openEye"):   # HOOK
		var h := Hooks.before(&"Her.openEye", self, [])
		if h.cancelled:
			eyelidMotion["closedTimer"] = 0   # vetoed: the 40 s check that opens a closed eye starts over (no retry every tick)
			return
	eyelidMotion["isClosed"] = false


func getArmPoint() -> Vector2:
	return localToGlobal(armConnection)


func debugMove(p: Vector2) -> void:
	x = p.x
	y = p.y
	mHer = transform
	updateElements()


func debugRotate(r: float) -> void:
	rotation_degrees = r
	mHer = transform
	updateElements()


func move(targetPos: float, tilt: float) -> float:
	g.animationControl.update()
	updateBlink()
	Sweat.staticTick()
	if randf() < g.breathLevel / g.breathLevelMax and randf() > 0.9:
		if randf() > 0.5:
			Sweat.spawn(head, Vector2(21, -65), Vector2(150, 100), [rightArmContainer.upperArm, torso.back, torso.midLayer.chest, torso.midLayer.rightBreast.hitArea, torso.leg])
		else:
			Sweat.spawn(torso.back, Vector2(110, -230), Vector2(320, 100), [torso.midLayer.chest, torso.midLayer.rightBreast.hitArea, torso.leg])
	if mouseHeld:
		if not g.penisOut and not g.handJobMode:
			if penisOutDelay < 5:
				penisOutDelay += 1
			else:
				movementHeld()
		if g.handJobMode:
			movingHeadWithHandJob = true
	if g.penisOut or movingHeadWithHandJob:
		if tilt > 0.8:
			g.dialogueControl.buildState(Dialogue.PULLED_DOWN, Dialogue.FRAME_BUILD)
		elif tilt < -0.8:
			g.dialogueControl.buildState(Dialogue.PULLED_UP, Dialogue.FRAME_BUILD)
	if movingHeadWithHandJob or g.autoModeOn:
		lastHeadPos.x = g.currentMousePos.x
		lastHeadPos.y = g.currentMousePos.y
		if not g.penisOut:
			if g.leftHandJobMode and g.rightHandJobMode:
				lastHeadPos.x = minf(0.8, lastHeadPos.x)
			else:
				lastHeadPos.x = minf(0.9, lastHeadPos.x)
	if not movingHeadWithHandJob or g.autoModeOn:
		g.targetHandJobPos.x = targetPos / 1.2
		g.targetHandJobPos.y = tilt - maxf(-0.3, minf(0.3, rightHandAngleOffset * 0.05))
	if g.handJobMode:
		targetPos = lastHeadPos.x
		tilt = lastHeadPos.y
	if pullingOff and not passedOut and not g.handsOff:
		if released:
			acceleration = (releasedPos - pos) / moveSmoothing
		else:
			acceleration = (releasedPos - pos) / 5.0
		if targetPos < pos + 0.3 and not g.handsOff:
			pullingOff = false
			if released:
				released = false
				g.soundControl.playGrab()
				g.dialogueControl.buildState(Dialogue.HEAD_GRABBED, Dialogue.ONE_OFF_BUILD)
			g.him.closeHand()
	else:
		acceleration = (targetPos - pos) / moveSmoothing
	speed += acceleration
	if not passedOut:
		if penisInMouthDist > 0 and acceleration > 0:
			var res := previousResistance
			if Hooks.has_value(&"Her.resistance"):   # HOOK value point: what holds him back as he pushes in (checkPosition's)
				res = Hooks.value(&"Her.resistance", self, res)
			speed -= res + armsPushPower * 0.001
		if not g.handsOff:
			speed -= pullOff
	elif Hooks.has_value(&"Her.limpResistance") and penisInMouthDist > 0 and acceleration > 0:   # HOOK value point: what holds him back while she is passed out (the game: nothing)
		speed -= Hooks.value(&"Her.limpResistance", self, 0.0)
	speed *= speedFriction
	var push := 0.0
	if Hooks.has_value(&"Her.pushBack"):   # HOOK value point: pushes her head back off him (0 in the game; before the clamp)
		push = Hooks.value(&"Her.pushBack", self, 0.0)
	pos = maxf(minPos, minf(maxPos, pos + speed - push))
	if intro and not g.penisOut:
		pos -= maxf(0.0, (penisInMouthDist - maxIntroDist) * 0.0015)
	if not mouthFull and clenchTeeth and not g.penisOut and not gagged:
		if penisInMouthDist > 0:
			clenchedTeethTimer = maxi(0, clenchedTeethTimer - 1)
		elif pos < 0.1:
			clenchedTeethTimer += 1
		pos -= maxf(0.0, penisInMouthDist + 25.0) * 0.002
		pos = minf(currentPenisTipPos - 0.05, pos)
	var result := pos
	generateSpit()
	movement = pos * range - previousPos * range
	absMovement = movement if movement > 0 else -movement
	vigour += absMovement * 0.2 if g.penisOut else absMovement
	vigour = minf(1050.0, maxf(0.0, vigour - 20.0))
	if currentMood == HAPPY_MOOD or currentMood == AHEGAO_MOOD:
		if movement < 0 and not passedOut:
			suck()
		wetGenerate += vigour * (0.02 if currentMood == AHEGAO_MOOD else 0.01)
		if wetGenerate > 500.0 + randf() * 300.0:
			generateWetness()
	if vigour > VIGOUR_WINCE_LEVEL:
		wince()
	if vigour > 600:
		g.dialogueControl.buildState(Dialogue.VIGOROUS, Dialogue.FRAME_BUILD)
	if released and not g.handsOff and not g.handJobMode:
		headTiltTarget = 0
	else:
		headTiltTarget = tilt * headTiltScaling
		if g.penisOut:
			headTiltScaling = maxf(0.0, minf(1.0, 1.0 - pos * 1.25 * (1.0 - g.animationControl.penisOutTransition)))
		else:
			headTiltScaling = maxf(0.0, minf(1.0, 1.0 - pos * 1.25))
	tickSwallowing()
	headTilt += (headTiltTarget - headTilt) * 0.25
	if tilt < swallowTilt:
		if not aboveSwallowTilt:
			aboveSwallowTilt = true
			if randf() > 0.2:
				changeLookTarget(hisFace)
	elif aboveSwallowTilt:
		aboveSwallowTilt = false
	updatePosition()
	checkMovementSounds()
	checkBreathing()
	checkPosition()
	animateBreathing()
	updateElements()
	tongue.update(pos, movement, absMovement, vigour)
	_penisControl.update()
	if droolingCum:
		tickCumDrool()
	if nostrilSpraying:
		tickNostrilSpray()
	if gagged or currentMood == AHEGAO_MOOD:
		if gagDroolTimer > 0:
			gagDroolTimer -= 1
		else:
			randomSpitDrool()
			randomGagDroolTimer()
	if droolingSpit:
		tickSpitDrool()
	if userHasClicked < 3 and held:
		heldTimer += 1
	if g.smearLipstick and mouthFull and absMovement > 10:
		g.him.smearLipstick(pos, absMovement)
	if g.coughing:
		tickCoughBuild()
	if held:
		if randf() + 0.97 < g.breathLevel / g.breathLevelMax:
			tapHands()
	if armPositions[currentLeftArmPosition] == "On Him" or armPositions[currentRightArmPosition] == "On Him":
		slipHands()
	if armsPushing:
		if armsPushTimer > 0:
			armsPushTimer -= 1
			if armsPushPower < armsPushPowerMax:
				armsPushPower = minf(armsPushPower + 4.0, armsPushPowerMax)
		else:
			armsPushing = false
	elif armsPushPower > 0:
		armsPushPower *= 0.8
		if armsPushPower < 0.05:
			armsPushPower = 0
	tears.tick(rotation_degrees)
	if g.penisOut and g.smudging:
		var tipPoint: Vector2 = g.him.getPenisTipPoint(45, -8)
		tears.smudge(tipPoint)
		g.strandControl.smearStrands(tipPoint, 25)
		g.clearSmudgeCache()
	previousMovement = movement
	previousPos = pos
	updateHairLimits()
	return result


func updateHairLimits() -> void:
	hairLimits[0] = -pos * 0.6
	hairLimits[1] = -pos * 1.2
	hairLimits[2] = 1.0 - pos


func passOut() -> void:
	if Hooks.has(&"Her.passOut"):   # HOOK
		var h := Hooks.before(&"Her.passOut", self, [])
		if h.cancelled:
			if not passedOut and passOutFactor >= passOutMax:   # vetoed (not replaced): she stays on the edge and
				passOutFactor = passOutMax - 7.5                 # animateBreathing tries again in 150 ticks, not every tick
			return
	passOutFactor = passOutMax
	g.soundControl.playPassOut(pos)
	passedOut = true
	startArmsPassOut()
	if Hooks.has(&"Her.passOut"):   # HOOK
		Hooks.after(&"Her.passOut", self)


func startArmsPassOut(left: bool = true, right: bool = true) -> void:
	if Hooks.has(&"Her.startArmsPassOut"):   # HOOK
		var h := Hooks.before(&"Her.startArmsPassOut", self, [left, right])
		if h.cancelled:
			return
		left = h.args[0]
		right = h.args[1]
	if left and _dropExtraArm(currentLeftArmPosition, true):
		left = false
	if right and _dropExtraArm(currentRightArmPosition, false):
		right = false
	if left:
		if armPositions[currentLeftArmPosition] == "On Legs":
			leftArmIK.startDropping(5)
		elif armPositions[currentLeftArmPosition] == "On His Legs":
			leftArmIK.startDropping(15)
		else:
			leftArmIK.newTarget(leftHandOnLegs, leftLegContainer.leg, false)
			leftArmIK.setEndRotationTarget(-50, [g.her.torso.leg, g.her.torso])
			leftArmIK.startDropping(15)
		g.changeLayer(leftArmContainer, g.backLayer)
		g.changeLayer(leftHandOver, g.backLayer)
	if right:
		if armPositions[currentRightArmPosition] == "On Legs":
			rightArmIK.startDropping(5)
		elif armPositions[currentRightArmPosition] == "On His Legs":
			rightArmIK.startDropping(15)
		else:
			rightArmIK.newTarget(rightHandOnLegs, torso.leg, false)
			rightArmIK.setEndRotationTarget(-50, [g.her.torso.leg, g.her.torso, g.her])
			rightArmIK.startDropping(15)


func wakeUp() -> void:
	if Hooks.has(&"Her.wakeUp"):   # HOOK
		var h := Hooks.before(&"Her.wakeUp", self, [])
		if h.cancelled:
			if passedOut and passOutFactor <= 0:   # vetoed (not replaced): animateBreathing tries again in 80 ticks
				passOutFactor = passOutMax
			return
	shock(85)
	eyeMotion["ang"] = 20.0
	g.dialogueControl.clearStates()
	g.dialogueControl.buildState(Dialogue.WAKE, Dialogue.ONE_OFF_BUILD)
	passedOut = false
	g.addBreath(g.outOfBreathPoint)
	if g.breathing:
		breathing = g.soundControl.startBreathing(true)
	setLeftArmPosition(currentLeftArmPosition, false)
	setRightArmPosition(currentRightArmPosition, false)
	if armPositions[currentLeftArmPosition] != "Loose":
		var p: Vector2 = leftArmContainer.upperArm.foreArm.hand.localToGlobal(Vector2())
		leftArmIK.jumpTo(p)
		leftArmIK.startTrackingTarget(true)
	if armPositions[currentRightArmPosition] != "Loose":
		var p: Vector2 = rightForeArmContainer.upperArm.foreArm.hand.localToGlobal(Vector2())
		rightArmIK.jumpTo(p)
		rightArmIK.startTrackingTarget(true)
	if Hooks.has(&"Her.wakeUp"):   # HOOK
		Hooks.after(&"Her.wakeUp", self)


func updateBlink() -> void:
	if blinkTime > 0:
		blinkTime -= 1
	else:
		blink()


func blink(lookAround: bool = true) -> void:
	if Hooks.has(&"Her.blink"):   # HOOK
		var h := Hooks.before(&"Her.blink", self, [lookAround])
		if h.cancelled:
			blinkTime = int(floor(randf() * 60 + 90))   # vetoed: the next try after a normal wait, not every tick
			return
		lookAround = h.args[0]
	if randf() > 0.8:
		blinkTime = int(floor(randf() * 5 + 5))
	else:
		blinkTime = int(floor(randf() * 60 + 90))
	blinkTimer = 2
	tears.releaseTears()
	if lookAround:
		if randf() > 0.5:
			if randf() > 0.5:
				changeLookTarget(hisFace, 5, 0)
			else:
				changeLookTarget(eyesDown, 5, 0)
	if Hooks.has(&"Her.blink"):   # HOOK
		Hooks.after(&"Her.blink", self)


func wince() -> void:
	if Hooks.has(&"Her.wince"):   # HOOK
		var h := Hooks.before(&"Her.wince", self, [])
		if h.cancelled:
			return
	winceTimer = 5
	tears.drawLowerEyelidMascara()
	tears.releaseTears()


func waggleEyebrows() -> void:
	if Hooks.has(&"Her.waggleEyebrows"):   # HOOK
		var h := Hooks.before(&"Her.waggleEyebrows", self, [])
		if h.cancelled:
			return
	changeLookTarget(hisFace, 0, 1)
	for i in 24:
		eyebrowOffsets.append(int(-10.0 * (pow(4.0, cos(i * PI / 6.0 - 1.8)) - cos(i * PI / 6.0))))
	if Hooks.has(&"Her.waggleEyebrows"):   # HOOK
		Hooks.after(&"Her.waggleEyebrows", self)


func startClenchingTeeth() -> void:
	if Hooks.has(&"Her.startClenchingTeeth"):   # HOOK
		var h := Hooks.before(&"Her.startClenchingTeeth", self, [])
		if h.cancelled:
			return
	if not clenchTeeth and not gagged and not mouthFull:
		clenchTeeth = true
		clenchedTeethTime = int(randf() * 120 + 60)
		if Hooks.has_value(&"Her.clenchTime"):   # HOOK value point: how long she keeps them clenched, ticks (the game: 60..179)
			clenchedTeethTime = int(Hooks.value(&"Her.clenchTime", self, clenchedTeethTime))
		clenchedTeethTimer = 0
		tongue.startFastIn()
		if not Hooks.has_value(&"Her.clenchTaps") or Hooks.value(&"Her.clenchTaps", self, true):   # HOOK value point: she taps him as she clenches (true in the game)
			tapHands(3)


## Port: she unclenches her teeth now. The game has no call for it: the clench ends when its time is up, when she
## speaks or her mood changes; the teeth then open over a few ticks (updateLips).
func releaseTeeth() -> void:
	if Hooks.has(&"Her.releaseTeeth"):   # HOOK
		var h := Hooks.before(&"Her.releaseTeeth", self, [])
		if h.cancelled:
			return
	clenchTeeth = false
	if Hooks.has(&"Her.releaseTeeth"):   # HOOK
		Hooks.after(&"Her.releaseTeeth", self, [])


func lookUp() -> void:
	changeLookTarget(hisFace, 0, 1)


func lookDown() -> void:
	changeLookTarget(eyesDown, 0, 1)


func tapHands(extra: float = 0.0) -> void:
	if Hooks.has(&"Her.tapHands"):   # HOOK
		var h := Hooks.before(&"Her.tapHands", self, [extra])
		if h.cancelled:
			return
	if not g.handJobMode:
		var power := randf() + (1.0 - passOutFactor / passOutMax) * 8.0 + extra
		if power > 2:
			if randf() > 0.2:
				if _armCanTap(currentRightArmPosition):
					rightArmIK.tap(power / 9.0)
			elif _armCanTap(currentLeftArmPosition):
				leftArmIK.tap(power / 9.0)


func pushArms() -> void:
	armsPushing = true
	armsPushPower = 0
	armsPushTimer = int(randf() * 60 + 15)


func cough() -> void:
	if Hooks.has(&"Her.cough"):   # HOOK
		var h := Hooks.before(&"Her.cough", self, [])
		if h.cancelled:
			if nextCoughTime <= 0:   # vetoed, and the handler set no time of its own: wait as after a cough
				nextCoughTime = int(floor(randf() * 210)) + 30
			return
	if g.coughing:
		nextCoughTime = int(floor(randf() * 210)) + 30
		coughing = true
		coughFactor = randf() * 1.5 + 0.5
		head.cheekBulge.alpha = 1
		tears.addTearSpot()
		generateSplat(5, 10)
		leftBreastController.accelerate(0.1)
		rightBreastController.accelerate(0.1)
		wince()
		g.soundControl.playCough()
		justCoughed = true
	if Hooks.has(&"Her.cough"):   # HOOK
		Hooks.after(&"Her.cough", self)


func openCough() -> void:
	if Hooks.has(&"Her.openCough"):   # HOOK
		var h := Hooks.before(&"Her.openCough", self, [])
		if h.cancelled:
			return
	if g.coughing:
		coughing = true
		coughFactor = randf() + 0.25
		head.cheekBulge.alpha = minf(1.0, head.cheekBulge.alpha + 0.3)
		tears.addTearSpot()
		generateSplat(15, 5, 1, cumInMouth > 0)
		leftBreastController.accelerate(0.1)
		rightBreastController.accelerate(0.1)
		wince()
		justCoughed = true
	if Hooks.has(&"Her.openCough"):   # HOOK
		Hooks.after(&"Her.openCough", self)


func swallow(intensity: float = 0.0, speak: bool = true) -> void:
	if Hooks.has(&"Her.swallow"):   # HOOK
		var h := Hooks.before(&"Her.swallow", self, [intensity, speak])
		if h.cancelled:
			startSwallowTimer = 0   # vetoed: the wait with cum in her mouth starts over (no retry every tick)
			return
		intensity = h.args[0]
		speak = h.args[1]
	var started := false   # for the after hook (a request while she swallows, speaks or is out is dropped)
	if not swallowing and not passedOut and not speaking:
		started = true
		if intensity <= 0.5:
			swallowSequence["intensity"] = randf() * 0.3 + 0.5 * (float(cumInMouth) / maxCumInMouth) + 0.4
		else:
			swallowSequence["intensity"] = intensity
		var si: float = swallowSequence["intensity"]
		swallowSequence["build"] = Maths.round(30 * si)
		swallowSequence["swallow"] = Maths.round(swallowSequence["build"] + 16 * si)
		swallowSequence["relax"] = Maths.round(swallowSequence["swallow"] + 16 * si)
		swallowSequence["end"] = Maths.round(swallowSequence["relax"] + 30 * si)
		if Hooks.has_value(&"Her.swallowSpeed"):   # HOOK value point: how fast the swallow plays (1 in the game)
			var sp: float = maxf(0.1, Hooks.value(&"Her.swallowSpeed", self, 1.0))
			var last := 0.0
			for k in ["build", "swallow", "relax", "end"]:
				last = maxf(last + 1.0, Maths.round(swallowSequence[k] / sp))
				swallowSequence[k] = last
		swallowTimer = 0
		startSwallowTime = int(floor(randf() * 60 + 50))
		startSwallowTimer = 0
		g.addBreath(2)
		breathing = g.soundControl.stopBreathing()
		if cumInMouth > 0 and speak:
			g.dialogueControl.buildState(Dialogue.SWALLOW, Dialogue.ONE_OFF_BUILD)
		if currentMood == HAPPY_MOOD or currentMood == AHEGAO_MOOD:
			wetGenerate += si * 100
		coughBuild += si * 10
		swallowing = true
	if Hooks.has(&"Her.swallow"):   # HOOK: result = whether the swallow started
		Hooks.after(&"Her.swallow", self, [intensity, speak], started)


func checkMovementSounds() -> void:
	if Hooks.has(&"Her.checkMovementSounds"):   # HOOK
		var h := Hooks.before(&"Her.checkMovementSounds", self, [])
		if h.cancelled:
			return
	var lipB: Vector2 = globalToLocal(head.jaw.localToGlobal(bottomLipA))
	var mouthVec := Vector2(lipB.x - topLipA.x, lipB.y - topLipA.y)
	var tip: Vector2 = globalToLocal(g.him.getPenisTipPoint())
	var tipVec := Vector2(tip.x - topLipA.x, tip.y - topLipA.y)
	var crossV := Maths.cross(mouthVec, tipVec)
	var inside := crossV > 0
	var entering := false
	var dotV := Maths.pointDot(topLipA, lipB, tip)
	var lenSq := mouthVec.x * mouthVec.x + mouthVec.y * mouthVec.y
	penisTipMouthOffset = dotV / sqrt(lenSq)
	var t := dotV / lenSq
	var proj := Vector2(topLipA.x + mouthVec.x * t, topLipA.y + mouthVec.y * t)
	mouthLength = Maths.vectorLength(mouthVec)
	if lastPenisDirection < 0 and crossV > 0:
		lastPenisDirection = 1
		if penisTipMouthOffset > -5 and penisTipMouthOffset < mouthLength + 5:
			entering = true
	penisInMouthDist = lastPenisDirection * Maths.vectorLength(Vector2(tip.x - proj.x, tip.y - proj.y))
	if inside:
		if not mouthFull and not g.penisOut:
			if (swallowing and not gagged) or not entering or clenchTeeth:
				g.setPenisOut(true)
			else:
				tongue.setMouthFull()
				changeLookTarget(eyesDown)
				mouthFull = true
				g.dialogueControl.interrupt()
				breathing = g.soundControl.stopBreathing()
				g.soundControl.playTouch()
				if droolingCum:
					stopDroolingCum()
		if not g.penisOut:
			for i in 4:
				updateNoseSquash()
			if movement > 0:
				downTravel += movement
				upTravel = 0
				upPlayed = false
				if downTravel > 50 and not downPlayed:
					if not passedOut and absMovement > 30 and penisInMouthDist > deepthroatStartDistance and not intro:
						if g.gagging:
							g.soundControl.playGag(pos)
						wince()
						downPlayed = true
					elif absMovement > 10:
						g.soundControl.playDown(pos, movement)
						downPlayed = true
			else:
				upTravel -= movement
				downTravel = 0
				downPlayed = false
				if absMovement > 10 and upTravel > 50 and not upPlayed:
					g.soundControl.playUp(pos, movement)
					generateRandomStrand("random")
					upPlayed = true
	else:
		if lastPenisDirection > 0 and crossV < 0:
			lastPenisDirection = -1
		if g.penisOut and (not mouseHeld or g.handJobMode):
			g.setPenisOut(false)
		if mouthFull:
			changeLookTarget(hisFace)
			tongue.setMouthFull(false)
			mouthFull = false
			var n := int(floor(randf() * 3))
			while n < 3:
				generateRandomStrand("back", false)
				n += 1
			if headTilt > 0:
				startDroolingCum()
			breatheDelay = 0
			offActionTime = int(floor(randf() * 300)) + 60
			offActionTimer = 0
			if currentMood == ANGRY_MOOD and vigour > VIGOUR_WINCE_LEVEL and randf() > 0.5:
				startClenchingTeeth()
			g.dialogueControl.readyToSpeak()
		offActionTimer += 1
		if offActionTimer >= offActionTime:
			if currentMood == HAPPY_MOOD:
				waggleEyebrows()
			elif currentMood == ANGRY_MOOD:
				startClenchingTeeth()
			offActionTime = int(floor(randf() * 300)) + 150
			offActionTimer = 0
	if Hooks.has(&"Her.checkMovementSounds"):   # HOOK
		Hooks.after(&"Her.checkMovementSounds", self)


func updateNoseSquash() -> void:
	var tipP: Vector2 = head.face.nose.localToGlobal(Vector2(head.face.nose.tip.x, head.face.nose.tip.y))
	var touching: bool = g.him.overLayer.hitTestPoint(tipP.x, tipP.y, true) or g.him.hitTestPoint(tipP.x, tipP.y, true)
	if touching:
		noseSquashAmount = minf(1.0, noseSquashAmount + 0.1)
	elif noseSquashAmount > 0:
		noseSquashAmount = maxf(0.0, noseSquashAmount - 0.1)
	currentNoseSquash.tween(noseSquashAmount)


func checkBreathing(force: bool = false) -> void:
	# port fix (sby's vanillapausedbreathpatch): she does not build up breath while the game is paused
	if not mouthFull and not breathing and not swallowing and not g.gamePaused:
		breatheDelay += 1
		if (force or breatheDelay >= breatheDelayTime) and g.breathing:
			breathing = g.soundControl.startBreathing()


func stopBreathing() -> void:
	breathing = g.soundControl.stopBreathing()


func checkPosition() -> void:
	if g.penisOut:
		previousResistance = 0
	else:
		previousResistance = resistance["upper"] * (pos - currentPenisTipPos) * 5.0
	if penisInMouthDist > 0:
		if not g.penisOut:
			g.him.givePleasure(movement)
			g.dialogueControl.movement(movement)
		if intro and not g.penisOut:
			if penisInMouthDist >= maxIntroDist - 13:
				g.dialogueControl.buildState(Dialogue.RESISTANCE, Dialogue.FRAME_BUILD)
				if not introPosToBeMoved:
					introPosToBeMoved = true
		if penisInMouthDist > deepthroatDistance and not g.penisOut:
			if not held:
				g.soundControl.startHolding()
				nextCoughTime = int(floor(randf() * 210)) + 30
				tears.addTearSpot()
				if not g.autoModeOn and userHasClicked < 3 and heldTimer > 150:
					g.clickPrompt.fadeIn()
				coughBuild += randf() * 2.0
				if intro:
					g.dialogueControl.buildState(Dialogue.FIRST_THROAT, Dialogue.ONE_OFF_BUILD * 2)
				held = true
			if firstDT:
				coughBuild += 0.2
				g.setBreathTo(g.outOfBreathPoint)
				wince()
			previousResistance = resistance["lower"]
			g.addBreath(0.1)
			pullOff = minf(1.0, pullOff + pullOffPower["current"])
			pullOffPower["current"] = minf(pullOffPower["max"], pullOffPower["current"] + pullOffPower["increase"])
			g.dialogueControl.buildState(Dialogue.PULL_OFF, Dialogue.FRAME_BUILD)
		else:
			if not g.penisOut:
				if penisInMouthDist >= deepthroatStartDistance:
					previousResistance = resistance["upper"] + resistance["boundary"] * (penisInMouthDist - deepthroatStartDistance) / (deepthroatDistance - deepthroatStartDistance)
				else:
					g.addBreath(-0.05)
			if held:
				g.soundControl.stopHolding()
				pullOff = 0
				pullOffPower["current"] = pullOffPower["start"]
				if not passedOut and not g.handsOff and not g.penisOut and g.currentPos.x > pos:
					pullingOff = true
					g.him.openHand()
				g.clickPrompt.fadeOut()
				held = false
		if penisInMouthDist >= hiltDistance or pos > 1:
			if g.penisOut:
				tongue.encourage()
			else:
				g.him.givePleasure(randf() * 5.0 + 5.0)
				if not hilt:
					g.sceneLayer.shake(movement)
					tears.addTearSpot()
					hilt = true
					justHilt = true
					coughBuild += 2
				if firstDT:
					coughBuild += 6
					firstDT = false
					g.dialogueControl.maxState(Dialogue.FIRST_DT)
				coughBuild += 0.1
		elif hilt:
			hilt = false
	else:
		if intro and introPosToBeMoved:
			maxIntroDist += introRelaxDist
			if maxIntroDist >= deepthroatDistance or maxIntroDist > hiltDistance - 50:
				intro = false
			introPosToBeMoved = false
		if pullingOff:
			released = true
	if held and not passedOut:
		if nextCoughTime > 0:
			if not swallowing:
				nextCoughTime -= 1
		else:
			cough()
		pos += randf() * 0.01 - 0.005
	if Hooks.has(&"Her.checkPosition"):   # HOOK
		Hooks.after(&"Her.checkPosition", self, [])


func animateBreathing() -> void:
	if breathing:
		var depth: float = 0.5 if passedOut else maxf(0.5, minf(2.0, g.breathLevel / g.outOfBreathPoint * 2.0))
		breathingFactor = sin(g.soundControl.breathPosition() * PI * 2.0) * depth
		pos += breathingFactor * 0.00625
		if g.soundControl.justBreathedOut() and g.herMouthOpeness > 0.4:
			var mist := BreathMist.new()
			var p: Vector2 = g.sceneLayer.globalToLocal(localToGlobal(midMouth))
			mist.x = p.x
			mist.y = p.y
			g.backLayer.addChild(mist)
		if passOutFactor > 0:
			passOutFactor = maxf(0.0, passOutFactor - 0.5)
		elif passedOut:
			wakeUp()
	else:
		if g.breathLevel == g.breathLevelMax and passOutFactor < passOutMax:
			passOutFactor += 0.05
			if not blankEyed and currentLookTarget != eyesDown and passOutFactor > 5:
				currentLookTarget = eyesDown
				lookChangeTimer = -1
			if not passedOut and passOutFactor >= passOutMax:
				passOut()
		breathingFactor *= 0.8
		pos += getRandomMotion()
	breathingFactor += coughFactor * 0.8
	if Hooks.has(&"Her.animateBreathing"):   # HOOK
		Hooks.after(&"Her.animateBreathing", self, [])


func tickCoughBuild() -> void:
	coughBuild = maxf(0.0, coughBuild - 0.05)
	if coughBuild >= 10:
		coughBuild -= 10
		g.soundControl.queueOpenCough()


func updatePosition() -> void:
	headTiltAngle = headTilt * 10.0 + (coughFactor * 2.5 + tongue.getHeadTilt()) * headTiltScaling
	mHer = g.animationControl.getHerMatrix(pos, headTilt)
	mHer = mHer.translated(Vector2(coughFactor * 3.0 * headTiltScaling, coughFactor * headTiltScaling))
	mHer = g.rotateMatrix(mHer, Maths.degToRad(headTiltAngle))
	mHer.origin.x -= maxf(-5.0, 20.0 * headTilt)
	if is_nan(lastYPos):
		lastYPos = mHer.origin.y
	absYMovement = mHer.origin.y - lastYPos
	lastYPos = mHer.origin.y
	transform = mHer


func updateElements() -> void:
	if Hooks.has(&"Her.updateElements"):   # HOOK
		var h := Hooks.before(&"Her.updateElements", self, [])
		if h.cancelled:
			return
	updateTorso()
	updateNeck()
	if g.characterControl.collarControl.selection == 2:
		if collarContainer.collar.tie:
			collarContainer.collar.tie.rotation_degrees = 6.0 - 6.0 * pos
	hairBackContainer.hairBack.transform = mHer
	g.hairCostumeBack.transform = mHer
	g.hairTop.transform = mHer
	g.hairCostumeOver.transform = mHer
	g.hairCostumeUnderOver.transform = mHer
	var sceneOrigin: Vector2 = globalToLocal(g.sceneLayer.localToGlobal(Vector2()))
	mZero = Transform2D(-rotation_degrees / 180.0 * PI, sceneOrigin)
	hairMidContainer.hairUnderLayer.transform = mZero
	hairBetweenLayer.transform = mZero
	var penisWidth: float = g.him.getPenisWidth(localToGlobal(topLipA), head.jaw.localToGlobal(bottomLipA), mouthFull)
	var sinA := (penisWidth - 20.0) / 2.0 / 165.0
	var openAng := asin(sinA) / 1.2 / 0.5
	var fullJaw := Maths.radToDeg(openAng) - 11.0
	if speaking or speakStopDelay > 0:
		jawAngleTarget = targetPhoneme["jaw"]
		# port fix: with his penis in her mouth her jaw doesn't close tighter than its width (the game shut it around
		# him on a closed sound mid-line); it opens as fast as when she isn't speaking
		jawHeldOpen = penisInMouthDist > 0 and not g.penisOut and jawAngleTarget < fullJaw
		if jawHeldOpen:
			jawAngleTarget = fullJaw
			head.jaw.rotation_degrees += (jawAngleTarget - head.jaw.rotation_degrees) * 0.8
		else:
			head.jaw.rotation_degrees += (jawAngleTarget - head.jaw.rotation_degrees) / (phonemeDelay + 1)
	elif swallowing:
		if swallowTimer < swallowSequence["relax"]:
			if penisInMouthDist > 0 and mouthFull:
				jawAngleTarget = fullJaw
			else:
				jawAngleTarget = closedJawAngle
			if swallowTimer == swallowSequence["swallow"]:
				gulp()   # port: the swallow's moment, split out for its own hook point
		elif swallowTimer >= swallowSequence["end"]:
			swallowing = false
			swallowTimer = 0
			if cumInMouth > 10 and aboveSwallowTilt and penisInMouthDist < 0 and randf() > 0.4:
				swallow()
			elif not mouthFull:
				if g.breathing:
					if g.coughing and coughBuild > 5:
						breathing = g.soundControl.startBreathingWithCough()
					else:
						breathing = g.soundControl.startBreathing()
			if cumInMouth == 0 and randf() > 0.2:
				changeLookTarget(hisFace)
		elif penisInMouthDist > 0 and not g.penisOut:
			jawAngleTarget = fullJaw
		else:
			jawAngleTarget = getJawAngle(0.8)
		head.jaw.rotation_degrees += (jawAngleTarget - head.jaw.rotation_degrees) * 0.5
	else:
		if penisInMouthDist > 0 and not g.penisOut:
			jawAngleTarget = fullJaw
		else:
			jawAngleTarget = maxf(-6.0, -2.5 - 2.0 * pos * 10.0)
		if penisInMouthDist < 0:
			var away := minf(0.8, minf(100.0, -penisInMouthDist) / 50.0)
			if cumInMouth > 0:
				jawAngleTarget = minf(jawAngleTarget, getJawAngle(maxf(0.0, -headTilt), away))
			else:
				jawAngleTarget = minf(jawAngleTarget, getJawAngle(maxf(0.0, -headTilt), minf(0.5, away)))
			head.jaw.rotation_degrees += (jawAngleTarget - head.jaw.rotation_degrees) * 0.25
			if cumInMouth > 0 and aboveSwallowTilt and not passedOut:
				startSwallowTimer += 1
				if startSwallowTimer >= startSwallowTime:
					swallow()
			else:
				startSwallowTimer = 0
		else:
			if cumInMouth > 0 and aboveSwallowTilt and not passedOut:
				startSwallowTimer += 1
				if startSwallowTimer >= startSwallowTime:
					swallow()
			else:
				startSwallowTimer = 0
			head.jaw.rotation_degrees += (jawAngleTarget - head.jaw.rotation_degrees) * 0.8
	if currentMood == ANGRY_MOOD or clenchTeethRatio > 0:
		head.jaw.rotation_degrees += (-6.5 - head.jaw.rotation_degrees) * clenchTeethRatio
	if gagged:
		head.jaw.rotation_degrees = gaggedRotation
	if Hooks.has_value(&"Her.jawAngle"):   # HOOK value point: her jaw's angle this tick (closedJawAngle: closed, higher: open)
		head.jaw.rotation_degrees = Hooks.value(&"Her.jawAngle", self, head.jaw.rotation_degrees)
	head.jawBack.rotation_degrees = head.jaw.rotation_degrees
	head.headTan.jaw.rotation_degrees = head.jaw.rotation_degrees
	head.headTan.jawBack.rotation_degrees = head.jaw.rotation_degrees
	g.herMouthOpeness = maxf(0.0, minf(1.0, 1.0 - head.jaw.rotation_degrees / closedJawAngle))
	updateLips()
	if g.herMouthOpeness < 0.2:
		if droolingCum:
			stopDroolingCum()
	elif not droolingCum and not mouthFull and headTilt > 0:
		startDroolingCum()
	head.cheekMask.gotoAndStop(int(floor(minf(144.0, maxf(1.0, (head.jaw.rotation_degrees + 12.0) * 8.0)))))
	leftBreastController.update(-movement / range * 0.2 - absYMovement * 0.002, breathingFactor * 1.25 - 1.0, -4.0 - breathingFactor * 3.125, breathingFactor * 1.75)
	rightBreastController.update(-movement / range * 0.2 - absYMovement * 0.002, breathingFactor * 1.25, -3.0 - breathingFactor * 4.375, breathingFactor * 1.75)
	braStrapController.update()
	shoulderStrapController.update()
	topStrapController.update()
	updateNipplePiercing()
	updateBreathingScaledElements()
	torsoBack.chestBack.rotation_degrees = 27.0 + breathingFactor * 2.6
	if mouthFull:
		cheekBulgeTarget = minf(1.0, maxf(0.0, movement) / 20.0 + cumInMouth / 20.0 + pos / 2.0)
		cheekSuckTarget = minf(1.0, maxf(0.0, -movement) / 20.0 + suckPower)
	else:
		cheekBulgeTarget = 0
		cheekSuckTarget = 0
	suckPower *= 0.7
	if hilt:
		cheekBulgeTarget += 0.5
	head.cheekBulge.alpha += (cheekBulgeTarget - head.cheekBulge.alpha) / 5.0
	head.cheekSuck.alpha += (cheekSuckTarget - head.cheekSuck.alpha) / 5.0
	if lookChangeTimer > 0:
		lookChangeTimer -= 1
	elif lookChangeTimer == 0:
		currentLookTarget = nextLookTarget
		lookChangeTimer = -1
	lookPoint = currentLookTarget
	if Hooks.has_value(&"Her.lookTarget"):   # HOOK value point: where she looks
		lookPoint = Hooks.value(&"Her.lookTarget", self, lookPoint)
	lookAt(lookPoint)
	if eyelidMotion["shock"] > 0:
		if Hooks.has_value(&"Her.shockFade"):   # HOOK value point: how much her eyes' shock eases this tick (1)
			eyelidMotion["shock"] = maxf(0.0, eyelidMotion["shock"] - Hooks.value(&"Her.shockFade", self, 1.0))
		else:
			eyelidMotion["shock"] -= 1
	eyelidShock = eyelidMotion["shock"]
	if Hooks.has_value(&"Her.eyelidShock"):   # HOOK value point: how shocked her eyes are (wider, smaller iris)
		eyelidShock = Hooks.value(&"Her.eyelidShock", self, eyelidShock)
	if winceTimer > 0:
		winceTimer -= 1
		eyelidMotion["pos"] += (eyePosWince - eyelidMotion["pos"]) * 0.75
	elif blinkTimer > 0:
		blinkTimer -= 1
		eyelidMotion["pos"] = eyePosBlink
	elif eyelidMotion["isClosed"] or passedOut:
		eyelidMotion["pos"] += (eyePosBlink - eyelidMotion["pos"]) * 0.25
		tears.clearLowerEyelid(200 - eyelidMotion["pos"])
		eyelidMotion["closedTimer"] += 1
		if eyelidMotion["closedTimer"] >= 1200:
			openEye()
			cumInEye = 0
	else:
		var posFrames: int = 0 if g.penisOut else int(minf(80.0, floor(pos * 80.0)))
		eyelidMotion["target"] = 101 - posFrames - eyelidShock - cumInMouth * 2 + floor(swallowPoint * 100.0)
		eyelidMotion["target"] = maxf(2.0, minf(eyePosWince, eyelidMotion["target"]))
		if passOutFactor > 0:
			eyelidMotion["target"] = minf(eyePosBlink, eyelidMotion["target"] + floor(passOutFactor * 3.0))
		if Hooks.has_value(&"Her.eyelidTarget"):   # HOOK value point: where her open eyelids head this tick
			eyelidMotion["target"] = Hooks.value(&"Her.eyelidTarget", self, eyelidMotion["target"])
		eyelidMotion["pos"] += (eyelidMotion["target"] - eyelidMotion["pos"]) * 0.2
		tears.clearLowerEyelid(200 - eyelidMotion["pos"])
	updateEyes()
	var irisScale: float = 0.9 - (0.25 - eyelidMotion["pos"] / 400.0) - eyelidShock / 200.0
	if Hooks.has_value(&"Her.irisScale"):   # HOOK value point: how big her irises are
		irisScale = Hooks.value(&"Her.irisScale", self, irisScale)
	eye.ball.irisContainer.iris.scaleX = irisScale
	eye.ball.irisContainer.iris.scaleY = irisScale
	if coughing:
		if justCoughed:
			justCoughed = false
			coughFactor *= 2.0
		else:
			coughFactor *= 0.8
			if coughFactor <= 0.01:
				coughFactor = 0
				coughing = false
	if Hooks.has(&"Her.updateElements"):   # HOOK
		Hooks.after(&"Her.updateElements", self)


func updateBreathingScaledElements() -> void:
	var s := 1.0 - breathingFactor * 0.024
	var inv := 1.0 / s
	torso.midLayer.chest.scaleX = s
	torso.chestCostume.scaleX = s
	torso.chestUnderCostume.scaleX = s
	torso.upperChestCostume.scaleX = s
	torso.topContainer.chestTop.scaleX = s
	torso.rightThighStocking.stocking.hipLayer.chestStocking.scaleX = s
	torso.rightThighStocking.stocking.hipOverLayer.chestStocking.scaleX = s
	torso.rightThighStocking.stocking2.hipLayer.chestStocking.scaleX = s
	torso.rightThighStocking.stocking.hipLayer.chestStocking.penisCostumeContainer.scaleX = inv
	torso.chestCostume.bottoms.penisCostumeContainer.scaleX = inv
	if Hooks.has(&"Her.updateBreathingScaledElements"):   # HOOK
		Hooks.after(&"Her.updateBreathingScaledElements", self, [])


func updateEyes() -> void:
	var lid := maxi(2, int(floor(eyelidMotion["pos"])))
	var brow := lid
	if eyebrowOffsets.size() > 0:
		brow += eyebrowOffsets[0]
		eyebrowOffsets.remove_at(0)
		if brow < 0:
			brow = 1 << 32  # uint wrap-around in the original: clamps to the last frame

	rightEyebrow.rightEyebrowFill.gotoAndStop(brow)
	rightEyebrow.rightEyebrowLine.gotoAndStop(brow)
	leftEyebrow.leftEyebrowFill.gotoAndStop(brow)
	leftEyebrow.leftEyebrowLine.gotoAndStop(brow)
	if currentMood == ANGRY_MOOD:
		var r := brow / 200.0
		leftEyebrowAngryTween.tween(r)
		rightEyebrowAngryTween.tween(r)
	else:
		leftEyebrowNormalTween.tween(0)
		rightEyebrowNormalTween.tween(0)
	rightEyebrow.rightEyebrowFill.gotoAndStop(brow)
	rightEyebrow.rightEyebrowLine.gotoAndStop(brow)
	leftEyebrow.leftEyebrowFill.gotoAndStop(brow)
	leftEyebrow.leftEyebrowLine.gotoAndStop(brow)
	eye.eyebrowMask.gotoAndStop(brow)
	var lookOffset := maxf(-55.0, minf(0.0, (eyeMotion["ang"] - 90.0) * 0.15 * maxf(0.0, 150.0 - lid)))
	var upper := int(floor(maxf(2.0, lid + lookOffset)))
	var lower := lid
	if currentMood == HAPPY_MOOD:
		lower = lid + int(maxf(0.0, (160 - lid) * 0.9))
	if Hooks.has_value(&"Her.upperEyelid"):   # HOOK value point: the upper eyelid's frame
		upper = int(Hooks.value(&"Her.upperEyelid", self, upper))
	upperLid = upper
	if Hooks.has_value(&"Her.lowerEyelid"):   # HOOK value point: the lower eyelid's frame (upperLid is already this tick's)
		lower = int(Hooks.value(&"Her.lowerEyelid", self, lower))
	lowerLid = lower
	eye.upperEyelid.gotoAndStop(upper)
	eye.lowerEyelid.gotoAndStop(lower)
	eye.ball.upperEyelidMask.gotoAndStop(upper)
	eye.ball.lowerEyelidMask.gotoAndStop(lower)
	eye.upperEyelid.eyeshadow.gotoAndStop(upper)
	eye.upperEyelid.mascara.gotoAndStop(upper)
	eye.lowerEyelid.mascara.gotoAndStop(lower)
	if Hooks.has(&"Her.updateEyes"):   # HOOK
		Hooks.after(&"Her.updateEyes", self)


func changeLookTarget(target: Vector2, randomDelay: int = 30, minDelay: int = 5) -> void:
	if Hooks.has(&"Her.changeLookTarget"):   # HOOK
		var h := Hooks.before(&"Her.changeLookTarget", self, [target, randomDelay, minDelay])
		if h.cancelled:
			return
		target = h.args[0]
	if passOutFactor < 5 and not eyelidMotion["isClosed"]:
		nextLookTarget = eyesUnfocused if blankEyed else target
		lookChangeTimer = int(floor(randf() * randomDelay)) + minDelay


func lookAt(target: Vector2) -> void:
	if Hooks.has(&"Her.lookAt"):   # HOOK
		var h := Hooks.before(&"Her.lookAt", self, [target])
		if h.cancelled:
			return
		target = h.args[0]
	lookPoint = target
	var local: Vector2 = globalToLocal(g.sceneLayer.localToGlobal(target))
	var d := Vector2(local.x - eyeAim.x, local.y - eyeAim.y)
	eyeMotion["target"] = minf(110.0, maxf(75.0, g.getAngle(d.x, d.y)))
	if currentMood == AHEGAO_MOOD:
		eyeMotion["target"] = 62.0 + eyelidMotion["pos"] * 0.05 + randf() * 2.0 - 1.0
	eyeMotion["target"] -= randf() * 0.5 * passOutFactor + passOutFactor * 0.5
	if Hooks.has_value(&"Her.gazeAngle"):   # HOOK value point: the iris angle she turns towards
		eyeMotion["target"] = Hooks.value(&"Her.gazeAngle", self, eyeMotion["target"])
	eyeMotion["ang"] += (eyeMotion["target"] - eyeMotion["ang"]) * 0.2
	eye.ball.irisContainer.rotation_degrees = eyeMotion["ang"] - 90.0
	if Hooks.has(&"Her.lookAt"):   # HOOK
		Hooks.after(&"Her.lookAt", self, [target])


func getJawAngle(amount: float, mult: float = 1.0) -> float:
	return amount * closedJawAngle * mult


func updateNeck() -> void:
	head.neck.render(0.0 if g.penisOut else penisInMouthDist / 400.0)
	var mult: float = 0.0 if g.penisOut else penisInMouthDist / 400.0 * g.him.getPenisWidthWithTwitch() * 0.6
	head.jaw.jawBulge.colorTransform = FlashColorTransform.tint(g.characterControl.currentSkinPalette.shade1.rgb, mult)
	var neckP: Vector2 = globalToLocal(head.localToGlobal(Vector2(head.neck.x, head.neck.y)))
	var torsoP: Vector2 = globalToLocal(torso.localToGlobal(Vector2(0, 0)))
	var ang: float = g.getAngle(torsoP.x - neckP.x, torsoP.y - neckP.y) + 180.0
	head.neck.rotation_degrees = wrapf(ang, -180.0, 180.0)   # Flash keeps rotation in -180..180 (ang reaches 367)
	collarContainer.rotation_degrees = head.neck.rotation_degrees


func updateLips() -> void:
	var upper: int = 0
	var lower: int = 0
	bottomLipstick.rotation_degrees = head.jaw.rotation_degrees
	if clenchTeeth or clenchTeethRatio > 0:
		clenchedTeethTimer += 1
		if clenchedTeethTimer >= clenchedTeethTime:
			clenchTeeth = false
		if clenchTeeth and clenchTeethRatio < 1:
			if not Hooks.has_value(&"Her.teethClosing") or Hooks.value(&"Her.teethClosing", self, true):   # HOOK value point: her teeth close further this tick (true; false holds them)
				clenchTeethRatio = minf(1.0, clenchTeethRatio + 0.2)
		elif not clenchTeeth:
			clenchTeethRatio = maxf(0.0, clenchTeethRatio - 0.3)
		topTeethTween.tween(clenchTeethRatio)
		bottomTeethTween.tween(clenchTeethRatio)
	if speaking or speakStopDelay > 0:
		upper = lastUpperLipPos + int(Maths.round(float(targetPhoneme["upperLip"] - lastUpperLipPos) / (phonemeDelay + 1)))
		lower = lastLowerLipPos + int(Maths.round(float(targetPhoneme["lowerLip"] - lastLowerLipPos) / (phonemeDelay + 1)))
		if jawHeldOpen:   # port fix (see jawHeldOpen): lips no more closed than the jaw's (higher frame: more closed)
			var open := int(minf(79.0, floor(maxf(0.0, -head.jaw.rotation_degrees * 4.5 + 30.0))))
			upper = mini(upper, open)
			lower = mini(lower, open)
		if phonemeDelay > 0:
			phonemeDelay -= 1
		if speakStopDelay > 0:
			speakStopDelay -= 1
	else:
		upper = int(minf(79.0, floor(maxf(0.0, -head.jaw.rotation_degrees * 4.5 + 30.0))))
		lower = upper
	if currentMood == ANGRY_MOOD or clenchTeethRatio > 0:
		upper = int(Maths.round(upper + (58 - upper) * clenchTeethRatio))
		lower = int(Maths.round(lower + (61 - lower) * clenchTeethRatio))
		upper = maxi(0, upper - 1)
		lower = mini(79, lower + 6)
	bottomLipstick.gotoAndStop(lower + 2)
	topLipstickContainer.topLipstick.gotoAndStop(upper + 2)
	tongueContainer.gotoAndStop(lower + 2)
	tongueContainer.rotation_degrees = head.jaw.rotation_degrees
	lastUpperLipPos = upper
	lastLowerLipPos = lower
	head.face.lipHighlight.gotoAndStop(upper)
	head.face.lipShading.gotoAndStop(upper)
	head.face.lipFill.gotoAndStop(upper)
	head.face.lipOutline.gotoAndStop(upper)
	head.headTan.face.lipFill.gotoAndStop(upper)
	head.headTan.face.lipOutline.gotoAndStop(upper)
	lower += lipSkinOffset
	head.jaw.gotoAndStop(lower)
	head.headTan.jaw.gotoAndStop(lower)
	if Hooks.has(&"Her.updateLips"):   # HOOK
		Hooks.after(&"Her.updateLips", self)


func breastSizeChanged() -> void:
	updateBreastFirmness()
	braStrapController.update()
	shoulderStrapController.update()
	topStrapController.update()
	updateNipplePiercing()


func updateBreastFirmness() -> void:
	leftBreastController.updateFirmness(g.characterControl.breastSize, breastCostumeOn)
	rightBreastController.updateFirmness(g.characterControl.breastSize, breastCostumeOn)


func findChild(n: String, c: FlashSprite) -> FlashDisplayObject:
	if c.getChildByName(n):
		return c.getChildByName(n)
	for i in c.numChildren:
		var ch := c.getChildAt(i)
		if ch is FlashSprite:
			var found := findChild(n, ch)
			if found:
				return found
	return null


func updateNipplePiercing() -> void:
	var leftN = null
	var rightN = null
	if torsoBack.leftBreast.getChildByName("leftBreast"):
		leftN = findChild("nipple", torsoBack.leftBreast.getChildByName("leftBreast"))
	if not leftN:
		if torsoBack.leftBreast.nipple.getChildByName("leftNipple"):
			leftN = torsoBack.leftBreast.nipple.getChildByName("leftNipple")
		else:
			leftN = torsoBack.leftBreast.nipple
	if torso.midLayer.rightBreast.getChildByName("rightBreast"):
		rightN = findChild("nipple", torso.midLayer.rightBreast.getChildByName("rightBreast"))
	if not rightN:
		if torso.midLayer.rightBreast.nipple.getChildByName("rightNipple"):
			rightN = torso.midLayer.rightBreast.nipple.getChildByName("rightNipple")
		else:
			rightN = torso.midLayer.rightBreast.nipple
	var lp := Vector2()
	var rp := Vector2()
	if leftN.getChildByName("piercingPoint"):
		lp = Vector2(leftN.getChildByName("piercingPoint").x, leftN.getChildByName("piercingPoint").y)
	if rightN.getChildByName("piercingPoint"):
		rp = Vector2(rightN.getChildByName("piercingPoint").x, rightN.getChildByName("piercingPoint").y)
	lp = torsoBack.globalToLocal(leftN.localToGlobal(lp))
	rp = torso.globalToLocal(rightN.localToGlobal(rp))
	torso.nipplePiercing.x = rp.x
	torso.nipplePiercing.y = rp.y
	torso.leftNipplePiercing.x = lp.x
	torso.leftNipplePiercing.y = lp.y


func updateTorso() -> void:
	var ac: AnimationControl = g.animationControl
	torsoJointAng = minf(ac.torsoMinAng, ac.torsoStartAng + pos * ac.torsoAngMultiplier - Maths.degToRad(rotation_degrees) * 0.9)
	torsoJointDist = minf(ac.torsoMinDist, ac.torsoStartDist + pos * ac.torsoDistMultiplier)
	var joint: Vector2 = g.getVector(torsoJointDist, torsoJointAng)
	torsoIK.update(joint)
	var s1: Transform2D = torsoIK.section1Matrix
	var s2: Transform2D = torsoIK.section2Matrix
	var s3: Transform2D = torsoIK.section3Matrix
	torso.transform = s1
	torsoBack.transform = s1
	leftLegContainer.transform = s1
	torsoBackCostume.transform = s1
	torsoUnderCostume.transform = s1
	var s1Global := transform * s1
	rightArmContainer.transform = s1Global
	rightForeArmContainer.transform = s1Global
	if leftArmContainer.parent == self:
		leftArmContainer.transform = s1
	else:
		leftArmContainer.transform = s1Global
	var unRotate := Transform2D(-torsoIK.section2Angle, Vector2.ZERO)
	torso.leg.transform = s2
	torso.rightThighBottoms.transform = s2
	torso.rightThighBottomsOver.transform = s2
	torso.rightCalfContainer.transform = s2
	torso.rightThighStocking.transform = s2
	torso.rightThighStocking.stocking.hipLayer.transform = unRotate
	torso.rightThighStocking.stocking2.hipLayer.transform = unRotate
	torso.rightThighStocking.stocking.hipOverLayer.transform = unRotate
	torso.rightThighStockingB.transform = s2
	torso.rightThighStockingB.stocking.hipLayer.transform = unRotate
	torso.rightThighStockingB.stocking2.hipLayer.transform = unRotate
	torso.rightThighStockingB.stocking.hipOverLayer.transform = unRotate
	torso.rightThighCostume.transform = s2
	var legM := s2
	legM.origin = Vector2.ZERO
	legM = legM.scaled(Vector2(0.95, 0.95))
	legM.origin += leftLegStartPoint
	leftLegContainer.leg.transform = legM
	torso.chestCostume.legMask.rotation_degrees = torso.leg.rotation_degrees - 27.6
	torso.rightThighCostumeMask.legMask.rotation_degrees = torso.leg.rotation_degrees
	torso.rightCalfContainer.calf.transform = s3
	torso.rightCalfContainer.calfStocking.transform = s3
	torso.rightCalfContainer.calfStockingB.transform = s3
	torso.rightCalfContainer.footwear.transform = s3
	torso.rightCalfContainer.bottoms.transform = s3
	torso.rightCalfContainer.cuffs.transform = s3
	leftLegContainer.leg.calf.transform = s3
	leftLegContainer.leg.calfStocking.transform = s3
	leftLegContainer.leg.calfStockingB.transform = s3
	leftLegContainer.leg.footwear.transform = s3
	leftLegContainer.leg.leftCalfBottoms.transform = s3
	leftLegContainer.leg.cuffs.transform = s3


func updateArms() -> void:
	if g.handJobMode and initialised:
		updateHandJobMode()
	if leftArmFree:
		leftArmIK.update()
		var l1: Transform2D = leftArmIK.section1Matrix
		var l2: Transform2D = leftArmIK.section2Matrix
		var l3: Transform2D = leftArmIK.section3Matrix
		if g.leftHandJobMode:
			workingHandJobOffset = 0
			if g.rightHandJobMode:
				workingHandJobDistance = doubleHandJobDistance
				if leftIsFirstHandJobHand:
					workingHandJobOffset = HAND_JOB_HAND_WIDTH / g.him.penisLengthScale
			else:
				workingHandJobDistance = handJobDistance
			var w: float = g.him.getPenisWidthWithTwitch()
			leftArmIK.newTarget(Vector2(-25.0 * g.him.penisLengthScale - handJobDistance + workingHandJobDistance * g.currentHandJobPos.x + workingHandJobOffset, 90.0 * bodyScale * (1.0 / w) + 40.0 - 35.0 * w), g.him.penis, true)
			leftHandAngleOffset = -(atan(leftArmIK.section3Angle) * 180.0 / PI) * 0.3
			leftArmIK.setEndRotationTarget(leftHandAngleOffset - 180.0, [g.him.penis, g.him])
		leftArmContainer.upperArm.transform = l1
		leftArmContainer.upperArmCostume.transform = l1
		leftArmContainer.upperArm.foreArm.transform = l2
		leftArmContainer.upperArmCostume.foreArmCostume.transform = l2
		leftArmContainer.upperArm.foreArm.hand.transform = l3
		leftArmContainer.upperArmCostume.foreArmCostume.handCostume.transform = leftArmContainer.upperArm.foreArm.hand.transform
		var handM := l1 * l2 * l3
		if leftHandOver.parent == leftHandOverContainer:
			handM = torso.transform * handM
		else:
			handM = leftArmContainer.transform * handM
		leftHandOver.transform = handM
	if rightArmFree:
		rightArmIK.update()
		var r1: Transform2D = rightArmIK.section1Matrix
		var r2: Transform2D = rightArmIK.section2Matrix
		var r3: Transform2D = rightArmIK.section3Matrix
		if g.rightHandJobMode:
			workingHandJobOffset = 0
			if g.leftHandJobMode:
				workingHandJobDistance = doubleHandJobDistance
				if not leftIsFirstHandJobHand:
					workingHandJobOffset = HAND_JOB_HAND_WIDTH / g.him.penisLengthScale
			else:
				workingHandJobDistance = handJobDistance
			rightArmIK.newTarget(Vector2(-25.0 * g.him.penisLengthScale - handJobDistance + workingHandJobDistance * g.currentHandJobPos.x + workingHandJobOffset, 90.0 * bodyScale * (1.0 / g.him.getPenisWidthWithTwitch())), g.him.penis, true)
			rightHandAngleOffset = -(atan(rightArmIK.section3Angle) * 180.0 / PI) * 0.3
			rightArmIK.setEndRotationTarget(rightHandAngleOffset - 180.0, [g.him.penis, g.him])
		if currentRightArmPosition == 2:
			var handAng := asin(r3.x.y)
			if handAng > 0.1:
				armIKOffsetSpeed.y += (handAng - 0.1) * 20.0
			else:
				armIKOffsetSpeed.y -= armIKOffset.y * 0.05 * maxf(0.0, -(handAng - 0.1))
			armIKOffset.y += armIKOffsetSpeed.y
			rightArmIK.newTarget(Vector2(rightHandOnHim.x, rightHandOnHim.y + armIKOffset.y), g.him.leftLeg, true)
			if currentLeftArmPosition == 2:
				leftArmIK.newTarget(leftHandOnHim, g.him.rightLeg, true)
		armIKOffsetSpeed.y *= 0.7
		rightArmEraseContainer.transform = g.him.transform.affine_inverse() * rightArmContainer.transform
		rightArmContainer.upperArm.transform = r1
		rightArmContainer.upperArmMask.transform = r1
		rightArmContainer.upperArmCostume.transform = r1
		rightArmEraseContainer.upperArm.transform = r1
		rightArmEraseContainer.upperArmCostume.transform = r1
		rightForeArmContainer.upperArm.transform = r1
		rightForeArmContainer.upperArmCostume.transform = r1
		rightForeArmContainer.upperArm.foreArm.transform = r2
		rightForeArmContainer.upperArmCostume.foreArmCostume.transform = r2
		rightForeArmContainer.upperArm.foreArm.hand.transform = r3
		rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume.transform = rightForeArmContainer.upperArm.foreArm.hand.transform


func updateHandJobMode() -> void:
	var before: float = g.currentHandJobPos.x
	var headLimit: float = g.him.getPosOnPenis(localToGlobal(topLipA)) + handJobHeadPadding / g.him.penisLengthScale
	g.currentHandJobPos.x += (g.targetHandJobPos.x * (1.0 - headLimit) + headLimit - g.currentHandJobPos.x) / 2.0
	g.currentHandJobPos.x = minf(1.0, maxf(headLimit, g.currentHandJobPos.x))
	g.currentHandJobPos.y += (g.targetHandJobPos.y - g.currentHandJobPos.y) / 2.0
	var stroke: float = g.currentHandJobPos.x * range - before * range
	if not passedOut:
		g.him.givePleasure(0.0 if is_nan(stroke) else stroke * 0.8)
		if absf(stroke) > 10:
			g.dialogueControl.buildState(Dialogue.HAND_JOB_STROKE, Dialogue.FRAME_BUILD)
	g.soundControl.updateRub(minf(0.5, stroke * 0.01), pos)
	handJobPenisWidth = g.him.getSimplePenisWidth(g.her.rightForeArmContainer.upperArm.foreArm.hand.localToGlobal(Vector2(0, 0)))
	var grip: float = 0.5 - 0.5 * g.him.getPenisMinRatio() + 0.5 * handJobPenisWidth / 65.0
	grip += absf(tan(rightHandAngleOffset / 180.0 * PI) * 0.4)
	grip = minf(1.1, grip)
	# the grip pieces exist only on some frames (skin, glove, tan); a missing one was undefined in Flash
	var hand = rightForeArmContainer.upperArm.foreArm.hand
	var glove = rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume.get("glove")
	var hand_tan = hand.get("tan")
	for part in [hand.get("grip"), glove.get("grip") if glove else null, hand_tan.get("grip") if hand_tan else null]:
		if part:
			part.scaleY = grip
	if leftHandOver.hand.get("grip"):
		leftHandOver.hand.scaleY = 0.8 + (1.0 - grip) * 0.3
	if Hooks.has(&"Her.updateHandJobMode"):   # HOOK
		Hooks.after(&"Her.updateHandJobMode", self, [])


func slipHands() -> void:
	if armPositions[currentLeftArmPosition] == "On Him":
		if g.breathLevel > g.outOfBreathPoint:
			leftArmIK.slip(passOutFactor / passOutMax * randf())
		else:
			leftArmIK.resetTarget(0.3)
	if armPositions[currentRightArmPosition] == "On Him":
		if g.breathLevel > g.outOfBreathPoint:
			rightArmIK.slip(passOutFactor / passOutMax * randf())
		else:
			rightArmIK.resetTarget(0.3)


func generateSpit() -> void:
	if justHilt:
		if previousMovement > 15:
			g.soundControl.playSplat()
			generateSplat(previousMovement / 10.0, 20, movement / 10.0)
		justHilt = false


func generateSplat(power: float, count: int = 1, spread: float = 1.0, isCum: bool = false) -> void:
	power = minf(8.0, power)
	spread = minf(2.0, spread)
	var top: Vector2 = g.sceneLayer.globalToLocal(localToGlobal(topLipB))
	var bottom: Vector2 = g.sceneLayer.globalToLocal(head.jaw.localToGlobal(bottomLipA))
	var step := Vector2(top.x - bottom.x, top.y - bottom.y)
	step.x /= 100.0
	step.y /= 100.0
	for i in count:
		var along := randf() * 100.0
		var p := Vector2(bottom.x + along * step.x, bottom.y + along * step.y)
		var vy := (randf() * 2.0 - 1.0 - (along - 50.0) * 0.25) * spread
		var vx := (randf() * 8.0 - 4.0 + power) * spread
		var mass := randf() * 1.5 + 0.1
		if isCum:
			g.cumLayer.addChild(Droplet.new(p, Vector2(vx, vy), mass, 0.2, 1, true))
		elif g.spit:
			g.strandFrontLayer.addChild(Droplet.new(p, Vector2(vx, vy), mass))


func generateRandomStrand(side: String = "front", long: bool = true) -> void:
	if Hooks.has(&"Her.generateRandomStrand"):   # HOOK
		var h := Hooks.before(&"Her.generateRandomStrand", self, [side, long])
		if h.cancelled:
			return
		side = h.args[0]
		long = h.args[1]
	if g.spit and not g.strandControl.maxPop():
		if side == "random":
			side = "front" if randf() > 0.7 else "back"
		var startAnchor: AnchorProp
		if randf() > 0.5:
			var d := Vector2(topLipA.x - topLipB.x, topLipA.y - topLipB.y)
			var r := randf()
			var p := Vector2(topLipB.x + r * d.x, topLipB.y + r * d.y)
			startAnchor = AnchorProp.new(p, self)
		else:
			var d := Vector2(bottomLipA.x - bottomLipB.x, bottomLipA.y - bottomLipB.y)
			var r := randf()
			var p := Vector2(bottomLipB.x + r * d.x, bottomLipB.y + r * d.y)
			startAnchor = AnchorProp.new(p, head.jaw)
		var endAnchor: AnchorProp = g.him.getRandomAnchor(pos)
		var links: int
		if long:
			links = int(floor(randf() * 4)) + 4
		else:
			links = int(floor(randf() * 2)) + 3
		if side == "front":
			g.strandControl.newStrand(g.strandFrontLayer, links, g.randomSpitMass(), startAnchor, endAnchor, long, Vector2(movement / 5.0, 0))
		elif side == "back":
			g.strandControl.newStrand(g.strandBackLayer, links, g.randomSpitMass(), startAnchor, endAnchor, long, Vector2(movement / 5.0, 0), true)


func generateTongueStrand() -> void:
	if g.spit and not g.strandControl.maxPop():
		var a := AnchorProp.new(Vector2(), tongue.tipPoint)
		var b := AnchorProp.new(g.him.penis.globalToLocal(tongue.localToGlobal(tongue.tip)), g.him.penis)
		var links := int(floor(randf() * 2)) + 4
		g.strandControl.newStrand(g.strandBackLayer, links, g.randomSpitMass() * 0.5, a, b, false, Vector2(movement / 5.0, 0))


func generateWetness() -> void:
	wetGenerate = maxf(0.0, wetGenerate - 500.0)


func tickSwallowing() -> void:
	jawBulgeTarget = int(floor(maxf(0.0, minf(25.0, pos * 25.0))))
	if swallowing:
		swallowTimer += 1
		var relax: float = swallowSequence["relax"]
		if swallowTimer < relax:
			swallowPoint = 1.0 - (relax - swallowTimer) / relax
		else:
			swallowPoint = 1.0 - (swallowTimer - relax) / (float(swallowSequence["end"]) - relax)
		headTiltTarget += 0.3 * swallowPoint * headTiltScaling
		jawBulgeTarget = mini(49, jawBulgeTarget + int(floor(swallowPoint * 40.0)))
		var fromSwallow := absi(swallowTimer - int(swallowSequence["swallow"]))
		if fromSwallow < 10:
			if not Hooks.has_value(&"Her.swallowWince") or Hooks.value(&"Her.swallowWince", self, true):   # HOOK value point: she squints around the swallow (true in the game)
				wince()
			headTiltTarget += 0.2 * headTiltScaling - 0.02 * fromSwallow * headTiltScaling
			jawBulgeTarget = maxi(0, jawBulgeTarget - int(floor(35 * 0.1 * (10 - fromSwallow))))
	updateJawBulge()


func updateJawBulge() -> void:
	head.jaw.jawBulge.gotoAndStop(lipSkinOffset + jawBulgeTarget)
	head.jawBack.jawBulgeOutline.gotoAndStop(jawBulgeTarget)
	head.headTan.jaw.jawBulge.gotoAndStop(lipSkinOffset + jawBulgeTarget)
	head.headTan.jawBack.jawBulgeOutline.gotoAndStop(jawBulgeTarget)


func fillMouth(force: bool = false) -> void:
	if force or mouthFull:
		if held:
			g.dialogueControl.buildState(Dialogue.CUM_IN_THROAT, Dialogue.TICK_BUILD * 2)
		else:
			g.dialogueControl.buildState(Dialogue.CUM_IN_MOUTH, Dialogue.TICK_BUILD * 2)
			cumInMouth = mini(maxCumInMouth, cumInMouth + 1)
	if Hooks.has(&"Her.fillMouth"):   # HOOK
		Hooks.after(&"Her.fillMouth", self, [force])


## Port: the moment she swallows (the jaw update's, split out so it has its own hook point): she squints,
## the gulp sound, the wave down her neck, and what it takes from her mouth. Same order as the game's.
func gulp() -> void:
	if Hooks.has(&"Her.gulp"):   # HOOK
		var h := Hooks.before(&"Her.gulp", self, [])
		if h.cancelled:
			return
	if not Hooks.has_value(&"Her.swallowWince") or Hooks.value(&"Her.swallowWince", self, true):   # HOOK value point
		wince()
	g.soundControl.playSwallow(pos)
	head.neck.swallow()
	swallowFromMouth()
	if Hooks.has(&"Her.gulp"):   # HOOK
		Hooks.after(&"Her.gulp", self, [])


func swallowFromMouth() -> void:
	var amount := mini(cumInMouth, int(floor(randf() * 5 + 5)))
	cumInMouth -= amount


func lastSpurt() -> void:
	if Hooks.has(&"Her.lastSpurt"):   # HOOK
		var h := Hooks.before(&"Her.lastSpurt", self, [])
		if h.cancelled:
			return
	if g.nostrilSpray and cumInMouth >= fullCumInMouth + minNostrilSpray:
		currentNostrilSpray = g.strandControl.newCumStrand(nostril, head.face)
		currentNostrilSpray.myGravity = g.gravity / 2.0
		shock(50)
		wince()
		nostrilSpraying = true
		nostrilSprayToggle = true


func tickNostrilSpray() -> void:
	nostrilSprayToggle = not nostrilSprayToggle
	var power := ((cumInMouth - fullCumInMouth) * 2.0 + maxf(0.0, movement) * 0.2) * 0.02
	if mouthFull and cumInMouth > fullCumInMouth:
		if nostrilSprayToggle:
			g.dialogueControl.buildState(Dialogue.CUM_IN_NOSE, Dialogue.TICK_BUILD * 2)
			currentNostrilSpray.insertLink(Vector2(25.0 * power + movement, 10.0 * power), 5, g.randomCumMass() * 0.8)
			cumInMouth -= 1
	else:
		currentNostrilSpray.detachSourceLink(Vector2(25.0 * power + movement, 10.0 * power), 5)
		nostrilSpraying = false


func tickSpitDrool() -> void:
	if spitDroolTimer > 0:
		spitDroolTimer -= 1
		if spitDroolTimer % spitDroolLinkFreq == 0:
			if startedSpitDrool:
				currentSpitDrool.insertLink(Vector2(0, 0), 2, g.randomSpitMass())
			else:
				currentSpitDrool = g.strandControl.newStrand(g.strandFrontLayer, 1, g.randomSpitMass(), null, null, true)
				currentSpitDrool.addSourceLink(offBottomLip, head.jaw)
				currentSpitDrool.myGravity = g.gravity / 2.0
				currentSpitDrool.collisionFree = 5
				startedSpitDrool = true
	else:
		stopDroolingSpit()
		droolingSpit = false


func stopDroolingSpit() -> void:
	if randf() > 0.3:
		currentSpitDrool.detachSourceLink(Vector2(0, 0), 5)
	currentSpitDrool.collisionFree = 5
	currentSpitDrool.myGravity = g.gravity
	startedSpitDrool = false
	droolingSpit = false


func randomSpitDrool() -> void:
	if Hooks.has(&"Her.randomSpitDrool"):   # HOOK
		var h := Hooks.before(&"Her.randomSpitDrool", self, [])
		if h.cancelled:
			return
	if g.spit:
		spitDroolTimer = int(floor(randf() * 5 + 3)) * spitDroolLinkFreq
		droolingSpit = true


func randomGagDroolTimer() -> void:
	gagDroolTimer = int(floor(randf() * 240)) + 300


func tickCumDrool() -> void:
	if cumDroolTimer > 0:
		cumDroolTimer -= 1
		if cumDroolTimer % cumDroolLinkFreq == 0:
			if startedCumDrool:
				currentCumDrool.insertLink(Vector2(0, 0), 2, g.randomCumMass() * 2.0)
			else:
				currentCumDrool = g.strandControl.newCumStrand(offBottomLip, head.jaw)
				currentCumDrool.myGravity = g.gravity / 2.0
				currentCumDrool.collisionFree = 2
				startedCumDrool = true
	else:
		stopDroolingCum()
		if cumDrool < cumDroolNum:
			randomCumDrool()
		else:
			droolingCum = false


func startDroolingCum(force: bool = false) -> void:
	if Hooks.has(&"Her.startDroolingCum") and (cumInMouth > 5 or force):   # HOOK (only when it would start)
		var h := Hooks.before(&"Her.startDroolingCum", self, [force])
		if h.cancelled:
			return
		force = h.args[0]
	if cumInMouth < 5 and force:
		cumInMouth = 5 + int(ceil(randf() * 5))
	if cumInMouth > 5:
		g.dialogueControl.buildState(Dialogue.DROOL, Dialogue.ONE_OFF_BUILD)
		cumDroolNum = maxi(1, int(floor(randf() * 2 + cumInMouth / 10.0)))
		cumDrool = 0
		randomCumDrool()


func stopDroolingCum() -> void:
	if currentCumDrool:
		if randf() > 0.3:
			currentCumDrool.detachSourceLink(Vector2(0, 0), 5)
		currentCumDrool.collisionFree = 4
		currentCumDrool.myGravity = g.gravity / 2.0
		currentCumDrool = null
	startedCumDrool = false
	droolingCum = false


func randomCumDrool() -> void:
	cumDroolTimer = int(minf(cumInMouth * cumDroolLinkFreq, floor(float(cumInMouth * cumDroolLinkFreq) / (cumDroolNum - cumDrool) + randf() * 5.0)))
	cumInMouth -= int(floor(float(cumDroolTimer) / cumDroolLinkFreq))
	cumDrool += 1
	droolingCum = true


func getRandomMotion() -> float:
	if randomMotion["next"] > 0:
		randomMotion["next"] -= 1
		randomMotion["speed"] += (randomMotion["target"] - randomMotion["pos"]) / 10.0
		randomMotion["speed"] *= 0.8
		randomMotion["pos"] += randomMotion["speed"]
	else:
		randomMotion["target"] = randf() * 0.6 - 0.3
		randomMotion["next"] = int(floor(randf() * 20 + 5))
	return randomMotion["pos"] / 50.0


var currentHiltDistance: float:
	get:
		return hiltDistance

var currentPenisDistance: float:
	get:
		return penisInMouthDist

var mood: String:
	get:
		return currentMood

var breathingAnimationAmount: float:
	get:
		return breathingFactor

var tan: Tan:
	get:
		return _tan

var penisControl: HerPenisControl:
	get:
		return _penisControl

var penisOn: bool:
	get:
		return _penisControl.currentPenisID > 0
