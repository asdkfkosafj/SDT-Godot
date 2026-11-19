extends SDTExtension
## Condoms: he can wear a condom (Him > Condom, or the Q key). It rolls on while he is out of her mouth, follows his
## penis's outline (every type, size and penis mod; not the strap-on) and hides in her mouth with it.
## His cum stays in it (no strands, her mouth does not fill) and hangs from his tip in a teardrop sack that grows with
## it (no more once it is full): a weight on stretchy latex with real gravity, heavier the more cum is in it, drawn
## smoothly between ticks. It rests and rubs on her face, squeezes in through her lips after him and lies in her
## mouth (the x-ray view draws it there). Past her throat ring it is stuck: pulled out, the latex to it stretches and
## holds her head back until it pops out; pushed in, it presses against the ring until it goes through; in her
## throat it makes a swallow lump in her neck.
## Planned next: it is taken off, tied and pinned on her.

const ROLL_TICKS := 15     # rolling it on or off takes half a second
const CUT_R := 70.0        # round his tip the bulb draws the outline of the sleeve and the sack as one line
const FULL := 80.0         # cum (strand link masses, one load is about 15-25) that fills the bulb to its biggest

var Condom: GDScript
var condom = null          # condom.gd, while he wears one (or it is rolling)
var worn := false          # he wears one (or it is rolling on)
var roll := 0.0            # 0 at his tip .. 1 rolled all the way on
var _dir := 0              # +1 rolling on, -1 rolling off
var _sig := ""             # what the outline was scanned for (penis type, skin, art)
var _dirty := true
var cum := 0.0             # cum in it (strand link masses; stops at FULL)
var _bulb_dirty := true
var _cum_rgb := -1


func _init() -> void:
	title = "Condoms"
	description = "He can wear a condom (Him > Condom, Q)."


func _setup() -> void:
	setting("colour", Color(0.86, 0.93, 1.0, 1.0), {"label": "Condom colour"})
	setting("density", 0.8, {"label": "Condom opacity", "min": 0.1, "max": 1.0, "step": 0.01,
		"desc": "How much the latex shows: low is clear, high is solid."})
	setting("cover", 0.86, {"label": "Condom length", "min": 0.3, "max": 1.0, "step": 0.01,
		"desc": "How far down his penis it reaches, from the tip."})


func _enable() -> void:
	Condom = load_script("condom.gd")
	on_late_tick(_tick)
	on_key(KEY_Q, toggle, "condom on / off", "condom")
	modify(&"Him.cumCaught", {"op": "set", "value": true, "phase": Hooks.FINAL,
		"when": func(_him): return roll > 0.0 and condom != null and condom.sprite.parent != null})
	hook_after(&"Him.catchCum", func(c): add_cum(c.args[0]))
	# stuck behind her throat ring the sack's stretched latex pulls her head back to him (pushed against it, it holds
	# her back a little); in her throat it makes a swallow lump in her neck
	modify(&"Her.drag", {"phase": Hooks.MOOD, "op": "fn", "fn": func(v, her):
		if condom == null:
			return v
		return v + condom.drag_add + minf(0.0, her.speed) * condom.grip_out + maxf(0.0, her.speed) * condom.grip_in})
	modify(&"Neck.bumps", {"op": "fn", "fn": func(v, _neck): return v + condom.bumps if condom != null else v})
	# the x-ray view draws it in her mouth with him
	modify(&"Him.tipExtra", {"op": "fn", "fn": func(v, _him):
		if condom == null or cum <= 0.0 or not condom.has_inside():
			return v
		return v + condom.tip_extra()})
	menu_control("him", "Condom", MenuSchema.toggle("Condom", "He wears a condom. It rolls on while he is out of her "
		+ "mouth (Q).", func(): return worn, func(on: bool): set_worn(on)))
	menu_control("him", "Condom", MenuSchema.colour("Colour", "The condom's colour.", _colour_dict,
		func(c, _f): _set_colour(c), "rgbFill", false))
	for k in ["density", "cover"]:
		menu_control("him", "Condom", MenuSchema.setting_control(self, k, {"wide": true}))


func _disable() -> void:
	_remove()
	if condom != null:
		condom.free_drawer()
	condom = null
	_sig = ""
	worn = false
	_dir = 0


func _setting_changed(_key: String, _value) -> void:
	_dirty = true
	_bulb_dirty = true


## Cum into the condom (strand link masses); the bulb at its tip grows with it up to FULL.
func add_cum(mass: float) -> void:
	if cum >= FULL:
		return
	cum = minf(FULL, cum + mass)
	_bulb_dirty = true


## The bulb's radius for the cum in it: the first drop is small, its area grows with the cum.
func bulb_radius() -> float:
	if cum <= 0.0:
		return 0.0
	return lerpf(condom.BULB_MIN, condom.BULB_R, sqrt(cum / FULL))


## The sack's length before its weight stretches it (his tip to the middle of its round bottom).
func sack_length() -> float:
	return bulb_radius() * 1.3


func _colour_dict() -> Dictionary:
	return MenuSchema.color_dict(get_setting("colour"))


func _set_colour(c: Dictionary) -> void:
	set_setting("colour", Color8(int(c["r"]), int(c["g"]), int(c["b"])))


func toggle() -> void:
	set_worn(not worn)


## Puts the condom on (rolls on) or takes it off. Only while he is out of her mouth, and not on the strap-on.
func set_worn(on: bool) -> void:
	if on == worn or g.him == null:
		return
	if g.him.inMouth or (on and _strapon()):
		return
	worn = on
	_dir = 1 if on else -1


func _strapon() -> bool:
	return g.him.currentPenisID == g.him.penisNameList.find("Strapon")


## The penis art: the clip's first unnamed child (its others are lipstickElements, wetMask and wet).
func _art() -> FlashDisplayObject:
	var p: FlashDisplayObject = g.him.penis
	for i in p.numChildren:
		var c = p.getChildAt(i)
		if c.flash_name == "" and (condom == null or c != condom.sprite):
			return c
	return null


func _tick() -> void:
	if g.him == null or g.him.penis == null:
		return
	if worn and _strapon():
		worn = false
		roll = 0.0
		_dir = 0
	if _dir != 0:
		roll = clampf(roll + float(_dir) / ROLL_TICKS, 0.0, 1.0)
		_dirty = true
		if (_dir > 0 and roll >= 1.0) or (_dir < 0 and roll <= 0.0):
			_dir = 0
	if roll <= 0.0:
		_remove()
		return
	var art := _art()
	if art == null:
		return
	if condom == null:
		condom = Condom.new()
	var sig := "%d|%s|%d" % [g.him.currentPenisID, g.himSkinType, art.get_instance_id()]
	if sig != _sig:
		condom.attach(g.him.penis, art)
		if not condom.scan():
			return
		_sig = sig
		_dirty = true
		condom.sack_ok = false
	else:
		condom.attach(g.him.penis, art)   # keeps it right above the art
	if cum > 0.0:
		condom.step_sack(sack_length(), bulb_radius(), cum / FULL)   # (drawn every frame while it moves: condom.gd)
	# while there is a sack the sleeve leaves its outline round the tip to it (one line round both)
	var cut := CUT_R if cum > 0.0 else 0.0
	if cut != condom.cut_r:
		condom.cut_r = cut
		_dirty = true
	if _dirty:
		_dirty = false
		var k := 1.0 - pow(1.0 - roll, 2.0)   # eases out as it reaches its place
		var end: float = lerpf(condom.tip_x, condom.tip_x + (condom.base_x - condom.tip_x) * get_setting("cover"), k)
		condom.draw(end, roll, get_setting("colour"), get_setting("density"))
		_bulb_dirty = true
	if g.cumRGB != _cum_rgb:
		_cum_rgb = g.cumRGB
		_bulb_dirty = true
	if _bulb_dirty:
		_bulb_dirty = false
		condom.set_bulb(bulb_radius(), get_setting("colour"), get_setting("density"),
			Color.hex((g.cumRGB << 8) | 0xFF))


## Takes the drawing off his penis. The outline it scanned stays (_sig), so putting one on again needs no new scan.
func _remove() -> void:
	roll = 0.0
	cum = 0.0   # (for now: taking it off and tying it comes later)
	if condom != null:
		condom.sack_ok = false
		condom.past = false
		condom.in_share = 0.0
		condom._pass_t = -1.0
		condom._strain = 0.0
		condom._rel_t = 0.0
		condom._lip_t = -1.0
		condom.cum_from = 0.0
		condom.drag_add = 0.0
		condom.grip_out = 0.0
		condom.grip_in = 0.0
		condom.bumps = []
		condom.prof.clear()
	if condom != null and condom.sprite.parent != null:
		condom.detach()
		_dirty = true
