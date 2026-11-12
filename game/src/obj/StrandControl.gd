class_name StrandControl
extends RefCounted
## Port of obj.StrandControl: owns the spit / cum strands.
##
## Port: with the native extension the strands are simulated and drawn by SDTFluids (native/src/fluids.cpp): plain
## data and one call per tick instead of a display object and dozens of script calls per strand and link. This class
## keeps the game-facing API, returning NativeStrand handles; each tick it sends the body parts' transforms and the
## collision targets, runs the simulation, applies its events (cum on her face, eye hits, the tongue, drips) and
## draws one mesh per strand layer. Without the extension the original GDScript Strand / StrandLink are used.

var strands: Array = []
var cumStrands: Array = []
var lockedStrands: Array = []
const maxStrands := 20
var cumMinThickness := 1.0   # port: a cum strand link is drawn at least this thick (the game: 1; morecumspurts)

static var native_enabled: bool = ClassDB.class_exists(&"SDTFluids") and not "--nonative" in OS.get_cmdline_user_args()

var fluids = null                    # SDTFluids
var _containers: Dictionary = {}     # display object -> container index
var _container_objs: Array = []      # index -> display object
var _layers: Array = []              # strandBackLayer, strandFrontLayer, cumLayer
var _meshes: Array = []              # a FlashSprite per layer, drawing that layer's strands
var _shown: Array = []               # per layer: it has strands now
var _changed_only := false           # the library skips rebuilding unchanged meshes (get_mesh_changed)

enum { EV_CUM_ON_FACE, EV_EYE_HIT, EV_EYE_CLEAR, EV_TONGUE_CUM_HIT, EV_TONGUE_CUM_REMOVED, EV_DROPLET }
const IN_HEAD := 1
const HIM := 2
const SCENE := 4
const TONGUE_TIP := 8
const TARGET_FACE := 1
const TARGET_TONGUE := 2


func newStrand(layer: FlashSprite, links: int, mass: float, a = null, b = null, long: bool = false,
		initialSpeed = null, back: bool = false):
	if _native():
		push_transforms()
		var id: int = fluids.new_strand(_layer_index(layer), links, mass, _anchor(a), _anchor(b), long, back,
			initialSpeed if initialSpeed != null else Vector2())
		return NativeStrand.new(fluids, id)
	var s := Strand.new(layer, links, mass, a, b, long, back)
	s.instancePoints(initialSpeed)
	layer.addChild(s)
	strands.append(s)
	return s


func checkElementAnchors(element: FlashDisplayObject) -> void:
	if _native():
		if _containers.has(element):
			fluids.detach_container(_containers[element])
		return
	for s in strands + cumStrands:
		s.checkElementAnchors(element)


func checkCostumeAnchors() -> void:
	if _native():
		for e in g.costumeHitElements:
			if _containers.has(e):
				fluids.detach_container(_containers[e])
		return
	for s in strands + cumStrands:
		s.checkCostumeAnchors()


func clearSpitStrands() -> void:
	if _native():
		fluids.clear(false)
		_apply_events(fluids.take_events())
		_draw()
		return
	for i in strands.size():
		strands[0].killMe()


## Port addition: removes the oldest spit strand (to make room for a new one at the limit, e.g. morespitstrands).
func killOldestSpit() -> void:
	if _native():
		if fluids.kill_oldest(false):
			_apply_events(fluids.take_events())
			_draw()
	elif not strands.is_empty():
		strands[0].killMe()


func clearCumStrands() -> void:
	if _native():
		fluids.clear(true)
		_apply_events(fluids.take_events())
		_draw()
	else:
		for i in cumStrands.size():
			cumStrands[0].killMe()
	for i in lockedStrands.size():
		lockedStrands[0].kill()


func smearStrands(p: Vector2, radius: float = 25.0) -> void:
	if _native():
		push_transforms()
		fluids.smear(g.sceneLayer.flash_global_transform().affine_inverse() * p, radius)
		_apply_events(fluids.take_events())
		return
	for s in strands + cumStrands:
		s.smear(p, radius)


func newCumStrand(p: Vector2, container: FlashDisplayObject):
	if _native():
		push_transforms()
		var id: int = fluids.new_cum_strand(2, g.randomCumMass(), p, container_index(container))
		return NativeStrand.new(fluids, id)
	var s := Strand.new(g.cumLayer, 1, g.randomCumMass())
	s.addSourceLink(p, container)
	g.cumLayer.addChild(s)
	cumStrands.append(s)
	return s


func addStrand(from: Strand, links: Array, mass: float) -> void:
	var s := Strand.new(from.layer, 0, mass)
	s.giveLinks(links)
	s.age = from.age
	s.ageMax = from.ageMax
	s.cumStrand = from.cumStrand
	from.layer.addChild(s)
	if from.cumStrand:
		cumStrands.append(s)
	else:
		strands.append(s)
	s.distSplitDelay = 10
	s.graphics.copyFrom(from.graphics)


func delistStrand(s: Strand) -> void:
	if s.cumStrand:
		cumStrands.erase(s)
	else:
		strands.erase(s)


func delistLockedStrand(s) -> void:
	lockedStrands.erase(s)


func maxPop() -> bool:
	if _native():
		return fluids.count(false) >= maxStrands
	return strands.size() >= maxStrands


## Port addition: the live spit (cum = false) or cum strands' alpha, oldest first (e.g. strandlimit).
func strand_alphas(cum: bool) -> PackedFloat32Array:
	if _native():
		return fluids.alphas(cum)
	var out := PackedFloat32Array()
	for s in (cumStrands if cum else strands):
		out.append(s.getAlpha())
	return out


## Port addition: ages the oldest live spit / cum strands, amounts[i] to the i-th oldest (they fade sooner).
func add_strand_ages(cum: bool, amounts: PackedInt32Array) -> void:
	if _native():
		fluids.add_ages(cum, amounts)
		return
	var list: Array = cumStrands if cum else strands
	for i in mini(amounts.size(), list.size()):
		list[i].age += amounts[i]


## Number of live spit (cum = false) or cum strands (tests).
func strand_count(cum: bool) -> int:
	if _native():
		return fluids.count(cum)
	return (cumStrands if cum else strands).size()


# ---------------------------------------------------------------- native fluid system

## True once the native fluid system runs (set up on first use, when the scene exists).
func _native() -> bool:
	if fluids != null:
		return true
	if not native_enabled or g.sceneLayer == null or g.strandBackLayer == null or g.her == null:
		return false
	fluids = ClassDB.instantiate(&"SDTFluids")
	_changed_only = fluids.has_method(&"get_mesh_changed")
	_layers = [g.strandBackLayer, g.strandFrontLayer, g.cumLayer]
	for l in _layers:
		var m := FlashSprite.new()
		m.mouseEnabled = false
		l.addChild(m)
		_meshes.append(m)
		_shown.append(false)
	var h: Her = g.her
	var scene := container_index(g.sceneLayer)
	fluids.set_special(container_index(h.head.face), container_index(h.head.jaw), container_index(h.eye.hitBox), scene)
	_set_params()
	# after all of the tick's game logic (her movement), whenever this is first used
	Flash.tick_after.append(_tick)
	if FlashRectClip.smooth:
		var drawer := _Drawer.new()
		drawer.control = self
		drawer.name = "FluidDrawer"
		Flash.add_child(drawer)
	return true


func _layer_index(layer: FlashSprite) -> int:
	return maxi(0, _layers.find(layer))


## Index of a body part (or any display object strands stick to), registered on first use.
func container_index(o: FlashDisplayObject) -> int:
	if o == null:
		return -1
	if _containers.has(o):
		return _containers[o]
	var flags := 0
	var h: Her = g.her
	if h != null and h.head != null and (o == h.head or h.head.contains(o)):
		flags |= IN_HEAD
	if g.him != null and (o == g.him or o == g.him.penis):
		flags |= HIM
	if o == g.sceneLayer:
		flags |= SCENE
	if h != null and o == h.tongueContainer.tongue.tipPoint:
		flags |= TONGUE_TIP
	var i: int = fluids.add_container(o, flags)
	_containers[o] = i
	_container_objs.append(o)
	push_transforms()
	return i


func _anchor(a):
	if a == null:
		return null
	return {"container": container_index(a.container), "local": a.localPoint, "force": a.forceHit}


## Sends every body part's transform (its space -> scene space).
func push_transforms() -> void:
	if fluids == null:
		return
	var inv := g.sceneLayer.flash_global_transform().affine_inverse()
	var out: Array = []
	out.resize(_container_objs.size())
	for i in _container_objs.size():
		var o = _container_objs[i]
		out[i] = inv * o.flash_global_transform() if is_instance_valid(o) else Transform2D()
	fluids.set_transforms(out)


func _scene_rect(o: FlashDisplayObject, inv: Transform2D) -> Rect2:
	return inv * o.getBounds(null)


## The collision targets in the order Strand.collide tests them.
func _targets(inv: Transform2D) -> Array:
	var h: Her = g.her
	var out: Array = []
	var plain := func(test: FlashDisplayObject, anchor: FlashDisplayObject, force: bool, need: Array = []) -> Dictionary:
		return {"obj": test, "inv": test.flash_global_transform().affine_inverse() * inv.affine_inverse(),
			"anchor": container_index(anchor), "force": force, "need": need}
	for e in g.costumeHitElements:
		if e.showing:
			out.append(plain.call(e, e, true))
	out.append(plain.call(h.eyewear, h.eyewear, true))
	var f: Dictionary = plain.call(h.head.face, h.head.face, false)
	f["kind"] = TARGET_FACE
	f["eye"] = _scene_rect(h.eye.hitBox, inv)
	out.append(f)
	out.append(plain.call(h.head.jaw, h.head.jaw, false))
	var tongue = h.tongueContainer.tongue
	if tongue.okayToHit():
		var t: Dictionary = plain.call(tongue, tongue.tipPoint, true)
		t["kind"] = TARGET_TONGUE
		t["hit_target"] = container_index(tongue)
		out.append(t)
	var breast = h.torso.midLayer.rightBreast
	out.append(plain.call(breast.hitArea, breast, false, [_scene_rect(breast, inv)]))
	var torso := [_scene_rect(h.torso, inv)]
	var leg: Dictionary = plain.call(h.torso.leg, h.torso.leg, false, torso + [_scene_rect(h.torso.leg, inv)])
	var calf = h.torso.rightCalfContainer.calf
	leg["exclude"] = calf
	leg["exclude_inv"] = calf.flash_global_transform().affine_inverse() * inv.affine_inverse()
	out.append(leg)
	out.append(plain.call(h.torso.midLayer.chest, h.torso.midLayer.chest, false, torso))
	out.append(plain.call(h.torso.back, h.torso.back, false, torso))
	if h.penisOn:
		out.append(plain.call(h.torso.penisContainer, h.torso.penisContainer, false, torso))
	return out


func _set_params() -> void:
	fluids.set_params({"gravity": g.gravity, "friction": g.friction, "max_mass": g.maxMass,
		"mass_generate_speed": g.massGenerateSpeed, "mass_flow": g.massFlow, "max_strand_length": g.maxStrandLength,
		"kill_y": g.screenSize.y * (1.0 / g.sceneZoom) + 10.0, "floor_y": 1220.0,
		"him_ejaculating": g.him.isEjaculating() if g.him != null else false,
		"cum_rgb": Color.hex((g.cumRGB << 8) | 0xFF), "tick": Flash.tick_count,
		"cum_min_thickness": cumMinThickness})


func _tick() -> void:
	if g.gamePaused:
		return
	push_transforms()
	_push_targets()
	_set_params()
	_apply_events(fluids.tick())
	if not FlashRectClip.smooth:
		_draw()
		return
	# the strand layers are render targets (the spit filters): without this they draw once per tick, at its start,
	# so the strands would show a tick behind her
	for i in _meshes.size():
		if _shown[i]:
			Flash.note_moved(_meshes[i].get_viewport())


## Sends this tick's collision targets. Only fluids.tick() tests them, and only for the strands alive when it starts
## (strands made later in the tick move from the next tick on, which sends its own targets): with none alive, building
## them (0.25 ms) is skipped. The targets left from an earlier tick are then never used.
func _push_targets() -> void:
	if fluids.count(false) + fluids.count(true) == 0:
		return
	fluids.set_targets(_targets(g.sceneLayer.flash_global_transform().affine_inverse()))


## Redraws the strands every rendered frame, between ticks like the body they stick to.
class _Drawer:
	extends Node
	var control

	func _process(_delta: float) -> void:
		control._draw()


## Draws the strands between their last two tick positions, like the body they stick to.
func _draw() -> void:
	var f := Engine.get_physics_interpolation_fraction() if FlashRectClip.smooth and not g.gamePaused else 1.0
	for i in _meshes.size():
		var m: Array = fluids.get_mesh_changed(i, f) if _changed_only else fluids.get_mesh(i, f)
		if m.is_empty():
			continue   # the same mesh as last time (settled strands, the same fraction): what is drawn stays
		var any := not (m[0] as PackedVector2Array).is_empty()
		if not any and not _shown[i]:
			continue
		var gr: FlashGraphics = _meshes[i].graphics
		gr.clear()
		_shown[i] = any
		if any:
			gr.setMesh(m[0], m[1], m[2], m[3] if m.size() > 3 else null)   # [3]: bounds (older libraries lack them)


func _apply_events(events: Array) -> void:
	for e in events:
		match int(e[0]):
			EV_CUM_ON_FACE:
				g.her.cumOnFace()
			EV_EYE_HIT:
				g.dialogueControl.triggerState(Dialogue.CUM_IN_EYE)
				g.her.eyeHit()
			EV_EYE_CLEAR:
				g.her.eyeClearHit()
			EV_TONGUE_CUM_HIT:
				g.her.tongueContainer.tongue.cumHit()
			EV_TONGUE_CUM_REMOVED:
				g.her.tongueContainer.tongue.cumRemoved()
				g.her.fillMouth(true)
			EV_DROPLET:
				var cum: bool = e[4]
				var drop := Droplet.new(e[1], e[2], 1, 0.02, e[3], cum)
				(g.cumLayer if cum else g.strandFrontLayer).addChild(drop)
