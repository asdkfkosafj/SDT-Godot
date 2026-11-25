extends RefCounted
## Checks of the positions extension (animtools' body positions, stage 1; tools/regress.sh copies Mods/Positions into
## the mods folder): every shipped position file reads, writes back to the same values (unknown lines kept), each of
## animtools' version rules, finding positions by the names dialogues and codes use, ATV_defaultsdt (tests/positions)
## giving exactly the game's default animation, applying a position, and the game's default coming back (cleared,
## and the extension switched off).
## Prints "POSITIONS CHECKS: n passed, m failed".

const Position := preload("res://src/ext/positions/position.gd")
const Fields := preload("res://src/ext/positions/position_fields.gd")
const SAMPLE := "animtools/Oral/HimD/Head_on_Pole_Wither2"   # oral, her path and torso far from the game's

var _pass := 0
var _fail := 0
var _t0 := -1
var _steps: Array = []
var _next := 0
var x: SDTExtension = null
var _ik_base: Array = []    # her torso IK's own leg angle offset / end rotation
var _her_end := Vector2()
var _player_zoom := 0.0     # the zoom before the first position
var _player_arms := []      # her arms before the first position   # where she is at the end of the stroke in the sample position


func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("CHECK %s %s%s" % ["ok  " if ok else "FAIL", name, "" if ok or detail == "" else " (%s)" % detail])


func _init() -> void:
	_at(0, func(): Flash.stage.getChildAt(0).playClicked())
	_at(1, _start)
	_at(2, _file_checks)
	_at(3, _rule_checks)
	_at(4, _find_checks)
	_at(5, _default_checks)
	_at(6, _apply)
	for k in 40:
		_at(10 + k, func(): _move(Vector2(lerpf(-300.0, 600.0, k / 39.0), 250)))
	_at(60, _applied_checks)
	_at(61, _clear_checks)
	_at(62, _layer_checks)
	_at(63, func():
		x.clear()
		_check("cleared: her layers, rotation, shadow, props and the player's zoom back", _layers_vanilla(), _layers_state()))
	_at(64, _him_start)
	for k in 40:
		_at(65 + k, func(): _him_stroke(k))
	_at(106, _him_checks)
	_at(107, _contact_start)
	for k in 160:
		_at(108 + k, func(): _contact_stroke(k))
	_at(270, _contact_checks)
	_at(271, _dialogue_checks)
	_at(272, _browse_start)
	_at(282, _fade_mid)
	_at(283, func(): _dark_before = x._shade.modulate.a; x.request("animtools/Anal/ATV_doggy_hard"))
	_at(284, _fade_again)
	_at(320, _fade_end)
	_at(321, _browse_checks)
	_at(322, _import_checks)
	_at(330, func(): x.load_position("animtools/Titfuck/ATV_titfuck"))
	_at(332, func():
		Extensions.set_enabled("positions", false)
		_check("switched off: the game's default animation and her leg angles back", _is_vanilla(), _state())
		_check("switched off: her layers, rotation, shadow, props and the player's zoom back", _layers_vanilla(), _layers_state())
		_check("switched off: him unmirrored, in the scene, his body shown, her mouth open to him", _him_vanilla(), _him_state()))
	_at(334, _finish)


func step(_frame: int) -> void:
	if _t0 < 0:
		if not Extensions.started:
			return
		_t0 = Flash.tick_count
	var t := Flash.tick_count - _t0
	while _next < _steps.size() and _steps[_next][0] <= t:
		_steps[_next][1].call()
		_next += 1


func _at(tick: int, f: Callable) -> void:
	var i := _steps.size()
	while i > 0 and _steps[i - 1][0] > tick:
		i -= 1
	_steps.insert(i, [tick, f])


func _move(p: Vector2) -> void:
	Flash.get_tree().current_scene._move(p)


func _start() -> void:
	_ik_base = [g.her.torsoIK.s2OffsetAng, g.her.torsoIK.endRotationAngle]
	Extensions.set_enabled("positions", true)
	x = Extensions.get_extension("positions")
	_check("positions extension on", x != null and x.enabled)
	if x == null or not x.enabled:
		_finish()


## Every shipped file: reads, all keys numbers, nothing unknown; written and read again gives the same values.
func _file_checks() -> void:
	var names: PackedStringArray = x.library.names
	var shipped := Array(names).filter(func(n): return n.begins_with("animtools/"))
	var partials := shipped.filter(func(n): return Position.is_partial_name(n))
	_check("74 shipped positions and 4 partials found", shipped.size() == 78 and partials.size() == 4,
		"%d, %d partial" % [shipped.size(), partials.size()])
	var bad := []
	var unknown := []
	var trip := []
	var versions := {}
	for n in shipped:
		if n in partials:
			continue
		var p = x.read_position(n)
		if p == null:
			bad.append(n)
			continue
		versions[p.version] = versions.get(p.version, 0) + 1
		for k in Fields.defaults():
			if not p.values.has(k) or is_nan(p.values[k]):
				bad.append("%s:%s" % [n, k])
		if not p.extra.is_empty() or not p.settings.is_empty():
			unknown.append("%s %s %s" % [n, p.extra, p.settings])
		var q = Position.from_text(p.to_text(), n)
		for k in Fields.defaults():
			if q.values[k] != p.values[k]:
				trip.append("%s:%s %s -> %s" % [n, k, p.values[k], q.values[k]])
		if q.version != Fields.VERSION:
			trip.append("%s: version %d" % [n, q.version])
	_check("every shipped position reads, every key a number", bad.is_empty(), str(bad.slice(0, 5)))
	_check("no unknown lines in the shipped positions", unknown.is_empty(), str(unknown.slice(0, 3)))
	_check("all shipped positions carry a posversion (28-39)", not versions.has(-1), str(versions))
	_check("written and read again: the same values, posversion 40", trip.is_empty(), str(trip.slice(0, 5)))
	# unknown lines and global settings survive a save
	var t := "posversion=40\r\nzoom=0.55\r\nfoo=bar baz\r\nmyNumber=1.5\r\npreV33herarmonlegs=1\r\nfoo=second"
	var p = Position.from_text(t, "test/unknown")
	var q = Position.from_text(p.to_text(), "test/unknown")
	_check("unknown lines kept (last value, first place) and written back",
		p.extra == [["foo", "second"], ["myNumber", "1.5"]] and q.extra == p.extra, "%s / %s" % [p.extra, q.extra])
	_check("a global setting in a position kept apart and written back",
		p.settings.get("preV33herarmonlegs") == 1.0 and q.settings.get("preV33herarmonlegs") == 1.0, str(q.settings))
	_check("numbers keep every digit", Position.number_text(-0.05235987755982988).to_float() == -0.05235987755982988
		and Position.number_text(290.0) == "290" and Position.number_text(367.3) == "367.3")


func _p(text: String, globals := {}):
	return Position.from_text(text.replace(";", "\n"), "test/rules", null, globals)


## animtools' backwards-compatibility rules, each just below and at its version.
func _rule_checks() -> void:
	_check("v32: arm on legs with her own points -> Custom (12)",
		_p("posversion=32;armpostyperight=1;armposx=10;armpostypeleft=1;armpos2y=5").values["armpostyperight"] == 12
		and _p("posversion=32;armpostypeleft=1;armpos2y=5").values["armpostypeleft"] == 12)
	_check("v33: arm on legs stays", _p("posversion=33;armpostyperight=1;armposx=10").values["armpostyperight"] == 1)
	_check("v32: arm on legs without points stays", _p("posversion=32;armpostyperight=1").values["armpostyperight"] == 1)
	var a = _p("posversion=37;torsox=300;torsoy=1000;torsox2=5;torsoy2=6")
	_check("v37: knee end = knee start", a.values["torsox2"] == 300 and a.values["torsoy2"] == 1000)
	a = _p("posversion=38;torsox=300;torsox2=5")
	_check("v38: knee end kept", a.values["torsox2"] == 5)
	_check("v14: hair gravity follows strand gravity",
		_p("posversion=14;changegravityforstrands=1").values["changegravityforhairstrands"] == 1
		and _p("posversion=15;changegravityforstrands=1").values["changegravityforhairstrands"] == 0)
	_check("v26 tit fuck: left breast behind",
		_p("posversion=26;positiontype=1").values["leftbreastbehind"] == 1
		and _p("posversion=27;positiontype=1").values["leftbreastbehind"] == 0
		and _p("posversion=26;positiontype=2").values["leftbreastbehind"] == 0)
	_check("v27: no body size reference (or the fallback)",
		_p("posversion=27;savedBodySize=0.5").values["savedBodySize"] == -999
		and _p("posversion=27;savedBodySize=0.5", {"usefallbacklegmountbodyscaling": 1}).values["savedBodySize"] == 0.4
		and _p("posversion=28;savedBodySize=0.5").values["savedBodySize"] == 0.5)
	_check("v34: sideways range 80; v35 its own",
		_p("posversion=34;offpathposmovement=10").values["offpathposmovement"] == 80
		and _p("posversion=35;offpathposmovement=10").values["offpathposmovement"] == 10)
	a = _p("posversion=32;himreversed=1;histweenstartang=0.1;histweenendangle=0.2")
	var want := -0.1 * 180.0 / PI
	_check("v32 reversed: his start angle becomes the penis offset, steady penis",
		is_equal_approx(a.values["hispenisrotationoffset"], want) and is_equal_approx(a.values["hispenisrotationoffsetend"], want)
		and a.values["histweenstartang"] == 0 and a.values["histweenendangle"] == 0 and a.values["usesteadypenis"] == 1,
		str([a.values["hispenisrotationoffset"], a.values["histweenstartang"], a.values["usesteadypenis"]]))
	a = _p("posversion=32;himflipped=1;histweenstartang=0.1;anglepeniswhenreversed=0")
	_check("v32 flipped, no penis angling: offset stays, angles 0",
		a.values["hispenisrotationoffset"] == 0 and a.values["histweenstartang"] == 0 and a.values["usesteadypenis"] == 1)
	_check("v33 reversed: angles stay", _p("posversion=33;himreversed=1;histweenstartang=0.1").values["histweenstartang"] == 0.1)
	_check("v33: penis offset end = start",
		_p("posversion=33;hispenisrotationoffset=7;hispenisrotationoffsetend=3").values["hispenisrotationoffsetend"] == 7
		and _p("posversion=34;hispenisrotationoffset=7;hispenisrotationoffsetend=3").values["hispenisrotationoffsetend"] == 3)
	_check("v38: no hand rotation of his; v39 its own",
		_p("posversion=38;hishandstartrotation=5;hishandrottarget=3").values["hishandstartrotation"] == -5000
		and _p("posversion=38;hishandrottarget=3").values["hishandrottarget"] == 1
		and _p("posversion=39;hishandstartrotation=5").values["hishandstartrotation"] == 5)
	_check("old hands on her breasts: arm types 5 / 6",
		_p("posversion=40;armpostypeleft=0;handlontit=1").values["armpostypeleft"] == 5
		and _p("posversion=40;armpostyperight=0;handrontit=2").values["armpostyperight"] == 6
		and _p("posversion=40;armpostyperight=-1;handrontit=2").values["armpostyperight"] == -1)
	a = _p("torsox=300;offpathposmovement=10")
	_check("no posversion: every rule (version -1)", a.version == -1 and a.values["torsox2"] == 300
		and a.values["offpathposmovement"] == 80)
	var base = _p("posversion=34;camerax=111;himhidden=1")
	var part = Position.from_text("himhidden=0", "test/hide_partial", base)
	_check("a partial changes only its keys and takes the base's version",
		part.partial and part.version == 34 and part.values["himhidden"] == 0 and part.values["camerax"] == 111,
		"%s %d" % [part.partial, part.version])


func _find_checks() -> void:
	var lib = x.library
	var want := "animtools/Oral/HimD/headpole_low"
	var got := {}
	for n in ["Oral/HimD/headpole_low", "headpole_low", "Oral_slash5C_HimD_slash5C_headpole_low",
			"animtools_positions\\Oral\\HimD\\headpole_low.txt", "ORAL/HIMD/HEADPOLE_LOW", want]:
		got[n] = lib.find(n)
	_check("positions found by the names dialogues and codes use", got.values().all(func(v): return v == want), str(got))
	_check("a name that is no position: none", lib.find("no_such_position") == "")
	_check("ATV_facefuck is with the shipped oral positions", lib.find("ATV_facefuck") == "animtools/Oral/ATV_facefuck")


## ATV_defaultsdt (animtools' copy of the game's default) gives exactly the game's default animation.
func _default_checks() -> void:
	var f := ProjectSettings.globalize_path("res://").path_join("../tests/positions/ATV_defaultsdt.txt")
	var p = Position.from_text(FileAccess.get_file_as_string(f), "test/ATV_defaultsdt")
	var a: MainAnimation = x.build_animation(p)
	var d: MainAnimation = g.animationControl.animations[AnimationControl.DEFAULT]
	var diffs := []
	for i in 13:
		var t := -0.2 + i * 0.1
		for tilt in [-1.0, 0.0, 1.0]:
			if not a.getHerMatrix(t, tilt).is_equal_approx(d.getHerMatrix(t, tilt)):
				diffs.append("her %.1f %.0f" % [t, tilt])
		if not a.getHisMatrix(t).is_equal_approx(d.getHisMatrix(t)):
			diffs.append("his %.1f" % t)
	for k in ["herKneeTarget", "altVector", "altRange", "hisLeftFootTarget", "hisRightFootTarget", "torsoMinAng",
			"torsoStartAng", "torsoAngMultiplier", "torsoMinDist", "torsoStartDist", "torsoDistMultiplier"]:
		if not is_equal_approx_any(a.get(k), d.get(k)):
			diffs.append("%s %s / %s" % [k, a.get(k), d.get(k)])
	_check("ATV_defaultsdt = the game's default animation (paths, knee, feet, torso)", diffs.is_empty(), str(diffs))
	_check("its leg angle offset = her torso IK's own (within 1e-6)",
		absf(a.torsoS2OffsetAng - _ik_base[0]) < 1e-6 and a.torsoEndRotation == _ik_base[1],
		"%s / %s" % [a.torsoS2OffsetAng, _ik_base[0]])


static func is_equal_approx_any(u, v) -> bool:
	if u is float or v is float:
		return is_equal_approx(float(u), float(v))
	if u is Vector2:
		return u.is_equal_approx(v)
	return u == v


func _apply() -> void:
	_player_zoom = g.sceneZoom
	_player_arms = [Her.armPositions[g.her.currentLeftArmPosition], Her.armPositions[g.her.currentRightArmPosition]]
	_check("sample position loads", x.load_position(SAMPLE))


func _applied_checks() -> void:
	var p = x.current
	var ac: AnimationControl = g.animationControl
	var v: Dictionary = p.values if p != null else {}
	_check("the position's animation runs", p != null and ac.currentAnimation == x.ANIM, ac.currentAnimation)
	if p == null:
		return
	_check("his feet and her knee from the file", ac.getHisLeftFootTarget() == Vector2(v["leftfootx"], v["leftfooty"])
		and ac.getHisRightFootTarget() == Vector2(v["rightfootx"], v["rightfooty"])
		and ac.getHerKneeTarget() == Vector2(v["torsox"], v["torsoy"]))
	_check("her torso numbers from the file", ac.torsoStartAng == v["torsostartangle"]
		and ac.torsoMinDist == v["torsomindistance"] and ac.torsoAngMultiplier == v["torsoanglemodifier"])
	_check("her leg angles from the file", g.her.torsoIK.s2OffsetAng == v["torsoikoffsetang"]
		and g.her.torsoIK.endRotationAngle == v["torsoendrotationangle"])
	var m: Transform2D = ac.getHerMatrix(g.her.pos, 0.0)
	var start := Vector2(v["hertweenstartx"], v["hertweenstarty"])
	var end := Vector2(v["hertweenendx"], v["hertweenendy"])
	var d: MainAnimation = ac.animations[AnimationControl.DEFAULT]
	var vstart: Vector2 = d.herTween.start.origin
	var vend: Vector2 = d.herTween.end.origin
	_check("her path is the position's (on its start-end line, off the game's)",
		_dist_to_line(m.origin, start, end) < 25.0 and _dist_to_line(m.origin, vstart, vend) > 60.0,
		"%s, line %s-%s, %.0f from the game's" % [m.origin, start, end, _dist_to_line(m.origin, vstart, vend)])
	_check("her torso start angle is the position's, not the game's", ac.torsoStartAng != d.torsoStartAng)
	_check("the save keeps the game's style (default)", ac.currentAnimationName == AnimationControl.DEFAULT)
	# stage 2: camera, props, joint limits
	var sl: SceneLayer = g.sceneLayer
	_check("the position's zoom, and at that zoom its camera (v32+ curve starts there)",
		is_equal_approx(sl.currentZoom, v["zoom"]) and sl.camera.distance_to(Vector2(v["camerax"], v["cameray"])) < 0.01,
		"zoom %s camera %s" % [sl.currentZoom, sl.camera])
	_check("the options save keeps the player's zoom", is_equal_approx(
		Hooks.value(&"SaveData.sceneZoom", g.saveData, g.sceneZoom), _player_zoom), str(_player_zoom))
	var active := []
	for pr in Fields.PROPS:
		if v[pr[0] + "active"] == 1:
			active.append(pr[0])
	var shown: Array = x.props.shown()
	shown.sort()
	active.sort()
	_check("the position's props show (and only those)", shown == active and not active.is_empty(), "%s vs %s" % [shown, active])
	_check("joint end limits lifted by version (her leg >= 29, her hands >= 32)",
		Hooks.value(&"IKController.endLimit", g.her.torsoIK, 1.22) == INF
		and Hooks.value(&"IKController.endLimit", g.her.leftArmIK, 1.22) == INF
		and Hooks.value(&"IKController.endLimit", g.him.currentBody.rightArmIK, 1.22) == 1.22)


## Stage 2's layers and rotation, one position after another (applying is immediate).
func _layer_checks() -> void:
	var her: Her = g.her
	var sl: SceneLayer = g.sceneLayer
	x.load_position("animtools/Oral/BedBJ")
	_check("scene rotation from the file, on the scene and its outside layers (BedBJ 88)",
		is_equal_approx(sl.rotation_degrees, 88.0) and is_equal_approx(g.backLayer.rotation_degrees, 88.0)
		and is_equal_approx(x.props.holder.rotation_degrees, 88.0), str(sl.rotation_degrees))
	var down: Vector2 = g.strandControl.gravityDir()
	_check("strands fall to the screen's bottom (BedBJ: along the scene's x)",
		down.is_equal_approx(Vector2(sin(deg_to_rad(88.0)), cos(deg_to_rad(88.0))))
		and sl.transform.basis_xform(down).normalized().is_equal_approx(Vector2(0, 1)), str(down))
	_check("hair turns with the scene (offset -88), its own offset kept; hair outside 25 degrees stays",
		is_equal_approx(Hooks.value(&"Rope.gravityOffset", null, 0.0), -88.0)
		and is_equal_approx(Hooks.value(&"Rope.gravityOffset", null, 10.0), -78.0)
		and Hooks.value(&"Rope.gravityOffset", null, 40.0) == 40.0)
	sl.toggleMirrored()
	_check("mirrored: the rotation the other way", is_equal_approx(sl.rotation_degrees, -88.0), str(sl.rotation_degrees))
	var mdown: Vector2 = g.strandControl.gravityDir()
	_check("mirrored: strands still fall to the screen's bottom",
		sl.transform.basis_xform(mdown).normalized().is_equal_approx(Vector2(0, 1)), str(mdown))
	sl.toggleMirrored()
	var bg_shadow: bool = x.layers._shadow().visible
	x.load_position("animtools/Oral/ATV_laydownarmsback")
	_check("her shadow off (hidehershadow)", bg_shadow and not x.layers._shadow().visible)
	x.load_position("animtools/Titfuck/ATV_titfuck")
	_check("a position without gravity changes: straight down again", g.strandControl.gravityDir() == Vector2(0, 1)
		and not Hooks.has_value(&"Rope.gravityOffset"))
	_check("her left leg and breast behind him: out of her, at the bottom of the scene",
		her.leftLegContainer.parent != her and her.torsoBack.leftBreast.parent != her.torsoBack
		and sl.getChildIndex(her.leftLegContainer.parent) < sl.getChildIndex(g.him)
		and sl.getChildIndex(her.torsoBack.leftBreast.parent) < sl.getChildIndex(g.him))
	her.updateTorso()
	x.layers._follow()
	var leg_ok: Vector2 = her.leftLegContainer.localToGlobal(Vector2(10, 20))
	her.leftLegContainer.parent.removeChild(her.leftLegContainer)
	x.layers._leg_home[0].addChildAt(her.leftLegContainer, x.layers._leg_home[1])
	her.updateTorso()
	var leg_in: Vector2 = her.leftLegContainer.localToGlobal(Vector2(10, 20))
	x.layers._leg_holder.addChild(her.leftLegContainer)
	_check("her moved leg is where it would be in her", leg_ok.distance_to(leg_in) < 0.01, "%s vs %s" % [leg_ok, leg_in])
	_check("her moved breast keeps her skin colour", her.torsoBack.leftBreast.filters == her.torsoBack.filters)
	g.changeLayer(her.leftArmContainer, her, her.leftLegContainer)
	_check("while her leg is out, \"next to her leg\" puts her left arm behind her; the leg stays out",
		her.leftLegContainer.parent != her and her.leftArmContainer.parent == g.backLayer)
	# her arms: the position's (titfuck: Cupping Breast both), the player's kept for the code and for the end
	_check("the position's arms (Cupping Breast)", Her.armPositions[her.currentLeftArmPosition] == "Cupping Breast"
		and Her.armPositions[her.currentRightArmPosition] == "Cupping Breast",
		"%s %s" % [Her.armPositions[her.currentLeftArmPosition], Her.armPositions[her.currentRightArmPosition]])
	var code: String = g.inGameMenu.getSaveDataString()
	_check("the character code keeps the player's arms", ("arms:%s,%s" % [g.dataName(_player_arms[0]),
		g.dataName(_player_arms[1])]) in code, code.substr(code.find("arms:"), 40))
	_check("her left arm's hand angle counts her while it is out of her", her in her.leftArmIK.endRotationTargets)
	x.load_position("animtools/Oral/ATV_all_fours_onewithshadows_edit")
	var v: Dictionary = x.current.values
	_check("Custom arm: her hand aims at the position's point", Her.armPositions[her.currentLeftArmPosition] == "Custom"
		and her.leftArmIK.targetPoint == Vector2(v["armpos2x"], v["armpos2y"]) and her.leftArmIK.targetPointCoordinateSpace == g.sceneLayer,
		"%s %s" % [Her.armPositions[her.currentLeftArmPosition], her.leftArmIK.targetPoint])


## Stage 3: him turned round, his layer, her mouth closed to him in non-oral positions, his body hidden.
var _mouth_before := []
var _mouth_full_seen := false


func _him_start() -> void:
	var her: Her = g.her
	x.load_position("animtools/Anal/ATV_doggy_hard")   # reversed, penis behind her, anal
	var him: Him = g.him
	him.currentBody.move(her.pos, 0.0, 0.0)
	_check("reversed: his body, his over layer and his arm mirrored",
		g.him.transform.determinant() < 0.0 and him.overLayer.scaleY < 0.0 and him.armContainer.scaleY < 0.0)
	var leg: IKController = him.currentBody.leftLegIK
	_check("reversed: his feet turn against his unmirrored turn",
		is_equal_approx(Hooks.value(&"IKController.parentRotation", leg, deg_to_rad(him.rotation_degrees)),
			wrapf(_his_turn(), -PI, PI)))
	_check("anal: her mouth closed to him, his feet not limited",
		Hooks.has_value(&"Her.mouthContact") and not Hooks.value(&"Her.mouthContact", her, true)
		and Hooks.value(&"IKController.endLimit", leg, 1.22) == INF)
	her.startClenchingTeeth()
	_check("anal: her teeth do not clench", not her.clenchTeeth)
	g.setPenisOut(false)
	g.setPenisOut(true)
	_check("penis behind her: he stays in the scene, under her, while his penis is out",
		him.parent == g.sceneLayer and g.sceneLayer.getChildIndex(him) < g.sceneLayer.getChildIndex(her) and g.penisOut,
		"%s %s" % [him.parent, g.penisOut])
	g.setPenisOut(false)


## The tween's angle before the mirror (doggy_hard: reversed).
func _his_turn() -> float:
	var t: Transform2D = x._anim.hisTween._tweenMatrix
	return Transform2D(t.x * Vector2(-1, 1), t.y * Vector2(-1, 1), Vector2()).get_rotation()


func _him_stroke(k: int) -> void:
	if k == 2:   # (from here: the first ticks end what the oral stroke before left pending, e.g. her intro relaxing)
		_mouth_before = [g.her.intro, g.her.firstDT, g.her.mouthFull]
	_move(Vector2(lerpf(600.0, -300.0, absf(sin(k * 0.4))), 250))
	if g.her.mouthFull:
		_mouth_full_seen = true


func _him_checks() -> void:
	var her: Her = g.her
	var him: Him = g.him
	_check("anal: her mouth never full over a stroke, intro and first deep throat kept",
		not _mouth_full_seen and [her.intro, her.firstDT, her.mouthFull] == _mouth_before, str([_mouth_full_seen, her.intro, her.firstDT]))
	var t: Transform2D = g.sceneLayer.flash_global_transform().affine_inverse() * him.penis.flash_global_transform()
	var axis: float = t.basis_xform(Vector2(-1, 0)).angle()
	_check("spurts along his penis (here: to the right, at her)",
		absf(angle_difference(Hooks.value(&"Him.spurtAngle", him, -2.9), axis)) < 0.01 and absf(axis) < PI / 2, str(axis))
	x.load_position("animtools/Vaginal/ATV_Missionary_V2_Medium_QuiteQuaint")
	_check("vaginal, penis not behind her: he draws in front of her", him.parent == g.frontLayer and not g.penisOut)
	x.load_position("animtools/Other/HerD/Futa_anal")
	_check("himhidden = 0: his body hidden, his penis shows", him.bodyHidden and him.penis.visible)
	x.load_position("animtools/Oral/BedBJ")
	_check("oral again: his body back, him where his penis says, her mouth open to him",
		not him.bodyHidden and him.parent == (g.frontLayer if g.penisOut else g.sceneLayer) and not Hooks.has_value(&"Her.mouthContact")
		and not Hooks.has_value(&"g.penisInFront"))
	x.clear()
	_check("cleared: him unmirrored, in the scene, his body shown, her mouth open to him", _him_vanilla(), _him_state())


func _him_vanilla() -> bool:
	var him: Him = g.him
	him.currentBody.move(g.her.pos, 0.0, 0.0)
	return (him.transform.determinant() > 0.0 and him.overLayer.scaleY > 0.0 and him.armContainer.scaleY > 0.0
		and him.parent == (g.frontLayer if g.penisOut else g.sceneLayer) and not him.bodyHidden
		and not Hooks.has_value(&"Her.mouthContact") and not Hooks.has_value(&"g.penisInFront")
		and not Hooks.has_value(&"IKController.parentRotation"))


func _him_state() -> String:
	var him: Him = g.him
	return "det %.2f, over %.1f, arm %.1f, in scene %s, penis out %s, hidden %s, mouth gate %s" % [
		him.transform.determinant(), him.overLayer.scaleY, him.armContainer.scaleY, him.parent == g.sceneLayer,
		g.penisOut, him.bodyHidden, Hooks.has_value(&"Her.mouthContact")]


## Stage 4: body contact in a non-oral position (the bodycontact extension; the experience preset Average).
var bc: SDTExtension = null
var _seen := {}            # what the stroke showed: contact, depth, drag, mask, caught, lowest resistance
var _tick_us := 0
var _ticks := 0


func _contact_start() -> void:
	bc = Extensions.get_extension("bodycontact")
	bc.set_setting("experience", "Average")
	x.load_position("animtools/Oral/BedBJ")
	bc._tick()
	_check("body contact: off in oral positions", bc != null and bc.enabled and not bc.active)
	x.load_position("animtools/Anal/ATV_doggy_hard")
	bc._load(false)
	_check("anal: on, Average's anal resistance (10), full", bc.active and bc.v["startingresistance"] == 10.0
		and bc.resistance == 10.0, "%s %s %s" % [bc.active, bc.v.get("startingresistance"), bc.resistance])
	_seen = {"contact": false, "depth": 0.0, "drag": 0.0, "mask": -100.0, "caught": false, "low": INF, "back": false}


func _contact_stroke(k: int) -> void:
	_move(Vector2(lerpf(-200.0, 700.0, 0.5 + 0.5 * sin(k * 0.08)), 250))
	var a := Time.get_ticks_usec()
	bc._tick()
	_tick_us += Time.get_ticks_usec() - a
	_ticks += 1
	var her: Her = g.her
	if bc.contact:
		_seen["contact"] = true
		_seen["depth"] = maxf(_seen["depth"], bc.depth)
		_seen["drag"] = maxf(_seen["drag"], Hooks.value(&"Her.drag", her, 0.0))
		_seen["mask"] = maxf(_seen["mask"], Hooks.value(&"Him.penisMask", g.him, {"x": -100.0, "scale": 1.0})["x"])
		if Hooks.value(&"Him.cumCaught", g.him, false):
			_seen["caught"] = true
		_seen["low"] = minf(_seen["low"], bc.resistance)
	elif _seen["low"] < 10.0 and bc.resistance > _seen["low"]:
		_seen["back"] = true


func _contact_checks() -> void:
	var her: Her = g.her
	_check("a stroke: contact, depth past the entry point, her resistance pushes back, his penis masked inside her",
		_seen["contact"] and _seen["depth"] > 100.0 and _seen["drag"] > 0.05 and _seen["mask"] > -100.0, str(_seen))
	_check("in contact his spurts stay inside her", _seen["caught"])
	_check("her resistance wears down while he is in her and comes back while he is out",
		_seen["low"] < 10.0 and _seen["back"], str(_seen))
	bc._vigour = 0.0
	_check("her vigour: the game's gain undone (the position's own instead)", Hooks.value(&"Her.vigourGain", her, 5.0) == 0.0)
	_check("body contact's tick under 0.2 ms (mean)", _tick_us / maxi(1, _ticks) < 200, "%d us" % (_tick_us / maxi(1, _ticks)))
	bc.set_setting("experience", "Position's own")
	_check("experience \"Position's own\": the file's resistance", bc.v["startingresistance"] == x.current.values["startingresistance"])
	bc.set_setting("experience", "Average")
	x.clear()
	bc._tick()
	_check("cleared: body contact off, nothing applied", not bc.active and Hooks.value(&"Her.drag", her, 0.0) == 0.0
		and not Hooks.value(&"Him.cumCaught", g.him, false) and Hooks.value(&"Her.vigourGain", her, 5.0) == 5.0)


## Stage 5: dialogue triggers, variables and line types, auto mode, character code.
func _dialogue_checks() -> void:
	x.set_setting("transition", "Instant")   # (the fade: _browse_start)
	var da = Extensions.get_extension("dialogueactions")
	_check("DialogueActions on", da != null and da.enabled)
	var val := func(n: String) -> String: return da.vars.value_text(n)
	_check("atv_active 1, atv_position 0 with the game's animation", val.call("atv_active") == "1"
		and val.call("atv_position") == "0", "%s %s" % [val.call("atv_active"), val.call("atv_position")])
	_check("[ANIMTOOLS_<name>] loads the position (folders as _slash5C_)",
		da.run_code("[ANIMTOOLS_Anal_slash5C_ATV_doggy_hard]") and x.current != null and x.current.name.ends_with("ATV_doggy_hard"))
	_check("atv_position 3, atv_position_name as the dialogue gave it, atv_dominant", val.call("atv_position") == "3"
		and val.call("atv_position2") == "3" and val.call("atv_position_name") == "Anal\\ATV_doggy_hard"
		and val.call("atv_dominant") == str(int(x.current.values["dominant"])),
		"%s %s %s" % [val.call("atv_position"), val.call("atv_position_name"), val.call("atv_dominant")])
	_check("animtools' voice triggers are taken (no voice pack yet)", da.run_code("[ANIMTOOLSSETVOICECHAR3]")
		and da.run_code("[ANIMTOOLSDISABLEHUNNIESOUNDS]"))
	var dc = g.dialogueControl
	dc.loadCustomDialogue('bodyentered:"in"\nbodyentered_anal:"anal in"\ncuminher:"cum"\n', false)
	bc._tick()
	_check("line types for the dialogue's animtools lines (and only those)", dc.states.has("bodyentered")
		and dc.states.has("bodyentered_anal") and dc.states.has("cuminher") and not dc.states.has("inbody"))
	bc._line("bodyentered")
	_check("the line for the position's type goes first", dc.states["bodyentered_anal"].build > 0
		and dc.states["bodyentered"].build == 0)
	_check("auto mode: her tip position is where he met her", is_equal_approx(g.animationControl.estimateTipPos(),
		0.15 if bc.meet == INF else bc.meet))
	var ac = g.automaticControl
	ac.currentPos = Vector2(0.2, 0.3)
	ac.lastPos = Vector2(0.0, 0.3)
	ac.adjustAim()
	_check("auto mode: no aiming at her mouth in non-oral positions", is_equal_approx(ac.currentPos.y, 0.3), str(ac.currentPos))
	_check("character code: animtoolsSexExperience (Average), the position only with animtools' saving on",
		bc._code_get() == "0,Average" and x.talk._code_get() == null)
	bc._code_set("0,Tight", null)
	var tight: bool = bc.get_setting("experience") == "Tight" and bc.v["startingresistance"] == 12.5
	bc._code_set("0,Average", null)
	_check("a code's sexual experience applies", tight and bc.get_setting("experience") == "Average")
	_check("[ANIMTOOLSRANDOM] loads a full position", da.run_code("[ANIMTOOLSRANDOM]") and x.current != null
		and not "_partial" in x.current.name.to_lower())
	dc.loadCustomDialogue("", false)
	x.clear()


## S6: the transition (dark fade), the browser's folders and filter, the hotkeys' functions, the Loader import.
const L := preload("res://src/ext/positions/position_library.gd")
var _dark_before := 0.0
var _faded_first = null


func _browse_start() -> void:
	_check("folders: source and dominance folders left out, partial and root files",
		L.category("animtools/Oral/HimD/x") == "Oral" and L.category("Imported/Vaginal/HerD/y") == "Vaginal"
		and L.category("animtools/_partial/z_partial") == "Partial" and L.category("Mine/Sub/w") == "Mine/Sub"
		and L.category("v") == "Other", "%s %s %s" % [L.category("animtools/Oral/HimD/x"), L.category("Mine/Sub/w"), L.category("v")])
	_check("dominance from HimD / HerD folders; short names", L.dominance("animtools/Anal/HimD/a") == "Him"
		and L.dominance("a/HerD/b") == "Her" and L.dominance("animtools/Oral/c") == "Neutral"
		and L.short_name("animtools/Oral/ATV_face_fuck") == "face fuck")
	x.set_setting("transition", "Dark fade")
	x.set_setting("fade_ticks", 18)
	x.clear()
	x.request("animtools/Oral/ATV_facefuck")
	_check("dark fade: the position waits for the dark, the shade is over the game and under the menu",
		x.current == null and x._fade != null and x._fade.layer < 50 and x._fade.layer > 0 and x._shade.modulate.a < 0.2)


func _fade_mid() -> void:
	_faded_first = x.current
	_check("dark fade: applied at its darkest point", x.current != null and x.current.name.ends_with("ATV_facefuck")
		and x._shade.modulate.a > 0.6, "%s %.2f" % [x.current, x._shade.modulate.a if x._shade else -1.0])


func _fade_again() -> void:
	_check("a pick while it fades in: back to dark from where it was (no jump)", x._fade != null
		and x._shade.modulate.a >= _dark_before - 0.01, "%.2f -> %.2f" % [_dark_before, x._shade.modulate.a if x._shade else -1.0])


func _fade_end() -> void:
	_check("dark fade: the second pick applied, the shade gone", x.current != null
		and x.current.name.ends_with("ATV_doggy_hard") and x._fade == null and x._fade_left == 0)


func _browse_checks() -> void:
	var cur = x.current
	x.request("animtools/_partial/himhidden_on_partial")
	_check("a partial position applies at once, even with the fade", x.current != cur and x._fade == null)
	x.set_setting("transition", "Instant")
	x.load_position("animtools/Anal/ATV_doggy_hard")
	var names: Array = []
	for i in 8:
		x.random()
		names.append(x.current.name)
	_check("random: full positions only, never the same twice in a row", names.all(func(n): return not L.is_partial(n))
		and range(1, names.size()).all(func(i): return names[i] != names[i - 1]), str(names))
	x.load_position("animtools/Anal/ATV_doggy_hard")
	x.step(1)
	var nxt: String = x.current.name
	x.step(-1)
	_check("next / previous stay in the position's folder", L.category(nxt) == "Anal"
		and nxt != "animtools/Anal/ATV_doggy_hard" and x.current.name == "animtools/Anal/ATV_doggy_hard", nxt)
	x.browser.filter = "Him"
	x.step(1)
	_check("next with the browser's filter: only positions he leads", x.library.dominance(x.current.name) == "Him"
		and L.category(x.current.name) == "Anal", x.current.name)
	x.browser.filter = "All"
	var box: Control = x.browser._grid()
	var cells := 0
	var heads := 0
	var built_folded := 0
	for ch in box.get_children():
		if ch is GridContainer:
			built_folded += ch.get_child_count()
		elif ch is Button:
			heads += 1
			if not ch.text.begins_with("▾"):
				ch.pressed.emit()   # open it: its cells come in the next frames
	var jobs: int = x.browser._jobs.size()
	for i in 200:
		if x.browser._jobs.is_empty():
			break
		x.browser._run_jobs()
	for ch in box.get_children():
		if ch is GridContainer:
			cells += ch.get_child_count()
	_check("browser: a folder's cells only once it is opened, made over several frames", built_folded == 0
		and jobs > 0 and cells == jobs, "%d before, %d queued, %d made" % [built_folded, jobs, cells])
	_check("browser: every position in a folder of its own", cells == x.library.names.size() and heads >= 5,
		"%d cells %d folders, %d positions" % [cells, heads, x.library.names.size()])
	x.browser.filter = "Her"
	box.get_meta("refresh").call()
	var shown := 0
	for ch in box.get_children():
		if ch is GridContainer:
			for c in ch.get_children():
				shown += 1 if c.visible else 0
	_check("browser filter: only the positions she leads", shown > 0 and shown < cells, "%d of %d" % [shown, cells])
	x.browser.filter = "All"
	box.free()
	x.request_default()
	_check("back to the game's default", x.current == null)
	var page := MenuSchema._positions()
	_check("the menu's Positions page: shown while positions is on, the game runs on it", page["owner"] == "positions"
		and page["live"] and SDTMenu._shown(page))


func _import_checks() -> void:
	if not Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--mods-dir=")):
		_check("Loader import (needs --mods-dir: it writes into Mods/Positions)", false)
		return
	var fake := FlashSharedObject.save_dir.path_join("fake_loader")
	var ap := fake.path_join("Settings/animtools_positions")
	var shipped: String = x.library.path_of("animtools/Oral/ATV_facefuck")
	DirAccess.make_dir_recursive_absolute(ap.path_join("Oral"))
	DirAccess.make_dir_recursive_absolute(ap.path_join("Mine"))
	DirAccess.make_dir_recursive_absolute(fake.path_join("Mods/SomeGirl"))
	DirAccess.copy_absolute(shipped, ap.path_join("Oral/ATV_facefuck.txt"))
	var f := FileAccess.open(ap.path_join("Mine/mine.txt"), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(shipped) + "\nscenerotation=5\n")
	f.close()
	DirAccess.copy_absolute(shipped.get_basename() + ".png", ap.path_join("Mine/mine.png"))
	f = FileAccess.open(fake.path_join("Mods/SomeGirl/animtoolscharposition.txt"), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(shipped) + "\nscenerotation=7\n")
	f.close()
	var li := LoaderImport.run(fake)
	var imp := Flash.mods_dir("Positions").path_join("Imported")
	_check("Loader import: new positions copied (thumbnail too), the shipped one not again, a character folder's by its name",
		li.positions == 2 and x.library.has("Imported/Mine/mine") and x.library.has("Imported/Characters/SomeGirl")
		and FileAccess.file_exists(imp.path_join("Mine/mine.png")) and not x.library.has("Imported/Oral/ATV_facefuck"),
		"%d %s" % [li.positions, Array(x.library.names).filter(func(n): return n.begins_with("Imported"))])
	_check("Loader import again: nothing copied twice", LoaderImport.run(fake).positions == 0)
	for p in [imp.path_join("Mine/mine.txt"), imp.path_join("Mine/mine.png"), imp.path_join("Characters/SomeGirl.txt"),
			imp.path_join("Mine"), imp.path_join("Characters"), imp]:
		DirAccess.remove_absolute(p)
	x.rescan()


func _layers_vanilla() -> bool:
	var her: Her = g.her
	return her.leftLegContainer.parent == her and her.torsoBack.leftBreast.parent == her.torsoBack \
		and her.torsoBack.leftBreast.filters.is_empty() and g.sceneLayer.rotation_degrees == 0.0 \
		and g.backLayer.rotation_degrees == 0.0 and x.layers._shadow().visible and x.props.shown().is_empty() \
		and is_equal_approx(g.sceneZoom, _player_zoom) 		and Her.armPositions[her.currentLeftArmPosition] == _player_arms[0] 		and Her.armPositions[her.currentRightArmPosition] == _player_arms[1]


func _layers_state() -> String:
	var her: Her = g.her
	return "leg in her %s, breast in torsoBack %s, rotation %s, shadow %s, props %s, zoom %s / %s" % [
		her.leftLegContainer.parent == her, her.torsoBack.leftBreast.parent == her.torsoBack,
		g.sceneLayer.rotation_degrees, x.layers._shadow().visible, x.props.shown(), g.sceneZoom, _player_zoom]


static func _dist_to_line(p: Vector2, a: Vector2, b: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)


func _clear_checks() -> void:
	x.clear()
	g.her.updateTorso()
	_check("cleared: the game's default animation and her leg angles back", _is_vanilla(), _state())
	_check("cleared: her layers, rotation, shadow, props and the player's zoom back", _layers_vanilla(), _layers_state())


func _is_vanilla() -> bool:
	var ac: AnimationControl = g.animationControl
	g.her.updateTorso()
	return ac.currentAnimation == AnimationControl.DEFAULT and ac.animations.size() == 2 \
		and g.her.torsoIK.s2OffsetAng == _ik_base[0] and g.her.torsoIK.endRotationAngle == _ik_base[1] \
		and ac.getHerKneeTarget() == Vector2(160, 1240)


func _state() -> String:
	var ac: AnimationControl = g.animationControl
	return "%s %s %s %s" % [ac.currentAnimation, ac.animations.keys(), g.her.torsoIK.s2OffsetAng, _ik_base]


func _finish() -> void:
	print("POSITIONS CHECKS: %d passed, %d failed" % [_pass, _fail])
	Flash.get_tree().quit()
