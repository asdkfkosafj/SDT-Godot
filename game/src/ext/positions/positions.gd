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
## and Custom); back to the game's default. Him reversed / flipped and body contact come in later stages. Until the
## position browser exists, the developer panel (Tools > Positions) loads a position by name.
##
## A position is a temporary state: it does not change the player's saved settings; switching the extension off (or
## Vanilla mode) gives the game's default animation back.

const Position := preload("res://src/ext/positions/position.gd")
const Library := preload("res://src/ext/positions/position_library.gd")
const Fields := preload("res://src/ext/positions/position_fields.gd")
const Props := preload("res://src/ext/positions/position_props.gd")
const Layers := preload("res://src/ext/positions/position_layers.gd")
const Arms := preload("res://src/ext/positions/position_arms.gd")

const ANIM := "position"   # the AnimationControl key of the applied position
## The value points an applied position modifies (taken off when it ends; the arms' own stay while the extension is on).
const POSITION_POINTS: Array[StringName] = [&"SceneLayer.rotation", &"SceneLayer.cameraAim", &"SaveData.sceneZoom",
	&"IKController.endLimit", &"HimMaleBody.armPoint", &"HimMaleBody.shoulderPoint", &"HimMaleBody.handRotation"]

var library = Library.new()
var current = null         # the applied Position (null: the game's default)
var props = Props.new()
var layers = null          # PositionLayers (her leg / breast behind him, her shadow)
var arms = null            # PositionArms (animtools' arm positions, a position's arms)


func _init() -> void:
	id = "positions"
	title = "Positions"
	description = "animtools' body positions: positions from .txt files in Mods/Positions (work in progress: developer panel only)."
	default_enabled = true


func _enable() -> void:
	rescan()
	props.start()
	layers = Layers.new(self)
	layers.start()
	arms = Arms.new(self)
	arms.start()
	on_tick(_tick)
	menu_control("dev_tools", "Positions", MenuSchema.choice("Position", "Load a body position (animtools .txt)",
		func(): return ["(game default)"] + Array(library.names),
		func(): return "(game default)" if current == null else current.name,
		func(v): clear() if v == "(game default)" else load_position(v)))


func _disable() -> void:
	clear()
	props.stop()
	if arms != null:
		arms.stop()


func positions_root() -> String:
	return Flash.mods_dir("Positions")


func rescan() -> void:
	library.scan(positions_root())


## Reads a position by name (see PositionLibrary.find); a partial one applies to the current position. null when not
## found or not readable.
func read_position(given: String):
	var n: String = library.find(given)
	if n == "":
		return null
	var text := FileAccess.get_file_as_string(library.path_of(n))
	if text == "" and FileAccess.get_open_error() != OK:
		return null
	var p = Position.from_text(text, n, current)
	p.path = library.path_of(n)
	return p


## Loads and applies a position by name; false when there is none by that name.
func load_position(given: String) -> bool:
	var p = read_position(given)
	if p == null:
		push_warning("Positions: no position \"%s\"" % given)
		return false
	apply(p)
	return true


func apply(p) -> void:
	if current == null and g.sceneLayer != null:
		player_zoom = g.sceneZoom
	current = p
	var ac: AnimationControl = g.animationControl
	_anim = build_animation(p)
	ac.addAnimation(ANIM, _anim)
	ac.setAnimation(ANIM)
	_apply_camera(p)
	_apply_limits(p)
	_apply_his_arm(p)
	props.show(p.values)
	layers.show(p.values)
	arms.show(p.values)
	_knee_moves = p.values["torsox"] != p.values["torsox2"] or p.values["torsoy"] != p.values["torsoy2"] \
		or (p.values["savedBodySize"] != -999 and _setting_global("enablelegmountbodyscaling") == 1)
	_knee = Vector2(INF, INF)
	_update_knee()


func _tick() -> void:
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
	var t: Transform2D = _anim.hisTween._tweenMatrix
	var off := Vector2(t.x.y, t.x.x) * (t.origin.y - 120.0)
	if (v["himreversed"] == 1) != (v["himflipped"] == 1):
		off.y = -off.y
	return Vector2(lerpf(v["shoulderpointstartx"], v["shoulderpointendx"], u),
		lerpf(v["shoulderpointstarty"], v["shoulderpointendy"], u)) + off


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


# ---------------------------------------------------------------- joint limits

## The game keeps her leg's and her hands' end joints within 1.22 rad; animtools lifted that for newer files (her
## leg from posversion 29, her hands from 32 or with its preventswitchinganglehandsforoldpositions setting).
func _apply_limits(p) -> void:
	unmodify(&"IKController.endLimit")
	var leg: bool = p.version >= 29
	var hands: bool = p.version >= 32 or _setting_global("preventswitchinganglehandsforoldpositions") != 0
	if leg or hands:
		modify(&"IKController.endLimit", {"op": "fn", "fn": func(lim: float, ik) -> float:
			var h = g.her
			if ik == h.torsoIK:
				return INF if leg else lim
			if ik == h.leftArmIK or ik == h.rightArmIK:
				return INF if hands else lim
			return lim})


## Back to the game's default animation.
func clear() -> void:
	var had := current != null
	current = null
	for n in POSITION_POINTS:
		unmodify(n)
	if g.animationControl != null:
		g.animationControl.removeAnimation(ANIM)
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
func _apply_camera(p) -> void:
	unmodify(&"SceneLayer.rotation")
	unmodify(&"SceneLayer.cameraAim")
	unmodify(&"SaveData.sceneZoom")
	modify(&"SaveData.sceneZoom", {"op": "fn", "fn": func(_v, _o): return player_zoom})
	if _setting_global("allowcamerarotationchanges") == 1:
		modify(&"SceneLayer.rotation", {"op": "fn", "fn": _scene_rotation})
	if _setting_global("allowcameraxychanges") == 1:
		modify(&"SceneLayer.cameraAim", {"op": "fn", "fn": _camera_aim})
	if _setting_global("allowcamerazoomchanges") == 1:
		g.sceneLayer.zoomTo(p.values["zoom"] - 0.4, true)
		g.inGameMenu.updateZoomSlider()
	else:
		g.sceneLayer.updateCamera()


func _setting_global(key: String) -> float:
	return float(Fields.SETTINGS[key])


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
	a.hisTween = _tween(v["histweenstartx"], v["histweenstarty"], v["histweenstartang"],
		v["histweenendx"], v["histweenendy"], v["histweenendangle"])
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
static func _tween(sx: float, sy: float, sa: float, ex: float, ey: float, ea: float) -> LinearTween:
	var t := LinearTween.new()
	t.start = Transform2D(0.0, Vector2(sx, sy))
	t.end = Transform2D(0.0, Vector2(ex, ey))
	t.rotateStart(sa)
	t.rotateEnd(ea)
	return t
