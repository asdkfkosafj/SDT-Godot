class_name Rope
extends CostumeElement
## Port of obj.Rope: dangling hair made of segments (the graphic's child clips sorted by y), simulated as a
## verlet-style chain hanging from an anchor on her head.

class RopeLink:
	## Port of obj.RopeLink (a flash.geom.Point subclass).
	var x: float
	var y: float
	var speed := Vector2()
	var friction: float
	var mass: float
	var lastPos := Vector2()

	func _init(px: float, py: float, f: float, m: float) -> void:
		x = px
		y = py
		friction = f
		mass = m

	func move(gravity: Vector2) -> void:
		lastPos = Vector2(x, y)
		x += gravity.x * mass
		y += gravity.y * mass


var ropeGraphic: FlashSprite
var ropeLength: int = 0
var segLength: Array = []
var segNum: float = 4.0
var links: Array = []
var segments: Array = []
var widthEstimates: Array = []
var mass: float = 20.0
var friction: float = 0.9
var damping: float = 0.595
var topLocked := false
var topDamping: float = 0.0
var topRotationLocked := false
var topRotationTarget: FlashDisplayObject = null
var subScaling := Vector2(1, 1)
var ropeAnchorContainer = null
var ropeAnchorPoint := Vector2()
var lastAnchor := Vector2()
var ropeCurrentAnchor := Vector2()
var impulse := Vector2()
var collisionImpulse := Vector2()
var gOffset: float = 0.0
var gravityDirection := Vector2()
var leftLimited := false
var leftLimitedMultiplier: float = 0.0
var rightLimited := false
var rightLimitedMultiplier: float = 0.0
var collisionImpulses: Array = []
var leftLimit: int = 0
var rightLimit: int = 0
var hairCollisionTest := false


func _init(graphic: FlashSprite = null, layer = null, anchor = null, container = null, gravityOffset: float = 0.0,
		limits: String = "none", pLeftLimit: int = 0, pRightLimit: int = 0, customLength: int = 0,
		customSegLengths = null) -> void:
	super()
	if graphic == null:
		return
	ropeGraphic = graphic
	ropeGraphic.x = 0
	ropeGraphic.y = 0
	ropeGraphic.scaleX = 1
	ropeGraphic.scaleY = 1
	ropeGraphic.alpha = 1
	addChild(ropeGraphic)
	gOffset = gravityOffset
	if limits == "left":
		leftLimited = true
	elif limits == "right":
		rightLimited = true
	elif limits == "both":
		leftLimited = true
		rightLimited = true
	leftLimit = pLeftLimit
	rightLimit = pRightLimit
	var ga := (180.0 + gOffset) * (PI / 180.0)
	gravityDirection = Vector2(sin(ga) * 1.2, -cos(ga) * 1.2)
	if customSegLengths == null:
		segLength = []
		segments = []
		for i in ropeGraphic.numChildren:
			var c := ropeGraphic.getChildAt(i)
			if c is FlashSprite:
				segments.append(c)
		segments.sort_custom(func(a, b): return a.y < b.y)
		ropeLength = segments.size()
		for s in segments:
			ropeGraphic.setChildIndex(s, 0)
		for i in ropeLength:
			widthEstimates.append(segments[i].width * 0.25)
			collisionImpulses.append(Vector2())
			if i < ropeLength - 1:
				segLength.append(segments[i + 1].y - segments[i].y)
			else:
				segLength.append(segments[i].getBounds(ropeGraphic).end.y - segments[i].y)
	else:
		ropeLength = customLength
		segLength = customSegLengths
	if anchor == null:
		anchor = Vector2(segments[0].x, segments[0].y)
	ropeAnchorContainer = container if container else g.her
	ropeAnchorPoint = anchor
	ropeCurrentAnchor = g.sceneLayer.globalToLocal(ropeAnchorContainer.localToGlobal(ropeAnchorPoint))
	var along := 0.0
	links = [RopeLink.new(ropeCurrentAnchor.x, ropeCurrentAnchor.y, friction, mass)]
	for i in range(1, ropeLength + 1):
		links.append(RopeLink.new(ropeCurrentAnchor.x + (along + segLength[i - 1]) * gravityDirection.x,
			ropeCurrentAnchor.y + (along + segLength[i - 1]) * gravityDirection.y, friction, mass))
		along += segLength[i - 1]
	addEventListener(FlashEvent.ENTER_FRAME, move)
	layer.addChild(self)


func setScaling(sx: float, sy: float) -> void:
	subScaling = Vector2(sx, sy)
	for i in ropeLength:
		segments[i].scaleX = subScaling.x
		segments[i].scaleY = subScaling.y
		segLength[i] *= subScaling.y


func lockTop(d: float) -> void:
	topLocked = true
	topDamping = d


func lockTopRotation(target = null) -> void:
	topRotationLocked = true
	topRotationTarget = target if target else g.her


func kill() -> void:
	removeEventListener(FlashEvent.ENTER_FRAME, move)
	if parent:
		parent.removeChild(self)
	Flash.dispose_later(self)


func move() -> void:
	var go := gOffset
	if Hooks.has_value(&"Rope.gravityOffset"):   # HOOK value point: the angle (degrees) a hanging strand of hair falls at, off straight down in scene space (its gOffset)
		go = Hooks.value(&"Rope.gravityOffset", self, gOffset)
	var ga := (180.0 + go) * PI / 180.0
	gravityDirection = Vector2(sin(ga), -cos(ga))
	lastAnchor = ropeCurrentAnchor
	ropeCurrentAnchor = g.sceneLayer.globalToLocal(ropeAnchorContainer.localToGlobal(ropeAnchorPoint))
	impulse = (ropeCurrentAnchor - lastAnchor) * (1.0 - damping)
	var down := Vector2()
	if topRotationLocked:
		down = topRotationTarget.flash_global_transform().basis_xform(Vector2(0, 1))
	links[0].x = ropeCurrentAnchor.x
	links[0].y = ropeCurrentAnchor.y
	for i in range(1, ropeLength + 1):
		var l: RopeLink = links[i]
		l.move(gravityDirection)
		if topLocked and i == 1:
			l.x += (ropeCurrentAnchor.x - lastAnchor.x) * (1.0 - topDamping * damping)
			l.y += (ropeCurrentAnchor.y - lastAnchor.y) * (1.0 - topDamping * damping)
		else:
			l.x += impulse.x
			l.y += impulse.y
		if topRotationLocked:
			var prev: RopeLink = links[i - 1]
			var f := 0.5 * (1.0 - float(i) / ropeLength)
			l.x += (prev.x + down.x * segLength[i - 1] - l.x) * f
			l.y += (prev.y + down.y * segLength[i - 1] - l.y) * f
	for i in ropeLength:
		var a: RopeLink = links[i]
		var b: RopeLink = links[i + 1]
		impulse = Vector2(a.x - b.x, a.y - b.y)
		var dist := sqrt(impulse.x * impulse.x + impulse.y * impulse.y)
		impulse /= dist
		var slope := impulse.x / impulse.y
		if not hairCollisionTest:
			if leftLimited and slope < g.her.hairLimits[leftLimit]:
				var over: float = slope - g.her.hairLimits[leftLimit]
				impulse.x -= over * -impulse.y * 0.5
				impulse.y -= over * impulse.x * 0.5
			if rightLimited and slope > g.her.hairLimits[rightLimit]:
				var over: float = slope - g.her.hairLimits[rightLimit]
				impulse.x -= over * -impulse.y * 0.5
				impulse.y -= over * impulse.x * 0.5
		b.x += impulse.x * (dist - segLength[i]) * 0.825
		b.y += impulse.y * (dist - segLength[i]) * 0.825
		a.x -= impulse.x * (dist - segLength[i]) * 0.25
		a.y -= impulse.y * (dist - segLength[i]) * 0.25
		a.x += collisionImpulses[i].x
		a.y += collisionImpulses[i].y
	updateRopeGraphic()


func updateRopeGraphic() -> void:
	for i in ropeLength:
		var a: RopeLink = links[i]
		var b: RopeLink = links[i + 1]
		segments[i].x = a.x
		segments[i].y = a.y
		var d := Vector2(b.x - a.x, b.y - a.y)
		var len := sqrt(d.x * d.x + d.y * d.y)
		segments[i].rotation_degrees = g.getAngle(d.x, d.y) + 180.0
		segments[i].scaleY = len / segLength[i]
