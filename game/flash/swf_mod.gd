class_name FlashSwfMod
extends RefCounted
## Runtime support for SWF mods (the original game's art-only .swf mods): converts a SWF into a library like the
## base game's (tools/swfconv, here with the native SWFFile reader / rasteriser instead of FFDec), caches it in
## user://modcache/<hash>/, and instantiates its symbols, running their timeline frame scripts with FlashAbc.
## Registered as a FlashLoader handler, so Loader.load("x.swf") gives the mod's main timeline as `content`.

## Folder of the converted mods (main.gd --mod-cache=<folder> points tests elsewhere).
static var cache_root := "user://modcache"
## Bump when the converter output changes, so cached conversions are redone.
## 2: "ma" (a shape's most opaque alpha, masks use the geometry); 3: COSTUME_FILL_GROW; 4: shape images are lossless
## WebP with their transparent edges already filled in (half the size of PNG, and no fix_alpha_edges when loading).
const CONVERTER_VERSION := 4
## Costume colour fills (the shapes inside sprites named rgbFill / rgbFill2) are grown outward by this many pixels
## (at 1x, solid parts only, see SWFFile.render): where a piece's edge lies exactly on her outline or on the next
## piece's edge, the two anti-aliased edges otherwise let what is underneath show through as a light line, much more
## than in Flash (whose renderer anti-aliases within a screen pixel; here the 2x textures are filtered down).
const COSTUME_FILL_GROW := 1.5
const COSTUME_FILLS := ["rgbFill", "rgbFill2"]
## Classes of the SDT mod kit implemented natively (the mod's compiled copies are ignored).
const KIT_CLASSES := {"SDTMods.ModPackage": "res://src/SDTMods/ModPackage.gd"}

var library: FlashLibrary
var abc: Array[FlashAbc] = []


static func register() -> void:
	if ClassDB.class_exists(&"SWFFile"):
		FlashLoader.preparers.append(_loader_prepare)
		FlashLoader.handlers.append(_loader_handler)


static func is_swf(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 8 and bytes[1] == 0x57 and bytes[2] == 0x53 and (bytes[0] == 0x43 or bytes[0] == 0x46)


static func _loader_handler(path: String, bytes: PackedByteArray) -> FlashDisplayObject:
	if not is_swf(bytes):
		return null  # not CWS / FWS
	var mod := load_mod(bytes, path)
	if mod == null:
		return null
	return mod.instantiate_root()


## Set when the game quits: conversions on worker threads stop at the next symbol (ModCatalog.shutdown). A stopped
## conversion writes no library.json, so the mod is converted again next time.
static var stop_converting := false
static var _loaded: Dictionary = {}   # digest -> FlashSwfMod (each file's library is loaded once)

## Conversions run on the converter's own threads, shared by the mod scan (ModCatalog) and the Loader, so a mod is
## converted once. Not Godot's WorkerThreadPool: a thread waiting there for one of its tasks (the main thread loading
## a texture) may run a queued task itself, and a conversion takes up to a minute. Not in headless runs (tests):
## there a mod converts when it is loaded, so runs repeat exactly.
static var async_conversion: bool = DisplayServer.get_name() != "headless"
## How many mods convert at once in the background (the scan of the collection), and how many more for the mods the
## player waits for (her character's): those never wait behind a big mod of the collection.
static var converter_threads: int = clampi(OS.get_processor_count() / 4, 2, 8)
static var _jobs: Dictionary = {}    # cache dir -> {"name", "bytes", "scale", "done"}; done is set by its thread
## Per kind (0 background, 1 urgent): cache dirs waiting for a thread (next first), the threads, one semaphore post
## per queued job (and one per thread to stop them).
static var _queues: Array = [[], []]
static var _threads: Array = [[], []]
static var _work: Array = [Semaphore.new(), Semaphore.new()]
static var _lock := Mutex.new()      # the queues and the jobs' "done"


## Starts converting a mod on a converter thread unless it is converted or converting already; returns its cache
## dir. urgent: a mod the player waits for (her character's) goes ahead of the scan of the whole collection.
static func convert_async(bytes: PackedByteArray, source_path: String, urgent := false) -> String:
	var dir := cache_root.path_join(_sha256(bytes))
	if _jobs.has(dir):
		if urgent:   # queued by the scan and not started yet: it moves to the urgent threads
			_lock.lock()
			var moved: bool = _queues[0].has(dir)
			if moved:
				_queues[0].erase(dir)
			_lock.unlock()
			if moved:
				_enqueue(dir, 1)
		return dir
	if is_converted(dir):
		return dir
	_jobs[dir] = {"name": source_path.get_file() if source_path != "" else dir.get_file(), "bytes": bytes,
		"scale": Flash.base_library.scale if Flash.base_library else 2.0, "done": false}
	_enqueue(dir, 1 if urgent else 0)
	return dir


static func _enqueue(dir: String, kind: int) -> void:
	_lock.lock()
	_queues[kind].push_back(dir)
	_lock.unlock()
	while _threads[kind].size() < converter_threads:
		var t := Thread.new()
		t.start(_thread_main.bind(kind), Thread.PRIORITY_LOW)
		_threads[kind].append(t)
	_work[kind].post()


static func _thread_main(kind: int) -> void:
	while true:
		_work[kind].wait()
		_lock.lock()
		var q: Array = _queues[kind]
		var dir = q.pop_front() if not q.is_empty() else null
		var job: Dictionary = _jobs.get(dir, {}) if dir != null else {}
		_lock.unlock()
		if stop_converting:
			return
		if job.is_empty():
			continue
		var t0 := Time.get_ticks_msec()
		if convert_swf(job["bytes"], dir, job["scale"]):
			print("SWF mod converted: %s (%d ms, converter thread)" % [job["name"], Time.get_ticks_msec() - t0])
		_lock.lock()
		job["done"] = true
		_lock.unlock()


## Whether the conversion into `dir` is still running or waiting; a finished one is collected here (once).
static func converting(dir: String) -> bool:
	var job = _jobs.get(dir)
	if job == null:
		return false
	_lock.lock()
	var done: bool = job["done"]
	_lock.unlock()
	if not done:
		return true
	_jobs.erase(dir)
	return false


## Waits for the conversion into `dir` (load_mod needs it now): a queued one is converted here, on this thread.
static func _wait_for(dir: String) -> void:
	_lock.lock()
	var queued := false
	for q in _queues:
		if q.has(dir):
			q.erase(dir)
			queued = true
	_lock.unlock()
	if queued:
		var job: Dictionary = _jobs[dir]
		convert_swf(job["bytes"], dir, job["scale"])
		_jobs.erase(dir)
		return
	while converting(dir):
		OS.delay_msec(5)


## File names of the mods converting or waiting now.
static func converting_names() -> Array:
	var names: Array = []
	for dir in _jobs:
		names.append(_jobs[dir]["name"])
	return names


## The game quits: running conversions stop at their next symbol and their threads are waited for (a thread still
## running GDScript while the engine shuts down crashes it).
static func stop_all() -> void:
	stop_converting = true
	for kind in 2:
		for t in _threads[kind]:
			_work[kind].post()
	for kind in 2:
		for t in _threads[kind]:
			t.wait_to_finish()
		_threads[kind].clear()
		_queues[kind].clear()
	_jobs.clear()


## Starts converting these mod files now, all at once and ahead of the scan (her character's mods, as soon as her
## code names them), so the Loader finds them done or nearly.
static func prefetch(paths: Array) -> void:
	if not async_conversion:
		return
	for p in paths:
		var bytes := FileAccess.get_file_as_bytes(p)
		if is_swf(bytes):
			convert_async(bytes, p, true)


## FlashLoader preparer: a SWF mod that is not converted yet converts on a worker thread, and the Loader finishes
## when it is done (port: converting on the main thread kept the screen black, 20 s and more for a big mod).
static func _loader_prepare(path: String, bytes: PackedByteArray) -> Callable:
	if not async_conversion or not is_swf(bytes):
		return Callable()
	var dir := convert_async(bytes, path, true)
	return func(): return converting(dir)


## True if 'dir' holds a conversion made by the current converter.
static func is_converted(dir: String) -> bool:
	if not FileAccess.file_exists(dir.path_join("library.json")):
		return false
	var info = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("library.json")))
	return info != null and int(info.get("converterVersion", 0)) == CONVERTER_VERSION


## Converts (or reuses the cached conversion of) a SWF and loads it as a library.
static func load_mod(bytes: PackedByteArray, source_path: String = "") -> FlashSwfMod:
	var digest := _sha256(bytes)
	if _loaded.has(digest):
		return _loaded[digest]
	var dir := cache_root.path_join(digest)
	if _jobs.has(dir):
		_wait_for(dir)   # converting on a thread, or waiting for one
	if not is_converted(dir):
		var t0 := Time.get_ticks_msec()
		if not convert_swf(bytes, dir, Flash.base_library.scale if Flash.base_library else 2.0):
			push_error("SWF mod: could not convert %s" % source_path)
			return null
		print("SWF mod converted: %s (%d ms)" % [source_path.get_file() if source_path else digest, Time.get_ticks_msec() - t0])
	var lib := Flash.load_library(dir)
	if lib == null:
		return null
	var mod := FlashSwfMod.new()
	_loaded[digest] = mod
	mod.library = lib
	lib.is_mod = true
	lib.mod = mod
	var i := 0
	while FileAccess.file_exists(dir.path_join("abc_%d.bin" % i)):
		var a := FlashAbc.parse(FileAccess.get_file_as_bytes(dir.path_join("abc_%d.bin" % i)))
		if a != null:
			a.host = mod
			a.source = source_path.get_file()
			mod.abc.append(a)
		i += 1
	return mod


## A converted library shipped with the game (art of a Loader mod, without its code): its symbols are created with
## create(class name). Loaded once.
static func load_art(dir: String) -> FlashSwfMod:
	if _loaded.has(dir):
		return _loaded[dir]
	var lib := Flash.load_library(dir)
	if lib == null:
		push_error("SWF art not found: %s" % dir)
		return null
	var mod := FlashSwfMod.new()
	_loaded[dir] = mod
	mod.library = lib
	lib.is_mod = true
	lib.mod = mod
	return mod


## A new instance of the library class `cls` ("headorigin"), every clip in it stopped on its first frame (the
## clips' own frame scripts only stopped them); null if there is no such class.
func create(cls: String) -> FlashDisplayObject:
	var id := _class_id(cls)
	if id < 0:
		return null
	var o = create_class_instance(id)
	if o is FlashDisplayObject:
		_stop_all(o)
		return o
	return null


static func _stop_all(o) -> void:
	if o is FlashMovieClip:
		o.stop()
	if o is FlashSprite:
		for i in o.numChildren:
			_stop_all(o.getChildAt(i))


static func _sha256(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


# ---------------------------------------------------------------- conversion (port of tools/swfconv/convert.py)

static func convert_swf(bytes: PackedByteArray, out_dir: String, scale: float) -> bool:
	var swf: Object = ClassDB.instantiate(&"SWFFile")
	if swf.open(bytes) != OK:
		return false
	for sub in ["shapes", "sounds", "bitmaps", "binary"]:
		DirAccess.make_dir_recursive_absolute(out_dir.path_join(sub))
	# an older conversion's images (other names or another format) would stay behind otherwise
	for f in DirAccess.get_files_at(out_dir.path_join("shapes")):
		DirAccess.remove_absolute(out_dir.path_join("shapes").path_join(f))
	var info: Dictionary = swf.get_info()
	var lib := {"version": 1, "converterVersion": CONVERTER_VERSION, "width": info["width"], "height": info["height"],
		"fps": info["fps"], "scale": scale, "classes": {}, "chars": {}, "imageFormat": "webp", "edgesFixed": true}
	var chars: Dictionary = lib["chars"]
	var symbols: Dictionary = swf.get_symbol_classes()
	for cid in symbols:
		if int(cid) == 0:
			lib["documentClass"] = symbols[cid]
		else:
			lib["classes"][symbols[cid]] = int(cid)
	var exports: Dictionary = swf.get_exports()
	for cid in exports:
		if not lib["classes"].has(exports[cid]):
			lib["classes"][exports[cid]] = int(cid)
	var all_chars: Dictionary = swf.get_characters()
	var grids: Dictionary = swf.get_scaling_grids()
	var morph_uses := {}
	for cid in all_chars:
		if stop_converting:
			return false
		if all_chars[cid]["type"] == "sprite":
			var tl := _build_timeline(swf.get_timeline(int(cid)), morph_uses)
			tl["t"] = "sprite"
			if grids.has(cid):
				tl["grid"] = grids[cid]
			chars[str(cid)] = tl
	var root := _build_timeline(swf.get_timeline(-1), morph_uses)
	var scenes: Array = swf.get_scenes()
	if not scenes.is_empty():
		root["scenes"] = scenes
	lib["root"] = root
	var root_sym := root.duplicate()
	root_sym["t"] = "sprite"
	chars["0"] = root_sym   # the main timeline as a symbol, so it is created like any other

	var fills := _costume_fill_shapes(chars, root)
	var blob := PackedByteArray()
	var render := func(cid: int, ratio: int, img_name: String) -> Dictionary:
		var r: Dictionary = swf.render(cid, ratio, scale, COSTUME_FILL_GROW if fills.has(cid) else 0.0)
		if r.is_empty() or r["empty"]:
			return {}
		# what Godot's importer does for the game's own art, done once here instead of at every load: transparent
		# pixels take their neighbours' colour, so filtering draws no dark seams where two pieces meet. Lossless WebP
		# keeps those pixels exactly.
		var image: Image = r["image"]
		image.fix_alpha_edges()
		image.save_webp(out_dir.path_join("shapes/%s.webp" % img_name))
		var entry := {"img": img_name, "x": r["x"], "y": r["y"], "w": r["w"], "h": r["h"],
			"hm": [blob.size(), r["hw"], r["hh"]]}
		if r.has("ma"):
			entry["ma"] = r["ma"]
		blob.append_array(r["hit"])
		return entry
	for cid in all_chars:
		if stop_converting:
			return false
		var t: String = all_chars[cid]["type"]
		var id := int(cid)
		match t:
			"shape", "text":
				var e: Dictionary = render.call(id, -1, ("s%d" if t == "shape" else "t%d") % id)
				chars[str(id)] = {"t": "empty"} if e.is_empty() else e.merged({"t": "shape"})
			"morph":
				var entry := {"t": "morph", "ratios": {}}
				for ratio in morph_uses.get(id, {0: true}):
					var e: Dictionary = render.call(id, ratio, "m%d_%d" % [id, ratio])
					entry["ratios"][str(ratio)] = null if e.is_empty() else e
				chars[str(id)] = entry
			"edittext":
				chars[str(id)] = swf.get_edit_text(id)
			"bitmap":
				var img: Image = swf.get_bitmap(id)
				if img != null:
					img.save_png(out_dir.path_join("bitmaps/%d.png" % id))
					chars[str(id)] = {"t": "bitmap", "file": "bitmaps/%d.png" % id}
				else:
					chars[str(id)] = {"t": "bitmap"}
			"sound":
				var snd: Dictionary = swf.get_sound(id)
				if int(snd.get("format", -1)) == 2:
					var f := FileAccess.open(out_dir.path_join("sounds/%d.mp3" % id), FileAccess.WRITE)
					f.store_buffer(snd["data"])
					f.close()
					chars[str(id)] = {"t": "sound", "file": "sounds/%d.mp3" % id}
				else:
					chars[str(id)] = {"t": "sound"}
			"binary":
				var f := FileAccess.open(out_dir.path_join("binary/%d.bin" % id), FileAccess.WRITE)
				f.store_buffer(swf.get_binary(id))
				f.close()
				chars[str(id)] = {"t": "binary", "file": "binary/%d.bin" % id}
			"font":
				chars[str(id)] = {"t": "font", "name": ""}
			"button":
				chars[str(id)] = {"t": "empty"}
	var hf := FileAccess.open(out_dir.path_join("hitmasks.bin"), FileAccess.WRITE)
	hf.store_buffer(blob)
	hf.close()
	var blocks: Array = swf.get_abc_blocks()
	for i in blocks.size():
		var af := FileAccess.open(out_dir.path_join("abc_%d.bin" % i), FileAccess.WRITE)
		af.store_buffer(blocks[i])
		af.close()
	var jf := FileAccess.open(out_dir.path_join("library.json"), FileAccess.WRITE)
	jf.store_string(JSON.stringify(lib))
	jf.close()
	return true


## Ids of the characters placed (directly or in nested sprites) inside a sprite placed as rgbFill / rgbFill2.
static func _costume_fill_shapes(chars: Dictionary, root: Dictionary) -> Dictionary:
	var found := {}
	var todo: Array = []
	for tl in [root] + chars.values():
		for p in tl.get("places", []):
			if str(p.get("n", "")) in COSTUME_FILLS:
				todo.append(int(p["c"]))
	while not todo.is_empty():
		var cid: int = todo.pop_back()
		if found.has(cid):
			continue
		found[cid] = true
		var tl = chars.get(str(cid))
		if tl is Dictionary:
			for p in tl.get("places", []):
				todo.append(int(p["c"]))
	return found


static func _r6(v) -> float:
	return snappedf(float(v), 0.000001)


static func _placement_key(p: Dictionary) -> Dictionary:
	var out := {"c": p["id"]}
	var m = p.get("matrix")
	if m != null and m != [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]:
		out["m"] = m.map(_r6)
	var ct = p.get("cxform")
	if ct != null and ct != [1.0, 1.0, 1.0, 1.0, 0, 0, 0, 0]:
		out["ct"] = ct.map(_r6)
	if p.get("ratio", 0):
		out["r"] = p["ratio"]
	if p.get("name", ""):
		out["n"] = p["name"]
	if p.get("clipDepth", 0):
		out["cd"] = p["clipDepth"]
	if p.get("blend", "normal") != "normal":
		out["bl"] = p["blend"]
	if p.get("filters"):
		out["f"] = p["filters"]
	if p.has("visible") and not p["visible"]:
		out["v"] = 0
	if p.get("cacheAsBitmap", 0):
		out["cab"] = 1
	return out


## tools/swfconv/convert.py build_timeline: per-frame display lists of [depth, place index, birth frame].
static func _build_timeline(tl: Array, morph_uses: Dictionary) -> Dictionary:
	var frames_ops: Array = tl[0] if tl.size() > 0 else []
	var labels: Dictionary = tl[1] if tl.size() > 1 else {}
	var places: Array = []
	var index := {}
	var state := {}
	var frames: Array = []
	var sounds := {}
	for fi in frames_ops.size():
		for op in frames_ops[fi]:
			match op["op"]:
				"remove":
					state.erase(int(op["depth"]))
				"sound":
					if not sounds.has(str(fi)):
						sounds[str(fi)] = []
					sounds[str(fi)].append(op["id"])
				"place":
					var d := int(op["depth"])
					if not op["move"] or not state.has(d):
						if not op.has("id"):
							continue
						var cur := {}
						for k in op:
							if not k in ["op", "move", "depth", "hasClipActions"]:
								cur[k] = op[k]
						state[d] = [cur, fi]
					else:
						var cur: Dictionary = state[d][0].duplicate()
						for k in op:
							if not k in ["op", "move", "depth", "hasClipActions"]:
								cur[k] = op[k]
						if op.has("id") and op["id"] != state[d][0]["id"]:
							state[d] = [cur, fi]
						else:
							state[d] = [cur, state[d][1]]
		var row: Array = []
		var depths := state.keys()
		depths.sort()
		for d in depths:
			var key := _placement_key(state[d][0])
			var cid := int(key["c"])
			if not morph_uses.has(cid):
				morph_uses[cid] = {}
			morph_uses[cid][int(key.get("r", 0))] = true
			var sk := JSON.stringify(key, "", true)
			if not index.has(sk):
				index[sk] = places.size()
				places.append(key)
			row.append([d, index[sk], state[d][1]])
		frames.append(row)
	var out := {"places": places, "frames": frames, "labels": labels}
	if not sounds.is_empty():
		out["sounds"] = sounds
	return out


# ---------------------------------------------------------------- instances

## Full AS3 class name of a symbol of this library ("" if none).
func class_of(id: int) -> String:
	if id == 0:
		return library.document_class
	for cls in library.classes:
		if int(library.classes[cls]) == id:
			return cls
	return ""


func _abc_for(cls: String) -> FlashAbc:
	for a in abc:
		if a.class_by_name.has(cls):
			return a
	return null


func instantiate_root() -> FlashDisplayObject:
	library.decode_all()
	var root := _instantiate_root()
	library.forget_decoded()
	return root


func _instantiate_root() -> FlashDisplayObject:
	return instantiate(0)


## The Loader calls a loaded mod package's initl(loader). Here it runs without a loader (null): the mod's setup of
## its own display objects works (a mod masking one part's erase shape with another part); Loader API
## calls (lProxy hooks, addEnterFramePersist, ...) and reads of l.g find nothing.
func run_initl(root) -> void:
	if root == null or not root.has_meta(&"abc"):
		return
	var a: FlashAbc = root.get_meta(&"abc")
	var m := a.find_method(str(root.get_meta(&"abc_class", "")), "initl")
	if not m.is_empty() and m[0] == 1:
		FlashAbc.quiet = true
		a.run(m[1], root, [null])
		FlashAbc.quiet = false


## Creates symbol 'id' (what a timeline PlaceObject or `new Class()` does), then runs its frame-1 script.
func instantiate(id: int, parent = null, place: Dictionary = {}, pidx: int = -1, depth: int = -1,
		birth: int = -1) -> FlashDisplayObject:
	var cls := class_of(id)
	var a := _abc_for(cls) if cls != "" else null
	var script: Script = null
	if a != null:
		for kit in KIT_CLASSES:
			if a.extends_class(cls, kit) or cls == kit:
				script = load(KIT_CLASSES[kit])
	elif KIT_CLASSES.has(cls):
		script = load(KIT_CLASSES[cls])
	Flash._pending_symbol = [library, id, parent, place, pidx, depth, birth]
	var mc: FlashMovieClip = script.new() if script != null else FlashMovieClip.new()
	Flash._pending_symbol = null
	if a != null:
		var defaults := a.slot_defaults(cls)
		for k in defaults:
			if not KIT_CLASSES.has(cls) and mc.get(k) == null:
				mc.set(k, defaults[k])
		mc.set_meta(&"abc", a)
		mc.set_meta(&"abc_class", cls)
		var scripts := a.frame_scripts(cls)
		for f in scripts:
			var mi: int = scripts[f]
			mc.addFrameScript(f, func() -> void: a.run(mi, mc))
		if scripts.has(mc._frame):
			mc._run_frame_script(mc._frame)
	return mc


# ---------------------------------------------------------------- FlashAbc host (globals for interpreted code)

func _class_id(n: String) -> int:
	if library.classes.has(n):
		return int(library.classes[n])
	for cls in library.classes:
		if String(cls).get_slice(".", String(cls).get_slice_count(".") - 1) == n:
			return int(library.classes[cls])
	return -1


func abc_has_global(n: String) -> bool:
	if n in ["trace", "ModTypes", "ModElements", "Math", "getDefinitionByName", "String", "Number", "int", "uint",
			"Boolean", "Array", "Object", "isNaN", "Event", "MouseEvent", "Dictionary"]:
		return true
	if _class_id(n) >= 0:
		return true
	for a in abc:
		if a.find_class(n) != "":
			return true
	return false


func abc_global(n: String):
	# classes compiled into the mod (its own copy of the kit's ModTypes / ModElements included) come first
	for a in abc:
		var full := a.find_class(n)
		if full != "":
			var d := a.static_consts(full)
			d["__class__"] = full
			return d
	match n:
		"Event", "MouseEvent":
			return FlashEvent.new("").get_script().get_script_constant_map()
		"ModTypes":
			return ModTypes.new().get_script().get_script_constant_map()
		"ModElements":
			return ModElements.new().get_script().get_script_constant_map()
		"Math":
			return {"__host_object__": "Math"}
	var id := _class_id(n)
	if id >= 0:
		return {"__class__": n}
	return null


func abc_call_global(n: String, args: Array):
	match n:
		"trace":
			print("[mod] ", " ".join(PackedStringArray(args.map(func(v): return FlashAbc._str(v)))))
			return null
		"getDefinitionByName":
			return {"__class__": str(args[0])} if not args.is_empty() else null
		"String":
			return FlashAbc._str(args[0]) if not args.is_empty() else ""
		"Number":
			return FlashAbc._num(args[0]) if not args.is_empty() else 0.0
		"int", "uint":
			return int(FlashAbc._num(args[0])) if not args.is_empty() else 0
		"Boolean":
			return FlashAbc._truthy(args[0]) if not args.is_empty() else false
		"isNaN":
			return is_nan(FlashAbc._num(args[0])) if not args.is_empty() else true
	return null


## Methods of host objects returned by abc_global / property access (Math, applicationDomain).
func abc_call_object(obj: Dictionary, n: String, args: Array):
	if obj.get("__host_object__") == "appdomain":
		var cname := str(args[0]) if not args.is_empty() else ""
		match n:
			"getDefinition":
				return {"__class__": cname}
			"hasDefinition":
				return abc_has_global(cname)
	if obj.get("__host_object__") == "Math":
		var x := FlashAbc._num(args[0]) if args.size() > 0 else 0.0
		var y := FlashAbc._num(args[1]) if args.size() > 1 else 0.0
		match n:
			"random": return randf()
			"floor": return floorf(x)
			"ceil": return ceilf(x)
			"round": return floorf(x + 0.5)
			"abs": return absf(x)
			"max": return maxf(x, y)
			"min": return minf(x, y)
			"sqrt": return sqrt(x)
			"sin": return sin(x)
			"cos": return cos(x)
			"pow": return pow(x, y)
	return null


func abc_construct(n: String, args: Array):
	match n:
		"Array":
			return args
		"Object", "Dictionary", "flash.utils.Dictionary":
			return {}
	var id := _class_id(n)
	if id < 0:
		if not FlashAbc.quiet:
			push_warning("SWF mod: cannot construct %s" % n)
		return null
	return create_class_instance(id)


## `new X()` for a library class: display symbols are instantiated, sounds become FlashSound.
func create_class_instance(id: int):
	match library.get_char(id).get("t", ""):
		"sprite":
			return instantiate(id)
		"sound":
			return FlashSound.from_library(library, id)
	return Flash.create_char(library, id)
