class_name FlashMovieClip
extends FlashSprite
## flash.display.MovieClip driven by a converted SWF timeline.
##
## A ported AS3 class (e.g. Her) extends this; its symbol is found automatically from the script's class name,
## so `Her.new()` builds the Her symbol's timeline exactly like `new Her()` in ActionScript. Library symbols
## without a ported class are plain FlashMovieClips created through Flash.create().
##
## Named timeline children are bound to same-named script variables (AS3 stage-instance declaration) and are
## also reachable dynamically (clip.leg), like AS3 dynamic MovieClips.

var _sym: Dictionary = {}
var _frame: int = 0                 # 0-based current frame
var _total: int = 1
var _playing := false
var _built := false
var _timeline_children: Dictionary = {}   # depth -> child
var _named: Dictionary = {}               # flash name -> child (dynamic property access)
var _code_frame_scripts: Dictionary = {}  # 0-based frame -> Callable
var _in_frame_script := false
## MovieClip.enabled (used by button-like clips)
var enabled := true


func _init() -> void:
	var pending = Flash.take_pending_symbol()
	if pending != null:
		_setup_symbol(pending[0], pending[1])
		var p = pending[2]
		if p != null:
			# Timeline placement happens before the class constructor body (AS3 semantics).
			_depth = pending[5]
			_birth = pending[6]
			_flash_parent = p
			xf_epoch += 1
			p._apply_place(self, pending[3], pending[4], true)
		return
	var script: Script = get_script()
	if script == null:
		return
	var cls := script.get_global_name()
	if cls == &"FlashMovieClip" or cls == &"":
		return
	var found: Array = Flash.find_class_symbol(String(cls))
	if not found.is_empty():
		_setup_symbol(found[0], found[1])


func _setup_symbol(library, char_id: int) -> void:
	_library = library
	_char_id = char_id
	_sym = library.get_char(char_id)
	if _sym.get("t") != "sprite":
		_sym = {}
		return
	_total = maxi(1, _sym["frames"].size())
	_playing = _total > 1
	_goto(0, true)
	_built = true


# ---------------------------------------------------------------- dynamic child access

func _get(property: StringName):
	var c = _named.get(String(property))
	if c == null and not _dyn.is_empty():
		return _dyn.get(String(property))
	return c


## MovieClip is a dynamic class in AS3: unknown properties can be set at runtime (mods rely on this).
var _dyn: Dictionary = {}


func _set(property: StringName, value) -> bool:
	var n := String(property)
	if _named.has(n):
		return false
	# _set also sees engine properties (visible, scale, ...); those must go to the node itself.
	if not _dyn.has(n) and _native_props().has(property):
		return false
	_dyn[n] = value
	return true


static var _native_prop_cache: Dictionary = {}


static func _native_props() -> Dictionary:
	if _native_prop_cache.is_empty():
		for p in ClassDB.class_get_property_list("Node2D"):
			_native_prop_cache[StringName(p["name"])] = true
	return _native_prop_cache


func hasOwnProperty(n: String) -> bool:
	if _dyn.has(n) or _named.has(n):
		return true
	for p in get_property_list():
		if p["name"] == n:
			return true
	return false


func get_property_bound_child(n: String) -> FlashDisplayObject:
	return _named.get(n)


# ---------------------------------------------------------------- playback API

var currentFrame: int:
	get:
		return _frame + 1

var totalFrames: int:
	get:
		return _total

var isPlaying: bool:
	get:
		return _playing


## Label of the current frame, or of the closest labelled frame before it ("" if none).
var currentLabel: String:
	get:
		var best := ""
		var best_f := -1
		var labels: Dictionary = _sym.get("labels", {})
		for k in labels:
			var f: int = labels[k]
			if f <= _frame and f > best_f:
				best_f = f
				best = k
		return best

## Label placed exactly on the current frame ("" if none).
var currentFrameLabel: String:
	get:
		var labels: Dictionary = _sym.get("labels", {})
		for k in labels:
			if labels[k] == _frame:
				return k
		return ""

## Array of {name, frame} (frame is 1-based), sorted by frame.
var currentLabels: Array:
	get:
		var out: Array = []
		var labels: Dictionary = _sym.get("labels", {})
		for k in labels:
			out.append({"name": k, "frame": labels[k] + 1})
		out.sort_custom(func(a, b): return a["frame"] < b["frame"])
		return out


func has_label(label: String) -> bool:
	return _sym.get("labels", {}).has(label)


func play() -> void:
	if _total > 1:
		_playing = true
		_update_play_registration()


func stop() -> void:
	_playing = false
	_update_play_registration()


## frame: 1-based frame number or label name.
func gotoAndStop(frame) -> void:
	_playing = false
	_update_play_registration()
	_goto_flash(frame)


func gotoAndPlay(frame) -> void:
	_playing = _total > 1
	_update_play_registration()
	_goto_flash(frame)


func nextFrame() -> void:
	gotoAndStop(mini(_frame + 2, _total))


func prevFrame() -> void:
	gotoAndStop(maxi(_frame, 1))


func _goto_flash(frame) -> void:
	var f: int
	if frame is String or frame is StringName:
		var labels: Dictionary = _sym.get("labels", {})
		if not labels.has(String(frame)):
			push_error("%s: frame label '%s' not found" % [_debug_name(), frame])
			return
		f = labels[String(frame)]
	else:
		f = int(frame) - 1
	_goto(clampi(f, 0, _total - 1), false)


## Registers a code frame script (0-based frame index), like AS3 addFrameScript.
func addFrameScript(frame_index: int, fn: Callable) -> void:
	_code_frame_scripts[frame_index] = fn


## Called by the runtime once per tick while playing.
func _advance() -> void:
	if not _playing or _total <= 1:
		return
	_goto((_frame + 1) % _total, false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_EXIT_TREE:
			if not FlashGroupProxy.moving:   # a group moving it in or out of its viewport keeps it playing in place
				_update_play_registration()


func _update_play_registration() -> void:
	if _playing and is_inside_tree():
		Flash.register_playing(self)
	else:
		Flash.unregister_playing(self)


func _debug_name() -> String:
	return "%s(%d)" % [flash_name if flash_name != "" else get_script().get_global_name(), _char_id]


# ---------------------------------------------------------------- timeline construction

func _goto(f: int, initial: bool) -> void:
	if _sym.is_empty():
		return
	if f == _frame and not initial:
		return
	var frames: Array = _sym["frames"]
	var places: Array = _sym["places"]
	var row: Array = frames[f]
	# Remove children that are not on the target frame. Nearly always there are none (morphing eyelids and lips change
	# frame every tick), which counting shows without building a set of the row's depths.
	var kept := 0
	for e in row:
		if _timeline_children.has(int(e[0])):
			kept += 1
	if kept != _timeline_children.size():
		var want := {}
		for e in row:
			want[int(e[0])] = e
		for d in _timeline_children.keys():
			if not want.has(d):
				_remove_timeline_child(d)
	# Add / update.
	for e in row:
		var d: int = e[0]
		var pidx: int = e[1]
		var birth: int = e[2]
		var child: FlashDisplayObject = _timeline_children.get(d)
		if child != null and child._place_index == pidx and child._birth == birth:
			continue   # the same placement: nothing to do
		var place: Dictionary = places[pidx]
		if child != null and (child._birth != birth or child._char_id != int(place["c"])):
			_remove_timeline_child(d)
			child = null
		if child == null:
			child = Flash.create_char(_library, int(place["c"]), self, place, pidx, d, birth)
			if child == null:
				continue
			child._depth = d
			child._birth = birth
			if child._place_index != pidx:
				_apply_place(child, place, pidx, true)
			_timeline_children[d] = child
			_insert_by_depth(child)
			if _in_render_state_chain():
				child._render_state_changed()
			child._on_added()
		elif child._place_index != pidx:
			_apply_place(child, place, pidx, false)
	_frame = f
	if _sym.has("sounds"):
		var snd = _sym["sounds"].get(str(f))
		if snd != null:
			for sid in snd:
				Flash.play_library_sound(_library, int(sid))
	_run_frame_script(f)


func _run_frame_script(f: int) -> void:
	if _in_frame_script:
		return
	var fs = _code_frame_scripts.get(f)
	if fs != null:
		_in_frame_script = true
		fs.call()
		_in_frame_script = false
		return
	var data: Dictionary = _sym.get("fs", {})
	var ops = data.get(str(f))
	if ops == null:
		return
	_in_frame_script = true
	for op in ops:
		match op[0]:
			"stop":
				stop()
			"play":
				play()
			"gotoAndStop":
				_in_frame_script = false
				gotoAndStop(op[1])
				return
			"gotoAndPlay":
				_in_frame_script = false
				gotoAndPlay(op[1])
				return
	_in_frame_script = false


func _apply_place(child: FlashDisplayObject, place: Dictionary, pidx: int, is_new: bool) -> void:
	var old: Dictionary = {}
	if not is_new and child._place_index >= 0:
		old = _sym["places"][child._place_index]
	child._place_index = pidx
	if is_new or place.get("m") != old.get("m"):
		var m = place.get("m")
		if m != null:
			child.set_flash_matrix(m)
		else:
			child.transform = Transform2D.IDENTITY
		# a new child starts where it is placed; one the timeline moves glides there like everything around it
		if is_new or not FlashRectClip.smooth:
			child.reset_physics_interpolation()
	if is_new or place.get("ct") != old.get("ct"):
		var ct = place.get("ct")
		child.colorTransform = FlashColorTransform.from_array(ct) if ct != null else FlashColorTransform.new()
	if child is FlashShape and (is_new or place.get("r", 0) != old.get("r", 0)):
		(child as FlashShape).set_ratio(int(place.get("r", 0)))
	if is_new or place.get("n", "") != old.get("n", ""):
		var n: String = place.get("n", "")
		if n != "" or is_new:
			_rename_child(child, n)
	if is_new or place.get("cd", 0) != old.get("cd", 0):
		child._clip_depth = int(place.get("cd", 0))
		child._mask_hidden = child._clip_depth > 0 or not child._masking.is_empty()
		_mark_tree_dirty()
	if is_new or place.get("bl", "normal") != old.get("bl", "normal") or place.get("f") != old.get("f"):
		var bl: String = place.get("bl", "normal")
		var f = place.get("f")
		if bl != "normal" or f != null or not is_new:
			child._blend_mode = bl
			child._filters = FlashFilter.from_swf_list(f) if f != null else []
			FlashProxy.update_for(child)
	if is_new or place.get("v", 1) != old.get("v", 1):
		child.visible = int(place.get("v", 1)) != 0


func _rename_child(child: FlashDisplayObject, n: String) -> void:
	var prev := child.flash_name
	if prev != "" and _named.get(prev) == child:
		_named.erase(prev)
		_bind_property(prev, null)
	child.flash_name = n
	if n != "":
		child.name = n
		if not _named.has(n):
			_named[n] = child
		_bind_property(n, child)


## AS3 automatically declares stage instances as properties of the owning class.
func _bind_property(n: String, value) -> void:
	if Flash.is_bindable_property(self, n):
		set(n, value)
	elif n == "hitArea":
		# The instance name assignment (this.hitArea = child) sets Sprite.hitArea in Flash.
		hitArea = value


func _insert_by_depth(child: FlashDisplayObject) -> void:
	var d := child._depth
	var idx := -1
	for i in _children.size():
		var c: FlashDisplayObject = _children[i]
		if c._depth >= 0 and _timeline_children.get(c._depth) == c and c._depth < d:
			idx = i
	if idx >= 0:
		_children.insert(idx + 1, child)
	else:
		var placed := false
		for i in _children.size():
			var c: FlashDisplayObject = _children[i]
			if c._depth > d and _timeline_children.get(c._depth) == c:
				_children.insert(i, child)
				placed = true
				break
		if not placed:
			# No timeline siblings: script-added children always sit above timeline content.
			_children.insert(0, child)
	child._flash_parent = self
	xf_epoch += 1
	_mark_tree_dirty()
	_sync_tree()
	_hb_child_added(child)


func _remove_timeline_child(d: int) -> void:
	var child: FlashDisplayObject = _timeline_children[d]
	_timeline_children.erase(d)
	if child.flash_name != "" and _named.get(child.flash_name) == child:
		_named.erase(child.flash_name)
		_bind_property(child.flash_name, null)
	if child._flash_parent == self:
		_detach(child)
		child._on_removed()
		# Flash garbage-collects it; Godot nodes must be freed explicitly (unless a script re-adds it this tick).
		Flash.release_if_orphaned(child)


# A script that removes a timeline child takes it out of timeline control (Flash behaviour).
func _detach(child: FlashDisplayObject) -> void:
	if child._depth >= 0 and _timeline_children.get(child._depth) == child:
		_timeline_children.erase(child._depth)
	super._detach(child)
