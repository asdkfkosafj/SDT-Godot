extends RefCounted
## The position files under the positions root (Mods/Positions): found by scanning the folders, no list to keep.
## Subfolders are categories ("Oral", "Anal/HimD", ...); a position's name is its path under the root without
## ".txt". A .png with the same name is its thumbnail.
##
## Finding a position by the name a dialogue trigger or a character code gives (animtools' names are relative to the
## Loader's Settings/animtools_positions folder, "\" or "_slash5C_" between folders): the exact path first (case
## ignored), then a unique file name anywhere under the root, then the same two with every non-word character
## removed (the Loader matched the dialogue word's "action", which has them removed).

var root := ""
var names: PackedStringArray = PackedStringArray()   # sorted
var _path_of: Dictionary = {}     # lower-case name -> file path
var _by_file: Dictionary = {}     # lower-case file name -> [names]
var _by_word: Dictionary = {}     # name, non-word characters removed, lower case -> [names]
var _by_file_word: Dictionary = {}


func scan(dir: String) -> void:
	root = dir
	names.clear()
	_path_of.clear()
	_by_file.clear()
	_by_word.clear()
	_by_file_word.clear()
	_scan(dir, "")
	names.sort()


func _scan(dir: String, rel: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = false
	for f in d.get_files():
		if f.get_extension().to_lower() != "txt":
			continue
		var n := (rel + "/" + f.get_basename()) if rel != "" else f.get_basename()
		names.append(n)
		_path_of[n.to_lower()] = dir.path_join(f)
		_add(_by_file, f.get_basename().to_lower(), n)
		_add(_by_word, _word(n), n)
		_add(_by_file_word, _word(f.get_basename()), n)
	for sub in d.get_directories():
		_scan(dir.path_join(sub), (rel + "/" + sub) if rel != "" else sub)


static func _add(d: Dictionary, k: String, n: String) -> void:
	if not d.has(k):
		d[k] = []
	d[k].append(n)


## The name with "/" and every non-word character removed, lower case (the Loader's \W stripping).
static func _word(n: String) -> String:
	var out := ""
	for ch in n.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_":
			out += ch
	return out


func has(n: String) -> bool:
	return _path_of.has(n.to_lower())


func path_of(n: String) -> String:
	return _path_of.get(n.to_lower(), "")


## The position a dialogue trigger / character code names, or "" (a name several files share: "" and `why` says so).
func find(given: String) -> String:
	var n := given.replace("_slash5C_", "/").replace("\\", "/").strip_edges()
	if n.to_lower().ends_with(".txt"):
		n = n.substr(0, n.length() - 4)
	for prefix in ["settings/", "animtools_positions/"]:
		if n.to_lower().begins_with(prefix):
			n = n.substr(prefix.length())
	if has(n):
		return _canon(n)
	if has("animtools/" + n):   # animtools' own names, in the shipped set
		return _canon("animtools/" + n)
	var hit := _unique(_by_file, n.get_file().to_lower())
	if hit != "":
		return hit
	hit = _unique(_by_word, _word(n))
	if hit != "":
		return hit
	return _unique(_by_file_word, _word(n.get_file()))


func _canon(n: String) -> String:
	for m in names:
		if m.to_lower() == n.to_lower():
			return m
	return n


## A unique match; several: the one in the shipped set ("animtools/...") when exactly one is, else none.
func _unique(d: Dictionary, k: String) -> String:
	var l: Array = d.get(k, [])
	if l.size() == 1:
		return l[0]
	if l.size() > 1:
		var shipped := l.filter(func(m): return m.begins_with("animtools/"))
		if shipped.size() == 1:
			push_warning("Positions: \"%s\" matches %d files, using %s" % [k, l.size(), shipped[0]])
			return shipped[0]
	return ""


func thumbnail_path(n: String) -> String:
	var p := path_of(n)
	if p == "":
		return ""
	var png := p.get_basename() + ".png"
	return png if FileAccess.file_exists(png) else ""
