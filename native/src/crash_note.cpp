// Crash note for plugins: see crash_note.h.

#include "crash_note.h"

#include <godot_cpp/core/class_db.hpp>

#include <cstring>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace {

constexpr int MAX_PLUGINS = 256;
constexpr int MAX_ID = 128;

// Plain static storage: the exception handler must not allocate or take locks.
char g_ids[MAX_PLUGINS][MAX_ID] = {};
volatile int g_running = 0;

#ifdef _WIN32
wchar_t g_path[1024] = {};
DWORD g_main_thread = 0;
PVOID g_handler = nullptr;

bool is_crash(DWORD code) {
	switch (code) {
		case EXCEPTION_ACCESS_VIOLATION:
		case EXCEPTION_STACK_OVERFLOW:
		case EXCEPTION_ILLEGAL_INSTRUCTION:
		case EXCEPTION_PRIV_INSTRUCTION:
		case EXCEPTION_INT_DIVIDE_BY_ZERO:
		case EXCEPTION_IN_PAGE_ERROR:
		case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:
			return true;
		default:
			return false;
	}
}

// Runs first for every exception of the process. Only notes crash-type exceptions on the main thread while a
// plugin runs, and always lets the normal handling go on (Godot's crash handler, or whoever handles it). An
// exception that is handled after all leaves a note behind; the game deletes it again when it quits cleanly.
LONG CALLBACK crash_handler(PEXCEPTION_POINTERS p_info) {
	const int running = g_running;
	if (running <= 0 || running >= MAX_PLUGINS || g_ids[running][0] == 0 || g_path[0] == 0) {
		return EXCEPTION_CONTINUE_SEARCH;
	}
	if (p_info == nullptr || p_info->ExceptionRecord == nullptr || !is_crash(p_info->ExceptionRecord->ExceptionCode)) {
		return EXCEPTION_CONTINUE_SEARCH;
	}
	if (GetCurrentThreadId() != g_main_thread) {
		return EXCEPTION_CONTINUE_SEARCH;
	}
	HANDLE f = CreateFileW(g_path, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
	if (f != INVALID_HANDLE_VALUE) {
		DWORD written = 0;
		WriteFile(f, g_ids[running], (DWORD)strlen(g_ids[running]), &written, nullptr);
		CloseHandle(f);
	}
	return EXCEPTION_CONTINUE_SEARCH;
}
#endif

} // namespace

void SDTCrashNote::_bind_methods() {
	ClassDB::bind_method(D_METHOD("install", "path"), &SDTCrashNote::install);
	ClassDB::bind_method(D_METHOD("uninstall"), &SDTCrashNote::uninstall);
	ClassDB::bind_method(D_METHOD("name_plugin", "number", "id"), &SDTCrashNote::name_plugin);
	ClassDB::bind_method(D_METHOD("set_running", "number"), &SDTCrashNote::set_running);
}

bool SDTCrashNote::install(const String &p_path) {
#ifdef _WIN32
	const Char16String wide = p_path.utf16();
	const int n = wide.length();
	if (n <= 0 || n >= (int)(sizeof(g_path) / sizeof(g_path[0]))) {
		return false;
	}
	for (int i = 0; i < n; i++) {
		g_path[i] = (wchar_t)wide.get_data()[i];
	}
	g_path[n] = 0;
	g_main_thread = GetCurrentThreadId();
	if (g_handler == nullptr) {
		g_handler = AddVectoredExceptionHandler(1, crash_handler);
	}
	return g_handler != nullptr;
#else
	return false;
#endif
}

void SDTCrashNote::uninstall() {
	g_running = 0;
#ifdef _WIN32
	if (g_handler != nullptr) {
		RemoveVectoredExceptionHandler(g_handler);
		g_handler = nullptr;
	}
	g_path[0] = 0;
#endif
}

void SDTCrashNote::name_plugin(int64_t p_number, const String &p_id) {
	if (p_number <= 0 || p_number >= MAX_PLUGINS) {
		return;
	}
	const CharString utf8 = p_id.utf8();
	const int n = utf8.length() < MAX_ID - 1 ? utf8.length() : MAX_ID - 1;
	memcpy(g_ids[p_number], utf8.get_data(), n);
	g_ids[p_number][n] = 0;
}

void SDTCrashNote::set_running(int64_t p_number) {
	g_running = (p_number > 0 && p_number < MAX_PLUGINS) ? (int)p_number : 0;
}
