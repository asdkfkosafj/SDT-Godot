class_name MenuExtensions
extends RefCounted
## Port addition (not in the original game): the Extensions list of the new menu (Mods > Extensions): every
## built-in extension and plugin with an on/off switch and a link to its settings page, plugins that failed to
## load with the reason, and the Vanilla mode switch.


static func build_list() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var switches: Array = []
	for ext in Extensions.all:
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
		var eid := ext.id
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
			var d := Label.new()
			d.text = ext.description
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.add_theme_font_size_override("font_size", MenuTheme.SMALL + 1)
			d.add_theme_color_override("font_color", MenuTheme.MUTED)
			row.add_child(d)
		if not ext.unknown_points.is_empty():
			var w := Label.new()
			w.text = "Uses what this game does not have (never runs): " + ", ".join(ext.unknown_points)
			w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			w.add_theme_font_size_override("font_size", MenuTheme.SMALL + 1)
			w.add_theme_color_override("font_color", MenuTheme.WARN)
			row.add_child(w)
		if ext.fault != "":
			var fl := Label.new()
			fl.text = "Switched off: " + ext.fault
			fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fl.add_theme_font_size_override("font_size", MenuTheme.SMALL + 1)
			fl.add_theme_color_override("font_color", MenuTheme.WARN)
			row.add_child(fl)
		v.add_child(row)
		switches.append([ext, sw, settings])
	for pid in Extensions.plugins:
		var info: Dictionary = Extensions.plugins[pid]
		if str(info.get("error", "")) == "":
			continue
		var l := Label.new()
		l.text = "%s: not loaded (%s)" % [info.get("name", pid), info["error"]]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", MenuTheme.SMALL + 1)
		l.add_theme_color_override("font_color", MenuTheme.PLUGIN)
		v.add_child(l)
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
	v.add_child(van)
	v.set_meta("refresh", func():
		for s in switches:
			s[1].set_pressed_no_signal(Extensions.is_on(s[0].id))
			s[2].visible = s[0].enabled and not s[0].settings().is_empty()
		vsw.set_pressed_no_signal(Extensions.vanilla_mode))
	return v
