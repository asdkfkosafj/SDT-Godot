class_name PortSettings
extends RefCounted
## Port addition (not in the original game): settings of the port itself (for now the new menu's), kept in
## port.cfg next to the save files (FlashSharedObject.save_dir, so --save-dir test runs use their own copy).

const FILE := "port.cfg"

static var _cfg: ConfigFile = null


static func get_value(section: String, key: String, default = null):
	_load()
	return _cfg.get_value(section, key) if _cfg.has_section_key(section, key) else default


static func set_value(section: String, key: String, value) -> void:
	_load()
	if _cfg.has_section_key(section, key) and _cfg.get_value(section, key) == value:
		return
	_cfg.set_value(section, key, value)
	var err := _cfg.save(FlashSharedObject.save_dir.path_join(FILE))
	if err != OK:
		push_error("port settings: cannot save %s (%s)" % [FILE, error_string(err)])


static func erase_value(section: String, key: String) -> void:
	_load()
	if not _cfg.has_section_key(section, key):
		return
	_cfg.erase_section_key(section, key)
	var err := _cfg.save(FlashSharedObject.save_dir.path_join(FILE))
	if err != OK:
		push_error("port settings: cannot save %s (%s)" % [FILE, error_string(err)])


## Frame rate limit (Settings > Graphics > FPS limit): "Off" (as fast as it goes), "Monitor" (the screen's refresh rate) or a
## number. A limit keeps the GPU from drawing frames the screen cannot show.
const FPS_LIMITS := ["Off", "Monitor", "60", "120", "144", "240"]


static func fps_limit() -> String:
	var v := str(get_value("graphics", "fps_limit", "Off"))
	return v if v in FPS_LIMITS else "Off"


static func set_fps_limit(v: String) -> void:
	set_value("graphics", "fps_limit", v)
	apply_fps_limit()


static func apply_fps_limit() -> void:
	var v := fps_limit()
	var fps := 0
	if v == "Monitor":
		var hz := DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
		fps = int(roundf(hz)) if hz > 0.0 else 60
	elif v != "Off":
		fps = int(v)
	Engine.max_fps = fps


## MSAA (Settings > Graphics): edge smoothing of strands, drawn shapes and the edges of rotated images, on the screen
## and in every render target (FlashProxy.msaa_level).
const MSAA_LEVELS := {"Off": Viewport.MSAA_DISABLED, "2x": Viewport.MSAA_2X, "4x": Viewport.MSAA_4X, "8x": Viewport.MSAA_8X}


static func msaa() -> String:
	var v := str(get_value("graphics", "msaa", "2x"))
	return v if MSAA_LEVELS.has(v) else "2x"


static func set_msaa(v: String) -> void:
	set_value("graphics", "msaa", v)
	apply_msaa()


## Godot's OpenGL renderer (gl_compatibility: no Vulkan / D3D12, e.g. older Intel graphics) has no 2D MSAA: each
## target set to it only logs "2D MSAA is not yet supported for GLES3" (about 140 lines at start). The setting is
## hidden there.
static func msaa_supported() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


static func apply_msaa() -> void:
	var m: Viewport.MSAA = MSAA_LEVELS[msaa()] if msaa_supported() else Viewport.MSAA_DISABLED
	FlashProxy.msaa_level = m
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.msaa_2d = m
	if RenderScale.instance != null:
		RenderScale.instance.set_msaa(m)
	# the render targets switch at once
	for p in Flash._mask_proxies.keys() + Flash._groups.keys():
		if is_instance_valid(p) and p.has_method("refresh_msaa"):
			p.refresh_msaa()


## Render scale (Settings > Graphics): the game drawn at this share of the window's resolution and stretched to it
## (RenderScale), for weak graphics cards; the menu and panels stay sharp. --render-scale=<percent> sets the scale a
## run starts with (tests), without saving.
const RENDER_SCALES := ["100 %", "85 %", "75 %", "60 %", "50 %"]


static func render_scale() -> String:
	var v := str(get_value("graphics", "render_scale", RENDER_SCALES[0]))
	return v if v in RENDER_SCALES else RENDER_SCALES[0]


static func set_render_scale(v: String) -> void:
	set_value("graphics", "render_scale", v)
	if RenderScale.instance != null:
		RenderScale.instance.apply(float(render_scale().get_slice(" ", 0)) / 100.0)


## The scale to start with: the setting, or --render-scale=<percent> (the menu still changes it during the run).
static func render_scale_factor() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--render-scale="):
			return clampf(float(a.substr(15)) / 100.0, 0.25, 1.0)
	return float(render_scale().get_slice(" ", 0)) / 100.0


## Window (Settings > Window): the windowed size, a preset (shrunk to fit a smaller screen, keeping its shape),
## fullscreen, and the blurred background beside the game (scenes/presentation.gd).
const WINDOW_SIZES := ["1280 x 720", "1600 x 800", "1920 x 1080", "2560 x 1440"]
const DEFAULT_WINDOW_SIZE := "1600 x 800"
static var _window_serial := 0


static func window_size() -> String:
	var v := str(get_value("window", "size", DEFAULT_WINDOW_SIZE))
	return v if v in WINDOW_SIZES else DEFAULT_WINDOW_SIZE


static func set_window_size(v: String) -> void:
	set_value("window", "size", v)
	apply_window()


static func fullscreen() -> bool:
	return bool(get_value("window", "fullscreen", false))


static func set_fullscreen(on: bool) -> void:
	set_value("window", "fullscreen", on)
	apply_window()


static func blurred_sides() -> bool:
	return bool(get_value("window", "blurred_sides", true))


## Applies the window settings (at start and when they change). Not in headless runs, nor when the editor embeds
## the game (it owns that window).
static func apply_window() -> void:
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor():
		return
	_window_serial += 1
	_apply_window(_window_serial)


static func _apply_window(serial: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var win := tree.root
	if fullscreen():
		win.mode = Window.MODE_FULLSCREEN
		return
	if win.mode != Window.MODE_WINDOWED:
		win.mode = Window.MODE_WINDOWED
		# the window manager finishes leaving fullscreen first
		for _i in 2:
			await tree.process_frame
			if serial != _window_serial:
				return
	var p := window_size().split(" x ")
	var want := Vector2(float(p[0]), float(p[1]))
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	var deco := win.get_size_with_decorations() - win.size
	var room := Vector2(usable.size - deco)
	var k := minf(1.0, minf(room.x / want.x, room.y / want.y)) if room.x > 0 and room.y > 0 else 1.0
	win.size = Vector2i((want * k).floor())
	# centred on the screen, title bar included
	var inner := win.position - win.get_position_with_decorations()
	win.position = usable.position + (usable.size - win.size - deco) / 2 + inner


static func _load() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	var path := FlashSharedObject.save_dir.path_join(FILE)
	if FileAccess.file_exists(path):
		_cfg.load(path)
