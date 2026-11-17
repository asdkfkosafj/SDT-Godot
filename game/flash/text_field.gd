class_name FlashTextField
extends FlashDisplayObject
## flash.text.TextField backed by a Godot Label (dynamic text) or LineEdit / TextEdit (input text).
## Supports the subset the game uses: text / htmlText (simple <p><font> markup), default text format,
## alignment, word wrap, autoSize, maxChars, restrict, change / focus / key events.

const GUTTER := 2.0
const FALLBACK_FONT_IDS := {134: true}   # embedded pixel font without exportable glyphs

var _box := Rect2(0, 0, 100, 20)
var _control: Control = null
var _text := ""
var _input := false
var _multiline := false
var _word_wrap := false
var _font: Font = null
## Port extension (not in Flash): thickens the glyphs (FontVariation.variation_embolden), e.g. for thin fonts.
var embolden := 0.0:
	set(value):
		if value != embolden:
			embolden = value
			_apply_format()
## Port extension (not in Flash): an outline around the glyphs (LabelSettings.outline_size, in the field's units),
## e.g. the Subtitles dialogue look's text border. 0: none. Labels only.
var outline_size := 0:
	set(value):
		if value != outline_size:
			outline_size = value
			_apply_format()
var outline_color := Color.BLACK:
	set(value):
		if value != outline_color:
			outline_color = value
			_apply_format()
var _font_size: float = 12.0
var _color := Color.BLACK
var _align := "left"
var _letter_spacing := 0.0
var _leading := 0.0
var _bold := false
var maxChars: int = 0
var restrict: String = ""
var selectable := true
var autoSize: String = "none"   # none, left, center, right
var border := false
var borderColor: int = 0
var background := false
var backgroundColor: int = 0xFFFFFF
var embedFonts := true
var condense_white := false

## Font instance id -> true when that embedded font has glyphs (an empty cmap means the export failed).
static var _font_has_glyphs := {}
## Port extension (not in Flash): the embedded font whose glyphs decide which characters show (see _shown), when
## the field draws with another font (the Subtitles dialogue look draws Inter, which has "Б"; the game's dialogue
## font, which decides, has not). null: the field's own font.
var glyph_font: Font = null:
	set(value):
		if value != glyph_font:
			glyph_font = value
			_apply_format()


## The text as Flash draws it: an embedded (SWF) font shows nothing for a character it has no glyph for, and
## that character takes no space. Dialogue writers use this: "Б" (not in the dialogue font) is an invisible
## character that still takes one typing step, a pause. Godot would draw it from a system font (or as a hex
## box), so such characters are taken out here. Device fonts (SystemFont) and input fields keep all text.
func _shown(t: String) -> String:
	var gf: Font = glyph_font if glyph_font != null else _font
	if _input or not (gf is FontFile) or t.is_empty():
		return t
	var id := gf.get_instance_id()
	if not _font_has_glyphs.has(id):
		_font_has_glyphs[id] = not gf.get_supported_chars().is_empty()
	if not _font_has_glyphs[id]:
		return t
	var out := t
	var removed := 0
	for i in t.length():
		var cp := t.unicode_at(i)
		if cp > 32 and not gf.has_char(cp):
			out = out.erase(i - removed, 1)
			removed += 1
	return out


func _init() -> void:
	_build_control()


func setup_from_library(lib: FlashLibrary, c: Dictionary) -> void:
	_library = lib
	_box = Rect2(c["x"], c["y"], c["w"], c["h"])
	_input = int(c.get("readOnly", 1)) == 0
	_multiline = int(c.get("multiline", 0)) != 0
	_word_wrap = int(c.get("wordWrap", 0)) != 0
	selectable = int(c.get("selectable", 1)) != 0
	border = int(c.get("border", 0)) != 0
	maxChars = int(c.get("maxLength", 0))
	_font_size = c.get("fontHeight", 12.0)
	var col: Array = c.get("color", [0, 0, 0, 255])
	_color = Color8(col[0], col[1], col[2], col[3])
	_align = c.get("align", "left")
	_leading = c.get("leading", 0.0)
	if c.has("font"):
		_font = Flash.get_font(lib, int(c["font"]))
	var t: String = c.get("text", "")
	_build_control()
	if int(c.get("html", 0)) != 0:
		htmlText = t
	else:
		text = t


func _build_control() -> void:
	if _control != null:
		remove_child(_control)
		_control.queue_free()
	if _input:
		if _multiline:
			var te := TextEdit.new()
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if _word_wrap else TextEdit.LINE_WRAPPING_NONE
			te.text_changed.connect(_on_text_changed)
			_control = te
		else:
			var le := LineEdit.new()
			le.text_changed.connect(func(_t): _on_text_changed())
			le.text_submitted.connect(func(_t): dispatchEvent(_key_event(13)))
			_control = le
		_control.focus_entered.connect(func(): Flash.set_focus(self))
		var empty := StyleBoxEmpty.new()
		_control.add_theme_stylebox_override("normal", empty)
		_control.add_theme_stylebox_override("focus", empty)
		_control.add_theme_stylebox_override("read_only", empty)
	else:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.clip_text = not _multiline
		_control = l
	_control.mouse_filter = Control.MOUSE_FILTER_STOP if _input else Control.MOUSE_FILTER_IGNORE
	add_child(_control)
	_apply_format()


func _key_event(code: int) -> FlashEvent:
	var e := FlashEvent.new(FlashEvent.KEY_DOWN, true)
	e.keyCode = code
	return e


func _on_text_changed() -> void:
	var t: String = _control.text
	if restrict != "":
		t = _apply_restrict(t)
	if maxChars > 0 and t.length() > maxChars:
		t = t.substr(0, maxChars)
	if t != _control.text:
		var caret = _control.caret_column if _control is LineEdit else 0
		_control.text = t
		if _control is LineEdit:
			_control.caret_column = mini(caret, t.length())
	_text = t
	dispatchEvent(FlashEvent.new(FlashEvent.CHANGE, true))


func _apply_restrict(t: String) -> String:
	var out := ""
	var re := RegEx.new()
	if re.compile("[" + restrict + "]") != OK:
		return t
	for ch in t:
		if re.search(ch) != null:
			out += ch
	return out


func _apply_format() -> void:
	if _control == null:
		return
	# embedFonts = false means a device font; those arrive here as SystemFont, so the font is used either way.
	var font := _font
	if font != null and (_letter_spacing != 0.0 or embolden != 0.0):
		var fv := FontVariation.new()
		fv.base_font = font
		fv.spacing_glyph = int(round(_letter_spacing))
		fv.variation_embolden = embolden
		font = fv
	if _control is Label:
		var ls := LabelSettings.new()
		if font != null:
			ls.font = font
		ls.font_size = int(round(_font_size))
		ls.font_color = _color
		ls.line_spacing = _leading
		if outline_size > 0:
			ls.outline_size = outline_size
			ls.outline_color = outline_color
		_control.label_settings = ls
		_control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _word_wrap else TextServer.AUTOWRAP_OFF
		_control.horizontal_alignment = _halign()
		_control.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		if font != null:
			_control.add_theme_font_override("font", font)
		_control.add_theme_font_size_override("font_size", int(round(_font_size)))
		_control.add_theme_color_override("font_color", _color)
		if _control is LineEdit:
			_control.alignment = _halign()
			if maxChars > 0:
				_control.max_length = maxChars
	_control.text = _shown(_text)
	_layout()


func _halign() -> HorizontalAlignment:
	match _align:
		"center":
			return HORIZONTAL_ALIGNMENT_CENTER
		"right":
			return HORIZONTAL_ALIGNMENT_RIGHT
		"justify":
			return HORIZONTAL_ALIGNMENT_FILL
	return HORIZONTAL_ALIGNMENT_LEFT


func _layout() -> void:
	if autoSize != "none" and not _word_wrap:
		var tw := textWidth + GUTTER * 2
		var old_w := _box.size.x
		_box.size.x = tw
		# Flash keeps the centre / right edge in place by moving the field itself (its x changes), so code that
		# then positions the field by x and width works as in Flash.
		if autoSize == "center":
			position.x += (old_w - tw) / 2.0 * scale.x
		elif autoSize == "right":
			position.x += (old_w - tw) * scale.x
		_box.size.y = textHeight + GUTTER * 2
	elif autoSize != "none":
		_box.size.y = textHeight + GUTTER * 2
	_control.position = _box.position + Vector2(GUTTER, GUTTER)
	_control.size = _box.size - Vector2(GUTTER * 2, GUTTER * 2)
	queue_redraw()
	_content_changed()


func _draw() -> void:
	if background:
		draw_rect(_box, Color.hex((backgroundColor << 8) | 0xFF))
	if border:
		draw_rect(_box, Color.hex((borderColor << 8) | 0xFF), false, 1.0)


# ---------------------------------------------------------------- Flash API

var text: String:
	get:
		return _control.text if _input else _text
	set(value):
		_text = value
		if _control != null:
			_control.text = _shown(value)
			_layout()


func appendText(t: String) -> void:
	text = text + t


## Minimal htmlText support: extracts <p align> and the first <font> attributes, converts <br> to newlines.
var htmlText: String:
	get:
		return _text
	set(value):
		var re := RegEx.new()
		re.compile('align="(\\w+)"')
		var m := re.search(value)
		if m:
			_align = m.get_string(1)
		re.compile('size="([\\d.]+)"')
		m = re.search(value)
		if m:
			_font_size = float(m.get_string(1))
		re.compile('color="#([0-9A-Fa-f]{6})"')
		m = re.search(value)
		if m:
			_color = Color.html(m.get_string(1))
		re.compile('letterSpacing="([-\\d.]+)"')
		m = re.search(value)
		if m:
			_letter_spacing = float(m.get_string(1))
		var t := value.replace("<br>", "\n").replace("<br/>", "\n").replace("</p><p", "\n<p")
		re.compile("<[^>]*>")
		t = re.sub(t, "", true)
		t = t.replace("&quot;", "\"").replace("&apos;", "'").replace("&lt;", "<").replace("&gt;", ">") \
			.replace("&amp;", "&")
		_text = t
		_apply_format()


var textColor: int:
	get:
		return _color.to_rgba32() >> 8
	set(value):
		_color = Color.hex((value << 8) | 0xFF)
		_apply_format()


var textWidth: float:
	get:
		var f: Font = _font if _font != null else ThemeDB.fallback_font
		var w := 0.0
		for line in _shown(_text).split("\n"):
			w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(_font_size))).x
				+ _letter_spacing * line.length())
		return w

var textHeight: float:
	get:
		var f: Font = _font if _font != null else ThemeDB.fallback_font
		var lines := maxi(1, _text.split("\n").size())
		return lines * f.get_height(int(round(_font_size))) + (lines - 1) * _leading

var numLines: int:
	get:
		if _control is Label or _control is TextEdit:
			return maxi(1, _control.get_line_count())
		return maxi(1, _text.split("\n").size())


var _scroll_v: int = 1

## 1-based index of the top visible line (Label only; input fields scroll themselves).
var scrollV: int:
	get:
		return _scroll_v
	set(value):
		_scroll_v = clampi(value, 1, maxScrollV)
		if _control is Label:
			_control.lines_skipped = _scroll_v - 1
			_control.clip_text = _scroll_v > 1 or not _multiline


var maxScrollV: int:
	get:
		var f: Font = _font if _font != null else ThemeDB.fallback_font
		var lh := f.get_height(int(round(_font_size))) + _leading
		var visible_lines := maxi(1, int(floor((_box.size.y - GUTTER * 2 + _leading) / maxf(1.0, lh))))
		return maxi(1, numLines - visible_lines + 1)


var type: String:
	get:
		return "input" if _input else "dynamic"
	set(value):
		var want := value == "input"
		if want != _input:
			var t := text
			_input = want
			_build_control()
			text = t


var multiline: bool:
	get:
		return _multiline
	set(value):
		_multiline = value
		_build_control()

var wordWrap: bool:
	get:
		return _word_wrap
	set(value):
		_word_wrap = value
		_apply_format()


## TextFormat as a Dictionary: font (name or Font), size, color, align, bold, letterSpacing, leading.
var defaultTextFormat: Dictionary:
	get:
		return {"font": _font, "size": _font_size, "color": _color.to_rgba32() >> 8, "align": _align,
			"bold": _bold, "letterSpacing": _letter_spacing, "leading": _leading}
	set(value):
		setTextFormat(value)


func setTextFormat(fmt: Dictionary) -> void:
	if fmt.has("font") and fmt["font"] != null:
		var f = fmt["font"]
		if f is Font:
			_font = f
		elif f is String:
			_font = Flash.get_font_by_name(f)
	if fmt.has("size") and fmt["size"] != null:
		_font_size = float(fmt["size"])
	if fmt.has("color") and fmt["color"] != null:
		_color = Color.hex((int(fmt["color"]) << 8) | 0xFF)
	if fmt.has("align") and fmt["align"] != null:
		_align = fmt["align"]
	if fmt.has("bold") and fmt["bold"] != null:
		_bold = fmt["bold"]
	if fmt.has("letterSpacing") and fmt["letterSpacing"] != null:
		_letter_spacing = float(fmt["letterSpacing"])
	if fmt.has("leading") and fmt["leading"] != null:
		_leading = float(fmt["leading"])
	_apply_format()


func setSelection(from: int, to: int) -> void:
	if _control is LineEdit:
		_control.select(from, to)
		_control.caret_column = to
	elif _control is TextEdit:
		var a := _index_to_line_col(from)
		var b := _index_to_line_col(to)
		_control.select(a.x, a.y, b.x, b.y)
		_control.set_caret_line(b.x)
		_control.set_caret_column(b.y)


var length: int:
	get:
		return text.length()


## Character index of the caret (input fields; 0 otherwise).
var caretIndex: int:
	get:
		if _control is LineEdit:
			return _control.caret_column
		if _control is TextEdit:
			var idx := 0
			for i in _control.get_caret_line():
				idx += _control.get_line(i).length() + 1
			return idx + _control.get_caret_column()
		return 0


func replaceText(begin: int, end: int, new_text: String) -> void:
	var t := text
	begin = clampi(begin, 0, t.length())
	end = clampi(end, begin, t.length())
	text = t.substr(0, begin) + new_text + t.substr(end)
	setSelection(begin + new_text.length(), begin + new_text.length())


func _index_to_line_col(idx: int) -> Vector2i:
	var line := 0
	while line < _control.get_line_count() - 1 and idx > _control.get_line(line).length():
		idx -= _control.get_line(line).length() + 1
		line += 1
	return Vector2i(line, mini(idx, _control.get_line(line).length()))


func grab_input_focus() -> void:
	if _input:
		_control.grab_focus()


func release_input_focus() -> void:
	if _control.has_focus():
		_control.release_focus()


func _local_bounds() -> Rect2:
	return _box


func _hit_shape(p: Vector2) -> bool:
	return _box.has_point(p)


func _get_width() -> float:
	return _box.size.x * absf(scale.x)


func _set_width(value: float) -> void:
	_box.size.x = value / maxf(absf(scale.x), 0.0001)
	_layout()


func _get_height() -> float:
	return _box.size.y * absf(scale.y)


func _set_height(value: float) -> void:
	_box.size.y = value / maxf(absf(scale.y), 0.0001)
	_layout()
