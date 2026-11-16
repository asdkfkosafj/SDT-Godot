class_name FlashColorTransform
extends RefCounted
## flash.geom.ColorTransform: per-channel multiplier (fraction) and offset (-255..255).

var redMultiplier: float = 1.0
var greenMultiplier: float = 1.0
var blueMultiplier: float = 1.0
var alphaMultiplier: float = 1.0
var redOffset: float = 0.0
var greenOffset: float = 0.0
var blueOffset: float = 0.0
var alphaOffset: float = 0.0


func _init(rm: float = 1.0, gm: float = 1.0, bm: float = 1.0, am: float = 1.0,
		ro: float = 0.0, go: float = 0.0, bo: float = 0.0, ao: float = 0.0) -> void:
	redMultiplier = rm
	greenMultiplier = gm
	blueMultiplier = bm
	alphaMultiplier = am
	redOffset = ro
	greenOffset = go
	blueOffset = bo
	alphaOffset = ao


static func from_array(a: Array) -> FlashColorTransform:
	return FlashColorTransform.new(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7])


func clone() -> FlashColorTransform:
	return FlashColorTransform.new(redMultiplier, greenMultiplier, blueMultiplier, alphaMultiplier,
		redOffset, greenOffset, blueOffset, alphaOffset)


## Same values (a mod setting the same transform every frame changes nothing).
func equals(o: FlashColorTransform) -> bool:
	return o != null and redMultiplier == o.redMultiplier and greenMultiplier == o.greenMultiplier \
		and blueMultiplier == o.blueMultiplier and alphaMultiplier == o.alphaMultiplier and redOffset == o.redOffset \
		and greenOffset == o.greenOffset and blueOffset == o.blueOffset and alphaOffset == o.alphaOffset


## Flash 'color' setter: sets offsets to the RGB value and multipliers to 0.
var color: int:
	get:
		return (int(redOffset) << 16) | (int(greenOffset) << 8) | int(blueOffset)
	set(value):
		redMultiplier = 0.0
		greenMultiplier = 0.0
		blueMultiplier = 0.0
		redOffset = (value >> 16) & 0xFF
		greenOffset = (value >> 8) & 0xFF
		blueOffset = value & 0xFF


## Applies 'second' after this one (Flash concat semantics).
func concat(second: FlashColorTransform) -> void:
	redOffset = redOffset * second.redMultiplier + second.redOffset
	greenOffset = greenOffset * second.greenMultiplier + second.greenOffset
	blueOffset = blueOffset * second.blueMultiplier + second.blueOffset
	alphaOffset = alphaOffset * second.alphaMultiplier + second.alphaOffset
	redMultiplier *= second.redMultiplier
	greenMultiplier *= second.greenMultiplier
	blueMultiplier *= second.blueMultiplier
	alphaMultiplier *= second.alphaMultiplier


func has_offsets() -> bool:
	return redOffset != 0.0 or greenOffset != 0.0 or blueOffset != 0.0 or alphaOffset != 0.0


func is_identity() -> bool:
	return not has_offsets() and redMultiplier == 1.0 and greenMultiplier == 1.0 \
		and blueMultiplier == 1.0 and alphaMultiplier == 1.0


# ---------------------------------------------------------------- fl.motion.Color helpers

## fl.motion.Color.setTint: blends towards 'tint_color' by 'multiplier' (0..1).
static func tint(tint_color: int, multiplier: float) -> FlashColorTransform:
	var ct := FlashColorTransform.new()
	ct.redMultiplier = 1.0 - multiplier
	ct.greenMultiplier = 1.0 - multiplier
	ct.blueMultiplier = 1.0 - multiplier
	ct.redOffset = floor(((tint_color >> 16) & 0xFF) * multiplier + 0.5)
	ct.greenOffset = floor(((tint_color >> 8) & 0xFF) * multiplier + 0.5)
	ct.blueOffset = floor((tint_color & 0xFF) * multiplier + 0.5)
	return ct


## fl.motion.Color.brightness setter (-1..1).
static func brightness(b: float) -> FlashColorTransform:
	b = clampf(b, -1.0, 1.0)
	var m := 1.0 - absf(b)
	var o := b * 255.0 if b > 0.0 else 0.0
	return FlashColorTransform.new(m, m, m, 1.0, o, o, o, 0.0)


## fl.motion.Color.interpolateTransform
static func interpolate_transform(a: FlashColorTransform, b: FlashColorTransform, t: float) -> FlashColorTransform:
	var u := 1.0 - t
	return FlashColorTransform.new(a.redMultiplier * u + b.redMultiplier * t, a.greenMultiplier * u + b.greenMultiplier * t,
		a.blueMultiplier * u + b.blueMultiplier * t, a.alphaMultiplier * u + b.alphaMultiplier * t,
		a.redOffset * u + b.redOffset * t, a.greenOffset * u + b.greenOffset * t,
		a.blueOffset * u + b.blueOffset * t, a.alphaOffset * u + b.alphaOffset * t)


## fl.motion.Color.interpolateColor (ARGB ints; channels truncated like the uint maths in Flash).
static func interpolate_color(a: int, b: int, t: float) -> int:
	var u := 1.0 - t
	var out := 0
	for shift in [24, 16, 8, 0]:
		var ca: int = (a >> shift) & 0xFF
		var cb: int = (b >> shift) & 0xFF
		out |= (int(ca * u + cb * t) & 0xFF) << shift
	return out
