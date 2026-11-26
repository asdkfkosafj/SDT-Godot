extends SDTExtension
## How hard she pulls back off him while he holds her deep in her throat (Behaviour > Resistance, "Pull off when
## held"): 100 % is the game's. Past her deep throat distance the game builds up a pull each tick (each click halves
## it); once she is out of that distance she pulls off and he grabs her again, so with the mouse kept still deep in
## her she goes back and forth. 0 %: she never pulls off while held; 200 %: twice as hard.
## The pull's power ({start, increase, max}: Her.pullOffPower) is scaled, so the pull itself scales the same way.
## A setting for all characters. Port addition (no Loader mod).


func _init() -> void:
	id = "pulloff"
	title = "Pull off when held"
	description = "How hard she pulls back off him while he holds her deep (Behaviour > Resistance)."
	default_enabled = true


func _setup() -> void:
	setting("strength", 100, {"label": "Pull off when held", "min": 0, "max": 200,
		"desc": "How hard she pulls back off him while he holds her deep (100 %: the game's; 0 %: she never "
			+ "pulls off, so he stays deep while the mouse stays still)."})


func _enable() -> void:
	var changed := func(_her): return get_setting("strength") != 100
	modify(&"Her.pullOffPower", {"phase": Hooks.MOOD, "op": "fn", "fn": _scale, "when": changed})
	# moods that add power by themselves (moremoods' Tease) stay under the scaled most; at 0 % nothing pulls
	modify(&"Her.pullOff", {"phase": Hooks.CLAMP, "op": "fn", "fn": _cap, "when": changed})
	menu_control("behaviour", "Resistance", MenuSchema.setting_control(self, "strength",
		{"after": "Throat resistance", "wide": true, "format": func(v): return "%d %%" % int(v)}))


func _scale(pp: Dictionary, _her) -> Dictionary:
	var k := float(get_setting("strength")) / 100.0
	var out := pp.duplicate()
	for key in ["start", "increase", "max"]:
		out[key] = float(pp[key]) * k
	return out


func _cap(po: Dictionary, her) -> Dictionary:
	if get_setting("strength") == 0:
		return {"pull": 0.0, "power": 0.0}
	return {"pull": po["pull"], "power": minf(float(po["power"]), float(her._pullOffPower()["max"]))}
