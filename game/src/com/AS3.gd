class_name AS3
extends RefCounted
## Helpers reproducing AS3 conversion semantics where game logic depends on them (dialogue settings, save data).

static var _reDecimal := RegEx.create_from_string("^[+-]?(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?$")
static var _reHex := RegEx.create_from_string("^[+-]?0[xX][0-9A-Fa-f]+$")


## AS3 Number(v): strings are trimmed; "" -> 0; decimal, exponent, hex and Infinity accepted; else NaN.
static func Number(v) -> float:
	match typeof(v):
		TYPE_NIL:
			return 0.0
		TYPE_BOOL:
			return 1.0 if v else 0.0
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(v).strip_edges()
			if s == "":
				return 0.0
			if _reDecimal.search(s):
				return s.to_float()
			if _reHex.search(s):
				var neg := s.begins_with("-")
				var body := s.trim_prefix("-").trim_prefix("+").substr(2)
				return float(body.hex_to_int()) * (-1.0 if neg else 1.0)
			match s:
				"Infinity", "+Infinity":
					return INF
				"-Infinity":
					return -INF
			return NAN
	return NAN


static func isNaN(v) -> bool:
	return is_nan(Number(v))


## AS3 String(v) for values that came from JSON / save data.
static func toString(v) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return AS3JSON.numStr(v)
	return str(v)


static func isNumber(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## AS3 loose equality (==) for the primitive types JSON produces.
static func looseEquals(a, b) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == tb or (isNumber(a) and isNumber(b)):
		return a == b
	if a == null or b == null:
		return a == null and b == null
	if ta == TYPE_BOOL or tb == TYPE_BOOL or isNumber(a) or isNumber(b):
		return Number(a) == Number(b)
	return str(a) == str(b)


## AS3 int(v): NaN, infinities and non-numeric become 0, fractions truncate towards 0, and the result wraps to a
## signed 32-bit number (int(4294967295) is -1).
static func toInt(v) -> int:
	var u := toUint(v)
	return u - 4294967296 if u >= 2147483648 else u


## AS3 uint(v): as int(v), but wrapping to an unsigned 32-bit number (uint(-1) is 4294967295).
static func toUint(v) -> int:
	var n := Number(v)
	if is_nan(n) or is_inf(n):
		return 0
	var m := fmod(signf(n) * floorf(absf(n)), 4294967296.0)
	if m < 0.0:
		m += 4294967296.0
	return int(m)
