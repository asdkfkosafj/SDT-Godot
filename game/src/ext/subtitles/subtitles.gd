extends SDTExtension
## Port addition (not a Loader mod): the "Subtitles" dialogue look. Her lines, his lines and her thoughts show as
## centred text over a soft dark shade along the bottom of the window, instead of the game's speech box: Inter
## Medium (her lines warm white, his blue, thoughts italic), with a drop shadow and, if set, a dark border
## (FlashTextField.outline_size). "Classic box" (or this extension
## off, as in Vanilla mode) shows the game's box.
##
## The text is still the game's dialogue field, typed out as before; only its look and place change. Characters
## the game's own dialogue font has no glyph for stay invisible (the "Б" pauses of dialogue writers), although
## Inter has them (FlashTextField.glyph_font). dialogdisplayedit's box colour and opacity colour the shade, its
## text colour and opacity the text. A font chosen by a dialogue (extramod [EM_FONT...]) is kept. While a dialogue
## box mod (extramod) is on, the Classic box shows (box_mods).

const Shade := preload("res://src/ext/subtitles/subtitle_shade.gd")
const FONT := preload("res://assets/fonts/inter/Inter-Variable.ttf")
const FONT_ITALIC := preload("res://assets/fonts/inter/Inter-Italic-Variable.ttf")

const LOOKS := ["Subtitles", "Classic box"]
const DEFAULT_SIZE := 21        # stage units (28 px in a 1600 x 800 window)
const WEIGHT := 500
const THOUGHT_WEIGHT := 500
const LEADING := 4.0
const MAX_LINES := 3
const WIDTH := 680.0            # centred on the stage
const BOTTOM := 24.0            # under the last line
const SHADE_HEIGHT := 172.0     # at the default size; grows with the text
const BORDER_COLOR := Color8(8, 12, 20)   # the text border (setting "border"), the shade's colour
## Text colour per style (frame label).
const COLORS := {"speaking": 0xFFF7F0, "thought": 0xECEBF4, "him": 0xC4DCFF}
const FRAME_LABEL := {1: "speaking", 2: "thought", 3: "him"}
## The text container's placement (and so its glow) per style: speaking and thought share one.
const PLACEMENT := {"speaking": "light", "thought": "light", "him": "dark"}

var _shade = null
var _box_mods := false   # a dialogue box mod is on (extramod): the game's box while it is
var _fonts := {}
var _filters: Array = []
## The game's look, kept to put it back: tfContainer position, the field's box, the container's filters per style.
var _orig := {}
var _orig_filters := {}


func _init() -> void:
	id = "subtitles"
	title = "Subtitles"
	description = "Dialogue as subtitles along the bottom of the screen instead of the game's speech box."
	default_enabled = true


func _setup() -> void:
	setting("look", LOOKS[0], {"label": "Dialogue look", "options": LOOKS,
		"desc": "Subtitles: her and his lines as text over a soft shade along the bottom of the screen. Classic box: the game's speech box."})
	setting("size", DEFAULT_SIZE, {"label": "Subtitle size", "min": 14, "max": 32,
		"desc": "Text size of the subtitles."})
	setting("border", 0, {"label": "Subtitle border", "min": 0, "max": 8,
		"desc": "Width of a dark border around the letters of the subtitles (0: none). Makes them easier to read on light backgrounds."})


func _enable() -> void:
	_filters = [FlashFilter.dropShadow(2.0, 90.0, 0x000000, 0.6, 6.0, 6.0, 1.0, 2),
		FlashFilter.glow(0x000000, 0.45, 2.0, 2.0, 1.0, 2)]
	hook_after(&"Dialogue.gotoStyle", func(c): _style(c.obj, c.args[0]))
	hook_after(&"Dialogue.updateTextField", func(c): _place_text(c.obj))
	on_tick(_tick)
	menu_control("dialogue", "Dialogue", MenuSchema.choice("Dialogue look",
		"Subtitles: her and his lines as text over a soft shade along the bottom of the screen. Classic box: the game's speech box. A dialogue box mod shows the Classic box while it is on.",
		LOOKS, func(): return LOOKS[1] if _box_mods else str(get_setting("look")), func(v: String): set_setting("look", v)))
	menu_control("dialogue", "Dialogue", MenuSchema.setting_control(self, "size"))
	menu_control("dialogue", "Dialogue", MenuSchema.setting_control(self, "border"))
	var em = Extensions.get_extension("extramod")
	_box_mods = em != null and em.enabled and em._dia_mods
	_refresh()


func _disable() -> void:
	_classic(g.dialogueControl)


func _setting_changed(_key: String, _value) -> void:
	_refresh()


func _active() -> bool:
	return get_setting("look") == LOOKS[0] and not _box_mods


## Called by extramod when a dialogue box mod comes on or goes off: such a mod is drawn for the game's box, so the
## Classic box shows while one is on (the setting stays as the player chose it).
func box_mods(on: bool) -> void:
	if on != _box_mods:
		_box_mods = on
		_refresh()


func _size() -> float:
	return float(get_setting("size"))


## Applies the current setting to the dialogue as it is now.
func _refresh() -> void:
	var dc = g.dialogueControl
	if dc == null:
		return
	if _active():
		_style(dc, FRAME_LABEL.get(dc.currentFrame, "speaking"))
		_place_text(dc)
	else:
		_classic(dc)


func _font(italic: bool) -> Font:
	var key := "italic" if italic else "regular"
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = FONT_ITALIC if italic else FONT
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):
			THOUGHT_WEIGHT if italic else WEIGHT}
		_fonts[key] = fv
	return _fonts[key]


func _style(dc: Dialogue, label: String) -> void:
	if not _active():
		return
	var tfc: FlashMovieClip = dc.tfContainer
	var field: FlashTextField = tfc.dialogueField
	if _orig.is_empty():
		_orig = {"tfc": Vector2(tfc.x, tfc.y), "field": Rect2(field.x, field.y, field.width, field.height)}
	# the timeline puts the game's glow back when the placement changes; keep it for going back
	var cur: Array = tfc.filters
	if not (cur.size() > 0 and cur[0] == _filters[0]):
		_orig_filters[PLACEMENT.get(label, label)] = cur
	for i in dc.numChildren:
		var c = dc.getChildAt(i)
		if c is FlashShape and Dialogue.BOX_FILL_ALPHA.has(c._char_id):
			c.visible = false
	if _shade == null or not is_instance_valid(_shade):
		_shade = Shade.new()
		dc.addChildAt(_shade, 0)
		dc.set_meta(&"subtitle_shade", _shade)
	tfc.filters = _filters
	tfc.x = g.screenSize.x / 2.0
	field.embolden = 0.0
	field.outline_size = int(get_setting("border"))
	field.outline_color = BORDER_COLOR
	var fmt := {"size": _size(), "align": "center", "color": COLORS.get(label, COLORS["speaking"]), "leading": LEADING,
		"letterSpacing": 0.0}
	if field.embedFonts:   # not a font a dialogue chose (extramod [EM_FONT...])
		fmt["font"] = _font(label == "thought")
		field.glyph_font = dc.originalFont if dc.originalFont is Font else null
	field.setTextFormat(fmt)
	field.x = -WIDTH / 2.0
	field.y = 0.0
	field.width = WIDTH
	field.height = MAX_LINES * _line_height(field) + 4.0
	_update_shade(dc)
	_place_text(dc)


func _line_height(field: FlashTextField) -> float:
	var f: Font = field.defaultTextFormat["font"]
	if f == null:
		f = ThemeDB.fallback_font
	return f.get_height(int(round(_size()))) + LEADING


## The text block sits on the bottom margin: its last line stays in place as lines are added.
func _place_text(dc: Dialogue) -> void:
	if not _active() or _shade == null:
		return
	var field: FlashTextField = dc.tfContainer.dialogueField
	var n := clampi(field.numLines, 1, MAX_LINES)
	dc.tfContainer.y = -BOTTOM - n * _line_height(field) + LEADING - FlashTextField.GUTTER


func _tick() -> void:
	if _shade != null and is_instance_valid(_shade) and _active():
		_update_shade(g.dialogueControl)


func _update_shade(dc: Dialogue) -> void:
	# the dialogue sits at the stage's bottom left (0, 600); the shade spans the window's width
	var pr: Rect2 = Flash.presentation_rect
	var h := SHADE_HEIGHT * _size() / DEFAULT_SIZE
	var bottom := pr.end.y - dc.y
	_shade.set_rect(Rect2(pr.position.x - dc.x, bottom - h, pr.size.x, h))


## Back to the game's box.
func _classic(dc) -> void:
	if dc == null:
		return
	if _shade != null and is_instance_valid(_shade):
		if _shade._flash_parent != null:
			_shade._flash_parent.removeChild(_shade)
		_shade.queue_free()
	_shade = null
	if dc.has_meta(&"subtitle_shade"):
		dc.remove_meta(&"subtitle_shade")
	if _orig.is_empty():
		return
	var tfc: FlashMovieClip = dc.tfContainer
	var field: FlashTextField = tfc.dialogueField
	var label: String = FRAME_LABEL.get(dc.currentFrame, "speaking")
	for i in dc.numChildren:
		var c = dc.getChildAt(i)
		if c is FlashShape and Dialogue.BOX_FILL_ALPHA.has(c._char_id):
			c.visible = true
	var place: String = PLACEMENT.get(label, label)
	if _orig_filters.has(place):
		tfc.filters = _orig_filters[place]
	tfc.x = _orig["tfc"].x
	tfc.y = _orig["tfc"].y
	var r: Rect2 = _orig["field"]
	field.glyph_font = null
	field.outline_size = 0
	var fmt: Dictionary = dc.originalTextFormat.duplicate()
	if not field.embedFonts:
		fmt.erase("font")
	field.setTextFormat(fmt)
	field.x = r.position.x
	field.y = r.position.y
	field.width = r.size.x
	field.height = r.size.y
	dc._gotoStyle(label)   # box opacity and text thickening as the game sets them
	dc.updateTextField()
	_orig = {}
	_orig_filters = {}
