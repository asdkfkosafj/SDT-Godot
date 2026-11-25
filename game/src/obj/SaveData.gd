class_name SaveData
extends RefCounted
## Port of obj.SaveData: persistent options, last character, custom characters and dialogue. Uses the same two
## SharedObject names as the original ("ChoIrrumatio" and "..._thumbs"), stored under user://.

var sdtSave: FlashSharedObject
var sdtCharShots: FlashSharedObject
var lastCharData: String
var loadingCharData := false
var lastCharShotsSize: int = 0
var _heldCharSave: Array = []   # saveCharData's arguments while it waits for her mods (port)


func _init() -> void:
	sdtSave = FlashSharedObject.getLocal("ChoIrrumatio")
	sdtCharShots = FlashSharedObject.getLocal("ChoIrrumatio_thumbs")


## AS3 `x != undefined` (null counts as undefined).
func _has(k: String) -> bool:
	return sdtSave.data.get(k) != null


func _d(k: String):
	return sdtSave.data.get(k)


func saveExists() -> bool:
	return sdtSave.size != 0


func clearSave() -> void:
	sdtSave.clear()
	sdtCharShots.clear()


func storeCurrentData() -> void:
	saveCharData()
	saveOptionsData()
	saveCharOptionsData()


func updatePlayCounter() -> void:
	if _has("playCount"):
		sdtSave.data["playCount"] = AS3.Number(_d("playCount")) + 1
	else:
		sdtSave.data["playCount"] = 1


func saveAutoLoadedHairPath(p: String) -> void:
	sdtSave.data["customHairPath"] = p


func clearAutoLoadedHairPath() -> void:
	sdtSave.data["customHairPath"] = null


func saveAutoLoadedBGPath(p: String) -> void:
	sdtSave.data["customBGPath"] = p


func clearAutoLoadedBGPath() -> void:
	sdtSave.data["customBGPath"] = null


func saveCharData(standard: bool = false, id: int = 0, mark_custom: bool = true) -> void:
	if not loadingCharData:
		# port: her mods go on after her code has loaded (once the mod scan is done, or on the next frame), so a
		# save now would store her without them; it waits until they are on
		if _modsPending():
			if _heldCharSave.is_empty():
				Flash.add_enter_frame(self, _saveHeldCharData)
			_heldCharSave = [standard, id]
			if not standard and mark_custom:   # now, not when the save happens: a stored character selects herself next
				g.inGameMenu.updateCharMenu(0, true)
			return
		sdtSave.data["lastCharData"] = g.inGameMenu.getSaveDataString()
		sdtSave.data["standardChar"] = standard
		if standard:
			sdtSave.data["standardCharID"] = id
		elif mark_custom:
			g.inGameMenu.updateCharMenu(0, true)


func _modsPending() -> bool:
	return (g.modCatalog != null and g.modCatalog.is_pending()) or g.customElementLoader.readingMods


func _saveHeldCharData() -> void:
	if _modsPending():
		return
	Flash.remove_enter_frame(self, _saveHeldCharData)
	var a := _heldCharSave
	_heldCharSave = []
	saveCharData(a[0], a[1], false)


func saveOptionsData() -> void:
	var d := sdtSave.data
	d["strandShaders"] = g.strandShaders
	d["showMouse"] = g.showMouse
	d["quality"] = g.qualitySetting
	d["hoverOptions"] = g.hoverOptions
	d["mirrored"] = g.mirrored
	d["mute"] = g.mute
	d["vol"] = g.soundControl.globalVol
	d["introSound"] = g.introSound
	d["breathing"] = g.breathing
	d["resetIntro"] = g.resetIntroOnNewChar
	d["introResistance"] = g.introResistance
	d["sceneZoom"] = g.sceneZoom
	if Hooks.has_value(&"SaveData.sceneZoom"):   # HOOK value point: the zoom saved with the options (g.sceneZoom; a temporary zoom keeps the player's)
		d["sceneZoom"] = Hooks.value(&"SaveData.sceneZoom", self, g.sceneZoom)
	d["autoMode"] = AutomaticControl.autoModeNameList[g.autoMode]
	d["himArmPos"] = Him.armPositions[g.him.currentArmPosition]
	d["himLeftArmPos"] = Him.leftArmPositions[g.him.currentLeftArmPosition]
	d["invertControls"] = g.invertControls
	d["screenShotScale"] = g.screenShotScale


func saveCharOptionsData() -> void:
	var d := sdtSave.data
	d["spit"] = g.spit
	d["tears"] = g.tears
	d["mascara"] = g.mascara
	d["nostrilSpray"] = g.nostrilSpray
	d["sweat"] = g.sweat
	d["gagging"] = g.gagging
	d["coughing"] = g.coughing
	d["tongue"] = g.tongue
	d["throatBulgeAmount"] = g.throatBulgeAmount
	d["smudging"] = g.smudging
	d["dialogue"] = g.dialogue
	d["customName"] = g.customName
	d["animationStyle"] = g.animationControl.currentAnimationName


func saveFolders() -> void:
	sdtSave.data["defaultFolders"] = g.defaultModFolders.duplicate()


func saveCustomDialogue(s: String) -> void:
	sdtSave.data["customDialogue"] = s


func clearCustomDialogue() -> void:
	sdtSave.data["customDialogue"] = ""


func saveCharacterListOrder(baseOrder: Array) -> void:
	var custom: Array = []
	for c in g.storedChars:
		custom.append(c.menuPosition)
	sdtSave.data["baseCharOrder"] = baseOrder.duplicate()
	sdtSave.data["customCharOrder"] = custom
	sdtSave.flush(10240)


## AS3 arrays grow when written past the end (gaps are undefined).
static func _setAt(a: Array, i: int, v) -> void:
	if i >= a.size():
		a.resize(i + 1)
	a[i] = v


func saveCustomChar(i: int) -> void:
	if not _d("customCharNames"):
		sdtSave.data["customCharNames"] = []
		sdtSave.data["customCharData"] = []
		sdtCharShots.data["customCharShots"] = []
	if not _d("customCharDialogue"):
		sdtSave.data["customCharDialogue"] = []
	if sdtCharShots.data.get("customCharShots") == null:
		sdtCharShots.data["customCharShots"] = []
	var c: CustomCharacter = g.storedChars[i]
	_setAt(sdtSave.data["customCharNames"], i, c.charName)
	_setAt(sdtSave.data["customCharData"], i, c.charData)
	if c.dialogue:
		_setAt(sdtSave.data["customCharDialogue"], i, c.dialogue)
	_setAt(sdtCharShots.data["customCharShots"], i, c.shotBytes if c.haveCharShot else null)
	sdtSave.flush(10240)
	sdtCharShots.flush(102400)


func loadCustomChars() -> void:
	var names = _d("customCharNames")
	if not names:
		return
	var list: Array = []
	var shots: Array = sdtCharShots.data.get("customCharShots", [])
	var dialogues = _d("customCharDialogue")
	var datas: Array = _d("customCharData")
	for i in names.size():
		if names[i] != null:
			var o := {"name": names[i], "data": datas[i] if i < datas.size() else null}
			if dialogues:
				o["dialogue"] = dialogues[i] if i < dialogues.size() else null
			if i < shots.size() and shots[i] != null:
				o["shotBytes"] = shots[i]
			list.append(o)
	g.inGameMenu.characterMenu.loadCustomChars(list, false)
	if _has("baseCharOrder") and _has("customCharOrder"):
		g.inGameMenu.characterMenu.updateCharOrder(_d("baseCharOrder"), _d("customCharOrder"))
	else:
		g.inGameMenu.characterMenu.updateCharOrder(g.characterControl.defaultCharOrder)


func clearStoredChars() -> void:
	sdtSave.data["customCharNames"] = []
	sdtSave.data["customCharData"] = []
	sdtCharShots.data["customCharShots"] = []


func deleteStoredChar(i: int) -> void:
	for a in [_d("customCharNames"), _d("customCharData"), _d("customCharDialogue"), sdtCharShots.data.get("customCharShots")]:
		if a is Array and i < a.size():
			a.remove_at(i)
	sdtSave.flush(10240)
	sdtCharShots.flush(102400)


func loadCharData() -> void:
	if not _has("lastCharData"):
		return
	loadingCharData = true
	var standard := false
	var loaded := false
	if _has("standardChar"):
		standard = bool(_d("standardChar"))
	if standard and _has("standardCharID"):
		loaded = g.characterControl.tryToSetChar(int(_d("standardCharID")), false)
	if not loaded:
		var s := str(_d("lastCharData"))
		if _has("customHairPath"):
			s += ";customHair:" + str(_d("customHairPath"))
		if _has("customBGPath"):
			s += ";customBG:" + str(_d("customBGPath"))
		g.inGameMenu.loadData(s, false)
		g.inGameMenu.updateCharMenu(0, true)
	loadingCharData = false


func loadCurrentData() -> void:
	if not _has("playCount"):
		return
	var menu = g.inGameMenu
	loadCharData()
	if _has("hairFolder"):
		menu.charStoring.addDefaultFolder(_d("hairFolder"))
	if _has("bgFolder"):
		menu.charStoring.addDefaultFolder(_d("bgFolder"))
	if _has("defaultFolders"):
		for f in _d("defaultFolders"):
			menu.charStoring.addDefaultFolder(f)
	if g.defaultModFolders.size() == 0:
		g.defaultModFolders.append("mods/")
		menu.charStoring.populateDefaultFolders()
	if _has("strandShaders"):
		g.strandShaders = _d("strandShaders")
		menu.updateStrandShaders()
	if _has("showMouse"):
		g.showMouse = _d("showMouse")
		menu.setcbShowMouse()
	if not _has("quality"):
		if _has("highQuality"):
			menu.setQualityTo(2 if _d("highQuality") else 0)
			menu.setQualityCBs()
	else:
		menu.setQualityTo(int(_d("quality")))
		menu.setQualityCBs()
	if _has("hoverOptions"):
		g.hoverOptions = _d("hoverOptions")
		menu.setcbHoverOptions()
	if _has("mirrored"):
		g.mirrored = _d("mirrored")
		menu.setcbMirrored()
	if _has("vol"):
		g.soundControl.changeVolume(_d("vol"))
		menu.updateVolumeSlider(g.soundControl.globalVol)
	if _has("mute") and _d("mute"):
		g.soundControl.muteSound()
	if _has("introSound"):
		g.introSound = _d("introSound")
		menu.updateCBIntroSound()
	if _has("breathing"):
		g.breathing = _d("breathing")
		g.her.breathingToggled()
		menu.updateCBBreathing()
	if _has("autoMode"):
		g.automaticControl.findAutoMode(_d("autoMode"))
	if _has("himArmPos"):
		g.him.findArmPosition(_d("himArmPos"), true)
	if _has("himLeftArmPos"):
		g.him.findLeftArmPosition(_d("himLeftArmPos"))
	if _has("resetIntro"):
		g.resetIntroOnNewChar = _d("resetIntro")
		menu.setCBResetResistance()
	if _has("introResistance"):
		g.introResistance = _d("introResistance")
		menu.updateResistanceSlider(true)
	if _has("sceneZoom"):
		g.sceneLayer.zoomTo(_d("sceneZoom"), true)
		menu.updateZoomSlider()
	if _has("spit"):
		g.spit = _d("spit")
		menu.updateCBSpit()
	if _has("tears"):
		g.tears = _d("tears")
		menu.updateCBTears()
	if _has("mascara"):
		g.mascara = _d("mascara")
		menu.updateCBMascara()
	if _has("smudging"):
		g.smudging = _d("smudging")
		menu.updateCBSmudging()
	if _has("nostrilSpray"):
		g.nostrilSpray = _d("nostrilSpray")
		menu.updateCBNostrilSpray()
	if _has("sweat"):
		g.sweat = _d("sweat")
		menu.updateCBSweat()
	if _has("gagging"):
		g.gagging = _d("gagging")
		menu.updateCBGagging()
	if _has("coughing"):
		g.coughing = _d("coughing")
		menu.updateCBCoughing()
	if _has("tongue"):
		g.tongue = _d("tongue")
		menu.updateCBTongue()
	if _has("throatBulge"):
		g.throatBulgeAmount = 1
		g.her.throatBulgeChanged()
		menu.updateThroatBulgeSlider()
	if _has("throatBulgeAmount"):
		g.throatBulgeAmount = _d("throatBulgeAmount")
		g.her.throatBulgeChanged()
		menu.updateThroatBulgeSlider()
	if _has("dialogue"):
		g.dialogue = _d("dialogue")
		menu.updateCBDialogue()
		g.dialogueControl.dialogueToggled()
	if _has("invertControls"):
		g.invertControls = _d("invertControls")
		menu.updateCBInvertControls()
	if _has("screenShotScale"):
		g.screenShotScale = int(Maths.round(_d("screenShotScale")))
		g.doubleSizeScreenshot = g.screenShotScale != 1
		menu.updateCBDoubleSizeScreenshot()
	if _has("customDialogue"):
		g.dialogueControl.loadCustomDialogue(_d("customDialogue"), false)
	if _has("customName"):
		g.customName = _d("customName")
		menu.customMenu.dialogueNameTF.text = g.customName
	if _has("animationStyle"):
		g.animationControl.loadStyle(_d("animationStyle"))
		menu.setStyleCheckboxes()
	if _has("gameMode") and AS3.looseEquals(_d("gameMode"), 2):
		g.her.findRightArmPosition("Hand Job")
		sdtSave.data["gameMode"] = null
