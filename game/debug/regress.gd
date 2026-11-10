extends RefCounted
## Regression test driver (main.gd --driver, run by tools/regress.sh). Plays one scripted scenario
## (--scenario=<name>) and writes text dumps of the game state at fixed ticks into --out=<folder>: the Flash display
## list (names, frames, transforms, colours) and the scalar state of Her and Him. tools/regress.sh compares them
## with the reference dumps in tests/golden/. Run with --deterministic --seed=1 --fixed-fps 30 so a tick is a frame.
## Actions are keyed on Flash.tick_count (game ticks), not on rendered frames.
## --images=<folder> (windowed runs only, tools/regress.sh starts them on a hidden desktop): also saves a picture of
## the window at the dumps listed in IMAGES, for the image goldens in tests/golden/images/. Textures then load on
## the main thread, so a picture never misses one that was still loading.

const SCENARIOS := ["menu", "idle", "grab", "costumes", "characters", "cum"]
## Dumps that also get a picture with --images.
const IMAGES := ["menu_menu", "idle_start", "idle_idle", "grab_grabbed", "grab_stroking", "costumes_dressed",
	"characters_char02", "characters_char05", "characters_char08", "cum_spurt", "cum_after"]

var _steps: Array = []   # [tick, Callable]
var _next := 0
var _out := ""
var _name := ""
var _images := ""


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			_name = a.substr(11)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--images="):
			_images = a.substr(9)
	if not _name in SCENARIOS:
		push_error("regress: unknown --scenario=%s (one of %s)" % [_name, SCENARIOS])
		_at(1, func(): Flash.get_tree().quit(1))
		return
	DirAccess.make_dir_recursive_absolute(_out)
	if _images != "":
		DirAccess.make_dir_recursive_absolute(_images)
		FlashLibrary._threaded = false
	call("_scenario_" + _name)
	_steps.sort_custom(func(a, b): return a[0] < b[0])


func step(_frame: int) -> void:
	while _next < _steps.size() and _steps[_next][0] <= Flash.tick_count:
		_steps[_next][1].call()
		_next += 1


# ---------------------------------------------------------------- scenarios

func _scenario_menu() -> void:
	_dump(30, "menu")
	_quit(31)


## Starts the game and leaves it alone (breathing, idle animations, automatic blinking).
func _scenario_idle() -> void:
	_play(30)
	_dump(60, "start")
	_dump(300, "idle")
	_quit(301)


## Moves the mouse into her (grab via far-left moves) and strokes back and forth.
func _scenario_grab() -> void:
	_play(30)
	_move(40, Vector2(300, 250))
	_move(60, Vector2(5, 250))
	_dump(80, "grabbed")
	for i in 20:
		_move(90 + i * 10, Vector2(200 + (i % 2) * 300, 220 + (i % 3) * 20))
	_dump(300, "stroking")
	_quit(301)


## Steps every costume picker forward a few times.
func _scenario_costumes() -> void:
	_play(30)
	var t := 40
	for h in ["collar", "gag", "cuffs", "ankleCuffs", "eyewear", "panties", "armwear", "legwear", "legwearB",
			"bottoms", "footwear", "top", "bra", "headwear", "earring"]:
		for k in 3:
			_at(t, func(): g.characterControl.get(h + "Control")._step(1))
			t += 2
	_at(t, func(): g.inGameMenu._stepHair(1))
	_at(t + 2, func(): g.inGameMenu._stepBG(1))
	_dump(t + 30, "dressed")
	_quit(t + 31)


## Switches through the built-in characters.
func _scenario_characters() -> void:
	_play(30)
	for k in range(1, 11):
		_at(20 + k * 40, func(): g.characterControl.setChar(k, false))
		_dump(20 + k * 40 + 30, "char%02d" % k)
	_quit(20 + 10 * 40 + 31)


## Him ejaculates while held in her mouth: cum strands, spurts, dripping.
func _scenario_cum() -> void:
	_play(30)
	_move(40, Vector2(5, 250))
	_move(60, Vector2(450, 250))
	_at(70, func(): g.him.ejaculate())
	_dump(100, "spurt")
	_dump(250, "after")
	_quit(251)


# ---------------------------------------------------------------- helpers

func _at(tick: int, f: Callable) -> void:
	_steps.append([tick, f])


func _play(tick: int) -> void:
	_at(tick, func(): Flash.stage.getChildAt(0).playClicked())


func _move(tick: int, p: Vector2) -> void:
	_at(tick, func(): Flash.get_tree().current_scene._move(p))


func _quit(tick: int) -> void:
	_at(tick, func(): Flash.get_tree().quit())


func _dump(tick: int, label: String) -> void:
	_at(tick, func(): _write("%s_%s.txt" % [_name, label]))
	if _images != "" and "%s_%s" % [_name, label] in IMAGES:
		_at(tick, func(): _picture("%s_%s.webp" % [_name, label]))


## Saves the window's picture once this frame (the tick just dumped) has been drawn.
func _picture(file: String) -> void:
	for n in Flash.get_tree().current_scene.get_children():   # the fps counter changes from run to run
		if n is CanvasLayer and n.get_script() == preload("res://scenes/fps_counter.gd"):
			n.visible = false
	await RenderingServer.frame_post_draw
	var img := Flash.get_viewport().get_texture().get_image()
	if img == null or img.is_empty() or img.save_webp(_images.path_join(file)) != OK:   # lossless
		push_error("regress: cannot save picture %s" % _images.path_join(file))
		return
	print("regress: pictured ", file)


func _write(file: String) -> void:
	var f := FileAccess.open(_out.path_join(file), FileAccess.WRITE)
	if f == null:
		push_error("regress: cannot write %s" % _out.path_join(file))
		return
	f.store_line("tick %d" % Flash.tick_count)
	for who in ["her", "him"]:
		var o = g.get(who)
		if o != null:
			f.store_line("---- %s" % who)
			_dump_vars(f, o)
	f.store_line("---- display list")
	Flash.get_tree().current_scene._dump_obj(f, Flash.stage, 0)
	print("regress: wrote ", file)


## Writes the script variables of o that hold plain values (numbers, flags, strings, vectors).
func _dump_vars(f: FileAccess, o: Object) -> void:
	for p in o.get_property_list():
		if not (p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v = o.get(p["name"])
		match typeof(v):
			TYPE_FLOAT:
				f.store_line("%s=%.3f" % [p["name"], v])
			TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME:
				f.store_line("%s=%s" % [p["name"], v])
			TYPE_VECTOR2:
				f.store_line("%s=(%.3f,%.3f)" % [p["name"], v.x, v.y])
