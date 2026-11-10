extends RefCounted
## moremoods, her face per mood: eyebrows, eyelids, pupils (shock), where she looks, eye roll, mouth hang, lips.
## Runs in hooks after Her.updateEyes, updateLips, lookAt, blink and changeLookTarget, as the Loader mod did, and as
## value point modifiers for her gaze, eyelids, shock, iris size, jaw, mouth openness, wince and waking. Numbers follow moremoods v18 (Flash rotation =
## rotation_degrees here).

var mm   # moremoods.gd

const NO_WINCE := ["Broken", "Horny", "Android", "Numb", "Asleep"]   # moods that don't squint as she winces

## Her mood doesn't wince (wincecontrol skips the wince for it).
var skip_wince: bool:
	get:
		return mm.mood_name in NO_WINCE

# eye roll button (0 off, 1 eye roll, 2 eye roll and cross-eyed while passing out) and upper eyelid limit
var eyeroll_mode := 0
var eyelid_mode := 0          # 0 normal, 1 auto lower, 2 slider limit, 3 both
var eyelid_slider := 0.5
# state
var _held_look = null          # see held_look()
var _seen_look := Vector2.INF
var toggle_out_eyes := false
var trying_face := false
var trying_penis := false
var angry_look_flag := false
var eye_look_timer := 0
var angry_brows := false
var lower_eyelid_level := 0
var _prev_lower_level := 0
var _prev_lower_lid := 0
var _eye_fir: Array = [0]
var _prev_upper := 0
var _prev_upper2 := 0
var _lids := [50, 50]         # [upper, lower] frames worked out by eyelids() this time


func _init(p_mm) -> void:
	mm = p_mm


func eyeroll_enabled() -> bool:
	return eyeroll_mode == 1 or eyeroll_mode == 2


func hook() -> void:
	mm.hook_after(&"Her.updateEyes", func(_c): update_eyes())
	# her eyelids through the value points (Hooks): moremoods' own lid model generates both frames, so states such as
	# alternativePassOut's (FINAL) still apply on top. The upper is asked first: it works out both.
	mm.modify(&"Her.upperEyelid", {"phase": Hooks.GENERATE, "op": "fn", "fn": func(_v, _her): return eyelids()[0]})
	mm.modify(&"Her.lowerEyelid", {"phase": Hooks.GENERATE, "op": "fn", "fn": func(_v, _her): return _lids[1]})
	mm.modify(&"Her.jawAngle", {"phase": Hooks.MOOD, "op": "fn", "fn": func(v, _her): return hang_jaw(v)})
	# her mood's eyes, mouth and wince through value points (they used to overwrite the game's after it)
	mm.modify(&"Her.eyelidShock", {"phase": Hooks.MOOD, "op": "fn", "fn": func(v, her): return mood_shock(v, her)})
	mm.modify(&"Her.irisScale", {"phase": Hooks.GENERATE, "op": "fn", "fn": func(v, her): return mood_iris(v, her)})
	mm.modify(&"Her.irisScale", {"phase": Hooks.CLAMP, "op": "clamp", "min": 0.0})
	mm.modify(&"Her.mouthOpenness", {"phase": Hooks.MOOD, "op": "fn", "fn": func(v, _her): return mood_mouth_openness(v)})
	mm.modify(&"Her.winceTime", {"phase": Hooks.MOOD, "op": "set", "value": 0,
		"when": func(_her): return skip_wince})
	mm.modify(&"Her.wakeShock", {"phase": Hooks.MOOD, "op": "set", "value": 25.0, "when": func(_her): return mm.mood_name == "Spent"})
	mm.modify(&"Her.wakeGaze", {"phase": Hooks.MOOD, "op": "fn", "fn": func(v, _her): return mood_wake_gaze(v)})
	mm.hook_after(&"Her.updateLips", func(_c): update_lips())
	mm.hook_after(&"Her.blink", func(_c): toggle_out_eyes = not toggle_out_eyes)
	mm.hook_before(&"Her.changeLookTarget", func(c): _change_look_target(c.args[0]))
	# her gaze through the value points (Hooks): the mood's look point, then moremoods' own angle model, so dialogue
	# looks ([LOOK_...], OVERRIDE) and pass-out states (FINAL) still apply on top
	mm.modify(&"Her.lookTarget", {"phase": Hooks.MOOD, "op": "fn", "fn": func(v, _her): return mood_point(v)})
	mm.modify(&"Her.gazeAngle", {"phase": Hooks.GENERATE, "op": "fn", "fn": func(_v, _her): return gaze_angle()})
	mm.hook_after(&"Her.lookAt", func(_c): _after_look())


func s(key: String):
	return mm.get_setting(key)


# ---------------------------------------------------------------- eyebrows and eyelids (value points)

func update_eyes() -> void:
	var her = g.her
	var m: String = mm.mood_name
	if m == "Upset" or m == "Aggressive" or m == "Angry" or m == "Disgusted" or (m == "Asleep" and s("asleepeyebrowshape") == 2):
		if m != "Angry":
			var r: float = her.rightEyebrow.rightEyebrowFill.currentFrame / 200.0
			her.leftEyebrowAngryTween.tween(r)
			her.rightEyebrowAngryTween.tween(r)
		angry_brows = true
	else:
		angry_brows = false
	if m == "Spent" or m == "Broken" or m == "Drugged":
		_set_brow(clampi(her.rightEyebrow.rightEyebrowFill.currentFrame, 100, 170))
	if m == "Android":
		_set_brow(clampi(int(her.rightEyebrow.rightEyebrowFill.currentFrame / 2.0), 0, 170))
	var lower: int = her.lowerLid
	if g.mascara:
		lower_eyelid_level = maxi(0, int(floor((mini(_prev_lower_lid, lower) - 150) / 8.0)))
		if _prev_lower_level != lower_eyelid_level:
			clear_lower_eyelid()
		_prev_lower_level = lower_eyelid_level
	_prev_lower_lid = lower


## moremoods' eyelid frames for her mood ([upper, lower]; GENERATE of Her.upperEyelid, which also keeps the lower
## for Her.lowerEyelid).
func eyelids() -> Array:
	var her = g.her
	var m: String = mm.mood_name
	var lid: int = maxi(2, int(floor(her.eyelidMotion["pos"])))
	var look: int = int(maxf(-55, minf(0, (her.eyeMotion["ang"] - 90) * 0.15 * maxf(0, 150 - lid))))
	if m == "Excited":
		look = int(maxf(-55, minf(0, (her.eyeMotion["ang"] - 105) * 0.15 * maxf(0, 150 - lid))))
	var upper: int = int(floor(maxf(2, lid + look)))
	var lower: int = lid
	if eyelid_mode == 1 or eyelid_mode == 3:
		upper = int(maxf(upper, minf(110, 100 * (her.eyeMotion["ang"] - 60) / 40.0 + 60 * (her.eye.ball.irisContainer.iris.scaleY - 0.5))))
	if eyelid_mode == 2 or eyelid_mode == 3:
		upper = int(maxf(upper, 150 * eyelid_slider))
	if m == "Happy" or m == "Excited" or m == "Overwhelmed":
		lower = lid + int(maxf(0, (160 - lid) * 0.9))
	# raised lower eyelid levels 2 / 3 / 4: [upper end of the 150-200 range, lower lid floor]
	var raised := {}
	if m == "Drugged" or m == "Elated" or m == "Tease" or m == "Overwhelmed":
		raised = {"top": 165, "span": 35}
	if m == "Disgusted":
		raised = {"top": 170, "span": 30}
	if m == "Smug" or m == "Horny":
		raised = {"top": 175, "span": 25}
	if not raised.is_empty():
		upper = _squint(upper, raised["top"], raised["span"])
		lower = upper if upper > raised["top"] else raised["top"]
	if m == "Spent":
		upper = _lowered(upper, 125, 130)
	if m == "Devoted":
		_devoted_eyes(upper)
	if m == "Asleep":
		var r := clampf((her.penisInMouthDist - her.deepthroatDistance) / (her.hiltDistance - her.deepthroatDistance) * s("asleepclosedeyelidsthroatmax"), 0, s("asleepclosedeyelidsthroatmax"))
		if not her.mouthFull or her.passedOut:
			r = 0
		r = clampf(r - her.passOutFactor / her.passOutMax * s("asleepclosedeyelidsthroatmax"), 0, s("asleepclosedeyelidsthroatmax"))
		r = minf(50, r)
		upper = int(150 + r)
		lower = int(150 + r)
	if m == "Depressed" or m == "Numb":
		upper = _lowered_level(upper, 110, 40.0)
	if m == "Smug" or m == "Horny" or m == "Tease":
		var before := upper
		upper = _lowered_level(upper, 55, 90.0, 60)
		if her.eyelidShock != 0:
			var a := clampf(her.eyelidShock / 40.0, 0, 1)
			upper = int(upper + (before - upper) * a)
	if m == "Disgusted" or m == "Broken":
		upper = _lowered_level(upper, 30, 120.0)
	if (m == "Frightened" or m == "Nervous" or m == "Excited") and not eyeroll_enabled():
		upper = _calm_jitter(upper)
	if m == "Android":
		upper = 0 if not her.passedOut else int(s("androidmoodpassouteyelid"))
	_lids = [upper, lower]
	return _lids


func _set_brow(f: int) -> void:
	var her = g.her
	for x in [her.rightEyebrow.rightEyebrowFill, her.rightEyebrow.rightEyebrowLine, her.leftEyebrow.leftEyebrowFill, her.leftEyebrow.leftEyebrowLine]:
		x.gotoAndStop(f)
	her.leftEyebrowNormalTween.tween(0)
	her.rightEyebrowNormalTween.tween(0)
	for x in [her.rightEyebrow.rightEyebrowFill, her.rightEyebrow.rightEyebrowLine, her.leftEyebrow.leftEyebrowFill, her.leftEyebrow.leftEyebrowLine]:
		x.gotoAndStop(f)
	her.eye.eyebrowMask.gotoAndStop(f)


## Upper eyelid squinted for the raised-lower-eyelid moods (0-20 -> 20, 20-110 -> 20-80, 110-150 -> 80-135,
## 150-200 -> top-200).
func _squint(u: int, top: int, span: int) -> int:
	if u <= 20:
		return 20
	if u <= 150:
		if u <= 110:
			return int((u - 20) / 90.0 * 60 + 20)
		return int((u - 110) / 40.0 * 55 + 80)
	return int((u - 150) / 50.0 * span + top)


## Spent: greatly lowered upper eyelid (level 4).
func _lowered(u: int, lvl: int, below: int) -> int:
	var her = g.her
	var pct := minf(100, her.passOutFactor / her.passOutMax * 100)
	if u <= below:
		if pct > 25 and pct < 75:
			var diff := maxf(lvl - u, lvl)
			pct = (75 - pct) * 4 if pct > 50 else (pct - 25) * 4
			u = int(lvl - diff * pct / 300.0)
		else:
			u = lvl
	if u <= 150 and u > below:
		u = int((u - below) / 20.0 * 25 + lvl)
	pct = minf(100, her.passOutFactor / her.passOutMax * 100)
	if pct > 75:
		u = int(maxf(u, lvl + pct - 75))
	return u


## Lowered upper eyelid levels 1-3: at least `lvl`, opening a little while she starts to pass out, then closing.
func _lowered_level(u: int, lvl: int, closing: float, closing_base := -1) -> int:
	var her = g.her
	var pct := minf(100, her.passOutFactor / her.passOutMax * 100)
	if u <= lvl:
		if pct > 25 and pct < 75:
			var diff := maxf(lvl - u, lvl)
			pct = (75 - pct) * 4 if pct > 50 else (pct - 25) * 4
			u = int(lvl - diff * pct / 300.0)
		else:
			u = lvl
	pct = minf(100, her.passOutFactor / her.passOutMax * 100)
	if pct > 75:
		u = int(maxf(u, (closing_base if closing_base >= 0 else lvl) + (pct - 75) / 100.0 * closing))
	return u


func _devoted_eyes(u: int) -> void:
	var her = g.her
	if her.passedOut or u > 150:
		return
	if (her.mouthFull and her.held and her.hilt) or (her.eyelidShock > 0 and not g.him.ejaculating) or g.breathLevel / g.breathLevelMax > 0.8:
		if her.cumInEye == 0 and her.eyelidMotion["isClosed"]:
			her.openEye()
	elif g.breathLevel / g.breathLevelMax < 0.7 and not her.mouthFull:
		if u != 150 and not her.eyelidMotion["isClosed"]:
			her.closeEye()


## Shocked-eye moods: damps the upper eyelid flickering up and down every frame.
func _calm_jitter(u: int) -> int:
	var changes := 0
	for i in range(1, _eye_fir.size()):
		if _eye_fir[i] != _eye_fir[i - 1]:
			changes += 1
	if _eye_fir.size() > 7:
		_eye_fir.pop_front()
	if changes > 3:
		if absi(_prev_upper - _prev_upper2) < absi(_prev_upper - u):
			if absi(_prev_upper - u) < absi(_prev_upper2 - u):
				u = int(floor((_prev_upper + u) / 2.0))
			else:
				u = int(floor((_prev_upper2 + u) / 2.0))
		else:
			u = int(floor((_prev_upper + u) / 2.0))
		u = int(floor((_prev_upper + u + _prev_upper2) / 3.0))
	var last: int = _eye_fir.back()
	_eye_fir.append((1 if u > _prev_upper - 2 else 0) if last == 1 else (1 if u > _prev_upper + 1 else 0))
	_prev_upper2 = _prev_upper
	_prev_upper = u
	return u


## Redraws the mascara on the lower eyelid for its raised level (otherwise it would show over the eyeball).
func clear_lower_eyelid() -> void:
	if lower_eyelid_level == 0:
		return
	var tears = g.her.tears
	var dst: FlashBitmapData = tears.lowerEyelidData
	var src: FlashBitmapData = tears.mascaraData
	dst.fillRect(tears.lowerEyelidArea, 0)
	var level := float(lower_eyelid_level)
	if Hooks.has_value(&"Her.lowerEyelidSquint"):   # HOOK value point: how far her mood's squint tilts the lower eyelid's mascara (the mood's level, 10-25)
		level = float(Hooks.value(&"Her.lowerEyelidSquint", g.her, level))
	# Flash: matrix.translate(-32 + amount, 12) then rotate(-level / 18), clipped to 50 x 20
	var t := Vector2(-32 + level * -4.0 / 3.0, 12)
	var inv := Transform2D(level / 18.0, Vector2.ZERO)   # inverse of rotate(-level / 18)
	var si: Image = src.image
	var di: Image = dst.image
	for y in mini(20, di.get_height()):
		for x in mini(50, di.get_width()):
			var p: Vector2 = inv * Vector2(x + 0.5, y + 0.5) - t
			var sx := int(floor(p.x))
			var sy := int(floor(p.y))
			if sx >= 0 and sy >= 0 and sx < si.get_width() and sy < si.get_height():
				di.set_pixel(x, y, si.get_pixel(sx, sy))
	dst.mark_dirty()
	tears.lowerEyelidClear = false
	tears.lowerEyelidLayer.refresh()
	if lower_eyelid_level > 1:
		tears.releaseTears()


# ---------------------------------------------------------------- shock, pupils, mouth (value points)

## Her mood's shock (MOOD modifier of Her.eyelidShock): frightened moods and Tease as she runs out of air look shocked.
func mood_shock(v: float, her) -> float:
	var m: String = mm.mood_name
	var pof: float = her.passOutFactor / her.passOutMax
	if m in ["Frightened", "Nervous", "Excited", "Overwhelmed"]:
		return maxf(v, (30.0 if m == "Excited" else 60.0) - 30.0 * pof)
	if m == "Tease" and her.passOutFactor > 0:
		return maxf(v, 60.0 * pof)
	return v


## Her mood's iris size (GENERATE modifier of Her.irisScale; her.eyelidShock already has mood_shock in it).
func mood_iris(v: float, her) -> float:
	var m: String = mm.mood_name
	var pos: float = her.eyelidMotion["pos"]
	if m in ["Frightened", "Nervous", "Excited", "Overwhelmed"]:
		var target := 30.0 if m == "Excited" else 60.0
		return 0.9 - (0.25 - target / 400.0) - her.eyelidShock / 200.0
	if m == "Android":
		return 0.65 - minf(1, her.passOutFactor / her.passOutMax) / 6.0
	if m == "Tease" and her.passOutFactor > 0:
		return 0.9 - (0.25 - pos / 400.0) - her.eyelidShock / 200.0
	if m in ["Depressed", "Drugged", "Spent", "Elated", "Broken"]:
		return 0.9 - (0.25 - pos / 400.0) - her.eyelidShock / (600.0 if m == "Broken" else 300.0)
	return v


## How open her mouth counts as (MOOD modifier of Her.mouthOpenness): quieter breathing in some moods.
func mood_mouth_openness(v: float) -> float:
	var m: String = mm.mood_name
	if m == "Excited" or m == "Asleep":
		return minf(0.6, v)
	if m == "Overwhelmed" or m == "Numb":
		return minf(0.7, v)
	return v


## How far her mouth hangs open for her mood when nothing else moves the jaw (MOOD modifier of Her.jawAngle: `r` is
## the game's angle this tick, eased towards the mood's).
func hang_jaw(r: float) -> float:
	var her = g.her
	if her.gagged or her.swallowing or (her.penisInMouthDist >= 0 and not g.penisOut) or her.speaking or her.speakStopDelay > 0 or her.clenchTeethRatio != 0:
		return r
	var m: String = mm.mood_name
	var t: float = her.jawAngleTarget
	var divisor := 4.0
	if m in ["Broken", "Tease", "Overwhelmed"]:
		t = maxf(t, maxf(r, 4))
	elif m in ["Frightened", "Disgusted", "Asleep"]:
		t = minf(t, minf(r, -8))
	elif m in ["Drugged", "Numb"]:
		t = -4.0
		divisor = 2.0
	elif m in ["Nervous", "Submissive"]:
		t = minf(t, minf(r, -5))
	elif m in ["Excited", "Elated", "Smug"]:
		t = minf(t, minf(r, -3))
	elif m == "Devoted":
		t = minf(t, minf(r, linear_scale(0, -9, g.breathLevelMax, 5, g.currentBreathLevel)))
	else:
		return r
	her.jawAngleTarget = t   # direct: her mood's jaw target, so the game's own easing heads there too (as the mod did)
	return r + (t - r) / divisor


static func linear_scale(x1: float, y1: float, x2: float, y2: float, x: float) -> float:
	return y1 + (x - x1) * (y2 - y1) / (x2 - x1)


# ---------------------------------------------------------------- lips (after Her.updateLips)

## The angry mouth of the added moods: lips drawn like vanilla's angry mood.
func update_lips() -> void:
	var her = g.her
	if not mm.angry_lips or her.mouthShape != "Angry":   # angry lips while her mouth shows the angry shape
		return
	var up: int = maxi(0, her.lastUpperLipPos - 1)
	var low: int = mini(79, her.lastLowerLipPos + 6)
	her.bottomLipstick.gotoAndStop(low + 2)
	her.topLipstickContainer.topLipstick.gotoAndStop(up + 2)
	her.tongueContainer.gotoAndStop(low + 2)
	her.tongueContainer.rotation_degrees = her.head.jaw.rotation_degrees   # direct: the angry lips: drawn over the game's lips, as vanilla's angry mood does
	her.lastUpperLipPos = up   # direct: the angry lips: drawn over the game's lips, as vanilla's angry mood does
	her.lastLowerLipPos = low   # direct: the angry lips: drawn over the game's lips, as vanilla's angry mood does
	var face = her.head.face
	for x in [face.lipHighlight, face.lipShading, face.lipFill, face.lipOutline, her.head.headTan.face.lipFill, her.head.headTan.face.lipOutline]:
		x.gotoAndStop(up)
	low += her.lipSkinOffset
	her.head.jaw.gotoAndStop(low)
	her.head.headTan.jaw.gotoAndStop(low)


# ---------------------------------------------------------------- looking (value points Her.lookTarget, Her.gazeAngle)
# (moremoods' iris speed limits for some moods clamped the iris rotation before the game set it again from the eased
# angle, so they never showed; not carried over)

func _change_look_target(target: Vector2) -> void:
	trying_face = target == g.her.hisFace
	trying_penis = target == g.her.eyesDown
	angry_look_flag = true


func _look_point(x: float, y: float) -> Vector2:
	return g.sceneLayer.globalToLocal(g.her.localToGlobal(Vector2(x, y)))


## The point the mood holds her look at (moremoods' own state, never written into hers), null: none. The game's
## next look change ends it, as its own assignment replaced the mod's in the original.
func held_look():
	var cur: Vector2 = g.her.currentLookTarget
	if cur != _seen_look:
		_seen_look = cur
		_held_look = null
	return _held_look


func hold_look(p: Vector2) -> void:
	held_look()
	_held_look = p


## The mood's look point (MOOD modifier of Her.lookTarget): the point the game chose, or the mood's own. Only returns
## it: her own look state is the game's (dialogue looks, OVERRIDE, and pass-out states, FINAL, still apply on top).
func mood_point(point: Vector2) -> Vector2:
	var her = g.her
	var him = g.him
	var m: String = mm.mood_name
	var held = held_look()
	var cur: Vector2 = held if held != null else point
	if m == "Submissive":
		return _look_point(800, s("submissivehimeye") if trying_face else s("submissivenormaleye"))
	if m == "Drugged" and cur == her.hisFace:
		return her.eyesUnfocused
	if m == "Spent" or m == "Numb":
		return _look_point(816, -138)
	if m == "Depressed":
		return _look_point(800, 75)
	if m == "Android" and her.passedOut:
		return _look_point(800, s("androidmoodpassouteyeycord"))
	var want = null
	if m == "Nervous" and not g.gamePaused and her.mouthFull and not her.passedOut:
		want = her.eyesDown if him.ejaculating else her.hisFace
	if m == "Smug" and not g.gamePaused and not her.passedOut:
		if her.mouthFull:
			if him.ejaculating:
				want = her.eyesDown
		else:
			want = her.hisFace
	if m == "Professional" and not g.gamePaused and not her.passedOut:
		if him.pleasure + 10 > him.ejacPleasure or him.ejaculating:
			want = her.hisFace
	if m == "Tease" or m == "Overwhelmed":
		if not g.gamePaused and not her.passedOut:
			if (her.mouthFull and him.ejaculating) or (her.mouthFull and her.passOutFactor > 0) or (her.held and mm.bite_timer() > 20):
				if cur != her.eyesDown:
					want = her.eyesDown
					eye_look_timer = 80 if him.ejaculating else 30
			elif eye_look_timer == 0:
				want = her.hisFace
		eye_look_timer = maxi(0, eye_look_timer - 1)
	if want != null and want != cur:
		hold_look(want)
		cur = want
	return cur


## moremoods' iris angle (GENERATE modifier of Her.gazeAngle), towards the point she looks at.
func gaze_angle() -> float:
	var her = g.her
	var m: String = mm.mood_name
	var local: Vector2 = her.globalToLocal(g.sceneLayer.localToGlobal(her.lookPoint))
	var aim: Vector2 = her.eyeAim
	var em := {"target": 0.0}
	var d := local - aim
	if m == "Submissive":
		em["target"] = clampf(g.getAngle(d.x, d.y), 75, 120)
	elif m == "Drugged":
		em["target"] = clampf(g.getAngle(d.x, d.y), 75, 106)
	else:
		em["target"] = clampf(g.getAngle(d.x, d.y), 75, 110)
	var lid_track: float = her.eyelidMotion["pos"]
	if eyelid_mode == 2 or eyelid_mode == 3:
		lid_track = maxf(lid_track, 150 * eyelid_slider)
	var assigned := eyeroll_enabled() or m in ["Ahegao", "Broken", "Horny", "Devoted"]
	var scale_y: float = s("eyelidslidereyeposscaley")
	if assigned:
		var roll := 62.0
		if eyeroll_enabled():
			roll = s("eyerolltargetangle")
		if m == "Spent":
			roll = 86
		if m == "Smug" or m == "Horny" or m == "Tease":
			roll = 65
			scale_y += 30
		em["target"] = roll + lid_track * 0.05 + randf() * 2 - 1
	var recenter := 0.0
	var vibration := 0.0
	var raise: float = her.passOutFactor
	if m in ["Frightened", "Nervous", "Overwhelmed"]:
		var c: float = s("feareyesamount") + her.passOutFactor / her.passOutMax * (her.passOutMax - s("feareyesamount"))
		vibration = randf() * 0.5 * c
		recenter = 0.25 * c
	else:
		vibration = randf() * 0.5 * her.passOutFactor
		recenter = 0.25 * her.passOutFactor
	if m == "Android":
		vibration = 0
		raise = her.passOutFactor * 1.5 if not her.passedOut else 0.0
	if s("limiteyerollpassoutangle"):
		var iris = her.eye.ball.irisContainer.iris
		var extra := clampf(iris.scaleY, 0, 1) / 0.9
		extra = clampf(1 - extra, 0, 1)
		# Port fix: the limit follows her upper eyelid as drawn. The mod took the more open of it and the game's
		# eyelid target, which is far more open than the drawn lid when a mood lowers her lids (Numb, Depressed,
		# ...) and another effect opens the target wide (ffbehavior): her irises then rolled up under the lid.
		var upper_frame: float = her.eye.upperEyelid.currentFrame
		var limit: float = s("eyelidslidereyeposbaselimit") \
			+ s("eyelidslidereyeposscalelimit") * minf(150, upper_frame) / 150.0 + scale_y * extra
		var inc := maxf(em["target"] - raise * 0.5, limit)
		if not assigned and m != "Spent":
			recenter = 0
		# Port fix: her eyes tremble as she runs out of air (up to half her pass-out factor), within the limit (the mod
		# took the tremble off after limiting, so it rolled her irises up to 20 degrees past it)
		em["target"] = maxf(inc - vibration + recenter, limit)
	else:
		em["target"] = em["target"] - (vibration + raise * 0.5)
	return em["target"]


## After Her.lookAt (the game eased the iris to the angle): the iris offsets of some moods.
func _after_look() -> void:
	var her = g.her
	var m: String = mm.mood_name
	var ic = her.eye.ball.irisContainer
	if m == "Drugged":
		ic.x = -54
		her.eye.ball.highlights.x = 17   # direct: her mood's iris offset (art placement; the game never moves it)
	if eyeroll_mode == 2 or m == "Broken":
		var cock := clampf(her.passOutFactor / her.passOutMax, 0, 1)
		ic.x = -54 - 6 * cock
		her.eye.ball.highlights.x = 17 - 5 * cock   # direct: her mood's iris offset (art placement; the game never moves it)


# ---------------------------------------------------------------- waking up (value point)

## Where her eyes start from as she wakes (MOOD modifier of Her.wakeGaze): Spent from below, Submissive from above.
func mood_wake_gaze(v: float) -> float:
	match mm.mood_name:
		"Spent":
			return 80.0
		"Submissive":
			return 110.0
	return v
