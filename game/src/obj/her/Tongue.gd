class_name Tongue
extends FlashMovieClip
## Port of obj.her.Tongue: tongue in/out, wiggling and lick actions, chosen from her situation.

var piercingBack
var piercing
var tipPoint

var tongueOut := false
const tongueOutStartFrame := 3
const tongueOutEndFrame := 33
var mouthFull := false
var mouthFullTimer: float = 0.0
var mouthFullTime: int = 0
var currentPos: float = 0.0
var nearTip := false
var startedOff := false
var playingAction := false
var cumOnTongue: int = 0
var swallowTimer: int = 0
var swallowTime: int = 0
var increasedAction: int = 0
var waitingForOut := false
var waitingForIn := false
var fastIn := false
var waitingToTouch := false
var tiltOffset: float = 0.0
var actionTimer: int = 0
var nextActionTime: int
var nearTimer: int = 0
var nearTime: int
var wiggleSpeed: float = 0.0
var nextAction: Callable
var currentAction: Callable
var offActions: Array
var tipActions: Array
var shaftActions: Array
var actionTime: int = 0
var hangingOut := false
var solidAction: Dictionary = {}
var tiltSpeeds: Dictionary = {}
var pushPower: Dictionary = {}


func _init() -> void:
	super()
	nextActionTime = int(floor(randf() * 60)) + 15
	nearTime = int(ceil(randf() * 20)) + 10
	nextAction = doNothing
	offActions = [startMovingTongueIn, startMovingTongueIn, startMovingTongueIn, startMovingTongueOut, doNothing,
		lick, longLick, smallLick, tinyLick, quickLick]
	shaftActions = [startMovingTongueIn, doNothing, tinyLick, shaftLick]
	tipActions = [lick, longLick, smallLick, tinyLick, quickLick]
	solidAction[startMovingTongueIn] = false
	solidAction[startMovingTongueOut] = false
	solidAction[doNothing] = false
	solidAction[lick] = true
	solidAction[longLick] = true
	solidAction[smallLick] = true
	solidAction[tinyLick] = true
	solidAction[quickLick] = true
	solidAction[shaftLick] = false
	tiltSpeeds[lick] = 0.3
	tiltSpeeds[longLick] = 0.15
	tiltSpeeds[smallLick] = 0.25
	tiltSpeeds[tinyLick] = 0.25
	tiltSpeeds[quickLick] = 0.3
	pushPower[lick] = -0.1
	pushPower[longLick] = -0.1
	pushPower[smallLick] = -0.05
	pushPower[tinyLick] = -0.05
	pushPower[quickLick] = -0.05
	gotoAndStop("InDone")
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func tick() -> void:
	updatePiercing()


func setMouthFull(v: bool = true) -> void:
	mouthFull = v
	mouthFullTimer = 0
	mouthFullTime = int(floor(randf() * 60))


func encourage(amount: int = 5) -> void:
	increasedAction = amount
	if Hooks.has(&"Tongue.encourage"):   # HOOK
		Hooks.after(&"Tongue.encourage", self, [amount])


func hangOut() -> void:
	hangingOut = true
	startMovingTongue("out")


func stopHangingOut() -> void:
	hangingOut = false
	startFastIn()


func startMovingTongue(dir: String) -> void:
	if Hooks.has(&"Tongue.startMovingTongue"):   # HOOK: her tongue asked to move "out" or "in"
		var h := Hooks.before(&"Tongue.startMovingTongue", self, [dir])
		if h.cancelled:
			return
		dir = h.args[0]
	if dir == "out":
		if g.tongue and not tongueOut and not g.her.isSpeaking() and not g.her.teethClenched:
			waitingForIn = false
			waitingForOut = true
			mouthFullTimer = 0
	elif dir == "in" and tongueOut:
		waitingForIn = true
		waitingForOut = false


func startFastIn() -> void:
	waitingForIn = true
	waitingForOut = false
	fastIn = true


var tip: Vector2:
	get:
		return Vector2(tipPoint.x, tipPoint.y)


func getPush() -> float:
	if solidAction.get(currentAction, false):
		return pushPower[currentAction]
	return 0.0


func getHeadTilt() -> float:
	return tiltOffset


func block() -> bool:
	return solidAction.get(currentAction, false) and startedOff


func okayToHit() -> bool:
	return tongueOut


func cumHit() -> void:
	swallowTimer = 0
	cumOnTongue += 1


func cumRemoved() -> void:
	cumOnTongue = maxi(0, cumOnTongue - 1)


func ejaculating() -> void:
	if checkOff():
		startMovingTongue("out")


func touched() -> bool:
	if waitingToTouch:
		g.him.givePleasure(randf() * 25.0 + 100.0)
		waitingToTouch = false
		g.soundControl.playLick()
		return true
	return false


func update(p: float, movement: float, absMovement: float, vigour: float) -> void:
	if Hooks.has(&"Tongue.update"):   # HOOK
		var h := Hooks.before(&"Tongue.update", self, [p, movement, absMovement, vigour])
		if h.cancelled:
			return
	currentPos = p
	tiltOffset *= 0.8
	if movement > 30 or vigour > 300:
		startFastIn()
	if waitingForOut and (currentAction.is_null() or currentAction == startMovingTongueOut):
		moveTongueOut()
	elif waitingForIn and (currentAction.is_null() or currentAction == startMovingTongueIn):
		moveTongueIn()
	elif playingAction:
		actionTime += 1
		if solidAction.get(currentAction, false):
			tiltOffset -= 0.5 * (1.0 - cos(actionTime * tiltSpeeds[currentAction]))
		if currentFrameLabel == "InDone" or currentFrameLabel == "OutDone":
			playingAction = false
			currentAction = Callable()
			waitingToTouch = false
			if currentFrameLabel == "OutDone":
				gotoAndStop(tongueOutEndFrame)
	else:
		if cumOnTongue > 0:
			swallowTimer += 1
			if swallowTimer > swallowTime:
				startMovingTongue("in")
		if tongueOut:
			if mouthFull:
				if mouthFullTime >= 0:
					if mouthFullTimer < mouthFullTime:
						mouthFullTimer += g.her.currentPenisDistance * 0.0025
					else:
						mouthFullTime = -1
						startMovingTongue("in")
		if not g.her.passedOut and not g.her.isSpeaking():
			if checkNearTip() or increasedAction > 0:
				if nearTimer < nearTime:
					wiggleTongue(nearTime - nearTimer)
					nearTimer += 1
				elif absMovement < 10 and vigour < 300:
					if not tongueOut:
						startMovingTongue("out")
					else:
						performRandomTipAction()
					nearTimer = 0
			else:
				nearTimer = 0
				if actionTimer < nextActionTime:
					wiggleTongue(nextActionTime - actionTimer)
					actionTimer += 1
				else:
					performNextAction()
	wiggleSpeed *= 0.9
	if increasedAction > 0:
		increasedAction -= 1
	if Hooks.has(&"Tongue.update"):   # HOOK
		Hooks.after(&"Tongue.update", self)


func updatePiercing() -> void:
	var a: float = g.getAngle(minf(25.0, tipPoint.x), tipPoint.y)
	piercing.x = tipPoint.x
	piercing.y = tipPoint.y
	piercing.rotation_degrees = a
	piercingBack.x = tipPoint.x
	piercingBack.y = tipPoint.y
	piercingBack.rotation_degrees = a


func wiggleTongue(amount: int = 0) -> void:
	amount = maxi(0, amount)
	if currentLabel == "TongueOut":
		var low := maxi(tongueOutEndFrame - 10, tongueOutEndFrame - amount)
		wiggleSpeed += randf() - 0.5
		if hangingOut:
			wiggleSpeed = maxf(-2.0, minf(2.0, wiggleSpeed))
		else:
			wiggleSpeed = maxf(-1.2, minf(1.2, wiggleSpeed))
		gotoAndStop(maxi(low, mini(tongueOutEndFrame, currentFrame + int(Maths.round(wiggleSpeed)))))


func performRandomTipAction() -> void:
	actionTimer = 0
	if increasedAction > 0:
		nextActionTime = int(floor(randf() * 15)) + 5
		nearTime = int(randf() * 10)
	else:
		nextActionTime = int(floor(randf() * 60)) + 15
		nearTime = int(ceil(randf() * 40)) + 5
	if increasedAction > 0 and not tongueOut:
		nextAction = startMovingTongueOut
	else:
		nextAction = tipActions[int(floor(randf() * tipActions.size()))]
	performNextAction()


func randomAction() -> void:
	actionTimer = 0
	mouthFullTimer = 0
	if increasedAction > 0:
		nextActionTime = int(floor(randf() * 15)) + 5
	else:
		nextActionTime = int(floor(randf() * 60)) + 15
	var actions: Array = shaftActions if g.her.currentPenisDistance > 0 and mouthFull else offActions
	var i: int
	if increasedAction > 0:
		i = int(floor(randf() * (actions.size() - 1))) + 1
	else:
		i = int(floor(randf() * actions.size()))
	nextAction = actions[i]


func performNextAction() -> void:
	if Hooks.has(&"Tongue.performNextAction"):   # HOOK
		var h := Hooks.before(&"Tongue.performNextAction", self, [])
		if h.cancelled:
			return
	actionTime = 0
	nearTip = checkNearTip()
	startedOff = checkOff()
	currentAction = nextAction
	playingAction = true
	nextAction.call()
	randomAction()


func checkNearTip() -> bool:
	return g.her.currentPenisDistance > -60 and (g.her.currentPenisDistance < 30 or g.penisOut)


func checkOff() -> bool:
	return g.her.currentPenisDistance < 0


func startMovingTongueIn() -> void:
	if tongueOut:
		startMovingTongue("in")
	else:
		playingAction = false


func startMovingTongueOut() -> void:
	if not tongueOut:
		startMovingTongue("out")
	else:
		playingAction = false


func moveTongueIn() -> void:
	playingAction = true
	if currentLabel == "OutDone":
		gotoAndStop(tongueOutEndFrame)
	else:
		if fastIn:
			gotoAndStop(maxi(tongueOutStartFrame, currentFrame - 4))
		else:
			gotoAndStop(maxi(tongueOutStartFrame, currentFrame - 2))
		if currentFrame == tongueOutStartFrame:
			swallowTime = int(ceil(randf() * 60)) + 15
			waitingForIn = false
			fastIn = false
			cumOnTongue = 0
			gotoAndStop("InDone")
		if hangingOut:
			fastIn = false
			waitingForIn = false
			startMovingTongue("out")
		tongueOut = false


func moveTongueOut() -> void:
	playingAction = true
	if currentLabel == "InDone":
		gotoAndStop(tongueOutStartFrame)
	else:
		gotoAndStop(mini(tongueOutEndFrame, currentFrame + 2))
		if currentFrame == tongueOutEndFrame:
			waitingForOut = false
			tongueOut = true
			gotoAndStop("OutDone")


func doNothing() -> void:
	playingAction = false


func lick() -> void:
	if tongueOut:
		gotoAndPlay("Lick")
		tongueOut = false
		if increasedAction > 0 or randf() > 0.5:
			startMovingTongue("out")
		waitingToTouch = true


func longLick() -> void:
	if tongueOut:
		gotoAndPlay("LongLick")
		tongueOut = false
		if increasedAction > 0 or randf() > 0.5:
			startMovingTongue("out")
		waitingToTouch = true


func smallLick() -> void:
	if tongueOut:
		gotoAndPlay("SmallLick")
		waitingToTouch = true


func tinyLick() -> void:
	if tongueOut:
		gotoAndPlay("TinyLick")
		waitingToTouch = true


func quickLick() -> void:
	if tongueOut:
		gotoAndPlay("QuickLick")
		waitingToTouch = true


func shaftLick() -> void:
	if tongueOut:
		gotoAndPlay("ShaftLick")
		waitingToTouch = true
