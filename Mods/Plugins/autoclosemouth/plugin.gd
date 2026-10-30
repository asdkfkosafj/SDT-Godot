extends SDTExtension
## Port of sby's autoclosemouthV10 Loader mod: she closes her mouth some time after the penis left it. The Behaviour >
## Reactions toggle or a button by the mood selector (classic Scene menu) switches it on (green) and off per character;
## saved in the character code as autoCloseMouth:CloseMouth / Normal, like the Loader mod. It closes her mouth through
## the value point Her.jawAngle, so her lips follow (the mod's "updatelips" setting is not needed).

const MOODS := ["Angry", "Normal", "Happy", "Ahegao", "Upset", "Worried", "Aggressive", "Drugged", "Frightened",
	"Spent", "Submissive", "Depressed", "Nervous", "Elated", "Disgusted", "Broken"]

var on := false
var closepercent := 0.0
var dist := 0.0
var fullcounter := 0
var distcounter := 0
var goclose := true
var manual := false
var closingmouth := false
var _button: ExtButton


func _init() -> void:
	title = "Auto close mouth"
	description = "She closes her mouth a while after the penis left it."


func _setup() -> void:
	setting("defaultmode", false, {"label": "On for new characters"})
	setting("closedistance", 38, {"label": "Distance from the tip before closing", "min": 0, "max": 400})
	setting("bufferdist", 9, {"label": "Buffer around that distance", "min": 0, "max": 100})
	setting("stopsuckingdelay", 80, {"label": "Frames after sucking before closing", "min": 0, "max": 1000})
	setting("distancedelay", 20, {"label": "Frames far enough before closing", "min": 0, "max": 1000})
	setting("maxcloseamount", 0.8, {"label": "How far she closes", "min": 0.0, "max": 1.0})
	setting("maxclosespeed", 1.5, {"label": "Closing speed", "min": 0.0, "max": 50.0})
	setting("breathlevelpercent", 0.7, {"label": "Breath needed before closing", "min": 0.0, "max": 1.0})
	setting("disableonpenisout", true, {"label": "Not while rubbing her face"})
	setting("preventlickbobonclose", true, {"label": "No licking head bob when closed"})
	setting("pulltongueonclose", true, {"label": "Pull the tongue in when closing"})
	setting("registerkeys", false, {"label": "Hotkeys (M toggle, N manual/auto)"})
	setting("startauto", true, {"label": "Start in auto mode"})
	setting("manualstartsclosed", true, {"label": "Manual mode starts closed"})
	setting("usetogglekeyasdisableinauto", false, {"label": "Toggle key pauses auto mode"})
	for m in MOODS:
		setting("closeon" + m.to_lower(), true, {"label": "Close when " + m})
	setting("enablevanillasaving", true, {"label": "Save on/off in the character code"})


func _enable() -> void:
	goclose = get_setting("manualstartsclosed")
	manual = not get_setting("startauto")
	on = get_setting("defaultmode")
	_button = menu_button("sceneMenu", -330 + 100 + 1 + 22 + 22, 40, "ᾑ0", func(): on = not on; g.saveData.saveCharData())
	on_late_tick(_tick)
	menu_control("behaviour", "Reactions", MenuSchema.toggle("Close her mouth after sucking",
		"She closes her mouth a while after the penis left it. Saved with the character.",
		func(): return on, func(v: bool): on = v; g.saveData.saveCharData(), {"keywords": "mouth close autoclosemouth"}))
	# closing: her jaw drawn towards closed by closepercent (MOOD modifier of Her.jawAngle, after moods' mouth hang;
	# dialogue triggers such as MoreTriggers' [OPEN_MOUTH_ms] override it)
	modify(&"Her.jawAngle", {"phase": Hooks.MOOD, "order": 10, "op": "fn", "fn": func(v, _her):
		return v + (Her.closedJawAngle - v) * closepercent if closingmouth else v})
	hook_after(&"Tongue.encourage", func(_c): _encourage())
	if get_setting("registerkeys"):
		on_key(77, func(): goclose = not goclose, "close mouth")
		on_key(78, func(): manual = not manual, "close mouth manual / auto")
	if get_setting("enablevanillasaving"):
		charcode_field("autoCloseMouth", func(): return "CloseMouth" if on else "Normal", _load_code,
			func(_l): on = get_setting("defaultmode"))


func _load_code(v: String, _l) -> void:
	if v == "Normal":
		on = false
	elif v == "CloseMouth":
		on = true


func _tick() -> void:
	var her = g.her
	if not g.gamePaused:
		if her.canSpeak() and not her.speaking and _is_on() and (not get_setting("disableonpenisout") or not g.penisOut):
			fullcounter = mini(get_setting("stopsuckingdelay") + 10, fullcounter + 1)
			dist = her.localToGlobal(her.topLipA).distance_to(g.him.getPenisTipPoint())
			dist += get_setting("bufferdist") if closepercent > 0 else -get_setting("bufferdist")
			var closedistance: int = get_setting("closedistance")
			if not manual:
				if dist > closedistance and (not get_setting("usetogglekeyasdisableinauto") or goclose):
					distcounter = mini(get_setting("distancedelay") + 1, distcounter + 1)
				else:
					distcounter = maxi(0, distcounter - 1)
					closepercent = 0
			elif goclose:
				distcounter = get_setting("distancedelay") + 1
				fullcounter = get_setting("stopsuckingdelay") + 1
			else:
				distcounter = get_setting("distancedelay") - 1
			if fullcounter > get_setting("stopsuckingdelay") and distcounter > get_setting("distancedelay") and _breath_ok():
				if not closingmouth and get_setting("pulltongueonclose"):
					her.tongue.stopHangingOut()
				closingmouth = true
				closepercent = maxf(0, minf(get_setting("maxcloseamount"),
					closepercent + 0.01 * minf(get_setting("maxclosespeed"), dist - closedistance)))
			else:
				closingmouth = false
		else:
			if not her.speaking:
				fullcounter = 0
				distcounter = 0
			closepercent = 0
			closingmouth = false
	_button.set_color(0x00FF00 if on else 0xFFFFFF)


func _encourage() -> void:
	if get_setting("preventlickbobonclose") and closepercent == get_setting("maxcloseamount"):
		g.her.tongue.increasedAction = 0


func _breath_ok() -> bool:
	if g.breathing:
		return (g.breathLevelMax - g.breathLevel) / g.breathLevelMax >= get_setting("breathlevelpercent")
	return true


func _is_on() -> bool:
	if not on:
		return false
	var m := mood()   # includes moremoods' moods, as the Loader mod read moremoods_comm.mymood
	if m in MOODS:
		return get_setting("closeon" + m.to_lower())
	return true
