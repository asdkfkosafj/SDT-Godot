extends CanvasLayer
## The position editor's handles on the scene: a dot for each point of the editor's open cards (her and his path
## ends, his feet, her knee, her and his arm points, his shoulder, the zoom point, the chosen prop) and a short arm
## for an angle. Hold Ctrl and drag a dot (or the end of its arm) to move it; without Ctrl the mouse plays the game
## as usual. The camera dot sits at the screen's centre: dragging it drags the whole scene (camerax / cameray).
## Drawn over the game and under the menu; built only while the editor is open.
##
## A handle: {label, x, y (value keys), angle (key or ""), angle_deg (the key is in degrees), space ("scene": the
## scene layer's coordinates, "him" / "him_shoulder": his, "pan": the camera), offset (optional Callable: a shift in
## that space, his shoulder's height on the stroke), color}.

const R := 6.0          # dot radius (window pixels)
const ARM := 34.0       # angle arm length
const GRAB := 11.0      # how close the mouse must be to grab

var editor            # PositionEditor
var handles: Array = []
var _view: Control
var _drag := {}       # the handle being dragged, "part": "dot" / "arm"
var _hover := {}
var dragging := false


func _ready() -> void:
	layer = 45
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	add_child(_view)


func _process(_d: float) -> void:
	_view.queue_redraw()


## Scene-layer (his; "pan": the scene layer's parent, the game's screen) coordinates -> this layer's canvas.
func _xf(space: String) -> Transform2D:
	var node: Node2D = g.him if space.begins_with("him") else g.sceneLayer
	if space == "pan" and node != null:
		node = node.get_parent() as Node2D
	if node == null or not node.is_inside_tree():
		return Transform2D.IDENTITY
	var vp := get_viewport()
	return vp.get_final_transform().affine_inverse() * RenderScale.final_transform(node) * node.get_global_transform_with_canvas()


func _pos(h: Dictionary) -> Vector2:
	if h["space"] == "pan":
		return _xf("pan") * (g.screenSize / 2.0)
	var v: Dictionary = editor.values
	var off: Vector2 = h["offset"].call() if h.has("offset") else Vector2.ZERO
	return _xf(h["space"]) * (Vector2(v[h["x"]], v[h["y"]]) + off)


func _has_arm(h: Dictionary) -> bool:
	return h["angle"] != "" and editor.values[h["angle"]] != -5000


func _arm_end(h: Dictionary, p: Vector2) -> Vector2:
	var a: float = editor.values[h["angle"]]
	if h.get("angle_deg", false):
		a = deg_to_rad(a)
	var xf := _xf(h["space"])
	var dir := (xf.basis_xform(Vector2.from_angle(a))).normalized()
	return p + dir * ARM


func _unset(h: Dictionary) -> bool:
	return h["space"] != "pan" and (editor.values[h["x"]] == -5000 or editor.values[h["y"]] == -5000)


func _draw_view() -> void:
	var font := MenuTheme.font()
	for h in handles:
		if _unset(h):
			continue
		var p := _pos(h)
		var c: Color = h["color"]
		var hot: bool = (_hover.get("h") == h) or (_drag.get("h") == h)
		if _has_arm(h):
			var e := _arm_end(h, p)
			_view.draw_line(p, e, c, 2.0, true)
			_view.draw_circle(e, 3.5, c)
		_view.draw_circle(p, R + (2.0 if hot else 0.0), Color(0, 0, 0, 0.55))
		_view.draw_circle(p, R - 1.0 + (2.0 if hot else 0.0), c)
		_view.draw_string_outline(font, p + Vector2(R + 3, 4), h["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
		_view.draw_string(font, p + Vector2(R + 3, 4), h["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)


func _hit(at: Vector2) -> Dictionary:
	var best := {}
	var bd := GRAB
	for h in handles:
		if _unset(h):
			continue
		var p := _pos(h)
		if _has_arm(h):
			var d := at.distance_to(_arm_end(h, p))
			if d < bd:
				bd = d
				best = {"h": h, "part": "arm"}
		var d2 := at.distance_to(p)
		if d2 < bd:
			bd = d2
			best = {"h": h, "part": "dot"}
	return best


func _input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		return
	var at: Vector2 = _view.get_global_transform_with_canvas().affine_inverse() * (event as InputEventMouse).position
	if event is InputEventMouseMotion:
		if dragging:
			_move_to(at)
			get_viewport().set_input_as_handled()
		else:
			_hover = _hit(at) if Input.is_key_pressed(KEY_CTRL) else {}
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and (event.ctrl_pressed or Input.is_key_pressed(KEY_CTRL)):
			var hit := _hit(at)
			if not hit.is_empty():
				_drag = hit
				_drag["last"] = at
				dragging = true
				get_viewport().set_input_as_handled()
		elif not event.pressed and dragging:
			dragging = false
			_drag = {}
			editor.commit()
			get_viewport().set_input_as_handled()


func _move_to(at: Vector2) -> void:
	var h: Dictionary = _drag["h"]
	var inv := _xf(h["space"]).affine_inverse()
	if h["space"] == "pan":
		# the scene follows the mouse: the mouse's move on the screen over how far one camera unit moves the scene
		var d := inv.basis_xform(at - _drag["last"])
		_drag["last"] = at
		var rate: Vector2 = editor._ext.camera_rate()
		var v: Dictionary = editor.values
		if absf(rate.x) > 0.001:
			editor.set_value(h["x"], snappedf(v[h["x"]] + d.x / rate.x, 0.1))
		if absf(rate.y) > 0.001:
			editor.set_value(h["y"], snappedf(v[h["y"]] + d.y / rate.y, 0.1))
	elif _drag["part"] == "dot":
		var off: Vector2 = h["offset"].call() if h.has("offset") else Vector2.ZERO
		var p := inv * at - off
		editor.set_value(h["x"], snappedf(p.x, 0.5))
		editor.set_value(h["y"], snappedf(p.y, 0.5))
	else:
		var d := inv.basis_xform(at - _pos(h))
		var a := d.angle()
		editor.set_value(h["angle"], snappedf(rad_to_deg(a), 0.5) if h.get("angle_deg", false) else snappedf(a, 0.001))
