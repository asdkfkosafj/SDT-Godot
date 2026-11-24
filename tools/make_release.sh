#!/usr/bin/env bash
# Builds a release: release/SDT-Godot-<date>-<commit>-<platform>/ and the .zip of it.
#   GODOT=<Godot 4.7.2 editor binary> bash tools/make_release.sh [windows|linux]   (default windows)
# Needs the 4.7.2.stable export templates (Editor > Manage Export Templates) and the export presets in
# game/export_presets.cfg ("Windows Desktop", "Linux"). The Linux build uses the Linux native libraries in game/bin
# (built by the GitHub workflow when native/ changes: pull first). Builds from the working tree: commit first, so the
# name's commit matches the contents.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
PY=tools/.venv/Scripts/python.exe
[ -x "$PY" ] || PY=python3
PLATFORM=${1:-windows}
case $PLATFORM in
	windows) PRESET="Windows Desktop"; BIN=SDT.exe ;;
	linux) PRESET="Linux"; BIN=SDT.x86_64 ;;
	*) echo "unknown platform $PLATFORM (windows or linux)" >&2; exit 2 ;;
esac

DIRTY=false
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
	echo "warning: uncommitted changes are in this build" >&2
	DIRTY=true
fi
DATE=$(date -u +%Y-%m-%d)
COMMIT=$(git rev-parse --short HEAD)
NAME="SDT-Godot-$DATE-$COMMIT-$PLATFORM"
OUT="release/$NAME"
if [ -e "$OUT" ] || [ -e "$OUT.zip" ]; then
	echo "$OUT already exists" >&2
	exit 1
fi
mkdir -p "$OUT"

# the build the game names in its log's SYSTEM line (FlashRuntime.build_id; exported with the *.json files)
INFO=game/build_info.json
trap 'rm -f "$INFO"' EXIT
printf '{"date": "%s", "commit": "%s", "dirty": %s}\n' "$DATE" "$COMMIT" "$DIRTY" > "$INFO"
"$GODOT" --headless --path game --export-release "$PRESET" "$PWD/$OUT/$BIN"
rm -f "$INFO"
[ -f "$OUT/SDT.pck" ] || { echo "export failed" >&2; exit 1; }

# the Mods folder: the game's folders, with the plugins and positions the repository ships (tracked files only)
for d in Clothing Hair Backgrounds Characters Dialogue Plugins Positions; do
	mkdir -p "$OUT/Mods/$d"
done
git ls-files -z Mods/Plugins Mods/Positions | while IFS= read -r -d '' f; do
	mkdir -p "$OUT/$(dirname "$f")"
	cp "$f" "$OUT/$f"
done
cp tools/release_readme.txt "$OUT/README.txt"

# (the program file marked executable in the zip, for Linux: zip entries made on Windows carry no Unix mode)
"$PY" -I -c '
import os, sys, zipfile
out, binary = sys.argv[1], sys.argv[2]
base = os.path.dirname(out)
with zipfile.ZipFile(out + ".zip", "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
	for root, dirs, files in os.walk(out):
		rel = os.path.relpath(root, base)
		if not files and not dirs:
			z.writestr(rel.replace(os.sep, "/") + "/", "")   # keep the empty mod folders
		for f in files:
			p = os.path.join(root, f)
			zi = zipfile.ZipInfo.from_file(p, os.path.relpath(p, base))
			zi.compress_type = zipfile.ZIP_DEFLATED
			zi.create_system = 3   # Unix: the modes below apply
			zi.external_attr = (0o100755 if root == out and f == binary else 0o100644) << 16
			with open(p, "rb") as fh:
				z.writestr(zi, fh.read(), compresslevel=9)
' "$OUT" "$BIN"
ls -la "$OUT" "$OUT.zip"
