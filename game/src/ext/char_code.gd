class_name CharCode
extends RefCounted
## Port extension (not in the original game): extra fields in the character code ("key:value;key:value...",
## InGameMenu.getSaveDataString / loadData), registered by extensions, in the same form Loader mods used, so codes
## shared from the Loader keep working.
##
## - Fields an extension registers are written after the vanilla fields and read after the vanilla ones are applied.
## - A field's setter gets the value and a Load context. When a code does not contain the field, its reset is called
##   only for a full character code: costume-only loads, a mod's built-in charData and short partial codes leave the
##   current value alone (the Loader mods' rule: a code is full only with more than PARTIAL_PAIRS ";"-separated parts).
## - Fields nobody knows (from a disabled plugin, or a Loader mod the port does not have) are kept and written back
##   out, so saving a character never loses them.
## - Fields marked after_mods are applied once the code's .swf mods have finished loading (fields that refer to mod
##   items, e.g. a headwear offset).

## Loader mods treated a code as full only if code.split(";") had more parts than this ("partialcharcodeskipdefaultamount").
const PARTIAL_PAIRS := 35

## Keys the vanilla game reads or writes (InGameMenu.loadData / getSaveDataString and the parts they call).
const VANILLA_KEYS := ["charName", "mood", "customHair", "customBG", "bodyScale", "arms", "throatResist", "hair",
	"iris", "nose", "ear", "breasts", "skin", "sclera", "eyebrow", "hairhsl", "skinhsl", "hisskinhsl", "bg", "him",
	"dialogue", "swfMod", "lipstick", "eyeshadow", "blush", "freckles", "mascara", "nailpolish", "collar", "cuffs",
	"ankleCuffs", "gag", "panties", "top", "armwear", "bottoms", "tops", "legwear", "legwearB", "footwear",
	"eyewear", "headwear", "tonguePiercing", "nipplePiercing", "bellyPiercing", "earring", "balls", "herPenis",
	"herTan", "hisBody", "hisBottoms", "hisBreasts", "hisFootwear", "hisPenis", "hisSkin", "hisTop"]

enum Kind { FULL, PARTIAL, COSTUME, MOD_CHARDATA }


## What kind of load is running, passed to field setters and resets.
class Load:
	extends RefCounted
	var kind: int = Kind.FULL
	var pairs: Dictionary = {}   # key -> value (String), last one wins
	var code := ""

	func is_full() -> bool:
		return kind == Kind.FULL


## key -> {"owner", "get", "set", "reset", "after_mods"}
static var _fields: Dictionary = {}
static var _order: Array = []
## Unknown pairs of the current character, in the order they were read: key -> value
static var _unknown: Dictionary = {}
static var _pending: Array = []   # [Load, [keys]] waiting for mods to finish loading
## Set by CustomElementLoader.parseMod while it loads a mod's built-in charData.
static var loading_mod_chardata := false
## Set while DialogueActions' [LOAD_CHARCODE] loads a code: InGameMenu.loadData then skips its reset of every
## clothing slot, body scale, nose, eyebrows and ears, so only what the code lists changes.
static var keep_unlisted := false


## Registers a field. `getter()` returns the value String to write, or null to leave the field out; it must not
## contain ";". `setter(value: String, load: Load)` applies a value. `reset(load: Load)` (optional) applies the
## default when a full code does not contain the field.
static func add_field(key: String, owner: String, getter: Callable, setter: Callable, reset := Callable(),
		after_mods := false) -> bool:
	if key in VANILLA_KEYS or _fields.has(key):
		push_error("charcode: field '%s' is already used" % key)
		return false
	_fields[key] = {"owner": owner, "get": getter, "set": setter, "reset": reset, "after_mods": after_mods}
	_order.append(key)
	return true


## Removes an extension's fields. Their current values are kept like unknown fields, so a character saved while
## the extension is off still has them.
static func remove_owner(owner: String) -> void:
	for key in _order.duplicate():
		if _fields[key]["owner"] == owner:
			var v = _field_value(key)
			if v != null and not ";" in str(v):
				_unknown[key] = str(v)
			_fields.erase(key)
			_order.erase(key)


## Gives an extension's fields the values kept for them as unknown pairs: the character was loaded before it was
## on (at startup the last character is restored before extensions start, or it was switched on later).
static func adopt_kept(owner: String) -> void:
	var l := Load.new()
	var keys: Array = []
	for key in _order:
		if _fields[key]["owner"] == owner and _unknown.has(key):
			l.pairs[key] = _unknown[key]
			_unknown.erase(key)
			keys.append(key)
	var later := keys.filter(func(k): return _fields[k]["after_mods"])
	_apply(l, keys.filter(func(k): return not _fields[k]["after_mods"]))
	if not later.is_empty():
		if mods_loading():
			_pending.append([l, later])
		else:
			_apply(l, later)


static func has_field(key: String) -> bool:
	return _fields.has(key)


## Value of an unknown (kept) field of the current character, or "" if there is none.
static func unknown_value(key: String) -> String:
	return _unknown.get(key, "")


# ---------------------------------------------------------------- called from InGameMenu

## The extra fields for getSaveDataString: ";key:value" for every registered field and every kept unknown pair.
## `vanilla` is the vanilla part of the string: keys it already contains are not repeated.
static func save_fields(vanilla: String) -> String:
	if _fields.is_empty() and _unknown.is_empty():
		return ""
	var present := {}
	for p in vanilla.split(";"):
		present[p.get_slice(":", 0)] = true
	var s := ""
	for key in _order:
		var v = _field_value(key)
		if v == null:
			continue
		v = str(v)
		if ";" in v:
			push_error("charcode: value of '%s' contains ';', not saved" % key)
			continue
		s += ";%s:%s" % [key, v]
		present[key] = true
	for key in _unknown:
		if not present.has(key) and not _fields.has(key):
			s += ";%s:%s" % [key, _unknown[key]]
	return s


## Applies the registered fields of a code being loaded (end of InGameMenu.loadData). `pairs` are loadData's split
## pairs ([key, value parts...]).
static func load_fields(pairs: Array, code: String, costume_only: bool) -> void:
	var from_mod := loading_mod_chardata
	var l := Load.new()
	l.code = code
	for p in pairs:
		if p.size() < 2 or p[0] == "":
			continue
		l.pairs[p[0]] = ":".join(PackedStringArray(p.slice(1)))
	if from_mod:
		l.kind = Kind.MOD_CHARDATA
	elif costume_only:
		l.kind = Kind.COSTUME
	elif code.split(";").size() <= PARTIAL_PAIRS:
		l.kind = Kind.PARTIAL
	else:
		l.kind = Kind.FULL
	# unknown pairs belong to the character: a full code replaces them, other loads add to them
	if l.kind == Kind.FULL:
		_unknown.clear()
	for key in l.pairs:
		if not key in VANILLA_KEYS and not _fields.has(key):
			_unknown[key] = l.pairs[key]
	var now: Array = []
	var later: Array = []
	for key in _order:
		(later if _fields[key]["after_mods"] else now).append(key)
	_apply(l, now)
	if not later.is_empty():
		if mods_loading():
			_pending.append([l, later])
		else:
			_apply(l, later)


## True while .swf mods of a code are still loading.
static func mods_loading() -> bool:
	return g.customElementLoader != null and g.customElementLoader.readingMods


## Called when mod loading finished (CustomElementLoader): applies after_mods fields and tells the extensions.
static func mods_loaded() -> void:
	var pending := _pending
	_pending = []
	for p in pending:
		_apply(p[0], p[1].filter(func(k): return _fields.has(k)))
	Extensions.emit("mods_loaded")


static func _apply(l: Load, keys: Array) -> void:
	for key in keys:
		var f: Dictionary = _fields[key]
		var prev := Extensions.enter(f["owner"])
		if l.pairs.has(key):
			f["set"].call(l.pairs[key], l)
		elif l.is_full() and f["reset"].is_valid():
			f["reset"].call(l)
		Extensions.leave(prev)


## A field's value from its extension's getter.
static func _field_value(key: String):
	var prev := Extensions.enter(_fields[key]["owner"])
	var v = _fields[key]["get"].call()
	Extensions.leave(prev)
	return v
