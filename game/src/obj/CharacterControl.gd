class_name CharacterControl
extends RefCounted
## Port of obj.CharacterControl: the built-in characters and every customisable part of her appearance
## (skin, hair, eyes, costume elements, colours, HSL shifts).

const noseTypeList := ["Normal", "Pointed", "Wedge"]
const earTypeList := ["Normal", "Elf", "Small"]
const eyebrowsTypeList := ["Normal", "Crescent", "Lines"]

var characters: Array = []
var currentChar: int = 0
var defaultCharOrder: Array = []
var currentName := ""
var currentHair: int = 0
var currentIris: int = 0
var currentSkin: int = 0
var currentNose: int = 0
var currentEar: int = 0
var currentEyebrows: int = 0
var irisRGB = {"r": 0, "g": 0, "b": 0, "a": 0}
var lipstickRGB = {"r": 0, "g": 0, "b": 0, "a": 0}
var eyebrowFillRGB = {"r": 0, "g": 0, "b": 0, "a": 0}
var eyebrowLineRGB = {"r": 0, "g": 0, "b": 0, "a": 0}
var eyeShadowRGB = {"r": 0, "g": 0, "b": 0, "a": 0}
var scleraRGB = {"r": 0, "g": 0, "b": 0, "a": 0}
var blushRGB = {"r": 0, "g": 0, "b": 0, "a": 0}
var frecklesRGB = {"r": 0, "g": 0, "b": 0, "a": 0}
var mascaraRGB = {"r": 0, "g": 0, "b": 0, "a": 0}
var nailPolishRGB = {"r": 0, "g": 0, "b": 0, "a": 0}
var breastSize: int = 0
var collarNameList := ["None", "Leather", "Tie", "Gem Choker"]
var gagNameList := ["None", "Ring", "Dental", "Tube"]
var cuffsNameList := ["None", "Leather", "Shirt"]
var ankleCuffsNameList := ["None", "Leather", "Panties", "Left Ribbon", "Right Ribbon", "Left Anklet", "Right Anklet"]
var pantiesNameList := ["None", "Briefs", "Bikini", "Thong", "Side Tie", "High Leg"]
var armwearNameList := ["None", "Wrist Glove", "Elbow Glove"]
var legwearNameList := ["None", "Short Sock", "Sock", "Kneehigh", "Overknee", "Thighhigh", "Pantyhose",
	"Striped Short Sock", "Striped Sock", "Striped Kneehigh", "Striped Overknee", "Striped Thighhigh",
	"Latex Thighhigh", "Garter Belt", "Left Garter", "Right Garter"]
var bottomsNameList := ["None", "Skirt", "Bike Shorts", "Boyshorts", "Jeans", "Jean Shorts", "Miniskirt"]
var footwearNameList := ["None", "Highheel", "School"]
var eyewearNameList := ["None", "Mari", "Pince Nez", "Blindfold", "Leather"]
var topNameList := ["None", "T-Shirt", "Tank", "Cropped", "Cropped Tank", "Shirt"]
var braNameList := ["None", "Bra", "Bikini"]
var tonguePiercingNameList := ["None", "Barbell", "Double", "Ring"]
var nipplePiercingNameList := ["None", "Barbell", "Ring", "Large Ring", "Weight"]
var bellyPiercingNameList := ["None", "Stud", "Ring", "Gem"]
var earringNameList := ["None", "Stud", "Ring", "Ball", "Teardrop", "Feather"]
var headwearNameList := ["None", "Cat Ears", "Bat Wings", "Band", "Ox Horns", "Peach's Crown", "Noel's Cap",
	"Zelda's Circlet"]
var collarControl: CharacterElementHelper
var gagControl: CharacterElementHelper
var cuffsControl: CharacterElementHelper
var ankleCuffsControl: CharacterElementHelper
var eyewearControl: CharacterElementHelper
var pantiesControl: CharacterElementHelper
var armwearControl: CharacterElementHelper
var legwearControl: CharacterElementHelper
var legwearBControl: CharacterElementHelper
var bottomsControl: CharacterElementHelper
var footwearControl: CharacterElementHelper
var topControl: CharacterElementHelper
var braControl: CharacterElementHelper
var tonguePiercingControl: CharacterElementHelper
var nipplePiercingControl: CharacterElementHelper
var bellyPiercingControl: CharacterElementHelper
var earringControl: CharacterElementHelper
var headwearControl: CharacterElementHelper
var blankHSL := {"h": 0, "s": 1, "l": 1, "c": 1}
var hairHSL: Dictionary
var skinHSL: Dictionary
var hisSkinHSL: Dictionary
const skinNameList := [SkinPalette.LIGHT_SKIN, SkinPalette.PALE_SKIN, SkinPalette.TAN_SKIN, SkinPalette.DARK_SKIN]
var skinPalettes: Dictionary = {}
const scalpFills := [{"r": 227, "g": 189, "b": 168}, {"r": 222, "g": 202, "b": 191}, {"r": 241, "g": 182, "b": 138},
	{"r": 118, "g": 79, "b": 52}]
const irisTypeList := ["Normal", "Bright", "Solid", "Blank", "Wide", "Sharp", "Flat", "Cat", "Swirl"]
const breastOffset := [2, 152, 302, 452, 602]
var currentBreastOffset: float
const browOffsets := [0, 199, 399, 599]
const lipOffsets := [2, 82, 162, 242]
var currentSkinType: String
var currentElements: Array = []
var currentElementsStatus: Array = []
var customHairLoaded := false
var customBGLoaded := false
var componentsRegistered := false
var braChangeListeners: Array = []
var breastSizeChangeListeners: Array = []
var waitingToSetHeadwearPosition := false


func _init() -> void:
	currentHair = currentChar
	hairHSL = blankHSL
	skinHSL = blankHSL
	hisSkinHSL = blankHSL
	currentBreastOffset = breastOffset[0]
	currentSkinType = g.dataName(skinNameList[0])
	characters = [SDChan.new(), SDChan2.new(), Asuka.new(), Rei.new(), Mari.new(), Misato.new(), Ino.new(),
		JillValentine.new(), Samus.new(), Misty.new(), Peach.new(), Noel.new(), Android18.new(), Seras.new(),
		TifaLockhart.new(), ZeldaTP.new(), ZeldaSS.new(), Rikku.new(), Nami.new(), HatsuneMiku.new(), Morrigan.new(),
		ChunLi.new()]
	defaultCharOrder = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 15, 18, 19, 20, 21]
	g.baseCharNum = characters.size()
	skinPalettes[SkinPalette.LIGHT_SKIN] = SkinPalette.new(16178890, 14925224, 13541515, 11306097, 13014407, 10974573)
	skinPalettes[SkinPalette.PALE_SKIN] = SkinPalette.new(16050399, 14600895, 13151647, 10126976, 11509658, 9994117, 0.6)
	skinPalettes[SkinPalette.TAN_SKIN] = SkinPalette.new(15916214, 15840906, 14000248, 11962728, 15383719, 14781802)
	skinPalettes[SkinPalette.DARK_SKIN] = SkinPalette.new(10053953, 7753524, 5519398, 4467227, 5451558, 4465690, 0.6)
	collarControl = CharacterElementHelper.new(collarNameList, setCollar, setCollarFill, findCollar)
	collarControl.setDefaultRGB("Gem Choker", null, AlphaRGBObject.new(1, 255, 255, 255))
	collarControl.setDefaultRGB("Tie", null, AlphaRGBObject.new(1, 232, 240, 255))
	gagControl = CharacterElementHelper.new(gagNameList, setGag, setGagFill)
	cuffsControl = CharacterElementHelper.new(cuffsNameList, setCuffs, setCuffsFill)
	cuffsControl.setDefaultRGB("Shirt", null, AlphaRGBObject.new(1, 171, 177, 185))
	ankleCuffsControl = CharacterElementHelper.new(ankleCuffsNameList)
	eyewearControl = CharacterElementHelper.new(eyewearNameList, setEyewear, setEyewearFill)
	pantiesControl = CharacterElementHelper.new(pantiesNameList, setPanties, setPantiesFill)
	armwearControl = CharacterElementHelper.new(armwearNameList, setArmwear, setArmwearFill)
	legwearControl = CharacterElementHelper.new(legwearNameList, setLegwearA, setLegwearFillA)
	legwearBControl = CharacterElementHelper.new(legwearNameList, setLegwearB, setLegwearFillB)
	bottomsControl = CharacterElementHelper.new(bottomsNameList, setBottoms, setBottomsFill)
	topControl = CharacterElementHelper.new(topNameList, setTop, setTopFill)
	footwearControl = CharacterElementHelper.new(footwearNameList, setFootwear, setFootwearFill)
	footwearControl.setDefaultRGB("School", null, AlphaRGBObject.new(1, 254, 248, 238))
	footwearControl.setDefaultRGB("Highheel", null, AlphaRGBObject.new(1, 0, 0, 0))
	braControl = CharacterElementHelper.new(braNameList, setBra, setBraFill)
	tonguePiercingControl = CharacterElementHelper.new(tonguePiercingNameList)
	tonguePiercingControl.setStartRGB(AlphaRGBObject.new(1, 183, 187, 195))
	nipplePiercingControl = CharacterElementHelper.new(nipplePiercingNameList)
	nipplePiercingControl.setStartRGB(AlphaRGBObject.new(1, 183, 187, 195))
	bellyPiercingControl = CharacterElementHelper.new(bellyPiercingNameList)
	bellyPiercingControl.setStartRGB(AlphaRGBObject.new(1, 183, 187, 195))
	earringControl = CharacterElementHelper.new(earringNameList)
	headwearControl = CharacterElementHelper.new(headwearNameList)
	headwearControl.setDefaultRGB("Cat Ears", null, AlphaRGBObject.new(1, 255, 255, 255))
	headwearControl.setDefaultRGB("Bat Wings", AlphaRGBObject.new(1, 24, 24, 24), AlphaRGBObject.new(1, 139, 42, 95))
	headwearControl.setDefaultRGB("Zelda's Circlet", AlphaRGBObject.new(1, 179, 124, 55), AlphaRGBObject.new(1, 62, 142, 193))
	headwearControl.setDefaultRGB("Noel's Cap", AlphaRGBObject.new(1, 47, 56, 221), AlphaRGBObject.new(1, 49, 100, 106))
	headwearControl.setDefaultRGB("Peach's Crown", AlphaRGBObject.new(1, 255, 208, 25))
	headwearControl.setDefaultRGB("Ox Horns", AlphaRGBObject.new(1, 239, 255, 248), AlphaRGBObject.new(1, 254, 210, 26))
	headwearControl.registerListener(waitToSetHeadwearPosition)


static func findName(n: String, list: Array, fn: Callable) -> void:
	for i in list.size():
		if g.dataName(list[i]) == g.dataName(n):
			fn.call(i)
			break


static func tryToSetFrame(mc, frame) -> void:
	if mc:
		mc.gotoAndStop(frame)


static func tryToSetFrameLabel(mc, label: String) -> void:
	if mc:
		if not (mc is FlashMovieClip):
			return  # callers pass `x as MovieClip`, which is null for other display objects
		for fl in mc.currentLabels:
			if fl["name"] == label:
				mc.gotoAndStop(label)
				return
		mc.gotoAndStop("None")


static func tryToSetFill(mc, fillName: String, ct: FlashColorTransform) -> void:
	if mc:
		tryToSetFillChildren(mc, fillName, ct)


static func tryToSetFillChildren(mc, fillName: String, ct: FlashColorTransform) -> void:
	for i in mc.numChildren:
		var c = mc.getChildAt(i)
		if c.flash_name == fillName:
			c.colorTransform = ct
		elif c is FlashSprite:
			tryToSetFillChildren(c, fillName, ct)


static func _ct(c) -> FlashColorTransform:
	return FlashColorTransform.new(1, 1, 1, c.a, c.r, c.g, c.b)


func registerComponents() -> void:
	if componentsRegistered:
		return
	var h: Her = g.her
	collarControl.registerComponents([h.collarContainer.collar])
	gagControl.registerComponents([h.gagFront, h.gagBack])
	cuffsControl.registerComponents([h.torso.cuffs, h.rightForeArmContainer.upperArmCostume.foreArmCostume.cuff,
		h.leftArmContainer.upperArmCostume.foreArmCostume.cuff])
	ankleCuffsControl.registerComponents([h.torso.rightCalfContainer.cuffs, h.leftLegContainer.leg.cuffs])
	eyewearControl.registerComponents([h.eyewear])
	pantiesControl.registerComponents([h.torso.rightThighCostume.panties, h.leftLegContainer.leg.leftThighCostume.panties,
		h.torso.backUnderCostume.panties, h.torso.chestUnderCostume.panties, h.torsoBackCostume.backsideCostume.panties])
	armwearControl.registerComponents([h.torso.leftGlove, h.torso.rightGlove,
		h.rightForeArmContainer.upperArmCostume.foreArmCostume.glove, h.leftArmContainer.upperArmCostume.foreArmCostume.glove,
		h.rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume.glove,
		h.leftArmContainer.upperArmCostume.foreArmCostume.handCostume.glove, h.rightArmContainer.upperArmCostume.glove,
		h.leftArmContainer.upperArmCostume.glove, h.leftHandOver.hand.glove])
	legwearControl.registerComponents([h.torso.rightThighStocking, h.torso.rightCalfContainer.calfStocking,
		h.leftLegContainer.leg.stocking, h.leftLegContainer.leg.calfStocking, h.torsoBackCostume.backsideCostume.stocking])
	legwearBControl.registerComponents([h.torso.rightThighStockingB, h.torso.rightCalfContainer.calfStockingB,
		h.leftLegContainer.leg.stockingB, h.leftLegContainer.leg.calfStockingB, h.torsoBackCostume.backsideCostume.stockingB])
	bottomsControl.registerComponents([h.torso.rightThighBottoms, h.torso.rightThighBottomsOver,
		h.torso.rightCalfContainer.bottoms, h.torso.chestCostume.bottoms, h.torso.backCostume.bottoms,
		h.leftLegContainer.leg.leftThighBottoms, h.leftLegContainer.leg.leftCalfBottoms,
		h.torsoBackCostume.backsideCostume.bottoms], ModTypes.BOTTOMS)
	footwearControl.registerComponents([h.torso.rightCalfContainer.footwear, h.leftLegContainer.leg.footwear], ModTypes.FOOTWEAR)
	topControl.registerComponents([h.torso.topContainer.breastTop, h.torso.topContainer.chestTop,
		h.torso.topContainer.backTop, h.torso.topContainer.topStrap, h.torsoBackCostume.breastCostume.top,
		h.torsoUnderCostume.top, h.rightArmContainer.upperArmCostume.top, h.leftArmContainer.upperArmCostume.top], ModTypes.TOP)
	braControl.registerComponents([h.torso.breastCostume.bra, h.torso.braStrap, h.torso.shoulderStrap,
		h.torso.upperChestCostume.bra, h.torsoBackCostume.breastCostume.bra])
	headwearControl.registerComponents([g.hairCostumeOver.headwear, g.hairCostumeBack.headwear], ModTypes.HEADWEAR)
	tonguePiercingControl.registerComponents([h.tongueContainer.tongue.piercing, h.tongueContainer.tongue.piercingBack,
		h.topLipTongue.piercing, h.topLipTongue.piercingBack], ModTypes.TONGUE_PIERCING)
	nipplePiercingControl.registerComponents([h.torso.nipplePiercing, h.torso.leftNipplePiercing], ModTypes.NIPPLE_PIERCING)
	bellyPiercingControl.registerComponents([h.torso.chestCostume.bellyPiercing], ModTypes.BELLY_PIERCING)
	earringControl.registerComponents([h.earrings], ModTypes.EAR_PIERCING)
	componentsRegistered = true
	CharCode.add_field("wholeTint", "port", _wholeTintField, _loadWholeTint, func(_l): _loadWholeTint("", _l), true)


## Port: the clothing slots by their character-code key.
func costumeSlots() -> Dictionary:
	return {"collar": collarControl, "cuffs": cuffsControl, "ankleCuffs": ankleCuffsControl, "gag": gagControl,
		"panties": pantiesControl, "top": braControl, "armwear": armwearControl, "tops": topControl,
		"bottoms": bottomsControl, "legwear": legwearControl, "legwearB": legwearBControl, "footwear": footwearControl,
		"eyewear": eyewearControl, "headwear": headwearControl, "tonguePiercing": tonguePiercingControl,
		"nipplePiercing": nipplePiercingControl, "bellyPiercing": bellyPiercingControl, "earring": earringControl}


## Code field "wholeTint": the slots whose mod has a whole-piece tint (CharacterElementHelper.wholeHSL / wholeAlpha),
## as "tops=hue|saturation|lightness|contrast|opacity,collar=...".
func _wholeTintField():
	var slots := costumeSlots()
	var out: Array = []
	for k in slots:
		var h: CharacterElementHelper = slots[k]
		if h.isWholeTinted():
			var t := h.wholeHSL
			var n: Array = [t["h"], t["s"], t["l"], t["c"], h.wholeAlpha].map(func(x): return AS3.toString(g.sigRound(3, x)))
			out.append(k + "=" + "|".join(PackedStringArray(n)))
	return ",".join(out) if not out.is_empty() else null


func _loadWholeTint(v: String, _load) -> void:
	var tints := {}
	for part in v.split(",", false):
		var kv := part.split("=")
		var n := kv[1].split("|") if kv.size() == 2 else PackedStringArray()
		if n.size() == 5:
			tints[kv[0]] = [{"h": clampf(n[0].to_float(), -180, 180), "s": clampf(n[1].to_float(), 0, 4),
				"l": clampf(n[2].to_float(), 0, 4), "c": clampf(n[3].to_float(), 0, 4)}, n[4].to_float()]
	var slots := costumeSlots()
	for k in slots:
		if tints.has(k):
			slots[k].setWholeTint(tints[k][0], tints[k][1])
		elif slots[k].isWholeTinted():
			slots[k].clearWholeTint()


func tick() -> void:
	if waitingToSetHeadwearPosition:
		g.characterControl.tryToLandHeadwear()
		waitingToSetHeadwearPosition = false


func addBraChangeListener(fn: Callable) -> void:
	braChangeListeners.append(fn)


func addBreastSizeChangeListener(fn: Callable) -> void:
	breastSizeChangeListeners.append(fn)


func getCurrentSkinType() -> String:
	return currentSkinType


func setChar(id: int, save: bool = true) -> void:
	currentChar = id
	initChar(save)


func initChar(save: bool = true) -> void:
	var c: Character = characters[currentChar]
	g.customElementLoader.clearInstancedMods()
	if not g.inGameMenu.onlyLoadingCostume:
		breastSize = c.breastSize
		currentName = c.charShortName
		if c.dialogue:
			g.dialogueControl.loadCustomDialogue(Dialogue.DIALOGUE_NAME_KEY + ":\"" + c.charShortName + "\"\n" + c.dialogue, save)
		else:
			g.dialogueControl.resetCustomDialogue(save)
		g.her.setBodyScale(c.bodyScale)
		g.her.setMood(c.mood)
		g.inGameMenu.updateBodySlider()
		g.inGameMenu.updateArmsList()
		setSkin(c.skinType)
		setNose(c.noseType)
		setEyebrows(c.eyebrowType)
		findEar(c.earType)
		findIris(c.iris)
		setIrisFill(c.irisFill)
		setHair(currentChar)
	setLipstick(c.lipstickFill)
	setEyeShadow(c.eyeShadow)
	setSclera(c.sclera)
	setBlush(c.blush)
	setFreckles(c.freckles)
	setFreckleAmount(c.freckleAmount)
	setMascara(c.mascara)
	gagControl.findName(c.gag)
	collarControl.select(c.collar)
	collarControl.setFill(c.collarFill, "rgbFill")
	if c.collarFill2:
		collarControl.setFill(c.collarFill2, "rgbFill2")
	cuffsControl.select(c.cuffs)
	cuffsControl.setFill(c.cuffsFill, "rgbFill")
	ankleCuffsControl.findName("None")
	armwearControl.findName(c.armwear)
	armwearControl.setFill(c.armwearFill, "rgbFill")
	bottomsControl.findName("None")
	legwearControl.findName(c.legwear)
	legwearControl.setFill(c.legwearFill, "rgbFill")
	legwearBControl.findName("None")
	eyewearControl.findName(c.eyewear)
	eyewearControl.setFill(c.eyewearFill, "rgbFill")
	footwearControl.findName(c.footwear)
	footwearControl.setFill(c.footwearFill, "rgbFill")
	pantiesControl.findName(c.panties)
	pantiesControl.setFill(c.pantiesFill, "rgbFill")
	braControl.findName(c.bra)
	braControl.setFill(c.braFill, "rgbFill")
	topControl.findName("None")
	headwearControl.findName(c.headwear)
	headwearControl.setFill(c.headwearFill, "rgbFill")
	headwearControl.setFill(c.headwearFill2, "rgbFill2")
	earringControl.findName(c.earring)
	earringControl.setFill(c.earringFill, "rgbFill")
	setNailPolish({"r": 0, "g": 0, "b": 0, "a": 0})
	tonguePiercingControl.findName("None")
	nipplePiercingControl.findName("None")
	bellyPiercingControl.findName("None")
	g.her.tan.setTan(0)
	g.mascaraAmount = 20
	g.inGameMenu.updateMascaraSlider()
	g.inGameMenu.updateFrecklesSlider()
	if not g.inGameMenu.onlyLoadingCostume:
		g.her.setThroatResistance(g.defaultThroatResistance)
		g.inGameMenu.updateThroatResistanceSlider()
		removeHairHSL()
		removeSkinHSL()
		removeHisSkinHSL()
		setBackground(c.bg)
		for i in irisTypeList.size():
			if g.dataName(irisTypeList[i]) == g.dataName(c.iris):
				currentIris = i
				break
		if customBGLoaded:
			g.customElementLoader.clearCustomBackground()
			customBGLoaded = false
		if g.resetIntroOnNewChar:
			g.resetIntro()
		g.inGameMenu.updateCharMenu(currentChar)
		g.inGameMenu.updateMoods()
		g.inGameMenu.setBGCheckboxes()
		g.inGameMenu.updateHairList()
		g.inGameMenu.updateIrisList()
		g.inGameMenu.updateNoseList()
		g.inGameMenu.updateEyebrowsList()
		g.inGameMenu.updateEarList()
		g.inGameMenu.updateBreastSlider()
		g.inGameMenu.updateSkinList()
	g.inGameMenu.closeRGBPicker()
	g.inGameMenu.closeHSLPicker()
	if save:
		g.saveData.saveCharData(true, currentChar)


func loadStoredChar(i: int) -> void:
	currentChar = i + g.baseCharNum
	g.inGameMenu.loadData(g.storedChars[i].charData, true, true, g.storedChars[i])
	currentName = g.storedChars[i].charName
	g.dialogueControl.loadCustomDialogue(g.storedChars[i].dialogue)
	g.inGameMenu.updateCharMenu(i, false, true)


func setBackground(id: int) -> void:
	g.customElementLoader.clearModTypes([ModTypes.BACKGROUND])
	g.bg.gotoAndStop(id)
	g.bgID = id
	g.inGameMenu.bgModIndex = -1  # port: the background picker shows the built-in background again
	g.inGameMenu.updateBGPicker()


func initHim() -> void:
	g.him.initBodies()
	g.him.setBody(g.him.currentBodyID)
	g.him.penisControl.select(g.him.currentPenisID)


func clearElements() -> void:
	for e in currentElements:
		if not is_instance_valid(e):
			continue
		e.removeEventListener("toggled", currentElementToggled)
		e.kill()
	var old := currentElements
	currentElements = []
	for e in old:
		if is_instance_valid(e):
			Flash.dispose_later(e)  # killed earlier while still listed (CostumeElement._can_dispose)
	g.strandControl.checkCostumeAnchors()
	g.costumeHitElements = []


func tryToSetChar(id: int, save: bool = true) -> bool:
	if id >= 0 and id < characters.size():
		setChar(id, save)
		return true
	return false


func resetSkin() -> void:
	setSkin(currentSkin, false)


## Port fix (the Loader did this): body mod pieces with a frame per skin ("light", "pale", "tan", "dark") show her
## skin; the game left them playing through those frames.
func setBodyModSkin() -> void:
	for m in g.customElementLoader.instancedModElements:
		if m.modType != ModTypes.BODY or m._mod == null or not is_instance_valid(m._mod):
			continue
		for p in [m._mod] + (range(m._mod.numChildren).map(func(i): return m._mod.getChildAt(i)) if m._mod is FlashSprite else []):
			if p is FlashMovieClip and p.has_label(currentSkinType):
				p.gotoAndStop(currentSkinType)


func prepForBodyMod() -> void:
	setBreasts()
	setArmSkin()
	g.her.torso.leg.highlights.visible = false
	g.her.torso.backHighlight.visible = false
	g.her.torso.backside.visible = false
	g.her.rightArmContainer.upperArmMask.visible = false
	var hand = g.her.rightForeArmContainer.upperArm.foreArm.hand
	var grip = hand.get("grip")   # not every hand frame has one
	# port fix: only a body mod with its own right hand hides her fingers around him (the game hid them for any body
	# mod, e.g. thighs, until her arm moved)
	if grip and g.customElementLoader.instancedModElements.any(func(m): return m.modType == ModTypes.BODY 			and m._mod != null and is_instance_valid(m._mod) and m._mod._flash_parent == hand):
		grip.visible = false
	g.her.tan.hideForMods()


func setSkin(id: int, clearMods: bool = true) -> void:
	if clearMods:
		g.customElementLoader.clearModTypes([ModTypes.BODY])
	var h: Her = g.her
	currentSkinType = g.dataName(skinNameList[id])
	currentSkin = id
	currentBreastOffset = breastOffset[currentSkin]
	h.ear.gotoAndStop(currentSkinType + earTypeList[currentEar])
	h.head.face.skull.gotoAndStop(currentSkinType)
	h.head.face.nose.gotoAndStop(currentSkinType + noseTypeList[currentNose])
	h.head.cheekSuck.gotoAndStop(currentSkinType)
	h.head.cheekBulge.gotoAndStop(currentSkinType)
	h.head.neck.setSkin(skinPalettes[skinNameList[currentSkin]])
	h.updateNeck()
	h.head.scalpHair.colorTransform = FlashColorTransform.new(1, 1, 1, 1, scalpFills[id]["r"], scalpFills[id]["g"], scalpFills[id]["b"])
	setArmSkin(clearMods)
	h.torso.midLayer.leftArm.gotoAndStop(currentSkinType)
	h.torso.behindBackRightArm.gotoAndStop(currentSkinType)
	if h.leftHandOver.hand.get("grip"):
		h.leftHandOver.hand.grip.gotoAndStop(currentSkinType + "Grip")
	h.torso.back.gotoAndStop(currentSkinType)
	h.torsoBack.chestBack.gotoAndStop(currentSkinType)
	h.torsoBack.leftShoulder.gotoAndStop(currentSkinType)
	h.torso.leg.thigh.gotoAndStop(currentSkinType)
	h.torso.rightCalfContainer.calf.gotoAndStop(currentSkinType)
	h.leftLegContainer.leg.thigh.gotoAndStop(currentSkinType)
	h.leftLegContainer.leg.calf.gotoAndStop(currentSkinType)
	h.torsoBack.backside.gotoAndStop(currentSkinType)
	h.torso.backside.gotoAndStop(currentSkinType)
	h.torso.leg.highlights.visible = true
	h.torso.backHighlight.visible = true
	h.torso.backside.visible = true
	h.rightArmContainer.upperArmMask.visible = true
	setBreasts(breastSize)
	h.setLipSkinOffset(lipOffsets[id])
	setLipFills()
	h.eye.eyebrowUnderMask.gotoAndStop(currentSkinType)
	h.updateEyes()
	h.updateLips()
	h.updateJawBulge()
	h.tan.updateSkin(skinNameList[id])
	h.penisControl.updatePenis()
	g.strandControl.checkElementAnchors(h.torso.midLayer.rightBreast)
	setBodyModSkin()   # port fix, see setBodyModSkin
	if Hooks.has(&"CharacterControl.setSkin"):   # HOOK
		Hooks.after(&"CharacterControl.setSkin", self, [id, clearMods])


func setLipFills() -> void:
	var p: SkinPalette = skinPalettes[skinNameList[currentSkin]]
	g.her.head.face.lipFill.colorTransform = FlashColorTransform.new(1, 1, 1, 1, p.shade1.r, p.shade1.g, p.shade1.b)
	g.her.head.face.lipShading.alpha = p.lipAlpha


func setArmSkin(force: bool = false) -> void:
	var h: Her = g.her
	setArmFrame(h.rightArmContainer.upperArm, h.isRightArmFree(), force)
	setArmFrame(h.rightForeArmContainer.upperArm.foreArm, h.isRightArmFree(), force)
	setArmFrame(h.rightForeArmContainer.upperArm.foreArm.hand, h.isRightArmFree(), force, g.rightHandJobMode or h.rightHandClosed)
	if h.rightForeArmContainer.upperArm.foreArm.hand.get("grip"):
		h.rightForeArmContainer.upperArm.foreArm.hand.grip.visible = true
		h.rightForeArmContainer.upperArm.foreArm.hand.grip.gotoAndStop(currentSkinType)
	setArmFrame(h.leftArmContainer.upperArm, h.isLeftArmFree(), force)
	setArmFrame(h.leftArmContainer.upperArm.foreArm, h.isLeftArmFree(), force)
	setArmFrame(h.leftArmContainer.upperArm.foreArm.hand, h.isLeftArmFree(), force, g.leftHandJobMode or h.leftHandClosed)
	h.leftArmContainer.upperArmCostume.foreArmCostume.handCostume.nailPolish.visible = not h.leftHandClosed
	h.rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume.nailPolish.visible = not h.rightHandClosed
	armwearControl.resetElement()
	if h._tan:   # port fix, see Tan.updateArms
		h._tan.updateArms()


func setArmFrame(mc, free: bool, force: bool = false, grip: bool = false) -> void:
	var label: String = mc.currentFrameLabel if mc.currentFrameLabel != "" else currentSkinType
	label = label.replace("Free", "").replace("Grip", "")
	if label != "None" or force:
		label = currentSkinType
	if grip:
		label += "Grip"
	else:
		label += "Free" if free else ""
	mc.gotoAndStop(label)


func findHair(n: String, force: bool = true) -> bool:
	if force or not customHairLoaded:
		for i in characters.size():
			if g.dataName(n) == g.dataName(characters[i].charShortName):
				setHair(i)
				return true
	return false


func setHair(id: int, withEyebrows: bool = true) -> void:
	if customHairLoaded:
		g.customElementLoader.clearCustomHair(false)
		customHairLoaded = false
	g.customElementLoader.clearModTypes([ModTypes.HAIR, ModTypes.DYNAMIC_HAIR, ModTypes.HAIR_COSTUME])
	clearElements()
	g.inGameMenu.hairModIndex = -1  # port: the hair picker is on a built-in hairstyle again
	var c: Character = characters[id]
	g.her.hairTop.gotoAndStop(c.hairTop)
	g.her.hairMidContainer.hairUnder.gotoAndStop(c.hairUnder)
	g.her.hairMidContainer.hairBottom.gotoAndStop(c.hairBottom)
	g.her.hairBackContainer.hairBack.gotoAndStop(c.hairBack)
	if withEyebrows:
		setEyebrowFill(c.eyebrowFill)
		setEyebrowLine(c.eyebrowLine)
	currentElements = c.generateElements()
	for e in currentElements:
		e.addEventListener("toggled", currentElementToggled)
	updateCurrentElementsStatus()
	waitToSetHeadwearPosition()
	currentHair = id
	if Hooks.has(&"CharacterControl.setHair"):   # HOOK
		Hooks.after(&"CharacterControl.setHair", self, [id, withEyebrows])


func currentElementToggled(_e = null) -> void:
	updateCurrentElementsStatus()
	g.saveData.saveCharData()


func updateCurrentElementsStatus() -> void:
	currentElementsStatus = []
	for e in currentElements:
		currentElementsStatus.append(e.showingString())


func setCurrentElements(status: Array) -> void:
	if not customHairLoaded:
		if status.size() == currentElements.size():
			for i in status.size():
				if status[i] == "0":
					currentElements[i].tryToHide()
	updateCurrentElementsStatus()


func randomCurrentElements() -> void:
	for e in currentElements:
		if randf() < 0.5:
			e.tryToHide()
	updateCurrentElementsStatus()


func setEyebrowFill(c, _n: String = "rgbFill") -> void:
	var ct := _ct(c)
	g.her.rightEyebrow.rightEyebrowFill.colorTransform = ct
	g.her.leftEyebrow.leftEyebrowFill.colorTransform = ct
	eyebrowFillRGB = c
	if Hooks.has(&"CharacterControl.setEyebrowFill"):   # HOOK
		Hooks.after(&"CharacterControl.setEyebrowFill", self, [c, _n])


func setEyebrowLine(c, _n: String = "rgbFill") -> void:
	var ct := _ct(c)
	g.her.rightEyebrow.rightEyebrowLine.colorTransform = ct
	g.her.leftEyebrow.leftEyebrowLine.colorTransform = ct
	eyebrowLineRGB = c
	if Hooks.has(&"CharacterControl.setEyebrowLine"):   # HOOK
		Hooks.after(&"CharacterControl.setEyebrowLine", self, [c, _n])


func findNose(n: String) -> void:
	findName(n, noseTypeList, setNose)


func setNose(id: int) -> void:
	g.her.head.face.nose.gotoAndStop(currentSkinType + noseTypeList[id])
	g.her.head.headTan.face.nose.gotoAndStop(currentSkinType + noseTypeList[id])
	currentNose = id


func findEyebrows(n: String) -> void:
	findName(n, eyebrowsTypeList, setEyebrows)


func setEyebrows(id: int) -> void:
	g.her.rightEyebrow.gotoAndStop(eyebrowsTypeList[id])
	g.her.leftEyebrow.gotoAndStop(eyebrowsTypeList[id])
	setEyebrowFill(eyebrowFillRGB)
	setEyebrowLine(eyebrowLineRGB)
	g.her.updateEyes()
	currentEyebrows = id


func findEar(n: String) -> void:
	findName(n, earTypeList, setEar)


func setEar(id: int) -> void:
	g.her.ear.gotoAndStop(currentSkinType + earTypeList[id])
	g.her.ear.tan.gotoAndStop(earTypeList[id])
	currentEar = id


func findIris(n: String) -> bool:
	for i in irisTypeList.size():
		if g.dataName(n) == g.dataName(irisTypeList[i]):
			setIris(i)
			return true
	return false


func setIris(id: int) -> void:
	g.her.blankEyed = g.dataName(irisTypeList[id]) == "blank"
	g.her.eye.ball.irisContainer.iris.gotoAndStop(g.dataName(irisTypeList[id]))
	g.her.eye.ball.irisContainer.iris.irisFill.gotoAndStop(g.dataName(irisTypeList[id]))
	currentIris = id
	g.her.eye.ball.highlights.visible = id != 3


func setEyeShadow(c, _n: String = "rgbFill") -> void:
	g.her.eye.upperEyelid.eyeshadow.colorTransform = _ct(c)
	eyeShadowRGB = c


func setSclera(c, _n: String = "rgbFill") -> void:
	g.her.eye.ball.sclera.overlay.colorTransform = _ct(c)
	scleraRGB = c


func setBlush(c, _n: String = "rgbFill") -> void:
	g.her.blush.colorTransform = _ct(c)
	blushRGB = c
	if Hooks.has(&"CharacterControl.setBlush"):   # HOOK
		Hooks.after(&"CharacterControl.setBlush", self)


func setFreckles(c, _n: String = "rgbFill") -> void:
	g.her.freckles.colorTransform = _ct(c)
	frecklesRGB = c


func setFreckleAmount(v: float) -> void:
	v = Maths.round(maxf(0.0, minf(100.0, v)))
	if v != g.frecklesAmount:
		g.frecklesAmount = v
		g.her.setFreckleAmount(g.frecklesAmount)


func setMascara(c, _n: String = "rgbFill") -> void:
	var ct := _ct(c)
	g.her.eye.upperEyelid.mascara.colorTransform = ct
	g.her.eye.lowerEyelid.mascara.colorTransform = ct
	g.her.tears.setMascaraRGB({"r": c.r, "g": c.g, "b": c.b, "a": c.a})
	mascaraRGB = c


func findSkin(n: String) -> bool:
	for i in skinNameList.size():
		if g.dataName(n) == g.dataName(skinNameList[i]):
			setSkin(i)
			return true
	return false


func setBreasts(size: int = -1) -> void:
	if size == -1:
		size = breastSize
	breastSize = size
	var h: Her = g.her
	FlashShape.load_now = true   # port: the new size shows at once in every part (no streaming lag, issue #1)
	setBreastFrame(h.torso.midLayer.chest)
	setBreastFrame(h.torsoBack.leftBreast)
	setBreastFrame(h.torso.midLayer.rightBreast)
	if h.torsoBack.leftBreast.nipple.getChildByName("leftNipple"):
		h.torsoBack.leftBreast.nipple.gotoAndStop("None")
	else:
		h.torsoBack.leftBreast.nipple.gotoAndStop(currentSkinType)
	if h.torso.midLayer.rightBreast.nipple.getChildByName("rightNipple"):
		h.torso.midLayer.rightBreast.nipple.gotoAndStop("None")
	else:
		h.torso.midLayer.rightBreast.nipple.gotoAndStop(currentSkinType)
	setBreastCostumeSize()
	for fn in breastSizeChangeListeners:
		fn.call()
	FlashShape.load_now = false


func setBreastFrame(mc) -> void:
	var inner = mc.getChildByName(mc.flash_name)
	if inner:
		# port fix (sby's bodymodpatch): only a body mod that overwrites hides her own breast / chest (the game
		# hid it for any body mod piece placed there)
		mc.gotoAndStop(breastOffset[4] if _bodyModOverwrites(mc) else int(currentBreastOffset + breastSize))
		if inner is FlashMovieClip:
			setChildrenFrame(inner, 2 + breastSize)
	else:
		setChildrenFrame(mc, 2 + breastSize)
		mc.gotoAndStop(int(currentBreastOffset + breastSize))


func _bodyModOverwrites(target) -> bool:
	for m in g.customElementLoader.instancedModElements:
		if m.overwrite and m.modType == ModTypes.BODY and m._mod != null and is_instance_valid(m._mod) 				and m._mod._flash_parent == target:
			return true
	return false


func setBreastCostumeSize() -> void:
	var h: Her = g.her
	for c in [h.torso.breastCostume.bra, h.torso.braStrap, h.torso.upperChestCostume.bra, h.torsoBackCostume.breastCostume.bra,
			h.torso.topContainer.breastTop, h.torso.topContainer.chestTop, h.torsoBackCostume.breastCostume.top]:
		setChildrenFrame(c, 2 + breastSize)
	if Hooks.has(&"CharacterControl.setBreastCostumeSize"):   # HOOK
		Hooks.after(&"CharacterControl.setBreastCostumeSize", self, [])


func setChildrenFrame(target, frame: int) -> void:
	for i in target.numChildren:
		var c = target.getChildAt(i)
		if c is FlashMovieClip:
			if c.flash_name != "tan" and c.flash_name != "nipple":
				c.gotoAndStop(frame)
			setChildrenFrame(c, frame)


func setIrisFill(c, _n: String = "rgbFill") -> void:
	g.her.eye.ball.irisContainer.iris.irisFill.colorTransform = FlashColorTransform.new(1, 1, 1, 1, c.r, c.g, c.b)
	g.her.eye.ball.irisContainer.iris.alpha = c.a
	irisRGB = c


func setLipstick(c, _n: String = "rgbFill") -> void:
	var ct := _ct(c)
	g.her.bottomLipstick.colorTransform = ct
	g.her.topLipstickContainer.colorTransform = ct
	g.him.lipstickRGB = ct
	lipstickRGB = c
	if Hooks.has(&"CharacterControl.setLipstick"):   # HOOK
		Hooks.after(&"CharacterControl.setLipstick", self, [c, _n])


func setNailPolish(c, _n: String = "rgbFill") -> void:
	var ct := _ct(c)
	var h: Her = g.her
	h.torso.nailPolish.colorTransform = ct
	h.leftArmContainer.upperArmCostume.foreArmCostume.handCostume.nailPolish.colorTransform = ct
	h.rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume.nailPolish.colorTransform = ct
	h.leftHandOver.hand.nailPolish.colorTransform = ct
	nailPolishRGB = c


func findCollar(n: String) -> void:
	if n == "Red Tie":
		n = "Tie"
	if n.is_valid_float():
		var v := int(floor(float(n)))
		if v >= 0 and v < collarNameList.size():
			setCollar(v)
	else:
		findName(n, collarNameList, collarControl.select)


func setCollar(id: int) -> void:
	g.customElementLoader.clearModTypes([ModTypes.COLLAR])
	g.her.collarContainer.collar.gotoAndStop(collarNameList[id])


func setCollarFill(c, n: String = "rgbFill") -> void:
	tryToSetFill(g.her.collarContainer.collar, n, _ct(c))


func setGag(id: int) -> void:
	g.customElementLoader.clearModTypes([ModTypes.GAG])
	g.her.gagFront.gotoAndStop(gagNameList[id])
	g.her.gagBack.gotoAndStop(gagNameList[id])
	g.her.setGagged(id != 0)


func setGagFill(c, n: String = "rgbFill") -> void:
	var ct := _ct(c)
	tryToSetFill(g.her.gagFront, n, ct)
	tryToSetFill(g.her.gagBack, n, ct)


func setCuffs(id: int) -> void:
	g.her.torso.cuffs.gotoAndStop(cuffsNameList[id])
	g.her.rightForeArmContainer.upperArmCostume.foreArmCostume.cuff.gotoAndStop(cuffsNameList[id])
	g.her.leftArmContainer.upperArmCostume.foreArmCostume.cuff.gotoAndStop(cuffsNameList[id])


func setCuffsFill(c, n: String = "rgbFill") -> void:
	var ct := _ct(c)
	tryToSetFill(g.her.torso.cuffs, n, ct)
	tryToSetFill(g.her.rightForeArmContainer.upperArmCostume.foreArmCostume.cuff, n, ct)
	tryToSetFill(g.her.leftArmContainer.upperArmCostume.foreArmCostume.cuff, n, ct)


func setFootwear(id: int) -> void:
	g.her.torso.rightCalfContainer.footwear.gotoAndStop(footwearNameList[id])
	g.her.leftLegContainer.leg.footwear.gotoAndStop(footwearNameList[id])


func setFootwearFill(c, n: String = "rgbFill") -> void:
	var ct := _ct(c)
	tryToSetFill(g.her.torso.rightCalfContainer.footwear, n, ct)
	tryToSetFill(g.her.leftLegContainer.leg.footwear, n, ct)


func setEyewear(_id: int) -> void:
	g.customElementLoader.clearModTypes([ModTypes.EYEWEAR])
	g.her.eyewear.gotoAndStop(eyewearNameList[eyewearControl.selection])
	g.strandControl.checkElementAnchors(g.her.eyewear)


func setEyewearFill(c, n: String = "rgbFill") -> void:
	tryToSetFill(g.her.eyewear, n, _ct(c))


func _pantiesParts() -> Array:
	var h: Her = g.her
	return [h.torso.rightThighCostume.panties, h.leftLegContainer.leg.leftThighCostume.panties,
		h.torso.backUnderCostume.panties, h.torso.chestUnderCostume.panties, h.torsoBackCostume.backsideCostume.panties]


func setPanties(_id: int) -> void:
	for p in _pantiesParts():
		p.gotoAndStop(pantiesNameList[pantiesControl.selection])


func setPantiesFill(c, n: String = "rgbFill") -> void:
	var ct := _ct(c)
	for p in _pantiesParts():
		tryToSetFill(p, n, ct)


func setBra(_id: int) -> void:
	var h: Her = g.her
	var label: String = braNameList[braControl.selection]
	h.torso.breastCostume.bra.gotoAndStop(label)
	h.torso.braStrap.gotoAndStop(label)
	h.torso.shoulderStrap.gotoAndStop(label)
	h.torso.upperChestCostume.bra.gotoAndStop(label)
	h.torsoBackCostume.breastCostume.bra.gotoAndStop(label)
	setBreastCostumeSize()
	for fn in braChangeListeners:
		fn.call(label)


func setTop(_id: int) -> void:
	var h: Her = g.her
	var n: String = topControl.selectedName
	tryToSetFrameLabel(h.torso.topContainer.breastTop, n)
	tryToSetFrameLabel(h.torso.topContainer.chestTop, n)
	tryToSetFrameLabel(h.torso.topContainer.backTop, n)
	tryToSetFrameLabel(h.torso.topContainer.topStrap, n)
	tryToSetFrameLabel(h.torsoBackCostume.breastCostume.top, n)
	tryToSetFrameLabel(h.torsoUnderCostume.top, n)
	var leftLabel := n + ("Free" if h.isLeftArmFree() else "")
	var rightLabel := n + ("Free" if h.isRightArmFree() else "")
	tryToSetFrameLabel(h.rightArmContainer.upperArmCostume.top, rightLabel)
	tryToSetFrameLabel(h.rightArmEraseContainer.upperArmCostume.top, rightLabel)
	tryToSetFrameLabel(h.leftArmContainer.upperArmCostume.top, leftLabel)
	setBreastCostumeSize()


func setTopFill(c, n: String = "rgbFill") -> void:
	var h: Her = g.her
	var ct := _ct(c)
	var opaque := FlashColorTransform.new(1, 1, 1, 1, c.r, c.g, c.b)
	# port fix: the see-through alpha (on the containers) and the outline belong to the top's main colour; a second
	# colour (rgbFill2, mods) only colours its own parts
	if n == "rgbFill":
		var cmf := FlashFilter.colorMatrix([1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, c.a, 0])
		h.torso.topContainer.filters = [cmf]
		h.torsoBackCostume.breastCostume.top.filters = [cmf]
	tryToSetFill(h.torso.topContainer.breastTop, n, opaque)
	tryToSetFill(h.torso.topContainer.chestTop, n, opaque)
	tryToSetFill(h.torso.topContainer.backTop, n, opaque)
	tryToSetFill(h.torso.topContainer.topStrap, n, opaque)
	tryToSetFill(h.torsoBackCostume.breastCostume.top, n, ct)
	tryToSetFill(h.torsoUnderCostume.top, n, ct)
	tryToSetFill(h.rightArmContainer.upperArmCostume.top, n, ct)
	tryToSetFill(h.leftArmContainer.upperArmCostume.top, n, ct)
	if n == "rgbFill":
		var outline := FlashColorTransform.new(1, 1, 1, 1, c.r * 0.5, c.g * 0.5, c.b * 0.5)
		tryToSetFill(h.torso.topContainer.breastTop, "outline", outline)
		tryToSetFill(h.torsoBackCostume.breastCostume.top, "outline", outline)
	if Hooks.has(&"CharacterControl.setTopFill"):   # HOOK
		Hooks.after(&"CharacterControl.setTopFill", self, [c, n])


func setBraFill(c, n: String = "rgbFill") -> void:
	var h: Her = g.her
	var ct := _ct(c)
	for p in [h.torso.breastCostume.bra, h.torso.braStrap, h.torso.shoulderStrap, h.torso.upperChestCostume.bra,
			h.torsoBackCostume.breastCostume.bra]:
		tryToSetFill(p, n, ct)


func setArmwear(id: int) -> void:
	var h: Her = g.her
	var label: String = armwearNameList[id]
	tryToSetFrameLabel(h.rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume, "Grip" if g.rightHandJobMode or h.rightHandClosed else "Free")
	tryToSetFrameLabel(h.leftArmContainer.upperArmCostume.foreArmCostume.handCostume, "Grip" if g.leftHandJobMode or h.leftHandClosed else "Free")
	tryToSetFrameLabel(h.rightForeArmContainer.upperArmCostume.foreArmCostume.glove, label)
	tryToSetFrameLabel(h.leftArmContainer.upperArmCostume.foreArmCostume.glove, label)
	tryToSetFrameLabel(h.rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume.glove, label)
	tryToSetFrameLabel(h.leftArmContainer.upperArmCostume.foreArmCostume.handCostume.glove, label)
	tryToSetFrameLabel(h.torso.leftGlove, label)
	tryToSetFrameLabel(h.torso.rightGlove, label)
	tryToSetFrameLabel(h.leftHandOver.hand.glove, label)
	var leftLabel := label + ("Free" if h.isLeftArmFree() else "")
	var rightLabel := label + ("Free" if h.isRightArmFree() else "")
	tryToSetFrameLabel(h.rightArmContainer.upperArmCostume.glove, rightLabel)
	tryToSetFrameLabel(h.rightArmEraseContainer.upperArmCostume.glove, rightLabel)
	tryToSetFrameLabel(h.leftArmContainer.upperArmCostume.glove, leftLabel)


func setArmwearFill(c, n: String = "rgbFill") -> void:
	var h: Her = g.her
	var ct := _ct(c)
	for p in [h.torso.leftGlove, h.torso.rightGlove, h.rightForeArmContainer.upperArmCostume.foreArmCostume.glove,
			h.leftArmContainer.upperArmCostume.foreArmCostume.glove,
			h.rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume.glove,
			h.leftArmContainer.upperArmCostume.foreArmCostume.handCostume.glove, h.rightArmContainer.upperArmCostume.glove,
			h.leftArmContainer.upperArmCostume.glove, h.leftHandOver.hand.glove]:
		tryToSetFill(p, n, ct)
	if Hooks.has(&"CharacterControl.setArmwearFill"):   # HOOK
		Hooks.after(&"CharacterControl.setArmwearFill", self, [c, n])


func _bottomsParts() -> Array:
	var h: Her = g.her
	return [h.torso.rightThighBottoms, h.torso.rightThighBottomsOver, h.torso.rightCalfContainer.bottoms,
		h.torso.chestCostume.bottoms, h.torso.backCostume.bottoms, h.leftLegContainer.leg.leftThighBottoms,
		h.leftLegContainer.leg.leftCalfBottoms, h.torsoBackCostume.backsideCostume.bottoms]


func setBottoms(_id: int) -> void:
	for p in _bottomsParts():
		tryToSetFrameLabel(p, bottomsControl.selectedName)


func setBottomsFill(c, n: String = "rgbFill") -> void:
	var ct := _ct(c)
	for p in _bottomsParts():
		tryToSetFill(p, n, ct)


func setLegwearFillA(c, n: String = "rgbFill") -> void:
	setLegwearFill(legwearControl, "", c, n)


func setLegwearFillB(c, n: String = "rgbFill") -> void:
	setLegwearFill(legwearBControl, "B", c, n)


func setLegwearA(id: int) -> void:
	setLegwear(legwearControl, id, "")


func setLegwearB(id: int) -> void:
	setLegwear(legwearBControl, id, "B")


func setLegwear(control: CharacterElementHelper, _id: int, suffix: String) -> void:
	var h: Her = g.her
	var label: String = legwearNameList[control.selection]
	var thigh = h.torso.get("rightThighStocking" + suffix)
	tryToSetFrameLabel(thigh.stocking, label)
	tryToSetFrameLabel(thigh.stocking.hipLayer.backStocking, label)
	tryToSetFrameLabel(thigh.stocking.hipLayer.chestStocking, label)
	tryToSetFrameLabel(thigh.stocking.hipOverLayer.backStocking, label)
	tryToSetFrameLabel(thigh.stocking.hipOverLayer.chestStocking, label)
	tryToSetFrameLabel(thigh.stocking2, label)
	tryToSetFrameLabel(thigh.stocking2.hipLayer.backStocking, label)
	tryToSetFrameLabel(thigh.stocking2.hipLayer.chestStocking, label)
	tryToSetFrameLabel(h.torso.rightCalfContainer.get("calfStocking" + suffix), label)
	tryToSetFrameLabel(h.leftLegContainer.leg.get("stocking" + suffix), label)
	tryToSetFrameLabel(h.leftLegContainer.leg.get("calfStocking" + suffix), label)
	tryToSetFrameLabel(h.torsoBackCostume.backsideCostume.get("stocking" + suffix), label)


func setLegwearFill(control: CharacterElementHelper, suffix: String, c, n: String = "rgbFill") -> void:
	var h: Her = g.her
	var ct := _ct(c)
	var thighCt := ct
	var cmf := FlashFilter.colorMatrix([1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, c.a, 0])
	var thigh = h.torso.get("rightThighStocking" + suffix)
	if n == "rgbFill":
		if control.selectedName == "Pantyhose" or control.selectedName == "Garter Belt":
			thighCt = FlashColorTransform.new(1, 1, 1, 1, c.r, c.g, c.b)
			thigh.stocking.filters = [cmf]
			thigh.stocking2.filters = [cmf]
		else:
			thigh.stocking.filters = []
			thigh.stocking2.filters = []
	tryToSetFill(thigh.stocking, n, thighCt)
	tryToSetFill(thigh.stocking.hipLayer.backStocking, n, thighCt)
	tryToSetFill(thigh.stocking.hipLayer.chestStocking, n, thighCt)
	tryToSetFill(thigh.stocking.hipOverLayer.backStocking, n, thighCt)
	tryToSetFill(thigh.stocking.hipOverLayer.chestStocking, n, thighCt)
	tryToSetFill(thigh.stocking2, n, thighCt)
	tryToSetFill(thigh.stocking2.hipLayer.backStocking, n, thighCt)
	tryToSetFill(thigh.stocking2.hipLayer.chestStocking, n, thighCt)
	tryToSetFill(h.torso.rightCalfContainer.get("calfStocking" + suffix), n, ct)
	tryToSetFill(h.leftLegContainer.leg.get("stocking" + suffix), n, ct)
	tryToSetFill(h.leftLegContainer.leg.get("calfStocking" + suffix), n, ct)
	tryToSetFill(h.torsoBackCostume.backsideCostume.get("stocking" + suffix), n, ct)


func findTonguePiercing(n: String) -> void:
	findName(n, tonguePiercingNameList, tonguePiercingControl.select)


func waitToSetHeadwearPosition(_n = null) -> void:
	waitingToSetHeadwearPosition = true


## Drops the headwear onto the hair: steps it down until its landing point first touches hair (binary search).
func tryToLandHeadwear() -> void:
	_landHeadwear()
	if Hooks.has(&"CharacterControl.tryToLandHeadwear"):   # HOOK
		Hooks.after(&"CharacterControl.tryToLandHeadwear", self, [])


func _landHeadwear() -> void:
	var over = g.hairCostumeOver.headwear
	over.y = 0
	g.hairCostumeBack.headwear.y = 0
	if customHairLoaded:
		return
	var touching := false
	var wasTouching := false
	var steps := 0
	var done := false
	var step := 10.0
	var lp = over.get("landingPoint")
	if lp:
		var local := Vector2(lp.x, lp.y)
		while true:
			var p: Vector2 = over.localToGlobal(local)
			wasTouching = touching
			touching = g.hairOverLayer.hitTestPoint(p.x, p.y, true) or g.hairTop.hitTestPoint(p.x, p.y, true) \
				or g.her.hairMidContainer.hitTestPoint(p.x, p.y, true)
			over.y += step
			g.hairCostumeBack.headwear.y += step
			if touching != wasTouching:
				step *= -0.5
				if absf(step) < 1:
					done = true
			steps += 1
			if done or steps >= 50:
				break
		if over.y > 50:
			over.y = 0
			g.hairCostumeBack.headwear.y = 0


func _hslFilter(hsl: Dictionary) -> FlashFilter:
	return FlashFilter.colorMatrix(g.getCMFMatrix(hsl["h"], hsl["s"], hsl["l"], hsl["c"]))


func applyHairHSL(hsl: Dictionary) -> void:
	var f := _hslFilter(hsl)
	g.her.hairMidContainer.filters = [f]
	g.her.hairBackContainer.filters = [f]
	g.hairOverContainer.filters = [f]
	g.hairBetweenLayer.filters = [f]
	hairHSL = hsl
	if Hooks.has(&"CharacterControl.applyHairHSL"):   # HOOK
		Hooks.after(&"CharacterControl.applyHairHSL", self, [hsl])


func removeHairHSL() -> void:
	g.her.hairMidContainer.filters = []
	g.her.hairBackContainer.filters = []
	g.hairOverContainer.filters = []
	g.hairBetweenLayer.filters = []
	hairHSL = blankHSL
	if Hooks.has(&"CharacterControl.removeHairHSL"):   # HOOK
		Hooks.after(&"CharacterControl.removeHairHSL", self, [])


func _skinHSLTargets() -> Array:
	var h: Her = g.her
	return [h.head, h.ear, h.eye.eyebrowUnderMask, h.torsoBack, h.backModContainer, h.leftLegContainer.leg.thigh,
		h.leftLegContainer.leg.calf, h.leftArmContainer.upperArm, h.rightArmContainer.upperArm,
		h.rightForeArmContainer.upperArm, h.leftHandOver.hand.grip, h.torso.backside, h.torso.midLayer,
		h.torso.behindBackRightArm, h.torso.back, h.torso.leg.thigh, h.torso.rightCalfContainer.calf,
		h.torso.penisContainer]


func applySkinHSL(hsl: Dictionary) -> void:
	var f := _hslFilter(hsl)
	for t in _skinHSLTargets():
		t.filters = [f]
	skinHSL = hsl


func removeSkinHSL() -> void:
	for t in _skinHSLTargets():
		t.filters = []
	skinHSL = blankHSL


func updateSkinHSL() -> void:
	if is_same(skinHSL, blankHSL):
		removeSkinHSL()
	else:
		applySkinHSL(skinHSL)


func applyHisSkinHSL(hsl: Dictionary) -> void:
	var f := _hslFilter(hsl)
	g.him.penis.filters = [f] if g.him.hslShiftPenis else []
	for t in [g.him.armContainer, g.him.leftArmContainer, g.him.balls, g.him.torsoLayer, g.him.leftLeg, g.him.rightLeg]:
		t.filters = [f]
	hisSkinHSL = hsl


func removeHisSkinHSL() -> void:
	for t in [g.him.penis, g.him.armContainer, g.him.leftArmContainer, g.him.balls, g.him.torsoLayer, g.him.leftLeg, g.him.rightLeg]:
		t.filters = []
	hisSkinHSL = blankHSL


func updateHisSkinHSL() -> void:
	if is_same(hisSkinHSL, blankHSL):
		removeHisSkinHSL()
	else:
		applyHisSkinHSL(hisSkinHSL)


func getCharacterList() -> Array:
	var out: Array = []
	for c in characters:
		out.append(c.charShortName)
	return out


func getIrisList() -> Array:
	return irisTypeList


func getSkinList() -> Array:
	return skinNameList


func nextCharacter() -> void:
	g.inGameMenu.characterMenu.selectNextCharacter()


func prevCharacter() -> void:
	g.inGameMenu.characterMenu.selectPrevCharacter()


func toggleBackground() -> void:
	if g.bgID == g.bgNum:
		g.bgID = 1
	else:
		g.bgID += 1
	g.bg.gotoAndStop(g.bgID)
	g.inGameMenu.setBGCheckboxes()


func toggleHim() -> void:
	g.him.toggleBodySettings()


func toggleSkin() -> void:
	if currentSkin == skinNameList.size() - 1:
		currentSkin = 0
	else:
		currentSkin += 1
	setSkin(currentSkin)
	g.inGameMenu.updateSkinList()


func toggleBreasts() -> void:
	var size := 0
	if breastSize != 149:
		size = int(floor((1 + breastSize) / 25.0)) * 25 + 24
	setBreasts(size)
	g.inGameMenu.updateBreastSlider()
	g.strandControl.checkElementAnchors(g.her.torso.midLayer.rightBreast)


func clearHair() -> void:
	clearElements()
	g.her.hairTop.gotoAndStop("None")
	g.her.hairMidContainer.hairUnder.gotoAndStop("None")
	g.her.hairMidContainer.hairBottom.gotoAndStop("None")
	g.her.hairBackContainer.hairBack.gotoAndStop("None")


func resetHair() -> void:
	setHair(currentHair, false)
	g.saveData.saveCharData()


func resetBackground() -> void:
	g.bg.gotoAndStop(g.bgID)


func setCustomHairLoaded() -> void:
	customHairLoaded = true
	if Hooks.has(&"CharacterControl.setCustomHairLoaded"):   # HOOK
		Hooks.after(&"CharacterControl.setCustomHairLoaded", self, [])


func setCustomBGLoaded() -> void:
	customBGLoaded = true


var currentSkinPalette: SkinPalette:
	get:
		return skinPalettes[skinNameList[currentSkin]]

var skinType: String:
	get:
		return currentSkinType


func getCharName(i: int) -> String:
	return String(characters[i].charName) if i < characters.size() else ""
