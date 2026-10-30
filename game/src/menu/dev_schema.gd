class_name DevSchema
extends RefCounted
## Port addition: the developer panel's sections (DevMenu), in the menu's spec format (see MenuWidgets). Extensions can
## add controls here too: SDTMenu.add_control() with "section" set to one of these ids.
##   dev_tools   workbench for experimental tools (empty for now)
##   dev_eyes, dev_mouth, dev_fluids, dev_state, dev_him   her and his behaviours (DevBehaviour): call, automation
##   dev_body    her body's models: the throat rings (ThroatRings)
##   dev_info    live values: her state by the same groups, frame rate, game tick, extensions and hook points in use
##   dev_panel   the panel's own settings, automation as a whole


static func sections() -> Array:
	return [_tools()] + DevBehaviour.sections() + [_body(), _info(), _panel()]


static func _tools() -> Dictionary:
	return {"id": "dev_tools", "name": "Tools", "groups": [
		{"title": "Workbench", "controls": [
			MenuSchema.note("Experimental and diagnostic tools appear here."),
		]},
	]}


static func _body() -> Dictionary:
	return {"id": "dev_body", "name": "Body", "groups": [_throat()]}


## Her throat's rings (ThroatRings): what they work out, the collar's settings, and the value points they act through.
static func _throat() -> Dictionary:
	var e: Dictionary = ThroatRings.entrance
	var c: Dictionary = ThroatRings.collar
	var acting := func(ext_id: String) -> String:
		var x = Extensions.get_extension(ext_id)
		return "acting" if x != null and x.enabled and x.get_setting("on") else "read only"
	return {"title": "Throat rings", "controls": [
		MenuSchema.note("Depth: 0 at her lips, 1 = 400 deep. Read only unless Behaviour > Resistance > Throat loosens (the entrance) or Collar holds her throat (the collar) is on."),
		value("Tip / push", "How deep his tip is, and how hard he pushes in this tick (0..1, from his movement).",
			func(): return "%.2f / %.2f" % [ThroatRings.tip, ThroatRings.push]),
		value("Entrance edges", "The throat entrance ring: the game's resistance zone at the way into her throat. Its tightness is her throat resistance slider.",
			func(): return _edges(e)),
		value("Entrance stretch", "How far the ring has stretched (0..1) / how hard he presses on it / how much it would hold him back.",
			func(): return _ring_state(e)),
		value("Entrance ring", "Acting: Throat loosens is on, so its stretch lowers the entrance's resistance and keeps her neck drawn stretched.",
			func(): return acting.call("throatresiststretch")),
		value("Collar edges", "Where the collar's picture covers the front of her neck (found every 15 ticks).",
			func(): return "%s: %s" % [ThroatRings.collar_name, _edges(c)] if c["on"] else "no collar"),
		value("Collar stretch", "How far the collar has stretched / how hard he presses on it / how much it would hold him back.",
			func(): return _ring_state(c) if c["on"] else "—"),
		value("Collar durability", "What is left before it would snap; it wears while he presses on it, more when it is stretched, and recovers at rest.",
			func(): return "doesn't break" if not is_finite(c["max_durability"]) else ("snapped" if c["snapped"] else "%.0f / %.0f" % [c["durability"], c["max_durability"]])),
		value("Collar ring", "Acting: Collar holds her throat is on.", func(): return acting.call("chokercollarresistance")),
		{"type": "slider", "label": "Stiffness", "tip": "The same setting as Behaviour > Resistance > Collar stiffness (0 soft band .. 1 metal); it sets the wall too.",
			"min": 0.0, "max": 1.0, "step": 0.05, "get": func(): return ThroatRings.stiffness,
			"set": func(v: float): ThroatRings.set_stiffness(v), "format": func(v): return "%.2f" % v,
			"reset": func(): ThroatRings.set_stiffness(ThroatRings.DEFAULT_STIFFNESS)},
		MenuSchema.actions("", "", ThroatRings.PROFILES.keys().map(func(k):
			return [k, func(): ThroatRings.apply_profile(k), "Profile %s: stiffness %.1f." % [k, ThroatRings.PROFILES[k]]])),
		{"type": "slider", "label": "Wall", "tip": "How hard the collar's band stops him going deeper (the game's throat at resistance 100: 0.2), apart from the stiffness, as code may set it (ThroatRings.set_wall). Setting the stiffness sets it again; not kept.",
			"min": 0.0, "max": ThroatRings.WALL_MAX, "step": 0.01, "get": func(): return ThroatRings.collar_wall,
			"set": func(v: float): ThroatRings.set_wall(v), "format": func(v): return "%.2f" % v},
		_vp("Neck.band", "The band holding the front of her neck in (a collar's), or none."),
		_vp("Her.resistance", "What holds him back as he pushes in (the game's throat resistance zones)."),
		_vp("Her.limpResistance", "What holds him back while she is passed out (nothing in the game; a collar holds)."),
		_vp("Her.pushBack", "What pushes her head back off him each tick (0 in the game)."),
		_vp("Neck.depth", "How deep the throat bulge sits (his depth / 400; a loosened throat keeps it deeper)."),
		MenuSchema.actions("", "", [
			["Reset stretch", func(): ThroatRings.reset_stretch(), "Every ring back to not stretched."],
			["Repair", func(): ThroatRings.repair(), "Durability back to full; a snapped ring holds again."]]),
	]}


## A value point's row: who changes it and the value the game used last (Hooks.explain), or that nothing changes it.
static func _vp(name: String, tip: String) -> Dictionary:
	return value(name, "Value point: " + tip, func():
		var sn := StringName(name)
		if not Hooks.has_value(sn):
			return "game's"
		var chain: Array = Hooks.explain(sn)
		if chain.is_empty():
			return "set, not asked yet"
		var owners: Array = []
		for step in chain:
			if step.has("owner") and not owners.has(step["owner"]):
				owners.append(step["owner"])
		var r = chain[-1].get("result")
		if r is Dictionary:
			r = "%.2f–%.2f, %.1f px" % [r["top"], r["bottom"], r["inside"]]
		return "%s → %s" % [", ".join(owners), "%.3f" % r if r is float else str(r)])


static func _edges(r: Dictionary) -> String:
	return "%.2f – %.2f" % [r["top"], r["bottom"]]


static func _ring_state(r: Dictionary) -> String:
	return "%.2f / %.2f / %.2f" % [r["stretch"], r["pressure"], r["hold"]]


static func _info() -> Dictionary:
	return {"id": "dev_info", "name": "Info", "groups": [
		{"title": "Engine", "controls": [
			value("Godot", "Engine version.", func(): return Engine.get_version_info()["string"]),
			value("Frame rate", "Frames drawn per second.", func(): return "%d fps" % Engine.get_frames_per_second()),
			value("Game tick", "Game logic steps since the start (30 per second, stopped while paused).",
				func(): return str(Flash.tick_count)),
		]},
		{"title": "Eyes", "controls": [
			value("Looking at", "Where her eyes are aimed.", _her(func(h):
				var t: Vector2 = h.currentLookTarget
				return "his face" if t == h.hisFace else ("down" if t == h.eyesDown else "elsewhere"))),
			value("Eye closed", "Closed by cum in her eye (opens when clean or after 40 s).",
				_her(func(h): return _yes(h.eyelidMotion["isClosed"]))),
			value("Tears", "Tear spots on her face / tears running.",
				_her(func(h): return "%d / %d" % [h.tears.tearSpotList.size(), h.tears.tearList.size()])),
		]},
		{"title": "Mouth", "controls": [
			value("Cum in mouth", "Units in her mouth (she swallows or drools it).",
				_her(func(h): return "%d of %d" % [h.cumInMouth, h.maxCumInMouth])),
			value("Swallowing", "", _her(func(h): return _yes(h.swallowing))),
			value("Teeth clenched", "Clenched teeth keep him out.", _her(func(h): return _yes(h.clenchTeeth))),
			value("Cough build-up", "Builds up while held deep; she coughs at the next cough time.",
				_her(func(h): return "%.1f" % h.coughBuild)),
		]},
		{"title": "Fluids", "controls": [
			value("Drooling", "Spit / cum.", _her(func(h): return "%s / %s" % [_yes(h.droolingSpit), _yes(h.droolingCum)])),
			value("Sweat droplets", "", func(): return str(Sweat.droplet_count())),
			value("Wetness build-up", "Grows in Happy and Ahegao moods; unfinished in the original (shows nothing).",
				_her(func(h): return "%.0f" % h.wetGenerate)),
		]},
		{"title": "State", "controls": [
			value("Mood", "Her mood; an extended mood (moremoods) in brackets.",
				_her(func(h): return h.currentMood + (" (%s)" % Moods.current() if Moods.is_extended() else ""))),
			value("Breath used", "Out of breath at the top; she passes out if it stays there.",
				func(): return "%.0f%%" % (g.breathLevel / g.breathLevelMax * 100.0)),
			value("Passing out", "Builds while out of breath; at the top she passes out.",
				_her(func(h): return "out" if h.passedOut else "%.0f%%" % (h.passOutFactor / h.passOutMax * 100.0))),
			value("Pace (vigour)", "Built from movement, falls by itself; above 1000 she winces.",
				_her(func(h): return "%.0f of 1050" % h.vigour)),
		]},
		{"title": "Him", "controls": [
			value("Pleasure", "He comes after 2 s at the top.", func():
				return "-" if g.him == null else "%.0f%%" % minf(100.0, g.him.pleasure / g.him.ejacPleasure * 100.0)),
			value("Ejaculating", "", func(): return "-" if g.him == null else _yes(g.him.ejaculating)),
		]},
		{"title": "Extensions", "controls": [
			value("Extensions on", "Extensions switched on, of all found.", func():
				return "%d of %d" % [Extensions.all.filter(func(e): return e.enabled).size(), Extensions.all.size()]),
			value("Hook points in use", "Game methods with extension handlers right now (Hooks).",
				func(): return str(Hooks.registered().size())),
		]},
	]}


static func _panel() -> Dictionary:
	return {"id": "dev_panel", "name": "Panel", "groups": [
		{"title": "Developer mode", "controls": [
			MenuSchema.toggle("Developer mode", "This panel. Off: it closes and its DEBUG tab goes away (back on in Settings › Menu).",
				SDTMenu.dev_mode_enabled, SDTMenu.set_dev_mode),
			MenuSchema.note("The panel opens on the side opposite the menu: Settings › Menu › Menu side moves both. It does not pause the game."),
		]},
		{"title": "Automation", "controls": [
			value("Switched off", "Behaviours the game no longer does by itself (Eyes, Mouth, Fluids, State, Him tabs).",
				func(): return "%d of %d" % [DevBehaviour.off_count(), DevBehaviour.hooks().size()]),
			MenuSchema.actions("", "", [
				["Freeze all", func(): DevBehaviour.set_all(false), "She and he do nothing by themselves; the call buttons still work."],
				["Restore all", func(): DevBehaviour.set_all(true), "Back to the game doing everything by itself."]],
				{"keywords": "automation freeze profile"}),
			MenuSchema.toggle("Remember after restart", "On: the switched-off automation comes back at the next start. Off: every start is the normal game (this session keeps what you switched off; Restore all clears it now).",
				DevBehaviour.remember, DevBehaviour.set_remember, {"keywords": "automation profile save"}),
		]},
	]}


## fn(her) for a value row, "-" while she is not there.
static func _her(fn: Callable) -> Callable:
	return func(): return "-" if g.her == null else fn.call(g.her)


static func _yes(v: bool) -> String:
	return "yes" if v else "no"


## A read-only value: label on the left, the value on the right, re-read while the panel is open.
static func value(label: String, tip: String, get_fn: Callable) -> Dictionary:
	return {"type": "custom", "label": label, "tip": tip, "wide": false, "keywords": "debug",
		"build": func():
			var l := Label.new()
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.add_theme_color_override("font_color", MenuTheme.ACCENT)
			l.set_meta("refresh", func(): l.text = str(get_fn.call()))
			return l}
