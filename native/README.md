# SDT native extension

C++ (GDExtension) implementations of the hottest paths of the Flash runtime / game simulation, loaded by the game
from `game/bin/sdt_native.gdextension`. The GDScript code checks `ClassDB.class_exists("SDTNative")` and falls back
to its own (identical, slower) implementation when the library is missing; `--nonative` on the game's command line
forces the GDScript paths (for A/B tests), `--checknative` cross-checks native hit tests against GDScript.

Currently native:
- `SDTNative.build_strand` - Strand.renderStrand / generateInterpolationPoints as one vertex-coloured mesh (gradient
  stops reproduced exactly by splitting triangles at the stop lines; indexed, bit-identical vertices shared).
- `SDTNative.hit_shape` - shape-flag hit testing (FlashSprite / FlashShape `_hit_shape`) over the display tree;
  `hit_flat` tests against a tree flattened once per tick (many tests of the same body part).
- `SDTFluids` (fluids.cpp) - the spit / cum strands simulated as plain data and drawn as one mesh per strand layer
  (used by StrandControl, with NativeStrand handles for the game); a layer whose mesh input did not change is not
  rebuilt (`get_mesh_changed`).
- `SDTSweat` (sweat.cpp) - the sweat droplets, drawn by one SweatBatch node per body part (used by Sweat.gd).
- `SDTCrashNote` (crash_note.cpp) - notes which plugin's code was running when the game crashed (Windows: a
  vectored exception handler), so the next start can switch it off (game/src/ext/extensions.gd, "guard").

Objects are built per target in `build/template_debug` and `build/template_release`.

## Building (Windows)

Requirements: MinGW-w64 g++ (e.g. the one in Strawberry Perl, `C:\Strawberry\c\bin`, on PATH) and SCons
(`tools/.venv`: `pip install scons`). godot-cpp is a git submodule (`git submodule update --init`).

```
cd native
../tools/.venv/Scripts/scons platform=windows use_mingw=yes target=template_debug -j8     # running from the editor binary
../tools/.venv/Scripts/scons platform=windows use_mingw=yes target=template_release -j8   # exported builds
```

The first build compiles godot-cpp (several minutes). `extension_api.json` is dumped from the engine binary the game
uses (`godot --headless --dump-extension-api`); regenerate it when updating Godot. After the first build, run the
editor or `godot --headless --path game --import` once so Godot registers the extension (.godot/extension_list.cfg).

## Linux

The Linux libraries (`game/bin/sdt_native.linux.template_*.x86_64.so`) are built by GitHub Actions
(`.github/workflows/native-linux.yml`, on Ubuntu 22.04) whenever `native/` changes on main, and committed back by
the github-actions bot: pull after pushing a native change. It can also be run by hand from the Actions tab. To build
on a Linux machine instead (g++ and SCons):

```
cd native
scons platform=linux target=template_debug -j8
scons platform=linux target=template_release -j8
```
