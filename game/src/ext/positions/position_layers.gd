extends RefCounted
## Where a position draws some of her parts (animtools' behindleg, leftbreastbehind, hidehershadow):
## - her left leg behind him: her left leg container goes into a layer at the bottom of the scene, which takes her
##   own transform every tick, so the leg stays where it was (her transform x her torso's) but draws under him;
## - her left breast behind his penis: her left breast and its costume the same way (the breast keeps her skin
##   colour: it no longer sits in torsoBack, which carries it);
## - her shadow off: the floor shadow drawn with her left calf.
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
	else:
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


## Every tick: the layers take her transform (and her torso's for the breast), and the moved breast her skin colour.
## They stay under him (the game puts him back at the bottom of the scene when his penis goes back in).
func _follow() -> void:
	var her: Her = g.her
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
