class_name AutomaticControl
extends RefCounted
## Port of obj.AutomaticControl: the auto modes (Normal / Soft / Hard / Self). Each movement pattern is a
## function returning the target (x = depth, y = tilt); modes cross-fade over a transition.

static var autoModeNameList: Array = ["Normal", "Soft", "Hard", "Self"]

var t: int = 0
var nextModeTimer: int = 0
var randomMode: Callable
var transitioning := false
var transitionSpeed: float = 0.01
var modeRatio: float = 0.0
var currentPos := Vector2(0, 0)
var lastPos := Vector2(0, 0)
var currentPenisTipPos: float = 0.0
var fullLength: float = 1.0
var lastMode: Callable
var currentMode: Callable
var singleAction: Callable
var waitingForSingleAction := false
var singleActionTimer: int = 0
var singleActionTime: int = 0
var standardModes: Array
var softModes: Array
var hardModes: Array
var selfModes: Array
var standardHJModes: Array
var softHJModes: Array
var hardHJModes: Array
var selfHJModes: Array
var currentSelfModes: Array = []
var singleActions: Array
var happySingleActions: Array
var singleActionModes: Dictionary = {}
var lastModeNo: int = 0
var offTilt: float = 0.0
var offTiltTarget: float = 0.0
var offTiltChangeTimer: int = 0
var ejaculatingModes: Array
var normalEjacModes: Array
var hardEjacModes: Array
var softEjacModes: Array
var selfEjacModes: Array
var lastEjacMode: Callable
var deepthroatTarget: float = 0.0
var deepthroatProgress: float = 0.0
var usingDeepSlow := false
var usingFullSlow := false


func _init() -> void:
	standardModes = [holdDown, activeHoldDown, offHold, fullSlow, fullFast, deepFast, shallowSlow, shallowMedium,
		shallowFast, mediumSlow, tipToDeepMedium, mediumFast]
	softModes = [offHold, shallowSlow, shallowMedium, mediumSlow, tipToDeepMedium, tipToDeepSlow]
	hardModes = [holdDown, activeHoldDown, offHold, fullFast, deepFast, shallowFast, mediumFast, tipToDeepFast, fullSlam,
		hiltMove]
	selfModes = [offHold, shallowSlow, shallowMedium, shallowMedium, mediumSlow, tipToDeepSlow, tipToDeepMedium,
		tipToDeepMedium, tipHold, outsideLickBalls]
	standardHJModes = [fullSlow, fullFast, deepFast, shallowSlow, shallowMedium, shallowFast, mediumSlow, tipToDeepMedium,
		mediumFast]
	softHJModes = [shallowSlow, shallowMedium, mediumSlow, tipToDeepMedium, tipToDeepSlow]
	hardHJModes = [fullFast, deepFast, shallowFast, mediumFast, tipToDeepFast, fullSlam]
	selfHJModes = [shallowSlow, shallowMedium, shallowMedium, mediumSlow, tipToDeepSlow, tipToDeepMedium, tipToDeepMedium]
	singleActions = [oneDeep]
	happySingleActions = [waggleEyebrows, waggleEyebrowsWithTongue, oneDeep]
	singleActionModes[waggleEyebrows] = offHold
	singleActionModes[waggleEyebrowsWithTongue] = offHold
	singleActionModes[oneDeep] = offHold
	normalEjacModes = [activeHoldDown, shallowHold, offHold, offHold]
	softEjacModes = [shallowHold, offHold, offHold]
	hardEjacModes = [activeHoldDown, shallowHold, offHold, offHold, hiltMove]
	selfEjacModes = [tipHold, shallowHold, offHold, offHold]
	currentMode = noMovement
	ejaculatingModes = normalEjacModes
	randomMode = standardAuto
	EventBus.addListener("penisTipPosChanged", updatePenisTipPos)


func updatePenisTipPos() -> void:
	currentPenisTipPos = g.animationControl.estimateTipPos()
	fullLength = 1.0 - currentPenisTipPos


func findAutoMode(n: String) -> void:
	for i in autoModeNameList.size():
		if n == autoModeNameList[i]:
			g.setAuto(i)
			g.inGameMenu.updateAutoList()
			break


func reducePleasureLoss() -> bool:
	return g.autoModeOn and randomMode == softAuto


func resetSelfMode() -> void:
	currentSelfModes = selfModes.duplicate()
	usingDeepSlow = false
	usingFullSlow = false
	deepthroatProgress = currentPenisTipPos + 0.4


func startAuto(p: Vector2) -> void:
	t = 0
	lastPos = p
	if g.autoModeOn:
		match g.autoMode:
			1:
				g.him.setArmPosition(0)
				randomMode = softAuto
				ejaculatingModes = softEjacModes
			2:
				g.him.setArmPosition(0)
				randomMode = hardAuto
				ejaculatingModes = hardEjacModes
			3:
				g.him.setArmPosition(1)
				randomMode = handsOffAuto
				ejaculatingModes = selfEjacModes
			_:
				g.him.setArmPosition(0)
				randomMode = standardAuto
				ejaculatingModes = normalEjacModes
		runRandomMode()
		g.inGameMenu.updateHisArmList()
	else:
		g.him.resetArmPosition()


func runRandomMode() -> void:
	g.her.movementRelease()
	randomMode.call()


func dialogueStarting() -> void:
	if randomMode == handsOffAuto:
		handsOffAuto()


func ejaculate() -> void:
	if g.autoModeOn:
		randomEjaculatingMode()


func doneEjaculating() -> void:
	nextModeTimer = int(floor(randf() * 90 + 60))


func _pickMode(modes: Array, skipIntro: bool) -> void:
	var i: int
	while true:
		if skipIntro and g.her.intro:
			i = int(floor(randf() * (modes.size() - 2))) + 2
		else:
			i = int(floor(randf() * modes.size()))
		if i != lastModeNo:
			break
	lastModeNo = i
	currentMode = modes[i]


func standardAuto() -> void:
	lastMode = currentMode
	var modes: Array = standardHJModes if g.handJobMode else standardModes
	if g.her.isActingOff():
		lastModeNo = 2
		currentMode = modes[2]
	else:
		_pickMode(modes, true)
	if currentMode == offHold:
		nextModeTimer = int(floor(randf() * 120 + 60))
	else:
		nextModeTimer = int(floor(randf() * 300 + 60))
	modeRatio = 0
	transitioning = true
	transitionSpeed = 0.01


func hardAuto() -> void:
	lastMode = currentMode
	var modes: Array = hardHJModes if g.handJobMode else hardModes
	if g.her.isActingOff():
		lastModeNo = 2
		currentMode = modes[2]
	else:
		_pickMode(modes, true)
	if currentMode == offHold:
		nextModeTimer = int(floor(randf() * 60 + 30))
	else:
		nextModeTimer = int(floor(randf() * 150 + 60))
	modeRatio = 0
	transitioning = true
	transitionSpeed = 0.25


func softAuto() -> void:
	lastMode = currentMode
	var modes: Array = softHJModes if g.handJobMode else softModes
	if g.her.isActingOff():
		lastModeNo = 0
		currentMode = modes[0]
	elif not g.handJobMode and randf() > 0.8:
		singleAction = oneDeep
		currentMode = offHold
		waitingForSingleAction = true
	elif not g.handJobMode and g.breathLevel > g.outOfBreathPoint:
		currentMode = offHold
	else:
		_pickMode(modes, false)
	if currentMode == offHold:
		nextModeTimer = int(floor(randf() * 120 + 60))
	else:
		nextModeTimer = int(floor(randf() * 300 + 60))
	modeRatio = 0
	transitioning = true
	transitionSpeed = 0.01


func handsOffAuto() -> void:
	lastMode = currentMode
	var modes: Array = selfHJModes if g.handJobMode else selfModes
	if g.her.isActingOff():
		lastModeNo = 0
		currentMode = modes[0]
	elif not g.handJobMode and randf() > (0.9 if usingFullSlow else 0.6):
		if randf() > 0.99:
			singleAction = waggleEyebrowsWithTongue
		else:
			singleAction = oneDeep
		currentMode = singleActionModes[singleAction]
		waitingForSingleAction = true
		lastModeNo = 1
	elif not g.handJobMode and randf() > 0.8:
		singleAction = singleActions[int(floor(randf() * singleActions.size()))]
		currentMode = singleActionModes[singleAction]
		waitingForSingleAction = true
	elif g.breathLevel > g.outOfBreathPoint:
		currentMode = offHold
		lastModeNo = 0
	else:
		_pickMode(currentSelfModes, false)
	if currentMode == offHold:
		nextModeTimer = int(floor(randf() * 60 + 30))
	elif currentMode == tipHold or currentMode == shallowHold:
		nextModeTimer = int(floor(randf() * 150 + 30))
	else:
		nextModeTimer = int(floor(randf() * 300 + 60))
	modeRatio = 0
	transitioning = true
	transitionSpeed = 0.01


func randomOffTilt() -> void:
	offTiltTarget = randf() * 1.4 - 0.9
	offTiltChangeTimer = int(floor(randf() * 300 + 60))


func randomEjaculatingMode() -> void:
	lastMode = currentMode
	var i: int
	while true:
		i = int(floor(randf() * ejaculatingModes.size()))
		if ejaculatingModes[i] != lastEjacMode:
			break
	currentMode = ejaculatingModes[i]
	lastEjacMode = currentMode
	nextModeTimer = 600
	modeRatio = 0
	transitioning = true
	transitionSpeed = 0.05


func getPos() -> Vector2:
	t += 1
	if g.her.released and not g.handsOff:
		lastPos.x = maxf(0.0, lastPos.x - 0.1)
		lastPos.y *= 0.8
	elif transitioning:
		modeRatio += transitionSpeed
		if modeRatio >= 1:
			if waitingForSingleAction:
				waitingForSingleAction = false
				if singleAction.is_valid():   # none yet: Flash's TypeError, ignored (armoverhaul waits with no action)
					singleAction.call()
			else:
				singleActionTime = 0
			singleActionTimer = 0
			transitioning = false
			modeRatio = 1
		var from: Vector2 = lastMode.call()
		var to: Vector2 = currentMode.call()
		lastPos = from * (1.0 - modeRatio) + to * modeRatio
	else:
		lastPos = currentMode.call()
		if singleActionTimer < singleActionTime:
			singleActionTimer += 1
		elif nextModeTimer > 0:
			nextModeTimer -= 1
		else:
			runRandomMode()
	offTilt += (offTiltTarget - offTilt) * 0.2
	if offTiltChangeTimer > 0:
		offTiltChangeTimer -= 1
	else:
		randomOffTilt()
	deepthroatProgress = maxf(deepthroatProgress, lastPos.x)
	if g.handJobMode:
		lastPos.x = lastPos.x * 0.9 + 0.1
	return lastPos


func adjustAim() -> void:
	if g.her.isInMouth() or g.handJobMode:
		currentPos.y *= 0.8
	else:
		var off: float = g.her.getPenisMouthOffset()
		if absf(off) < 5:
			return
		currentPos.y += maxf(-0.5, minf(0.5, off * minf(0.3, 10.0 * absf(lastPos.x - currentPos.x))))


func avoidPenisOut() -> void:
	if not transitioning:
		g.her.movementRelease()
		currentPos.x = maxf(-0.2, currentPenisTipPos - 0.2)
		adjustAim()


func sinWave(speed: float, amp: float, base: float) -> float:
	return base + (sin(t * speed) + 1.0) * amp * 0.5


func _suckOnPull() -> void:
	if currentPos.x - lastPos.x < 0 and g.her.isInMouth():
		currentPos.y = offTilt
		if randomMode == handsOffAuto:
			g.her.suck()
			g.him.givePleasure(7)
	else:
		adjustAim()


func _tiltOnPull() -> void:
	if currentPos.x - lastPos.x < 0 and g.her.isInMouth():
		currentPos.y = offTilt
	else:
		adjustAim()


func noMovement() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = currentPenisTipPos - 0.2
	currentPos.y = lastPos.y * 0.8
	return currentPos


func fullSlow() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = maxf(currentPenisTipPos - 0.3, sinWave(0.06, fullLength + 0.6, currentPenisTipPos - 0.4))
	if currentPos.x - lastPos.x < 0:
		currentPos.y = offTilt * (cos(t * 0.06) * 0.5 + 0.5)
	else:
		adjustAim()
	return currentPos


func fullFast() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = sinWave(0.25, fullLength + 0.2, currentPenisTipPos)
	currentPos.y = minf(0.2, maxf(-0.2, offTilt))
	return currentPos


func deepFast() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = sinWave(0.5, fullLength - 0.1, 1.25 - fullLength)
	adjustAim()
	return currentPos


func deepSlow() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = sinWave(0.25, fullLength - 0.1, 1.15 - fullLength)
	adjustAim()
	return currentPos


func shallowSlow() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = sinWave(0.25, minf(0.5, fullLength - 0.3), currentPenisTipPos + 0.05)
	_suckOnPull()
	return currentPos


func shallowMedium() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = sinWave(0.35, fullLength - 0.3, currentPenisTipPos + 0.05)
	_suckOnPull()
	return currentPos


func shallowFast() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = sinWave(0.5, fullLength - 0.3, currentPenisTipPos + 0.05)
	currentPos.y = minf(0.2, maxf(-0.2, offTilt))
	return currentPos


func mediumSlow() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = maxf(0.0, sinWave(0.05, fullLength + 0.1, currentPenisTipPos - 0.2))
	_suckOnPull()
	return currentPos


func tipToDeepSlow() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = maxf(0.0, sinWave(0.08, fullLength - 0.1, currentPenisTipPos + 0.1))
	_tiltOnPull()
	return currentPos


func tipToDeepMedium() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = maxf(0.0, sinWave(0.2, fullLength - 0.1, currentPenisTipPos + 0.1))
	_tiltOnPull()
	return currentPos


func tipToDeepFast() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = maxf(0.0, sinWave(0.35, fullLength - 0.1, currentPenisTipPos + 0.1))
	adjustAim()
	return currentPos


func mediumFast() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = sinWave(0.25, fullLength, currentPenisTipPos - 0.2)
	_tiltOnPull()
	return currentPos


func fullSlam() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	var target := maxf(currentPenisTipPos - 0.2, minf(1.25, 1.5 * ceil(t * 0.05) - t * 0.05 * 1.5))
	currentPos.x = minf(lastPos.x + 0.5, target)
	adjustAim()
	return currentPos


func hiltMove() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	if g.her.currentPenisDistance > g.her.currentHiltDistance:
		currentPos.x = lastPos.x + randf() * 0.04 - 0.02
	else:
		currentPos.x = minf(lastPos.x + 0.1, 1.2)
	if randf() > 0.6:
		g.her.activeHold(false)
	adjustAim()
	return currentPos


func holdDown() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	if randf() > 0.99:
		g.her.activeHold(false)
	currentPos.x = minf(lastPos.x + 0.1, 1.2)
	adjustAim()
	return currentPos


func activeHoldDown() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	if randf() > 0.6:
		g.her.activeHold(false)
	currentPos.x = 1.2
	adjustAim()
	return currentPos


func singleDeepthroat() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = minf(deepthroatTarget, lastPos.x + 0.02)
	g.him.givePleasure(5)
	if currentPos.x == deepthroatTarget:
		currentPos.x += randf() * 0.01 - 0.005
		g.her.wince()
	if float(singleActionTimer) / singleActionTime > 0.8:
		currentMode = moveOff
		g.her.lookUp()
	adjustAim()
	return currentPos


func shallowHold() -> Vector2:
	if g.penisOut:
		avoidPenisOut()
		return currentPos
	currentPos.x = sinWave(0.1, 0.05, currentPenisTipPos + 0.75)
	adjustAim()
	return currentPos


func offHold() -> Vector2:
	currentPos.x = maxf(-0.2, sinWave(0.1, 0.05, currentPenisTipPos - 0.3))
	currentPos.y = offTilt
	if g.her.isActingOff():
		nextModeTimer += 1
	return currentPos


func moveOff() -> Vector2:
	currentPos.x = maxf(currentPenisTipPos - 0.2, lastPos.x - 0.03)
	currentPos.y = offTilt
	return currentPos


func offHoldWithTongue() -> Vector2:
	currentPos.x = maxf(-0.2, sinWave(0.1, 0.05, currentPenisTipPos - 0.3))
	currentPos.y = offTilt
	g.her.tongueContainer.tongue.encourage()
	return currentPos


func tipHold() -> Vector2:
	var d: float = g.her.getPenisMouthDist() + 10.0
	currentPos.x -= d * 0.001
	currentPos.y = offTilt
	g.her.tongueContainer.tongue.encourage()
	return currentPos


func outsideLickBalls() -> Vector2:
	if transitioning:
		currentPos.x = maxf(currentPenisTipPos - 0.2, lastPos.x - 0.03)
	elif g.penisOut:
		if g.him.currentBalls > 0:
			currentPos.x = minf(1.0, lastPos.x + 0.03)
			currentPos.y = lastPos.y + (0.8 + randf() * 0.2 - lastPos.y) * 0.1
		else:
			currentPos.x = sinWave(0.073, fullLength - 0.3, currentPenisTipPos + 0.3)
			currentPos.y = sinWave(0.04, 0.6, -0.2)
		g.her.tongueContainer.tongue.encourage()
	else:
		currentPos.x = maxf(currentPenisTipPos - 0.2, lastPos.x - 0.03)
		currentPos.y = offTilt
		g.her.mousePressed()
	return currentPos


func waggleEyebrows() -> void:
	nextModeTimer = 0
	singleActionTime = 25
	g.her.waggleEyebrows()


func waggleEyebrowsWithTongue() -> void:
	nextModeTimer = 0
	singleActionTime = 25
	g.her.waggleEyebrows()
	g.her.tongueContainer.tongue.encourage(50)


func oneDeep() -> void:
	nextModeTimer = 0
	singleActionTime = 120
	deepthroatTarget = randf() * 0.1 + 0.1 + deepthroatProgress
	if g.her.currentPenisDistance > g.her.deepthroatDistance and not usingDeepSlow:
		usingDeepSlow = true
		currentSelfModes.append(deepSlow)
	if g.her.currentPenisDistance > g.her.currentHiltDistance and not usingFullSlow:
		usingFullSlow = true
		currentSelfModes.append(fullSlow)
	currentMode = singleDeepthroat
	g.her.lookDown()
