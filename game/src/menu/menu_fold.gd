class_name MenuFold
extends RefCounted
## Port addition: folding cards and a card reset, for menu sections that ask for it with "fold" (Behaviour for now):
## {"fold": {group title: folded at first}} ({}: all open at first). The card's heading gets ▸/▾ (a click anywhere on the heading too) and,
## while folded, how many settings it holds; the state is kept in port.cfg (menu_fold/<section>/<group>). Its ↺ sets
## every setting of that card back to its default - through the rows' own back-to-the-default buttons ("reset"),
## extension settings to their declared defaults ("restore"), the game's checkboxes to its starting values
## ("default") - after a second press within 3 s; the other cards stay as they are. Search results are never folded.

const CFG := "menu_fold"
const CONFIRM_S := 3.0


static func _key(sec: Dictionary, grp: Dictionary) -> String:
	return "%s/%s" % [sec.get("id", ""), grp["title"]]


static func is_folded(sec: Dictionary, grp: Dictionary) -> bool:
	return bool(PortSettings.get_value(CFG, _key(sec, grp), sec.get("fold", {}).get(grp["title"], false)))


static func set_folded(sec: Dictionary, grp: Dictionary, on: bool) -> void:
	PortSettings.set_value(CFG, _key(sec, grp), on)


## Something a card reset can set back.
static func resettable(spec: Dictionary) -> bool:
	return spec.has("restore") or spec.has("reset") or (spec.has("default") and spec.has("get") and spec.has("set"))


## Every setting of `specs` back to its default.
static func reset(specs: Array) -> void:
	for s in specs:
		if s.has("restore"):
			s["restore"].call()
		elif s.has("reset"):
			s["reset"].call()
		elif s.has("default") and s.has("get") and s.has("set"):
			if s["get"].call() != s["default"]:
				s["set"].call(s["default"])


## Adds the fold and reset buttons to a card's heading `h` (title label `hl`) and returns the box its rows go in.
static func card(h: HBoxContainer, hl: Label, cv: VBoxContainer, sec: Dictionary, grp: Dictionary, specs: Array,
		refresh_all: Callable) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	cv.add_child(body)
	var fold := MenuWidgets._icon_button("▾", "Show or hide this card's settings.")
	h.add_child(fold)
	h.move_child(fold, 0)
	h.add_theme_constant_override("separation", 5)
	var count := Label.new()
	count.text = "(%d)" % specs.size()
	count.add_theme_font_size_override("font_size", MenuTheme.HEADING)
	count.add_theme_color_override("font_color", MenuTheme.MUTED)
	h.add_child(count)
	h.move_child(count, hl.get_index() + 1)
	var apply := func(folded: bool):
		body.visible = not folded
		count.visible = folded
		fold.text = "▸" if folded else "▾"
	apply.call(is_folded(sec, grp))
	var toggle := func():
		var folded := body.visible
		set_folded(sec, grp, folded)
		apply.call(folded)
	fold.pressed.connect(toggle)
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	h.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			toggle.call())
	if specs.any(resettable):
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(spacer)
		var r := MenuWidgets._icon_button("↺", "Back to the defaults: every setting in this card (the other cards stay). Press twice.")
		var armed := [false]
		r.pressed.connect(func():
			if not armed[0]:
				armed[0] = true
				r.text = "Reset?"
				r.get_tree().create_timer(CONFIRM_S).timeout.connect(func():
					if is_instance_valid(r):
						armed[0] = false
						r.text = "↺")
				return
			armed[0] = false
			r.text = "↺"
			reset(specs)
			refresh_all.call())
		h.add_child(r)
	return body
