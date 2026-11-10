// Registration of the SDT native extension: hot paths of the Flash runtime / game simulation in C++.

#include "register_types.h"

#include <gdextension_interface.h>

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "crash_note.h"
#include "fluids.h"
#include "sweat.h"
#include "sdt_native.h"
#include "swf_file.h"

void initialize_sdt_native(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(SDTNative);
	GDREGISTER_CLASS(SWFFile);
	GDREGISTER_CLASS(SDTFluids);
	GDREGISTER_CLASS(SDTSweat);
	GDREGISTER_CLASS(SDTCrashNote);
}

void uninitialize_sdt_native(ModuleInitializationLevel p_level) {
}

extern "C" {
GDExtensionBool GDE_EXPORT sdt_native_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	::godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_sdt_native);
	init_obj.register_terminator(uninitialize_sdt_native);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
