class_name DevTuning
extends RefCounted
## Port addition: hand settings for the behaviour tabs of the developer panel (DevBehaviour) - how her and his
## behaviours run, for testing and for later automation. Each is a modifier on one of the game's value points, or a
## handler, (owner "devtuning") while it is not the game's. Only while Developer mode is on (DevBehaviour.sync resets
## them when it goes off) and for this session only. The controls appear under a tab's rows.
## His cum amount and pauses are morecumspurts' (Him > Cum), not here.

const OWNER := "devtuning"

## value point -> modifier id, for the tunings that differ from the game
static var _mods := {}
## "Clench time" in seconds; 0: the game's (2 to 6 s)
static var clench_s := 0.0
static var clench_taps := true
static var spam_j := false
static var _spam_fn := Callable()


static func _set_mod(name: StringName, on: bool, spec: Dictionary) -> void:
	if _mods.has(name):
		Hooks.remove_modifier(_mods[name])
		_mods.erase(name)
	if on:
		_mods[name] = Hooks.add_modifier(name, spec, OWNER)


static func set_clench_time(s: float) -> void:
	clench_s = maxf(0.0, s)
	_set_mod(&"Her.clenchTime", clench_s > 0.0, {"phase": Hooks.OVERRIDE, "op": "set",
		"value": maxi(1, int(round(clench_s * Flash.frame_rate)))})


static func set_clench_taps(on: bool) -> void:
	clench_taps = on
	_set_mod(&"Her.clenchTaps", not on, {"phase": Hooks.OVERRIDE, "op": "set", "value": false})


## "J adds a spurt": the J key calls his ejaculation, which does nothing while he cums; a before handler on
## Him.ejaculate adds a spurt then.
static func set_spam_j(on: bool) -> void:
	spam_j = on
	if _spam_fn.is_valid():
		Hooks.remove(&"Him.ejaculate", _spam_fn)
		_spam_fn = Callable()
	if on:
		_spam_fn = func(c):
			if c.obj.ejaculating:
				DevTuning.add_spurt()
		Hooks.add_before(&"Him.ejaculate", _spam_fn, OWNER, -99998)   # after Developer mode's veto (auto off: no J)


## One more spurt: after the ones he has left while he cums, else he starts to cum.
static func add_spurt() -> void:
	var him = g.him
	if him == null:
		return
	if not him.ejaculating:
		DevBehaviour.call_now(&"Him.ejaculate", func(): him.ejaculate())
		return
	him.addRandomSpurt(int(floor(randf() * 20.0 + 6.0)))
	Journal.log("him", "Spurt added: %d to come" % him.ejaculation.size())


## Tools > Her: her air (g.breathLevelMax, 50 in the game; out of breath at half of it) and how long she lasts with
## none before passing out (her passOutMax, 40). The game's numbers, changed by hand; back with reset().
const AIR := 50.0
const LAST := 40.0
static var _breath_changed := false


static func set_air(v: float) -> void:
	_breath_changed = true
	g.breathLevelMax = v
	g.outOfBreathPoint = v / 2.0
	g.currentBreathLevel = minf(g.currentBreathLevel, v)


static func set_last(v: float) -> void:
	_breath_changed = true
	g.her.passOutMax = v
	g.her.passOutFactor = minf(g.her.passOutFactor, v)


## All back to the game's.
static func reset() -> void:
	set_clench_time(0.0)
	set_clench_taps(true)
	set_spam_j(false)
	if _breath_changed:
		set_air(AIR)
		if g.her != null:
			set_last(LAST)
		_breath_changed = false


## The tab's hand settings, under its rows.
static func controls(group: String) -> Array:
	var note := MenuSchema.note("Hand settings, while Developer mode is on and for this session.")
	match group:
		"mouth":
			return [note,
				{"type": "slider", "label": "Clench time", "tip": "How long she keeps her teeth clenched. 0: the game's, 2 to 6 s at random.",
					"min": 0.0, "max": 20.0, "step": 0.5, "get": func(): return clench_s, "set": func(v: float): set_clench_time(v),
					"format": func(v): return "game" if v <= 0.0 else "%.1f s" % v, "reset": func(): set_clench_time(0.0)},
				MenuSchema.toggle("Taps when clenching", "She taps him as she clenches her teeth (the game's). Off: she clenches them without it; Tap hands stays its own.",
					func(): return clench_taps, func(on: bool): set_clench_taps(on))]
		"him":
			return [note,
				MenuSchema.toggle("J adds a spurt", "While he cums, J (the game's cum key) adds one more spurt each time; otherwise J starts him as in the game. His cum amount and pauses: Him > Cum.",
					func(): return spam_j, func(on: bool): set_spam_j(on)),
				MenuSchema.actions("", "", [["Spurt now", func(): add_spurt(), "One more spurt while he cums; otherwise he starts to cum."]])]
	return []
