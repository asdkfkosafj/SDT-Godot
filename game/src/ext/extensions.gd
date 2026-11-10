class_name Extensions
extends RefCounted
## Port extension (not in the original game): loads, enables and runs extensions (see SDTExtension).
##
## - Built-in extensions are listed in BUILTIN; plugins from Mods/Plugins are added with add() (plugin loading
##   comes later).
## - Which extensions are on, and their settings, are kept in extensions.cfg next to the save files
##   (FlashSharedObject.save_dir, so --save-dir test runs use their own copy).
## - "Vanilla mode" (setting, or --vanilla on the command line) keeps every extension off.
## - Tick callbacks run at two fixed points of the game tick (Flash.tick_before / tick_after), in extension load
##   order; their time shows in --profile and in HITCH lines as "ext:<id>".
## - Plugin errors are contained (see "guard" below): a plugin whose code raises an error is switched off for the
##   session, and one that crashed the game is switched off at the next start.

## Built-in extensions (script paths), in load order.
const BUILTIN: Array[String] = [
	"res://src/ext/dialogueactions/dialogue_actions.gd",
	"res://src/ext/moremoods/moremoods.gd",
	"res://src/ext/moretriggers/moretriggers.gd",
	"res://src/ext/dasbyaddons/dasbyaddons.gd",
	"res://src/ext/dialogpatch/dialogpatch.gd",
	"res://src/ext/dialogdisplayedit/dialogdisplayedit.gd",
	"res://src/ext/gaggeddialog/gaggeddialog.gd",
	"res://src/ext/dialogspeed/dialogspeed.gd",
	"res://src/ext/monitordialog/monitordialog.gd",
	"res://src/ext/templateextension/templateextension.gd",
	"res://src/ext/hairrgb/hairrgb.gd",
	"res://src/ext/loaderarm/loaderarm.gd",
	"res://src/ext/cumrgb/cumrgb.gd",
	"res://src/ext/allalphasliders/allalphasliders.gd",
	"res://src/ext/removedefaultrgb/removedefaultrgb.gd",
	"res://src/ext/headwearland/headwearland.gd",
	"res://src/ext/counters/counters.gd",
	"res://src/ext/coughhotkey/coughhotkey.gd",
	"res://src/ext/clearallshortcut/clearallshortcut.gd",
	"res://src/ext/loadershortcuts/loadershortcuts.gd",
	"res://src/ext/throatsoundcontrol/throatsoundcontrol.gd",
	"res://src/ext/wincecontrol/wincecontrol.gd",
	"res://src/ext/himnotletgo/himnotletgo.gd",
	"res://src/ext/menualphatoggle/menualphatoggle.gd",
	"res://src/ext/charcodefilesaving/charcodefilesaving.gd",
	"res://src/ext/dynamicblushing/dynamicblushing.gd",
	"res://src/ext/alternativepassout/alternativepassout.gd",
	"res://src/ext/moveear/moveear.gd",
	"res://src/ext/movebrow/movebrow.gd",
	"res://src/ext/moveeyewear/moveeyewear.gd",
	"res://src/ext/tonguelength/tonguelength.gd",
	"res://src/ext/throatresiststretch/throatresiststretch.gd",
	"res://src/ext/throatcumbulge/throatcumbulge.gd",
	"res://src/ext/chokercollarresistance/chokercollarresistance.gd",
	"res://src/ext/penisrange/penisrange.gd",
	"res://src/ext/tongueguard/tongueguard.gd",
	"res://src/ext/aimpenis/aimpenis.gd",
	"res://src/ext/regulaterandom/regulaterandom.gd",
	"res://src/ext/morespitstrands/morespitstrands.gd",
	"res://src/ext/morecumspurts/morecumspurts.gd",
	"res://src/ext/lipstickringsmear/lipstickringsmear.gd",
	"res://src/ext/strandlimit/strandlimit.gd",
	"res://src/ext/dynamichair/dynamichair.gd",
	"res://src/ext/extramod/extramod.gd",
	"res://src/ext/extramodhim/extramodhim.gd",
]

const CONFIG_FILE := "extensions.cfg"

## The extension API (SDTExtension, hook points, value points, events) that plugins are checked against (their
## plugin.cfg api_version, 1 when missing). Raise API_VERSION when adding to it: a plugin that uses the addition
## sets that number and an older game refuses it. Raise MIN_API_VERSION when changing or removing something
## plugins may use: plugins written for an older API are refused instead of failing during play.
const API_VERSION := 2   # 2: FlashGroupProxy.of / render_texture / render_rect / set_cut
const MIN_API_VERSION := 1

static var all: Array[SDTExtension] = []
static var by_id: Dictionary = {}
static var vanilla_mode := false
static var started := false

static var _config: ConfigFile = null
static var _ticks: Array = []        # [extension, Callable], before the game's tick
static var _late_ticks: Array = []   # [extension, Callable], after it
static var _installed := false
static var _events: Dictionary = {}   # event name -> [[extension, Callable]]
static var _widgets: Array = []      # [extension, FlashDisplayObject]
static var _da_addons: Array = []    # [extension, Callable(da)]: additions to DialogueActions (on_dialogueactions)

## Plugins found in Mods/Plugins: id -> {"folder", "name", "author", "version", "error"} ("" = loaded).
static var plugins: Dictionary = {}
const LOADING_MARKER := "loading_plugin.txt"

## Events extensions can listen to with SDTExtension.on_event(): name -> description.
const EVENTS := {
	"mods_loaded": "a character's .swf mods (or mods chosen in a picker) finished loading",
	"mood_changed": "her mood changed; argument: the mood name (an extended one if active, see Moods)",
}


## Called once the game is built (end of DT.initGame): loads the built-in extensions and enables those that are on.
static func start() -> void:
	if started:
		return
	started = true
	_load_config()
	vanilla_mode = "--vanilla" in OS.get_cmdline_user_args() or bool(_config.get_value("extensions", "vanilla_mode", false))
	_install_tick()
	_install_guard()
	for path in BUILTIN:
		var scr = load(path)
		if scr == null:
			push_error("extensions: cannot load %s" % path)
			continue
		add(scr.new())
	load_plugins(Flash.mods_dir("Plugins"))


## Adds an extension (built in or a plugin): declares its settings, loads saved values, enables it if it is on.
static func add(ext: SDTExtension) -> bool:
	if ext.id == "" or by_id.has(ext.id):
		push_error("extensions: missing or duplicate id '%s'" % ext.id)
		return false
	if _config == null:
		_load_config()
	all.append(ext)
	by_id[ext.id] = ext
	ext._setup()
	for s in ext.settings():
		if _config.has_section_key(ext.id, s["key"]):
			ext._settings[s["key"]]["value"] = ext._coerce(s, _config.get_value(ext.id, s["key"]))
	if is_on(ext.id):
		_enable(ext)
	return true


## Removes an extension entirely (disables it first). Used by tests and when a plugin is unloaded.
static func remove(ext_id: String) -> void:
	var ext: SDTExtension = by_id.get(ext_id)
	if ext == null:
		return
	if ext.enabled:
		_disable(ext)
	all.erase(ext)
	by_id.erase(ext_id)


static func get_extension(ext_id: String) -> SDTExtension:
	return by_id.get(ext_id)


## Whether the extension with this id is (or would be) enabled: the player's choice, else its default.
static func is_on(ext_id: String) -> bool:
	if vanilla_mode:
		return false
	var ext: SDTExtension = by_id.get(ext_id)
	var dflt := ext.default_enabled if ext != null else false
	return bool(_config.get_value("enabled", ext_id, dflt)) if _config != null else dflt


## Switches an extension on or off and remembers the choice.
static func set_enabled(ext_id: String, on: bool) -> void:
	var ext: SDTExtension = by_id.get(ext_id)
	if ext == null:
		return
	_config.set_value("enabled", ext_id, on)
	_save_config()
	ext.fault = ""   # the player tries it again
	if vanilla_mode:
		return
	if on and not ext.enabled:
		_enable(ext)
	elif not on and ext.enabled:
		_disable(ext)


## Turns Vanilla mode on (all extensions off) or off (each back to its own on/off choice).
static func set_vanilla_mode(on: bool) -> void:
	vanilla_mode = on
	_config.set_value("extensions", "vanilla_mode", on)
	_save_config()
	for ext in all:
		var want := is_on(ext.id)
		if want and not ext.enabled:
			_enable(ext)
		elif not want and ext.enabled:
			_disable(ext)


## Folder for extension files, next to the save files.
static func data_root() -> String:
	return FlashSharedObject.save_dir.path_join("extensions")


# ---------------------------------------------------------------- internals

static func _enable(ext: SDTExtension) -> void:
	ext.enabled = true
	var prev := enter(ext.id)
	ext._enable()
	CharCode.adopt_kept(ext.id)
	leave(prev)


static func _disable(ext: SDTExtension) -> void:
	ext.enabled = false
	Hooks.remove_owner(ext.id)
	CharCode.remove_owner(ext.id)
	Moods.unregister_owner(ext.id)
	SDTMenu.remove_owner(ext.id)
	_da_addons = _da_addons.filter(func(x): return x[0] != ext)
	var da: SDTExtension = by_id.get("dialogueactions")
	if da != null and da != ext and da.enabled:
		da.remove_owner(ext.id)
	for w in _widgets.filter(func(x): return x[0] == ext):
		if is_instance_valid(w[1]) and w[1]._flash_parent != null:
			w[1]._flash_parent.removeChild(w[1])
	_widgets = _widgets.filter(func(x): return x[0] != ext)
	Hotkeys.remove_owner(ext.id)
	for name in _events:
		_events[name] = _events[name].filter(func(e): return e[0] != ext)
	_ticks = _ticks.filter(func(t): return t[0] != ext)
	_late_ticks = _late_ticks.filter(func(t): return t[0] != ext)
	var prev := enter(ext.id)
	ext._disable()
	leave(prev)


## Releases every extension when the game quits (main scene _exit_tree). Plugin scripts are compiled at runtime;
## if static lists still hold their instances while the engine shuts down, Godot can crash on exit.
static func shutdown() -> void:
	for ext in all.duplicate():
		if ext.enabled:
			_disable(ext)
	_uninstall_guard()
	all.clear()
	by_id.clear()
	_ticks.clear()
	_late_ticks.clear()
	_events.clear()
	Hotkeys.clear()
	_widgets.clear()
	Hooks._hooks.clear()
	CharCode._fields.clear()
	CharCode._order.clear()
	CharCode._pending.clear()
	Moods._registered.clear()
	Moods._extended = ""


# ---------------------------------------------------------------- plugins

## Loads every plugin in `dir` (one folder per plugin, each with a plugin.cfg). A plugin that crashed or hung the
## game while it was being loaded last time (its id is still in the loading marker) is switched off.
static func load_plugins(dir: String) -> void:
	var marker := data_root().path_join(LOADING_MARKER)
	if FileAccess.file_exists(marker):
		var bad := FileAccess.get_file_as_string(marker).strip_edges()
		if bad != "":
			push_warning("extensions: plugin '%s' did not finish loading last time; it has been switched off" % bad)
			_config.set_value("enabled", bad, false)
			_save_config()
		DirAccess.remove_absolute(marker)
	var note := data_root().path_join(CRASH_NOTE)
	if FileAccess.file_exists(note):
		crashed_last_time = FileAccess.get_file_as_string(note).strip_edges()
		DirAccess.remove_absolute(note)
		if crashed_last_time != "":
			push_warning("extensions: plugin '%s' crashed the game last time; it has been switched off" % crashed_last_time)
			_config.set_value("enabled", crashed_last_time, false)
			_save_config()
	var da := DirAccess.open(dir)
	if da == null:
		return
	var found: Array = []   # [id, folder, ConfigFile]
	for sub in da.get_directories():
		var folder := dir.path_join(sub)
		var cfg := ConfigFile.new()
		if cfg.load(folder.path_join("plugin.cfg")) != OK:
			continue
		var pid := str(cfg.get_value("plugin", "id", sub))
		if plugins.has(pid) or by_id.has(pid):
			push_warning("extensions: plugin id '%s' (%s) is already used, skipped" % [pid, folder])
			continue
		var api := int(cfg.get_value("plugin", "api_version", 1))
		plugins[pid] = {"folder": folder, "name": str(cfg.get_value("plugin", "name", pid)),
			"author": str(cfg.get_value("plugin", "author", "")),
			"version": str(cfg.get_value("plugin", "version", "")), "api_version": api, "error": ""}
		if api > API_VERSION:
			plugins[pid]["error"] = "needs a newer game (extension API %d, this game has %d)" % [api, API_VERSION]
		elif api < MIN_API_VERSION:
			plugins[pid]["error"] = "written for an older game (extension API %d, this game needs %d or later)" \
				% [api, MIN_API_VERSION]
		if plugins[pid]["error"] != "":
			push_warning("extensions: plugin '%s' not loaded: %s" % [pid, plugins[pid]["error"]])
			continue
		found.append([pid, folder, cfg])
	found.sort_custom(func(a, b): return a[0] < b[0])
	# a plugin loads after the plugins it depends on
	var progress := true
	while progress and not found.is_empty():
		progress = false
		for f in found.duplicate():
			var deps: Array = f[2].get_value("plugin", "depends", [])
			if deps.all(func(d): return by_id.has(d)):
				found.erase(f)
				_load_plugin(f[0], f[1], f[2], marker)
				progress = true
	for f in found:
		plugins[f[0]]["error"] = "missing dependency %s" % [f[2].get_value("plugin", "depends", [])]
		push_warning("extensions: plugin '%s' not loaded: %s" % [f[0], plugins[f[0]]["error"]])


static func _load_plugin(pid: String, folder: String, cfg: ConfigFile, marker: String) -> void:
	DirAccess.make_dir_recursive_absolute(data_root())
	var mf := FileAccess.open(marker, FileAccess.WRITE)
	if mf != null:
		mf.store_string(pid)
		mf.close()
	var scr := compile_script(folder.path_join(str(cfg.get_value("plugin", "main", "plugin.gd"))))
	var ext = scr.new() if scr != null else null
	if not ext is SDTExtension:
		plugins[pid]["error"] = "main script missing, broken or not an SDTExtension"
		push_warning("extensions: plugin '%s': %s" % [pid, plugins[pid]["error"]])
	else:
		ext.id = pid
		ext.builtin = false
		ext.folder = folder
		if ext.title == "":
			ext.title = plugins[pid]["name"]
		ext.author = plugins[pid]["author"]
		ext.version = plugins[pid]["version"]
		ext.default_enabled = bool(cfg.get_value("plugin", "enabled_by_default", true))
		if pid == crashed_last_time:
			ext.fault = "it crashed the game last time, so it was switched off"
		_note_numbers[pid] = _note_numbers.size() + 1
		if _note != null:
			_note.name_plugin(_note_numbers[pid], pid)
		add(ext)
	DirAccess.remove_absolute(marker)


## Compiles a GDScript file from anywhere on disk (plugins live outside the project). Plugin scripts may not use
## class_name, so they cannot take over the name of a game class.
static func compile_script(path: String) -> GDScript:
	if not FileAccess.file_exists(path):
		push_warning("extensions: %s not found" % path)
		return null
	var src := FileAccess.get_file_as_string(path)
	for line in src.split("\n"):
		if line.strip_edges().begins_with("class_name"):
			push_warning("extensions: %s uses class_name, which plugin scripts may not do" % path)
			return null
	var scr := GDScript.new()
	scr.source_code = src
	scr.resource_path = path   # errors and backtraces name the file (the guard finds the plugin by it)
	if scr.reload() != OK:
		push_warning("extensions: %s has errors" % path)
		return null
	return scr


# ---------------------------------------------------------------- keys and widgets

## Runs the extensions' actions on this key (tests; play goes through Hotkeys.pressed from DT.keyPressed).
static func key_pressed(keycode: int) -> void:
	for a in Hotkeys.actions.filter(func(x): return x["owner"] != Hotkeys.GAME and Hotkeys.binding(x["id"]) == keycode):
		if a["fn"].is_valid():
			a["fn"].call()


## An extension's hotkey as a rebindable action (Settings › Hotkeys), id "<extension>:<id or label>".
static func _add_key(ext: SDTExtension, keycode: int, fn: Callable, label: String, id: String) -> void:
	var aid := ext.id + ":" + (id if id != "" else label)
	if Hotkeys.by_id.has(aid):   # the same label twice: told apart by the default key
		aid += ":%d" % keycode
	Hotkeys.add(aid, ext.id, label, keycode, fn)


static func _add_da_addon(ext: SDTExtension, setup: Callable) -> void:
	_da_addons.append([ext, setup])
	var da: SDTExtension = by_id.get("dialogueactions")
	if da != null and da != ext and da.enabled:
		da.run_addon(ext.id, setup)


## The DialogueActions additions of enabled extensions, in registration order (DialogueActions runs them when it
## is switched on).
static func da_addons() -> Array:
	return _da_addons.filter(func(x): return x[0].enabled)


static func _add_widget(ext: SDTExtension, w: FlashDisplayObject) -> void:
	_widgets.append([ext, w])


## Calls every listener of event `name` (see EVENTS) with `args`.
static func emit(name: String, args: Array = []) -> void:
	for e in _events.get(name, []).duplicate():
		var fn: Callable = e[1]
		if fn.is_valid():
			var prev := enter(e[0].id)
			fn.callv(args)
			leave(prev)


static func _add_event(ext: SDTExtension, name: String, fn: Callable) -> void:
	if not EVENTS.has(name):
		push_error("extension %s: unknown event '%s'" % [ext.id, name])
		return
	if not _events.has(name):
		_events[name] = []
	_insert_in_load_order(_events[name], [ext, fn])


static func _add_tick(ext: SDTExtension, fn: Callable, late: bool) -> void:
	var list := _late_ticks if late else _ticks
	_insert_in_load_order(list, [ext, fn])


## Adds `entry` ([extension, ...]) to `list` in extension load order, whatever order the callbacks were registered in;
## one extension's callbacks keep the order it registered them in (inserted, not sorted: Godot's sort_custom does not
## keep the order of equal items).
static func _insert_in_load_order(list: Array, entry: Array) -> void:
	var rank := all.find(entry[0])
	var at := list.size()
	while at > 0 and all.find(list[at - 1][0]) > rank:
		at -= 1
	list.insert(at, entry)


static func _install_tick() -> void:
	if _installed:
		return
	_installed = true
	Flash.tick_before.append(func(): _run_ticks(_ticks, "tick"))
	Flash.tick_after.append(func(): _run_ticks(_late_ticks, "late_tick"))


static func _run_ticks(list: Array, phase: String) -> void:
	if list.is_empty():
		return
	for t in list.duplicate():
		var fn: Callable = t[1]
		if not fn.is_valid():
			continue
		var ts := Time.get_ticks_usec()
		var prev := running
		var track: bool = prev != "" or not t[0].builtin
		if track:
			enter(t[0].id)
		fn.call()
		if track:
			leave(prev)
		Flash.account_listener("ext:%s.%s" % [t[0].id, phase], Time.get_ticks_usec() - ts)


static func _load_config() -> void:
	_config = ConfigFile.new()
	var path := FlashSharedObject.save_dir.path_join(CONFIG_FILE)
	if FileAccess.file_exists(path) and _config.load(path) != OK:
		push_warning("extensions: cannot read %s, using defaults" % path)
		_config = ConfigFile.new()


static func _save_config() -> void:
	var err := _config.save(FlashSharedObject.save_dir.path_join(CONFIG_FILE))
	if err != OK:
		push_warning("extensions: cannot save %s (error %d)" % [CONFIG_FILE, err])


static func _save_setting(ext: SDTExtension, key: String, value) -> void:
	if _config == null:
		_load_config()
	_config.set_value(ext.id, key, value)
	_save_config()


# ---------------------------------------------------------------- guard (port)

## Plugin errors are contained. The game notes which extension's code runs (`running`, set around every call it
## makes into one: ticks, hooks, value points, events, keys, character code fields, settings, menu widgets), and a
## Logger puts the errors reported meanwhile down to it; in debug builds the script backtrace also finds plugin code
## the game did not call directly (its own nodes and signals). A plugin whose code raised an error is switched off
## for the rest of the session (`fault` says why, in Mods > Extensions); the player's choice is kept, so it is tried
## again at the next start. Its own push_error() lines and warnings do not count.
## Release builds report far fewer script errors (no null checks: a call on null crashes the game), so the native
## crash note (SDTCrashNote, Windows) writes the running plugin's id to CRASH_NOTE when the game crashes; the next
## start switches that plugin off. Built-in extensions are tracked too, but never switched off.
const CRASH_NOTE := "crashed_plugin.txt"
## The extension whose code runs now (its id), or "" while the game's own code runs.
static var running := ""
## The plugin switched off at this start because it crashed the game last time, or "".
static var crashed_last_time := ""
static var _guard: Logger = null
static var _note: Object = null   # SDTCrashNote, when the native library has it
static var _note_numbers := {}    # plugin id -> its number for the crash note
static var _note_running := 0     # the number the crash note has now
static var _faults: Array = []    # [extension id, message], applied at the next frame
static var _applying := false


## Marks `owner`'s code as running; returns what ran before, for leave(). The hot loops (hooks, value points,
## ticks) skip it for built-in code the game calls directly (nothing to put an error down to), inline.
static func enter(owner: String) -> String:
	var prev := running
	if owner != prev:
		running = owner
		if _note != null:
			var n: int = _note_numbers.get(owner, 0)
			if n != _note_running:
				_note_running = n
				_note.set_running(n)
	return prev


static func leave(prev: String) -> void:
	if running != prev:
		running = prev
		if _note != null:
			var n: int = _note_numbers.get(prev, 0)
			if n != _note_running:
				_note_running = n
				_note.set_running(n)


## The plugin whose folder holds this script file, or "".
static func plugin_of_file(file: String) -> String:
	if file == "":
		return ""
	var f := file.replace("\\", "/")
	for pid in plugins:
		var folder := str(plugins[pid]["folder"]).replace("\\", "/")
		if folder != "" and f.begins_with(folder.trim_suffix("/") + "/"):
			return pid
	return ""


static func _install_guard() -> void:
	if _guard == null:
		_guard = _Guard.new()
		OS.add_logger(_guard)
	if _note == null and ClassDB.class_exists(&"SDTCrashNote"):
		DirAccess.make_dir_recursive_absolute(data_root())
		_note = ClassDB.instantiate(&"SDTCrashNote")
		if not _note.install(ProjectSettings.globalize_path(data_root().path_join(CRASH_NOTE))):
			_note = null


static func _uninstall_guard() -> void:
	if _guard != null:
		OS.remove_logger(_guard)
		_guard = null
	if _note != null:
		_note.uninstall()
		_note = null
		_note_running = 0
		# a clean exit: a note written for an exception that was handled after all goes
		var note := data_root().path_join(CRASH_NOTE)
		if FileAccess.file_exists(note):
			DirAccess.remove_absolute(note)
	running = ""


## An error was reported while `owner`'s code ran (main thread): its extension is switched off at the next frame.
static func _report_fault(owner: String, message: String) -> void:
	if _applying:
		return
	var ext: SDTExtension = by_id.get(owner)
	if ext == null or ext.builtin or ext.fault != "":
		return
	for f in _faults:
		if f[0] == owner:
			return
	_faults.append([owner, message])
	if _faults.size() == 1:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.process_frame.connect(_apply_faults, CONNECT_ONE_SHOT)


static func _apply_faults() -> void:
	_applying = true
	for f in _faults:
		var ext: SDTExtension = by_id.get(f[0])
		if ext == null or ext.fault != "":
			continue
		ext.fault = "stopped after an error: " + f[1]
		push_warning("extensions: plugin '%s' %s" % [ext.id, ext.fault])
		if ext.enabled:
			_disable(ext)
	_faults.clear()
	_applying = false


## Puts errors down to the extension that was running (or, in debug builds, to the plugin in the backtrace).
class _Guard extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING or function == "push_error":
			return
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			return
		var owner := Extensions.running
		if not Extensions.plugins.has(owner):
			owner = Extensions.plugin_of_file(file)
			for bt in script_backtraces:
				if owner != "":
					break
				for i in bt.get_frame_count():
					owner = Extensions.plugin_of_file(bt.get_frame_file(i))
					if owner != "":
						break
		if owner == "" or not Extensions.plugins.has(owner):
			return
		var where := file.get_file() + ":" + str(line) if file != "" else function
		var what := rationale if rationale != "" else code
		Extensions._report_fault(owner, "%s (%s)" % [what.strip_edges(), where])
