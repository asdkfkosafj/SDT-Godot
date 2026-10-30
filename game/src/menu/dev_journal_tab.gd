class_name DevJournalTab
extends RefCounted
## Port addition: the Log card of the developer panel's Tools section, showing Journal: a button per group to show
## or hide its lines, Pause, Clear, Copy (the shown lines to the clipboard) and Save (the whole log to a file in the
## save folder). Newest line on top here; Copy and Save give them oldest first.


static func group() -> Dictionary:
	return {"title": "Log", "controls": [
		MenuSchema.note("What happens in the game, as it happens: swallowing first, then her mouth and throat, her breath, him, and the rest. Read only; recorded while Developer mode is on."),
		{"type": "custom", "label": "", "keywords": "journal log events history", "tip": "The event log. Lines repeated right away are folded (x N); the last %d are kept." % Journal.MAX,
			"build": _build},
	]}


static func _build() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 4)
	filters.add_theme_constant_override("v_separation", 4)
	box.add_child(filters)
	var view := TextEdit.new()
	var status := Label.new()
	var state := {"version": -1, "filter": ""}
	var redraw := func():
		state["version"] = -1
	for gid in Journal.GROUPS:
		var b := Button.new()
		b.text = Journal.GROUPS[gid]
		b.toggle_mode = true
		b.button_pressed = Journal.shown.get(gid, true)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "Show or hide the %s lines." % Journal.GROUPS[gid].to_lower()
		b.toggled.connect(func(on: bool):
			Journal.shown[gid] = on
			redraw.call())
		filters.add_child(b)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	box.add_child(actions)
	var pause := Button.new()
	pause.text = "Pause"
	pause.toggle_mode = true
	pause.button_pressed = Journal.paused
	pause.focus_mode = Control.FOCUS_NONE
	pause.tooltip_text = "Stop recording for now (the lines so far stay)."
	pause.toggled.connect(func(on: bool): Journal.paused = on)
	actions.add_child(pause)
	var clear_fn := func():
		Journal.clear()
		status.text = ""
	var copy_fn := func():
		DisplayServer.clipboard_set(Journal.as_text())
		status.text = "Copied."
	var save_fn := func():
		var path := Journal.save()
		status.text = ("Saved: " + path) if path != "" else "Could not save."
	for a in [["Clear", "Remove every line.", clear_fn],
			["Copy", "Copy the lines shown to the clipboard, to paste them elsewhere.", copy_fn],
			["Save", "Save the whole log to a text file in the save folder (journal/).", save_fn]]:
		var b := Button.new()
		b.text = a[0]
		b.tooltip_text = a[1]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(a[2])
		actions.add_child(b)
	view.editable = false
	view.focus_mode = Control.FOCUS_NONE   # the game's keys stay the game's
	view.custom_minimum_size = Vector2(0, 300)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	view.add_theme_font_size_override("font_size", MenuTheme.SMALL + 1)
	view.add_theme_color_override("font_readonly_color", MenuTheme.TEXT)   # read only, but not greyed out
	box.add_child(view)
	status.add_theme_font_size_override("font_size", MenuTheme.SMALL)
	status.add_theme_color_override("font_color", MenuTheme.MUTED)
	status.clip_text = true
	box.add_child(status)
	box.set_meta("refresh", func():
		var filter := str(Journal.shown)
		if state["version"] == Journal.version and state["filter"] == filter:
			return
		state["version"] = Journal.version
		state["filter"] = filter
		var top: bool = view.scroll_vertical <= 0.0
		view.text = Journal.as_text(true, true)
		if top:
			view.scroll_vertical = 0
		if status.text == "" or status.text.begins_with("Lines"):
			status.text = "Lines: %d%s" % [Journal.lines.size(), " (paused)" if Journal.paused else ""])
	return box
