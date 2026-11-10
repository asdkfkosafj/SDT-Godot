class_name FlashShape
extends FlashDisplayObject
## A static vector shape (DefineShape / static text) or a morph shape at a given ratio.
##
## This is the only class that knows how artwork is drawn. The current backend draws pre-rasterised
## textures produced by tools/swfconv; a vector-mesh backend would replace _draw / _hit_shape here only.

var _entry: Dictionary = {}      # library image entry: img, x, y, w, h, hm
var _morph: Dictionary = {}      # morph character entry (ratios -> image entry), if a morph shape
var _ratio: int = 0
var _texture: Texture2D = null
var _draw_entry: Dictionary = {} # entry of the image currently shown; lags _entry while a morph frame streams in
## Set by game code around a discrete appearance change (e.g. a breast size): morph frames load at once instead of
## streaming in, so no part shows its old picture next to parts that already switched (Flash shows all at once).
## Animation keeps streaming: its next frames are prefetched, and a blocking load there would be a hitch.
static var load_now := false


func setup(library, char_id: int, ratio: int = 0) -> void:
	_library = library
	_char_id = char_id
	var c: Dictionary = library.get_char(char_id)
	if c.get("t") == "morph":
		_morph = c
		set_ratio(ratio)
	else:
		_set_entry(c)


func set_ratio(ratio: int) -> void:
	if _morph.is_empty() or (ratio == _ratio and not _entry.is_empty()):
		return
	var prev := _ratio
	_ratio = ratio
	var e = _morph["ratios"].get(str(ratio))
	if e == null:
		e = _nearest_ratio(ratio)
	if e == null or not e.has("img"):
		_set_entry(e if e != null else {})
		return
	# Geometry (bounds, hit mask) switches now; the picture follows as soon as its texture is loaded.
	_entry = e
	_content_changed()
	if load_now:
		_show(e, _library.get_texture(e["img"]))
		return
	var t: Texture2D = _library.request_texture(e["img"], self)
	if t != null:
		_show(e, t)
	elif _texture == null:
		# New instance with nothing to show yet: use the nearest frame already in memory, else load now.
		var near := _nearest_cached(ratio)
		if near.is_empty():
			_set_entry(e)
		else:
			_show(near, _library.request_texture(near["img"]))
	_prefetch(ratio, ratio - prev)


func _sorted_ratios() -> PackedInt32Array:
	var keys: PackedInt32Array = _morph.get("_keys", PackedInt32Array())
	if keys.is_empty():
		for k in _morph["ratios"]:
			if _morph["ratios"][k] != null:
				keys.append(int(k))
		keys.sort()
		_morph["_keys"] = keys
	return keys


func _nearest_cached(ratio: int) -> Dictionary:
	var keys := _sorted_ratios()
	var i := keys.bsearch(ratio)
	for n in range(1, 6):
		for j in [i - n, i + n - 1]:
			if j >= 0 and j < keys.size():
				var e: Dictionary = _morph["ratios"][str(keys[j])]
				if _library.is_texture_cached(e["img"]):
					return e
	return {}


## Starts background loads of the next frames of the morph in the direction it is moving.
func _prefetch(ratio: int, direction: int) -> void:
	var keys := _sorted_ratios()
	var i := keys.bsearch(ratio)
	var step := 1 if direction >= 0 else -1
	if step < 0:
		i -= 1
	for n in 2:
		i += step
		if i < 0 or i >= keys.size():
			return
		var e: Dictionary = _morph["ratios"][str(keys[i])]
		_library.request_texture(e["img"])


func _texture_ready(img: String, t: Texture2D) -> void:
	if _entry.get("img") == img:
		_show(_entry, t)


func _nearest_ratio(ratio: int):
	var best = null
	var best_d := 1 << 30
	for k in _morph["ratios"]:
		var d: int = absi(int(k) - ratio)
		if d < best_d and _morph["ratios"][k] != null:
			best_d = d
			best = _morph["ratios"][k]
	return best


func _set_entry(e: Dictionary) -> void:
	_entry = e
	_content_changed()
	_show(e, _library.get_texture(e["img"]) if e.has("img") else null)


## The library switched the file of the entry's picture (FlashLibrary.use_drawn_fills): load it again.
func _picture_changed() -> void:
	if _entry.has("img"):
		_show(_entry, _library.get_texture(_entry["img"]))


func _show(e: Dictionary, t: Texture2D) -> void:
	if t == _texture and e == _draw_entry:
		return
	_draw_entry = e
	_texture = t
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var s: float = _library.scale
	draw_texture_rect(_texture, Rect2(_draw_entry["x"], _draw_entry["y"], _texture.get_width() / s, _texture.get_height() / s), false)


func _local_bounds() -> Rect2:
	if _entry.is_empty():
		return Rect2()
	return Rect2(_entry["x"], _entry["y"], _entry["w"], _entry["h"])


func _hit_shape(p: Vector2) -> bool:
	if _entry.is_empty() or not _entry.has("hm"):
		return false
	return _library.hit_mask_test(_entry, p)


func _render_state_changed() -> void:
	material = Flash.shape_material(self)
