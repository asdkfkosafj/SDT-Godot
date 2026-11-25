class_name HimMaleBody
extends HimBody
## Port of obj.him.bodies.HimMaleBody: male body: leg / arm IK, his hand on her head, skin tone and clothes.

var armPos: float = 0.0
var armSpeed: float = 0.0
var lastX: float = NAN
var xMovement: float = 0.0
var rightArmIK: IKController
var leftArmIK: IKController
var shoulderPoint := Vector2(170, -380)
var leftArmDefaultPoint := Vector2(65, 720)
var leftArmTarget := Vector2(65, 720)
var leftArmSpeed := Vector2()
var mHim = null
var leftLegIK: IKController
var rightLegIK: IKController
var topControl: CharacterElementHelper
var bottomsControl: CharacterElementHelper
var footwearControl: CharacterElementHelper
var topNameList := ["None", "Shirt"]
var bottomsNameList := ["None", "Slacks"]
var footwearNameList := ["None", "Loafers"]
var skinNameList := ["Light", "Dark"]
var currentSkinID: int = 0
var hisSwatch: Array = []


func move(p: float, hand: float, yp: float) -> void:
	super.move(p, hand, yp)
	xMovement = 0.0 if is_nan(lastX) else mHim.origin.x - lastX
	if mHim != null:
		lastX = mHim.origin.x
	mHim = g.animationControl.getHisMatrix(p)
	_him.transform = mHim
	updateLegs()
	_him.overLayer.x = _him.x
	_him.overLayer.y = _him.y
	_him.overLayer.rotation_degrees = _him.rotation_degrees
	_him.overLayer.torso.rotation_degrees = -3.0 + 1.0 * p
	_him.torsoLayer.torso.rotation_degrees = -3.0 + 1.0 * p
	_him.midLayer.hips.rotation_degrees = -3.0 + 1.0 * p
	var armPoint: Vector2 = _him.globalToLocal(g.her.getArmPoint())
	if g.her.isReleased():
		armSpeed += (hand - 0.3 - armPos) / 3.0
		armSpeed *= 0.5
		armPos = maxf(p, armPos + armSpeed)
	else:
		var before := armPos
		armPos = p
		armSpeed = (armPos - before) * 100.0
	var reach := armPos - p
	var arm = _him.armContainer.arm
	_him.armContainer.x = _him.x
	_him.armContainer.rotation_degrees = _him.rotation_degrees
	if g.handsOff:
		arm.x += (80.0 - arm.x) * 0.25
		arm.y += (200.0 - arm.y) * 0.25
		shoulderPoint.x += (170.0 - shoulderPoint.x) * 0.5
		shoulderPoint.y += (-520.0 - shoulderPoint.y) * 0.5
	else:
		if g.her.isReleased():
			arm.x += (armPoint.x + reach * 250.0 - arm.x) * 0.5
			arm.y += (armPoint.y - reach * 30.0 - arm.y) * 0.5
		else:
			arm.x = armPoint.x + reach * 250.0
			arm.y = armPoint.y - reach * 30.0
		shoulderPoint.x = 150.0 + 40.0 * armPos
		shoulderPoint.x += (arm.x + 580.0 - shoulderPoint.x) * 0.5
		shoulderPoint.y = -450.0 - 100.0 * armPos
	if Hooks.has_value(&"HimMaleBody.armPoint"):   # HOOK value point: where his right hand goes this tick (in his arm container)
		var to: Vector2 = Hooks.value(&"HimMaleBody.armPoint", self, Vector2(arm.x, arm.y))
		arm.x = to.x
		arm.y = to.y
	if Hooks.has_value(&"HimMaleBody.shoulderPoint"):   # HOOK value point: the point his right arm's IK aims his shoulder at (his space)
		shoulderPoint = Hooks.value(&"HimMaleBody.shoulderPoint", self, shoulderPoint)
	updateArmPosition()


func updateLegs() -> void:
	leftLegIK.update()
	rightLegIK.update()
	_him.leftLeg.transform = leftLegIK.section1Matrix
	_him.leftLeg.calf.transform = leftLegIK.section2Matrix
	_him.leftLegCostume.transform = leftLegIK.section1Matrix
	_him.leftLegCostume.calf.transform = leftLegIK.section2Matrix
	_him.rightLeg.transform = rightLegIK.section1Matrix
	_him.rightLeg.calf.transform = rightLegIK.section2Matrix
	_him.rightLegCostume.transform = rightLegIK.section1Matrix
	_him.rightLegCostume.calf.transform = rightLegIK.section2Matrix
	_him.leftLeg.calf.foot.transform = leftLegIK.section3Matrix
	_him.rightLeg.calf.foot.transform = rightLegIK.section3Matrix
	_him.leftLegCostume.calf.foot.transform = leftLegIK.section3Matrix
	_him.rightLegCostume.calf.foot.transform = rightLegIK.section3Matrix
	_him.balls.rotation_degrees = _him.leftLeg.rotation_degrees


func updateArmPosition() -> void:
	var arm = _him.armContainer.arm
	rightArmIK.newTarget(shoulderPoint, _him, true)
	rightArmIK.update(Vector2(arm.x, arm.y))
	arm.transform = rightArmIK.section1Matrix
	arm.upperArm.transform = rightArmIK.section2Matrix
	if g.handsOff:
		arm.hand.rotation_degrees *= 0.5
	else:
		var hr: float = g.her.rotation_degrees - arm.rotation_degrees
		if Hooks.has_value(&"HimMaleBody.handRotation"):   # HOOK value point: his right hand's angle on his arm (degrees; the game: along her head)
			hr = Hooks.value(&"HimMaleBody.handRotation", self, hr)
		arm.hand.rotation_degrees = hr
	leftArmSpeed.x += (leftArmDefaultPoint.x - leftArmTarget.x) * 0.1 - xMovement * 0.1
	leftArmSpeed.y += (leftArmDefaultPoint.y - leftArmTarget.y) * 0.1 - absf(xMovement * 0.05)
	leftArmTarget += leftArmSpeed
	leftArmSpeed *= 0.8
	if Hooks.has_value(&"HimMaleBody.leftHand"):   # HOOK value point: where his loose left hand goes this tick
		var to: Vector2 = Hooks.value(&"HimMaleBody.leftHand", self, leftArmTarget)
		if to != leftArmTarget:   # (moved there: his hand swings back from there once let go)
			leftArmTarget = to
			leftArmSpeed = Vector2()
	leftArmIK.newTarget(leftArmTarget, _him)
	leftArmIK.update(null, true)


func debugMove(p: Vector2) -> void:
	super.debugMove(p)
	updateLegs()
	updateArmPosition()


func loadDataPairs(pairs: Array) -> void:
	for pair in pairs:
		match pair[0]:
			"hisSkin":
				setSkin(int(pair[1]))
			"hisTop":
				topControl.loadDataString(pair[1])
			"hisBottoms":
				bottomsControl.loadDataString(pair[1])
			"hisFootwear":
				footwearControl.loadDataString(pair[1])


func getDataString() -> String:
	return "hisSkin:%s;hisTop:%s;hisBottoms:%s;hisFootwear:%s" % [currentSkinID, topControl.getDataString(),
		bottomsControl.getDataString(), footwearControl.getDataString()]


func initElements() -> void:
	rightLegIK = IKController.new(_him, _him.rightLeg, _him.rightLeg.calf, _him.rightLeg.calf.foot)
	rightLegIK.newTarget(g.animationControl.getHisRightFootTarget(), g.sceneLayer, true)
	rightLegIK.rescale(0.9)
	leftLegIK = IKController.new(_him, _him.leftLeg, _him.leftLeg.calf, _him.leftLeg.calf.foot)
	leftLegIK.newTarget(g.animationControl.getHisLeftFootTarget(), g.sceneLayer, true)
	rightArmIK = IKController.new(_him, _him.armContainer.arm, _him.armContainer.arm.upperArm, _him.armContainer.arm.upperArm.shoulderPoint)
	rightArmIK.newTarget(shoulderPoint, _him, true)
	leftArmIK = IKController.new(_him, _him.leftArmContainer.arm, _him.leftArmContainer.arm.foreArm, _him.leftArmContainer.arm.foreArm.hand, true)
	leftArmIK.newTarget(leftArmTarget, _him, true)
	topControl = CharacterElementHelper.new(topNameList, setTop, setTopFill)
	topControl.setStartRGB(AlphaRGBObject.new(1, 238, 242, 245))
	bottomsControl = CharacterElementHelper.new(bottomsNameList, setBottoms, setBottomsFill)
	bottomsControl.setStartRGB(AlphaRGBObject.new(1, 27, 29, 29))
	footwearControl = CharacterElementHelper.new(footwearNameList, setFootwear, setFootwearFill)
	footwearControl.setStartRGB(AlphaRGBObject.new(1, 0, 0, 0))


func initMenu() -> void:
	_bodyMenu = Flash.create("HimMaleBodyMenu")
	hisSwatch = [
		{"r": 22, "g": 8, "b": 0, "a": 1}, {"r": 82, "g": 0, "b": 6, "a": 1}, {"r": 255, "g": 126, "b": 167, "a": 1},
		{"r": 0, "g": 26, "b": 114, "a": 1}, {"r": 63, "g": 118, "b": 162, "a": 1}, {"r": 238, "g": 242, "b": 245, "a": 1},
		{"r": 27, "g": 29, "b": 29, "a": 1}, {"r": 0, "g": 0, "b": 0, "a": 1}, {"r": 255, "g": 255, "b": 255, "a": 1}]
	_bodyMenu.mlSkin.leftArrow.addEventListener(FlashEvent.CLICK, hisSkinLeftClicked)
	_bodyMenu.mlSkin.rightArrow.addEventListener(FlashEvent.CLICK, hisSkinRightClicked)
	topControl.registerMenuList(_bodyMenu.mlTop)
	topControl.registerRGBButton(_bodyMenu.rgbTop, hisSwatch, 489, false)
	bottomsControl.registerMenuList(_bodyMenu.mlBottoms)
	bottomsControl.registerRGBButton(_bodyMenu.rgbBottoms, hisSwatch, 489, false)
	footwearControl.registerMenuList(_bodyMenu.mlFootwear)
	footwearControl.registerRGBButton(_bodyMenu.rgbFootwear, hisSwatch, 489, false)
	updateSkinList()
	topControl.select(1)
	bottomsControl.select(1)
	footwearControl.select(1)


func animationChanged() -> void:
	rightLegIK.newTarget(g.animationControl.getHisRightFootTarget(), g.sceneLayer, true)
	leftLegIK.newTarget(g.animationControl.getHisLeftFootTarget(), g.sceneLayer, true)
	updateLegs()


func toggleBodySettings() -> void:
	if g.him.currentPenisID == 1:
		if currentSkinID == 1:
			g.him.penisControl.select(0)
			setSkin(0)
		else:
			setSkin(1)
	elif currentSkinID == 1:
		g.him.penisControl.select(1)
		setSkin(0)
	else:
		setSkin(1)


func shuffle() -> void:
	g.him.penisControl.select(int(floor(randf() * 2)))
	setSkin(int(floor(randf() * 2)))


func setupElements() -> void:
	setSkin(currentSkinID)
	topControl.resetElement()
	bottomsControl.resetElement()
	footwearControl.resetElement()


func setupAnimation() -> void:
	rightLegIK.newSegments(_him.rightLeg, _him.rightLeg.calf, _him.rightLeg.calf.foot)
	leftLegIK.newSegments(_him.leftLeg, _him.leftLeg.calf, _him.leftLeg.calf.foot)
	rightArmIK.newSegments(_him.armContainer.arm, _him.armContainer.arm.upperArm, _him.armContainer.arm.upperArm.shoulderPoint)
	leftArmIK.newSegments(_him.leftArmContainer.arm, _him.leftArmContainer.arm.foreArm, _him.leftArmContainer.arm.foreArm.hand)


func hisSkinLeftClicked(_e = null) -> void:
	setSkin(maxi(0, mini(skinNameList.size() - 1, currentSkinID - 1)))
	g.saveData.saveCharData()


func hisSkinRightClicked(_e = null) -> void:
	setSkin(maxi(0, mini(skinNameList.size() - 1, currentSkinID + 1)))
	g.saveData.saveCharData()


func updateSkinList() -> void:
	_bodyMenu.mlSkin.itemLabel.text = skinNameList[currentSkinID]


func setSkin(id: int) -> void:
	currentSkinID = id
	g.himSkinType = "Male" + skinNameList[currentSkinID]
	g.him.updatePenis()
	g.him.balls.setSkin(g.himSkinType)
	g.him.updateArm()
	g.him.torsoLayer.torso.gotoAndStop(g.himSkinType)
	g.him.leftLeg.gotoAndStop(g.himSkinType)
	g.him.leftLeg.calf.gotoAndStop(g.himSkinType)
	g.him.leftLeg.calf.foot.gotoAndStop(g.himSkinType)
	g.him.rightLeg.gotoAndStop(g.himSkinType)
	g.him.rightLeg.calf.gotoAndStop(g.himSkinType)
	g.him.rightLeg.calf.foot.gotoAndStop(g.himSkinType)
	updateSkinList()


static func _fill(c) -> FlashColorTransform:
	return FlashColorTransform.new(1, 1, 1, c.a, c.r, c.g, c.b)


func setTop(_id: int = 0) -> void:
	CharacterControl.tryToSetFrameLabel(g.him.topBack, topControl.selectedName)
	CharacterControl.tryToSetFrameLabel(g.him.overLayer.torso.costume, topControl.selectedName)


func setTopFill(c, fillName: String = "rgbFill") -> void:
	var ct := _fill(c)
	CharacterControl.tryToSetFill(g.him.topBack, fillName, ct)
	CharacterControl.tryToSetFill(g.him.overLayer.torso.costume, fillName, ct)


func setBottoms(_id: int = 0) -> void:
	var n: String = bottomsControl.selectedName
	CharacterControl.tryToSetFrameLabel(g.him.rightLegCostume, n)
	CharacterControl.tryToSetFrameLabel(g.him.rightLegCostume.calf, n)
	CharacterControl.tryToSetFrameLabel(g.him.leftLegCostume, n)
	CharacterControl.tryToSetFrameLabel(g.him.leftLegCostume.calf, n)
	CharacterControl.tryToSetFrameLabel(g.him.midLayer.hips, n)


func setBottomsFill(c, fillName: String = "rgbFill") -> void:
	var ct := _fill(c)
	CharacterControl.tryToSetFill(g.him.rightLegCostume, fillName, ct)
	CharacterControl.tryToSetFill(g.him.rightLegCostume.calf, fillName, ct)
	CharacterControl.tryToSetFill(g.him.leftLegCostume, fillName, ct)
	CharacterControl.tryToSetFill(g.him.leftLegCostume.calf, fillName, ct)
	CharacterControl.tryToSetFill(g.him.midLayer.hips, fillName, ct)


func setFootwear(_id: int = 0) -> void:
	CharacterControl.tryToSetFrameLabel(g.him.rightLegCostume.calf.foot, footwearControl.selectedName)
	CharacterControl.tryToSetFrameLabel(g.him.leftLegCostume.calf.foot, footwearControl.selectedName)


func setFootwearFill(c, fillName: String = "rgbFill") -> void:
	var ct := _fill(c)
	CharacterControl.tryToSetFill(g.him.rightLegCostume.calf.foot, fillName, ct)
	CharacterControl.tryToSetFill(g.him.leftLegCostume.calf.foot, fillName, ct)


func _getXDelta() -> float:
	return xMovement
