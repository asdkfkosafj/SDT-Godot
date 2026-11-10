# SDT-Godot

A port of the Flash game *SDT* to the Godot engine (4.7). It aims to stay faithful to the original while being
easier to extend (mods, new features) and running much faster than the Flash version.

**Adult content (18+).** The game is sexually explicit.

The game's art, sounds and fonts are included, already converted from the original `SDT.swf` into
`game/assets/sdt/`, so the original game is not needed to play. Art and sounds from community mods whose features
the port reimplements are included in `game/assets/mods/` (for example DialogueActions' voice clips). They belong
to their authors (the original game's author, and the mods' authors) and are not covered by this repository's
license. If you are a rights holder and want something removed, please open an issue.

## Layout

- `game/`: the Godot project.
  - `game/flash/`: a small Flash runtime (display list, timelines, filters, text, SharedObject; an ActionScript
    interpreter for mod scripts).
  - `game/src/`: the game, ported class by class from the original ActionScript (same class and method names).
  - `game/scenes/main.gd`: entry point, plus the scripted test harness options.
- `native/`: source of the C++ GDExtension for hot paths (see [native/README.md](native/README.md)).
- `game/assets/sdt/`: the converted game assets (shapes, sounds, fonts, timelines in `library.json`).
- `game/assets/mods/`: art and sounds from community mods whose features the port reimplements.
- `game/bin/`: the native extension, prebuilt for Windows (debug and release DLLs) and Linux (debug and release
  `.so`, built by GitHub Actions).
- `.github/workflows/native-linux.yml`: builds the Linux libraries when `native/` changes and commits them.
- `tools/swfconv/`: converts `SDT.swf` into the asset library (only needed to regenerate `game/assets/sdt/`).
- `tools/porting/`: one-off scripts used while porting the ActionScript (kept for reference).
- `Mods/`: created on first run in the repository root (next to `run_debug.bat`; next to the executable in an
  exported build), with `Clothing`, `Hair`, `Backgrounds`, `Characters`, `Dialogue` and `Plugins` folders.
  Vanilla SDT `.swf` and `.mod` mods placed there show up in the in-game pickers.

## Running

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) (the standard version, not .NET).
2. Tell `run_debug.bat` where Godot is, in one of these ways:
   - create `run_debug.local.bat` next to it containing
     `set GODOT=C:\path\to\Godot_v4.7.2-stable_win64_console.exe` (the console version shows the log), or
   - set the `GODOT` environment variable to that path, or
   - copy or rename the Godot executable to `godot.exe` in a folder on PATH.
3. Run `run_debug.bat`. The first run imports the assets once (a few minutes), then the game starts.

You can also open `game/` in the Godot editor and press F5.

On **Linux** (x86_64; not tested yet), `run_debug.sh` does the same as `run_debug.bat`: point it at the Godot 4.7.2
binary (`Godot_v4.7.2-stable_linux.x86_64`, made executable) with the `GODOT` environment variable, a
`run_debug.local.sh` next to it containing `GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64`, or `godot` on PATH,
then run `./run_debug.sh`. It imports the assets on the first run and again after updates. By hand, the same is
`godot --headless --path game --import` (first run and after updating), then `godot --path game`.

The native extension is prebuilt for Linux too. Linux file names are case-sensitive: a character code that names a
mod file with other capital letters than the file has will not find it there. On **macOS** there is no prebuilt
native extension yet: Godot reports the missing library and the game uses its slower GDScript code instead.

## Performance problems

If the game runs slowly, please send `%APPDATA%\Godot\app_userdata\SDT Godot\logs\godot.log` right after
playing (later runs replace it). Its `SYSTEM` line says which renderer and graphics card the game uses and whether
the native extension loaded; a `PERF` line every 30 seconds gives the frame rate and where the time goes (game
ticks or drawing); `HITCH` lines describe single slow frames.

On weak or integrated graphics, Godot's lighter renderer can be faster: `run_debug.bat --rendering-method gl_compatibility`.

## Regenerating the assets (optional)

Only needed to rebuild `game/assets/sdt/` from an original `SDT.swf`. Requirements: Python 3 with `pillow` and
`numpy`, Java and [JPEXS FFDec](https://github.com/jindrapetrik/jpexs-decompiler).

```
python tools/swfconv/convert.py original/SDT.swf game/assets/sdt --scale 2 [--ffdec path/to/ffdec.jar]
python tools/swfconv/fix_hitmasks.py original/SDT.swf game/assets/sdt
python tools/swfconv/supersample.py original/SDT.swf game/assets/sdt
```

The native extension can be rebuilt from source too, see `native/README.md`: the Windows DLLs are built locally
(MinGW), the Linux libraries by GitHub Actions on every change to `native/` (the github-actions bot commits them to
`game/bin/`, so pull after pushing a native change). Without the extension the game falls back to slower GDScript
code.

## Release builds

`GODOT=<Godot 4.7.2 editor> bash tools/make_release.sh` exports a Windows build (Godot's 4.7.2 export templates
needed) into `release/SDT-Godot-<date>-<commit>-windows/`, with the `Mods` folders, the shipped plugins and a
readme for players, and zips it.

## Testing

`game/scenes/main.gd` documents the command-line options for scripted runs (`--eval`, `--driver`, `--shot`,
`--frames`, `--deterministic`, ...). Always pass `--save-dir=<folder>` to test runs so they don't overwrite your
own save. Example:

```
godot --headless --path game -- --save-dir=/tmp/sdt-test --driver=res://debug/stress_costumes.gd
```

`tools/regress.sh` runs the regression tests (Git Bash or any POSIX shell, with `GODOT` set). It plays fixed
scenarios headless (menu, idle, grab and stroking, costume changes, every character, cumming) with sound and timers
following game time, so runs repeat exactly. It compares dumps of the display list and character state with the
references in `tests/golden/`. It runs without mods and with a throwaway save. On Windows it also takes pictures
of the same scenarios in a 1280 x 720 window on a hidden desktop (nothing shows on the screen) and compares them
pixel by pixel with `tests/golden/images/`; a difference leaves a picture of the changed pixels in the work folder.
The references come from one GPU, so another GPU or driver may differ slightly. Options:
- `--update` accepts the current output as the new reference; check `git diff tests/golden` first;
- `--stress` adds the costume stress test and reports memory per round;
- `--mods=<folder>` load-tests every `.swf` mod in a folder;
- `--no-images` skips the pictures.

An intended change to the game's behaviour shows up as a difference: review it, then run `--update`.

`tools/check_all.sh` parse-checks every script. It reports "Identifier not found: Flash / g" for autoloads, which
can be ignored.

## Contributing

Code contributions are licensed under the MIT license (see `LICENSE`).
