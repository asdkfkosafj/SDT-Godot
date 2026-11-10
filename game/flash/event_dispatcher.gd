class_name FlashEventDispatcher
extends RefCounted
## flash.events.EventDispatcher for non-display objects.

var _listeners: Dictionary = {}


func addEventListener(type: String, listener: Callable, _use_capture: bool = false, priority: int = 0) -> void:
	var list: Array = _listeners.get(type, [])
	for l in list:
		if l[0] == listener:
			return
	# higher priority first; equal priorities in the order they were added (Flash). Inserted, not sorted: Godot's
	# sort_custom does not keep the order of equal items.
	var at := list.size()
	while at > 0 and list[at - 1][1] < priority:
		at -= 1
	list.insert(at, [listener, priority])
	_listeners[type] = list


func removeEventListener(type: String, listener: Callable, _use_capture: bool = false) -> void:
	var list: Array = _listeners.get(type, [])
	for i in range(list.size() - 1, -1, -1):
		if list[i][0] == listener:
			list.remove_at(i)


func hasEventListener(type: String) -> bool:
	return not _listeners.get(type, []).is_empty()


func dispatchEvent(event: FlashEvent) -> bool:
	event.target = self
	event.currentTarget = self
	for l in _listeners.get(event.type, []).duplicate():
		var cb: Callable = l[0]
		if not cb.is_valid():
			continue
		if cb.get_argument_count() == 0:
			cb.call()
		else:
			cb.call(event)
		if event._stop_immediate:
			break
	return not event.defaultPrevented
