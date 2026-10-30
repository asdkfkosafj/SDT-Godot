extends Node
## Port of g.as: global game state, shared references and helper functions (autoload "g").

const ver := "v1.21.1b"
const screenSize := Vector2(700, 600)
const NORMAL_MODE := 1
const HAND_JOB_MODE := 2

var defaultCM = null
var container: FlashSprite
var her: Her
var him: Him
var himOverLayer: FlashMovieClip
var bg: FlashMovieClip
var sceneLayer: SceneLayer
var backLayer: FlashSprite
var hairBackContainer: FlashMovieClip
var mistLayer: FlashSprite
var strandBackLayer: FlashSprite
var strandFrontLayer: FlashSprite
var cumLayer: FlashSprite
var frontLayer: FlashSprite
var screenEffects: ScreenEffects
var stageRef: FlashSprite
var clickPrompt: ClickPrompt
var inGameMenu: InGameMenu
var animationControl: AnimationControl
var strandControl: StrandControl
var soundControl: SoundControl
var automaticControl: AutomaticControl
var characterControl: CharacterControl
var saveData: SaveData
var customElementLoader: CustomElementLoader
var modCatalog: ModCatalog   # port extension: mods offered in the pickers
var dialogueControl: Dialogue
var dialogueEditor: DialogueEditor
var highlight: FlashFilter
var cumHighlight: FlashFilter
var shadow: FlashFilter
var spitShaders: Array = []
var cumShaders: Array = []
var hairCM = null
var skinCM = null

const gravity := 5.5
const friction := 1.18
const spitMass := 0.4
const massGenerateSpeed := 0.001
const massFlow := 0.005
const maxMass := 1.1
const maxStrandLength := 18
var cumRGB := 16776439   # port: a variable (the cumRGB extension changes it)

var currentBreathLevel: float = 0.0
var breathLevelMax: float = BREATH_MAX   # port: the value point Her.breathMax's result (resolveBreath)
var outOfBreathPoint: float = 25.0       # port: Her.outOfBreathPoint's (half her air in the game)
const BREATH_MAX := 50.0
var strandShaders := true
var showMouse := true
var qualitySetting: int = 2
var hoverOptions := true
var mute := false
var mirrored := false
var invertControls := false
var screenShotScale: float = 1.0
var doubleSizeScreenshot := false
var resetIntroOnNewChar := false
var introResistance: float = 0.0
const defaultResistance := 50.0
var throatResistance: float = 0.0
const defaultThroatResistance := 50.0
var sceneZoom: float = 0.85
const defaultZoom := 0.45
var smearLipstick := false
var spit := true
var tears := true
var mascara := true
var smudging := true
var eyeShadow := true
var nostrilSpray := true
var sweat := true
var tongue := true
var throatBulgeAmount: float = 1.0
var dialogue := true  # port: on by default (false in the original)
var introSound := true
var breathing := true
var gagging := true
var coughing := true
var mascaraAmount: float = 20.0
var frecklesAmount: float = 0.0
var bgNum: int = 4
var bgID: int = 1
var himSkinType := "Light"
var overwriteCharList := false
var customName := ""
var autoModeOn := false
var autoMode: int = 0
var handsOff := false
var baseCharNum: int = 0
var storedChars: Array = []
var defaultModFolders: Array = []
var bukkakeMode := false
var hairOverContainer: FlashSprite
var hairTop: FlashMovieClip
var hairUnder: FlashMovieClip
var hairBottom: FlashMovieClip
var hairBack: FlashMovieClip
var hairOverLayer: FlashSprite
var hairBetweenLayer: FlashSprite
var hairUnderLayer: FlashSprite
var hairBackLayer: FlashSprite
var hairCostumeOver: FlashMovieClip
var hairCostumeUnderOver: FlashSprite
var hairCostumeUnder: FlashSprite
var hairCostumeBack: FlashMovieClip
var costumeHitElements: Array = []
var currentMousePos := Vector2()
var currentPos := Vector2(0, 0)
var currentHandJobPos := Vector2(0, 0)
var targetHandJobPos := Vector2(0, 0)
var herCurrentPos: float = 0.0
var shiftDown := false
var ctrlDown := false
var herMouthOpeness: float = 0.0
var penisOut := false
var leftHandJobMode := false
var rightHandJobMode := false
var currentModeID: int = 1
var gameRunning := false
var gamePaused := false:
	set(v):
		if v != gamePaused:
			gamePaused = v
			_pause_changed()


var _held_before_pause := false


## Port fix (sby's vanillapausedbreathpatch): no breathing or breath / throat sounds while the game is paused,
## whatever paused it; they come back when it goes on.
func _pause_changed() -> void:
	if her == null or soundControl == null:
		return
	if gamePaused:
		her.breathing = soundControl.stopBreathing()
		_held_before_pause = soundControl.beingHeld
		if _held_before_pause:
			soundControl.stopHolding()
	else:
		her.checkBreathing()
		if _held_before_pause:
			_held_before_pause = false
			soundControl.startHolding()
var controlLocked := false
var inTextField := false
var overScrollArea = null
var smudgeCache: Dictionary = {}
var totalFinishes: int = 0
var _eyedropperScreenshot: Image = null
var _screenFreeze: FlashBitmap = null
var _capCount: int = 0
var _screenshotNum: int = 1
var _eraseParents: Array = []


func newHer() -> Her:
	her = Her.new()
	return her


func newHim() -> Him:
	him = Him.new()
	return him


func newInGameMenu() -> InGameMenu:
	inGameMenu = InGameMenu.new()
	return inGameMenu


func newSaveData() -> SaveData:
	saveData = SaveData.new()
	return saveData


func newSceneLayer(zoom: float) -> SceneLayer:
	sceneLayer = SceneLayer.new(zoom)
	return sceneLayer


func getStrandControl() -> StrandControl:
	strandControl = StrandControl.new()
	return strandControl


func getSoundControl() -> SoundControl:
	soundControl = SoundControl.new()
	return soundControl


func getAutomaticControl() -> AutomaticControl:
	automaticControl = AutomaticControl.new()
	return automaticControl


func getCharacterControl() -> CharacterControl:
	characterControl = CharacterControl.new()
	return characterControl


func getCustomElementLoader() -> CustomElementLoader:
	customElementLoader = CustomElementLoader.new()
	return customElementLoader


func getDialogue() -> Dialogue:
	dialogueControl = Dialogue.new()
	return dialogueControl


func showError(_msg: String) -> void:
	pass


var handJobMode: bool:
	get:
		return leftHandJobMode or rightHandJobMode


func resetIntro() -> void:
	her.startIntro()
	him.resetSpit()


## Moves obj into newParent: at the bottom, just above 'above', or on top.
func changeLayer(obj: FlashDisplayObject, newParent: FlashSprite, above: FlashDisplayObject = null,
		atBottom: bool = false) -> void:
	obj.parent.removeChild(obj)
	if atBottom:
		newParent.addChildAt(obj, 0)
	elif above:
		newParent.addChildAt(obj, newParent.getChildIndex(above) + 1)
	else:
		newParent.addChild(obj)


func clearSmudgeCache() -> void:
	for o in smudgeCache.values():
		o["updated"] = false
		o["lastPoint"] = o["localPoint"]


func setPenisOut(out: bool = true) -> void:
	if out and not penisOut:
		# port fix (sby's hairlayerpatch): him under the hair costume layer (her forearm is under the hair now)
		frontLayer.addChildAt(sceneLayer.removeChild(him), frontLayer.getChildIndex(hairCostumeOver))
		frontLayer.addChildAt(her.leftHandOver, frontLayer.getChildIndex(himOverLayer))
		penisOut = true
	elif penisOut:
		sceneLayer.addChildAt(frontLayer.removeChild(him), 0)
		her.leftHandOverContainer.addChild(frontLayer.removeChild(her.leftHandOver))
		penisOut = false
	if Hooks.has(&"g.setPenisOut"):   # HOOK
		Hooks.after(&"g.setPenisOut", self, [out])


func setAuto(mode: int) -> void:
	autoMode = mode
	automaticControl.startAuto(currentPos)


func toggleAutoMode() -> void:
	autoModeOn = not autoModeOn
	automaticControl.startAuto(currentPos)


func toggleQuality() -> void:
	if qualitySetting == 2:
		qualitySetting = 0
	else:
		qualitySetting += 1
	inGameMenu.setQualityTo(qualitySetting)
	inGameMenu.setQualityCBs()


var breathLevel: float:
	get:
		return currentBreathLevel


func addBreath(amount: float) -> void:
	if breathing:
		currentBreathLevel = maxf(0.0, minf(breathLevelMax, currentBreathLevel + amount))


func setBreathTo(amount: float) -> void:
	if breathing:
		currentBreathLevel = maxf(0.0, minf(breathLevelMax, amount))


## Port: her breath limits, the game's numbers unless extensions change them on the value points Her.breathMax,
## Her.outOfBreathPoint and Her.passOutMax. Once per tick (DT.tick), and by an extension right after it changes
## their modifiers. A new limit keeps how much of it is used (her breath, how close she is to passing out).
func resolveBreath() -> void:
	var mx := BREATH_MAX
	if Hooks.has_value(&"Her.breathMax"):   # HOOK value point: how much breath she has (50)
		mx = maxf(1.0, Hooks.value(&"Her.breathMax", her, mx))
	if mx != breathLevelMax:
		var was := breathLevelMax
		breathLevelMax = mx
		setBreathTo(currentBreathLevel / was * mx)
		currentBreathLevel = minf(currentBreathLevel, mx)
	var oob := mx * 0.5
	if Hooks.has_value(&"Her.outOfBreathPoint"):   # HOOK value point: she is out of breath past this (half her air)
		oob = Hooks.value(&"Her.outOfBreathPoint", her, oob)
	outOfBreathPoint = oob
	if her == null:
		return
	var po := Her.PASS_OUT_MAX
	if Hooks.has_value(&"Her.passOutMax"):   # HOOK value point: how long she lasts with no air before passing out (40)
		po = maxf(1.0, Hooks.value(&"Her.passOutMax", her, po))
	if po != her.passOutMax:
		her.passOutFactor = her.passOutFactor / her.passOutMax * po
		her.passOutMax = po


func randomSpitMass() -> float:
	return randf() * 0.2 - 0.1 + spitMass


func randomCumMass() -> float:
	return 0.3 + randf() * 0.4


## Lower-cases and strips non-word characters (used as save-data keys).
func dataName(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\W")
	return re.sub(s.to_lower(), "", true)


## Records containers holding ERASE-blended children. (Flash needed cacheAsBitmap on them for BitmapData
## rendering; offscreen groups make that unnecessary here, but the list is kept for parity.)
func getEraseItems(c: FlashSprite) -> void:
	for i in c.numChildren:
		var o := c.getChildAt(i)
		if o.blendMode == "erase" and not _eraseParents.has(c):
			_eraseParents.append(c)
		if o is FlashSprite:
			getEraseItems(o)


## Freezes the scene behind a blurred snapshot (used while menus are open).
func freezeScreen() -> void:
	var img := Flash.capture_screen(screenSize, 1.0)
	if img == null:
		return
	_screenFreeze = FlashBitmap.new(FlashBitmapData.from_image(img), "auto", true)
	_screenFreeze.filters = [FlashFilter.blur()]
	sceneLayer.parent.addChildAt(_screenFreeze, sceneLayer.parent.getChildIndex(sceneLayer))
	sceneLayer.setSceneVisible(false)


func thawScreen() -> void:
	if _screenFreeze:
		_screenFreeze.parent.removeChild(_screenFreeze)
		_screenFreeze.queue_free()
		_screenFreeze = null
	sceneLayer.setSceneVisible(true)


func startEyedropper() -> void:
	_eyedropperScreenshot = Flash.capture_screen(screenSize, 1.0)


func getEyedropperPoint(px: float, py: float) -> int:
	if _eyedropperScreenshot:
		var x := clampi(int(px), 0, _eyedropperScreenshot.get_width() - 1)
		var y := clampi(int(py), 0, _eyedropperScreenshot.get_height() - 1)
		var c := _eyedropperScreenshot.get_pixel(x, y)
		return (c.r8 << 16) | (c.g8 << 8) | c.b8
	return 0


func stopEyedropper() -> void:
	_eyedropperScreenshot = null


## Saves a PNG of the game screen (Flash prompted with a save dialog; here it goes to the screenshots folder).
func takeScreenShot() -> void:
	var oldQuality := qualitySetting
	inGameMenu.setQualityTo(3)
	var img := Flash.capture_screen(screenSize, screenShotScale)
	inGameMenu.setQualityTo(oldQuality)
	if img == null:
		return
	var id := str(_screenshotNum).pad_zeros(4)
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/screenshot%s.png" % id
	while FileAccess.file_exists(path):
		_screenshotNum += 1
		id = str(_screenshotNum).pad_zeros(4)
		path = "user://screenshots/screenshot%s.png" % id
	if img.save_png(path) == OK:
		_screenshotNum += 1


func renderCharacterShot(scale_: float = 0.2) -> FlashBitmap:
	var b := FlashBitmap.new(generateCharacterShot(scale_))
	var col := _capCount % 5
	b.x = col * 140 - 0.5
	b.y = (_capCount - col) * 24 - 0.5
	_capCount += 1
	return b


## Thumbnail of the current character (Flash rendered selected layers; here the screen is captured).
func generateCharacterShot(scale_: float = 0.1) -> FlashBitmapData:
	var img := Flash.capture_screen(screenSize, scale_)
	if img == null:
		return FlashBitmapData.new(int(700 * scale_), int(600 * scale_), false, 4284773279)
	return FlashBitmapData.from_image(img)


## Colour matrix for hue (degrees) / saturation / lightness / contrast adjustments.
func getCMFMatrix(h: float, s: float, l: float, c: float) -> Array:
	var u := l * s * cos(h * PI / 180.0)
	var w := l * s * sin(h * PI / 180.0)
	var m := [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]
	m[0] = (0.299 * l + 0.701 * u + 0.168 * w) * c
	m[1] = (0.587 * l - 0.587 * u + 0.33 * w) * c
	m[2] = (0.114 * l - 0.114 * u - 0.497 * w) * c
	m[5] = (0.299 * l - 0.299 * u - 0.328 * w) * c
	m[6] = (0.587 * l + 0.413 * u + 0.035 * w) * c
	m[7] = (0.114 * l - 0.114 * u + 0.292 * w) * c
	m[10] = (0.299 * l - 0.3 * u + 1.25 * w) * c
	m[11] = (0.587 * l - 0.588 * u - 1.05 * w) * c
	m[12] = (0.114 * l + 0.886 * u - 0.203 * w) * c
	var o := 128.0 - c * 128.0
	m[4] = o
	m[9] = o
	m[14] = o
	return m


func getUnitVector(a: float) -> Vector2:
	return Vector2(sin(a), -cos(a))


func getAngle(px: float, py: float) -> float:
	return radToDeg(atan2(py, px)) + 90.0


func getRadAngle(px: float, py: float) -> float:
	return atan2(py, px) + PI * 0.5


func getVector(length: float, angle: float) -> Vector2:
	return Vector2(sin(angle) * length, -cos(angle) * length)


func getDist(dx: float, dy: float) -> float:
	return sqrt(dx * dx + dy * dy)


func degToRad(a: float) -> float:
	return a / 180.0 * PI


func radToDeg(a: float) -> float:
	return a / PI * 180.0


func sigRound(places: int, v: float) -> float:
	v *= pow(10.0, places)
	v = Maths.round(v)
	return v / pow(10.0, places)


## Keeps the matrix's scale-free rotation in sync with an added angle (radians).
func rotateMatrix(m: Transform2D, angle: float) -> Transform2D:
	angle += asin(m.x.y)
	var s := sin(angle)
	var c := cos(angle)
	m.x = Vector2(c, s)
	m.y = Vector2(-s, c)
	return m
