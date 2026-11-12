extends RefCounted
## Rule checks (main.gd --driver, run by tools/rules_checks.sh): pins ported game rules to the original
## ActionScript. Every expected value is read from the decompiled game's scripts and carries a `# src:` comment
## naming the file and line there (relative to the decompiled scripts folder). Each check reads a ported constant or
## calls the ported function on the running game and compares the result with that value.
## Run in Vanilla mode (--vanilla) so no extension changes the value points these rules go through.
## Prints one "RULE FAIL" line per failing check and "RULES CHECKS: n passed, m failed", then quits (exit code 1 on
## any failure). --verbose also prints the passing checks.
##
## All checks run in one tick, after the game has started: nothing else moves her or him between a check's setup
## and its result.

const START_TICK := 30   # the game starts (Play)
const CHECK_TICK := 90   # the checks run (her and him are set up and ticking)

var _pass := 0
var _fail := 0
var _verbose := "--verbose" in OS.get_cmdline_user_args()
var _done := false


func step(_frame: int) -> void:
	if _done:
		return
	if Flash.tick_count == START_TICK:
		Flash.stage.getChildAt(0).playClicked()
	elif Flash.tick_count >= CHECK_TICK:
		_done = true
		_run()
		print("RULES CHECKS: %d passed, %d failed" % [_pass, _fail])
		Flash.get_tree().quit(1 if _fail > 0 else 0)


func _eq(name: String, got, want) -> void:
	var ok: bool
	if (typeof(got) == TYPE_FLOAT or typeof(got) == TYPE_INT) and (typeof(want) == TYPE_FLOAT or typeof(want) == TYPE_INT):
		ok = absf(float(got) - float(want)) <= 1e-9 * maxf(1.0, absf(float(want)))
	else:
		ok = got == want
	_result(name, ok, "got %s, want %s" % [got, want])


## For values the port keeps in a Vector2 (32-bit floats; Flash's Point holds 64-bit Numbers).
func _near(name: String, got: float, want: float, tolerance := 1e-6) -> void:
	_result(name, absf(got - want) <= tolerance, "got %s, want %s (within %s)" % [got, want, tolerance])


func _true(name: String, ok: bool, detail := "") -> void:
	_result(name, ok, detail)


func _result(name: String, ok: bool, detail: String) -> void:
	if ok:
		_pass += 1
		if _verbose:
			print("RULE ok   %s" % name)
	else:
		_fail += 1
		print("RULE FAIL %s: %s" % [name, detail])


func _run() -> void:
	if g.her == null or g.him == null or g.automaticControl == null:
		_true("game started", false, "g.her / g.him / g.automaticControl missing at tick %d" % Flash.tick_count)
		return
	_breath_checks()
	_mouth_checks()
	_pass_out_checks()
	_her_misc_checks()
	_auto_checks()
	_pleasure_checks()   # last: it makes him finish


# ---------------------------------------------------------------- breath (g)

func _breath_checks() -> void:
	_eq("breath max", g.breathLevelMax, 50)   # src: g.as:129
	_eq("out of breath point", g.outOfBreathPoint, 25)   # src: g.as:131
	g.setBreathTo(10)
	g.addBreath(100)
	_eq("addBreath stops at the max", g.breathLevel, 50)   # src: g.as:466
	g.addBreath(-100)
	_eq("addBreath stops at 0", g.breathLevel, 0)   # src: g.as:466
	g.setBreathTo(80)
	_eq("setBreathTo stops at the max", g.breathLevel, 50)   # src: g.as:474
	_eq("her breathing restarts after ticks", g.her.breatheDelayTime, 10)   # src: obj/Her.as:530


# ---------------------------------------------------------------- mouth entry, resistance, deepthroat (Her)

func _mouth_checks() -> void:
	var her = g.her
	_eq("deepthroat distance", her.deepthroatDistance, 150)   # src: obj/Her.as:170
	_eq("deepthroat start distance", her.deepthroatStartDistance, 75)   # src: obj/Her.as:172
	_eq("first intro depth", her.introStartDist, 80)   # src: obj/Her.as:208
	_eq("resistance upper", her.resistance["upper"], 0.01)   # src: obj/Her.as:585
	_eq("resistance lower", her.resistance["lower"], 0)   # src: obj/Her.as:587
	_eq("resistance multiplier", her.resistance["multiplier"], 5)   # src: obj/Her.as:588
	_eq("pull-off power start", her.pullOffPower["start"], 0.001)   # src: obj/Her.as:592
	_eq("pull-off power increase", her.pullOffPower["increase"], 0.00005)   # src: obj/Her.as:594
	_eq("pull-off power max", her.pullOffPower["max"], 0.008)   # src: obj/Her.as:595

	# the menu sliders' rules
	var intro_was: float = g.introResistance
	var throat_was: float = g.throatResistance
	her.setIntroResistance(50)
	_eq("intro relax step at resistance 50", her.introRelaxDist, 12.5)   # src: obj/Her.as:1248 (25 - 50 * 0.25)
	her.setIntroResistance(100)
	_eq("intro relax step never below 0.25", her.introRelaxDist, 0.25)   # src: obj/Her.as:1248
	her.setThroatResistance(200)
	_eq("throat resistance capped at 100", her.resistance["boundary"], 0.2)   # src: obj/Her.as:1254 (100 * 0.002)
	her.setThroatResistance(50)
	_eq("throat resistance 50 = the default boundary", her.resistance["boundary"], 0.1)   # src: obj/Her.as:586, obj/Her.as:1254
	her.setIntroResistance(intro_was)

	# checkPosition, with nothing else in the way: penis in, no intro, not at the hilt, no cough due
	g.setPenisOut(false)
	her.intro = false
	her.firstDT = false
	her.passedOut = false
	her.movement = 0.0
	her.hiltDistance = 1.0e6
	her.pos = 0.5
	her.nextCoughTime = 1000
	# held in her throat: breath builds, no resistance, she pulls off harder each tick up to the max
	her.held = true
	her.penisInMouthDist = 200.0
	her.pullOff = 0.0
	her.pullOffPower["current"] = 0.001
	g.setBreathTo(10)
	her.checkPosition()
	_eq("held: breath +0.1 per tick", g.breathLevel, 10.1)   # src: obj/Her.as:2244
	_eq("held: resistance is the lower one", her.previousResistance, 0)   # src: obj/Her.as:2243
	_eq("held: pull-off grows by its power", her.pullOff, 0.001)   # src: obj/Her.as:2245
	_eq("held: pull-off power grows", her.pullOffPower["current"], 0.00105)   # src: obj/Her.as:2246 (0.001 + 0.00005)
	her.pullOffPower["current"] = 0.008
	her.checkPosition()
	_eq("held: pull-off power stops at its max", her.pullOffPower["current"], 0.008)   # src: obj/Her.as:2246
	# between the deepthroat start and the throat: resistance rises with depth, breath unchanged
	her.held = false
	her.penisInMouthDist = 100.0
	g.setBreathTo(10)
	her.checkPosition()
	_eq("throat entry resistance at depth 100", her.previousResistance, 0.01 + 0.1 * 25.0 / 75.0)   # src: obj/Her.as:2255
	_eq("throat entry: breath unchanged", g.breathLevel, 10)   # src: obj/Her.as:2253-2260
	# shallow: she gets her breath back; leaving the throat resets the pull-off
	her.held = true
	her.penisInMouthDist = 50.0
	her.pullOff = 0.5
	g.setBreathTo(10)
	her.checkPosition()
	_eq("shallow: breath -0.05 per tick", g.breathLevel, 9.95)   # src: obj/Her.as:2259
	_eq("out of the throat: pull-off resets", her.pullOff, 0)   # src: obj/Her.as:2265
	_eq("out of the throat: pull-off power back to its start", her.pullOffPower["current"], 0.001)   # src: obj/Her.as:2266
	# the intro: each time he pulls out after reaching her limit she lets him in further, until the throat
	her.penisInMouthDist = 0.0
	her.held = false
	her.intro = true
	her.introRelaxDist = 12.5
	her.maxIntroDist = 80.0
	her.introPosToBeMoved = true
	her.checkPosition()
	_eq("intro: limit grows by the relax step", her.maxIntroDist, 92.5)   # src: obj/Her.as:2311
	_true("intro: goes on below the deepthroat distance", her.intro)   # src: obj/Her.as:2312
	her.maxIntroDist = 140.0
	her.introPosToBeMoved = true
	her.checkPosition()
	_true("intro: ends at the deepthroat distance", not her.intro)   # src: obj/Her.as:2312-2314
	her.setThroatResistance(throat_was)
	her.setIntroResistance(intro_was)
	her.startIntro()
	_eq("startIntro: intro limit back to its start", her.maxIntroDist, 80)   # src: obj/Her.as:1236, obj/Her.as:208
	_eq("startIntro: self mode deepthroat progress", g.automaticControl.deepthroatProgress,
		g.automaticControl.currentPenisTipPos + 0.4)   # src: obj/AutomaticControl.as:246


# ---------------------------------------------------------------- breathing animation and passing out (Her)

func _pass_out_checks() -> void:
	var her = g.her
	_eq("pass-out max", her.passOutMax, 40)   # src: obj/Her.as:460
	# not breathing with no air left: she gets closer to passing out
	her.breathing = false
	her.passedOut = false
	her.passOutFactor = 0.0
	g.setBreathTo(g.breathLevelMax)
	her.animateBreathing()
	_eq("no air: pass-out +0.05 per tick", her.passOutFactor, 0.05)   # src: obj/Her.as:2371
	her.passOutFactor = 3.0
	g.setBreathTo(49)
	her.animateBreathing()
	_eq("some air left: pass-out unchanged", her.passOutFactor, 3.0)   # src: obj/Her.as:2369
	her.passOutFactor = 39.97
	g.setBreathTo(g.breathLevelMax)
	her.animateBreathing()
	_true("passes out at the max", her.passedOut)   # src: obj/Her.as:2377-2379
	_eq("passing out sets the max", her.passOutFactor, 40)   # src: obj/Her.as:1763
	# breathing again: she recovers, and wakes up once it is back to 0
	her.breathing = true
	her.passOutFactor = 10.0
	her.animateBreathing()
	_eq("breathing: pass-out -0.5 per tick", her.passOutFactor, 9.5)   # src: obj/Her.as:2360
	her.passOutFactor = 0.0
	g.setBreathTo(10)
	her.animateBreathing()
	_true("wakes up at 0", not her.passedOut)   # src: obj/Her.as:2362-2364
	_eq("waking up gives back the out-of-breath point", g.breathLevel, 35)   # src: obj/Her.as:1817 (10 + 25)


# ---------------------------------------------------------------- other Her rules

func _her_misc_checks() -> void:
	var her = g.her
	_eq("wince vigour", her.VIGOUR_WINCE_LEVEL, 1000)   # src: obj/Her.as:230
	her.vigour = 5000.0
	her.move(g.currentPos.x, g.currentPos.y)
	_eq("vigour capped at 1050", her.vigour, 1050)   # src: obj/Her.as:1608
	her.coughBuild = 5.0
	her.tickCoughBuild()
	_eq("cough build -0.05 per tick", her.coughBuild, 4.95)   # src: obj/Her.as:2390
	her.coughBuild = 10.5
	her.tickCoughBuild()
	_eq("cough at 10, keeps the rest", her.coughBuild, 0.45)   # src: obj/Her.as:2390-2393
	_eq("cum in mouth max", her.maxCumInMouth, 40)   # src: obj/Her.as:476
	_eq("mouth full of cum", her.fullCumInMouth, 25)   # src: obj/Her.as:506
	_eq("nostril spray needs", her.minNostrilSpray, 5)   # src: obj/Her.as:508
	her.held = false
	her.cumInMouth = 39
	her.fillMouth(true)
	_eq("fillMouth +1", her.cumInMouth, 40)   # src: obj/Her.as:3371
	her.fillMouth(true)
	_eq("fillMouth stops at the max", her.cumInMouth, 40)   # src: obj/Her.as:3371, obj/Her.as:476
	her.cumInMouth = 0
	_eq("closed jaw angle", her.getJawAngle(1.0), -12)   # src: obj/Her.as:382, obj/Her.as:2777
	_eq("jaw angle scales", her.getJawAngle(0.5, 2.0), -12)   # src: obj/Her.as:2777
	her.setBodyScaleFromSlider(0.0)
	_eq("smallest body", her.bodyScale, 0.95)   # src: obj/Her.as:262, obj/Her.as:826
	her.setBodyScaleFromSlider(1.0)
	_eq("largest body", her.bodyScale, 1.075)   # src: obj/Her.as:264, obj/Her.as:826
	her.setBodyScale(2.0)
	_eq("body scale capped", her.bodyScale, 1.075)   # src: obj/Her.as:832
	her.setDefaultBodyScale()
	_eq("default body size on the slider", her.bodySize, (1.0 - 0.95) / (1.075 - 0.95))   # src: obj/Her.as:815, obj/Her.as:820
	var hilt_was: float = her.hiltDistance
	her.hisPenisSizeChanged(300.0)
	_eq("hilt 25 short of his length", her.hiltDistance, 275)   # src: obj/Her.as:1318
	her.hisPenisSizeChanged(hilt_was + 25.0)


# ---------------------------------------------------------------- automatic modes (AutomaticControl)

func _names(modes: Array) -> Array:
	return modes.map(func(c: Callable): return String(c.get_method()))


func _auto_checks() -> void:
	var ac: AutomaticControl = g.automaticControl
	_eq("auto mode names", AutomaticControl.autoModeNameList, ["Normal", "Soft", "Hard", "Self"])   # src: obj/AutomaticControl.as:9
	_eq("normal modes", _names(ac.standardModes), ["holdDown", "activeHoldDown", "offHold", "fullSlow", "fullFast",
		"deepFast", "shallowSlow", "shallowMedium", "shallowFast", "mediumSlow", "tipToDeepMedium", "mediumFast"])   # src: obj/AutomaticControl.as:102-113
	_eq("soft modes", _names(ac.softModes), ["offHold", "shallowSlow", "shallowMedium", "mediumSlow",
		"tipToDeepMedium", "tipToDeepSlow"])   # src: obj/AutomaticControl.as:115-120
	_eq("hard modes", _names(ac.hardModes), ["holdDown", "activeHoldDown", "offHold", "fullFast", "deepFast",
		"shallowFast", "mediumFast", "tipToDeepFast", "fullSlam", "hiltMove"])   # src: obj/AutomaticControl.as:122-131
	_eq("self modes", _names(ac.selfModes), ["offHold", "shallowSlow", "shallowMedium", "shallowMedium",
		"mediumSlow", "tipToDeepSlow", "tipToDeepMedium", "tipToDeepMedium", "tipHold", "outsideLickBalls"])   # src: obj/AutomaticControl.as:133-142
	_eq("normal finish modes", _names(ac.normalEjacModes), ["activeHoldDown", "shallowHold", "offHold",
		"offHold"])   # src: obj/AutomaticControl.as:185-188
	_eq("hard finish modes", _names(ac.hardEjacModes), ["activeHoldDown", "shallowHold", "offHold", "offHold",
		"hiltMove"])   # src: obj/AutomaticControl.as:194-198

	# mode changes: how long a mode lasts and how fast the next one blends in (200 draws each)
	var bad := []
	var repeat := false
	for i in 200:
		var last := ac.lastModeNo
		ac.standardAuto()
		var off := ac.currentMode == ac.offHold
		var lo := 60   # src: obj/AutomaticControl.as:348, obj/AutomaticControl.as:352
		var hi := 180 if off else 360   # src: obj/AutomaticControl.as:348 (120 + 60), obj/AutomaticControl.as:352 (300 + 60)
		if ac.nextModeTimer < lo or ac.nextModeTimer >= hi:
			bad.append(ac.nextModeTimer)
		if not g.her.isActingOff() and ac.lastModeNo == last:
			repeat = true
	_true("normal: mode lengths", bad.is_empty(), "out of range: %s" % [bad.slice(0, 5)])
	_true("normal: never the same mode twice", not repeat)   # src: obj/AutomaticControl.as:341
	_eq("normal: blend speed", ac.transitionSpeed, 0.01)   # src: obj/AutomaticControl.as:356
	bad = []
	for i in 200:
		ac.hardAuto()
		var off := ac.currentMode == ac.offHold
		var lo := 30 if off else 60   # src: obj/AutomaticControl.as:389, obj/AutomaticControl.as:393
		var hi := 90 if off else 210   # src: obj/AutomaticControl.as:389 (60 + 30), obj/AutomaticControl.as:393 (150 + 60)
		if ac.nextModeTimer < lo or ac.nextModeTimer >= hi:
			bad.append(ac.nextModeTimer)
	_true("hard: mode lengths", bad.is_empty(), "out of range: %s" % [bad.slice(0, 5)])
	_eq("hard: blend speed", ac.transitionSpeed, 0.25)   # src: obj/AutomaticControl.as:397
	ac.softAuto()
	_eq("soft: blend speed", ac.transitionSpeed, 0.01)   # src: obj/AutomaticControl.as:441
	ac.randomEjaculatingMode()
	_eq("finish mode length", ac.nextModeTimer, 600)   # src: obj/AutomaticControl.as:526
	_eq("finish mode blend speed", ac.transitionSpeed, 0.05)   # src: obj/AutomaticControl.as:529
	bad = []
	var tilt_bad := []
	for i in 200:
		ac.doneEjaculating()
		if ac.nextModeTimer < 60 or ac.nextModeTimer >= 150:   # src: obj/AutomaticControl.as:315 (90 + 60)
			bad.append(ac.nextModeTimer)
		ac.randomOffTilt()
		if ac.offTiltTarget < -0.9 or ac.offTiltTarget >= 0.5 \
				or ac.offTiltChangeTimer < 60 or ac.offTiltChangeTimer >= 360:   # src: obj/AutomaticControl.as:510-511
			tilt_bad.append([ac.offTiltTarget, ac.offTiltChangeTimer])
	_true("pause after finishing", bad.is_empty(), "out of range: %s" % [bad.slice(0, 5)])
	_true("off-axis tilt", tilt_bad.is_empty(), "out of range: %s" % [tilt_bad.slice(0, 3)])

	# the movement patterns: sinWave and one pattern built on it
	ac.t = 10
	_eq("sinWave", ac.sinWave(0.06, 1.0, 0.2), 0.2 + (sin(10 * 0.06) + 1.0) * 1.0 * 0.5)   # src: obj/AutomaticControl.as:628
	g.setPenisOut(false)
	ac.t = 7
	ac.currentPenisTipPos = 0.3
	ac.fullLength = 0.7
	ac.offTilt = 0.5
	var p: Vector2 = ac.fullFast()
	_near("fullFast depth", p.x, 0.3 + (sin(7 * 0.25) + 1.0) * (0.7 + 0.2) * 0.5)   # src: obj/AutomaticControl.as:669
	_near("fullFast tilt capped", p.y, 0.2)   # src: obj/AutomaticControl.as:670
	ac.updatePenisTipPos()
	ac.randomMode = ac.standardAuto


# ---------------------------------------------------------------- his pleasure and finish (Him)

func _pleasure_checks() -> void:
	var him = g.him
	_eq("finish pleasure", him.ejacPleasure, 140)   # src: obj/Him.as:129
	_eq("smallest penis", Him.MIN_PENIS_SIZE, 0.7)   # src: obj/Him.as:81
	_eq("largest penis", Him.MAX_PENIS_SIZE, 1.2)   # src: obj/Him.as:83
	_eq("smallest balls", Him.MIN_BALL_SIZE, 0.5)   # src: obj/Him.as:91
	_eq("largest balls", Him.MAX_BALL_SIZE, 1.3)   # src: obj/Him.as:93
	_eq("spurt minimum", Him.EJACULATION["min_spurt"], 6)   # src: obj/Him.as:1077
	_eq("spurt maximum (plus 0-5)", Him.EJACULATION["max_spurt"], 21)   # src: obj/Him.as:1076
	_eq("spurt share", Him.EJACULATION["normal"], [0.2, 0.3])   # src: obj/Him.as:1074
	_eq("last spurts' share", Him.EJACULATION["terminal"], [0.5, 0.5])   # src: obj/Him.as:1070

	him.pleasure = 0.0
	him.buildUp = 0.0
	him.givePleasure(300.0)
	_eq("givePleasure: 1% of the movement", him.pleasure, 3)   # src: obj/Him.as:715-716
	him.givePleasure(-200.0)
	_eq("givePleasure: either direction", him.pleasure, 5)   # src: obj/Him.as:715
	_eq("givePleasure: build-up too", him.buildUp, 5)   # src: obj/Him.as:717
	him.pleasure = 145.0
	him.givePleasure(500.0)
	_eq("givePleasure: capped 6 over the finish", him.pleasure, 146)   # src: obj/Him.as:716

	# Him.move: the pleasure rules (no finish yet, he is not ejaculating)
	g.autoModeOn = false
	him.pleasure = 100.0
	him.maxPleasureTimer = 5
	him.move(0.0, g.currentPos.x, g.currentPos.y)
	_eq("pleasure fades 0.05 per tick", him.pleasure, 99.95)   # src: obj/Him.as:840
	_eq("below the finish: timer reset", him.maxPleasureTimer, 0)   # src: obj/Him.as:842
	var ac: AutomaticControl = g.automaticControl
	g.autoModeOn = true
	ac.randomMode = ac.softAuto
	him.pleasure = 100.0
	him.move(0.0, g.currentPos.x, g.currentPos.y)
	_eq("soft auto: pleasure fades 0.03 per tick", him.pleasure, 99.97)   # src: obj/Him.as:834-836, obj/AutomaticControl.as:234
	ac.randomMode = ac.standardAuto
	him.pleasure = 100.0
	him.move(0.0, g.currentPos.x, g.currentPos.y)
	_eq("normal auto: pleasure fades 0.05 per tick", him.pleasure, 99.95)   # src: obj/Him.as:840, obj/AutomaticControl.as:234
	g.autoModeOn = false
	him.pleasure = 140.0
	him.maxPleasureTimer = 0
	him.move(0.0, g.currentPos.x, g.currentPos.y)
	_eq("at the finish: timer counts", him.maxPleasureTimer, 1)   # src: obj/Him.as:826
	_eq("at the finish: pleasure -0.1 per tick", him.pleasure, 139.9)   # src: obj/Him.as:827
	var finishes: int = g.totalFinishes
	him.pleasure = 140.0
	him.buildUp = 200.0
	him.maxPleasureTimer = 60
	him.move(0.0, g.currentPos.x, g.currentPos.y)
	_eq("finishes after 60 ticks at the top", g.totalFinishes, finishes + 1)   # src: obj/Him.as:816-818, obj/Him.as:1059
	_true("finishing", him.isEjaculating())   # src: obj/Him.as:1086
	_eq("finishing: pleasure back to 0", him.pleasure, 0)   # src: obj/Him.as:819
	_eq("finishing: build-up back to 0", him.buildUp, 0)   # src: obj/Him.as:820
