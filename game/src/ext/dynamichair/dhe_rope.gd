extends Rope
## A dynamic hair strand with dynamicHairExtender's settings (see dynamichair.gd). Written from DHE's behaviour
## (stuntcock, v5.91, ExtraMod's fork extraModDHE 0.1).
##
## Without extended settings (rotationBlending, linkWeights, anchored) the strand keeps the game's physics and only
## hangs from its own anchor container / sits in its own visual parent. With them DHE's physics replaces the game's:
## each step its links go to the anchor, fall by their weight (linkWeights, sharedLinkInfluences) and are pulled back
## to their segment lengths (proximal / distal elasticity per segment) after turning each segment toward a rotation
## relative to the one before it (relativeRotationTargets / Multipliers, minRotations / maxRotations; the first
## segment relative to the anchor container), blended with the segment's own direction (rotationBlending). Links of
## segments named SHARED_<x> are shared with other strands that have one of the same name; slavedUpdates strands are
## stepped by the strand they share links with.

const DEFAULT_ELASTICITY_PROXIMAL := 0.25
const DEFAULT_ELASTICITY_DISTAL := 0.825
const ELASTICITY_MAX := 5.0
const SHARED_PREFIX := "SHARED_"

var ext                       # dynamichair.gd
var extended := false         # DHE's physics instead of the game's
var custom_parent := false    # visualParent: the graphic is placed through global coordinates
var rotationBlending := 0.0
var anchored := true
var anchorSource = null
var simCyclesPerUpdate := 1
var maxCyclesPerUpdate := 2147483647
var slavedUpdates := false
var doNotSimulate := false
var isotropicScaling := false
var maximumY := INF
var floorKneeOffset = null     # floorAtKneeLevel: from her body's target to the floor (null: no floor)
var rgbHelper = null           # rgbElement: the element helper whose colours the strand takes
var sharedRopes := {}          # DHE rope -> true: strands sharing links with this one
var sharedLinkInfluences = null    # link index -> influence (null: none given)
var proximalElasticityFactors := {}   # segment name or index -> factor
var distalElasticityFactors := {}
var allowElongations := {}
var allowCompressions := {}
var blendingExclusions := {}
var relativeRotationTargets := {}
var relativeRotationMultipliers := {}
var minRotations := {}
var maxRotations := {}
var skinSegments: Array = []    # segments showing her skin's frame (useSkinPalette)
var _rots := PackedFloat32Array()   # the segments' rotations during a frame's physics (see _load_rotations)
var _link_inf := PackedFloat32Array()   # per link: its influence (sharedLinkInfluences, 0..1)
var _seg: Array = []                 # per segment: its settings (_prepare)
var _to_graphic := Transform2D()   # scene layer -> graphic coordinates, once per step (segments turning inside a step
                                   # would make every localToGlobal walk the parents again)


func _init(owner_ext = null, graphic: FlashSprite = null, layer = null, container = null, gravity := 0.0) -> void:
	super(graphic, layer, null, container, gravity)
	ext = owner_ext


## DHE's settings from the mod item `m` (after the strand is built).
func setup(m) -> void:
	var her_g = g
	var vci = m.get("visualChildIndex")
	if vci != null and parent != null:
		parent.setChildIndex(self, clampi(int(vci), 0, parent.numChildren - 1))
	var svi = m.get("segmentVisualIndex")
	if svi is Dictionary:
		for k in svi:
			var child = null
			if str(k).is_valid_float():
				var ci := int(float(k))
				child = ropeGraphic.getChildAt(ci) if ci >= 0 and ci < ropeGraphic.numChildren else null
			else:
				child = ropeGraphic.getChildByName(str(k))
			if child != null:
				ropeGraphic.setChildIndex(child, clampi(int(svi[k]), 0, ropeGraphic.numChildren - 1))
	var mask_path = m.get("maskPath")
	if mask_path != null:
		var mo = ext.find_path(her_g, str(mask_path))
		if mo == null:
			mo = ext.shared_ropes.get(str(mask_path))
		if mo != null:
			mask = mo
			mo.visible = true
	if m.get("rotationBlending") != null:
		rotationBlending = AS3.Number(m.rotationBlending)
		extended = true
	var ap = m.get("autoPlay")
	if (ap is bool and not ap) or ap is Dictionary:
		var per := _keys(ap)
		for i in segments.size():
			if ap is bool or per.get(i) == false:
				segments[i].stop()
	distalElasticityFactors = _keys(m.get("distalElasticityFactors"))
	proximalElasticityFactors = _keys(m.get("proximalElasticityFactors"))
	allowElongations = _keys(m.get("allowElongations"))
	allowCompressions = _keys(m.get("allowCompressions"))
	blendingExclusions = _keys(m.get("blendingExclusions"))
	isotropicScaling = _truthy(m.get("isotropicScaling"))
	_share_links()
	var lw = m.get("linkWeights")
	if lw is Dictionary:
		var w := _link_keys(_keys(lw))
		for i in links.size():
			if w.has(i) and (w[i] is float or w[i] is int):
				links[i].mass = float(w[i])
		extended = true
	if _truthy(m.get("reverseSegmentOrder")):
		for i in range(segments.size() - 1, -1, -1):
			ropeGraphic.setChildIndex(segments[i], 0)
	var sc = m.get("simCyclesPerUpdate")
	simCyclesPerUpdate = 1 if sc == null or int(AS3.Number(sc)) < 0 else int(AS3.Number(sc))
	var mc = m.get("maxCyclesPerUpdate")
	maxCyclesPerUpdate = 2147483647 if mc == null or int(AS3.Number(mc)) < 0 else int(AS3.Number(mc))
	slavedUpdates = _truthy(m.get("slavedUpdates"))
	doNotSimulate = _truthy(m.get("doNotSimulate"))
	if m.get("anchored") != null:
		anchored = _truthy(m.anchored)
		extended = true
	if _truthy(m.get("floorAtKneeLevel")):
		var off = m.get("floorKneeOffset")
		floorKneeOffset = Vector2(off.x, off.y) if off != null else Vector2(85, 85)
		set_floor(g.her.torsoIK.targetPoint, g.her.torsoIK.targetPointCoordinateSpace)
	if m.get("rgbElement") != null:
		rgbHelper = g.characterControl.get(str(m.rgbElement)) as CharacterElementHelper
		if rgbHelper != null:
			set_fill(rgbHelper.rgb1, "rgbFill")
			set_fill(rgbHelper.rgb2, "rgbFill2")
	if not extended:
		return
	var sli = m.get("sharedLinkInfluences")
	if sli is Dictionary:
		sharedLinkInfluences = _link_keys(_keys(sli))
	relativeRotationMultipliers = _keys(m.get("relativeRotationMultipliers"))
	relativeRotationTargets = _keys(m.get("relativeRotationTargets"))
	minRotations = _keys(m.get("minRotations"))
	maxRotations = _keys(m.get("maxRotations"))
	custom_parent = m.get("visualParent") != null
	if m.get("anchorSource") != null:
		anchorSource = ext.find_path(her_g, str(m.anchorSource))
		if anchorSource == null:
			push_warning("dynamicHairExtender: anchorSource '%s' was not recognized" % m.anchorSource)
		elif _truthy(m.get("hideAnchor")):
			anchorSource.visible = false   # direct: the mod's own setting (its anchor marker hidden)
	if not segments.is_empty():
		ropeAnchorPoint = Vector2(segments[0].x, segments[0].y)
	_prepare()
	var usp = m.get("useSkinPalette")
	if usp is Dictionary:
		for k in usp:
			if str(k).is_valid_float() and _truthy(usp[k]):
				var si := int(float(k))
				if si >= 0 and si < segments.size():
					skinSegments.append(segments[si])
		set_skin(g.characterControl.currentSkin)


## Segments named SHARED_<x> (and the graphic itself, which stands for link 0): the first strand with the name owns
## the link after the segment, later ones use that same link.
func _share_links() -> void:
	for s in segments + [ropeGraphic]:
		var n := str(s.flash_name)
		if not SHARED_PREFIX in n:
			continue
		var li: int = segments.find(s) + 1
		if li >= links.size():
			continue
		var owner = ext.shared_links.get(n)
		if owner == null or not is_instance_valid(owner[1]):
			ext.shared_links[n] = [links[li], self]
			ext.shared_ropes[str(ropeGraphic.flash_name)] = self
		else:
			links[li] = owner[0]
			if owner[1] != self:
				sharedRopes[owner[1]] = true
				owner[1].sharedRopes[self] = true


func set_skin(skin: int) -> void:
	var label := g.dataName(CharacterControl.skinNameList[skin]) if skin >= 0 and skin < CharacterControl.skinNameList.size() else ""
	for s in skinSegments:
		if s is FlashMovieClip and label != "":
			s.gotoAndStop(label)


## rgbElement: one of the helper's colours on this strand's parts of that name (the mod's fillOverrides can rename it).
func set_fill(c, fill_name: String) -> void:
	if c == null:
		return
	var overrides = ropeGraphic.get("fillOverrides")
	if overrides is Dictionary and overrides.has(fill_name):
		fill_name = str(overrides[fill_name])
	CharacterElementHelper.tryToSetFillChildren(ropeGraphic, fill_name, CharacterControl._ct(c))


## floorAtKneeLevel: the floor's height in the scene, from her body's target point.
func set_floor(p: Vector2, space) -> void:
	if floorKneeOffset != null and space != null:
		maximumY = g.sceneLayer.globalToLocal(space.localToGlobal(p + floorKneeOffset)).y


func kill() -> void:
	for s in sharedRopes:
		if is_instance_valid(s):
			s.sharedRopes.erase(self)
	sharedRopes.clear()
	if ext != null:
		ext.forget(self)
	super.kill()


# ---------------------------------------------------------------- physics

## The per-segment settings as arrays (they do not change once the strand is set up; DHE looks them up by segment
## name, then index, every step).
func _prepare() -> void:
	var n := segments.size()
	_link_inf = PackedFloat32Array()
	for li in ropeLength + 1:
		var f := 1.0
		if sharedLinkInfluences != null:
			f = _num(sharedLinkInfluences.get(li), f)
		_link_inf.append(clampf(f, 0.0, 1.0))
	_seg = []
	for i in n:
		var nm := str(segments[i].flash_name)
		var rel_mult := _by(relativeRotationMultipliers, nm, i, 1.0)
		var min_rel := _by(minRotations, nm, i, -720.0)
		var max_rel := _by(maxRotations, nm, i, 720.0)
		_seg.append({
			"prox": clampf(_by(proximalElasticityFactors, nm, i, DEFAULT_ELASTICITY_PROXIMAL), 0.0, ELASTICITY_MAX),
			"dist": clampf(_by(distalElasticityFactors, nm, i, DEFAULT_ELASTICITY_DISTAL), 0.0, ELASTICITY_MAX),
			"elongate": _flag(allowElongations, nm, i), "compress": _flag(allowCompressions, nm, i),
			"blend": 0.0 if _flag(blendingExclusions, nm, i) else rotationBlending,
			"target": _by(relativeRotationTargets, nm, i, 0.0), "mult": rel_mult, "min": min_rel, "max": max_rel,
			"turn": rel_mult != 1.0 or min_rel > -720.0 or max_rel < 720.0,
			"limit": maxf(absf(min_rel), absf(max_rel)) != 720.0})


func move() -> void:
	if not extended:
		super.move()
		return
	if slavedUpdates:
		return   # the strand it shares links with steps it
	_load_rotations()
	for s in sharedRopes:
		if is_instance_valid(s) and s.slavedUpdates:
			s._load_rotations()
	for c in simCyclesPerUpdate:
		for s in sharedRopes:
			if is_instance_valid(s) and s.slavedUpdates and not s.doNotSimulate and c < s.maxCyclesPerUpdate:
				s.physics_step()
		physics_step()
	updateRopeGraphic()
	for s in sharedRopes:
		if is_instance_valid(s) and s.slavedUpdates:
			s.updateRopeGraphic()


## The segments' rotations as the physics sees them (Flash's -180..180), from the nodes once a frame: inside a frame
## DHE's turns live here, the nodes get their rotation in updateRopeGraphic.
func _load_rotations() -> void:
	_rots.resize(segments.size())
	for i in segments.size():
		_rots[i] = _rot(segments[i])


func physics_step() -> void:
	if _rots.size() != segments.size():
		_load_rotations()
	_to_graphic = _scene_to_graphic()
	_links_to_anchors(true)
	_gravity()
	_adjust_segments()


func _links_to_anchors(with_shared: bool) -> void:
	if anchored:
		if anchorSource != null and is_instance_valid(anchorSource):
			ropeAnchorPoint = Vector2(anchorSource.x, anchorSource.y)
		ropeCurrentAnchor = g.sceneLayer.globalToLocal(ropeAnchorContainer.localToGlobal(ropeAnchorPoint))
		links[0].x = ropeCurrentAnchor.x
		links[0].y = ropeCurrentAnchor.y
	if with_shared:
		for s in sharedRopes:
			if is_instance_valid(s) and s.doNotSimulate:
				s._links_to_anchors(false)


func _gravity() -> void:
	var go := gOffset
	if Hooks.has_value(&"Rope.gravityOffset"):   # HOOK value point: as in Rope.move
		go = Hooks.value(&"Rope.gravityOffset", self, gOffset)
	var a := (180.0 + go) * PI / 180.0
	gravityDirection = Vector2(sin(a), -cos(a))
	for i in ropeLength + 1:
		_move(links[i], gravityDirection, _link_inf[i] * links[i].mass, maximumY)


## DHE's adjustSegment, segment by segment: each turns toward its rotation relative to the one before it (the first:
## relative to the anchor container), which moves the next link, then both links are pulled to the segment's length.
## A turned segment counts as turned for the next one; afterwards its rotation is that of the blended direction.
func _adjust_segments() -> void:
	var n := segments.size()
	var prev_rot := _rot(ropeAnchorContainer)
	var after := PackedFloat32Array()
	after.resize(n)
	for i in n:
		var st: Dictionary = _seg[i]
		var a: Rope.RopeLink = links[i]
		var b: Rope.RopeLink = links[i + 1]
		var cur_inf: float = _link_inf[i]
		var next_inf: float = _link_inf[i + 1]
		var cur_rot: float = _rots[i]
		var turned := cur_rot
		after[i] = cur_rot
		if st["turn"]:
			var rel: float = fmod(cur_rot - (prev_rot + float(st["target"])) + 540.0, 360.0) - 180.0
			var cur_vec := _to_graphic * Vector2(b.x, b.y) - _to_graphic * Vector2(a.x, a.y)
			var seg_vec: Vector2 = Vector2.from_angle(deg_to_rad(cur_rot + 90.0)) * (float(segments[i].scaleY) * float(segLength[i]))
			var rot_vec: Vector2 = cur_vec + (seg_vec - cur_vec) * float(st["blend"])   # Point.interpolate(seg, cur, blend)
			var old := g.getAngle(rot_vec.x, rot_vec.y) + 180.0
			var c: float = cur_rot - rel * (1.0 - float(st["mult"]))
			rel = fmod(c - prev_rot + 540.0, 360.0) - 180.0
			if st["limit"]:
				var mn: float = st["min"]
				var mx: float = st["max"]
				if fmod(rel - mn + 720.0, 360.0) >= fmod(rel - mx + 720.0, 360.0):
					if absf(fmod(mn - rel + 180.0, 360.0) - 180.0) < absf(fmod(mx - rel + 180.0, 360.0) - 180.0):
						c = prev_rot + mn
					else:
						c = prev_rot + mx
			turned = wrapf(fmod(720.0 + c, 360.0), -180.0, 180.0)   # set as Flash rotation, read back normalized
			var pivot := Vector2(a.x, a.y)
			var goal := pivot + (Vector2(b.x, b.y) - pivot).rotated(deg_to_rad(turned - old))
			_move(b, goal - Vector2(b.x, b.y), next_inf)
			after[i] = wrapf(fmod(old, 360.0), -180.0, 180.0)
		if cur_inf * st["prox"] > 0.0 or next_inf * st["dist"] > 0.0:
			var link_dist := Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))
			var cv := Vector2(b.x - a.x, b.y - a.y)
			if cv.length() > 0.0:
				cv = cv.normalized() * (segLength[i] - link_dist)
				if not (st["elongate"] and segLength[i] < link_dist) and not (st["compress"] and segLength[i] > link_dist):
					_move(a, cv, -cur_inf * st["prox"])
					_move(b, cv, next_inf * st["dist"])
		prev_rot = turned
	for i in n:
		_rots[i] = after[i]


func updateRopeGraphic() -> void:
	if not (extended and custom_parent):
		super.updateRopeGraphic()
		return
	var t := _scene_to_graphic()
	for i in ropeLength:
		var a := t * Vector2(links[i].x, links[i].y)
		var b := t * Vector2(links[i + 1].x, links[i + 1].y)
		var d := b - a
		var sg = segments[i]
		var sy: float = d.length() / segLength[i]
		# x, y, rotation and scaleY (and scaleX if isotropic) in one transform: one change notification, not four
		sg.transform = Transform2D(deg_to_rad(g.getAngle(d.x, d.y) + 180.0), Vector2(sy if isotropicScaling else sg.scale.x, sy),
			sg.skew, a)


# ---------------------------------------------------------------- helpers

## ropeGraphic.globalToLocal(sceneLayer.localToGlobal(p)) as one transform.
func _scene_to_graphic() -> Transform2D:
	return ropeGraphic.flash_global_transform().affine_inverse() * g.sceneLayer.flash_global_transform()


## RopeLink.moveInfluenced (DHE adds it to the game's links): moved by v * f, not below max_y.
static func _move(l, v: Vector2, f: float, max_y := INF) -> void:
	l.lastPos = Vector2(l.x, l.y)
	l.x += v.x * f
	l.y += v.y * f
	l.y = minf(l.y, max_y)


## Flash's rotation: degrees in -180..180.
static func _rot(o) -> float:
	if o == null:
		return 0.0
	return wrapf(o.rotation_degrees, -180.0, 180.0)


## `v as Number || fallback`: 0, NaN and anything not a number fall back.
static func _num(v, fallback: float) -> float:
	if not (v is float or v is int):
		return fallback
	var f := float(v)
	return fallback if f == 0.0 or is_nan(f) else f


## A per-segment setting by the segment's name, else its index, else the fallback (AS3's `||` chain).
static func _by(d: Dictionary, n: String, i: int, fallback: float) -> float:
	return _num(d.get(n), _num(d.get(i), fallback)) if n != "" else _num(d.get(i), fallback)


static func _flag(d: Dictionary, n: String, i: int) -> bool:
	return (n != "" and _truthy(d.get(n))) or _truthy(d.get(i))


static func _truthy(v) -> bool:
	return v != null and FlashAbc._truthy(v)


## A mod's Dictionary with its keys as the scripts meant them: numbers (the interpreter stores "1" or "1.0") as
## ints, segment names as strings.
static func _keys(d) -> Dictionary:
	var out := {}
	if not d is Dictionary:
		return out
	for k in d:
		var s := str(k)
		out[int(float(s)) if s.is_valid_float() else s] = d[k]
	return out


## Segment names as link indices (the link after the segment), as DHE's convertSegmentNamesToLinkIndices.
func _link_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		if k is int:
			out[k] = d[k]
	for k in d:
		if k is String:
			var c = ropeGraphic.getChildByName(k)
			var li := segments.find(c)
			if c != null and li != -1:
				out[li + 1] = d[k]
	return out
