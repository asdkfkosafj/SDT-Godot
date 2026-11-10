extends SceneTree
## Compares the pictures of a regress run with the image goldens (tools/regress.sh runs it headless):
##   godot --headless -s tools/image_compare.gd -- <golden folder> <new folder> <diff folder>
## Prints one line per picture: "ok", "DIFF <n> pixels ..." (and writes <diff folder>/<name>.png: the golden
## darkened, differing pixels in red), "NEW" (no golden yet) or "MISSING" (golden without a new picture). Exit code 1
## when anything is not ok.

## A pixel differs when one of its channels moved by more than this (out of 255): small rounding differences
## between GPU drivers stay below it.
const DELTA := 8
## Differing pixels a picture may have and still pass.
const MAX_PIXELS := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		printerr("usage: -s tools/image_compare.gd -- <golden folder> <new folder> <diff folder>")
		quit(2)
		return
	quit(_compare_all(a[0], a[1], a[2]))


func _compare_all(golden: String, got: String, diffs: String) -> int:
	var fail := 0
	var names := {}
	for f in DirAccess.get_files_at(got):
		if f.ends_with(".webp"):
			names[f] = true
	for f in DirAccess.get_files_at(golden):
		if f.ends_with(".webp"):
			names[f] = true
	var keys := names.keys()
	keys.sort()
	for f in keys:
		var gp := golden.path_join(f)
		var np := got.path_join(f)
		if not FileAccess.file_exists(np):
			print("MISSING %s (a golden with no new picture)" % f)
			fail = 1
		elif not FileAccess.file_exists(gp):
			print("NEW  %s (no reference yet: run with --update to add it)" % f)
			fail = 1
		elif not _compare(gp, np, diffs.path_join(f.get_basename() + ".png"), f):
			fail = 1
	return fail


func _compare(golden_path: String, new_path: String, diff_path: String, label: String) -> bool:
	if FileAccess.get_file_as_bytes(golden_path) == FileAccess.get_file_as_bytes(new_path):
		print("ok   %s" % label)
		return true
	var g := Image.load_from_file(golden_path)
	var n := Image.load_from_file(new_path)
	if g == null or n == null:
		print("DIFF %s: cannot read the pictures" % label)
		return false
	if g.get_size() != n.get_size():
		print("DIFF %s: size %s, golden %s" % [label, n.get_size(), g.get_size()])
		return false
	g.convert(Image.FORMAT_RGBA8)
	n.convert(Image.FORMAT_RGBA8)
	var gd := g.get_data()
	var nd := n.get_data()
	var w := g.get_width()
	var count := 0
	var worst := 0
	var box := Rect2i()
	var diff := Image.create_empty(w, g.get_height(), false, Image.FORMAT_RGBA8)
	var i := 0
	while i < gd.size():
		var d := maxi(maxi(absi(gd[i] - nd[i]), absi(gd[i + 1] - nd[i + 1])),
				maxi(absi(gd[i + 2] - nd[i + 2]), absi(gd[i + 3] - nd[i + 3])))
		var x := (i / 4) % w
		var y := (i / 4) / w
		if d > DELTA:
			count += 1
			worst = maxi(worst, d)
			box = Rect2i(x, y, 1, 1) if box.size == Vector2i.ZERO else box.expand(Vector2i(x, y))
			diff.set_pixel(x, y, Color(1, 0, 0))
		else:
			worst = maxi(worst, d)
			diff.set_pixel(x, y, Color8(gd[i] / 3, gd[i + 1] / 3, gd[i + 2] / 3))
		i += 4
	if count <= MAX_PIXELS:
		print("ok   %s (largest change %d/255, within the tolerance)" % [label, worst])
		return true
	diff.save_png(diff_path)
	print("DIFF %s: %d pixels differ (%.3f%%), largest change %d/255, in %s; red = changed: %s" % [label, count,
			100.0 * count / (w * g.get_height()), worst, box, diff_path])
	return false
