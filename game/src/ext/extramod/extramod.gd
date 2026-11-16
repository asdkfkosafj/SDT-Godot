extends SDTExtension
## Built-in reimplementation of the Loader mod ExtraMod Core (SClover13, v1.51): mod types for nearly every visible
## part of her, so mods made with the ExtraMod template load. Needs TemplateExtension. Written from its behaviour.
##
## Her head and eyes:
##   BodyHead  face, nose, ear, eyeridge, jaw, upperlip, brows (line / fill), lipstick, teeth, neck. Flags on the mod:
##             hideVanillaFace (hide her own parts it replaces), hideVanillaEyebrows, hideScalp, hideCheekBulge,
##             hideVanillaHeadTan, useSkinPalette (parts have a frame per skin: "light", "pale", "tan", "dark").
##   BodyEye   eyelids (and their mascara / eyeshadow), eyelid masks, iris, sclera, highlights, eyeball, back
##             eyelash, simpleEyeReplacer. Flags: hideVanillaEye, eyeerasemask.
##   Parts with a "mood" child show the frame named after her mood (moremoods' too, else its vanilla group).
## Every tick the mod parts follow her own: eyelid / mask / brow frames, jaw frame and position, lip shape, the
## mascara / eyeshadow colours. Anything it hid comes back when the mods are cleared or the extension is off.
##
## Her body: BodyExpanded (em_body.gd): her arms, hands, thumb, shoulder, chest, breasts, back, hips, legs, with her
## skin, tan, breast size, nail polish and hand positions.
##
## Scene, dialogue, her penis, piercings:
##   Overlay              art on the screen effects, front, back, scene or mist layer; a "diabox" part replaces the
##                        dialogue box picture (an Overlay item named "diabox" is listed with the dialogue box mods).
##   DialogueBox          a new dialogue box picture (the game's own is hidden while one is on).
##   Overlay and DialogueBox mods may set the dialogue text: newColor (hex), newFontSize, dialogueFontName (a font
##   installed on the computer). Dialogue words do the same: [EM_FCOLORff0000], [EM_FSIZE20], [EM_FONTComic_Sans_MS]
##   (underscores are spaces), [EM_FCLEAR] (the game's own font, colour and size again).
##   Futa                 art in her penis container, shown while she has a penis.
##   CostumeBrowPiercing  rightbrowpierce / leftbrowpierce: follow her eyebrows (position and frame).
##   CostumeNosePiercing  on her nose.
##   With overwrite = true a mod of these types takes off the others of its type.

## Containers next to her own parts, for mod parts that replace them: name -> [path of her part it sits next to,
## copy that part's transform, blend mode]
const CONTAINERS := {
	"eyeball": ["eye.ball.sclera", true, ""],
	"uppereyelid": ["eye.upperEyelid", true, ""], "lowereyelid": ["eye.lowerEyelid", true, ""],
	"uppereyelidmask": ["eye.ball.upperEyelidMask", true, "erase"],
	"lowereyelidmask": ["eye.ball.lowerEyelidMask", true, "erase"],
	"jaw": ["head.jaw", true, ""], "upperlip": ["head.face", true, ""], "overjaw": ["head.jaw", false, ""],
	"backeyelash": ["head", true, ""],
	"rightbrowpierce": ["rightEyebrow", true, ""], "leftbrowpierce": ["leftEyebrow", true, ""],
	"nosepierce": ["head.face.nose", true, ""],
	"thumb": ["leftHandOver.hand", true, ""],
}
const HEAD_PARTS := {"nosemask": "head.face.nose", "neckmask": "head.neck", "neck": "head.neck",
	"face": "head.face.skull", "eyeridge": "eye.eyebrowUnderMask", "ear": "ear", "nose": "head.face.nose",
	"rightbrowline": "rightEyebrow", "rightbrowfill": "rightEyebrow", "leftbrowline": "leftEyebrow",
	"leftbrowfill": "leftEyebrow", "upperlip": "#upperlip", "jaw": "#jaw", "overjaw": "#overjaw",
	"upperlipstick": "topLipstickContainer", "lowerlipstick": "bottomLipstick", "upperteeth": "head.teeth",
	"lowerteeth": "head.jaw.teeth"}
const EYE_PARTS := {"placeholder": "eye", "eyeerasemask": "eye", "altsclera": "eye.ball.sclera",
	"alteyeball": "#eyeball", "altiris": "eye.ball.irisContainer.iris", "althighlights": "eye.ball.highlights",
	"altUpperEyelidMask": "#uppereyelidmask", "altLowerEyelidMask": "#lowereyelidmask",
	"altuppereyelid": "#uppereyelid", "altlowereyelid": "#lowereyelid", "backeye": "#backeyelash",
	"simpleEyeReplacer": "eye"}
## Targets of the other types ("#": a container above, "@": a member of g, else a path under her)
const OTHER_TYPES := {
	"CostumeBrowPiercing": {"rightbrowpierce": "#rightbrowpierce", "leftbrowpierce": "#leftbrowpierce"},
	"CostumeNosePiercing": {"target": "#nosepierce"},
	"Overlay": {"screenlayer": "@screenEffects", "frontlayer": "@frontLayer", "backlayer": "@backLayer",
		"scenelayer": "@sceneLayer", "mistlayer": "@mistLayer", "diabox": "@dialogueControl"},
	"DialogueBox": {"target": "@dialogueControl"},
	"Futa": {"target": "torso.penisContainer"},
}
const ALL_TYPES := ["BodyHead", "BodyEye", "CostumeBrowPiercing", "CostumeNosePiercing", "Overlay", "DialogueBox",
	"Futa", "BodyExpanded"]
const EmBody := preload("res://src/ext/extramod/em_body.gd")

## Her own parts a hideVanillaFace head mod covers: their first child is hidden (on load and skin changes)
const FACE_COVERS := {"nose": "head.face.nose", "ear": "ear", "eyeridge": "eye.eyebrowUnderMask",
	"face": "head.face.skull", "upperteeth": "head.teeth"}
## Extended moods -> the vanilla mood a part falls back to
const MOOD_GROUPS := {"happy": ["happy", "elated", "excited", "smug", "tease"],
	"normal": ["normal", "android", "tease", "submissive", "depressed", "spent"],
	"angry": ["angry", "upset", "frightened", "aggressive", "worried", "disgusted"],
	"ahegao": ["ahegao", "horny", "overwhelmed", "devoted", "broken", "drugged"]}

const LIST := "extramod"   # the mod catalog's list of ExtraMod mods (Her > Face in the new menu)
const PIERCING_LIST := "extramod_piercings"   # Clothes > Piercings
const FUTA_LIST := "extramod_futa"            # Her > Body
const OVERLAY_LIST := "extramod_overlays"     # Scene > Overlays
const DIABOX_LIST := "extramod_diabox"        # Dialogue > Dialogue
const BODY_LIST := "extramod_body"            # Her > Body

var c := {}               # container name -> FlashSprite
var body = null           # em_body.gd: the BodyExpanded type
var _mood_parts: Array = []    # parts with a "mood" child
var _skin_parts: Array = []    # parts (useSkinPalette) shown at the frame named after her skin
var _face_covers: Array = []   # FACE_COVERS keys some hideVanillaFace mod replaces
var _eye_masks := false        # a mod brings its own eyelid masks
var _eye_set := false
var _hide := {}                # what is hidden: "jaw", "upperlip", "brows", "headtan", "upperlipstick", ...
var _lower_lipsticks: Array = []
var _lip_offset := 0           # her lip / jaw frames: 81 per skin
## Every ExtraMod mod placed: {"pkg": its LoadedModPackage, "type", "flags": {flag: value}}, replayed when one of them
## is taken off alone (the others keep what they need hidden)
var _records: Array = []
var _dia_mods := false         # a mod replaces the dialogue box picture (the game's box is hidden)
var _dia_color = null          # dialogue text colour / size set by a mod or an EM_ word (null: the game's)
var _dia_size = null
var _dia_font := false         # a mod or an EM_ word set a font
var _futa := false
var _others: Array = []        # [package, mod] of the mods of the other types, replayed like _records
var _brow_pierce := false
const FLAG_KEYS := ["overwrite", "hideVanillaFace", "hideVanillaEye", "hideVanillaEyebrows", "hideVanillaHeadTan",
	"hideScalp", "hideCheekBulge", "useSkinPalette"]


func _init() -> void:
	id = "extramod"
	title = "ExtraMod"
	description = "ExtraMod Core (SClover13): mod types for her head and eyes, overlays, dialogue boxes, her penis and brow / nose piercings, for mods made with the ExtraMod template. Needs TemplateExtension."
	default_enabled = true


func _enable() -> void:
	var her = g.her
	for n in CONTAINERS:
		var d: Array = CONTAINERS[n]
		var beside = _node(d[0])
		if beside == null or beside._flash_parent == null:
			push_warning("ExtraMod: no %s" % d[0])
			continue
		var s := FlashSprite.new()
		s.flash_name = "em_" + n
		beside._flash_parent.addChild(s)
		if d[1]:
			s.transform = beside.transform
		if d[2] != "":
			s.blendMode = d[2]
		c[n] = s
	if c.has("backeyelash"):
		c["backeyelash"]._flash_parent.setChildIndex(c["backeyelash"], 0)   # behind her head
	if c.has("thumb"):
		c["thumb"].visible = false
	body = EmBody.new(self)
	body.register()
	_register("BodyHead", HEAD_PARTS)
	_register("BodyEye", EYE_PARTS)
	for t in OTHER_TYPES:
		_register(t, OTHER_TYPES[t])
	_lip_offset = g.characterControl.currentSkin * 81
	hook_after(&"CustomElementLoader.addStaticModElement", func(h): _placed(h.args[0]))
	hook_after(&"CustomElementLoader.clearInstancedMods", func(_h): _reset())
	hook_after(&"Her.updateEyes", func(_h): _follow_eyes())
	hook_after(&"Her.updateLips", func(_h): _follow_mouth())
	hook_after(&"CharacterControl.setSkin", func(h): _skin_changed(h.args[0]))
	hook_after(&"CharacterControl.setEyebrowFill", func(h): _brow_colour("fill", h.args[0]))
	hook_after(&"CharacterControl.setEyebrowLine", func(h): _brow_colour("line", h.args[0]))
	hook_after(&"HerPenisControl.updatePenis", func(_h): _update_futa())
	for ev in ["Her.setRightArmPosition", "Her.setLeftArmPosition", "CharacterControl.setBreasts",
			"CharacterControl.setNailPolish", "CharacterControl.applySkinHSL"]:
		hook_after(StringName(ev), func(_h): _body_event(ev))
	hook_after(&"Dialogue.startSpeakingPhrase", func(_h): _update_dia())
	hook_before(&"Dialogue.checkWordAction", _on_word)
	on_event("mood_changed", func(_m): _update_moods())
	on_late_tick(_tick)
	if g.modCatalog != null:
		g.modCatalog.add_picker(LIST, ["BodyHead", "BodyEye"])
		g.modCatalog.add_picker(PIERCING_LIST, ["CostumeBrowPiercing", "CostumeNosePiercing"])
		g.modCatalog.add_picker(FUTA_LIST, ["Futa"])
		g.modCatalog.add_picker(OVERLAY_LIST, ["Overlay"])
		g.modCatalog.add_picker(DIABOX_LIST, ["DialogueBox", "Overlay/diabox"])   # overlays made as a dialogue box too
		g.modCatalog.add_picker(BODY_LIST, ["BodyExpanded"])
		# whole-body mods: one switch for their face, hair, clothes and body
		g.modCatalog.merge_pickers([LIST, "hair", g.modCatalog.COSTUME], BODY_LIST)
	menu_control("her", "Face", {"type": "custom", "label": "ExtraMod face and eye mods", "wide": true,
		"tip": "Face, eye and eyebrow mods made with ExtraMod, from Mods/Clothing. Several can be on: they stack.",
		"build": func(): return ModSwitchList.build(LIST, _toggle), "keywords": "extramod em emc face eyes eyebrows anime"})
	menu_control("clothes", "Piercings", {"type": "custom", "label": "Brow and nose piercing mods", "wide": true,
		"tip": "Eyebrow and nose piercings made with ExtraMod, from Mods/Clothing.",
		"build": func(): return ModSwitchList.build(PIERCING_LIST, _toggle, "None found in Mods/Clothing."),
		"keywords": "extramod piercing brow eyebrow nose"})
	menu_control("her", "Body", {"type": "custom", "label": "Penis mods", "wide": true,
		"tip": "Art for her penis made with ExtraMod (Futa mods), from Mods/Clothing. Shown while she has a penis (Penis above).",
		"build": func(): return ModSwitchList.build(FUTA_LIST, _toggle, "None found in Mods/Clothing."),
		"keywords": "extramod futa penis"})
	menu_control("her", "Body", {"type": "custom", "label": "ExtraMod body mods", "wide": true,
		"tip": "Body mods made with ExtraMod (BodyExpanded): arms, hands, chest, breasts, back, hips, legs, from Mods/Clothing. A mod that also brings face parts, hair or clothes is one switch here.",
		"build": func(): return ModSwitchList.build(BODY_LIST, _toggle, "None found in Mods/Clothing."),
		"keywords": "extramod body expanded arms hands legs breasts skin"})
	menu_control("scene", "Overlays", {"type": "custom", "label": "Overlay mods", "wide": true,
		"tip": "Art over or behind the scene made with ExtraMod (Overlay mods), from Mods/Clothing. Some also change the dialogue box or its text.",
		"build": func(): return ModSwitchList.build(OVERLAY_LIST, _toggle, "None found in Mods/Clothing."),
		"keywords": "extramod overlay screen layer mist frame"})
	menu_control("dialogue", "Dialogue", {"type": "custom", "label": "Dialogue box mods", "wide": true,
		"tip": "Dialogue box pictures made with ExtraMod, from Mods/Clothing; some also change the text colour, size or font.",
		"build": func(): return ModSwitchList.build(DIABOX_LIST, _toggle, "None found in Mods/Clothing."),
		"keywords": "extramod dialogue box font text colour"})
	her.updateEyes()


func _disable() -> void:
	if g.modCatalog != null:
		for k in [LIST, PIERCING_LIST, FUTA_LIST, OVERLAY_LIST, DIABOX_LIST, BODY_LIST]:
			g.modCatalog.remove_picker(k)
	var cel = g.customElementLoader
	if cel != null:
		cel.clearModTypes(ALL_TYPES)
		for t in ALL_TYPES:
			cel.modTargetHelpers.erase(t)
	_reset()
	for n in c:
		if c[n]._flash_parent != null:
			c[n]._flash_parent.removeChild(c[n])
	c.clear()


func _register(type: String, parts: Dictionary) -> void:
	var d := {}
	for p in parts:
		var path: String = parts[p]
		var o
		if path.begins_with("#"):
			o = c.get(path.substr(1))
		elif path.begins_with("@"):
			o = g.get(path.substr(1))
		else:
			o = _node(path)
		if o != null:
			d[p] = o
	g.customElementLoader.modTargetHelpers[type] = CustomElementHelper.new(d)   # direct: registers a mod target


## Her display object by a dotted path ("eye.ball.sclera"), null if a part is missing.
func _node(path: String):
	var o = g.her
	for part in path.split("."):
		o = o.get(part) if o != null else null
		if not o is Object:
			return null
	return o


## The mod's placed parts of `type` named `part_name`.
func _parts(type: String, part_name := "") -> Array:
	var out: Array = []
	for lm in g.customElementLoader.instancedModElements:
		if lm._modType == type and lm._mod != null and is_instance_valid(lm._mod) \
				and (part_name == "" or lm._mod.flash_name == part_name):
			out.append(lm._mod)
	return out


static func _child(o, n: String):
	return o.getChildByName(n) if o is FlashSprite else null


static func _frame(mc, f: int) -> void:
	if mc is FlashMovieClip:
		mc.gotoAndStop(f if f >= 1 and f <= mc.totalFrames else 1)


static func _label(mc, label: String, fallback = "None") -> void:
	if not mc is FlashMovieClip:
		return
	if mc.has_label(label):
		mc.gotoAndStop(label)
	elif fallback is int:
		mc.gotoAndStop(fallback)
	elif mc.has_label(fallback):
		mc.gotoAndStop(fallback)


## Hides all children of `o` except the last `keep` (the mod parts just placed into it).
static func _hide_children(o, keep := 1) -> void:
	if o is FlashSprite:
		for i in maxi(0, o.numChildren - keep):
			o.getChildAt(i).visible = false


# ---------------------------------------------------------------- the list of mods in the menu

## A switch per ExtraMod mod found in Mods/Clothing (the list grows while the catalog scans).
func _toggle(on: bool, e: Dictionary) -> void:
	if on:
		g.modCatalog.clear_slots_for(e)   # a whole-body mod's hair and clothes take her own off, as their pickers do
		g.modCatalog.apply(e)
	else:
		g.modCatalog.remove_entry(e)
		_rebuild()


## After one mod was taken off: her own parts back, then what the remaining mods need hidden again.
func _rebuild() -> void:
	var live := {}
	for lm in g.customElementLoader.instancedModElements:
		live[lm.sourcePackage] = true
	var keep: Array = _records.filter(func(r): return live.has(r["pkg"]))
	var others: Array = _others.filter(func(o): return live.has(o[0]) and is_instance_valid(o[1]))
	_reset()
	_records = keep
	_others = others
	for r in keep:
		_apply(r, false)
	for o in others:
		_other_placed(str(o[1].get("modType")), o[1], false, o[0])


# ---------------------------------------------------------------- a mod was placed

func _placed(m) -> void:
	if m == null or not m is FlashDisplayObject:
		return
	var t := str(m.get("modType"))
	if not t in ALL_TYPES:
		return
	if t != "BodyHead" and t != "BodyEye":
		_others.append([g.customElementLoader.loadingModPackage, m])
		_other_placed(t, m, true, g.customElementLoader.loadingModPackage)
		return
	var r := {"pkg": g.customElementLoader.loadingModPackage, "type": t, "flags": {}}
	for f in FLAG_KEYS:
		r["flags"][f] = m.get(f)
	_records.append(r)
	_apply(r, true)


## What a placed mod (record) needs: its flags acted on, its parts registered. `first`: the mod was just placed
## (overwrite clears the other mods of its type).
func _apply(r: Dictionary, first: bool) -> void:
	var t: String = r["type"]
	var m: Dictionary = r["flags"]
	if first and m.get("overwrite"):
		g.customElementLoader.clearModTypes([t])
		_records = _records.filter(func(x): return x == r or x["type"] != t or x["pkg"] == r["pkg"])
	# the parts are placed already: look at what the mods brought
	var parts: Dictionary = {}
	for p in _parts(t):
		parts[str(p.flash_name)] = p
	for p in parts.values():
		if _child(p, "mood") != null and not p in _mood_parts:
			_mood_parts.append(p)
	if m.get("useSkinPalette"):
		for p in _parts("BodyHead"):
			if not p in _skin_parts:
				_skin_parts.append(p)
		_set_skin_frames()
	if t == "BodyEye":
		_eye_placed(m, parts)
	else:
		_head_placed(m, parts)
	_update_moods()
	# new clips play their own timelines: put them on her frames now (also while the game is paused, e.g. a mod
	# switched on in the menu, when her eyes do not update)
	_follow_eyes()
	_follow_mouth()


func _eye_placed(m: Dictionary, parts: Dictionary) -> void:
	var her = g.her
	_eye_set = true
	var erase = parts.get("eyeerasemask")
	if erase != null:
		erase.blendMode = "erase"
	if parts.has("altUpperEyelidMask") or parts.has("altLowerEyelidMask"):
		_eye_masks = true
	if not m.get("hideVanillaEye"):
		return
	if parts.has("altuppereyelid"):
		her.eye.upperEyelid.visible = false   # direct: replaced by a mod's art
	if parts.has("altlowereyelid"):
		her.eye.lowerEyelid.visible = false   # direct: replaced by a mod's art
	for p in [["altsclera", "eye.ball.sclera"], ["althighlights", "eye.ball.highlights"],
			["altiris", "eye.ball.irisContainer.iris"]]:
		if parts.has(p[0]):
			_hide_children(_node(p[1]))
	_hide["eye"] = true


func _head_placed(m: Dictionary, parts: Dictionary) -> void:
	var her = g.her
	if m.get("hideVanillaHeadTan"):
		_hide["headtan"] = true
	if m.get("hideScalp"):
		her.head.scalpHair.visible = false   # direct: replaced by a mod's art
		_hide["scalp"] = true
	if m.get("hideCheekBulge"):
		her.head.cheekBulge.visible = false   # direct: replaced by a mod's art
		her.head.cheekSuck.visible = false   # direct: replaced by a mod's art
		_hide["cheeks"] = true
	if parts.has("lowerlipstick") and not parts["lowerlipstick"] in _lower_lipsticks:
		_lower_lipsticks.append(parts["lowerlipstick"])
	if m.get("hideVanillaEyebrows"):
		_hide_children(her.rightEyebrow, 2)
		_hide_children(her.leftEyebrow, 2)
		_hide["brows"] = true
	if m.get("hideVanillaFace"):
		for k in FACE_COVERS:
			if parts.has(k) and not k in _face_covers:
				_face_covers.append(k)
		if parts.has("jaw"):
			_hide["jaw"] = true
			her.head.jawBack.visible = false   # direct: replaced by a mod's art
		if parts.has("upperlip"):
			_hide["upperlip"] = true
		if parts.has("upperlipstick"):
			_hide["upperlipstick"] = true
		if parts.has("lowerlipstick"):
			_hide["lowerlipstick"] = true
		_hide_face()
	if parts.has("jaw") or parts.has("upperlip"):
		for n in ["cheekBulge", "cheekSuck", "cheekMask"]:   # her cheeks over the mod's jaw and lip
			var o = her.head.get(n)
			if o != null:
				her.head.setChildIndex(o, her.head.numChildren - 1)
	if parts.has("rightbrowfill") or parts.has("leftbrowfill"):
		var cc = g.characterControl
		_brow_colour("fill", cc.eyebrowFillRGB)
		_brow_colour("line", cc.eyebrowLineRGB)
	_follow_mouth()


## Her own face parts the mods replace stay hidden (her skin or the game can show them again).
func _hide_face() -> void:
	var her = g.her
	for k in _face_covers:
		var o = _node(FACE_COVERS[k])
		if o is FlashSprite and o.numChildren > 0:
			o.getChildAt(0).visible = false
	if _hide.get("jaw", false):
		_hide_children(her.head.jaw, 0)
	if _hide.get("upperlip", false):
		for n in ["lipFill", "lipOutline", "lipShading"]:
			_hide_children(her.head.face.get(n), 0)
	if _hide.get("upperlipstick", false):
		_hide_children(her.topLipstickContainer.get("topLipstick"), 0)
	if _hide.get("lowerlipstick", false):
		var bl = her.bottomLipstick
		for i in bl.numChildren:
			if not bl.getChildAt(i) in _lower_lipsticks:
				bl.getChildAt(i).visible = false
	if _hide.get("headtan", false) and her.head.get("headTan") != null:
		her.head.headTan.visible = false   # direct: replaced by a mod's art


# ---------------------------------------------------------------- scene, dialogue, her penis, piercings

func _other_placed(t: String, m, first: bool, pkg = null) -> void:
	if first and m.get("overwrite") and t != "Futa" and t != "BodyExpanded":
		g.customElementLoader.clearModTypes([t])
	match t:
		"BodyExpanded":
			body.placed(m, first, pkg)
		"Futa":
			_futa = true
			_update_futa()
		"CostumeBrowPiercing":
			_brow_pierce = true
			_follow_eyes()
		"Overlay", "DialogueBox":
			_dia_text_from(m)
			_update_dia()


## A mod's dialogue text settings (newColor: hex string or number, newFontSize, dialogueFontName).
func _dia_text_from(m) -> void:
	var col = m.get("newColor")
	if col != null and str(col) != "":
		var n: int = _hex(str(col)) if col is String else int(col)
		_dia_color = n if n >= 0 else 9030   # ExtraMod's fallback for a bad colour code
	var font = m.get("dialogueFontName")
	if font != null and str(font) != "":
		g.dialogueControl.setCustomFont(str(font))
		_dia_font = true
	var size = m.get("newFontSize")
	if size != null and float(size) > 0:
		_dia_size = float(size)
	_dia_format()


## "ff0000" or "0xff0000" -> the number, -1 if it is not one.
static func _hex(t: String) -> int:
	t = t.strip_edges().trim_prefix("_").trim_prefix("#")
	if t.to_lower().begins_with("0x"):
		t = t.substr(2)
	return t.hex_to_int() if t != "" and t.is_valid_hex_number() else -1


## The dialogue text gets the mods' colour and size (the game's own font changes put them back otherwise).
func _dia_format() -> void:
	if _dia_color == null and _dia_size == null:
		return
	var field = g.dialogueControl.tfContainer.dialogueField
	var fmt := {}
	if _dia_color != null and field.textColor != _dia_color:
		fmt["color"] = _dia_color
	if _dia_size != null and field._font_size != _dia_size:
		fmt["size"] = _dia_size
	if not fmt.is_empty():
		field.setTextFormat(fmt)


## The dialogue box picture: a mod's replaces the game's.
func _update_dia() -> void:
	var dc = g.dialogueControl
	var mods: Array = _parts("Overlay", "diabox") + _parts("DialogueBox")   # ExtraMod's order
	var was := _dia_mods
	_dia_mods = not mods.is_empty()
	for p in mods:
		if p._flash_parent == dc:
			dc.setChildIndex(p, 0)
	if was and not _dia_mods:
		_game_box(true)
	_tell_subtitles()   # the Subtitles look gives way to the box mod (its Classic box), or comes back
	if _dia_mods:
		_game_box(false)   # again at each line: every style has its own box picture
	_dia_format()   # the mods' text colour / size again (a change of look sets the text's own)


## Shows or hides the game's own dialogue box pictures (the box of each style).
func _game_box(on: bool) -> void:
	var dc = g.dialogueControl
	if dc == null:
		return
	for i in dc.numChildren:
		var c = dc.getChildAt(i)
		if c is FlashShape and Dialogue.BOX_FILL_ALPHA.has(c._char_id):
			c.visible = on


func _tell_subtitles() -> void:
	var st = Extensions.get_extension("subtitles")
	if st != null and st.enabled:
		st.box_mods(_dia_mods)


## Dialogue words [EM_FCLEAR], [EM_FONT<name>], [EM_FSIZE<n>], [EM_FCOLOR<hex>]: done at once, the line goes on.
func _on_word(h) -> void:
	var raw: String = h.args[0]
	if not raw.begins_with("[EM_F"):
		return
	var a := raw.substr(1, raw.length() - 2)
	var dc = g.dialogueControl
	if a == "EM_FCLEAR":
		_dia_color = null
		_dia_size = null
		_dia_font = false
		dc.setDefaultFont()
	elif a.begins_with("EM_FONT"):
		var font_name := a.substr(7).trim_prefix("_").replace("_slash5C_", "\\").replace("_", " ")
		if font_name != "":
			dc.setCustomFont(font_name)
			_dia_font = true
	elif a.begins_with("EM_FSIZE"):
		var v := a.substr(8).trim_prefix("_")
		if v.is_valid_float() and float(v) > 0:
			_dia_size = float(v)
	elif a.begins_with("EM_FCOLOR"):
		var n := _hex(a.substr(9))
		if n >= 0:
			_dia_color = n
	else:
		return
	_dia_format()
	dc.nextWord()
	h.cancel()


## Futa parts show while she has a penis.
func _update_futa() -> void:
	if not _futa:
		return
	var on: bool = g.her._penisControl.currentPenisID != 0
	for p in _parts("Futa"):
		p.visible = on


# ---------------------------------------------------------------- skin, moods, brow colours

## Her arms, breasts, nail polish or skin colour changed: the BodyExpanded parts follow.
func _body_event(ev: String) -> void:
	if body == null or not body.on:
		return
	match ev:
		"Her.setRightArmPosition":
			body.right_hand()
		"Her.setLeftArmPosition":
			body.left_hand()
		"CharacterControl.setBreasts":
			body.breasts()
		"CharacterControl.setNailPolish":
			body.nails()
		"CharacterControl.applySkinHSL":
			body.skin_hsl()
	body.hide_vanilla()


func _skin_changed(skin: int) -> void:
	_lip_offset = skin * 81
	_set_skin_frames()
	_hide_face()
	if body != null and body.on:
		body.skin()
		body.breasts()
		body.hide_vanilla()


func _set_skin_frames() -> void:
	var label: String = g.dataName(CharacterControl.skinNameList[g.characterControl.currentSkin])
	_skin_parts = _skin_parts.filter(func(p): return is_instance_valid(p))
	for p in _skin_parts:
		_label(p, label)


func _update_moods() -> void:
	var mood := str(Moods.current()).to_lower()
	_mood_parts = _mood_parts.filter(func(p): return is_instance_valid(p))
	for p in _mood_parts:
		var mc = _child(p, "mood")
		if not mc is FlashMovieClip:
			continue
		if mc.has_label(mood):
			mc.gotoAndStop(mood)
			continue
		var done := false
		for v in MOOD_GROUPS:
			if mood in MOOD_GROUPS[v] and mc.has_label(v):
				mc.gotoAndStop(v)
				done = true
				break
		if not done:
			mc.gotoAndStop(1)


func _brow_colour(which: String, rgb) -> void:
	if rgb == null:
		return
	var ct := FlashColorTransform.new(1, 1, 1, rgb.a, rgb.r, rgb.g, rgb.b)
	for side in ["right", "left"]:
		for p in _parts("BodyHead", side + "brow" + which):
			p.colorTransform = ct


# ---------------------------------------------------------------- every tick

## After her eyes update: the mod's eyelids, masks and back eyelash on her current frames, with her mascara and
## eyeshadow colours.
func _follow_eyes() -> void:
	var her = g.her
	for side in [["right", her.rightEyebrow, "rightEyebrow"], ["left", her.leftEyebrow, "leftEyebrow"]]:
		for which in ["Line", "Fill"]:
			var hers = side[1].get(side[2] + which)
			if hers == null:
				continue
			for p in _parts("BodyHead", side[0] + "brow" + which.to_lower()):
				_frame(p, hers.currentFrame)
			if which == "Fill" and _brow_pierce:
				c[side[0] + "browpierce"].transform = side[1].transform
				for p in _parts("CostumeBrowPiercing", side[0] + "browpierce"):
					_frame(p, hers.currentFrame)
	var eye = her.eye
	var ball = eye.ball
	ball.upperEyelidMask.visible = not _eye_masks
	ball.lowerEyelidMask.visible = not _eye_masks
	if c.has("uppereyelidmask"):
		c["uppereyelidmask"].visible = _eye_masks
		c["lowereyelidmask"].visible = _eye_masks
	if not _eye_set:
		return
	for p in _parts("BodyEye", "altUpperEyelidMask"):
		_frame(p, ball.upperEyelidMask.currentFrame)
	for p in _parts("BodyEye", "altLowerEyelidMask"):
		_frame(p, ball.lowerEyelidMask.currentFrame)
	for lid in [["altuppereyelid", eye.upperEyelid], ["altlowereyelid", eye.lowerEyelid]]:
		for p in _parts("BodyEye", lid[0]):
			_frame(p, lid[1].currentFrame)
			for n in ["mascara", "eyeshadow"]:
				var mine = _child(p, n)
				var hers = lid[1].get(n) if n == "mascara" else eye.upperEyelid.get(n)
				if mine != null and hers != null:
					_frame(mine, hers.currentFrame)
					mine.colorTransform = hers.colorTransform
	for p in _parts("BodyEye", "backeye"):
		_frame(p, eye.upperEyelid.currentFrame)
	for p in _parts("BodyEye", "simpleEyeReplacer"):
		_frame(p, eye.upperEyelid.currentFrame)
		for n in ["mascara", "eyeshadow"]:
			var mine = _child(p, n)
			var hers = eye.upperEyelid.get(n)
			if mine != null and hers != null:
				_frame(mine, eye.upperEyelid.currentFrame)
				mine.colorTransform = hers.colorTransform


## After her lips update: the mod's jaw follows hers (position and frame), the upper lip her lip shape.
func _follow_mouth() -> void:
	var her = g.her
	var head = her.head
	for p in _parts("BodyHead"):
		match str(p.flash_name):
			"upperlip":
				_frame(p, head.face.currentFrame)
				var shape = _child(p, "shape")
				if shape != null:
					_frame(shape, head.face.lipOutline.currentFrame + _lip_offset)
					_tan_child(shape)
			"upperlipstick":
				_frame(p, her.topLipstickContainer.currentFrame)
				var shape = _child(p, "shape")
				if shape != null:
					_frame(shape, her.topLipstickContainer.topLipstick.currentFrame)
			"lowerlipstick":
				_frame(p, her.bottomLipstick.currentFrame)
			"jaw":
				if c.has("jaw"):
					c["jaw"].transform = head.jaw.transform
				_frame(p, head.jaw.currentFrame - _lip_offset if p.totalFrames < 82 else head.jaw.currentFrame)
				_tan_child(p)


## A mod part's "tan" child shows her tan lines like her own skin does.
func _tan_child(part) -> void:
	var t = _child(part, "tan")
	if t == null:
		return
	var tan = g.her._tan
	var back_tan = g.her.torso.back.get("tan")
	var on: bool = tan._tanNameList[tan._currentTanID] != "None" and back_tan != null and back_tan.alpha > 0.05
	t.visible = on
	if on:
		t.alpha = back_tan.alpha


func _tick() -> void:
	if _dia_color != null or _dia_size != null:
		_dia_format()
	if body != null and body.on:
		body.tick()
	if _hide.is_empty() and _skin_parts.is_empty() and not _eye_set:
		if _brow_pierce and g.gamePaused:
			_follow_eyes()
		return
	var her = g.her
	if _hide.get("jaw", false):
		_hide_children(her.head.jaw)   # the game shows its jaw pieces again as she moves
	if _hide.get("upperlip", false) or _hide.get("headtan", false) or _hide.get("lowerlipstick", false):
		_hide_face()
	if g.gamePaused:   # her own updates stop while paused; the mod parts must not play on by themselves
		_follow_eyes()
		_follow_mouth()


# ---------------------------------------------------------------- mods cleared

## Everything the mods hid comes back.
func _reset() -> void:
	_reset_other()
	var her = g.her
	if her == null or (_hide.is_empty() and not _eye_set and _skin_parts.is_empty() and _mood_parts.is_empty()):
		return   # nothing was changed: the game's own clearing stays as it is
	if _hide.get("eye", false) or _eye_set:
		var e = her.eye
		for o in [e, e.ball, e.ball.irisContainer.iris, e.ball.sclera, e.ball.highlights, e.upperEyelid,
				e.upperEyelid.get("mascara"), e.upperEyelid.get("eyeshadow"), e.lowerEyelid,
				e.lowerEyelid.get("mascara"), e.ball.upperEyelidMask, e.ball.lowerEyelidMask]:
			if o is FlashSprite:
				o.visible = true
				for i in o.numChildren:
					o.getChildAt(i).visible = true
	if _hide.get("brows", false):
		for b in [her.rightEyebrow, her.leftEyebrow]:
			for i in b.numChildren:
				b.getChildAt(i).visible = true
	var head = her.head
	for o in [head, head.face, head.face.skull, head.jaw, head.face.nose, her.ear, her.topLipstickContainer,
			her.bottomLipstick, her.topLipstickContainer.get("topLipstick"), head.jawBack, head.face.lipFill,
			head.face.lipOutline, head.face.lipShading, her.eye.eyebrowUnderMask]:
		if o is FlashSprite:
			o.visible = true
			for i in o.numChildren:
				o.getChildAt(i).visible = true
	head.scalpHair.visible = true
	head.cheekBulge.visible = true
	head.cheekSuck.visible = true
	if head.get("headTan") != null:
		head.headTan.visible = true
	_hide.clear()
	_face_covers.clear()
	_mood_parts.clear()
	_skin_parts.clear()
	_lower_lipsticks.clear()
	_records.clear()
	_eye_masks = false
	_eye_set = false
	her._tan.updateSkin()
	her.updateEyes()


## The dialogue box and text, her penis parts and brow piercings back to the game's.
func _reset_other() -> void:
	if body != null:
		body.reset()
	if _dia_mods:
		_dia_mods = false
		_game_box(true)
		_tell_subtitles()
	_dia_mods = false
	var dc = g.dialogueControl
	if dc != null and (_dia_font or _dia_color != null or _dia_size != null):
		dc.setDefaultFont()
	_dia_color = null
	_dia_size = null
	_dia_font = false
	_futa = false
	_brow_pierce = false
	_others.clear()
