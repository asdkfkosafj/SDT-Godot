extends SDTExtension
## Port of sby's deepthroatactionsV6 Loader mod: what happens when he reaches her throat (past the game's deepthroat
## distance) and when he hilts (past its hilt distance): once when he gets there ("reaching") and every tick while he
## stays. Gag sound, wince, wide eyes, a splat of droplets, pleasure for him, breath and oxygen she loses, her mood.
## Behaviour > Deep throat and Behaviour > Hilt; everything off by default (the game's own), the pack's values are in
## each row's description.
## Adapted:
## - each "amount" is one slider: the mod's random part is kept as the pack's share of it (pleasure on reaching her
##   throat: 5 + up to 10 -> the slider is the 5, up to twice it comes on top), its on/off switches are the slider at 0;
## - her wide eyes "faster back to normal" go through a new value point, Her.shockFade (how much the shock eases per
##   tick), instead of the mod writing her shock every tick; "wide eyes while he stays" is a MOOD modifier of
##   Her.eyelidShock (dialogue [SHOCK] and passing out still win), handed to the game's own shock when he leaves;
## - wincing, gagging, passing out, pleasure, breath and moods go through the game's own calls (Her.wince, playGag,
##   Her.passOut, Him.givePleasure, g.addBreath, Her.setMood), so wincecontrol and vetoes on them still apply;
## - the moods are any mood the game has (moremoods' too) by name instead of the mod's numbers.
## - the splat is spit droplets, like the game's own splat when he hilts fast (the mod drew cum droplets), so it
##   follows the Spit setting.
## Kept from the mod: wide eyes reach at most 120, a wince is held for 6 ticks after reaching.

const ZONES := ["throat", "hilt"]
const ZONE_CARDS := {"throat": "Deep throat", "hilt": "Hilt"}
const WINCE_HOLD := 6
const SHOCK_MAX := 120
## the mod's shock "normalize faster" rates: linear (share of the shock amount), then towards the amount
const SHOCK_FADE := {"throat": [0.005, 0.05], "hilt": [0.005, 0.03]}
## the random part of each amount, as a share of the slider (the pack's random / base)
const RANDOM := {
	"throat": {"pleasure_hit": 2.0, "pleasure_in": 2.0 / 1.1, "breath_hit": 2.0, "oxygen_hit": 2.0},
	"hilt": {"pleasure_hit": 2.0, "pleasure_in": 2.0, "breath_hit": 2.0, "oxygen_hit": 2.0},
}
const SPLAT_SPEED := [1.0, 0.5]      # base, share of her movement / 10
const SPLAT_POWER := [1.0, 0.5]      # base, share of her previous movement / 10
const OFF := "Off"

var _in := {"throat": false, "hilt": false}
var _wince_timer := {"throat": 0, "hilt": 0}
var _mood_prev := {"throat": "", "hilt": ""}   # her mood before the zone changed it ("": not changed)
var _fading := {"throat": false, "hilt": false}   # her shock from this zone eases faster
var _fade_id := 0
var _hold_ids := []


func _init() -> void:
	title = "Deep throat actions"
	description = "What happens when he reaches her throat and when he hilts: gag, wince, wide eyes, splat, pleasure, breath, mood."


func _setup() -> void:
	for z in ZONES:
		var where: String = "reaches her throat" if z == "throat" else "hilts"
		var stay: String = "in her throat" if z == "throat" else "hilted"
		var pack := func(v): return " The Loader pack: %s." % v
		setting(z + "_gag", 0.0, {"label": "Gag sound", "min": 0.0, "max": 1.0, "step": 0.05,
			"desc": "Chance of a gag sound when he %s. 0: never (the game's).%s" % [where, pack.call("70%" if z == "throat" else "off")]})
		setting(z + "_wince", 0.0, {"label": "Wince", "min": 0.0, "max": 1.0, "step": 0.05,
			"desc": "Chance she winces when he %s (held for a moment). 0: never.%s" % [where, pack.call("70%")]})
		setting(z + "_wince_in", false, {"label": "Wince while " + stay,
			"desc": "She keeps wincing while he stays %s (unless her eyes are wide).%s" % [stay, pack.call("off")]})
		setting(z + "_shock", 0, {"label": "Wide eyes", "min": 0, "max": SHOCK_MAX,
			"desc": "How wide her eyes go when he %s, if she does not wince (120: almost no pupils). They go back to normal faster than after the game's own shock. 0: off.%s" % [where, pack.call("off (90)")]})
		setting(z + "_shock_in", false, {"label": "Wide eyes while " + stay,
			"desc": "Her eyes stay wide (as wide as above) while he stays %s, then go back. Wincing while %s wins over it.%s" % [stay, stay, pack.call("off")]})
		setting(z + "_splat", 0, {"label": "Splat", "min": 0, "max": 30,
			"desc": "Droplets that splash from her lips when he %s. 0: none (the game splashes on its own when he hilts fast).%s" % [where, pack.call("10" if z == "throat" else "off (5)")]})
		setting(z + "_splat_sound", false, {"label": "Splat sound", "desc": "A splat sound when he %s.%s" % [where, pack.call("off")]})
		setting(z + "_pleasure_hit", 0.0, {"label": "His pleasure", "min": 0.0, "max": 40.0, "step": 0.5,
			"desc": "Pleasure for him when he %s: this, plus up to twice it at random. 0: none (the game gives 5 to 10 each tick he is hilted).%s" % [where, pack.call("5" if z == "throat" else "10")]})
		setting(z + "_pleasure_in", 0.0, {"label": "His pleasure while " + stay, "min": 0.0, "max": 5.0, "step": 0.1,
			"desc": "Pleasure for him every tick he stays %s: this, plus up to about twice it at random. 0: none.%s" % [stay, pack.call("1.1" if z == "throat" else "0.5")]})
		setting(z + "_breath_hit", 0.0, {"label": "Breath lost", "min": 0.0, "max": 20.0, "step": 0.5,
			"desc": "Breath she loses when he %s (of 50): this, plus up to twice it at random. 0: none.%s" % [where, pack.call("1")]})
		setting(z + "_breath_in", 0.0, {"label": "Breath lost while " + stay, "min": 0.0, "max": 0.5, "step": 0.01,
			"desc": "Breath she loses every tick he stays %s. 0: none.%s" % [stay, pack.call("0.01")]})
		setting(z + "_oxygen_hit", 0.0, {"label": "Oxygen lost", "min": 0.0, "max": 20.0, "step": 0.5,
			"desc": "How much closer she gets to passing out when he %s (of 40): this, plus up to twice it at random. At the top she passes out. 0: none.%s" % [where, pack.call("1")]})
		setting(z + "_oxygen_in", 0.0, {"label": "Oxygen lost while " + stay, "min": 0.0, "max": 0.5, "step": 0.01,
			"desc": "How much closer she gets to passing out every tick he stays %s. 0: none.%s" % [stay, pack.call("0.01")]})
		setting(z + "_mood", OFF, {"label": "Mood while " + stay,
			"desc": "Her mood while he stays %s; her own mood comes back when he leaves.%s" % [stay, pack.call("off")]})
	setting("oxygen_when_breathless", true, {"label": "Oxygen only when out of breath",
		"desc": "Oxygen is lost only once her breath is all gone (as the game does). Off: also while she still has breath. The Loader pack: on."})


func _enable() -> void:
	for z in ZONES:
		var card: String = ZONE_CARDS[z]
		for key in ["gag", "wince", "wince_in", "shock", "shock_in", "splat", "splat_sound", "pleasure_hit", "pleasure_in",
				"breath_hit", "breath_in", "oxygen_hit", "oxygen_in"]:
			var extra := {"wide": true}
			if key in ["gag", "wince"]:
				extra["format"] = func(v): return "%d%%" % roundi(v * 100.0)
			menu_control("behaviour", card, MenuSchema.setting_control(self, z + "_" + key, extra))
		var mk: String = z + "_mood"
		var mood := MenuSchema.choice(_label(mk), _desc(mk), func(): return [OFF] + Moods.selectable(), func(): return str(get_setting(mk)),
			func(v: String): set_setting(mk, v), {"wide": true})
		mood["restore"] = func(): set_setting(mk, OFF)
		menu_control("behaviour", card, mood)
	menu_control("behaviour", ZONE_CARDS["throat"], MenuSchema.setting_control(self, "oxygen_when_breathless"))
	_apply_holds()
	on_late_tick(_tick)


func _disable() -> void:
	for z in ZONES:
		_leave(z)
		_in[z] = false
	_fade_id = 0
	_hold_ids.clear()


func _setting_changed(key: String, _value) -> void:
	if key.ends_with("_shock") or key.ends_with("_shock_in") or key.ends_with("_wince_in"):
		_apply_holds()


func _label(key: String) -> String:
	for s in settings():
		if s["key"] == key:
			return s.get("label", key)
	return key


func _desc(key: String) -> String:
	for s in settings():
		if s["key"] == key:
			return s.get("desc", "")
	return ""


## "Wide eyes while he stays": a MOOD modifier of Her.eyelidShock while he is in the zone (only while switched on).
func _apply_holds() -> void:
	for id in _hold_ids:
		Hooks.remove_modifier(id)
	_hold_ids.clear()
	for z in ZONES:
		if _holds(z):
			_hold_ids.append(modify(&"Her.eyelidShock", {"phase": Hooks.MOOD, "op": "fn",
				"when": func(her): return _in[z] and not her.passedOut,
				"fn": func(v, _her): return maxf(v, float(get_setting(z + "_shock")))}))


func _holds(z: String) -> bool:
	return get_setting(z + "_shock_in") and int(get_setting(z + "_shock")) > 0 and not get_setting(z + "_wince_in")


func _tick() -> void:
	var her = g.her
	if her == null:
		return
	var full: bool = her.mouthFull
	var throat: bool = full and her.penisInMouthDist > her.deepthroatDistance
	var hilt: bool = full and her.penisInMouthDist > her.hiltDistance
	_zone(her, "throat", throat, throat and not _in["throat"])
	_zone(her, "hilt", hilt, hilt and her.justHilt)
	if _fade_id != 0 and float(her.eyelidMotion["shock"]) <= 0.0:
		_fading["throat"] = false
		_fading["hilt"] = false
		Hooks.remove_modifier(_fade_id)
		_fade_id = 0


func _zone(her, z: String, inside: bool, reached: bool) -> void:
	if not inside:
		if _in[z]:
			_leave(z)
		_in[z] = false
		return
	_in[z] = true
	if reached:
		_reach(her, z)
	else:
		_stay(her, z)
	if get_setting(z + "_wince_in"):
		if not her.passedOut and float(her.eyelidMotion["shock"]) == 0.0:
			her.wince()
	_mood(her, z)


func _amount(z: String, key: String) -> float:
	var base: float = get_setting(z + "_" + key)
	return base + randf() * base * RANDOM[z].get(key, 0.0) if base > 0.0 else 0.0


func _oxygen_allowed() -> bool:
	return not get_setting("oxygen_when_breathless") or g.breathLevel == g.breathLevelMax


## He just got there.
func _reach(her, z: String) -> void:
	var n: int = get_setting(z + "_splat")
	if n > 0:
		_splat(her, n)
	if get_setting(z + "_splat_sound"):
		g.soundControl.playSplat()
	var p := _amount(z, "pleasure_hit")
	if p > 0.0:
		g.him.givePleasure(p)
	if z == "hilt":   # the mod: also while she is passed out
		_breath(z, "breath_hit")
	if her.passedOut:
		_wince_timer[z] = 0
		return
	_wince_timer[z] = WINCE_HOLD
	var o := _amount(z, "oxygen_hit")
	if o > 0.0 and _oxygen_allowed():
		her.passOutFactor = minf(her.passOutMax, her.passOutFactor + o)
	if z == "throat":
		_breath(z, "breath_hit")
	if her.passOutFactor >= her.passOutMax:
		her.passOut()
		return
	if randf() < float(get_setting(z + "_gag")):
		g.soundControl.playGag(her.pos)
	if randf() < float(get_setting(z + "_wince")):
		her.wince()
	elif int(get_setting(z + "_shock")) > 0:
		her.shock(int(get_setting(z + "_shock")))
		_fade(z)


## He stays there.
func _stay(her, z: String) -> void:
	_breath(z, "breath_in")
	var o: float = get_setting(z + "_oxygen_in")
	if o > 0.0 and _oxygen_allowed():
		her.passOutFactor = minf(her.passOutMax, her.passOutFactor + o)
	var p := _amount(z, "pleasure_in")
	if p > 0.0:
		g.him.givePleasure(p)
	if _wince_timer[z] > 0:
		_wince_timer[z] -= 1
		if float(get_setting(z + "_wince")) > 0.0 and her.winceTimer > 0:
			her.wince()


func _breath(z: String, key: String) -> void:
	var b := _amount(z, key) if key.ends_with("_hit") else float(get_setting(z + "_" + key))
	if b > 0.0:
		g.addBreath(b)


## He left the zone: her own mood back, and wide eyes held while he stayed are handed to the game's shock.
func _leave(z: String) -> void:
	var her = g.her
	if her == null:
		_mood_prev[z] = ""
		return
	if _mood_prev[z] != "":
		her.setMood(_mood_prev[z])
		g.inGameMenu.updateMoods()
		_mood_prev[z] = ""
	if _holds(z) and not her.passedOut and _hold_ids.size() > 0:
		her.shock(int(get_setting(z + "_shock")))
		_fade(z)


func _mood(her, z: String) -> void:
	var m: String = get_setting(z + "_mood")
	if m == OFF or not m in Moods.all():   # off, or a mood of an extension that is off now
		return
	if z == "throat" and _in["hilt"] and get_setting("hilt_mood") != OFF:
		return   # the hilt's mood takes over
	if _mood_prev[z] == "":
		_mood_prev[z] = Moods.current()
	if Moods.current() != m:
		her.setMood(m)
		g.inGameMenu.updateMoods()


## Her shock from zone `z` goes back to normal faster (the mod's rates): Her.shockFade, until it is gone.
func _fade(z: String) -> void:
	_fading[z] = true
	if _fade_id == 0:
		_fade_id = modify(&"Her.shockFade", {"phase": Hooks.MOOD, "op": "fn", "fn": _fade_step})


func _fade_step(v, her) -> float:
	var z := "hilt" if _fading["hilt"] else "throat"
	var amount := float(get_setting(z + "_shock"))
	var rates: Array = SHOCK_FADE[z]
	var s: float = float(her.eyelidMotion["shock"]) - amount * rates[0]
	return v + amount * rates[0] + maxf(0.0, amount - s) * rates[1]


## The mod's splat: spit droplets from along her lips, thrown with her movement (none with Spit off, as the game's).
func _splat(her, count: int) -> void:
	if not g.spit:
		return
	var power: float = her.previousMovement / 10.0 * SPLAT_POWER[1] + SPLAT_POWER[0]
	var speed: float = SPLAT_SPEED[0] + her.movement / 10.0 * SPLAT_SPEED[1]
	var top: Vector2 = g.sceneLayer.globalToLocal(her.localToGlobal(her.topLipB))
	var bottom: Vector2 = g.sceneLayer.globalToLocal(her.head.jaw.localToGlobal(her.bottomLipA))
	var step := (top - bottom) / 100.0
	for i in count:
		var along := randf() * 100.0
		var p := Vector2(bottom.x + her.movement / 10.0 + along * step.x, bottom.y + along * step.y)
		var vy := (randf() * 2.0 - 1.0 - (along - 50.0) / 10.0) * speed
		var vx := (randf() * 4.0 + power) * speed
		g.strandFrontLayer.addChild(Droplet.new(p, Vector2(vx, vy), randf() * 1.5 + 0.1))
