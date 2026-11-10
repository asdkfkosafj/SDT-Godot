extends SDTExtension
## Test plugin for the guard (game/debug/ext_checks.gd): raises a script error from its tick or from a hook when
## told to, or reports one with push_error (which must not count against it).

var boom := ""   # "tick" or "hook": where the next error happens
var ticks := 0
var nothing: Object = null


func _enable() -> void:
	on_late_tick(_tick)
	hook_after(&"Her.passOut", _on_pass_out)


func _tick() -> void:
	ticks += 1
	if boom == "tick":
		nothing.call("missing")   # an error in debug builds (a crash in release builds)


func _on_pass_out(_c) -> void:
	if boom == "hook":
		nothing.call("missing")


func report() -> void:
	push_error("faulty: a problem it reports itself")
