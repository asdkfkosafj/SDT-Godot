extends SDTExtension
## Built-in reimplementation of animtools' body positions (animtools V40): positions are animtools .txt files in
## Mods/Positions (the set the game comes with in Mods/Positions/animtools), read as they are and brought to the V40
## format (Position), and applied as an animation of their own next to the game's two (AnimationControl
## .addAnimation), so the game's own "default" and "face fuck" stay untouched. Written from the mod's files,
## documentation and behaviour.
##
## So far: reading, the version rules, writing; applying her and his paths, his feet, her knee anchor (along her
## stroke and with her body size), her torso numbers and the mouse's sideways range, the camera (zoom, zoom point,
## scene rotation), the joint limits by file version, props (position_props.gd), his right arm's path, her left leg
## and breast behind him and her shadow (position_layers.gd), her arms (position_arms.gd: animtools' arm positions
## and Custom), him reversed / flipped, the dialogue triggers and variables (position_dialogue.gd); back to the
## game's default. The menu's Positions page (position_browser.gd) and hotkeys load positions with a transition
## (request): a dark fade that applies the position while the screen is dark (animtools' "shade", off in its own
## settings file; here on, as it hides the load). Body contact is its own extension (bodycontact).
##
## A position is a temporary state: it does not change the player's saved settings; switching the extension off (or
## Vanilla mode) gives the game's default animation back.

const Position := preload("res://src/ext/positions/position.gd")
const Library := preload("res://src/ext/positions/position_library.gd")
const Fields := preload("res://src/ext/positions/position_fields.gd")
const Props := preload("res://src/ext/positions/position_props.gd")
const Layers := preload("res://src/ext/positions/position_layers.gd")
const Arms := preload("res://src/ext/positions/position_arms.gd")
const Talk := preload("res://src/ext/positions/position_dialogue.gd")
const Browser := preload("res://src/ext/positions/position_browser.gd")
const Editor := preload("res://src/ext/positions/position_editor.gd")
const TRANSITIONS := ["Dark fade", "Instant"]
const FADE_LAYER := 40   # over the game, under the menu (50)

const ANIM := "position"   # the AnimationControl key of the applied position
## The value points an applied position modifies (taken off when it ends; the arms' own stay while the extension is on).
const POSITION_POINTS: Array[StringName] = [&"SceneLayer.rotation", &"SceneLayer.cameraAim", &"SaveData.sceneZoom",
	&"IKController.endLimit", &"HimMaleBody.armPoint", &"HimMaleBody.shoulderPoint", &"HimMaleBody.handRotation",
	&"StrandControl.gravityDirection", &"Rope.gravityOffset", &"IKController.parentRotation", &"Him.penisAngle",
	&"Him.spurtAngle", &"Her.mouthContact", &"g.penisInFront", &"SoundControl.breathOpenness"]

var library = Library.new()
var current = null         # the applied Position (null: the game's default)
var props = Props.new()
var layers = null          # PositionLayers (her leg / breast behind him, her shadow)
var arms = null            # PositionArms (animtools' arm positions, a position's arms)
var talk = null            # PositionDialogue (dialogue triggers and variables, the character code field)
var browser = null         # PositionBrowser (the menu's Positions page)
var editor = null          # PositionEditor (the menu's Edit position page and the handles)
var loaded_name := ""      # the name the current position was loaded by (a dialogue's, a code's or the library's)
var file_settings := {}    # animtools global settings loaded files set (kept for the session, as animtools' globals)
var serial := 0            # counts the positions loaded (the editor's changes do not: body contact keeps its state)


func _init() -> void:
	id = "positions"
	title = "Positions"
	description = "animtools' body positions: positions from .txt files in Mods/Positions, picked on the menu's Positions page."
	default_enabled = true
	setting("transition", TRANSITIONS[0], {"label": "Transition", "options": TRANSITIONS,
		"tip": "How the scene changes to another position: a short fade to dark (the change happens while it is dark) or at once. Partial positions always change at once."})
	setting("fade_ticks", 18, {"label": "Fade length", "min": 6, "max": 60, "step": 1,
		"tip": "How long the dark fade takes, in game frames (60 a second). animtools' default: 18."})
	setting("random_from", RANDOM_FROM[0], {"label": "Random picks from", "options": RANDOM_FROM,
		"tip": "What Random, its hotkey and the dialogue's [ANIMTOOLSRANDOM] pick from. Right-click a position to make it a favourite."})


func _enable() -> void:
	rescan()
	props.start()
	layers = Layers.new(self)
	layers.start()
	arms = Arms.new(self)
	arms.start()
	talk = Talk.new(self)
	talk.start()
	browser = Browser.new(self)
	browser.start()
	editor = Editor.new(self)
	editor.start()
	on_tick(_tick)
	on_key(122, random, "random position", "random")
	on_key(121, reload, "reload the position", "reload")
	on_key(34, func(): step(1), "next position in the folder", "next")
	on_key(33, func(): step(-1), "previous position in the folder", "previous")
	hook_before(&"Her.startClenchingTeeth", func(c): if not _oral(): c.cancel())
	menu_control("dev_tools", "Positions", MenuSchema.choice("Position", "Load a body position (animtools .txt)",
		func(): return ["(game default)"] + Array(library.names),
		func(): return "(game default)" if current == null else current.name,
		func(v): clear() if v == "(game default)" else load_position(v)))


func _disable() -> void:
	_end_fade()
	var ac: AnimationControl = g.animationControl
	if ac != null and ac.heldStyle != "":   # the player's face fuck style back
		var style := ac.heldStyle
		ac.heldStyle = ""
		clear()
		ac.setAnimation(style)
	if editor != null:
		editor.stop()
		editor.editing = false
	clear()
	file_settings.clear()
	props.stop()
	if arms != null:
		arms.stop()


func positions_root() -> String:
	return Flash.mods_dir("Positions")


func rescan() -> void:
	library.scan(positions_root())
	Browser.forget_thumbnails()


# ---------------------------------------------------------------- picking positions (menu, hotkeys, dialogue)

## Loads a position by name with the transition (the dark fade; at once for a partial one, with "Instant" or when
## `fade` is false); `shown` is the name the dialogue variable atv_position_name gives (default: `given`). false
## when there is none by that name.
func request(given: String, shown := "", fade := true) -> bool:
	var n: String = library.find(given)
	if n == "":
		_not_found(given)
		return false
	missing = ""
	var change := func():
		var had = current
		if load_position(given) and shown != "" and not (library.is_partial(n) and had != null):
			loaded_name = shown
	if library.is_partial(n) or not fade:
		change.call()
	else:
		_transition(change, n)
	return true


## Back to the game's default animation, with the transition (also when a picked position still waits for the dark).
func request_default() -> void:
	missing = ""
	if current != null or _fade_do.is_valid():
		_transition(clear, "")


## A random full position (not partial, not the current one): animtools' random key / [ANIMTOOLSRANDOM].
## With "Random picks from" Favourites, only the favourite ones (all when no favourite is a full position).
func random() -> void:
	var cur: String = "" if current == null else current.name
	var full: Array = Array(library.names).filter(func(n): return not library.is_partial(n) and n != cur)
	if get_setting("random_from") == RANDOM_FROM[1]:
		var fav := full.filter(func(n): return is_favourite(n))
		if not fav.is_empty() or favourites().any(func(n): return n == cur):
			full = fav
	if not full.is_empty():
		request(full[randi() % full.size()])


# ---------------------------------------------------------------- favourites (port.cfg, by library name)

const FAV_CFG := "positions_fav"
const RANDOM_FROM := ["All positions", "Favourites"]
var fav_serial := 0   # goes up on each change (the browser's Favourites folder is made again)


## The favourite positions that are in the library now, in library order.
func favourites() -> Array:
	var names: Array = PortSettings.get_value(FAV_CFG, "names", [])
	return Array(library.names).filter(func(n): return n in names)


func is_favourite(n: String) -> bool:
	return n in PortSettings.get_value(FAV_CFG, "names", [])


func set_favourite(n: String, on: bool) -> void:
	var names: Array = PortSettings.get_value(FAV_CFG, "names", []).duplicate()
	if on == (n in names):
		return
	if on:
		names.append(n)
	else:
		names.erase(n)
	PortSettings.set_value(FAV_CFG, "names", names)
	fav_serial += 1


## Reads the folder again and loads the current position's file again (after it was edited): animtools' reload key.
func reload() -> void:
	rescan()
	if current != null and current.name != "":
		var keep := loaded_name
		if load_position(current.name):
			loaded_name = keep


## The next (`by` 1) or previous (-1) position in the current position's folder, as the browser shows it (its
## dominance filter too); from the game's default: the first or last position.
func step(by: int) -> void:
	var cur: String = "" if current == null else current.name
	if _fade_do.is_valid() and _fade_target != null:   # a pick still waits for the dark: on from that one
		cur = _fade_target
	var cat: String = library.category(cur) if cur != "" else ""
	var list: Array = Array(library.names).filter(func(n):
		return not library.is_partial(n) and (cat == "" or library.category(n) == cat) \
			and (browser == null or browser.filter == "All" or library.dominance(n) == browser.filter))
	if list.is_empty():
		return
	var i := list.find(cur)
	i = (0 if by > 0 else list.size() - 1) if i < 0 else posmod(i + by, list.size())
	if list[i] != cur:
		request(list[i])


# ---------------------------------------------------------------- the transition (dark fade)

var _fade: CanvasLayer = null
var _shade: ColorRect = null
var _fade_left := 0          # ticks left (0: no fade)
var _fade_len := 0
var _fade_do := Callable()   # runs at the darkest point
var _fade_target = null      # the library name _fade_do loads ("": the game's default; null: none waits)


## Runs `change` now (Instant, or in Vanilla-like states without a scene) or at the midpoint of a dark fade. A
## second request during a fade replaces the change if the screen is not dark yet, else waits for the next fade.
func _transition(change: Callable, target = null) -> void:
	var n := int(get_setting("fade_ticks"))
	if get_setting("transition") != TRANSITIONS[0] or n < 2 or g.sceneLayer == null:
		change.call()
		return
	_fade_target = target
	if _fade_left > 0 and _fade_do.is_valid():   # still fading out: the newer pick wins
		_fade_do = change
		return
	var dark: float = 0.0 if _shade == null else _shade.modulate.a   # fading in: back to dark from where it is
	_fade_len = n
	_fade_left = n - roundi(dark * n * 0.5)
	_fade_do = change
	if _fade == null:
		_fade = CanvasLayer.new()
		_fade.layer = FADE_LAYER
		_shade = ColorRect.new()
		_shade.color = Color.BLACK
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade.add_child(_shade)
		Flash.add_child(_fade)
	_shade.modulate.a = dark


func _fade_tick() -> void:
	_fade_left -= 1
	var half := _fade_len / 2
	if _fade_left <= half and _fade_do.is_valid():   # animtools: the change at the midpoint (or at once when the fade started dark)
		var c := _fade_do
		_fade_do = Callable()
		_fade_target = null
		c.call()
	_shade.modulate.a = 1.0 - absf(_fade_left - _fade_len * 0.5) / (_fade_len * 0.5)
	if _fade_left <= 0:
		_end_fade()


func _end_fade() -> void:
	if _fade_do.is_valid():
		var c := _fade_do
		_fade_do = Callable()
		_fade_target = null
		c.call()
	_fade_left = 0
	if _fade != null:
		_fade.queue_free()
		_fade = null
		_shade = null


## Reads a position by name (see PositionLibrary.find); a partial one applies to the current position. null when not
## found or not readable.
func read_position(given: String):
	var n: String = library.find(given)
	if n == "":
		return null
	var text := FileAccess.get_file_as_string(library.path_of(n))
	if text == "" and FileAccess.get_open_error() != OK:
		return null
	var p = Position.from_text(text, n, current, file_settings, library.is_partial(n))
	if p.partial and current == null:   # a partial on the game's default: a changed default, no file of its own
		p.name = ""
	elif p.path == "":   # (a partial keeps the file of the position it changes)
		p.path = library.path_of(n)
	return p


## Loads and applies a position by name; false when there is none by that name. A partial changes the current
## position (its name stays); the global settings a file sets stay for later positions, as in animtools.
func load_position(given: String) -> bool:
	var before = current
	var p = read_position(given)
	if p == null:
		_not_found(given)
		return false
	missing = ""
	var n: String = library.find(given)
	file_settings.merge(p.own_settings, true)
	serial += 1
	apply(p)
	_da_masturbate(p)
	if not (library.is_partial(n) and before != null):   # (a library name: in animtools' form)
		loaded_name = library.animtools_name(library.find(given)) if library.has(given) else given
	return true


var missing := ""   # the last name asked for that is not in Mods/Positions (a character code, a dialogue): the page shows it


func _not_found(given: String) -> void:
	push_warning("Positions: no position \"%s\"" % given)
	missing = given


## An animtools global setting: the value a loaded file set (kept for later positions, as animtools' globals), else
## animtools' shipped value.
func setting_value(key: String) -> float:
	return float(file_settings.get(key, Fields.SETTINGS[key]))


## Applies a position. `edit`: the editor's change of the current one (the zoom and her arms are set again only when
## their own keys changed, so the player's zoom and her arm stay while other keys are edited).
func apply(p, edit := false) -> void:
	var prev = current if edit else null
	if current == null and g.sceneLayer != null:
		player_zoom = g.sceneZoom
	current = p
	var ac: AnimationControl = g.animationControl
	_anim = build_animation(p)
	ac.addAnimation(ANIM, _anim)
	ac.setAnimation(ANIM)
	_apply_camera(p, prev == null or prev.values["zoom"] != p.values["zoom"])
	_apply_limits(p)
	_apply_his_arm(p)
	_apply_him(p)
	_apply_penis(p)
	_apply_breath()
	props.show(p.values)
	layers.show(p.values)
	if prev == null or Arms.KEYS.any(func(k): return prev.values[k] != p.values[k]):
		arms.show(p.values)
	_knee_moves = p.values["torsox"] != p.values["torsox2"] or p.values["torsoy"] != p.values["torsoy2"] \
		or (p.values["savedBodySize"] != -999 and _setting_global("enablelegmountbodyscaling") == 1)
	_knee = Vector2(INF, INF)
	_update_knee()


## The game's face fuck style is not offered while positions is on (ATV_facefuck is a position like the others): its
## animation gives way to the game's default (or the position), the player's choice kept for the save.
func _no_face_fuck() -> void:
	var ac: AnimationControl = g.animationControl
	if ac == null or ac.currentAnimation != AnimationControl.FACE_FUCK:
		return
	ac.heldStyle = AnimationControl.FACE_FUCK
	ac.setAnimation(ANIM if current != null and ac.animations.has(ANIM) else AnimationControl.DEFAULT)


## The position's animation made again from its values (the editor's path, knee, feet and torso changes), without
## the rest of apply().
func rebuild_animation(p) -> void:
	current = p
	_anim = build_animation(p)
	g.animationControl.addAnimation(ANIM, _anim)
	g.animationControl.dispatchUpdates()
	_knee_moves = p.values["torsox"] != p.values["torsox2"] or p.values["torsoy"] != p.values["torsoy2"] 		or (p.values["savedBodySize"] != -999 and _setting_global("enablelegmountbodyscaling") == 1)
	_knee = Vector2(INF, INF)
	_update_knee()


func _tick() -> void:
	if _fade_left > 0:
		_fade_tick()
	_no_face_fuck()
	if current != null and _knee_moves:
		_update_knee()


# ---------------------------------------------------------------- her knee

var _anim: MainAnimation = null
var _knee_moves := false   # the knee point changes along the stroke or with her body size
var _knee := Vector2()


## Her knee's anchor (animtools' dokneetranslate, every tick): from the start point to the end point along her
## stroke, moved with her body size against the size the position was made with (along her thigh). animtools moves
## it in screen space (so it grew with the player's zoom); here it is the same offset at the position's own camera,
## steady as the player zooms or mirrors.
func _update_knee() -> void:
	var v: Dictionary = current.values
	var u := clampf((g.her.pos + 0.25) / 1.27, 0.0, 1.0)
	var k := Vector2(lerpf(v["torsox"], v["torsox2"], u), lerpf(v["torsoy"], v["torsoy2"], u))
	var saved: float = v["savedBodySize"]
	if saved != -999 and _setting_global("enablelegmountbodyscaling") == 1:
		var d: float = (g.her.bodySize - saved) * _setting_global("legmountscalefactor")
		if d != 0.0:
			var th: FlashDisplayObject = g.her.torso.leg.thigh
			var sl: SceneLayer = g.sceneLayer
			var along := sl.globalToLocal(th.localToGlobal(Vector2(d, d))) - sl.globalToLocal(th.localToGlobal(Vector2.ZERO))
			k += along.rotated(deg_to_rad(v["scenerotation"])) * v["zoom"]
	if k == _knee:
		return
	_knee = k
	_anim.herKneeTarget = k
	g.her.torsoIK.newTarget(k, g.sceneLayer, true)


# ---------------------------------------------------------------- his custom arm

var _prev_arm := Vector2(NAN, NAN)   # his hand's point last tick (hands off: it eases to the rest point from there)


## His right arm on the position's own path (enablehiscustomarm, animtools' doarmsstuff): his shoulder from the start
## to the end point as his arm moves along the stroke (and with his body's height on the stroke), his hand from its
## start to its end point (scene space) along her stroke, back to its rest point (his space) while she is free, eased
## there with the hands off; his hand's angle from the start to the end angle against the chosen part.
## (altarmfollows = 0, a separate path for the Loader's extra arm, is in no shipped file: the extra arm follows.)
func _apply_his_arm(p) -> void:
	unmodify(&"HimMaleBody.armPoint")
	unmodify(&"HimMaleBody.shoulderPoint")
	unmodify(&"HimMaleBody.handRotation")
	_prev_arm = Vector2(NAN, NAN)
	var v: Dictionary = p.values
	if v["enablehiscustomarm"] != 1:
		return
	modify(&"HimMaleBody.armPoint", {"op": "fn", "fn": _his_arm_point})
	modify(&"HimMaleBody.shoulderPoint", {"op": "fn", "fn": _his_shoulder})
	if v["hishandstartrotation"] != -5000 and v["hishandendrotation"] != -5000:
		modify(&"HimMaleBody.handRotation", {"op": "fn", "fn": _his_hand_rotation,
			"when": func(_b): return not g.her.released})


static func _u(pos: float) -> float:
	return clampf((pos + 0.25) / 1.27, 0.0, 1.0)


func _his_shoulder(_sp: Vector2, body) -> Vector2:
	var v: Dictionary = current.values
	var u := _u(body.armPos)
	return Vector2(lerpf(v["shoulderpointstartx"], v["shoulderpointendx"], u),
		lerpf(v["shoulderpointstarty"], v["shoulderpointendy"], u)) + his_shoulder_offset()


## How far his shoulder's points move with his body's height on the stroke now (his space; the editor's handles
## add it too).
func his_shoulder_offset() -> Vector2:
	if current == null or _anim == null:
		return Vector2.ZERO
	var t: Transform2D = _anim.hisTween._tweenMatrix
	var off := Vector2(t.x.y, t.x.x) * (t.origin.y - 120.0)
	if (current.values["himreversed"] == 1) != (current.values["himflipped"] == 1):
		off.y = -off.y
	return off


## How far the scene moves on the screen (its parent's pixels) for one unit more of camerax / cameray at the
## player's zoom now (the editor's camera handle drags the scene with the mouse).
func camera_rate() -> Vector2:
	if current == null or g.sceneLayer == null:
		return Vector2.ONE
	var v: Dictionary = current.values
	var sl = g.sceneLayer
	var a0 := _camera_aim(Vector2.ZERO, sl)
	v["camerax"] += 1.0
	var ax := _camera_aim(Vector2.ZERO, sl)
	v["camerax"] -= 1.0
	v["cameray"] += 1.0
	var ay := _camera_aim(Vector2.ZERO, sl)
	v["cameray"] -= 1.0
	return Vector2(ax.x - a0.x, ay.y - a0.y)


func _his_arm_point(_ap: Vector2, body) -> Vector2:
	var v: Dictionary = current.values
	var ac: FlashDisplayObject = body._him.armContainer
	var sl: SceneLayer = g.sceneLayer
	var rest := ac.globalToLocal(g.him.localToGlobal(Vector2(v["handpointrestx"], v["handpointresty"])))
	var out: Vector2
	if g.handsOff:
		out = rest if is_nan(_prev_arm.x) else _prev_arm + (rest - _prev_arm) * 0.1
	else:
		var start := ac.globalToLocal(sl.localToGlobal(Vector2(v["handpointstartx"], v["handpointstarty"])))
		if g.her.isReleased():
			out = start + maxf(0.0, body.armPos) * (rest - start)
		else:
			var end := ac.globalToLocal(sl.localToGlobal(Vector2(v["handpointendx"], v["handpointendy"])))
			out = start + _u(g.her.pos) * (end - start)
	_prev_arm = out
	return out


func _his_hand_rotation(_r: float, body) -> float:
	var v: Dictionary = current.values
	var her: Her = g.her
	var arm_rot: float = body._him.armContainer.arm.rotation_degrees
	var against := 0.0
	match int(v["hishandrottarget"]):
		1:
			against = -arm_rot
		2:
			against = her.rotation_degrees - arm_rot
		3:
			against = her.leftLegContainer.leg.rotation_degrees - arm_rot + her.torso.rotation_degrees
		4:
			against = her.torso.rotation_degrees - arm_rot + her.rotation_degrees
	return lerpf(v["hishandstartrotation"], v["hishandendrotation"], _u(her.pos)) + against


# ---------------------------------------------------------------- him turned round, his penis

## His body mirrored (the tween does that), his feet's angles against his unmirrored turn, his penis's angle offset
## along her stroke (or steady: without its tilt), and his spurts along his penis.
func _apply_him(p) -> void:
	unmodify(&"IKController.parentRotation")
	unmodify(&"Him.penisAngle")
	unmodify(&"Him.spurtAngle")
	var v: Dictionary = p.values
	var rev: bool = v["himreversed"] == 1
	if rev or v["himflipped"] == 1:
		modify(&"IKController.parentRotation", {"op": "fn", "fn": _his_leg_turn, "when": func(ik): return ik.s1.parent == g.him})
	if v["usesteadypenis"] == 1 or v["hispenisrotationoffset"] != 0 or v["hispenisrotationoffsetend"] != 0:
		modify(&"Him.penisAngle", {"phase": Hooks.FINAL, "op": "fn", "fn": _penis_angle})
	modify(&"Him.spurtAngle", {"op": "fn", "fn": _spurt_angle})


## His body's rotation as his feet see it: the turn before the mirror (animtools: the mirrored body's rotation the
## other way round, half a turn more when reversed).
func _his_leg_turn(r: float, _ik) -> float:
	var v: Dictionary = current.values
	var odd: bool = (v["himreversed"] == 1) != (v["himflipped"] == 1)
	return wrapf((-r if odd else r) - (PI if v["himreversed"] == 1 else 0.0), -PI, PI)


func _penis_angle(a: float, _him) -> float:
	var v: Dictionary = current.values
	var off := lerpf(v["hispenisrotationoffset"], v["hispenisrotationoffsetend"], _u(g.her.pos))
	return (0.0 if v["usesteadypenis"] == 1 else a) + off


## Spurts shoot along his penis (animtools: along his body's angle and the penis offset), with part of the game's
## random spread (spurtanglerandomamount; the game's spurts are -2.9 +- 0.4 rad).
func _spurt_angle(a: float, him) -> float:
	var t: Transform2D = g.sceneLayer.flash_global_transform().affine_inverse() * him.penis.flash_global_transform()
	var spread := (a + 2.9) * _setting_global("spurtanglerandomamount")
	return t.basis_xform(Vector2(-1, 0)).angle() + (-spread if t.determinant() < 0.0 else spread)


# ---------------------------------------------------------------- her mouth, his layer, his body

var _hid_body := false   # his body hidden by the position (the player's "Show his body" was on)


## Not oral (tit fuck, vaginal, anal, other): his tip never reaches her mouth (so no mouth full, intro, deep throat,
## gag, nose squash...: they keep their values for the next oral position) and her teeth do not clench. He draws
## behind her, so his penis goes in behind her; as in animtools, the files without setpenisoutbehind bring him in
## front while his penis is out (the game's penisOut: while the mouse button is held), the others never. His body
## hides in the files that hide it (himhidden = 0).
func _apply_penis(p) -> void:
	unmodify(&"Her.mouthContact")
	unmodify(&"g.penisInFront")
	var v: Dictionary = p.values
	if not _oral():
		modify(&"Her.mouthContact", {"op": "set", "value": false})
		if g.her.clenchTeeth:
			g.her.releaseTeeth()
	if v["setpenisoutbehind"] == 1:
		modify(&"g.penisInFront", {"op": "set", "value": false})
	g.updatePenisLayer()
	_show_body(v["himhidden"] != 0)


## Her breath grows louder with her mouth half open (animtools' newRandomBreath: the openness / 0.6, between 0.4 and
## 0.9, or the openness when more), only while a position is applied.
func _apply_breath() -> void:
	unmodify(&"SoundControl.breathOpenness")
	modify(&"SoundControl.breathOpenness", {"op": "fn", "fn": func(v: float, _sc) -> float:
		var m: float = g.herMouthOpeness
		return maxf(v, maxf(clampf(m / 0.6, 0.4, 0.9), m))})


## animtools tells DialogueActions to start or stop her masturbating with each position it loads (its "shady DA
## injection", on in its settings file): the position's DAhermasterbate (0 in every shipped file, so she stops and
## her arm goes back to the position's).
func _da_masturbate(p) -> void:
	if _setting_global("enableshadyDAinjection") != 1:
		return
	var da = Extensions.get_extension("dialogueactions")
	if da != null and da.enabled:
		da.run_code("[MASTURBATE_ON]" if p.values["DAhermasterbate"] == 1 else "[MASTURBATE_OFF]")


func _oral() -> bool:
	return current == null or current.values["positiontype"] == 0


func _show_body(on: bool) -> void:
	if not on and not g.him.bodyHidden:
		g.him.setBodyHidden(true)
		_hid_body = true
	elif on and _hid_body:
		if g.him.bodyHidden:
			g.him.setBodyHidden(false)
		_hid_body = false


# ---------------------------------------------------------------- joint limits

## The game keeps her leg's and her hands' end joints within 1.22 rad; animtools lifted that for newer files (her
## leg from posversion 29, her hands from 32 or with its preventswitchinganglehandsforoldpositions setting).
func _apply_limits(p) -> void:
	unmodify(&"IKController.endLimit")
	var leg: bool = p.version >= 29
	var hands: bool = p.version >= 32 or _setting_global("preventswitchinganglehandsforoldpositions") != 0
	modify(&"IKController.endLimit", {"op": "fn", "fn": func(lim: float, ik) -> float:
		var h = g.her
		if ik == h.torsoIK:
			return INF if leg else lim
		if ik == h.leftArmIK or ik == h.rightArmIK:
			return INF if hands else lim
		if ik.s1.parent == g.him:   # his legs: animtools' own leg IK has no limit
			return INF
		return lim})


## Back to the game's default animation.
func clear() -> void:
	var had := current != null
	current = null
	for n in POSITION_POINTS:
		unmodify(n)
	if g.animationControl != null:
		g.animationControl.removeAnimation(ANIM)
	if g.him != null:
		g.updatePenisLayer()
		_show_body(true)
	props.show(null)
	if layers != null:
		layers.show(null)
	if arms != null:
		arms.show(null)
	if had and g.sceneLayer != null:
		g.sceneLayer.zoomTo(player_zoom, true)
		g.inGameMenu.updateZoomSlider()


# ---------------------------------------------------------------- camera

var player_zoom := 0.0     # g.sceneZoom before the first position (saved instead of the position's; back on clear)


## The position's camera: its zoom now (the player can still zoom), its rotation, and the camera's aim as the zoom
## changes (animtools' updateCamera: from posversion 32 a curve from the position's camera towards its zoom point,
## older files a straight line).
func _apply_camera(p, zoom := true) -> void:
	unmodify(&"SceneLayer.rotation")
	unmodify(&"SceneLayer.cameraAim")
	unmodify(&"SaveData.sceneZoom")
	modify(&"SaveData.sceneZoom", {"op": "fn", "fn": func(_v, _o): return player_zoom})
	if _setting_global("allowcamerarotationchanges") == 1:
		modify(&"SceneLayer.rotation", {"op": "fn", "fn": _scene_rotation})
	if _setting_global("allowcameraxychanges") == 1:
		modify(&"SceneLayer.cameraAim", {"op": "fn", "fn": _camera_aim})
	unmodify(&"StrandControl.gravityDirection")
	unmodify(&"Rope.gravityOffset")
	if p.values["changegravityforstrands"] == 1:
		modify(&"StrandControl.gravityDirection", {"op": "fn", "fn": func(_d, _sc): return screen_down()})
	if p.values["changegravityforhairstrands"] == 1:
		modify(&"Rope.gravityOffset", {"op": "fn", "fn": _hair_offset})
	if zoom and _setting_global("allowcamerazoomchanges") == 1:
		g.sceneLayer.zoomTo(p.values["zoom"] - 0.4, true)
		g.inGameMenu.updateZoomSlider()
	else:
		g.sceneLayer.updateCamera()


## Straight down on the screen, in scene space (the scene may be turned and mirrored).
func screen_down() -> Vector2:
	return g.sceneLayer.transform.basis_xform_inv(Vector2(0, 1)).normalized()


## A hanging strand of hair falls towards the screen's bottom (animtools: its own offset kept, and only for hair
## that hangs within 25 degrees of straight down).
func _hair_offset(go: float, _rope) -> float:
	if go <= _setting_global("minhairrangetochange") or go >= _setting_global("maxhairrangetochange"):
		return go
	var d := screen_down()
	var turn := rad_to_deg(atan2(-d.x, d.y))
	return turn + (go if _setting_global("hairgravityapplyoffset") == 1 else 0.0)


func _setting_global(key: String) -> float:
	return setting_value(key)


## The scene's rotation (degrees): the position's, the other way round while the screen is mirrored.
func _scene_rotation(_v, _o) -> float:
	var r: float = current.values["scenerotation"]
	return -r if g.mirrored and current.values["reversescreen"] != 2 else r


## Where the camera puts the scene's origin (screen pixels), animtools' rules by the file's version.
func _camera_aim(_v: Vector2, sl) -> Vector2:
	var pv: Dictionary = current.values
	var cur: float = sl.currentZoom
	var zoom: float = pv["zoom"]
	var cam := Vector2(pv["camerax"], pv["cameray"])
	var zp := Vector2(pv["zoompointx"], pv["zoompointy"])
	var old: float = _setting_global("allowoldzoompoint")
	var out: Vector2
	if current.version > 31 or old == -1:
		# the screen's centre in scene space: from where the position's camera puts it at the smallest zoom, along a
		# curve towards the zoom point (turned with the scene) as the player zooms in
		var z0 := minf(0.4, zoom)
		var z1 := maxf(1.4, zoom)
		var c0 := Vector2(g.screenSize.x / z0 / 2.0, g.screenSize.y / z0 / 2.0) - cam / z0
		var zr := zp.rotated(deg_to_rad(sl.rotation_degrees))
		var t := clampf((cur - z0) / (z1 - z0), 0.0, 1.0)
		t = 1.4 - 1.4 / (1.0 + t / 0.4)
		var c := c0 + t * (zr - c0)
		out = g.screenSize / 2.0 - c * cur
		if g.mirrored:
			out.x = g.screenSize.x - out.x
		return out
	# older files: a straight line from the position's camera, away from the zoom point as the player zooms
	var k: float = (cur - zoom) if (current.version > 10 or old < 1) else (cur - 0.4)
	out = cam - k * (zp - cam)
	if g.mirrored and pv["reversescreen"] != 2:
		out.x = g.screenSize.x - out.x
	return out


## The position's paths and numbers as a MainAnimation (her and his tweens, his feet, her knee, her torso).
static func build_animation(p) -> MainAnimation:
	var v: Dictionary = p.values
	var a := MainAnimation.new()
	a.herTween = _tween(v["hertweenstartx"], v["hertweenstarty"], v["hertweenstartang"],
		v["hertweenendx"], v["hertweenendy"], v["hertweenendangle"])
	var his := MirrorTween.new()
	his.mirror = Vector2(-1.0 if v["himreversed"] == 1 else 1.0, -1.0 if v["himflipped"] == 1 else 1.0)
	a.hisTween = _tween(v["histweenstartx"], v["histweenstarty"], v["histweenstartang"],
		v["histweenendx"], v["histweenendy"], v["histweenendangle"], his)
	a.herKneeTarget = Vector2(v["torsox"], v["torsoy"])
	a.altVector = Vector2(0, 1)
	a.altRange = v["offpathposmovement"]
	a.hisLeftFootTarget = Vector2(v["leftfootx"], v["leftfooty"])
	a.hisRightFootTarget = Vector2(v["rightfootx"], v["rightfooty"])
	a.torsoMinAng = v["torsominang"]
	a.torsoStartAng = v["torsostartangle"]
	a.torsoAngMultiplier = v["torsoanglemodifier"]
	a.torsoMinDist = v["torsomindistance"]
	a.torsoStartDist = v["torsostartdistance"]
	a.torsoDistMultiplier = v["torsodistancemultiplier"]
	a.torsoS2OffsetAng = v["torsoikoffsetang"]
	a.torsoEndRotation = v["torsoendrotationangle"]
	return a


## A tween from start / end points and angles (radians). animtools never turns on his skew at runtime (the skew keys
## are only read and written), so the tweens rotate.
static func _tween(sx: float, sy: float, sa: float, ex: float, ey: float, ea: float, t := LinearTween.new()) -> LinearTween:
	t.start = Transform2D(0.0, Vector2(sx, sy))
	t.end = Transform2D(0.0, Vector2(ex, ey))
	t.rotateStart(sa)
	t.rotateEnd(ea)
	return t


## His tween, mirrored (animtools' himreversed: left-right, himflipped: up-down) in the scene's space.
class MirrorTween extends LinearTween:
	var mirror := Vector2.ONE

	func tween(r: float) -> Transform2D:
		super.tween(r)
		if mirror != Vector2.ONE:
			var o := _tweenMatrix.origin
			_tweenMatrix = _tweenMatrix.scaled(mirror)
			_tweenMatrix.origin = o
		return _tweenMatrix
