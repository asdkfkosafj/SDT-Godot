class_name Neck
extends FlashMovieClip
## Port of obj.her.Neck: draws the neck procedurally (gradient fills + outline band) through outline points placed
## in the symbol, with a throat bulge and a swallow wave.

var neckPoints: Array = []
var numPoints: int = 0
var highlightPoints: Array = []
var numHighlightPoints: int = 0
var frontEndPoint: int = 0
var shadeLight: int = 16178890
var shade1: int = 14925224
var shade2: int = 13541515
var shade3: int = 11306097
var mainGradient: Transform2D
var highlightGradient: Transform2D
var swallowing := false
var swallowProgress: float = 0.0
var swallowSize: float = 10.0
var swallowStart: float = 0.2
var bulgeSize: float = 35.0
var bulgeVec: Vector2
var throatBulgeAmount: float = 1.0
var _tanLayer: FlashSprite
var tanAlpha: float = 1.0
## Port: how far the swallow bulge pushes the neck out (x) and down (y); the throatcumbulge extension changes it.
## Port: the last render's outline points and depth (a collar reads how far her throat pushes out; the developer panel).
var renderedPoints: Array = []
var lastDepth: float = 0.0


func _init() -> void:
	super()
	_tanLayer = FlashSprite.new()
	_tanLayer.blendMode = "overlay"
	addChild(_tanLayer)
	numPoints = 0
	var p = get("outline%d" % numPoints)
	while p:
		neckPoints.append(Vector2(p.x, p.y))
		numPoints += 1
		p = get("outline%d" % numPoints)
	numPoints -= 1
	numHighlightPoints = 0
	p = get("highlight%d" % numHighlightPoints)
	while p:
		highlightPoints.append(Vector2(p.x, p.y))
		numHighlightPoints += 1
		p = get("highlight%d" % numHighlightPoints)
	numHighlightPoints -= 1
	respacePoints()
	mainGradient = Transform2D(Vector2(-0.0003204345703125, -0.142364501953125),
		Vector2(0.2744293212890625, -0.000640869140625), Vector2(-19.099, 76.85))
	highlightGradient = Transform2D(Vector2(0.0777435302734375, 0.0058441162109375),
		Vector2(-0.0086517333984375, 0.114990234375), Vector2(-8.649, 109))
	bulgeVec = Maths.getUnitVector(PI * 0.75)


func setSkin(palette: SkinPalette) -> void:
	shadeLight = palette.light.rgb
	shade1 = palette.shade1.rgb
	shade2 = palette.shade2.rgb
	shade3 = palette.shade3.rgb


## Resamples the front of the neck outline into evenly spaced points along a quadratic spline.
func respacePoints() -> void:
	var old: Array = neckPoints.duplicate()
	neckPoints = []
	var seg := -1
	numPoints -= 1
	var segments := 6.0
	var steps := int(segments * 5)
	var mid1 := Vector2()
	var mid2 := Vector2()
	var d1 := Vector2()
	var d2 := Vector2()
	for i in steps:
		var s := int(floor(float(i) / steps * segments))
		if seg != s:
			seg = s
			mid1 = (old[seg] + old[seg + 1]) * 0.5
			mid2 = (old[seg + 1] + old[seg + 2]) * 0.5
			d1 = old[seg + 1] - mid1
			d2 = mid2 - old[seg + 1]
		var t := float(i) / steps * segments - seg
		var a: Vector2 = mid1 + d1 * t
		var b: Vector2 = old[seg + 1] + d2 * t
		neckPoints.append(a + (b - a) * t)
	frontEndPoint = neckPoints.size()
	neckPoints.append_array(old.slice(int(segments) + 1))
	numPoints = neckPoints.size()


## Port: how far (px) the band `band` (the value point Neck.band) lets the front of her neck push out at depth `f`
## (0 at her jaw .. 1 at her chest; `free_px`: as far as it would without the band). band = {"top", "bottom": its
## edges (depth), "inside": px her neck may push out between them, "soft": depth past each edge over which that
## blends into the free bulge}. A second extension that holds her neck returns the narrower band (narrower(): the
## smaller "inside" wins, like a clamp).
static func band_limit(band: Dictionary, f: float, free_px: float) -> float:
	var out: float = maxf(band["top"] - f, f - band["bottom"])
	if out <= 0.0:
		return band["inside"]
	var soft: float = band.get("soft", 0.0)
	if out >= soft:
		return INF
	return lerpf(band["inside"], maxf(band["inside"], free_px), smoothstep(0.0, 1.0, out / soft))


## Port: of two bands (either may be null), the one that holds her neck in more.
static func narrower(a, b):
	if a == null:
		return b
	if b == null:
		return a
	return a if a["inside"] <= b["inside"] else b


## The swallow's lump at `at` along the front of her neck, at f (0..1 of its size).
static func lump(f: float, at: float) -> float:
	return maxf(0.0, 2.0 / (2.0 + pow(8.0 * (f - at), 2.0)) - 0.2)


func swallow() -> void:
	swallowing = true
	swallowProgress = swallowStart


var _drawn_look: Array = []   # what render last drew with, besides the points


func render(depth: float) -> void:
	if Hooks.has_value(&"Neck.depth"):   # HOOK value point: how deep the throat bulge sits (his depth / 400)
		depth = Hooks.value(&"Neck.depth", self, depth)
	var pts: Array = neckPoints.duplicate()
	bulgeSize = 35.0 * (1.0 + (g.him.getPenisWidthWithTwitch() - 1.0) * 1.5)
	var bulgeAmount := throatBulgeAmount
	if Hooks.has_value(&"Neck.throatBulge"):   # HOOK value point: how much the throat bulges (her throat bulge setting)
		bulgeAmount = Hooks.value(&"Neck.throatBulge", self, bulgeAmount)
	var bulgeCap := 35.0
	if Hooks.has_value(&"Neck.bulgeCap"):   # HOOK value point: the most the bulge pushes the neck out, in pixels
		bulgeCap = Hooks.value(&"Neck.bulgeCap", self, bulgeCap)
	var swallowScale := Vector2(0.8, 0.5)
	if swallowing and Hooks.has_value(&"Neck.swallowScale"):   # HOOK value point: how a swallow pushes her neck out (x out, y down)
		swallowScale = Hooks.value(&"Neck.swallowScale", self, swallowScale)
	var bumps: Array = []
	if Hooks.has_value(&"Neck.bumps"):   # HOOK value point: swallow lumps held in her throat ([] in the game; {at, size})
		bumps = Hooks.value(&"Neck.bumps", self, bumps)
	var band = null
	if Hooks.has_value(&"Neck.band"):   # HOOK value point: a band that holds the front of her neck in (a collar), or null
		band = Hooks.value(&"Neck.band", self, null)
	for i in frontEndPoint:
		var f := float(i) / frontEndPoint
		if bulgeAmount > 0:
			var rel := f - depth
			var bulge := 1.0 / (1.0 + pow(2.0, rel * 35.0)) * bulgeAmount
			var amt := minf(1.0, 0.6 + 0.6 * depth) * minf(bulgeCap, bulgeSize * bulge * pow(1.0 - f, 1.4))
			pts[i] = pts[i] + Vector2(amt, 0.3 * amt)
		for b in bumps:   # (port extension: the swallow's lump, held where something is in her throat)
			pts[i] = pts[i] + float(b["size"]) * lump(f, float(b["at"])) * swallowScale
		if swallowing:
			var sw := swallowSize * lump(f, swallowProgress)
			sw *= minf(1.0, minf((swallowProgress - swallowStart) * 5.0, 2.0 - swallowProgress * 2.0))
			pts[i] = pts[i] + sw * swallowScale
		if band != null:
			var d: Vector2 = pts[i] - neckPoints[i]
			if d.x > 0.0:
				var lim := band_limit(band, f, d.x)
				if lim < d.x:
					pts[i] = neckPoints[i] + d * (maxf(0.0, lim) / d.x)
	if swallowing:
		swallowProgress += 0.05
		if swallowProgress > 1:
			swallowing = false
	var look := [shade1, shade3, shadeLight, tanAlpha, mainGradient, highlightGradient]
	if pts == renderedPoints and look == _drawn_look:   # the same neck: nothing to draw again
		lastDepth = depth
		return
	_drawn_look = look
	renderedPoints = pts
	lastDepth = depth
	var gr := graphics
	gr.clear()
	gr.beginGradientFill("radial", [shade1, shade3], [1, 1], [209, 250], mainGradient, "pad", "rgb", 0.1)
	var mid: Vector2 = (pts[0] + pts[1]) * 0.5
	var first := mid
	var tg := _tanLayer.graphics
	if tanAlpha > 0:
		tg.clear()
		tg.beginFill(0, tanAlpha)
		tg.moveTo(pts[0].x, pts[0].y)
		tg.lineTo(first.x, first.y)
	gr.moveTo(pts[0].x, pts[0].y)
	gr.lineTo(first.x, first.y)
	var i := 1
	while i < numPoints - 1:
		mid = (pts[i] + pts[i + 1]) * 0.5
		gr.curveTo(pts[i].x, pts[i].y, mid.x, mid.y)
		if tanAlpha > 0:
			tg.curveTo(pts[i].x, pts[i].y, mid.x, mid.y)
		i += 1
	mid = (pts[pts.size() - 1] + pts[0]) * 0.5
	gr.lineTo(pts[i].x, pts[i].y)
	gr.lineStyle()
	gr.curveTo(mid.x, mid.y, pts[0].x, pts[0].y)
	gr.endFill()
	if tanAlpha > 0:
		tg.lineTo(pts[i].x, pts[i].y)
		tg.lineStyle()
		tg.curveTo(mid.x, mid.y, pts[0].x, pts[0].y)
		tg.endFill()
	gr.beginGradientFill("radial", [shadeLight, shade1], [1, 1], [215, 250], highlightGradient, "pad", "rgb", 0.1)
	var hp := highlightPoints
	gr.moveTo(hp[0].x, hp[0].y)
	first = (hp[0] + hp[1]) * 0.5
	gr.lineTo(first.x, first.y)
	i = 1
	while i < numHighlightPoints - 1:
		mid = (hp[i] + hp[i + 1]) * 0.5
		gr.curveTo(hp[i].x, hp[i].y, mid.x, mid.y)
		i += 1
	gr.lineTo(hp[i].x, hp[i].y)
	gr.lineStyle()
	mid = (hp[hp.size() - 1] + hp[0]) * 0.5
	gr.curveTo(mid.x, mid.y, hp[0].x, hp[0].y)
	gr.endFill()
	# Outline band along the neck edge.
	gr.beginFill(5849907, 1)
	gr.moveTo(pts[0].x, pts[0].y)
	var outer: Array = []
	var inner: Array = []
	var outerMid: Array = []
	var innerMid: Array = []
	var dirs: Array = []
	var w := 0.6
	outer.resize(numPoints)
	inner.resize(numPoints)
	outerMid.resize(numPoints)
	innerMid.resize(numPoints)
	dirs.resize(numPoints)
	outer[0] = pts[0]
	inner[0] = pts[0]
	i = 0
	while i < numPoints - 1:
		var d: Vector2 = pts[i + 1] - pts[i]
		d /= sqrt(d.x * d.x + d.y * d.y)
		dirs[i] = d
		if i > 0:
			var pd: Vector2 = dirs[i - 1]
			var n := Vector2((pd.y + d.y) * w, -((pd.x + d.x) * w))
			outer[i] = pts[i] - n
			inner[i] = pts[i] + n
			outerMid[i] = outer[i - 1] + (outer[i] - outer[i - 1]) * 0.5
			innerMid[i] = inner[i - 1] + (inner[i] - inner[i - 1]) * 0.5
		i += 1
	outerMid[i] = outer[i - 1] + (pts[i] - outer[i - 1]) * 0.5
	innerMid[i] = inner[i - 1] + (pts[i] - inner[i - 1]) * 0.5
	gr.lineTo(outerMid[1].x, outerMid[1].y)
	i = 1
	while i < numPoints - 1:
		gr.curveTo(outer[i].x, outer[i].y, outerMid[i + 1].x, outerMid[i + 1].y)
		i += 1
	gr.lineTo(pts[numPoints - 1].x, pts[numPoints - 1].y)
	gr.markBandTip()
	i = numPoints - 1
	gr.lineTo(innerMid[i].x, innerMid[i].y)
	while i > 1:
		gr.curveTo(inner[i - 1].x, inner[i - 1].y, innerMid[i - 1].x, innerMid[i - 1].y)
		i -= 1
	gr.lineTo(pts[0].x, pts[0].y)


var throatBulge: float:
	get:
		return throatBulgeAmount
	set(v):
		throatBulgeAmount = v

var tan: FlashSprite:
	get:
		return _tanLayer
