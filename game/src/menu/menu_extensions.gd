class_name MenuExtensions
extends RefCounted
## Port addition (not in the original game): the Extensions list of the new menu (Mods > Extensions): every
## built-in extension and plugin with an on/off switch and a link to its settings page, plugins that failed to
## load with the reason, and the Vanilla mode switch.


## The rows are made a few per frame (FILL_BUDGET_US): all ~60 at once put some 360 controls with wrapped text into
## the tree in one frame (about 30 ms, a hitch while the menu builds its sections after it opens).
const FILL_BUDGET_US := 2000


static func build_list() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var switches: Array = []   # [extension, switch, Settings button] of the rows made so far
	var todo: Array = Extensions.all.duplicate()
	var van := _vanilla_row()
	v.add_child(van)
	v.set_meta("refresh", func():
		for s in switches:
			_refresh_row(s)
		van.get_meta("switch").set_pressed_no_signal(Extensions.vanilla_mode))
	var fill := [null]
	fill[0] = func():
		if not is_instance_valid(v):
			return
		var t0 := Time.get_ticks_usec()
		while not todo.is_empty() and Time.get_ticks_usec() - t0 < FILL_BUDGET_US:
			var row := _ext_row(todo.pop_front(), switches)
			v.add_child(row)
			v.move_child(row, van.get_index())   # above the plugin errors and Vanilla mode
			_refresh_row(switches[-1])
		if todo.is_empty():
			_add_plugin_errors(v, van)
		else:
			Flash.get_tree().process_frame.connect(fill[0], CONNECT_ONE_SHOT)
	Flash.get_tree().process_frame.connect(fill[0], CONNECT_ONE_SHOT)   # from the next frame: v is in the menu then
	return v


static func _refresh_row(s: Array) -> void:
	s[1].set_pressed_no_signal(Extensions.is_on(s[0].id))
	s[2].visible = s[0].enabled and not s[0].settings().is_empty()


## One extension's row: name, kind, Settings button, switch, description and warnings.
static func _ext_row(ext, switches: Array) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var top := HBoxContainer.new()
	var name := Label.new()
	name.text = ext.title if ext.title != "" else ext.id
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	top.add_child(name)
	var kind := Label.new()
	kind.text = "built in" if ext.builtin else "plugin"
	kind.add_theme_font_size_override("font_size", MenuTheme.SMALL)
	kind.add_theme_color_override("font_color", MenuTheme.MUTED)
	top.add_child(kind)
	var settings := Button.new()
	settings.text = "Settings"
	settings.focus_mode = Control.FOCUS_NONE
	var eid: String = ext.id
	settings.pressed.connect(func(): SDTMenu.instance.show_section("ext:" + eid))
	top.add_child(settings)
	var sw := CheckButton.new()
	sw.focus_mode = Control.FOCUS_NONE
	sw.tooltip_text = "Switch %s on or off" % name.text
	sw.toggled.connect(func(on: bool):
		Extensions.set_enabled(eid, on)
		SDTMenu.instance.call_deferred("_show"))
	top.add_child(sw)
	row.add_child(top)
	if ext.description != "":
		row.add_child(_note(ext.description, MenuTheme.MUTED))
	if not ext.unknown_points.is_empty():
		row.add_child(_note("Uses what this game does not have (never runs): " + ", ".join(ext.unknown_points), MenuTheme.WARN))
	if ext.fault != "":
		row.add_child(_note("Switched off: " + ext.fault, MenuTheme.WARN))
	switches.append([ext, sw, settings])
	return row


static func _note(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", MenuTheme.SMALL + 1)
	l.add_theme_color_override("font_color", colour)
	return l


## Plugins that failed to load, with the reason, above the Vanilla mode row.
static func _add_plugin_errors(v: VBoxContainer, van: Control) -> void:
	for pid in Extensions.plugins:
		var info: Dictionary = Extensions.plugins[pid]
		if str(info.get("error", "")) == "":
			continue
		var l := _note("%s: not loaded (%s)" % [info.get("name", pid), info["error"]], MenuTheme.PLUGIN)
		v.add_child(l)
		v.move_child(l, van.get_index())


static func _vanilla_row() -> Control:
	var van := HBoxContainer.new()
	var vl := Label.new()
	vl.text = "Vanilla mode"
	vl.tooltip_text = "Switches every extension off and brings back the original menu: the game plays exactly like the original. Switch it off again in the original menu's Options tab."
	vl.mouse_filter = Control.MOUSE_FILTER_PASS
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	van.add_child(vl)
	var vsw := CheckButton.new()
	vsw.focus_mode = Control.FOCUS_NONE
	vsw.toggled.connect(func(on: bool):
		Extensions.set_vanilla_mode(on)
		SDTMenu.instance.apply_mode())
	van.add_child(vsw)
	van.set_meta("switch", vsw)
	return van
