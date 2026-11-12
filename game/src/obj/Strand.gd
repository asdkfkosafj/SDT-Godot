class_name Strand
extends FlashMovieClip
## Port of obj.Strand: a chain of StrandLinks simulated as springs, colliding with and sticking to body parts,
## splitting, dripping and fading; drawn as gradient-filled segments.

var layer: FlashSprite
var strandLength: int = 0
var links: Array = []
var alive := false
var age: int = 0
var ageMax: int = 600
var myGravity: float
var interPoints: Array = []
var offsetPoints: Array = []
var topCap := Vector2()
var bottomCap := Vector2()
var maxInterpDist: float = 1000.0
var topAnchor = null
var topAttached := false
var bottomAnchor = null
var bottomAttached := false
var topSource := false
var lM: float = 0.0
var disappearOnAllAnchor := false
var sourceLink: StrandLink = null
var cumStrand := false
var moveSmoothing: float = 8.0
var maxDist: float = 120.0
var distSplitDelay: int = 0
var collisionFree: int = 0


func _init(pLayer: FlashSprite = null, pLength: int = 0, pMass: float = 0.0, a = null, b = null,
		pTopSource: bool = false, pDisappear: bool = false) -> void:
	super()
	disappearOnAllAnchor = pDisappear
	layer = pLayer
	strandLength = pLength
	lM = pMass
	if a != null:
		topAnchor = a
		topAttached = true
	if b != null:
		bottomAnchor = b
		bottomAttached = true
	topSource = pTopSource
	age = 0
	alive = false
	myGravity = g.gravity
	maxDist *= maxDist
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func insertLink(v: Vector2, delay: int, mass: float) -> void:
	var l := StrandLink.new(mass, minf(1.0, randf() * 3.0), v, collisionFree, cumStrand)
	links.insert(strandLength - 1, l)
	l.x = sourceLink.x
	l.y = sourceLink.y
	l.anchorDelay = delay
	strandLength = links.size()
	setNeighbours()


func detachSourceLink(v: Vector2, delay: int = 0) -> void:
	sourceLink.detachAnchor(false)
	sourceLink.speed = v
	sourceLink.anchorDelay = delay
	sourceLink.collisionFree = collisionFree
	sourceLink.slideOnAnchor = cumStrand


func checkElementAnchors(element: FlashDisplayObject) -> void:
	for i in strandLength:
		if links[i].anchored and links[i].anchorContainer == element:
			links[i].detachAnchor(false)


func checkCostumeAnchors() -> void:
	for i in strandLength:
		for e in g.costumeHitElements:
			if links[i].anchored and links[i].anchorContainer == e:
				links[i].detachAnchor(false)


func delayCollisions(delay: int) -> void:
	var start := 1 if topAttached else 0
	var end := strandLength - 1 if bottomAttached else strandLength
	for i in range(start, end):
		links[i].detachAnchor(false)
		links[i].anchorDelay += delay


func detachTop() -> void:
	links[0].detachAnchor()


func detachBottom() -> void:
	links[links.size() - 1].detachAnchor()


func instancePoints(initialSpeed = null) -> void:
	links = []
	for i in strandLength:
		var l := StrandLink.new(lM, 1, initialSpeed, collisionFree, cumStrand)
		if topAttached and bottomAttached:
			var tp: Vector2 = g.sceneLayer.globalToLocal(topAnchor.container.localToGlobal(topAnchor.localPoint))
			var bp: Vector2 = g.sceneLayer.globalToLocal(bottomAnchor.container.localToGlobal(bottomAnchor.localPoint))
			l.x = tp.x + i * (bp.x - tp.x) / strandLength
			l.y = tp.y + i * (bp.y - tp.y) / strandLength
		elif topAttached:
			var tp: Vector2 = g.sceneLayer.globalToLocal(topAnchor.container.localToGlobal(topAnchor.localPoint))
			l.x = tp.x
			l.y = tp.y
		links.append(l)
	if topSource:
		links[0].massGenerator()
	if topAttached:
		links[0].anchorTo(topAnchor)
	if bottomAttached:
		links[links.size() - 1].anchorTo(bottomAnchor)
	strandLength = links.size()
	setNeighbours()
	alive = true


func giveLinks(ls: Array) -> void:
	links = []
	for l in ls:
		links.append(l.cloneLink())
	strandLength = links.size()
	setNeighbours()
	alive = true


func addSourceLink(p: Vector2, container: FlashDisplayObject, cum: bool = true) -> void:
	if cum:
		cumStrand = true
		ageMax = 1500
	links = []
	sourceLink = StrandLink.new(lM, 1, Vector2(), collisionFree, false)
	sourceLink.anchorTo(AnchorProp.new(p, container), true)
	links.append(sourceLink)
	collisionFree = 2
	strandLength = links.size()
	alive = true


func setNeighbours() -> void:
	if strandLength > 1:
		links[0].setNeighbours(links[1])
		for i in range(1, strandLength - 2):
			links[i].setNeighbours(links[i - 1], links[i + 1])
		links[strandLength - 1].setNeighbours(links[strandLength - 2])


func tick() -> void:
	updateStrand()


func updateStrand() -> void:
	if not alive or g.gamePaused:
		return
	age += 1
	maxDist = maxf(30.0, maxDist - 0.2)
	var highest := 1.79e308
	var i := 0
	while true:
		if i >= strandLength:
			if highest > g.screenSize.y * (1.0 / g.sceneZoom) + 10.0:
				killMe()
				break
			for l in links:
				l.tick(myGravity)
				l.clearGlobalAnchor()
			if not cumStrand and strandLength > g.maxStrandLength:
				var at := int(floor(randf() * strandLength / 3.0 + strandLength / 3.0))
				if splitStrand(at):
					break
			if getAlpha() == 0:
				killMe()
				break
			renderStrand()
			break
		var link: StrandLink = links[i]
		var prev: StrandLink = links[i - 1] if i > 0 else null
		if link.onTongue:
			if tongueCollide(i):
				splitStrand(i, i > 0, true)
				if cumStrand:
					g.her.tongueContainer.tongue.cumRemoved()
					g.her.fillMouth(true)
		elif link.anchorable:
			var a := collide(i)
			if a:
				if a.forceHit:
					link.anchorTo(a)
					if cumStrand and g.her.head.contains(a.container) and g.him.isEjaculating():
						g.her.cumOnFace()
					if a.eyeHit:
						g.dialogueControl.triggerState(Dialogue.CUM_IN_EYE)
						g.her.eyeHit()
				elif link.tryToAnchorTo(a):
					if cumStrand and g.her.head.contains(a.container) and g.him.isEjaculating():
						g.her.cumOnFace()
					if a.eyeHit:
						g.dialogueControl.triggerState(Dialogue.CUM_IN_EYE)
						g.her.eyeHit()
				if disappearOnAllAnchor:
					if checkAllAnchored():
						killMe()
						break
		if link.anchored:
			var lp: Vector2 = g.sceneLayer.globalToLocal(link.globalAnchor)
			link.x = lp.x
			link.y = lp.y
			if not cumStrand and link.anchorAge > ageMax:
				link.detachAnchor()
		var toPrev := Vector2.ZERO
		var distSq := 0.0
		if i > 0:
			toPrev = Vector2(prev.x - link.x, prev.y - link.y)
			distSq = toPrev.x * toPrev.x + toPrev.y * toPrev.y
		var toNext := Vector2.ZERO
		if i < strandLength - 1:
			toNext = Vector2(links[i + 1].x - link.x, links[i + 1].y - link.y)
		link.accelerate((toPrev.x + toNext.x) / moveSmoothing, (toPrev.y + toNext.y) / moveSmoothing + myGravity * link.mass)
		link.move(g.friction)
		if distSq > maxDist and i > 0:
			if distSplitDelay == 0:
				distSplitDelay = 10
				splitStrand(i)
		if i < strandLength:
			if link.y < highest:
				highest = link.y
			if link.mass >= g.maxMass:
				expandStrand(i)
		i += 1
	if distSplitDelay > 0:
		distSplitDelay -= 1


func smear(p: Vector2, radius: float) -> void:
	for l in links:
		l.smear(p, radius)


func splitStrandAtAnchorChange() -> void:
	# (sic) the original compares instead of assigning, so 'side' is never set.
	var side = null
	for i in range(1, strandLength):
		if links[0].anchorContainer == g.her.head.face or links[0].anchorContainer == g.her.head.jaw:
			if side == "breast":
				splitStrand(i, false)
				break
		elif links[0].anchorContainer == g.her.torso.midLayer.rightBreast:
			if side == "face":
				splitStrand(i, false)
				break


func splitStrandAtOffAnchor() -> void:
	var wasAnchored: bool = links[0].anchored
	for i in range(1, strandLength):
		var isAnchored: bool = links[i].anchored
		if wasAnchored != isAnchored:
			splitStrand(i, false)
			break
		wasAnchored = isAnchored


func _hit(o, p: Vector2) -> bool:
	return o.hitTestPoint(p.x, p.y, false) and o.hitTestPoint(p.x, p.y, true)


func collide(i: int) -> AnchorProp:
	var p: Vector2 = g.strandBackLayer.localToGlobal(Vector2(links[i].x, links[i].y))
	var h: Her = g.her
	for e in g.costumeHitElements:
		if e.showing and _hit(e, p):
			return AnchorProp.new(e.globalToLocal(p), e)
	if _hit(h.eyewear, p):
		return AnchorProp.new(h.eyewear.globalToLocal(p), h.eyewear)
	if _hit(h.head.face, p):
		var a := AnchorProp.new(h.head.face.globalToLocal(p), h.head.face, false)
		if cumStrand and h.eye.hitBox.hitTestPoint(p.x, p.y, false):
			a.setEyeHit()
		return a
	if _hit(h.head.jaw, p):
		return AnchorProp.new(h.head.jaw.globalToLocal(p), h.head.jaw, false)
	var tongue = h.tongueContainer.tongue
	if tongue.okayToHit() and _hit(tongue, p):
		if cumStrand:
			tongue.cumHit()
		var a := AnchorProp.new(tongue.tipPoint.globalToLocal(p), tongue.tipPoint, true)
		a.setOriginalHitTarget(tongue)
		return a
	if h.torso.midLayer.rightBreast.hitTestPoint(p.x, p.y, false):
		if h.torso.midLayer.rightBreast.hitArea.hitTestPoint(p.x, p.y, true):
			return AnchorProp.new(h.torso.midLayer.rightBreast.globalToLocal(p), h.torso.midLayer.rightBreast, false)
	if h.torso.hitTestPoint(p.x, p.y, false):
		if h.torso.leg.hitTestPoint(p.x, p.y, false):
			if h.torso.leg.hitTestPoint(p.x, p.y, true) and not h.torso.rightCalfContainer.calf.hitTestPoint(p.x, p.y, true):
				return AnchorProp.new(h.torso.leg.globalToLocal(p), h.torso.leg, false)
		if h.torso.midLayer.chest.hitTestPoint(p.x, p.y, true):
			return AnchorProp.new(h.torso.midLayer.chest.globalToLocal(p), h.torso.midLayer.chest, false)
		if h.torso.back.hitTestPoint(p.x, p.y, true):
			return AnchorProp.new(h.torso.back.globalToLocal(p), h.torso.back, false)
		if h.penisOn and h.torso.penisContainer.hitTestPoint(p.x, p.y, true):
			return AnchorProp.new(h.torso.penisContainer.globalToLocal(p), h.torso.penisContainer, false)
	if g.sceneLayer.globalToLocal(p).y > 1220.0 + randf() * 65.0:
		return AnchorProp.new(g.sceneLayer.globalToLocal(p), g.sceneLayer)
	return null


func tongueCollide(i: int) -> bool:
	var p: Vector2 = g.strandBackLayer.localToGlobal(Vector2(links[i].x, links[i].y))
	return _hit(g.her.head.face, p) or _hit(g.her.head.jaw, p)


func checkAllAnchored() -> bool:
	for l in links:
		if not l.anchored:
			return false
	return true


## The native extension builds the whole drawing in one call (same geometry and gradients, as one mesh).
static var _native: bool = ClassDB.class_exists(&"SDTNative") and not "--nonative" in OS.get_cmdline_user_args()


func renderStrand() -> void:
	if _native:
		_renderStrandNative()
		return
	generateInterpolationPoints()
	var gr := graphics
	gr.clear()
	var rgb := getRGB()
	var a := getAlpha()
	for i in range(1, strandLength):
		var cur: StrandLink = links[i]
		var prev: StrandLink = links[i - 1]
		var o: Dictionary = offsetPoints[i]
		var po: Dictionary = offsetPoints[i - 1]
		var d := Vector2(cur.x - prev.x, cur.y - prev.y)
		var size := maxf(absf(d.x), absf(d.y))
		var box := FlashGraphics.createGradientBox(size, size, atan2(d.y, d.x), minf(cur.x, prev.x), minf(cur.y, prev.y))
		gr.beginGradientFill("linear", [rgb, rgb], [minf(1.0, prev.density) * a, minf(1.0, cur.density) * a], [100, 155], box)
		var ip: Dictionary = prev.getStoredInterPoints() if prev.hasStoredInterPoints else interPoints[i - 1]
		gr.moveTo(po["inside"].x, po["inside"].y)
		gr.curveTo(ip["inside"].x, ip["inside"].y, o["inside"].x, o["inside"].y)
		if i == strandLength - 1:
			gr.curveTo(bottomCap.x, bottomCap.y, o["outside"].x, o["outside"].y)
		else:
			gr.lineTo(o["outside"].x, o["outside"].y)
		gr.curveTo(ip["outside"].x, ip["outside"].y, po["outside"].x, po["outside"].y)
		if i == 1:
			gr.curveTo(topCap.x, topCap.y, offsetPoints[0]["inside"].x, offsetPoints[0]["inside"].y)
	gr.endFill()


func _renderStrandNative() -> void:
	var n := strandLength
	var pos := PackedVector2Array()
	var thick := PackedFloat32Array()
	var dens := PackedFloat32Array()
	var has_stored := PackedByteArray()
	var stored := PackedVector2Array()
	pos.resize(n)
	thick.resize(n)
	dens.resize(n)
	has_stored.resize(n)
	stored.resize(n * 2)
	for i in n:
		var l: StrandLink = links[i]
		pos[i] = Vector2(l.x, l.y)
		thick[i] = getLinkThickness(i)
		dens[i] = l.density
		if i < n - 1 and l.hasStoredInterPoints:
			var b: StrandLink = links[i + 1]
			if not l.anchored or not b.anchored:
				l.unstoreInterPoints()
			else:
				var sp: Dictionary = l.getStoredInterPoints()
				has_stored[i] = 1
				stored[i * 2] = sp["inside"]
				stored[i * 2 + 1] = sp["outside"]
	var mesh: Array = ClassDB.class_call_static(&"SDTNative", &"build_strand", pos, thick, dens, has_stored, stored,
		Color.hex((getRGB() << 8) | 0xFF), getAlpha(), maxInterpDist)
	graphics.clear()
	graphics.setMesh(mesh[0], mesh[1], mesh[2], mesh[3] if mesh.size() > 3 else null)


func getAlpha() -> float:
	if cumStrand:
		return 0.95 - maxf(0.0, minf(1.9, 1.2 * age / ageMax - 0.2)) / 2.0
	return 1.0 - maxf(0.0, minf(1.0, 1.2 * age / ageMax - 0.2))


func getRGB() -> int:
	return g.cumRGB if cumStrand else 16777215


func getLinkThickness(i: int) -> float:
	var t := maxf(g.strandControl.cumMinThickness if cumStrand else 1.0, pow(links[i].mass * 2.0, 1.5))
	if links[i].anchored:
		t *= 1.5
	if cumStrand:
		t *= 1.3
	return t


func generateInterpolationPoints() -> void:
	interPoints = []
	interPoints.resize(maxi(strandLength, 1))
	offsetPoints = []
	offsetPoints.resize(maxi(strandLength, 1))
	var dirs: Array = []
	dirs.resize(maxi(strandLength + 1, 2))   # AS3 arrays grow on write; a 0-link strand writes index 1
	var lines: Array = []
	lines.resize(maxi(strandLength, 1))
	for i in strandLength - 1:
		var a: StrandLink = links[i]
		var b: StrandLink = links[i + 1]
		var d := Vector2(b.x - a.x, b.y - a.y)
		if not (d.x == 0 and d.y == 0):
			d /= sqrt(d.x * d.x + d.y * d.y)
		dirs[i + 1] = d
	if strandLength > 1:
		dirs[0] = dirs[1]
		dirs[strandLength] = dirs[strandLength - 1]
	else:
		dirs[0] = Vector2(0, 1)
		dirs[1] = Vector2(0, 1)
	for i in strandLength:
		var l: StrandLink = links[i]
		var n: Vector2 = dirs[i + 1] + dirs[i]
		if n.x == 0 and n.y == 0:
			n = dirs[i]
		var t := getLinkThickness(i)
		var inside := Vector2(l.x - n.y * t, l.y + n.x * t)
		var outside := Vector2(l.x + n.y * t, l.y - n.x * t)
		if i == 0:
			topCap = Vector2(l.x - n.x * t * 2.0, l.y - n.y * t * 2.0)
		elif i == strandLength - 1:
			bottomCap = Vector2(l.x + n.x * t * 2.0, l.y + n.y * t * 2.0)
		offsetPoints[i] = {"inside": inside, "outside": outside}
		lines[i] = {"inside": Line.new(inside + n, inside - n), "outside": Line.new(outside + n, outside - n)}
	for i in strandLength - 1:
		var a: StrandLink = links[i]
		var b: StrandLink = links[i + 1]
		if a.hasStoredInterPoints and (not a.anchored or not b.anchored):
			a.unstoreInterPoints()
		if not a.hasStoredInterPoints:
			var mid := Vector2((a.x + b.x) / 2.0, (a.y + b.y) / 2.0)
			var ins := Vector2()
			var outs := Vector2()
			if i > 0 and i < strandLength - 2:
				ins = _interPoint(lines[i]["inside"], lines[i + 1]["inside"], mid, offsetPoints[i]["inside"], offsetPoints[i + 1]["inside"])
				outs = _interPoint(lines[i]["outside"], lines[i + 1]["outside"], mid, offsetPoints[i]["outside"], offsetPoints[i + 1]["outside"])
			elif i == 0:
				ins = Maths.normal(lines[1]["inside"].p1, lines[1]["inside"].p2, mid)
				outs = Maths.normal(lines[1]["outside"].p1, lines[1]["outside"].p2, mid)
			elif i == strandLength - 2:
				ins = Maths.normal(lines[strandLength - 2]["inside"].p1, lines[strandLength - 2]["inside"].p2, mid)
				outs = Maths.normal(lines[strandLength - 2]["outside"].p1, lines[strandLength - 2]["outside"].p2, mid)
			interPoints[i] = {"inside": ins, "outside": outs}


## Control point where adjacent offset lines meet, clamped towards the midpoint (squared-distance comparison is
## as in the original).
func _interPoint(l1: Line, l2: Line, mid: Vector2, o1: Vector2, o2: Vector2) -> Vector2:
	var hit := Maths.intersect(l1, l2)
	if hit["intersect"] == true:
		var d := Vector2(hit["x"] - mid.x, hit["y"] - mid.y)
		var d2 := d.x * d.x + d.y * d.y
		if d2 > maxInterpDist:
			d *= maxInterpDist / d2
			return mid + d
		return Vector2(hit["x"], hit["y"])
	return o1 + (o2 - o1) / 2.0


func expandStrand(i: int) -> void:
	var m: float = links[i].mass
	var dens: float = links[i].density
	links[i].mass = m / 2.0
	links[i].density = dens / 2.0
	var c: StrandLink = links[i].cloneLink()
	c.x += 1
	c.isExpanded = true
	links.insert(i, c)
	strandLength = links.size()
	var drop := Droplet.new(Vector2(links[i].x, links[i].y), links[i].speed, 1, 0.02, getAlpha(), cumStrand)
	if cumStrand:
		g.cumLayer.addChild(drop)
	else:
		g.strandFrontLayer.addChild(drop)
	setNeighbours()


func splitStrand(at: int, addMiddle: bool = true, removeFirst: bool = false) -> bool:
	var middle: StrandLink = null
	if addMiddle:
		var a: StrandLink = links[at - 1]
		var b: StrandLink = links[at]
		middle = StrandLink.new(0, (a.density + b.density) * 0.5, Vector2())
		middle.x = b.x + (a.x - b.x) / 2.0
		middle.y = b.y + (a.y - b.y) / 2.0
		middle.speed = Vector2(b.speed.x + (a.speed.x - b.speed.x) / 2.0, b.speed.y + (a.speed.y - b.speed.y) / 2.0)
	var head: Array = links.slice(0, at)
	links = links.slice(at)
	if removeFirst and not links.is_empty():
		links.remove_at(0)
	if addMiddle:
		head.append(middle)
		if not removeFirst:
			links.push_front(middle)
	if head.size() > 1:
		g.strandControl.addStrand(self, head, lM)
	strandLength = links.size()
	setNeighbours()
	if strandLength <= 1:
		killMe()
		return true
	return false


func killMe() -> void:
	if alive:
		for l in links:
			if l.onEye:
				g.her.eyeClearHit()
		g.strandControl.delistStrand(self)
		alive = false
		removeEventListener(FlashEvent.ENTER_FRAME, tick)
		if parent:
			parent.removeChild(self)
		Flash.dispose_later(self)   # port: freed once nothing holds it any more (_can_dispose)


## Flash.dispose_later policy: in Flash a killed strand lives on while the game still holds it, and the game keeps
## calling it (her drool and nostril spray, his current spurt: insertLink / detachSourceLink on a dead strand are
## harmless there). Freeing it any earlier made those calls crash.
func _can_dispose() -> bool:
	var her = g.her
	if her != null and (her.currentCumDrool == self or her.currentSpitDrool == self or her.currentNostrilSpray == self):
		return false
	if g.him != null and g.him.currentSpurt == self:
		return false
	var sc = g.strandControl
	return not (sc.strands.has(self) or sc.cumStrands.has(self))
