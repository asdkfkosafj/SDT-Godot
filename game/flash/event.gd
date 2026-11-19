class_name FlashEvent
extends RefCounted
## flash.events.Event plus the mouse / keyboard / timer fields used by the game.

const ENTER_FRAME := "enterFrame"
const ADDED := "added"
const ADDED_TO_STAGE := "addedToStage"
const REMOVED := "removed"
const REMOVED_FROM_STAGE := "removedFromStage"
const COMPLETE := "complete"
const CHANGE := "change"
const SELECT := "select"
const CANCEL := "cancel"
const INIT := "init"
const MOUSE_LEAVE := "mouseLeave"
const SOUND_COMPLETE := "soundComplete"
const RESIZE := "resize"

const CLICK := "click"
const DOUBLE_CLICK := "doubleClick"
const MOUSE_DOWN := "mouseDown"
const MOUSE_UP := "mouseUp"
const RIGHT_MOUSE_DOWN := "rightMouseDown"   # (Flash Player 11.2+; the game does not use it)
const MOUSE_MOVE := "mouseMove"
const MOUSE_OVER := "mouseOver"
const MOUSE_OUT := "mouseOut"
const ROLL_OVER := "rollOver"
const ROLL_OUT := "rollOut"
const MOUSE_WHEEL := "mouseWheel"

const KEY_DOWN := "keyDown"
const KEY_UP := "keyUp"
const FOCUS_IN := "focusIn"
const FOCUS_OUT := "focusOut"

const TIMER := "timer"
const TIMER_COMPLETE := "timerComplete"
const IO_ERROR := "ioError"

const CAPTURING_PHASE := 1
const AT_TARGET := 2
const BUBBLING_PHASE := 3

var type: String
var bubbles: bool
var cancelable: bool
var target: Object = null
var currentTarget: Object = null
var eventPhase: int = AT_TARGET
var defaultPrevented := false
var _stop := false
var _stop_immediate := false
## ErrorEvent.text / TextEvent.text
var text: String = ""

# Mouse
var stageX: float = 0.0
var stageY: float = 0.0
var localX: float = 0.0
var localY: float = 0.0
var delta: int = 0
var relatedObject: Object = null
var buttonDown := false
# Keyboard (keyCode uses Flash/Windows virtual key codes, as the original game does)
var keyCode: int = 0
var charCode: int = 0
# Modifiers
var shiftKey := false
var ctrlKey := false
var altKey := false
# Generic payload (e.g. loaded data)
var data = null


func _init(p_type: String, p_bubbles: bool = false, p_cancelable: bool = false) -> void:
	type = p_type
	bubbles = p_bubbles
	cancelable = p_cancelable


func stopPropagation() -> void:
	_stop = true


func stopImmediatePropagation() -> void:
	_stop = true
	_stop_immediate = true


func preventDefault() -> void:
	if cancelable:
		defaultPrevented = true


static func mouse(p_type: String, bubbles_: bool = true) -> FlashEvent:
	var e := FlashEvent.new(p_type, bubbles_)
	var p := Flash.mouse_position()
	e.stageX = p.x
	e.stageY = p.y
	e.shiftKey = Input.is_key_pressed(KEY_SHIFT)
	e.ctrlKey = Input.is_key_pressed(KEY_CTRL)
	e.altKey = Input.is_key_pressed(KEY_ALT)
	e.buttonDown = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return e
