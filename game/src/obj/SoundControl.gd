class_name SoundControl
extends RefCounted
## Port of obj.SoundControl: breathing (in/out, fast, sudden, quiet), coughs, gags, sucks, licks, holds, cum and
## rub loops, dialogue audio, and global volume.

var globalVol: float = 1.0
var breathing := false
var fadingBreath := false
var beingHeld := false
var playingInBreath := false
var justStartedBreath := false
var startOnInBreath := false
var openCoughing := false
var waitingToBreathe := false
var cumPlaying: int = 0
var queuedCoughs: int = 0
var consecutiveCoughs: int = 0
var maxConsecutiveCoughs: int = 1
var quietBreathingLevel: float = 1.0   # port: a variable so moremoods can change it (a private const in the original)
var lastBreath: int = 0
var lastInBreath: int = 0
var lastSuddenBreath: int = 0
var lastRandomGag: int = 0
var lastRandomHold: int = 0
var lastRandomCough: int = 0
var lastRandomOpenCough: int = 0
var lastRandomDown: int = 0
var lastRandomSuck: int = 0
var lastRandomTouch: int = 0
var lastRandomSplat: int = 0
var lastRandomPassOut: int = 0
var lastRandomSwallow: int = 0
var lastRandomLick: int = 0
var breathStartTime: int = 0
var leftPan: float = -0.4
var rightPan: float = 0.4
var currentBreath: FlashSoundChannel = null
var currentBreathST := FlashSoundTransform.new(0, 0)
var currentOpenCough: FlashSoundChannel = null
var currentBreathVolume: float = 0.0
var currentHoldSound: FlashSoundChannel = null
var currentCum: FlashSoundChannel = null
var currentCumVolume: float = 0.0
var dialogueSound: FlashSound = null
var dialogueVol: float = 1.0
var dialogueChannel: FlashSoundChannel = null
var playingDialogue := false
var dialogueStartTime: int = 0
var dialogueResumeTime: int = 0
var currentBreathSound: FlashSound = null
var customCoughs = null
var normalBreath: Array
var breatheIn: Array
var fastBreath: Array
var suddenBreath: Array
var quietBreath: Array
var down: Array
var gag: Array
var suck: Array
var touch: Array
var splat: Array
var cough: Array
var openCough: Array
var held: Array
var passOut: Array
var swallow: Array
var lick: Array
var cum: Array
var cumInside: Array
var grab: FlashSound
var rub: FlashSound
var rubSC: FlashSoundChannel = null
var rubST: FlashSoundTransform = null
var intro: FlashSound
## Port: which of her sounds is asking value point SoundControl.herSoundVolume (&"cough", &"openCough", &"gag",
## &"passOut"), for its modifiers
var herSound: StringName = &""


func _init() -> void:
	initSoundEffects()


static func getTimer() -> int:
	return Flash.getTimer()


func _pan(p: float) -> float:
	return maxf(leftPan, minf(rightPan, p * 2.0 - 1.0))


## Picks a random index different from 'last' (the original loops until it differs). port: with one sound or none
## it returns 0 instead of looping forever as the original would.
static func _pick(list: Array, last: int) -> int:
	if list.size() <= 1:
		return 0
	var i := int(floor(randf() * list.size()))
	while i == last:
		i = int(floor(randf() * list.size()))
	return i


static func _play(s: FlashSound, vol: float, pan: float, start: float = 0.0) -> FlashSoundChannel:
	var ch := s.play(start)
	if ch:
		ch.soundTransform = FlashSoundTransform.new(vol, pan)
	return ch


## Port: the volume of one of her sounds after value point SoundControl.herSoundVolume (herSound says which)
func _her_volume(which: StringName, vol: float) -> float:
	if not Hooks.has_value(&"SoundControl.herSoundVolume"):   # HOOK value point: the volume of her cough, open cough, gag, pass-out sound
		return vol
	herSound = which
	vol = Hooks.value(&"SoundControl.herSoundVolume", self, vol)
	herSound = &""
	return vol


func loadAudioMod(kind: String, mod) -> void:
	if customCoughs == null:
		customCoughs = []
	if kind == "cough" and mod:
		customCoughs.append(mod)


func resetAudioMods() -> void:
	customCoughs = null


func changeVolume(v: float) -> void:
	globalVol = v
	if g.mute:
		g.mute = false
	Flash.set_master_volume(globalVol)


func increaseVolume() -> void:
	globalVol = minf(1.0, Maths.round(globalVol * 10.0 + 1.0) / 10.0)
	changeVolume(globalVol)
	g.inGameMenu.updateVolumeSlider(globalVol)


func decreaseVolume() -> void:
	globalVol = maxf(0.0, Maths.round(globalVol * 10.0 - 1.0) / 10.0)
	changeVolume(globalVol)
	g.inGameMenu.updateVolumeSlider(globalVol)


func toggleMute() -> void:
	if not g.mute:
		muteSound()
	else:
		g.mute = false
		Flash.set_master_volume(globalVol)
		g.inGameMenu.updateVolumeSlider(globalVol)


func muteSound() -> void:
	g.mute = true
	Flash.set_master_volume(0)
	g.inGameMenu.updateVolumeSlider(0)


func startBreathingWithCough() -> bool:
	if g.breathing:
		playOpenCough()
		startBreathing()
	return breathing


func startBreathing(fromInBreath: bool = false) -> bool:
	if g.breathing and not playingDialogue:
		if fromInBreath:
			stopBreathing(true)
			openCoughing = false
		if openCoughing:
			waitingToBreathe = true
		else:
			playStartBreath(fromInBreath)
			waitingToBreathe = false
		breathing = true
		fadingBreath = false
	return breathing


func playStartBreath(fromInBreath: bool = false) -> void:
	if Hooks.has(&"SoundControl.playStartBreath"):   # HOOK
		var h := Hooks.before(&"SoundControl.playStartBreath", self, [fromInBreath])
		if h.cancelled:
			return
		fromInBreath = h.args[0]
	if g.breathLevel > g.outOfBreathPoint and not g.her.passedOut:
		newSuddenBreath()
	elif startOnInBreath or fromInBreath:
		newInBreath()
	elif queuedCoughs > 0 and consecutiveCoughs < maxConsecutiveCoughs:
		playOpenCough()
	else:
		newRandomBreath()


func stopBreathing(immediate: bool = false) -> bool:
	if breathing:
		var p := breathPosition()
		if immediate:
			if currentBreath:
				currentBreath.stop()
			if openCoughing:
				stopOpenCough()
		else:
			fadingBreath = true
		breathing = false
		waitingToBreathe = false
		startOnInBreath = g.breathLevel >= quietBreathingLevel and p > 0.1 and p < 0.6
	return breathing


func tick() -> void:
	if fadingBreath:
		currentBreathVolume = maxf(0.0, currentBreathVolume - 0.25)
		if currentBreathVolume <= 0:
			if currentBreath:
				currentBreath.stop()
			fadingBreath = false
	if currentBreath:
		currentBreathST.volume = currentBreathVolume * maxf(0.4, g.herMouthOpeness)
		currentBreathST.pan = leftPan
		currentBreath.soundTransform = currentBreathST


func breathPosition() -> float:
	if breathing and not openCoughing and currentBreathSound:
		var t := getTimer()
		if playingInBreath:
			return (t - breathStartTime) / currentBreathSound.length / 2.0 + 0.5
		return (t - breathStartTime) / currentBreathSound.length
	return 0.0


func justBreathedOut() -> bool:
	if justStartedBreath:
		justStartedBreath = false
		return true
	return false


func startHolding() -> void:
	if Hooks.has(&"SoundControl.startHolding"):   # HOOK
		var h := Hooks.before(&"SoundControl.startHolding", self)
		if h.cancelled:
			return
	if not beingHeld:
		newRandomHoldSound()
		beingHeld = true
	if Hooks.has(&"SoundControl.startHolding"):   # HOOK
		Hooks.after(&"SoundControl.startHolding", self)


func stopHolding() -> void:
	if beingHeld:
		if currentHoldSound:
			currentHoldSound.stop()
		beingHeld = false


func queueOpenCough() -> void:
	queuedCoughs = mini(5, queuedCoughs + 1)


func playIntro() -> void:
	_play(intro, 1, 0)


func playTouch() -> void:
	var i := _pick(touch, lastRandomTouch)
	lastRandomTouch = i
	_play(touch[i], 0.5, leftPan)


func playDown(p: float, movement: float) -> void:
	var vol := minf(1.0, movement / 40.0)
	var i := _pick(down, lastRandomDown)
	lastRandomDown = i
	_play(down[i], vol, _pan(p))


func playUp(p: float, movement: float) -> void:
	var vol := minf(1.0, movement / 40.0)
	var i := _pick(suck, lastRandomSuck)
	lastRandomSuck = i
	_play(suck[i], vol, _pan(p))


func playGag(p: float) -> void:
	if Hooks.has(&"SoundControl.playGag"):   # HOOK
		var h := Hooks.before(&"SoundControl.playGag", self, [p])
		if h.cancelled:
			return
		p = h.args[0]
	var vol := 0.5 + randf() * 0.2
	var i := _pick(gag, lastRandomGag)
	lastRandomGag = i
	_play(gag[i], _her_volume(&"gag", vol), _pan(p))


func playCough() -> void:
	var i := _pick(cough, lastRandomCough)
	lastRandomCough = i
	_play(cough[i], _her_volume(&"cough", 1.0), rightPan)


func playSplat() -> void:
	var i := _pick(splat, lastRandomSplat)
	lastRandomSplat = i
	_play(splat[i], 1, rightPan)


func playPassOut(p: float = 0.0) -> void:
	var i := _pick(passOut, lastRandomPassOut)
	lastRandomPassOut = i
	_play(passOut[i], _her_volume(&"passOut", 1.0), _pan(p))


func playGrab(p: float = 0.0, vol: float = 1.0) -> void:
	_play(grab, 0.5 * vol, _pan(p))


func playSwallow(p: float = 0.0) -> void:
	var i := _pick(swallow, lastRandomSwallow)
	lastRandomSwallow = i
	_play(swallow[i], 1, _pan(p))


func playLick(p: float = 0.0) -> void:
	var i := _pick(lick, lastRandomLick)
	lastRandomLick = i
	_play(lick[i], 0.4, _pan(p))


func startRub() -> void:
	if rubSC == null:
		rubSC = rub.play()
		rubSC.addEventListener(FlashEvent.SOUND_COMPLETE, rubFinished)
		updateRub()


func stopRub() -> void:
	rubFinished()


func updateRub(vol: float = 0.0, p: float = 0.0) -> void:
	if rubSC:
		if rubST == null:
			rubST = FlashSoundTransform.new(0, 0)
			rubSC.soundTransform = rubST
		rubST.volume += (vol - rubST.volume) * 0.3
		rubST.pan = _pan(p)
		rubSC.soundTransform = rubST


## (sic) as in the original, stopping the rub immediately starts it again.
func rubFinished(_e = null) -> void:
	if rubSC:
		rubSC.stop()
		rubSC.removeEventListener(FlashEvent.SOUND_COMPLETE, rubFinished)
		rubSC = null
		startRub()


func playCum(inside: bool = false) -> void:
	cumPlaying = int(floor(randf() * cum.size()))
	currentCumVolume = 0.8
	currentCum = _play(cumInside[cumPlaying] if inside else cum[cumPlaying], currentCumVolume, leftPan)


func switchCumInside() -> void:
	if currentCum:
		var p := currentCum.position
		currentCum.stop()
		currentCum = _play(cumInside[cumPlaying], currentCumVolume, leftPan, p)


func switchCumOutside() -> void:
	if currentCum:
		var p := currentCum.position
		currentCum.stop()
		currentCum = _play(cum[cumPlaying], currentCumVolume, leftPan, p)


func adjustCumVolume(scale: float, base: float) -> void:
	currentCumVolume = scale * 0.5 + base
	if currentCum:
		currentCum.soundTransform = FlashSoundTransform.new(currentCumVolume, leftPan)


func fadeCumVolume(amount: float = 0.05) -> bool:
	currentCumVolume = maxf(0.0, currentCumVolume - amount)
	if currentCum:
		currentCum.soundTransform = FlashSoundTransform.new(currentCumVolume, leftPan)
	return currentCumVolume > 0


func newRandomHoldSound() -> void:
	var i := _pick(held, lastRandomHold)
	lastRandomHold = i
	currentHoldSound = _play(held[i], 1, rightPan)
	if currentHoldSound:
		currentHoldSound.addEventListener(FlashEvent.SOUND_COMPLETE, holdFinished)


func holdFinished(_e = null) -> void:
	if beingHeld:
		newRandomHoldSound()


func _startBreathSound(s: FlashSound) -> void:
	currentBreathSound = s
	currentBreath = s.play()


func newRandomBreath() -> void:
	if not g.breathing:
		return
	consecutiveCoughs = 0
	playingInBreath = false
	justStartedBreath = true
	if g.breathLevel > g.outOfBreathPoint and not g.her.passedOut:
		var i := _pick(fastBreath, lastBreath)
		lastBreath = i
		_startBreathSound(fastBreath[i])
		g.addBreath(-2)
	elif g.breathLevel < quietBreathingLevel:
		var i := _pick(quietBreath, lastBreath)
		lastBreath = i
		_startBreathSound(quietBreath[i])
		g.addBreath(-0.5)
	else:
		var i := _pick(normalBreath, lastBreath)
		lastBreath = i
		_startBreathSound(normalBreath[i])
		g.addBreath(-1)
	var open := maxf(0.4, g.herMouthOpeness)
	if Hooks.has_value(&"SoundControl.breathOpenness"):   # HOOK value point: how much her open mouth makes the breath loud (the game: her mouth's openness, at least 0.4)
		open = Hooks.value(&"SoundControl.breathOpenness", self, open)
	if g.her.passedOut:
		currentBreathVolume = 0.15 * open
	else:
		currentBreathVolume = minf(1.0, g.breathLevel / g.outOfBreathPoint + 0.15) * open
	currentBreathST.volume = currentBreathVolume
	currentBreathST.pan = leftPan
	if currentBreath:
		currentBreath.soundTransform = currentBreathST
		breathStartTime = getTimer()
		currentBreath.addEventListener(FlashEvent.SOUND_COMPLETE, breathFinished)
	if Hooks.has(&"SoundControl.newRandomBreath"):   # HOOK
		Hooks.after(&"SoundControl.newRandomBreath", self)


func newInBreath() -> void:
	consecutiveCoughs = 0
	playingInBreath = true
	var i := _pick(breatheIn, lastInBreath)
	lastInBreath = i
	_startBreathSound(breatheIn[i])
	if currentBreath:
		currentBreathVolume = minf(1.0, g.breathLevel / 20.0 + 0.5)
		currentBreathST.volume = currentBreathVolume
		currentBreathST.pan = leftPan
		currentBreath.soundTransform = currentBreathST
		breathStartTime = getTimer()
		currentBreath.addEventListener(FlashEvent.SOUND_COMPLETE, breathFinished)


func newSuddenBreath() -> void:
	consecutiveCoughs = 0
	playingInBreath = true
	var i := _pick(suddenBreath, lastSuddenBreath)
	lastSuddenBreath = i
	_startBreathSound(suddenBreath[i])
	if currentBreath:
		currentBreathVolume = minf(1.0, g.breathLevel / 20.0 + 0.5)
		currentBreathST.volume = currentBreathVolume
		currentBreathST.pan = leftPan
		currentBreath.soundTransform = currentBreathST
		breathStartTime = getTimer()
		currentBreath.addEventListener(FlashEvent.SOUND_COMPLETE, breathFinished)


func playOpenCough() -> void:
	if consecutiveCoughs == 0:
		maxConsecutiveCoughs = int(minf(maxf(1, queuedCoughs), ceil(randf() * 2) + 1))
	consecutiveCoughs += 1
	if queuedCoughs > 0:
		queuedCoughs -= 1
	var vol := 0.4
	var mod = g.dialogueControl.cough()
	if mod:
		currentOpenCough = mod.audio.play()
		vol = mod.volume
	elif customCoughs:
		var i := 0
		if customCoughs.size() > 1:
			i = _pick(customCoughs, lastRandomOpenCough)
		lastRandomOpenCough = i
		currentOpenCough = customCoughs[i].audio.play()
		vol = float(customCoughs[i].volume)
	else:
		var i := _pick(openCough, lastRandomOpenCough)
		lastRandomOpenCough = i
		currentOpenCough = openCough[i].play()
	if currentOpenCough:
		currentOpenCough.soundTransform = FlashSoundTransform.new(_her_volume(&"openCough", vol), leftPan)
		currentOpenCough.addEventListener(FlashEvent.SOUND_COMPLETE, coughFinished)
		openCoughing = true
		startOnInBreath = true
		pauseDialogue()
		g.her.openCough()
	else:
		playStartBreath()


func coughFinished(_e = null) -> void:
	resumeDialogue()
	currentOpenCough.removeEventListener(FlashEvent.SOUND_COMPLETE, coughFinished)
	# Flash Timer with a random 0-100 ms delay
	Flash.get_tree().create_timer(floor(randf() * 100.0) / 1000.0, true).timeout.connect(delayedCoughFinish)


func stopOpenCough() -> void:
	if currentOpenCough:
		currentOpenCough.stop()
	openCoughing = false
	if currentOpenCough and currentOpenCough.hasEventListener(FlashEvent.SOUND_COMPLETE):
		currentOpenCough.removeEventListener(FlashEvent.SOUND_COMPLETE, coughFinished)


func delayedCoughFinish() -> void:
	if openCoughing:
		openCoughing = false
		if breathing:
			if queuedCoughs > 0 and consecutiveCoughs < maxConsecutiveCoughs:
				playOpenCough()
			else:
				playStartBreath()


func breathFinished(e = null) -> void:
	if e:
		e.target.removeEventListener(FlashEvent.SOUND_COMPLETE, breathFinished)
	if breathing:
		if queuedCoughs > 0 and consecutiveCoughs < maxConsecutiveCoughs:
			playOpenCough()
		else:
			newRandomBreath()


func playDialogue(mod) -> void:
	if playingDialogue and dialogueChannel:
		stopDialogue()
	g.her.stopBreathing()
	dialogueSound = mod.audio
	dialogueVol = mod.volume
	dialogueChannel = dialogueSound.play()
	if dialogueChannel:
		dialogueChannel.addEventListener(FlashEvent.SOUND_COMPLETE, dialogueFinished)
		dialogueChannel.soundTransform = FlashSoundTransform.new(dialogueVol, _pan(g.herCurrentPos))
		dialogueStartTime = getTimer()
		dialogueResumeTime = 0
		playingDialogue = true


func updateDialogue() -> void:
	if dialogueChannel:
		dialogueChannel.soundTransform = FlashSoundTransform.new(0.9, _pan(g.herCurrentPos))


func playDialogueInterrupt(mod) -> void:
	_play(mod.audio, mod.volume, _pan(g.currentPos.x))


func dialogueFinished(e = null) -> void:
	if e:
		e.target.removeEventListener(FlashEvent.SOUND_COMPLETE, dialogueFinished)
	dialogueSound = null
	dialogueChannel = null
	playingDialogue = false
	g.her.checkBreathing(true)


func pauseDialogue() -> void:
	if playingDialogue and dialogueChannel:
		stopDialogue()
		playingDialogue = true
		dialogueResumeTime = getTimer() - dialogueStartTime


func stopDialogue() -> void:
	if dialogueChannel:
		dialogueChannel.removeEventListener(FlashEvent.SOUND_COMPLETE, dialogueFinished)
		dialogueChannel.stop()
		dialogueChannel = null
		playingDialogue = false


func resumeDialogue(at: int = -1) -> void:
	if playingDialogue and dialogueSound:
		if at == -1:
			at = dialogueResumeTime
		if dialogueChannel:
			stopDialogue()
		dialogueChannel = dialogueSound.play(at)
		if dialogueChannel:
			dialogueChannel.addEventListener(FlashEvent.SOUND_COMPLETE, dialogueFinished)
			dialogueChannel.soundTransform = FlashSoundTransform.new(dialogueVol, _pan(g.currentPos.x))
			dialogueStartTime = getTimer() - at
			playingDialogue = true


static func _sounds(names: Array) -> Array:
	var out: Array = []
	for n in names:
		out.append(FlashSound.named(n))
	return out


static func _range(prefix: String, from: int, to: int) -> Array:
	var out: Array = []
	for i in range(from, to + 1):
		out.append(prefix + str(i))
	return out


func initSoundEffects() -> void:
	normalBreath = _sounds(_range("sfxBreathe", 10, 17) + ["sfxMoanBreathe8", "sfxMoanBreathe9", "sfxBreathe4"])
	breatheIn = _sounds(_range("sfxBreatheIn", 2, 6))
	fastBreath = _sounds(_range("sfxBreathe", 5, 9))
	suddenBreath = _sounds(["sfxCoughBreathe2", "sfxCoughBreathe6", "sfxCoughBreathe7", "sfxCoughBreathe8",
		"sfxCoughBreathe10", "sfxBreatheIn1", "sfxMoanBreathe6", "sfxMoanBreathe7"])
	quietBreath = _sounds(_range("sfxQuietBreath", 1, 4))
	down = _sounds(_range("sfxDown", 1, 10))
	touch = _sounds(_range("sfxTouch", 1, 3))
	gag = _sounds(_range("sfxGag", 1, 15))
	suck = _sounds(_range("sfxSuck", 1, 18) + ["sfxMoanSuck1", "sfxMoanSuck2"])
	cough = _sounds(_range("sfxCough", 1, 7))
	openCough = _sounds(_range("sfxOpenCough", 1, 12))
	held = _sounds(_range("sfxHeld", 1, 13))
	splat = _sounds(_range("sfxSplat", 1, 3))
	passOut = _sounds(_range("sfxPassOut", 1, 3))
	swallow = _sounds(_range("sfxSwallow", 1, 12))
	lick = _sounds(_range("sfxLick", 1, 8))
	cum = _sounds(["sfxCum1", "sfxCum2"])
	cumInside = _sounds(["sfxCumInside1", "sfxCumInside2"])
	grab = FlashSound.named("sfxGrab")
	rub = FlashSound.named("sfxRub")
	intro = FlashSound.named("sfxIntro")
