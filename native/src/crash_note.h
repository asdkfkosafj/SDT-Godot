#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

// Crash note for plugins (see game/src/ext/extensions.gd, "guard"): the game tells it which plugin's code runs on
// the main thread; if the game crashes meanwhile (an access violation in a plugin's script, for example: release
// builds have no null checks in GDScript), it writes that plugin's id to a file. The next start reads the file and
// switches the plugin off. Windows only for now (a vectored exception handler); elsewhere install() returns false.
class SDTCrashNote : public RefCounted {
	GDCLASS(SDTCrashNote, RefCounted)

protected:
	static void _bind_methods();

public:
	// Starts watching: `path` is the file to write on a crash (an absolute, native path). Returns false where
	// crash notes are not supported. The thread that calls it counts as the main thread.
	bool install(const String &p_path);
	// Stops watching (at a clean exit).
	void uninstall();
	// Gives a plugin a number (1..255) for set_running.
	void name_plugin(int64_t p_number, const String &p_id);
	// The plugin whose code runs now (its number), or 0 when none does.
	void set_running(int64_t p_number);
};
