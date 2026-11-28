extends RefCounted
## The Positions page of the menu (MenuSchema's "positions" section, shown while the extension is on): the game's
## default, a random position, rescan; a dominance filter; a Find field; then the positions by folder
## (PositionLibrary.category), each folder a fold with a grid of thumbnails, the player's favourites first. A click
## loads the position with the transition (Positions.request); a right-click makes it a favourite (or not).
## While Find has text, every folder with a match shows it (the folds stay as they were for later).
##
## Thumbnails (700x600 .png files next to the .txt) are read and made small on worker threads when a folder first
## opens, so opening the page never stalls a frame; they stay in memory (~10 MB for the shipped set at 2x).

const COLS := 2
const CELL := Vector2(94, 96)      # stage pixels: the picture (94 x 80) and a line for the name
const PIC_H := 80.0
const LOAD := Vector2i(188, 160)   # the size thumbnails are kept at (2x: the window scales the stage up)
const FOLD_CFG := "positions_fold"
const DOMINANCE := ["All", "Him", "Her", "Neutral"]
const FAVOURITES := "Favourites"   # the folder of the player's favourites (shown first)

var _ext
var filter := "All"
var query := ""   # Find: part of a name (no case)

static var _thumbs: Dictionary = {}    # .png path -> Texture2D (null: not readable)
static var _waiting: Dictionary = {}   # .png path -> [TextureRect] while it loads


func _init(ext) -> void:
	_ext = ext


func start() -> void:
	var ext = _ext
	ext.menu_control("positions", "Position", {"type": "custom", "label": "", "build": _current_label})
	ext.menu_control("positions", "Position", MenuSchema.actions("", "", [
		["Game's default", func(): ext.request_default(), "Back to the game's own animation."],
		["Random", func(): ext.random(), "A random position (not a partial one)."],
		["Rescan", func(): ext.rescan(), "Reads the Mods/Positions folder again (after you add or change files)."],
		["Edit", func(): ext.editor.begin(), "Opens the position editor on the current position (a new one at the game's default)."],
		["New", func(): ext.editor.begin(true), "Opens the position editor on a new position from the game's default values."]],
		{"keywords": "position animtools default random reload"}))
	ext.menu_control("positions", "Position", MenuSchema.setting_control(ext, "transition"))
	ext.menu_control("positions", "Position", MenuSchema.setting_control(ext, "random_from"))
	ext.menu_control("positions", "Position", {"type": "chips", "label": "Who leads",
		"tip": "Shows only the positions where he leads (HimD folders), she leads (HerD) or neither.",
		"options": DOMINANCE, "get": func(): return filter, "set": func(v: String): filter = v,
		"keywords": "dominance dominant filter"})
	ext.menu_control("positions", "Browse", {"type": "text", "label": "Find", "placeholder": "part of a name",
		"live": true, "tip": "Shows only the positions whose name or folder has this text.",
		"get": func(): return query, "set": func(t: String): query = t.strip_edges(), "keywords": "search find name"})
	ext.menu_control("positions", "Browse", {"type": "custom", "label": "", "build": _grid,
		"keywords": "position animtools oral anal vaginal titfuck browse"})


# ---------------------------------------------------------------- the current position

func _current_label() -> Control:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", MenuTheme.MUTED)
	l.set_meta("refresh", func():
		var t := "Now: the game's default"
		if _ext.current != null:
			var n: String = _ext.current.name
			if n == "":
				t = "Now: the game's default, changed by a partial position"
			else:
				t = "Now: %s (%s)" % [_ext.library.short_name(n), _ext.library.category(n)] if _ext.library.has(n) else "Now: " + n
		if _ext.missing != "":
			t += "\nNot found in Mods/Positions: \"%s\" (asked for by a character or a dialogue)." % _ext.missing
		if l.text != t:
			l.text = t)
	l.get_meta("refresh").call()
	return l


# ---------------------------------------------------------------- the folders and thumbnails

func _grid() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var state := {"version": -1, "fav": -1, "filter": "", "query": "", "current": null, "folds": {}}
	box.set_meta("refresh", func(): _refresh(box, state))
	_refresh(box, state)
	return box


func _refresh(box: VBoxContainer, state: Dictionary) -> void:
	var lib = _ext.library
	if state["version"] != lib.version or state["fav"] != _ext.fav_serial:
		state["version"] = lib.version
		state["fav"] = _ext.fav_serial
		state["filter"] = ""
		state["current"] = null
		_rebuild(box, state)
	var cur: String = "" if _ext.current == null else _ext.current.name
	if state["filter"] != filter or state["current"] != cur or state["query"] != query:
		state["filter"] = filter
		state["current"] = cur
		state["query"] = query
		for f in state["folds"].values():
			for cell in f["cells"]:
				_show_cell(cell, cur)
			var shown: int = f["names"].filter(_shows).size()
			var open: bool = not f["folded"] or query != ""
			f["head"].text = "%s %s (%d)" % ["▾" if open else "▸", f["title"], shown]
			f["head"].visible = shown > 0
			f["grid"].visible = open
			if open:
				_build_cells(f)


## A position the filter and Find let through.
func _shows(n: String) -> bool:
	var lib = _ext.library
	if filter != "All" and lib.dominance(n) != filter:
		return false
	return query == "" or lib.short_name(n).containsn(query) or lib.category(n).containsn(query)


## The folders' headings only; a folder's cells are made when it is first opened, a few per frame (_jobs).
func _rebuild(box: VBoxContainer, state: Dictionary) -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()
	state["folds"] = {}
	var lib = _ext.library
	var by_cat: Dictionary = {}
	for n in lib.names:
		var c: String = lib.category(n)
		if not by_cat.has(c):
			by_cat[c] = []
		by_cat[c].append(n)
	var cats: Array = by_cat.keys()
	cats.sort_custom(func(a, b): return _order(a) < _order(b) if _order(a) != _order(b) else a < b)
	var favs: Array = _ext.favourites()
	if not favs.is_empty():
		by_cat[FAVOURITES] = favs
		cats.push_front(FAVOURITES)
	if cats.is_empty():
		var l := Label.new()
		l.text = "No positions in Mods/Positions."
		l.add_theme_color_override("font_color", MenuTheme.MUTED)
		box.add_child(l)
	for c in cats:
		var f := {"title": c, "names": by_cat[c], "cells": [], "folded": bool(PortSettings.get_value(FOLD_CFG, c, c != FAVOURITES)),
			"built": false}
		var head := Button.new()
		head.flat = true
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.focus_mode = Control.FOCUS_NONE
		head.add_theme_color_override("font_color", MenuTheme.TEXT)
		head.tooltip_text = "Show or hide the positions in this folder."
		f["head"] = head
		box.add_child(head)
		var grid := GridContainer.new()
		grid.columns = COLS
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		grid.visible = not f["folded"]
		f["grid"] = grid
		box.add_child(grid)
		head.pressed.connect(func():
			if query != "":   # Find shows every folder with a match: the folds wait for it to be empty
				return
			f["folded"] = not f["folded"]
			PortSettings.set_value(FOLD_CFG, c, f["folded"])
			grid.visible = not f["folded"]
			state["filter"] = ""   # heading text again
			if not f["folded"]:
				_build_cells(f))
		state["folds"][c] = f
		if not f["folded"] or query != "":
			_build_cells(f)


## Queues the cells of an opened folder (each with its thumbnail) for the next frames.
func _build_cells(f: Dictionary) -> void:
	if f["built"]:
		return
	f["built"] = true
	var grid: GridContainer = f["grid"]
	for n in f["names"]:
		_jobs.append(func():
			if not is_instance_valid(grid):
				return
			var cell := _cell(n)
			grid.add_child(cell)
			f["cells"].append(cell)
			_show_cell(cell, "" if _ext.current == null else _ext.current.name)
			var png: String = cell.get_meta("png")
			if png != "":
				thumbnail(png, cell.get_meta("pic")))
	_start_jobs()


func _show_cell(cell: Button, cur: String) -> void:
	cell.visible = _shows(cell.get_meta("name"))
	_mark(cell, cell.get_meta("name") == cur)


## Folders in animtools' order of types, then the others by name, partial positions last.
static func _order(c: String) -> int:
	var i := ["Oral", "Titfuck", "Vaginal", "Anal", "Other"].find(c.get_slice("/", 0))
	return 99 if c == "Partial" else (i if i >= 0 else 50)


func _cell(n: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CELL
	b.focus_mode = Control.FOCUS_NONE
	var fav: bool = _ext.is_favourite(n)
	b.tooltip_text = n + ("\n(Partial: changes only some parts of the current position.)" if _ext.library.is_partial(n) else "") \
		+ ("\nRight-click: no longer a favourite." if fav else "\nRight-click: make it a favourite.")
	b.set_meta("name", n)
	b.set_meta("png", _ext.library.thumbnail_path(n))
	b.set_meta("marked", false)
	_style(b, false)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 2
	v.offset_top = 2
	v.offset_right = -2
	v.offset_bottom = -1
	b.add_child(v)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size.y = PIC_H - 4
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	b.set_meta("pic", pic)
	var l := Label.new()
	l.text = ("★ " if fav else "") + _ext.library.short_name(n)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", MenuTheme.SMALL)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.pressed.connect(func(): _ext.request(n))
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			_ext.set_favourite(n, not _ext.is_favourite(n))
			b.accept_event())
	return b


static var _styles: Dictionary = {}   # "normal" / "hover" + marked, "pressed" -> StyleBoxFlat (shared by every cell)


static func _mark(b: Button, on: bool) -> void:
	if b.get_meta("marked") != on:
		b.set_meta("marked", on)
		_style(b, on)


static func _style(b: Button, on: bool) -> void:
	if _styles.is_empty():
		for m in [false, true]:
			_styles["normal%s" % m] = MenuTheme.box(MenuTheme.FIELD, MenuTheme.ACCENT if m else MenuTheme.LINE, 4, 0, 0, 2 if m else 1)
			_styles["hover%s" % m] = MenuTheme.box(MenuTheme.CARD, MenuTheme.ACCENT, 4, 0, 0, 2 if m else 1)
		_styles["pressed"] = MenuTheme.box(MenuTheme.CARD, MenuTheme.ACCENT, 4, 0, 0, 2)
	b.add_theme_stylebox_override("normal", _styles["normal%s" % on])
	b.add_theme_stylebox_override("hover", _styles["hover%s" % on])
	b.add_theme_stylebox_override("pressed", _styles["pressed"])


# ---------------------------------------------------------------- work spread over frames

## Cells to make and thumbnails to turn into textures: done in the frames after, up to JOB_BUDGET_US and
## TEXTURES_PER_FRAME each (a folder of 40 at once took ~60 ms: a hitch).
const JOB_BUDGET_US := 1500
const TEXTURES_PER_FRAME := 3
static var _jobs: Array = []
static var _textures: Array = []   # [png, Image] read by the worker threads
static var _running := false


static func _start_jobs() -> void:
	if not _running:
		_running = true
		Flash.get_tree().process_frame.connect(_run_jobs)


static func _run_jobs() -> void:
	var t0 := Time.get_ticks_usec()
	var made := 0
	while not _textures.is_empty() and made < TEXTURES_PER_FRAME and Time.get_ticks_usec() - t0 < JOB_BUDGET_US:
		var tr: Array = _textures.pop_front()
		_thumb_done(tr[0], tr[1])
		made += 1
	while not _jobs.is_empty() and Time.get_ticks_usec() - t0 < JOB_BUDGET_US:
		var job: Callable = _jobs.pop_front()
		if job.is_valid():
			job.call()
	if _jobs.is_empty() and _textures.is_empty() and _waiting.is_empty():
		_running = false
		Flash.get_tree().process_frame.disconnect(_run_jobs)


## Shows the thumbnail `png` in `rect`, read and made small on a worker thread the first time.
static func thumbnail(png: String, rect: TextureRect) -> void:
	if _thumbs.has(png):
		rect.texture = _thumbs[png]
		return
	if _waiting.has(png):
		_waiting[png].append(rect)
		return
	_waiting[png] = [rect]
	WorkerThreadPool.add_task(_read_thumb.bind(png), false, "position thumbnail")
	_start_jobs()


static func _read_thumb(png: String) -> void:
	var img := Image.load_from_file(png)
	if img != null and not img.is_empty():
		var s := Vector2(img.get_size())
		var k := minf(LOAD.x / s.x, LOAD.y / s.y)
		if k < 1.0:
			img.resize(maxi(1, roundi(s.x * k)), maxi(1, roundi(s.y * k)), Image.INTERPOLATE_LANCZOS)
	_queue_texture.call_deferred(png, img)


static func _queue_texture(png: String, img: Image) -> void:
	_textures.append([png, img])
	_start_jobs()


static func _thumb_done(png: String, img: Image) -> void:
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
	_thumbs[png] = tex
	for r in _waiting.get(png, []):
		if is_instance_valid(r):
			r.texture = tex
	_waiting.erase(png)


## Drops the loaded thumbnails (rescan: files may have changed).
static func forget_thumbnails() -> void:
	_thumbs.clear()
