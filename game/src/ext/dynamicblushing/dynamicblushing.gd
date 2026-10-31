extends SDTExtension
## Built-in reimplementation of the Loader mod dynamicBlushing (V1): her blush deepens with what happens (vigour,
## breath, pleasure, cum in her mouth / on her face / in her eyes, swallowing, coughs, his grip, tongue, looks,
## throat anticipation, his spurts in her throat, waking up) and fades again. Blush shown =
## her blush colour's alpha + (sum of the effects) x (maxBlush - that alpha) x her blush factor, at most maxBlush.
## "Dynamic blushing" (Her > Colours, under Blush) is off by default (the original game's fixed blush); the blush
## factor is per character, in the character code as "blushFactor:n" like the mod (a full code without it means 1).
## The effects' values are the mod's settings file as shipped; it overrides moremoods' blushing (its
## overrideMoreMoods=1). Written from its decompiled code.

# the mod's settings file (dynamicBlushingV1.txt)
const S := {
	"maxBlush": 1.1,
	"vigorMax": 0.4, "vigorFactor": 1.0,
	"passOutFactorMax": 0.5, "passOutDecreaseRate": 0.008,
	"wakeUpMax": 0.6, "wakeUpIncreaseRate": 0.15, "wakeUpDecreaseRate": 0.008,
	"pleasureMax": 0.4, "pleasureIncreaseRate": 0.01, "pleasureDecreaseRate": 0.01,
	"throatEjacMax": 0.4, "throatEjacIncreaseRate": 0.02, "throatEjacDecreaseRate": 0.01,
	"cumInEyeMax": 0.4, "cumInEyeIncreaseConstant": 0.05, "cumInEyeDecreaseRate": 0.001,
	"cumOnFaceMax": 0.4, "cumOnFaceIncreaseConstant": 0.0125, "cumOnFaceDecreaseRate": 0.001,
	"cumInMouthMax": 0.4, "cumInMouthIncreaseRate": 0.01, "cumInMouthDecreaseRate": 0.005,
	"swallowingMax": 0.2, "swallowingIncreaseRate": 0.01, "swallowingDecreaseRate": 0.01,
	"nostrilSprayMax": 0.6, "nostrilSprayIncreaseRate": 0.2, "nostrilSprayDecreaseRate": 0.02,
	"clenchTeethMax": 0.4, "clenchTeethIncreaseRate": 0.01, "clenchTeethDecreaseRate": 0.02,
	"waggleEyebrowsMax": 0.2, "waggleEyebrowsIncreaseRate": 0.04, "waggleEyebrowsDecreaseRate": 0.01,
	"headGrabMax": 0.2, "headGrabIncreaseRate": 0.03, "headGrabDecreaseRate": 0.02, "headGrabInitial": 0.4,
	"headGrabMinimumTime": 30,
	"throatAnticipationMax": 0.3, "throatAnticipationIncreaseRate": 0.015, "throatAnticipationDecreaseRate": 0.03,
	"throatAnticipationRange": 0.75,
	"coughMax": 0.25, "coughInitial": 0.15, "coughDecreaseRate": 0.005,
	"openCoughMax": 0.5, "openCoughInitial": 0.3, "openCoughDecreaseRate": 0.01,
	"tongueActionMax": 0.2, "tongueActionIncreaseRate": 0.01, "tongueActionDecreaseRate": 0.02,
	"tongueMovingOutBlushTime": 60, "tongueLickBlushTime": 40, "tongueLongLickBlushTime": 50,
	"tongueSmallLickBlushTime": 30, "tongueTinyLickBlushTime": 20, "tongueQuickLickBlushTime": 10,
	"tongueShaftLickBlushTime": 25,
	"tongueOutMax": 0.2, "tongueOutIncreaseRate": 0.02, "tongueOutDecreaseRate": 0.02,
	"lookAtFaceOffMax": 0.0, "lookAtFaceOffIncreaseRate": 0.004, "lookAtFaceOffDecreaseRate": 0.012,
	"lookAtPenisOffMax": 0.3, "lookAtPenisOffIncreaseRate": 0.004, "lookAtPenisOffDecreaseRate": 0.012,
	"lookAtFaceOnMax": 0.3, "lookAtFaceOnIncreaseRate": 0.004, "lookAtFaceOnDecreaseRate": 0.012,
	"lookAtPenisOnMax": 0.0, "lookAtPenisOnIncreaseRate": 0.004, "lookAtPenisOnDecreaseRate": 0.012,
}

var blush_factor := 1.0
var cur: Dictionary = {}   # effect -> current amount
var _waggle := 0
var _grab_counter := 3
var _closed_hand := false
var _tongue_counter := 0
var _pass_out_counter := 0
var _waking := false
var _spurt_counter := 0


func _init() -> void:
	id = "dynamicblushing"
	title = "dynamicBlushing"
	description = "dynamicBlushing: her blush deepens with what happens and fades again (Her > Colours, under Blush)."
	default_enabled = true


func _setup() -> void:
	setting("on", false, {"label": "Dynamic blushing",
		"desc": "Her blush deepens with what happens (vigour, breath, cum, his grip...) and fades again."})


func _enable() -> void:
	_reset_effects()
	hook_after(&"Her.waggleEyebrows", func(_c): _waggle = 25)
	hook_after(&"Him.openHand", func(_c): _grab_counter = S["headGrabMinimumTime"])
	hook_after(&"Him.closeHand", func(_c):
		if g.him.currentArmPosition == 0 and _grab_counter < 0:
			_closed_hand = true)
	hook_before(&"Tongue.performNextAction", func(_c): _tongue_action())
	hook_after(&"Her.passOut", func(_c): _pass_out_counter = 0)
	hook_after(&"Her.wakeUp", func(_c): _waking = true)
	hook_after(&"Her.eyeHit", func(_c): _add("cumInEye", S["cumInEyeIncreaseConstant"], S["cumInEyeMax"]))
	hook_after(&"Her.cumOnFace", func(_c): _add("cumOnFace", S["cumOnFaceIncreaseConstant"], S["cumOnFaceMax"]))
	hook_after(&"Him.nextSpurt", func(_c):
		if g.her.held:
			_spurt_counter = int(floor(g.him.spurtTimer / 1.5 + 0.5)))
	hook_after(&"Her.cough", func(_c): _add("cough", S["coughInitial"], S["coughMax"]))
	hook_after(&"Her.openCough", func(_c): _add("openCough", S["openCoughInitial"], S["openCoughMax"]))
	on_late_tick(_tick)
	charcode_field("blushFactor", func(): return _num(blush_factor), func(v, _l): blush_factor = v.to_float(),
		func(_l): blush_factor = 1.0)
	var on := func(): return get_setting("on")
	menu_control("her", "Colours", MenuSchema.setting_control(self, "on", {"after": "Blush"}))
	menu_control("her", "Colours", {"type": "slider", "label": "Blush factor", "after": "Blush",
		"tip": "How fast and how much she blushes (this character; 1 = the mod's own).", "min": 0.0, "max": 3.0,
		"step": 0.05, "get": func(): return blush_factor, "set": func(v: float): blush_factor = v,
		"release": func(): g.saveData.saveCharData(), "format": func(v): return str(snappedf(v, 0.01)),
		"reset": func(): blush_factor = 1.0; g.saveData.saveCharData(),
		"visible": on})


func _disable() -> void:
	_restore()


func _setting_changed(_key: String, value) -> void:
	if not value:
		_restore()


## Her blush colour's own alpha back (the mod's toggle-off).
func _restore() -> void:
	if g.her != null and g.characterControl != null:
		g.her.blush.alpha = g.characterControl.blushRGB.a


func _reset_effects() -> void:
	for k in ["cumInMouth", "swallowing", "clenchTeeth", "waggleEyebrows", "nostrilSpray", "headGrab", "tongueAction",
			"tongueOut", "wakeUp", "lookAtFaceOff", "lookAtPenisOff", "lookAtFaceOn", "lookAtPenisOn", "cumInEye",
			"cumOnFace", "throatAnticipation", "throatEjac", "cough", "openCough", "pleasure"]:
		cur[k] = 0.0


func _add(k: String, amount: float, cap: float) -> void:
	cur[k] = minf(cap, cur[k] + amount)


## Towards its max while `up`, back to 0 otherwise (the mod's pattern for most effects); returns the amount.
func _ramp(k: String, up: bool) -> float:
	if up:
		cur[k] = minf(S[k + "Max"], cur[k] + S[k + "IncreaseRate"])
	else:
		cur[k] = maxf(0.0, cur[k] - S[k + "DecreaseRate"])
	return cur[k]


func _decay(k: String) -> float:
	cur[k] = maxf(0.0, cur[k] - S[k + "DecreaseRate"])
	return cur[k]


func _tongue_action() -> void:
	if not g.tongue:
		return
	var t = g.her.tongue
	var n: Callable = t.nextAction
	if n == Callable(t, "startMovingTongueOut"):
		_tongue_counter = S["tongueMovingOutBlushTime"]
	elif t.tongueOut:
		for a in [["lick", "tongueLickBlushTime"], ["longLick", "tongueLongLickBlushTime"],
				["smallLick", "tongueSmallLickBlushTime"], ["tinyLick", "tongueTinyLickBlushTime"],
				["quickLick", "tongueQuickLickBlushTime"], ["shaftLick", "tongueShaftLickBlushTime"]]:
			if n == Callable(t, a[0]):
				_tongue_counter = S[a[1]]
				break


func _tick() -> void:
	var her = g.her
	var him = g.him
	if not get_setting("on") or her == null or not g.gameRunning:
		return
	var sum := 0.0
	sum += _ramp("cumInMouth", cur["cumInMouth"] < her.cumInMouth / 40.0)
	sum += _ramp("swallowing", her.swallowing)
	sum += _ramp("clenchTeeth", her.clenchTeeth)
	var waggling := _waggle > 0
	if waggling:
		_waggle -= 1
	sum += _ramp("waggleEyebrows", waggling)
	sum += _ramp("nostrilSpray", her.nostrilSprayToggle)
	_grab_counter -= 1
	if _closed_hand:
		_closed_hand = false
		cur["headGrab"] = S["headGrabInitial"]
	elif not him.handOpen and cur["headGrab"] > S["headGrabMax"]:
		cur["headGrab"] = maxf(S["headGrabMax"], cur["headGrab"] - S["headGrabDecreaseRate"])
	elif not him.handOpen and cur["headGrab"] < S["headGrabMax"] and him.currentArmPosition == 0:
		cur["headGrab"] = minf(S["headGrabMax"], cur["headGrab"] + S["headGrabIncreaseRate"])
	elif him.handOpen or him.currentArmPosition == 1:
		cur["headGrab"] = maxf(0.0, cur["headGrab"] - S["headGrabDecreaseRate"])
	sum += cur["headGrab"]
	var acting := _tongue_counter > 0
	if acting:
		_tongue_counter -= 1
	sum += _ramp("tongueAction", acting)
	sum += _ramp("tongueOut", her.tongue.tongueOut)
	sum += her.passOutFactor / 40.0 * S["passOutFactorMax"]
	if her.passedOut:
		_pass_out_counter += 1
		sum -= _pass_out_counter * S["passOutDecreaseRate"]
	if _waking:
		cur["wakeUp"] = minf(S["wakeUpMax"], cur["wakeUp"] + S["wakeUpIncreaseRate"])
		if cur["wakeUp"] == S["wakeUpMax"]:
			_waking = false
	else:
		_decay("wakeUp")
	sum += cur["wakeUp"]
	var open: bool = not her.eyelidMotion["isClosed"]
	var at_face: bool = her.lookPoint == her.hisFace and open
	var at_penis: bool = her.lookPoint == her.eyesDown and open
	sum += _ramp("lookAtFaceOff", at_face and not her.mouthFull)
	sum += _ramp("lookAtPenisOff", at_penis and not her.mouthFull)
	sum += _ramp("lookAtFaceOn", at_face and her.mouthFull)
	sum += _ramp("lookAtPenisOn", at_penis and her.mouthFull)
	sum += _decay("cumInEye")
	sum += _decay("cumOnFace")
	sum += _ramp("throatAnticipation", her.mouthFull and not her.held and her.penisInMouthDist < her.deepthroatDistance
		and her.penisInMouthDist > her.deepthroatDistance * S["throatAnticipationRange"])
	var spurting := _spurt_counter > 0
	if spurting:
		_spurt_counter -= 1
	sum += _ramp("throatEjac", spurting)
	sum += _decay("cough")
	sum += _decay("openCough")
	sum += minf(S["vigorMax"], her.vigour / 1050.0 * S["vigorMax"] * S["vigorFactor"])
	sum += _ramp("pleasure", him.pleasure / 150.0 * S["pleasureMax"] > cur["pleasure"])
	if Hooks.has_value(&"Her.blushEffects"):   # HOOK value point: the effects' sum, before her blush factor
		sum = Hooks.value(&"Her.blushEffects", her, sum)
	var base: float = g.characterControl.blushRGB.a
	var v := minf(S["maxBlush"], maxf(base, base + sum * (S["maxBlush"] - base) * blush_factor))
	if absf(her.blush.alpha - v) > 0.002:   # a new alpha re-renders her blush: only when it shows
		her.blush.alpha = v


static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)
