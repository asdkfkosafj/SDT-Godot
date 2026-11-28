class_name Dialogue
extends FlashMovieClip
## Port of obj.dialogue.Dialogue: the speech/thought bubble. States build up from game events; when one passes the
## threshold a random line for it is typed out letter by letter, driving her mouth shapes, with [ACTION] words
## triggering game actions mid-line.

const ZERO_STATE := "zero_state"
const RESISTANCE := "resistance"
const FIRST_THROAT := "first_throat"
const FIRST_DT := "first_dt"
const PULL_OFF := "pull_off"
const HELD := "held"
const WAKE := "wake"
const VIGOROUS := "vigorous"
const LICK_PENIS := "lick_penis"
const LICK_BALLS := "lick_balls"
const PRE_CUM := "pre_cum"
const CUM_ON_FACE := "cum_on_face"
const CUM_IN_MOUTH := "cum_in_mouth"
const CUM_IN_THROAT := "cum_in_throat"
const CUM_IN_EYE := "cum_in_eye"
const CUM_IN_NOSE := "cum_in_nose"
const SWALLOW := "swallow"
const DROOL := "drool"
const HEAD_GRABBED := "head_grabbed"
const PULLED_UP := "pulled_up"
const PULLED_DOWN := "pulled_down"
const HAND_JOB_STROKE := "hand_job_stroke"
const QUEUED := "queued"
const INTRO := "intro"
const GENERAL := "general"
const RESTART := "restart"
const COUGH := "cough"
const INTERRUPT := "interrupt"
const ONE_OFF_BUILD := 120
const FRAME_BUILD := 4
const TICK_BUILD := 16
const MAX_BUILD := 320
const STATE_THRESHOLD := 20
const DIALOGUE_NAME_KEY := "dialogue_name"

const GENERAL_PHRASE_FREQ := 0.8
const SPEAK_DELAY := 20
var DEFAULT_TYPING_SPEED := 55   # a var in the port: extensions change it (dialogspeed)
const clearTime := 60

static var _reBeforeBracket := RegEx.create_from_string("(\\S)\\[")
static var _reAfterBracket := RegEx.create_from_string("\\](\\S)")
static var _reHex2 := RegEx.create_from_string("^[0-9A-Fa-f]{2}$")
static var _reHex4 := RegEx.create_from_string("^[0-9A-Fa-f]{4}$")

var tfContainer: FlashMovieClip
var library: DialogueLibrary
var advancedController: AdvancedDialogueController
var originalTextFormat: Dictionary
var originalFont
var typingSpeed: int = 55
var typingDelay: int = 0
var coughDelay: int = 0
var continueDelay: int = 0
var lastFrameTime: int = 0
var currentTime: int = 0
var frameTime: int = 0
var dialogueTicks: int = 0
var clearDelay: int = 0
var nextLineTimer: float = 0.0
var speaking := false
var interruptTimer: int = 0
var showingText := false
var fadingOut := false
var fadingIn := false
var currentText: String = ""
var words: Array = []
var sayingState: String = ""
var sayingPhrase: String = ""
var sayingWord: int = 0
var sayingChar: int = 0
var sayingSpace := false
var sayingSpeakingStyle := false
var waitingToContinue := false
var queuedPhrase: String = ""
var sayingAudio: FlashSound
var cumulativeMovement: float = 0.0
var postEjaculation := false
var firstThroatSpoken := false
var states: Dictionary = {}
var debugMode := false
var debugBars: Dictionary = {}


func _init() -> void:
	super()
	x = 0
	y = g.screenSize.y
	originalTextFormat = tfContainer.dialogueField.defaultTextFormat
	originalFont = originalTextFormat["font"]
	_gotoStyle("speaking")
	mouseEnabled = false
	mouseChildren = false
	library = DialogueLibrary.new()
	advancedController = AdvancedDialogueController.new()
	DialogueLine.advancedController = advancedController
	states[ZERO_STATE] = DialogueState.new(0, 0)
	states[HEAD_GRABBED] = DialogueState.new(MAX_BUILD, 1)
	states[PULLED_UP] = DialogueState.new(MAX_BUILD, 0)
	states[PULLED_DOWN] = DialogueState.new(MAX_BUILD, 0)
	states[RESISTANCE] = DialogueState.new(MAX_BUILD, 0)
	states[FIRST_THROAT] = DialogueState.new(MAX_BUILD + 80, 1)
	states[FIRST_DT] = DialogueState.new(MAX_BUILD + 80, 2)
	states[PULL_OFF] = DialogueState.new(MAX_BUILD, 0)
	states[HELD] = DialogueState.new(MAX_BUILD + 160, 0)
	states[WAKE] = DialogueState.new(MAX_BUILD + 80, 4)
	states[LICK_PENIS] = DialogueState.new(MAX_BUILD, 1)
	states[LICK_BALLS] = DialogueState.new(MAX_BUILD, 1)
	states[VIGOROUS] = DialogueState.new(MAX_BUILD + 100, 0)
	states[PRE_CUM] = DialogueState.new(MAX_BUILD, 2)
	states[CUM_ON_FACE] = DialogueState.new(MAX_BUILD + 240, 3, 0.1)
	states[CUM_IN_MOUTH] = DialogueState.new(MAX_BUILD + 240, 3, 0.1)
	states[CUM_IN_THROAT] = DialogueState.new(MAX_BUILD + 240, 3, 0.1)
	states[CUM_IN_NOSE] = DialogueState.new(MAX_BUILD + 240, 4, 0.1)
	states[SWALLOW] = DialogueState.new(MAX_BUILD + 80, 0)
	states[DROOL] = DialogueState.new(MAX_BUILD + 80, 1)
	states[RESTART] = DialogueState.new(MAX_BUILD + 160, 2)
	states[HAND_JOB_STROKE] = DialogueState.new(MAX_BUILD + 100, 0)
	states[QUEUED] = DialogueState.new(MAX_BUILD + 300, 5, 0.1)
	states[INTRO] = DialogueState.new(0, 0)
	states[GENERAL] = DialogueState.new(0, 0)
	states[CUM_IN_EYE] = DialogueState.new(0, 0)
	if not debugMode:
		alpha = 0
	readyToSpeak()
	if debugMode:
		var names: Array = states.keys()
		names.sort()
		var i := 0
		for n in names:
			var bar := Flash.create("DebugBar")
			bar.scaleX = states[n].max / MAX_BUILD
			bar.x = 100
			bar.y = i * 12 - 550
			bar.labelField.text = n
			addChild(bar)
			debugBars[n] = bar
			i += 1


func setDefaultFont() -> void:
	originalTextFormat["font"] = originalFont
	tfContainer.dialogueField.embedFonts = true
	tfContainer.dialogueField.defaultTextFormat = originalTextFormat
	tfContainer.dialogueField.setTextFormat(originalTextFormat)


func setCustomFont(fontName: String) -> void:
	var names: Array = Array(OS.get_system_fonts())
	if names.has(fontName):
		applyCustomFont(fontName)
	else:
		var re := RegEx.create_from_string("(?i)" + fontName)
		if re == null or not re.is_valid():
			return
		for n in names:
			if re.search(n):
				applyCustomFont(n)
				break


func applyCustomFont(fontName: String) -> void:
	originalTextFormat["font"] = fontName
	tfContainer.dialogueField.embedFonts = false
	tfContainer.dialogueField.defaultTextFormat = originalTextFormat
	tfContainer.dialogueField.setTextFormat(originalTextFormat)


func resetCustomDialogue(clearSave: bool = true) -> void:
	library.resetCustomDialogue()
	for s in states.values():
		s.clearPrevPhrases()
	if clearSave:
		g.saveData.clearCustomDialogue()
	setDefaultFont()


func getCurrentDialogue() -> Dictionary:
	return library.getCurrentDialogue()


func getCurrentFinishes() -> Dictionary:
	return library.getCurrentFinishes()


func getCurrentLibraryName() -> String:
	return library.libraryName


func loadFromDialogueEditor(lines: Array, save: bool = true) -> void:
	library.loadFromDialogueEditor(lines)
	if save:
		g.saveData.saveCustomDialogue(library.exportLibrary())


func loadDialogueMod(m) -> void:
	library.loadDialogueMod(m)


func setupDialogueMod(n: String, clearAll: bool) -> void:
	library.setupDialogueMod(n, clearAll)


func loadCustomDialogue(text: String, save: bool = true) -> void:
	if Hooks.has(&"Dialogue.loadCustomDialogue"):   # HOOK
		var h := Hooks.before(&"Dialogue.loadCustomDialogue", self, [text, save])
		if h.cancelled:
			return
		text = h.args[0]
	if text != "":
		library.loadCustomDialogue(text)
		for s in states.values():
			s.clearPrevPhrases()
	if save:
		g.saveData.saveCustomDialogue(library.exportLibrary())
	if Hooks.has(&"Dialogue.loadCustomDialogue"):   # HOOK
		Hooks.after(&"Dialogue.loadCustomDialogue", self, [text, save])


func exportDialogue() -> String:
	return library.exportLibrary()


func setDialogueLibraryName(n: String) -> void:
	library.setDialogueLibraryName(n)


func dialogueToggled() -> void:
	if not g.dialogue and speaking:
		stopSpeaking()
		clearDelay = clearTime


func instantStop() -> void:
	if speaking:
		stopSpeaking()
	alpha = 0
	fadingIn = false
	fadingOut = false
	sayingSpace = false


func reset() -> void:
	clearStates()
	postEjaculation = false
	if speaking:
		stopSpeaking()
	sayingSpace = false


func triggerState(s: String) -> void:
	sayRandomPhrase(s)


func readyToSpeak() -> void:
	nextLineTimer = 0


func movement(v: float) -> void:
	if postEjaculation:
		cumulativeMovement += v if v > 0 else -v
		if cumulativeMovement > 100:
			buildState(RESTART, MAX_BUILD)
			postEjaculation = false


func doneEjaculating() -> void:
	cumulativeMovement = 0
	postEjaculation = true


func clearStates() -> void:
	for s in states.values():
		s.clearBuild()
	firstThroatSpoken = false


func _isCumState(s: String) -> bool:
	return s == CUM_ON_FACE or s == CUM_IN_MOUTH or s == CUM_IN_THROAT or s == CUM_IN_EYE


func buildState(s: String, amount: int) -> void:
	if states.get(s):
		if s == FIRST_THROAT and firstThroatSpoken:
			return
		states[s].buildState(amount)
		if speaking and sayingSpeakingStyle and _isCumState(s) and not _isCumState(sayingState):
			currentText += "-"
			updateTextField()
			stopSpeaking()


func maxState(s: String) -> void:
	if states.get(s):
		states[s].maxBuild()


## Characters left in the current word (uint arithmetic in the original, so a negative result wraps to huge).
func _remainingInWord() -> int:
	var r: int = words[sayingWord].length - 1 - sayingChar
	return r if r >= 0 else 0x7FFFFFFF


func interrupt() -> void:
	nextLineTimer = 0
	if sayingSpeakingStyle:
		g.her.setSpeaking(false)
		if speaking:
			var left: int = _remainingInWord() if sayingWord < words.size() else 0
			if left < 3:
				if sayingSpace:
					sayingSpace = false
					currentText += " "
				for i in left + 1:
					currentText += nextChar()
			else:
				sayingChar = 0
			currentText += randomInterrupt()
			sayingSpace = true
			updateTextField()
			if interruptTimer == 0:
				interruptTimer = int(floor(randf() * 50)) + 60
			continueDelay = int(floor(randf() * 5)) + 3
			g.soundControl.pauseDialogue()
			speaking = false
			waitingToContinue = true
			clearDelay = 0


func cough() -> AudioMod:
	if speaking and sayingSpeakingStyle and sayingWord < words.size():
		var left := _remainingInWord()
		if left < 3:
			if sayingSpace:
				sayingSpace = false
				currentText += " "
			for i in left + 1:
				currentText += nextChar()
		else:
			sayingChar = 0
		var c := randomCough()
		currentText += randomCough()
		sayingSpace = true
		updateTextField()
		coughDelay = 20
		clearDelay = 0
		return library.playInterruptAudio(c)
	return null


func checkForSpeechStart() -> void:
	if Hooks.has(&"Dialogue.checkForSpeechStart"):   # HOOK
		var h := Hooks.before(&"Dialogue.checkForSpeechStart", self, [])
		if h.cancelled:
			return
	if not g.dialogue:
		return
	if interruptTimer > 0:
		if waitingToContinue:
			if g.her.canSpeak():
				if continueDelay > 0:
					continueDelay -= 1
				else:
					continueSpeaking()
		elif continueDelay > 0:
			continueDelay -= 1
		else:
			continueSpeaking()
	nextLineTimer += maxf(randf() * 0.2, speechUrgency())
	if nextLineTimer > SPEAK_DELAY and not speaking and not waitingToContinue:
		var best := ZERO_STATE
		var candidates: Array = []
		var topPriority := 0
		for k in states:
			if states[k].build > STATE_THRESHOLD:
				if states[k].priority > topPriority:
					candidates = []
					topPriority = states[k].priority
				candidates.append(k)
		var found := false
		for k in candidates:
			if states[k].build > states[best].build:
				best = k
				if states[best].build > 0:
					found = true
		if g.her.introRunning():   # port: not her intro's lines while his tip cannot reach her mouth (Her.introRunning)
			if states[best].build < STATE_THRESHOLD:
				best = INTRO
				found = true
		if found:
			if best == QUEUED:
				states[QUEUED].clearBuild()
				sayRandomPhrase(queuedPhrase)
			else:
				sayRandomPhrase(best, true)
		elif randf() < GENERAL_PHRASE_FREQ:
			sayRandomPhrase(GENERAL)
		else:
			nextLineTimer = 0


func reduceStates() -> void:
	for s in states.values():
		s.reduce(ONE_OFF_BUILD * 2)


func speechUrgency() -> float:
	var total := 0
	for s in states.values():
		total = int(total + s.build)
	return float(total) / MAX_BUILD


func sayRandomPhrase(stateName: String, reduceOthers: bool = false) -> void:
	if Hooks.has(&"Dialogue.sayRandomPhrase"):   # HOOK
		var h := Hooks.before(&"Dialogue.sayRandomPhrase", self, [stateName, reduceOthers])
		if h.cancelled:
			return
		stateName = h.args[0]
		reduceOthers = h.args[1]
		_sayRandomPhrase(stateName, reduceOthers)
		Hooks.after(&"Dialogue.sayRandomPhrase", self, [stateName, reduceOthers])
		return
	_sayRandomPhrase(stateName, reduceOthers)


## sayRandomPhrase's original body (split out so the hook can run after every exit).
func _sayRandomPhrase(stateName: String, reduceOthers: bool) -> void:
	var all: Array = library.getPhrases(stateName).duplicate()
	var playable: Array = []
	for l in all:
		if l.canPlay:
			playable.append(l)
	if g.dialogue and playable.size() > 0:
		if not states.get(stateName):
			states[stateName] = DialogueState.new(0, 0)
		states[stateName].clearBuild()
		states[stateName].delayBuild()
		var idx: int = states[stateName].randomPhrase(playable)
		var line: DialogueLine = playable[idx] if idx < playable.size() else null
		if line:
			if stateName == FIRST_THROAT and line.style == DialogueLine.SPEAKING_STYLE:
				firstThroatSpoken = true
			if reduceOthers:
				reduceStates()
			startSpeakingPhrase(line)
			sayingState = stateName
			nextLineTimer = 0
	else:
		nextLineTimer = 0


func update() -> void:
	for s in states.values():
		s.reduce()
	if interruptTimer > 0:
		interruptTimer -= 1
		if interruptTimer == 0 and not speaking:
			stopSpeaking()
			g.soundControl.stopDialogue()
	if coughDelay > 0:
		coughDelay -= 1
	# Typing runs on wall-clock time (one character per typingSpeed ms), independent of the tick rate.
	currentTime = Flash.getTimer()
	if not lastFrameTime:
		lastFrameTime = currentTime
	frameTime = currentTime - lastFrameTime
	lastFrameTime = currentTime
	dialogueTicks = int(floor(float(frameTime) / typingSpeed))
	lastFrameTime -= frameTime % typingSpeed
	g.soundControl.updateDialogue()
	if debugMode:
		for k in states:
			if debugBars.get(k):
				debugBars[k].bar.scaleX = states[k].build / states[k].max
	for i in dialogueTicks:
		if speaking and coughDelay == 0:
			typingDelay = 0
			if sayingSpace:
				sayingSpace = false
				var p := {"phoneme": Her.allMouthShapes[int(floor(randf() * Her.allMouthShapes.size()))],
					"sayL": false}
				g.her.setTargetPhoneme(p, 2)
				currentText += " "
				updateTextField()
			elif sayingWord < words.size():
				if sayingSpeakingStyle:
					var ph = words[sayingWord].phoneme(sayingChar)
					if ph:
						var len: int = int(minf(5, maxf(1, words[sayingWord].phonemeLength(sayingChar) * (typingSpeed + 1))))
						g.her.setTargetPhoneme(ph, len)
				currentText += nextChar()
				updateTextField()
			else:
				stopSpeaking()
	if not speaking:
		if showingText and not waitingToContinue:
			if clearDelay < clearTime:
				clearDelay += 1
			else:
				if not debugMode:
					fade(false)
				showingText = false
				updateTextField()
		checkForSpeechStart()
	if fadingOut:
		alpha = maxf(0, alpha - 0.05)
		if alpha == 0:
			fadingOut = false
	elif fadingIn:
		alpha = minf(1, alpha + 0.15)
		if alpha == 1:
			fadingIn = false


func nextChar() -> String:
	if not speaking:
		return ""
	if sayingWord >= words.size():
		stopSpeaking()
		return ""
	var w: Word = words[sayingWord]
	var c := w.letter(sayingChar)
	if sayingChar == 0 and w.actionWord:
		checkWordAction()
		return ""
	sayingChar += 1
	if sayingChar >= w.length and sayingWord < words.size() - 1:
		sayingSpace = true
	if sayingChar >= w.length:
		nextWord()
	return c


func nextWord() -> void:
	sayingChar = 0
	sayingWord += 1


func checkWordAction() -> void:
	if Hooks.has(&"Dialogue.checkWordAction"):   # HOOK (args: the raw word, e.g. "[SETVAR_x_+=5]")
		var h := Hooks.before(&"Dialogue.checkWordAction", self, [words[sayingWord].word])
		if h.cancelled:
			return
	var action := Callable()
	var extraDelay := 0
	match words[sayingWord].action:
		"SWALLOW":
			action = func(): g.her.swallow(0, false)
		"DROOL":
			action = func(): g.her.startDroolingCum(true)
		"COUGH":
			action = g.her.cough
			extraDelay = int(floor(randf() * 15)) + 5
		"CLENCH_TEETH":
			action = g.her.startClenchingTeeth
			extraDelay = int(floor(randf() * 30)) + 30
		"ARMS_BACK":
			action = func(): g.her.setArmPosition(0)
		"ARMS_LEGS":
			action = func(): g.her.setArmPosition(1)
		"ARMS_HIS_LEGS":
			action = func(): g.her.setArmPosition(2)
		"ARMS_HAND_JOB":
			action = func(): g.her.setArmPosition(3)
		"ARMS_LOOSE":
			action = func(): g.her.setArmPosition(4)
		"LEFT_ARM_BACK":
			action = func(): g.her.setLeftArmPosition(0)
		"LEFT_ARM_LEGS":
			action = func(): g.her.setLeftArmPosition(1)
		"LEFT_ARM_HIS_LEGS":
			action = func(): g.her.setLeftArmPosition(2)
		"LEFT_ARM_HAND_JOB":
			action = func(): g.her.setLeftArmPosition(3)
		"LEFT_ARM_LOOSE":
			action = func(): g.her.setLeftArmPosition(4)
		"RIGHT_ARM_BACK":
			action = func(): g.her.setRightArmPosition(0)
		"RIGHT_ARM_LEGS":
			action = func(): g.her.setRightArmPosition(1)
		"RIGHT_ARM_HIS_LEGS":
			action = func(): g.her.setRightArmPosition(2)
		"RIGHT_ARM_HAND_JOB":
			action = func(): g.her.setRightArmPosition(3)
		"RIGHT_ARM_LOOSE":
			action = func(): g.her.setRightArmPosition(4)
		"HOLD":
			action = func(): g.him.setArmPosition(0)
		"RELEASE":
			action = func(): g.him.setArmPosition(1)
		"SHOCK":
			action = func(): g.her.shock(50)
		"WINCE":
			action = g.her.wince
		"CLOSE_EYES":
			action = g.her.closeEye
		"OPEN_EYES":
			action = g.her.openEye
		"BLINK":
			action = g.her.blink
		"LOOK_UP":
			action = g.her.lookUp
		"LOOK_DOWN":
			action = g.her.lookDown
		"TAP_HANDS":
			action = g.her.tapHands
		"NORMAL_MOOD":
			action = func(): g.her.setMood(Her.NORMAL_MOOD)
		"HAPPY_MOOD":
			action = func(): g.her.setMood(Her.HAPPY_MOOD)
		"ANGRY_MOOD":
			action = func(): g.her.setMood(Her.ANGRY_MOOD)
		"AHEGAO_MOOD":
			action = func(): g.her.setMood(Her.AHEGAO_MOOD)
		"NORMAL_STYLE":
			action = func():
				g.animationControl.setAnimation(AnimationControl.DEFAULT)
				g.saveData.saveCharOptionsData()
				g.inGameMenu.setStyleCheckboxes()
		"FACE_FUCK_STYLE":
			action = func():
				g.animationControl.setAnimation(AnimationControl.FACE_FUCK)
				g.saveData.saveCharOptionsData()
				g.inGameMenu.setStyleCheckboxes()
		"EJACULATE":
			action = g.him.ejaculate
		"ADD_TEARS":
			action = g.her.tears.addTears
	if action.is_valid():
		pauseSpeakingForAction(extraDelay)
		nextWord()
		action.call()
	else:
		queuedPhrase = str(words[sayingWord].action)
		states[QUEUED].maxBuild()
		nextWord()


func pauseSpeakingForAction(extra: int = 0) -> void:
	g.her.setSpeaking(false)
	if speaking and sayingSpeakingStyle:
		sayingChar = -1
		continueDelay = int(floor(randf() * 5)) + 3 + extra
		interruptTimer = int(floor(randf() * 50)) + 60 + extra
		g.soundControl.pauseDialogue()
		speaking = false
		clearDelay = 0
		waitingToContinue = true


func continueSpeaking() -> void:
	waitingToContinue = false
	if sayingSpeakingStyle:
		g.her.setSpeaking(true)
	g.soundControl.resumeDialogue()
	speaking = true
	if Hooks.has(&"Dialogue.continueSpeaking"):   # HOOK
		Hooks.after(&"Dialogue.continueSpeaking", self, [])


func startSpeakingPhrase(line: DialogueLine) -> void:
	var p: String = line.phrase
	outputLog("Playing line \"" + p + "\"")
	if line.style == DialogueLine.SPEAKING_STYLE:
		g.her.setSpeaking(true)
		sayingSpeakingStyle = true
	else:
		sayingSpeakingStyle = false
	match line.style:
		DialogueLine.THOUGHT_STYLE:
			_gotoStyle("thought")
		DialogueLine.HIM_STYLE:
			_gotoStyle("him")
		_:
			_gotoStyle("speaking")
	waitingToContinue = false
	if line.nextLine:
		queuedPhrase = line.nextLine
		states[QUEUED].maxBuild()
	advancedController.readAdvancedLineSettings(line)
	var snd: FlashSound = null
	var audio: AudioMod = library.playAudio(p)
	if audio:
		snd = audio.audio
		sayingAudio = snd
	p = unescape(p)
	sayingPhrase = p
	p = replaceTokens(sayingPhrase)
	currentText = ""
	showingText = true
	updateTextField()
	fade(true)
	sayingWord = 0
	sayingChar = 0
	words = []
	p = _reBeforeBracket.sub(p, "$1 [", true)
	p = _reAfterBracket.sub(p, "] $1", true)
	for w in p.split(" "):
		words.append(Word.new(w))
	if snd:
		typingSpeed = int(snd.length / p.length()) if p.length() > 0 else DEFAULT_TYPING_SPEED
	else:
		typingSpeed = DEFAULT_TYPING_SPEED
	# port: in Flash a typing speed of 0 (audio shorter than the text) gave uint(Infinity) = 0 characters per
	# tick, so the line stalled; here it types at the fastest speed instead.
	typingSpeed = maxi(1, typingSpeed)
	nextLineTimer = 0
	typingDelay = 0
	speaking = true
	if Hooks.has(&"Dialogue.startSpeakingPhrase"):   # HOOK
		Hooks.after(&"Dialogue.startSpeakingPhrase", self, [line])


func stopSpeaking() -> void:
	g.her.setSpeaking(false)
	waitingToContinue = false
	speaking = false
	sayingState = ""
	interruptTimer = 0
	clearDelay = 0


func fade(fadeIn: bool) -> void:
	fadingOut = not fadeIn
	fadingIn = fadeIn


func replaceTokens(s: String) -> String:
	s = smartReplace(s, "FINISHES", finishes)
	s = smartReplace(s, "YOUR", partnerPosessive)
	s = smartReplace(s, "YOU", partnerName)
	s = smartReplace(s, "ME", herName)
	s = smartReplace(s, "MY", herPosessive)
	return advancedController.replaceValues(s)


func smartReplace(s: String, token: String, fn: Callable) -> String:
	var re := RegEx.create_from_string("\\*([^\\*]*?)" + token + "([^\\*]*?)\\*")
	var v: String = fn.call()
	if v != "":
		return re.sub(s, "$1" + v.replace("$", "$$") + "$2", true)
	return re.sub(s, "", true)


## Port extension, for readability: the text boxes are drawn 50% opaque (35-45% in the original), the text
## fully opaque (75% for speaking and thought lines) and the thin dialogue font thickened. Box shape id -> its strongest fill
## alpha in the original art.
const BOX_ALPHA := 0.5
const BOX_FILL_ALPHA := {38: 0.349, 44: 0.349, 45: 0.349, 46: 0.451}
const TEXT_EMBOLDEN := 0.8


func _gotoStyle(label: String) -> void:
	gotoAndStop(label)
	for i in numChildren:
		var c = getChildAt(i)
		if c is FlashShape and BOX_FILL_ALPHA.has(c._char_id):
			c.alpha = BOX_ALPHA / BOX_FILL_ALPHA[c._char_id]
	tfContainer.alpha = 1.0
	tfContainer.dialogueField.embolden = TEXT_EMBOLDEN
	if Hooks.has(&"Dialogue.gotoStyle"):   # HOOK (args: "speaking" / "thought" / "him"; after the box and text are set)
		Hooks.after(&"Dialogue.gotoStyle", self, [label])


func updateTextField() -> void:
	tfContainer.dialogueField.text = currentText
	tfContainer.dialogueField.scrollV = maxi(0, tfContainer.dialogueField.numLines - 1)
	if Hooks.has(&"Dialogue.updateTextField"):   # HOOK (after the text changed, every letter)
		Hooks.after(&"Dialogue.updateTextField", self, [])


func randomInterrupt() -> String:
	var p: String = chooseRandomPhrase(library.getPhrases(INTERRUPT)).phrase
	library.playInterruptAudio(p)
	return p


func randomCough() -> String:
	return chooseRandomPhrase(library.getPhrases(COUGH)).phrase


func partnerName() -> String:
	return g.customName if g.customName else ""


func partnerPosessive() -> String:
	if g.customName:
		if g.customName.ends_with("s"):
			return g.customName + "'"
		return g.customName + "'s"
	return ""


func herName() -> String:
	return g.characterControl.currentName if g.characterControl.currentName else ""


func herPosessive() -> String:
	var n: String = g.characterControl.currentName
	if n:
		if n.ends_with("s"):
			return n + "'"
		return n + "'s"
	return ""


func finishes() -> String:
	var list: Array = library.getFinishes(g.totalFinishes)
	return str(list[int(floor(randf() * list.size()))].phrase) if list.size() > 0 else ""


func chooseRandomPhrase(list: Array) -> DialogueLine:
	return list[int(floor(randf() * list.size()))] if list.size() > 0 else DialogueLine.new("")


func outputLog(s: String) -> void:
	g.dialogueEditor.appendLog(s)


## AS3 global unescape(): decodes %XX and %uXXXX sequences, leaving malformed ones untouched.
static func unescape(s: String) -> String:
	var out := ""
	var i := 0
	var n := s.length()
	while i < n:
		var c := s[i]
		if c == "%":
			if i + 5 < n + 0 and s[i + 1] == "u" and _reHex4.search(s.substr(i + 2, 4)):
				out += char(s.substr(i + 2, 4).hex_to_int())
				i += 6
				continue
			if i + 2 < n and _reHex2.search(s.substr(i + 1, 2)):
				out += char(s.substr(i + 1, 2).hex_to_int())
				i += 3
				continue
		out += c
		i += 1
	return out
