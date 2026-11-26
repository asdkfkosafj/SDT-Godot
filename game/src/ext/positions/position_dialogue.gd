extends RefCounted
## Body positions in dialogues and character codes (animtools):
## - [ANIMTOOLS_<position>] loads a position by the name dialogues write (a path with _slash5C_ for folders, or a file
##   name), [ANIMTOOLSRANDOM] a random full position. animtools' voice triggers ([ANIMTOOLSSETVOICECHAR0] ... 7,
##   [ANIMTOOLSDISABLEHUNNIESOUNDS], [ANIMTOOLSENABLEHUNNIESOUNDS]) are taken and do nothing (the voices are not ported).
## - The variables dialogues check: atv_active (1 while positions is on), atv_position / atv_position2 (the type: 0
##   oral, 1 tit fuck, 2 vaginal, 3 anal, 4 other, 5 alt pleasure; 0 with the game's own animation), atv_position_name,
##   atv_dominant / atv_dominant2 (0 neutral, 1 her, 2 him), atv_dominant_held / 2 (oral and neutral: 2 while his
##   hand holds her head, else 1), and from body contact atv_inbody, atv_inbodycontactloose, atv_curresist / 2.
## - Character code: animtoolsPosition loads the position it names (written only with animtools' charposition saving
##   on, off by default); after any code her arms go back to the position's (the code sets the player's).

var _ext   # the positions extension


func _init(ext) -> void:
	_ext = ext


func start() -> void:
	_ext.on_dialogueactions(_setup)
	_ext.charcode_field("animtoolsPosition", _code_get, _code_set)
	_ext.hook_after(&"InGameMenu.loadData", func(_c): _after_code())


func _setup(da) -> void:
	da.register_trigger("ANIMTOOLS", -1, func(a): _load_named("_".join(PackedStringArray(a.map(func(x): return str(x))))))
	da.register_trigger("ANIMTOOLSRANDOM", 0, func(_a): _random())
	for i in 8:
		da.register_trigger("ANIMTOOLSSETVOICECHAR%d" % i, 0, func(_a): pass)
	da.register_trigger("ANIMTOOLSDISABLEHUNNIESOUNDS", 0, func(_a): pass)
	da.register_trigger("ANIMTOOLSENABLEHUNNIESOUNDS", 0, func(_a): pass)
	var v = da.vars
	var none := Callable()
	v.register("atv_active", func(): return 1, none)
	for n in ["atv_position", "atv_position2"]:
		v.register(n, func(): return _value("positiontype"), none)
	for n in ["atv_dominant", "atv_dominant2"]:
		v.register(n, func(): return _value("dominant"), none)
	for n in ["atv_dominant_held", "atv_dominant_held2"]:
		v.register(n, _dominant_held, none)
	v.register("atv_position_name", func(): return "" if _ext.current == null else _ext.loaded_name, none)
	v.register("atv_inbody", func(): return _contact("inbody"), none)
	v.register("atv_inbodycontactloose", func(): return _contact("loose"), none)
	for n in ["atv_curresist", "atv_curresist2"]:
		v.register(n, func(): return _contact("resist"), none)


func _value(key: String) -> int:
	return 0 if _ext.current == null else int(_ext.current.values[key])


func _dominant_held() -> int:
	var d := _value("dominant")
	if d == 0 and _value("positiontype") == 0:
		return 2 if g.him.currentArmPosition == 0 else 1
	return d


func _contact(what: String):
	var bc = Extensions.get_extension("bodycontact")
	if bc == null or not bc.enabled or not bc.active:
		return 0
	match what:
		"inbody":
			return 1 if bc.in_body else 0
		"loose":
			return 1 if bc.loose else 0
	return bc.resistance_scaled()


## A dialogue's or code's position (animtools keeps the name as dialogues give it, folders with \); a dialogue's
## comes with the transition, a code's at once (it is part of loading her).
func _load_named(name: String, fade := true) -> void:
	_ext.request(name, name.replace("_slash5C_", "\\"), fade)


func _random() -> void:
	_ext.random()


func _code_get():
	if _ext.current == null or _ext._setting_global("enablecharpositionsaving") != 1:
		return null
	return _ext.loaded_name


func _code_set(value: String, _load) -> void:
	_load_named(value.split(",")[0], false)


func _after_code() -> void:
	if _ext.current != null and _ext._setting_global("reloadarmsaftercharcode") == 1 and _ext.arms != null:
		_ext.arms.show(_ext.current.values)
