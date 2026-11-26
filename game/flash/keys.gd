class_name FlashKeys
extends RefCounted
## Maps Godot keycodes to Flash keyCode values (Windows virtual-key codes), which the game logic uses.

const SPECIAL := {
	KEY_BACKSPACE: 8, KEY_TAB: 9, KEY_ENTER: 13, KEY_KP_ENTER: 13, KEY_SHIFT: 16, KEY_CTRL: 17, KEY_ALT: 18,
	KEY_PAUSE: 19, KEY_CAPSLOCK: 20, KEY_ESCAPE: 27, KEY_SPACE: 32, KEY_PAGEUP: 33, KEY_PAGEDOWN: 34,
	KEY_END: 35, KEY_HOME: 36, KEY_LEFT: 37, KEY_UP: 38, KEY_RIGHT: 39, KEY_DOWN: 40, KEY_INSERT: 45,
	KEY_DELETE: 46, KEY_KP_MULTIPLY: 106, KEY_KP_ADD: 107, KEY_KP_SUBTRACT: 109, KEY_KP_PERIOD: 110,
	KEY_KP_DIVIDE: 111, KEY_SEMICOLON: 186, KEY_EQUAL: 187, KEY_COMMA: 188, KEY_MINUS: 189, KEY_PERIOD: 190,
	KEY_SLASH: 191, KEY_QUOTELEFT: 192, KEY_BRACKETLEFT: 219, KEY_BACKSLASH: 220, KEY_BRACKETRIGHT: 221,
	KEY_APOSTROPHE: 222,
}


static func to_flash(k: Key) -> int:
	if k >= KEY_A and k <= KEY_Z:
		return 65 + (k - KEY_A)
	if k >= KEY_0 and k <= KEY_9:
		return 48 + (k - KEY_0)
	if k >= KEY_KP_0 and k <= KEY_KP_9:
		return 96 + (k - KEY_KP_0)
	if k >= KEY_F1 and k <= KEY_F15:
		return 112 + (k - KEY_F1)
	return SPECIAL.get(k, 0)


## The Godot keycode for a Flash keyCode (to_flash backwards; KEY_NONE when there is none). For the two keys that
## share a code (Enter), the main one.
static func to_godot(code: int) -> int:
	if code >= 65 and code <= 90:
		return KEY_A + (code - 65)
	if code >= 48 and code <= 57:
		return KEY_0 + (code - 48)
	if code >= 96 and code <= 105:
		return KEY_KP_0 + (code - 96)
	if code >= 112 and code <= 126:
		return KEY_F1 + (code - 112)
	for k in SPECIAL:
		if SPECIAL[k] == code:
			return k
	return KEY_NONE
