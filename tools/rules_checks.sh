#!/usr/bin/env bash
# Rule checks: pins ported game rules (breath, passing out, mouth resistance, pleasure and finish, automatic modes)
# to the original ActionScript, each expected value citing its source line (game/debug/rules_checks.gd).
# Runs the game headless, without mods, in Vanilla mode and with a throwaway save, so your own save is never touched.
#
#   tools/rules_checks.sh             run the checks, print each failure and a summary
#   tools/rules_checks.sh --verbose   also print the passing checks
#
# Needs GODOT (path to the Godot console executable) or godot on PATH. Exit code 0 when every check passes.
# The run is stopped after RULES_TIMEOUT seconds (default 120).
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
TIMEOUT=${RULES_TIMEOUT:-120}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sdt-rules.XXXXXX")
# Godot's own log goes to the work folder, not the user data folder (that would rotate the player's logs away).
# Godot needs a native path (cygpath on Windows).
LOGS=$WORK
command -v cygpath > /dev/null && LOGS=$(cygpath -m "$WORK")
mkdir -p "$WORK/mods" "$WORK/save"

timeout -k 10 "$TIMEOUT" "$GODOT" --headless --fixed-fps 30 --path game --log-file "$LOGS/godot.log" -- \
	--deterministic --seed=1 --vanilla --save-dir="$LOGS/save" --mods-dir="$LOGS/mods" \
	--driver=res://debug/rules_checks.gd "$@" > "$WORK/rules.log" 2>&1
status=$?

fail=0
grep -E "^RULE (ok|FAIL)" "$WORK/rules.log"
# script errors during the run fail the checks too (Godot's leak reports at exit do not)
if grep -E "SCRIPT ERROR|^ERROR" "$WORK/rules.log" | grep -v "at exit" > /dev/null; then
	echo "FAIL errors during the run:"
	grep -E -A2 "SCRIPT ERROR|^ERROR" "$WORK/rules.log" | grep -v "at exit" | head -12
	fail=1
fi
if [ "$status" = 0 ] && grep -q "^RULES CHECKS: .* 0 failed" "$WORK/rules.log"; then
	grep "^RULES CHECKS:" "$WORK/rules.log"
else
	[ "$status" = 124 ] && echo "timed out after $TIMEOUT s"
	grep "^RULES CHECKS:" "$WORK/rules.log" || echo "no summary line: the checks did not finish (exit code $status)"
	fail=1
fi

if [ $fail = 0 ]; then
	echo "PASS"
	case $WORK in
		*/sdt-rules.*) rm -rf "$WORK" ;;
	esac
else
	echo "FAILED (log kept in $WORK)"
fi
exit $fail
