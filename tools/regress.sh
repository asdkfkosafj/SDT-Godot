#!/usr/bin/env bash
# Regression tests: plays fixed scenarios headless (game/debug/regress.gd) and compares the state dumps with the
# reference dumps in tests/golden/. Runs without mods, in Vanilla mode (no extensions) and with a throwaway save,
# so your own save is never touched.
#
#   tools/regress.sh                 run all scenarios, report differences
#   tools/regress.sh grab cum        run only these scenarios
#   tools/regress.sh --update        accept the current output as the new reference (after checking the diff!)
#   tools/regress.sh --stress        also run the costume stress test and report memory per round
#   tools/regress.sh --mods=<dir>    also load every .swf mod in <dir> (and subfolders) and report failures
#   tools/regress.sh --no-images     skip the image goldens
#
# Image goldens (tests/golden/images/): the same scenarios also run in a window, 1280 x 720, and pictures of the
# window at the dumps listed in game/debug/regress.gd IMAGES are compared with the references pixel by pixel
# (tools/image_compare.gd: tolerance, and a picture of what changed). Windows only: the windows open on a hidden
# desktop (tools/hidden_desktop.ps1), so nothing shows on the screen. The references come from one GPU; another
# GPU or driver may differ slightly: check the diff pictures, then --update.
#
# Needs GODOT (path to the Godot console executable) or godot on PATH. Each game run is stopped after REGRESS_TIMEOUT
# seconds (default 300): a script that fails to compile leaves the game running without its driver's quit.
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
TIMEOUT=${REGRESS_TIMEOUT:-300}
ROOT=$(pwd)
GOLDEN=$ROOT/tests/golden
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sdt-regress.XXXXXX")
# Godot's own log file goes to the work folder too, not the user data folder: parallel runs would mix their lines
# in one godot.log there and rotate the player's logs away. Godot needs a native path (cygpath on Windows).
LOGS=$WORK
command -v cygpath > /dev/null && LOGS=$(cygpath -m "$WORK")
ALL="menu idle grab costumes characters cum"
update=0
stress=0
mods=""
images=0
command -v powershell.exe > /dev/null && command -v cygpath > /dev/null && images=1
scenarios=""
for a in "$@"; do
	case $a in
		--update) update=1 ;;
		--stress) stress=1 ;;
		--mods=*) mods=${a#--mods=} ;;
		--no-images) images=0 ;;
		-*) echo "unknown option $a"; exit 2 ;;
		*) scenarios="$scenarios $a" ;;
	esac
done
scenarios=${scenarios:-$ALL}
mkdir -p "$WORK/mods" "$WORK/out"

godot() {   # the game, stopped after TIMEOUT seconds (exit code 124)
	timeout -k 10 "$TIMEOUT" "$GODOT" "$@"
}

timed_out() {   # exit code -> " (timed out after N s)" for 124
	[ "$1" = 124 ] && echo " (timed out after ${TIMEOUT} s)"
}

run_game() {   # name, extra args...
	local name=$1; shift
	godot --headless --fixed-fps 30 --path game --log-file "$LOGS/godot_$name.log" -- --deterministic --seed=1 --vanilla \
		--save-dir="$WORK/save_$name" --mods-dir="$WORK/mods" "$@" > "$WORK/$name.log" 2>&1
}

run_pictures() {   # name: the scenario in a window on a hidden desktop, its pictures into $WORK/img
	local name=$1
	mkdir -p "$WORK/save_img_$name"
	printf '[window]\nsize="1280 x 720"\n' > "$WORK/save_img_$name/port.cfg"
	local exe args
	exe=$(cygpath -w "$(command -v "$GODOT")")
	args="--audio-driver Dummy --fixed-fps 30 --path \"$(cygpath -m "$ROOT/game")\" --log-file \"$LOGS/godot_img_$name.log\""
	args="$args -- --deterministic --seed=1 --vanilla --save-dir=\"$LOGS/save_img_$name\" --mods-dir=\"$LOGS/mods\""
	args="$args --driver=res://debug/regress.gd --scenario=$name --out=\"$LOGS/out_img\" --images=\"$LOGS/img\""
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/tools/hidden_desktop.ps1")" \
		-TimeoutSec "$TIMEOUT" -Output "$LOGS/img_$name.log" -CommandLine "\"$exe\" $args"
}

echo "running:$scenarios (work folder $WORK)"
for s in $scenarios; do
	(run_game "$s" --driver=res://debug/regress.gd --scenario="$s" --out="$WORK/out"; echo $? > "$WORK/$s.status") &
	[ $images = 1 ] && (run_pictures "$s"; echo $? > "$WORK/img_$s.status") &
done
# Extension system checks (game/debug/ext_checks.gd); not in Vanilla mode, they switch extensions on and off.
# They load the test plugins from tests/plugins; "crashy" is marked as having crashed the previous start.
mkdir -p "$WORK/mods_ext/Plugins" "$WORK/save_ext/extensions" "$WORK/mods_da"
cp -r tests/plugins/*/ "$WORK/mods_ext/Plugins/"
printf crashy > "$WORK/save_ext/extensions/loading_plugin.txt"
godot --headless --fixed-fps 30 --path game --log-file "$LOGS/godot_ext.log" -- --save-dir="$WORK/save_ext" --mods-dir="$WORK/mods_ext" \
	--driver=res://debug/ext_checks.gd > "$WORK/ext_checks.log" 2>&1 &
ext_pid=$!
# Built-in DialogueActions checks (game/debug/da_checks.gd)
godot --headless --fixed-fps 30 --path game --log-file "$LOGS/godot_da.log" -- --save-dir="$WORK/save_da" --mods-dir="$WORK/mods_da" \
	--driver=res://debug/da_checks.gd > "$WORK/da_checks.log" 2>&1 &
da_pid=$!
# New in-game menu checks (game/debug/menu_checks.gd)
mkdir -p "$WORK/mods_menu"
godot --headless --fixed-fps 30 --path game --log-file "$LOGS/godot_menu.log" -- --save-dir="$WORK/save_menu" --mods-dir="$WORK/mods_menu" 	--driver=res://debug/menu_checks.gd > "$WORK/menu_checks.log" 2>&1 &
menu_pid=$!
wait "$ext_pid"; ext_status=$?
wait "$da_pid"; da_status=$?
wait "$menu_pid"; menu_status=$?
wait   # the scenarios

fail=0
for s in $scenarios; do
	# Errors during the run count as failures (Godot's leak reports at exit do not).
	if grep "ERROR" "$WORK/$s.log" | grep -v "at exit" > /dev/null; then
		echo "FAIL $s: errors during the run (see $WORK/$s.log):"
		grep -A3 "ERROR" "$WORK/$s.log" | grep -v "at exit" | head -12
		fail=1
	fi
	got=$(ls "$WORK/out" | grep "^${s}_" || true)
	if [ -z "$got" ]; then
		echo "FAIL $s: no dumps written$(timed_out "$(cat "$WORK/$s.status" 2> /dev/null)") (see $WORK/$s.log)"
		fail=1
		continue
	fi
	for f in $got; do
		if [ $update = 1 ]; then
			mkdir -p "$GOLDEN"
			cp "$WORK/out/$f" "$GOLDEN/$f"
		elif [ ! -f "$GOLDEN/$f" ]; then
			echo "NEW  $f (no reference yet: run with --update to add it)"
			fail=1
		elif ! diff -q "$GOLDEN/$f" "$WORK/out/$f" > /dev/null; then
			n=$(diff "$GOLDEN/$f" "$WORK/out/$f" | grep -c '^[<>]')
			echo "DIFF $f ($n lines differ):"
			diff "$GOLDEN/$f" "$WORK/out/$f" | head -20
			fail=1
		else
			echo "ok   $f"
		fi
	done
done
# Script errors fail the checks too, except the deliberate ones (the broken test plugins, a duplicate id).
script_errors() {   # each error line with the "at:" line after it
	awk '/SCRIPT ERROR|^ERROR/ { e = $0; getline n; print e " | " n }' "$1" \
		| grep -v -E "at exit|gdscript://|mods_ext/Plugins|missing or duplicate id|already used|contains ';'|has errors|uses class_name" | head -5
}
if [ -n "$(script_errors "$WORK/ext_checks.log")" ] || [ -n "$(script_errors "$WORK/da_checks.log")" ] 		|| [ -n "$(script_errors "$WORK/menu_checks.log")" ]; then
	echo "FAIL script errors in the checks:"
	script_errors "$WORK/ext_checks.log"
	script_errors "$WORK/da_checks.log"
	script_errors "$WORK/menu_checks.log"
	fail=1
fi
if [ "$ext_status" = 0 ] && grep -q "^EXT CHECKS: .* 0 failed" "$WORK/ext_checks.log"; then
	echo "ok   extension checks ($(grep -c '^CHECK ok' "$WORK/ext_checks.log") passed)"
else
	echo "FAIL extension checks, exit code $ext_status$(timed_out $ext_status) (see $WORK/ext_checks.log):"
	grep -E "^CHECK FAIL|SCRIPT ERROR" "$WORK/ext_checks.log" | head -12
	fail=1
fi
if [ "$da_status" = 0 ] && grep -q "^DA CHECKS: .* 0 failed" "$WORK/da_checks.log"; then
	echo "ok   DialogueActions checks ($(grep -c '^CHECK ok' "$WORK/da_checks.log") passed)"
else
	echo "FAIL DialogueActions checks, exit code $da_status$(timed_out $da_status) (see $WORK/da_checks.log):"
	grep -E "^CHECK FAIL|SCRIPT ERROR" -A1 "$WORK/da_checks.log" | head -16
	fail=1
fi
if [ "$menu_status" = 0 ] && grep -q "^MENU CHECKS: .* 0 failed" "$WORK/menu_checks.log"; then
	echo "ok   menu checks ($(grep -c '^CHECK ok' "$WORK/menu_checks.log") passed)"
else
	echo "FAIL menu checks, exit code $menu_status$(timed_out $menu_status) (see $WORK/menu_checks.log):"
	grep -E "^CHECK FAIL|SCRIPT ERROR" -A1 "$WORK/menu_checks.log" | head -16
	fail=1
fi
if [ $images = 1 ]; then
	mkdir -p "$WORK/img" "$WORK/img_golden" "$WORK/img_diff" "$GOLDEN/images"
	for s in $scenarios; do
		st=$(cat "$WORK/img_$s.status" 2> /dev/null)
		if [ "$st" != 0 ] || grep "ERROR" "$WORK/img_$s.log" | grep -v "at exit" > /dev/null; then
			echo "FAIL $s pictures: exit code $st$(timed_out "$st") (see $WORK/img_$s.log):"
			grep -A3 "ERROR" "$WORK/img_$s.log" | grep -v "at exit" | head -12
			fail=1
		fi
		if [ $update = 1 ]; then
			rm -f "$GOLDEN/images/${s}_"*.webp
			cp "$WORK/img/${s}_"*.webp "$GOLDEN/images/" 2> /dev/null
		else
			cp "$GOLDEN/images/${s}_"*.webp "$WORK/img_golden/" 2> /dev/null
		fi
	done
	if [ $update = 0 ]; then
		"$GODOT" --headless --log-file "$LOGS/godot_compare.log" -s tools/image_compare.gd -- "$LOGS/img_golden" \
			"$LOGS/img" "$LOGS/img_diff" 2>&1 | grep -E "^(ok|DIFF|NEW|MISSING)|ERROR" \
			| sed -E 's/^(ok   |DIFF |NEW  |MISSING )/\1image /'
		[ "${PIPESTATUS[0]}" = 0 ] || fail=1
	fi
else
	echo "skip image goldens (Windows only, or --no-images)"
fi
[ $update = 1 ] && echo "references updated in tests/golden/ (review with git diff before committing)"

if [ $stress = 1 ]; then
	echo "stress test (4 rounds of every picker and character)..."
	run_game stress --driver=res://debug/stress_costumes.gd
	grep "^STRESS" "$WORK/stress.log"
fi

if [ -n "$mods" ]; then
	# Godot needs native paths (Git Bash on Windows passes /c/... style ones).
	command -v cygpath > /dev/null && mods=$(cygpath -m "$mods")
	find "$mods" -iname '*.swf' > "$WORK/modlist.txt"
	echo "loading $(wc -l < "$WORK/modlist.txt") mods from $mods..."
	godot --headless --path game --log-file "$LOGS/godot_mods.log" res://debug/mod_load_test.tscn -- --list="$WORK/modlist.txt" > "$WORK/mods.log" 2>&1
	grep -E "^FAIL|^done" "$WORK/mods.log"
	grep -q "^done: .* 0 failed" "$WORK/mods.log" || fail=1
fi

if [ $fail = 0 ]; then
	echo "PASS"
	rm -rf "$WORK"
else
	echo "FAILED (logs and output kept in $WORK)"
fi
exit $fail
