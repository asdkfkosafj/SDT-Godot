class_name MainAnimation
extends RefCounted
## Port of obj.animation.MainAnimation: the tweens that place her and him for a given position.

var herTween: LinearTween
var herKneeTarget: Vector2
var altVector: Vector2
var altRange: float
var torsoMinAng: float
var torsoStartAng: float
var torsoAngMultiplier: float
var torsoMinDist: float
var torsoStartDist: float
var torsoDistMultiplier: float
var hisTween: LinearTween
var hisLeftFootTarget: Vector2
var hisRightFootTarget: Vector2
var posScaling: Callable
var tipPosEstimate: float = 0.15
var penisLength: float = -1.0
## Port addition (body positions, see AnimationControl.applyTorsoIK): her torso IK's leg angle offset and end
## rotation while this animation runs; NAN (the game's two) leaves the IK's own.
var torsoS2OffsetAng: float = NAN
var torsoEndRotation: float = NAN


func _init() -> void:
	posScaling = noScaling


func getHerMatrix(p: float, tilt: float) -> Transform2D:
	p = posScaling.call(p)
	var m := herTween.tween(p)
	m.origin += Vector2(altVector.x * altRange * tilt, altVector.y * altRange * tilt)
	return m


func getHisMatrix(p: float) -> Transform2D:
	p = posScaling.call(p)
	return hisTween.tween(p)


var estimateTipPos: float:
	get:
		if penisLength != g.him.currentPenisLength:
			var herLen := herTween.translationLength
			var hisLen := hisTween.translationLength
			var total := herLen + hisLen
			var tip: Vector2 = g.sceneLayer.globalToLocal(g.him.getPenisTipPoint())
			var base: Vector2 = g.sceneLayer.globalToLocal(g.him.getPenisBasePoint())
			# (sic) the original subtracts base.x from tip.y
			var length := Maths.vectorLength(Vector2(tip.x - base.x, tip.y - base.x)) - 65.0
			tipPosEstimate = (total - length) / total
		return tipPosEstimate


func noScaling(p: float) -> float:
	return p
