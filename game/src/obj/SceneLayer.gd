class_name SceneLayer
extends FlashSprite
## Port of obj.SceneLayer: the camera. Zoom/shake/mirroring are applied to this layer and mirrored onto the
## "external" layers (back, front, strands, cum) that live outside it in the display list.

var camera := Vector2()
var magnitude := Vector2()
var shaking := false
var t: int = 0
var externalLayers: Array = []
var currentZoom: float = 0.0
var targetZoom: float = 0.0
var zooming := false
const extendedBackgroundHeight := 825.0
var backgroundHeight: float = 825.0
var bgYLimit: float


func _init(zoom: float = g.defaultZoom) -> void:
	bgYLimit = g.screenSize.y - backgroundHeight
	zoomTo(zoom, true)
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func giveExternalLayer(layer: FlashSprite) -> void:
	layer.x = x
	layer.y = y
	layer.scaleX = scaleX
	layer.scaleY = scaleY
	if rotation_degrees != 0.0:   # port: a body position may turn the scene
		layer.rotation_degrees = rotation_degrees
	externalLayers.append(layer)


func toggleMirrored() -> void:
	g.mirrored = not g.mirrored
	updateCamera()


func applyHSL(cmf: FlashFilter) -> void:
	if externalLayers:
		filters = [cmf]
		for l in externalLayers:
			l.filters = [cmf]


func setSceneVisible(v: bool) -> void:
	visible = v
	for l in externalLayers:
		l.visible = v


func setCustomBGHeight(h: float) -> void:
	backgroundHeight = h
	bgYLimit = g.screenSize.y - backgroundHeight
	updateBGScroll()


func removeCustomBGHeight() -> void:
	backgroundHeight = extendedBackgroundHeight
	bgYLimit = g.screenSize.y - backgroundHeight
	updateBGScroll()


func tick() -> void:
	t += 1
	if shaking:
		x = camera.x + sin(t * 1.5) * magnitude.x
		y = camera.y + sin(t * 1.5) * magnitude.y
		magnitude.x *= 0.8
		magnitude.y *= 0.8
		if absf(magnitude.x) < 0.1 and absf(magnitude.y) < 0.1:
			x = camera.x
			y = camera.y
			shaking = false
		updateExternalLayerPositions()
	if zooming:
		var z := currentZoom + (targetZoom - currentZoom) / 4.0
		if absf(z - targetZoom) < 0.0001:
			z = targetZoom
			zooming = false
		currentZoom = z
		updateCamera()


func updateExternalLayerPositions() -> void:
	for l in externalLayers:
		l.x = x
		l.y = y


func updateExternalLayerScales() -> void:
	for l in externalLayers:
		l.scaleX = scaleX
		l.scaleY = scaleY


func updateCamera() -> void:
	var rot := 0.0
	if Hooks.has_value(&"SceneLayer.rotation"):   # HOOK value point: the scene's rotation in degrees (0), on this layer and the external layers
		rot = float(Hooks.value(&"SceneLayer.rotation", self, 0.0))
	if rotation_degrees != rot:
		rotation_degrees = rot
		for l in externalLayers:
			l.rotation_degrees = rot
	scaleX = -currentZoom if g.mirrored else currentZoom
	scaleY = currentZoom
	updateExternalLayerScales()
	updateBGScroll()
	var cx := maxf(200.0, 370.0 - currentZoom * 200.0)
	if g.mirrored:
		cx = g.screenSize.x - cx
	var aim := Vector2(cx, 50)
	if Hooks.has_value(&"SceneLayer.cameraAim"):   # HOOK value point: where the camera puts this layer's origin on the screen (the zoom's point, mirrored)
		aim = Hooks.value(&"SceneLayer.cameraAim", self, aim)
	aimCamera(aim.x, aim.y)
	x = camera.x
	y = camera.y
	updateExternalLayerPositions()


func updateBGScroll() -> void:
	if g.bg:
		g.bg.y = minf(0.0, maxf(bgYLimit, -40.0 / (currentZoom - 0.264) + 68.0))


func zoomTo(z: float, instant: bool = false) -> void:
	g.sceneZoom = z
	z += 0.4
	targetZoom = z
	if instant:
		currentZoom = targetZoom
		updateCamera()
		zooming = false
	else:
		zooming = true


func zoomIn(amount: float = 0.25) -> void:
	var step := maxf(0.05, g.sceneZoom * g.sceneZoom * amount)
	zoomTo(minf(1.0, g.sceneZoom + step))
	g.inGameMenu.updateZoomSlider()


func zoomOut(amount: float = 0.25) -> void:
	var step := maxf(0.05, g.sceneZoom * g.sceneZoom * amount)
	zoomTo(maxf(0.0, g.sceneZoom - step))
	g.inGameMenu.updateZoomSlider()


func aimCamera(cx: float, cy: float) -> void:
	camera = Vector2(cx, cy)
	x = camera.x
	y = camera.y


func shake(amount: float) -> void:
	magnitude.x = randf() * minf(9.0 * currentZoom, amount * currentZoom)
	magnitude.y = 0
	shaking = true
