extends RefCounted
## animtools' props (furniture: beds, chairs, tables, a staircase...): its 14 pictures (assets/mods/animtools, the
## mod's art), in one layer just above the background that follows the camera like the game's other layers outside
## the scene (SceneLayer.giveExternalLayer), so a prop sits in scene space with her and him. A position turns each
## prop on and places it (x, y, scale x / y, rotation in degrees). The art loads when the extension starts, so a
## position change does not wait for it.

const Fields := preload("res://src/ext/positions/position_fields.gd")
const ART := "res://assets/mods/animtools"

var holder: FlashSprite = null
var props: Dictionary = {}   # prop name -> its picture
var _mask: FlashDisplayObject = null


func start() -> void:
	if holder != null or g.bg == null or g.sceneLayer == null:
		return
	var art := FlashSwfMod.load_art(ART)
	if art == null:
		return
	holder = FlashSprite.new()
	holder.flash_name = "positionProps"
	holder.mouseEnabled = false
	holder.mouseChildren = false
	for p in Fields.PROPS:   # animtools puts each one at the bottom: the first in the list is drawn on top
		var o := art.create("animtoolsV40_fla.MainTimeline_%sc" % p[0])
		if o == null:
			push_warning("Positions: no picture for the prop %s" % p[0])
			continue
		o.visible = false
		holder.addChildAt(o, 0)
		props[p[0]] = o
	var bgp: FlashSprite = g.bg.parent
	bgp.addChildAt(holder, bgp.getChildIndex(g.bg) + 1)
	g.sceneLayer.giveExternalLayer(holder)
	_mask = Flash.create("ScreenMask")   # only on the game's screen, like the scene's own layers
	bgp.addChildAt(_mask, bgp.getChildIndex(holder) + 1)
	holder.mask = _mask


func stop() -> void:
	if holder == null:
		return
	g.sceneLayer.externalLayers.erase(holder)
	holder.mask = null
	if holder.parent != null:
		holder.parent.removeChild(holder)
	if _mask != null and _mask.parent != null:
		_mask.parent.removeChild(_mask)
	_mask = null
	holder = null
	props.clear()


## Shows the props a position has on, where it puts them; null hides them all.
func show(values) -> void:
	for n in props:
		var o: FlashDisplayObject = props[n]
		if values == null or values[n + "active"] != 1:
			o.visible = false
			continue
		o.x = values[n + "x"]
		o.y = values[n + "y"]
		o.scaleX = values[n + "scalex"]
		o.scaleY = values[n + "scaley"]
		o.rotation_degrees = values[n + "rotation"]
		o.visible = true


## The props showing now (names), for checks.
func shown() -> Array:
	return props.keys().filter(func(n): return props[n].visible)
