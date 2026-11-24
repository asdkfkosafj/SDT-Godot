extends Node2D
## Main scene: puts the Flash stage in the scene tree and starts the game's document class (DT).
## Debug options (after `--` on the command line): --shot=<file.png> [--frames=N] [--click=x,y@frame ...]
## saves a screenshot after N frames and quits; --click simulates a left click at stage coordinates.
## --eval=<expression>@frame runs a Godot Expression with `g`, `Flash` and `OS` available, e.g. --eval=g.him.ejaculate()@600
## --driver=res://debug/<script>.gd runs a scripted test: the script's step(frame: int) is called every frame.
## --save-dir=<folder> keeps the save files there instead of user:// (copy a save in first to test with it).
## --mods-dir=<folder> reads mods from that folder instead of Mods/ (an empty folder runs without mods).
## --mod-cache=<folder> keeps converted mods there instead of user://modcache (tests of converter changes).
## --vanilla keeps every port extension and plugin off (Vanilla mode, see src/ext/extensions.gd).
## --render-scale=<percent> draws the game at that render scale for the run, not saved (Settings > Graphics, RenderScale).
## Regression tests: tools/regress.sh (driver res://debug/regress.gd, reference dumps in tests/golden/).

var _shot := ""
var _frames := 60
var _clicks: Array = []
var _frame := 0
var _dump := ""
var _quit_at_end := false
var _picks: Array = []
var _hide: Array = []
var _counter: Label = null
var _driver = null
var presentation: Presentation


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--pick="):
			var pxy := a.substr(7).split(",")
			_picks.append(Vector2(float(pxy[0]), float(pxy[1])))
		elif a.begins_with("--key="):
			var kp := a.substr(6).split("@")
			_clicks.append([int(kp[1]) if kp.size() > 1 else 10, kp[0], "key"])
		elif a.begins_with("--hide="):
			_hide.append(a.substr(7))
		elif a.begins_with("--dump="):
			_dump = a.substr(7)
		elif a.begins_with("--eval="):
			var at := a.rfind("@")
			_clicks.append([int(a.substr(at + 1)), a.substr(7, at - 7), "eval"])
		elif a.begins_with("--driver="):
			var ds = load(a.substr(9))
			if ds == null or not ds.can_instantiate():   # missing, or it failed to compile
				push_error("--driver: cannot load %s" % a.substr(9))
				get_tree().quit(1)   # nothing would ever quit the test run
			else:
				_driver = ds.new()
		elif a.begins_with("--save-dir="):
			FlashSharedObject.save_dir = a.substr(11)
			DirAccess.make_dir_recursive_absolute(FlashSharedObject.save_dir)
		elif a.begins_with("--mods-dir="):
			Flash.mods_dir_override = a.substr(11)
		elif a.begins_with("--mod-cache="):
			FlashSwfMod.cache_root = a.substr(12)
		elif a.begins_with("--seed="):
			seed(int(a.substr(7)))
		elif a.begins_with("--frames="):
			_frames = int(a.substr(9))
			_quit_at_end = true
		elif a.begins_with("--move="):
			var mp := a.substr(7).split("@")
			var mxy := mp[0].split(",")
			_clicks.append([int(mp[1]) if mp.size() > 1 else 10, Vector2(float(mxy[0]), float(mxy[1])), true])
		elif a.begins_with("--click="):
			var parts := a.substr(8).split("@")
			var xy := parts[0].split(",")
			_clicks.append([int(parts[1]) if parts.size() > 1 else 10, Vector2(float(xy[0]), float(xy[1]))])
	if "--counter" in OS.get_cmdline_user_args():
		_counter = Label.new()
		_counter.z_index = 100
		_counter.add_theme_font_size_override("font_size", 40)
		add_child(_counter)
	PortSettings.apply_window()   # port: Settings > Window (size, fullscreen)
	presentation = Presentation.new()   # port: widescreen, the stage centred in the window
	var rs := RenderScale.new()   # port: Settings > Graphics > Render scale (the stage's own CanvasLayer)
	add_child(rs.layer)
	rs.layer.add_child(presentation)
	add_child(rs)
	rs.apply(PortSettings.render_scale_factor())
	Flash.attach_stage(presentation.host)
	Flash.stage.addChild(DT.new())
	add_child(preload("res://scenes/fps_counter.gd").new())


func _exit_tree() -> void:
	if g.modCatalog != null:
		g.modCatalog.shutdown()   # before anything else goes: mods converting on worker threads
	Extensions.shutdown()


func _process(_delta: float) -> void:
	if _shot == "" and _clicks.is_empty() and not _quit_at_end and _driver == null:
		return
	_frame += 1
	if _counter:
		_counter.text = str(_frame)
		move_child(_counter, get_child_count() - 1)
	if _frame % 60 == 0:
		print("frame %d fps=%d nodes=%d objects=%d" % [_frame, Engine.get_frames_per_second(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
		print("   running=%s paused=%s locked=%s mouse=%s cur=%s flashmouse=%s" % [g.gameRunning, g.gamePaused, g.controlLocked, g.currentMousePos, g.currentPos, Flash.mouse_position()])
	for c in _clicks:
		if c[0] == _frame:
			if c.size() > 2 and c[2] is String and c[2] == "eval":
				_eval(c[1])
			elif c.size() > 2 and c[2] is String:
				_key(c[1])
			elif c.size() > 2:
				_move(c[1])
			else:
				_click(c[1])
	if _driver != null:
		_driver.step(_frame)
	if _frame == 150 and not _hide.is_empty():
		_hide_matching(Flash.stage)
	if _frame >= 150 and _frame < 156 and not _hide.is_empty():
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		var dt = Flash.stage._children[0]
		print("f%d px=%s dt_vis=%s in_tree=%s" % [_frame, im.get_pixel(im.get_width() / 2, im.get_height() / 2), dt.visible, dt.is_visible_in_tree()])
	if _quit_at_end and _shot == "" and _frame >= _frames:
		_print_targets()
		get_tree().quit()
		return
	if _shot != "" and _frame >= _frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot)
		for pk in _picks:
			var tgt: FlashDisplayObject = Flash._mouse_target_at(pk)
			var chain := []
			var o = tgt
			while o != null:
				chain.append("%s#%d" % [o.flash_name, o._char_id])
				o = o._flash_parent
			print("TARGET ", pk, " ", chain)
			print("PICK ", pk)
			_pick(Flash.stage, pk, "")
		if _dump != "":
			var f := FileAccess.open(_dump, FileAccess.WRITE)
			_dump_obj(f, Flash.stage, 0)
			f.store_line("---- godot tree (depth 4)")
			_dump_godot(f, get_tree().root, 0)
			f.store_line("---- proxies")
			_dump_proxies(f, Flash.stage)
		get_tree().quit()


func _click(p: Vector2) -> void:
	var screen: Vector2 = Flash._stage_to_window() * p
	Flash.mouse_override = p
	var m := InputEventMouseMotion.new()
	m.position = screen
	m.global_position = screen
	Input.parse_input_event(m)
	await get_tree().physics_frame
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = screen
		e.global_position = screen
		Input.parse_input_event(e)
		await get_tree().physics_frame


## Writes the Flash display list (names, classes, frames, visibility, transforms) for debugging.
func _dump_obj(f: FileAccess, o: FlashDisplayObject, depth: int) -> void:
	var cls := String(o.get_script().get_global_name()) if o.get_script() else o.get_class()
	var line := "%s%s [%s#%d]" % ["  ".repeat(depth), o.flash_name, cls, o._char_id]
	if o is FlashMovieClip:
		line += " f=%d/%d" % [o.currentFrame, o.totalFrames]
		if o.currentLabel != "":
			line += " '%s'" % o.currentLabel
	if not o.visible:
		line += " HIDDEN"
	if o.alpha != 1.0:
		line += " a=%.2f" % o.alpha
	line += " pos=(%.1f,%.1f) sc=(%.2f,%.2f) rot=%.1f" % [o.x, o.y, o.scaleX, o.scaleY, o.rotation_degrees]
	if o.blendMode != "normal":
		line += " blend=" + o.blendMode
	if o.mask != null:
		line += " mask=%s(%s)" % [o.mask.flash_name, o._tree_node().get_class() if not o._tree_node().get_script() else o._tree_node().get_script().get_global_name()]
	if not o._filters.is_empty():
		line += " filters=%d node=%s" % [o._filters.size(), o._tree_node().get_path()]
	var ct: FlashColorTransform = o.colorTransform
	if ct.redMultiplier != 1 or ct.greenMultiplier != 1 or ct.blueMultiplier != 1 or ct.redOffset != 0 or ct.greenOffset != 0 or ct.blueOffset != 0:
		line += " ct=(%.2f,%.2f,%.2f|%d,%d,%d)" % [ct.redMultiplier, ct.greenMultiplier, ct.blueMultiplier, ct.redOffset, ct.greenOffset, ct.blueOffset]
	f.store_line(line)
	if o is FlashSprite:
		for c in o._children:
			_dump_obj(f, c, depth + 1)


func _move(p: Vector2) -> void:
	var screen: Vector2 = Flash._stage_to_window() * p
	Flash.mouse_override = p
	var m := InputEventMouseMotion.new()
	m.position = screen
	m.global_position = screen
	Input.parse_input_event(m)


## Prints every visible shape covering stage point p (bottom to top), with its display-list path.
func _pick(o: FlashDisplayObject, p: Vector2, path: String) -> void:
	if not o.visible or o.alpha <= 0.0:
		return
	var here := path + "/" + (o.flash_name if o.flash_name != "" else "#%d" % o._char_id)
	if o is FlashShape:
		if o.hitTestPoint(p.x, p.y, true):
			print("  ", here)
	elif o is FlashSprite:
		for c in o._children:
			if c._masking.is_empty():
				_pick(c, p, here)


func _dump_proxies(f: FileAccess, n: Node) -> void:
	if n is FlashProxy:
		var names: Array = []
		for c in n.content_parent().get_children():
			names.append(String(c.name) + ("(%s)" % c.flash_name if c is FlashDisplayObject else ""))
		f.store_line("%s rect=%s vis=%s vp=%s mask=%s content=%s" % [n.get_path(), n._rect, n.is_visible_in_tree(), n._vp.size, n._mask_obj.flash_name if n._mask_obj else "-", names])
	for c in n.get_children():
		_dump_proxies(f, c)


## Hides display objects whose name, class or path index matches a --hide value (debug bisection).
func _hide_matching(o: FlashDisplayObject) -> void:
	var cls := String(o.get_script().get_global_name()) if o.get_script() else ""
	if _hide.has(o.flash_name) or _hide.has(cls) or _hide.has("#%d" % o._char_id):
		o.visible = false
		print("hid ", o.flash_name, " ", cls, " #", o._char_id)
	if o is FlashSprite:
		for c in o._children:
			_hide_matching(c)


func _dump_godot(f: FileAccess, n: Node, depth: int) -> void:
	if depth > 5:
		return
	var extra := ""
	if n is FlashDisplayObject:
		extra = " flash=%s#%d" % [n.flash_name, n._char_id]
	if n is CanvasItem and not n.visible:
		extra += " HIDDEN"
	f.store_line("%s%s [%s]%s" % ["  ".repeat(depth), n.name, n.get_script().get_global_name() if n.get_script() else n.get_class(), extra])
	for c in n.get_children():
		_dump_godot(f, c, depth + 1)


func _key(k: String) -> void:
	var code := OS.find_keycode_from_string(k)
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().physics_frame


## Prints the Flash mouse target (with its parent chain) at each --pick point.
func _print_targets() -> void:
	for pk in _picks:
		var o = Flash._mouse_target_at(pk)
		var chain := []
		while o != null:
			chain.append("%s#%d" % [o.flash_name, o._char_id])
			o = o._flash_parent
		print("TARGET ", pk, " ", chain)


func _eval(code: String) -> void:
	var e := Expression.new()
	if e.parse(code, ["g", "Flash", "OS"]) != OK:
		push_error("--eval parse error: %s" % e.get_error_text())
		return
	var r = e.execute([g, Flash, Engine.get_singleton("OS")], self)
	print("eval %s -> %s%s" % [code, r, (" ERROR " + e.get_error_text()) if e.has_execute_failed() else ""])
