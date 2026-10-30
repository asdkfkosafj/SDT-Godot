class_name MenuFold
extends RefCounted
## Port addition: folding cards, for menu sections that ask for it with "fold" (Behaviour for now):
## {"fold": {group title: folded at first}}. The card's heading gets ▸/▾ (a click anywhere on the heading too) and,
## while folded, how many settings it holds; the state is kept in port.cfg (menu_fold/<section>/<group>). Search
## results are never folded.

const CFG := "menu_fold"


static func _key(sec: Dictionary, grp: Dictionary) -> String:
	return "%s/%s" % [sec.get("id", ""), grp["title"]]


static func is_folded(sec: Dictionary, grp: Dictionary) -> bool:
	return bool(PortSettings.get_value(CFG, _key(sec, grp), sec.get("fold", {}).get(grp["title"], false)))


static func set_folded(sec: Dictionary, grp: Dictionary, on: bool) -> void:
	PortSettings.set_value(CFG, _key(sec, grp), on)


## Adds the fold button to a card's heading `h` (title label `hl`) and returns the box its rows go in.
static func card(h: HBoxContainer, hl: Label, cv: VBoxContainer, sec: Dictionary, grp: Dictionary, specs: Array) -> VBoxContainer:
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
	return body
