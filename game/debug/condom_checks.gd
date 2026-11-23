extends RefCounted
## Checks of the condoms plugin (Mods/Plugins/condoms; tools/regress.sh copies the shipped plugins into the mods
## folder): it rolls on, he comes into it, [CONDOM_OFF] has his hand take it off and tie it, it is pinned on her head,
## [CONDOM_ON] puts on a new one, and a full one stuck deep in her throat holds her head at its limit until it has been
## pulled there its stuck time (by her own pull-off or by him), then pops out. Also its dialogue line types (with a small test dialogue) and variables.
## Prints "CONDOM CHECKS: n passed, m failed".

var _pass := 0
var _fail := 0
var _t0 := -1
var _steps: Array = []   # [tick from the start, Callable]
var _next := 0
var x: SDTExtension = null   # the condoms plugin
var da = null                # DialogueActions
var _built := {}             # line type -> it built up at some tick
var _stuck_at := -1          # the tick the sack got stuck at its limit, and the one it popped out
var _pop_at := -1
var _pops := 0
var _held: Array[float] = []   # the latex's stretch each tick while stuck, as a share of its limit
var _off_in_mouth := true


func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("CHECK %s %s%s" % ["ok  " if ok else "FAIL", name, "" if ok or detail == "" else " (%s)" % detail])


func _init() -> void:
	_at(0, func(): Flash.stage.getChildAt(0).playClicked())
	_at(1, _start)
	_at(5, func(): x.set_worn(true))
	_at(30, _on_checks)
	_at(31, func(): g.him.ejaculate())
	_at(100, _filled_checks)
	_at(101, func(): da.run_code("[CONDOM_OFF]"))
	_at(102, func(): _check("[CONDOM_OFF] with cum in it: his hand takes it off", x._off != 0, "off %d" % x._off))
	_at(160, _tied_checks)
	_at(161, _aim)
	_at(190, _pin)
	_at(192, func(): _check("line type condom_pinned built", _built.has("condom_pinned")))
	_at(200, func(): da.run_code("[CONDOM_ON]"))
	_at(225, _on_again_checks)
	# a full one, then into her mouth (grab her head, then in), deep past her throat ring, and pulled back out
	_at(226, func(): x.add_cum(x.FULL * 0.4))
	for k in 7:
		_at(230 + k, func(): _move(Vector2(300, 250)))
		_at(238 + k, func(): _move(Vector2(-300, 250)))
	for k in 120:
		_at(250 + k, func(): _move(Vector2(lerpf(0.0, 900.0, minf(1.0, k / 60.0)), 240)); _watch())
	_at(300, func():
		_off_in_mouth = g.him.inMouth
		da.run_code("[CONDOM_OFF]"))
	_at(301, func(): _check("[CONDOM_OFF] while he is in her mouth: it stays on", not _off_in_mouth or (x.worn and x._off == 0)))
	_at(330, _deep_checks)
	for k in 200:
		_at(370 + k, func(): _move(Vector2(0, 240)); _watch())
	_at(570, _stuck_checks)


func step(_frame: int) -> void:
	if _t0 < 0:
		if not Extensions.started:
			return
		_t0 = Flash.tick_count
	var t := Flash.tick_count - _t0
	if x != null and g.dialogueControl != null:
		for k in x.LINES:
			if g.dialogueControl.states.has(k) and g.dialogueControl.states[k].build > 0.0:
				_built[k] = true
	while _next < _steps.size() and _steps[_next][0] <= t:
		_steps[_next][1].call()
		_next += 1


func _at(tick: int, f: Callable) -> void:   # (kept in tick order; the same tick: in the order added)
	var i := _steps.size()
	while i > 0 and _steps[i - 1][0] > tick:
		i -= 1
	_steps.insert(i, [tick, f])


func _move(p: Vector2) -> void:
	Flash.get_tree().current_scene._move(p)


func _var(name: String) -> String:
	return da.vars.value_text(name)


func _start() -> void:
	x = Extensions.get_extension("condoms")
	da = Extensions.get_extension("dialogueactions")
	_check("condoms plugin present and on", x != null and x.enabled)
	_check("DialogueActions on", da != null and da.enabled)
	if x == null or not x.enabled or da == null or not da.enabled:
		_finish()
		return
	var lines := ""
	for k in x.LINES:
		lines += '%s:"%s."\n' % [k, k]
	g.dialogueControl.loadCustomDialogue(lines, false)
	# so he goes in and deep at once, whatever her mood (the condom's own hold on her head stays: Her.holdOut)
	for vp in [&"Her.resistance", &"Her.pushBack"]:
		Hooks.add_modifier(vp, {"phase": Hooks.FINAL, "op": "set", "value": 0.0}, "test")


func _on_checks() -> void:
	_check("it rolled on", x.worn and x.roll >= 1.0 and x.condom != null, "worn %s roll %.2f" % [x.worn, x.roll])
	_check("line type condom_on built", _built.has("condom_on"))
	_check("variable condoms.worn is 1", _var("condoms.worn") == "1", _var("condoms.worn"))


func _filled_checks() -> void:
	_check("he came into it", x.cum > 0.0, str(x.cum))
	_check("line type condom_filled built", _built.has("condom_filled"))
	_check("variable condoms.full follows its cum", _var("condoms.full") == str(roundi(100.0 * x.cum / x.FULL)), _var("condoms.full"))


func _tied_checks() -> void:
	_check("taken off and tied: in his hand", x.tied != null and not x.worn and x._off == 0,
		"tied %s worn %s off %d" % [x.tied != null, x.worn, x._off])


func _aim() -> void:
	x.pins.start_aim()
	x.pins.test_aim = g.her.head.getBounds(Flash.stage).get_center()


func _pin() -> void:
	_check("pinned on her head", x.pins.pin_here(x.pins.test_aim), str(x.pins.test_aim))
	_check("variable condoms.pinned is 1", _var("condoms.pinned") == "1", _var("condoms.pinned"))


func _on_again_checks() -> void:
	_check("[CONDOM_ON] puts on a new one", x.worn and x.roll >= 1.0 and x.cum == 0.0, "worn %s roll %.2f cum %.1f" % [x.worn, x.roll, x.cum])


func _deep_checks() -> void:
	_check("deep in her throat with a full one", g.him.inMouth and x.condom != null and x.condom.past,
		"in mouth %s past %s depth %.1f" % [g.him.inMouth, x.condom.past if x.condom != null else false, g.her.penisInMouthDist])
	_pops = x.condom.pops if x.condom != null else 0


## From deep in her throat on: when it gets stuck at its limit, his depth while it holds, and when it pops out.
func _watch() -> void:
	var c = x.condom
	if c == null or Flash.tick_count - _t0 < 300:
		return
	var t := Flash.tick_count - _t0
	if _stuck_at < 0 and c.stuck_event:
		_stuck_at = t
	if _stuck_at >= 0 and _pop_at < 0:
		if c.pops > _pops:
			_pop_at = t
		else:
			_held.append(c.stretch / (c.POP_BASE + c.POP_FULL * c.heft(x.bulb_radius())))


func _stuck_ticks() -> float:
	return x.condom.stuck_ticks(x.bulb_radius())


func _stuck_checks() -> void:
	_check("pulled out, it got stuck at its limit", _stuck_at >= 0)
	_check("line type condom_stuck built", _built.has("condom_stuck"))
	var want := _stuck_ticks()
	var took := _pop_at - _stuck_at
	_check("it popped out after its stuck time", _pop_at >= 0 and took >= want - 2 and took <= want * 1.5,
		"stuck at %d, popped at %d, want %.0f ticks" % [_stuck_at, _pop_at, want])
	var hi := 0.0
	for f in _held:
		hi = maxf(hi, f)
	_check("held there: her head goes no further out than its limit (a little past it as she stops)", _held.size() > 10 and hi < 1.3,
		"%d ticks, stretch up to %.2f of its limit" % [_held.size(), hi])
	_gone_checks()
	_finish()


## It goes away while its sack holds her (e.g. his penis changed to the strap-on): her squint, tremble, hold and the
## lump in her neck go with it.
func _gone_checks() -> void:
	var c = x.condom
	if c == null:
		_check("a condom there to take away", false)
		return
	var her: Her = g.her
	x.condom = null   # (the values with no condom at all)
	var none := _effects(her)
	x.condom = c
	c.strain_k = 0.8
	c.drag_add = -0.02
	c.grip_out = 0.5
	c.grip_in = 0.3
	c.bumps = [{"at": 0.5, "size": 10.0}]
	var stuck := _effects(her)
	x._remove()
	var after := _effects(her)
	_check("taken away while stuck: no squint, tremble, hold or lump left", stuck != none and after == none,
		"none %s, stuck %s, after %s" % [none, stuck, after])


## What the condom's sack does to her: [eyelid target, tremble, hold out, drag, neck bumps].
func _effects(her: Her) -> Array:
	return [Hooks.value(&"Her.eyelidTarget", her, 0.0), Hooks.value(&"Her.tremble", her, 0.0),
		Hooks.value(&"Her.holdOut", her, 0.0), Hooks.value(&"Her.drag", her, 0.0),
		Hooks.value(&"Neck.bumps", her.head.neck, [])]


func _finish() -> void:
	print("CONDOM CHECKS: %d passed, %d failed" % [_pass, _fail])
	Flash.get_tree().quit()
