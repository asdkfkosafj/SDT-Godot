extends SDTExtension
## Port of sby's eyeMakeupV1 Loader mod (art: Rod and SClover13's Eyelid Line, Smokey Eye Make Up, Tear Stained Eyes
## and Glitter Eyeshadow mods): eye liner, smoky eye shadow and the lower one (the mod's "tear stains": a soft shadow
## under the eye), each with a colour in Her > Colours
## (fully transparent = off, the default), and eye glitter. Saved in the character code as eyelinemakeup,
## eyesmokemakeup, eyestainmakeup (r,g,b,alpha 0-255) and eyeglitter (1 / 0), like the Loader mod.
## Adapted: the parts follow her eyelid frames after Her.updateEyes instead of every frame; the art (art/, trimmed to
## the classes used with tools/swfconv/prune.py) is the mod's.

const BLANK := {"r": 0, "g": 0, "b": 0, "a": 0.0}

var line_rgb := BLANK.duplicate()
var smoke_rgb := BLANK.duplicate()
var tear_rgb := BLANK.duplicate()
var glitter := false

var _line      # eye liner on her upper eyelid
var _smoke     # smoky shadow behind her eye
var _ridge     # its part on her eye ridge
var _tear      # smoky shadow under her eye (the mod's "tear stains")
var _sparkles  # glitter on her upper eyelid
var _all_glitter: FlashSprite


func _init() -> void:
	title = "Eye makeup"
	description = "Eye liner, smoky eye shadow (upper and lower) and eye glitter (art by Rod and SClover13)."


func _setup() -> void:
	setting("glitcount", 130, {"label": "Glitter sparkles", "min": 0, "max": 400})
	setting("maxglitsize", 0.3, {"label": "Smallest sparkle size", "min": 0.0, "max": 2.0})
	setting("shine", true, {"label": "Sparkles shine"})
	setting("enablevanillasaving", true, {"label": "Save in the character code"})


func _enable() -> void:
	var art := FlashSwfMod.load_art(file_path("art"))
	if art == null:
		return
	var eye = g.her.eye
	var lid = eye.upperEyelid
	_line = art.create("EyelidLine")
	lid.addChildAt(_line, lid.getChildIndex(lid.mascara) + 1)
	_smoke = art.create("neweye2")
	eye.addChildAt(_smoke, 0)
	_smoke.makeup.mask = _smoke.mmask
	_ridge = art.create("neweyeridge2")
	eye.eyebrowUnderMask.addChild(_ridge)
	_tear = art.create("neweye3")
	eye.addChildAt(_tear, 0)
	_sparkles = art.create("NewUpperEyeShadow4")
	_all_glitter = FlashSprite.new()
	var big: bool = get_setting("shine")
	for i in int(get_setting("glitcount")):
		var s = art.create("sparkle" if big else "sparkleSansShine")
		s.alpha = (20 + randi() % 75) * 0.01
		s.scaleX = randf() + get_setting("maxglitsize")
		s.scaleY = s.scaleX
		s.rotation_degrees = randf() * 180
		s.x = randf() * 100
		s.y = randf() * 70
		_all_glitter.addChild(s)
	lid.addChildAt(_sparkles, lid.getChildIndex(_line) + 1)
	_apply_colours()
	hook_after(&"Her.updateEyes", func(_c): _follow())
	for c in [["Eye liner", "line"], ["Smoky eye shadow", "smoke"], ["Smoky eye shadow lower", "tear"]]:
		menu_control("her", "Colours", MenuSchema.colour(c[0], "Fully transparent: none (the default, also the reset).",
			func(): return get(c[1] + "_rgb"), func(rgb, _fill): _set_colour(c[1], rgb), "rgbFill", true,
			{"after": "Mascara", "keywords": "eye makeup eyemakeup smoky " + c[1], "reset": func(): _set_colour(c[1], BLANK); g.saveData.saveCharData()}))
	menu_control("her", "Colours", MenuSchema.toggle("Eye glitter", "Glitter on her eye shadow. Saved with the character.",
		func(): return glitter, func(v: bool): glitter = v; _follow(); g.saveData.saveCharData(), {"after": "Mascara", "keywords": "eye makeup glitter sparkle"}))
	if get_setting("enablevanillasaving"):
		for c in [["eyelinemakeup", "line"], ["eyesmokemakeup", "smoke"], ["eyestainmakeup", "tear"]]:
			charcode_field(c[0], func(): return _code(get(c[1] + "_rgb")), func(v: String, _l): _load_colour(c[1], v),
				func(_l): _set_colour(c[1], BLANK))
		charcode_field("eyeglitter", func(): return "1" if glitter else "0",
			func(v: String, _l): glitter = v.get_slice(",", 0) == "1"; _follow(), func(_l): glitter = false; _follow())
	_follow()


func _disable() -> void:
	for o in [_line, _smoke, _ridge, _tear, _sparkles]:
		if o != null and o._flash_parent != null:
			o._flash_parent.removeChild(o)
	_line = null


static func _code(c: Dictionary) -> String:
	return "%d,%d,%d,%.5f" % [c["r"], c["g"], c["b"], float(c["a"]) * 255.0]


func _load_colour(which: String, v: String) -> void:
	var p := v.split(",")
	if p.size() > 3:
		_set_colour(which, {"r": int(float(p[0])), "g": int(float(p[1])), "b": int(float(p[2])), "a": float(p[3]) / 255.0})


func _set_colour(which: String, rgb: Dictionary) -> void:
	set(which + "_rgb", {"r": rgb["r"], "g": rgb["g"], "b": rgb["b"], "a": rgb["a"]})
	_apply_colours()


## Each part's rgbFill takes the colour outright (as the mod did): alpha 0 hides it.
func _apply_colours() -> void:
	for p in [[line_rgb, [_line]], [smoke_rgb, [_smoke.makeup, _ridge.makeup]], [tear_rgb, [_tear]]]:
		var c: Dictionary = p[0]
		var ct := FlashColorTransform.new(0, 0, 0, c["a"], c["r"], c["g"], c["b"])
		for o in p[1]:
			var fill = o.getChildByName("rgbFill") if o != null else null
			if fill != null:
				fill.colorTransform = ct


## After her eyes update: the liner, shadow mask and glitter on her eyelid's frames.
func _follow() -> void:
	if _line == null:
		return
	var lid = g.her.eye.upperEyelid
	_line.rgbFill.gotoAndStop(lid.currentFrame)
	_smoke.mmask.gotoAndStop(lid.eyeshadow.currentFrame)
	_sparkles.visible = glitter
	if glitter:
		_sparkles.gotoAndStop(lid.eyeshadow.currentFrame)
		var holder = _sparkles.glittercontainer   # the frame's container: the sparkles move into it
		if holder != null and _all_glitter._flash_parent != holder:
			holder.addChild(_all_glitter)
