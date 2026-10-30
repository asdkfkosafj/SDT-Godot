class_name HerPenisControl
extends RefCounted
## Port of obj.her.HerPenisControl: her optional strap-on / penis, its sizing and physics.

const DEFAULT_PENIS_SIZE := 0.85
const MIN_PENIS_SIZE := 0.7
const MAX_PENIS_SIZE := 1.2
const SCALING_RANGE := 0.5
const MIN_PENIS_ANGLE := -24.0
const penisNameList := ["None", "Strapon", "Penis A", "Penis B"]

var currentPenisLengthScale: float = 0.85
var currentPenisWidthScale: float = 0.85
var weightScaling: float = 1.0
var penisControl: CharacterElementHelper
var characterMenu = null
var penisMenu = null
var penisContainer
var penis
var angSpeed: float = 0.0
var torsoAngle: float = 0.0
var lastTorsoAngle: float = 0.0
var wearingNone := false


func _init() -> void:
	penisContainer = g.her.torso.penisContainer
	penis = penisContainer.penis
	penis.stop()
	penisControl = CharacterElementHelper.new(penisNameList, setPenis)
	penisControl.setStartRGB(AlphaRGBObject.new(1, 204, 94, 147))
	penisControl.registerComponents([penis], "", false)
	torsoAngle = g.her.rotation_degrees + g.her.torso.rotation_degrees
	lastTorsoAngle = torsoAngle
	g.characterControl.bottomsControl.registerListener(clothingChanged)
	g.characterControl.pantiesControl.registerListener(clothingChanged)
	g.characterControl.legwearControl.registerListener(clothingChanged)
	g.characterControl.legwearBControl.registerListener(clothingChanged)
	updateScaling()


func setMenu(menu, rgbItems: Array) -> void:
	characterMenu = menu
	penisMenu = characterMenu.penisMenu
	penisControl.registerMenuList(menu.mlPenis)
	penisControl.registerRGBButton(menu.rgbPenis, rgbItems, 489, false)
	penisMenu.penisLengthSlider.setRangeEnd(98)
	penisMenu.penisLengthSlider.addEventListener("handleReleased", penisLengthSliderReleased)
	penisMenu.penisLengthSlider.addEventListener("sliderChanged", penisLengthSliderChanged)
	penisMenu.mbDefaultPenisLength.addEventListener(FlashEvent.CLICK, mbDefaultPenisLengthClicked)
	penisMenu.penisWidthSlider.setRangeEnd(98)
	penisMenu.penisWidthSlider.addEventListener("handleReleased", penisWidthSliderReleased)
	penisMenu.penisWidthSlider.addEventListener("sliderChanged", penisWidthSliderChanged)
	penisMenu.mbDefaultPenisWidth.addEventListener(FlashEvent.CLICK, mbDefaultPenisWidthClicked)
	updatePenisWidthSlider()
	updatePenisLengthSlider()
	penisMenu.visible = false
	penisMenu.scaleY = 0
	penisControl.select(0)


func getDataString() -> String:
	if currentPenisID == 0:
		return ""
	return ";herPenis:%s,%s,%s" % [currentPenisID, penisLengthScale, penisWidthScale]


func loadDataPairs(pairs: Array) -> void:
	var found := false
	for pair in pairs:
		match pair[0]:
			"herPenis":
				var vals: PackedStringArray = String(pair[1]).split(",")
				penisControl.select(int(vals[0]))
				if vals.size() == 3:
					loadPenisScales(float(vals[1]), float(vals[2]))
				found = true
	if not found:
		penisControl.select(0)


func clothingChanged(_n: String = "") -> void:
	var cc: CharacterControl = g.characterControl
	wearingNone = cc.bottomsControl.selection == 0 and cc.pantiesControl.selection == 0
	wearingNone = wearingNone and cc.legwearControl.selectedName != "Pantyhose"
	wearingNone = wearingNone and cc.legwearBControl.selectedName != "Pantyhose"
	if throughClothes():
		wearingNone = true
	if not wearingNone:
		penisContainer.rotation_degrees = MIN_PENIS_ANGLE
	updateCostumeVisibility()
	updateScaling()


func _costumeContainers() -> Array:
	var t = g.her.torso
	return [t.chestCostume.bottoms.penisCostumeContainer,
		t.rightThighStocking.stocking.hipLayer.chestStocking.penisCostumeContainer,
		t.rightThighStockingB.stocking.hipLayer.chestStocking.penisCostumeContainer,
		t.chestUnderCostume.panties.penisCostumeContainer]


func updateCostumeVisibility() -> void:
	var shown := currentPenisID != 0 and not throughClothes()
	for c in _costumeContainers():
		c.visible = shown


## Port: her penis sticks out through her clothes (moves freely, the clothes' penis shapes hidden) instead of lying
## against her body under them. The game: false. After changing its modifiers, call clothingChanged().
func throughClothes() -> bool:
	return Hooks.has_value(&"HerPenisControl.throughClothes") and Hooks.value(&"HerPenisControl.throughClothes", self, false)   # HOOK value point


func update() -> void:
	if currentPenisID != 0:
		if wearingNone:
			torsoAngle = g.her.rotation_degrees + g.her.torso.rotation_degrees
			var rest := 0.0
			if Hooks.has_value(&"HerPenisControl.restAngle"):   # HOOK value point: the angle it swings back to (0)
				rest = Hooks.value(&"HerPenisControl.restAngle", self, rest)
			var highest := MIN_PENIS_ANGLE
			if Hooks.has_value(&"HerPenisControl.minAngle"):   # HOOK value point: the furthest it rises (-24)
				highest = Hooks.value(&"HerPenisControl.minAngle", self, highest)
			angSpeed -= (torsoAngle - lastTorsoAngle) * 0.1
			angSpeed -= (penisContainer.rotation_degrees - rest) * 0.1
			angSpeed *= 0.8 + 0.1
			penisContainer.rotation_degrees += angSpeed
			if penisContainer.rotation_degrees < highest:
				penisContainer.rotation_degrees = highest
				angSpeed *= -0.7
			lastTorsoAngle = torsoAngle
		else:
			penisContainer.rotation_degrees = MIN_PENIS_ANGLE - 1.0 * g.her.breathingAnimationAmount
			for c in _costumeContainers():
				updatePenisCostumeRotation(c)


func updatePenisCostumeRotation(c) -> void:
	for i in c.numChildren:
		var ch: FlashDisplayObject = c.getChildAt(i)
		if ch.flash_name == "penisCostume":
			ch.rotation_degrees = penisContainer.rotation_degrees - 27.6


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


func setPenis(_id: int = 0) -> void:
	updatePenis()
	if currentPenisID == penisNameList.find("Strapon"):
		characterMenu.rgbPenis.visible = true
		penisControl.resetFills()
	else:
		characterMenu.rgbPenis.visible = false
	g.characterControl.updateSkinHSL()


func updatePenis() -> void:
	if currentPenisID == 0:
		penis.visible = false
		if penisMenu.visible:
			penisMenu.visible = false
			penisMenu.scaleY = 0
			g.inGameMenu.updateCostumeMenuContent()
		g.strandControl.checkElementAnchors(penisContainer)
	else:
		if not penisMenu.visible:
			penisMenu.visible = true
			penisMenu.scaleY = 1
			g.inGameMenu.updateCostumeMenuContent()
		penis.visible = true
		if currentPenisID == penisNameList.find("Strapon"):
			penis.gotoAndStop(penisNameList[currentPenisID])
		else:
			penis.gotoAndStop("Female" + capitalise(g.characterControl.skinType) + penisNameList[currentPenisID])
		penis.wet.gotoAndStop(penisNameList[currentPenisID])
		penis.lipstickElements.lipstickMask.gotoAndStop(penisNameList[currentPenisID])
	updateCostumeVisibility()
	if Hooks.has(&"HerPenisControl.updatePenis"):   # HOOK
		Hooks.after(&"HerPenisControl.updatePenis", self, [])


func capitalise(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


func loadPenisScales(length: float, width: float) -> void:
	currentPenisLengthScale = maxf(MIN_PENIS_SIZE, minf(MAX_PENIS_SIZE, length))
	currentPenisWidthScale = maxf(MIN_PENIS_SIZE, minf(MAX_PENIS_SIZE, width))
	updatePenisWidthSlider()
	updatePenisLengthSlider()
	updateScaling()


func setPenisLength(v: float) -> void:
	var ratio := currentPenisWidthScale / currentPenisLengthScale
	currentPenisLengthScale = MIN_PENIS_SIZE + (MAX_PENIS_SIZE - MIN_PENIS_SIZE) * v
	currentPenisWidthScale = maxf(MIN_PENIS_SIZE, minf(MAX_PENIS_SIZE, ratio * currentPenisLengthScale))
	updateScaling()


func setPenisWidth(v: float) -> void:
	currentPenisWidthScale = MIN_PENIS_SIZE + (MAX_PENIS_SIZE - MIN_PENIS_SIZE) * v
	updateScaling()


func updateScaling() -> void:
	penisContainer.scaleX = currentPenisLengthScale
	penisContainer.scaleY = currentPenisWidthScale
	weightScaling = (currentPenisLengthScale - MIN_PENIS_SIZE) / SCALING_RANGE * ((currentPenisWidthScale - MIN_PENIS_SIZE) / SCALING_RANGE)
	for c in _costumeContainers():
		updatePenisCostumeScaling(c)


func updatePenisCostumeScaling(c) -> void:
	for i in c.numChildren:
		var ch: FlashDisplayObject = c.getChildAt(i)
		if ch.flash_name == "penisCostume":
			ch.scaleX = currentPenisLengthScale
			ch.scaleY = currentPenisWidthScale


func penisLengthSliderReleased(_e = null) -> void:
	g.saveData.saveCharData()


func penisLengthSliderChanged(_e = null) -> void:
	setPenisLength(penisMenu.penisLengthSlider.currentValue(100) * 0.01)
	updatePenisWidthSlider()


func updatePenisLengthSlider() -> void:
	if penisMenu:
		penisMenu.penisLengthSlider.setPos(penisLengthSlider)


func mbDefaultPenisLengthClicked(_e = null) -> void:
	loadPenisScales(DEFAULT_PENIS_SIZE, penisWidthScale)
	g.saveData.saveCharData()


func penisWidthSliderReleased(_e = null) -> void:
	g.saveData.saveCharData()


func penisWidthSliderChanged(_e = null) -> void:
	setPenisWidth(penisMenu.penisWidthSlider.currentValue(100) * 0.01)


func updatePenisWidthSlider() -> void:
	if penisMenu:
		penisMenu.penisWidthSlider.setPos(penisWidthSlider)


func mbDefaultPenisWidthClicked(_e = null) -> void:
	# (sic) the original resets the width to the current length scale
	loadPenisScales(penisLengthScale, penisLengthScale)
	updatePenisWidthSlider()
	g.saveData.saveCharData()


var currentPenisID: int:
	get:
		return penisControl.selection
