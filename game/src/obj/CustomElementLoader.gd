class_name CustomElementLoader
extends FlashEventDispatcher
## Port of obj.CustomElementLoader: custom hair / background images and mod loading. Mod content objects are
## display objects carrying dynamic properties (MOD_VERSION, modType, targetElement, overwrite, mods, ...), read
## with get() because any of them may be absent (undefined in AS3).

var browsing := false
var hairTemplate := Rect2i(0, 0, 600, 600)
var expandedHairTemplate := false
var hairImportSource: FlashBitmapData
var bgImportSource: FlashBitmapData
var hairOverData: FlashBitmapData
var hairOverLayer: FlashBitmap
var hairUnderData: FlashBitmapData
var hairUnderLayer: FlashBitmap
var hairBackData: FlashBitmapData
var hairBackLayer: FlashBitmap
var bgData: FlashBitmapData
var bgLayer: FlashBitmap
var hairImageFile: FlashFileReference
var bgImageFile: FlashFileReference
var imageFilter := {"description": "Images", "extension": "*.jpg;*.gif;*.png"}
var browsingForHair := false
var browsingForBG := false
var customHairLoaded := false
var customBGLoaded := false
var customBGHeight: float = 600.0
var proxyHairPackage: LoadedModPackage
var proxyBGPackage: LoadedModPackage
var modTargetHelpers: Dictionary = {}
var modFileList: FlashFileReferenceList
var swfFilter := {"description": "Mods", "extension": "*.swf;*.mod;*.sdtmod"}
var loadingMod: int = 0
var tryingToLoadMods: Array = []
var tryingToLoadMod: int = 0
var blockSwfCharData := false
var readingMods := false
var onlyLoadingCostume := false
var parsingModFile: FlashFileReference
var loadingModPackage: LoadedModPackage
var instancedModElements: Array = []
var loadedModPackages: Array = []


func _init() -> void:
	hairImageFile = FlashFileReference.new()
	hairImageFile.start_dir = Flash.mods_dir("Hair")
	hairImageFile.addEventListener(FlashEvent.COMPLETE, hairCompleteHandler)
	hairImageFile.addEventListener(FlashEvent.SELECT, hairSelectHandler)
	bgImageFile = FlashFileReference.new()
	bgImageFile.start_dir = Flash.mods_dir("Backgrounds")
	bgImageFile.addEventListener(FlashEvent.COMPLETE, bgCompleteHandler)
	bgImageFile.addEventListener(FlashEvent.SELECT, bgSelectHandler)
	bgImageFile.addEventListener(FlashEvent.CANCEL, cancelHandler)
	modFileList = FlashFileReferenceList.new()
	modFileList.start_dir = Flash.mods_dir("Clothing")
	modFileList.addEventListener(FlashEvent.SELECT, modSelectHandler)
	modFileList.addEventListener(FlashEvent.CANCEL, modCancelHandler)


static func _p(o, n: String):
	if o == null:
		return null
	return o.get(n)


## AS3 Boolean(): a flag the mod does not have is false (bool(null) is an error in GDScript).
static func _b(v) -> bool:
	return v != null and FlashAbc._truthy(v)


func addListeners() -> void:
	var mm = g.inGameMenu.moddingMenu
	mm.mbImportHair.addEventListener(FlashEvent.CLICK, browseCustomHairClicked)
	mm.mbClearHair.addEventListener(FlashEvent.CLICK, clearCustomHairClicked)
	mm.mbImportBackground.addEventListener(FlashEvent.CLICK, browseCustomBackgroundClicked)
	mm.mbClearBackground.addEventListener(FlashEvent.CLICK, clearCustomBackgroundClicked)
	mm.mbImportMod.addEventListener(FlashEvent.CLICK, browseModClicked)
	mm.mbClearSwfMod.addEventListener(FlashEvent.CLICK, clearSwfModClicked)


var swfModsLoaded: bool:
	get: return instancedModElements.size() > 0


func getLoadedModPackages() -> Array:
	return loadedModPackages


func getSwfModsDataString() -> String:
	var s := ""
	for p in loadedModPackages:
		s += p.dataString()
	return s


func tryToLoadSwfMods(list: Array, blockCharData: bool = false, costumeOnly: bool = false) -> void:
	readingMods = true
	onlyLoadingCostume = costumeOnly
	blockSwfCharData = blockCharData
	tryingToLoadMods = list
	tryingToLoadMod = 0
	tryToLoadNextMod()


func tryToLoadNextMod() -> void:
	if tryingToLoadMod < tryingToLoadMods.size():
		loadingModPackage = LoadedModPackage.new("swfMod")
		var parts: PackedStringArray = str(tryingToLoadMods[tryingToLoadMod]).split(",")
		var path: String
		if parts.size() > 1:
			path = ",".join(parts.slice(0, parts.size() - 1))
			loadingModPackage.setStatusString(parts[parts.size() - 1])
		else:
			path = str(tryingToLoadMods[tryingToLoadMod])
		loadingModPackage.tryToLoadFilePath(path, tryModLoadingErrorHandler, Callable(), tryModLoadingInitHandler)
		loadedModPackages.append(loadingModPackage)
		tryingToLoadMod += 1
	else:
		blockSwfCharData = false
		g.inGameMenu.charStoring.populateMods()
		readingMods = false
		onlyLoadingCostume = false
		CharCode.mods_loaded()   # HOOK port extension


func tryModLoadingErrorHandler(_e = null) -> void:
	g.inGameMenu.openCharStoring(false)
	tryToLoadNextMod()


func tryModLoadingInitHandler(e: FlashEvent) -> void:
	var content = e.target.content
	if content is FlashDisplayObject:
		loadingModPackage.modRoot = content   # port: kept until the package goes (its scripts keep running)
	if _p(content, "MOD_VERSION") and not loadingModPackage.items.is_empty():
		# items chosen from a picker (ModCatalog)
		var mods = _p(content, "mods")
		if mods is Array:
			loadingModPackage.setModDetails(_p(content, "modName"), _p(content, "modCreator"))
			var keep := blockSwfCharData
			blockSwfCharData = true
			for i in loadingModPackage.items:
				if i < mods.size():
					parseMod(mods[i])
			blockSwfCharData = keep
			loadingModPackage.applyStatusString()
			updateInstancedModElements()
			if g.modCatalog:
				g.modCatalog.mark_selected(loadingModPackage.filePath.get_slice("|", 0), loadingModPackage.items)
	elif _p(content, "MOD_VERSION"):
		parseMod(content)
		loadingModPackage.applyStatusString()
		updateInstancedModElements()
	loadingModPackage = null
	tryToLoadNextMod()


func modSelectHandler(_e = null) -> void:
	browsing = false
	readingMods = true
	loadingMod = 0
	loadNextModFile()


func loadNextModFile() -> void:
	if loadingMod == 0 and modFileList.fileList.size() > 1:
		# port: the mods that still need converting start converting together on worker threads (one after the
		# other here, they kept the screen black for as long as all of them took)
		FlashSwfMod.prefetch(modFileList.fileList.map(func(f): return f._path))
	if loadingMod < modFileList.fileList.size():
		parsingModFile = modFileList.fileList[loadingMod]
		loadingModPackage = LoadedModPackage.new("swfMod", parsingModFile)
		# Remember the full path so the mod can be auto-loaded again from save data (Flash only had the bytes).
		loadingModPackage.setFilePath(parsingModFile._path)
		loadedModPackages.append(loadingModPackage)
		parsingModFile.addEventListener(FlashEvent.COMPLETE, modCompleteHandler)
		parsingModFile.load()
		loadingMod += 1
	else:
		blockSwfCharData = false
		g.inGameMenu.charStoring.populateMods()
		readingMods = false
		CharCode.mods_loaded()   # HOOK port extension


func modCompleteHandler(e: FlashEvent) -> void:
	loadModData(e.target.data, e.target._path)


func modCancelHandler(_e = null) -> void:
	browsing = false


func loadModData(bytes: PackedByteArray, path: String = "") -> void:
	var l := FlashLoader.new()
	l.contentLoaderInfo.addEventListener(FlashEvent.INIT, modDataInit)
	l.contentLoaderInfo.addEventListener(FlashEvent.IO_ERROR, func(_e): loadingModPackage = null; loadNextModFile())
	if path != "":
		l.load(path)
	else:
		l.loadBytes(bytes)


func modDataInit(e: FlashEvent) -> void:
	e.target.removeEventListener(FlashEvent.INIT, modDataInit)
	var content = e.target.content
	if _p(content, "MOD_VERSION"):
		loadingModPackage.setModDetails(_p(content, "modName"), _p(content, "modCreator"))
		loadingModPackage.filePathOkay = loadingModPackage.filePath != ""
		parseMod(content)
		updateInstancedModElements()
	loadingModPackage = null
	loadNextModFile()


## Port fix: mod types some mods misspell, by their lower-case spelling. The Loader's lookups were exact, so these
## items were lost there.
const MOD_TYPE_SPELLINGS := {"costumeovertop": "CostumeOverTop"}


static func normalModType(t: String) -> String:
	return MOD_TYPE_SPELLINGS.get(t.to_lower(), t)


func parseMod(m) -> void:
	var mt = _p(m, "modType")
	if mt != null and normalModType(str(mt)) != str(mt):
		m.set("modType", normalModType(str(mt)))
	match str(_p(m, "modType")):
		ModTypes.MOD_PACKAGE:
			if _p(m, "charData") and not blockSwfCharData:
				CharCode.loading_mod_chardata = true   # HOOK port extension: a mod's code is not a full character
				g.inGameMenu.loadData(m.charData)
				CharCode.loading_mod_chardata = false
			if m.hasOwnProperty("dialogueName"):
				g.dialogueControl.setupDialogueMod(str(m.dialogueName), _b(_p(m, "clearAllDialogue")))
			var children = _p(m, "mods")
			if children != null:
				for c in children:
					parseMod(c)
		ModTypes.HAIR:
			if onlyLoadingCostume:
				addDummyMod(m)
			else:
				addStaticModElement(m)
		ModTypes.COLLAR, ModTypes.EYEWEAR, ModTypes.FOOTWEAR, ModTypes.TOP:
			addStaticModElement(m)
		ModTypes.BACKGROUND:
			if onlyLoadingCostume:
				addDummyMod(m)
			else:
				addStaticModElement(m)
				g.sceneLayer.setCustomBGHeight(m.height)
		ModTypes.GAG:
			addStaticModElement(m)
			g.her.setGagged(true)
		ModTypes.HAIR_COSTUME:
			addLayerModElement(m, m.modType)
		ModTypes.DYNAMIC_HAIR:
			if onlyLoadingCostume:
				addDummyMod(m)
			else:
				addDynamicHairMod(m)
		ModTypes.DIALOGUE:
			if onlyLoadingCostume:
				addDummyMod(m)
			else:
				addDialogueMod(m)
		_:
			if modTargetHelpers.get(_p(m, "modType")):
				addStaticModElement(m)


func _settings(m) -> Dictionary:
	return {"modType": str(_p(m, "modType")), "overwrite": _b(_p(m, "overwrite"))}


func placeElements(container, targets: Dictionary, setTargetFrame: bool = false) -> void:
	var n: int = container.numChildren
	var i := 0
	while i < n:
		var child = container.getChildAt(i)
		if child is FlashSprite:
			var elementName: String = child.flash_name
			if targets.get(elementName):
				var target = targets[elementName]
				child.alpha = 1
				child.matrix = Transform2D.IDENTITY
				target.addChild(child)
				if setTargetFrame:
					if target == g.her.backModContainer:
						g.her.torso.back.gotoAndStop("None")
					elif target is FlashMovieClip and target.has_label("None"):
						target.gotoAndStop("None")
					var existing = target.getChildByName(child.flash_name)
					if existing:
						removeModElement(existing)
				var nm := LoadedMod.new(loadingModPackage, _settings(container), child)
				instancedModElements.append(nm)
				loadingModPackage.addElement(nm)
				i -= 1
				n -= 1
		i += 1


func addDummyMod(m) -> void:
	var nm := LoadedMod.new(loadingModPackage, _settings(m), null)
	instancedModElements.append(nm)
	loadingModPackage.addElement(nm)


func addModToTarget(m, target) -> void:
	m.x = 0
	m.y = 0
	m.scaleX = 1
	m.scaleY = 1
	m.alpha = 1
	target.addChild(m)
	var nm := LoadedMod.new(loadingModPackage, _settings(m), m)
	instancedModElements.append(nm)
	loadingModPackage.addElement(nm)


func clearSwfModClicked(_e = null) -> void:
	clearInstancedMods()
	g.soundControl.resetAudioMods()


func clearInstancedMods() -> void:
	var resets: Dictionary = {}
	for m in instancedModElements:
		if g.inGameMenu.onlyLoadingCostume:
			if m.modType.to_lower().contains("costume"):
				resets[getResetFunction(m.modType)] = true
				m.kill()
		else:
			resets[getResetFunction(m.modType)] = true
			m.kill()
	updateInstancedModElements()
	for fn in resets:
		fn.call()
	for pkg in loadedModPackages:   # port: mods taken off stop their scripts (costume-only clears keep the others')
		if not pkg.hasInstancedMods():
			pkg.dispose_root()
	loadedModPackages = []
	if Hooks.has(&"CustomElementLoader.clearInstancedMods"):   # HOOK
		Hooks.after(&"CustomElementLoader.clearInstancedMods", self, [])


func updateInstancedModElements() -> void:
	var bodyOrTop := false
	var i := 0
	while i < instancedModElements.size():
		var m: LoadedMod = instancedModElements[i]
		if not m.active:
			instancedModElements.remove_at(i)
			continue
		bodyOrTop = bodyOrTop or m.modType == ModTypes.TOP or m.modType == ModTypes.BODY
		i += 1
	g.her.rightArmContainer.upperArmMask.visible = not bodyOrTop
	if Hooks.has(&"CustomElementLoader.updateInstancedModElements"):   # HOOK
		Hooks.after(&"CustomElementLoader.updateInstancedModElements", self, [])


func getResetFunction(modType: String) -> Callable:
	var h = modTargetHelpers.get(modType)
	if h and h.hasCostumeHelper:
		return h.characterElementHelper.resetElement
	match modType:
		ModTypes.BACKGROUND:
			return g.characterControl.resetBackground
		ModTypes.HAIR, ModTypes.DYNAMIC_HAIR, ModTypes.HAIR_COSTUME:
			return g.characterControl.resetHair
		ModTypes.BODY:
			return g.characterControl.resetSkin
		ModTypes.GAG:
			return g.characterControl.gagControl.resetElement
		ModTypes.COLLAR:
			return g.characterControl.collarControl.resetElement
		ModTypes.EYEWEAR:
			return g.characterControl.eyewearControl.resetElement
	return _noop


func _noop() -> void:
	pass


func checkLoadedModPackages() -> void:
	var i := 0
	while i < loadedModPackages.size():
		if not loadedModPackages[i].hasInstancedMods() and loadedModPackages[i] != loadingModPackage:
			loadedModPackages[i].dispose_root()   # port: its scripts stop with it
			loadedModPackages.remove_at(i)
			continue
		i += 1


func clearModTypes(types: Array) -> void:
	var i := 0
	while i < instancedModElements.size():
		var m: LoadedMod = instancedModElements[i]
		if types.has(m.modType) and m.sourcePackage != loadingModPackage:
			m.kill()
			instancedModElements.remove_at(i)
			continue
		i += 1
	checkLoadedModPackages()
	updateInstancedModElements()


func removeModElement(element) -> void:
	for i in instancedModElements.size():
		var m: LoadedMod = instancedModElements[i]
		if m.modElement == element:
			m.kill()
			instancedModElements.remove_at(i)
			break
	checkLoadedModPackages()


func addStaticModElement(m) -> void:
	if Hooks.has(&"CustomElementLoader.addStaticModElement"):   # HOOK
		var h := Hooks.before(&"CustomElementLoader.addStaticModElement", self, [m])
		if h.cancelled:
			return
	var key = _p(m, "targetElement")
	if not key:
		key = _p(m, "modType")
	var helper: CustomElementHelper = modTargetHelpers.get(key)
	if helper == null:
		push_warning("Mod target not found: %s" % key)
		return
	if helper.hasCostumeHelper:
		helper.characterElementHelper.prepForMod(loadingModPackage.titleString, _b(_p(m, "overwrite")))
	if helper.singleElement:
		var target = helper.targetDictionary["target"]
		if _p(m, "overwrite"):
			var te = _p(m, "targetElement")
			if te == ModElements.HAIR_TOP or te == ModElements.HAIR_UNDER or te == ModElements.HAIR_BOTTOM \
					or te == ModElements.HAIR_BACK:
				g.characterControl.clearHair()
			elif target is FlashMovieClip and target.has_label("None"):
				target.gotoAndStop("None")
		addModToTarget(m, target)
	else:
		var setFrame := false
		if _p(m, "modType") == ModTypes.BODY:
			setFrame = _b(_p(m, "overwrite"))
		placeElements(m, helper.targetDictionary, setFrame)
		if _p(m, "modType") == ModTypes.TOP or _p(m, "modType") == ModTypes.BRA:
			g.characterControl.setBreastCostumeSize()
		elif _p(m, "modType") == ModTypes.BODY:
			g.characterControl.prepForBodyMod()
			# port fix (the Loader did this): the mod's pieces on her skin's frame, their tan on her tan lines
			g.characterControl.setBodyModSkin()
			g.her._tan.setTan()
	if helper.hasCostumeHelper:
		helper.characterElementHelper.resetFills()
	if Hooks.has(&"CustomElementLoader.addStaticModElement"):   # HOOK
		Hooks.after(&"CustomElementLoader.addStaticModElement", self, [m])


func _clearTarget(target) -> void:
	while target.numChildren > 0:
		var c = target.getChildAt(0)
		if c is CostumeElement:
			c.kill()
			if c.parent == target:
				target.removeChildAt(0)
		else:
			target.removeChildAt(0)


func addLayerModElement(m, modType: String) -> void:
	var key = _p(m, "targetElement")
	if not key:
		key = _p(m, "modType")
	var helper: CustomElementHelper = modTargetHelpers.get(key)
	if helper == null:
		return
	var target = helper.targetDictionary["target"]
	if _p(m, "overwrite"):
		clearModTypes([modType])
		_clearTarget(target)
	m.x = 0
	m.y = 0
	m.scaleX = 1
	m.scaleY = 1
	m.alpha = 1
	var ce := CostumeElement.new()
	ce.addChild(m)
	var tog = _p(m, "toggleable")
	if tog != null and not tog:
		ce.makeUnToggleable()
	target.addChild(ce)
	var nm := LoadedMod.new(loadingModPackage, _settings(m), ce)
	instancedModElements.append(nm)
	loadingModPackage.addElement(nm)


func addDynamicHairMod(m) -> void:
	if Hooks.has(&"CustomElementLoader.addDynamicHairMod"):   # HOOK
		var h := Hooks.before(&"CustomElementLoader.addDynamicHairMod", self, [m])
		if h.cancelled:
			return
	var key = _p(m, "targetElement")
	if not key:
		key = _p(m, "modType")
	var helper: CustomElementHelper = modTargetHelpers.get(key)
	if helper == null:
		return
	var target = helper.targetDictionary["target"]
	if _p(m, "overwrite"):
		clearModTypes([ModTypes.DYNAMIC_HAIR])
		_clearTarget(target)
	var gravity := 0.0
	if _p(m, "gravityAngle"):
		gravity = AS3.Number(m.gravityAngle)
	var rope := Rope.new(m, target, null, null, gravity)
	if _p(m, "damping") != null:
		rope.damping = maxf(0, minf(1, AS3.Number(m.damping)))
	if _p(m, "topDamping") != null:
		rope.lockTop(maxf(0, minf(1, AS3.Number(m.topDamping))))
	var tog = _p(m, "toggleable")
	if tog != null and not tog:
		rope.makeUnToggleable()
	var nm := LoadedMod.new(loadingModPackage, _settings(m), rope)
	instancedModElements.append(nm)
	loadingModPackage.addElement(nm)


func addDialogueMod(m) -> void:
	if m.hasOwnProperty("lineType") and m.hasOwnProperty("dialogueLine"):
		g.dialogueControl.loadDialogueMod({"lineType": m.lineType, "dialogueLine": m.dialogueLine,
			"audio": _p(m, "audio"), "volume": _p(m, "volume")} if m.hasOwnProperty("audio") \
			else {"lineType": m.lineType, "dialogueLine": m.dialogueLine})


func cancelLoading() -> void:
	browsingForHair = false
	browsingForBG = false


func browseCustomHairClicked(_e = null) -> void:
	hairImageFile.browse()
	browsing = true
	browsingForBG = false
	browsingForHair = true


func browseCustomBackgroundClicked(_e = null) -> void:
	bgImageFile.browse([imageFilter])
	browsing = true
	browsingForHair = false
	browsingForBG = true


func browseModClicked(_e = null) -> void:
	modFileList.browse([swfFilter])
	browsing = true


func hairCompleteHandler(_e = null) -> void:
	loadData(hairImageFile.data)


func hairSelectHandler(_e = null) -> void:
	browsing = false
	proxyHairPackage = LoadedModPackage.new("customHair", hairImageFile)
	hairImageFile.load()


func bgCompleteHandler(_e = null) -> void:
	loadData(bgImageFile.data)


func bgSelectHandler(_e = null) -> void:
	browsing = false
	proxyBGPackage = LoadedModPackage.new("customBG", bgImageFile)
	bgImageFile.load()


func cancelHandler(_e = null) -> void:
	browsing = false
	browsingForHair = false
	browsingForBG = false


## Port: a file a code names by a path that is not there (a Loader character's "Mods/$INIT$/hair.png") is the file
## of the same name in the port's Mods folder, if there is one.
static func findModFile(p: String) -> String:
	if FileAccess.file_exists(Flash.resolve_content_path(p)):
		return p
	var found := _findFile(Flash.mods_dir(), p.replace("\\", "/").get_file())
	return ModCatalog._relative(found) if found != "" else p


static func _findFile(dir: String, file: String) -> String:
	var d := DirAccess.open(dir)
	if d == null:
		return ""
	if d.file_exists(file):
		return dir.path_join(file)
	for sub in d.get_directories():
		var found := _findFile(dir.path_join(sub), file)
		if found != "":
			return found
	return ""


func tryToLoadHairFile(p: String) -> FlashLoader:
	browsingForHair = true
	if p.ends_with(","):
		p = p.substr(0, p.length() - 1)
	p = findModFile(p)
	if not proxyHairPackage:
		proxyHairPackage = LoadedModPackage.new("customHair")
	return proxyHairPackage.tryToLoadFilePath(p, hairErrorHandler, hairLoaderComplete)


func hairErrorHandler(_e = null) -> void:
	browsingForHair = false


func tryToLoadBGFile(p: String) -> FlashLoader:
	browsingForBG = true
	if p.ends_with(","):
		p = p.substr(0, p.length() - 1)
	p = findModFile(p)
	if not proxyBGPackage:
		proxyBGPackage = LoadedModPackage.new("customBG")
	return proxyBGPackage.tryToLoadFilePath(p, bgErrorHandler, bgLoaderComplete)


func bgErrorHandler(_e = null) -> void:
	browsingForBG = false


func loadData(bytes: PackedByteArray) -> void:
	if browsingForHair:
		var l := FlashLoader.new()
		l.contentLoaderInfo.addEventListener(FlashEvent.COMPLETE, hairLoaderComplete)
		l.loadBytes(bytes)
	elif browsingForBG:
		var l := FlashLoader.new()
		l.contentLoaderInfo.addEventListener(FlashEvent.COMPLETE, bgLoaderComplete)
		l.loadBytes(bytes)


func hairLoaderComplete(e: FlashEvent) -> void:
	var loader: FlashLoader = e.target.loader
	if browsingForHair:
		var size := Vector2(loader.content.width, loader.content.height)
		if size.x <= 1200 and size.y <= 1200:
			hairTemplate = Rect2i(0, 0, 600, 600)
			expandedHairTemplate = false
		else:
			hairTemplate = Rect2i(0, 0, int(ceil(size.x * 0.5)), int(ceil(size.y * 0.5)))
			expandedHairTemplate = true
		hairImportSource = FlashBitmapData.new(int(size.x), int(size.y), true, 0)
		hairImportSource.draw(loader.content)
		generateCustomHair()
		if proxyHairPackage.hasFilePath():
			g.saveData.saveAutoLoadedHairPath(proxyHairPackage.path)
	browsingForHair = false
	loader.contentLoaderInfo.removeEventListener(FlashEvent.COMPLETE, hairLoaderComplete)


func bgLoaderComplete(e: FlashEvent) -> void:
	var loader: FlashLoader = e.target.loader
	if browsingForBG:
		customBGHeight = loader.content.height
		# port (widescreen): an image wider than the stage is kept whole (the game kept its leftmost 700 pixels)
		bgImportSource = FlashBitmapData.new(maxi(700, int(loader.content.width)), int(customBGHeight), false, 0xFF000000)
		bgImportSource.draw(loader.content)
		generateCustomBackground()
		if proxyBGPackage.hasFilePath():
			g.saveData.saveAutoLoadedBGPath(proxyBGPackage.path)
	browsingForBG = false
	loader.contentLoaderInfo.removeEventListener(FlashEvent.COMPLETE, bgLoaderComplete)


func _hairLayer(data: FlashBitmapData) -> FlashBitmap:
	var b := FlashBitmap.new(data, "auto", true)
	var s := 1.0 / 0.85
	b.x = -360
	b.y = -560
	b.rotation_degrees = 15   # Flash degrees (the port's rotation is in radians)
	b.scaleX = s
	b.scaleY = s
	return b


func generateCustomHair() -> void:
	clearCustomHair(false, false)
	var w := hairTemplate.size.x
	var h := hairTemplate.size.y
	hairOverData = FlashBitmapData.new(w, h, true, 0)
	hairOverData.copyPixels(hairImportSource, Rect2i(0, 0, w, h), Vector2i())
	hairUnderData = FlashBitmapData.new(w, h, true, 0)
	hairUnderData.copyPixels(hairImportSource, Rect2i(w, 0, w, h), Vector2i())
	hairBackData = FlashBitmapData.new(w, h, true, 0)
	hairBackData.copyPixels(hairImportSource, Rect2i(0, h, w, h), Vector2i())
	g.characterControl.clearHair()
	hairOverLayer = _hairLayer(hairOverData)
	hairUnderLayer = _hairLayer(hairUnderData)
	hairBackLayer = _hairLayer(hairBackData)
	g.hairTop.addChild(hairOverLayer)
	g.hairUnder.addChild(hairUnderLayer)
	g.hairBack.addChild(hairBackLayer)
	if g.resetIntroOnNewChar:
		g.resetIntro()
	g.characterControl.setCustomHairLoaded()
	customHairLoaded = true
	if g.modCatalog != null and proxyHairPackage != null:   # port: the hair picker shows it if it is a Mods/Hair image
		g.modCatalog.mark_selected(proxyHairPackage.path, [])


func generateCustomBackground() -> void:
	clearCustomBackground(false)
	var w := bgImportSource.width
	bgData = FlashBitmapData.new(w, int(customBGHeight), false, 0xFF000000)
	bgLayer = FlashBitmap.new(bgData, "auto", true)
	bgData.copyPixels(bgImportSource, Rect2i(0, 0, w, int(customBGHeight)), Vector2i())
	# port (widescreen): a wide image takes the height of the game's own backgrounds (850, drawn for the same view,
	# e.g. a widened classroom) and is centred on the game field, running into the side areas; the game drew images
	# 1:1 and kept their leftmost 700 pixels
	var s := 850.0 / customBGHeight if w > 700 else 1.0
	bgLayer.scaleX = s
	bgLayer.scaleY = s
	bgLayer.x = (700 - w * s) / 2.0
	g.bg.addChild(bgLayer)
	g.characterControl.setCustomBGLoaded()
	g.sceneLayer.setCustomBGHeight(customBGHeight * s)
	customBGLoaded = true


func clearCustomHairClicked(_e = null) -> void:
	clearCustomHair()


func clearCustomBackgroundClicked(_e = null) -> void:
	clearCustomBackground()


func clearCustomHair(reset: bool = true, clearProxy: bool = true) -> void:
	clearModTypes([ModTypes.HAIR, ModTypes.DYNAMIC_HAIR, ModTypes.HAIR_COSTUME])
	if customHairLoaded:
		customHairLoaded = false
		g.hairTop.removeChild(hairOverLayer)
		g.hairUnder.removeChild(hairUnderLayer)
		g.hairBack.removeChild(hairBackLayer)
		for l in [hairOverLayer, hairUnderLayer, hairBackLayer]:
			Flash.dispose_later(l)
		g.saveData.clearAutoLoadedHairPath()
		if clearProxy:
			proxyHairPackage = null
	if reset:
		g.characterControl.resetHair()


func clearCustomBackground(clearProxy: bool = true) -> void:
	clearModTypes([ModTypes.BACKGROUND])
	if customBGLoaded:
		customBGLoaded = false
		g.saveData.clearAutoLoadedBGPath()
		g.sceneLayer.removeCustomBGHeight()
		g.bg.removeChild(bgLayer)
		Flash.dispose_later(bgLayer)
		if clearProxy:
			proxyBGPackage = null
		g.inGameMenu.bgModIndex = -1
		g.inGameMenu.updateBGPicker()


func prepareModTargetElementsDictionary() -> void:
	var her = g.her
	var cc = g.characterControl
	modTargetHelpers = {}
	modTargetHelpers[ModElements.BACKGROUND] = CustomElementHelper.new({"target": g.bg})
	modTargetHelpers[ModElements.HAIR_TOP] = CustomElementHelper.new({"target": g.hairTop})
	modTargetHelpers[ModElements.HAIR_UNDER] = CustomElementHelper.new({"target": g.hairUnder})
	modTargetHelpers[ModElements.HAIR_BOTTOM] = CustomElementHelper.new({"target": g.hairBottom})
	modTargetHelpers[ModElements.HAIR_BACK] = CustomElementHelper.new({"target": g.hairBack})
	modTargetHelpers[ModElements.DYNAMIC_HAIR_OVER] = CustomElementHelper.new({"target": g.hairOverLayer})
	modTargetHelpers[ModElements.DYNAMIC_HAIR_UNDER] = CustomElementHelper.new({"target": g.hairUnderLayer})
	modTargetHelpers[ModElements.DYNAMIC_HAIR_BETWEEN] = CustomElementHelper.new({"target": g.hairBetweenLayer})
	modTargetHelpers[ModElements.DYNAMIC_HAIR_BACK] = CustomElementHelper.new({"target": g.hairBackLayer})
	modTargetHelpers[ModElements.HAIR_COSTUME_OVER] = CustomElementHelper.new({"target": g.hairCostumeOver})
	modTargetHelpers[ModElements.HAIR_COSTUME_UNDEROVER] = CustomElementHelper.new({"target": g.hairCostumeUnderOver})
	modTargetHelpers[ModElements.HAIR_COSTUME_UNDER] = CustomElementHelper.new({"target": g.hairCostumeUnder})
	modTargetHelpers[ModElements.HAIR_COSTUME_BACK] = CustomElementHelper.new({"target": g.hairCostumeBack})
	modTargetHelpers[ModElements.GAG_FRONT] = CustomElementHelper.new({"target": her.gagFront}, cc.gagControl)
	modTargetHelpers[ModElements.GAG_BACK] = CustomElementHelper.new({"target": her.gagBack}, cc.gagControl)
	modTargetHelpers[ModElements.COLLAR] = CustomElementHelper.new({"target": her.collarContainer.collar},
		cc.collarControl)
	modTargetHelpers[ModElements.EYEWEAR] = CustomElementHelper.new({"target": her.eyewear}, cc.eyewearControl)
	modTargetHelpers[ModTypes.BODY] = CustomElementHelper.new({
		"behindBackHands": her.torso.midLayer.leftArm,
		"back": her.backModContainer,
		"chestUnder": her.torsoBack.chestBack,
		"leftShoulder": her.torsoBack.leftShoulder,
		"rightThigh": her.torso.leg.thigh,
		"rightCalf": her.torso.rightCalfContainer.calf,
		"leftThigh": her.leftLegContainer.leg.thigh,
		"leftCalf": her.leftLegContainer.leg.calf,
		"backside": her.torsoBack.backside,
		"rightUpperArm": her.rightArmContainer.upperArm,
		"rightForearm": her.rightForeArmContainer.upperArm.foreArm,
		"rightHand": her.rightForeArmContainer.upperArm.foreArm.hand,
		"leftUpperArm": her.leftArmContainer.upperArm,
		"leftForearm": her.leftArmContainer.upperArm.foreArm,
		"leftHand": her.leftArmContainer.upperArm.foreArm.hand,
		"chest": her.torso.midLayer.chest,
		"leftBreast": her.torsoBack.leftBreast,
		"leftNipple": her.torsoBack.leftBreast.nipple,
		"rightBreast": her.torso.midLayer.rightBreast,
		"rightNipple": her.torso.midLayer.rightBreast.nipple})
	modTargetHelpers[ModTypes.TOP] = CustomElementHelper.new({
		"rightBreast": her.torso.topContainer.breastTop,
		"chest": her.torso.topContainer.chestTop,
		"back": her.torso.topContainer.backTop,
		"strap": her.torso.topContainer.topStrap,
		"leftBreast": her.torsoBackCostume.breastCostume.top,
		"under": her.torsoUnderCostume.top,
		"rightArm": her.rightArmContainer.upperArmCostume.top,
		"leftArm": her.leftArmContainer.upperArmCostume.top}, cc.topControl)
	modTargetHelpers[ModTypes.FOOTWEAR] = CustomElementHelper.new({
		"rightFoot": her.torso.rightCalfContainer.footwear,
		"leftFoot": her.leftLegContainer.leg.footwear}, cc.footwearControl)
	modTargetHelpers[ModTypes.HEADWEAR] = CustomElementHelper.new({
		"front": g.hairCostumeOver.headwear,
		"back": g.hairCostumeBack.headwear}, cc.headwearControl)
	modTargetHelpers[ModTypes.BOTTOMS] = CustomElementHelper.new({
		"rightThighMasked": her.torso.rightThighBottoms,
		"rightThigh": her.torso.rightThighBottomsOver,
		"rightCalf": her.torso.rightCalfContainer.bottoms,
		"chest": her.torso.chestCostume.bottoms,
		"back": her.torso.backCostume.bottoms,
		"leftThigh": her.leftLegContainer.leg.leftThighBottoms,
		"leftCalf": her.leftLegContainer.leg.leftCalfBottoms,
		"backside": her.torsoBackCostume.backsideCostume.bottoms}, cc.bottomsControl)
	modTargetHelpers[ModTypes.TONGUE_PIERCING] = CustomElementHelper.new({
		"front": her.tongueContainer.tongue.piercing,
		"back": her.tongueContainer.tongue.piercingBack}, cc.tonguePiercingControl)
	modTargetHelpers[ModTypes.NIPPLE_PIERCING] = CustomElementHelper.new({
		"right": her.torso.nipplePiercing,
		"left": her.torso.leftNipplePiercing}, cc.nipplePiercingControl)
	modTargetHelpers[ModTypes.BELLY_PIERCING] = CustomElementHelper.new(
		{"target": her.torso.chestCostume.bellyPiercing}, cc.bellyPiercingControl)
	modTargetHelpers[ModTypes.EAR_PIERCING] = CustomElementHelper.new({"target": her.earrings}, cc.earringControl)
