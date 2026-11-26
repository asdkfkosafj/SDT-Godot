extends RefCounted
## Her arms in body positions (animtools): its 7 arm positions (Cupping Breast ... On Her Ass) and "Custom", added to
## her arm lists while the positions extension is on (Her.addArmPosition; the armoverhaul plugin offers its own on top
## of these), and the arms a position asks for.
##
## A position's arm types (armpostypeleft / right): -1 keeps her own arm (the player's; animtools kept the arm the
## position before had set, so after one with her hands on her breasts they stayed there), 0-4 the game's five, 5-11
## the 7 below, 12 Custom. Custom puts her hand on the position's own point (scene space, from the start to the end
## point along her stroke) at the position's hand angle (absolute, in scene space), closed or turned over as the file
## says; without a point it is On Legs. The arms a position sets are temporary: the character code keeps the player's arms, and
## they come back when the position ends (P2). The player can still change them while it is on.
##
## With animtools' preV33herarmonlegs setting on (a partial switches it), the game's On Legs takes the position's
## point too, as Custom does (older files used On Legs for that).
##
## While her left leg is behind him (PositionLayers), the game's "next to her leg" moves put her left arm behind
## her (g.changeLayer redirected), and her hand angles that count her own parts then also count her (animtools).

const NAMES := ["Cupping Breast", "Holding Breast", "On His Waist", "On His Chest", "Gripping Breast", "Gripping Thigh",
	"On Her Ass"]
const CUSTOM := "Custom"
const TAPS := ["On His Waist", "On His Chest"]   # her hand may tap him from these while she's held
const OWNER := "positions"
## The position keys her arms use (a change of one sets her arms again).
const KEYS := ["armpostypeleft", "armpostyperight", "armposx", "armposy", "armposxend", "armposyend", "armpos2x",
	"armpos2y", "armpos2xend", "armpos2yend", "handangler", "handanglel", "handrinverted", "handlinverted",
	"userightclosehand", "useleftclosehand", "behindleg"]

var _ext
var player_arms := ["", ""]    # the player's arm choices (names) while a position has set hers; "" = none set
var held := ["", ""]           # the arm (name) the position put her left / right arm in; "" = none
var _setting := false          # a position is setting her arms now (not the player)
var _anti_her: Node2D = null   # turned against her: a hand angle counted in scene space for an arm inside her


func _init(ext) -> void:
	_ext = ext


func start() -> void:
	_anti_her = Node2D.new()
	for n in NAMES:
		Her.addArmPosition(n, _set_up.bind(n, true), _set_up.bind(n, false), OWNER, {"tap": n in TAPS})
	Her.addArmPosition(CUSTOM, _set_up.bind(CUSTOM, true), _set_up.bind(CUSTOM, false), OWNER, {"tap": true})
	_ext.hook_after(&"Her.setLeftArmPosition", func(_c): _arm_set(true))
	_ext.hook_after(&"Her.setRightArmPosition", func(_c): _arm_set(false))
	_ext.hook_before(&"IKController.tap", _tap)
	_ext.hook_before(&"Her.startArmsPassOut", _drop, -10)   # before armoverhaul's, which drops by these args
	_ext.modify(&"InGameMenu.savedArms", {"op": "fn", "fn": _saved_arms})
	_ext.on_tick(_tick)
	g.inGameMenu.updateArmsList()


func stop() -> void:
	Her.removeArmPositions(OWNER)
	if g.inGameMenu != null:
		g.inGameMenu.updateArmsList()
	if _anti_her != null:
		_anti_her.free()
		_anti_her = null


static func _type_name(t: int) -> String:
	if t >= 0 and t < Her.GAME_ARM_POSITIONS:
		return Her.armPositions[t]
	if t >= 5 and t <= 11:
		return NAMES[t - 5]
	return CUSTOM if t == 12 else ""


## A position's arms (null: back to the player's).
func show(values) -> void:
	var her: Her = g.her
	for left in [true, false]:
		var s := 0 if left else 1
		if values == null:   # no position: the player's arm back
			held[s] = ""
			if player_arms[s] != "":
				var back := Her.armPositions.find(player_arms[s])
				player_arms[s] = ""
				if back >= 0:
					_put(her, left, back)
			continue
		var want := _type_name(int(values["armpostypeleft" if left else "armpostyperight"]))
		if want == "":   # keep (-1): her own arm (not one an earlier position set), set up for this position's numbers
			held[s] = ""
			var own := Her.armPositions.find(player_arms[s]) if player_arms[s] != "" else -1
			player_arms[s] = ""
			_put(her, left, own)
			continue
		var i := Her.armPositions.find(want)
		if i < 0:
			continue
		if player_arms[s] == "":
			player_arms[s] = _name(left)
		held[s] = want
		_put(her, left, i)
	g.inGameMenu.updateArmsList()


## Whether the position holds that arm now (it set it, and it is still there): other code that moves her arms by
## itself (armoverhaul's dynamic arms) leaves it alone then.
func holds(left: bool) -> bool:
	var s := 0 if left else 1
	return held[s] != "" and _ext.current != null and _name(left) == held[s]


func _put(her: Her, left: bool, i: int) -> void:
	_setting = true
	if left:
		her.setLeftArmPosition(i)
	else:
		her.setRightArmPosition(i)
	_setting = false


func _name(left: bool) -> String:
	return Her.armPositions[g.her.currentLeftArmPosition if left else g.her.currentRightArmPosition]


## After her arm changed: the player's own choice while a position is on (kept for the code and for the end), and the
## hand angle chain of her left arm while it is out of her.
func _arm_set(left: bool) -> void:
	var s := 0 if left else 1
	if not _setting and player_arms[s] != "":
		player_arms[s] = _name(left)
	if _legs_custom(left):
		_set_up_custom(g.her, left)
	if left:
		_fix_left_chain()


## Her arm on the position's point: Custom, or On Legs with preV33herarmonlegs on (animtools' usingcustomleftarm).
func _on_point(left: bool) -> bool:
	return _name(left) == CUSTOM or _legs_custom(left)


func _legs_custom(left: bool) -> bool:
	var v = _values()
	var s := "armpos2" if left else "armpos"
	return v != null and (g.her.currentLeftArmPosition if left else g.her.currentRightArmPosition) == 1 		and _ext.setting_value("preV33herarmonlegs") == 1 and v[s + "x"] != -5000 and v[s + "y"] != -5000


## The arm names the character code saves: the player's, not a position's.
func _saved_arms(names: Array, _menu) -> Array:
	return [player_arms[0] if player_arms[0] != "" else names[0], player_arms[1] if player_arms[1] != "" else names[1]]


func _values():
	return null if _ext.current == null else _ext.current.values


# ---------------------------------------------------------------- setting her arm up

## animtools' (and armoverhaul's) arm positions, written from the mod's behaviour.
func _set_up(her: Her, n: String, left: bool) -> void:
	var ik: IKController = her.leftArmIK if left else her.rightArmIK
	var on_him: Vector2 = Her.leftHandOnHim if left else Her.rightHandOnHim
	var bs: float = g.characterControl.breastSize
	ik.stopDropping()
	if left:   # first behind her, then in her own layer by her leg (both arms on him stay behind)
		g.changeLayer(her.leftArmContainer, g.backLayer)
		if n not in ["On His Waist", "On His Chest"]:
			g.changeLayer(her.leftArmContainer, her, her.leftLegContainer)
	var breast = her.torsoBack.leftBreast if left else her.torso.midLayer.rightBreast
	var breast_chain: Array = [breast.nipple, breast, her.torsoBack] if left else \
		[breast.nipple, breast, her.torso.midLayer, her.torso, her]
	match n:
		"Cupping Breast":
			ik.newTarget(Vector2(-40 + bs / 10.0, 95 - bs / 8.0), breast.nipple, true)
			ik.reversedEnd = true
			ik.setEndRotationTarget(-168 + bs / 12.0, breast_chain)
			(her.leftBreastController if left else her.rightBreastController).updateFirmness(bs, true)
		"Holding Breast":
			ik.newTarget(Vector2(-50 - minf(110, bs), 80 - bs / 2.65), breast.nipple, true)
			ik.reversedEnd = true
			ik.setEndRotationTarget((-160.0 if left else -165.0) + minf(75.0 if left else 80.0, bs * 1.2), breast_chain)
		"On His Waist":
			ik.newTarget(on_him + (Vector2(-20, -106) if left else Vector2(-12, -36)), g.him.rightLeg, true)
			ik.setEndRotationTarget(-185 if left else -183, [g.him.rightLeg, g.him])
		"On His Chest":
			ik.newTarget(on_him + (Vector2(136, -246) if left else Vector2(144, -176)), g.him.torsoLayer, true)
			ik.setEndRotationTarget(-175 if left else -173, [g.him.torsoLayer, g.him])
		"Gripping Breast":
			ik.newTarget(Vector2(-150 + bs / 1.8, -25 + bs / 13.0), breast.nipple, true)
			ik.setEndRotationTarget(-70, breast_chain)
			_close(her, left, true)
		"Gripping Thigh":
			ik.newTarget(Vector2(105, -90) if left else Vector2(95, -75), her.torsoBack.backside, true)
			ik.setEndRotationTarget(-22, [her.torsoBack.backside, her.torsoBack] + ([] if left else [her]))
			_close(her, left, true)
		"On Her Ass":
			ik.reversedEnd = true
			ik.newTarget(Vector2(-5, -80), her.torsoBack.backside, true)
			ik.setEndRotationTarget(36, [her.torsoBack.backside, her.torsoBack] + ([] if left else [her]))
		CUSTOM:
			_set_up_custom(her, left)


## Custom: the position's point and hand angle; On Legs without a point (or without a position).
func _set_up_custom(her: Her, left: bool) -> void:
	var ik: IKController = her.leftArmIK if left else her.rightArmIK
	var v = _values()
	var px := "armpos2x" if left else "armposx"
	var py := "armpos2y" if left else "armposy"
	if v == null or v[px] == -5000 or v[py] == -5000:
		if left:
			ik.newTarget(her.leftHandOnLegs, her.leftLegContainer.leg, true)
			ik.setEndRotationTarget(-50, [her.torso.leg, her.torso])
		else:
			ik.newTarget(her.rightHandOnLegs, her.torso.leg, true)
			ik.setEndRotationTarget(-50, [her.torso.leg, her.torso, her])
		return
	ik.newTarget(_custom_point(v, left), g.sceneLayer, true)
	var a: float = v["handanglel" if left else "handangler"]
	ik.setEndRotationTarget(-50.0 if a == -5000 else a, _scene_chain(her, left))
	ik.reversedEnd = v["handlinverted" if left else "handrinverted"] == 1
	if v["useleftclosehand" if left else "userightclosehand"] == 1:
		_close(her, left, true)


## The hand angle counted in scene space: against her own turn for an arm inside her.
func _scene_chain(her: Her, left: bool) -> Array:
	if left and her.leftArmContainer.parent == her:
		return [_anti_her]
	return []


func _custom_point(v: Dictionary, left: bool) -> Vector2:
	var s := "armpos2" if left else "armpos"
	var p := Vector2(v[s + "x"], v[s + "y"])
	if v[s + "xend"] != -5000 and v[s + "yend"] != -5000:
		var u := clampf((g.her.pos + 0.25) / 1.27, 0.0, 1.0)
		p = p.lerp(Vector2(v[s + "xend"], v[s + "yend"]), u)
	return p


## A closed hand; the left one also shows the hand drawn over her breast (her.leftHandOver), as armoverhaul does.
func _close(her: Her, left: bool, closed: bool) -> void:
	if left:
		her.leftHandClosed = closed   # direct: her hand's state, as her arm positions set it (the game has no method)
		if closed:
			g.changeLayer(her.leftHandOver, her.leftHandOverContainer)
			her.leftHandOver.visible = true   # direct: her hand's state, as her arm positions set it (the game has no method)
	else:
		her.rightHandClosed = closed   # direct: her hand's state, as her arm positions set it (the game has no method)


## While her left arm is out of her (her leg behind him), a hand angle that counts her parts also counts her.
func _fix_left_chain() -> void:
	var her: Her = g.her
	var ik: IKController = her.leftArmIK
	if her.leftArmContainer.parent == her or her in ik.endRotationTargets:
		return
	for t in ik.endRotationTargets:
		if t is FlashDisplayObject and _inside(t, her):
			ik.setEndRotationTarget(ik.endRotationAngle, ik.endRotationTargets + [her])
			return


static func _inside(o: FlashDisplayObject, her: Her) -> bool:
	var p = o
	while p != null:
		if p == her:
			return true
		p = p.parent
	return false


# ---------------------------------------------------------------- every tick, taps, drops

func _tick() -> void:
	var her: Her = g.her
	_anti_her.rotation_degrees = -her.rotation_degrees
	var v = _values()
	if v == null:
		return
	for left in [true, false]:   # Custom with an end point: the hand moves along her stroke
		var s := "armpos2" if left else "armpos"
		if _on_point(left) and v[s + "x"] != -5000 and v[s + "y"] != -5000 and v[s + "xend"] != -5000 \
				and v[s + "yend"] != -5000 and not (her.leftArmIK if left else her.rightArmIK).dropping:
			(her.leftArmIK if left else her.rightArmIK).newTarget(_custom_point(v, left), g.sceneLayer, true)


## allowleftarmtap / allowrightarmtap = 0: that hand does not tap him.
func _tap(c) -> void:
	var v = _values()
	if v == null:
		return
	var her: Her = g.her
	if c.obj == her.leftArmIK and v["allowleftarmtap"] == 0 or c.obj == her.rightArmIK and v["allowrightarmtap"] == 0:
		c.cancel()


## allowleftarmdrop / allowrightarmdrop = 0: that arm stays where it is when she passes out.
func _drop(c) -> void:
	var v = _values()
	if v == null:
		return
	if v["allowleftarmdrop"] == 0:
		c.args[0] = false
	if v["allowrightarmdrop"] == 0:
		c.args[1] = false
