class_name DevMenu
extends SDTMenu
## Port addition: the developer panel (Settings > Menu > Developer mode). The same panel as the menu (search on top,
## sections on the left, cards on the right, help line at the bottom), docked on the other side: Menu side moves
## both. A DEBUG tab on its edge opens it, like the MENU tab. Its sections come from DevSchema; it never pauses
## the game, so the values it shows keep moving. Made by SDTMenu._sync_dev() the first time Developer mode is on.

const DEV_HELP := "Developer mode: tools for testing and debugging. Point at an option to see what it does; turn the mode off in Settings › Menu."


func _left() -> bool:
	return not SDTMenu.on_left()


func _enabled() -> bool:
	return SDTMenu.active() and SDTMenu.dev_mode_enabled()


func _make_sections() -> Array:
	return DevSchema.sections()


func _search_pool() -> Array:
	return sections


func _home() -> String:
	return sections[0]["id"]


func _title() -> String:
	return "Debug"


func _search_hint() -> String:
	return "Search debug tools"


func _tab_label() -> String:
	return "D\nE\nB\nU\nG"


func _pauses() -> bool:
	return false


func _default_help() -> String:
	return DEV_HELP


## Developer mode, Vanilla mode or the classic menu changed: hide the tab (and close) when it is off; the behaviour
## tabs' vetoes and observers only exist while it is on.
func apply_mode() -> void:
	DevBehaviour.sync(_enabled())
	if _root == null:
		return
	if not _enabled():
		close_menu()
		_tab_t = 0.0
		_tab.visible = false
	_layout()


## Behaviour rows have no label of their own (the row draws its name): the help line uses theirs.
func _show_help(spec) -> void:
	if spec != null and spec.has("label_text"):
		spec = spec.duplicate()
		spec["label"] = spec["label_text"]
	super(spec)


## The classic menu's hotkeys and Options button belong to the menu.
func toggle_tab(_tab_index: int) -> void:
	pass
