extends SDTExtension
## Condoms: he can wear a condom (Him > Condom, or the Q key). It rolls on while he is out of her mouth, follows his
## penis's outline (every type, size and penis mod; not the strap-on) and hides in her mouth with it.
## His cum stays in it (no strands, her mouth does not fill) and hangs from his tip in a teardrop sack that grows with
## it (no more once it is full): a weight on stretchy latex with real gravity, heavier the more cum is in it, drawn
## smoothly between ticks. It rests and rubs on her face, squeezes in through her lips after him and lies in her
## mouth (the x-ray view draws it there). Past her throat ring it is stuck: pulled out, the latex to it stretches and
## holds her head back until it pops out; pushed in, it goes through the ring with no hold; in her
## throat it makes a swallow lump in her neck.
## With cum in it, Q has his left hand take it off: his hand goes to his tip, pulls it off (the empty latex stretched
## from his glans to his fist; a drop of cum stays on his tip), ties it and holds it by the knot, the sack hanging from
## his fist and swinging with it. (His left arm must show and hang loose; else it only rolls off.)
## While he holds it, a short Q press starts pin mode (pins.gd: the mouse moves his hand, a click pins it on her,
## right click / Esc / Q stops); a long Q press drops it. He puts on a new one once it is pinned or dropped.
## Dialogue: line types condom_on, condom_filled, condom_stuck, condom_pinned (LINES); variables condoms.worn,
## condoms.full, condoms.pinned; triggers [CONDOM_ON], [CONDOM_OFF].

const ROLL_TICKS := 15     # rolling it on or off takes half a second
const CUT_R := 70.0        # round his tip the bulb draws the outline of the sleeve and the sack as one line
const FULL := 160.0        # cum (strand link masses, one load is about 15-25) that fills the bulb to its biggest
                           #   (half of it weighs, holds her and stretches as much as it gets: condom.BULB_HEFT)
const REACH_TICKS := 12    # taking a full one off: his hand goes to his tip,
const PULL_TICKS := 14     #   pulls it off,
const TIE_TICKS := 16      #   and ties it
const PULL_DIST := 170.0   # it pulls it this far off his tip (penis units)
const AHEAD := 3.0         # it takes it by its tip just this far past his glans (penis units)
const DROP_LINKS := 2      # ... made of this many strand links
const DROP_TICKS := 50     # the drop of cum left on his tip hangs there this long, then falls
const WINCE := 0.85         # stuck sack about to pop out: her eyes squint this share of the way to her wince
## Her dialogue line types for it: [life (build it holds), priority] as the game's own (Dialogue.gd): he put it on, a
## spurt went into it (as her cum lines), its sack is stuck in her throat, he pinned one on her.
const LINES := {
	"condom_on": [Dialogue.MAX_BUILD, 1],
	"condom_filled": [Dialogue.MAX_BUILD + 240, 3],
	"condom_stuck": [Dialogue.MAX_BUILD + 80, 2],
	"condom_pinned": [Dialogue.MAX_BUILD + 80, 1],
}

var Condom: GDScript
var Tied: GDScript
var pins = null            # pins.gd: pin mode, and the ones pinned on her or falling
var tied = null            # tied.gd: the one he took off, in his hand
var _off := 0              # taking it off: 0 not, 1 his hand goes to his tip, 2 pulls it off, 3 ties it
var _off_t := 0            # ticks into that
var _grip0 := Vector2()    # where the knot point of his hand was as it started (stage coordinates)
var _end0 := 0.0           # where the sleeve ended as he started pulling it off (penis-local x)
var _tie_at := Vector2()   # where his hand pulled it to (his coordinates)
var _rest_at := Vector2()  # where the knot point of his hand was as it started (his coordinates)
var _drop = null           # the drop of cum on his tip (a cum strand), and its ticks left
var _drop_t := 0
var condom = null          # condom.gd, while he wears one (or it is rolling)
var worn := false          # he wears one (or it is rolling on)
var roll := 0.0            # 0 at his tip .. 1 rolled all the way on
var _dir := 0              # +1 rolling on, -1 rolling off
var _sig := ""             # what the outline was scanned for (penis type, skin, art)
var _dirty := true
var _spurt_id := 0         # the spurt the last caught link was of (a new one: Him's spurt timer went up again)
var _spurt_left := 0
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
	Tied = load_script("tied.gd")
	pins = load_script("pins.gd").new(self)
	on_late_tick(_tick)
	on_key(KEY_Q, toggle, "condom: on / off, take off, pin (hold: drop)", "condom")
	on_key(27, func(): pins.stop_aim(), "condom: stop pinning", "pin_cancel")
	# pin mode: her head stays where it was while the mouse moves his hand
	modify(&"DT.mousePos", {"op": "fn", "fn": func(v, _dt): return pins.mouse_pos(v)})
	modify(&"Him.cumCaught", {"op": "set", "value": true, "phase": Hooks.FINAL,
		"when": func(_him): return roll > 0.0 and _off < 2 and condom != null and condom.sprite.parent != null})
	# taking a full one off: his left hand
	modify(&"HimMaleBody.leftHand", {"op": "fn", "fn": func(v, _body): return _hand_target(v)})
	hook_after(&"Him.catchCum", func(c): _caught(c.args[0]))
	# stuck behind her throat ring the sack's stretched latex pulls her head back to him (pushed against it, it holds
	# her back a little); in her throat it makes a swallow lump in her neck
	modify(&"Her.drag", {"phase": Hooks.MOOD, "op": "fn", "fn": func(v, her):
		if condom == null:
			return v
		return v + condom.drag_add + maxf(0.0, her.speed) * condom.grip_in})
	# and it holds her head back from leaving him, whatever moves her out (the player, her resistance, her pull-off)
	modify(&"Her.holdOut", {"phase": Hooks.MOOD, "op": "fn", "fn": func(v, _her):
		return maxf(v, condom.grip_out) if condom != null else v})
	# held there she squints more and more as it gets close to popping out (towards her wince), and trembles on him
	# lightly just before it does
	modify(&"Her.tremble", {"phase": Hooks.MOOD, "op": "fn", "fn": func(v, _her):
		return v + condom.TREMBLE * smoothstep(condom.TREMBLE_FROM, 1.0, condom.strain_k) if condom != null else v})
	modify(&"Her.eyelidTarget", {"phase": Hooks.MOOD, "op": "fn", "fn": func(v, her):
		return lerpf(v, her.eyePosWince, WINCE * smoothstep(0.0, 0.8, condom.strain_k)) if condom != null else v})
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
	on_dialogueactions(func(da):
		da.register_trigger("CONDOM_ON", 0, func(_a): set_worn(true))
		da.register_trigger("CONDOM_OFF", 0, func(_a): take_off())
		da.vars.register_read("condoms.worn", func(): return 1 if worn else 0)
		da.vars.register_read("condoms.full", func(): return roundi(100.0 * cum / FULL) if worn else 0)
		da.vars.register_read("condoms.pinned", func(): return pins.pinned.size() if pins != null else 0))


func _disable() -> void:
	_off = 0
	if g.dialogueControl != null:
		for t in LINES:
			g.dialogueControl.states.erase(t)
	if pins != null:
		pins.free_all()
		pins = null
	_let_drop()
	if tied != null:
		tied.release()
		tied = null
	_remove()
	if condom != null:
		condom.free_all()
	condom = null
	_sig = ""
	worn = false
	_dir = 0


func _setting_changed(_key: String, _value) -> void:
	_dirty = true
	_bulb_dirty = true


## A link of a spurt caught: it shoots into the sack (seen when it hangs free), its cum into the bulb.
func _caught(mass: float) -> void:
	add_cum(mass)
	if condom != null and g.him != null:
		var h = g.him
		var left: int = h.bmTimer if g.bukkakeMode else h.spurtTimer   # (counts down in a spurt: up again, a new one)
		if left >= _spurt_left:
			_spurt_id += 1
			say("condom_filled")
		_spurt_left = left
		var thick := maxf(g.strandControl.cumMinThickness if g.strandControl != null else 1.0, pow(mass * 2.0, 1.5))
		condom.spurt(h.randomSpurtSpeed, thick, _spurt_id)   # (as cum strands: Him's speed, Strand's thickness)


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
	if _off != 0:
		return
	if tied != null and not worn:   # he holds one: a short press pins it, a long one drops it (pins.gd)
		pins.q_pressed()
		return
	if worn:
		take_off()
	else:
		set_worn(true)


## Takes it off (Q, [CONDOM_OFF]): one with cum in it his left hand takes off and ties; else (or his arm cannot) it
## rolls off. Only while he is out of her mouth.
func take_off() -> void:
	if _off != 0 or not worn:
		return
	if _dir == 0 and cum > 0.0 and condom != null and _hand_ok() and not g.him.inMouth:
		_off = 1   # a full one: his hand takes it off
		_off_t = 0
		_grip0 = _hand().localToGlobal(Tied.GRIP)
		_rest_at = g.him.globalToLocal(_grip0)
		return
	set_worn(false)


## Puts the condom on (rolls on) or takes it off. Only while he is out of her mouth, and not on the strap-on.
func set_worn(on: bool) -> void:
	if on == worn or g.him == null or _off != 0 or (on and tied != null):   # (one in his hand: pinned or dropped first)
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
	_tick_off()
	pins.tick()
	if worn and _strapon():
		worn = false
		roll = 0.0
		_dir = 0
	if _dir != 0:
		roll = clampf(roll + float(_dir) / ROLL_TICKS, 0.0, 1.0)
		_dirty = true
		if (_dir > 0 and roll >= 1.0) or (_dir < 0 and roll <= 0.0):
			if _dir > 0:
				say("condom_on")
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
		condom.step_sack(sack_length(), bulb_radius(), 2.0 * cum / FULL)   # (drawn every frame while it moves: condom.gd)
		condom.step_jets()
		if condom.stuck_event:
			say("condom_stuck")
	# while there is a sack the sleeve leaves its outline round the tip to it (one line round both)
	var cut := CUT_R if cum > 0.0 else 0.0
	if cut != condom.cut_r:
		condom.cut_r = cut
		_dirty = true
	if _dirty:
		_dirty = false
		var k := 1.0 - pow(1.0 - roll, 2.0)   # eases out as it reaches its place
		var end: float = lerpf(condom.tip_x, condom.tip_x + (condom.base_x - condom.tip_x) * get_setting("cover"), k)
		if _off == 2:   # (pulled off: its end slides to his tip)
			end = lerpf(_end0, condom.tip_x, smoothstep(0.0, 1.0, float(_off_t) / PULL_TICKS))
		condom.draw(end, roll, get_setting("colour"), get_setting("density"))
		_bulb_dirty = true
	if g.cumRGB != _cum_rgb:
		_cum_rgb = g.cumRGB
		_bulb_dirty = true
	if _bulb_dirty:
		_bulb_dirty = false
		condom.set_bulb(bulb_radius(), get_setting("colour"), get_setting("density"),
			Color.hex((g.cumRGB << 8) | 0xFF))


## Builds her dialogue line type `t` (LINES) by a one-off event's build, as the game's events do; only when the loaded
## dialogue has lines of it (else it could be chosen over her other lines and she would say nothing).
func say(t: String) -> void:
	var dc = g.dialogueControl
	if dc == null or dc.library.getPhrases(t).is_empty():
		return
	if not dc.states.has(t):   # (a dialogue line type of its own, from the first time)
		dc.states[t] = DialogueState.new(LINES[t][0], LINES[t][1])
	dc.buildState(t, Dialogue.ONE_OFF_BUILD)


## Takes the drawing off his penis. The outline it scanned stays (_sig), so putting one on again needs no new scan.
func _remove() -> void:
	roll = 0.0
	cum = 0.0   # (a full one his hand took off has its cum in tied.gd)
	if condom != null:
		condom.reset_sack()
	if condom != null and condom.sprite.parent != null:
		condom.detach()
		_dirty = true


## His left hand can take it off: his male body, the arm showing and hanging loose (not holding a leash).
func _hand_ok() -> bool:
	var him: Him = g.him
	return him.currentBody is HimMaleBody and him.currentLeftArmPosition == 1 and him.leftArmContainer.visible


func _hand() -> FlashDisplayObject:
	return g.him.leftArmContainer.arm.foreArm.hand


## Where his hand's knot point goes while he takes it off (stage coordinates).
func _hand_goal() -> Vector2:
	var pen: FlashDisplayObject = g.him.penis
	var tip: Vector2 = condom._outline[condom._ti] if condom != null and condom._outline.size() > 0 else g.him.tipMid
	var a := pen.localToGlobal(tip)
	var out := pen.localToGlobal(tip + Vector2(-1, 0)) - a   # one penis unit out past his tip
	match _off:
		1:
			return _grip0.lerp(a + out * AHEAD, smoothstep(0.0, 1.0, float(_off_t) / REACH_TICKS))
		2:
			var u := smoothstep(0.0, 1.0, float(_off_t) / PULL_TICKS)
			# off his tip, then down and back towards him (his arm reaches no further forwards; not up into her face)
			var fw := (Vector2(0, 0.9) - out.normalized() * 0.35).normalized() * out.length()
			var d := PULL_DIST * u
			return a + out * (AHEAD + minf(d, 20.0)) + fw * maxf(0.0, d - 20.0)
		3:   # tying it (a little twist) on the way back to where his hand hangs (with his body)
			var u := float(_off_t) / TIE_TICKS
			var w := sin(PI * u) * 10.0 * out.length()
			var at := g.him.localToGlobal(_tie_at).lerp(g.him.localToGlobal(_rest_at), smoothstep(0.0, 1.0, u))
			return at + Vector2(cos(TAU * 2.0 * u) - 1.0, sin(TAU * 2.0 * u)) * w * 0.5
	return Vector2()


## HimMaleBody.leftHand: while he takes it off, his hand's wrist where its knot point is at _hand_goal().
func _hand_target(v: Vector2) -> Vector2:
	if (_off == 0 and not pins.aiming) or not _hand_ok():
		return v
	var hand := _hand()
	var off := hand.localToGlobal(Tied.GRIP) - hand.localToGlobal(Vector2.ZERO)
	var goal: Vector2 = pins.aim_goal() if pins.aiming else _hand_goal()
	return g.him.leftArmContainer.globalToLocal(goal - off)   # (the arm's IK works in its container's units)


## Taking it off, a tick at a time; and the one in his hand.
func _tick_off() -> void:
	if _drop != null:
		_drop_t -= 1
		if DROP_TICKS - _drop_t <= DROP_LINKS:   # (a link a tick after the strand starts, as his spurts do)
			_drop.insertLink(Vector2(0.0, 1.0), 2, g.randomCumMass())
		if _drop_t <= 0 or g.him.inMouth:
			_let_drop()
	if _off != 0 and (not _hand_ok() or condom == null):
		_off = 0   # (his arm went away: it stays on, or is gone if already off)
	if _off != 0:
		_off_t += 1
	if tied != null and worn and _off == 0:   # (a new one went on while he held one: the held one falls)
		pins.drop()
	match _off:
		1:
			if g.him.inMouth:
				_off = 0   # (he went back in: it stays on)
			elif _off_t >= REACH_TICKS:
				_take()
		2:
			_dirty = true
			tied.tail = g.him.penis.localToGlobal(condom._outline[condom._ti] + Vector2(1.0, 0.0))
			if _off_t >= PULL_TICKS:
				_tie_at = g.him.globalToLocal(_hand_goal())
				worn = false
				_dir = 0
				_remove()
				_start_drop()
				tied.closed = true
				tied.bow = 0.0
				_off = 3
				_off_t = 0
		3:
			# the sleeve's end springs back into his fist and is tied: a short end over the knot
			var u := smoothstep(0.0, 1.0, float(_off_t) / TIE_TICKS)
			var stub: Vector2 = tied.stub_point()
			if is_nan(tied.tail.x):
				tied.tail = stub
			tied.tail = tied.tail.lerp(stub, lerpf(0.35, 1.0, u))
			tied.tail_w = lerpf(tied.tail_w, Tied.TIE_W, 0.3)
			tied.bow = smoothstep(0.3, 1.0, u)   # (the rim's loops open as the sleeve's end goes into the knot)
			if _off_t >= TIE_TICKS:
				_off = 0
				tied.tied = true
	if tied != null:
		if not _hand_ok():
			pins.drop()   # (his arm went away: it falls)
			return
		tied.attach(_hand())
		tied.set_look(get_setting("colour"), get_setting("density"), Color.hex((g.cumRGB << 8) | 0xFF))
		tied.step()


## His hand has it by its tip: the sack goes from his penis to his hand.
func _take() -> void:
	if tied != null:
		pins.drop()   # (not while he holds one: set_worn waits; but to be safe it falls)
	tied = Tied.new(condom)
	tied.attach(_hand())
	var neck: Array = condom._neck(bulb_radius())
	var a: Vector2 = g.him.penis.localToGlobal(neck[0])
	var unit: float = g.him.penis.localToGlobal(neck[0] + Vector2(-1, 0)).distance_to(a)
	var at: Vector2 = condom.sack_p if condom.sack_ok else a + Vector2(0, sack_length() * unit)
	tied.take(at, condom.sack_v if condom.sack_ok else Vector2.ZERO, bulb_radius(), sack_length(), 2.0 * cum / FULL, unit)
	var e: Vector2 = condom.edges_at(condom.tip_x + 10.0)
	tied.tail_w = absf(e.y - e.x) * 0.5
	var k := 1.0 - pow(1.0 - roll, 2.0)
	_end0 = lerpf(condom.tip_x, condom.tip_x + (condom.base_x - condom.tip_x) * get_setting("cover"), k)
	cum = 0.0   # (no sack on his penis any more)
	_bulb_dirty = true
	condom.sack_ok = false
	_off = 2
	_off_t = 0


## A small drop of cum left on his tip: a short cum strand that hangs there a while, then falls.
func _start_drop() -> void:
	_let_drop()
	_drop = g.strandControl.newCumStrand(g.him.tipMid, g.him.penis)
	_drop_t = DROP_TICKS


func _let_drop() -> void:
	if _drop != null:
		_drop.detachSourceLink(Vector2.ZERO, 0)
		_drop = null
