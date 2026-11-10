class_name FlashLibrary
extends RefCounted
## A converted SWF (see tools/swfconv): symbol table, timelines, and lazily-loaded artwork.
##
## The base game is one library; every converted mod is another. Character ids are local to a library.

var path: String                 # folder containing library.json
var scale: float = 2.0           # bake scale of the shape images
var chars: Dictionary = {}       # str(id) -> entry
var classes: Dictionary = {}     # fully qualified AS3 class name -> id
var root: Dictionary = {}        # main timeline
var document_class: String = ""
var width: float = 700.0
var height: float = 600.0
var fps: float = 30.0
## Set for libraries converted from SWF mods at runtime (see FlashSwfMod): their symbols never map to the game's
## GDScript classes, and their ActionScript runs through `mod`.
var is_mod := false
var mod: Object = null
## Shape image files: "png" (the game's own, imported by Godot; older mod conversions) or "webp" (mods converted
## since FlashSwfMod.CONVERTER_VERSION 4). `edges_fixed`: the transparent edges are filled in already.
var image_format := "png"
var edges_fixed := false
var _cutouts: Dictionary = {}    # char id -> has_cutout result
var drawn_fills := false         # use_drawn_fills has run
var _drawn_imgs: Dictionary = {} # images whose drawn file shape_path picks then

var _textures: Dictionary = {}
var _decoded: Dictionary = {}    # img -> Image, ready for get_texture (decode_all)
var _all_decoded := false        # decode_all has run: it is for a mod's first use

## Morph shapes have one image per ratio (~15k in the base game, several GB of VRAM in total), so their textures
## are streamed: loaded on worker threads on first use and kept in an LRU cache of at most morph_cache_bytes.
static var morph_cache_bytes: int = 1024 * 1048576
static var _streaming: Array[FlashLibrary] = []   # libraries with loads in flight
var _lru: Dictionary = {}        # img -> bytes, least recently used first (insertion order)
var _lru_bytes := 0
var _pending: Dictionary = {}    # img -> Array of FlashShape waiting for it
## The headless dummy renderer cannot create textures off the main thread.
static var _threaded: bool = DisplayServer.get_name() != "headless"
var _hit_masks: PackedByteArray = PackedByteArray()
var _hit_masks_loaded := false


static func load_from(dir: String) -> FlashLibrary:
	var f := FileAccess.open(dir.path_join("library.json"), FileAccess.READ)
	if f == null:
		push_error("FlashLibrary: cannot open %s" % dir)
		return null
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		push_error("FlashLibrary: bad json in %s" % dir)
		return null
	var lib := FlashLibrary.new()
	lib.path = dir
	lib.scale = float(data.get("scale", 2))
	lib.chars = data["chars"]
	lib.classes = data.get("classes", {})
	lib.root = data.get("root", {})
	lib.document_class = data.get("documentClass", "")
	lib.width = data.get("width", 700.0)
	lib.height = data.get("height", 600.0)
	lib.fps = data.get("fps", 30.0)
	lib.image_format = str(data.get("imageFormat", "png"))
	lib.edges_fixed = bool(data.get("edgesFixed", false))
	return lib


## The file of a shape image.
func shape_path(img: String) -> String:
	if drawn_fills and _drawn_imgs.has(img):
		img += FlashSwfMod.DRAWN_SUFFIX
	return path.path_join("shapes/%s.%s" % [img, image_format])


func get_char(id: int) -> Dictionary:
	return chars.get(str(id), {})


func class_id(cls: String) -> int:
	return int(classes.get(cls, -1))


## True if the symbol's timeline (or a symbol it places) puts ERASE / ALPHA pieces on any frame.
func has_cutout(id: int) -> bool:
	if _cutouts.has(id):
		return _cutouts[id]
	_cutouts[id] = false   # cycles
	var found := false
	for p in get_char(id).get("places", []):
		if p.get("bl") == "erase" or p.get("bl") == "alpha" or has_cutout(int(p.get("c", -1))):
			found = true
			break
	_cutouts[id] = found
	return found


func get_texture(img: String) -> Texture2D:
	_used[img] = true
	var t: Texture2D = _textures.get(img)
	if t != null:
		_touch(img)
		return t
	var p := shape_path(img)
	if p.begins_with("res://"):
		Flash.prof_count("#texture loads (blocking)")
		Flash.hitch_note("blocking texture load")
		t = load(p)   # waits for an in-flight background load of the same file
	elif _jobs.has(img):
		Flash.hitch_note("blocking texture load")
		t = _finish_job(img)   # waits for its worker
		return t
	else:
		# Mods converted at runtime are plain image files.
		var image: Image = _decoded.get(img)
		if image != null:
			_decoded.erase(img)
		else:
			image = _decode(p, not edges_fixed)
		if image != null:
			t = ImageTexture.create_from_image(image)
	_cache(img, t)
	return t


static func _decode(p: String, fix_edges: bool) -> Image:
	var image := Image.load_from_file(p)
	if image != null:
		if fix_edges:
			# what Godot's importer does for the game's own art: transparent pixels take their neighbours' colour,
			# so filtering does not draw dark seams where two mod pieces meet (newer conversions have it done)
			image.fix_alpha_edges()
		image.generate_mipmaps()
	return image


## Decodes a mod's images on worker threads, all at once: one by one on the main thread, a mod's first use took up
## to 0.4 s. get_texture takes them from here; forget_decoded() drops those nothing asked for. Not the morph frames:
## a shape needs one of them, a mod can have hundreds.
func decode_all() -> void:
	var dir := path.path_join("shapes")
	if dir.begins_with("res://") or _all_decoded:
		return
	_all_decoded = true
	var ext := "." + image_format
	# image names, not files: shape_path picks the drawn file of a colour fill (use_drawn_fills)
	var names: Array = Array(DirAccess.get_files_at(dir)).filter(func(f: String):
		return f.ends_with(ext) and not f.begins_with("m") and not f.get_basename().ends_with(FlashSwfMod.DRAWN_SUFFIX) \
			and _textures.get(f.get_basename()) == null).map(func(f: String): return f.get_basename())
	_decode_into(names)


## Decodes the named images on worker threads into _decoded (for get_texture).
func _decode_into(names: Array) -> void:
	if names.is_empty():
		return
	var images: Array = []
	images.resize(names.size())
	var fix := not edges_fixed
	var id := WorkerThreadPool.add_group_task(func(i: int): images[i] = _decode(shape_path(names[i]), fix),
		names.size(), -1, true)
	WorkerThreadPool.wait_for_group_task_completion(id)
	for i in names.size():
		if images[i] != null:
			_decoded[names[i]] = images[i]


func forget_decoded() -> void:
	_decoded.clear()


## Mods only: the colour fills are drawn as the mod drew them, not grown (FlashSwfMod.COSTUME_FILL_GROW). Hair mods
## switch when they are registered (CustomElementLoader.parseMod): grown, the thin tips of the fills poke out past the
## hair's outline. The drawn images have the grown ones' size and position, so only the pictures change: the shapes
## already made (under `tree` or in the scene) are given theirs now, the others load them when they are made.
func use_drawn_fills(tree: Node = null) -> void:
	if drawn_fills:
		return
	var stills: Array = []
	for k in chars:
		var c = chars[k]
		if not c is Dictionary:
			continue
		if c.get("drawn", false) and c.has("img"):
			_drawn_imgs[c["img"]] = true
			stills.append(c["img"])
		elif c.get("t") == "morph":
			for r in c["ratios"].values():
				if r is Dictionary and r.get("drawn", false):
					_drawn_imgs[r["img"]] = true
	if _drawn_imgs.is_empty():
		return
	drawn_fills = true
	for img in _drawn_imgs:   # loaded or decoded from the grown files
		_textures.erase(img)
		_decoded.erase(img)
		_images.erase(img)
		if _lru.has(img):
			_lru_bytes -= _lru[img]
			_lru.erase(img)
	_decode_into(stills)
	var done := {}
	for root in [tree, Flash.get_tree().current_scene if Flash.get_tree() else null]:
		if root != null:
			_redraw_shapes(root, done)
	for img in stills:
		_decoded.erase(img)


func _redraw_shapes(n: Node, done: Dictionary) -> void:
	if n is FlashShape and n._library == self and not done.has(n):
		done[n] = true
		n._picture_changed()
	for c in n.get_children():
		_redraw_shapes(c, done)


## Non-blocking get for morph frames: returns the texture if it is cached, otherwise starts loading it on a worker
## thread and returns null; 'waiter' (if any) gets _texture_ready(img, texture) once it has loaded.
func request_texture(img: String, waiter: Object = null) -> Texture2D:
	if not _warming:
		_used[img] = true
	var t: Texture2D = _textures.get(img)
	if t != null:
		_touch(img)
		return t
	var p := shape_path(img)
	if not _threaded or _decoded.has(img):   # decoded already (decode_all): only the texture is left to make
		return get_texture(img)
	if not _pending.has(img):
		if not p.begins_with("res://"):
			# a mod's image: decoded on a worker thread (port: decoding them here took 3-4 ms per morph frame)
			var holder := [null]
			var fix := not edges_fixed
			_jobs[img] = [WorkerThreadPool.add_task(func(): holder[0] = _decode(p, fix)), holder]
		elif ResourceLoader.load_threaded_request(p, "Texture2D") != OK:
			return get_texture(img)
		Flash.prof_count("#texture loads (background)")
		_pending[img] = []
		if _streaming.is_empty() or not _streaming.has(self):
			_streaming.append(self)
	if waiter != null and not _pending[img].has(waiter):
		_pending[img].append(waiter)
	return null


func is_texture_cached(img: String) -> bool:
	return _textures.get(img) != null


## Waits for every background load to finish (before quitting: worker threads must not outlive the renderer).
static func drain_streaming() -> void:
	for lib in _streaming:
		for img in lib._pending.keys():
			if lib._jobs.has(img):
				WorkerThreadPool.wait_for_task_completion(lib._jobs[img][0])
			else:
				ResourceLoader.load_threaded_get(lib.shape_path(img))
		lib._jobs.clear()
		lib._pending.clear()
	_streaming.clear()


## Called once per tick by the runtime: hands finished background loads to their waiting shapes.
static func poll_streaming() -> void:
	var i := 0
	while i < _streaming.size():
		var lib := _streaming[i]
		for img in lib._pending.keys():
			lib._poll_one(img)
		if lib._pending.is_empty():
			_streaming.remove_at(i)
		else:
			i += 1


func _poll_one(img: String) -> bool:
	if _jobs.has(img):
		if not WorkerThreadPool.is_task_completed(_jobs[img][0]):
			return false
		_finish_job(img)
		return true
	var p := shape_path(img)
	var st := ResourceLoader.load_threaded_get_status(p)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return false
	var t: Texture2D = ResourceLoader.load_threaded_get(p) if st == ResourceLoader.THREAD_LOAD_LOADED else null
	var waiters: Array = _pending[img]
	_pending.erase(img)
	if t == null:
		t = load(p)
	_cache(img, t)
	for w in waiters:
		if is_instance_valid(w):
			w._texture_ready(img, t)
	return true


## A mod image's worker decode (request_texture): waits for it if it is still running, makes the texture, hands it to
## the shapes waiting for it.
var _jobs: Dictionary = {}   # img -> [WorkerThreadPool task id, [Image]]


func _finish_job(img: String) -> Texture2D:
	var job: Array = _jobs[img]
	_jobs.erase(img)
	WorkerThreadPool.wait_for_task_completion(job[0])
	var image: Image = job[1][0]
	var t: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	_cache(img, t)
	var waiters: Array = _pending.get(img, [])
	_pending.erase(img)
	for w in waiters:
		if is_instance_valid(w):
			w._texture_ready(img, t)
	return t


# ---------------------------------------------------------------- warm-up list (port)

## The textures a session used, saved next to the save files: the next start loads them on worker threads while
## the title screen shows, instead of one by one when the game scene first draws them (50-90 ms ticks after Play).
const WARM_FILE := "texture_warmup.txt"
const WARM_MORPH_BYTES := 256 * 1048576   # morph frames kept in the list: the most recent, up to this size
var _used: Dictionary = {}      # textures the game asked for this session (not the warm-up's own loads)
var _warming := false


func save_warm_list(dir: String) -> void:
	var lines := PackedStringArray()
	for img in _used:
		if not str(img).begins_with("m"):
			lines.append(img)
	var morphs := PackedStringArray()
	var budget := WARM_MORPH_BYTES
	var keys: Array = _lru.keys()
	for i in range(keys.size() - 1, -1, -1):   # most recently used first
		if not _used.has(keys[i]):
			continue
		budget -= int(_lru[keys[i]])
		if budget < 0:
			break
		morphs.append(keys[i])
	lines.append_array(morphs)
	if lines.is_empty():
		return
	var f := FileAccess.open(dir.path_join(WARM_FILE), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))


## Starts background loads of the textures in the warm-up list (only with threaded loading: headless runs load on
## demand). Returns how many were requested.
func warm_up(dir: String) -> int:
	if not _threaded:
		return 0
	var p := dir.path_join(WARM_FILE)
	if not FileAccess.file_exists(p):
		return 0
	var n := 0
	_warming = true
	for img in FileAccess.get_file_as_string(p).split("\n", false):
		if _textures.get(img) == null and ResourceLoader.exists(shape_path(img)):
			request_texture(img)
			n += 1
	_warming = false
	return n


func _cache(img: String, t: Texture2D) -> void:
	_textures[img] = t
	if t == null or not img.begins_with("m"):
		return
	if _lru.has(img):
		_touch(img)
		return
	var bytes := t.get_width() * t.get_height() * 16 / 3   # RGBA8 + mipmaps
	_lru[img] = bytes
	_lru_bytes += bytes
	while _lru_bytes > morph_cache_bytes and _lru.size() > 1:
		var oldest: String
		for k in _lru:
			oldest = k
			break
		_lru_bytes -= _lru[oldest]
		_lru.erase(oldest)
		# shapes still showing it keep their own reference
		_textures.erase(oldest)


func _touch(img: String) -> void:
	var b = _lru.get(img)
	if b != null:
		_lru.erase(img)
		_lru[img] = b


var _images: Dictionary = {}


## CPU copy of a shape image (for software rendering into BitmapData).
func get_image(img: String) -> Image:
	var im: Image = _images.get(img)
	if im == null:
		var p := shape_path(img)
		if p.begins_with("res://"):
			var tex: Texture2D = load(p)
			im = tex.get_image() if tex != null else null
		else:
			im = Image.load_from_file(p)
		if im != null:
			if im.is_compressed():
				im.decompress()
			if im.has_mipmaps():
				im.clear_mipmaps()
			im.convert(Image.FORMAT_RGBA8)
		_images[img] = im
	return im


func file_path(rel: String) -> String:
	return path.path_join(rel)


## Tests p (shape-local, pixels) against the 1-bit 1x coverage mask produced by the converter.
func hit_mask_test(entry: Dictionary, p: Vector2) -> bool:
	if not _hit_masks_loaded:
		_hit_masks_loaded = true
		var f := FileAccess.open(path.path_join("hitmasks.bin"), FileAccess.READ)
		if f != null:
			_hit_masks = f.get_buffer(f.get_length())
	var hm: Array = entry["hm"]
	var x := int(floor(p.x - entry["x"]))
	var y := int(floor(p.y - entry["y"]))
	var w: int = hm[1]
	var h: int = hm[2]
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	var bit := y * w + x
	var byte_i: int = int(hm[0]) + (bit >> 3)
	if byte_i >= _hit_masks.size():
		return false
	return (_hit_masks[byte_i] >> (bit & 7)) & 1 == 1
