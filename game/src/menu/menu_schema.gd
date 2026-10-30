class_name MenuSchema
extends RefCounted
## Port addition (not in the original game): the sections, groups and controls of the new menu (SDTMenu), and the
## generated settings pages of extensions. Each control drives the classic menu (InGameMenu, hidden but still the
## controller): toggles call the checkbox handlers, sliders move the classic slider and call its handlers, lists
## call the arrow handlers, so saving, side effects and the classic menu's state stay exactly as in the game.
## The control spec format is described in MenuWidgets.


static func _m() -> InGameMenu:
	return g.inGameMenu


static func _save_char() -> void:
	g.saveData.saveCharData()


# ---------------------------------------------------------------- control helpers

static func toggle(label: String, tip: String, get_fn: Callable, set_fn: Callable, extra := {}) -> Dictionary:
	return _with({"type": "toggle", "label": label, "tip": tip, "get": get_fn, "set": set_fn}, extra)


## A classic checkbox: on = its state, clicking calls its handler (which flips the setting and the box).
static func check(label: String, tip: String, box: Callable, handler: Callable, extra := {}) -> Dictionary:
	return toggle(label, tip, func(): return box.call().on, func(on: bool):
		if on != box.call().on:
			handler.call(), extra)


## A classic slider (SDTSlider, 0..1 handle position): moves the handle, then calls its "sliderChanged" handler;
## "handleReleased" when let go; reset = the classic default button.
static func slider(label: String, tip: String, sl: Callable, changed: Callable, released: Callable,
		reset := Callable(), extra := {}) -> Dictionary:
	var s := {"type": "slider", "label": label, "tip": tip,
		"get": func(): return sl.call().currentValue(1000) / 1000.0,
		"set": func(v: float): sl.call().setPos(v); changed.call(),
		"release": released}
	if reset.is_valid():
		s["reset"] = reset
	return _with(s, extra)


## A list with options; index() and pick(i).
static func pick(label: String, tip: String, options: Callable, index: Callable, pick_fn: Callable, extra := {}) -> Dictionary:
	return _with({"type": "pick", "label": label, "tip": tip, "options": options, "index": index, "pick": pick_fn}, extra)


## A classic arrow list (◄ name ►): pick(i) presses the arrows until the index is i.
static func arrows(label: String, tip: String, options: Callable, index: Callable, left: Callable, right: Callable,
		extra := {}) -> Dictionary:
	return pick(label, tip, options, index, func(i: int):
		for _guard in 64:
			var cur: int = index.call()
			if cur < i:
				right.call()
			elif cur > i:
				left.call()
			if index.call() == cur:
				break, extra)


static func choice(label: String, tip: String, options, get_fn: Callable, set_fn: Callable, extra := {}) -> Dictionary:
	return _with({"type": "choice", "label": label, "tip": tip, "options": options, "get": get_fn, "set": set_fn}, extra)


static func actions(label: String, tip: String, buttons: Array, extra := {}) -> Dictionary:
	return _with({"type": "actions", "label": label, "tip": tip, "buttons": buttons}, extra)


## A colour (CharacterControl RGB {r, g, b, a}): get() returns it, setter(c, fill) applies it.
static func colour(label: String, tip: String, get_fn: Callable, setter: Callable, fill := "rgbFill", alpha := true,
		extra := {}) -> Dictionary:
	return _with({"type": "color", "label": label, "tip": tip, "alpha": alpha, "get": get_fn,
		"set": func(c: Dictionary): setter.call(c, fill), "release": _save_char}, extra)


static func hsl(label: String, tip: String, get_fn: Callable, apply: Callable, remove: Callable) -> Dictionary:
	return {"type": "hsl", "label": label, "tip": tip, "get": get_fn, "set": apply, "remove": func(): remove.call(); _save_char(),
		"release": _save_char}


static func note(text: String) -> Dictionary:
	return {"type": "note", "text": text}


static func _with(spec: Dictionary, extra: Dictionary) -> Dictionary:
	spec.merge(extra, true)
	return spec


## A costume slot (CharacterElementHelper): the list (built-in items, then clothing mods) and its colours.
static func element(label: String, tip: String, helper: Callable, alpha := false) -> Array:
	var out: Array = []
	out.append(pick(label, tip,
		func():
			var h: CharacterElementHelper = helper.call()
			return h.elementNameList + h.modEntries.map(func(e): return e["title"]),
		func():
			var h: CharacterElementHelper = helper.call()
			return h.elementNameList.size() + h.modEntryIndex if h.modEntryIndex >= 0 else h.selection,
		func(i: int):
			var h: CharacterElementHelper = helper.call()
			var cur: int = h.elementNameList.size() + h.modEntryIndex if h.modEntryIndex >= 0 else h.selection
			h._step(i - cur), {"keywords": "clothes costume", "wide": true}))
	# a worn mod without colourable parts gets the whole-piece tint and opacity instead of the colours
	var whole := func(): return helper.call().canTintWhole()
	var vis1 := func(): return helper.call().haveRGBFill and helper.call().inUse() and not whole.call()
	var vis2 := func():
		var h: CharacterElementHelper = helper.call()
		return h.haveRGBFill2 and h.inUse() and (not h.rgbFill2ForMods or h.modEntryIndex >= 0) and not whole.call()
	alpha = alpha or CharacterElementHelper.all_alpha
	out.append({"type": "colors", "label": label + " colours", "tip": "", "keywords": "clothes costume colour",
		"visible": func(): return vis1.call() or vis2.call(), "colors": [
			colour(label + " colour", "", func(): return helper.call().rgb1, func(c, f): helper.call().setFill(c, f),
				"rgbFill", alpha, {"visible": vis1}),
			colour(label + " second colour", "", func(): return helper.call().rgb2, func(c, f): helper.call().setFill(c, f),
				"rgbFill2", alpha, {"visible": vis2})]})
	out.append(_with(hsl(label + " tint", "This mod has no colourable parts: shifts the whole piece's hue, saturation, lightness and contrast.",
		func(): return helper.call().wholeHSL,
		func(c): var h: CharacterElementHelper = helper.call(); h.setWholeTint(c, h.wholeAlpha),
		func(): var h: CharacterElementHelper = helper.call(); h.setWholeTint(CharacterElementHelper.BLANK_HSL, h.wholeAlpha)),
		{"visible": whole, "keywords": "clothes costume colour tint hue"}))
	out.append({"type": "slider", "label": label + " opacity", "tip": "How visible the whole piece is.",
		"min": 0.0, "max": 1.0, "visible": whole, "keywords": "clothes costume alpha opacity transparent",
		"get": func(): return helper.call().wholeAlpha,
		"set": func(v: float): var h: CharacterElementHelper = helper.call(); h.setWholeTint(h.wholeHSL, v),
		"release": _save_char,
		"reset": func(): var h: CharacterElementHelper = helper.call(); h.setWholeTint(h.wholeHSL, 1.0); _save_char()})
	return out


# ---------------------------------------------------------------- sections

static func sections() -> Array:
	return [_her(), _clothes(), _him(), _scene(), _behaviour(), _effects(), _dialogue(), _mods(), _settings(), _help()]


static func _her() -> Dictionary:
	var cc := func(): return g.characterControl
	return {"id": "her", "name": "Her", "groups": [
		{"title": "Character", "controls": [
			pick("Character", "Switches to another character: the game's own, then stored ones (C and X also step through them).",
				func(): return MenuCharacters.names(), func(): return MenuCharacters.index(),
				func(i): MenuCharacters.select(i)),
			actions("", "", [["Shuffle her look", func(): _m().shuffle(), "Random hair, colours and clothes (Shift+/)."]]),
			_with({"type": "text", "label": "Name in dialogue", "placeholder": "the character's own",
				"tip": "The name dialogue lines use for her. Empty: the character's own name.",
				"get": func(): return g.customName,
				"set": func(t: String):
					if t != g.customName:
						_m().customMenu.dialogueNameTF.text = t
						_m().dialogueNameChanged()}, {}),
		]},
		{"title": "Mood", "controls": [
			_with({"type": "chips", "label": "", "tip": "How she reacts: her face, eyes, breathing and dialogue. Normal, Happy, Angry and Ahegao are the game's own moods; the outlined ones come from extensions.",
				"options": func(): return Moods.selectable(), "get": func(): return Moods.current(),
				"marked": func(m): return not m in Moods.VANILLA,
				"set": func(m: String):
					g.her.setMood(m)
					_m().updateMoods()
					_save_char(), "keywords": "mood emotion"}, {}),
		]},
		{"title": "Face", "controls": [
			arrows("Iris", "Iris shape.", func(): return _m().irisTypes, func(): return cc.call().currentIris,
				_m().irisLeftClicked, _m().irisRightClicked),
			arrows("Eyebrows", "Eyebrow shape.", func(): return CharacterControl.eyebrowsTypeList,
				func(): return cc.call().currentEyebrows, _m().eyebrowsLeftClicked, _m().eyebrowsRightClicked),
			arrows("Nose", "", func(): return CharacterControl.noseTypeList, func(): return cc.call().currentNose,
				_m().noseLeftClicked, _m().noseRightClicked),
			arrows("Ears", "", func(): return CharacterControl.earTypeList, func(): return cc.call().currentEar,
				_m().earLeftClicked, _m().earRightClicked),
			slider("Mascara", "How much mascara she wears (it runs when she cries).", func(): return _m().customMenu.mascaraSlider,
				_m().mascaraSliderChanged, _m().mascaraSliderReleased, _m().defaultMascaraClicked),
			slider("Freckles", "How many freckles she has.", func(): return _m().customMenu.frecklesSlider,
				_m().frecklesSliderChanged, _m().frecklesSliderReleased, _m().defaultFrecklesClicked),
		]},
		{"title": "Body", "controls": [
			arrows("Skin", "Skin tone; fine-tune it with the skin tint below.", func(): return _m().skinTypes,
				func(): return cc.call().currentSkin, _m().skinLeftClicked, _m().skinRightClicked),
			slider("Body size", "", func(): return _m().customMenu.bodySlider, _m().bodySliderChanged,
				_m().bodySliderReleased, _m().mbDefaultBodyScaleClicked),
			slider("Breast size", "", func(): return _m().customMenu.breastSlider, _m().breastSliderChanged,
				_m().breastSliderReleased, _m().defaultBreastSizeClicked),
		] + element("Penis", "Gives her a penis (futa) or a strapon.", func(): return g.her._penisControl.penisControl) + [
			slider("Penis length", "", func(): return g.her._penisControl.penisMenu.penisLengthSlider,
				func(): g.her._penisControl.penisLengthSliderChanged(), func(): g.her._penisControl.penisLengthSliderReleased(),
				func(): g.her._penisControl.mbDefaultPenisLengthClicked(), {"visible": func(): return g.her._penisControl.currentPenisID != 0}),
			slider("Penis width", "", func(): return g.her._penisControl.penisMenu.penisWidthSlider,
				func(): g.her._penisControl.penisWidthSliderChanged(), func(): g.her._penisControl.penisWidthSliderReleased(),
				func(): g.her._penisControl.mbDefaultPenisWidthClicked(), {"visible": func(): return g.her._penisControl.currentPenisID != 0}),
			{"type": "custom", "label": "Body mods", "wide": true, "keywords": "body mod thighs breasts shape",
				"tip": "Mods that change her body (thicker thighs, other breasts...) from Mods/Clothing. Several can be on.",
				"build": func(): return ModSwitchList.build(ModCatalog.BODY_MODS_LIST, _toggle_body, "None found in Mods/Clothing.")},
		]},
		{"title": "Hair", "controls": [
			pick("Hairstyle", "The game's hairstyles, then hair mods from the Mods folders.",
				func(): return _m().charNames + (g.modCatalog.hair_entries.map(func(e): return e["title"]) if g.modCatalog else []),
				func(): return _m().charNames.size() + _m().hairModIndex if _m().hairModIndex >= 0 else cc.call().currentHair,
				func(i: int):
					var cur: int = _m().charNames.size() + _m().hairModIndex if _m().hairModIndex >= 0 else cc.call().currentHair
					_m()._stepHair(i - cur)),
		]},
		{"title": "Colours", "controls": [
			hsl("Hair tint", "Shifts the hair's hue, saturation, lightness and contrast.", func(): return cc.call().hairHSL,
				func(c): cc.call().applyHairHSL(c), func(): cc.call().removeHairHSL()),
			hsl("Skin tint", "Shifts her skin's hue, saturation, lightness and contrast.", func(): return cc.call().skinHSL,
				func(c): cc.call().applySkinHSL(c), func(): cc.call().removeSkinHSL()),
			colour("Iris", "", func(): return cc.call().irisRGB, func(c, f): cc.call().setIrisFill(c, f)),
			colour("Sclera", "The whites of her eyes.", func(): return cc.call().scleraRGB, func(c, f): cc.call().setSclera(c, f)),
			colour("Eyebrow fill", "", func(): return cc.call().eyebrowFillRGB, func(c, f): cc.call().setEyebrowFill(c, f)),
			colour("Eyebrow line", "", func(): return cc.call().eyebrowLineRGB, func(c, f): cc.call().setEyebrowLine(c, f)),
			colour("Eye shadow", "", func(): return cc.call().eyeShadowRGB, func(c, f): cc.call().setEyeShadow(c, f)),
			colour("Mascara", "", func(): return cc.call().mascaraRGB, func(c, f): cc.call().setMascara(c, f)),
			colour("Blush", "", func(): return cc.call().blushRGB, func(c, f): cc.call().setBlush(c, f)),
			colour("Lipstick", "", func(): return cc.call().lipstickRGB, func(c, f): cc.call().setLipstick(c, f)),
			colour("Freckles", "", func(): return cc.call().frecklesRGB, func(c, f): cc.call().setFreckles(c, f)),
			colour("Nail polish", "", func(): return cc.call().nailPolishRGB, func(c, f): cc.call().setNailPolish(c, f)),
			actions("", "", [["Clear all tints", func(): _m().clearTintsClicked(), "Removes the hair, skin and his skin tints."]]),
		]},
	]}


static func _toggle_body(on: bool, e: Dictionary) -> void:
	if on:
		g.modCatalog.apply(e)
	else:
		g.modCatalog.remove_entry(e)


static func _clothes() -> Dictionary:
	var cc := func(): return g.characterControl
	var head: Array = []
	for e in [["Headwear", "headwearControl"], ["Eyewear", "eyewearControl"], ["Earrings", "earringControl"],
			["Collar", "collarControl"], ["Gag", "gagControl"]]:
		head.append_array(element(e[0], "", func(): return cc.call().get(e[1])))
	var upper: Array = []
	for e in [["Top", "topControl", true], ["Bra", "braControl", false], ["Armwear", "armwearControl", false],
			["Cuffs", "cuffsControl", false]]:
		upper.append_array(element(e[0], "", func(): return cc.call().get(e[1]), e[2]))
	var lower: Array = []
	for e in [["Bottoms", "bottomsControl", false], ["Panties", "pantiesControl", false], ["Legwear", "legwearControl", true],
			["Second legwear", "legwearBControl", true], ["Footwear", "footwearControl", false],
			["Ankle cuffs", "ankleCuffsControl", false]]:
		lower.append_array(element(e[0], "", func(): return cc.call().get(e[1]), e[2]))
	var pierce: Array = []
	for e in [["Tongue", "tonguePiercingControl"], ["Nipples", "nipplePiercingControl"], ["Belly", "bellyPiercingControl"]]:
		pierce.append_array(element(e[0], "", func(): return cc.call().get(e[1])))
	var tan := func(): return g.her.tan
	return {"id": "clothes", "name": "Clothes", "groups": [
		{"title": "Outfit", "controls": [
			actions("", "", [["Load a costume…", func(): MenuCharacters.choose_costume(),
				"Puts on a stored character's clothes; her body stays."]]),
		]},
		{"title": "Head and neck", "controls": head},
		{"title": "Upper body", "controls": upper},
		{"title": "Lower body", "controls": lower},
		{"title": "Body pieces", "controls": [
			{"type": "custom", "label": "Body pieces", "wide": true, "keywords": "moreclothing body armband",
				"tip": "Clothing worn besides the slots above (MoreClothing's body slot): an armband, a harness... Several can be on. A mod goes here when Mods/Clothing/names.txt names it with \"> body\".",
				"build": func(): return ModSwitchList.build(ModCatalog.BODY_LIST, _toggle_body, "None (see the tip).")},
		]},
		{"title": "Piercings", "controls": pierce},
		{"title": "Tan lines", "controls": [
			arrows("Tan", "", func(): return tan.call()._tanNameList, func(): return tan.call()._currentTanID,
				func(): tan.call().tanLeftClicked(), func(): tan.call().tanRightClicked()),
			slider("Tan strength", "", func(): return tan.call()._alphaSlider, func(): tan.call().alphaSliderChanged(),
				func(): tan.call().alphaSliderReleased(), func(): tan.call().resetAlpha()),
		]},
		{"title": "Arms", "controls": [
			arrows("Left arm", "Where she keeps her left arm.", func(): return Her.armPositionsFor(true),
				func(): return Her.armPositionsFor(true).find(Her.armPositions[g.her.currentLeftArmPosition]),
				_m().leftArmLeftClicked, _m().leftArmRightClicked),
			arrows("Right arm", "Where she keeps her right arm.", func(): return Her.armPositionsFor(false),
				func(): return Her.armPositionsFor(false).find(Her.armPositions[g.her.currentRightArmPosition]),
				_m().rightArmLeftClicked, _m().rightArmRightClicked),
		]},
	]}


static func _him() -> Dictionary:
	var him := func(): return g.him
	var penis: Array = element("Penis", "", func(): return g.him.penisControl)
	penis.append(slider("Length", "", func(): return _m().himMenu.penisLengthSlider, _m().penisLengthSliderChanged,
		_m().penisLengthSliderReleased, _m().mbDefaultPenisLengthClicked))
	penis.append(slider("Width", "", func(): return _m().himMenu.penisWidthSlider, _m().penisWidthSliderChanged,
		_m().penisWidthSliderReleased, _m().mbDefaultPenisWidthClicked))
	# his clothes (the classic menu's body page): top and bottoms on the male body, footwear on both
	var male := func(): return g.him.currentBodyID == 0
	var clothes: Array = []
	for e in [["Top", "topControl"], ["Bottoms", "bottomsControl"]]:
		for spec in element(e[0], "", func(): return g.him.bodies[0].get(e[1])):
			var vis = spec.get("visible")
			spec["visible"] = (func(): return male.call() and vis.call()) if vis is Callable else male
			clothes.append(spec)
	clothes.append_array(element("Footwear", "Loafers on his male body, heels on the futa body.",
		func(): return Him.feet_control(g.him.currentBody)))
	return {"id": "him", "name": "Him", "groups": [
		{"title": "Body", "controls": [
			arrows("Body", "", func(): return Him.bodyNameList, func(): return him.call().currentBodyID,
				_m().hisBodyLeftClicked, _m().hisBodyRightClicked),
			arrows("Skin", "", func(): return him.call().currentBody.skinNameList,
				func(): return him.call().currentBody.currentSkinID, func(): him.call().currentBody.hisSkinLeftClicked(),
				func(): him.call().currentBody.hisSkinRightClicked()),
			hsl("Skin tint", "Shifts his skin's hue, saturation, lightness and contrast.",
				func(): return g.characterControl.hisSkinHSL, func(c): g.characterControl.applyHisSkinHSL(c),
				func(): g.characterControl.removeHisSkinHSL()),
			toggle("Show his body", "Off: only his penis shows.", func(): return not g.him.bodyHidden,
				func(on: bool): g.him.setBodyHidden(not on)),
		]},
		{"title": "Clothes", "controls": clothes},
		{"title": "Arms", "controls": [
			arrows("Right arm", "Holding: his hand is on her head. Free: he lets go.", func(): return Him.armPositions,
				func(): return him.call().currentArmPosition, _m().hisArmLeftClicked, _m().hisArmRightClicked),
			arrows("Left arm", "", func(): return Him.leftArmPositions, func(): return him.call().currentLeftArmPosition,
				_m().hisLeftArmLeftClicked, _m().hisLeftArmRightClicked),
		]},
		{"title": "Penis", "controls": penis},
		{"title": "Balls", "controls": [
			arrows("Balls", "", func(): return him.call().ballsNameArray, func(): return him.call().currentBalls,
				_m().ballsLeftClicked, _m().ballsRightClicked),
			slider("Size", "", func(): return _m().himMenu.ballSizeSlider, _m().ballSizeSliderChanged,
				_m().ballSizeSliderReleased, _m().mbDefaultBallSizeClicked),
		]},
	]}


static func _scene() -> Dictionary:
	return {"id": "scene", "name": "Scene", "groups": [
		{"title": "Background", "controls": [
			pick("Background", "The game's backgrounds, then background mods and images from Mods/Backgrounds (B toggles the background).",
				func(): return InGameMenu.BG_NAMES + (g.modCatalog.bg_entries.map(func(e): return e["title"]) if g.modCatalog else []),
				func(): return InGameMenu.BG_NAMES.size() + _m().bgModIndex if _m().bgModIndex >= 0 else g.bgID - 1,
				func(i: int):
					var cur: int = InGameMenu.BG_NAMES.size() + _m().bgModIndex if _m().bgModIndex >= 0 else g.bgID - 1
					_m()._stepBG(i - cur)),
		]},
		{"title": "Camera", "controls": [
			slider("Zoom", "", func(): return _m().sceneMenu.zoomSlider, _m().zoomSliderChanged, _m().zoomSliderReleased,
				_m().mbDefaultZoomClicked),
			check("Mirror the scene", "Flips the scene left to right.", func(): return _m().optionsMenu.cbMirrored,
				_m().cbMirroredClicked),
		]},
		{"title": "Auto mode", "controls": [
			check("Auto mode", "He moves by himself (A).", func(): return _m().sceneMenu.cbAuto, _m().cbAutoClicked),
			arrows("Style", "How auto mode moves: Normal, Soft, Hard, or Self (she moves).",
				func(): return AutomaticControl.autoModeNameList, func(): return g.autoMode, _m().autoLeftClicked,
				_m().autoRightClicked),
		]},
		{"title": "Controls", "controls": [
			choice("Mouse control", "The game's two control styles.", ["Style 1", "Style 2"],
				func(): return "Style 1" if g.animationControl.currentAnimationID == 1 else "Style 2",
				func(v: String):
					if v == "Style 1":
						_m().style1Clicked()
					else:
						_m().style2Clicked()),
			check("Invert controls", "", func(): return _m().optionsMenu.cbInvertControls, _m().cbInvertControlsClicked),
		]},
	]}


static func _behaviour() -> Dictionary:
	var om := func(): return _m().optionsMenu
	# its cards fold (all open at first: MenuFold) and reset as a whole; "default": the game's starting values of its
	# checkboxes (g.gd), for that reset
	return {"id": "behaviour", "name": "Behaviour", "fold": {}, "groups": [
		{"title": "Resistance", "controls": [
			slider("Resistance", "How much she resists at first; it wears off while you play.",
				func(): return _m().costumeMenu.resistanceSlider, _m().resistanceSliderChanged, _m().resistanceSliderReleased,
				_m().mbDefaultResistanceClicked),
			slider("Throat resistance", "How hard it is to go deep.", func(): return _m().costumeMenu.throatResistanceSlider,
				_m().throatResistanceSliderChanged, _m().throatResistanceSliderReleased, _m().mbDefaultThroatResistanceClicked),
			check("Reset resistance for each character", "", func(): return _m().costumeMenu.cbResetResistance,
				_m().cbResetResistanceClicked),
		]},
		{"title": "Reactions", "controls": [
			check("Breathing", "", func(): return om.call().cbBreathing, _m().cbBreathingClicked, {"default": true}),
			check("Coughing", "", func(): return om.call().cbCoughing, _m().cbCoughingClicked, {"default": true}),
			check("Gagging", "", func(): return om.call().cbGagging, _m().cbGaggingClicked, {"default": true}),
			check("Tongue", "She sticks her tongue out at times.", func(): return om.call().cbTongue, _m().cbTongueClicked,
				{"default": true}),
			slider("Throat bulge", "How much her throat bulges.", func(): return om.call().throatBulgeSlider,
				_m().throatBulgeSliderChanged, _m().throatBulgeSliderReleased, _m().mbDefaultThroatBulgeClicked),
		]},
	]}


static func _effects() -> Dictionary:
	var om := func(): return _m().optionsMenu
	return {"id": "effects", "name": "Effects", "groups": [
		{"title": "Fluids and marks", "controls": [
			check("Spit", "", func(): return om.call().cbSpit, _m().cbSpitClicked),
			check("Tears", "", func(): return om.call().cbTears, _m().cbTearsClicked),
			check("Running mascara", "", func(): return om.call().cbMascara, _m().cbMascaraClicked),
			check("Smudging", "Lipstick and mascara smudge on contact.", func(): return om.call().cbSmudging, _m().cbSmudgingClicked),
			check("Lipstick smearing", "Her lipstick smears onto him.", func(): return _m().customMenu.cbLipstickSmearing,
				_m().lipstickSmearingClicked),
			check("Sweat", "", func(): return om.call().cbSweat, _m().cbSweatClicked),
			check("Nostril spray", "", func(): return om.call().cbNostrilSpray, _m().cbNostrilSprayClicked),
		]},
		{"title": "Clean up", "controls": [
			actions("", "", [["Clear all", func(): _m().clearAllClicked()], ["Cum", func(): _m().clearCumClicked()],
				["Spit", func(): _m().clearSpitClicked()], ["Lipstick", func(): _m().clearLipstickClicked()],
				["Mascara", func(): _m().clearMascaraClicked()]], {"keywords": "clear clean wipe"}),
		]},
	]}


static func _dialogue() -> Dictionary:
	return {"id": "dialogue", "name": "Dialogue", "groups": [
		{"title": "Dialogue", "controls": [
			check("Show dialogue", "", func(): return _m().optionsMenu.cbDialogue, _m().cbDialogueClicked),
			pick("Dialogue", "Default, or a dialogue file from Mods/Dialogue (loading one replaces the current dialogue).",
				func(): return ["Default"] + InGameMenu._dialogueFiles().map(func(f): return f.get_file().get_basename()),
				func(): return _m().dialogueFileIndex + 1 if _m().dialogueFileIndex >= 0 else 0,
				func(i: int):
					var cur: int = _m().dialogueFileIndex + 1 if _m().dialogueFileIndex >= 0 else 0
					_m()._stepDialogue(i - cur)),
			actions("", "", [["Load…", func(): _m().loadDialogueClicked(), "Loads a dialogue file from anywhere."],
				["Save…", func(): _m().saveDialogueClicked()], ["Edit…", func(): close_then(DialogueEditorPanel.open_editor), "The dialogue editor: line types, lines, actions."],
				["Default", func(): _m().resetDefaultDialogueClicked(), "Back to the game's own dialogue."]]),
		]},
	]}


## Runs fn after closing the menu (for screens that open over the game, like the dialogue editor).
static func close_then(fn: Callable) -> void:
	if SDTMenu.instance != null:
		SDTMenu.instance.close_menu()
	fn.call()


static func _mods() -> Dictionary:
	var md := func(): return _m().moddingMenu
	return {"id": "mods", "name": "Mods", "groups": [
		{"title": "Load mods", "controls": [
			actions("", "Loads a file once. To load it every time, put it in the matching Mods folder.", [
				["Mod…", func(): g.customElementLoader.browseModClicked()],
				["Hair…", func(): g.customElementLoader.browseCustomHairClicked()],
				["Background…", func(): g.customElementLoader.browseCustomBackgroundClicked()]], {"keywords": "import swf"}),
		]},
		{"title": "Character code", "controls": [
			_with({"type": "text", "label": "Code", "placeholder": "paste a character code",
				"tip": "Her whole look and settings as text: paste one and press Load, or Generate one from her current look.",
				"get": func(): return md.call().saveDataTF.text, "set": func(t: String): md.call().saveDataTF.text = t,
				"wide": true, "live": true}, {}),   # live: Load / Copy read it without the field losing focus first
			actions("", "", [["Load", func(): _m().loadClicked()], ["Generate", func(): _m().generateClicked()],
				["Copy", func(): DisplayServer.clipboard_set(str(md.call().saveDataTF.text)), "Copies the code."]]),
		]},
		{"title": "Character list", "controls": [
			actions("", "", [["Save backup…", func(): _m().saveBackupClicked(), "All stored characters in one file (CustomChars.sdt)."],
				["Load backup…", func(): _m().loadBackupClicked(), "Characters from a backup file, or from a Flash save (ChoIrrumatio.sol)."]],
				{"keywords": "characters backup import export sol"}),
			actions("", "", [["Import from the Loader…", func(): LoaderImport.choose(),
				"Pick the Loader's folder: its stored characters come in with the clothing and hair mods they wear (copied into Mods/, never over your files)."]],
				{"keywords": "loader import characters mods moreclothing"}),
			check("Replace the list when loading", "Off: loaded characters are added to the list.",
				func(): return md.call().cbOverwriteCharList, _m().cbOverwriteCharListClicked),
		]},
		{"title": "Extensions", "controls": [
			{"type": "custom", "label": "", "build": MenuExtensions.build_list},
		]},
	]}


static func _settings() -> Dictionary:
	var om := func(): return _m().optionsMenu
	return {"id": "settings", "name": "Settings", "groups": [
		{"title": "Window", "controls": [
			choice("Window size", "Size of the game window (shrunk to fit a smaller screen). The game fills its height; the room beside it holds the menu.",
				PortSettings.WINDOW_SIZES, func(): return PortSettings.window_size(), func(v: String): PortSettings.set_window_size(v),
				{"dropdown": true}),
			toggle("Fullscreen", "Fill the whole screen. Off: back to the window size above.",
				func(): return PortSettings.fullscreen(), func(on: bool): PortSettings.set_fullscreen(on)),
			toggle("Blurred sides", "Beside the game: a blurred copy of the background. Off: black.",
				func(): return PortSettings.blurred_sides(), func(on: bool): PortSettings.set_value("window", "blurred_sides", on)),
		]},
		{"title": "Menu", "controls": [
			choice("Menu side", "Which side of the screen the menu opens on. The developer panel (Developer mode) opens on the other side.", ["Right", "Left"],
				func(): return PortSettings.get_value("menu", "side", "Right"),
				func(v: String):
					PortSettings.set_value("menu", "side", v)
					SDTMenu.instance.side_setting_changed()),
			toggle("Pause while the menu is open", "Off: the scene keeps playing while you change things.",
				func(): return SDTMenu.pause_on_open(),
				func(on: bool):
					PortSettings.set_value("menu", "pause", on)
					SDTMenu.instance.pause_setting_changed()),
			toggle("Classic menu", "Use the original game's menu instead of this one (switch back in its Options tab).",
				func(): return SDTMenu.classic(),
				func(on: bool):
					PortSettings.set_value("menu", "classic", on)
					SDTMenu.instance.apply_mode()),
			toggle("Developer mode", "A second panel with tools for testing and debugging, on the side opposite the menu. Its DEBUG tab shows when the mouse comes close to that edge.",
				SDTMenu.dev_mode_enabled, SDTMenu.set_dev_mode, {"keywords": "debug developer tools"}),
		]},
		{"title": "Graphics", "controls": [
			# (the classic menu's Quality is not here: it set Flash's vector quality, which the port does not use)
			choice("FPS limit", "Frame rate limit. Off: as many frames as the computer can draw. Monitor: your screen's refresh rate. A limit keeps the graphics card from drawing frames the screen cannot show.",
				PortSettings.FPS_LIMITS, func(): return PortSettings.fps_limit(), func(v: String): PortSettings.set_fps_limit(v)),
			choice("MSAA", "Edge smoothing of strands, drawn shapes and the edges of turned body parts. Off is fastest on weak graphics cards.",
				PortSettings.MSAA_LEVELS.keys(), func(): return PortSettings.msaa(), func(v: String): PortSettings.set_msaa(v)),
			check("Strand shading", "", func(): return om.call().cbStrandShaders, _m().cbStrandShadersClicked),
			check("Show the mouse pointer", "", func(): return om.call().cbShowMouse, _m().cbShowMouseClicked),
			check("Double-size screenshots", "Screenshots (/) at twice the size.", func(): return om.call().cbDoubleSizeScreenshot,
				_m().cbDoubleSizeScreenshotClicked),
		]},
		{"title": "Sound", "controls": [
			_with({"type": "slider", "label": "Volume", "tip": "",
				"get": func(): return om.call().volumeSlider.currentValue(),
				"set": func(v: float): om.call().volumeSlider.setPos(v),
				"release": func(): _m().volumeChanged(),
				"reset": func(): om.call().volumeSlider.setPos(1.0); _m().volumeChanged()}, {}),
			check("Intro sound", "", func(): return om.call().cbIntroSound, _m().cbIntroSoundClicked),
		]},
	]}


static func _help() -> Dictionary:
	return {"id": "help", "name": "Help", "groups": [
		{"title": "Keys", "controls": [
			note("Y U I O P: open this menu (Her, Clothes, Mods, Settings, Help) · Esc: close it\nA: auto mode · Space: hold her\nC / X: next / previous character · B: background on/off · H: show/hide him\n/: screenshot · Shift+/: shuffle her look"),
		]},
		{"title": "Extensions", "controls": [
			note("Options with an orange dot or tag come from an extension. Switch extensions on or off in Mods › Extensions; Vanilla mode switches all of them off and brings back the original menu."),
		]},
	]}


# ---------------------------------------------------------------- extension settings pages

## Pages generated from extensions' settings (one per extension with settings), for search.
static func extension_pages() -> Array:
	var out: Array = []
	for ext in Extensions.all:
		if ext.enabled and not ext.settings().is_empty():
			out.append(extension_page(ext.id))
	return out


static func extension_page(ext_id: String) -> Dictionary:
	var ext: SDTExtension = Extensions.by_id.get(ext_id)
	if ext == null:
		return {}
	var groups: Array = []   # a setting's "group" (default "Settings"), in order of first use
	for s in ext.settings():
		var title: String = s.get("group", "Settings")
		var grp = null
		for gr in groups:
			if gr["title"] == title:
				grp = gr
		if grp == null:
			grp = {"title": title, "controls": []}
			groups.append(grp)
		grp["controls"].append(setting_control(ext, s["key"]))
	return {"id": "ext:" + ext_id, "name": ext.title if ext.title != "" else ext.id, "hidden": true, "parent": "mods",
		"groups": groups}


static func color_dict(c: Color) -> Dictionary:
	return {"r": c.r8, "g": c.g8, "b": c.b8, "a": 1.0}


## The control for one extension setting (from its declaration: type of the default, min / max, options).
static func setting_control(ext: SDTExtension, key: String, extra := {}) -> Dictionary:
	var info: Dictionary = {}
	for s in ext.settings():
		if s["key"] == key:
			info = s
	var label: String = info.get("label", key)
	var tip: String = info.get("desc", "")
	var get_fn := func(): return ext.get_setting(key)
	var spec: Dictionary
	var d = info.get("default")
	if info.has("options"):
		spec = choice(label, tip, info["options"].map(func(o): return str(o)), func(): return str(ext.get_setting(key)),
			func(v: String): ext.set_setting(key, v))
	elif d is bool:
		spec = toggle(label, tip, get_fn, func(on: bool): ext.set_setting(key, on))
	elif d is Color:
		spec = {"type": "color", "label": label, "tip": tip, "alpha": false,
			"get": func(): return color_dict(ext.get_setting(key)),
			"set": func(c: Dictionary): ext.set_setting(key, Color8(c["r"], c["g"], c["b"]))}
	elif (d is int or d is float) and info.has("min") and info.has("max"):
		spec = {"type": "slider", "label": label, "tip": tip, "min": float(info["min"]), "max": float(info["max"]),
			"step": 1.0 if d is int else float(info.get("step", 0.0)), "get": func(): return float(ext.get_setting(key)),
			"set": func(v: float): ext.set_setting(key, v), "reset": func(): ext.set_setting(key, d),
			"format": func(v): return str(int(v)) if d is int else str(snappedf(v, 0.01))}
	else:
		spec = {"type": "text", "label": label, "tip": tip, "get": func(): return str(ext.get_setting(key)),
			"set": func(t: String): ext.set_setting(key, t)}
	spec["restore"] = func(): ext.set_setting(key, d)   # back to the extension's default (a card's reset, MenuFold)
	return _with(spec, extra)
