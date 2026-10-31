extends SDTExtension
## Port of sby's ffbehaviorV3_1 Loader mod (Final Fellatio-style behaviour): as she runs out of air with him in her
## mouth her eyes roll up and open wide, the background darkens and her pupils shrink (with his depth or her air);
## while you hold her head she loses breath and air faster. Behaviour > Out of air; everything off by default (the
## game's own), the Loader pack's values are in each row's description, where each effect starts and ends is in
## values.cfg (the mod's keys).
## Adapted:
## - her gaze, eyelids and iris size are MOOD modifiers of value points (Her.gazeAngle, and the new Her.eyelidTarget,
##   Her.irisScale) instead of the mod writing them after her tick: the game eases her eyes towards them (the mod's
##   own slow lead-in to its first angle), she still blinks and winces, dialogue triggers and passing out win;
## - the background's colour is written only when it changes, and goes back to normal when switched off;
## - breath and air lost while held: one amount every tick (the mod: twice it every other tick), the air loss never
##   lowers how close she already is to passing out.
## Not ported: the mod's older timer mode (usepassout=0: eyes up and pull-off attempts on a timer while he hilts),
## "persist", and its clearing of the tears on her lower eyelid every tick (the game's own clearing follows the
## eyelids it eases).

const CARD := "Out of air"
const PUPILS := ["Off", "With his depth", "As she runs out of air"]

var V := {}                   # values.cfg: the mod's key -> number
var _bg := 1.0                # the background's colour multiplier last written


func _init() -> void:
	title = "Final Fellatio behaviour"
	description = "As she runs out of air: her eyes roll up and open wide, the background darkens, her pupils shrink."


func _setup() -> void:
	var pack := func(v): return " The Loader pack: %s." % v
	setting("eyes_up", false, {"label": "Eyes roll up", "desc": "With him in her mouth her eyes turn up as she runs "
		+ "out of air (from 30% to 70% of the way to passing out), a little unsteady. Off: the game's." + pack.call("on")})
	setting("eyes_open", false, {"label": "Eyes open wide", "desc": "With him in her mouth her eyes open wide as she "
		+ "runs out of air (from 40% to 90% of the way to passing out), until just before she passes out. Off: the game's "
		+ "(they close)." + pack.call("on")})
	setting("darken", 1.0, {"label": "Background brightness", "min": 0.0, "max": 1.0, "step": 0.05, "desc": "How "
		+ "bright the background stays as she runs out of air (darkening from 30% to 90% of the way to passing out). "
		+ "1: it doesn't darken (the game's)." + pack.call("0.15")})
	setting("pupils", PUPILS[0], {"label": "Pupils shrink", "options": PUPILS, "desc": "With him in her mouth her "
		+ "pupils shrink the deeper he is (from 30% of the way to the hilt), or as she runs out of air (up to 30% of the "
		+ "way to passing out). Off: the game's." + pack.call("with his depth")})
	setting("pupil_min", 0.18, {"label": "Smallest pupils", "min": 0.05, "max": 0.9, "step": 0.01, "desc": "How "
		+ "small her pupils get when they shrink (0.9: they don't)." + pack.call("0.18")})
	setting("breath_held", 0.0, {"label": "Breath lost while held", "min": 0.0, "max": 1.0, "step": 0.01, "desc":
		"Breath she loses every tick while you hold her head with him in her mouth (of 50). 0: none (the game's)."
		+ pack.call("0.15")})
	setting("air_held", 0.0, {"label": "Air lost while held", "min": 0.0, "max": 0.5, "step": 0.01, "desc": "How much "
		+ "closer she gets to passing out every tick while you hold her head with him in her mouth, once her breath is "
		+ "gone (of 40); it stops just short of passing out. 0: none (the game's)." + pack.call("0.05")})


func _enable() -> void:
	_load_values()
	for k in ["eyes_up", "eyes_open", "darken", "pupils", "pupil_min", "breath_held", "air_held"]:
		menu_control("behaviour", CARD, MenuSchema.setting_control(self, k, {} if k.begins_with("eyes") else {"wide": true}))
	modify(&"Her.gazeAngle", {"phase": Hooks.MOOD, "op": "fn", "when": _eyes_up, "fn": _gaze})
	modify(&"Her.eyelidTarget", {"phase": Hooks.MOOD, "op": "fn", "when": _eyes_open, "fn": _eyelids})
	modify(&"Her.irisScale", {"phase": Hooks.MOOD, "op": "fn", "when": _shrinking, "fn": _iris})
	on_late_tick(_tick)


func _disable() -> void:
	_set_bg(1.0)


func _load_values() -> void:
	V.clear()
	var cf := ConfigFile.new()
	var err := cf.load(file_path("values.cfg"))
	if err != OK:
		push_error("ffbehavior: values.cfg could not be read (%s)" % error_string(err))
		return
	for section in cf.get_sections():
		for k in cf.get_section_keys(section):
			V[k] = float(cf.get_value(section, k))


## How far she is between two points on the way to passing out (0 to 1; the mod's getpassoutpercent)
func _p(her: Her, from: String, to: String) -> float:
	return clampf((her.passOutFactor / her.passOutMax - V[from]) / (V[to] - V[from]), 0.0, 1.0)


func _choking(her: Her) -> bool:
	return g.breathing and her.mouthFull and not her.passedOut


# ---------------------------------------------------------------- her eyes

func _eyes_up(her: Her) -> bool:
	return get_setting("eyes_up") and _choking(her) and _p(her, "passoutraisestartpoint", "passoutraiseendpoint") > 0.0


func _gaze(_v, her: Her) -> float:
	var p := _p(her, "passoutraisestartpoint", "passoutraiseendpoint")
	return (randf() * 2.0 - 1.0) * V["passoutrandomanglerange"] * p + V["passouteyeanglestart"] \
		+ p * (V["passouteyeangleend"] - V["passouteyeanglestart"])


func _eyes_open(her: Her) -> bool:
	if not get_setting("eyes_open") or not _choking(her):
		return false
	var p := _p(her, "passoutraiseeyelidstartpoint", "passoutraiseeyelidendpoint")
	return p > 0.0 and p < V["passouteyelidignorepoint"]


func _eyelids(_v, her: Her) -> float:
	var p := _p(her, "passoutraiseeyelidstartpoint", "passoutraiseeyelidendpoint")
	return V["passouteyelidanglestart"] + p * (V["passouteyelidangleend"] - V["passouteyelidanglestart"])


func _shrinking(her: Her) -> bool:
	match get_setting("pupils"):
		"With his depth":
			return her.mouthFull
		"As she runs out of air":
			return g.breathing
	return false


func _iris(_v, her: Her) -> float:
	var d: float
	if get_setting("pupils") == "With his depth":
		var s: float = V["passoutshrinkirisfrompenisdepthstart"]
		d = clampf((her.penisInMouthDist / maxf(1.0, her.hiltDistance) - s)
			/ (V["passoutshrinkirisfrompenisdepthend"] - s), 0.0, 1.0)
	else:
		d = _p(her, "passoutshrinkstartpoint", "passoutshrinkendpoint")
	var lo: float = get_setting("pupil_min")
	return lo + (V["passoutirisshrinksizestart"] - lo) * (1.0 - d)


# ---------------------------------------------------------------- every tick

func _tick() -> void:
	var her: Her = g.her
	if her == null or g.gamePaused:
		return
	var m := 1.0
	if g.breathing:
		m = 1.0 - (1.0 - get_setting("darken")) * _p(her, "passoutdarkenstartpoint", "passoutdarkenendpoint")
	_set_bg(m)
	if g.breathing and her.mouthFull and her.held:
		var b: float = get_setting("breath_held")
		if b > 0.0:
			g.addBreath(b)
		var a: float = get_setting("air_held")
		var top := her.passOutMax - 0.02
		if a > 0.0 and g.breathLevel >= g.breathLevelMax and her.passOutFactor < top:
			her.passOutFactor = minf(top, her.passOutFactor + a)


## The background's brightness (its colour multipliers; the mod's darkening)
func _set_bg(m: float) -> void:
	if g.bg == null or absf(m - _bg) < 0.001:
		return
	_bg = m
	var ct: FlashColorTransform = g.bg.colorTransform
	ct.redMultiplier = m
	ct.greenMultiplier = m
	ct.blueMultiplier = m
	g.bg.colorTransform = ct
