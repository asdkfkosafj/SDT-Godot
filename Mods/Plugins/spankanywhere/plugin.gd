extends SDTExtension
## Port of SpankAnywhereForked (Sclover13's Spank Anywhere, forked): hold the left mouse button over her back, chest,
## right breast, face, right thigh, right calf or right arm and let go to spank her there (or punch her: key G, or
## Behaviour > Spanking). The longer the button is held, the harder (power 0 to powerMax ticks): she blinks, winces,
## gags or coughs, flinches forward, cries, her eyes widen, her breasts shake, she may clench her teeth, he gets
## pleasure, a spank brings her round (a punch pushes her towards passing out) and costs her breath; a soft mark in the
## shape of the hit fades from her skin (punch marks stay as bruises; key L or the menu clears them).
## Adapted: the part under the mouse is found by testing her own body parts (front-most first) instead of invisible
## copies of them. Improved marks (same blob, colours and hardlight): painted onto her skin itself, one continuous
## piece over the parts her skin is made of, never on her clothes or hair, not on her arm when her back is hit (see
## _add_mark); the blur is baked into the image (art/mark.png). Not ported: the effects on progressiveExhaustion and
## BreastExpansion's puking (those mods aren't in the port yet). With Dynamic blushing on, spanks make her blush (value
## point Her.blushEffects). Other plugins: the `hit` signal
## and `power` / `punch` / `holding` (armoverhaul's spank reactions).
## The mod's numbers are in values.cfg (its own key names).

signal hit(part: String, power: int, punch: bool, local: Vector2, node: FlashDisplayObject)

## the mod's body parts (values.cfg section / key prefix), front-most wins when several are under the mouse
const PARTS := ["back", "chest", "breast", "face", "thigh", "calf", "upperarm", "forearm"]
## the mod's mark (its blob at alpha 0.1765, blurred) as a white image at twice the size, and its origin there
const MARK_ORIGIN := Vector2(231.8, 246.9)
## the stage area the mark maps cover (the stage and half its size around it), one texel per stage unit
const MAP_RECT := Rect2(-350, -300, 1400, 1200)

var V := {}                   # values.cfg: the mod's key -> number (colours: Color)
const MODE_KEY := KEY_G
const CLEAR_KEY := KEY_N      # the mod's (L: armoverhaul's left hand Masturbating key)

var power := 0                # how hard the hit will be (0 to powerMax)
var holding := false          # the button went down over her
var punch := false            # punch mode
var spank_current := 0.0      # blush from spanking (the mod's spankCurrent)
var _after_hit := 0
var _mark_tex: Texture2D
var _sounds := {}
var _marks: Array = []        # {"sprites": one per map, "anchors": [part, mark there] per sprite, fade state}
var _maps := {}               # "body" / "arm" -> {"vp": SubViewport, "root": Node2D}
var _joint: ShaderMaterial    # a mark in the other map, faded down her upper arm (art/joint_fade.gdshader)
var _ms := 1000.0 / 30.0


func _init() -> void:
	title = "Spank anywhere"
	description = "Hold the mouse over her body and let go to spank (or punch) her there; marks fade from her skin."


func _setup() -> void:
	setting("on", true, {"label": "Spank anywhere", "desc": "Hold the mouse over her body and let go to spank "
		+ "(or punch) her there."})
	setting("keepSpankMarks", false, {"label": "Keep spank marks",
		"desc": "Spank marks stay faintly instead of fading away."})
	setting("keepPunchMarks", true, {"label": "Keep punch marks", "desc": "Punch marks stay as bruises."})


func _enable() -> void:
	_load_values()
	_ms = 1000.0 / Flash.frame_rate
	var img := Image.load_from_file(file_path("art/mark.png"))
	_mark_tex = ImageTexture.create_from_image(img) if img else null
	for k in ["body", "arm"]:
		_maps[k] = _make_map()
	var sh := Shader.new()
	sh.code = FileAccess.get_file_as_string(file_path("art/joint_fade.gdshader"))
	_joint = ShaderMaterial.new()
	_joint.shader = sh
	for n in ["spank1", "spank2", "spank3", "spank4", "spank5"]:
		_sounds[n] = FlashSound.from_file(file_path("sounds/%s.wav" % n))
	for n in ["punch1", "punch2", "punch3", "punch4", "punch5", "moan1", "moan2", "moan3"]:
		_sounds[n] = FlashSound.from_file(file_path("sounds/%s.mp3" % n))
	Flash.stage.addEventListener(FlashEvent.MOUSE_DOWN, _mouse_down)
	Flash.stage.addEventListener(FlashEvent.MOUSE_UP, _mouse_up)
	on_tick(_tick)
	on_late_tick(_follow_all)
	modify(&"Her.blushEffects", {"op": "fn", "fn": func(v, _her): return v + spank_current})
	on_key(MODE_KEY, func(): punch = not punch, "spank / punch")
	on_key(CLEAR_KEY, clear_marks, "clear spank marks")
	menu_control("behaviour", "Spanking", MenuSchema.toggle("Spank anywhere", "Hold the mouse over her body and let go "
		+ "to spank (or punch) her there. Off: the mouse does what it does in the game, her marks go.",
		func(): return get_setting("on"), _set_on))
	menu_control("behaviour", "Spanking", MenuSchema.choice("Spank mode", "Hold the mouse over her body and let go to "
		+ "hit her there; the longer you hold, the harder. Punches hit harder and leave bruises (Spank anywhere).",
		["Spank", "Punch"], func(): return "Punch" if punch else "Spank", func(v: String): punch = v == "Punch",
		{"keywords": "spank punch slap hit"}))
	menu_control("behaviour", "Spanking", MenuSchema.toggle("Keep spank marks", "Spank marks stay faintly instead of "
		+ "fading away.", func(): return get_setting("keepSpankMarks"), func(v: bool): set_setting("keepSpankMarks", v)))
	menu_control("behaviour", "Spanking", MenuSchema.toggle("Keep punch marks", "Punch marks stay as bruises.",
		func(): return get_setting("keepPunchMarks"), func(v: bool): set_setting("keepPunchMarks", v)))
	menu_control("behaviour", "Spanking", MenuSchema.actions("", "", [["Clear marks", clear_marks,
		"Her spank and punch marks fade away."]]))
	menu_control("help", "Keys", MenuSchema.note("Spank anywhere: hold the left mouse button over her and let go to "
		+ "spank, G spank / punch, N clear the marks"))


func _disable() -> void:
	Flash.stage.removeEventListener(FlashEvent.MOUSE_DOWN, _mouse_down)
	Flash.stage.removeEventListener(FlashEvent.MOUSE_UP, _mouse_up)
	_clear_all()
	for k in _maps:
		_maps[k]["vp"].queue_free()
	_maps.clear()
	if g.him and g.him.leftArmContainer:
		g.him.leftArmContainer.visible = true
	holding = false
	power = 0
	spank_current = 0.0


## Spank anywhere on / off (Behaviour > Spanking): off, nothing she does starts a hit and her marks go
func _set_on(v: bool) -> void:
	set_setting("on", v)
	if not v:
		if holding:
			_hand_back()
		holding = false
		power = 0
		_clear_all()


func _load_values() -> void:
	V.clear()
	var cf := ConfigFile.new()
	var err := cf.load(file_path("values.cfg"))
	if err != OK:
		push_error("spankanywhere: values.cfg could not be read (%s)" % error_string(err))
		return
	for section in cf.get_sections():
		for k in cf.get_section_keys(section):
			var v = cf.get_value(section, k)
			V[k] = Color(v) if v is String else float(v)


## The mod's Min / Max value for this power
func _at(key: String, p := power) -> float:
	return V[key + "Min"] + float(p) / V["powerMax"] * (V[key + "Max"] - V[key + "Min"])


# ---------------------------------------------------------------- the mouse

func _playing() -> bool:
	return get_setting("on") and g.gameRunning and not g.gamePaused and g.her != null


## Her body part under the stage point (the front-most), or ""
func part_at(p: Vector2) -> String:
	var best := ""
	var best_node: Node = null
	for k in PARTS:
		var n = _node(k)
		if n == null or not n.is_visible_in_tree() or not n.hitTestPoint(p.x, p.y, true):
			continue
		if best_node == null or n.is_greater_than(best_node):
			best = k
			best_node = n
	return best


func _node(part: String) -> FlashDisplayObject:
	var her: Her = g.her
	match part:
		"back":
			return her.torso.back
		"chest":
			return her.torso.midLayer.chest
		"breast":
			return her.torso.midLayer.rightBreast
		"face":
			return her.head.face
		"thigh":
			return her.torso.leg.thigh
		"calf":
			return her.torso.rightCalfContainer.calf
		"upperarm":
			return her.rightArmContainer.upperArm
		"forearm":   # behind her back it doesn't show
			return her.rightForeArmContainer.upperArm.foreArm if her.currentRightArmPosition != 0 else null
	return null


func _mouse_down(_e) -> void:
	if _playing() and part_at(_mouse()) != "":
		holding = true


func _mouse_up(_e) -> void:
	if not _playing():
		return
	var was := holding
	holding = false
	var at := _mouse()
	var part := part_at(at) if was else ""
	if part != "":
		hit_at(part, at)
	else:
		_hand_back()
	power = 0


func _mouse() -> Vector2:
	return Vector2(Flash.stage.mouseX, Flash.stage.mouseY)


# ---------------------------------------------------------------- a hit

## The mod's mouseUp<Part>: what a spank (punch) of this power on this part (at that stage point) does to her
func hit_at(part: String, at: Vector2) -> void:
	var her: Her = g.her
	var him: Him = g.him
	var p := part
	var po_max: float = her.passOutMax
	if punch:
		her.passOutFactor = minf(po_max, her.passOutFactor + _at(p + "PassOut"))
	else:
		her.passOutFactor = maxf(0.0, her.passOutFactor - _at(p + "PassOut"))
	g.addBreath(_at(p + "Breath"))
	var wince_add := roundi(V[p + "WinceMin"] + (power - V[p + "BlinkThreshold"]) / (V["powerMax"] - V[p + "BlinkThreshold"])
		* (V[p + "WinceMax"] - V[p + "WinceMin"]))
	var moan := false
	if g.coughing and not her.passedOut:
		if her.passOutFactor >= po_max:
			her.passOut()
		elif power <= V[p + "BlinkThreshold"]:
			her.blink()
		elif power <= V[p + "WinceThreshold"]:
			her.wince()
			her.winceTimer += wince_add
			moan = true
		elif power <= V[p + "GagThreshold"]:
			if her.mouthFull:
				g.soundControl.playGag(her.pos)
			her.wince()
			her.winceTimer += wince_add
		elif power <= V[p + "CoughThreshold"]:
			if her.mouthFull:
				her.nextCoughTime = randi() % 210 + 30
				her.head.cheekBulge.alpha = 1.0
				her.generateSplat(5, 10)
				g.soundControl.playCough()
			elif V["openCoughDisable"] != 1:
				g.soundControl.queueOpenCough()
			her.wince()
			her.winceTimer += wince_add
		var tears := int(V[p + "TearsMin"] + floorf((power - 1) / V["powerMax"] * (1 + V[p + "TearsMax"] - V[p + "TearsMin"])))
		for i in tears:
			her.tears.addTearSpot()
		her.eyelidMotion["shock"] += _at(p + "EyeShock")
	elif g.coughing and her.passedOut and V["openCoughDisable"] != 1 and power <= V[p + "CoughThreshold"]:
		var ap = Extensions.get_extension("alternativepassout")   # its "the game's own" pass out coughs on a hit
		if ap != null and ap.enabled and ap.get_setting("on") and ap.option == 0:
			g.soundControl.queueOpenCough()
	her.coughFactor = _at(p + "CoughFactor")
	her.leftBreastController.accelerate(_at(p + "BreastAccel"))
	her.rightBreastController.accelerate(_at(p + "BreastAccel"))
	if _at(p + "ClenchTeeth") > randf() and not her.passedOut:
		her.startClenchingTeeth()
	if him.pleasure < V["spankPleasureMax"]:
		him.givePleasure(_at(p + "Pleasure"))
		him.pleasure = minf(V["spankPleasureMax"], him.pleasure)
	spank_current = minf(V["blushMax"], spank_current + _at(p + "Blush"))
	var movement := _at(p + "Motion")
	if punch:
		her.coughFactor *= V["punchMoveFactor"]
		movement *= V["punchMoveFactor"]
		spank_current *= V["punchBlushFactor"]
	# the flinch: a cough of that strength
	her.coughing = true
	her.justCoughed = true
	_hand_back()
	if V["wakeWithMouthFull"] == 1 and her.passedOut and her.passOutFactor == 0:
		her.wakeUp()
		her.breathing = g.soundControl.stopBreathing(true)
	var node := _node(p)
	var local := node.globalToLocal(at)
	_add_mark(p, at)
	_play(moan)
	_after_hit = int(V["afterEyeshockDelay"])
	var hit_power := power
	power = 0
	if V["motionDirection"] == 0 or V["motionDirection"] == 2 and randf() > 0.5:
		movement = -movement
	her.pos += movement
	hit.emit(p, hit_power, punch, local, node)


## His left arm shows again (the mod's leftArmToggle hid it while the hit built up)
func _hand_back() -> void:
	if V.get("leftArmToggle", 0.0) == 1 and g.him.currentLeftArmPosition == 1:
		g.him.leftArmContainer.visible = true


func _play(moan: bool) -> void:
	var her: Her = g.her
	if moan and not her.passedOut and her.mouthFull and V["mouthFullMoan"] == 1:
		_sounds["moan%d" % (randi() % 3 + 1)].play()
	var n := 5
	for i in 4:
		if power <= V["audioThreshold%d" % (i + 1)]:
			n = i + 1
			break
	var vol: float = 1.0 if punch else V["volumeMin"] + float(power) / V["powerMax"] * (V["volumeMax"] - V["volumeMin"])
	_sounds[("punch%d" if punch else "spank%d") % n].play(0.0, 0, FlashSoundTransform.new(vol))


# ---------------------------------------------------------------- every tick

func _tick() -> void:
	var her: Her = g.her
	if her == null:
		return
	if g.gamePaused:   # paused, everything waits; only marks being cleared go on fading
		_tick_marks(true)
		return
	_after_hit = maxi(0, _after_hit - 1)
	if holding and power < V["powerMax"]:
		power += 1
		if V["leftArmToggle"] == 1 and power == V["armToggleStart"]:
			g.him.leftArmContainer.visible = false
	if spank_current > 0.0:
		spank_current = maxf(0.0, spank_current - V["blushDecreaseRate"])
	if holding and not her.passedOut and _after_hit == 0:
		if power == V["eyeshockThreshold"]:
			her.eyelidMotion["shock"] += V["punchStartEyeshock"] if punch else V["spankStartEyeshock"]
		elif power == V["powerMax"]:
			her.eyelidMotion["shock"] += 1
		elif power > V["eyeshockThreshold"]:
			her.eyelidMotion["shock"] += V["punchHoldEyeshock"] if punch else V["spankHoldEyeshock"]
	her.eyelidMotion["shock"] = minf(V["maxEyeshock"], her.eyelidMotion["shock"])
	_tick_marks()


# ---------------------------------------------------------------- marks

## A mark where she was hit: the mod's blob (blurred, tinted with the mark colour), fading. Marks are painted into
## screen-sized maps that her skin's own shapes composite onto themselves with the mod's hardlight (the shapes' paint,
## shape_paint.gdshader): so a mark is one continuous piece over all the parts her skin is made of, shows only on her
## skin (not her clothes, hair, collar), and only where that skin shows. Her right arm has its own map, so a hit on
## her back doesn't mark the arm over it; near her shoulder (where arm and body meet: the shoulder, the armpit) a mark
## also goes into the other map, fading down the arm, so it goes on over the joint. The mark follows the part that
## was hit.
func _add_mark(part: String, at: Vector2) -> void:
	if _mark_tex == null:
		return
	var hit_node := _node(part)
	var s: float = (V["spankSizeMin"] + float(power) / V["powerMax"] * (V["spankSizeMax"] - V["spankSizeMin"]))
	if punch:
		s *= V["punchSizeFactor"]
	# sized in the part's own coordinates, as the mod puts it there
	var t := Transform2D(deg_to_rad(randf() * 60.0), Vector2(s, s), 0.0,
		hit_node.flash_global_transform().affine_inverse() * at)
	var c: Color = V["punchColor"] if punch else V["spankColor"]
	var a0: float = V["alphaMin"] + float(power) / V["powerMax"] * (V["alphaMax"] - V["alphaMin"])
	var keep: bool = get_setting("keepPunchMarks") if punch else get_setting("keepSpankMarks")
	var a1 := 0.0
	if keep:
		a1 = _at("punchKeepAlpha") if punch else _at("keepAlpha")
	var mark := {"sprites": [], "anchors": [], "colour": c, "a0": a0, "a1": a1, "t": 0.0, "dur": _at("fadeTime"),
		"keep": keep, "alpha": a0}
	_maps_up()
	var on_arm := part == "upperarm" or part == "forearm"
	# the copy in the other map follows the part it lies on: a back mark reaching her arm moves with the arm, an arm
	# mark reaching her shoulder stays on her body (the arm turns about the shoulder, so the copies meet there)
	var other: FlashDisplayObject = g.her.torso.back if on_arm else g.her.rightArmContainer.upperArm
	var global_t: Transform2D = hit_node.flash_global_transform() * t
	for m in (["arm", "body"] if on_arm else ["body", "arm"]):
		var anchor: Array = [hit_node, t]
		if not mark["sprites"].is_empty():
			anchor = [other, other.flash_global_transform().affine_inverse() * global_t]
		mark["anchors"].append(anchor)
		var sp := Sprite2D.new()
		sp.texture = _mark_tex
		sp.centered = false
		sp.offset = -MARK_ORIGIN
		sp.modulate = Color(c, a0)
		if not mark["sprites"].is_empty():
			sp.material = _joint
		_maps[m]["root"].add_child(sp)
		mark["sprites"].append(sp)
	_marks.append(mark)
	_place(mark)
	_follow_joint()
	_paint_skin(true)


## The mark's place: each copy on its part (the map's root takes stage coordinates; the image is at twice the size)
func _place(mark: Dictionary) -> void:
	for i in mark["sprites"].size():
		var a: Array = mark["anchors"][i]
		if is_instance_valid(a[0]):
			mark["sprites"][i].transform = a[0].flash_global_transform() * a[1] * Transform2D(0.0,
				Vector2(0.5, 0.5), 0.0, Vector2.ZERO)


## A map: a transparent viewport over MAP_RECT, stage coordinates in its root. Her skin reads it at this tick's
## places (the runtime's paint), so the marks in it take this tick's places too (not interpolated).
func _make_map() -> Dictionary:
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.size = Vector2i(MAP_RECT.size)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var root := Node2D.new()
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.position = -MAP_RECT.position
	vp.add_child(root)
	Flash.add_child(vp)
	Flash.draw_early(vp)   # drawn before her skin reads it (some of it inside masks)
	return {"vp": vp, "root": root}


## The maps draw while there are marks
func _maps_up() -> void:
	for k in _maps:
		_maps[k]["vp"].render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Her skin parts and the map each one shows (the parts that take her skin colour, CharacterControl.setSkin)
func _skin_parts() -> Array:
	var her: Her = g.her
	var fore = her.rightForeArmContainer.upperArm.foreArm
	var out: Array = []
	for n in [her.torso.back, her.torso.backside, her.torsoBack.backside, her.torsoBack.chestBack,
			her.torsoBack.leftShoulder, her.torso.midLayer.chest, her.torso.midLayer.rightBreast,
			her.torsoBack.leftBreast, her.torso.leg.thigh, her.torso.rightCalfContainer.calf,
			her.leftLegContainer.leg.thigh, her.leftLegContainer.leg.calf, her.head.neck, her.head.face, her.head.jaw,
			her.head.cheekBulge, her.head.cheekSuck, her.ear, her.eye.upperEyelid, her.eye.lowerEyelid,
			her.eye.eyebrowUnderMask]:
		out.append([n, "body"])
	for n in [her.rightArmContainer.upperArm, fore, fore.hand]:
		out.append([n, "arm"])
	return out


## The fade of marks across her shoulder follows her upper arm (map coordinates -> distance down the arm)
func _follow_joint() -> void:
	var arm = g.her.rightArmContainer.upperArm
	if arm == null or not is_instance_valid(arm):
		return
	var t: Transform2D = arm.flash_global_transform().affine_inverse() * Transform2D(0.0, MAP_RECT.position)
	_joint.set_shader_parameter("along_row", Vector3(t.x.y, t.y.y, t.origin.y))


## Her skin shows the maps (on: while there are marks; checked every tick, parts can change)
func _paint_skin(on: bool) -> void:
	if g.her == null:
		return
	var uv := Transform2D(0.0, Vector2.ONE / MAP_RECT.size, 0.0, -MAP_RECT.position / MAP_RECT.size)
	for pair in _skin_parts():
		var n = pair[0]
		if n != null and is_instance_valid(n):
			n.paint_transform = uv
			n.paint = _maps[pair[1]]["vp"].get_texture() if on else null


## Marks fade (the mod's tween: Regular.easeIn from the mark's alpha to 0, or to the kept alpha)
func _tick_marks(paused := false) -> void:
	if _marks.is_empty():
		return
	var left: Array = []
	for m in _marks:
		if paused and not m.get("clearing", false):
			left.append(m)
			continue
		m["t"] += _ms
		var k := minf(1.0, m["t"] / maxf(1.0, m["dur"]))
		if m.get("clearing", false):   # cleared: fading from the start (the mod's easeIn barely moves at first)
			k = 1.0 - (1.0 - k) * (1.0 - k)
		else:
			k *= k
		var a: float = m["a0"] + (m["a1"] - m["a0"]) * k
		if k < 1.0 or m["keep"]:
			m["alpha"] = a
			for sp in m["sprites"]:
				sp.modulate.a = a
			left.append(m)
		else:
			for sp in m["sprites"]:
				sp.queue_free()
	_marks = left
	if _marks.is_empty():
		_paint_skin(false)
		for k in _maps:
			_maps[k]["vp"].render_target_update_mode = SubViewport.UPDATE_DISABLED


## After her tick: the marks follow the parts that were hit, the maps the screen
func _follow_all() -> void:
	if g.her == null or _marks.is_empty():
		return
	_maps_up()
	for m in _marks:
		_place(m)
	_follow_joint()
	_paint_skin(true)


func _clear_all() -> void:
	for m in _marks:
		for sp in m["sprites"]:
			sp.queue_free()
	_marks.clear()
	_paint_skin(false)


## Every mark fades away (the mod's clear key; at once with clearFade 0)
func clear_marks() -> void:
	for m in _marks:
		var a: float = m["alpha"]
		m["a0"] = a
		m["a1"] = 0.0
		m["t"] = 0.0
		m["dur"] = roundf(V["clearFadeTimer"] * a) if V["clearFade"] == 1 else 0.0
		m["keep"] = false
		m["clearing"] = true
