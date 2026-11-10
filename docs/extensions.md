# Extensions and plugins

The game code in `game/src` is a 1:1 port of the original ActionScript. Features that are not in the original
(reimplemented Loader mods, fixes, new options) are **extensions**, kept out of the ported classes:

- **Built-in extensions**: `game/src/ext/<name>/`, shipped with the game, each switched on or off in the options.
- **Plugins**: `Mods/Plugins/<name>/`, installed by the player; loaded automatically at startup, each can be
  switched off. The repo ships the plugins made for the port there (ports of Loader mods: autoclosemouth,
  darkenpassout); the rest of `Mods/` is the player's own and not tracked.

Both use the same API (`SDTExtension`). One switch, **Vanilla mode** (`--vanilla` on the command line), turns every
extension off and gives the original game.

Status: hooks, the extension base class, tick callbacks, events, settings, character code fields, classic menu
buttons, controls in the new menu (with generated settings pages and the list of extensions), hotkeys, dialogue
triggers / variables and plugin loading exist.

Built in, each a reimplementation of the Loader mod of that name (id in brackets), written from its documentation
and behaviour: DialogueActions (`dialogueactions`), moremoods (`moremoods`), MoreTriggers (`moretriggers`),
DA_sbyAddons (`dasbyaddons`), dialogpatch (`dialogpatch`), dialogdisplayedit (`dialogdisplayedit`), gaggeddialog
(`gaggeddialog`), dialogspeed (`dialogspeed`) and monitordialog (`monitordialog`). Defaults are the original game's
behaviour and look; the extensions add what dialogues use (triggers, styles, line types).

## Writing an extension

```gdscript
extends SDTExtension

func _init() -> void:
	id = "example"            # unique, used for settings and file names
	title = "Example"
	default_enabled = false   # on or off until the player chooses

func _setup() -> void:        # declare settings; saved values are loaded afterwards
	setting("strength", 0.5, {"label": "Strength", "min": 0.0, "max": 1.0})

func _enable() -> void:       # register everything here
	on_tick(_tick)            # every game tick, before the game's own logic
	hook_after(&"Her.passOut", _passed_out)

func _disable() -> void:      # hooks and tick callbacks are removed automatically;
	pass                      # undo only what you changed in the game yourself

func _tick() -> void:
	pass

func _passed_out(call: Hooks.Call) -> void:
	print("she passed out, strength ", get_setting("strength"))
```

| Call | What it does |
|---|---|
| `on_tick(fn)` / `on_late_tick(fn)` | `fn()` every game tick (30 per second), before the game's tick / after the game's logic. Extensions run in load order. |
| `hook_before(name, fn, priority, target)` / `hook_after(...)` | `fn(call)` around a game method, see Hooks below. |
| `setting(key, default, info)` | Declares a setting. Type from the default (bool, int, float, String, Color); `info`: `label`, `desc`, `min`, `max`, `step`, `options`, `group` (a heading on the extension's settings page). |
| `get_setting(key)` / `set_setting(key, value)` | Read / change (saved immediately, then `_setting_changed(key, value)` is called). |
| `data_dir()` | A folder for the extension's own files, next to the save files. |
| `on_event(name, fn)` | `fn(...)` when something happens; events are listed in `Extensions.EVENTS` (`mods_loaded`, `mood_changed`). |
| `mood()` | Her current mood, including extended moods (see Moods). |
| `charcode_field(key, get, set, reset, after_mods)` | A field in the character code, see below. |
| `on_dialogueactions(setup)` | Dialogue triggers and variables, see [Dialogue triggers](#dialogue-triggers). |
| `menu_control(section, group, spec)` | A control in the new in-game menu: `section` is `"her"`, `"clothes"`, `"him"`, `"scene"`, `"behaviour"`, `"effects"`, `"dialogue"`, `"mods"` or `"settings"` (or `"dev_tools"`, `"dev_info"`, `"dev_panel"`: the developer panel, shown only in Developer mode); `group` an existing group of it (e.g. `"Face"`) or a new one. `spec` is a control spec (`MenuWidgets`: `type` toggle / choice / slider / actions / ..., `label`, `tip`, `get` / `set`, optional `visible()` / `enabled()`, `wide`, `after` = the label of the row to follow instead of the group's end); `MenuSchema.choice(...)` and friends build them. Tagged with the extension's name in the menu; removed when the extension is disabled. Settings declared with `setting()` get a page of their own automatically. |
| `menu_button(menu, x, y, text, on_click)` | A small button in a game menu (`"optionsMenu"`, `"sceneMenu"`, ...), styled like the Loader's mod buttons; `set_color(0x00FF00)` shows a state. |
| `menu_slider(menu, x, y, w, h, value, on_change)` | A slider (ExtSlider, value 0..1) in a game menu. |
| `menu_label(menu, x, y, w, text)` | A text label in a game menu. |
| `menu_add(menu, obj, x, y)` | Any display object (an ExtList, ...) in a game menu; removed when the extension is disabled. |
| `on_key(keycode, fn, label, id = "")` | `fn()` when a key is pressed during play (Flash key codes; not while typing). It is a rebindable action in Settings › Hotkeys: `keycode` is the default (`\| Hotkeys.SHIFT / CTRL / ALT` for a combination, 0 for none), `label` names it there, `id` (default: the label) keeps the player's key when the label changes. Keys several actions share are marked there; all of them run. |

Objects drawn as an offscreen group (Flash blend mode "layer", filters; him, for one) can be drawn again elsewhere:
`FlashGroupProxy.of(obj)` is the object's group (or null), `render_texture()` its render (premultiplied alpha,
updated every frame) and `render_rect()` the area of the object's local space it covers. `set_cut(to_a, a, to_b, b)`
leaves out of the on-screen drawing what lies inside rect `a` and outside rect `b` (each in the space `to_a` / `to_b`
maps the object's local space to) while it stays in the render; `clear_cut()` undoes it. The x-ray plugin
(`Mods/Plugins/xray`) uses them to show his whole penis inside her (API version 2).

Settings and on/off choices are stored in `extensions.cfg` next to the save files. Test runs with `--save-dir` use
their own copy.

Tick time is measured per extension: it appears in `--profile` output and in the log's `HITCH` lines as
`ext:<id>.tick`.

## Plugins

A plugin is a folder in `Mods/Plugins/` with a `plugin.cfg` and a main script:

```ini
[plugin]
id="myplugin"                 ; unique; also the name of its settings section
name="My plugin"
author="me"
version="1"                   ; the plugin's own version
api_version=1                 ; the extension API it was written for (see below); missing = 1
main="plugin.gd"              ; extends SDTExtension
depends=["otherplugin"]       ; optional: loaded after these
enabled_by_default=true       ; optional
```

`api_version` is checked against the game's `Extensions.API_VERSION` and `Extensions.MIN_API_VERSION`. A plugin
that needs a newer API than the game has, or that was written for an API the game no longer supports, is not
loaded, and the Extensions list says why. The game raises `API_VERSION` when it adds to the API (hooks, value
points, `SDTExtension` calls): a plugin that uses an addition sets that number, so an older game refuses it instead
of failing during play. It raises `MIN_API_VERSION` when it changes or removes something plugins may rely on.

- Scripts are compiled from the folder at startup. They must not use `class_name`, and they load their other
  scripts with `load_script("other.gd")` and files with `file_path("art.png")` instead of `res://` paths.
- A plugin with errors is skipped; the rest of the game and the other plugins still load.
- If the game crashes or hangs while a plugin loads, that plugin is switched off at the next start.
- Errors during play are contained. The game notes which extension's code it is running (ticks, hooks, value
  points, events, keys, character code fields, settings, its menu widgets; `guarded(fn)` wraps any other callback
  the game's UI calls directly). A plugin whose code raises an error is switched off for the rest of the session,
  and the Extensions list shows the error with its file and line. The player's on/off choice is kept, so the plugin
  is tried again at the next start, or at once when they switch it on again. Its own `push_error()` lines and
  warnings do not count. Debug builds also find plugin code through the script backtrace (its own nodes and signals).
- Release builds report far fewer script errors: there are no null checks, so a call on `null` crashes the game,
  and an index out of range goes by silently. On Windows the native library notes which plugin was running when the
  game crashed (`SDTCrashNote`, file `extensions/crashed_plugin.txt` next to the save), and the next start switches
  that plugin off and says why. Test plugins in a debug build (the editor binary) to see their errors.
- Plugins can do anything a program can, as Loader mods could: only install plugins you trust.

`tests/plugins/example` is a small working plugin.

## Character code fields

The character code ("key:value;key:value...", used by saved characters and the Generate / Load box) can carry
extension fields, in the same form Loader mods used, so codes shared from the Loader keep working:

```gdscript
charcode_field("tongueLength",
	func(): return str(length),                    # value to write (null leaves the field out; no ";")
	func(value: String, load: CharCode.Load): length = float(value),
	func(load: CharCode.Load): length = 1.0)       # default, when a full code lacks the field
```

- The reset (default) runs only for a **full** character code. Costume-only loads, a mod's built-in character
  data and partial codes (35 or fewer ";"-separated parts, the Loader mods' rule) leave the current value alone.
  `load.kind` tells which one it is (`CharCode.Kind.FULL / PARTIAL / COSTUME / MOD_CHARDATA`).
- `after_mods = true` applies the field once the code's .swf mods have loaded (for values that refer to mod items).
- Fields nobody knows, from a disabled extension or a Loader mod the port does not have, are kept with the
  character and written back out, so saving never loses them.

## Dialogue triggers

Triggers (`[NAME_arg1_arg2]` in dialogue lines) and variables (`*name*`, `"set"`, `"check"`) come from the built-in
DialogueActions. Extensions add their own inside `on_dialogueactions`:

```gdscript
func _enable() -> void:
	on_dialogueactions(func(da):
		da.register_trigger("WAVE", 1, func(args): print("wave ", args[0]))   # [WAVE_3]; -1 = any number of args
		da.vars.register("example.power", func(): return 5, func(v): print("set to ", v))
		da.vars.add_listener("myVar", func(old, new): print(old, " -> ", new)))
```

`setup(da)` runs when DialogueActions is on, and again whenever it is switched back on; everything it registered
is removed when the extension is disabled. Arguments are split at `_`, so variable names used as arguments cannot
contain `_`. Something registered later (e.g. from inside a trigger) goes in `da.run_addon(id, func(d): ...)` so
it is removed with the extension too.

## Moods

The vanilla game has four moods (`Her.currentMood`). Extensions that add moods (moremoods adds 22) take over
`Her.setMood` with a before-hook, show the mood themselves, set a vanilla mood underneath and call
`Moods.set_extended(name)`; they declare their moods with `Moods.register(name, id)`.

Everyone else reads `mood()` (or `Moods.current()`): the extended mood while one is active, else the vanilla one.
The `mood_changed` event reports every change with the mood name.

## Arm positions

`Her.armPositions` starts with the game's five (Back, On Legs, On His Legs, Hand Job, Loose); extensions add more
with `Her.addArmPosition(name, left, right, id, spec)`, and `Her.removeArmPositions(id)` takes them out again (an arm
in one goes behind her back). `left` / `right` are `Callable(her)`s that set the arm up when she takes the position
(`her.leftArmIK.newTarget(point, space, true)`, `setEndRotationTarget`, layers, `her.leftHandClosed = true` for a
fist); an empty `Callable()` keeps the position out of that arm's list. `spec`: `"tap"` (false: that hand doesn't tap
him while she's held), `"slip"` (ticks the arm takes to drop when she passes out, default 15), `"pass_out"`
(`Callable(her, left)` run instead of the drop). The menu's Left arm / Right arm lists, the "arms:" character code
field and dialogue triggers use the names. `Her.armPositionsFor(left)`, `Her.armPositionAllowed(i, left)` and
`Her.stepArmPosition(from, dir, left)` list and step through the positions one arm can take. The armoverhaul plugin
(`Mods/Plugins/armoverhaul`) adds 18.

## Hooks

GDScript cannot replace a method at runtime (the Loader's `lProxy` did this for Loader mods), so each game method
that an extension needs gets a hook point: two guarded blocks named after the original `Class.method`, marked
`# HOOK`. `grep -rn "# HOOK" game/src` lists them all. Hook points are added when an extension needs them.

`game/src/ext/hook_points.gd` lists every hook point and value point name; it is generated from the game's code by
`sh tools/gen_hook_points.sh` (rerun it after adding or removing a point; `tools/check_all.sh` reports when it is out
of date, and value points missing from the table below). `hook_before`, `hook_after` and `modify` warn once when a
name is not in that list, a typo or a point that no longer exists: the handler would never run. A plugin that runs
hook points or value points of its own declares their names first with `declare_hook_point(name)` /
`declare_value_point(name)`, so other plugins can use them without a warning.

```gdscript
func lookAt(target: Vector2) -> void:
	if Hooks.has(&"Her.lookAt"):                       # HOOK
		var h := Hooks.before(&"Her.lookAt", self, [target])
		if h.cancelled:
			return
		target = h.args[0]
	...original code, unchanged...
	if Hooks.has(&"Her.lookAt"):                       # HOOK
		Hooks.after(&"Her.lookAt", self, [target])
```

Handlers get a `Hooks.Call` with `name`, `obj` (the object whose method runs), `args`, `result` and `cancel(value)`
(and, once cancelled, `cancelled_by`: the owner of the handler that cancelled it, e.g. for logs):

- **Before-handlers** run in `priority` order (lower first, then registration order). They may change `call.args`,
  or call `call.cancel(value)`: the original method is skipped and returns `value`, and the remaining handlers
  (before and after) are skipped too.
- **After-handlers** see the method's return value in `call.result` and may replace it.
- While a hook's handlers run, the hook is inactive, so a handler can call the hooked method itself to run the
  original code.
- A handler registered with a `target` runs only for that object. A hook name covers every instance of the class.
- An unused hook point costs one dictionary lookup, so hooks are fine even in methods that run every tick.

## Value points

Hooks let an extension replace a method, so two extensions that both change, say, where she looks end up fighting:
the one that cancels the method wins and the other's code never runs. For her continuous behaviour (gaze, eyelids,
mouth...) the game code has **value points** instead: the place where it decides a *target* (where she wants to
look), before its own easing moves her towards it. Extensions add **modifiers** to the target; they all apply, in a
fixed order, and the easing keeps the motion smooth when one starts or ends.

```gdscript
# game code (one guarded line, marked # HOOK like hook points)
if Hooks.has_value(&"Her.lookTarget"):   # HOOK
	point = Hooks.value(&"Her.lookTarget", self, point)

# an extension
modify(&"Her.lookTarget", {"phase": Hooks.OVERRIDE, "op": "set", "value": g.her.eyesDown, "ms": 2000})
```

Modifiers apply phase by phase, each phase working on the result of the one before:

| Phase | For |
|---|---|
| `GENERATE` | replacing how the value is made (`op: "fn"`), e.g. a mood's own way of looking around |
| `MOOD` | ambient states: moods, settings |
| `OVERRIDE` | timed commands: dialogue triggers (manual control: a high `order`) |
| `CLAMP` | limits |
| `FINAL` | states that win over everything, e.g. passed out |

Within a phase: `fn` modifiers run in order, then the last `set` or `hold` replaces the value, then every `bias` is
added, then the clamps apply together (their ranges intersect). So the result never depends on the order inside a
phase, and the order between extensions is (phase, `order`, extension id, add order): never their load order.

A modifier is a Dictionary:

- `op`: `"set"` (`value`), `"bias"` (`value`, added), `"clamp"` (`min` / `max`, numbers only), `"hold"` (keeps the
  value it saw when it started applying), `"fn"` (`fn: Callable(value, obj) -> value`, for anything else)
- `phase` (default `MOOD`), `order` (default 0, a later one wins among `set`s)
- `when: Callable(obj) -> bool`: applies only while true (a `hold` captures again each time it starts applying)
- `ms`: lifetime in milliseconds of game time (counted down by each tick's length, so a paused game doesn't use it
  up and it lasts as long at any tick rate; default: until removed)

`modify()` returns an id for `Hooks.remove_modifier(id)` (`Hooks.has_modifier(id)`: still there, e.g. a timed one);
`unmodify(name)` removes the extension's own modifiers from one point (`unmodify()`: from all), e.g. when the setting
that added them is switched off; an extension's modifiers go by themselves when it is switched off. Values are numbers
or `Vector2` points (`Neck.band`: a Dictionary or `null`, changed with `op: "fn"`). Two extensions `set`ting different values in the same phase at the same time log a warning once.

The value points in the game, with the field that keeps the result for code that reads it:

| Point | Value | Result in |
|---|---|---|
| `Her.lookTarget` | the point she looks at (scene coordinates) | `her.lookPoint` |
| `Her.gazeAngle` | the angle her iris turns towards, before easing | `her.eyeMotion["target"]` |
| `Her.eyelidShock` | how shocked her eyes are (wider, smaller iris; the game's `shock()` sets 10-85, counting down) | `her.eyelidShock` |
| `Her.eyelidTarget` | the frame her eyelids ease towards while her eyes are open (not blinking, wincing, closed or passed out), after her movement, shock, cum and passing out terms; 2 open, 150 closed | `her.eyelidMotion["target"]` |
| `Her.irisScale` | how big her irises are (the game: 0.9 less a share of her eyelid frame and shock), every tick | `her.eye.ball.irisContainer.iris.scaleX` / `scaleY` |
| `Her.eyebrowFrame` | her eyebrows' frame (her eyelid frame, plus a waggle's offsets), every tick | `her.rightEyebrow` frames |
| `Her.angryEyebrows` | whether her eyebrows take the angry shape (the angry mood), every tick | the eyebrow tweens |
| `Her.upperEyelid` | the upper eyelid's frame (2 open, 150 closed, up to 200 squeezed shut) | `her.upperLid` |
| `Her.lowerEyelid` | the lower eyelid's frame (asked after the upper) | `her.lowerLid` |
| `Her.jawAngle` | her jaw's angle this tick, after the game's easing (`Her.closedJawAngle` -12: closed, higher: open); lips, cheeks and `g.herMouthOpeness` follow it | `her.head.jaw.rotation_degrees` |
| `Her.swallowSpeed` | how fast a swallow plays (1; the four phases' lengths are divided by it, at least a tick apart), asked when it starts | `her.swallowSequence` |
| `Her.swallowWince` | whether she squints around the swallow (true) | |
| `Her.swallowAmount` | how much one swallow takes from her mouth (5-9 at random; never more than there is) | `her.cumInMouth` |
| `Her.targetPhoneme` | the mouth shape a spoken word aims for (its phoneme: `{name, upperLip, lowerLip, jaw}`; return a new one); the word's "L" tongue flick plays only with the word's own shape | `her.targetPhoneme` |
| `Her.speakingMouth` | her mouth's target as she starts or stops speaking (the same Dictionary; `her.speaking` is still the old state) | `her.targetPhoneme` |
| `Her.clenchTime` | how long she keeps her teeth clenched, ticks (the game: 60..179 at random) | `her.clenchedTeethTime` |
| `Her.clenchTaps` | whether she taps him as she clenches her teeth (true) | |
| `Her.teethClosing` | whether her clenched teeth close further this tick (true; false holds them where they are) | `her.clenchTeethRatio` |
| `Her.shockFade` | how much her eyes' shock (`her.eyelidMotion["shock"]`, set by `Her.shock`) eases this tick (1), while it is above 0 | `her.eyelidMotion["shock"]` |
| `HerPenisControl.throughClothes` | whether her penis sticks out through her clothes (false: under them it lies against her body); after changing its modifiers call `g.her._penisControl.clothingChanged()` | `her._penisControl.wearingNone` |
| `HerPenisControl.restAngle` | the angle her penis swings back to while it moves freely (0; positive: down) | `her._penisControl.penisContainer.rotation_degrees` |
| `HerPenisControl.minAngle` | the furthest her penis rises while it moves freely (-24) | |
| `Her.breathMax` | how much breath she has (50), once per tick; a change keeps how much of it is used. After changing its modifiers, `g.resolveBreath()` applies them at once | `g.breathLevelMax` |
| `Her.outOfBreathPoint` | past this she is out of breath (half of `Her.breathMax`), right after it | `g.outOfBreathPoint` |
| `Her.passOutMax` | how long she lasts with no air before passing out (40), right after it; a change keeps how close she is | `her.passOutMax` |
| `Her.mouthOpenness` | how open her mouth counts as (0..1, from her jaw) for her breath's volume, the breath mist and drool, every tick | `g.herMouthOpeness` |
| `Her.blushEffects` | with Dynamic blushing on: the sum of what makes her blush this tick, before her blush factor and the cap (the spankanywhere plugin adds its spank blush here) | `her.blush.alpha` |
| `Her.blushAlpha` | how much her blush shows, every tick while it has modifiers (her blush colour's alpha; Dynamic blushing sets its own in the `GENERATE` phase) | `her.blush.alpha` |
| `Her.highlightsAlpha` | how much the highlights in her eyes show, every tick while it has modifiers (the art's own alpha) | `her.eye.ball.highlights.alpha` |
| `Her.mouthShape` | the shape her mouth shows: a face frame (`"Normal"`, `"Angry"`, `"Ahegao"`, ...; her mood's, set with `her.setMouthShape()`, which extended moods use too), every tick while it has modifiers; angry lips only while it shows `"Angry"` | `her.mouthShape` |
| `Her.lowerEyelidSquint` | how far her (moremoods) mood's squint tilts the mascara under her eyes (the mood's level, 10-25) | |
| `Tears.lowerMascaraTop` | the first row of the mascara band drawn under her eyes as she winces (0; higher: a thinner band) | |
| `Her.biteRarity` | how rarely she bites (moremoods' "How rarely she bites"; higher: rarer) | |
| `CharacterControl.skinSaturation` | how much of her skin's colour saturation shows (1), when her skin filter is made: after changing its modifiers call `g.characterControl.updateSkinHSL()` | her skin filters |
| `Her.wakeShock` | how shocked her eyes are as she wakes (85, then counting down) | `her.eyelidMotion["shock"]` |
| `Her.wakeGaze` | the angle her eyes start from as she wakes (20; higher: rolled from further below) | `her.eyeMotion["ang"]` |
| `Her.blinks` | whether a due blink happens (true; false: the next try after a normal wait); not asked for a quick second blink | |
| `Her.quickBlink` | the chance that a quick second blink follows this one (0.2) | `her.blinkTime` |
| `Her.winceTime` | how long her eyes squint in a wince, ticks (5; 0: no squint, the wince's tears still come) | `her.winceTimer` |
| `Her.coughDue` | whether a cough that is due while he holds her happens (true; false: she waits as long as after a cough) | `her.nextCoughTime` |
| `Her.coughForce` / `Her.openCoughForce` | how hard a cough / an open-mouthed cough is as it starts (0.5..2 / 0.25..1.25 at random; it eases off by itself) | `her.coughFactor` |
| `BreastController.kick` | how much a push (a cough, a spank, a dialogue trigger) speeds a breast up | |
| `BreastController.firmness` | how firmly a breast springs back (0.2 + (60 - her breast size) x 0.01, at least 0.2; 0.1 more with a top on), when her breast size or top changes | `BreastController._breastFirmness` |
| `BreastController.push` | the force her movement gives a breast this tick | |
| `BreastController.damping` | how much of its speed a breast keeps this tick (0.7; up to 0.1 more at random) | |
| `SoundControl.herSoundVolume` | the volume of her cough, open cough, gag or pass-out sound as it starts; `soundControl.herSound` says which (`&"cough"`, `&"openCough"`, `&"gag"`, `&"passOut"`) | |
| `IKController.tapPower` | how hard a tap of her hand is (its multiplier x `maxTapPower`; the grab sound's volume stays the multiplier) | `ik.tapPower` |
| `IKController.tapSpeed` | how fast that tap starts (-6 x its power) | `ik.tapSpeed` |
| `Him.penisTiltTarget` | the angle his penis eases towards (bukkake mode's mouse aim and her push already in), before easing | `him.penisTiltTarget` |
| `Him.penisAngle` | his penis's angle this tick, after easing and the game's -10..25 limits (`him.penisTilt`: the eased angle before them) | `him.penis.rotation_degrees` |
| `Him.penisMask` | the mask that hides his penis inside her mouth, every tick: `{x, scale}` (the game's x: -100 + his depth x 200 in her mouth, -100 hides it all; scale 1) | `him.penisMask` |
| `Him.mouthSmoothing` | how much her mouth holds his penis's tilt while he is in it (0..1, the game's rises by 0.4 a tick) | `him.mouthConstraintSmoothing` |
| `Him.ballScale` | his balls' scale (his ball size), when it is set: after changing its modifiers call `g.him.updateBalls()` | `him.balls.scaleX` / `scaleY` |
| `Him.ballsOffset` | how far his balls sit from their place in the art (`him.ballsHome`; `Vector2.ZERO`), when his ball size is set: `g.him.updateBalls()` as above | `him.balls.x` / `y` |
| `Her.pullOff` | how hard she pulls back off him and its power, every tick after the game's update: `{pull, power}` (`her.pullOff`, `her.pullOffPower["current"]`; return a new one) | `her.pullOff` |
| `Her.pullOffPower` | how hard she pulls back off him while he holds her deep: `{start, increase, max}` (0.001, 0.00005, 0.008; return a changed copy), every tick held and when he lets go | `her.pullOffPower["current"]` |
| `Her.passOutGain` | how much closer to passing out she gets per tick with no air left (0.05) | `her.passOutFactor` |
| `Her.passOutRecovery` | how much of that she gets back per tick while she breathes (0.5); 0 keeps her out | `her.passOutFactor` |
| `Her.resistance` | what holds him back as he pushes in, per tick (`checkPosition`'s throat resistance zones) | (subtracted from her speed) |
| `Her.limpResistance` | the same while she is passed out (0: the game holds nothing then) | (subtracted from her speed) |
| `Her.pushBack` | how far her head is pushed back off him this tick (0), before the `minPos`/`maxPos` clamp | `her.pos` |
| `Her.drag` | how much her head is slowed this tick (0; subtracted from her speed before friction, positive: away from him), e.g. her arms resisting | `her.speed` |
| `Her.passOutExtra` | how much closer to passing out she gets this tick on top of the game's own (0), with or without air, while she is awake | `her.passOutFactor` |
| `Scene.backgroundBrightness` | how bright the background is (1; its colour multipliers), every tick while it has modifiers | `g.bg.colorTransform` |
| `Neck.depth` | how deep the throat bulge sits (his depth / 400) | `neck.lastDepth` |
| `Neck.throatBulge` | how much her throat bulges (her throat bulge setting) | |
| `Neck.swallowScale` | how a swallow pushes her neck out, while she swallows (`Vector2(0.8, 0.5)`: out, down) | |
| `Neck.bulgeCap` | the most the bulge pushes the neck out, px (35); throatcumbulge's "Neck follows his size" scales it with his width | |
| `Neck.band` | a band that holds the front of her neck in, asked once per render: `null`, or `{top, bottom, inside, soft}` (edges as depth along the front, px her neck may push out between them, depth over which that blends into the free bulge past each edge); a second holder returns `Neck.narrower(value, its own)` | `neck.renderedPoints` |

`Hooks.explain(name)` returns the last evaluation step by step (recording starts with the first call),
`Hooks.value_points()` lists the points with modifiers. A value point without modifiers costs one dictionary lookup.

Rule: for behaviour that has value points, change the targets through modifiers; do not cancel the method. One-off
actions (a blink, a cough) keep their before-hooks, which may cancel (veto) them. Code that writes a target field
directly (an older plugin) still works, as part of the game's base value: modifiers apply on top of it.

## Painting onto her skin

A plugin can lay a texture over her skin that every shape under a display object composites onto its own pixels
with hardlight, clipped to each shape and moving with it, under her clothes (spankanywhere's marks):
`obj.paint = texture` (null: none) and `obj.paint_transform` (stage coordinates -> the texture's UV; update it each
tick if the texture follows the screen). The nearest object's paint applies, only to shapes drawn with normal blend
and no colour matrix filter. Draw the texture into a `SubViewport` and pass it to `Flash.draw_early(vp)` so masked
and grouped parts show this tick's paint, not last tick's.

## Testing

`tools/regress.sh` runs the game scenarios in Vanilla mode (their reference dumps must not change because of an
extension), plus `game/debug/ext_checks.gd`, which tests the hook system, the extension lifecycle, tick order and
settings.

`tools/check_plugin_writes.sh` (also run by `tools/check_all.sh`, on `Mods/Plugins` and the built-in extensions in
`game/src/ext`) lists the lines that write the game's state directly (`her.x = ...`, `g.her.x *= ...`). Change it through a value point (add one to the game code if it
is missing) or the game's own methods; a write that is meant, such as an event's one-off push, gets the comment
`# direct: <why>` on its line.
