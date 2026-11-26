extends RefCounted
## The position editor (the menu page "positions_edit", opened with Edit / New on the Positions page): animtools'
## position keys in folding cards (sliders, switches, choices), the open cards' points as handles on the scene
## (PositionHandles: hold Ctrl and drag), undo, and saving into Mods/Positions/My positions as an animtools .txt with
## a 700x600 thumbnail of the scene. The files the game comes with (Mods/Positions/animtools) are never written:
## saving one of them makes a copy. Changes show at once: path, knee, feet and torso numbers update her and his
## animation only; other keys apply the whole position again (at most once a tick).

const Position := preload("res://src/ext/positions/position.gd")
const Fields := preload("res://src/ext/positions/position_fields.gd")
const Handles := preload("res://src/ext/positions/position_handles.gd")
const Browser := preload("res://src/ext/positions/position_browser.gd")
const Arms := preload("res://src/ext/positions/position_arms.gd")

const SECTION := "positions_edit"
const MY_FOLDER := "My positions"
const UNSET := -5000.0
const TYPES := ["Oral", "Tit fuck", "Vaginal", "Anal", "Other", "Alt pleasure"]
const DOMINANT := ["Neutral", "Her", "Him"]

## Keys whose change needs only the animation rebuilt (MainAnimation: paths, feet, knee, torso numbers).
const ANIM_KEYS := ["hertweenstartx", "hertweenstarty", "hertweenendx", "hertweenendy", "hertweenstartang",
	"hertweenendangle", "histweenstartx", "histweenstarty", "histweenendx", "histweenendy", "histweenstartang",
	"histweenendangle", "leftfootx", "leftfooty", "rightfootx", "rightfooty", "offpathposmovement", "torsominang",
	"torsostartangle", "torsoanglemodifier", "torsomindistance", "torsostartdistance", "torsodistancemultiplier",
	"torsoikoffsetang", "torsoendrotationangle", "torsox", "torsoy", "torsox2", "torsoy2"]

const SCENE_X := [-1500.0, 2000.0]
const SCENE_Y := [-1000.0, 2500.0]
const HIS_X := [-900.0, 900.0]

## [title, fields, handles]. A field: [key, label, kind, a, b]: kind "n" a slider from a to b, "f" a switch, "c" a
## choice (a: the option names, the value is the index), "a" her arm type (-1 keep, 0-4 the game's, 5-11 animtools',
## 12 Custom), "r" radians shown in degrees from a to b. A handle:
## [label, x key, y key, angle key ("" none; "deg:" + key for degrees), space, colour].
const CARDS := [
	["Position", [
		["positiontype", "Type", "c", TYPES], ["dominant", "Who leads", "c", DOMINANT],
		["maxpenissize", "Max penis size", "n", 0.0, 999.0], ["reversescreen", "Screen mirror", "c", ["Player's", "Normal", "Reversed"]],
		["enablelicking", "Licking", "c", ["Off", "On", "Player's"]], ["hisarmfree", "His arm free", "c", ["No", "Yes", "Player's"]],
	], []],
	["Scene & camera", [
		["camerax", "Camera x", "n", -600.0, 1200.0], ["cameray", "Camera y", "n", -600.0, 1000.0],
		["zoom", "Zoom", "n", 0.1, 1.5], ["zoompointx", "Zoom point x", "n", -1000.0, 1500.0],
		["zoompointy", "Zoom point y", "n", -500.0, 2000.0], ["scenerotation", "Scene rotation", "n", -180.0, 180.0],
		["changegravityforstrands", "Strands fall to the screen's bottom", "f"],
		["changegravityforhairstrands", "Hair falls to the screen's bottom", "f"],
		["angledgravity", "Angled gravity force", "n", 0.0, 5.0],
	], []],
	["Her body & paths", [
		["hertweenstartx", "Start x", "n", SCENE_X[0], SCENE_X[1]], ["hertweenstarty", "Start y", "n", SCENE_Y[0], SCENE_Y[1]],
		["hertweenstartang", "Start angle", "r", -200.0, 200.0],
		["hertweenendx", "End x", "n", SCENE_X[0], SCENE_X[1]], ["hertweenendy", "End y", "n", SCENE_Y[0], SCENE_Y[1]],
		["hertweenendangle", "End angle", "r", -200.0, 200.0], ["offpathposmovement", "Off-path movement", "n", -100.0, 300.0],
		["torsox", "Knee x", "n", SCENE_X[0], SCENE_X[1]], ["torsoy", "Knee y", "n", SCENE_Y[0], SCENE_Y[1]],
		["torsox2", "Knee x at the end", "n", SCENE_X[0], SCENE_X[1]], ["torsoy2", "Knee y at the end", "n", SCENE_Y[0], SCENE_Y[1]],
		["torsominang", "Torso min angle", "n", -30.0, 80.0], ["torsostartangle", "Torso start angle", "n", 0.0, 7.0],
		["torsoanglemodifier", "Torso angle multiplier", "n", -3.0, 25.0],
		["torsomindistance", "Torso min distance", "n", 0.0, 400.0], ["torsostartdistance", "Torso start distance", "n", 0.0, 400.0],
		["torsodistancemultiplier", "Torso distance multiplier", "n", -100.0, 100.0],
		["torsoikoffsetang", "Leg angle offset", "n", -3.2, 3.2], ["torsoendrotationangle", "Torso end rotation", "n", -220.0, 220.0],
		["leftlegoffsetangle", "Left leg offset angle", "n", -3.2, 3.2], ["leftlegcalfangle", "Left calf angle", "n", -90.0, 90.0],
		["behindleg", "Her left leg behind him", "f"], ["leftbreastbehind", "Her left breast behind him", "f"],
		["hidehershadow", "Hide her shadow", "f"],
	], [["her start", "hertweenstartx", "hertweenstarty", "hertweenstartang", "scene", Color("ff8fb8")],
		["her end", "hertweenendx", "hertweenendy", "hertweenendangle", "scene", Color("ff4f8f")],
		["knee", "torsox", "torsoy", "", "scene", Color("ffd34f")],
		["knee end", "torsox2", "torsoy2", "", "scene", Color("d9a520")]]],
	["Him", [
		["himhidden", "His body shown", "f"], ["himreversed", "Him turned round", "f"], ["himflipped", "Him upside down", "f"],
		["histweenstartx", "Start x", "n", SCENE_X[0], SCENE_X[1]], ["histweenstarty", "Start y", "n", SCENE_Y[0], SCENE_Y[1]],
		["histweenstartang", "Start angle", "r", -120.0, 120.0],
		["histweenendx", "End x", "n", SCENE_X[0], SCENE_X[1]], ["histweenendy", "End y", "n", SCENE_Y[0], SCENE_Y[1]],
		["histweenendangle", "End angle", "r", -120.0, 120.0],
		["leftfootx", "Left foot x", "n", SCENE_X[0], SCENE_X[1]], ["leftfooty", "Left foot y", "n", SCENE_Y[0], 5000.0],
		["rightfootx", "Right foot x", "n", SCENE_X[0], SCENE_X[1]], ["rightfooty", "Right foot y", "n", SCENE_Y[0], 5000.0],
		["setpenisoutbehind", "Penis out behind her", "f"], ["usesteadypenis", "Steady penis", "f"],
		["hispenisrotationoffset", "Penis angle offset", "n", -180.0, 360.0],
		["hispenisrotationoffsetend", "Penis angle offset at the end", "n", -180.0, 360.0],
	], [["his start", "histweenstartx", "histweenstarty", "histweenstartang", "scene", Color("6fc3ff")],
		["his end", "histweenendx", "histweenendy", "histweenendangle", "scene", Color("2f8fe0")],
		["left foot", "leftfootx", "leftfooty", "", "scene", Color("9fe0a0")],
		["right foot", "rightfootx", "rightfooty", "", "scene", Color("5fbf60")]]],
	["Her arms", [
		["armpostyperight", "Right arm", "a"], ["armposx", "Right hand x", "n", SCENE_X[0], SCENE_X[1]],
		["armposy", "Right hand y", "n", SCENE_Y[0], SCENE_Y[1]], ["armposxend", "Right hand x at the end", "n", SCENE_X[0], SCENE_X[1]],
		["armposyend", "Right hand y at the end", "n", SCENE_Y[0], SCENE_Y[1]], ["handangler", "Right hand angle", "n", -270.0, 270.0],
		["handrinverted", "Right hand reversed", "f"], ["userightclosehand", "Right hand closed", "f"],
		["allowrightarmdrop", "Right arm may drop", "f"], ["allowrightarmtap", "Right arm may tap", "f"],
		["armpostypeleft", "Left arm", "a"], ["armpos2x", "Left hand x", "n", SCENE_X[0], SCENE_X[1]],
		["armpos2y", "Left hand y", "n", SCENE_Y[0], SCENE_Y[1]], ["armpos2xend", "Left hand x at the end", "n", SCENE_X[0], SCENE_X[1]],
		["armpos2yend", "Left hand y at the end", "n", SCENE_Y[0], SCENE_Y[1]], ["handanglel", "Left hand angle", "n", -270.0, 270.0],
		["handlinverted", "Left hand reversed", "f"], ["useleftclosehand", "Left hand closed", "f"],
		["allowleftarmdrop", "Left arm may drop", "f"], ["allowleftarmtap", "Left arm may tap", "f"],
	], [["right hand", "armposx", "armposy", "deg:handangler", "scene", Color("ffb070")],
		["right hand end", "armposxend", "armposyend", "", "scene", Color("e08840")],
		["left hand", "armpos2x", "armpos2y", "deg:handanglel", "scene", Color("ffe070")],
		["left hand end", "armpos2xend", "armpos2yend", "", "scene", Color("e0b840")]]],
	["His arm", [
		["enablehiscustomarm", "His own arm path", "f"],
		["handpointrestx", "Rest x", "n", HIS_X[0], HIS_X[1]], ["handpointresty", "Rest y", "n", HIS_X[0], HIS_X[1]],
		["handpointstartx", "Hand start x", "n", SCENE_X[0], SCENE_X[1]], ["handpointstarty", "Hand start y", "n", SCENE_Y[0], SCENE_Y[1]],
		["handpointendx", "Hand end x", "n", SCENE_X[0], SCENE_X[1]], ["handpointendy", "Hand end y", "n", SCENE_Y[0], SCENE_Y[1]],
		["shoulderpointstartx", "Shoulder start x", "n", -300.0, 500.0], ["shoulderpointstarty", "Shoulder start y", "n", -800.0, 0.0],
		["shoulderpointendx", "Shoulder end x", "n", -300.0, 500.0], ["shoulderpointendy", "Shoulder end y", "n", -800.0, 0.0],
		["hishandstartrotation", "Hand start rotation", "n", -180.0, 180.0], ["hishandendrotation", "Hand end rotation", "n", -180.0, 180.0],
		["hishandrottarget", "Hand rotation against", "c", ["Nothing", "His arm", "Her", "Her leg", "Her torso"]],
	], [["his hand rest", "handpointrestx", "handpointresty", "", "him", Color("c0a0ff")],
		["his hand start", "handpointstartx", "handpointstarty", "", "scene", Color("a080ff")],
		["his hand end", "handpointendx", "handpointendy", "", "scene", Color("8060e0")]]],
	["Body contact", [
		["bodycontactsounds", "Contact sounds", "f"], ["pleasurefromcontact", "Pleasure from contact", "f"],
		["pleasurefromcontactmult", "Pleasure multiplier", "n", 0.0, 5.0],
		["resistancewithbodycontact", "Resistance", "f"], ["resistancestartingdistance", "Resistance starts at", "n", 0.0, 200.0],
		["startingresistance", "Starting resistance", "n", 0.0, 20.0], ["minresistance", "Lowest resistance", "n", -0.1, 0.1],
		["resistdecreaserate", "Resistance wears down", "n", 0.0, 0.01], ["movementresistancemult", "Movement resistance", "n", 0.0, 6.0],
		["bodycontactvigour", "Vigour from contact", "f"], ["bodycontactvigourcontinuousamount", "Vigour amount", "n", 0.0, 10.0],
		["hidestrandsinbodycontact", "No strands inside her", "f"], ["adjustspeedinbodycontact", "Adjust speed in contact", "f"],
		["spaceholdresist", "Space holds resistance", "f"], ["usepenisrangebodycontactmask", "Penis mask inside her", "f"],
		["undovanillavigourmovechanges", "Undo the game's movement vigour", "f"],
		["undoallvanillavigourincreases", "Undo all of the game's vigour", "f"],
	], []],
]

var _ext
var values: Dictionary = {}    # the position being edited (every key)
var editing := false           # values hold a position (Edit / New pressed)
var base_name := ""            # the library name it was opened from ("" new)
var save_name := ""            # the name field
var dirty := false
var status := ""
var _base = null               # the Position opened (its extra lines and settings are written back)
var _pending := ""             # "" / "anim" / "full": what the next tick applies
var _undo: Array = []
var _handles = null
var _freeze := Vector2(NAN, NAN)   # where the mouse steered her when a drag began
var _applied = null             # the Position the editor applied last (another one loaded: editing ends)
var prop := 0                   # the prop the Props card shows (PositionFields.PROPS index)


func _init(ext) -> void:
	_ext = ext


func start() -> void:
	var ext = _ext
	ext.menu_control(SECTION, "Edit", {"type": "custom", "label": "", "build": _status_label})
	ext.menu_control(SECTION, "Edit", {"type": "text", "label": "Name", "placeholder": "a name for Save as",
		"tip": "The file name in Mods/Positions/My positions.", "get": func(): return save_name,
		"set": func(t: String): save_name = t.strip_edges()})
	ext.menu_control(SECTION, "Edit", MenuSchema.actions("", "", [
		["Save", save, "Writes the position (a copy in My positions for the game's own ones) with a thumbnail of the scene."],
		["Save as", func(): save_as(save_name), "Writes it under the name above, in My positions."],
		["Undo", undo, "Takes back the last change."],
		["Revert", revert, "Back to the file as it was opened."]],
		{"keywords": "position editor save undo"}))
	ext.menu_control(SECTION, "Edit", MenuSchema.note("Hold Ctrl and drag the dots on the scene (the open cards' points; the end of a dot's arm turns it)."))
	for card in CARDS:
		for f in card[1]:
			ext.menu_control(SECTION, card[0], _spec(f))
	var names: Array = Fields.PROPS.map(func(pr): return pr[0])
	ext.menu_control(SECTION, "Props", MenuSchema.choice("Prop", "The prop the controls below change (animtools' furniture).",
		names, func(): return names[prop], func(v: String): prop = names.find(v)))
	for f in [["active", "Shown", "f"], ["x", "X", "n", -3000.0, 3000.0], ["y", "Y", "n", -2000.0, 3000.0],
			["scalex", "Width scale", "n", -8.0, 8.0], ["scaley", "Height scale", "n", -8.0, 8.0],
			["rotation", "Rotation", "n", -180.0, 180.0]]:
		ext.menu_control(SECTION, "Props", _prop_spec(f))
	ext.modify(&"DT.mousePos", {"op": "fn", "fn": _mouse_pos})
	ext.on_late_tick(_tick)


func stop() -> void:
	_show_handles(false)


static func section() -> Dictionary:
	var fold := {}
	for card in CARDS:
		fold[card[0]] = card[0] != "Her body & paths"
	fold["Props"] = true
	return {"id": SECTION, "name": "Edit position", "owner": "positions", "live": true, "hidden": true,
		"parent": "positions", "fold": fold, "groups": []}


# ---------------------------------------------------------------- opening, undo, saving

## Edits the current position (or, with `fresh` or at the game's default, a new one from the default values).
func begin(fresh := false) -> void:
	var cur = _ext.current
	if fresh or cur == null:
		_base = Position.from_text("", "")
		base_name = ""
		save_name = ""
	else:
		_base = cur
		base_name = cur.name
		save_name = cur.name.get_file()
	values = _base.values.duplicate()
	_applied = null
	editing = true
	dirty = false
	_undo.clear()
	status = ""
	_pending = "full"
	if SDTMenu.instance != null:
		SDTMenu.instance.open_menu(SECTION)


func set_value(key: String, v: float) -> void:
	if not editing or values.get(key) == v:
		return
	if _undo.is_empty() or _undo[-1].get("_open", false) == false:
		var snap := values.duplicate()
		snap["_open"] = true
		_undo.append(snap)
		if _undo.size() > 100:
			_undo.pop_front()
	values[key] = v
	dirty = true
	_pending = "full" if _pending == "full" or not key in ANIM_KEYS else "anim"


## The end of a change (a slider let go, a drag ended): the next change gets its own undo step.
func commit() -> void:
	if not _undo.is_empty():
		_undo[-1].erase("_open")
	_freeze = Vector2(NAN, NAN)


func undo() -> void:
	if _undo.is_empty():
		return
	values = _undo.pop_back()
	values.erase("_open")
	dirty = true
	_pending = "full"


func revert() -> void:
	if _base == null:
		return
	values = _base.values.duplicate()
	_undo.clear()
	dirty = false
	_pending = "full"


func _position(n: String):
	var p = Position.new()
	p.name = n
	p.version = Fields.VERSION
	p.values = values.duplicate()
	if _base != null:
		p.extra = _base.extra.duplicate()
		p.settings = _base.settings.duplicate()
	return p


## Save: back into its own file, except the game's own (animtools/...) and new ones: those go to My positions.
func save() -> void:
	if not editing:
		return
	if base_name != "" and not base_name.begins_with("animtools/") and _ext.library.has(base_name):
		_write(base_name, _ext.library.path_of(base_name))
	else:
		var stem := save_name if save_name != "" else (base_name.get_file() if base_name != "" else "position")
		var n := MY_FOLDER + "/" + stem
		var k := 2
		while _ext.library.has(n) and n != base_name:
			n = "%s/%s %d" % [MY_FOLDER, stem, k]
			k += 1
		_write(n, _ext.positions_root().path_join(n + ".txt"))


func save_as(stem: String) -> void:
	if not editing:
		return
	stem = stem.validate_filename().strip_edges()
	if stem == "":
		status = "Give a name first."
		return
	var n := MY_FOLDER + "/" + stem
	if _ext.library.has(n) and n != base_name:
		status = "\"%s\" exists already: pick another name." % stem
		return
	_write(n, _ext.positions_root().path_join(n + ".txt"))


func _write(n: String, file: String) -> void:
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		status = "Could not write %s." % file
		return
	f.store_string(_position(n).to_text())
	f.close()
	base_name = n
	save_name = n.get_file()
	_base = _position(n)
	dirty = false
	status = "Saved as %s." % n
	_ext.rescan()
	_ext.current = _base
	_applied = _base
	_ext.loaded_name = n
	_thumbnail(file.get_basename() + ".png")


## A 700x600 picture of the scene for the browser (as animtools' thumbnails: the scene only), without the menu, the
## handles, the frame counter and the game's layers above the scene (menus, dialogue, bars).
func _thumbnail(png: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var hide: Array = [SDTMenu.instance, _handles] + Flash.get_tree().root.find_children("*", "CanvasLayer", true, false) \
		.filter(func(c): return c.layer >= 100)
	var hidden: Array = []
	for node in hide:
		if node != null and node.visible:
			node.visible = false
			hidden.append(node)
	var faded: Array = []   # the game's layers by alpha (some set their visibility every tick)
	var above := false
	for i in g.container.numChildren:
		var c: FlashDisplayObject = g.container.getChildAt(i)
		if above and c.alpha > 0:
			faded.append([c, c.alpha])
			c.alpha = 0.0
		above = above or c == g.screenEffects
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = Flash.capture_screen(g.screenSize, 1.0)
	for node in hidden:
		if is_instance_valid(node):
			node.visible = true
	for fa in faded:
		if is_instance_valid(fa[0]):
			fa[0].alpha = fa[1]
	if img != null:
		img.save_png(png)
		Browser._thumbs.erase(png)


# ---------------------------------------------------------------- applying, handles

func _tick() -> void:
	if editing and _applied != null and _ext.current != _applied:
		editing = false   # another position was loaded (the browser, a hotkey, a dialogue)
		_pending = ""
	var on := editing and _page_open()
	_show_handles(on)
	if not editing or _pending == "":
		return
	var what := _pending
	_pending = ""
	var p = _position(base_name if base_name != "" else MY_FOLDER + "/" + (save_name if save_name != "" else "new"))
	var keep: String = _ext.loaded_name
	if what == "anim" and _ext.current != null:
		_ext.current = p
		_ext.rebuild_animation(p)
	else:
		_ext.apply(p, true)
	_ext.loaded_name = keep
	_applied = p


func _page_open() -> bool:
	var m := SDTMenu.instance
	return m != null and m.is_open and m.section == SECTION and m.query == ""


func _show_handles(on: bool) -> void:
	var made := false
	if on and _handles == null:
		_handles = Handles.new()
		_handles.editor = self
		Flash.add_child(_handles)
		made = true
	elif not on and _handles != null:
		_handles.queue_free()
		_handles = null
		_freeze = Vector2(NAN, NAN)
	if _handles != null and (made or Flash.tick_count % 6 == 0):   # (cards fold by a click: a few ticks are soon enough)
		_handles.handles = _open_handles()


## The handles of the cards that are open on the page.
func _open_handles() -> Array:
	var out: Array = []
	var sec := section()
	for card in CARDS:
		if card[2].is_empty() or MenuFold.is_folded(sec, {"title": card[0]}):
			continue
		for h in card[2]:
			var ak: String = h[3]
			out.append({"label": h[0], "x": h[1], "y": h[2], "angle": ak.trim_prefix("deg:"),
				"angle_deg": ak.begins_with("deg:"), "space": h[4], "color": h[5]})
	if not MenuFold.is_folded(sec, {"title": "Props"}):
		var n: String = Fields.PROPS[prop][0]
		if values.get(n + "active", 0.0) == 1.0:
			out.append({"label": n.replace("_", " "), "x": n + "x", "y": n + "y", "angle": n + "rotation",
				"angle_deg": true, "space": "scene", "color": Color("e0e0e0")})
	return out


## While a handle is dragged she stays where the mouse had her (the mouse is moving the handle).
func _mouse_pos(mp: Vector2, _dt) -> Vector2:
	if _handles == null or not _handles.dragging:
		_freeze = Vector2(NAN, NAN)
		return mp
	if is_nan(_freeze.x):
		_freeze = mp
	return _freeze


# ---------------------------------------------------------------- the menu

func _status_label() -> Control:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", MenuTheme.MUTED)
	l.set_meta("refresh", func():
		var t := "Open a position and press Edit (or New) on the Positions page." if not editing else \
			"Editing: %s%s" % [base_name if base_name != "" else "a new position", " (not saved)" if dirty else ""]
		if status != "":
			t += "\n" + status
		if l.text != t:
			l.text = t)
	l.get_meta("refresh").call()
	return l


## A Props card control: the same field of whichever prop is chosen.
func _prop_spec(f: Array) -> Dictionary:
	var key := func() -> String: return Fields.PROPS[prop][0] + f[0]
	var spec: Dictionary
	if f[2] == "f":
		spec = MenuSchema.toggle(f[1], "", func(): return values.get(key.call(), 0.0) == 1.0,
			func(on: bool): set_value(key.call(), 1.0 if on else 0.0); commit())
	else:
		spec = {"type": "slider", "label": f[1], "tip": "", "min": f[3], "max": f[4], "step": 0.01 if f[4] <= 10.0 else 0.5,
			"get": func(): return values.get(key.call(), 0.0), "set": func(v: float): set_value(key.call(), v),
			"release": commit, "reset": func(): set_value(key.call(), Fields.defaults()[key.call()]); commit(),
			"format": func(v): return str(snappedf(v, 0.01))}
	spec["visible"] = func(): return editing
	return spec


func _spec(f: Array) -> Dictionary:
	var key: String = f[0]
	var label: String = f[1]
	var d: float = Fields.defaults()[key]
	var spec: Dictionary
	match f[2]:
		"f":
			spec = MenuSchema.toggle(label, "", func(): return values.get(key, d) == 1.0,
				func(on: bool): set_value(key, 1.0 if on else 0.0); commit())
		"a":
			var opts: Array = ["Keep hers"] + Array(Her.armPositions.slice(0, Her.GAME_ARM_POSITIONS)) + Arms.NAMES + [Arms.CUSTOM]
			spec = MenuSchema.choice(label, "", opts, func(): return opts[clampi(int(values.get(key, d)) + 1, 0, opts.size() - 1)],
				func(v: String): set_value(key, float(opts.find(v) - 1)); commit())
		"c":
			var opts: Array = f[3]
			spec = MenuSchema.choice(label, "", opts, func(): return opts[clampi(int(values.get(key, d)), 0, opts.size() - 1)],
				func(v: String): set_value(key, float(opts.find(v))); commit())
		"r":
			spec = {"type": "slider", "label": label, "tip": "", "min": f[3], "max": f[4], "step": 0.5,
				"get": func(): return rad_to_deg(values.get(key, d)), "set": func(v: float): set_value(key, deg_to_rad(v)),
				"release": commit, "reset": func(): set_value(key, d); commit(), "format": func(v): return "%d°" % roundi(v)}
		_:
			var lo: float = f[3]
			var hi: float = f[4]
			var step := 0.0 if hi - lo <= 20.0 else 0.5
			spec = {"type": "slider", "label": label, "tip": "", "min": lo, "max": hi, "step": step,
				"get": func(): return values.get(key, d), "set": func(v: float): set_value(key, v),
				"release": commit, "reset": func(): set_value(key, d); commit(),
				"format": func(v):
					if values.get(key, d) == UNSET:
						return "unset"
					return str(snappedf(v, 0.01)) if hi - lo <= 20.0 else str(snappedf(v, 0.5))}
	spec["visible"] = func(): return editing
	spec["keywords"] = key
	return spec
