extends RefCounted
## Pinning the condom he holds on her, and the ones pinned on her or falling. While he holds a tied one, a short Q
## press starts pin mode: the mouse moves his left hand (the knot at the bottom of his fist goes to the mouse, as far
## as his arm reaches) and her head stays where it was; a left click on her pins it there (skin, clothes, hair: what
## shows at the mouse; it goes there from his hand even where his arm does not reach), where it hangs from the knot,
## swings and moves with that part of her. A right click, Esc or a short Q
## press stops pin mode (he keeps it); a long Q press (in pin mode or not) drops it: it falls off the screen.
## At most MAX are pinned (the oldest goes); they last this play session (they are not in the character code).
## Clicks in pin mode are taken before the game sees them (no grabbing her, no spanking).

const MAX := 20
const LONG_TICKS := 12          # Q held this long (0.4 s) drops it
const AIM_EASE := 0.4           # his hand goes this much of the way to the mouse each tick
## Her parts it can be pinned on (paths from her), front-most first where they overlap: each moves on its own
const PARTS := ["head", "collarContainer", "hairBackContainer", "torso.back", "torso.midLayer.chest", "torso.midLayer.rightBreast", "torsoBack.leftBreast",
	"torso.leg.thigh", "torso.rightCalfContainer.calf", "rightArmContainer.upperArm",
	"rightForeArmContainer.upperArm.foreArm", "leftArmContainer.upperArm", "leftArmContainer.upperArm.foreArm",
	"torso"]

var x                           # the plugin
var aiming := false             # pin mode
var pinned: Array = []          # tied.gd, pinned on her (oldest first)
var falling: Array = []         # tied.gd, dropped
var layer: FlashSprite          # where they are drawn: right above her
var _goal := Vector2()          # where the knot goes this tick (stage coordinates)
var _held := Vector2(NAN, NAN)  # the game's mouse point as pin mode started (her head stays there)
var _eat_up := false            # a press was taken: its release too,
var _eat_click := false         #   and the click right after that release
var _q_down := false            # Q is down (while he holds one: short or long press)
var _q_t := 0
var _q_used := false            # ... the long press already dropped it
var test_aim := Vector2(NAN, NAN)   # tests: aim here instead of at the mouse (stage coordinates)


func _init(plugin) -> void:
	x = plugin
	layer = FlashSprite.new()
	layer.mouseEnabled = false
	layer.mouseChildren = false
	Flash.stage.addEventListener(FlashEvent.MOUSE_DOWN, _down, true, 1000)
	Flash.stage.addEventListener(FlashEvent.MOUSE_DOWN, _down_stage, false, 1000)
	Flash.stage.addEventListener(FlashEvent.MOUSE_UP, _up, true, 1000)
	Flash.stage.addEventListener(FlashEvent.MOUSE_UP, _up_stage, false, 1000)
	Flash.stage.addEventListener(FlashEvent.CLICK, _up, true, 1000)
	Flash.stage.addEventListener(FlashEvent.CLICK, _up_stage, false, 1000)
	Flash.stage.addEventListener(FlashEvent.RIGHT_MOUSE_DOWN, _right, true, 1000)
	Flash.stage.addEventListener(FlashEvent.RIGHT_MOUSE_DOWN, _right_stage, false, 1000)
	Flash.stage.addEventListener(FlashEvent.KEY_UP, _key_up, false, 1000)


## The plugin is switched off: all of them go, the listeners too.
func free_all() -> void:
	Flash.stage.removeEventListener(FlashEvent.MOUSE_DOWN, _down, true)
	Flash.stage.removeEventListener(FlashEvent.MOUSE_DOWN, _down_stage, false)
	Flash.stage.removeEventListener(FlashEvent.MOUSE_UP, _up, true)
	Flash.stage.removeEventListener(FlashEvent.MOUSE_UP, _up_stage, false)
	Flash.stage.removeEventListener(FlashEvent.CLICK, _up, true)
	Flash.stage.removeEventListener(FlashEvent.CLICK, _up_stage, false)
	Flash.stage.removeEventListener(FlashEvent.RIGHT_MOUSE_DOWN, _right, true)
	Flash.stage.removeEventListener(FlashEvent.RIGHT_MOUSE_DOWN, _right_stage, false)
	Flash.stage.removeEventListener(FlashEvent.KEY_UP, _key_up, false)
	aiming = false
	for t in pinned + falling:
		t.release()
	pinned.clear()
	falling.clear()
	if layer.parent != null:
		layer.parent.removeChild(layer)


## Q pressed while he holds one (repeats while it is held down are not new presses).
func q_pressed() -> void:
	if _q_down:
		return
	_q_down = true
	_q_t = 0
	_q_used = false


func _key_up(e: FlashEvent) -> void:
	if not _q_down or e.keyCode != Hotkeys.binding(_key_id()) & Hotkeys.KEY_MASK:
		return
	_q_down = false
	if _q_used or x.tied == null:
		return
	if aiming:
		stop_aim()
	else:
		start_aim()


func start_aim() -> void:
	if x.tied == null or not x._hand_ok():
		return
	aiming = true
	_held = Vector2(NAN, NAN)
	_goal = x.tied.knot()


func stop_aim() -> void:
	aiming = false


## DT.mousePos: in pin mode her head stays where the mouse had it.
func mouse_pos(v: Vector2) -> Vector2:
	if not aiming:
		_held = Vector2(NAN, NAN)
		return v
	if is_nan(_held.x):
		_held = v
	return _held


## Where the knot goes in pin mode (stage coordinates).
func aim_goal() -> Vector2:
	return _goal


func tick() -> void:
	if _q_down:
		_q_t += 1
		var b: int = Hotkeys.binding(_key_id()) & Hotkeys.KEY_MASK
		if b >= 48 and b <= 90 and not Input.is_key_pressed(b):   # (letters and digits: the same codes in Godot)
			_key_up_code()   # (its release went elsewhere, e.g. the window lost focus)
		elif _q_t >= LONG_TICKS and not _q_used:
			_q_used = true
			drop()
	if aiming:
		if x.tied == null or not x._hand_ok() or g.gamePaused:
			aiming = false
		else:
			var m := Vector2(Flash.stage.mouseX, Flash.stage.mouseY) if is_nan(test_aim.x) else test_aim
			_goal = _goal.lerp(m, AIM_EASE)
	_keep_layer()
	var look := [x.get_setting("colour"), x.get_setting("density"), Color.hex((g.cumRGB << 8) | 0xFF)]
	for t in pinned:
		t.set_look(look[0], look[1], look[2])
		t.step()
	var bottom := Flash.stage.stageHeight + 200.0
	for t in falling.duplicate():
		t.set_look(look[0], look[1], look[2])
		t.step()
		if t.gone(bottom):
			t.release()
			falling.erase(t)


func _key_up_code() -> void:
	var e := FlashEvent.new(FlashEvent.KEY_UP, true)
	e.keyCode = Hotkeys.binding(_key_id()) & Hotkeys.KEY_MASK
	_key_up(e)


func _key_id() -> String:
	return x.id + ":condom"


## The one in his hand falls (from pin mode too).
func drop() -> void:
	if x.tied == null:
		return
	aiming = false
	_keep_layer()
	x.tied.drop(layer)
	falling.append(x.tied)
	x.tied = null


## Pins the one in his hand at the stage point `at`, if her part there shows. Returns whether it did.
func pin_here(at: Vector2) -> bool:
	if x.tied == null:
		return false
	var part := part_at(at)
	if part == null:
		return false
	var chain := _deepest(part, at)   # (on what shows there: a strand of hair that swings, her nipple...)
	_keep_layer()
	x.tied.pin(chain[0], x.tied.pin_knot(at), layer, chain.slice(1))   # (the knot's middle at the mouse)
	pinned.append(x.tied)
	x.tied = null
	aiming = false
	x.say("condom_pinned")
	while pinned.size() > MAX:
		pinned.pop_front().release()
	return true


## Her part that shows at the stage point (front-most), or null.
func part_at(p: Vector2) -> FlashDisplayObject:
	var best: FlashDisplayObject = null
	for path in PARTS:
		var n := _node(path)
		if n == null or not n.hitTestVisible(p.x, p.y):
			continue
		if best == null or (n.is_greater_than(best) and not best.is_ancestor_of(n) and not n.is_ancestor_of(best)):
			best = n
	return best


## From `part` down to the deepest container that shows at the stage point p: [that, its parent, ..., part].
static func _deepest(part: FlashDisplayObject, p: Vector2) -> Array:
	var chain := [part]
	var o: FlashDisplayObject = part
	while o is FlashSprite:
		var next: FlashDisplayObject = null
		for i in range(o.numChildren - 1, -1, -1):
			var ch = o.getChildAt(i)
			if ch is FlashSprite and ch.visible and ch.hitTestVisible(p.x, p.y):
				next = ch
				break
		if next == null:
			break
		o = next
		chain.push_front(o)
	return chain


static func _node(path: String) -> FlashDisplayObject:
	var o = g.her
	for k in path.split("."):
		if o == null:
			return null
		o = o.get(k)
	return o if o is FlashDisplayObject else null


## The layer right above her.
func _keep_layer() -> void:
	var her: FlashDisplayObject = g.her
	if her == null or her.parent == null:
		return
	var host: FlashDisplayObject = her.parent
	if layer.parent != host:
		if layer.parent != null:
			layer.parent.removeChild(layer)
		host.addChildAt(layer, host.getChildIndex(her) + 1)
	elif host.getChildIndex(layer) != host.getChildIndex(her) + 1:
		host.setChildIndex(layer, mini(host.numChildren - 1, host.getChildIndex(her) + (1 if host.getChildIndex(layer)
			> host.getChildIndex(her) else 0)))


# ---------------------------------------------------------------- the mouse in pin mode

## A press in pin mode (capture: before anything below the stage sees it): pins it, unless it is on the classic menu.
func _down(e: FlashEvent) -> void:
	if not aiming or _on_menu(e.target):
		return
	e.stopImmediatePropagation()
	_eat_up = true
	pin_here(Vector2(e.stageX, e.stageY))


## ... and on the stage itself (outside the scene's objects: the game would grab her)
func _down_stage(e: FlashEvent) -> void:
	if aiming and e.target == Flash.stage:
		e.stopImmediatePropagation()
		_eat_up = true
		pin_here(Vector2(e.stageX, e.stageY))


func _up(e: FlashEvent) -> void:
	if e.type == FlashEvent.CLICK:
		if _eat_click:
			e.stopImmediatePropagation()
			_eat_click = false
		return
	if _eat_up:
		e.stopImmediatePropagation()
		_eat_up = false
		_eat_click = true   # (the click comes right after the release, in the same input event)
		(func(): _eat_click = false).call_deferred()


func _up_stage(e: FlashEvent) -> void:
	if e.target == Flash.stage:
		_up(e)


func _right(e: FlashEvent) -> void:
	if aiming:
		e.stopImmediatePropagation()
		stop_aim()


func _right_stage(e: FlashEvent) -> void:
	if aiming and e.target == Flash.stage:
		stop_aim()


func _on_menu(t) -> bool:
	var m = g.inGameMenu
	while t != null:
		if t == m:
			return true
		t = t.parent if t is FlashDisplayObject else null
	return false
