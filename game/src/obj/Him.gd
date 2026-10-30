class_name Him
extends FlashMovieClip
## Port of obj.Him: the male character. Penis tilt / twitch physics, pleasure and ejaculation (spurts become cum
## strands), body types (male / female) and his arms.

const armPositions := ["Holding", "Free"]
const leftArmPositions := ["Hidden", "Loose"]
const DEFAULT_PENIS_SIZE := 1.0
const DEFAULT_BALL_SIZE := 1.0

# Timeline instances
var topBack
var rightLegCostume
var straponStraps
var midLayer
var leftLegCostume
var balls
var penis
var torsoLayer
var rightLeg
var leftLeg

var currentBody = null
var bodies: Array = []
var characterMenu = null
const bodyNameList := ["Male", "Female"]
var currentBodyID: int = 0
var currentArmPosition: int = 0
var lastSelectedArmPosition: int = 0
var currentLeftArmPosition: int = 1
var penisMask: FlashDisplayObject
var overLayer
var armContainer
var leftArmContainer
var bentPenis = null
var bpMask = null
var deepestPos: float = 0.0
## The size limits are static vars, not constants, so an extension can widen them (penisrange); the game's values.
static var MIN_PENIS_SIZE := 0.7
static var MAX_PENIS_SIZE := 1.2
var currentPenisLengthScale: float = 1.0
var currentPenisWidthScale: float = 1.0
var penisPullScale: float = 0.0
static var MIN_BALL_SIZE := 0.5
static var MAX_BALL_SIZE := 1.3
var currentBallSize: float = 1.0
const penisNameList := ["Penis A", "Penis B", "Strapon"]
var currentPenis: Penis
var penisControl: CharacterElementHelper
var penisType1: Penis
var penisType2: Penis
var penisTypes: Array = []
var ballsNameArray: Array = ["None", "Normal"]
var currentBalls: int = 0
var penisTilt: float = 0.0
var penisTiltSpeed: float = 0.0
var penisTiltTarget: float = 0.0
var inMouthTiltOffset: float = 0.0
var mouthConstraintSmoothing: float = 0.0
var twitchFactor: float = 0.0
var twitching := false
var pleasure: float = 0.0
var ejacPleasure: float = 140.0
var buildUp: float = 0.0
var maxPleasureTimer: int = 0
var inMouth := false
var handOpen := true
var ejaculating := false
var ejaculation: Array = []
var playingCumSound := false
var spurting := false
var startedSpurt := false
var currentSpurt   # Strand, or NativeStrand with the native fluid system (StrandControl)
var spurtTimer: int = 0
var spurtTimerStart: int = 0
var spurt: int = 0
var randomSpurtAngle: float = 0.0
var randomSpurtAngleRange: float = 0.0
var randomSpurtSpeed: float = 0.0
var randomSpurtCollisionDelay: int = 0
var spurtNum: int = 0
var linkFreq: int = 2
var pauseTimer: int = 0
var startSpeed := Vector2()
var timerScale: float = 0.0
var bmEjaculating := false
var bmSpurtAngle: float = 3.3415926535897933
var bmTimerStart: int = 30
var bmTimer: int = 0
var lipstickData: FlashBitmapData
var lipstickLayer: FlashBitmap
var lipstickCounter: int = 0
## Port addition: see setBodyHidden().
var bodyHidden := false
var _shownParts: Array = []
var lipstickBlur: FlashFilter = FlashFilter.blur(3.5, 1)
var lipstickRGB: FlashColorTransform = FlashColorTransform.new()
var smearGraphic: FlashDisplayObject
var baseA := Vector2(-5, 37)
var baseB := Vector2(-13, -36)
var tipA := Vector2(-317, 7)
var tipB := Vector2(-310, -27)
var tipMid := Vector2(-324, -11)


## Port: a body's footwear control (the futa body has its own, femaleFootwearControl; its footwearControl is unset).
static func feet_control(body) -> CharacterElementHelper:
	if body == null:
		return null
	var f = body.get("femaleFootwearControl")
	return f if f != null else body.get("footwearControl")


func _init() -> void:
	super()
	x = 420
	y = 135
	penisMask = Flash.create("HimMask")
	addChild(penisMask)
	penis.mask = penisMask
	lipstickData = FlashBitmapData.new(350, 120, true, 0)
	lipstickLayer = FlashBitmap.new(lipstickData, "auto", true)
	penis.lipstickElements.lipstickContainer.addChild(lipstickLayer)
	lipstickLayer.alpha = 0.8
	smearGraphic = Flash.create("LipstickSmear")
	penisType1 = Penis.new(penis, Vector2(-315, 0))
	penisType1.defineWidth(-321.9, -19.3, 23.4)
	penisType1.defineWidth(-309.5, -29.3, 44.8)
	penisType1.defineWidth(-291.8, -33.5, 52.5)
	penisType1.defineWidth(-269.5, -39.2, 60.9)
	penisType1.defineWidth(-261.5, -33.3, 56.6)
	penisType1.defineWidth(-168.4, -36.6, 71.5)
	penisType1.defineWidth(-31.3, -36.3, 74.6)
	penisType2 = Penis.new(penis, Vector2(-315, 0))
	penisType2.defineWidth(-318.7, -23.8, 29)
	penisType2.defineWidth(-293.8, -36, 55.1)
	penisType2.defineWidth(-286.2, -36.9, 57.4)
	penisType2.defineWidth(-249.2, -45, 68.6)
	penisType2.defineWidth(-242.7, -40.6, 65.4)
	penisType2.defineWidth(-154.6, -38.2, 73)
	penisType2.defineWidth(-27.7, -37.5, 75)
	penisTypes = [penisType1, penisType2, penisType1]
	currentPenis = penisType1
	setBalls(0)
	penisControl = CharacterElementHelper.new(penisNameList, setPenis)
	penisControl.setStartRGB(AlphaRGBObject.new(1, 204, 94, 147))
	penisControl.registerComponents([penis], "", false)


func initBodies() -> void:
	bodies = [HimMaleBody.new(self), HimFemaleBody.new(self)]


func shuffle() -> void:
	currentBody.shuffle()


func getDataString() -> String:
	var body := "hisBody:" + g.dataName(bodyNameList[currentBodyID])
	var p := "hisPenis:%s,%s,%s" % [currentPenisID, penisLengthScale, penisWidthScale]
	var b := "balls:%s,%s" % [currentBalls, ballSizeScale]
	return body + ";" + p + ";" + b + ((";" + currentBody.getDataString()) if currentBody else "")


func loadDataPairs(pairs: Array) -> void:
	var bodySet := false
	for pair in pairs:
		match pair[0]:
			"hisBody":
				for i in bodyNameList.size():
					if g.dataName(pair[1]) == g.dataName(bodyNameList[i]):
						setBody(i)
						bodySet = i > 0
						break
			"hisPenis":
				var vals: PackedStringArray = String(pair[1]).split(",")
				penisControl.select(int(vals[0]))
				if vals.size() == 3:
					loadPenisScales(float(vals[1]), float(vals[2]))
			"balls":
				var vals: PackedStringArray = String(pair[1]).split(",")
				setBalls(int(vals[0]))
				if vals.size() == 2:
					setBallScale(float(vals[1]))
				g.inGameMenu.updateBallSizeSlider()
				g.inGameMenu.updateBallsList()
	if not bodySet and currentBodyID == 0:
		setBody(0)
	currentBody.loadDataPairs(pairs)


func loadLegacyData(vals: Array) -> void:
	var v := mini(3, maxi(0, int(vals[0])))
	setBody(bodyNameList.find("Male"))
	if v == 0 or v == 2:
		penisControl.select(0)
	else:
		penisControl.select(1)
	if v == 0 or v == 1:
		currentBody.loadDataPairs([["hisSkin", 0]])
	else:
		currentBody.loadDataPairs([["hisSkin", 1]])
	if vals.size() == 3:
		loadPenisScales(float(vals[1]), float(vals[2]))
	updateArm()


func setBody(id: int) -> void:
	if currentBody:
		currentBody.breakdown()
	currentBodyID = id
	currentBody = bodies[currentBodyID]
	gotoAndStop(bodyNameList[currentBodyID])
	armContainer.gotoAndStop(bodyNameList[currentBodyID])
	leftArmContainer.gotoAndStop(bodyNameList[currentBodyID])
	currentBody.setup()
	currentBody.redoLastMove()
	g.characterControl.updateHisSkinHSL()
	g.inGameMenu.updateHisBodyList()
	g.inGameMenu.updateHimMenuContent()
	g.her.setArmPosition()
	if bodyHidden:   # port: the new body's parts hidden too
		setBodyHidden(false)
		setBodyHidden(true)
	if Hooks.has(&"Him.setBody"):   # HOOK
		Hooks.after(&"Him.setBody", self, [id])


## Port addition (the Loader mod ToggleHim, Him > Body "Show his body"): hides all of him but his penis. The game's own
## visibility changes (strap-on straps, balls, left arm) keep them hidden meanwhile and showing him again restores them.
func setBodyHidden(on: bool) -> void:
	if on == bodyHidden:
		return
	bodyHidden = on
	if on:
		_shownParts = []
		for i in numChildren:
			var c = getChildAt(i)
			if c != penis and c.visible:
				_shownParts.append(c)
				c.visible = false
		for c in [armContainer, overLayer, leftArmContainer]:
			if c != null and c.visible:
				_shownParts.append(c)
				c.visible = false
		return
	for c in _shownParts:
		if is_instance_valid(c):
			c.visible = true
	_shownParts = []
	straponStraps.visible = currentPenisID == penisNameList.find("Strapon")
	balls.visible = currentBalls != 0
	if leftArmContainer != null:
		leftArmContainer.visible = currentLeftArmPosition == 1


func animationChanged() -> void:
	currentBody.animationChanged()


func toggleBodySettings() -> void:
	currentBody.toggleBodySettings()


func giveOverLayer(l) -> void:
	overLayer = l
	overLayer.x = x
	overLayer.y = 135


func giveHimArm(a) -> void:
	armContainer = a
	armContainer.x = x
	armContainer.y = 135
	openHand()


func giveHimLeftArm(a) -> void:
	leftArmContainer = a
	leftArmContainer.x = 136
	leftArmContainer.y = -516


func giveHimBentPenis(b) -> void:
	bentPenis = b
	bpMask = Flash.create("BentPenisMask")
	addChild(bpMask)
	bentPenis.mask = bpMask


func isEjaculating() -> bool:
	return ejaculating or bmEjaculating


var penisLengthScale: float:
	get:
		return currentPenisLengthScale

var penisWidthScale: float:
	get:
		return currentPenisWidthScale

var penisLengthSlider: float:
	get:
		return (currentPenisLengthScale - MIN_PENIS_SIZE) / (MAX_PENIS_SIZE - MIN_PENIS_SIZE)

var penisWidthSlider: float:
	get:
		return (currentPenisWidthScale - MIN_PENIS_SIZE) / (MAX_PENIS_SIZE - MIN_PENIS_SIZE)

var hslShiftPenis: bool:
	get:
		return currentPenisID != penisNameList.find("Strapon")


func setPenis(id: int) -> void:
	updatePenis()
	currentPenis = penisTypes[id]
	if currentPenisID == penisNameList.find("Strapon"):
		characterMenu.rgbPenis.visible = true
		straponStraps.visible = not bodyHidden
		penisControl.resetFills()
	else:
		characterMenu.rgbPenis.visible = false
		straponStraps.visible = false
	g.characterControl.updateHisSkinHSL()


func updatePenis() -> void:
	if currentPenisID == penisNameList.find("Strapon"):
		penis.gotoAndStop(penisNameList[currentPenisID])
	else:
		penis.gotoAndStop(g.himSkinType + penisNameList[currentPenisID])
	penis.wet.gotoAndStop(penisNameList[currentPenisID])
	penis.lipstickElements.lipstickMask.gotoAndStop(penisNameList[currentPenisID])


func _applyPenisScale() -> void:
	penis.scaleX = currentPenisLengthScale
	penis.scaleY = currentPenisWidthScale
	g.her.hisPenisSizeChanged(currentPenisLengthScale * currentPenis.length)
	EventBus.dispatch("penisTipPosChanged")


func loadPenisScales(length: float, width: float) -> void:
	currentPenisLengthScale = maxf(MIN_PENIS_SIZE, minf(MAX_PENIS_SIZE, length))
	currentPenisWidthScale = maxf(MIN_PENIS_SIZE, minf(MAX_PENIS_SIZE, width))
	g.inGameMenu.updatePenisWidthSlider()
	g.inGameMenu.updatePenisLengthSlider()
	_applyPenisScale()


func setPenisLength(v: float) -> void:
	var ratio := currentPenisWidthScale / currentPenisLengthScale
	currentPenisLengthScale = MIN_PENIS_SIZE + (MAX_PENIS_SIZE - MIN_PENIS_SIZE) * v
	currentPenisWidthScale = maxf(MIN_PENIS_SIZE, minf(MAX_PENIS_SIZE, ratio * currentPenisLengthScale))
	_applyPenisScale()


func setPenisWidth(v: float) -> void:
	currentPenisWidthScale = MIN_PENIS_SIZE + (MAX_PENIS_SIZE - MIN_PENIS_SIZE) * v
	_applyPenisScale()


func getPenisTipPoint(dx: float = 0.0, dy: float = 0.0) -> Vector2:
	return currentPenis.getGlobalTip(dx, dy)


func getPenisBasePoint() -> Vector2:
	return penis.localToGlobal(Vector2())


func getSimplePenisWidth(p: Vector2) -> float:
	return currentPenis.getSimplePenisWidth(p)["width"]


func getPenisWidth(top: Vector2, bottom: Vector2, mouth: bool = false) -> float:
	var info: Dictionary = currentPenis.getPenisWidth(top, bottom)
	if mouth:
		inMouthTiltOffset = maxf(-3.0, minf(3.0, info["angOffset"]))
	else:
		inMouthTiltOffset *= 0.5
	return info["width"] * penis.scaleY


func getPosOnPenis(p: Vector2) -> float:
	return currentPenis.getPosOnPenis(p)


func getPenisWidthWithTwitch(mult: float = 1.0) -> float:
	return currentPenisWidthScale * (1.0 + twitchFactor * 0.02 * mult)


func getPenisMinRatio() -> float:
	return maxf(0.0, (1.0 - currentPenisWidthScale) / (1.0 - MIN_PENIS_SIZE))


var currentPenisLength: float:
	get:
		return currentPenisLengthScale * currentPenis.length

var currentPenisFullLength: float:
	get:
		return currentPenis.fullLength

var currentPenisBaseWidth: float:
	get:
		return currentPenis.baseWidth * penis.scaleY


func setBalls(v: int) -> void:
	balls.visible = v != 0 and not bodyHidden
	currentBalls = v
	if g.inGameMenu:
		g.inGameMenu.updateBallsList()


func setBallSize(v: float) -> void:
	currentBallSize = MIN_BALL_SIZE + (MAX_BALL_SIZE - MIN_BALL_SIZE) * v
	balls.scaleX = currentBallSize
	balls.scaleY = currentBallSize


func setBallScale(v: float) -> void:
	currentBallSize = maxf(MIN_BALL_SIZE, minf(MAX_BALL_SIZE, v))
	balls.scaleX = currentBallSize
	balls.scaleY = currentBallSize


var ballSizeSlider: float:
	get:
		return (currentBallSize - MIN_BALL_SIZE) / (MAX_BALL_SIZE - MIN_BALL_SIZE)

var ballSizeScale: float:
	get:
		return currentBallSize


func findArmPosition(n: String, remember: bool = false) -> void:
	for i in armPositions.size():
		if g.dataName(armPositions[i]) == g.dataName(n):
			setArmPosition(i, remember)
			break


func setArmPosition(p: int, remember: bool = false) -> void:
	currentArmPosition = p
	match currentArmPosition:
		0:
			g.handsOff = false
		1:
			g.handsOff = true
			closeHand()
			g.her.setHandsFree()
	if remember:
		lastSelectedArmPosition = currentArmPosition
	g.inGameMenu.updateHisArmList()


func findLeftArmPosition(n: String) -> void:
	for i in leftArmPositions.size():
		if g.dataName(leftArmPositions[i]) == g.dataName(n):
			setLeftArmPosition(i)
			break


func setLeftArmPosition(p: int) -> void:
	currentLeftArmPosition = p
	leftArmContainer.visible = currentLeftArmPosition == 1 and not bodyHidden
	g.inGameMenu.updateHisLeftArmList()
	if Hooks.has(&"Him.setLeftArmPosition"):   # HOOK
		Hooks.after(&"Him.setLeftArmPosition", self, [p])


func resetArmPosition() -> void:
	setArmPosition(lastSelectedArmPosition)


func closeHand() -> void:
	armContainer.arm.hand.gotoAndStop("holding" + g.himSkinType)
	handOpen = false
	if Hooks.has(&"Him.closeHand"):   # HOOK
		Hooks.after(&"Him.closeHand", self)


func openHand() -> void:
	if Hooks.has(&"Him.openHand"):   # HOOK
		var h := Hooks.before(&"Him.openHand", self, [])
		if h.cancelled:
			return
	if not handOpen:
		armContainer.arm.hand.gotoAndPlay("released" + g.himSkinType)
		handOpen = true
	if Hooks.has(&"Him.openHand"):   # HOOK
		Hooks.after(&"Him.openHand", self)


func updateArm() -> void:
	armContainer.arm.upperArm.gotoAndStop(g.himSkinType)
	armContainer.arm.lowerArm.gotoAndStop(g.himSkinType)
	if handOpen:
		armContainer.arm.hand.gotoAndStop("releasedDone" + g.himSkinType)
	else:
		armContainer.arm.hand.gotoAndStop("holding" + g.himSkinType)
	leftArmContainer.arm.gotoAndStop(g.himSkinType)
	leftArmContainer.arm.foreArm.gotoAndStop(g.himSkinType)
	leftArmContainer.arm.foreArm.hand.gotoAndStop(g.himSkinType)


func givePleasure(amount: float) -> void:
	var p := amount * 0.01 if amount > 0 else -amount * 0.01
	pleasure = minf(ejacPleasure + 6.0, pleasure + p)
	buildUp += p
	if Hooks.has(&"Him.givePleasure"):   # HOOK
		Hooks.after(&"Him.givePleasure", self, [amount])


func smearLipstick(p: float, movement: float) -> void:
	if Hooks.has(&"Him.smearLipstick"):   # HOOK
		var h := Hooks.before(&"Him.smearLipstick", self, [p, movement])
		if h.cancelled:
			return
		p = h.args[0]
		movement = h.args[1]
	if lipstickRGB.alphaMultiplier > 0 and lipstickCounter >= 5:
		lipstickCounter = 0
		var ct := FlashColorTransform.new(1, 1, 1, lipstickRGB.alphaMultiplier * randf() * 0.4 + 0.2,
			lipstickRGB.redOffset, lipstickRGB.greenOffset, lipstickRGB.blueOffset)
		var _anchor := getRandomAnchor(p)
		var off := randf()
		off *= off
		if randf() > 0.5:
			off = 80.0 - off * 40.0
		else:
			off *= 40.0
		var m := Transform2D(Vector2(maxf(0.1, randf() * 0.1 - 0.05 + movement * 0.05), 0), Vector2(0, randf() * 0.8 + 0.2),
			Vector2((p - 0.2) * 380.0, off))
		lipstickData.draw(smearGraphic, m, ct)
		lipstickLayer.refresh()
	else:
		lipstickCounter += 1


func clearLipstick() -> void:
	lipstickData.fillRect(Rect2i(0, 0, 350, 100), 0)
	lipstickLayer.refresh()


func resetSpit() -> void:
	deepestPos = 0
	penis.wetMask.x = -600 + 400 * deepestPos


func debugMove(p: Vector2) -> void:
	currentBody.debugMove(p)


func move(p: float, mx: float, my: float) -> void:
	inMouth = g.her.isInMouth()
	if inMouth:
		if mouthConstraintSmoothing < 1:
			mouthConstraintSmoothing = minf(1.0, mouthConstraintSmoothing + 0.4)
	else:
		mouthConstraintSmoothing = 0
	if inMouth:
		penisMask.x = -100 + p * 200
	else:
		penisMask.x = -100
	balls.pushBalls(-currentBody.xDelta * 0.003, twitchFactor * -2.0)
	balls.update()
	penisTiltTarget = 11.0 - p * p * 6.0
	penis.scaleY = getPenisWidthWithTwitch()
	if inMouth:
		penisTiltSpeed += g.her.pushPenisTilt() * 0.5
	else:
		penisTiltTarget += twitchFactor * 6.0
		if g.bukkakeMode:
			penisTiltTarget += -2.5 - my * 15.0
		penisTiltSpeed += g.her.pushPenisTilt()
	if Hooks.has_value(&"Him.penisTiltTarget"):   # HOOK value point: the angle his penis tilts towards (my: mouse y)
		penisTiltTarget = Hooks.value(&"Him.penisTiltTarget", self, penisTiltTarget)
	penisPullScale *= 0.9
	penisTiltSpeed += (penisTiltTarget - penisTilt) / 8.0
	penisTiltSpeed *= 0.5 if inMouth else 0.8
	penisTilt += penisTiltSpeed - inMouthTiltOffset * mouthConstraintSmoothing
	penis.rotation_degrees = maxf(-10.0, minf(25.0, penisTilt))
	if Hooks.has_value(&"Him.penisAngle"):   # HOOK value point: his penis's angle (penisTilt: before the -10..25 limit)
		penis.rotation_degrees = Hooks.value(&"Him.penisAngle", self, penis.rotation_degrees)
	currentBody.move(p, mx, my)
	if pleasure >= ejacPleasure:
		if maxPleasureTimer >= 60:
			ejaculate()
			if ejaculating:   # HOOK: always true in the original; false when Him.ejaculate was vetoed (pleasure kept)
				pleasure = 0
				buildUp = 0
				g.screenEffects.showFlash()
		else:
			g.screenEffects.showPulse()
			maxPleasureTimer += 1
			pleasure = maxf(0.0, pleasure - 0.1)
			g.dialogueControl.buildState(Dialogue.PRE_CUM, Dialogue.TICK_BUILD * 2)
	else:
		g.screenEffects.stopPulse()
		if g.automaticControl.reducePleasureLoss():
			pleasure = maxf(0.0, pleasure - 0.03)
		else:
			pleasure = maxf(0.0, pleasure - 0.05)
		maxPleasureTimer = 0
	g.screenEffects.showWhiteout((pleasure - ejacPleasure + 20.0) * 5.0)
	if p > deepestPos and inMouth:
		deepestPos = p
		penis.wetMask.x = -600 + 400 * deepestPos
		if p > 0.995:
			penis.wetMask.x = -600 + 400 * 1.1
	if twitchFactor > 0:
		twitchFactor *= 0.83
		if twitchFactor <= 0.01:
			twitchFactor = 0
			twitching = false
	if g.bukkakeMode:
		if ejaculating and spurting:
			currentSpurt.detachSourceLink(Vector2(0, 0), 0)
			ejaculating = false
			spurting = false
		if bmEjaculating:
			bmSpurtAngle = 3.0 - my * 1.2
			if bmTimer > 0:
				bmTimer -= 1
				if bmTimer % linkFreq == 0:
					if startedSpurt:
						timerScale = float(bmTimer) / bmTimerStart
						if spurting:
							twitchFactor += 0.2
							if inMouth:
								g.soundControl.switchCumInside()
								spurting = false
								g.her.fillMouth()
								currentSpurt.detachSourceLink(Vector2(0, 0), 0)
							else:
								startSpeed = Vector2(cos(bmSpurtAngle) * (randomSpurtSpeed - randf() * 2.0 + absf(my)),
									sin(bmSpurtAngle) * (randomSpurtSpeed - randf() * 2.0 + absf(my)))
								currentSpurt.insertLink(startSpeed, randomSpurtCollisionDelay + int(floor(timerScale * 2.0)), g.randomCumMass())
								g.soundControl.adjustCumVolume(timerScale, 0.3)
						elif not inMouth:
							g.soundControl.switchCumOutside()
							currentSpurt = g.strandControl.newCumStrand(tipMid, penis)
							spurting = true
						else:
							g.soundControl.adjustCumVolume(timerScale, 0.2)
							g.her.fillMouth()
					else:
						if not inMouth:
							currentSpurt = g.strandControl.newCumStrand(tipMid, penis)
							startedSpurt = true
							spurting = true
						else:
							g.her.lastSpurt()
							startedSpurt = true
						g.her.ejaculating()
						g.soundControl.playCum(inMouth)
						playingCumSound = true
						if not twitching:
							twitchFactor = randf()
							twitching = true
			elif spurting:
				currentSpurt.detachSourceLink(Vector2(0, 0), 0)
				spurting = false
		elif playingCumSound:
			playingCumSound = g.soundControl.fadeCumVolume(0.1)
	elif ejaculating:
		if pauseTimer > 0:
			pauseTimer -= 1
		elif spurtTimer > 0:
			spurtTimer -= 1
			twitchFactor += 0.2
			if spurtTimer % linkFreq == 0:
				if startedSpurt:
					timerScale = float(spurtTimer) / spurtTimerStart
					if spurting:
						if inMouth:
							g.soundControl.switchCumInside()
							spurting = false
							g.her.fillMouth()
							currentSpurt.detachSourceLink(Vector2(0, 0), 0)
						else:
							var ang := randomSpurtAngle + sin(timerScale * PI) * randomSpurtAngleRange
							startSpeed = Vector2(cos(ang) * (randomSpurtSpeed - randf()), sin(ang) * (randomSpurtSpeed - randf()))
							currentSpurt.insertLink(startSpeed, randomSpurtCollisionDelay + int(floor(timerScale * 2.0)), g.randomCumMass())
							g.soundControl.adjustCumVolume(timerScale, 0.3)
					elif not inMouth:
						g.soundControl.switchCumOutside()
						currentSpurt = g.strandControl.newCumStrand(tipMid, penis)
						spurting = true
					else:
						g.soundControl.adjustCumVolume(timerScale, 0.2)
						g.her.fillMouth()
				else:
					if not inMouth:
						currentSpurt = g.strandControl.newCumStrand(tipMid, penis)
						startedSpurt = true
						spurting = true
					else:
						startedSpurt = true
					g.her.ejaculating()
					g.soundControl.playCum(inMouth)
					playingCumSound = true
					if not twitching:
						twitchFactor = randf() + ejaculation.size() / 3.0
						twitching = true
		else:
			if spurting:
				currentSpurt.detachSourceLink(Vector2(cos(randomSpurtAngle) * randomSpurtSpeed, sin(randomSpurtAngle) * randomSpurtSpeed), 0)
			startedSpurt = false
			spurting = false
			if ejaculation.size() > 0:
				if ejaculation.size() == 1:
					g.her.lastSpurt()
				nextSpurt()
			else:
				ejaculating = false
				g.dialogueControl.doneEjaculating()
				g.automaticControl.doneEjaculating()
	elif playingCumSound:
		playingCumSound = g.soundControl.fadeCumVolume()


## Port: how ejaculate() splits his cum into spurts (the game's numbers); a before-hook can change them (args
## [params], e.g. morecumspurts). amount: times the load; build_up: the build-up adds to it; min/max_spurt: spurt
## length in ticks (max plus 0-5 at random; 0: no limit); normal / terminal: [random, fixed] share of what is left per
## spurt (terminal once less than 20 is left); pause: chance of a pause before each spurt after the first.
const EJACULATION := {"amount": 1.0, "build_up": true, "min_spurt": 6, "max_spurt": 21, "normal": [0.2, 0.3],
	"terminal": [0.5, 0.5], "pause": 1.0}


func ejaculate() -> void:
	var p: Dictionary = EJACULATION
	if Hooks.has(&"Him.ejaculate"):   # HOOK
		var h := Hooks.before(&"Him.ejaculate", self, [EJACULATION.duplicate(true)])
		if h.cancelled:
			maxPleasureTimer = 0   # vetoed: the pre-climax wait starts over (no retry every tick)
			return
		p = h.args[0]
	if not ejaculating:
		g.totalFinishes += 1
		var extra := minf(30.0, maxf(0.0, (buildUp - ejacPleasure - 20.0) / 6.0)) if p["build_up"] else 0.0
		var base := floorf(60.0 + randf() * 10.0)
		ejaculation = []
		var done := 0
		var total := int((base + extra) * float(p["amount"]))
		var normal: Array = p["normal"]
		var terminal: Array = p["terminal"]
		var max_spurt: int = p["max_spurt"]
		var pause: float = p["pause"]
		var first := true
		while true:
			var left := total - done
			var size: int
			if left < 20:
				size = int(floor(randf() * left * terminal[0] + left * terminal[1]))
			else:
				size = int(floor(randf() * left * normal[0] + left * normal[1]))
			if max_spurt > 0:
				size = int(minf(floor(randf() * 5 + max_spurt), size))
			var s := maxi(int(p["min_spurt"]), size)
			addRandomSpurt(s, first or (pause < 1.0 and randf() > pause))
			first = false
			done += s
			if done >= total:
				break
		nextSpurt()
		g.automaticControl.ejaculate()
		ejaculating = true


func addRandomSpurt(time: int, first: bool = false) -> void:
	var s := {
		"spurtTimer": time,
		"spurtTimerStart": time,
		"randomSpurtAngle": randf() * 0.8 - 3.3,
		"randomSpurtAngleRange": randf() * 0.4 + 0.1,
		"randomSpurtSpeed": randf() * 15.0 + 25.0,
		"randomSpurtCollisionDelay": int(floor(randf() * 3)) + 1,
		"pauseTimer": 0,
	}
	if not first:
		s["pauseTimer"] = int(floor(randf() * 4 * maxf(1.0, 3.0 - ejaculation.size()) + 5))
	ejaculation.append(s)


func nextSpurt() -> void:
	var s: Dictionary = ejaculation[0]
	spurtTimer = s["spurtTimer"]
	spurtTimerStart = s["spurtTimerStart"]
	randomSpurtAngle = s["randomSpurtAngle"]
	randomSpurtAngleRange = s["randomSpurtAngleRange"]
	randomSpurtSpeed = s["randomSpurtSpeed"]
	randomSpurtCollisionDelay = s["randomSpurtCollisionDelay"]
	pauseTimer = s["pauseTimer"]
	ejaculation.remove_at(0)
	g.her.tongueContainer.tongue.ejaculating()
	if Hooks.has(&"Him.nextSpurt"):   # HOOK
		Hooks.after(&"Him.nextSpurt", self)


func startBMSpurt() -> void:
	if bmEjaculating:
		stopBMSpurt()
	randomSpurtCollisionDelay = int(floor(randf() * 2))
	randomSpurtSpeed = randf() * 5.0 + 25.0
	bmTimer = bmTimerStart
	startedSpurt = false
	spurting = false
	bmEjaculating = true


func stopBMSpurt() -> void:
	if bmEjaculating:
		if spurting:
			currentSpurt.detachSourceLink(Vector2(0, 0), 0)
			spurting = false
		bmEjaculating = false
		startedSpurt = false


func getRandomAnchor(p: float) -> AnchorProp:
	var baseVec := baseB - baseA
	var tipVec := tipB - tipA
	var shaft := tipA - baseA
	var r := randf()
	var along := minf(1.0, 1.0 - (p - 0.2) * (1.0 / 0.8))
	var start := baseA + along * shaft
	var pt := start + r * (1.0 - along) * baseVec + r * along * tipVec
	return AnchorProp.new(pt, penis)


func setHimMenu(menu, rgbItems: Array) -> void:
	characterMenu = menu
	penisControl.registerMenuList(characterMenu.mlPenis)
	penisControl.registerRGBButton(characterMenu.rgbPenis, rgbItems, 489, false)


var currentPenisID: int:
	get:
		return penisControl.selection
