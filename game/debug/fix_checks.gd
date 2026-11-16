extends RefCounted
## Scripted checks (main.gd --driver, use with --save-dir): an overwriting mod clearing the layer with a
## character's rope hair, then hair / character changes after the killed elements' disposal delay (used to hit freed
## objects); text decoding; characters without a glyph in the dialogue font; Flash .sol import guard (SDT_SOL_DIR).
## Run by tools/regress.sh; prints "CHECK ok / FAIL <name>" and "FIX CHECKS: n passed, m failed".

var _android := -1
var _pass := 0
var _fail := 0


func _check(name: String, ok: bool, detail = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("CHECK %s %s%s" % ["ok  " if ok else "FAIL", name, "" if ok or str(detail) == "" else " (%s)" % str(detail)])


## What `_info` prints is not checked (values to read, e.g. the .sol import with SDT_SOL_DIR).
func _info(name: String, v) -> void:
	print("INFO %s: %s" % [name, v])


## Every rope element of the character still valid (none freed while still listed).
func _elements_valid() -> bool:
	var els: Array = g.characterControl.currentElements
	return els.filter(func(e): return is_instance_valid(e)).size() == els.size()


func step(frame: int) -> void:
	match frame:
		20:
			Flash.stage.getChildAt(0).playClicked()
			_decoding()
			_sol()
		40:
			for i in g.characterControl.characters.size():
				if g.characterControl.characters[i].get_script().get_global_name() == "Android18":
					_android = i
			g.characterControl.setChar(_android, false)
			_check("Android 18 has her rope elements", g.characterControl.currentElements.size() > 0,
				g.characterControl.currentElements.size())
			_missing_glyphs()
		100:
			# what an overwriting HAIR_COSTUME / dynamic-hair mod does to the layer holding the character's ropes
			g.customElementLoader._clearTarget(g.hairOverLayer)
		101:
			_check("rope elements valid after an overwriting hair mod cleared their layer", _elements_valid())
		400:
			_check("rope elements valid after the disposal delay", _elements_valid())
			g.characterControl.randomCurrentElements()
			g.inGameMenu._stepHair(-1)
			var hair := [g.inGameMenu.hairModIndex, g.characterControl.currentHair]
			_check("hair picker steps back from the first hair to the last built-in one", hair == [-1, 11], hair)
		420:
			g.characterControl.setChar(0, false)
			_check("no hair mod after a character change", g.inGameMenu.hairModIndex == -1, g.inGameMenu.hairModIndex)
		440:
			g.inGameMenu._stepBG(4)
			_check("background picker without mods: no mod background", g.inGameMenu.bgModIndex == -1, g.inGameMenu.bgModIndex)
			g.characterControl.setBackground(2)
			var bg := [g.inGameMenu.bgModIndex, g.inGameMenu.bgPicker.itemLabel.text]
			_check("setBackground shows the background's name in the picker", bg == [-1, "Dungeon"], bg)
		700:
			_info("orphans", Flash.orphan_stats(5))
			print("FIX CHECKS: %d passed, %d failed" % [_pass, _fail])
			Flash.get_tree().quit()


## Dialogue "delay characters": a character the embedded dialogue font has no glyph for (Б) shows as nothing,
## as in Flash, but stays in the field's text (one typing step each).
func _missing_glyphs() -> void:
	var field: FlashTextField = g.dialogueControl.tfContainer.dialogueField
	var old := field.text
	field.text = "Oh ББББ my é"
	var shown: String = field._control.text
	_check("dialogue field hides characters its font has no glyph for", shown == "Oh  my é", shown)
	_check("dialogue field text keeps those characters", field.text == "Oh ББББ my é", field.text)
	field.text = old


func _decoding() -> void:
	# [bytes, the code points expected]: invalid UTF-8 is read as Windows-1252, byte by byte
	var cases := {
		"utf8": ["héllo ünïcode".to_utf8_buffer(), [104, 233, 108, 108, 111, 32, 252, 110, 239, 99, 111, 100, 101]],
		"utf8 bom": [PackedByteArray([0xEF, 0xBB, 0xBF]) + "abc".to_utf8_buffer(), [97, 98, 99]],
		"utf16le": [PackedByteArray([0xFF, 0xFE, 0x61, 0x00, 0xE9, 0x00]), [97, 233]],
		"utf16be": [PackedByteArray([0xFE, 0xFF, 0x00, 0x61, 0x00, 0xE9]), [97, 233]],
		"cp1252": [PackedByteArray([0x61, 0x84, 0x41, 0xE9, 0x62]), [97, 8222, 65, 233, 98]],
		"overlong": [PackedByteArray([0x61, 0xE0, 0x80, 0x80, 0x62]), [97, 224, 8364, 8364, 98]],
		"surrogate": [PackedByteArray([0xED, 0xA0, 0x80]), [237, 160, 8364]],
		"mixed": ["ok ".to_utf8_buffer() + PackedByteArray([0x93]) + " ünï".to_utf8_buffer(),
			[111, 107, 32, 8220, 32, 252, 110, 239]],
	}
	for k in cases:
		var s: String = Flash.bytes_to_string(cases[k][0])
		var got := Array(s.to_utf32_buffer().to_int32_array())
		_check("decode " + k, got == cases[k][1], got)


## Folder of a Flash save to test the .sol import with (SDT_SOL_DIR environment variable, e.g.
## %APPDATA%/Macromedia/Flash Player/#SharedObjects/<id>/localhost/<path>/SDT.swf); skipped when not set.
func _sol() -> void:
	var dir := OS.get_environment("SDT_SOL_DIR")
	if dir == "":
		_info("sol", "skipped (SDT_SOL_DIR not set)")
		return
	for f in ["ChoIrrumatio.sol", "ChoIrrumatio_thumbs.sol"]:
		var p := dir.path_join(f)
		if not FileAccess.file_exists(p):
			_info("sol " + f, "missing")
			continue
		AMF3.lastError = ""
		var r = g.inGameMenu._storedCharsFromSol(FileAccess.get_file_as_bytes(p), p)
		_info("sol " + f, "%s err=%s" % [r.size() if r is Array else r, AMF3.lastError])
