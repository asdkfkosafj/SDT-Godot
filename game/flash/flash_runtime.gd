extends Node
## Flash runtime (autoload "Flash").
##
## Owns the stage (root of the Flash display list), the loaded symbol libraries, the mapping from AS3 classes
## to ported GDScript classes, and the fixed 30 Hz tick that drives ENTER_FRAME listeners and timelines.
## Game logic runs inside that tick (_physics_process); Godot's physics interpolation smooths rendering
## between ticks.

const BASE_LIBRARY := "res://assets/sdt"

const SHAPE_SHADERS := {
	"normal": preload("res://flash/shaders/shape_mix.gdshader"),
	"add": preload("res://flash/shaders/shape_add.gdshader"),
	"subtract": preload("res://flash/shaders/shape_sub.gdshader"),
	"multiply": preload("res://flash/shaders/shape_mul.gdshader"),
	"erase": preload("res://flash/shaders/shape_erase.gdshader"),
	"alpha": preload("res://flash/shaders/shape_alpha.gdshader"),
	"screen_read": preload("res://flash/shaders/shape_screen.gdshader"),
	"none": preload("res://flash/shaders/shape_none.gdshader"),
	"paint": preload("res://flash/shaders/shape_paint.gdshader"),
}
const SCREEN_BLEND_MODES := {"overlay": 0, "hardlight": 1, "screen": 2, "lighten": 3, "darken": 4,
	"difference": 5, "invert": 6}

## Debug flags from the command line (after --).
var debug_flags: PackedStringArray = OS.get_cmdline_user_args()

## Debug: render layer-blend / filtered objects directly instead of through offscreen groups.
var debug_no_groups := "--nogroups" in OS.get_cmdline_user_args()
## Debug: ignore masks.
var debug_no_masks := "--nomasks" in OS.get_cmdline_user_args()

## Root of the Flash display list (700x600 stage space).
var stage: FlashStage
var libraries: Array = []
var base_library: FlashLibrary
## Frames per second of the logic tick (Flash frame rate).
var frame_rate: float = 30.0
var tick_count: int = 0
## Ticks between mouse-over checks while the mouse is still (see the tick).
const MOUSE_OVER_TICKS := 3
## When true, timelines and ENTER_FRAME listeners are not ticked (debug tools / pause screens).
var paused := false

var _pending_symbol = null
var _gd_classes: Dictionary = {}       # short class name -> script path
var _lib_class_by_id: Dictionary = {}  # library -> {id -> short class name}
var _script_cache: Dictionary = {}
var _bindable_cache: Dictionary = {}   # Script -> {name: true}
var _runtime_props: Dictionary = {}

var _enter_frame: Array = []           # [object, Callable]
var _playing: Dictionary = {}          # FlashMovieClip -> true (insertion ordered)
var _mask_proxies: Dictionary = {}
var _groups: Dictionary = {}
var _material_pool: Dictionary = {}
var _painted: Dictionary = {}   # FlashShape -> the object whose paint it shows (own material, see update_paints)

var _mouse_over: FlashDisplayObject = null
var _mouse_down_target: FlashDisplayObject = null
var _focus: FlashDisplayObject = null

var _audio_pool: Array = []
var _active_channels: Dictionary = {}   # keeps playing FlashSoundChannels alive


func _ready() -> void:
	process_physics_priority = -100
	Engine.physics_ticks_per_second = int(frame_rate)
	_index_gd_classes()
	_setup_frame_monitor()
	base_library = load_library(BASE_LIBRARY)
	FlashSwfMod.register()
	for sub in MOD_FOLDERS:
		if not DirAccess.dir_exists_absolute(mods_dir(sub)):
			DirAccess.make_dir_recursive_absolute(mods_dir(sub))
	stage = FlashStage.new()
	stage.name = "Stage"
	stage.flash_name = "root1"


func _exit_tree() -> void:
	FlashLibrary.drain_streaming()
	for v in _early_chain:
		RenderingServer.free_rid(v)
	_early_chain.clear()
	if stage != null and stage.get_parent() == null:
		stage.free()


## Adds the stage to the scene tree under 'parent' (done by the main scene).
func attach_stage(parent: Node) -> void:
	if stage.get_parent() != null:
		stage.get_parent().remove_child(stage)
	parent.add_child(stage)


func load_library(dir: String) -> FlashLibrary:
	var lib := FlashLibrary.load_from(dir)
	if lib == null:
		return null
	libraries.append(lib)
	var by_id := {}
	for cls in lib.classes:
		by_id[int(lib.classes[cls])] = cls.get_slice(".", cls.get_slice_count(".") - 1)
	_lib_class_by_id[lib] = by_id
	return lib


# ---------------------------------------------------------------- classes & instantiation

func _index_gd_classes() -> void:
	for c in ProjectSettings.get_global_class_list():
		_gd_classes[String(c["class"])] = c["path"]
	# Properties declared by the runtime base classes must never be bound to timeline children.
	var probe := FlashMovieClip.new()
	for p in probe.get_property_list():
		_runtime_props[p["name"]] = true
	probe.free()


func take_pending_symbol():
	var p = _pending_symbol
	_pending_symbol = null
	return p


## AS3 class names that clash with Godot built-in classes are ported under these GDScript names.
const CLASS_ALIASES := {"Slider": "SDTSlider", "MenuButton": "SDTMenuButton"}


## GDScript class name used for an AS3 short class name.
## ByteArray.toString(): a UTF-16 (LE / BE) or UTF-8 byte order mark selects the encoding, otherwise UTF-8 -
## with bytes that are not valid UTF-8 taken as single characters (Windows-1252, as text saved in Notepad as
## "ANSI" is meant) instead of being replaced.
const _CP1252 := [0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039,
	0x0152, 0x8D, 0x017D, 0x8F, 0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122,
	0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178]


static func bytes_to_string(b: PackedByteArray) -> String:
	var n := b.size()
	if n >= 2 and b[0] == 0xFF and b[1] == 0xFE:
		return b.slice(2).get_string_from_utf16()
	if n >= 2 and b[0] == 0xFE and b[1] == 0xFF:
		var sw := b.slice(2)
		for i in range(0, sw.size() - 1, 2):
			var t := sw[i]
			sw[i] = sw[i + 1]
			sw[i + 1] = t
		return sw.get_string_from_utf16()
	var start := 3 if n >= 3 and b[0] == 0xEF and b[1] == 0xBB and b[2] == 0xBF else 0
	# Decoded in runs: valid UTF-8 natively, each invalid byte as one Windows-1252 character.
	var out := PackedStringArray()
	var run := start
	var i := start
	while i < n:
		if b[i] < 0x80:
			i += 1
			continue
		var k := _utf8_seq(b, i, n)
		if k > 0:
			i += k
			continue
		if i > run:
			out.append(b.slice(run, i).get_string_from_utf8())
		var c := b[i]
		out.append(char(_CP1252[c - 0x80] if c < 0xA0 else c))
		i += 1
		run = i
	if run == start:
		return b.slice(start).get_string_from_utf8()
	if run < n:
		out.append(b.slice(run).get_string_from_utf8())
	return "".join(out)


## Length of the well-formed UTF-8 multi-byte sequence starting at i (no overlongs or surrogates), or 0.
static func _utf8_seq(b: PackedByteArray, i: int, n: int) -> int:
	var c := b[i]
	var k := 0
	var lo := 0x80
	var hi := 0xBF
	if c >= 0xC2 and c <= 0xDF:
		k = 2
	elif c >= 0xE0 and c <= 0xEF:
		k = 3
		if c == 0xE0:
			lo = 0xA0
		elif c == 0xED:
			hi = 0x9F
	elif c >= 0xF0 and c <= 0xF4:
		k = 4
		if c == 0xF0:
			lo = 0x90
		elif c == 0xF4:
			hi = 0x8F
	else:
		return 0
	if i + k > n or b[i + 1] < lo or b[i + 1] > hi:
		return 0
	for j in range(2, k):
		if (b[i + j] & 0xC0) != 0x80:
			return 0
	return k


static func gd_class_name(as3_short: String) -> String:
	return CLASS_ALIASES.get(as3_short, as3_short)


## Finds the library symbol for a class: [library, id], or [] if none. Exact (fully qualified or top-level) names
## win over short-name matches, since e.g. both "MenuCheckbox" and "obj.MenuCheckbox" exist.
func find_class_symbol(name_: String) -> Array:
	for lib in libraries:
		if lib.classes.has(name_):
			return [lib, int(lib.classes[name_])]
	var short := name_.get_slice(".", name_.get_slice_count(".") - 1)
	for alias in CLASS_ALIASES:
		if CLASS_ALIASES[alias] == short:
			short = alias
	for lib in libraries:
		var by_id: Dictionary = _lib_class_by_id[lib]
		for id in by_id:
			if by_id[id] == short:
				return [lib, id]
	return []


func _gd_script_for(short_name: String) -> Script:
	if _script_cache.has(short_name):
		return _script_cache[short_name]
	var s: Script = null
	var gd_name := gd_class_name(short_name)
	if _gd_classes.has(gd_name):
		s = load(_gd_classes[gd_name])
	_script_cache[short_name] = s
	return s


## Instantiates character 'id' of 'lib' (what a timeline PlaceObject does). When placed by a timeline, the
## parent and placement are applied before the class constructor body runs, as in Flash.
func create_char(lib: FlashLibrary, id: int, parent = null, place: Dictionary = {}, pidx: int = -1,
		depth: int = -1, birth: int = -1) -> FlashDisplayObject:
	var c: Dictionary = lib.get_char(id)
	match c.get("t", ""):
		"shape", "morph":
			var s := FlashShape.new()
			s.setup(lib, id)
			return s
		"sprite":
			if lib.is_mod:
				return lib.mod.instantiate(id, parent, place, pidx, depth, birth)
			var short = _lib_class_by_id[lib].get(id)
			_pending_symbol = [lib, id, parent, place, pidx, depth, birth]
			if short != null:
				var script := _gd_script_for(short)
				if script != null:
					var o = script.new()
					_pending_symbol = null
					return o
			var mc := FlashMovieClip.new()
			_pending_symbol = null
			return mc
		"edittext":
			var tf := FlashTextField.new()
			tf.setup_from_library(lib, c)
			tf._char_id = id
			return tf
		"button":
			return _create_button(lib, id, c)
		"bitmap":
			var b := FlashBitmap.new(FlashBitmapData.from_library(lib, id))
			b._char_id = id
			return b
		"empty":
			var e := FlashShape.new()
			e._char_id = id
			return e
	return null


func _create_button(lib: FlashLibrary, id: int, c: Dictionary) -> FlashDisplayObject:
	var sp := FlashSprite.new()
	sp._char_id = id
	sp.buttonMode = true
	for r in c["records"]:
		if not r["states"].has("up"):
			continue
		var child := create_char(lib, int(r["c"]))
		if child == null:
			continue
		child.set_flash_matrix(r["m"])
		child.colorTransform = FlashColorTransform.from_array(r["ct"])
		sp.addChild(child)
	return sp


## Creates an instance of a library class by AS3 name (short or fully qualified), e.g. Flash.create("MenuButton").
func create(as3_class: String) -> FlashDisplayObject:
	var found := find_class_symbol(as3_class)
	if found.is_empty():
		push_error("Flash.create: no library symbol for class %s" % as3_class)
		return null
	return create_char(found[0], found[1])


## True if 'n' is a script-declared property of obj (not a runtime/engine property), so a timeline child of
## that name can be bound to it.
func is_bindable_property(obj: Object, n: String) -> bool:
	var script: Script = obj.get_script()
	if script == null:
		return false
	var props: Dictionary = _bindable_cache.get(script, {})
	if not _bindable_cache.has(script):
		for p in script.get_script_property_list():
			if not _runtime_props.has(p["name"]):
				props[p["name"]] = true
		_bindable_cache[script] = props
	return props.has(n)


# ---------------------------------------------------------------- fonts

var _fonts: Dictionary = {}


func get_font(lib: FlashLibrary, id: int) -> Font:
	var key := "%s/%d" % [lib.path, id]
	if _fonts.has(key):
		return _fonts[key]
	var f: Font = null
	var c: Dictionary = lib.get_char(id)
	if c.has("file"):
		var p := lib.file_path(c["file"])
		if p.begins_with("res://") and ResourceLoader.exists(p):
			f = load(p)
		elif FileAccess.file_exists(p):
			var ff := FontFile.new()
			if ff.load_dynamic_font(p) == OK:
				f = ff
	if f == null:
		f = get_font_by_name(c.get("name", ""))
	_fonts[key] = f
	return f


## Device / named fonts (e.g. dialogue font choices). Falls back to the system font.
func get_font_by_name(font_name: String) -> Font:
	for lib in libraries:
		for id in lib.chars:
			var c: Dictionary = lib.chars[id]
			if c.get("t") == "font" and c.get("name") == font_name and c.has("file"):
				return get_font(lib, int(id))
	var sf := SystemFont.new()
	if font_name != "" and not font_name.begins_with("_"):
		sf.font_names = PackedStringArray([font_name])
	return sf


# ---------------------------------------------------------------- tick

func add_enter_frame(obj: Object, cb: Callable) -> void:
	for e in _enter_frame:
		if e[0] == obj and e[1] == cb:
			return
	_enter_frame.append([obj, cb])


func remove_enter_frame(obj: Object, cb: Callable) -> void:
	for i in range(_enter_frame.size() - 1, -1, -1):
		if _enter_frame[i][0] == obj and _enter_frame[i][1] == cb:
			_enter_frame.remove_at(i)


func has_enter_frame(obj: Object) -> bool:
	for e in _enter_frame:
		if e[0] == obj:
			return true
	return false


func register_playing(mc: FlashMovieClip) -> void:
	_playing[mc] = true


func unregister_playing(mc: FlashMovieClip) -> void:
	_playing.erase(mc)


func register_mask_proxy(p: Node) -> void:
	_mask_proxies[p] = true


func unregister_mask_proxy(p: Node) -> void:
	_mask_proxies.erase(p)


func register_group(g: FlashGroupProxy) -> void:
	_groups[g] = true
	g.update_layout.call_deferred()


func unregister_group(g: FlashGroupProxy) -> void:
	_groups.erase(g)


func _physics_process(_delta: float) -> void:
	if paused:
		return
	tick_count += 1
	in_tick = true
	_ph["tick_start"] = Time.get_ticks_usec()
	if tick_count % 15 == 0:
		FlashDisplayObject.hb_gen += 1   # periodically rebuild loose hit-test bounds tight
	var prof := profiling
	var t0 := Time.get_ticks_usec()
	var snap: Dictionary = _prof.duplicate() if prof else {}
	FlashLibrary.poll_streaming()
	if _deterministic:
		for ch in _active_channels.keys():
			ch._tick_deterministic()
	_slowest_listener_us = 0
	moved_viewports.clear()
	_flush_mouse_move()
	# 0. Callbacks that run before the game's tick (port extensions, see tick_before).
	for cb in tick_before:
		cb.call()
	# 1. Timelines advance.
	for mc in _playing.keys():
		if is_instance_valid(mc):
			mc._advance()
		else:
			_playing.erase(mc)
	var t1 := Time.get_ticks_usec()
	_perf_add("#timelines", t1 - t0)
	# 2. ENTER_FRAME listeners (game logic).
	var stale := false
	for e in _enter_frame.duplicate():
		if not is_instance_valid(e[0]):
			stale = true
			continue
		var cb: Callable = e[1]
		if cb.is_valid():
			var ts := Time.get_ticks_usec()
			if cb.get_argument_count() == 0:
				cb.call()
			else:
				cb.call(FlashEvent.new(FlashEvent.ENTER_FRAME))
			var dt := Time.get_ticks_usec() - ts
			var scr = e[0].get_script()   # per script totals for the PERF line
			_perf_listeners[scr] = _perf_listeners.get(scr, 0) + dt
			if prof or dt > _slowest_listener_us:
				var obj = e[0]
				var key := "%s.%s" % [obj.get_script().get_global_name() if obj.get_script() else obj.get_class(), cb.get_method()] 					if is_instance_valid(obj) else "(freed)." + str(cb.get_method())
				account_listener(key, dt)
	if stale:
		# listeners of freed objects
		_enter_frame = _enter_frame.filter(func(e): return is_instance_valid(e[0]))
	# 2b. Callbacks that run after the game's tick, before masks follow the moved objects (see tick_after).
	for cb in tick_after:
		var ts := Time.get_ticks_usec()
		cb.call()
		_perf_add("after:" + cb.get_method(), Time.get_ticks_usec() - ts)
	var t2 := Time.get_ticks_usec()
	update_paints()
	# 3. Masks follow the (possibly moved) objects.
	for p in _mask_proxies.keys():
		if is_instance_valid(p):
			p.refresh()
		else:
			_mask_proxies.erase(p)
	var t3 := Time.get_ticks_usec()
	for g in _groups.keys():
		if is_instance_valid(g):
			g.update_layout()
		else:
			_groups.erase(g)
	FlashProxy.update_backdrops()
	var t4 := Time.get_ticks_usec()
	_perf_add("#masks", t3 - t2)
	_perf_add("#groups", t4 - t3)
	# objects moving under a still mouse: a hit search costs up to ~0.2 ms, so look every few ticks (mouse motion
	# updates it at the next tick, see _flush_mouse_move)
	if tick_count % MOUSE_OVER_TICKS == 0:
		_update_mouse_over()
	if tick_count % 3600 == 0 and base_library != null:   # every 2 minutes: the warm-up list survives a crash
		base_library.save_warm_list(FlashSharedObject.save_dir)
	_finish_lazy_detach()
	in_tick = false
	_free_orphans()
	_ph["tick_end"] = Time.get_ticks_usec()
	# a frame can run several ticks (catching up after a slow frame): count them and their total time
	_ph["ticks"] = _ph.get("ticks", 0) + 1
	_ph["ticks_us"] = _ph.get("ticks_us", 0) + _ph["tick_end"] - _ph["tick_start"]
	if prof:
		var t5 := Time.get_ticks_usec()
		_prof["#timelines"] = _prof.get("#timelines", 0) + t1 - t0
		_prof["#enter_frame (all)"] = _prof.get("#enter_frame (all)", 0) + t2 - t1
		_prof["#masks (%d)" % _mask_proxies.size()] = _prof.get("#masks (%d)" % _mask_proxies.size(), 0) + t3 - t2
		_prof["#groups"] = _prof.get("#groups", 0) + t4 - t3
		_prof["#mouse+free"] = _prof.get("#mouse+free", 0) + t5 - t4
		if t5 - t0 > _prof_max:
			_prof_max = t5 - t0
			_prof_worst.clear()
			for k in _prof:
				var d: int = _prof[k] - snap.get(k, 0)
				if d > 0:
					_prof_worst[k] = d
		_prof_ticks += 1
		if _prof_ticks % 150 == 0:
			_print_profile()
			_ph["skip"] = true   # printing takes long; keep it out of the frame statistics


## Debug: per-tick timing of runtime phases and ENTER_FRAME listeners (--profile on the command line).
var profiling := "--profile" in OS.get_cmdline_user_args()
var _prof: Dictionary = {}
var _prof_ticks := 0
var _prof_max := 0
var _prof_worst: Dictionary = {}   # bucket -> usec during the worst tick
# ---------------------------------------------------------------- frame monitor
# Always on (cheap): timestamps the phases of every rendered frame and logs "HITCH" lines for frames that take
# over HITCH_MS, with what happened in them, so a stutter seen while playing can be diagnosed from the log.
# With --profile it also accumulates per-phase statistics, printed with the tick profile.

var HITCH_MS := 50   # --hitch-ms=N to change the threshold
var _ph: Dictionary = {}           # phase -> timestamp (usec) for the current frame
var _ph_prev_end := 0              # post_draw of the previous frame
var _hitch_notes: Dictionary = {}  # note -> count during the current frame
var _slowest_listener := ""        # slowest ENTER_FRAME listener of the last tick ...
var _slowest_listener_us := 0      # ... and its time
var _prof_frames: Dictionary = {}


class _PhaseNode:
	extends Node
	var key := ""

	func _process(_d: float) -> void:
		Flash._ph[key] = Time.get_ticks_usec()

	func _physics_process(_d: float) -> void:
		if key == "process_first":
			var now := Time.get_ticks_usec()
			Flash._ph["physics_start"] = now
			if not Flash._ph.has("first_physics"):
				Flash._ph["first_physics"] = now


func _setup_frame_monitor() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hitch-ms="):
			HITCH_MS = int(arg.substr(11))
		elif arg.begins_with("--perf-seconds="):
			PERF_SECONDS = float(arg.substr(15))
	for k in ["process_first", "process_last"]:
		var n := _PhaseNode.new()
		n.key = k
		n.process_priority = -1000000 if k == "process_first" else 1000000
		n.process_physics_priority = -1000000
		add_child(n)
	RenderingServer.frame_pre_draw.connect(func(): _ph["pre_draw"] = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(_end_frame)
	_log_system.call_deferred()


## One "SYSTEM" line at startup with what matters for performance reports (testers send their godot.log).
func _log_system() -> void:
	var v := Engine.get_version_info()
	var vsync: String = ["off", "on", "adaptive", "mailbox"][clampi(DisplayServer.window_get_vsync_mode(), 0, 3)]
	print("SYSTEM Godot %s (%s build) | %s | %s %s | CPU %s, %d threads | native %s | window %s on a %s screen, vsync %s, max fps %d" % [
		v["string"], "debug" if OS.is_debug_build() else "release", RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name(), OS.get_processor_name(),
		OS.get_processor_count(), "on" if ClassDB.class_exists(&"SDTNative") and not "--nonative" in OS.get_cmdline_user_args() else "OFF",
		DisplayServer.window_get_size(), DisplayServer.screen_get_size(), vsync, Engine.max_fps])


# Every PERF_SECONDS of play, one "PERF" line: frame rate, slow frames, tick and render time, worst frame, so a
# steady low frame rate (no single frame slow enough for a HITCH line) shows in the log too.
var PERF_SECONDS := 30.0   # --perf-seconds=N to change the interval
var _perf := {"frames": 0, "us": 0, "slow": 0, "tick_us": 0, "ticks": 0, "draw_us": 0, "worst": 0, "start": 0}
var _perf_listeners: Dictionary = {}   # script (or "ext:<id>.tick") -> usec in the current PERF window


func _perf_add(key: String, dt: int) -> void:
	_perf_listeners[key] = _perf_listeners.get(key, 0) + dt


## The listeners / phases ("after:" tick_after callbacks, "#" runtime phases) that took the most time in the PERF
## window, as "Name 1.2 ms" (per tick).
func _perf_top(ticks: int) -> String:
	var keys := _perf_listeners.keys()
	keys.sort_custom(func(a, b): return _perf_listeners[a] > _perf_listeners[b])
	var parts := PackedStringArray()
	for k in keys.slice(0, 6):
		var name: String = k if k is String else (k.get_global_name() if k is Script and k.get_global_name() != &"" 			else (k.resource_path.get_file() if k is Resource else "?"))
		parts.append("%s %.1f ms" % [name, _perf_listeners[k] / 1000.0 / maxi(1, ticks)])
	return ", ".join(parts)


func _perf_frame(total: int, ph: Dictionary, now: int) -> void:
	var pf := _perf
	if pf["start"] == 0:
		pf["start"] = now
	pf["frames"] += 1
	pf["us"] += total
	if total > 33333:
		pf["slow"] += 1
	if ph.has("ticks_us"):
		pf["tick_us"] += ph["ticks_us"]
		pf["ticks"] += ph.get("ticks", 1)
	if ph.has("pre_draw"):
		pf["draw_us"] += now - ph["pre_draw"]
	pf["worst"] = maxi(pf["worst"], total)
	if now - pf["start"] >= PERF_SECONDS * 1000000.0:
		var n: int = pf["frames"]
		print("PERF last %.0f s: %.1f fps (%.1f ms per frame), %d of %d frames over 33 ms, tick %.1f ms (%d ticks), render + vsync wait %.1f ms per frame, worst frame %.0f ms" % [
			(now - pf["start"]) / 1000000.0, n / ((now - pf["start"]) / 1000000.0), pf["us"] / 1000.0 / n, pf["slow"], n,
			pf["tick_us"] / 1000.0 / maxi(1, pf["ticks"]), pf["ticks"], pf["draw_us"] / 1000.0 / n, pf["worst"] / 1000.0]
			+ "; per tick: " + _perf_top(pf["ticks"]))
		_perf = {"frames": 0, "us": 0, "slow": 0, "tick_us": 0, "ticks": 0, "draw_us": 0, "worst": 0, "start": now}
		_perf_listeners = {}


## Records something worth knowing about if the current frame turns out to be a hitch (a load, a compile, ...).
func hitch_note(what: String) -> void:
	_hitch_notes[what] = _hitch_notes.get(what, 0) + 1


func _end_frame() -> void:
	var now := Time.get_ticks_usec()
	var ph := _ph
	var prev_end := _ph_prev_end
	_ph = {}
	_ph_prev_end = now
	var notes := _hitch_notes
	_hitch_notes = {}
	if prev_end == 0 or ph.has("skip"):
		return
	var total := now - prev_end
	if tick_count > 60:
		_perf_frame(total, ph, now)
	# phase durations in order; missing phases (no tick this frame) are skipped
	var parts: Array = []
	var last := prev_end
	for k in ["first_physics", "physics_start", "tick_start", "tick_end", "process_first", "process_last", "pre_draw"]:
		if ph.has(k):
			parts.append([k, ph[k] - last])
			last = ph[k]
	parts.append(["post_draw", now - last])
	var input_us := _frame_input_us
	var input_max := _frame_input_max
	var input_max_us := _frame_input_max_us
	_frame_input_us = 0
	_frame_input_max_us = 0
	_frame_input_max = ""
	if total > HITCH_MS * 1000 and tick_count > 60:
		var desc := PackedStringArray()
		for p in parts:
			desc.append("%s +%.1f" % [_phase_label(p[0]), p[1] / 1000.0])
		var line := "HITCH %.0f ms at tick %d: %s" % [total / 1000.0, tick_count, ", ".join(desc)]
		if ph.get("ticks", 0) > 1:
			line += "; %d ticks this frame (%.1f ms in total)" % [ph["ticks"], ph["ticks_us"] / 1000.0]
		if ph.has("tick_end"):
			line += "; slowest listener %s %.1f ms" % [_slowest_listener, _slowest_listener_us / 1000.0]
		line += "; input handlers %.1f ms" % (input_us / 1000.0)
		if input_max != "":
			line += " (slowest: %s %.1f ms)" % [input_max, input_max_us / 1000.0]
		if not notes.is_empty():
			line += "; " + str(notes)
		print(line)
	if profiling:
		var kind := "tick frame" if ph.has("tick_end") else "frame"
		_prof_frames[kind + "s"] = _prof_frames.get(kind + "s", 0) + 1
		for p in parts:
			var key: String = "%s: %s ms" % [kind, _phase_label(p[0])]
			_prof_frames[key] = _prof_frames.get(key, 0.0) + p[1] / 1000.0
		if total > _prof_frames.get("worst frame ms", 0.0) * 1000.0:
			_prof_frames["worst frame ms"] = total / 1000.0


static func _phase_label(k: String) -> String:
	match k:
		"first_physics": return "wait/begin (OS events, input)"
		"physics_start": return "earlier ticks"
		"tick_start": return "pre-tick"
		"tick_end": return "tick"
		"process_first": return "deferred draws/frees"
		"process_last": return "_process"
		"pre_draw": return "pre-render"
		_: return "render"


func _print_frame_stats() -> void:
	var out := PackedStringArray()
	for kind in ["tick frame", "frame"]:
		var n: int = _prof_frames.get(kind + "s", 0)
		if n == 0:
			continue
		var avg := PackedStringArray()
		for k in _prof_frames:
			if String(k).begins_with(kind + ": "):
				avg.append("%s %.2f" % [String(k).substr(kind.length() + 2).trim_suffix(" ms"), _prof_frames[k] / n])
		out.append("%d %ss avg ms [%s]" % [n, kind, ", ".join(avg)])
	print("  frames: %s; worst frame %.1f ms" % ["; ".join(out), _prof_frames.get("worst frame ms", 0.0)])
	_prof_frames.clear()


## Adds the time since t_start (Time.get_ticks_usec()) to a named profile bucket. No-op unless profiling.
func prof(key: String, t_start: int) -> void:
	if profiling:
		_prof[key] = _prof.get(key, 0) + Time.get_ticks_usec() - t_start


## Counts an event in a profile bucket (printed as events per tick in the 'ms/tick' column).
func prof_count(key: String) -> void:
	if profiling:
		_prof[key] = _prof.get(key, 0) + 1000


func _print_profile() -> void:
	var keys := _prof.keys()
	keys.sort_custom(func(a, b): return _prof[a] > _prof[b])
	var total := 0
	for k in keys:
		if not String(k).begins_with("#") or k == "#enter_frame (all)":
			continue
	print("--- profile over %d ticks: worst tick %.2f ms, render fps %d" % [_prof_ticks, _prof_max / 1000.0,
		Engine.get_frames_per_second()])
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	_print_frame_stats()
	print("  gpu: main viewport %.2f ms (cpu %.2f ms), draw calls %d, %d mask viewports, vram %d MB" % [
		RenderingServer.viewport_get_measured_render_time_gpu(vp),
		RenderingServer.viewport_get_measured_render_time_cpu(vp),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		_mask_proxies.size(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576])
	for k in keys.slice(0, 18):
		print("  %8.3f ms/tick  %s" % [_prof[k] / 1000.0 / _prof_ticks, k])
	var wk := _prof_worst.keys()
	wk.sort_custom(func(a, b): return _prof_worst[a] > _prof_worst[b])
	print("  worst tick:")
	for k in wk.slice(0, 10):
		print("  %8.3f ms  %s" % [_prof_worst[k] / 1000.0, k])
	_prof.clear()
	_prof_ticks = 0
	_prof_max = 0


var _release_candidates: Array = []

## Port extension (not in Flash): callables run every tick before the timelines advance (tick_before) and after
## the ENTER_FRAME listeners (tick_after). The port's extension system (src/ext/extensions.gd) uses them so
## extensions run at fixed points of the tick instead of wherever their listener happens to be in the list.
var tick_before: Array[Callable] = []
var tick_after: Array[Callable] = []


## Records the time a tick callback took under `key`: shows in --profile buckets and as the slowest listener in
## HITCH lines.
func account_listener(key: String, dt: int) -> void:
	if key.begins_with("ext:"):   # extension ticks (the game's listeners are counted per script in the tick loop)
		_perf_listeners[key] = _perf_listeners.get(key, 0) + dt
	if dt > _slowest_listener_us:
		_slowest_listener_us = dt
		_slowest_listener = key
	if profiling:
		_prof[key] = _prof.get(key, 0) + dt

## flash.utils.getTimer(): milliseconds since start. With --deterministic (benchmarks / tests together with
## --fixed-fps and --seed) it advances with the ticks instead of the wall clock.
func getTimer() -> int:
	if _deterministic:
		return int(tick_count * 1000.0 / frame_rate)
	return Time.get_ticks_msec()


var _deterministic := "--deterministic" in OS.get_cmdline_user_args()


## True while the runtime runs a tick (see FlashSprite._detach).
var in_tick := false
var _lazy_detached: Array = []   # [child, old parent]


func lazy_detach(child: FlashDisplayObject, from: FlashSprite) -> void:
	_lazy_detached.append([child, from])


## Removes the Godot nodes of children that were removed during the tick and not re-added to the same parent.
func _finish_lazy_detach() -> void:
	for e in _lazy_detached:
		var child: FlashDisplayObject = e[0]
		var from: FlashSprite = e[1]
		if not is_instance_valid(child) or not is_instance_valid(from) or child._flash_parent == from:
			continue
		var n := child._tree_node()
		if n.get_parent() == from:
			from.remove_child(n)
		var pre: Node = n.get_meta("bbc") if n.has_meta("bbc") else null
		if pre != null and pre.get_parent() == from:
			from.remove_child(pre)
	_lazy_detached.clear()


## Frees `o` at the end of the tick if it is still off the display list by then.
func release_if_orphaned(o: FlashDisplayObject) -> void:
	_release_candidates.append(o)


## Port of Flash's garbage collection for objects the game is done with (e.g. a killed costume element): freed
## DISPOSE_DELAY ticks later if still off the display list then, along with its whole subtree (and its filter /
## mask proxy), unless its class says it is still referenced (a _can_dispose() method returning false: it is
## looked at again every DISPOSE_DELAY ticks until it can go, or is back on the display list). Mod
## ActionScript that still holds one of them sees it as null (FlashAbc), like a detached object that does
## nothing.
const DISPOSE_DELAY := 60
var _disposals: Array = []   # [object, tick], in tick order
var _disposing: Dictionary = {}   # objects in _disposals


func dispose_later(o: FlashDisplayObject) -> void:
	if _disposing.has(o):
		return
	_disposing[o] = true
	_disposals.append([o, tick_count + DISPOSE_DELAY])


func _free_disposals() -> void:
	while not _disposals.is_empty() and _disposals[0][1] <= tick_count:
		var o = _disposals.pop_front()[0]
		_disposing.erase(o)
		if not is_instance_valid(o) or o._flash_parent != null or o.is_inside_tree() or o.is_queued_for_deletion():
			continue
		var top: CanvasItem = o._tree_node()
		if top.get_parent() != null:
			continue
		if o.has_method(&"_can_dispose") and not o._can_dispose():
			dispose_later(o)   # still referenced: look again later
			continue
		if _focus != null and is_instance_valid(_focus) and (o == _focus or o.is_ancestor_of(_focus)):
			_focus = null
		top.queue_free()


func _free_orphans() -> void:
	if not _disposals.is_empty():
		_free_disposals()
	if _release_candidates.is_empty():
		return
	var list := _release_candidates
	_release_candidates = []
	for o in list:
		if is_instance_valid(o) and o._flash_parent == null and not o.is_inside_tree() and _freeable(o):
			if o == _focus:
				_focus = null
			o.queue_free()


const _PLAIN_SCRIPTS := [&"FlashShape", &"FlashMovieClip", &"FlashSprite", &"FlashBitmap", &"FlashTextField"]


## True if nothing in o's subtree can still be referenced by game code: only plain runtime objects (no game
## class), no instance names, no listeners, and every Godot descendant belongs to o. Anything else is left for
## the game to keep or reuse (Flash's garbage collector would only free it once unreferenced).
func _freeable(o: FlashDisplayObject) -> bool:
	if not _PLAIN_SCRIPTS.has(o.get_script().get_global_name()):
		return false
	if o.flash_name != "" or not o._listeners.is_empty() or has_enter_frame(o):
		return false
	if o is FlashSprite:
		for c in o._children:
			if not _freeable(c):
				return false
	return _owns_godot_subtree(o, o)


func _owns_godot_subtree(root: FlashDisplayObject, n: Node) -> bool:
	for c in n.get_children():
		if c is FlashDisplayObject:
			var p: FlashDisplayObject = c
			while p != null and p != root:
				p = p._flash_parent
			if p == null:
				return false
		if not _owns_godot_subtree(root, c):
			return false
	return true


# ---------------------------------------------------------------- materials

## A viewport drawn before every render target of the scene (masks, groups), for a texture other objects show in
## the same frame (a paint: marks on her skin). Godot draws nested viewports first, the deepest first; drawn after a
## mask nested two deep, a paint would show there as it was the tick before, a tick behind her other parts. So the
## viewport hangs below a chain of empty viewports deeper than any nesting of render targets.
const EARLY_DEPTH := 32
var _early_chain: Array[RID] = []


func draw_early(vp: SubViewport) -> void:
	if _early_chain.is_empty():
		var parent := get_viewport().get_viewport_rid()
		for i in EARLY_DEPTH:
			var v := RenderingServer.viewport_create()
			RenderingServer.viewport_set_parent_viewport(v, parent)
			RenderingServer.viewport_set_update_mode(v, RenderingServer.VIEWPORT_UPDATE_DISABLED)
			RenderingServer.viewport_set_active(v, true)
			_early_chain.append(v)
			parent = v
	RenderingServer.viewport_set_parent_viewport(vp.get_viewport_rid(), _early_chain[-1])


## Painted shapes (FlashDisplayObject.paint) take this tick's place: shape-local -> paint UV
func update_paints() -> void:
	for s in _painted.keys():
		if not is_instance_valid(s) or not is_instance_valid(_painted[s]) or not (s.material is ShaderMaterial):
			_painted.erase(s)
		elif s.is_visible_in_tree():
			_update_paint(s, s.material, _painted[s])


func _update_paint(s: FlashShape, m: ShaderMaterial, owner: FlashDisplayObject) -> void:
	var t: Transform2D = owner.paint_transform * s.flash_global_transform()
	m.set_shader_parameter("paint_row0", Vector3(t.x.x, t.y.x, t.origin.x))
	m.set_shader_parameter("paint_row1", Vector3(t.x.y, t.y.y, t.origin.y))


## Shared material for a shape given its inherited colour offsets, blend mode and colour-matrix filters.
func shape_material(s: FlashShape) -> Material:
	var off := s.effective_color_offset()
	var blend := "normal"
	var cm: Projection = Projection.IDENTITY
	var cm_off := Vector4.ZERO
	var has_cm := false
	var o: FlashDisplayObject = s
	var blend_open := true
	var grouped := false   # an offscreen group above the object the blend mode comes from
	var paint: Texture2D = null
	var paint_owner: FlashDisplayObject = null
	_painted.erase(s)
	while o != null:
		if paint == null and o.paint != null:
			paint = o.paint
			paint_owner = o
		# An offscreen group composites its whole content with its own blend mode (group_display), so blend
		# modes at or above a grouped ancestor do not apply to the shapes inside it.
		if o != s and o._proxy is FlashGroupProxy:
			blend_open = false
			grouped = grouped or blend != "normal"
		if blend_open and blend == "normal" and o._blend_mode != "normal" and o._blend_mode != "layer":
			blend = o._blend_mode
		for f in o._filters:
			if f is FlashFilter and f.type == "ColorMatrix" and f.matrix.size() >= 20:
				var m: Array = f.matrix
				var b := Projection(Vector4(m[0], m[5], m[10], m[15]), Vector4(m[1], m[6], m[11], m[16]),
					Vector4(m[2], m[7], m[12], m[17]), Vector4(m[3], m[8], m[13], m[18]))
				cm_off = b * cm_off + Vector4(m[4], m[9], m[14], m[19]) / 255.0
				cm = b * cm
				has_cm = true
		o = o._flash_parent
	if blend != "normal" or has_cm:
		paint = null   # painted shapes are plain ones (her skin)
	if off == Color(0, 0, 0, 0) and blend == "normal" and not has_cm and paint == null:
		return null
	# ERASE / ALPHA need a LAYER parent; without one Flash draws nothing (a mod part with ERASE moved out of its
	# mod onto her layers, e.g. the shibari over-top's breast, which only cut the mod's own ropes)
	if (blend == "erase" or blend == "alpha") and not grouped:
		blend = "none"
	if paint != null:
		# its own material: the paint is found from the shape's own coordinates (update_paints, every tick)
		var pm := ShaderMaterial.new()
		pm.shader = SHAPE_SHADERS["paint"]
		pm.set_shader_parameter("paint", paint)
		pm.set_shader_parameter("offset", Vector4(off.r, off.g, off.b, off.a) / 255.0)
		_painted[s] = paint_owner
		_update_paint(s, pm, paint_owner)
		return pm
	var key := "%s|%s|%s|%s" % [blend, off, cm if has_cm else "", cm_off if has_cm else ""]
	var mat: ShaderMaterial = _material_pool.get(key)
	if mat != null:
		return mat
	mat = ShaderMaterial.new()
	if SCREEN_BLEND_MODES.has(blend) and not ("--noscreenblend" in OS.get_cmdline_user_args()):
		mat.shader = SHAPE_SHADERS["screen_read"]
		mat.set_shader_parameter("mode", SCREEN_BLEND_MODES[blend])
	else:
		mat.shader = SHAPE_SHADERS.get(blend, SHAPE_SHADERS["normal"])
	mat.set_shader_parameter("offset", Vector4(off.r, off.g, off.b, off.a) / 255.0)
	if has_cm:
		mat.set_shader_parameter("use_matrix", true)
		mat.set_shader_parameter("cm", cm)
		mat.set_shader_parameter("cm_offset", cm_off)
	_material_pool[key] = mat
	return mat


# ---------------------------------------------------------------- input

## Debug / automation: when set, used as the mouse position instead of the OS cursor.
var mouse_override = null
## Port addition: returns true while the mouse is over Godot UI that is not part of the stage (the new menu,
## SDTMenu); presses and moves are then not dispatched to the display list.
var mouse_blocker := Callable()


## Port addition (widescreen): the part of the window that shows the game, in stage coordinates. The 700x600 stage
## is centred in the window (scenes/presentation.gd); the side areas give x < 0 and x > 700.
var presentation_rect := Rect2(0, 0, 700, 600)


## Mouse position in stage coordinates.
func mouse_position() -> Vector2:
	if mouse_override != null:
		return mouse_override
	if stage != null and stage.is_inside_tree():
		return stage.get_local_mouse_position()
	return Vector2.ZERO


## Window pixels per stage pixel (used to size screen-space effects such as blur).
func screen_scale() -> float:
	return _stage_to_window().get_scale().x


## Stage coordinates to window pixels.
func _stage_to_window() -> Transform2D:
	var vp := get_viewport()
	if vp == null:
		return Transform2D.IDENTITY
	var t := vp.get_final_transform()
	if stage != null and stage.is_inside_tree():
		t = t * stage.get_global_transform_with_canvas()
	return t


func _mouse_target_at(p: Vector2) -> FlashDisplayObject:
	var t := stage._mouse_target(p)
	return t if t != null else stage


## _input (not _unhandled_input) so clicks and keys on text fields (Godot Controls) still reach the Flash
## display list, as in Flash where the TextField is an ordinary event target.
func _input(event: InputEvent) -> void:
	if stage == null:
		return
	var t0 := Time.get_ticks_usec()
	_handle_input(event)
	if event is InputEventMouseMotion and not _gui_wants_motion(event):
		get_viewport().set_input_as_handled()
	var dt := Time.get_ticks_usec() - t0
	_frame_input_us += dt
	if dt > _frame_input_max_us:
		_frame_input_max_us = dt
		_frame_input_max = _describe_input(event)


## Godot's GUI looks for the Control under the mouse on every motion event (~80 µs: the game's text fields are
## ~250 Labels, each a GUI root). Motion goes on to the GUI only where a Control can use it: over the menus and
## popups (mouse_blocker), while a button is held (drags), while a text field has focus, and once more after
## leaving them (their hover ends).
var _gui_motion := true


func _gui_wants_motion(m: InputEventMouseMotion) -> bool:
	var want: bool = m.button_mask != 0 or (mouse_blocker.is_valid() and mouse_blocker.call()) \
		or get_viewport().gui_get_focus_owner() != null
	var pass_on := want or _gui_motion
	_gui_motion = want
	return pass_on


var _frame_input_us := 0        # time spent in _input during the current frame
var _frame_input_max_us := 0
var _frame_input_max := ""


static func _describe_input(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return "mouse button %d %s at %s" % [mb.button_index, "down" if mb.pressed else "up", mb.position]
	if event is InputEventMouseMotion:
		return "mouse motion"
	if event is InputEventKey:
		var k := event as InputEventKey
		return "key %s %s" % [OS.get_keycode_string(k.keycode), "down" if k.pressed else "up"]
	return event.get_class()


func _handle_input(event: InputEvent) -> void:
	# Port addition: mouse presses and moves over the new menu (SDTMenu) are not the scene's; releases always pass
	if mouse_blocker.is_valid() and (event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed)) \
			and mouse_blocker.call():
		return
	if event is InputEventMouseButton:
		_flush_mouse_move()   # the move before the press, as in Flash
		var mb := event as InputEventMouseButton
		var target := _mouse_target_at(mouse_position())
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_down_target = target
				_set_focus(target)
				_dispatch_mouse(target, FlashEvent.MOUSE_DOWN)
			else:
				_dispatch_mouse(target, FlashEvent.MOUSE_UP)
				if _mouse_down_target == target:
					_dispatch_mouse(target, FlashEvent.CLICK)
				_mouse_down_target = null
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var e := FlashEvent.mouse(FlashEvent.MOUSE_WHEEL)
			e.delta = 3 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -3
			_fill_local(e, target)
			target.dispatchEvent(e)
	elif event is InputEventMouseMotion:
		_mouse_moved = true
		if paused:
			_flush_mouse_move()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.echo and not k.pressed:
			return
		var e := FlashEvent.new(FlashEvent.KEY_DOWN if k.pressed else FlashEvent.KEY_UP, true)
		e.keyCode = FlashKeys.to_flash(k.physical_keycode if k.keycode == KEY_NONE else k.keycode)
		e.charCode = k.unicode
		e.shiftKey = k.shift_pressed
		e.ctrlKey = k.ctrl_pressed
		e.altKey = k.alt_pressed
		var t: FlashDisplayObject = _focus if _focus != null and is_instance_valid(_focus) and _focus.is_inside_tree() else stage
		t.dispatchEvent(e)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and stage != null:
		stage.dispatchEvent(FlashEvent.new(FlashEvent.MOUSE_LEAVE))
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		FlashSharedObject.flush_all()
		FlashLibrary.drain_streaming()
		if base_library != null:
			base_library.save_warm_list(FlashSharedObject.save_dir)
	if what == NOTIFICATION_PREDELETE:
		free_orphans_at_exit()


func _set_focus(o: FlashDisplayObject) -> void:
	if o == _focus:
		return
	var old := _focus
	_focus = o
	if old != null and is_instance_valid(old):
		old.dispatchEvent(FlashEvent.new(FlashEvent.FOCUS_OUT, true))
	if o != null:
		o.dispatchEvent(FlashEvent.new(FlashEvent.FOCUS_IN, true))


## Debugging: display objects off the scene tree, counted by "class name" (top-level ones only: those whose
## Godot parent is not off the tree too), most common first.
func orphan_stats(limit: int = 15) -> Array:
	var counts := {}
	var total := 0
	for id in FlashDisplayObject.off_tree.keys():
		var o = instance_from_id(id)
		if o == null or not is_instance_valid(o) or o.is_inside_tree():
			continue
		total += 1
		if o.get_parent() != null:
			continue
		var k: String = str(o.get_script().get_global_name()) + " " + str(o.flash_name) + "#" + str(o._char_id)
		counts[k] = counts.get(k, 0) + 1
	var keys := counts.keys()
	keys.sort_custom(func(x, y): return counts[x] > counts[y])
	var out: Array = [total]
	for k in keys.slice(0, limit):
		out.append("%s x%d" % [k, counts[k]])
	return out


## Frees display-object subtrees that are off the scene tree at shutdown (removed or never added; Flash would have
## garbage-collected them), while the engine's servers still exist.
func free_orphans_at_exit() -> void:
	for id in FlashDisplayObject.off_tree.keys():
		var o = instance_from_id(id)
		if o == null or not is_instance_valid(o) or o.is_inside_tree():
			continue
		var top: Node = o
		while top.get_parent() != null:
			top = top.get_parent()
		if not top.is_inside_tree() and not top.is_queued_for_deletion():
			top.free()


func set_focus(o: FlashDisplayObject) -> void:
	_set_focus(o)


func get_focus() -> FlashDisplayObject:
	return _focus


func _fill_local(e: FlashEvent, target: FlashDisplayObject) -> void:
	var lp := target.globalToLocal(Vector2(e.stageX, e.stageY))
	e.localX = lp.x
	e.localY = lp.y


func _dispatch_mouse(target: FlashDisplayObject, type: String) -> void:
	var e := FlashEvent.mouse(type)
	_fill_local(e, target)
	target.dispatchEvent(e)


## Render targets (mask / group viewports) holding an interpolated object that moved this tick: they redraw every
## frame until the next tick, while Godot's physics interpolation glides the object; the others draw once after
## the tick (see FlashProxy.target_mode). Nested targets mark the ones around them too.
var moved_viewports := {}


func note_moved(vp: Viewport) -> void:
	while vp is SubViewport and not moved_viewports.has(vp):
		moved_viewports[vp] = true
		var outer := vp.get_parent()
		vp = outer.get_viewport() if outer != null else null


## Mouse motion is handled once per tick (and before a press), not per motion event: Godot sends about one a frame,
## and each costs a hit search of the scene (~0.2 ms; at 1000 fps a fifth of the frame time). The game sees the
## mouse in its ticks, and the picture changes only in ticks.
var _mouse_moved := false


func _flush_mouse_move() -> void:
	if not _mouse_moved:
		return
	_mouse_moved = false
	var target := _mouse_target_at(mouse_position())
	_dispatch_mouse(target, FlashEvent.MOUSE_MOVE)
	_update_mouse_over(target, true)


func _update_mouse_over(target: FlashDisplayObject = null, searched := false) -> void:
	if stage == null or not stage.is_inside_tree():
		return
	if not searched:
		target = _mouse_target_at(mouse_position())
	# the hovered object may have been freed since the last update (orphan freeing): treat it as gone
	var old: FlashDisplayObject = _mouse_over if is_instance_valid(_mouse_over) else null
	if target == old:
		return
	_mouse_over = target
	if old != null:
		var e := FlashEvent.mouse(FlashEvent.MOUSE_OUT)
		e.relatedObject = target
		_fill_local(e, old)
		old.dispatchEvent(e)
	if target != null:
		var e := FlashEvent.mouse(FlashEvent.MOUSE_OVER)
		e.relatedObject = old
		_fill_local(e, target)
		target.dispatchEvent(e)
	# ROLL_OUT / ROLL_OVER: non-bubbling, sent to every ancestor left / entered.
	var old_chain := _ancestors(old)
	var new_chain := _ancestors(target)
	for o in old_chain:
		if not new_chain.has(o):
			var e := FlashEvent.mouse(FlashEvent.ROLL_OUT, false)
			_fill_local(e, o)
			o.dispatchEvent(e)
	for i in range(new_chain.size() - 1, -1, -1):
		var o: FlashDisplayObject = new_chain[i]
		if not old_chain.has(o):
			var e := FlashEvent.mouse(FlashEvent.ROLL_OVER, false)
			_fill_local(e, o)
			o.dispatchEvent(e)
	var hand := false
	var o2 := target
	while o2 != null:
		if o2 is FlashSprite and o2.buttonMode and o2.useHandCursor:
			hand = true
			break
		o2 = o2._flash_parent
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hand else Input.CURSOR_ARROW)


func _ancestors(o: FlashDisplayObject) -> Array:
	var out: Array = []
	while o != null and is_instance_valid(o):
		out.append(o)
		o = o._flash_parent
	return out


# ---------------------------------------------------------------- sound

## Plays a timeline (StartSound) sound.
func play_library_sound(lib: FlashLibrary, id: int) -> void:
	var s := FlashSound.from_library(lib, id)
	if s != null:
		s.play()


func _get_audio_player() -> AudioStreamPlayer:
	for p in _audio_pool:
		if not p.playing and not p.has_meta("busy"):
			return p
	var np := AudioStreamPlayer.new()
	# Each pooled player gets its own bus with a panner, for SoundTransform.pan.
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	var bus_name := "FlashSfx%d" % _audio_pool.size()
	AudioServer.set_bus_name(bus, bus_name)
	AudioServer.set_bus_send(bus, "Master")
	AudioServer.add_bus_effect(bus, AudioEffectPanner.new())
	np.bus = bus_name
	add_child(np)
	_audio_pool.append(np)
	return np


## Stereo pan (-1..1) for a pooled player.
func set_player_pan(p: AudioStreamPlayer, pan: float) -> void:
	var bus := AudioServer.get_bus_index(p.bus)
	if bus > 0:
		var fx := AudioServer.get_bus_effect(bus, 0) as AudioEffectPanner
		if fx:
			fx.pan = clampf(pan, -1.0, 1.0)


## Global volume / mute (flash.media.SoundMixer.soundTransform).
func set_master_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.0)


# ---------------------------------------------------------------- external content

## Folder that relative content paths (mods, custom hair / backgrounds) resolve against, like a SWF's own
## location in Flash: the executable's folder when exported, the project's parent folder in the editor.
func content_root() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	return OS.get_executable_path().get_base_dir()


## Mods/ next to the game, organised by purpose. The folders only decide where file dialogs open: what a mod
## does is read from the file itself, so a mod works from any folder. Plugins/ is reserved for mods that change
## the game (loaded automatically at startup once supported).
const MOD_FOLDERS := ["Clothing", "Hair", "Backgrounds", "Characters", "Dialogue", "Plugins"]

## --mods-dir=<folder> on the command line: use that folder instead of Mods/ (tests run against a fixed mod set).
var mods_dir_override := ""


## Mods/ (or one of its MOD_FOLDERS) next to the game.
func mods_dir(sub: String = "") -> String:
	var d := mods_dir_override if mods_dir_override != "" else content_root().path_join("Mods")
	return d.path_join(sub) if sub != "" else d


func resolve_content_path(url: String) -> String:
	if url == "":
		return ""
	var p := url.replace("\\", "/")
	if p.begins_with("file:///"):
		p = p.substr(8)
	elif p.begins_with("file://"):
		p = p.substr(7)
	p = p.uri_decode()
	if p.is_absolute_path() or p.begins_with("res://") or p.begins_with("user://"):
		return p
	return content_root().path_join(p)


## Captures the last rendered frame of the stage area as an Image of size (stage_size * scale). Flash drew the
## display list into a BitmapData; here the displayed frame is read back, which shows the same content (the game
## only captures what is on screen) and keeps the window's resolution for high-quality screenshots.
func capture_screen(stage_size: Vector2, scale: float = 1.0) -> Image:
	var vp := get_viewport()
	if vp == null:
		return null
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	var t := _stage_to_window()
	var origin := t.origin
	var s := t.get_scale()
	var rect := Rect2i(Vector2i(origin.round()), Vector2i((stage_size * s).round()))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return null
	var out := img.get_region(rect)
	var want := Vector2i(maxi(1, int(round(stage_size.x * scale))), maxi(1, int(round(stage_size.y * scale))))
	if out.get_size() != want:
		out.resize(want.x, want.y, Image.INTERPOLATE_LANCZOS if want.x < out.get_width() else Image.INTERPOLATE_CUBIC)
	out.convert(Image.FORMAT_RGBA8)
	return out

