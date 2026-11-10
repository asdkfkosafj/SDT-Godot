#!/bin/sh
# Parse-checks every GDScript file in the project (first error per file) without running the game.
cd "$(dirname "$0")/../game" || exit 1
GODOT=${GODOT:-godot}  # path to the Godot 4.7 binary
# One Godot start per file: its log file goes to the temp folder (Godot keeps the last few there), or the
# player's logs in the user data folder would be rotated away.
LOG=${TMPDIR:-/tmp}/sdt-check-godot.log
command -v cygpath > /dev/null && LOG=$(cygpath -m "$LOG")
# the game's scripts, then the plugins (Mods/Plugins, outside the project: by their full path)
PLUGINS=$(cd ../Mods/Plugins 2>/dev/null && pwd)
command -v cygpath > /dev/null && [ -n "$PLUGINS" ] && PLUGINS=$(cygpath -m "$PLUGINS")
for f in $(find flash src scenes debug -name '*.gd' 2>/dev/null | sed 's|^|res://|') \
		$([ -n "$PLUGINS" ] && find "$PLUGINS" -name '*.gd' 2>/dev/null); do
	out=$("$GODOT" --headless --path . --log-file "$LOG" --check-only -s "$f" 2>&1 | grep -A1 'SCRIPT ERROR' | grep -v '^--$' | head -2)
	if [ -n "$out" ]; then
		echo "$out" | paste - - | sed 's/SCRIPT ERROR: //; s/\s*at: GDScript::reload//'
	fi
done
# plugins and built-in extensions writing the game's state directly instead of through value points (see the script)
sh ../tools/check_plugin_writes.sh Mods/Plugins game/src/ext
# the generated list of hook points and value points, and the names extensions and plugins use (see the script)
sh ../tools/gen_hook_points.sh --check
