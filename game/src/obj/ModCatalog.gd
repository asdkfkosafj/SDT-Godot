class_name ModCatalog
extends RefCounted
## Port extension (not in the original game): mods in Mods/Clothing and Mods/Hair are found automatically and each
## item they register becomes an option in its costume picker (or the hair picker), after the built-in options.
## Items of one mod that go to the same picker form one option (a hairstyle's parts, a gag's front and back); a
## mod's items for several costume pickers are one option too, in one of them (SLOT_ORDER).
## Choosing one applies those items exactly like loading the mod does (CustomElementLoader.parseMod), with the
## package saved as "<path>|<item>+<item>..." so saved characters restore just them. A pack's character preset
## (charData) and dialogue are not applied.
##
## New mods are converted on a worker thread and inspected once (which items, their types and slots); the result is
## cached next to the conversion (catalog.json), so later startups only read small files.
##
## Names: a character code names a costume or hair by its picker name (g.dataName). Codes from the Loader name mod
## items the way MoreClothing listed them, so a name the game does not know is looked up here (find_named): an
## entry answers to its mod's name, its file name, and the name a names.txt in its folder gives it. names.txt lines:
## "<file> = <name>" or "<file> = <name> > <slot>" (the slot's picker shows it instead, e.g. "> earring" for an
## earring made as a hair accessory; "> body": MoreClothing's body slot, the "Body pieces" list in Clothes, where
## several can be on); "#" starts a comment.
const BODY_LIST := "body"
## Mods of body parts only (ThickerThighs, HardBod, breast mods): the "Body mods" list in Her > Body. A body part that
## comes with clothing stays a companion of the clothing's picker entry.
const BODY_MODS_LIST := "bodymods"
## Clothes > Head and neck > Leash: dynamic hair strands hanging from her collar (is_leash). One at a time.
const LEASH_LIST := "leash"

const SCAN_FOLDERS := ["Clothing", "Hair", "Backgrounds"]
const MOD_EXTENSIONS := ["swf", "mod"]   # .mod: a SWF under the Loader's other name for mods
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "gif", "bmp"]
const CATALOG_VERSION := 3   # 2: misspelt mod types normalised (CustomElementLoader.normalModType); 3: leashes
const HAIR_TYPES := [ModTypes.HAIR, ModTypes.DYNAMIC_HAIR]
## A mod with pieces for several costume slots (a vest with its shirt, sleeves and collar) is one option, in the
## first of these slots it has a piece for; its other pieces go on and off with it.
const SLOT_ORDER := ["costumeovertop", "costumetop", "costumebottoms", "costumebra", "costumepanties",
	"costumelegwear", "costumelegwearb", "costumearmwear", "costumefootwear", "costumeheadwear", "haircostume",
	"costumecollar", "costumecuffs", "costumeanklecuffs", "costumegag", "costumeeyewear"]

## Entries: {path, items: Array[int], title, modTypes: Array[String], helper (costume pickers only)}
var entries: Array = []
var hair_entries: Array = []
var bg_entries: Array = []
## Lists extensions add for their mod types (add_picker): mod type -> list key; key -> entries (one per mod, all its
## items of those types). Shown as on / off switches, so several can be on (ExtraMod's face and eye mods stack).
var picker_types: Dictionary = {}
var picker_entries: Dictionary = {}
## List key -> list key (merge_pickers): a mod with items for both lists gets one entry, in the second. Keys:
## add_picker lists, "hair", "bg", or COSTUME (any clothes picker).
var picker_merge: Dictionary = {}
const COSTUME := "*costume"
var _seen: Array = []         # [path, catalog] of every mod looked at, for lists added later
var _queue: Array = []        # paths still to inspect
var _converting: Dictionary = {}  # cache dir -> [path, bytes] (the conversion runs in FlashSwfMod)
## New mods handed to the converter at once (it runs FlashSwfMod.converter_threads of them, her mods first)
var _slots: int = FlashSwfMod.converter_threads + 1
var _waiting: Array = []          # [path, cache dir] of new mods waiting for a free conversion slot
## Main-thread time per tick for reading cached catalogs (the file read and hash of each .swf are most of it)
const TICK_BUDGET_US := 3000
var _busy := false
var _names: Dictionary = {}   # lower-case file path -> [name, slot] from names.txt
var _scanned := false         # every mod has been looked at
var _wanted: Array = []       # [picker, name, callback] asked for before the scan finished (find_named)
var _due := 0                 # find_named answers found but not called yet (they run deferred)
var _known: Dictionary = {}   # lower-case paths of the files scanned, so rescan() only adds new ones
var _total := 0               # .swf files queued by the current scan (the loading notice's count)
var _notice: Node = null      # the "Loading mods" notice (mod_load_notice.gd) while a scan runs


func start() -> void:
	picker_entries[BODY_LIST] = []
	picker_entries[BODY_MODS_LIST] = []
	picker_entries[LEASH_LIST] = []
	picker_types[ModTypes.LEASH] = LEASH_LIST
	for sub in SCAN_FOLDERS:
		_scan(Flash.mods_dir(sub))
	Flash.add_enter_frame(self, _tick)
	_show_notice()
	# MoreClothing's extra body slot (Loader codes): the mod is put on; saving writes it as the port's own mod field
	CharCode.add_field("moreclothingbody", "port", _no_field, _load_body_slot)


func _no_field():
	return null


func _load_body_slot(v: String, _load) -> void:
	if v != "" and v != "none":
		find_named(null, v, _apply_once)


func _apply_once(e: Dictionary) -> void:
	if not is_applied(e):
		apply(e)


func _scan(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	if d.file_exists("names.txt"):
		_read_names(dir)
	for f in d.get_files():
		var ext := f.get_extension().to_lower()
		if _known.has(dir.path_join(f).to_lower()):
			continue
		_known[dir.path_join(f).to_lower()] = true
		if ext in MOD_EXTENSIONS:
			_queue.append(dir.path_join(f))
			_total += 1
		elif ext in IMAGE_EXTENSIONS and dir.begins_with(Flash.mods_dir("Backgrounds")):
			# background images: shown like the vanilla "Import background"
			var e := {"path": _relative(dir.path_join(f)), "image": true, "items": [], "modTypes": [],
				"title": f.get_basename().replace("_", " ").strip_edges(), "picker": "bg"}
			entries.append(e)
			bg_entries.append(e)
		elif ext in IMAGE_EXTENSIONS and dir.begins_with(Flash.mods_dir("Hair")):
			# image hairs: put on like the vanilla "Import hair" (CustomElementLoader.tryToLoadHairFile)
			var named: Array = _names.get(dir.path_join(f).to_lower(), ["", ""])
			var e := {"path": _relative(dir.path_join(f)), "image": true, "items": [], "modTypes": [],
				"title": named[0] if named[0] != "" else f.get_basename().replace("_", " ").strip_edges(), "picker": "hair",
				"names": [g.dataName(f.get_basename())] + ([g.dataName(named[0])] if named[0] != "" else []),
				"named": named[0] != ""}
			entries.append(e)
			hair_entries.append(e)
	for sub in d.get_directories():
		_scan(dir.path_join(sub))


## Each tick: mods with a cached catalog are read for up to TICK_BUDGET_US (a small file each, so a collection that was
## seen before is done in a few frames); new mods are converted on worker threads (two at a time) and then inspected
## on the main thread one per tick (their frame scripts must run to know what they contain).
func _tick() -> void:
	for dir in _converting.keys():
		if not FlashSwfMod.converting(dir):
			var job: Array = _converting[dir]
			_converting.erase(dir)
			_inspect(job[0], job[1])
			return
	while not _waiting.is_empty() and _converting.size() < _slots:
		_convert(_waiting.pop_front())
	var t0 := Time.get_ticks_usec()
	while not _queue.is_empty() and Time.get_ticks_usec() - t0 < TICK_BUDGET_US:
		if not _step(_queue.pop_front()):
			return
	if _queue.is_empty() and _waiting.is_empty():
		if _converting.is_empty():
			Flash.remove_enter_frame(self, _tick)
			_sync_loaded()
			_scanned = true
			_total = 0
			for w in _wanted:
				find_named(w[0], w[1], w[2])
			_wanted.clear()


## Looks at one queued mod; false if it took a main-thread inspection (that tick's budget is spent).
func _step(path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return true
	var dir := FlashSwfMod.cache_root.path_join(FlashSwfMod._sha256(bytes))
	var cat := _read_catalog(dir)
	if not cat.is_empty():
		_add(path, cat)
		return true
	if FlashSwfMod.is_converted(dir):
		_inspect(path, bytes)
		return false
	if _converting.size() < _slots:
		_convert([path, dir], bytes)
	else:
		_waiting.append([path, dir])   # not its bytes: a large new collection would hold them all in memory
	return true


func _convert(job: Array, bytes := PackedByteArray()) -> void:
	if bytes.is_empty():
		bytes = FileAccess.get_file_as_bytes(job[0])
	if bytes.is_empty():
		return
	if not FlashSwfMod.async_conversion:
		_inspect(job[0], bytes)   # converts it (headless runs: tests repeat exactly)
		return
	_converting[FlashSwfMod.convert_async(bytes, job[0])] = [job[0], bytes]


## The game quits: mods still converting on worker threads stop and are waited for (a worker thread still running
## GDScript while the engine shuts down crashes it).
func shutdown() -> void:
	FlashSwfMod.stop_all()
	_converting.clear()
	_waiting.clear()
	_queue.clear()


## The scan's progress, for the loading notice: {finished, done, total, converting: file names}.
func progress() -> Dictionary:
	var names: Array = FlashSwfMod.converting_names()
	return {"finished": _scanned, "done": _total - _queue.size() - _waiting.size() - _converting.size(), "total": _total,
		"converting": names}


## Puts up the "Loading mods" notice for the scan just started (it shows itself only if the scan takes a while).
func _show_notice() -> void:
	if _total == 0 or (_notice != null and is_instance_valid(_notice)):
		return
	_notice = preload("res://src/menu/mod_load_notice.gd").new()
	_notice.name = "ModLoadNotice"   # named: an auto-generated name would shift the numbering of the game's nodes
	_notice.catalog = self
	Flash.add_child(_notice)


static func _read_catalog(dir: String) -> Dictionary:
	var p := dir.path_join("catalog.json")
	if not FileAccess.file_exists(p):
		return {}
	var c = JSON.parse_string(FileAccess.get_file_as_string(p))
	if c == null or int(c.get("version", 0)) != CATALOG_VERSION:
		return {}
	return c


func _inspect(path: String, bytes: PackedByteArray) -> void:
	var mod := FlashSwfMod.load_mod(bytes, path)
	if mod == null:
		return
	var root = mod.instantiate_root()
	var cat := {"version": CATALOG_VERSION, "items": []}
	if root != null and root.get("MOD_VERSION") != null:
		cat["modName"] = str(root.get("modName")) if root.get("modName") else ""
		cat["modCreator"] = str(root.get("modCreator")) if root.get("modCreator") else ""
		var mods = root.get("mods")
		var leash: bool = mods is Array and mods.any(func(m): return is_leash(m))
		for i in (mods.size() if mods is Array else 0):
			var m = mods[i]
			if m is FlashDisplayObject:
				cat["items"].append({"item": i, "name": m.flash_name,
					"modType": ModTypes.LEASH if leash and str(m.get("modType")) == ModTypes.DYNAMIC_HAIR \
						else CustomElementLoader.normalModType(str(m.get("modType"))),
					"targetElement": str(m.get("targetElement")) if m.get("targetElement") else ""})
	if root != null:
		root.queue_free()
	var f := FileAccess.open(mod.library.path.path_join("catalog.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(cat))
		f.close()
	_add(path, cat)


## Adds a list for mods with items of `mod_types` (see picker_types), including mods already scanned. An entry
## "<modType>/<item name>" takes only the items of that type with that name (it wins over the type alone).
func add_picker(key: String, mod_types: Array) -> void:
	for t in mod_types:
		picker_types[t] = key
	picker_entries[key] = []
	if picker_merge.values().has(key) or picker_merge.has(key):
		_rebuild_all()
		return
	for s in _seen:
		_add(s[0], s[1], key)


## A mod with items for one of the `from` lists and for `into` gets one entry (one switch) in `into`, with those
## items too (ExtraMod: a whole-body mod's head parts, hair and clothes go on and off with its body). Mods without
## `into` items stay where they were.
func merge_pickers(from: Array, into: String) -> void:
	for f in from:
		picker_merge[f] = into
	_rebuild_all()


func remove_picker(key: String) -> void:
	for t in picker_types.keys():
		if picker_types[t] == key:
			picker_types.erase(t)
	var gone: Array = picker_entries.get(key, [])
	entries = entries.filter(func(e): return not e in gone)
	picker_entries.erase(key)
	var merged := false
	for f in picker_merge.keys():
		if f == key or picker_merge[f] == key:
			picker_merge.erase(f)
			merged = true
	if merged:
		_rebuild_all()


## Builds every list again from the mods scanned so far (the merge rules changed), keeping each picker's current
## option (the hair, the background and the clothes pickers point at their entries by index).
func _rebuild_all() -> void:
	if _seen.is_empty():
		return
	var menu = g.inGameMenu
	var helpers := {}
	for e in entries:
		if e.has("helper"):
			helpers[e["helper"]] = true
	var cur_hair := _at(hair_entries, menu.hairModIndex) if menu != null else {}
	var cur_bg := _at(bg_entries, menu.bgModIndex) if menu != null else {}
	var cur_helper := {}
	for h in helpers:
		cur_helper[h] = _at(h.modEntries, h.modEntryIndex)
		h.modEntries.clear()
	entries = []
	hair_entries.clear()
	bg_entries.clear()
	for k in picker_entries:
		picker_entries[k] = []
	for s in _seen:
		_add(s[0], s[1], null, false)
	if menu != null:
		menu.hairModIndex = _refind(hair_entries, cur_hair)
		menu.bgModIndex = _refind(bg_entries, cur_bg)
	for h in cur_helper:
		h.modEntryIndex = _refind(h.modEntries, cur_helper[h])


static func _at(list: Array, i: int) -> Dictionary:
	return list[i] if i >= 0 and i < list.size() else {}


## The index of the entry for the same mod and items as `old` (-1: gone, e.g. merged into another list).
static func _refind(list: Array, old: Dictionary) -> int:
	if old.is_empty():
		return -1
	for i in list.size():
		if list[i]["path"] == old["path"] and list[i]["items"] == old["items"]:
			return i
	return -1


## Whether the entry's mod is on (some of its items are placed).
func is_applied(e: Dictionary) -> bool:
	for lm in g.customElementLoader.instancedModElements:
		if lm.sourcePackage != null and _same_path(lm.sourcePackage.filePath.get_slice("|", 0), e["path"]):
			return true
	return false


static func _same_path(a: String, b: String) -> bool:
	return a == b or Flash.resolve_content_path(a) == Flash.resolve_content_path(b)


## Takes off one entry's mod (its own items only, other mods of the same types stay).
func remove_entry(e: Dictionary) -> void:
	_kill_from(e["path"], [])
	g.inGameMenu.charStoring.populateMods()


## Adds a mod's items to the pickers they belong to (only_key: just to that extension list).
func _add(path: String, cat: Dictionary, only_key = null, remember := true) -> void:
	var first_new := entries.size()
	_add_entries(path, cat, only_key, remember)
	if not _wanted.is_empty() and entries.size() > first_new:
		_answer_wanted(first_new)


## A character waiting for a mod by name (find_named) gets it as soon as the scan has added it, not after the whole
## collection: the first entry that answers, as after a full scan (entries are added in the same order).
func _answer_wanted(first_new: int) -> void:
	for w in _wanted.duplicate():
		var n := g.dataName(w[1])
		for i in range(first_new, entries.size()):
			var e: Dictionary = entries[i]
			if n in e.get("names", []) and (w[0] == null or is_same(e.get("helper", e.get("picker")), w[0])):
				_wanted.erase(w)
				_due += 1
				_answer.call_deferred(w[2], e)
				break


func _add_entries(path: String, cat: Dictionary, only_key = null, remember := true) -> void:
	if only_key == null and remember:
		_seen.append([path, cat])
	var rel := _relative(path)
	var title: String = cat.get("modName", "")
	if title == "":
		title = path.get_file().get_basename().replace("_", " ").strip_edges()
	var named: Array = _names.get(path.to_lower(), ["", ""])
	var names := [g.dataName(title), g.dataName(path.get_file().get_basename())]
	var mod_name := title
	if named[0] != "":
		names.append(g.dataName(named[0]))
		title = named[0]   # the pickers show the names.txt name
	var moved = g.characterControl.get(named[1] + "Control") if named[1] != "" else null
	# one option per picker: the mod's items for that picker are applied together
	var groups: Array = []   # [picker key, entry]
	# items no picker shows (a set's body part: ThickerThighs' socks come with the thicker thighs they fit) go on and
	# off with the mod's picker entries, as loading the whole mod in the original did
	var companions: Array = []
	var companion_types: Array = []
	var items: Array = cat.get("items", [])
	var body_only := items.any(func(it): return it["modType"] == ModTypes.BODY) \
		and not items.any(func(it): return _picker_key(it) != null)
	for it in items:
		if _picker_key(it) == null and it["modType"] != ModTypes.DIALOGUE \
				and not (body_only and it["modType"] == ModTypes.BODY):
			companions.append(int(it["item"]))
			if not companion_types.has(it["modType"]):
				companion_types.append(it["modType"])
	for it in items:
		var key = _picker_key(it)
		if key == null and body_only and it["modType"] == ModTypes.BODY:
			key = BODY_MODS_LIST
		if key == null:
			continue
		if moved is CharacterElementHelper and key is CharacterElementHelper:
			key = moved
		elif named[1] == BODY_LIST and not key is String:
			key = BODY_LIST
		var e := {}
		for gr in groups:
			if is_same(gr[0], key):
				e = gr[1]
		if e.is_empty():
			e = {"path": rel, "items": [], "modTypes": [], "title": title, "modName": mod_name, "companions": companions,
				"companionTypes": companion_types, "names": names, "named": named[0] != ""}
			groups.append([key, e])
		e["items"].append(int(it["item"]))
		if not e["modTypes"].has(it["modType"]):
			e["modTypes"].append(it["modType"])
	groups = _merge_costume_groups(_merge_pickers(groups))
	for gr in groups:
		var key = gr[0]
		var e: Dictionary = gr[1]
		if only_key != null and not is_same(key, only_key):
			continue
		entries.append(e)
		var list: Array
		if key is String and picker_entries.has(key):
			e["picker"] = key
			list = picker_entries[key]
		elif key is String:
			e["picker"] = key
			list = hair_entries if key == "hair" else bg_entries
		else:
			e["helper"] = key
			list = key.modEntries
		list.append(e)
		_dedupe(list, e)


## picker_merge: a mod's entry for one list joins its entry for another.
func _merge_pickers(groups: Array) -> Array:
	if picker_merge.is_empty():
		return groups
	var by_key := {}
	for gr in groups:
		if gr[0] is String:
			by_key[gr[0]] = gr
	for gr in groups.duplicate():
		var into = picker_merge.get(gr[0] if gr[0] is String else COSTUME)
		if into == null or not by_key.has(into):
			continue
		var e: Dictionary = by_key[into][1]
		e["items"].append_array(gr[1]["items"])
		for t in gr[1]["modTypes"]:
			if not e["modTypes"].has(t):
				e["modTypes"].append(t)
		groups.erase(gr)
	return groups


## A mod's costume options (pickers that are element helpers) become one, in the first slot of SLOT_ORDER; the
## others' items are its companions.
static func _merge_costume_groups(groups: Array) -> Array:
	var costume := groups.filter(func(gr): return not gr[0] is String)
	if costume.size() < 2:
		return groups
	var main = costume[0]
	for gr in costume:
		if _slot_rank(gr[1]) < _slot_rank(main[1]):
			main = gr
	var e: Dictionary = main[1]
	e["companions"] = e["companions"].duplicate()
	e["companionTypes"] = e["companionTypes"].duplicate()
	for gr in costume:
		if gr == main:
			continue
		e["companions"].append_array(gr[1]["items"])
		for t in gr[1]["modTypes"]:
			if not e["companionTypes"].has(t):
				e["companionTypes"].append(t)
	return groups.filter(func(gr): return gr == main or gr[0] is String)


static func _slot_rank(e: Dictionary) -> int:
	var best := SLOT_ORDER.size()
	for t in e["modTypes"]:
		var i := SLOT_ORDER.find(str(t).to_lower())
		if i >= 0 and i < best:
			best = i
	return best


## Mods of a set often share their name (ThickerThighs' variants are all "Thicker Thighs"): in one list, those show
## their file names instead.
static func _dedupe(list: Array, e: Dictionary) -> void:
	var name: String = e.get("modName", e["title"])
	for o in list:
		if o != e and o.get("modName", o["title"]) == name:   # the mod's own name, not a title changed already
			for x in [o, e]:
				if not x.get("named", false):   # a names.txt name stays
					x["title"] = _file_title(x["path"])


## Reads a folder's names.txt (see the top of this file).
func _read_names(dir: String) -> void:
	for line in FileAccess.get_file_as_string(dir.path_join("names.txt")).split("\n"):
		line = line.get_slice("#", 0).strip_edges()
		if not "=" in line:
			continue
		var file := line.get_slice("=", 0).strip_edges()
		var rest := line.substr(line.find("=") + 1)
		var slot := rest.get_slice(">", 1).strip_edges() if ">" in rest else ""
		_names[dir.path_join(file).to_lower()] = [rest.get_slice(">", 0).strip_edges(), slot]


## Calls found(entry) with the installed mod that answers to `name` (see the top of this file) in `picker` (a
## costume element helper, "hair", or null for any), now or once every mod has been looked at; nothing if none does.
## A newer request for the same picker replaces one still waiting.
func find_named(picker, name: String, found: Callable) -> void:
	if not _scanned:
		_wanted = _wanted.filter(func(w): return picker == null or not is_same(w[0], picker))
		_wanted.append([picker, name, found])
		return
	var n := g.dataName(name)
	for e in entries:
		if n in e.get("names", []) and (picker == null or is_same(e.get("helper", e.get("picker")), picker)):
			# after the code has finished loading, as the original's mods arrived (loading its hair clears hair
			# costumes, e.g. an earring made as one)
			_due += 1
			_answer.call_deferred(found, e)
			return


func _answer(found: Callable, e: Dictionary) -> void:
	found.call(e)
	_due -= 1


## Whether mods a character code named are still to be put on (find_named): her code lacks them until then.
func is_pending() -> bool:
	return _due > 0 or not _wanted.is_empty()


## Looks at the mods folders again (files added since, e.g. by LoaderImport): new mods are added, names.txt is read
## again and installed mods take its new names.
func rescan() -> void:
	_scanned = false
	for sub in SCAN_FOLDERS:
		_scan(Flash.mods_dir(sub))
	for e in entries:
		var named: Array = _names.get(Flash.resolve_content_path(e["path"]).to_lower(), ["", ""])
		if named[0] != "" and not g.dataName(named[0]) in e.get("names", []):
			e["names"] = e.get("names", []) + [g.dataName(named[0])]
			e["title"] = named[0]
			e["named"] = true
	Flash.remove_enter_frame(self, _tick)
	Flash.add_enter_frame(self, _tick)
	_show_notice()


## Whether an installed mod answers to `name` in `picker` (see find_named), as far as the scan has got.
func has_named(picker, name: String) -> bool:
	var n := g.dataName(name)
	for e in entries:
		if n in e.get("names", []) and (picker == null or is_same(e.get("helper", e.get("picker")), picker)):
			return true
	return false


## Drops a request still waiting for the picker (its slot was set to something else); null: every request (another
## character is loading).
func forget_named(picker) -> void:
	_wanted = _wanted.filter(func(w): return picker != null and not is_same(w[0], picker))


## A dynamic hair item hanging from her collar. Its own mod type, as in dynamicHairExtender: it is worn with her hair,
## and a new leash replaces only the leash. The mod's other strands (the end in his hand) go with it.
static func is_leash(m) -> bool:
	return str(m.get("modType")) == ModTypes.DYNAMIC_HAIR and str(m.get("anchorContainer")).begins_with("her.collarContainer")


static func _file_title(path: String) -> String:
	return path.get_file().get_basename().replace("_", " ").strip_edges()


## The picker an item goes to: a costume element helper, "hair", or null (not selectable, e.g. Loader-only types).
func _picker_key(it: Dictionary):
	var named = picker_types.get("%s/%s" % [it["modType"], it.get("name", "")])
	if named != null:
		return named
	if picker_types.has(it["modType"]):
		return picker_types[it["modType"]]
	if it["modType"] in HAIR_TYPES:
		return "hair"
	if it["modType"] == ModTypes.BACKGROUND:
		return "bg"
	var key: String = it["targetElement"] if it["targetElement"] != "" else it["modType"]
	if it["modType"] == ModTypes.HAIR_COSTUME:
		return g.characterControl.headwearControl
	var helper = g.customElementLoader.modTargetHelpers.get(key)
	if helper != null and helper.hasCostumeHelper:
		return helper.characterElementHelper
	return null


static func _relative(path: String) -> String:
	var root := Flash.content_root().path_join("")
	return path.substr(root.length()) if path.begins_with(root) else path


# ---------------------------------------------------------------- applying

## Applies one catalog entry like loading its mod would (only that item).
func apply(e: Dictionary) -> void:
	var cel := g.customElementLoader
	var full := Flash.resolve_content_path(e["path"])
	var bytes := FileAccess.get_file_as_bytes(full)
	var mod := FlashSwfMod.load_mod(bytes, full) if not bytes.is_empty() else null
	if mod == null:
		push_warning("Mod not found: %s" % e["path"])
		return
	var root = mod.instantiate_root()
	var mods = root.get("mods") if root != null else null
	if not mods is Array:
		return
	mod.run_initl(root)
	var pkg := LoadedModPackage.new("swfMod")
	var items := _applied_items(e)
	pkg.setFilePath("%s|%s" % [e["path"], "+".join(PackedStringArray(items.map(func(i): return str(i))))])
	pkg.filePathOkay = true
	pkg.setModDetails(root.get("modName"), root.get("modCreator"))
	cel.loadedModPackages.append(pkg)
	cel.loadingModPackage = pkg
	cel.blockSwfCharData = true
	for i in items:
		if i < mods.size():
			cel.parseMod(mods[i])
	cel.blockSwfCharData = false
	cel.loadingModPackage = null
	# The mod stays loaded as with the Loader (its scripts run), until its package goes: then the root and the items
	# not placed are freed.
	pkg.modRoot = root
	pkg.modItems = mods.duplicate()
	cel.updateInstancedModElements()
	g.inGameMenu.charStoring.populateMods()


## Frees what an entry's items take the place of, as the hair and clothes pickers do before they put a mod on: her
## hairstyle and the hair mods for a hairstyle (static hair: dynamic hair alone may be cables or wings),
## a clothes slot's own piece and mods for clothes items. For entries that hold such items outside those pickers
## (merge_pickers: ExtraMod's whole-body mods).
func clear_slots_for(e: Dictionary) -> void:
	var cel := g.customElementLoader
	var cc := g.characterControl
	var types: Array = e["modTypes"]
	if types.has(ModTypes.HAIR):
		if cc.customHairLoaded:
			cel.clearCustomHair(false)
			cc.customHairLoaded = false
		cc.clearHair()
		cel.clearModTypes(HAIR_TYPES)
		if g.inGameMenu != null:
			g.inGameMenu.hairModIndex = -1
	for t in types:
		var h = _picker_key({"modType": t, "targetElement": "", "name": ""})
		if not h is CharacterElementHelper:
			continue
		h.clearWholeTint()
		if h.associatedModType:
			cel.clearModTypes([h.associatedModType])
		if h.modEntryIndex >= 0 and h.modEntryIndex < h.modEntries.size() and h.modEntries[h.modEntryIndex] != e:
			remove(h.modEntries[h.modEntryIndex])
		h.modEntryIndex = -1
		h.findName("None")


## An entry's items with its companions, in the mod's order.
static func _applied_items(e: Dictionary) -> Array:
	var items: Array = e["items"] + e.get("companions", [])
	items.sort()
	return items


## Removes an applied entry (its mod type's instanced elements, and its own companions).
func remove(e: Dictionary) -> void:
	var cel := g.customElementLoader
	cel.clearModTypes(e["modTypes"])
	var types: Array = e.get("companionTypes", [])
	if types.is_empty():
		return
	for o in entries:   # another entry of the same mod still on (its top and its skirt): the companions stay
		if o != e and o["path"] == e["path"]:
			for lm in cel.instancedModElements:
				if o["modTypes"].has(lm.modType) and lm.sourcePackage != null 						and _same_path(lm.sourcePackage.filePath.get_slice("|", 0), e["path"]):
					return
	_kill_from(e["path"], types)


## Takes off the placed items of `types` (all types if empty) that came from the mod at `path`, then puts back what
## those mods replaced (as clearing mods does: her own skin parts after a body mod).
func _kill_from(path: String, types: Array) -> void:
	var cel := g.customElementLoader
	var resets: Dictionary = {}
	var i := 0
	while i < cel.instancedModElements.size():
		var lm: LoadedMod = cel.instancedModElements[i]
		if (types.is_empty() or types.has(lm.modType)) and lm.sourcePackage != null 				and _same_path(lm.sourcePackage.filePath.get_slice("|", 0), path):
			resets[cel.getResetFunction(lm.modType)] = true
			lm.kill()
			cel.instancedModElements.remove_at(i)
			continue
		i += 1
	cel.checkLoadedModPackages()
	cel.updateInstancedModElements()
	for fn in resets:
		fn.call()


## Marks items restored before the scan finished (saved character loaded at startup) as their pickers' options.
func _sync_loaded() -> void:
	var cel := g.customElementLoader
	for pkg in cel.loadedModPackages:
		if not pkg.items.is_empty():
			mark_selected(pkg.filePath.get_slice("|", 0), pkg.items)
	if cel.customBGLoaded and cel.proxyBGPackage and cel.proxyBGPackage.hasFilePath():
		mark_selected(cel.proxyBGPackage.path, [])
	if cel.customHairLoaded and cel.proxyHairPackage and cel.proxyHairPackage.hasFilePath():
		mark_selected(cel.proxyHairPackage.path, [])


## Shows a restored saved item as the current option of its picker.
func mark_selected(path: String, items: Array) -> void:
	var e := find(path, items)
	if e.is_empty():
		return
	if e.has("helper"):
		var h: CharacterElementHelper = e["helper"]
		h.modEntryIndex = h.modEntries.find(e)
		h.updateMenuList.call(e["title"])
	elif picker_entries.has(e.get("picker", "")):
		pass   # on / off lists read is_applied()
	elif e.get("picker") == "bg":
		g.inGameMenu.bgModIndex = bg_entries.find(e)
		g.inGameMenu.updateBGPicker()
	else:
		g.inGameMenu.hairModIndex = hair_entries.find(e)
		g.inGameMenu.customMenu.mlHair.itemLabel.text = e["title"]


## Finds the entry for a saved "<path>|<items>" (to show it as selected when a saved character restores it).
func find(path: String, items: Array) -> Dictionary:
	for e in entries:
		if (e["items"] == items or _applied_items(e) == items) and (e["path"] == path or Flash.resolve_content_path(e["path"]) == Flash.resolve_content_path(path)):
			return e
	return {}
