class_name IKController
extends RefCounted
## Port of obj.animation.IKController: two-bone IK (plus an end segment) with target springing, hand tapping,
## slipping and dropping (limbs going limp).

var dropping := false
var reversed: int = 1
var coordinateSpace: FlashDisplayObject
var s1: FlashDisplayObject
var s2: FlashDisplayObject
var s3: FlashDisplayObject
var s1L: float
var s1LSq: float
var s1OffsetAng: float
var s1StartPoint: Vector2
var s2L: float
var s2LSq: float
var s2OffsetAng: float
var s2StartPoint: Vector2
var s3StartPoint: Vector2
var lastS1Ang: float = 0.0
var lastS2Ang: float = 0.0
var s1AS: float = 0.0
var s2AS: float = 0.0
var maxL: float
var scaling: float = 1.0
var endRotationTargets: Array = []
var endRotationAngle: float = 0.0
var v := Vector2()
var offsetAng: float = 0.0
var totalL: float = 0.0
var totalLSq: float = 0.0
var minTotalLSq: float = 0.0
var s1Ang: float = 0.0
var s2Ang: float = 0.0
var s3Ang: float = 0.0
var m1Ang: float = 0.0
var m2Ang: float = 0.0
var m1 := Transform2D.IDENTITY
var m2 := Transform2D.IDENTITY
var m3 := Transform2D.IDENTITY
var springV := Vector2()
var s3Mass: float = 6.0
var reversedEnd := false
var maxSlipDist: float = 65.0
var slipping := false
var slipTimer: int = 0
var slipTime: float = 15.0
const gravity := 15.0
var speed := Vector2()
var friction: float = 0.6
var mass: float = 10.0
var currentPoint := Vector2()
var localTargetPoint := Vector2()
var originalTarget := Vector2()
var targetPoint := Vector2()
var targetPointCoordinateSpace: FlashDisplayObject
var tapping := false
var tapVector := Vector2()
var tapDist: float = 0.0
var tapSpeed: float = 0.0
var tapMultiplier: float = 1.0
var tapPower: float = 0.0
const maxTapPower := 4.0


func _init(space: FlashDisplayObject, seg1: FlashDisplayObject, seg2: FlashDisplayObject, seg3: FlashDisplayObject,
		isReversed: bool = false) -> void:
	coordinateSpace = space
	s1 = seg1
	s2 = seg2
	s3 = seg3
	calculateLengths()
	s1OffsetAng = g.getRadAngle(s2.x, s2.y)
	s2OffsetAng = g.getRadAngle(s3.x, s3.y)
	s1StartPoint = Vector2(s1.x, s1.y)
	s2StartPoint = Vector2(s2.x, s2.y)
	s3StartPoint = Vector2(s3.x, s3.y)
	currentPoint = Vector2(0, 0)
	targetPoint = currentPoint
	speed = Vector2()
	targetPointCoordinateSpace = g.sceneLayer
	reversed = -1 if isReversed else 1


func newSegments(seg1: FlashDisplayObject, seg2: FlashDisplayObject, seg3: FlashDisplayObject, recalc: bool = true) -> void:
	s1 = seg1
	s2 = seg2
	s3 = seg3
	if recalc:
		calculateLengths()
		s1OffsetAng = g.getRadAngle(s2.x, s2.y)
		s2OffsetAng = g.getRadAngle(s3.x, s3.y)
		s1StartPoint = Vector2(s1.x, s1.y)
		s2StartPoint = Vector2(s2.x, s2.y)
		s3StartPoint = Vector2(s3.x, s3.y)


func newTarget(p: Vector2, space: FlashDisplayObject, jump: bool = false) -> void:
	originalTarget = p
	targetPoint = p
	if space:
		targetPointCoordinateSpace = space
	if jump:
		mass = 1
		currentPoint = targetPoint
	elif targetPointCoordinateSpace:
		jumpTo(targetPointCoordinateSpace.localToGlobal(currentPoint))


func calculateLengths() -> void:
	s1LSq = (s2.x * s2.x + s2.y * s2.y) * scaling * scaling
	s1L = sqrt(s1LSq)
	s2LSq = (s3.x * s3.x + s3.y * s3.y) * scaling * scaling
	s2L = sqrt(s2LSq)
	maxL = s1L + s2L - 5.0
	minTotalLSq = (s1L - s2L) * (s1L - s2L) + 10.0


func getMaxLength() -> float:
	return s1L + s2L


func rescale(s: float) -> void:
	scaling = s
	calculateLengths()


func setEndRotationTarget(angle: float = 0.0, targets: Array = []) -> void:
	endRotationTargets = targets if targets != null else []
	endRotationAngle = angle


func startDropping(time: float = 15.0) -> void:
	if not dropping:
		slipping = true
	dropping = true
	slipTime = time
	slipTimer = 0


func stopDropping() -> void:
	dropping = false
	slipping = false


func startTrackingTarget(heavy: bool = false) -> void:
	dropping = false
	slipping = false
	tapping = false
	s3Mass = 10
	if heavy:
		mass = 6


func drop() -> void:
	if slipping:
		slipTimer += 1
		slip(slipTimer / slipTime * slipTimer / slipTime * 40.0, false)
		if slipTimer >= slipTime:
			slipping = false
		updateTarget()
		localTargetPoint = coordinateSpace.globalToLocal(globalPoint)
		trackTarget()
	else:
		var down := getDown()
		s1AS += asin(sin(m1Ang - down)) * 0.05
		s2AS += asin(sin(m2Ang + PI)) * 0.05
		s1AS *= 0.8
		s2AS *= 0.8
		var fold := maxf(0.0, 0.1 + m2Ang * 0.5)
		s1AS -= fold * 0.5
		s2AS -= fold
		s1Ang += s1AS
		s2Ang += s2AS
		m1Ang = offsetAng - s1Ang - s1OffsetAng
		m2Ang = s2Ang + s1Ang + s1OffsetAng - s2OffsetAng
		m2Ang = maxf(-PI * 0.7, minf(0.0, m2Ang))
		m1 = Transform2D(m1Ang, Vector2(scaling, scaling), 0.0, s1StartPoint)
		m2 = Transform2D(m2Ang, s2StartPoint)
		s3Ang *= 0.8
		m3 = Transform2D(s3Ang, Vector2(-1, 1) if reversedEnd else Vector2.ONE, 0.0, s3StartPoint)


func update(start = null, apply: bool = false) -> void:
	updateTarget()
	localTargetPoint = coordinateSpace.globalToLocal(globalPoint)
	if dropping:
		drop()
	else:
		trackTarget(start)
	if apply:
		s1.transform = section1Matrix
		s2.transform = section2Matrix
		s3.transform = section3Matrix


func trackTarget(start = null) -> void:
	if start != null:
		s1.x = start.x
		s1.y = start.y
		s1StartPoint = start
	v = Vector2(localTargetPoint.x - s1StartPoint.x, localTargetPoint.y - s1StartPoint.y)
	offsetAng = g.getRadAngle(v.x, v.y)
	totalLSq = maxf(minTotalLSq, v.x * v.x + v.y * v.y)
	totalL = maxf(1.0, sqrt(totalLSq))
	if totalL > maxL:
		totalL = maxL
		totalLSq = totalL * totalL
	springV = Vector2(-v.x / maxL, -v.y / maxL)
	lastS1Ang = s1Ang
	lastS2Ang = s2Ang
	s1Ang = -acos((totalLSq + s1LSq - s2LSq) / (2.0 * totalL * s1L)) * reversed
	m1Ang = offsetAng - s1Ang - s1OffsetAng
	s2Ang = -acos((totalLSq + s2LSq - s1LSq) / (2.0 * totalL * s2L)) * reversed
	m2Ang = s2Ang + s1Ang + s1OffsetAng - s2OffsetAng
	m1 = Transform2D(m1Ang, Vector2(scaling, scaling), 0.0, s1StartPoint)
	m2 = Transform2D(m2Ang, s2StartPoint)
	if not tapping:
		s3Ang = -(s1.parent.rotation_degrees / 180.0 * PI) - offsetAng - s2Ang + s2OffsetAng
		s3Ang += getEndRotation()
		var cur := s3.rotation_degrees / 180.0 * PI
		s3Ang = cur + (s3Ang - cur) / s3Mass
		s3Ang = maxf(-1.22, minf(1.22, s3Ang))
		if is_nan(s3Ang):
			s3Ang = 0.0
	if s3Mass > 1:
		s3Mass = maxf(1.0, s3Mass - 1.0)
	var endScale := Vector2(-1, 1) if reversedEnd else Vector2.ONE
	if tapping:
		m3 = Transform2D(s3Ang + tapDist * 0.005, endScale, 0.0, s3StartPoint)
	else:
		m3 = Transform2D(s3Ang, endScale, 0.0, s3StartPoint)
	s1AS = s1Ang - lastS1Ang
	s2AS = s2Ang - lastS2Ang


func jumpTo(p: Vector2) -> void:
	currentPoint = targetPointCoordinateSpace.globalToLocal(p)


func tap(power: float = 1.0, angleOffset: float = 0.0) -> void:
	if not tapping and not dropping:
		tapVector = Vector2(cos(getEndRotation() + angleOffset), sin(getEndRotation() + angleOffset))
		tapMultiplier = power
		tapPower = tapMultiplier * maxTapPower
		tapDist = 0
		tapSpeed = -tapPower * 6.0
		tapping = true


func dropTarget(force: Vector2) -> void:
	speed.x += force.x
	speed.y += force.y + gravity
	currentPoint += speed
	speed *= 0.9


func slip(amount: float, limit: bool = true) -> void:
	var dir := Vector2(sin(s3Ang), -cos(s3Ang))
	if dir.y < 0:
		dir = -dir
	targetPoint += dir * amount
	if limit:
		var dx := targetPoint.x - originalTarget.x
		if dx > maxSlipDist:
			targetPoint.x = originalTarget.x + maxSlipDist
		elif dx < -maxSlipDist:
			targetPoint.x = originalTarget.x - maxSlipDist
		var dy := targetPoint.y - originalTarget.y
		if dy > maxSlipDist:
			targetPoint.y = originalTarget.y + maxSlipDist
		elif dy < -maxSlipDist:
			targetPoint.y = originalTarget.y - maxSlipDist


func resetTarget(amount: float) -> void:
	targetPoint += (originalTarget - targetPoint) * amount


func updateTarget() -> void:
	speed = (targetPoint - currentPoint) / mass
	currentPoint += speed
	mass = maxf(1.0, mass - 1.0)
	if tapping:
		tapDist += tapSpeed
		tapSpeed += tapPower
		tapPower *= 2.0
		if tapDist > 0:
			tapDist = 8
			g.soundControl.playGrab(1, tapMultiplier)
			tapping = false
	elif tapDist > 0:
		tapDist = maxf(0.0, tapDist - 4.0)
	currentPoint -= tapVector * tapDist


var globalPoint: Vector2:
	get:
		if targetPointCoordinateSpace:
			return targetPointCoordinateSpace.localToGlobal(currentPoint)
		return Vector2()


func getDown() -> float:
	var a := 0.0
	var o: FlashDisplayObject = s1.parent
	var n := 0
	while o != Flash.stage and o != null and n < 5:
		a -= o.rotation_degrees / 180.0 * PI
		n += 1
		o = o.parent
	return a


func trigBound(v_: float) -> float:
	if v_ > 1:
		return fmod(v_, 1.0) - 1.0
	if v_ < -1:
		return fmod(v_, 1.0) + 1.0
	return v_


func getEndRotation() -> float:
	var a := 0.0
	for t in endRotationTargets:   # Flash's rotation is always -180..180; a Godot node keeps what was assigned
		a += wrapf(t.rotation_degrees, -180.0, 180.0) / 180.0 * PI
	return a + endRotationAngle / 180.0 * PI


var section1Matrix: Transform2D:
	get:
		return m1

var section2Matrix: Transform2D:
	get:
		return m2

var section3Matrix: Transform2D:
	get:
		return m3

var section1Angle: float:
	get:
		return offsetAng - s1Ang - s1OffsetAng

var section2Angle: float:
	get:
		return s2Ang + s1Ang + s1OffsetAng - s2OffsetAng

var section3Angle: float:
	get:
		return s3Ang

var springVector: Vector2:
	get:
		return springV
