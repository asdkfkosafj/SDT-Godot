class_name SDTMenu
extends CanvasLayer
## Port addition (not in the original game): the new in-game menu. A panel docked on one side of the screen with
## a list of sections, search, labelled controls and a help line for whatever the mouse is over; a MENU tab on the
## screen edge (shown when the mouse comes close) opens it.
##
## It does not duplicate game logic: the controls (MenuSchema) call the classic menu's handlers (InGameMenu), which
## stays the controller and is only hidden. The classic menu comes back with Settings > Menu > Classic menu, and
## always in Vanilla mode. Extensions add controls with SDTExtension.menu_control() / menu_setting(); each
## extension's settings also get a generated page (Mods > Extensions > Settings).

const WIDTH := 290.0
const NAV_W := 64.0
const EDGE_ZONE := 60.0       # how close (stage pixels) the mouse must come to the edge to show the MENU tab
const TAB_SECTIONS := {1: "her", 2: "clothes", 3: "mods", 4: "settings", 5: "help"}   # Y U I O P

static var instance: SDTMenu = null
static var dev = null                  # the developer panel (DevMenu), made when Developer mode is first on
static var _ext_controls: Array = []   # specs added by extensions: {"section", "group", "owner", ...}
static var open_popups := 0            # colour pickers etc. open (they block the scene's mouse input too)

var is_open := false
var section := "her"
var query := ""
var sections: Array = []

var _root: Control
var _dock: PanelContainer
var _nav: VBoxContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _search: LineEdit
var _help: Label
var _heading: Label
var _back: Button
var _tab: Button
var _popups: Control
var _rows: Array = []
var _cache: Dictionary = {}   # section id -> its built view (VBoxContainer with a "rows" meta)
var _cache_sig := ""
var _search_view: Control = null
static var _controls_version := 0
var _nav_buttons: Dictionary = {}
var _tab_t := 0.0             # 0 hidden .. 1 shown
var _frame := 0
## Open menu: every row re-reads its value this often (by time: a frame count re-read every option ~150 times a
## second at high frame rates)
const REFRESH_SECONDS := 0.1
var _refresh_t := 0.0
var _paused_by_menu := false
var classic_button   # the classic menu's "New menu" button


# ---------------------------------------------------------------- setup

## Called once the game is built (end of DT.initGame, after the extensions started).
static func start() -> void:
	if instance != null:
		return
	instance = SDTMenu.new()
	instance.name = "SDTMenu"   # named: an auto-generated name would shift the numbering of the game's nodes
	Flash.add_child(instance)
	Flash.mouse_blocker = instance.blocks_mouse
	instance._add_classic_button()
	instance.apply_mode()


## The classic menu's way back: a "New menu" button in its Options tab, under Mirrored (a copy of the Clear All
## button). It turns Classic menu and Vanilla mode off and opens the new menu.
func _add_classic_button() -> void:
	var om = g.inGameMenu.optionsMenu
	var src = om.mbClearAll
	var b = Flash.create_char(src._library, src._char_id)
	om.addChild(b)
	classic_button = b
	var cb: Rect2 = om.cbMirrored.getBounds(om)
	var bb: Rect2 = b.getBounds(b)
	b.x = cb.position.x - bb.position.x
	b.y = cb.end.y + 8 - bb.position.y
	var label = b.labelContainer.buttonLabel
	label.wordWrap = false
	label.text = "New menu"
	# the button is made wider for the longer label (the label is scaled back, so the text keeps its size)
	var k := 1.6
	var center: float = b.getBounds(b).get_center().x
	b.scaleX = k
	b.labelContainer.scaleX = 1.0 / k
	b.labelContainer.x = center - label.textWidth / 2.0 / k - label.x / k - 2.0 / k
	b.x += cb.position.x - b.getBounds(om).position.x
	b.addEventListener(FlashEvent.CLICK, func(_e = null):
		g.inGameMenu.closeMenu()
		PortSettings.set_value("menu", "classic", false)
		if Extensions.vanilla_mode:
			Extensions.set_vanilla_mode(false)
		apply_mode()
		open_menu("settings"))


## Whether the new menu replaces the classic one right now.
## See-through (the menualphatoggle extension): the panel's background at `bg_alpha`; the section buttons and the
## help line get boxes of their own, so they stay readable over the game.
func set_see_through(on: bool, bg_alpha := 0.25) -> void:
	if _dock == null:
		return
	_dock.self_modulate.a = bg_alpha if on else 1.0
	var clear := Color(0, 0, 0, 0)
	for b in _nav.get_children():
		if b is Button:
			b.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.CARD if on else clear, clear, 4, 5, 3))
	if on:
		_help.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.CARD, clear, 4, 5, 3))
	else:
		_help.remove_theme_stylebox_override("normal")


static func active() -> bool:
	return instance != null and not Extensions.vanilla_mode and not classic()


static func classic() -> bool:
	return bool(PortSettings.get_value("menu", "classic", false))


## Developer mode (Settings > Menu), off by default. Its panel (DevMenu) opens on the side opposite the menu.
static func dev_mode_enabled() -> bool:
	return bool(PortSettings.get_value("developer", "enabled", false))


static func set_dev_mode(on: bool) -> void:
	PortSettings.set_value("developer", "enabled", on)
	_sync_dev()


## Makes the developer panel the first time it is needed (never in Vanilla mode or with the classic menu).
static func _sync_dev() -> void:
	if dev == null and instance != null and active() and dev_mode_enabled():
		dev = DevMenu.new()
		dev.name = "DevMenu"
		Flash.add_child(dev)
		dev._ensure_built()
	if dev != null:
		dev.apply_mode()


static func on_left() -> bool:
	return PortSettings.get_value("menu", "side", "Right") == "Left"


static func pause_on_open() -> bool:
	return bool(PortSettings.get_value("menu", "pause", true))


# What a second panel built on this one (DevMenu) changes.
func _left() -> bool:
	return on_left()


func _enabled() -> bool:
	return active()


func _make_sections() -> Array:
	return MenuSchema.sections()


func _search_pool() -> Array:
	return sections + MenuSchema.extension_pages()


func _home() -> String:
	return "her"


func _title() -> String:
	return "Menu"


func _search_hint() -> String:
	return "Search all options"


func _tab_label() -> String:
	return "M\nE\nN\nU"


func _pauses() -> bool:
	return pause_on_open()


func _default_help() -> String:
	return DEFAULT_HELP


## The built panels: the menu and (once made) the developer panel.
static func panels() -> Array:
	var out: Array = []
	for p in [instance, dev]:
		if p != null and p._root != null:
			out.append(p)
	return out


## True if the other panel's open dock or visible tab is under `pos`.
func _over_other(pos: Vector2) -> bool:
	for p in panels():
		if p == self:
			continue
		if p.is_open and p._dock.get_global_rect().has_point(pos):
			return true
		if p._tab.visible and p._tab.get_global_rect().has_point(pos):
			return true
	return false


## How far an open panel docked on the left reaches (0 if none): the FPS counter moves beside it.
static func left_inset() -> float:
	var x := 0.0
	for p in panels():
		if p.is_open and p._left():
			x = maxf(x, p._dock.get_global_rect().end.x)
	return x


func _ready() -> void:
	layer = 50


## The UI is built the first time the new menu is used (in Vanilla mode or with the classic menu it never is).
func _ensure_built() -> void:
	if _root != null:
		return
	sections = _make_sections()
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = MenuTheme.get_theme()
	add_child(_root)

	_dock = PanelContainer.new()
	_dock.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.PANEL, Color(0, 0, 0, 0), 0, 0, 0))
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dock)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_dock.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	var head_m := _margin(head, 7, 6, 7, 6)
	v.add_child(head_m)
	var title := Label.new()
	title.text = _title()
	title.add_theme_font_size_override("font_size", MenuTheme.TITLE)
	head.add_child(title)
	_search = LineEdit.new()
	_search.placeholder_text = _search_hint()
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.focus_entered.connect(func(): g.inTextField = true)
	_search.focus_exited.connect(func(): g.inTextField = false)
	_search.text_changed.connect(func(t): query = t.strip_edges(); _show())
	head.add_child(_search)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "Close the menu"
	close.custom_minimum_size = Vector2(18, 18)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_menu)
	head.add_child(close)
	v.add_child(_line())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var nav_scroll := ScrollContainer.new()
	nav_scroll.custom_minimum_size.x = NAV_W
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_nav = VBoxContainer.new()
	_nav.add_theme_constant_override("separation", 1)
	_nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_scroll.add_child(_margin(_nav, 3, 4, 3, 4))
	body.add_child(nav_scroll)
	var vline := ColorRect.new()
	vline.color = MenuTheme.LINE
	vline.custom_minimum_size.x = 1
	body.add_child(vline)
	var group := ButtonGroup.new()
	for s in sections:
		if s.get("hidden", false):
			continue
		var b := Button.new()
		b.text = s["name"]
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", MenuTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 5, 3))
		b.add_theme_stylebox_override("hover", MenuTheme.box(MenuTheme.CARD, Color(0, 0, 0, 0), 4, 5, 3))
		b.add_theme_stylebox_override("pressed", MenuTheme.box(MenuTheme.ACCENT, Color(0, 0, 0, 0), 4, 5, 3))
		b.add_theme_stylebox_override("hover_pressed", MenuTheme.box(MenuTheme.ACCENT, Color(0, 0, 0, 0), 4, 5, 3))
		b.add_theme_color_override("font_color", MenuTheme.MUTED)
		var sid: String = s["id"]
		b.pressed.connect(func(): show_section(sid))
		_nav.add_child(b)
		_nav_buttons[sid] = b

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	_back = Button.new()
	_back.text = "‹ Back"
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(func(): show_section("mods"))
	top.add_child(_back)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", MenuTheme.TITLE - 1)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.clip_text = true
	top.add_child(_heading)
	cv.add_child(top)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_child(_content)
	_scroll.add_child(_margin(cv, 7, 6, 9, 10))

	v.add_child(_line())
	_help = Label.new()
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(WIDTH - 16, 34)
	_help.add_theme_color_override("font_color", MenuTheme.MUTED)
	_help.add_theme_font_size_override("font_size", MenuTheme.SMALL + 1)
	v.add_child(_margin(_help, 8, 5, 8, 6))
	_show_help(null)

	_tab = Button.new()
	_tab.text = _tab_label()
	_tab.focus_mode = Control.FOCUS_NONE
	_tab.custom_minimum_size = Vector2(20, _tab_height())
	_tab.add_theme_font_size_override("font_size", MenuTheme.SMALL + 1)
	_tab.pressed.connect(func(): open_menu())
	_root.add_child(_tab)
	_popups = Control.new()
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_popups)
	_layout()
	_dock.visible = false
	_tab.visible = false


## Popups that do not belong to a row (lists, dialogs); closed with the menu.
func add_popup(p: Window) -> void:
	_popups.add_child(p)


func _margin(c: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(c)
	return m


func _line() -> ColorRect:
	var l := ColorRect.new()
	l.color = MenuTheme.LINE
	l.custom_minimum_size.y = 1
	return l


func _tab_height() -> float:
	return 16.0 * (_tab_label().count("\n") + 1)


## Places the dock and the tab on the chosen side.
func _layout() -> void:
	var left := _left()
	_dock.anchor_top = 0
	_dock.anchor_bottom = 1
	_dock.offset_top = 0
	_dock.offset_bottom = 0
	_dock.anchor_left = 0 if left else 1
	_dock.anchor_right = 0 if left else 1
	_dock.offset_left = 0 if left else -WIDTH
	_dock.offset_right = WIDTH if left else 0
	# content wider than WIDTH widens the dock towards the scene, never past the window's edge
	_dock.grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
	var r := MenuTheme.box(MenuTheme.PANEL, Color(0, 0, 0, 0), 0, 3, 6)
	if left:
		r.corner_radius_top_right = 6
		r.corner_radius_bottom_right = 6
	else:
		r.corner_radius_top_left = 6
		r.corner_radius_bottom_left = 6
	_tab.add_theme_stylebox_override("normal", r)
	var rh := r.duplicate()
	rh.bg_color = MenuTheme.CARD
	_tab.add_theme_stylebox_override("hover", rh)
	_tab.anchor_top = 0.5
	_tab.anchor_bottom = 0.5
	_tab.offset_top = -_tab_height() / 2.0
	_tab.offset_bottom = _tab_height() / 2.0
	_place_tab()


func _place_tab() -> void:
	var w := 20.0
	var shown := w * _tab_t
	if _left():
		_tab.anchor_left = 0
		_tab.anchor_right = 0
		_tab.offset_left = shown - w
		_tab.offset_right = shown
	else:
		_tab.anchor_left = 1
		_tab.anchor_right = 1
		_tab.offset_left = -shown
		_tab.offset_right = w - shown


## Shows the new or the classic menu, as the settings say (after Vanilla mode or Classic menu changed).
func apply_mode() -> void:
	var on := active()
	if on:
		_ensure_built()
	if g.inGameMenu != null:
		if on and g.inGameMenu.menuOpen:
			g.inGameMenu.closeMenu()
			g.inGameMenu.finishSlideout()   # it is hidden: no need to watch it slide away
		g.inGameMenu.visible = not on
	if _root == null:
		return
	if not on:
		if is_open:
			close_menu()
		_tab.visible = false
	_layout()
	_sync_dev()


# ---------------------------------------------------------------- open / close

func open_menu(sec := "") -> void:
	if not _enabled():
		return
	if sec != "":
		section = sec
	if not is_open:
		is_open = true
		_dock.visible = true
		_paused_by_menu = _pauses()
		if _paused_by_menu:
			g.gamePaused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show()


func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	_dock.visible = false
	_search.release_focus()
	g.inTextField = false
	if _paused_by_menu:
		g.gamePaused = false
	_paused_by_menu = false
	if not g.showMouse and g.gameRunning and not panels().any(func(p): return p.is_open):
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_close_popups(_content)   # colour pickers belong to the rows
	for p in _popups.get_children():
		p.queue_free()
	open_popups = 0


## The classic menu's hotkeys and Options button (InGameMenu.toggleMenu / openMenu) land here.
func toggle_tab(tab: int) -> void:
	var sec: String = TAB_SECTIONS.get(tab, section)
	if is_open and sec == section and query == "":
		close_menu()
	else:
		open_menu(sec)


func show_section(sec: String) -> void:
	section = sec
	query = ""
	_search.text = ""
	_show()


## The pause setting changed: pause or resume now if the menu is open.
func pause_setting_changed() -> void:
	if not is_open:
		return
	var want := pause_on_open()
	if want != _paused_by_menu:
		_paused_by_menu = want
		g.gamePaused = want


func side_setting_changed() -> void:
	if _root != null:
		_layout()
	if self == instance and dev != null:
		dev.side_setting_changed()   # the developer panel takes the other side


# ---------------------------------------------------------------- content

func _find_section(sid: String) -> Dictionary:
	for s in sections:
		if s["id"] == sid:
			return s
	if sid.begins_with("ext:"):
		return MenuSchema.extension_page(sid.substr(4))
	return {}


## A section's groups with the extension controls merged in: [{title, owner, controls}].
func _groups_of(s: Dictionary) -> Array:
	var out: Array = []
	for grp in s.get("groups", []):
		out.append({"title": grp["title"], "owner": grp.get("owner", ""), "controls": grp["controls"].duplicate()})
	for spec in _ext_controls:
		if spec.get("section", "") != s["id"]:
			continue
		var target = null
		for grp in out:
			if grp["title"] == spec.get("group", ""):
				target = grp
				break
		if target == null:   # a group of the extension's own: its tag on the heading, not on every row
			target = {"title": spec.get("group", spec.get("owner", "")), "owner": spec.get("owner", ""), "controls": []}
			out.append(target)
		if target["owner"] != "" and target["owner"] == spec.get("owner", ""):
			spec = spec.duplicate()
			spec["tagless"] = true
		# "after": the label of the row to follow (after the rows already placed there); the group's end otherwise
		var at := -1
		var after: String = spec.get("after", "")
		if after != "":
			for i in target["controls"].size():
				var c: Dictionary = target["controls"][i]
				if c.get("label") == after:
					at = i + 1
				elif at == i and c.get("after", "") == after:
					at = i + 1
		if at >= 0:
			target["controls"].insert(at, spec)
		else:
			target["controls"].append(spec)
	return out


func _show() -> void:
	if not is_open:
		return
	var sig := _signature()
	if sig != _cache_sig:   # extensions switched on or off, or their controls changed: rebuild every section
		invalidate()
		_cache_sig = sig
	if _search_view != null:
		_search_view.queue_free()
		_search_view = null
	var view: Control
	var s := {}
	if query != "":
		var q := query.to_lower()
		var groups: Array = []
		for sec in _search_pool():
			for grp in _groups_of(sec):
				var hits: Array = grp["controls"].filter(func(c): return _matches(c, q, grp["title"], sec["name"]))
				if not hits.is_empty():
					groups.append({"title": sec["name"] + " › " + grp["title"], "owner": grp["owner"], "controls": hits})
		var n: int = groups.reduce(func(a, gr): return a + gr["controls"].size(), 0)
		_heading.text = "%d %s for “%s”" % [n, "option" if n == 1 else "options", query]
		_back.visible = false
		view = _build_view(groups, "Nothing matches. Try a word from what an option does, like “eyes”, “clean” or “pause”.")
		_search_view = view
	else:
		s = _find_section(section)
		if s.is_empty():
			section = _home()
			s = _find_section(section)
		_heading.text = s["name"]
		_back.visible = s.get("hidden", false)
		view = _cache.get(section)
		if view == null:
			view = _build_view(_groups_of(s), "", s)
			_cache[section] = view
	for v in _content.get_children():
		v.visible = v == view
	_rows = view.get_meta("rows")
	_pump(view, BUILD_BUDGET_US)
	var nav_id: String = s.get("parent", s.get("id", "")) if query == "" else ""
	for sid in _nav_buttons:
		_nav_buttons[sid].set_pressed_no_signal(sid == nav_id)
		_nav_buttons[sid].add_theme_color_override("font_color", MenuTheme.INK if sid == nav_id else MenuTheme.MUTED)
	_refresh_rows()
	if query == "":
		_scroll.scroll_vertical = 0


## One section's (or the search results') cards, added to the content and kept for the next visit. The cards are
## made now; their rows are built a few per frame (_pump), so opening a big section never stalls a frame. A section
## with "fold" ({group title: folded at first}) gets a fold button and a reset button on each card (MenuFold; not in
## search results).
func _build_view(groups: Array, empty_text: String, sec := {}) -> Control:
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 6)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pending: Array = []   # [card's VBoxContainer, spec]
	for grp in groups:
		var specs: Array = grp["controls"].filter(_shown)
		if specs.is_empty():
			continue
		var card := PanelContainer.new()
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		card.add_child(cv)
		var h := HBoxContainer.new()
		# title, count and tag wrap (the tag goes to a second line) instead of widening the dock past the window
		var title := HFlowContainer.new()
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_constant_override("h_separation", 5)
		title.add_theme_constant_override("v_separation", 2)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(title)
		var hl := Label.new()
		hl.text = str(grp["title"]).to_upper()
		hl.add_theme_font_size_override("font_size", MenuTheme.HEADING)
		hl.add_theme_color_override("font_color", MenuTheme.MUTED)
		title.add_child(hl)
		if grp["owner"] != "":
			title.add_child(MenuWidgets.tag(grp["owner"]))
		cv.add_child(h)
		view.add_child(card)
		var body: VBoxContainer = cv
		if sec.has("fold"):
			body = MenuFold.card(h, hl, cv, sec, grp, specs, _refresh_rows)
		for spec in specs:
			pending.append([body, spec])
	if pending.is_empty() and empty_text != "":
		var l := Label.new()
		l.text = empty_text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", MenuTheme.MUTED)
		view.add_child(l)
	view.set_meta("rows", [])
	view.set_meta("pending", pending)
	_content.add_child(view)
	return view


## Controls of extensions that are off are not shown.
static func _shown(spec: Dictionary) -> bool:
	return spec.get("owner", "") == "" or Extensions.is_on(spec["owner"])


const BUILD_BUDGET_US := 3000       # per frame, for the section on screen
const PREBUILD_BUDGET_US := 1500    # per frame, for the other sections while the menu is open


## Builds pending rows of `view` for up to `budget` microseconds; returns true when the view is complete.
func _pump(view: Control, budget: int) -> bool:
	var pending: Array = view.get_meta("pending")
	var rows: Array = view.get_meta("rows")
	var t0 := Time.get_ticks_usec()
	while not pending.is_empty() and Time.get_ticks_usec() - t0 < budget:
		var item: Array = pending.pop_front()
		var row := MenuWidgets.build(item[1], _show_help)
		item[0].add_child(row)
		rows.append(row)
		row.get_meta("refresh").call()
	return pending.is_empty()


## Builds everything pending at once (tests).
func build_now() -> void:
	for v in _content.get_children():
		if v.has_meta("pending"):
			_pump(v, 1 << 30)


## While the menu is open: finish the section on screen, then build the sections not visited yet.
func _pump_frame() -> void:
	var cur: Control = _search_view if _search_view != null else _cache.get(section)
	if cur != null and not _pump(cur, BUILD_BUDGET_US):
		return
	for sec in sections:   # one section per frame
		var sid: String = sec["id"]
		if not _cache.has(sid):
			var v := _build_view(_groups_of(sec), "", sec)
			v.visible = false
			_cache[sid] = v
			return
		if not _cache[sid].get_meta("pending").is_empty():
			_pump(_cache[sid], PREBUILD_BUDGET_US)
			return


## Drops the built sections (they are rebuilt when shown).
func invalidate() -> void:
	for v in _cache.values():
		v.queue_free()
	_cache.clear()


func _signature() -> String:
	var on: Array = []
	for ext in Extensions.all:
		if ext.enabled:
			on.append(ext.id)
	return "%s|%d" % [",".join(on), _controls_version]


## Closes colour pickers and other popups that belong to rows.
func _close_popups(n: Node) -> void:
	for c in n.get_children():
		if c is Popup:
			if c.visible:
				c.hide()
		elif c.get_child_count() > 0:
			_close_popups(c)


func _matches(spec: Dictionary, q: String, group: String, sec: String) -> bool:
	var hay := (str(spec.get("label", "")) + " " + str(spec.get("tip", "")) + " " + group + " " + sec + " "
		+ str(spec.get("owner", "")) + " " + str(spec.get("keywords", ""))).to_lower()
	for b in spec.get("buttons", []):
		hay += " " + str(b[0]).to_lower() + " " + (str(b[2]).to_lower() if b.size() > 2 else "")
	for word in q.split(" ", false):
		if hay.find(word) < 0:
			return false
	return true


func _refresh_rows() -> void:
	for r in _rows:
		if is_instance_valid(r) and r.has_meta("refresh"):
			r.get_meta("refresh").call()


const DEFAULT_HELP := "Point at an option to see what it does. Search finds options in every section; orange dots and tags mark options added by an extension."


func _show_help(spec) -> void:
	if spec == null:
		_help.text = _default_help()
		return
	var who := " (%s)" % spec["owner"] if spec.get("owner", "") != "" else ""
	var tip := str(spec.get("tip", ""))
	_help.text = "%s%s%s" % [spec.get("label", ""), who, ": " + tip if tip != "" else ""]


# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	if _root == null or not _enabled():
		return
	_frame += 1
	if is_open:
		_pump_frame()
		_refresh_t += delta
		if _refresh_t >= REFRESH_SECONDS:
			_refresh_t = 0.0
			_refresh_rows()
		_tab_t = 0.0
		_tab.visible = false
		return
	# the MENU tab slides in while the mouse is near its edge
	var m := _root.get_local_mouse_position()
	var w := _root.size.x
	var near: bool = (m.x < EDGE_ZONE if _left() else m.x > w - EDGE_ZONE) and m.y >= 0 and m.y <= _root.size.y \
		and g.gameRunning and not g.controlLocked
	_tab_t = move_toward(_tab_t, 1.0 if near else 0.0, delta * 8.0)
	_tab.visible = _tab_t > 0.0
	_place_tab()


func _input(event: InputEvent) -> void:
	if outside_click(event):
		for p in panels():   # a click on the scene closes both panels (a handled click reaches only this one)
			if p == self or p.outside_click(event):
				p.close_menu()
		get_viewport().set_input_as_handled()   # the click only closes the menu, it does not reach the scene
		return
	if is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _search.has_focus() and _search.text != "":
			_search.text = ""
			query = ""
			_show()
		else:
			close_menu()
		get_viewport().set_input_as_handled()


## True for a mouse press outside the open dock (no colour picker / dropdown open): it closes the menu.
func outside_click(event: InputEvent) -> bool:
	if not is_open or open_popups > 0 or not (event is InputEventMouseButton and event.pressed):
		return false
	var b: MouseButton = event.button_index
	if b == MOUSE_BUTTON_WHEEL_UP or b == MOUSE_BUTTON_WHEEL_DOWN or b == MOUSE_BUTTON_WHEEL_LEFT 			or b == MOUSE_BUTTON_WHEEL_RIGHT:
		return false
	if _over_other(event.position):   # the other panel: clicking it keeps this one open
		return false
	return not _dock.get_global_rect().has_point(event.position)


## Flash input skips mouse presses and moves over the dock and the tab (Flash.mouse_blocker), so clicking the menu
## does not also click the scene behind it.
func blocks_mouse() -> bool:
	if self == instance and dev != null and dev.blocks_mouse():   # Flash.mouse_blocker asks the menu only
		return true
	if self == instance and DialogueEditorPanel.instance != null and DialogueEditorPanel.instance.blocks_mouse():
		return true
	if _root == null or not _enabled():
		return false
	var p := _root.get_global_mouse_position()
	if is_open and _dock.get_global_rect().has_point(p):
		return true
	if _tab.visible and _tab.get_global_rect().has_point(p):
		return true
	return open_popups > 0


# ---------------------------------------------------------------- extension controls

static func add_control(spec: Dictionary) -> void:
	_ext_controls.append(spec)
	_controls_version += 1
	if instance != null and instance.is_open:
		instance._show()


static func remove_owner(owner: String) -> void:
	_ext_controls = _ext_controls.filter(func(s): return s.get("owner", "") != owner)
	_controls_version += 1
	if instance != null and instance.is_open:
		instance._show()
