extends RefCounted
## Where a position draws some of her parts (animtools' behindleg, leftbreastbehind, hidehershadow):
## - her left leg behind him: her left leg container goes into a layer at the bottom of the scene, which takes her
##   own transform every tick, so the leg stays where it was (her transform x her torso's) but draws under him;
## - her left breast behind his penis: her left breast and its costume the same way (the breast keeps her skin
##   colour: it no longer sits in torsoBack, which carries it), and its nipple piercing with it (the game keeps that in
##   her torso layer, placed from the breast each tick: here again after the layer has moved, so it does not lag);
## - her shadow off: the floor shadow drawn with her left calf;
## - her near (right) arm over her hair while a position has it up (her hand above her shoulder, as when her hands
##   are tied above her head): the arm and forearm go above the hair layers in front of her (and the hair mods drawn
##   there, such as an earring made as a hair mod), under his arm; they go back under the hair when it comes down.
## The game moves her left leg between layers in some places (g.changeLayer with the leg): not while it is out.
## Everything goes back where it was when the position ends.

var _ext   # the positions extension
var leg_out := false
var breast_out := false
var _leg_holder: FlashSprite = null
var _breast_holder: FlashSprite = null
var _breast_cos_holder: FlashSprite = null
var _leg_home := []        # [parent, index]
var _breast_home := []
var _breast_cos_home := []
var _piercing_home := []
var arm_over_hair := false
var _on := false           # a position's layers are applied (the arm test runs)

const ARM_UP := 0.25       # her arm is up when her hand is this far above her shoulder (times the distance between)
const ARM_DOWN := 0.1      # and down again below this (no flicker)


func _init(ext) -> void:
	_ext = ext


func start() -> void:
	_ext.hook_before(&"g.changeLayer", _guard)
	_ext.on_late_tick(_follow)


## Applies a position's layer keys (null: the game's own layers).
func show(values) -> void:
	_set_leg(values != null and values["behindleg"] == 1)
	_set_breast(values != null and values["leftbreastbehind"] == 1)
	_shadow().visible = values == null or values["hidehershadow"] == 0
	_on = values != null
	if not _on:
		_set_arm(false)


func _shadow() -> FlashDisplayObject:
	return g.her.leftLegContainer.leg.getChildAt(0).getChildAt(0)


func _set_leg(out: bool) -> void:
	if out == leg_out:
		return
	var leg: FlashDisplayObject = g.her.leftLegContainer
	if out:
		_leg_holder = _holder("positionLeftLeg")
		_leg_home = _take(leg, _leg_holder)
	else:
		_put_back(leg, _leg_home)
		_leg_holder = _drop(_leg_holder)
	leg_out = out
	_follow()


func _set_breast(out: bool) -> void:
	if out == breast_out:
		return
	var her: Her = g.her
	var breast: FlashDisplayObject = her.torsoBack.leftBreast
	var cos: FlashDisplayObject = her.torsoBackCostume.breastCostume
	if out:
		_breast_cos_holder = _holder("positionLeftBreastCostume")
		_breast_cos_home = _take(cos, _breast_cos_holder)
		_breast_holder = _holder("positionLeftBreast")
		_breast_home = _take(breast, _breast_holder)
		_piercing_home = _take(her.torso.leftNipplePiercing, _breast_holder)   # (over the breast; torsoBack's space)
	else:
		_put_back(her.torso.leftNipplePiercing, _piercing_home)
		_put_back(breast, _breast_home)
		_put_back(cos, _breast_cos_home)
		breast.filters = []
		_breast_holder = _drop(_breast_holder)
		_breast_cos_holder = _drop(_breast_cos_holder)
	breast_out = out
	_follow()


## A layer at the bottom of the scene (under him and her).
func _holder(n: String) -> FlashSprite:
	var s := FlashSprite.new()
	s.flash_name = n
	g.sceneLayer.addChildAt(s, 0)
	return s


func _drop(s: FlashSprite) -> FlashSprite:
	if s != null and s.parent != null:
		s.parent.removeChild(s)
	return null


func _take(o: FlashDisplayObject, into: FlashSprite) -> Array:
	var home := [o.parent, o.parent.getChildIndex(o)]
	into.addChild(o)
	return home


func _put_back(o: FlashDisplayObject, home: Array) -> void:
	var p: FlashSprite = home[0]
	p.addChildAt(o, mini(int(home[1]), p.numChildren))


## Her near arm above (or back under) the hair layers in the front layer.
func _set_arm(over: bool) -> void:
	if over == arm_over_hair:
		if over:
			_lift_arm()   # (the game moves the hair layers when he goes in front of her and back)
		return
	arm_over_hair = over
	if over:
		_lift_arm()
	else:
		_lower_arm()


## The hair layers in the front layer (her hair over her, its costume, and layers plugins add over them).
func _hair_layers(front: FlashSprite) -> Array:
	var out := [g.hairCostumeUnderOver, g.hairOverContainer, g.hairCostumeOver]
	for i in front.numChildren:
		var c: FlashDisplayObject = front.getChildAt(i)
		if c.flash_name == "dynamicHairOverExtended":
			out.append(c)
	return out.filter(func(h): return h != null and h.parent == front)


func _arm_parts() -> Array:
	var her: Her = g.her
	var front: FlashSprite = g.frontLayer
	if her.rightArmContainer.parent != front or her.rightForeArmContainer.parent != front:
		return []
	return [front, her.rightArmContainer, her.rightForeArmContainer]


func _lift_arm() -> void:
	var parts := _arm_parts()
	if parts.is_empty():
		return
	var front: FlashSprite = parts[0]
	var top := -1
	for h in _hair_layers(front):
		top = maxi(top, front.getChildIndex(h))
	if front.getChildIndex(parts[1]) < top:   # (lands just above the top one)
		front.setChildIndex(parts[1], top)
	if front.getChildIndex(parts[2]) < front.getChildIndex(parts[1]):   # the forearm just above the arm
		front.setChildIndex(parts[2], front.getChildIndex(parts[1]))


## Back under the hair: under the lowest hair layer above him (while he is in front of her: the game puts the hair
## that hangs over her under him then), as the game has it.
func _lower_arm() -> void:
	var parts := _arm_parts()
	if parts.is_empty():
		return
	var front: FlashSprite = parts[0]
	var above := front.getChildIndex(g.him) if g.him.parent == front else -1
	var home := front.numChildren
	for h in _hair_layers(front):
		var i := front.getChildIndex(h)
		if i > above:
			home = mini(home, i)
	if front.getChildIndex(parts[1]) > home:
		front.setChildIndex(parts[1], home)
	var at := front.getChildIndex(parts[1]) + 1
	if front.getChildIndex(parts[2]) > at:
		front.setChildIndex(parts[2], at)


## Her near arm is up: her hand above her shoulder (in her torso's space), with some room both ways.
func _arm_up() -> bool:
	var her: Her = g.her
	var inv: Transform2D = (her.flash_global_transform() * her.torso.transform).affine_inverse()
	var shoulder: Vector2 = inv * her.rightArmContainer.upperArm.localToGlobal(Vector2())
	var hand: Vector2 = inv * her.rightForeArmContainer.upperArm.foreArm.hand.localToGlobal(Vector2())
	var up := (shoulder.y - hand.y) / maxf(1.0, shoulder.distance_to(hand))
	return up > (ARM_DOWN if arm_over_hair else ARM_UP)


## Every tick: the layers take her transform (and her torso's for the breast), and the moved breast her skin colour.
## They stay under him (the game puts him back at the bottom of the scene when his penis goes back in).
func _follow() -> void:
	var her: Her = g.her
	if _on or arm_over_hair:
		_set_arm(_on and _arm_up())
	var sl: SceneLayer = g.sceneLayer
	if g.him.parent == sl:
		var top := -1
		for h in [_leg_holder, _breast_holder, _breast_cos_holder]:
			if h != null:
				top = maxi(top, sl.getChildIndex(h))
		if top > sl.getChildIndex(g.him):
			sl.setChildIndex(g.him, top)
	if _leg_holder != null:
		_leg_holder.transform = her.transform
	if _breast_holder != null:   # (the breast's own parents carry her torso's transform; the leg container its own)
		_breast_holder.transform = her.transform * her.torsoBack.transform
		_breast_cos_holder.transform = her.transform * her.torsoBackCostume.transform
		var f: Array = her.torsoBack.filters
		var breast: FlashDisplayObject = her.torsoBack.leftBreast
		if breast.filters != f:
			breast.filters = f
		her.updateNipplePiercing()   # (the game placed it from where the layer was last tick)


## While her left leg is out: the game's moves of the leg itself are skipped, and "into her, next to her leg" (her left
## arm on her legs, on her breasts...) puts the part behind her instead (where animtools leaves it).
func _guard(c) -> void:
	if not leg_out:
		return
	var leg: FlashDisplayObject = g.her.leftLegContainer
	if c.args[0] == leg or c.args[1] == leg:
		c.cancel()
	elif c.args[2] == leg:
		c.args[1] = g.backLayer
		c.args[2] = null
		c.args[3] = false
