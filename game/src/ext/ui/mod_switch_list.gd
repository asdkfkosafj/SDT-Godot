class_name ModSwitchList
extends RefCounted
## Port extension: a new-menu control listing the mods of one mod catalog list (ModCatalog.add_picker), each with an
## on / off switch, so several can be on at once (ExtraMod's face mods, ExtraModHim's body mods).
## on_toggle(on: bool, entry) applies or removes the mod; the list then saves her, as the game does after every change
## in its menus (the mods she wears are part of her character, restored at the next start).


## A "custom" control spec's build(): the list, refreshed while the menu is open.
static func build(list_key: String, on_toggle: Callable, empty_text := "None found in Mods/Clothing.") -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.set_meta("refresh", _refresh.bind(box, list_key, on_toggle, empty_text))
	_refresh(box, list_key, on_toggle, empty_text)
	return box


static func _refresh(box: VBoxContainer, list_key: String, on_toggle: Callable, empty_text: String) -> void:
	var cat = g.modCatalog
	var list: Array = cat.picker_entries.get(list_key, []) if cat != null else []
	if box.get_meta("count", -1) != list.size():
		box.set_meta("count", list.size())
		for ch in box.get_children():
			ch.queue_free()
			box.remove_child(ch)
		if list.is_empty():
			var l := Label.new()
			l.text = empty_text
			l.add_theme_color_override("font_color", MenuTheme.MUTED)
			box.add_child(l)
		for e in list:   # a row like the menu's own switches: the mod's name, then its switch
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = e["title"]
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var b := CheckButton.new()
			b.focus_mode = Control.FOCUS_NONE
			b.toggled.connect(func(on: bool): on_toggle.call(on, e); g.saveData.saveCharData())
			row.add_child(l)
			row.add_child(b)
			row.set_meta("switch", b)
			box.add_child(row)
	for i in list.size():
		var b: CheckButton = box.get_child(i).get_meta("switch")
		b.set_pressed_no_signal(cat.is_applied(list[i]))
