extends FlashDisplayObject
## Subtitles dialogue look: the soft dark shade along the bottom of the window, behind the text (a child of the
## dialogue, so it fades in and out with it). It has no bounds: the dialogue editor keeps only the text in view.

const COLOR := Color8(8, 12, 20)
const STRENGTH := 0.55
## Opacity down the shade (top 0, bottom 1): eased, so it has no visible top edge.
const BANDS := [[0.0, 0.0], [0.4, 0.3], [1.0, 1.0]]

var _rect := Rect2()
var _tint = null      # Color (dialogdisplayedit's box colour) or null
var _opacity := 1.0   # dialogdisplayedit's box opacity (0..3)


## The area to cover, in the dialogue's coordinates.
func set_rect(r: Rect2) -> void:
	if r != _rect:
		_rect = r
		queue_redraw()


## Colour (null: the shade's own) and opacity factor, from the box settings of dialogdisplayedit.
func set_look(tint, opacity: float) -> void:
	if tint != _tint or opacity != _opacity:
		_tint = tint
		_opacity = opacity
		queue_redraw()


func _draw() -> void:
	if _rect.size.x <= 0.0 or _rect.size.y <= 0.0:
		return
	var c: Color = _tint if _tint != null else COLOR
	var a := STRENGTH * _opacity
	for i in BANDS.size() - 1:
		var y0: float = _rect.position.y + _rect.size.y * BANDS[i][0]
		var y1: float = _rect.position.y + _rect.size.y * BANDS[i + 1][0]
		var c0 := Color(c, minf(1.0, a * BANDS[i][1]))
		var c1 := Color(c, minf(1.0, a * BANDS[i + 1][1]))
		draw_polygon(PackedVector2Array([Vector2(_rect.position.x, y0), Vector2(_rect.end.x, y0),
			Vector2(_rect.end.x, y1), Vector2(_rect.position.x, y1)]), PackedColorArray([c0, c0, c1, c1]))
