extends RefCounted
## Checks of the new in-game menu (src/menu): every section builds, the controls change the game through the classic
## menu's handlers (and the classic menu shows the same), settings (side, pause, classic menu), extension settings
## pages and controls added by extensions, the dialogue editor. Run by tools/regress.sh (main.gd --driver); prints
## "MENU CHECKS: n passed, m failed" and quits.

var _pass := 0
var _fail := 0
var _phase := 0
var _t0 := 0
var menu: SDTMenu


func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("CHECK %s %s%s" % ["ok  " if ok else "FAIL", name, "" if ok or detail == "" else " (%s)" % detail])


func step(_frame: int) -> void:
	if not Extensions.started:
		return
	match _phase:
		0:
			Flash.stage.getChildAt(0).playClicked()
			_t0 = Flash.tick_count
			_phase = 1
		1:
			if Flash.tick_count > _t0 + 10:
				menu = SDTMenu.instance
				_open_checks()
				_section_checks()
				_control_checks()
				_settings_checks()
				_fold_checks()
				_dev_mode_checks()
				_behaviour_checks()
				_extension_checks()
				_dialogue_editor_checks()
				_finish()


func _finish() -> void:
	print("MENU CHECKS: %d passed, %d failed" % [_pass, _fail])
	Flash.get_tree().quit(1 if _fail > 0 else 0)
	_phase = 99


## The spec with this label in a section (searched in the merged groups, like the menu shows them).
func _spec(section: String, label: String) -> Dictionary:
	for grp in menu._groups_of(menu._find_section(section)):
		for c in grp["controls"]:
			if c.get("label", "") == label:
				return c
			for sub in c.get("colors", []):
				if sub.get("label", "") == label:
					return sub
	return {}


func _open_checks() -> void:
	_check("new menu active", SDTMenu.active())
	_check("classic menu hidden", not g.inGameMenu.visible)
	g.inGameMenu.toggleMenu(true, 1)   # the Y key
	_check("Y opens the new menu on Her", menu.is_open and menu.section == "her" and not g.inGameMenu.menuOpen)
	_check("the menu pauses the game", g.gamePaused)
	g.inGameMenu.toggleMenu(true, 1)
	_check("Y again closes it", not menu.is_open and not g.gamePaused)
	g.inGameMenu.toggleMenu(true, 1)
	var press := func(p: Vector2, b := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
		var e := InputEventMouseButton.new()
		e.button_index = b
		e.pressed = true
		e.position = p
		return e
	var inside: Vector2 = menu._dock.get_global_rect().get_center()
	var outside := Vector2(inside.x - menu._dock.size.x if not SDTMenu.on_left() else inside.x + menu._dock.size.x, inside.y)
	_check("a click on the dock keeps it open", not menu.outside_click(press.call(inside)))
	_check("the wheel outside keeps it open", not menu.outside_click(press.call(outside, MOUSE_BUTTON_WHEEL_UP)))
	_check("a click outside the dock closes it", menu.outside_click(press.call(outside)))
	menu.close_menu()
	g.inGameMenu.toggleMenu(true, 4)
	_check("O opens Settings", menu.is_open and menu.section == "settings")


func _section_checks() -> void:
	for s in menu.sections:
		menu.show_section(s["id"])
		menu.build_now()
		_check("section %s builds" % s["id"], menu._rows.size() > 0, str(menu._rows.size()))
		var w: float = menu._dock.get_combined_minimum_size().x
		_check("section %s fits the dock" % s["id"], w <= SDTMenu.WIDTH + 0.5, "needs %.0f of %d px" % [w, SDTMenu.WIDTH])
	menu.query = "spit"
	menu._show()
	menu.build_now()
	_check("search finds options in other sections", menu._rows.size() >= 2 and "spit" in menu._heading.text,
		"%d %s" % [menu._rows.size(), menu._heading.text])
	menu.show_section("her")


func _control_checks() -> void:
	var chars := _spec("her", "Character")   # first: changing her look makes her a custom character
	var names: Array = chars["options"].call()
	_check("character list", names.size() >= 20 and chars["index"].call() >= 0 and names[chars["index"].call()] == "SD chan",
		"%d %d" % [names.size(), chars["index"].call()])
	chars["pick"].call(names.find("Misty"))
	_check("character pick", g.characterControl.currentName == "Misty" or names[chars["index"].call()] == "Misty",
		str(chars["index"].call()))
	chars["pick"].call(names.find("SD chan"))

	var spit := _spec("effects", "Spit")
	spit["set"].call(false)
	_check("toggle: Spit off", not g.spit and not g.inGameMenu.optionsMenu.cbSpit.on and not spit["get"].call())
	spit["set"].call(true)
	_check("toggle: Spit on", g.spit and spit["get"].call())

	# Show his body (ToggleHim): off leaves only his penis, keeps his skin, keeps balls hidden when they change; on
	# brings back exactly what showed
	var him: Him = g.him
	var body := _spec("him", "Show his body")
	var shown := func() -> Array:
		var out := []
		for i in him.numChildren:
			if him.getChildAt(i).visible:
				out.append(him.getChildAt(i))
		return out
	var before: Array = shown.call()
	var skin: int = him.currentBody.currentSkinID
	var balls: int = him.currentBalls
	body["set"].call(false)
	var hidden: Array = shown.call()
	him.setBalls(1)
	_check("Show his body off: only his penis", hidden == [him.penis] and not body["get"].call() and not him.balls.visible
		and not him.armContainer.visible and him.currentBody.currentSkinID == skin, str(hidden))
	him.setBalls(balls)
	body["set"].call(true)
	_check("Show his body on: as before", shown.call() == before and body["get"].call() and him.armContainer.visible,
		"%s %s" % [before, shown.call()])

	var res := _spec("behaviour", "Resistance")
	res["set"].call(0.25)
	res["release"].call()
	var want: float = g.inGameMenu.costumeMenu.resistanceSlider.currentValue(100)
	_check("slider: resistance", absf(res["get"].call() - 0.25) < 0.01 and absf(g.introResistance - want) < 0.5,
		"%s %s" % [res["get"].call(), g.introResistance])
	res["reset"].call()
	_check("slider: reset to the default", absf(g.introResistance - g.defaultResistance) < 0.5, str(g.introResistance))

	var iris := _spec("her", "Iris")
	iris["pick"].call(2)
	_check("arrow list: iris 3", g.characterControl.currentIris == 2 and iris["index"].call() == 2,
		str(g.characterControl.currentIris))
	iris["pick"].call(0)
	_check("arrow list: back to iris 1", g.characterControl.currentIris == 0)

	var top := _spec("clothes", "Top")
	top["pick"].call(1)
	var tc: CharacterElementHelper = g.characterControl.topControl
	_check("costume slot: top", tc.selection == 1 and top["index"].call() == 1, str(tc.selection))
	var col := _spec("clothes", "Top colour")
	col["set"].call({"r": 10, "g": 20, "b": 30, "a": 1.0})
	_check("costume colour", tc.rgb1.r == 10 and tc.rgb1.g == 20 and tc.rgb1.b == 30, str(tc.rgb1))
	top["pick"].call(0)

	var lip := _spec("her", "Lipstick")
	lip["set"].call({"r": 200, "g": 10, "b": 10, "a": 0.5})
	_check("colour: lipstick", g.characterControl.lipstickRGB.r == 200 and is_equal_approx(g.characterControl.lipstickRGB.a, 0.5),
		str(g.characterControl.lipstickRGB))

	var auto := _spec("scene", "Auto mode")
	auto["set"].call(true)
	_check("auto mode on", g.autoModeOn and g.inGameMenu.sceneMenu.cbAuto.on)
	auto["set"].call(false)
	_check("auto mode off", not g.autoModeOn)

	var mood: Dictionary = {}
	for grp in menu._groups_of(menu._find_section("her")):
		if grp["title"] == "Mood":
			mood = grp["controls"][0]
	_check("mood list has the extension moods", "Smug" in mood["options"].call() and "Ahegao" in mood["options"].call())
	mood["set"].call("Smug")
	_check("mood: Smug", Moods.current() == "Smug")
	mood["set"].call("Happy")
	_check("mood: Happy", Moods.current() == "Happy" and g.inGameMenu.sceneMenu.cbMoodHappy.on)
	mood["set"].call("Normal")

	var msaa := _spec("settings", "MSAA")
	msaa["set"].call("Off")
	_check("choice: MSAA off", Flash.get_tree().root.msaa_2d == Viewport.MSAA_DISABLED and msaa["get"].call() == "Off")
	msaa["set"].call("2x")

	var bg := _spec("scene", "Background")
	bg["pick"].call(0)
	_check("background picker", g.bgID == 1 and bg["options"].call()[0] == "Lab", str(g.bgID))

	# refreshing every visible row (what the menu does while open) reads all getters without errors
	for s in menu.sections:
		menu.show_section(s["id"])
		menu.build_now()
		menu._refresh_rows()
	_check("all rows refresh", true)
	var no_reset := []   # every slider has its back-to-the-default button
	for s in menu.sections + MenuSchema.extension_pages():
		for grp in menu._groups_of(s):
			for c in grp["controls"]:
				if c.get("type", "") == "slider" and not c.has("reset"):
					no_reset.append(c.get("label", ""))
	_check("every slider can go back to its default", no_reset.is_empty(), str(no_reset))
	g.characterControl.setBreasts(20)
	g.inGameMenu.defaultBreastSizeClicked()
	var cc = g.characterControl
	_check("breast size back to the character's", cc.currentChar >= g.baseCharNum
		or cc.breastSize == cc.characters[cc.currentChar].breastSize, "%d %d" % [cc.breastSize, cc.currentChar])

	# the character code field: Load (a button that takes no focus) reads what was pasted while the field still has
	# focus; Generate shows its code in the focused field, so losing focus does not write the old text back
	var code_row := MenuWidgets.build(_spec("mods", "Code"), func(_s): pass)
	menu.add_child(code_row)
	var le: LineEdit = code_row.find_children("*", "LineEdit", true, false)[0]
	le.grab_focus()
	le.text = "charName:pasted"
	le.text_changed.emit(le.text)
	_check("code field: pasted text reaches Load", g.inGameMenu.moddingMenu.saveDataTF.text == "charName:pasted",
		g.inGameMenu.moddingMenu.saveDataTF.text.left(40))
	g.inGameMenu.generateClicked()
	code_row.get_meta("refresh").call()
	le.release_focus()
	_check("code field: Generate shown while focused", le.text.begins_with("charName:") and le.text != "charName:pasted"
		and g.inGameMenu.moddingMenu.saveDataTF.text == le.text, le.text.left(40))
	code_row.queue_free()

	# a label that does not fit beside its control: a slider goes below it, a toggle's label wraps; short ones stay
	var fits := []
	for spec in [{"type": "slider", "label": "Short", "get": func(): return 0.5, "set": func(_v): pass},
			{"type": "slider", "label": "A long slider label that cannot fit", "get": func(): return 0.5, "set": func(_v): pass},
			{"type": "toggle", "label": "A long toggle label that cannot fit at all", "get": func(): return true, "set": func(_v): pass}]:
		var r := MenuWidgets.build(spec, func(_s): pass)
		menu.add_child(r)
		r.size = Vector2(200, MenuWidgets.ROW_H)
		MenuWidgets._fit(r, r.get_child(1), spec["type"])
		var l: Label = r.get_child(0).get_child(0)
		fits.append([r.vertical, l.autowrap_mode != TextServer.AUTOWRAP_OFF])
		r.free()
	_check("long labels: two lines / wrapped, short ones one line", fits == [[false, false], [true, false], [false, true]],
		str(fits))


## Behaviour's cards fold (MenuFold): all open at first; the button and a click on the heading; the state kept; none
## in search results.
func _fold_checks() -> void:
	menu.open_menu()
	menu.show_section("behaviour")
	menu.build_now()
	var cards := {}
	for card in menu._cache["behaviour"].get_children():
		if not card is PanelContainer:
			continue
		var cv: VBoxContainer = card.get_child(0)
		var h: HBoxContainer = cv.get_child(0)
		cards[(h.get_child(1) as Label).text] = [h, cv.get_child(1)]
	_check("fold: Behaviour cards have a fold button", cards.has("RESISTANCE") and cards.has("REACTIONS")
		and (cards["REACTIONS"][0].get_child(0) as Button).text in ["▸", "▾"], str(cards.keys()))
	var all_open := true
	for k in cards:
		if not cards[k][1].visible:
			all_open = false
	_check("fold: every card open at first", all_open)
	var fold_btn: Button = cards["REACTIONS"][0].get_child(0)
	fold_btn.pressed.emit()
	_check("fold: the button folds it, and it is kept", not cards["REACTIONS"][1].visible and fold_btn.text == "▸"
		and PortSettings.get_value("menu_fold", "behaviour/Reactions", false) == true)
	_check("fold: a folded card shows how many settings it holds", (cards["REACTIONS"][0].get_child(2) as Label).visible
		and (cards["REACTIONS"][0].get_child(2) as Label).text.begins_with("("))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	cards["REACTIONS"][0].gui_input.emit(click)
	_check("fold: a click on the heading opens it again", cards["REACTIONS"][1].visible and fold_btn.text == "▾"
		and PortSettings.get_value("menu_fold", "behaviour/Reactions", true) == false)
	# a card's reset: change a game checkbox, a game slider and extension settings in Reactions and the collar's
	# stiffness in Resistance; ↺ once only asks, twice sets Reactions back and leaves Resistance as it is
	var x = Extensions.get_extension("throatcumbulge")
	var om = g.inGameMenu.optionsMenu
	if g.breathing:
		g.inGameMenu.cbBreathingClicked()
	x.set_setting("queue", 3)
	x.set_setting("speed", 1.5)
	g.inGameMenu.mbDefaultThroatBulgeClicked()
	var bulge0: float = g.throatBulgeAmount
	om.throatBulgeSlider.setPos(0.9)
	g.inGameMenu.throatBulgeSliderChanged()
	ThroatRings.set_stiffness(0.9)
	var hx: HBoxContainer = cards["REACTIONS"][0]
	var r: Button = hx.get_child(hx.get_child_count() - 1)
	r.pressed.emit()
	_check("card reset: the first press only asks", r.text == "Reset?" and not g.breathing and x.get_setting("queue") == 3)
	r.pressed.emit()
	_check("card reset: the second sets Reactions back (game checkbox, game slider, extension settings)", g.breathing
		and x.get_setting("queue") == 0 and x.get_setting("speed") == 1.0 and is_equal_approx(g.throatBulgeAmount, bulge0)
		and r.text == "↺", "breathing %s queue %s speed %s bulge %s/%s" % [g.breathing, x.get_setting("queue"),
		x.get_setting("speed"), g.throatBulgeAmount, bulge0])
	_check("card reset: the other cards stay", is_equal_approx(ThroatRings.stiffness, 0.9))
	var hr: HBoxContainer = cards["RESISTANCE"][0]
	var rr: Button = hr.get_child(hr.get_child_count() - 1)
	rr.pressed.emit()
	rr.pressed.emit()
	_check("card reset: Resistance back, the collar's stiffness too", is_equal_approx(ThroatRings.stiffness,
		ThroatRings.DEFAULT_STIFFNESS))
	menu.query = "swallow queue"
	menu._show()
	var found := 0
	for b in menu._content.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.text in ["▸", "▾"]:
			found += 1
	_check("fold: none in search results", found == 0)
	menu.query = ""
	menu._show()
	menu.close_menu()


func _settings_checks() -> void:
	var side := _spec("settings", "Menu side")
	side["set"].call("Left")
	_check("menu on the left", menu._dock.anchor_left == 0.0 and menu._dock.offset_left == 0.0)
	side["set"].call("Right")
	_check("menu on the right", menu._dock.anchor_left == 1.0)

	var pause := _spec("settings", "Pause while the menu is open")
	pause["set"].call(false)
	_check("pause off resumes the game", not g.gamePaused)
	menu.close_menu()
	menu.open_menu("settings")
	_check("pause off: open menu keeps playing", menu.is_open and not g.gamePaused)
	pause["set"].call(true)
	_check("pause on pauses", g.gamePaused)

	var classic := _spec("settings", "Classic menu")
	classic["set"].call(true)
	_check("classic menu: new menu off", not SDTMenu.active() and not menu.is_open and g.inGameMenu.visible)
	g.inGameMenu.toggleMenu(true, 4)
	_check("classic menu opens with O", g.inGameMenu.menuOpen and not menu.is_open)
	menu.classic_button.dispatchEvent(FlashEvent.mouse(FlashEvent.CLICK))
	_check("classic menu's New menu button", SDTMenu.active() and menu.is_open and not g.inGameMenu.visible
		and not g.inGameMenu.menuOpen and not SDTMenu.classic(), "%s %s %s %s %s" % [SDTMenu.active(), menu.is_open,
		g.inGameMenu.visible, g.inGameMenu.menuOpen, SDTMenu.classic()])
	classic["set"].call(true)
	g.inGameMenu.closeMenu()
	classic["set"].call(false)
	_check("back to the new menu", SDTMenu.active() and not g.inGameMenu.visible)

	Extensions.set_vanilla_mode(true)
	menu.apply_mode()
	_check("Vanilla mode uses the classic menu", not SDTMenu.active() and g.inGameMenu.visible)
	Extensions.set_vanilla_mode(false)
	menu.apply_mode()
	_check("leaving Vanilla mode brings it back", SDTMenu.active())


## Developer mode: off by default and never built then; a collapsed panel with the menu's layout on the other side;
## both panels open together; the FPS counter beside a left panel; switched off and remembered.
func _dev_mode_checks() -> void:
	menu.close_menu()
	_check("developer mode off by default", not SDTMenu.dev_mode_enabled() and SDTMenu.dev == null)
	_check("developer mode off: no behaviour vetoes or observers, no event log", not DevBehaviour._active
		and DevBehaviour._watch_fns.is_empty() and not Journal.active and not Journal._tick_fn.is_valid())
	var side := _spec("settings", "Menu side")
	side["set"].call("Right")
	_spec("settings", "Developer mode")["set"].call(true)
	var dev = SDTMenu.dev
	_check("developer panel made", dev is DevMenu and dev._root != null)
	_check("developer mode remembered", bool(PortSettings.get_value("developer", "enabled", false)))
	_check("developer panel starts collapsed", not dev.is_open and not dev._dock.visible)
	_check("developer panel: search, sections, help line", dev._search != null and dev._nav_buttons.size() == 9)
	_check("developer tab says DEBUG", dev._tab.text.replace("\n", "") == "DEBUG")
	_check("menu right: developer panel left", dev._left() and not menu._left())
	dev.open_menu()
	dev.build_now()
	var w: float = dev._root.size.x
	_check("developer panel at the left edge", is_zero_approx(dev._dock.get_global_rect().position.x))
	_check("developer panel does not pause", not g.gamePaused)
	_check("FPS counter beside a left panel", is_equal_approx(SDTMenu.left_inset(), SDTMenu.WIDTH))
	dev.query = "frame rate"
	dev._show()
	_check("developer search finds its own options", dev._heading.text.begins_with("1 option"), dev._heading.text)
	dev.query = ""
	dev._show()
	menu.open_menu()
	var inside := _press(dev._dock.get_global_rect().get_center())
	var scene := _press(Vector2(w * 0.5, 200))
	_check("clicking the developer panel keeps the menu open", not menu.outside_click(inside) and not dev.outside_click(inside))
	_check("clicking the scene closes both", menu.outside_click(scene) and dev.outside_click(scene))
	menu.close_menu()
	side["set"].call("Left")
	_check("menu left: developer panel right", not dev._left() and is_equal_approx(dev._dock.get_global_rect().end.x, w))
	_check("FPS counter at the left with nothing open there", is_zero_approx(SDTMenu.left_inset()))
	Extensions.set_vanilla_mode(true)
	menu.apply_mode()
	_check("Vanilla mode hides the developer panel", not dev.is_open and not dev._tab.visible)
	Extensions.set_vanilla_mode(false)
	menu.apply_mode()
	_spec("settings", "Developer mode")["set"].call(false)
	_check("developer mode off closes it and hides its tab", not dev.is_open and not dev._tab.visible)
	_check("developer mode off remembered", not bool(PortSettings.get_value("developer", "enabled", true)))
	side["set"].call("Right")


func _press(pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	return e


## Behaviour tabs (DevBehaviour): a row per behaviour, automation off = a veto that the panel's own call passes,
## freeze / restore, remembering, and nothing left behind when Developer mode goes off or Vanilla mode comes on.
func _behaviour_checks() -> void:
	var her = g.her
	_spec("settings", "Developer mode")["set"].call(true)
	var dev = SDTMenu.dev
	_check("behaviour tabs: Eyes, Mouth, Fluids, State, Him", ["dev_eyes", "dev_mouth", "dev_fluids", "dev_state", "dev_him"]
		.all(func(id): return dev._nav_buttons.has(id)))
	_check("developer mode on: observers on every behaviour", DevBehaviour._active
		and DevBehaviour._watch_fns.size() == DevBehaviour.hooks().size())
	dev.open_menu("dev_mouth")
	dev.build_now()
	_check("Mouth tab: All off / on, 10 rows, 3 hand settings", dev._rows.size() == 14, str(dev._rows.size()))
	_check("everything on at first", DevBehaviour.off_count() == 0)
	var was := [her.swallowing, her.cumInMouth]
	DevBehaviour.set_auto(&"Her.swallow", false)
	her.swallowing = false
	her.swallow()
	_check("Swallow off: she does not swallow by herself", not her.swallowing)
	_check("Swallow off: the status names the veto", DevBehaviour.status(&"Her.swallow").contains("vetoed by Developer mode"),
		DevBehaviour.status(&"Her.swallow"))
	var free: bool = not her.passedOut and not her.speaking
	DevBehaviour.call_now(&"Her.swallow", func(): her.swallow())
	_check("Swallow off: the call button still works", not free or her.swallowing)
	_check("the button's call shows as called from here", not free or DevBehaviour.status(&"Her.swallow").contains("called from here"),
		DevBehaviour.status(&"Her.swallow"))
	DevBehaviour.set_auto(&"Her.swallow", true)
	her.swallowing = was[0]
	her.cumInMouth = 10
	var winces := [0]
	var count := func(_c): winces[0] += 1
	Hooks.add_before(&"Her.wince", count, "menu_checks")
	DevBehaviour.call_now(&"", func(): DevBehaviour._gulp_without_squint(her))
	_check("Gulp, no squint: a gulp without her wince", winces[0] == 0 and her.cumInMouth < 10
		and not Hooks.has_value(&"Her.swallowWince"), "%d %d" % [winces[0], her.cumInMouth])
	Hooks.remove_owner("menu_checks")
	her.cumInMouth = was[1]
	_teeth_tongue_checks()
	_spurt_checks()
	_journal_checks()
	DevTuning.set_clench_time(5.0)
	DevTuning.set_spam_j(true)
	var tools: Array = dev.sections.filter(func(sec): return sec["id"] == "dev_tools")[0]["groups"]
	var air := {}
	for c in tools.filter(func(grp): return grp["title"] == "Her")[0]["controls"]:
		air[c.get("label", "")] = c
	_check("Tools > Her: Air, Oxygen, and their now", ["Air", "Oxygen", "Air now", "Oxygen now"].all(func(k): return air.has(k)))
	air["Air"]["set"].call(100.0)
	air["Oxygen"]["set"].call(80.0)
	_check("Air 100: out of breath at half of it; Oxygen 80", g.breathLevelMax == 100.0 and g.outOfBreathPoint == 50.0
		and g.her.passOutMax == 80.0)
	DevBehaviour.set_all(false)
	_check("Freeze all switches off every behaviour", DevBehaviour.off_count() == DevBehaviour.hooks().size())
	DevBehaviour.set_all(true, "eyes")
	_check("All on in one tab", not DevBehaviour.is_off(&"Her.blink") and DevBehaviour.is_off(&"Her.swallow"))
	DevBehaviour.set_all(true)
	_check("Restore all", DevBehaviour.off_count() == 0)
	DevBehaviour.set_remember(true)
	DevBehaviour.set_auto(&"Him.ejaculate", false)
	_check("Remember on: switched-off automation saved", "Him.ejaculate" in PortSettings.get_value("dev_behaviour", "off", []))
	DevBehaviour.set_remember(false)
	_check("Remember off: nothing saved, the session keeps it", PortSettings.get_value("dev_behaviour", "off", ["x"]).is_empty()
		and DevBehaviour.is_off(&"Him.ejaculate"))
	Extensions.set_vanilla_mode(true)
	menu.apply_mode()
	_check("Vanilla mode: no vetoes or observers", not DevBehaviour._active and DevBehaviour._watch_fns.is_empty())
	Extensions.set_vanilla_mode(false)
	menu.apply_mode()
	_check("Vanilla mode off again: the session's switches return", DevBehaviour._active and DevBehaviour.is_off(&"Him.ejaculate"))
	DevBehaviour.set_all(true)
	dev.close_menu()
	_spec("settings", "Developer mode")["set"].call(false)
	_check("Developer mode off: no vetoes or observers left", not DevBehaviour._active and DevBehaviour._watch_fns.is_empty())
	_check("Developer mode off: hand settings back to the game's", DevTuning._mods.is_empty() and not DevTuning._spam_fn.is_valid()
		and DevTuning.clench_s == 0.0 and not Hooks.has_value(&"Her.clenchTime"))
	_check("Developer mode off: her air and oxygen the game's again", g.breathLevelMax == 50.0 and g.outOfBreathPoint == 25.0
		and g.her.passOutMax == 40.0)
	_check("Developer mode off: the event log stops, no hooks or tick of its own", not Journal.active
		and not Journal._tick_fn.is_valid() and not Flash.tick_after.any(func(f): return f == Journal._tick_fn))
	var n0: int = Journal.lines.size()
	Journal.log("other", "nothing")
	_check("Developer mode off: Journal.log does nothing", Journal.lines.size() == n0)


## The event log (Journal): folding, swallow lines, vetoes, a state change held HOLD ticks, hidden groups.
func _journal_checks() -> void:
	var her = g.her
	_check("log: on with Developer mode", Journal.active and Journal._tick_fn.is_valid())
	var was := [her.swallowing, her.speaking, her.passedOut, her.cumInMouth, her.breathing]
	Journal.clear()
	Journal.log("other", "a")
	Journal.log("other", "a")
	Journal.log("other", "b")
	_check("log: the same line again is folded", Journal.lines.size() == 2 and Journal.lines[0][3] == 2
		and Journal.as_text().contains("a  x2"), Journal.as_text())
	Journal.clear()
	her.swallowing = false
	her.speaking = false
	her.passedOut = false
	her.cumInMouth = 20
	her.swallow(0.8, false)
	her.swallow(0.8, false)
	her.gulp()
	Journal._tick()
	var t := Journal.as_text()
	_check("log: swallow starts, a dropped request, the gulp", t.contains("Swallow starts (strength 0.80, 20 in her mouth)")
		and t.contains("Asked to swallow: dropped, already swallowing") and t.contains("Gulp: took ")
		and t.find("Swallow starts") < t.find("dropped") and t.find("dropped") < t.find("Gulp"), t)
	Journal.clear()
	DevBehaviour.set_auto(&"Her.cough", false)
	her.cough()
	Journal._tick()
	DevBehaviour.set_auto(&"Her.cough", true)
	_check("log: a veto names who", Journal.as_text().contains("Cough vetoed by Developer mode"), Journal.as_text())
	Journal.clear()
	Journal._prev.clear()
	Journal._tick()
	her.breathing = not was[4]
	Journal._tick()
	_check("log: a state change waits HOLD ticks", not Journal.as_text().contains("breath"), Journal.as_text())
	Journal._since["breathing"][1] -= Journal.HOLD   # as if HOLD ticks went by
	Journal._tick()
	t = Journal.as_text()
	_check("log: then one line", t.contains("Holds her breath") or t.contains("Breathes again"), t)
	Journal.shown["breath"] = false
	_check("log: hidden groups are left out of the text", not Journal.as_text().contains("breath")
		and Journal.as_text(false).contains("breath"))
	Journal.shown["breath"] = true
	Journal.clear()
	her.swallowing = was[0]
	her.speaking = was[1]
	her.passedOut = was[2]
	her.cumInMouth = was[3]
	her.breathing = was[4]


## Her teeth (Her.releaseTeeth, Her.clenchTime, Her.clenchTaps through the hand settings) and her tongue's rows
## (Tongue.startMovingTongue: the Tongue out switch vetoes only "out").
func _teeth_tongue_checks() -> void:
	var her = g.her
	var was := [her.gagged, her.mouthFull]
	her.gagged = false
	her.mouthFull = false
	her.clenchTeeth = false
	var taps := [0]
	var tap := func(_c): taps[0] += 1
	Hooks.add_before(&"Her.tapHands", tap, "menu_checks")
	her.startClenchingTeeth()
	_check("teeth: the game's clench time (2 to 6 s) and its taps", her.clenchTeeth and her.clenchedTeethTime >= 60
		and her.clenchedTeethTime < 180 and taps[0] == 1)
	her.releaseTeeth()
	_check("teeth: Release teeth unclenches them now", not her.clenchTeeth)
	DevTuning.set_clench_time(5.0)
	DevTuning.set_clench_taps(false)
	her.startClenchingTeeth()
	_check("teeth: Clench time 5 s = 150 ticks, no tap with Taps off", her.clenchedTeethTime == 150 and taps[0] == 1)
	var veto := func(c): c.cancel()
	Hooks.add_before(&"Her.releaseTeeth", veto, "menu_checks")
	her.releaseTeeth()
	_check("teeth: Her.releaseTeeth can be vetoed", her.clenchTeeth)
	Hooks.remove_owner("menu_checks")
	her.releaseTeeth()
	DevTuning.reset()
	_check("teeth: hand settings back to the game's, no modifiers", not Hooks.has_value(&"Her.clenchTime")
		and not Hooks.has_value(&"Her.clenchTaps"))
	her.gagged = was[0]
	her.mouthFull = was[1]
	var t = her.tongue
	DevBehaviour.set_auto(&"Tongue.startMovingTongue", false)
	t.startMovingTongue("out")
	var out_vetoed: bool = DevBehaviour._seen[&"Tongue.startMovingTongue"][0].cancelled
	t.startMovingTongue("in")
	var in_vetoed: bool = DevBehaviour._seen[&"Tongue.startMovingTongue"][0].cancelled
	DevBehaviour.set_auto(&"Tongue.startMovingTongue", true)
	_check("Tongue out off: vetoes her tongue coming out, not going in", out_vetoed and not in_vetoed)


## His spurts: J adds a spurt while he cums (a before handler on Him.ejaculate); Spurt now.
func _spurt_checks() -> void:
	var him = g.him
	var was := [him.ejaculating, him.ejaculation.duplicate()]
	him.ejaculating = true
	him.ejaculation = []
	DevTuning.set_spam_j(true)
	him.ejaculate()
	_check("J adds a spurt: one more each press while he cums", him.ejaculation.size() == 1)
	DevTuning.add_spurt()
	_check("Spurt now: one more", him.ejaculation.size() == 2)
	DevTuning.set_spam_j(false)
	him.ejaculate()
	_check("J adds a spurt off: the game's (nothing while he cums)", him.ejaculation.size() == 2)
	him.ejaculating = was[0]
	him.ejaculation = was[1]


func _extension_checks() -> void:
	menu.open_menu("ext:moremoods")
	menu.build_now()
	_check("moremoods settings page", menu._rows.size() > 20 and menu._heading.text != "", str(menu._rows.size()))
	var mm: SDTExtension = Extensions.get_extension("moremoods")
	var spec := MenuSchema.setting_control(mm, "closemenuonselect")
	var before: bool = mm.get_setting("closemenuonselect")
	spec["set"].call(not before)
	_check("setting toggle changes the setting", mm.get_setting("closemenuonselect") == (not before))
	spec["set"].call(before)
	var sl := MenuSchema.setting_control(mm, "biteoccurancedivisor")
	sl["set"].call(500.0)
	_check("setting slider", is_equal_approx(float(mm.get_setting("biteoccurancedivisor")), 500.0))
	sl["set"].call(float(mm._settings["biteoccurancedivisor"]["default"]))

	# moremoods' modes in Her > Face and Behaviour > Biting (the classic menu's u / eyelid / bite buttons)
	var roll := _spec("her", "Eye roll")
	_check("eye roll control in Her", roll.get("group", "") == "Face" and roll.get("owner", "") == "moremoods")
	var roll_before: int = mm.face.eyeroll_mode
	roll["set"].call("Roll")
	_check("eye roll control sets the mode", mm.face.eyeroll_mode == 1 and roll["get"].call() == "Roll")
	mm.ui.set_eyeroll(roll_before)
	var lid_before: int = mm.face.eyelid_mode
	_spec("her", "Upper eyelids")["set"].call("Normal")
	var limit := _spec("her", "Eyelid limit")
	_check("eyelid limit hidden unless limited", not limit["visible"].call())
	_spec("her", "Upper eyelids")["set"].call("Both")
	_check("eyelid limit shown with Both", mm.face.eyelid_mode == 3 and limit["visible"].call())
	mm.ui.set_eyelid(lid_before)
	var bite := _spec("behaviour", "Biting")
	var bite_before: int = mm.behaviour.bite_mode
	bite["set"].call("By slider")
	_check("biting control sets the mode", mm.behaviour.bite_mode == 2 and _spec("behaviour", "Bite chance")["visible"].call())
	mm.ui.set_bite(bite_before)
	Extensions.set_enabled("moremoods", false)
	_check("moremoods off removes its controls", _spec("her", "Eye roll").is_empty())
	Extensions.set_enabled("moremoods", true)
	_check("moremoods on adds them once", menu._groups_of(menu._find_section("her")).filter(func(gr): return gr["title"] == "Face")[0]["controls"].filter(func(c): return c.get("label", "") == "Eye roll").size() == 1)

	SDTMenu.add_control({"type": "toggle", "label": "Test toggle", "owner": "moremoods", "section": "her",
		"group": "Face", "get": func(): return true, "set": func(_v): pass})
	menu.show_section("her")
	var found := _spec("her", "Test toggle")
	_check("extension control in a vanilla group", not found.is_empty())
	# its row is marked by a dot, not the full tag, so the label keeps its width; the tooltip names the extension
	var ext_row := MenuWidgets.build(found, func(_s): pass)
	_check("extension row: a dot, the label whole", ext_row.find_children("*", "Panel", true, false).size() == 1
		and ext_row.find_children("*", "Label", true, false).size() == 1 and ext_row.tooltip_text.contains("moremoods"),
		ext_row.tooltip_text)
	ext_row.free()
	Extensions.set_enabled("moremoods", false)
	menu.show_section("her")
	menu.build_now()
	var shown := menu._rows.any(func(r): return r.get_meta("spec").get("label", "") == "Test toggle")
	_check("extension off: its controls are hidden", not shown)
	Extensions.set_enabled("moremoods", true)
	SDTMenu.remove_owner("moremoods")
	_check("remove_owner", _spec("her", "Test toggle").is_empty())
	menu.close_menu()


## The dialogue editor (Dialogue > Edit…): loads every line, leaves an unchanged dialogue alone, edits reach the
## game's dialogue, [ / * suggestions, undo, play and back.
func _dialogue_editor_checks() -> void:
	var before: String = g.dialogueControl.exportDialogue()
	MenuSchema.close_then(DialogueEditorPanel.open_editor)
	var p := DialogueEditorPanel.instance
	_check("dialogue editor opens", p != null and p.is_open and g.gamePaused)
	var n := 0
	var dlg: Dictionary = g.dialogueControl.getCurrentDialogue()
	for k in dlg:
		if dlg[k] != null:
			n += dlg[k].size()
	for k in g.dialogueControl.getCurrentFinishes().values():
		n += k.size()
	_check("dialogue editor: every line", p.entries.size() == n, "%d of %d" % [p.entries.size(), n])
	p.close()
	_check("dialogue editor: closing unchanged keeps the dialogue", not g.gamePaused
		and g.dialogueControl.exportDialogue() == before)

	p.open()
	p.current_type = "general"
	p._select([])
	p._add_line()
	p._text.text = "[BLINK] Hello *YOU*"
	p._text_changed()   # (TextEdit reports text changes at the end of the frame)
	_check("dialogue editor: add a line and type", p._sel.size() == 1 and p._sel[0].trigger == "general"
		and p._sel[0].phrase == "[BLINK] Hello *YOU*" and p.dirty)
	p._set_on_selection(func(e): e._put("mood", Her.HAPPY_MOOD))
	g.her.setMood(Her.NORMAL_MOOD)
	_check("dialogue editor: can't play now (mood)", DialogueEditorPanel.why_not(p._sel[0]) == "not now: mood")
	_check("dialogue editor: variables parsed", str(DialogueEditorPanel.parse_vars("a=1, b=>=3, c=x")) == str({"a": 1, "b": ">=3", "c": "x"}))

	p._text.grab_focus()
	p._text.text = "x [BL"
	p._text.set_caret_column(5)
	p._complete()
	_check("dialogue editor: [ suggests actions", p._ac.visible and p._ac_items[0]["insert"] == "[BLINK]")
	p._ac_accept(0)
	_check("dialogue editor: a suggestion replaces what was typed", p._text.text == "x [BLINK]")
	p._text.text = "x *YO"
	p._text.set_caret_column(5)
	p._complete()
	_check("dialogue editor: * suggests wildcards", p._ac_items.any(func(a): return a["insert"] == "*YOU*"))
	p._text.text = "[BLINK] Hello *YOU*"
	p._text_changed()
	p._typing_snapshot = false
	p._text.text = "ZZZ"
	p._text_changed()
	p.undo()
	_check("dialogue editor: undo", p.entries.any(func(e): return e.phrase == "[BLINK] Hello *YOU*")
		and not p.entries.any(func(e): return e.phrase == "ZZZ"))
	p.close()
	_check("dialogue editor: the edit reaches the game",
		g.dialogueControl.exportDialogue().contains("general:\"[BLINK] Hello *YOU*\"{\"mood\":\"Happy\"}"))

	p.open()
	var mine: Array = p.entries.filter(func(e): return e.phrase == "[BLINK] Hello *YOU*")
	_check("dialogue editor: reopened with the line", mine.size() == 1)
	p._select(mine)
	p._play_clicked()
	_check("dialogue editor: play hides it and plays the line", p.playing and not g.gamePaused and p.blocks_mouse()
		and g.dialogueControl.sayingPhrase == "[BLINK] Hello *YOU*")
	var mood_before := Moods.current()
	var arms_before := [g.her.currentLeftArmPosition, g.her.currentRightArmPosition]
	var hold_before: int = g.him.currentArmPosition
	var store: Dictionary = g.dialogueControl.advancedController._dialogueDataStore
	var had_var := store.has("dlgedit_check")
	# as [ANGRY_MOOD] [ARMS_HIS_LEGS] [RELEASE] / [HOLD] [ADD_TEARS] and a "set" in the line would
	g.her.setMood(Her.ANGRY_MOOD if mood_before != Her.ANGRY_MOOD else Her.HAPPY_MOOD)
	g.her.setArmPosition(2 if arms_before[0] != 2 else 1)
	g.him.setArmPosition(1 - hold_before)
	g.her.tears.addTears()
	store["dlgedit_check"] = 1.0
	p._input(_press(Vector2(10, 10)))
	_check("dialogue editor: a click brings it back", not p.playing and g.gamePaused)
	_check("dialogue editor: a played line's mood does not last", Moods.current() == mood_before)
	_check("dialogue editor: a played line's arms, hold, tears and variables do not last",
		[g.her.currentLeftArmPosition, g.her.currentRightArmPosition] == arms_before
		and g.him.currentArmPosition == hold_before and store.has("dlgedit_check") == had_var
		and g.her.tears.tearSpotList.size() == p._before["tears"][4].size())
	p._search.text = "hello"
	p.query = "hello"
	p._show_lines()
	_check("dialogue editor: search finds the line", p._shown.has(mine[0]))
	p._delete()
	p.close()
	_check("dialogue editor: delete", not g.dialogueControl.exportDialogue().contains("Hello *YOU*"))
