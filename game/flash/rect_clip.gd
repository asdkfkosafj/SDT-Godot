class_name FlashRectClip
extends Control
## Mask wrapper for masks that are a single opaque, axis-aligned rectangle (the game's ScreenMask on every scene
## layer). Clips with a scissor rect (Control.clip_contents) instead of Godot's clip_children, which is cheaper and,
## unlike clip_children, can contain further masks.

## The game layers glide between ticks. A Control is not interpolated by default and its children inherit that, so
## this has to be asked for here. --no-smooth: off (A/B comparisons).
static var smooth := not OS.get_cmdline_user_args().has("--no-smooth")

var _proxy: CanvasItem = null
var _container = null
var _mask_obj: FlashDisplayObject = null
var _wrapped: FlashDisplayObject = null
var _local_rect := Rect2()      # opaque rect in the mask object's local space
var _holder := Node2D.new()
var _size_from := Vector2.ZERO  # the clip's size at the tick before and at this one: it glides between them with its
var _size_to := Vector2.ZERO    # position (_process); else a rect that grows or shrinks while it moves (his penis mask
var _sized := false             # when the x-ray gives it back) is drawn at the old place with the new size for a tick


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if smooth:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_holder.name = "content"
	add_child(_holder)


func content_parent() -> Node:
	return _holder


## Follows the mask object (called by the runtime every tick).
func refresh() -> void:
	if _mask_obj == null or not is_instance_valid(_mask_obj):
		return
	var cont: FlashDisplayObject = _container if _container != null else (_wrapped._flash_parent if _wrapped else null)
	var base := Transform2D.IDENTITY
	if cont != null:
		base = cont.flash_global_transform()
	var m := base.affine_inverse() * _mask_obj.flash_global_transform()
	var r := m * _local_rect
	position = r.position
	_holder.position = -r.position
	_size_from = _size_to if _sized and smooth else r.size
	_size_to = r.size
	_sized = true
	size = _size_to
	set_process(_size_from != _size_to)


func _process(_delta: float) -> void:
	if is_physics_interpolated_and_enabled():
		size = _size_from.lerp(_size_to, Engine.get_physics_interpolation_fraction())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESET_PHYSICS_INTERPOLATION:   # placed anew, not gliding there: nor does its size
		_size_from = _size_to
		size = _size_to
		set_process(false)


## Rect of an opaque, unrotated rectangle mask in its own space, or an empty Rect2 if the mask is anything else.
static func rect_of(mask: FlashDisplayObject) -> Rect2:
	var shape: FlashShape = null
	var offset := Transform2D.IDENTITY
	if mask is FlashShape:
		shape = mask
	elif mask is FlashSprite and mask._children.size() == 1 and mask._children[0] is FlashShape \
			and mask._graphics == null:
		shape = mask._children[0]
		offset = shape.transform
	if shape == null or (shape._texture == null and shape._await == "") or offset.x.y != 0.0 or offset.y.x != 0.0:
		return Rect2()
	if not _is_opaque_rect(shape):
		return Rect2()
	var e: Dictionary = shape._entry
	return offset * Rect2(e["x"], e["y"], e["w"], e["h"])


static var _opaque_cache: Dictionary = {}


static func _is_opaque_rect(s: FlashShape) -> bool:
	var key := "%s/%d" % [s._library.path, s._char_id]
	if _opaque_cache.has(key):
		return _opaque_cache[key]
	# The shape's 1-bit hit mask must cover a grid of points spanning its bounds (inset by a pixel).
	var e: Dictionary = s._entry
	var ok: bool = e.has("hm") and e["w"] > 2 and e["h"] > 2
	if ok:
		for iy in 9:
			for ix in 9:
				var p := Vector2(e["x"] + 1 + (e["w"] - 2) * ix / 8.0, e["y"] + 1 + (e["h"] - 2) * iy / 8.0)
				if not s._library.hit_mask_test(e, p):
					ok = false
	_opaque_cache[key] = ok
	return ok
