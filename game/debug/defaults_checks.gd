extends RefCounted
## Checks of the game as players get it: not in Vanilla mode, every extension at its default, the shipped plugins
## (tools/regress.sh copies Mods/Plugins into the mods folder), and the x-ray and its stomach switched on. Plays a
## short scene (grab, in her mouth, deep with cum in her mouth, he comes), then switches every extension off and on
## again. Any extension or plugin whose code fails is switched off by the plugin guard (its `fault`): checked at the
## end. Script errors during the run fail tools/regress.sh by themselves. Prints "DEFAULTS CHECKS: n passed, m failed".

var _pass := 0
var _fail := 0
var _t0 := -1
var _steps: Array = []   # [tick from the start, Callable]
var _next := 0
var _xray: SDTExtension = null
var _drained := false    # the x-ray drained cum from her mouth at least once
var _on_before: Array[String] = []


func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("CHECK %s %s%s" % ["ok  " if ok else "FAIL", name, "" if ok or detail == "" else " (%s)" % detail])


func _init() -> void:
	_at(0, func(): Flash.stage.getChildAt(0).playClicked())
	_at(1, _start_checks)
	for k in 7:   # grab her head: a move to the far left
		_at(30 + k, func(): _move(Vector2(300, 250)))
		_at(38 + k, func(): _move(Vector2(-300, 250)))
	for k in 60:   # in her mouth
		_at(50 + k, func(): _move(Vector2(330, 240)))
	_at(109, _mouth_checks)
	_at(110, func(): g.her.cumInMouth = 30)
	for k in 90:   # deep, his tip past the ring below her mouth
		_at(110 + k, func(): _move(Vector2(540, 240)); _drained = _drained or _xray._view.drain() > 0.0)
	_at(199, _drain_checks)
	_at(200, func(): g.him.ejaculate())
	for k in 60:
		_at(200 + k, func(): _move(Vector2(540, 240)))
	_at(260, func(): _move(Vector2(150, 240)))   # out
	_at(289, _fault_check.bind("while playing"))   # (switching one on again clears its fault)
	_at(290, _toggle_all.bind(false))
	_at(295, _toggle_all.bind(true))
	_at(320, _end_checks)


func step(_frame: int) -> void:
	if _t0 < 0:
		if not Extensions.started:
			return
		_t0 = Flash.tick_count
	var t := Flash.tick_count - _t0
	while _next < _steps.size() and _steps[_next][0] <= t:
		_steps[_next][1].call()
		_next += 1


func _at(tick: int, f: Callable) -> void:
	_steps.append([tick, f])


func _move(p: Vector2) -> void:
	Flash.get_tree().current_scene._move(p)


func _start_checks() -> void:
	_check("not in Vanilla mode", not Extensions.vanilla_mode)
	var off := []
	for ext in Extensions.all:
		if ext.default_enabled and not ext.enabled:
			off.append(ext.id)
	_check("every extension on by default is on", off.is_empty(), str(off))
	var plugins := []
	for ext in Extensions.all:
		if ext.folder != "":
			plugins.append(ext.id)
	var shipped := DirAccess.get_directories_at(Flash.mods_dir("Plugins"))
	_check("every shipped plugin loaded", plugins.size() == shipped.size() and shipped.size() > 0,
		"%d of %d" % [plugins.size(), shipped.size()])
	_xray = Extensions.get_extension("xray")
	_check("x-ray plugin present", _xray != null)
	if _xray == null:
		_finish()
		return
	_xray.set_setting("on", true)
	_xray.set_setting("stomach", true)
	# so he goes in and deep at once (as the scratch drivers do), whatever her mood
	for vp in [&"Her.drag", &"Her.resistance", &"Her.pushBack"]:
		Hooks.add_modifier(vp, {"phase": Hooks.FINAL, "op": "set", "value": 0.0}, "test")


func _mouth_checks() -> void:
	_check("he is in her mouth", g.her.mouthFull, str(g.her.penisInMouthDist))
	_check("x-ray shows him in her mouth", _xray._view != null and _xray._view.shown >= 1.0 and not _xray._view.mouth_only)
	_check("x-ray stomach shows with it", _xray._stomach != null and _xray._stomach.shown >= 1.0)


func _drain_checks() -> void:
	var v = _xray._view
	_check("deep: the cum in her mouth drains down", _drained and g.her.cumInMouth < 30, "in her mouth %d, tip %.1f, ring %.1f"
		% [g.her.cumInMouth, v._inside / v.STEP, v._gate_f])
	_check("deep: her stomach fills", _xray._stomach.amount > 0.0, str(_xray._stomach.amount))


func _toggle_all(on: bool) -> void:
	if not on:
		_on_before.clear()
		for ext in Extensions.all:
			if ext.enabled:
				_on_before.append(ext.id)
	for id in _on_before:
		Extensions.set_enabled(id, on)


func _end_checks() -> void:
	var off := []
	for id in _on_before:
		if not Extensions.get_extension(id).enabled:
			off.append(id)
	_check("every extension on again after off and on", off.is_empty(), str(off))
	_fault_check("switched off and on")
	_tied_hands_check()
	_finish()


## armoverhaul's resistance (her arms slow her head) only from her free arms: none while a body position holds both
## (her hands tied above her head), all of it again once the position ends.
func _tied_hands_check() -> void:
	var ao: SDTExtension = Extensions.get_extension("armoverhaul")
	var pe: SDTExtension = Extensions.get_extension("positions")
	var was_on: bool = pe.enabled
	Extensions.set_enabled("positions", true)
	var text := "posversion=34;positiontype=0;armpostypeleft=12;armpostyperight=12;armposx=-332;armposy=-202;" \
		+ "armpos2x=-315;armpos2y=-192"
	var p = preload("res://src/ext/positions/position.gd").from_text(text.replace(";", "\n"), "test/tied")
	pe.apply(p)
	var tied: int = ao.hands.free_arms()
	ao.hands.resistance = 1.0
	ao.hands._resist(g.her)
	var drag: float = ao.hands.drag
	pe.clear()
	var free: int = ao.hands.free_arms()
	Extensions.set_enabled("positions", was_on)
	_check("armoverhaul: no arm resistance while a position holds both her arms, both free again after", tied == 0
		and drag == 0.0 and free == 2, "%d %s %d" % [tied, drag, free])


func _fault_check(when: String) -> void:
	var faults := []
	for ext in Extensions.all:
		if ext.fault != "":
			faults.append("%s: %s" % [ext.id, ext.fault])
	_check("no extension or plugin failed %s (plugin guard)" % when, faults.is_empty(), str(faults))


func _finish() -> void:
	print("DEFAULTS CHECKS: %d passed, %d failed" % [_pass, _fail])
	Flash.get_tree().quit()
