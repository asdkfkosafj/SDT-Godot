extends SDTExtension
## Built-in reimplementation of animtools' body positions (animtools V40): positions are animtools .txt files in
## Mods/Positions (the set the game comes with in Mods/Positions/animtools), read as they are and brought to the V40
## format (Position), and applied as an animation of their own next to the game's two (AnimationControl
## .addAnimation), so the game's own "default" and "face fuck" stay untouched. Written from the mod's files,
## documentation and behaviour.
##
## Stage 1 (this): reading, the version rules, writing; applying her and his paths, his feet, her knee anchor (its
## start point), her torso numbers and the mouse's sideways range; back to the game's default. Camera, arms, props,
## layers, flips and body contact come in later stages (notes: the plan). Until the position browser exists, the
## developer panel (Tools > Positions) loads a position by name.
##
## A position is a temporary state: it does not change the player's saved settings; switching the extension off (or
## Vanilla mode) gives the game's default animation back.

const Position := preload("res://src/ext/positions/position.gd")
const Library := preload("res://src/ext/positions/position_library.gd")
const Fields := preload("res://src/ext/positions/position_fields.gd")

const ANIM := "position"   # the AnimationControl key of the applied position

var library = Library.new()
var current = null         # the applied Position (null: the game's default)


func _init() -> void:
	id = "positions"
	title = "Positions"
	description = "animtools' body positions: positions from .txt files in Mods/Positions (stage 1: developer panel only)."
	default_enabled = false


func _enable() -> void:
	rescan()
	menu_control("dev_tools", "Positions", MenuSchema.choice("Position", "Load a body position (animtools .txt)",
		func(): return ["(game default)"] + Array(library.names),
		func(): return "(game default)" if current == null else current.name,
		func(v): clear() if v == "(game default)" else load_position(v)))


func _disable() -> void:
	clear()


func positions_root() -> String:
	return Flash.mods_dir("Positions")


func rescan() -> void:
	library.scan(positions_root())


## Reads a position by name (see PositionLibrary.find); a partial one applies to the current position. null when not
## found or not readable.
func read_position(given: String):
	var n: String = library.find(given)
	if n == "":
		return null
	var text := FileAccess.get_file_as_string(library.path_of(n))
	if text == "" and FileAccess.get_open_error() != OK:
		return null
	var p = Position.from_text(text, n, current)
	p.path = library.path_of(n)
	return p


## Loads and applies a position by name; false when there is none by that name.
func load_position(given: String) -> bool:
	var p = read_position(given)
	if p == null:
		push_warning("Positions: no position \"%s\"" % given)
		return false
	apply(p)
	return true


func apply(p) -> void:
	current = p
	var ac: AnimationControl = g.animationControl
	ac.addAnimation(ANIM, build_animation(p))
	ac.setAnimation(ANIM)


## Back to the game's default animation.
func clear() -> void:
	current = null
	if g.animationControl != null:
		g.animationControl.removeAnimation(ANIM)


## The position's paths and numbers as a MainAnimation (her and his tweens, his feet, her knee, her torso).
static func build_animation(p) -> MainAnimation:
	var v: Dictionary = p.values
	var a := MainAnimation.new()
	a.herTween = _tween(v["hertweenstartx"], v["hertweenstarty"], v["hertweenstartang"],
		v["hertweenendx"], v["hertweenendy"], v["hertweenendangle"])
	a.hisTween = _tween(v["histweenstartx"], v["histweenstarty"], v["histweenstartang"],
		v["histweenendx"], v["histweenendy"], v["histweenendangle"])
	a.herKneeTarget = Vector2(v["torsox"], v["torsoy"])
	a.altVector = Vector2(0, 1)
	a.altRange = v["offpathposmovement"]
	a.hisLeftFootTarget = Vector2(v["leftfootx"], v["leftfooty"])
	a.hisRightFootTarget = Vector2(v["rightfootx"], v["rightfooty"])
	a.torsoMinAng = v["torsominang"]
	a.torsoStartAng = v["torsostartangle"]
	a.torsoAngMultiplier = v["torsoanglemodifier"]
	a.torsoMinDist = v["torsomindistance"]
	a.torsoStartDist = v["torsostartdistance"]
	a.torsoDistMultiplier = v["torsodistancemultiplier"]
	a.torsoS2OffsetAng = v["torsoikoffsetang"]
	a.torsoEndRotation = v["torsoendrotationangle"]
	return a


## A tween from start / end points and angles (radians). animtools never turns on his skew at runtime (the skew keys
## are only read and written), so the tweens rotate.
static func _tween(sx: float, sy: float, sa: float, ex: float, ey: float, ea: float) -> LinearTween:
	var t := LinearTween.new()
	t.start = Transform2D(0.0, Vector2(sx, sy))
	t.end = Transform2D(0.0, Vector2(ex, ey))
	t.rotateStart(sa)
	t.rotateEnd(ea)
	return t
