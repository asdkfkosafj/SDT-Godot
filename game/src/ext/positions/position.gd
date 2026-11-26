extends RefCounted
## One body position: an animtools position file read and brought to the current format (V40).
##
## - `values`: every position key -> number (the field table's keys; a full file starts from their defaults, a
##   partial from the position it is applied to).
## - `extra`: lines the port does not know, kept in their order so a save writes them back ([key, text]).
## - `settings`: animtools global settings the file sets (see PositionFields.SETTINGS), kept apart (a partial: its
##   base's and its own); positions keeps the ones a loaded file sets for the session (Positions.setting_value).
## - `version`: the file's posversion (-1 when it has none). Some behaviour depends on it at runtime (the camera's
##   zoom model, the joint limits), so it is kept; the values themselves are converted to V40 meaning on load.
##
## Reading follows the Loader's settings files: `key=value` lines, values trimmed; a number when the value is one,
## else text. A file whose name ends in "_partial" changes only the keys it has. Written from animtools' files,
## documentation and behaviour (its backwards-compatibility rules below).

const Fields := preload("res://src/ext/positions/position_fields.gd")

var name := ""          # path under the positions root, without .txt, with "/" (e.g. "Oral/HimD/headpole_low")
var path := ""          # the file it came from ("" for one built in code)
var partial := false
var version := -1
var values: Dictionary = {}
var extra: Array = []
var settings: Dictionary = {}
var own_settings: Dictionary = {}   # the settings this file's own text sets (a partial: not its base's)


## The lines of a position file: [[key, text], ...] in file order (comments after ';' and empty lines left out).
static func parse_lines(text: String) -> Array:
	var out: Array = []
	if text.begins_with("﻿"):
		text = text.substr(1)
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		var c := line.find(";")
		if c >= 0:
			line = line.substr(0, c).strip_edges()
		var e := line.find("=")
		if e <= 0:
			continue
		out.append([line.substr(0, e).strip_edges(), line.substr(e + 1).strip_edges()])
	return out


static func is_number(s: String) -> bool:
	return s.is_valid_float() or s.is_valid_int()


## Whether a position name (or file name) is a partial one: animtools' rule, "_partial" at the end of the name.
static func is_partial_name(n: String) -> bool:
	return n.get_file().get_basename().ends_with("_partial") if n.ends_with(".txt") else n.get_file().ends_with("_partial")


## Reads a position. `base`: the position a partial applies to (null: animtools' defaults at V40). `globals`: the
## global settings the conversion reads (assumepartialsareofequalversion, usefallbacklegmountbodyscaling,
## fallbacklegmountbodyscaling); missing ones take animtools' shipped values.
static func from_text(text: String, pos_name: String, base = null, globals: Dictionary = {}, partial_override = null):
	var p = new()
	p.name = pos_name
	p.partial = is_partial_name(pos_name) if partial_override == null else partial_override
	var prev_version: int = Fields.VERSION
	var seen := {}
	if p.partial and base != null:   # a partial changes the position it is applied to: that one's name, file and lines
		p.name = base.name
		p.path = base.path
		p.values = base.values.duplicate()
		p.extra = base.extra.duplicate()
		p.settings = base.settings.duplicate()
		for i in p.extra.size():
			seen[p.extra[i][0]] = i
		prev_version = base.version
	else:
		p.values = Fields.defaults().duplicate()
		for k in Fields.LEGACY:
			p.values[k] = Fields.LEGACY[k]
	if p.partial:
		p.version = prev_version
	for kv in parse_lines(text):
		var k: String = kv[0]
		var v: String = kv[1]
		if k == "posversion" and is_number(v):
			p.version = int(v.to_float())
		elif (Fields.is_field(k) or Fields.LEGACY.has(k)) and is_number(v):
			p.values[k] = v.to_float()
		elif Fields.SETTINGS.has(k):   # (a partial's own stay out of `settings`: a save of the changed position does not write them)
			p.own_settings[k] = v.to_float() if is_number(v) else v
			if not (p.partial and base != null):
				p.settings[k] = p.own_settings[k]
		elif not seen.has(k):
			seen[k] = p.extra.size()
			p.extra.append([k, v])
		else:
			p.extra[seen[k]] = [k, v]
	p._convert(prev_version, globals)
	return p


func _g(globals: Dictionary, key: String) -> float:
	return float(globals.get(key, Fields.SETTINGS[key]))


## animtools' backwards-compatibility rules (applied on load, in its order), then the legacy keys it applies when a
## position is used (hands on her breasts as arm types). After this the values mean what V40 means.
func _convert(prev_version: int, globals: Dictionary) -> void:
	var v := values
	if partial and _g(globals, "assumepartialsareofequalversion") == 1:
		version = maxi(prev_version, version)
	var pv := version
	if pv < 33:
		if v["armpostyperight"] == 1 and (v["armposx"] != -5000 or v["armposy"] != -5000):
			v["armpostyperight"] = 12.0
		if v["armpostypeleft"] == 1 and (v["armpos2x"] != -5000 or v["armpos2y"] != -5000):
			v["armpostypeleft"] = 12.0
	if pv < 38:
		v["torsox2"] = v["torsox"]
		v["torsoy2"] = v["torsoy"]
	if pv < 15:
		v["changegravityforhairstrands"] = v["changegravityforstrands"]
	if pv < 27 and v["positiontype"] == 1:
		v["leftbreastbehind"] = 1.0
	if pv < 28:
		v["savedBodySize"] = _g(globals, "fallbacklegmountbodyscaling") if _g(globals, "usefallbacklegmountbodyscaling") == 1 else -999.0
	if pv < 35:
		v["offpathposmovement"] = 80.0
	if pv < 33 and (v["himreversed"] == 1 or v["himflipped"] == 1):
		if v["anglepeniswhenreversed"] == 1:
			v["hispenisrotationoffset"] = v["histweenstartang"] * -180.0 / PI
			v["hispenisrotationoffsetend"] = v["hispenisrotationoffset"]
		v["histweenstartang"] = 0.0
		v["histweenendangle"] = 0.0
		v["usesteadypenis"] = 1.0
	if pv == 33:
		v["hispenisrotationoffsetend"] = v["hispenisrotationoffset"]
	if pv < 39:
		v["hishandstartrotation"] = -5000.0
		v["hishandendrotation"] = -5000.0
		v["hishandrottarget"] = 1.0
	# her hands on her breasts, the old way (animtools' updateeverything): arm types 5 / 6
	if v["handlontit"] != 0 and v["armpostypeleft"] != -1:
		v["armpostypeleft"] = 4.0 + v["handlontit"]
	if v["handrontit"] != 0 and v["armpostyperight"] != -1:
		v["armpostyperight"] = 4.0 + v["handrontit"]
	v["handlontit"] = 0.0
	v["handrontit"] = 0.0


func get_value(key: String) -> float:
	return values.get(key, 0.0)


## The file text animtools writes for this position (posversion = current, every key, then the unknown lines).
func to_text() -> String:
	var lines := PackedStringArray(["posversion=%d" % Fields.VERSION])
	for k in Fields.order():
		lines.append("%s=%s" % [k, number_text(values[k])])
	for k in settings:
		lines.append("%s=%s" % [k, number_text(settings[k]) if settings[k] is float else str(settings[k])])
	for kv in extra:
		lines.append("%s=%s" % kv)
	return "\r\n".join(lines)


## A number as text that reads back as the same number (shortest form; whole numbers without a point).
static func number_text(x: float) -> String:
	if is_nan(x) or is_inf(x):
		return "0"
	if x == floorf(x) and absf(x) < 1e15:
		return str(int(x))
	for d in range(1, 18):
		var s := String.num(x, d)
		if s.to_float() == x:
			return s
	return String.num_scientific(x)
