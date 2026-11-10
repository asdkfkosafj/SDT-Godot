extends SDTExtension
## Test plugin for game/debug/ext_checks.gd: registers names the game has no point for (they must be reported), a
## real hook point and value point, and a hook point of its own that it declares first (neither may be reported).

var own_calls := 0


func _enable() -> void:
	hook_after(&"Her.passOut", func(_c): pass)
	hook_before(&"Her.noSuchMethod", func(_c): pass)
	hook_after(&"Her.noSuchMethod", func(_c): pass)
	modify(&"Her.noSuchValue", {"op": "bias", "value": 1.0})
	modify(&"Her.lookTarget", {"op": "bias", "value": Vector2.ZERO})
	declare_hook_point(&"UnknownPoint.own")
	hook_after(&"UnknownPoint.own", func(_c): own_calls += 1)
	if Hooks.has(&"UnknownPoint.own"):
		Hooks.after(&"UnknownPoint.own", self)
