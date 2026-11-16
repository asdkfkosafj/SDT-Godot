extends SDTExtension
## Built-in reimplementation of the Loader mod hairRGB (sby, V4): up to four colours for hair mods made for it. Hair
## parts named rgbFill, rgbFill2, rgbFill3, rgbFill4 take the colours, the outlines next to them (outline, outline2,
## ...) a darker shade (colour x 0.4). Saved in the character code as "hairRGB:r,g,b,a,..." like the Loader mod.
## Written from its source.
##
## Port: a colour the player has not set leaves the mod's own colour (the original game showed hair mods that way;
## the Loader mod started them all at 255,252,247). Its colours are in the new menu's Her > Hair, each shown when the
## hair has that part. Taking the mods off (clearing them) gives the hair its own colours back, as the Loader mod's
## reset did. Hair mods' packages see the Loader mod's hairRGB_comm (LoaderComm), as they did with the Loader.

const OUTLINE_MULT := 0.4
const SLOTS := 4


## What hair mods made for hairRGB find on the Loader as hairRGB_comm (the Loader mod's own object): with it they
## keep all their colour parts (without it some hide rgbFill2 / rgbFill3 and take one colour from another item) and
## may read hairRGB, the first colour (e.g. for their outlines, every frame). Its other fields are the Loader
## mod's settings they check.
class LoaderComm:
	extends RefCounted
	var ext
	var usedefaultonnocharcode := 0
	var usedefaultonreset := 0
	var swatch3A := 0.0
	## The first colour as {r, g, b, a}; one the player has not chosen gives no change (black offsets).
	var hairRGB: Dictionary:
		get:
			return ext._rgb[0] if ext._set[0] else {"r": 0, "g": 0, "b": 0, "a": 1.0}

	func _init(e) -> void:
		ext = e

var _comm: LoaderComm = null

var _rgb: Array = []          # slot -> {r, g, b, a}
var _set: Array = []          # slot -> the player (or a code) chose it
var _present: Array = []      # slot -> the hair has that part (its colour is shown in the menu)
var _orig: Dictionary = {}    # part -> its own colour transform, put back on reset


func _init() -> void:
	id = "hairrgb"
	title = "hairRGB"
	description = "hairRGB (sby): up to four colours for hair mods made for it (parts named rgbFill to rgbFill4)."
	default_enabled = true


func _enable() -> void:
	_clear_slots()
	hook_after(&"CharacterControl.setHair", func(_c): _apply())
	hook_after(&"CharacterControl.setCustomHairLoaded", func(_c): _apply())
	hook_after(&"CustomElementLoader.updateInstancedModElements", func(_c): _apply())
	hook_after(&"CustomElementLoader.clearInstancedMods", func(_c): _reset())
	charcode_field("hairRGB", _code, func(v, _l): _load_code(v), func(_l): _reset(), true)
	var colours: Array = []
	for i in SLOTS:
		colours.append(MenuSchema.colour("Hair colour %d" % (i + 1), "", func(): return _rgb[i],
			func(c, _f): set_colour(i, c), "rgbFill", true, {"visible": func(): return _present[i]}))
	menu_control("her", "Hair", {"type": "colors", "label": "Hair mod colours", "tip": "Colours of hair mods made for hairRGB.",
		"keywords": "hair colour rgb", "visible": func(): return _present.has(true), "colors": colours})
	_apply()


func _disable() -> void:
	_reset()


func loader_comms() -> Dictionary:
	if _comm == null:
		_comm = LoaderComm.new(self)
	return {"hairRGB_comm": _comm}


func _clear_slots() -> void:
	_rgb = []
	_set = []
	_present = []
	for i in SLOTS:
		_rgb.append({"r": 255, "g": 252, "b": 247, "a": 1.0})
		_set.append(false)
		_present.append(false)


func set_colour(slot: int, c: Dictionary) -> void:
	_rgb[slot] = c.duplicate()
	_set[slot] = true
	_apply()


static func _fill_name(slot: int) -> String:
	return "rgbFill" if slot == 0 else "rgbFill%d" % (slot + 1)


static func _outline_name(slot: int) -> String:
	return "outline" if slot == 0 else "outline%d" % (slot + 1)


## The hair containers (the static hair clips, the dynamic hair layers, TemplateExtension's extra layer).
func _targets() -> Array:
	var out: Array = [g.hairTop, g.hairUnder, g.hairBottom, g.hairBack, g.hairOverLayer, g.hairUnderLayer,
		g.hairBetweenLayer, g.hairBackLayer]
	var te = Extensions.get_extension("templateextension")
	if te != null and te.enabled and te.hair_over_extended != null:
		out.append(te.hair_over_extended)
	return out.filter(func(o): return o != null and is_instance_valid(o))


## Parts by name under the hair (names of interest only).
func _collect(o, names: Dictionary, out: Dictionary) -> void:
	for i in o.numChildren:
		var c = o.getChildAt(i)
		if names.has(c.flash_name):
			out[c.flash_name].append(c)
		elif c is FlashSprite:
			_collect(c, names, out)


func _apply() -> void:
	var names := {}
	for i in SLOTS:
		names[_fill_name(i)] = true
		names[_outline_name(i)] = true
	var parts := {}
	for n in names:
		parts[n] = []
	for t in _targets():
		_collect(t, names, parts)
	for i in SLOTS:
		_present[i] = not parts[_fill_name(i)].is_empty()
		if not _set[i]:
			continue
		var c: Dictionary = _rgb[i]
		var fill := FlashColorTransform.new(1, 1, 1, float(c["a"]), float(c["r"]), float(c["g"]), float(c["b"]))
		var line := FlashColorTransform.new(1, 1, 1, 1, c["r"] * OUTLINE_MULT, c["g"] * OUTLINE_MULT, c["b"] * OUTLINE_MULT)
		for p in parts[_fill_name(i)]:
			_colour(p, fill)
		for p in parts[_outline_name(i)]:
			_colour(p, line)


func _colour(p, ct: FlashColorTransform) -> void:
	if not _orig.has(p):
		_orig[p] = p.colorTransform
	p.colorTransform = ct


## The hair's own colours back, no colour chosen.
func _reset() -> void:
	for p in _orig:
		if is_instance_valid(p):
			p.colorTransform = _orig[p]
	_orig.clear()
	for i in SLOTS:
		_set[i] = false
		_rgb[i] = {"r": 255, "g": 252, "b": 247, "a": 1.0}


## "r,g,b,a" per slot up to the last one chosen (the Loader mod always wrote four); null when none is.
func _code():
	var last := _set.rfind(true)
	if last < 0:
		return null
	var parts := PackedStringArray()
	for i in last + 1:
		var c: Dictionary = _rgb[i]
		parts.append("%d,%d,%d,%.3f" % [int(c["r"]), int(c["g"]), int(c["b"]), float(c["a"])])
	return ",".join(parts)


func _load_code(v: String) -> void:
	_reset()
	var n := v.split(",")
	for i in SLOTS:
		if n.size() > i * 4 + 3:
			_rgb[i] = {"r": int(float(n[i * 4])), "g": int(float(n[i * 4 + 1])), "b": int(float(n[i * 4 + 2])),
				"a": float(n[i * 4 + 3])}
			_set[i] = true
	_apply()
