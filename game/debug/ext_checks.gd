extends RefCounted
## Checks of the extension system (src/ext): hooks, extension lifecycle, tick order, settings, Vanilla mode.
## Run by tools/regress.sh (main.gd --driver); prints "EXT CHECKS: n passed, m failed" and quits.

var _pass := 0
var _fail := 0
var _phase := 0
var _start_tick := 0
var _order: Array = []
var _ext: TestExt = null
var _listener_obj: FlashSprite = null


## A class with one hooked method, written like a hook point in game code.
class Probe:
	extends RefCounted
	var calls := 0

	func calc(x: int) -> int:
		if Hooks.has(&"Probe.calc"):   # HOOK
			var h := Hooks.before(&"Probe.calc", self, [x])
			if h.cancelled:
				return h.result
			x = h.args[0]
		calls += 1
		var r := x * 2
		if Hooks.has(&"Probe.calc"):   # HOOK
			r = Hooks.after(&"Probe.calc", self, [x], r).result
		return r


class TestExt:
	extends SDTExtension
	var ticks := 0
	var late_ticks := 0
	var enabled_calls := 0
	var disabled_calls := 0
	var changed: Array = []
	var order: Array = []
	var slow := false
	var value = "abc"
	var late_value := ""
	var loads: Array = []   # [value, kind] per setter / reset call
	var mods_events := 0
	var moods_seen: Array = []

	func _init() -> void:
		id = "test"
		title = "Test"

	func _setup() -> void:
		setting("flag", false, {"label": "Flag"})
		setting("amount", 0.5, {"min": 0.0, "max": 1.0})
		setting("count", 3, {"min": 1, "max": 10})
		setting("mode", "a", {"options": ["a", "b"]})

	func _enable() -> void:
		enabled_calls += 1
		on_late_tick(_late)
		on_tick(_early)
		hook_before(&"Probe.calc", func(c): c.args[0] += 100)
		charcode_field("testField", func(): return value,
			func(v, l): value = v; loads.append([v, l.kind]),
			func(l): value = "default"; loads.append(["reset", l.kind]))
		charcode_field("testLate", func(): return late_value if late_value != "" else null,
			func(v, _l): late_value = v, Callable(), true)
		on_event("mods_loaded", func(): mods_events += 1)
		on_event("mood_changed", func(m): moods_seen.append(m))

	func _disable() -> void:
		disabled_calls += 1

	func _setting_changed(key: String, value) -> void:
		changed.append([key, value])

	func _early() -> void:
		ticks += 1
		order.append("early")
		if slow:
			OS.delay_usec(3000)

	func _late() -> void:
		late_ticks += 1
		order.append("late")


func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("CHECK %s %s%s" % ["ok  " if ok else "FAIL", name, "" if ok or detail == "" else " (%s)" % detail])


func step(_frame: int) -> void:
	if not Extensions.started:
		return
	match _phase:
		0:
			_hook_checks()
			_value_checks()
			_lifecycle_start()
			_ext.modify(&"T.ext", {"op": "set", "value": 1.0})
			_phase = 1
		1:
			if Flash.tick_count >= _start_tick + 5:
				_tick_checks()
				_phase = 2
		2:
			_ext.slow = true
			_start_tick = Flash.tick_count
			_phase = 3
		3:
			if Flash.tick_count > _start_tick:
				_check("profiler names the extension", Flash._slowest_listener.begins_with("ext:test."), Flash._slowest_listener)
				_check("value modifier lifetime ends after its ms", not Hooks.has_value(&"T.t")
					and Hooks.value(&"T.t", null, 7.0) == 7.0)
				_ext.slow = false
				_veto_checks()
				_settings_checks()
				_poll_veto_checks()
				_charcode_checks()
				_mood_checks()
				_blink_veto_checks()
				_template_checks()
				_extramod_checks()
				_shock_spray_veto_checks()
				_extramodhim_checks()
				_leglayer_checks()
				_aimpenis_checks()
				_regulaterandom_checks()
				_morespitstrands_checks()
				_morecumspurts_checks()
				_lipstickringsmear_checks()
				_strandlimit_checks()
				_swallow_veto_checks()
				_rings_checks()
				_entrance_checks()
				_collar_checks()
				_swallowing_checks()
				_swallow_points_checks()
				_swallow_queue_checks()
				_penisrange_checks()
				_tongueguard_checks()
				_disable_checks()
				_plugin_checks()
				print("EXT CHECKS: %d passed, %d failed" % [_pass, _fail])
				Flash.get_tree().quit(1 if _fail > 0 else 0)
				_phase = 4


## Her.swallow: a vetoed swallow restarts the wait with cum in her mouth (it would be retried every tick) and
## changes nothing else; a handler can change the arguments.
func _swallow_veto_checks() -> void:
	var her = g.her
	var calls := [0]
	var veto := func(c): calls[0] += 1; c.cancel()
	Hooks.add_before(&"Her.swallow", veto, "test")
	her.swallowing = false
	her.startSwallowTimer = 999
	var cough: float = her.coughBuild
	var wet: float = her.wetGenerate
	her.swallow()
	_check("vetoed swallow: no swallow", calls[0] == 1 and not her.swallowing)
	_check("vetoed swallow: the wait starts over", her.startSwallowTimer == 0)
	_check("vetoed swallow: cough and wetness untouched", her.coughBuild == cough and her.wetGenerate == wet)
	Hooks.remove(&"Her.swallow", veto)
	var change := func(c): c.args[0] = 0.9
	Hooks.add_before(&"Her.swallow", change, "test")
	var free: bool = not her.passedOut and not her.speaking
	her.swallow()
	_check("swallow: a handler can change the intensity", not free or (her.swallowing
		and is_equal_approx(float(her.swallowSequence["intensity"]), 0.9)), str(her.swallowSequence.get("intensity")))
	Hooks.remove(&"Her.swallow", change)


## TemplateExtension: the alternate loader template's mod types, its over-top layer and extra hair layer.
func _template_checks() -> void:
	var te: SDTExtension = Extensions.get_extension("templateextension")
	_check("TemplateExtension on by default", te != null and te.enabled)
	if te == null or not te.enabled:
		return
	var helpers: Dictionary = g.customElementLoader.modTargetHelpers
	var missing: Array = []
	for t in te.TYPES:
		if not helpers.has(t) or not te.TYPES[t].keys().all(func(p): return helpers[t].targetDictionary.has(p)):
			missing.append(t)
	_check("mod types registered with all their parts", missing.is_empty(), str(missing))
	var lb: Dictionary = helpers["CostumeLegwearB"].targetDictionary if helpers.has("CostumeLegwearB") else {}
	_check("legwear B takes the legwear A part names too", lb.get("backside") != null
		and lb.get("backside") == lb.get("backsideB") and lb.get("chestOver") == lb.get("chestOverB"))
	_check("over-top layer: 8 parts above the top's", te._layers.size() == 8 and helpers.has("CostumeOverTop")
		and te._layers.values().all(func(l): return l._flash_parent != null))
	_check("misspelt CostumeOvertop is read as CostumeOverTop",
		CustomElementLoader.normalModType("CostumeOvertop") == "CostumeOverTop"
		and CustomElementLoader.normalModType("CostumeTop") == "CostumeTop")
	_check("over-top breast moves with her breast", g.her.rightBreastController._costumeLayers.has(te._layers["rightBreast"]))
	var hl: FlashSprite = te.hair_over_extended
	_check("extra hair layer under his arm", hl != null and hl._flash_parent == g.frontLayer
		and g.frontLayer.getChildIndex(hl) < g.frontLayer.getChildIndex(g.himOverLayer))
	g.characterControl.applyHairHSL({"h": 30, "s": 0, "l": 0, "c": 0})
	_check("extra hair layer takes the hair colour", hl.filters.size() == g.hairBetweenLayer.filters.size()
		and hl.filters.size() > 0)
	g.characterControl.removeHairHSL()
	Extensions.set_enabled("templateextension", false)
	var layers_left: bool = g.her.rightBreastController._costumeLayers.any(func(l): return l.flash_name.ends_with("OverTop"))
	_check("TemplateExtension off: types and layers gone", not helpers.has("CostumeArmwear") and not helpers.has("CostumeBra")
		and hl._flash_parent == null and not layers_left)
	Extensions.set_enabled("templateextension", true)
	_check("TemplateExtension on again", helpers.has("CostumeArmwear") and te._layers.size() == 8)


## ExtraMod (stage 1: her head and eyes): types, containers next to her parts, a clear that changes nothing.
func _extramod_checks() -> void:
	var em: SDTExtension = Extensions.get_extension("extramod")
	_check("ExtraMod on by default", em != null and em.enabled)
	if em == null or not em.enabled:
		return
	var helpers: Dictionary = g.customElementLoader.modTargetHelpers
	_check("ExtraMod head and eye types", helpers.has("BodyHead") and helpers.has("BodyEye")
		and helpers["BodyHead"].targetDictionary.size() == em.HEAD_PARTS.size()
		and helpers["BodyEye"].targetDictionary.size() == em.EYE_PARTS.size(),
		"%d %d" % [helpers["BodyHead"].targetDictionary.size(), helpers["BodyEye"].targetDictionary.size()])
	var her = g.her
	_check("ExtraMod containers beside her parts", em.c.size() == em.CONTAINERS.size()
		and em.c["uppereyelid"]._flash_parent == her.eye.upperEyelid._flash_parent
		and em.c["uppereyelidmask"].blendMode == "erase")
	var skull_vis: bool = her.head.face.skull.getChildAt(0).visible
	g.customElementLoader.clearInstancedMods()
	_check("ExtraMod: clearing without its mods changes nothing", her.head.face.skull.getChildAt(0).visible == skull_vis
		and her.eye.ball.upperEyelidMask.visible)
	var cat = g.modCatalog
	_check("ExtraMod's list of mods in the catalog", cat.picker_entries.has("extramod")
		and cat.picker_types.get("BodyHead") == "extramod")
	Extensions.set_enabled("extramod", false)
	_check("ExtraMod off: types, containers and list gone", not helpers.has("BodyHead") and em.c.is_empty()
		and not cat.picker_entries.has("extramod"))
	Extensions.set_enabled("extramod", true)
	_check("ExtraMod on again", helpers.has("BodyEye") and em.c.size() == em.CONTAINERS.size()
		and cat.picker_entries.has("extramod"))
	# overlays, dialogue boxes, her penis, piercings
	_check("ExtraMod overlay, dialogue box, futa and piercing types", helpers.has("Overlay") and helpers.has("DialogueBox")
		and helpers.has("CostumeBrowPiercing") and helpers.has("CostumeNosePiercing")
		and helpers["Overlay"].targetDictionary.size() == 6
		and helpers["Futa"].targetDictionary["target"] == her.torso.penisContainer
		and cat.picker_types.get("Futa") == "extramod_futa" and cat.picker_types.get("Overlay") == "extramod_overlays")
	var dc = g.dialogueControl
	var field = dc.tfContainer.dialogueField
	var box = dc.getChildAt(0)
	var color0: int = field.textColor
	var cel = g.customElementLoader
	var pkg := LoadedModPackage.new("swfMod")
	pkg.setFilePath("test/em_stage3.swf|0")
	cel.loadedModPackages.append(pkg)
	cel.loadingModPackage = pkg
	var dbox := FlashMovieClip.new()
	dbox.set("modType", "DialogueBox")
	dbox.set("newColor", "ff0000")
	cel.parseMod(dbox)
	var futa := FlashMovieClip.new()
	futa.set("modType", "Futa")
	cel.parseMod(futa)
	cel.loadingModPackage = null
	_check("ExtraMod dialogue box mod: behind the text, the game's box hidden, red text",
		dbox._flash_parent == dc and dc.getChildIndex(dbox) == 0 and not box.visible and field.textColor == 0xff0000,
		"%s %s %x" % [dc.getChildIndex(dbox), box.visible, field.textColor])
	_check("ExtraMod futa mod: in her penis container, hidden without her penis",
		futa._flash_parent == her.torso.penisContainer and futa.visible == (her._penisControl.currentPenisID != 0))
	cel.clearInstancedMods()
	_check("ExtraMod cleared: the game's dialogue box and text colour back", box.visible and field.textColor == color0)


## ExtraModHim (his body and penis so far): types registered, follow his body change, off removes them.
func _extramodhim_checks() -> void:
	var emh: SDTExtension = Extensions.get_extension("extramodhim")
	_check("ExtraModHim on by default", emh != null and emh.enabled)
	if emh == null or not emh.enabled:
		return
	var helpers: Dictionary = g.customElementLoader.modTargetHelpers
	# his breast containers exist on his futa body only
	var expected: int = emh.BODY_PARTS.size() - (emh.BREASTS.size() if g.him.currentBodyID == 0 else 0)
	_check("ExtraModHim body and penis types", helpers.has("HimBody") and helpers.has("HimPenis")
		and helpers["HimBody"].targetDictionary.size() == expected, str(helpers["HimBody"].targetDictionary.size()))
	var body: int = g.him.currentBodyID
	g.him.setBody(1 - body)
	_check("ExtraModHim targets follow his body change", helpers["HimBody"].targetDictionary["hisTorso"] == g.him.torsoLayer.torso)
	g.him.setBody(body)
	Extensions.set_enabled("extramodhim", false)
	_check("ExtraModHim off: types gone", not helpers.has("HimBody"))
	Extensions.set_enabled("extramodhim", true)
	_check("ExtraModHim on again", helpers.has("HimBody"))


## regulaterandom: its defaults are the game's shuffle; with every part off a shuffle changes nothing (also not
## moremoods' mood).
func _regulaterandom_checks() -> void:
	var rr: SDTExtension = Extensions.get_extension("regulaterandom")
	var seen := []
	var spy := func(c): seen.append([c.args[0].duplicate(), c.args[1].duplicate()])
	Hooks.add_after(&"InGameMenu.shuffle", spy, "test")
	g.inGameMenu.shuffle()
	var defaults_ok: bool = seen.size() == 1 and seen[0][0] == InGameMenu.SHUFFLE_PARTS and seen[0][1].keys().all(
		func(k): return seen[0][1][k] == InGameMenu.SHUFFLE_ALPHA.get(k, false))
	for p in rr.PARTS:
		rr.set_setting(p[0], false)
	var mood: String = g.her.currentMood
	var before: String = g.inGameMenu.getSaveDataString()
	g.inGameMenu.shuffle()
	var after: String = g.inGameMenu.getSaveDataString()
	var mood_after: String = g.her.currentMood
	for p in rr.PARTS:
		rr.set_setting(p[0], InGameMenu.SHUFFLE_PARTS.get(p[0], false))
	Hooks.remove(&"InGameMenu.shuffle", spy)
	_check("regulaterandom defaults: the game's shuffle", defaults_ok, str(seen[0]) if not seen.is_empty() else "")
	_check("regulaterandom all off: shuffle changes nothing", before == after and mood == mood_after,
		"" if before == after else "%s\n%s" % [before, after])


## morespitstrands: off by default; on, her lips leaving him make up to the set number of strands; at the strand
## limit the oldest one makes room (StrandControl.killOldestSpit, native or not).
func _morespitstrands_checks() -> void:
	var ms: SDTExtension = Extensions.get_extension("morespitstrands")
	var her: Her = g.her
	var sc = g.strandControl
	_check("morespitstrands: off by default", not ms.get_setting("pulled_off") and not ms.get_setting("pulling_up"))
	var spit_before: bool = g.spit
	g.spit = true
	sc.clearSpitStrands()
	ms.set_setting("pulled_off", true)
	ms.set_setting("pulled_off_max", 5)
	seed(3)
	var made: int = ms.made
	her.mouthFull = true
	ms._tick()
	her.mouthFull = false
	ms._tick()
	var pulled: int = ms.made - made
	ms._tick()
	_check("morespitstrands: strands when she pulls off (once)", pulled >= 1 and pulled <= 5 and ms.made - made == pulled,
		str(ms.made - made))
	var guard := 0
	while not sc.maxPop() and guard < 100:
		her.generateRandomStrand("random", true)
		guard += 1
	var full: int = sc.strand_count(false)
	ms._strand()
	var after_new: int = sc.strand_count(false)
	sc.killOldestSpit()
	_check("morespitstrands: at the limit the oldest makes room", full == sc.maxStrands and after_new == full
		and sc.strand_count(false) == full - 1, "%d %d %d" % [full, after_new, sc.strand_count(false)])
	ms.set_setting("pulled_off", false)
	ms.set_setting("pulled_off_max", 1)
	sc.clearSpitStrands()
	g.spit = spit_before


## lipstickringsmear: off by default; multiplyAlpha scales alpha inside its rectangle only (8.8 fixed point); the ring
## puts lipstick on him while she holds still; the fade takes one alpha step; her lipstick wears off, then smears stop,
## and setting her lipstick (or switching wear-off off) brings it back.
func _lipstickringsmear_checks() -> void:
	var ls: SDTExtension = Extensions.get_extension("lipstickringsmear")
	var her: Her = g.her
	var him: Him = g.him
	var cc = g.characterControl
	_check("lipstickringsmear: off by default", not ls.get_setting("ring") and not ls.get_setting("mouth_push")
		and not ls.get_setting("hand_push") and not ls.get_setting("fade") and not ls.get_setting("wear_off"))
	var lip_before = cc.lipstickRGB
	var data: FlashBitmapData = him.lipstickData
	him.clearLipstick()
	data.fillRect(Rect2i(10, 10, 20, 20), 0xC8FF0000)
	data.multiplyAlpha(Rect2i(10, 10, 10, 20), 0.95)
	_check("lipstickringsmear: multiplyAlpha in its rectangle", data.getPixel32(12, 12) >> 24 == 189
		and data.getPixel32(25, 12) >> 24 == 200, "%x %x" % [data.getPixel32(12, 12), data.getPixel32(25, 12)])
	ls.set_setting("fade", true)
	ls._fade_counter = 0
	ls._tick()
	ls._tick()
	_check("lipstickringsmear: fade takes one alpha step", data.getPixel32(25, 12) >> 24 == 199, "%x" % data.getPixel32(25, 12))
	ls.set_setting("fade", false)
	him.clearLipstick()
	cc.setLipstick(AlphaRGBObject.new(1.0, 200, 0, 0))
	ls.set_setting("ring", true)
	var full_before := her.mouthFull
	her.mouthFull = true
	her.absMovement = 0.0
	her.pos = 0.6
	for i in 30:
		ls._tick()
	_check("lipstickringsmear: ring while she holds still", data.image.get_used_rect().has_area(), str(data.image.get_used_rect()))
	ls.set_setting("ring", false)
	her.mouthFull = full_before
	ls.set_setting("wear_off", true)
	him.smearLipstick(0.5, 30000.0)
	var worn: float = her.bottomLipstick.alpha
	var counter: int = him.lipstickCounter
	him.smearLipstick(0.5, 10.0)
	_check("lipstickringsmear: her lipstick wears off, then no more smears", worn == 0.0
		and her.topLipstickContainer.topLipstick.alpha == 0.0 and him.lipstickCounter == counter, "%s %d %d" % [worn, counter, him.lipstickCounter])
	cc.setLipstick(AlphaRGBObject.new(1.0, 200, 0, 0))
	var back: float = her.bottomLipstick.alpha
	him.smearLipstick(0.5, 30000.0)
	ls.set_setting("wear_off", false)
	var restored: float = her.bottomLipstick.alpha
	cc.setLipstick(AlphaRGBObject.new(0.0, 200, 0, 0))
	_check("lipstickringsmear: lipstick back when set again or wear-off is off, at its colour's alpha", back == 1.0
		and restored == 1.0 and her.bottomLipstick.alpha == 0.0, "%s %s %s" % [back, restored, her.bottomLipstick.alpha])
	cc.setLipstick(lip_before)
	him.clearLipstick()


## strandlimit: off by default (strands untouched); over the limit the oldest cum strands age, the oldest most, the
## ones within the limit not at all; faint strands age, the others not.
func _strandlimit_checks() -> void:
	var sl: SDTExtension = Extensions.get_extension("strandlimit")
	var sc = g.strandControl
	_check("strandlimit: off by default", not sl.get_setting("limit_cum") and not sl.get_setting("limit_spit")
		and not sl.get_setting("faint"))
	sc.clearCumStrands()
	for i in 8:
		sc.newCumStrand(Vector2(300 + i * 5, 200), g.sceneLayer)
	var before: PackedFloat32Array = sc.strand_alphas(true)
	sl._counter = 0
	for i in 6:
		sl._tick()
	_check("strandlimit: off, strands untouched", sc.strand_alphas(true) == before, "%s %s" % [before, sc.strand_alphas(true)])
	sc.add_strand_ages(true, PackedInt32Array([1900, 1900, 1900, 1900, 1900, 1900, 1900, 1900]))
	before = sc.strand_alphas(true)
	sl.set_setting("limit_cum", true)
	sl.set_setting("max_cum", 5)
	sl._counter = 0
	for i in 6:
		sl._tick()
	var after: PackedFloat32Array = sc.strand_alphas(true)
	_check("strandlimit: the oldest over the limit fade faster", after.size() == 8 and before[0] - after[0] > before[2] - after[2]
		and after[2] < before[2] and after[3] == before[3] and after[7] == before[7], "%s -> %s" % [before, after])
	sl.set_setting("limit_cum", false)
	sl.set_setting("max_cum", 40)
	sc.add_strand_ages(true, PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 400]))
	before = sc.strand_alphas(true)
	sl.set_setting("faint", true)
	sl._counter = 0
	for i in 6:
		sl._tick()
	after = sc.strand_alphas(true)
	_check("strandlimit: faint strands fade quickly", before[7] < 0.25 and before[3] >= 0.25 and after[7] < before[7]
		and after[3] == before[3], "%s -> %s" % [before, after])
	sl.set_setting("faint", false)
	sc.clearCumStrands()
	var spit_before: bool = g.spit
	g.spit = true
	sc.clearSpitStrands()
	for i in 8:
		g.her.generateRandomStrand("random", true)
	var n: int = sc.strand_count(false)
	sc.add_strand_ages(false, PackedInt32Array([200, 200, 200, 200, 200, 200, 200, 200]))
	before = sc.strand_alphas(false)
	sl.set_setting("limit_spit", true)
	sl.set_setting("max_spit", 5)
	sl._counter = 0
	for i in 6:
		sl._tick()
	after = sc.strand_alphas(false)
	_check("strandlimit: the oldest spit strands over the limit fade faster", n == 8 and after.size() == 8
		and after[0] < before[0] and after[5] == before[5] and sc.strand_alphas(true).is_empty(), "%d %s -> %s" % [n, before, after])
	sl.set_setting("limit_spit", false)
	sl.set_setting("max_spit", 20)
	sc.clearSpitStrands()
	g.spit = spit_before


## morecumspurts: its defaults give the game's spurts; the amount scales the load, no pauses with pause 0; edging:
## near orgasm then calm = one edge (capped), the next orgasm takes the boost, which is spent once he cums; his balls
## grow on top of his ball size and are back at it when switched off; cum strand thickness reaches the strands.
func _morecumspurts_checks() -> void:
	var mc: SDTExtension = Extensions.get_extension("morecumspurts")
	var him: Him = g.him
	var spurts := func(amount: float, pause: float) -> Array:
		mc.set_setting("amount", amount)
		mc.set_setting("pause", pause)
		seed(5)
		him.ejaculating = false
		him.ejaculate()
		var e: Array = him.ejaculation.duplicate(true)
		him.ejaculating = false
		him.ejaculation = []
		return e
	var game: Array = []
	Hooks.add_before(&"Him.ejaculate", func(c): game.append(c.args[0].duplicate(true)), "test")
	var base: Array = spurts.call(1.0, 1.0)
	Hooks.remove_owner("test")
	var total := func(e: Array) -> int: return e.reduce(func(a, s): return a + int(s["spurtTimerStart"]), 0)
	var triple: Array = spurts.call(3.0, 1.0)
	var no_pause: Array = spurts.call(1.0, 0.0)
	_check("morecumspurts defaults: the game's numbers", not game.is_empty() and game[0] == Him.EJACULATION, str(game))
	var r: float = float(total.call(triple)) / total.call(base)
	_check("morecumspurts: amount 3 triples the load", r > 2.5 and r < 4.0, str(r))   # (the last spurt overshoots)
	_check("morecumspurts: no pauses with pause 0", no_pause.size() > 1 and no_pause.all(func(s): return s["pauseTimer"] == 0))
	mc.set_setting("amount", 1.0)
	mc.set_setting("pause", 1.0)

	mc.set_setting("edging", true)
	var pleasure := him.pleasure
	for i in 30:   # 30 edges, capped at 3
		him.pleasure = him.ejacPleasure * 0.9
		mc._tick()
		him.pleasure = him.ejacPleasure * 0.5
		mc._tick()
	var capped: bool = is_equal_approx(mc.edge, 3.0) and is_equal_approx(mc.ball_growth, 1.5)
	for i in 400:
		mc._tick()
	var grown: float = him.balls.scaleX / him.currentBallSize
	var amount := []
	Hooks.add_before(&"Him.ejaculate", func(c): amount.append([c.args[0]["amount"], c.args[0]["build_up"]]), "test", 10)
	seed(5)
	him.ejaculating = false
	him.ejaculate()
	Hooks.remove_owner("test")
	mc._tick()   # he cums: the edging is spent
	_check("morecumspurts edging: capped, the next orgasm takes it, spent once he cums", capped
		and amount == [[3.0, false]] and mc.edge == 1.0 and mc.ball_growth == 1.0, "%s %s %s" % [mc.edge, amount, capped])
	him.ejaculating = false
	him.ejaculation = []
	him.pleasure = pleasure
	_check("morecumspurts: his balls grow on top of his size", grown > 1.05, str(grown))
	mc.set_setting("edging", false)
	_check("morecumspurts: balls back at his size when edging is off", is_equal_approx(him.balls.scaleX, him.currentBallSize),
		"%s %s" % [him.balls.scaleX, him.currentBallSize])
	mc.set_setting("thickness", 2.5)
	var thick: float = g.strandControl.cumMinThickness
	mc.set_setting("thickness", 1.0)
	_check("morecumspurts: cum strand thickness", thick == 2.5 and g.strandControl.cumMinThickness == 1.0)
	mc.set_setting("amount", 2.0)
	MenuSchema.setting_control(mc, "amount")["reset"].call()
	_check("setting slider: back to the default", mc.get_setting("amount") == 1.0, str(mc.get_setting("amount")))


## aimpenis: the aim goes into his tilt target and the wider limits into his angle, only while it is on and he is out
## of her mouth.
func _aimpenis_checks() -> void:
	var ap: SDTExtension = Extensions.get_extension("aimpenis")
	var him = g.him
	var was := [him.inMouth, him.penisTilt, g.currentPos.y, g.bukkakeMode]
	him.inMouth = false
	him.penisTilt = 60.0
	g.currentPos.y = -1.0
	g.bukkakeMode = false
	var off := [Hooks.value(&"Him.penisTiltTarget", him, 10.0), Hooks.value(&"Him.penisAngle", him, 25.0)]
	ap.set_setting("on", true)
	var up := [Hooks.value(&"Him.penisTiltTarget", him, 10.0), Hooks.value(&"Him.penisAngle", him, 25.0)]
	him.inMouth = true
	var mouth := [Hooks.value(&"Him.penisTiltTarget", him, 10.0), Hooks.value(&"Him.penisAngle", him, 25.0)]
	Extensions.key_pressed(77)
	var key_off: bool = not ap.get_setting("on")
	Extensions.key_pressed(77)
	var key_on: bool = ap.get_setting("on")
	ap.set_setting("on", false)
	him.inMouth = was[0]
	him.penisTilt = was[1]
	g.currentPos.y = was[2]
	g.bukkakeMode = was[3]
	_check("aimpenis off: the game's tilt", off == [10.0, 25.0], str(off))
	_check("aimpenis on, mouse up: aims up, up to 35", up[0] > 40.0 and up[1] == 35.0, str(up))
	_check("aimpenis in her mouth: the game's tilt", mouth == [10.0, 25.0], str(mouth))
	_check("aimpenis: M switches it off and on", key_off and key_on)


# ---------------------------------------------------------------- throat rings

## The value points `owner` has modifiers on.
func _owned(owner: String) -> Array:
	return Hooks._modifiers.values().filter(func(m): return m.owner == owner).map(func(m): return m.name)


## The rings are worked out once per game tick; these checks run several in one tick.
func _ring_tick(her) -> void:
	ThroatRings._tick_done = -1
	ThroatRings.tick(her)


## The ring model: the entrance on the game's resistance zone, the collar ring where the collar's picture covers her
## neck, one stiffness for every collar (its profiles and tags), and rings that stretch, wear down and recover.
func _rings_checks() -> void:
	var her = g.her
	var n = her.head.neck
	var cc = g.characterControl.collarControl
	var was: int = cc.selection
	cc.select(0)
	_ring_tick(her)
	_check("rings: no collar, no collar ring", not ThroatRings.collar["on"] and ThroatRings.entrance["on"])
	_check("rings: the entrance on the game's resistance zone", is_equal_approx(ThroatRings.entrance["top"], 75.0 / 400.0)
		and is_equal_approx(ThroatRings.entrance["bottom"], 150.0 / 400.0))
	var c: Dictionary = ThroatRings.collar
	var fits := {}
	for i in [1, 2, 3]:
		cc.select(i)
		_ring_tick(her)
		fits[ThroatRings.collar_name] = [c["on"], c["top"], c["bottom"]]
	# the edges seen in the game: front of her throat, below the top of the picture's bounds (at her nape)
	var lb: Array = fits.get("Leather", [false, 0, 0])
	_check("rings: the leather collar's band where it covers her throat", lb[0] and lb[1] > 0.53 and lb[1] < 0.57
		and lb[2] > 0.72 and lb[2] < 0.77, str(fits))
	var tie: Array = fits.get("Tie", [false, 0, 0])
	_check("rings: the tie - only its band, not the hanging tie", tie[0] and tie[2] - tie[1] < 0.2, str(tie))
	_check("rings: each collar its own band", fits.size() == 3 and fits.values().all(func(f): return f[0] and f[2] > f[1]))
	ThroatRings.set_stiffness(1.0)
	_check("rings: one stiffness for every collar, kept in port.cfg", c["stiff"] == 1.0
		and PortSettings.get_value(ThroatRings.SECTION, "stiffness") == 1.0)
	_check("rings: profiles by name", ThroatRings.apply_profile("Band") and ThroatRings.stiffness == 0.2
		and not ThroatRings.apply_profile("nope"))
	ThroatRings.set_stiffness(0.6)
	var game := [g.throatResistance, her.pos, n.throatBulgeAmount, her.collarContainer.collar.scaleX, n.swallowScale]
	var r := ThroatRings._ring("test", 0.2, 0.3, 0.8, 0.0, 5.0)
	ThroatRings.tip = 0.5
	ThroatRings.push = 1.0
	ThroatRings._step(r, 1.0, n)
	var hold0: float = r["hold"]
	for i in 30:
		ThroatRings._step(r, 1.0, n)
	_check("rings: pressure stretches a ring and it holds less", r["stretch"] > 0.05 and r["hold"] < hold0 and r["pressure"] >= 1.0)
	_check("rings: pressure wears a ring down until it snaps", r["snapped"] and r["hold"] == 0.0)
	ThroatRings.tip = 0.0
	var st: float = r["stretch"]
	ThroatRings._step(r, 1.0, n)
	_check("rings: at rest a ring recovers", r["stretch"] < st and r["pressure"] == 0.0)
	var m := ThroatRings._ring("metal", 0.2, 0.3, 0.85, 1.0, INF)
	ThroatRings.tip = 0.5
	for i in 30:
		ThroatRings._step(m, 1.0, n)
	_check("rings: a fully stiff ring does not give or break", m["stretch"] == 0.0 and not m["snapped"] and m["hold"] == 0.85)
	ThroatRings.set_stiffness(0.0)
	_check("rings: stiffness 0 holds nothing; collars never break by default", c["tight"] == 0.0 and not is_finite(c["max_durability"]))
	ThroatRings.collar_breaks = true
	ThroatRings._apply_stiffness()
	_check("rings: collars may break, a soft band easily", c["max_durability"] == 60.0)
	ThroatRings.set_stiffness(1.0)
	_check("rings: metal holds fully and never breaks", c["tight"] == 1.0 and not is_finite(c["max_durability"]))
	ThroatRings.collar_tags[ThroatRings.collar_name] = {"profile": "Band"}
	ThroatRings._apply_stiffness()
	_check("rings: a collar's tags may name its profile", c["stiff"] == 0.2)
	ThroatRings.collar_tags[ThroatRings.collar_name] = {"stiffness": 0.4, "can_snap": false}
	ThroatRings._apply_stiffness()
	_check("rings: or set its own stiffness, or never snap", c["stiff"] == 0.4 and not is_finite(c["max_durability"]))
	ThroatRings.collar_tags.clear()
	ThroatRings.collar_breaks = false
	ThroatRings.set_stiffness(0.6)
	_ring_tick(her)
	_check("rings: they change nothing in the game by themselves", game == [g.throatResistance, her.pos, n.throatBulgeAmount,
		her.collarContainer.collar.scaleX, n.swallowScale])
	cc.select(was)
	ThroatRings.reset_stretch()


## throatresiststretch on the entrance ring: a stretched entrance lowers its share of the resistance and keeps the
## neck drawn deep; it tightens back at the set speed; off, nothing is left.
func _entrance_checks() -> void:
	var x = Extensions.get_extension("throatresiststretch")
	var her = g.her
	var e: Dictionary = ThroatRings.entrance
	x.set_setting("on", true)
	var owners: Array = _owned("throatresiststretch")
	_check("throat loosens: acts on resistance and neck depth", owners.has(&"Her.resistance") and owners.has(&"Neck.depth"))
	e["stretch"] = 0.5
	ThroatRings.tip = 0.3
	var upper: float = her.resistance["upper"]
	_check("throat loosens: a stretched entrance lowers its share of the resistance",
		is_equal_approx(Hooks.value(&"Her.resistance", her, upper + 0.05), upper + 0.025))
	ThroatRings.tip = 0.5
	_check("throat loosens: past the entrance the resistance is the game's", Hooks.value(&"Her.resistance", her, 0.0) == 0.0)
	_check("throat loosens: the neck drawn as deep as the stretch", Hooks.value(&"Neck.depth", her.head.neck, 0.1) == 0.5
		and Hooks.value(&"Neck.depth", her.head.neck, 0.7) == 0.7)
	x.set_setting("recover", 0.5)
	ThroatRings.tip = 0.0
	ThroatRings._step(e, 1.0, her.head.neck)
	_check("throat loosens: tightens back at the set speed", is_equal_approx(e["stretch"], 0.5 - ThroatRings.RECOVER_RATE * 0.5 * (1.0 - 0.5 * e["stiff"])))
	x.set_setting("recover", 0.25)
	x.set_setting("on", false)
	_check("throat loosens off: nothing left", _owned("throatresiststretch").is_empty() and e["stretch"] == 0.0)


## chokercollarresistance: a wall across the collar's band (awake and passed out), her head pushed back in it, her neck
## held in by the band (Neck.band) as far as the collar gives, its front a fast spring; breaking; off, nothing left.
func _collar_checks() -> void:
	var x = Extensions.get_extension("chokercollarresistance")
	var her = g.her
	var neck = her.head.neck
	var cc = g.characterControl.collarControl
	var was: int = cc.selection
	var c: Dictionary = ThroatRings.collar
	_check("collar: off by default", x != null and not x.get_setting("on") and _owned("chokercollarresistance").is_empty())
	cc.select(1)
	_ring_tick(her)
	x.set_setting("on", true)
	var pts: Array = _owned("chokercollarresistance")
	_check("collar on: push back, resistance (awake and passed out), the band on her neck", pts.has(&"Her.pushBack")
		and pts.has(&"Her.resistance") and pts.has(&"Her.limpResistance") and pts.has(&"Neck.band"))
	ThroatRings.set_stiffness(0.6)
	ThroatRings.reset_stretch()
	ThroatRings.repair()
	var band: float = c["bottom"] - c["top"]
	ThroatRings.tip = c["top"] + 0.05
	c["hold"] = c["tight"]
	_check("collar: in its band her head is pushed back by what it holds",
		is_equal_approx(Hooks.value(&"Her.pushBack", her, 0.0), 0.05 * 400.0 * 0.0015 * c["tight"]))
	_check("collar: in the band going deeper gets harder, like her throat entrance",
		is_equal_approx(Hooks.value(&"Her.resistance", her, 0.0), 0.3 * c["tight"] * 0.05 / band))
	ThroatRings.tip = c["bottom"] - 0.0001
	_check("collar: at its bottom edge a wall of 0.3 x the stiffness", absf(x.wall() - 0.3 * c["tight"]) < 0.001)
	ThroatRings.set_wall(0.25)
	_check("collar: the wall can be set apart from code", absf(x.wall() - 0.25) < 0.001)
	_check("collar: passed out she is still held", is_equal_approx(Hooks.value(&"Her.limpResistance", her, 0.0), x.wall()))
	ThroatRings.set_stiffness(0.2)
	_check("collar: the stiffness sets the wall again (0.3 x stiffness)", is_equal_approx(ThroatRings.collar_wall, 0.06))
	ThroatRings.set_stiffness(0.6)
	c["hold"] = c["tight"]
	ThroatRings.tip = c["bottom"] + 0.2
	_check("collar: through it only a squeeze, no more push back than the band's", is_equal_approx(x.wall(), 0.03 * c["tight"])
		and is_equal_approx(Hooks.value(&"Her.pushBack", her, 0.0), band * 400.0 * 0.0015 * c["tight"]))
	ThroatRings.tip = c["top"] + 0.05
	var mid: float = (c["top"] + c["bottom"]) / 2.0
	var at := func(f: float) -> float:
		x.refresh_band()
		var b = Hooks.value(&"Neck.band", neck, null)
		return 30.0 if b == null else minf(30.0, Neck.band_limit(b, f, 30.0))
	var give: float = 6.0 * 0.4 / 0.6
	_check("collar: a softer collar gives way at once", is_equal_approx(x.room(), give))
	x.push_px = 0.0
	_check("collar: between its edges her neck pushes out only as far as it gives", is_equal_approx(at.call(mid), 2.0 + 3.0))
	_check("collar: well above and below it her neck is free", at.call(c["top"] - 0.1) == 30.0 and at.call(c["bottom"] + 0.1) == 30.0)
	var s1: float = at.call(c["top"] - 0.02)
	var s2: float = at.call(c["top"] - 0.05)
	_check("collar: past each edge the band blends into the free bulge", s1 > 5.0 and s1 < s2 and s2 < 30.0, "%s %s" % [s1, s2])
	_check("collar: one band value per render; a narrower band wins", Neck.narrower(null, {"inside": 4.0})["inside"] == 4.0
		and Neck.narrower({"inside": 9.0}, {"inside": 4.0})["inside"] == 4.0)
	c["stretch"] = 1.0
	x.push_px = 30.0
	_check("collar: stretched it gives further", is_equal_approx(at.call(mid), 2.0 + give + 70.0 * 0.25))
	x.push_px = 0.0
	x.set_setting("widen", false)
	_check("collar: its picture not widening, the band stays tight", at.call(mid) == 2.0)
	x.set_setting("widen", true)
	ThroatRings.set_stiffness(1.0)
	c["stretch"] = 0.0
	c["hold"] = c["tight"]
	_check("collar: metal does not give", x.room() == 0.0 and at.call(mid) == 2.0)
	ThroatRings.set_stiffness(0.0)
	c["hold"] = c["tight"]
	_check("collar: stiffness 0 holds nothing and rides along", x.rides_free() and at.call(mid) == 30.0
		and x.wall() == 0.0 and Hooks.value(&"Her.pushBack", her, 0.0) == 0.0)
	ThroatRings.set_stiffness(1.0)
	c["hold"] = c["tight"]
	var was_bulge: float = neck.throatBulgeAmount
	neck.throatBulgeAmount = 1.5
	x.refresh_band()
	neck.render(0.95)
	var pr: Array = neck.renderedPoints
	var n: int = neck.frontEndPoint
	var i_mid := int(round(mid * n))
	var i_above := int(floor((c["top"] - 0.1) * n))
	var out_mid: float = (pr[i_mid] - neck.neckPoints[i_mid]).x
	var out_above: float = (pr[i_above] - neck.neckPoints[i_above]).x
	_check("collar drawn: under it her neck stays in, above it bulges", out_mid <= 2.001 and out_above > 5.0, "%s %s" % [out_mid, out_above])
	ThroatRings.set_stiffness(0.6)
	var cont = her.collarContainer
	var col = cont.collar
	var before: Rect2 = col.getBounds(cont)
	x.push_px = 12.0
	x._widen(her)
	var after: Rect2 = col.getBounds(cont)
	_check("collar: her throat pushes its front out by as much, the back stays put", absf((after.end.x - before.end.x) - 12.0) < 0.5
		and absf(after.position.x - before.position.x) < 0.5, "%s -> %s" % [before, after])
	c["stretch"] = 1.0
	x.push_px = 0.0
	x.refresh_band()
	neck.render(0.95)
	var push0: float = x._throat_push(neck, c)
	x.push_speed = 0.0
	x._spring(push0)
	var first: float = x.push_px
	x._spring(push0)
	x._spring(push0)
	var peak := 0.0
	for i in 60:
		x._spring(push0)
		peak = maxf(peak, x.push_px)
	_check("collar: its front a fast spring - part way at first, a little overshoot, settles", push0 > 0.0 and first > 0.0
		and first < push0 and peak > push0 and peak < 1.2 * push0 and absf(x.push_px - push0) < 0.2, "%s %s %s" % [push0, first, peak])
	neck.throatBulgeAmount = was_bulge
	x.push_px = 0.0
	_check("collar can break: off by default", not x.get_setting("breaks") and not is_finite(c["max_durability"]))
	x.set_setting("breaks", true)
	c["snapped"] = true
	ThroatRings.tip = c["top"] + 0.05
	_check("collar: snapped, it holds nothing and rides along", Hooks.value(&"Her.pushBack", her, 0.0) == 0.0
		and at.call(mid) == 30.0 and x.wall() == 0.0 and x.rides_free())
	ThroatRings.repair()
	_check("collar: repaired, it holds again", not c["snapped"] and not x.rides_free())
	x.set_setting("breaks", false)
	x.set_setting("on", false)
	_check("collar off: nothing left, the picture as it was", _owned("chokercollarresistance").is_empty()
		and her.collarContainer.collar.scaleX == 1.0)
	ThroatRings.set_stiffness(0.6)
	ThroatRings.reset_stretch()
	cc.select(was)


## throatcumbulge's swallowing: all off by default; per swallow, until empty (vetoable), while he cums, bulge by amount.
func _swallowing_checks() -> void:
	var x = Extensions.get_extension("throatcumbulge")
	var her = g.her
	var neck = her.head.neck
	var was := [her.cumInMouth, her.swallowing, her.speaking, her.passedOut, her.penisInMouthDist, her.mouthFull, her.held]
	_check("swallowing: all off by default", not x.get_setting("guzzle") and x.get_setting("pump") == "Off"
		and x.get_setting("per_swallow") == 0)
	her.swallowing = false
	her.speaking = false
	her.passedOut = false
	# a swallow's wave starts: the game took 7 of 20; with "per swallow" 3 it takes 3
	x.set_setting("per_swallow", 3)
	x._prev_cum = 20
	x._prev_wave = false
	x._prev_swallowing = false
	her.cumInMouth = 13
	neck.swallowing = true
	x._swallowing(her)
	_check("per swallow: takes what is set", her.cumInMouth == 17 and x.last_amount == 3)
	x.set_setting("per_swallow", 0)
	x._prev_cum = 20
	x._prev_wave = false
	her.cumInMouth = 13
	x._swallowing(her)
	_check("per swallow 0: the game's amount", her.cumInMouth == 13 and x.last_amount == 7)
	neck.swallowing = false
	x.set_setting("guzzle", true)
	x._prev_swallowing = true
	her.swallowing = false
	her.penisInMouthDist = -50.0
	her.cumInMouth = 10
	x._swallowing(her)
	_check("until empty: she swallows again", her.swallowing)
	her.swallowing = false
	x._prev_swallowing = true
	var n := _vetoed(&"Her.swallow", func(): x._swallowing(her))
	_check("until empty: a veto on Her.swallow stops it", n == 1 and not her.swallowing)
	x.set_setting("guzzle", false)
	x._prev_swallowing = true
	x._swallowing(her)
	_check("until empty off: no extra swallow", not her.swallowing)
	her.mouthFull = true
	her.held = false
	her.cumInMouth = 25
	x._on_spurt()
	_check("while he cums Off: nothing", not her.swallowing)
	x.set_setting("pump", "When full")
	x._on_spurt()
	_check("while he cums When full: more than half full", her.swallowing)
	her.swallowing = false
	her.cumInMouth = 10
	x._on_spurt()
	_check("while he cums When full: not at a quarter", not her.swallowing)
	x.set_setting("pump", "Always")
	x._on_spurt()
	_check("while he cums Always: whenever there is cum", her.swallowing)
	her.swallowing = false
	her.held = true
	x._on_spurt()
	_check("while he cums: not held deep (it goes down her throat)", not her.swallowing)
	x.set_setting("pump", "Off")
	x.set_setting("swallow_mode", "By amount")
	neck.swallowing = true
	x.last_amount = 10
	x._swallow_scale(her)
	var big: float = neck.swallowScale.x
	x.last_amount = 5
	x._swallow_scale(her)
	_check("swallow bulge by amount: a bigger swallow, a bigger bulge", big > neck.swallowScale.x and is_equal_approx(big, 0.8 * 0.75 * 4))
	neck.swallowing = false
	x.set_setting("swallow_mode", "The game's")
	x._swallow_scale(her)
	her.cumInMouth = was[0]
	her.swallowing = was[1]
	her.speaking = was[2]
	her.passedOut = was[3]
	her.penisInMouthDist = was[4]
	her.mouthFull = was[5]
	her.held = was[6]
	her.swallowTimer = 0
	x._prev_cum = her.cumInMouth
	x._prev_swallowing = her.swallowing


## Runs `fn` counting the calls of hook `name` (not vetoed); returns the count.
func _counted(name: StringName, fn: Callable) -> int:
	var n := [0]
	var count := func(_c): n[0] += 1
	Hooks.add_before(name, count, "count")
	fn.call()
	Hooks.remove(name, count)
	return n[0]


func _set_test(name: StringName, v) -> int:
	return Hooks.add_modifier(name, {"phase": Hooks.OVERRIDE, "op": "set", "value": v}, "ext_checks")


## The swallow's own points: Her.swallow's after point (did it start), Her.gulp, Her.swallowSpeed, Her.swallowWince.
func _swallow_points_checks() -> void:
	var her = g.her
	var was := [her.cumInMouth, her.swallowing, her.speaking, her.passedOut]
	her.swallowing = false
	her.speaking = false
	her.passedOut = false
	var started := []
	var rec := func(c): started.append(c.result)
	Hooks.add_after(&"Her.swallow", rec, "ext_checks")
	her.swallow(0.8, false)
	her.swallow(0.8, false)
	Hooks.remove(&"Her.swallow", rec)
	_check("Her.swallow after: tells a started swallow from a dropped one", started == [true, false], str(started))
	var base: Dictionary = her.swallowSequence.duplicate()
	her.swallowing = false
	var sp := _set_test(&"Her.swallowSpeed", 2.0)
	her.swallow(0.8, false)
	Hooks.remove_modifier(sp)
	var seq: Dictionary = her.swallowSequence
	_check("Her.swallowSpeed 2: the swallow plays in half the ticks", seq["end"] == Maths.round(base["end"] / 2.0)
		and seq["build"] < seq["swallow"] and seq["swallow"] < seq["relax"] and seq["relax"] < seq["end"], "%s -> %s" % [base, seq])
	her.swallowing = false
	her.swallow(0.8, false)
	_check("Her.swallowSpeed unset: the game's lengths", her.swallowSequence == base)
	her.swallowing = false
	her.swallowTimer = 0
	her.cumInMouth = 20
	var n := _counted(&"Her.gulp", func(): her.gulp())
	_check("Her.gulp: once, takes from her mouth", n == 1 and her.cumInMouth < 20 and her.cumInMouth >= 11)
	her.cumInMouth = 20
	n = _vetoed(&"Her.gulp", func(): her.gulp())
	_check("Her.gulp vetoed: nothing leaves her mouth", n == 1 and her.cumInMouth == 20)
	n = _counted(&"Her.wince", func(): her.gulp())
	_check("Her.gulp: she squints (the game's)", n == 1)
	var nw := _set_test(&"Her.swallowWince", false)
	her.cumInMouth = 20
	n = _counted(&"Her.wince", func(): her.gulp())
	_check("Her.swallowWince false: the gulp without the squint", n == 0 and her.cumInMouth < 20)
	Hooks.remove_modifier(nw)
	her.head.neck.swallowing = false
	her.cumInMouth = was[0]
	her.swallowing = was[1]
	her.speaking = was[2]
	her.passedOut = was[3]
	her.swallowTimer = 0


## throatcumbulge's swallow queue, speed and squint (the game's way by default).
func _swallow_queue_checks() -> void:
	var x = Extensions.get_extension("throatcumbulge")
	var her = g.her
	var was := [her.cumInMouth, her.swallowing, her.speaking, her.passedOut, her.mouthFull, her.held]
	_check("queue, speed, squint: the game's by default", x.get_setting("queue") == 0 and x.get_setting("speed") == 1.0
		and x.get_setting("wince") and not Hooks.has_value(&"Her.swallowSpeed") and not Hooks.has_value(&"Her.swallowWince"))
	her.swallowing = false
	her.speaking = false
	her.passedOut = false
	her.cumInMouth = 30
	her.swallow(0.8, false)
	her.swallow(0.8, false)
	_check("queue 0: a swallow asked for during one is dropped", x.queued == 0)
	x.set_setting("queue", 2)
	for i in 3:
		her.swallow(0.8, false)
	_check("queue 2: keeps two", x.queued == 2, str(x.queued))
	x.set_setting("queue_gap", 3)
	her.swallowing = false
	x._queue(her)
	x._queue(her)
	_check("queue: waits the pause after a swallow ends", not her.swallowing and x.queued == 2)
	x._queue(her)
	_check("queue: then the next swallow", her.swallowing and x.queued == 1)
	her.swallowing = false
	her.cumInMouth = 0
	x._gap = 0
	for i in 3:
		x._queue(her)
	_check("dry swallows on: the series goes on with her mouth empty", her.swallowing and x.queued == 0)
	her.swallowing = false
	x.queued = 2
	x.set_setting("dry", false)
	x._queue(her)
	_check("dry swallows off: an empty mouth ends the series", x.queued == 0 and not her.swallowing)
	x.set_setting("dry", true)
	x.queued = 2
	her.passedOut = true
	x._queue(her)
	_check("queue: passing out clears it", x.queued == 0)
	her.passedOut = false
	x.set_setting("pump", "Always")
	her.swallowing = true
	her.mouthFull = true
	her.held = false
	her.cumInMouth = 10
	x._on_spurt()
	_check("while he cums + queue: the spurt's swallow waits", x.queued == 1)
	x.set_setting("pump", "Off")
	x.set_setting("queue", 0)
	_check("queue 0 again: none wait, no hook on Her.swallow", x.queued == 0 and not Hooks.has(&"Her.swallow"))
	x.set_setting("speed", 2.0)
	x.set_setting("wince", false)
	_check("speed and squint set the value points", Hooks.value(&"Her.swallowSpeed", her, 1.0) == 2.0
		and Hooks.value(&"Her.swallowWince", her, true) == false)
	x.set_setting("speed", 1.0)
	x.set_setting("wince", true)
	_check("speed and squint back: no modifiers", not Hooks.has_value(&"Her.swallowSpeed") and not Hooks.has_value(&"Her.swallowWince"))
	_check("neck follows his size: off by default, the game's limit", not x.get_setting("follow_size")
		and not Hooks.has_value(&"Neck.bulgeCap"))
	var scales := [g.him.penisLengthScale, g.him.penisWidthScale]
	x.set_setting("follow_size", true)
	g.him.loadPenisScales(1.0, 1.2)
	_check("neck follows his size: the bulge limit grows with his width",
		is_equal_approx(Hooks.value(&"Neck.bulgeCap", her.head.neck, 35.0), 35.0 * g.him.getPenisWidthWithTwitch()))
	g.him.loadPenisScales(1.0, 0.8)
	_check("neck follows his size: never below the game's limit", Hooks.value(&"Neck.bulgeCap", her.head.neck, 35.0) == 35.0)
	x.set_setting("follow_size", false)
	g.him.loadPenisScales(scales[0], scales[1])
	_check("neck follows his size off: no modifier", not Hooks.has_value(&"Neck.bulgeCap"))
	her.cumInMouth = was[0]
	her.swallowing = was[1]
	her.speaking = was[2]
	her.passedOut = was[3]
	her.mouthFull = was[4]
	her.held = was[5]
	her.swallowTimer = 0
	x._prev_cum = her.cumInMouth
	x._prev_swallowing = her.swallowing


## penisrange: off by default (the game's limits); on, wider limits, sizes kept as sizes; big sizes move the mask
## and the balls; off again, sizes and limits back inside the game's range.
func _penisrange_checks() -> void:
	var x = Extensions.get_extension("penisrange")
	var him = g.him
	var was := [him.currentPenisLengthScale, him.currentPenisWidthScale, him.currentBallSize]
	_check("penisrange: built in, off by default, the game's limits", x != null and x.enabled and not x.get_setting("on")
		and Him.MIN_PENIS_SIZE == 0.7 and Him.MAX_PENIS_SIZE == 1.2 and Him.MIN_BALL_SIZE == 0.5 and Him.MAX_BALL_SIZE == 1.3)
	var balls := Vector2(him.balls.x, him.balls.y)
	x.set_setting("on", true)
	_check("penisrange on: wider limits", Him.MAX_PENIS_SIZE == 3.0 and is_equal_approx(Him.MIN_PENIS_SIZE, 0.35)
		and is_equal_approx(Him.MAX_BALL_SIZE, 3.25) and is_equal_approx(Him.MIN_BALL_SIZE, 0.25))
	him.setPenisLength(1.0)
	_check("penisrange: the length slider reaches the new largest size", is_equal_approx(him.currentPenisLengthScale, 3.0))
	him.loadPenisScales(2.5, 2.0)
	_check("penisrange: sizes past the game's range load as they are", him.currentPenisLengthScale == 2.5 and him.currentPenisWidthScale == 2.0)
	him.setBallScale(2.0)
	x._tick()
	_check("penisrange: big sizes, the mask follows his length", him.penisMask.scaleX == 2.5)
	_check("penisrange: big balls move down and back", is_equal_approx(him.balls.y, balls.y + 0.7 * 22.0)
		and is_equal_approx(him.balls.x, balls.x + 0.7 * 20.0))
	him.loadPenisScales(1.0, 1.0)
	him.setBallScale(1.0)
	x._tick()
	_check("penisrange: within the game's range, the game's mask and balls", him.penisMask.scaleX == 1.0 and him.balls.y == balls.y)
	him.loadPenisScales(2.5, 2.0)
	x.set_setting("on", false)
	_check("penisrange off: the game's limits, sizes brought back", Him.MAX_PENIS_SIZE == 1.2 and Him.MIN_PENIS_SIZE == 0.7
		and him.currentPenisLengthScale == 1.2 and him.currentPenisWidthScale == 1.2 and him.penisMask.scaleX == 1.0)
	him.loadPenisScales(was[0], was[1])
	him.setBallScale(was[2])


## tongueguard: on by default; her teeth wait (Her.teethClosing) while her tongue is out, at most WAIT ticks; while
## clenched the tongue's update is skipped and it moves in 4 frames a tick to rest; after, hanging out again.
func _tongueguard_checks() -> void:
	var her = g.her
	var t = her.tongue
	var x = Extensions.get_extension("tongueguard")
	var was := [her.clenchTeeth, her.clenchTeethRatio, t.hangingOut, t.tongueOut]
	_check("tongueguard: built in, on by default, holding her teeth through Her.teethClosing", x != null and x.enabled
		and x.get_setting("on") and Hooks.has_value(&"Her.teethClosing"))
	t.gotoAndStop(t.tongueOutEndFrame)
	t.tongueOut = true
	her.clenchTeeth = true
	x._wait = 0
	_check("tongueguard: her teeth wait while her tongue is out", Hooks.value(&"Her.teethClosing", her, true) == false)
	for i in x.WAIT:
		Hooks.value(&"Her.teethClosing", her, true)
	_check("tongueguard: at most WAIT ticks", Hooks.value(&"Her.teethClosing", her, true) == true)
	var c := Hooks.Call.new()
	c.obj = t
	var f0: int = t.currentFrame
	x._on_update(c)
	_check("tongueguard: while clenched her tongue's update is skipped, it moves in 4 frames a tick", c.cancelled and t.currentFrame == f0 - 4)
	for i in 10:
		x._on_update(c)
	_check("tongueguard: and comes to rest inside", t.currentLabel == "InDone" and not t.tongueOut and not t.playingAction)
	t.hangingOut = true
	her.clenchTeeth = false
	her.clenchTeethRatio = 0.0
	var c2 := Hooks.Call.new()
	c2.obj = t
	x._on_update(c2)
	_check("tongueguard: her teeth open while she hangs it out: out again", not c2.cancelled and t.waitingForOut)
	t.waitingForOut = false
	x.set_setting("on", false)
	_check("tongueguard off: no hold on her teeth", not Hooks.has_value(&"Her.teethClosing"))
	var r0: float = 0.4
	her.clenchTeeth = true
	her.clenchTeethRatio = r0
	her.clenchedTeethTimer = 0
	her.clenchedTeethTime = 100
	her.updateLips()
	_check("tongueguard off: her teeth close as in the game", her.clenchTeethRatio > r0)
	x.set_setting("on", true)
	her.clenchTeeth = was[0]
	her.clenchTeethRatio = was[1]
	t.hangingOut = was[2]
	t.gotoAndStop("InDone")
	t.tongueOut = false


## Port fixes from sby's Loader patches (in the game code).
func _leglayer_checks() -> void:
	var leg = g.her.leftLegContainer.leg
	var on: Array = range(leg.numChildren).map(func(i): return str(leg.getChildAt(i).flash_name))
	_check("leglayermove: calf pieces under the thigh", on.find("cuffs") < on.find("thigh") and on.find("leftCalfBottoms") < on.find("thigh")
		and on.find("thigh") < on.find("leftThighCostume"), str(on))
	var fl: FlashSprite = g.frontLayer
	_check("hairlayerpatch: her forearm under the hair", fl.getChildIndex(g.her.rightForeArmContainer) < fl.getChildIndex(g.hairOverContainer))
	g.gamePaused = true
	var breathing: bool = g.her.breathing
	g.gamePaused = false
	_check("pausedbreathpatch: no breathing while paused", not breathing)


func _hook_checks() -> void:
	var p := Probe.new()
	_check("no handler: original runs", p.calc(3) == 6 and not Hooks.has(&"Probe.calc"))
	var f1 := func(c): c.args[0] = c.args[0] + 1
	Hooks.add_before(&"Probe.calc", f1, "t")
	_check("before changes args", p.calc(3) == 8)
	Hooks.add_after(&"Probe.calc", func(c): c.result = c.result + 1000, "t")
	_check("after replaces result", p.calc(3) == 1008)
	var seen: Array = []
	Hooks.add_before(&"Probe.calc", func(_c): seen.append("late"), "t", 5)
	Hooks.add_before(&"Probe.calc", func(_c): seen.append("early"), "t", -5)
	p.calc(1)
	_check("priority order", seen == ["early", "late"], str(seen))
	var calls_before := p.calls
	Hooks.add_before(&"Probe.calc", func(c): c.cancel(-1), "t2", 1)
	_check("cancel skips original and returns result", p.calc(3) == -1 and p.calls == calls_before)
	var hc := Hooks.before(&"Probe.calc", p, [3])
	_check("cancelled_by names the cancelling owner", hc.cancelled and hc.cancelled_by == "t2", hc.cancelled_by)
	Hooks.remove_owner("t2")
	var other := Probe.new()
	Hooks.add_before(&"Probe.calc", func(c): c.cancel(42), "t3", -10, other)
	_check("target filter", p.calc(0) != 42 and other.calc(0) == 42)
	Hooks.remove_owner("t3")
	var inner: Array = []
	Hooks.add_before(&"Probe.calc", func(c): inner.append(c.obj.calc(10)), "t4", 10)
	p.calc(0)
	_check("handler can call the original", inner == [20], str(inner))
	Hooks.remove_owner("t4")
	Hooks.remove_owner("t")
	_check("remove_owner clears the hook", not Hooks.has(&"Probe.calc") and p.calc(3) == 6)


## Value points: phases, folding rules, hold, generator, ordering independent of load order, lifetimes (checked
## a few ticks later), removal with the owner.
func _value_checks() -> void:
	var o := Probe.new()
	_check("value point without modifiers is unchanged", Hooks.value(&"T.v", o, 5.0) == 5.0 and not Hooks.has_value(&"T.v"))
	Hooks.add_modifier(&"T.v", {"phase": Hooks.MOOD, "op": "set", "value": 10.0}, "va")
	Hooks.add_modifier(&"T.v", {"phase": Hooks.MOOD, "op": "bias", "value": 1.0}, "vb")
	_check("set then bias within a phase", Hooks.value(&"T.v", o, 5.0) == 11.0)
	Hooks.add_modifier(&"T.v", {"phase": Hooks.OVERRIDE, "op": "set", "value": 20.0}, "vc")
	_check("a later phase wins", Hooks.value(&"T.v", o, 5.0) == 20.0)
	Hooks.add_modifier(&"T.v", {"phase": Hooks.CLAMP, "op": "clamp", "min": 0.0, "max": 15.0}, "vd")
	Hooks.add_modifier(&"T.v", {"phase": Hooks.CLAMP, "op": "clamp", "min": 3.0, "max": 12.0}, "ve")
	_check("clamps intersect", Hooks.value(&"T.v", o, 5.0) == 12.0)
	var chain := Hooks.explain(&"T.v")
	Hooks.value(&"T.v", o, 5.0)
	_check("explain records the chain", Hooks.explain(&"T.v").size() > 0 and chain is Array)
	Hooks.add_modifier(&"T.g", {"phase": Hooks.GENERATE, "op": "fn", "fn": func(v, _o): return v * 3.0}, "vf")
	Hooks.add_modifier(&"T.g", {"phase": Hooks.MOOD, "op": "bias", "value": 1.0}, "vf")
	_check("generator, then later phases", Hooks.value(&"T.g", o, 2.0) == 7.0)
	var on := [true]
	Hooks.add_modifier(&"T.h", {"phase": Hooks.FINAL, "op": "hold", "when": func(_o): return on[0]}, "vg")
	var h1 = Hooks.value(&"T.h", o, 1.0)
	var h2 = Hooks.value(&"T.h", o, 2.0)
	on[0] = false
	var h3 = Hooks.value(&"T.h", o, 3.0)
	on[0] = true
	var h4 = Hooks.value(&"T.h", o, 4.0)
	_check("hold keeps the captured value while it applies", [h1, h2, h3, h4] == [1.0, 1.0, 3.0, 4.0], str([h1, h2, h3, h4]))
	Hooks.add_modifier(&"T.o1", {"op": "set", "value": 1.0}, "y")
	Hooks.add_modifier(&"T.o1", {"op": "set", "value": 2.0}, "x")
	Hooks.add_modifier(&"T.o2", {"op": "set", "value": 2.0}, "x")
	Hooks.add_modifier(&"T.o2", {"op": "set", "value": 1.0}, "y")
	_check("order does not depend on load order", Hooks.value(&"T.o1", o, 0.0) == Hooks.value(&"T.o2", o, 0.0))
	_check("two owners setting one phase warn once", Hooks._warned.has("T.o1|x|y"))
	Hooks.add_modifier(&"T.vec", {"op": "bias", "value": Vector2(1, 2)}, "vh")
	_check("vector values", Hooks.value(&"T.vec", o, Vector2(10, 10)) == Vector2(11, 12))
	var id := Hooks.add_modifier(&"T.r", {"op": "set", "value": 9.0}, "vi")
	var had := Hooks.has_modifier(id)
	Hooks.remove_modifier(id)
	_check("remove_modifier", had and not Hooks.has_modifier(id) and not Hooks.has_value(&"T.r"))
	Hooks.add_modifier(&"T.u1", {"op": "set", "value": 1.0}, "vu")
	Hooks.add_modifier(&"T.u2", {"op": "set", "value": 2.0}, "vu")
	Hooks.add_modifier(&"T.u2", {"op": "bias", "value": 1.0}, "vv")
	Hooks.remove_modifiers("vu", &"T.u2")
	var one_point: bool = Hooks.has_value(&"T.u1") and Hooks.value(&"T.u2", o, 5.0) == 6.0
	Hooks.remove_modifiers("vu")
	_check("remove_modifiers: one point, then all of an owner's", one_point and not Hooks.has_value(&"T.u1")
		and Hooks.has_value(&"T.u2"))
	Hooks.remove_owner("vv")
	for owner in ["va", "vb", "vc", "vd", "ve", "vf", "vg", "vh", "x", "y"]:
		Hooks.remove_owner(owner)
	var left := Hooks.value_points().filter(func(n): return str(n).begins_with("T."))
	_check("remove_owner removes modifiers", left.is_empty(), str(left))
	Hooks.add_modifier(&"T.t", {"op": "set", "value": 1.0, "ms": 100.0}, "vt")
	_check("timed modifier applies", Hooks.value(&"T.t", o, 7.0) == 1.0)


## Her.shock (startled: eyes wide, maybe a blink) and Her.lastSpurt (cum from her nose when her mouth overflows at
## his last spurt): a veto changes nothing; a handler can change the shock's strength.
func _shock_spray_veto_checks() -> void:
	var her = g.her
	var veto := func(c): c.cancel()
	Hooks.add_before(&"Her.shock", veto, "shock")
	her.eyelidMotion["shock"] = 0
	her.blinkTimer = 0
	her.shock(50)
	_check("vetoed shock: eyes and eyelids untouched", her.eyelidMotion["shock"] == 0 and her.blinkTimer == 0)
	Hooks.remove(&"Her.shock", veto)
	var weaker := func(c): c.args[0] = 20
	Hooks.add_before(&"Her.shock", weaker, "shock")
	her.shock(50)
	_check("shock: a handler can change the strength", her.eyelidMotion["shock"] == 20)
	Hooks.remove(&"Her.shock", weaker)
	her.eyelidMotion["shock"] = 0
	var was: bool = g.nostrilSpray
	g.nostrilSpray = true
	her.cumInMouth = her.fullCumInMouth + her.minNostrilSpray + 1
	her.nostrilSpraying = false
	Hooks.add_before(&"Her.lastSpurt", veto, "shock")
	her.lastSpurt()
	_check("vetoed last spurt: no cum from her nose, no shock", not her.nostrilSpraying and her.eyelidMotion["shock"] == 0)
	Hooks.remove(&"Her.lastSpurt", veto)
	her.cumInMouth = 0
	g.nostrilSpray = was


func _lifecycle_start() -> void:
	_ext = TestExt.new()
	_check("add extension", Extensions.add(_ext))
	_check("default off", not _ext.enabled and _ext.enabled_calls == 0)
	_check("duplicate id rejected", not Extensions.add(TestExt.new()))
	Extensions.set_enabled("test", true)
	_check("enable", _ext.enabled and _ext.enabled_calls == 1)
	_check("hook registered by extension", Probe.new().calc(1) == 202)
	_listener_obj = FlashSprite.new()
	_listener_obj.addEventListener(FlashEvent.ENTER_FRAME, func(): _ext.order.append("game"))
	_ext.order.clear()
	_start_tick = Flash.tick_count


## Her.passOut, Her.wakeUp, Her.cough: their callers ask every tick, so a veto restarts the action's own wait, unless
## the handler replaced the action (did it itself, or set its own wait).
func _poll_veto_checks() -> void:
	var her = g.her
	var veto := func(c): c.cancel()
	Hooks.add_before(&"Her.passOut", veto, "poll")
	her.passedOut = false
	her.passOutFactor = her.passOutMax
	her.passOut()
	_check("vetoed pass-out: still awake, next try in 150 ticks", not her.passedOut
		and is_equal_approx(her.passOutFactor, her.passOutMax - 7.5), str(her.passOutFactor))
	her.passOutFactor = 0.0
	her.passOut()
	_check("vetoed pass-out called early: nothing changes", her.passOutFactor == 0.0)
	Hooks.remove(&"Her.passOut", veto)
	var replace := func(c): c.cancel(); her.passedOut = true
	Hooks.add_before(&"Her.passOut", replace, "poll")
	her.passOutFactor = her.passOutMax
	her.passOut()
	_check("pass-out replaced by a handler: left as the handler made it", her.passedOut and her.passOutFactor == her.passOutMax)
	Hooks.remove(&"Her.passOut", replace)
	Hooks.add_before(&"Her.wakeUp", veto, "poll")
	her.passOutFactor = 0.0
	her.wakeUp()
	_check("vetoed wake-up: still out, next try in 80 ticks", her.passedOut and her.passOutFactor == her.passOutMax)
	Hooks.remove(&"Her.wakeUp", veto)
	her.passedOut = false
	her.passOutFactor = 0.0
	Hooks.add_before(&"Her.cough", veto, "poll")
	her.nextCoughTime = 0
	her.cough()
	_check("vetoed cough: next try after a normal wait", her.nextCoughTime >= 30 and her.nextCoughTime < 240, str(her.nextCoughTime))
	Hooks.remove(&"Her.cough", veto)
	var own := func(c): c.cancel(); her.nextCoughTime = 500
	Hooks.add_before(&"Her.cough", own, "poll")
	her.nextCoughTime = 0
	her.cough()
	_check("cough replaced with its own wait: kept", her.nextCoughTime == 500)
	Hooks.remove(&"Her.cough", own)
	her.nextCoughTime = 0


func _tick_checks() -> void:
	_check("tick runs every tick", _ext.ticks >= 4 and _ext.late_ticks >= 4, "%d/%d" % [_ext.ticks, _ext.late_ticks])
	var o: Array = _ext.order.slice(_ext.order.find("early"))
	_check("tick order: before game, game, after", o.slice(0, 3) == ["early", "game", "late"], str(o.slice(0, 6)))


func _settings_checks() -> void:
	_ext.set_setting("amount", 5.0)
	_check("setting clamped to max", is_equal_approx(_ext.get_setting("amount"), 1.0))
	_ext.set_setting("mode", "zzz")
	_check("setting options enforced", _ext.get_setting("mode") == "a")
	_ext.set_setting("flag", "true")
	_check("setting type coerced", _ext.get_setting("flag") == true)
	_check("setting change callback", [["amount", 1.0], ["flag", true]] == _ext.changed, str(_ext.changed))
	var cfg := ConfigFile.new()
	var path := FlashSharedObject.save_dir.path_join(Extensions.CONFIG_FILE)
	_check("settings saved next to the save files", cfg.load(path) == OK and cfg.get_value("test", "flag", false) == true
		and cfg.get_value("enabled", "test", false) == true, path)
	_check("data_dir under save dir", _ext.data_dir().begins_with(FlashSharedObject.save_dir) and DirAccess.dir_exists_absolute(_ext.data_dir()))
	# a fresh extension with the same id picks the saved values up again
	Extensions.remove("test")
	var again := TestExt.new()
	Extensions.add(again)
	_check("saved settings and on/off restored", again.enabled and again.get_setting("flag") == true
		and is_equal_approx(again.get_setting("amount"), 1.0))
	_ext = again


func _charcode_checks() -> void:
	var menu = g.inGameMenu
	var e := _ext
	var code: String = menu.getSaveDataString(false)
	var n := code.split(";").size()
	_check("vanilla code is a full code (%d pairs)" % n, n > CharCode.PARTIAL_PAIRS)
	_check("field written", ";testField:abc" in code and not "testLate" in code, code.right(80))
	var base := code.replace(";testField:abc", "")
	e.loads.clear()
	menu.loadData(base + ";testField:xyz", false)
	_check("field loaded from a full code", e.value == "xyz" and e.loads == [["xyz", CharCode.Kind.FULL]], str(e.loads))
	e.loads.clear()
	menu.loadData(base, false)
	_check("full code without the field resets it", e.value == "default" and e.loads == [["reset", CharCode.Kind.FULL]], str(e.loads))
	e.loads.clear()
	menu.loadData("mood:Happy;testField:p", false)
	_check("partial code sets the field", e.value == "p" and e.loads == [["p", CharCode.Kind.PARTIAL]], str(e.loads))
	e.loads.clear()
	menu.loadData("mood:Happy", false)
	_check("partial code without the field keeps it", e.value == "p" and e.loads.is_empty(), str(e.loads))
	e.loads.clear()
	CharCode.loading_mod_chardata = true
	menu.loadData(base, false)
	CharCode.loading_mod_chardata = false
	_check("a mod's charData does not reset", e.value == "p" and e.loads.is_empty(), str(e.loads))
	e.loads.clear()
	menu.onlyLoadCostume = true
	menu.loadData(base, false)
	menu.onlyLoadCostume = false
	_check("costume-only load does not reset", e.value == "p" and e.loads.is_empty(), str(e.loads))
	menu.loadData(base + ";loaderThing:1,2:3", false)
	var saved: String = menu.getSaveDataString(false)
	_check("unknown field kept (with ':' in the value)", ";loaderThing:1,2:3" in saved, saved.right(80))
	menu.loadData("mood:Happy;otherThing:x", false)
	saved = menu.getSaveDataString(false)
	_check("partial code adds unknown fields", ";loaderThing:1,2:3" in saved and ";otherThing:x" in saved)
	menu.loadData(base, false)
	_check("full code replaces unknown fields", not "loaderThing" in menu.getSaveDataString(false))
	e.value = "a;b"
	_check("value with ';' is not written", not "testField" in menu.getSaveDataString(false))
	e.value = "keepme"
	# after_mods: held back while mods load, applied when they finish
	var cel = g.customElementLoader
	var events := e.mods_events
	cel.readingMods = true
	menu.loadData(base + ";testLate:late1", false)
	var held := e.late_value == ""
	cel.readingMods = false
	CharCode.mods_loaded()
	_check("after_mods field waits for mods", held and e.late_value == "late1", e.late_value)
	_check("mods_loaded event", e.mods_events == events + 1)
	e.value = "keepme"   # the full code above reset it
	_check("vanilla key cannot be registered", not CharCode.add_field("mood", "x", func(): return "", func(_v, _l): pass))
	# disabling keeps the extension's values in the code
	Extensions.set_enabled("test", false)
	saved = menu.getSaveDataString(false)
	_check("disabled extension's field kept", ";testField:keepme" in saved and ";testLate:late1" in saved, saved.right(80))
	Extensions.set_enabled("test", true)
	menu.loadData(base + ";testField:back", false)
	_check("re-enabled extension reads its field", e.value == "back")


## The test plugins in tests/plugins (regress.sh copies them into the run's Mods/Plugins and leaves a loading
## marker for "crashy", as if it had crashed the previous start).
## Before-hooks on one-off actions: a vetoed action changes nothing, apart from restarting its own timer where the
## caller would otherwise ask again on every tick.
func _veto_checks() -> void:
	_veto_clench_teeth()
	_veto_waggle_eyebrows()
	_veto_open_eye()
	_veto_tear_spot()
	_veto_release_tears()
	_veto_random_strand()
	_veto_spit_drool()
	_veto_cum_drool()
	_veto_ejaculate()
	_veto_sweat()
	Hooks.remove_owner("veto")   # (end of the veto checks)


## Runs `fn` with a counting veto on hook `name`; returns how many times the veto was asked.
func _vetoed(name: StringName, fn: Callable) -> int:
	var n := [0]
	var veto := func(c): n[0] += 1; c.cancel()
	Hooks.add_before(name, veto, "veto")
	fn.call()
	Hooks.remove(name, veto)
	return n[0]


func _veto_clench_teeth() -> void:
	var her = g.her
	her.clenchTeeth = false
	var time: int = her.clenchedTeethTime
	var free: bool = not her.gagged and not her.mouthFull
	var n := _vetoed(&"Her.startClenchingTeeth", her.startClenchingTeeth)
	_check("vetoed clenching: teeth not clenched", n == 1 and not her.clenchTeeth and her.clenchedTeethTime == time and free)


func _veto_waggle_eyebrows() -> void:
	var her = g.her
	var queued: int = her.eyebrowOffsets.size()
	var n := _vetoed(&"Her.waggleEyebrows", her.waggleEyebrows)
	_check("vetoed eyebrow waggle: nothing queued", n == 1 and her.eyebrowOffsets.size() == queued)


func _veto_open_eye() -> void:
	var her = g.her
	her.closeEye()
	her.eyelidMotion["closedTimer"] = 1200
	var n := _vetoed(&"Her.openEye", her.openEye)
	_check("vetoed eye opening: the eye stays closed", n == 1 and her.eyelidMotion["isClosed"])
	_check("vetoed eye opening: the 40 s check starts over", her.eyelidMotion["closedTimer"] == 0)
	her.openEye()
	_check("eye opens without the veto", not her.eyelidMotion["isClosed"])


func _veto_tear_spot() -> void:
	var tears = g.her.tears
	var was: bool = g.tears
	g.tears = true
	tears.clearTearSpots()
	var n := _vetoed(&"Tears.addTearSpot", tears.addTearSpot)
	_check("vetoed tear spot: none added", n == 1 and tears.tearSpotList.is_empty())
	tears.clearTearSpots()
	g.tears = was


func _veto_release_tears() -> void:
	var tears = g.her.tears
	var was: bool = g.tears
	g.tears = true
	tears.clearTearSpots()
	for i in 4:
		tears.addTearSpot()
	var spots: int = tears.tearSpotList.size()
	var falling: int = tears.tearList.size()
	var n := _vetoed(&"Tears.releaseTears", tears.releaseTears)
	_check("vetoed tear release: the spots stay", n == 1 and spots > 0 and tears.tearSpotList.size() == spots
		and tears.tearList.size() == falling)
	tears.clearTearSpots()
	g.tears = was


func _veto_random_strand() -> void:
	var was: bool = g.spit
	g.spit = true
	var count := func(): return g.strandFrontLayer.numChildren + g.strandBackLayer.numChildren
	var before: int = count.call()
	var n := _vetoed(&"Her.generateRandomStrand", g.her.generateRandomStrand.bind("front", true))
	_check("vetoed spit strand: none made", n == 1 and count.call() == before)
	g.spit = was


func _veto_spit_drool() -> void:
	var her = g.her
	var was: bool = g.spit
	g.spit = true
	her.droolingSpit = false
	var timer: int = her.spitDroolTimer
	var n := _vetoed(&"Her.randomSpitDrool", her.randomSpitDrool)
	_check("vetoed spit drool: no drool", n == 1 and not her.droolingSpit and her.spitDroolTimer == timer)
	g.spit = was


func _veto_cum_drool() -> void:
	var her = g.her
	her.cumInMouth = 0
	var asked := _vetoed(&"Her.startDroolingCum", her.startDroolingCum.bind(false))
	_check("cum drool: not asked when it would not start", asked == 0)
	var n := _vetoed(&"Her.startDroolingCum", her.startDroolingCum.bind(true))
	_check("vetoed forced cum drool: no cum added, no drool", n == 1 and her.cumInMouth == 0 and not her.droolingCum)


func _veto_ejaculate() -> void:
	var him = g.him
	var finishes: int = g.totalFinishes
	var n := _vetoed(&"Him.ejaculate", him.ejaculate)
	_check("vetoed ejaculation: none", n == 1 and not him.ejaculating and g.totalFinishes == finishes)
	# the automatic one: at full pleasure for 60 ticks; a veto keeps his pleasure and restarts the wait
	him.pleasure = him.ejacPleasure + 10.0
	him.maxPleasureTimer = 60
	n = _vetoed(&"Him.ejaculate", func(): him.move(0.0, 0.0, 0.0))
	_check("vetoed automatic ejaculation: pleasure kept, wait restarted", n == 1 and not him.ejaculating
		and him.pleasure >= him.ejacPleasure and him.maxPleasureTimer == 0, "%s %s" % [him.pleasure, him.maxPleasureTimer])
	him.pleasure = 0.0
	him.maxPleasureTimer = 0


func _veto_sweat() -> void:
	var before: int = Sweat.droplet_count()
	var seen := [0]
	var see := func(c): seen[0] = c.args.size()
	Hooks.add_before(&"Sweat.spawn", see, "veto", -1)
	var n := _vetoed(&"Sweat.spawn", func(): Sweat.spawn(g.her.head, Vector2(21, -65), Vector2(150, 100), []))
	Hooks.remove(&"Sweat.spawn", see)
	_check("vetoed sweat: no droplet", n == 1 and Sweat.droplet_count() == before and seen[0] == 4)


func _plugin_checks() -> void:
	var P := Extensions.plugins
	if not P.has("example"):
		_check("test plugins present (run through tools/regress.sh)", false)
		return
	var ex = Extensions.get_extension("example")
	_check("plugin loaded and on by default", P["example"]["error"] == "" and ex != null and ex.enabled and not ex.builtin)
	_check("plugin manifest read", ex.title == "Example plugin" and ex.author == "tests" and ex.folder.ends_with("example"))
	_check("plugin helper script", ex.helper != null and ex.helper.answer() == 42)
	_check("dependency loaded after its dependency", Extensions.all.find(Extensions.get_extension("needs_example")) > Extensions.all.find(ex))
	_check("broken plugin skipped", P["broken"]["error"] != "" and Extensions.get_extension("broken") == null)
	_check("class_name plugin refused", P["classname"]["error"] != "" and Extensions.get_extension("classname") == null
		and g.her.get_script() == Her)
	_check("missing dependency reported", "missing dependency" in P["missing_dep"]["error"] and Extensions.get_extension("missing_dep") == null)
	var crashy = Extensions.get_extension("crashy")
	_check("plugin that crashed last start is off", crashy != null and not crashy.enabled)
	var dt = Flash.stage.getChildAt(0)
	var e := FlashEvent.new(FlashEvent.KEY_DOWN)
	e.keyCode = 120
	dt.keyPressed(e)
	g.inTextField = true
	dt.keyPressed(e)
	g.inTextField = false
	_check("plugin hotkey (not while typing)", ex.key_presses == 1, str(ex.key_presses))
	_check("plugin menu button", ex.button != null and ex.button._flash_parent == g.inGameMenu.optionsMenu)
	g.her.passOut()
	_check("Her.passOut hook", ex.passouts == 1)
	var b: ExtButton = ex.button
	Extensions.set_enabled("example", false)
	g.her.passOut()
	dt.keyPressed(e)
	_check("disabled plugin: button, hook and key removed", b._flash_parent == null and ex.passouts == 1 and ex.key_presses == 1)


func _mood_checks() -> void:
	var e := _ext
	var her = g.her
	e.moods_seen.clear()
	her.setMood("Happy")
	_check("vanilla mood", Moods.current() == "Happy" and not Moods.is_extended() and e.moods_seen == ["Happy"], str(e.moods_seen))
	# an extended mood the way moremoods does it: take over setMood, set a vanilla mood underneath
	Moods.register("Upset", "test")
	var take_over := func(c):
		if c.args[0] == "Upset":
			c.cancel()
			her.setMood("Normal")       # runs the original (the hook is inactive while its handlers run)
			Moods.set_extended("Upset")
	Hooks.add_before(&"Her.setMood", take_over, "test")
	e.moods_seen.clear()
	her.setMood("Upset")
	_check("extended mood", Moods.current() == "Upset" and her.currentMood == "Normal" and e.moods_seen == ["Upset"], str(e.moods_seen))
	_check("extension sees the extended mood", e.mood() == "Upset" and "Upset" in Moods.all())
	e.moods_seen.clear()
	her.setMood("Angry")
	_check("vanilla mood clears the extended one", Moods.current() == "Angry" and e.moods_seen == ["Angry"], str(e.moods_seen))
	her.setMood("Upset")
	Hooks.remove(&"Her.setMood", take_over)
	Moods.unregister_owner("test")
	_check("unregistered extended mood is cleared", Moods.current() == "Normal")
	her.setMood("Normal")


## Her.blink: a vetoed blink waits a normal interval before the next try (updateBlink would retry every tick) and
## leaves the eyelids alone.
func _blink_veto_checks() -> void:
	var her = g.her
	var calls := [0]
	var veto := func(c): calls[0] += 1; c.cancel()
	Hooks.add_before(&"Her.blink", veto, "test")
	her.blinkTime = 0
	her.blinkTimer = 0
	for i in 30:
		her.updateBlink()
	_check("vetoed blink: tried once, not every tick", calls[0] == 1, str(calls[0]))
	# 90..149 ticks from the veto, minus the 29 calls after it
	_check("vetoed blink: next try after a normal wait", her.blinkTime >= 60 and her.blinkTime <= 120, str(her.blinkTime))
	_check("vetoed blink: eyelids not closed", her.blinkTimer == 0)
	Hooks.remove(&"Her.blink", veto)
	her.blinkTime = 0
	her.updateBlink()
	_check("blink runs again without the veto", her.blinkTimer == 2)


func _disable_checks() -> void:
	var d := _ext.disabled_calls
	Extensions.set_vanilla_mode(true)
	var t := _ext.ticks
	_check("vanilla mode disables", not _ext.enabled and _ext.disabled_calls == d + 1 and not Hooks.has(&"Probe.calc"))
	Extensions._run_ticks(Extensions._ticks, "tick")
	_check("no ticks while disabled", _ext.ticks == t)
	Extensions.set_vanilla_mode(false)
	_check("leaving vanilla mode re-enables", _ext.enabled and Hooks.has(&"Probe.calc"))
	Extensions.set_enabled("test", false)
	_check("disable", not _ext.enabled and not Hooks.has(&"Probe.calc"))
	_check("disable removes the extension's value modifiers", not Hooks.has_value(&"T.ext"))
	Extensions.remove("test")
	_listener_obj.free()
