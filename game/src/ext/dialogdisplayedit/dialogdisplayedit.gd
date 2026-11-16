extends SDTExtension
## Built-in reimplementation of the Loader mod dialogdisplayedit (sby, v7): colours and opacity of the dialogue box
## and its text per line style, extra styles, and colour changes from dialogue lines. Written from its documentation
## and behaviour. Speak, Thought and Him keep the game's colours until recoloured (the colours offered are those of
## sby's Loader pack); the Alt styles use the pack's colours.
##
## - Styles Speak / Thought / Him get their own box and text colours and opacity (settings).
## - {"style":"SpeakAlt1"} ... "ThoughtAlt3", "HimAlt3": the Alt 1-3 colours, spoken / thought / his box as named.
## - {"style":"SpeakCustom"} / "ThoughtCustom" / "HimCustom": colours set by the dialogue with
##   [dialogdisplayedit_setspeakcustomstyle_<box RRGGBB>_<text RRGGBB>] (sethimcustomstyle, setthoughtcustomstyle).
## - [dialogdisplayedit_speak_<colour>] (him, thought): a named colour (red, orange, yellow, limegreen, green,
##   aquamarine, cyan, skyblue, blue, purple, magenta, pink) until the dialogue changes it again; "initialsettings"
##   goes back to the settings' colours, "default" to the game's.
## - A line with only actions (no words) does not show an empty box.
## Opacity multiplies the game's (0..3; above 1 makes the see-through box more solid).
## With the Subtitles look (extension subtitles) there is no box: the box colour and opacity apply to its shade.

const NAMED := {"red": Color8(255, 50, 50), "orange": Color8(255, 128, 50), "yellow": Color8(255, 255, 50),
	"limegreen": Color8(128, 255, 50), "green": Color8(50, 255, 50), "aquamarine": Color8(50, 255, 128),
	"cyan": Color8(50, 255, 255), "skyblue": Color8(50, 128, 255), "blue": Color8(50, 50, 255),
	"purple": Color8(128, 50, 255), "magenta": Color8(255, 50, 255), "pink": Color8(255, 50, 128)}
## Style -> [label, recolour box, box colour, box opacity, recolour text, text colour, text opacity]
const STYLES := {
	"speak": ["Her (Speak)", false, Color8(255, 230, 230), 1.0, false, Color8(0, 0, 0), 1.0],
	"thought": ["Thought", false, Color8(250, 250, 250), 1.0, false, Color8(0, 0, 0), 1.0],
	"him": ["Him", false, Color8(160, 165, 185), 1.0, false, Color8(20, 20, 20), 1.0],
	"alt1": ["Alt 1", true, Color8(0, 250, 0), 1.0, true, Color8(0, 0, 0), 1.0],
	"alt2": ["Alt 2", true, Color8(150, 150, 0), 1.0, true, Color8(0, 0, 0), 1.0],
	"alt3": ["Alt 3", true, Color8(150, 0, 200), 1.0, true, Color8(0, 0, 0), 1.0],
}
const FRAME_STYLE := {1: "speak", 2: "thought", 3: "him"}

## Changes made by the dialogue: style -> [box Color or null (the game's), text Color or null]
var _override := {}
var _custom := {"speak": [Color.BLACK, Color.BLACK], "him": [Color.BLACK, Color.BLACK], "thought": [Color.BLACK, Color.BLACK]}


func _init() -> void:
	id = "dialogdisplayedit"
	title = "dialogdisplayedit"
	description = "Colours and opacity of the dialogue box per line style, Alt and Custom styles, colour changes from dialogue lines; no empty box for lines with only actions."
	default_enabled = true


func _setup() -> void:
	for st in STYLES:
		var d: Array = STYLES[st]
		var grp: String = d[0]
		setting(st + "_box_recolour", d[1], {"label": "Recolour the box", "group": grp,
			"desc": "Off: the game's box colour."})
		setting(st + "_box", d[2], {"label": "Box colour", "group": grp})
		setting(st + "_box_alpha", d[3], {"label": "Box opacity", "group": grp, "min": 0.0, "max": 3.0, "step": 0.1})
		setting(st + "_text_recolour", d[4], {"label": "Recolour the text", "group": grp,
			"desc": "Off: the game's text colour."})
		setting(st + "_text", d[5], {"label": "Text colour", "group": grp})
		setting(st + "_text_alpha", d[6], {"label": "Text opacity", "group": grp, "min": 0.0, "max": 3.0, "step": 0.1})


func _enable() -> void:
	_override.clear()
	# before DialogueActions looks at the line's words (its single-trigger and instant lines)
	hook_after(&"Dialogue.startSpeakingPhrase", func(c): _line_started(c.obj, c.args[0]), -5)
	_apply(g.dialogueControl, "speak", 0)


func _disable() -> void:
	var dc = g.dialogueControl
	if dc != null and dc.numChildren > 0:
		dc.getChildAt(0).colorTransform = FlashColorTransform.new()
		dc.tfContainer.colorTransform = FlashColorTransform.new()
		var shade = dc.get_meta(&"subtitle_shade") if dc.has_meta(&"subtitle_shade") else null
		if shade != null and is_instance_valid(shade):
			shade.set_look(null, 1.0)


func _setting_changed(_key: String, _value) -> void:
	var dc = g.dialogueControl
	if dc != null and dc.showingText:
		_apply(dc, FRAME_STYLE.get(dc.currentFrame, "speak"), 0)


func _line_started(dc: Dialogue, line: DialogueLine) -> void:
	var style: String = line.style if line.style else ""
	var base := ""
	var alt := 0
	if style.begins_with("SpeakAlt") or style == "SpeakCustom":
		base = "speak"
		g.her.setSpeaking(true)
		dc.sayingSpeakingStyle = true
		dc._gotoStyle("speaking")
	elif style.begins_with("ThoughtAlt") or style == "ThoughtCustom":
		base = "thought"
		dc._gotoStyle("thought")
	elif style.begins_with("HimAlt") or style == "HimCustom":
		base = "him"
		dc._gotoStyle("him")
	if base != "":
		if style.ends_with("Custom"):
			alt = 10
		elif style.right(1).is_valid_int():
			alt = int(style.right(1))
	if not dc.showingText:
		return
	var has_words := false
	var kept: Array = []
	for w in dc.words:
		if not w.actionWord:
			has_words = true
		elif w.word.begins_with("[dialogdisplayedit_"):
			_action(w.word.trim_prefix("[").trim_suffix("]").split("_"))
			continue
		kept.append(w)
	dc.words = kept   # its actions are done here, the game would take them for line names
	if not has_words:
		dc.alpha = 0
		dc.fadingIn = false
		return
	_apply(dc, base if base != "" else FRAME_STYLE.get(dc.currentFrame, "speak"), alt)


## [dialogdisplayedit_<style>_<colour>] and [dialogdisplayedit_set<style>customstyle_<box>_<text>]
func _action(parts: PackedStringArray) -> void:
	if parts.size() == 3 and STYLES.has(parts[1]) and FRAME_STYLE.values().has(parts[1]):
		var c := parts[2]
		if c == "initialsettings":
			_override.erase(parts[1])
		elif c == "default":
			_override[parts[1]] = [null, null]
		elif NAMED.has(c):
			_override[parts[1]] = [NAMED[c], Color.BLACK]
	elif parts.size() == 4 and parts[1].begins_with("set") and parts[1].ends_with("customstyle"):
		var st := parts[1].trim_prefix("set").trim_suffix("customstyle")
		if _custom.has(st):
			_custom[st] = [_hex(parts[2]), _hex(parts[3])]


static func _hex(s: String) -> Color:
	var v := 0
	for i in 3:
		var part := s.substr(i * 2, 2)
		v = (v << 8) | (part.hex_to_int() if part.is_valid_hex_number() else 0)
	return Color.hex((v << 8) | 0xFF)


## Colours and opacity for `base` ("speak" / "thought" / "him"); alt 1-3: the Alt colours, 10: the Custom ones.
func _apply(dc: Dialogue, base: String, alt: int) -> void:
	if dc == null or dc.numChildren == 0:
		return
	var st := "alt%d" % alt if alt >= 1 and alt <= 3 else base
	var box = null
	var text = null
	if alt == 10:
		box = _custom[base][0]
		text = _custom[base][1]
	elif _override.has(st):
		box = _override[st][0]
		text = _override[st][1]
	else:
		box = get_setting(st + "_box") if get_setting(st + "_box_recolour") else null
		text = get_setting(st + "_text") if get_setting(st + "_text_recolour") else null
	var alpha_st := st if alt >= 1 and alt <= 3 else base
	dc.tfContainer.colorTransform = _transform(text, get_setting(alpha_st + "_text_alpha"))
	var shade = dc.get_meta(&"subtitle_shade") if dc.has_meta(&"subtitle_shade") else null
	if shade != null and is_instance_valid(shade):   # the Subtitles look (extension subtitles): no box, its shade
		shade.set_look(box, get_setting(alpha_st + "_box_alpha"))
		return
	var bg = dc.getChildAt(0)
	var game_alpha: float = Dialogue.BOX_ALPHA / Dialogue.BOX_FILL_ALPHA[bg._char_id] 		if bg is FlashShape and Dialogue.BOX_FILL_ALPHA.has(bg._char_id) else 1.0   # as Dialogue._gotoStyle sets it
	bg.colorTransform = _transform(box, game_alpha * get_setting(alpha_st + "_box_alpha"))


## A solid colour (null: the picture's own) at `alpha` times the picture's opacity.
static func _transform(c, alpha: float) -> FlashColorTransform:
	if c == null:
		return FlashColorTransform.new(1, 1, 1, alpha)
	return FlashColorTransform.new(0, 0, 0, alpha, c.r8, c.g8, c.b8, 0)
