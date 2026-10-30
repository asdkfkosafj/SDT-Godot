class_name DT
extends FlashMovieClip
## Port of DT.as, the SWF's document class: builds the layer stack, creates the game objects and routes input.
## The main scene adds one DT instance to the Flash stage.

const HIGHLIGHT_SHADER := preload("res://flash/shaders/highlight.gdshader")

var preloaderBG: FlashDisplayObject
var preloadDisplay: FlashDisplayObject
var strandControl: StrandControl
var soundControl: SoundControl
var characterControl: CharacterControl
var automaticControl: AutomaticControl
var saveData: SaveData
var customElementLoader: CustomElementLoader
var bgLayer: FlashSprite
var strandBackLayer: FlashSprite
var strandBackMask: FlashDisplayObject
var sceneLayer: SceneLayer
var strandFrontLayer: FlashSprite
var strandFrontMask: FlashDisplayObject
var cumLayer: FlashSprite
var cumLayerMask: FlashDisplayObject
var screenEffects: ScreenEffects
var uiLayer: FlashSprite
var menuLayer: FlashSprite
var sceneMask: FlashDisplayObject
var her: Her
var him: Him
var himMask: FlashDisplayObject
var menuBG: FlashDisplayObject
var mainMenu: FlashMovieClip
var inGameMenu: InGameMenu
var fadingBG := false
var clickPrompt: ClickPrompt
var currentMousePos := Vector2()
var mouseScrollDeltas: Array = []


func _init() -> void:
	super()
	_setup_document_timeline()
	addFrameScript(0, stop)
	preloaderBG = Flash.create("MenuBackground")
	addChild(preloaderBG)
	preloadDisplay = Flash.create("PreloadDisplay")
	preloadDisplay.bar.scaleX = 0
	preloadDisplay.x = 350
	preloadDisplay.y = 300
	addChild(preloadDisplay)
	g.highlight = FlashFilter.shaderFilter(HIGHLIGHT_SHADER, {"trans": 0.275, "totMult": 0.2})
	g.cumHighlight = FlashFilter.shaderFilter(HIGHLIGHT_SHADER, {"trans": 1.1, "totMult": 0.5})
	saveData = g.newSaveData()
	# port: the textures the last session used load on worker threads while the title screen shows
	Flash.base_library.warm_up(FlashSharedObject.save_dir)
	# Everything is already loaded; Flash fired the loaderInfo COMPLETE event after streaming the SWF.
	completePreloader.call_deferred()


## The document class instance is the SWF's main timeline (Preloader and Main scenes).
func _setup_document_timeline() -> void:
	var lib: FlashLibrary = Flash.libraries[0]
	var sym := lib.root.duplicate()
	sym["t"] = "sprite"
	_library = lib
	_sym = sym
	_total = maxi(1, sym["frames"].size())
	_playing = false
	_goto(0, true)
	_built = true


func initGame() -> void:
	g.stageRef = self
	g.container = FlashSprite.new()
	addChild(g.container)
	g.animationControl = AnimationControl.new()
	strandControl = g.getStrandControl()
	soundControl = g.getSoundControl()
	characterControl = g.getCharacterControl()
	automaticControl = g.getAutomaticControl()
	g.getDialogue()
	g.bg = Flash.create("Background")
	sceneLayer = g.newSceneLayer(g.defaultZoom)
	him = g.newHim()
	her = g.newHer()
	customElementLoader = g.getCustomElementLoader()
	g.shadow = FlashFilter.dropShadow(1, -90, 13288100, 1, 5, 5, 1.5, 1, true)
	g.spitShaders = [g.highlight]
	g.cumShaders = [g.cumHighlight, g.shadow]
	bgLayer = FlashSprite.new()
	g.container.addChild(bgLayer)
	bgLayer.addChild(g.bg)
	g.backLayer = FlashSprite.new()
	g.container.addChild(g.backLayer)
	var backMask := Flash.create("ScreenMask")
	g.container.addChild(backMask)
	g.backLayer.mask = backMask
	g.mistLayer = FlashSprite.new()
	g.container.addChild(g.mistLayer)
	strandBackLayer = FlashSprite.new()
	g.strandBackLayer = strandBackLayer
	g.container.addChild(strandBackLayer)
	strandBackMask = Flash.create("ScreenMask")
	g.container.addChild(strandBackMask)
	strandBackLayer.mask = strandBackMask
	strandBackLayer.filters = g.spitShaders
	sceneLayer.aimCamera(200, 50)
	g.container.addChild(sceneLayer)
	sceneMask = Flash.create("ScreenMask")
	g.container.addChild(sceneMask)
	sceneLayer.mask = sceneMask
	var himArm := Flash.create("HimArmContainer")
	g.backLayer.addChild(himArm)
	var hairBackContainer := Flash.create("HairBackContainer")
	g.backLayer.addChild(hairBackContainer)
	g.hairBackContainer = hairBackContainer
	g.hairBackLayer = hairBackContainer.hairBackLayer
	g.hairBack = hairBackContainer.hairBack
	var herLeftArm := Flash.create("HerLeftArmContainer")
	sceneLayer.addChild(herLeftArm)
	g.hairCostumeBack = Flash.create("HairCostumeBack")
	sceneLayer.addChild(g.hairCostumeBack)
	sceneLayer.addChild(him)
	sceneLayer.addChild(her)
	her.giveHairBackContainer(hairBackContainer)
	g.himOverLayer = Flash.create("HimOverLayer")
	him.giveOverLayer(g.himOverLayer)
	var himLeftArm := Flash.create("HimLeftArmContainer")
	g.himOverLayer.addChild(himLeftArm)
	him.giveHimLeftArm(himLeftArm)
	him.giveHimArm(himArm)
	strandFrontLayer = FlashSprite.new()
	strandFrontLayer.mouseEnabled = false
	strandFrontLayer.mouseChildren = false
	g.strandFrontLayer = strandFrontLayer
	g.container.addChild(strandFrontLayer)
	strandFrontMask = Flash.create("ScreenMask")
	g.container.addChild(strandFrontMask)
	strandFrontLayer.mask = strandFrontMask
	strandFrontLayer.filters = g.spitShaders
	cumLayer = FlashSprite.new()
	cumLayer.mouseEnabled = false
	cumLayer.mouseChildren = false
	g.cumLayer = cumLayer
	g.container.addChild(cumLayer)
	cumLayerMask = Flash.create("ScreenMask")
	g.container.addChild(cumLayerMask)
	cumLayer.mask = cumLayerMask
	cumLayer.filters = g.cumShaders
	g.frontLayer = FlashSprite.new()
	g.container.addChild(g.frontLayer)
	var herRightArm := Flash.create("HerRightArmContainer")
	var herRightArmErase := Flash.create("HerRightArmEraseContainer")
	var herRightForeArm := Flash.create("HerRightForeArmContainer")
	var leftHandOver := Flash.create("LeftHandOver")
	g.hairCostumeUnderOver = FlashSprite.new()
	g.hairOverLayer = FlashSprite.new()
	g.hairOverContainer = FlashSprite.new()
	g.hairCostumeOver = Flash.create("HairCostumeOver")
	g.hairTop = her.hairTop
	her.removeChild(g.hairTop)
	g.frontLayer.addChild(herRightArm)
	# port fix (sby's hairlayerpatch): her right forearm under the hair layers, so big hair does not pass
	# through her elbow (the game put it above them)
	g.frontLayer.addChild(herRightForeArm)
	_orderLeftLeg(her.leftLegContainer.leg)
	g.hairOverContainer.addChild(g.hairTop)
	g.hairOverContainer.addChild(g.hairOverLayer)
	g.frontLayer.addChild(g.hairCostumeUnderOver)
	g.frontLayer.addChild(g.hairOverContainer)
	g.frontLayer.addChild(g.hairCostumeOver)
	g.frontLayer.addChild(leftHandOver)
	g.frontLayer.addChild(g.himOverLayer)
	g.him.addChild(herRightArmErase)
	herRightArmErase.blendMode = "erase"
	g.him.blendMode = "layer"
	her.giveArmContainers(herLeftArm, herRightArm, herRightForeArm, herRightArmErase, leftHandOver)
	her.setupTan()
	sceneLayer.giveExternalLayer(g.backLayer)
	sceneLayer.giveExternalLayer(g.frontLayer)
	sceneLayer.giveExternalLayer(strandBackLayer)
	sceneLayer.giveExternalLayer(strandFrontLayer)
	sceneLayer.giveExternalLayer(cumLayer)
	var frontMask := Flash.create("ScreenMask")
	g.container.addChild(frontMask)
	g.frontLayer.mask = frontMask
	screenEffects = ScreenEffects.new()
	screenEffects.mouseEnabled = false
	screenEffects.mouseChildren = false
	g.screenEffects = screenEffects
	g.container.addChild(screenEffects)
	g.getEraseItems(g.container)
	menuLayer = FlashSprite.new()
	g.container.addChild(menuLayer)
	menuBG = Flash.create("MenuBackground")
	menuBG.mouseEnabled = false
	menuLayer.addChild(menuBG)
	mainMenu = Flash.create("Menu")
	menuLayer.addChild(mainMenu)
	uiLayer = FlashSprite.new()
	g.container.addChild(uiLayer)
	clickPrompt = ClickPrompt.new()
	clickPrompt.x = 675
	clickPrompt.y = 590
	g.clickPrompt = clickPrompt
	uiLayer.addChild(clickPrompt)
	g.container.addChild(g.dialogueControl)
	inGameMenu = g.newInGameMenu()
	customElementLoader.addListeners()
	g.container.addChild(inGameMenu)
	customElementLoader.prepareModTargetElementsDictionary()
	characterControl.registerComponents()
	g.modCatalog = ModCatalog.new()
	g.modCatalog.start()
	PortSettings.apply_fps_limit()   # port: Settings > Graphics > FPS limit, MSAA
	PortSettings.apply_msaa()
	g.dialogueEditor = DialogueEditor.new()
	g.container.addChild(g.dialogueEditor)
	addEventListener(FlashEvent.ENTER_FRAME, tick)
	addEventListener(FlashEvent.MOUSE_DOWN, mousePressed)
	addEventListener(FlashEvent.MOUSE_UP, mouseReleased)
	addEventListener(FlashEvent.MOUSE_MOVE, mouseMoved)
	addEventListener(FlashEvent.MOUSE_WHEEL, mouseWheel)
	stage.addEventListener(FlashEvent.KEY_DOWN, keyPressed)
	stage.addEventListener(FlashEvent.KEY_UP, keyReleased)
	stage.addEventListener(FlashEvent.MOUSE_LEAVE, mouseLeft)
	# port (widescreen): the side areas outside the 700x600 field hit the stage itself, below which DT's listeners
	# never hear them
	for type in [FlashEvent.MOUSE_DOWN, FlashEvent.MOUSE_UP, FlashEvent.MOUSE_MOVE, FlashEvent.MOUSE_WHEEL]:
		stage.addEventListener(type, _stageMouse)
	mainMenu.buttonPlay.addEventListener(FlashEvent.CLICK, playClicked)
	mainMenu.buttonOptions.addEventListener(FlashEvent.CLICK, optionsClicked)
	if saveData.saveExists():
		characterControl.initChar(false)
		characterControl.initHim()
		saveData.loadCurrentData()
	else:
		characterControl.initChar()
		characterControl.initHim()
		saveData.saveOptionsData()
		saveData.saveCharOptionsData()
		g.inGameMenu.characterMenu.updateCharOrder(g.characterControl.defaultCharOrder)
	saveData.updatePlayCounter()
	openMainMenu()
	g.her.initialise()
	Extensions.start()   # port extension: built-in extensions and plugins (src/ext), once the game is built
	SDTMenu.start()   # port addition: the new in-game menu (src/menu); the classic one in Vanilla mode


func startGame() -> void:
	if not g.showMouse:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	g.soundControl.startBreathing()
	currentMousePos = Vector2(700, 0)
	g.gameRunning = true


func tick() -> void:
	if fadingBG:
		menuBG.alpha -= 0.025
		if menuBG.alpha <= 0:
			menuBG.alpha = 0
			menuBG.visible = false
			fadingBG = false
	if g.gameRunning:
		g.resolveBreath()   # port: her breath limits' value points
		if not g.gamePaused:
			if not g.controlLocked:
				var mirroredControls: bool = (g.mirrored or g.invertControls) and not (g.mirrored and g.invertControls)
				var mx: float = g.screenSize.x - currentMousePos.x if mirroredControls else currentMousePos.x
				mx = (mx - 100) / 500
				g.currentMousePos.x = minf(1.2, mx)
				g.currentMousePos.y = maxf(-1, minf(1, (currentMousePos.y - 100) / 200 - 1))
				if g.autoModeOn:
					g.currentPos = automaticControl.getPos()
				else:
					g.currentPos = g.currentMousePos
			var t0 := Time.get_ticks_usec() if Flash.profiling else 0   # port: --profile buckets
			g.animationControl.stepAnimation()
			var t1 := Time.get_ticks_usec() if Flash.profiling else 0
			g.dialogueControl.update()
			if Flash.profiling:
				Flash.account_listener("DT>animation", t1 - t0)
				Flash.account_listener("DT>dialogue", Time.get_ticks_usec() - t1)
		var t2 := Time.get_ticks_usec() if Flash.profiling else 0
		soundControl.tick()
		var t3 := Time.get_ticks_usec() if Flash.profiling else 0
		g.characterControl.tick()
		if Flash.profiling:
			Flash.account_listener("DT>sound", t3 - t2)
			Flash.account_listener("DT>characterControl", Time.get_ticks_usec() - t3)


func playClicked(_e = null) -> void:
	closeMainMenu()
	startGame()


func optionsClicked(_e = null) -> void:
	inGameMenu.openMenu(true)


func mousePressed(e: FlashEvent) -> void:
	if g.gameRunning and not g.gamePaused:
		her.mousePressed(e)
		her.activeHold()
		if g.bukkakeMode:
			him.startBMSpurt()


func mouseReleased(e: FlashEvent) -> void:
	if g.gameRunning and not g.gamePaused:
		her.mouseReleased(e)
		him.stopBMSpurt()
	inGameMenu.mouseReleased(e)


func mouseMoved(_e = null) -> void:
	if not g.shiftDown and not g.controlLocked:
		currentMousePos = Vector2(mouseX, mouseY)
	inGameMenu.mouseMoved(mouseX, mouseY)


## Port (widescreen): mouse events aimed at the stage itself (the side areas) go to the handlers above. Events on
## the display list bubble through DT already.
func _stageMouse(e: FlashEvent) -> void:
	if e.target != stage:
		return
	match e.type:
		FlashEvent.MOUSE_DOWN:
			mousePressed(e)
		FlashEvent.MOUSE_UP:
			mouseReleased(e)
		FlashEvent.MOUSE_MOVE:
			mouseMoved(e)
		FlashEvent.MOUSE_WHEEL:
			mouseWheel(e)


func mouseLeft(_e = null) -> void:
	if not g.shiftDown and not g.controlLocked:
		if currentMousePos.x > g.screenSize.x / 2 + 200:
			currentMousePos.x = g.screenSize.x
		elif currentMousePos.x < g.screenSize.x / 2 - 200:
			currentMousePos.x = 0


func mouseWheel(e: FlashEvent) -> void:
	var d := 8.0 if e.delta > 0.5 else (-8.0 if e.delta < -0.5 else 0.0)
	if g.overScrollArea:
		g.overScrollArea.mouseWheelScroll(d)
	elif d > 0:
		g.sceneLayer.zoomIn(0.05)
		g.saveData.saveOptionsData()
	elif d < 0:
		g.sceneLayer.zoomOut(0.05)
		g.saveData.saveOptionsData()


func keyReleased(e: FlashEvent) -> void:
	match e.keyCode:
		16:
			if not g.controlLocked:
				currentMousePos = Vector2(mouseX, mouseY)
			g.shiftDown = false
		17:
			g.ctrlDown = false


func keyPressed(e: FlashEvent) -> void:
	match e.keyCode:
		16:
			g.shiftDown = true
		17:
			g.ctrlDown = true
	if g.inTextField or g.controlLocked:
		return
	Extensions.key_pressed(e.keyCode)   # HOOK port extension: extension hotkeys
	match e.keyCode:
		191:
			if g.shiftDown:
				g.inGameMenu.shuffle()
			else:
				g.takeScreenShot()
		32:
			her.activeHold()
		65:
			g.toggleAutoMode()
			inGameMenu.setCBAuto()
		80:
			inGameMenu.toggleMenu(true, 5)
		79:
			inGameMenu.toggleMenu(true, 4)
		73:
			inGameMenu.toggleMenu(true, 3)
		85:
			inGameMenu.toggleMenu(true, 2)
		89:
			inGameMenu.toggleMenu(true, 1)
		67:
			characterControl.nextCharacter()
		88:
			characterControl.prevCharacter()
		66:
			characterControl.toggleBackground()
			g.saveData.saveCharData()
		72:
			characterControl.toggleHim()
			g.saveData.saveCharData()
		75:
			g.her.swallow()
		84:
			characterControl.toggleBreasts()
			g.saveData.saveCharData()
		83:
			characterControl.toggleSkin()
			g.saveData.saveCharData()
		74:
			him.ejaculate()
		189, 109:
			g.sceneLayer.zoomOut()
			g.saveData.saveOptionsData()
		187, 107:
			g.sceneLayer.zoomIn()
			g.saveData.saveOptionsData()
		188:
			soundControl.decreaseVolume()
			g.saveData.saveOptionsData()
		190:
			soundControl.increaseVolume()
			g.saveData.saveOptionsData()
		77:
			soundControl.toggleMute()
			g.saveData.saveOptionsData()
		81:
			g.toggleQuality()
			g.saveData.saveOptionsData()


func closeMainMenu() -> void:
	fadingBG = true
	mainMenu.visible = false
	mainMenu.enabled = false


func openMainMenu() -> void:
	if g.introSound:
		soundControl.playIntro()
	mainMenu.visible = true
	mainMenu.enabled = true


func completePreloader() -> void:
	removeChild(preloadDisplay)
	gotoAndStop(3)
	initGame()
	# Flash loaded the stored characters one second later (Timer), after the first frames had rendered.
	Flash.get_tree().create_timer(1.0).timeout.connect(loadDelayDone)


func loadDelayDone() -> void:
	saveData.loadCustomChars()


## Port fix (sby's leglayermove): her left leg's calf pieces all under its thigh pieces (the game interleaved them);
## only visible where calf and thigh overlap, with leg angles the game's own poses do not use.
static func _orderLeftLeg(leg) -> void:
	var shape = leg.getChildAt(2) if leg.numChildren > 2 else null   # the unnamed shading over the thigh
	var index := 0
	for n in ["calf", "calfStocking", "calfStockingB", "footwear", "cuffs", "leftCalfBottoms", "thigh", "#shape",
			"stocking", "stockingB", "leftThighCostume", "leftThighBottoms"]:
		var o = shape if n == "#shape" else leg.get(n)
		if o is FlashDisplayObject and o._flash_parent == leg:
			leg.setChildIndex(o, index)
			index += 1
