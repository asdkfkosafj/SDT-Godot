extends RefCounted
## moremoods, how she behaves per mood: breathing, pulling off, biting, panic eyebrows, drooling and other timer
## actions, tongue, blushing, clenching, coughs, hand tapping, off-penis actions, sweat. A late tick (moremoods'
## ENTER_FRAME work) plus hooks before / after the game functions the Loader mod wrapped or replaced.
## Numbers follow moremoods v18. The vomiting feature is left out (it is switched off in moremoods itself).

const QUIET_GAGS := [2, 5, 7, 10]
const LOUD_GAGS := [0, 1, 3, 4, 6, 8, 9, 11, 12, 13, 14]

var mm   # moremoods.gd

# bite button: 0 off, 1 by mood, 2 by slider
var bite_mode := 1
var bite_slider := 0.6
var bite_timer := 0

var _breath_fright := false
var _breath_spent := false
var lowered_breath := false
var _prev_quiet := 0.0
var _prev_out_of_breath := 25.0
var _rand_pulloff := 1.0
var _prev_held := false
var _prev_mouth := false
var _prev_pulloff := 0.0
var _prev_pull_power := 0.0
var _prev_marked_power := 0.0
var _delayed_push := 0.0
var _fright_held_timer := 0
var _spit_drool_flag := false
var _spit_drool_timer := 0
var wanting_hang_tongue := false
var _tongue_flag := false
var _not_held_timer := 0
var _outside_timer := 0
var _fright_blush_flag := false
var _last_quiet_gag := -1
var _last_loud_gag := -1
var _mouth_before_sounds := false
var _action_tracker := 0
var _eye_change_holder := Vector2.ZERO
var _eye_change_timer := 0
# panic eyebrows
var _brow_offsets: Array = []
var _panic := 0.0
var _past_breath_brow := 0.0
# blush (percent above her own blush colour)
var _blush := 0.0
var _blush_target := 0.0
var _blush_rate := 0.0
var _blush_timer := 0


func _init(p_mm) -> void:
	mm = p_mm


func s(key: String):
	return mm.get_setting(key)


func hook() -> void:
	mm.on_late_tick(tick)
	mm.hook_before(&"Her.tapHands", _tap_hands)
	mm.hook_before(&"Her.cough", _cough)
	mm.hook_before(&"Her.openCough", _open_cough)
	mm.hook_before(&"Her.passOut", _pass_out)
	mm.hook_after(&"SoundControl.startHolding", func(_c): if mm.mood_name == "Asleep" and not s("asleepthroatsound"): g.soundControl.stopHolding())
	mm.hook_before(&"Her.checkMovementSounds", func(_c): _mouth_before_sounds = g.her.mouthFull)
	mm.hook_after(&"Her.checkMovementSounds", func(_c): _after_movement_sounds())
	mm.hook_after(&"SoundControl.newRandomBreath", func(_c): _lowered_breath_step())
	mm.hook_before(&"Her.ejaculating", func(_c): mm.face.angry_look_flag = false)
	mm.hook_after(&"Her.ejaculating", func(_c): _after_ejaculating())
	mm.hook_after(&"InGameMenu.shuffle", func(c): _shuffle(c))
	mm.hook_after(&"Tears.drawLowerEyelidMascara", func(_c): mm.face.clear_lower_eyelid())
	mm.hook_after(&"Tears.clearLowerEyelid", func(_c): mm.face.clear_lower_eyelid())
	mm.hook_before(&"Tongue.update", _tongue_update)
	mm.hook_after(&"Tongue.update", func(_c): _tongue_unstick())
	var da = Extensions.get_extension("dialogueactions")
	if da != null and da.enabled and not da.has_trigger("BITE", 0):
		da.register_trigger("BITE", 0, func(_a): _bite_trigger())
	var dc = g.dialogueControl
	dc.states["moremoods_bitten"] = DialogueState.new(s("moremoods_bittenlife"), s("moremoods_bittenpriority"))


func remove() -> void:
	_restore_breath()
	_set_blush(0)


# ---------------------------------------------------------------- every tick

func tick() -> void:
	var her = g.her
	var him = g.him
	var m: String = mm.mood_name
	if m == "Android" or m == "Asleep":
		her.blinkTime = 90
	_breathing(m)
	if m in ["Spent", "Depressed", "Elated", "Broken", "Horny", "Android", "Devoted", "Numb", "Asleep"] or (m == "Aggressive" and s("nopulloffonaggressive")):
		_reset_pulloff()
	var pp: Dictionary = her.pullOffPower
	if m == "Tease" and her.held:
		pp["current"] = minf(pp["max"], pp["current"] + pp["increase"])
	if m == "Drugged":
		if randf() * 100 > 97:
			_rand_pulloff = (5 + randf() * 10) / 10.0
		if her.pullOff > 0:
			her.pullOff = maxf(0, her.pullOff - pp["current"] * _rand_pulloff)
	if m == "Aggressive" or m == "Overwhelmed":
		_delayed_pulloff(0.1, 0.6)
	if m == "Excited":
		_delayed_pulloff(0.25, 0.8)
	if m == "Smug" or m == "Professional":
		_delayed_pulloff(0.5, 0.9)
	if m == "Submissive":
		if her.passOutFactor / her.passOutMax < 0.25:
			_reset_pulloff()
		else:
			her.pullOff = maxf(0, her.pullOff - pp["current"] * 0.9)
			her.pullOff = minf(2.0 / 3.0 * (1 - her.passOutFactor / her.passOutMax), her.pullOff)
	if m == "Tease":
		_tease_pulloff()
	_bite_chance(m)
	_check_bite()
	if m == "Tease" and her.mouthFull:
		her.speed = her.speed * (1 - minf(1, her.vigour / her.VIGOUR_WINCE_LEVEL))
	if m in ["Worried", "Frightened", "Submissive", "Depressed", "Nervous", "Broken", "Smug", "Overwhelmed", "Devoted"] or (m == "Asleep" and s("asleepeyebrowshape") == 1):
		if not g.gamePaused:
			_panic_eyebrows()
	if not g.gamePaused:
		_timer_actions(m)
	_tongue(m)
	_blush_rules(m)
	if m == "Tease" and not g.gamePaused:
		_tease_clench()
	_prev_mouth = her.mouthFull
	_prev_held = her.held
	_prev_pulloff = her.pullOff
	_prev_pull_power = pp["current"]
	if not her.mouthFull:
		_outside_timer = mini(100, _outside_timer + 1)
	else:
		if her.held:
			_fright_blush_flag = false
		_outside_timer = 0
	_not_held_timer = 0 if her.held else mini(500, _not_held_timer + 1)
	_tick_blush()


func _breathing(m: String) -> void:
	var sc = g.soundControl
	if m in ["Frightened", "Excited", "Horny", "Overwhelmed"]:
		if not _breath_fright and not _breath_spent:
			_prev_quiet = sc.quietBreathingLevel
			sc.quietBreathingLevel = -5
			_breath_fright = true
	elif _breath_fright:
		sc.quietBreathingLevel = _prev_quiet
		_breath_fright = false
	if m in ["Spent", "Broken", "Android", "Numb", "Asleep"]:
		lowered_breath = true
		if not _breath_spent and not _breath_fright:
			_prev_out_of_breath = g.outOfBreathPoint
			_prev_quiet = sc.quietBreathingLevel
			mm.modify(&"Her.breathMax", {"phase": Hooks.MOOD, "op": "set", "value": 4.0})
			mm.modify(&"Her.outOfBreathPoint", {"phase": Hooks.MOOD, "op": "fn", "fn": func(_v, _her): return g.breathLevelMax})
			sc.quietBreathingLevel = 5
			g.resolveBreath()   # now, keeping how much of her breath is used
			_breath_spent = true
	else:
		lowered_breath = false
		if _breath_spent:
			_restore_breath()


func _restore_breath() -> void:
	var sc = g.soundControl
	if _breath_spent:
		mm.unmodify(&"Her.breathMax")
		mm.unmodify(&"Her.outOfBreathPoint")
		sc.quietBreathingLevel = _prev_quiet
		g.resolveBreath()
		_breath_spent = false
	if _breath_fright:
		sc.quietBreathingLevel = _prev_quiet
		_breath_fright = false


## After SoundControl.newRandomBreath: the lowered-breath moods lose breath more slowly.
func _lowered_breath_step() -> void:
	if lowered_breath and _breath_spent and g.breathing:
		if g.breathLevel > _prev_out_of_breath and not g.her.passedOut:
			g.addBreath(-1.5)
		elif g.breathLevel < _prev_quiet:
			pass
		else:
			g.addBreath(-0.5)


func _reset_pulloff() -> void:
	g.her.pullOff = 0
	g.her.pullOffPower["current"] = 0


## No pulling off until she is low on breath (below `start` of pass-out), then a reduced pull-off.
func _delayed_pulloff(start: float, keep: float) -> void:
	var her = g.her
	if her.passOutFactor / her.passOutMax < start:
		_reset_pulloff()
	else:
		her.pullOff = maxf(0, her.pullOff - her.pullOffPower["current"] * keep)


func _him_pleasure() -> float:
	return clampf(g.him.pleasure / g.him.ejacPleasure, 0, 1)


func _tease_pulloff() -> void:
	var her = g.her
	var pp: Dictionary = her.pullOffPower
	if her.pullOff > 0:
		her.pullOff = minf(1, her.pullOff + pp["current"] * _him_pleasure() * 3)
	if her.mouthFull:
		var r := clampf((her.penisInMouthDist - 100) / 300.0, 0, 1)
		if _prev_held and not her.held:
			her.pullOff = _prev_pulloff
			pp["current"] = _prev_pull_power
			_prev_marked_power = _prev_pull_power
		her.pullOff = maxf(her.pullOff, r / 15.0)
		_prev_marked_power = maxf(_prev_marked_power, her.pullOff)
		if not her.held:
			her.pullOff = _prev_marked_power * (0.5 + r / 2)
		her.pullOff = minf(0.25, her.pullOff)
	else:
		if her.pullOff > 0.1:
			her.pullOff = 0.1
			pp["current"] = 0
		if her.pullOff > 0.01:
			her.pullOff = her.pullOff * 0.8
			pp["current"] = pp["current"] * 0.8
		else:
			her.pullOff = 0
			pp["current"] = 0
		_prev_marked_power = 0
	if g.him.ejaculating:
		her.pullOff = 0
		pp["current"] = 0


# ---------------------------------------------------------------- biting

func _bite_trigger() -> void:
	var her = g.her
	if bite_mode > 0 and not her.gagged and her.mouthFull and bite_timer == 0 and not her.swallowing:
		bite_timer = 70


func _bite_chance(m: String) -> void:
	var her = g.her
	if bite_mode <= 0:
		return
	if her.gagged or not her.held or not her.mouseHeld or bite_timer != 0 or her.swallowing or g.him.ejaculating:
		return
	var p := 0.0
	var b := 0.0
	var d := 0.0
	var pf := minf(1, her.passOutFactor / her.passOutMax)
	var br := minf(1, g.breathLevel / g.breathLevelMax)
	var dp := clampf((her.penisInMouthDist - her.deepthroatDistance) / (her.hiltDistance - her.deepthroatDistance), 0, 1)
	if bite_mode == 1:
		if m == "Aggressive" and s("aggressivemoodbite"):
			p = pf
		if m == "Tease":
			p = pf
			b = br
		if (m == "Angry" and s("angrymoodbite")) or (m == "Upset" and s("upsetmoodbite")) or (m == "Disgusted" and s("disgustedmoodbite")):
			p = pf
			b = br
			d = dp
	else:
		p = clampf(bite_slider * 3, 0, 1) * pf
		b = clampf((bite_slider - 1.0 / 3.0) * 3, 0, 1) * br
		d = clampf((bite_slider - 2.0 / 3.0) * 3, 0, 1) * dp
	if randf() < (p + b + d) / s("biteoccurancedivisor"):
		bite_timer = 70


## The bite, frame by frame: she swallows hard, taps, he flinches (red flash, less pleasure, the
## moremoods_bitten line), then she pushes off.
func _check_bite() -> void:
	var her = g.her
	var him = g.him
	if bite_timer > 0:
		match bite_timer:
			70:
				her.tongue.doNothing()
				her.tongue.stopHangingOut()
				var sq: Dictionary = her.swallowSequence
				sq["intensity"] = 0.8
				her.swallowing = true
				sq["build"] = roundi(30 * sq["intensity"])
				sq["swallow"] = roundi(sq["build"] + 16 * sq["intensity"])
				sq["relax"] = roundi(sq["swallow"] + 16 * sq["intensity"] / 2)
				sq["end"] = roundi(sq["relax"] + 30 * sq["intensity"] / 2)
				her.swallowTimer = 0
				her.startSwallowTimer = 0
			45:
				if her.mouthFull:
					_original_tap_hands()
			40:
				if her.held:
					var choices := [2, 6, 7, 8, 9]
					var snd = g.soundControl.down[choices[int(randf() * choices.size()) % choices.size()]]
					if snd != null:
						snd.play()
			38:
				if her.mouthFull:
					g.screenEffects.whiteFlash.colorTransform = FlashColorTransform.new(0, 0, 0, 1, 255, 0, 0, 0)
					g.screenEffects.showPulse()
					if him.pleasure < him.ejacPleasure:
						him.pleasure = him.pleasure * 0.7
					g.dialogueControl.buildState("moremoods_bitten", 8000)
			26:
				if her.mouthFull:
					if not g.handsOff:
						her.pullingOff = true
						her.released = true
						him.openHand()
					else:
						_delayed_push = 175 + 300 * clampf(g.currentMousePos.x / 12.0 * 10.0, 0, 1)
			25:
				g.screenEffects.whiteFlash.colorTransform = FlashColorTransform.new(0, 0, 0, 1, 255, 255, 255, 0)
		her.pullOff = 0
		if her.mouthFull and her.pullingOff and not g.handsOff:
			her.armsPushPower = 175 + 300 * clampf(g.currentMousePos.x / 12.0 * 10.0, 0, 1)
		if her.swallowTimer == her.swallowSequence["swallow"] - 1:
			her.swallowTimer = her.swallowSequence["swallow"] + 1
		bite_timer = maxi(bite_timer - 1, 0)
	if _delayed_push > 0:
		_delayed_push = maxf(0, _delayed_push - 10)
		if _delayed_push > 100:
			her.speed = her.speed - her.acceleration + (Her.releasedPos - her.pos) / her.moveSmoothing
		else:
			her.speed = her.speed + (-her.acceleration + (Her.releasedPos - her.pos) / her.moveSmoothing) * (_delayed_push / 100.0)


# ---------------------------------------------------------------- panic eyebrows

const MIN_BROW := 170
const MAX_BROW := 200
const MAX_BROW_ANGRY := 200


func _min_brow() -> float:
	return 110.0 if mm.face.angry_brows else float(MIN_BROW)


func _max_brow() -> float:
	return float(MAX_BROW_ANGRY) if mm.face.angry_brows else float(MAX_BROW)


## Her eyebrows rise in worry with depth, breath, vigour and pass-out (moremoods' defaults, not in its settings).
func _panic_eyebrows() -> void:
	var her = g.her
	var off := 0
	var past := _panic
	if her.passedOut:
		_panic = 50.0
	else:
		if _brow_offsets.size() > 0:
			off = _brow_offsets.pop_front()
			her.rightEyebrow.y += off / 6.0
			her.leftEyebrow.y += off / 6.0
		elif her.eyebrowOffsets.size() > 0:
			_brow_offsets.append_array(her.eyebrowOffsets)
		_panic = 0.0
		# by depth (from 75 to the hilt), breath, vigour, pass-out
		var num: float = her.penisInMouthDist - 75 if her.mouthFull else 0.0
		var den: float = her.hiltDistance - 75
		_panic += clampf(num / den, 0, 1) * 220 if den != 0 else 0.0
		if not lowered_breath:
			_past_breath_brow = _past_breath_brow - (_past_breath_brow - clampf((g.breathLevel - 25) / (g.breathLevelMax - 25), 0, 1) * 50) * 0.1
			_panic += _past_breath_brow
		_panic += clampf((her.vigour - 100) / (900.0 - 100), 0, 1) * 200
		_panic += clampf((her.passOutFactor - 7) / (her.passOutMax - 7), 0, 1) * 200
	_panic = minf(250, past - (past - _panic) * 0.15)
	var rb = her.rightEyebrow
	var lb = her.leftEyebrow
	var brows := [rb.rightEyebrowFill, rb.rightEyebrowLine, lb.leftEyebrowFill, lb.leftEyebrowLine]
	if mm.face.angry_brows:
		var current: int = rb.rightEyebrowFill.currentFrame
		var c := int(clampf(floor(minf(_max_brow(), _min_brow() + off / 3.0 + _panic * 90 / 200)), 0, 200))
		for x in brows:
			x.gotoAndStop(c)
		if mm.mood_name == "Angry":
			her.leftEyebrowAngryTween.tween(c / 200.0)
			her.rightEyebrowAngryTween.tween(c / 200.0)
		for x in brows:
			x.gotoAndStop(c)
		her.eye.eyebrowMask.gotoAndStop(current)
		var k := maxf(0, c - 110)
		rb.y = -182 - k / 4.5
		lb.y = -164 - k / 2.5
		rb.x = 74 + k / -15.0
		lb.x = 119 + k / -35.0
		rb.rotation_degrees = 32 - k / 2.0
		lb.rotation_degrees = -70 + k / 0.7
	else:
		var c := int(clampf(floor(minf(_max_brow(), _min_brow() - off / 3.0 + _panic)), 0, 200))
		if mm.mood_name in ["Frightened", "Broken", "Smug"]:
			c = int(clampf(floor(maxf(_min_brow(), _max_brow() + off / 3.0 - _panic)), 0, 200))
		var oy: float = rb.y + 3
		var oly: float = lb.y
		var ox: float = rb.x - 10
		var olx: float = lb.x - 3
		for x in brows:
			x.gotoAndStop(c)
		her.leftEyebrowNormalTween.tween(0)
		her.rightEyebrowNormalTween.tween(0)
		for x in brows:
			x.gotoAndStop(c)
		rb.y = oy - c / 15.0
		lb.y = oly - c / 8.5
		rb.x = ox + c / 40.0
		lb.x = olx + c / 99.0
		rb.rotation_degrees = -c / 15.0
		lb.rotation_degrees = -c / 99.0


# ---------------------------------------------------------------- timer actions (drool, wince, gag, ...)

func _timer_actions(m: String) -> void:
	var her = g.her
	if m in ["Aggressive", "Drugged", "Elated", "Broken", "Horny", "Tease", "Overwhelmed", "Numb", "Asleep"]:
		if mm.random_timer > 0:
			mm.random_timer = maxi(0, mm.random_timer - 1)
		else:
			if m == "Drugged" and her.mouthFull and not her.held and not her.passedOut:
				if s("playsoundfordruggeddrool"):
					g.soundControl.playSplat()
				her.wince()
			her.randomSpitDrool()
			_reset_timer()
	if m == "Disgusted" or m == "Numb":
		if mm.random_timer > 0:
			if mm.random_timer < 10 and her.mouthFull:
				her.wince()
			if mm.random_timer == 15 and her.mouthFull:
				her.randomSpitDrool()
			if mm.random_timer == 5 and her.mouthFull:
				_play_gag(QUIET_GAGS, true, 0.5)
			mm.random_timer = maxi(0, mm.random_timer - 1)
		else:
			her.wince()
			_reset_timer()
	if m == "Nervous" and not her.passedOut:
		if her.mouthFull and not her.held:
			if mm.random_timer > 0:
				mm.random_timer = maxi(0, mm.random_timer - 5)
			else:
				her.tongue.hangOut()
				_reset_timer()
		else:
			_reset_timer()
		if not her.mouthFull:
			her.tongue.doNothing()
			her.tongue.stopHangingOut()
	if (m == "Spent" or m == "Broken") and her.mouthFull and not her.passedOut:
		var q: float = s("spentpassoutquicker")
		if q > 0 and g.breathing and g.breathLevel >= g.breathLevelMax and her.passOutFactor < her.passOutMax:
			if her.passOutFactor + q < her.passOutMax:
				her.passOutFactor += q
	if m == "Spent":
		_spent_action()
	if m == "Frightened":
		if her.mouthFull and not g.penisOut:
			if _fright_held_timer != -100:
				_fright_held_timer += 1
				if _fright_held_timer > 50 or her.held:
					if g.breathLevel < g.outOfBreathPoint + 10:
						g.addBreath(1)
					else:
						_fright_held_timer = -100
		else:
			_fright_held_timer = 0


func _reset_timer() -> void:
	mm.random_timer = int(floor(randf() * 240)) + 300


func _spent_action() -> void:
	var her = g.her
	var sc = g.soundControl
	if mm.random_timer > 0:
		mm.random_timer = maxi(0, mm.random_timer - 1)
	else:
		_spit_drool_flag = true
		_spit_drool_timer = 0
		if her.mouthFull and not her.passedOut:
			var i := _pick(sc.lick.size(), sc.lastRandomLick)
			sc.lastRandomLick = i
			var ch = sc.lick[i].play()
			if ch:
				ch.soundTransform = FlashSoundTransform.new(0.55 + randf() * 0.1, clampf(0.5, sc.leftPan, sc.rightPan))
		elif not her.passedOut:
			var choices: Array = []
			for pair in [["spentoffactioncoughsound", 0], ["spentoffactiongagsound", 1], ["spentoffactionquietgagsound", 2],
					["spentoffactionswallowsound", 3], ["spentoffactionsplatsound", 4]]:
				if s(pair[0]):
					choices.append(pair[1])
			var use := -1
			if choices.size() >= 1:
				use = choices[mini(choices.size() - 1, int(floor(randf() * choices.size())))]
			if s("spentoffactionwince"):
				her.wince()
			if s("spentoffactionaddtear"):
				her.tears.addTearSpot()
			if s("spentoffactiongeneratesplat"):
				her.generateSplat(3, 7)
			if s("spentoffactionaccelbreasts"):
				her.leftBreastController.accelerate(0.08)
				her.rightBreastController.accelerate(0.08)
			if s("spentoffactioncoughfactor"):
				her.coughFactor = randf() / 10 + 0.2
			_spit_drool_timer = 10
			match use:
				0: _spent_cough()
				1: sc.playGag(0.5)
				2: _play_gag(QUIET_GAGS, true, 0.5)
				3: sc.playSwallow(0.5)
				4: sc.playSplat()
		_reset_timer()
	if _spit_drool_flag:
		if _spit_drool_timer == 0:
			_spit_drool_flag = false
			her.randomSpitDrool()
		_spit_drool_timer = maxi(0, _spit_drool_timer - 1)


static func _pick(n: int, last: int) -> int:
	if n <= 1:
		return 0
	var i := last
	while i == last:
		i = int(floor(randf() * n))
	return i


func _play_gag(indexes: Array, quiet: bool, pos: float) -> void:
	var sc = g.soundControl
	var last := _last_quiet_gag if quiet else _last_loud_gag
	var j := _pick(indexes.size(), last)
	if quiet:
		_last_quiet_gag = j
	else:
		_last_loud_gag = j
	var idx: int = indexes[j]
	if idx >= sc.gag.size():
		return
	var ch = sc.gag[idx].play()
	if ch:
		ch.soundTransform = FlashSoundTransform.new(0.3 + randf() * 0.1, clampf(pos * 2 - 1, sc.leftPan, sc.rightPan))


func _spent_cough() -> void:
	var her = g.her
	var sc = g.soundControl
	her.nextCoughTime = int(floor(randf() * 210)) + 30
	her.coughing = true
	var i := _pick(sc.cough.size(), sc.lastRandomCough)
	sc.lastRandomCough = i
	var ch = sc.cough[i].play()
	if ch:
		ch.soundTransform = FlashSoundTransform.new(0.25 + randf() * 0.1, clampf(her.pos * 2 - 1, sc.leftPan, sc.rightPan))
	her.justCoughed = true


# ---------------------------------------------------------------- tongue

func _tongue(m: String) -> void:
	var her = g.her
	var t = her.tongue
	wanting_hang_tongue = false
	if mm.always_tongue_out:
		if not her.isSpeaking():
			t.hangOut()
			wanting_hang_tongue = true
		else:
			t.doNothing()
			t.stopHangingOut()
	var on_penis: bool = her.penisInMouthDist > 0 and not g.penisOut and bite_timer == 0
	if (m == "Submissive" and s("submissivetongueout")) or m in ["Elated", "Disgusted", "Excited", "Smug"]:
		if not her.passedOut:
			if on_penis:
				t.hangOut()
				wanting_hang_tongue = true
			else:
				t.doNothing()
				t.stopHangingOut()
	if m == "Professional" and not her.passedOut:
		if ((her.penisInMouthDist > 0 and not g.penisOut) or (g.him.pleasure + 10 > g.him.ejacPleasure or g.him.ejaculating)) and bite_timer == 0:
			t.hangOut()
			wanting_hang_tongue = true
		else:
			t.doNothing()
			t.stopHangingOut()
	if m == "Horny" and not her.passedOut:
		if on_penis:
			t.hangOut()
			wanting_hang_tongue = true
			_tongue_flag = true
		elif _tongue_flag:
			t.doNothing()
			_tongue_flag = false
	if m in ["Disgusted", "Spent", "Broken", "Drugged", "Overwhelmed", "Android", "Asleep"]:
		t.playingAction = true
	if m in ["Submissive", "Excited", "Smug"] and her.mouthFull and her.held:
		t.playingAction = true
	if m in ["Depressed", "Frightened", "Numb"]:
		t.doNothing()
		t.stopHangingOut()
	if (m == "Tease" or m == "Devoted") and not her.passedOut:
		if on_penis and not (her.mouthFull and her.held):
			t.hangOut()
			wanting_hang_tongue = true
		else:
			t.doNothing()
			t.stopHangingOut()
	if m == "Asleep":
		if on_penis and her.mouthFull and her.held:
			t.hangOut()
			wanting_hang_tongue = true
		else:
			t.doNothing()
			t.stopHangingOut()


## Tongue.update as moremoods ran it: while a mood keeps her tongue out, fast movement does not pull it in and
## cum on it does not make her swallow it in.
func _tongue_update(c: Hooks.Call) -> void:
	if not wanting_hang_tongue:
		return
	c.cancel()
	var t = c.obj
	var p: float = c.args[0]
	var movement: float = c.args[1]
	var abs_movement: float = c.args[2]
	var vigour: float = c.args[3]
	t.currentPos = p
	t.tiltOffset *= 0.8
	if t.waitingForOut and (t.currentAction.is_null() or t.currentAction == t.startMovingTongueOut):
		t.moveTongueOut()
	elif t.waitingForIn and (t.currentAction.is_null() or t.currentAction == t.startMovingTongueIn):
		t.moveTongueIn()
	elif t.playingAction:
		t.actionTime += 1
		if t.solidAction.get(t.currentAction, false):
			t.tiltOffset -= 0.5 * (1.0 - cos(t.actionTime * t.tiltSpeeds[t.currentAction]))
		if t.currentFrameLabel == "InDone" or t.currentFrameLabel == "OutDone":
			t.playingAction = false
			t.currentAction = Callable()
			t.waitingToTouch = false
			if t.currentFrameLabel == "OutDone":
				t.gotoAndStop(t.tongueOutEndFrame)
	else:
		if t.tongueOut and t.mouthFull and t.mouthFullTime >= 0:
			if t.mouthFullTimer < t.mouthFullTime:
				t.mouthFullTimer += g.her.currentPenisDistance * 0.0025
			else:
				t.mouthFullTime = -1
				t.startMovingTongue("in")
		if not g.her.passedOut and not g.her.isSpeaking():
			if t.checkNearTip() or t.increasedAction > 0:
				if t.nearTimer < t.nearTime:
					t.wiggleTongue(t.nearTime - t.nearTimer)
					t.nearTimer += 1
				elif abs_movement < 10 and vigour < 300:
					if not t.tongueOut:
						t.startMovingTongue("out")
					else:
						t.performRandomTipAction()
					t.nearTimer = 0
			else:
				t.nearTimer = 0
				if t.actionTimer < t.nextActionTime:
					t.wiggleTongue(t.nextActionTime - t.actionTimer)
					t.actionTimer += 1
				else:
					t.performNextAction()
	t.wiggleSpeed *= 0.9
	if t.increasedAction > 0:
		t.increasedAction -= 1
	Hooks.after(&"Tongue.update", t, c.args)


## After Tongue.update: an action held by a mood for over 80 frames is ended (moremoods' fix for a stuck tongue).
func _tongue_unstick() -> void:
	var t = g.her.tongue
	if t.playingAction and t.actionTime > 80:
		if t.waitingForOut or t.waitingForIn:
			t.currentAction = Callable()
			t.actionTime = 1
		else:
			t.waitingForIn = true
			t.waitingForOut = false
			t.actionTime = 1


# ---------------------------------------------------------------- blush

func _change_blush(target: float, frames: float) -> void:
	_blush_target = clampf(target, 0, 100)
	_blush_rate = (_blush_target - _blush) / frames
	_blush_rate = maxf(_blush_rate, 0.1) if _blush_rate > 0 else minf(_blush_rate, -0.1)


func _blush_reached() -> bool:
	return _blush == _blush_target


func _tick_blush() -> void:
	if _blush_rate > 0:
		_blush = minf(_blush_target, _blush_rate + _blush)
	else:
		_blush = maxf(_blush_target, _blush_rate + _blush)
	if _blush_reached() or _blush_rate == 0:
		_blush_timer = maxi(0, _blush_timer - 1)
	_set_blush(_blush)


var _blush_applied := []


func _set_blush(percent: float) -> void:
	var c: Dictionary = g.characterControl.blushRGB
	var a: float = c.get("a", 0)
	var v := minf(s("blushmaxamount"), (1 - a) * percent / 100.0 + a)
	var key := [v, c.get("r", 0), c.get("g", 0), c.get("b", 0)]
	if key == _blush_applied:
		return   # setting a colour transform re-renders her blush: only when it changes
	_blush_applied = key
	g.her.blush.colorTransform = FlashColorTransform.new(1, 1, 1, v, c.get("r", 0), c.get("g", 0), c.get("b", 0), 0)


func _blush_rules(m: String) -> void:
	if g.gamePaused:
		if not (m in ["Aggressive", "Horny", "Overwhelmed", "Devoted", "Nervous", "Elated", "Excited", "Frightened", "Submissive"]):
			_change_blush(_blush - 5, 5)
		return
	var her = g.her
	var him = g.him
	if (m == "Aggressive" and s("aggressiveenableblush")) or m in ["Horny", "Overwhelmed", "Devoted"]:
		if her.passedOut:
			_change_blush(_blush - 2, 5)
		elif her.mouthFull:
			if her.passOutFactor >= her.passOutMax / 4:
				_change_blush(_blush + 2, 5)
		else:
			_change_blush(_blush - 4, 5)
	elif m == "Nervous" and s("nervousenableblush"):
		if her.passedOut:
			_change_blush(_blush - 2, 5)
		elif her.vigour > 300:
			_change_blush(_blush - 5, 5)
		elif her.cumInMouth > 10:
			_change_blush(_blush + 5, 5)
		elif her.mouthFull:
			if him.ejaculating:
				_change_blush(_blush + 5, 5)
			elif her.held:
				_change_blush(_blush - 1, 5)
		elif her.lookPoint == her.hisFace:
			_change_blush(_blush + 4, 5)
		else:
			_change_blush(_blush - 2, 5)
	elif (m == "Elated" and s("elatedenableblush")) or (m == "Excited" and s("excitedenableblush")):
		if her.passedOut:
			_change_blush(_blush - 2, 5)
		elif her.vigour > 300:
			_change_blush(_blush + 1, 5)
		elif her.cumInMouth > 10:
			_change_blush(_blush + 5, 5)
		elif her.mouthFull:
			if him.ejaculating:
				_change_blush(_blush + 5, 5)
			elif her.held:
				_change_blush(_blush + 1, 5)
		else:
			_change_blush(_blush - 2, 5)
	elif (m == "Frightened" and s("frightenedenableblush")) or (m == "Submissive" and s("submissiveenableblush")):
		if her.passedOut:
			_change_blush(_blush - 2, 5)
		elif her.mouthFull and not her.held and her.absMovement <= 10 and her.movement > 3 and _not_held_timer > 200:
			_change_blush(minf(80, _blush + 25), 5)
			_fright_blush_flag = true
		elif _blush_reached() and _blush_timer == 0:
			if her.mouthFull and him.ejaculating:
				_change_blush(_blush + 100, 10)
				_blush_timer = 400
			elif not her.mouthFull:
				_change_blush(_blush - 2, 5)
			elif her.held:
				_change_blush(_blush - 50, 5)
			elif _fright_blush_flag:
				_change_blush(_blush - (4 if her.movement < -2 else 1), 5)
			else:
				_change_blush(_blush - 6, 5)
	else:
		_change_blush(_blush - 5, 5)


# ---------------------------------------------------------------- Tease clenching

func _tease_clench() -> void:
	var her = g.her
	if her.passedOut or her.speaking or her.speakStopDelay > 0:
		return
	if not her.mouthFull and not her.held and not g.penisOut:
		var breath := minf(1, g.breathLevel / g.breathLevelMax)
		if her.firstDT:
			breath = minf(0.25, breath)
		if not her.clenchTeeth and her.movement > 35 - maxf(_him_pleasure(), breath) * 28 and _not_held_timer > 10 and her.penisInMouthDist < -35:
			her.startClenchingTeeth()
			if her.movement > 30:
				g.setPenisOut(true)
				her.clenchedTeethTime = her.clenchedTeethTime / 2
			else:
				her.clenchedTeethTime = her.clenchedTeethTime / 6
		elif her.clenchTeeth and her.acceleration > 1.0 / 15.0:
			her.clenchedTeethTimer = 0
			if her.movement > 30:
				g.setPenisOut(true)


# ---------------------------------------------------------------- wrapped game functions

func _original_tap_hands(extra := 0.0) -> void:
	Hooks.without(&"Her.tapHands", func(): g.her.tapHands(extra))


func _tap_hands(c: Hooks.Call) -> void:
	var m: String = mm.mood_name
	var her = g.her
	if m in ["Spent", "Submissive", "Drugged", "Aggressive", "Elated", "Broken", "Horny", "Android", "Devoted", "Numb", "Asleep"]:
		c.cancel()
	elif m == "Tease" and randf() < 0.5:
		c.cancel()
	elif m == "Professional" and her.passOutFactor / her.passOutMax < 0.7:
		c.cancel()


func _cough(c: Hooks.Call) -> void:
	var her = g.her
	var m: String = mm.mood_name
	var weak := m == "Spent" or m == "Asleep"
	var odds := -1.0
	var swallow := false
	if m == "Professional" or m == "Numb":
		odds = 3
	elif m == "Smug" or m == "Tease":
		odds = 4
		swallow = true
	elif m in ["Broken", "Horny", "Asleep"]:
		odds = 2
		swallow = true
	if m == "Android":
		c.cancel()
		her.nextCoughTime = int(floor(randf() * 170)) + 90
		return
	if odds < 0:
		if weak:
			c.cancel()
			_weak_cough()
		return
	c.cancel()
	if randf() > 1.5 - her.passOutFactor / her.passOutMax * odds:
		if weak:
			_weak_cough()
		else:
			her.cough()   # the original (the hook is inactive inside its handler)
		if her.justCoughed:
			her.nextCoughTime = int(floor(randf() * 170)) + 130
	else:
		if swallow and her.mouthFull and not her.passedOut:
			_quick_swallow()
		her.nextCoughTime = int(floor(randf() * 170)) + 100


func _weak_cough() -> void:
	var her = g.her
	var sc = g.soundControl
	if not g.coughing:
		return
	her.nextCoughTime = int(floor(randf() * 210)) + 30
	her.coughing = true
	her.coughFactor = randf() * 1.2 + 0.4
	her.tears.addTearSpot()
	her.leftBreastController.accelerate(0.08)
	her.rightBreastController.accelerate(0.08)
	her.wince()
	her.head.cheekBulge.alpha = 1
	her.generateSplat(3, 7)
	var i := _pick(sc.cough.size(), sc.lastRandomCough)
	sc.lastRandomCough = i
	var ch = sc.cough[i].play()
	if ch:
		ch.soundTransform = FlashSoundTransform.new(0.2 + randf() * 0.15, clampf(her.pos * 2 - 1, sc.leftPan, sc.rightPan))
	her.justCoughed = true


func _quick_swallow() -> void:
	var her = g.her
	var sq: Dictionary = her.swallowSequence
	if not sq.get("intensity", 0):
		sq["intensity"] = randf() * 0.3 + 0.5 * (her.cumInMouth / her.maxCumInMouth) + 0.4
		sq["build"] = roundi(30 * sq["intensity"])
		sq["swallow"] = roundi(sq["build"] + 16 * sq["intensity"])
		sq["relax"] = roundi(sq["swallow"] + 16 * sq["intensity"])
		sq["end"] = roundi(sq["relax"] + 30 * sq["intensity"])
	her.head.neck.swallow()
	g.soundControl.playSwallow(0.5)


func _open_cough(c: Hooks.Call) -> void:
	if mm.mood_name != "Asleep":
		return
	c.cancel()
	var her = g.her
	her.tears.addTearSpot()
	her.generateSplat(15, 5, 1, her.cumInMouth > 0)
	her.leftBreastController.accelerate(0.1)
	her.rightBreastController.accelerate(0.1)
	her.justCoughed = true
	her.coughBuild = 0
	g.soundControl.queuedCoughs = 0


## Asleep: passing out without the pass-out sound.
func _pass_out(c: Hooks.Call) -> void:
	if mm.mood_name != "Asleep":
		return
	c.cancel()
	var her = g.her
	her.passOutFactor = her.passOutMax
	her.passedOut = true
	her.startArmsPassOut()
	Hooks.after(&"Her.passOut", her)


func _after_ejaculating() -> void:
	if mm.face.angry_look_flag and mm.mood_name == "Tease" and not g.her.mouthFull:
		g.her.startClenchingTeeth()
	mm.face.angry_look_flag = false


func _after_movement_sounds() -> void:
	var her = g.her
	var m: String = mm.mood_name
	if _mouth_before_sounds and not her.mouthFull and m == "Tease":
		if her.vigour > her.VIGOUR_WINCE_LEVEL / 3.0 and randf() > 0.5:
			her.startClenchingTeeth()
	if m == "Nervous":
		var look = mm.face.held_look()
		if look == null:
			look = her.currentLookTarget
		if look != _eye_change_holder:
			_eye_change_holder = look
			_eye_change_timer = 0
		else:
			_eye_change_timer = mini(500, _eye_change_timer + 1)
		if _eye_change_timer > 60 and her.offActionTimer == 0 and _action_tracker != 0:
			if look != her.eyesDown:
				mm.face.hold_look(her.eyesDown)   # given out through the look value point (mood_point)
	if her.offActionTimer == 0 and _action_tracker != 0:
		if m in ["Aggressive", "Elated", "Excited", "Smug", "Horny"]:
			her.waggleEyebrows()
		if m == "Tease":
			if randf() > 0.5:
				her.startClenchingTeeth()
			else:
				her.waggleEyebrows()
		if m == "Spent" or m == "Drugged":
			her.wince()
		if m in ["Submissive", "Frightened", "Broken", "Overwhelmed"]:
			her.tears.addTearSpot()
			her.tears.releaseTears()
		if m == "Depressed":
			her.tears.addTearSpot()
	_action_tracker = her.offActionTimer
	if m == "Nervous" and randf() > 0.99:
		if randf() > 0.5:
			Sweat.spawn(her.head, Vector2(21, -65), Vector2(150, 100), [her.rightArmContainer.upperArm, her.torso.back,
				her.torso.midLayer.chest, her.torso.midLayer.rightBreast.hitArea, her.torso.leg])
		else:
			Sweat.spawn(her.torso.back, Vector2(110, -230), Vector2(320, 100), [her.torso.midLayer.chest,
				her.torso.midLayer.rightBreast.hitArea, her.torso.leg])


## After shuffle: a random mood, the added ones included (setting).
## After the game's shuffle, unless it left her mood alone (regulaterandom).
func _shuffle(c) -> void:
	if not c.args.is_empty() and not c.args[0].get("mood", false):
		return
	if s("shufflemoods"):
		var list: Array = mm.MOODS
		g.her.setMood(list[int(ceil(randf() * list.size())) - 1])
