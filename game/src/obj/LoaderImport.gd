class_name LoaderImport
extends RefCounted
## Port addition: imports the stored characters of a Loader installation with the mods they wear.
##
## The player picks the Loader's folder. Its Flash save (the Loader's SDT.swf save in Flash's #SharedObjects) gives
## the characters, added like Load Backup does (or replacing the list, as that setting says). Their codes name
## clothing the way MoreClothing listed it, so every name the port has no item for is looked up in that Loader's
## MoreClothing settings (Settings/moreclothingV*settings.txt: "<file>=<name>:<types>"), else by file name in its
## mods folder. The files are copied into Mods/Clothing, Mods/Hair or Mods/Backgrounds (never over a file there) and
## their names added to that folder's names.txt (ModCatalog), also image hairs and backgrounds a code names by path.
## The Loader's files are only read here: afterwards the port needs nothing from the Loader.
##
## animtools' body positions come along too: Settings/animtools_positions (its folders kept) and the position files of
## character folders (animtoolscharposition.txt in a folder under Mods, named after that folder) go into
## Mods/Positions/Imported (Characters/ for those), with their thumbnails; a file the same as one already in
## Mods/Positions (the shipped set) is not copied again.

## Character code key -> costume slot (its CharacterControl helper is "<slot>Control")
const SLOT_KEYS := {"collar": "collar", "cuffs": "cuffs", "ankleCuffs": "ankleCuffs", "gag": "gag", "panties": "panties",
	"top": "bra", "armwear": "armwear", "bottoms": "bottoms", "tops": "top", "legwear": "legwear",
	"legwearB": "legwearB", "footwear": "footwear", "eyewear": "eyewear", "headwear": "headwear",
	"tonguePiercing": "tonguePiercing", "nipplePiercing": "nipplePiercing", "bellyPiercing": "bellyPiercing",
	"earring": "earring"}
## MoreClothing's menu (the mod type after ">") -> the names.txt slot that shows the mod there
const TYPE_SLOTS := {"CostumeCollar": "collar", "CostumeGag": "gag", "CostumeCuffs": "cuffs",
	"CostumeAnkleCuffs": "ankleCuffs", "CostumeEyewear": "eyewear", "CostumePanties": "panties",
	"CostumeArmwear": "armwear", "CostumeLegwear": "legwear", "CostumeLegwearB": "legwearB",
	"CostumeBottoms": "bottoms", "CostumeFootwear": "footwear", "CostumeTop": "top", "CostumeBra": "bra",
	"CostumeTonguePiercing": "tonguePiercing", "CostumeNipplePiercing": "nipplePiercing",
	"CostumeBellyPiercing": "bellyPiercing", "CostumeEarPiercing": "earring", "CostumeHeadwear": "headwear",
	"Body": "body", "Body2": "body", "Body3": "body"}
const IMAGES := ["png", "jpg", "jpeg", "gif", "bmp"]

var loader := ""          # the Loader's folder
var _mc_dir := ""         # MoreClothing's mods folder
var _mc: Dictionary = {}  # g.dataName(name) -> [{file, name, types}] from the MoreClothing settings
var _named: Dictionary = {}   # Mods subfolder -> {lower-case file name: true} already in its names.txt
var copied: Array = []        # file names copied
var named_count := 0          # names added to names.txt
var missing: Array = []       # names / paths found nowhere
var chars: Array = []         # the characters (Load Backup entries)
var added := 0                # characters added to the list (the others were in it already)
var positions := 0            # position files copied
var _position_sums: Dictionary = {}   # md5 of every position file already in Mods/Positions
var error := ""


## Menu entry: asks for the Loader's folder, imports, shows what was done.
static func choose() -> void:
	var done := func(ok: bool, paths: PackedStringArray, _filter: int):
		if ok and not paths.is_empty():
			_report(LoaderImport.run(paths[0]))
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Choose the Loader's folder (with Loader.swf)", "", "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_DIR, PackedStringArray(), done)
	else:
		var d := FileDialog.new()
		d.access = FileDialog.ACCESS_FILESYSTEM
		d.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		d.title = "Choose the Loader's folder (with Loader.swf)"
		Flash.add_child(d)
		d.dir_selected.connect(func(p: String): done.call(true, PackedStringArray([p]), 0); d.queue_free())
		d.canceled.connect(func(): d.queue_free())
		d.popup_centered_ratio(0.7)


## Imports from the Loader at `dir` (see the top of this file).
static func run(dir: String) -> LoaderImport:
	var li := LoaderImport.new()
	li.loader = dir.replace("\\", "/").trim_suffix("/")
	li._import_positions()
	var sol := li._find_save()
	if sol == "":
		li.error = "No Flash save found for the Loader in %s. Use Load backup with its ChoIrrumatio.sol instead." % li.loader
		return li
	var c = g.inGameMenu._storedCharsFromSol(FileAccess.get_file_as_bytes(sol), sol)
	if not c is Array:
		li.error = "Could not read the Loader's characters (%s)." % sol
		return li
	li.chars = c
	li._read_settings()
	for ch in li.chars:
		if str(ch.get("charName", "")) != "":
			li._import_code(str(ch.get("charData", "")))
	g.modCatalog.rescan()
	var before: int = 0 if g.overwriteCharList else g.storedChars.size()
	g.inGameMenu.instanceStoredCharFile(li.chars)
	li.added = g.storedChars.size() - before
	return li


static func _report(li: LoaderImport) -> void:
	var n := li.chars.filter(func(c): return str(c.get("charName", "")) != "").size()
	var already := " (%d were in the list already)" % (n - li.added) if n > li.added else ""
	var text := li.error if li.error != "" else "%d characters imported%s.\n%d mod files copied, %d names added to names.txt." \
		% [li.added, already, li.copied.size(), li.named_count]
	if li.positions > 0:
		text += "\n%d body positions copied into Mods/Positions/Imported." % li.positions
	if not li.missing.is_empty():
		text += "\n\nNot found in the Loader: " + ", ".join(PackedStringArray(li.missing))
	var d := AcceptDialog.new()
	d.title = "Import from the Loader"
	d.dialog_text = text
	d.dialog_autowrap = true
	d.size = Vector2i(520, 200)
	Flash.add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	d.popup_centered()


## The Loader's save: Flash keeps it under #SharedObjects/<id>/localhost/<the Loader's folder>/SDT.swf.
func _find_save() -> String:
	var base := OS.get_environment("APPDATA").path_join("Macromedia/Flash Player/#SharedObjects")
	var rel := loader.substr(loader.find(":/") + 2) if ":/" in loader else loader.trim_prefix("/")
	var d := DirAccess.open(base)
	if d == null:
		return ""
	for id in d.get_directories():
		for swf in ["SDT.swf", "Loader.swf"]:
			var p := base.path_join(id).path_join("localhost").path_join(rel).path_join(swf).path_join("ChoIrrumatio.sol")
			if FileAccess.file_exists(p):
				return p
	return ""


func _read_settings() -> void:
	_mc_dir = loader.path_join("Mods/$INIT$/moreclothingmods")
	var sd := DirAccess.open(loader.path_join("Settings"))
	if sd == null:
		return
	var best := ""
	for f in sd.get_files():
		if f.to_lower().begins_with("moreclothing") and f.to_lower().ends_with("settings.txt") and f > best:
			best = f
	if best == "":
		return
	var block := false
	for raw in FileAccess.get_file_as_string(loader.path_join("Settings").path_join(best)).split("\n"):
		var line := raw.strip_edges()
		if line.to_lower().begins_with(";blockcomment"):
			block = true
		elif line.to_lower().begins_with(";endblockcomment"):
			block = false
		# commented-out entries still count: characters saved while they were on still name them
		var l := line.trim_prefix(";").strip_edges() if not block else ""
		if not "=" in l or l.begins_with("+"):
			continue
		var file := l.get_slice("=", 0).strip_edges()
		var parts := l.substr(l.find("=") + 1).split(":")
		var name := parts[0].get_slice("+", 0).strip_edges()
		if file.get_extension().to_lower() in ModCatalog.MOD_EXTENSIONS + IMAGES and name != "":
			var key := g.dataName(name)
			var e := {"file": file, "name": name, "types": Array(parts.slice(1)), "commented": line.begins_with(";")}
			if not _mc.has(key):
				_mc[key] = []
			_mc[key].append(e)


# ---------------------------------------------------------------- body positions (animtools)

const CHAR_POSITION := "animtoolscharposition.txt"


func _import_positions() -> void:
	var root := Flash.mods_dir("Positions")
	_sum_dir(root)
	var dest := root.path_join("Imported")
	_copy_positions(loader.path_join("Settings/animtools_positions"), dest)
	_char_positions(loader.path_join("Mods"), dest.path_join("Characters"), 0)
	if positions > 0:
		var ext = Extensions.get_extension("positions")
		if ext != null and ext.enabled:
			ext.rescan()


func _sum_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension().to_lower() == "txt":
			_position_sums[FileAccess.get_md5(dir.path_join(f))] = true
	for sub in d.get_directories():
		_sum_dir(dir.path_join(sub))


## Every .txt under `src` (with its .png) into the same folders under `dest`.
func _copy_positions(src: String, dest: String) -> void:
	var d := DirAccess.open(src)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension().to_lower() == "txt":
			_copy_position(src.path_join(f), dest.path_join(f))
	for sub in d.get_directories():
		_copy_positions(src.path_join(sub), dest.path_join(sub))


## Character folders' positions (searched a few folders deep under the Loader's Mods), named after their folder.
func _char_positions(dir: String, dest: String, depth: int) -> void:
	var d := DirAccess.open(dir)
	if d == null or depth > 4:
		return
	for f in d.get_files():
		if f.to_lower() == CHAR_POSITION:
			_copy_position(dir.path_join(f), dest.path_join(dir.get_file() + ".txt"))
	for sub in d.get_directories():
		_char_positions(dir.path_join(sub), dest, depth + 1)


func _copy_position(src: String, dest: String) -> void:
	var sum := FileAccess.get_md5(src)
	if sum == "" or _position_sums.has(sum) or FileAccess.file_exists(dest):
		return   # the same as one there already (the shipped set, an earlier import), or a file of the player's
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	if DirAccess.copy_absolute(src, dest) != OK:
		return
	_position_sums[sum] = true
	positions += 1
	var png := src.get_basename() + ".png"
	if FileAccess.file_exists(png) and not FileAccess.file_exists(dest.get_basename() + ".png"):
		DirAccess.copy_absolute(png, dest.get_basename() + ".png")


## Copies what one character code needs.
func _import_code(code: String) -> void:
	var cc = g.characterControl
	for pair in code.split(";"):
		var key := pair.get_slice(":", 0)
		var val := pair.substr(key.length() + 1)
		var name := val.get_slice(",", 0)
		if name == "" or name.to_lower() == "none":
			continue
		if SLOT_KEYS.has(key):
			var h = cc.get(SLOT_KEYS[key] + "Control")
			if h == null or h.elementNameList.any(func(n): return g.dataName(n) == g.dataName(name)) \
					or g.modCatalog.has_named(h, name):
				continue
			_bring(name, "", SLOT_KEYS[key])
		elif key == "hair":
			if g.dataName(name) == "customhair" or cc.characters.any(func(c): return g.dataName(c.charShortName) == g.dataName(name)) \
					or g.modCatalog.has_named("hair", name):
				continue
			_bring(name, "", "")
		elif key == "moreclothingbody":
			if not g.modCatalog.has_named(null, name):
				_bring(name, "body", "")
		elif key == "customHair" or key == "customBG":
			_bring_file(val, "Hair" if key == "customHair" else "Backgrounds")


## A name from a code: its MoreClothing entry, else a file of that name in the mods folder. Of several entries of the
## name, one for the code's slot (`for_slot`) comes first (Torn Stockings and its B version), then active ones.
func _bring(name: String, slot: String, for_slot: String) -> void:
	var list: Array = _mc.get(g.dataName(name), [])
	var rank := func(e) -> int:
		var fits := false
		for t in e["types"]:
			fits = fits or TYPE_SLOTS.get(str(t).get_slice(">", 0).get_slice("+", 0).get_slice("-", 0).strip_edges(), "") == for_slot
		return (0 if fits or for_slot == "" else 2) + (1 if e["commented"] else 0)
	list = list.duplicate()
	list.sort_custom(func(a, b): return rank.call(a) < rank.call(b))
	for e in list:
		var src := _source(e["file"])
		if src == "":
			continue
		var redirect := slot
		for t in e["types"]:
			if ">" in t and redirect == "":
				redirect = TYPE_SLOTS.get(str(t).get_slice(">", 1).get_slice("+", 0).get_slice("-", 0).strip_edges(), "")
		var sub := _subfolder(e["file"], e["types"])
		_copy(src, sub)
		_add_name(sub, src.get_file(), e["name"], redirect)
		return
	var found := _find_by_stem(_mc_dir, g.dataName(name))
	if found != "":
		var sub := _subfolder(found, [])
		_copy(found, sub)
		_add_name(sub, found.get_file(), name, slot)
		return
	if not name in missing:
		missing.append(name)


## An image a code names by path (customHair / customBG), copied unless Mods/ has a file of that name.
func _bring_file(p: String, sub: String) -> void:
	var path := Flash.resolve_content_path(p)
	if FileAccess.file_exists(path) or CustomElementLoader._findFile(Flash.mods_dir(), p.replace("\\", "/").get_file()) != "":
		return
	var src := loader.path_join(p.replace("\\", "/")) if not p.replace("\\", "/").is_absolute_path() else p
	if not FileAccess.file_exists(src):
		if not p in missing:
			missing.append(p)
		return
	_copy(src, sub)


func _source(file: String) -> String:
	var p := _mc_dir.path_join(file)
	if FileAccess.file_exists(p):
		return p
	return CustomElementLoader._findFile(loader.path_join("Mods"), file.get_file())


static func _subfolder(file: String, types: Array) -> String:
	var f := file.to_lower()
	var t := " ".join(PackedStringArray(types.map(func(x): return str(x))))
	if f.begins_with("backgrounds/") or "Background" in t:
		return "Backgrounds"
	if f.begins_with("hairs/") or f.get_extension() in IMAGES or "Hair" in t.replace("HairCostume", ""):
		return "Hair"
	return "Clothing"


func _copy(src: String, sub: String) -> void:
	var dest := Flash.mods_dir(sub).path_join(src.get_file())
	if FileAccess.file_exists(dest):
		return   # never over a file there (the same mod, or the player's own)
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	if DirAccess.copy_absolute(src, dest) == OK:
		copied.append(src.get_file())


## Adds "<file> = <name> [> <slot>]" to the folder's names.txt, unless the file is named there already.
func _add_name(sub: String, file: String, name: String, slot: String) -> void:
	var p := Flash.mods_dir(sub).path_join("names.txt")
	if not _named.has(sub):
		var known := {}
		if FileAccess.file_exists(p):
			for line in FileAccess.get_file_as_string(p).split("\n"):
				line = line.get_slice("#", 0)
				if "=" in line:
					known[line.get_slice("=", 0).strip_edges().to_lower()] = true
		_named[sub] = known
	if _named[sub].has(file.to_lower()):
		return
	var text := FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else \
		"# Names Loader characters use for these mods (MoreClothing's): <file> = <name> [> <slot>]\n"
	if not text.ends_with("\n"):
		text += "\n"
	text += "%s = %s%s\n" % [file, name, " > " + slot if slot != "" else ""]
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
	_named[sub][file.to_lower()] = true
	named_count += 1


## A .swf in `dir` (or below) whose name is `want` (g.dataName), else the shortest one containing it.
static func _find_by_stem(dir: String, want: String) -> String:
	var best := ""
	var d := DirAccess.open(dir)
	if d == null or want == "":
		return ""
	for f in d.get_files():
		if not f.get_extension().to_lower() in ModCatalog.MOD_EXTENSIONS:
			continue
		var stem := g.dataName(f.get_basename())
		if stem == want:
			return dir.path_join(f)
		if want in stem and (best == "" or f.length() < best.get_file().length()):
			best = dir.path_join(f)
	for sub in d.get_directories():
		var found := _find_by_stem(dir.path_join(sub), want)
		if found != "" and (best == "" or g.dataName(found.get_file().get_basename()) == want):
			return found
	return best
