class_name RenderScale
extends Node
## Port addition: Settings > Graphics > Render scale. Below 100 % the game (the Flash stage with the blurred sides:
## Presentation) is drawn into a smaller render target, which the window shows stretched to its size; the menu, the
## panels and the FPS counter stay in the window at full size (sharp). For weak graphics cards, where the render
## time follows the number of pixels drawn: 75 % draws 56 % of them, 50 % a quarter.
##
## The stage stays where it is in the tree, under its own CanvasLayer (layer): at 100 % that layer is drawn in the
## window as before (its custom_viewport unset, or the window after a switch back); below, its custom_viewport is the
## smaller target (_view). Only the drawing moves, so the
## stage's coordinates, the mouse and the window's picture (screenshots: capture_screen reads the window) stay as
## they are. What sizes render targets by the screen pixels a canvas item covers asks final_transform / view_size
## here instead of its viewport: the targets (masks, groups) shrink with the scale too.

static var instance: RenderScale = null

## The stage's CanvasLayer (always there; layer -1: under anything else drawn in the window's own canvas).
var layer := CanvasLayer.new()
var factor := 1.0                  # the render scale in use (1: off)
var _view: SubViewport = null      # the smaller target while below 100 %
var _display: TextureRect = null   # shows it, stretched to the window
var _applied := false              # apply ran once (later changes are logged)


func _init() -> void:
	name = "RenderScale"
	instance = self
	layer.name = "StageLayer"
	layer.layer = -1


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)


## At quit the layer goes back to the window first: Godot disconnects the layer from the viewport it has when it
## leaves the tree, but connected it to the one it had when it came in (the window).
func _exit_tree() -> void:
	layer.custom_viewport = get_viewport()


## Draws the stage at `f` of the window's resolution (1: in the window itself).
func apply(f: float) -> void:
	f = clampf(f, 0.25, 1.0)
	if _applied and not is_equal_approx(f, factor):   # (the scale at start is in the SYSTEM line)
		print("RENDER SCALE %d %% from now on (was %d %%)" % [roundi(f * 100.0), roundi(factor * 100.0)])
	_applied = true
	if is_equal_approx(f, 1.0):
		factor = 1.0
		if _view != null:
			layer.custom_viewport = get_viewport()   # the window again (Godot takes no null here)
			_display.queue_free()
			_view.queue_free()
			_display = null
			_view = null
		return
	factor = f
	if _view == null:
		var root := get_viewport()
		_view = SubViewport.new()
		_view.name = "StageView"
		_view.disable_3d = true
		_view.transparent_bg = false
		_view.msaa_2d = root.msaa_2d
		_view.use_hdr_2d = root.use_hdr_2d
		_view.canvas_item_default_texture_filter = root.canvas_item_default_texture_filter
		_view.canvas_item_default_texture_repeat = root.canvas_item_default_texture_repeat
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_view)
		_display = TextureRect.new()
		_display.name = "StageDisplay"
		_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_display.stretch_mode = TextureRect.STRETCH_SCALE
		_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_display.texture = _view.get_texture()
		add_child(_display)
		layer.custom_viewport = _view
	_fit()


## The target at the window's size times the factor, with the window's canvas stretch scaled down to it; the display
## over the whole window (its visible rect, in the window's canvas units).
func _fit() -> void:
	if _view == null:
		return
	var root := get_viewport()
	var win := Vector2(root.size)
	var px := Vector2i(maxi(2, roundi(win.x * factor)), maxi(2, roundi(win.y * factor)))
	if _view.size != px:
		_view.size = px
	var k := Vector2(px) / win.max(Vector2.ONE)
	_view.global_canvas_transform = Transform2D().scaled(k) * root.get_final_transform()
	var vis := root.get_visible_rect()
	_display.position = vis.position
	_display.size = vis.size


## MSAA follows the setting (PortSettings.apply_msaa).
func set_msaa(m: Viewport.MSAA) -> void:
	if _view != null:
		_view.msaa_2d = m


## Canvas -> the pixels canvas item ci is drawn in: its viewport's final transform, or for the stage below 100 % the
## smaller target's.
static func final_transform(ci: CanvasItem) -> Transform2D:
	var vp := ci.get_viewport()
	if instance != null and instance._view != null and vp == instance.get_viewport() and instance.layer.is_ancestor_of(ci):
		return instance._view.get_final_transform()
	return vp.get_final_transform() if vp != null else Transform2D.IDENTITY


## The size in pixels of what ci is drawn in (as final_transform).
static func view_size(ci: CanvasItem) -> Vector2:
	var vp := ci.get_viewport()
	if instance != null and instance._view != null and vp == instance.get_viewport() and instance.layer.is_ancestor_of(ci):
		return Vector2(instance._view.size)
	return Vector2(vp.size) if vp != null else Vector2.ZERO


## The render scale for ci (1 outside the stage or at 100 %).
static func factor_for(ci: CanvasItem) -> float:
	if instance != null and instance._view != null and instance.layer.is_ancestor_of(ci):
		return instance.factor
	return 1.0
