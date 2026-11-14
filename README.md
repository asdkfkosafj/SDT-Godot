# SDT-Godot

A port of the Flash game *SDT* to the Godot engine (4.7). It stays faithful to the original game, runs much faster
than the Flash version (no more low frame rates), and is easier to extend with mods and new features.

**Adult content (18+).** The game is sexually explicit.

The original game is not needed: its art, sounds and fonts are included, already converted. See
[Credits and assets](#credits-and-assets) for who they belong to.

## Contents

- [Play it](#play-it)
- [What is new compared to Flash](#what-is-new-compared-to-flash)
- [The menu](#the-menu)
- [Mods](#mods)
- [Bringing your characters from Flash or the Loader](#bringing-your-characters-from-flash-or-the-loader)
- [Saves and settings](#saves-and-settings)
- [If something goes wrong](#if-something-goes-wrong)
- [Running from source](#running-from-source)
- [For developers](#for-developers)
- [Credits and assets](#credits-and-assets)

## Play it

**Windows:**

1. Download the zip of the latest build from the [Releases page](https://github.com/asdkfkosafj/SDT-Godot/releases/latest).
2. Unzip it into a folder of its own (not into `Program Files`: the game writes to its `Mods` folder).
3. Run `SDT.exe`.

Windows may warn that the program is from an unknown publisher: the build is not code-signed. Choose "More info",
then "Run anyway".

**Linux and macOS:** there is no ready-made build yet. Run it from source, see
[Running from source](#running-from-source).

## What is new compared to Flash

- **Speed.** Smooth frame rates at any window size, with a C++ extension for the busiest parts (hair and fluid
  strands, sweat, hit tests). The game logic still runs at the original 30 ticks per second, so it plays the same.
- **Any window size, or fullscreen.** The game fills the window's height.
- **A new menu**, docked on the side of the screen, with search and a help line for every control.
- **Popular Loader mods are built in.** Many mods that needed the Loader (DialogueActions, moremoods, MoreTriggers,
  dialogue display and speed mods, morecumspurts, hairrgb, cumrgb and many more) are reimplemented
  in the game. Each one can be switched on or off in the menu.
- **Plugins.** Larger mods are ported as plugins in `Mods/Plugins` (see [Plugins](#plugins)), and new ones can be
  written in GDScript.
- **Rebindable hotkeys** for every action of the game and of the mods, with Shift, Ctrl or Alt combinations.

## The menu

Move the mouse to the right edge of the screen: a **MENU** tab shows. Click it to open the menu. The sections are:

| Section | What is in it |
|---|---|
| Her | Character, mood, face, body, arms, hair, colours. |
| Clothes | Outfit, clothing by body area, piercings, tan lines. |
| Him | His body, clothes, arms, penis and balls. |
| Scene | Background, camera, auto mode, controls. |
| Behaviour | Her resistance and reactions. |
| Effects | Fluids and marks, and cleaning them up. |
| Dialogue | Dialogue files and how they show. |
| Mods | Loading mods, character codes, the character list, and every extension and plugin with its settings. |
| Settings | Window size, fullscreen, menu, graphics (FPS limit, MSAA), sound, hotkeys. |
| Help | Extensions info and the credits. |

Use the search box when you do not know where an option is. Hover over a control to read what it does.

## Mods

Put mods in the `Mods` folder next to `SDT.exe`:

| Folder | What goes in it |
|---|---|
| `Mods/Clothing` | Clothing, body and face mods (`.swf`, `.mod`) |
| `Mods/Hair` | Hair mods and hair images |
| `Mods/Backgrounds` | Background mods and images |
| `Mods/Characters` | Character files |
| `Mods/Dialogue` | Dialogue files |
| `Mods/Plugins` | Plugins for this port |

New mods show up in the game's pickers by themselves. A `.swf` mod is converted the first time it loads, so it is
a little slower to load the first time only.

**What works:**

- Vanilla SDT mods: art-only `.swf` and `.mod` files (clothing, hair, backgrounds, bodies), image hairs and
  backgrounds, character files, dialogue files.
- Dialogues written for DialogueActions and its add-on mods: the triggers and variables they use are built in.

**What does not work:** Loader *code* mods (mods that change how the game behaves) do not run directly. Many of
them are reimplemented in the game or ported as plugins; the others are skipped when the game loads mods.

### Plugins

The game comes with these plugins in `Mods/Plugins`. Each one can be switched off in **Mods › Extensions**:

- Ports of Loader mods: `armoverhaul`, `autocloseeye`, `autoclosemouth`, `breastfirmness`, `darkenpassout`,
  `deepthroatactions`, `eyemakeup`, `ffbehavior`, `ignoreherclothingpenis`, `progressiveexhaustion`,
  `spankanywhere`.
- New: `xray`, a cutaway view inside her.

To write your own plugin or extension, see [docs/extensions.md](docs/extensions.md).

## Bringing your characters from Flash or the Loader

In **Mods**:

- **Load backup…** reads characters from a backup file, or straight from a Flash save (`ChoIrrumatio.sol`, in
  Flash Player's `#SharedObjects` folder under `%APPDATA%\Macromedia\Flash Player`).
- **Import from the Loader…**: pick your Loader folder. Its stored characters come in together with the clothing
  and hair mods they wear. The files are copied into `Mods` (never over your own files); the Loader folder is only
  read, and the game does not need it afterwards.
- **Replace the list when loading**: off adds the characters to your list, on replaces it.

## Saves and settings

Saves, settings and the cache of converted mods are in `%APPDATA%\Godot\app_userdata\SDT Godot` on Windows
(`~/.local/share/godot/app_userdata/SDT Godot` on Linux). Release builds and builds from source share this folder.
Back up the `.sav` files there to keep your characters safe.

## If something goes wrong

**The game is slow or stutters.** Please open an issue and attach `logs/godot.log` from the save folder above,
right after playing (the next start replaces it). It says which renderer and graphics card the game uses and
whether the C++ extension loaded (`SYSTEM` line), gives the frame rate and where the time goes every 30 seconds
(`PERF` lines), and describes single slow frames (`HITCH` lines).

Things to try first:

- **Settings › Graphics**: set **MSAA** to Off, and set an **FPS limit** (Monitor is a good choice).
- On weak or integrated graphics, Godot's lighter renderer can be faster: start the game with
  `--rendering-method gl_compatibility` (for example `SDT.exe --rendering-method gl_compatibility`, or
  `run_debug.bat --rendering-method gl_compatibility`).

**A plugin causes errors.** A plugin whose code raises an error is switched off for the rest of the session (the
reason shows in **Mods › Extensions**). If a plugin crashes the game (Windows), the game switches it off at the next
start.

**A mod does not show up.** Check that it is in the right folder (see [Mods](#mods)) and that it is not a Loader
code mod. On Linux, file names are case-sensitive: a character code that names a mod file with different capital
letters will not find it.

**Something else is broken or different from Flash.** Please [open an issue](https://github.com/asdkfkosafj/SDT-Godot/issues)
with what you did, what you saw and what you expected.

## Running from source

Use this to play the newest code, or on Linux.

1. Download this repository (Code › Download ZIP, or `git clone https://github.com/asdkfkosafj/SDT-Godot.git`).
2. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) (the standard version, not .NET).
3. Tell the start script where Godot is.

**Windows**, `run_debug.bat`, in one of these ways:

- create `run_debug.local.bat` next to it containing
  `set GODOT=C:\path\to\Godot_v4.7.2-stable_win64_console.exe` (the console version shows the log), or
- set the `GODOT` environment variable to that path, or
- copy or rename the Godot executable to `godot.exe` in a folder on PATH.

Then run `run_debug.bat`. The first run imports the assets once (a few minutes), then the game starts. After an
update it does a quick import (a few seconds) first. You can also
open `game/` in the Godot editor and press F5.

**Linux** (x86_64; not tested much yet), `run_debug.sh`: point it at the Godot 4.7.2 binary
(`Godot_v4.7.2-stable_linux.x86_64`, made executable) with the `GODOT` environment variable, a `run_debug.local.sh`
next to it containing `GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64`, or `godot` on PATH. Then run
`./run_debug.sh`. It imports the assets on the first run and again after updates. By hand, the same is
`godot --headless --path game --import` (first run and after updating), then `godot --path game`.

**macOS**: there is no prebuilt C++ extension yet. Godot reports the missing library and the game uses its slower
GDScript code instead.

## For developers

### Layout

- `game/`: the Godot project.
  - `game/flash/`: a small Flash runtime (display list, timelines, filters, text, SharedObject; an ActionScript
    interpreter for mod scripts).
  - `game/src/`: the game, ported class by class from the original ActionScript (same class and method names).
  - `game/src/ext/`: built-in extensions (reimplemented Loader mods and other additions), kept out of the ported
    classes; `game/src/menu/`: the new menu.
  - `game/scenes/main.gd`: entry point, plus the scripted test harness options.
- `native/`: source of the C++ GDExtension for hot paths (see [native/README.md](native/README.md)).
- `game/assets/sdt/`: the converted game assets (shapes, sounds, fonts, timelines in `library.json`).
- `game/assets/mods/`: art and sounds from community mods whose features the port reimplements.
- `game/bin/`: the native extension, prebuilt for Windows (debug and release DLLs) and Linux (debug and release
  `.so`, built by GitHub Actions).
- `Mods/Plugins/`: the plugins shipped with the game. The rest of `Mods/` is the player's own and not tracked.
- `docs/extensions.md`: the extension and plugin API.
- `tests/golden/`: references for the regression tests.
- `.github/workflows/native-linux.yml`: builds the Linux libraries when `native/` changes and commits them.
- `tools/swfconv/`: converts `SDT.swf` into the asset library (only needed to regenerate `game/assets/sdt/`).
- `tools/porting/`: one-off scripts used while porting the ActionScript (kept for reference).

### Native extension

The native extension can be rebuilt from source, see [native/README.md](native/README.md): the Windows DLLs are
built locally (MinGW), the Linux libraries by GitHub Actions on every change to `native/` (the github-actions bot
commits them to `game/bin/`, so pull after pushing a native change). Without the extension the game falls back to
slower GDScript code.

### Release builds

`GODOT=<Godot 4.7.2 editor> bash tools/make_release.sh` exports a Windows build (Godot's 4.7.2 export templates
needed) into `release/SDT-Godot-<date>-<commit>-windows/`, with the `Mods` folders, the shipped plugins and a
readme for players, and zips it. It builds from the working tree: commit first, so the commit in the name matches
the contents.

### Testing

The top of `game/scenes/main.gd` documents the command-line options for scripted runs (`--shot`, `--frames`,
`--click`, `--eval`, `--driver`, `--save-dir`, `--mods-dir`, `--mod-cache`, `--vanilla`). `--deterministic` (with
Godot's `--fixed-fps 30`) makes timers and sound follow game time, so a run repeats exactly. Always pass
`--save-dir=<folder>` to test runs so they don't overwrite your own save, and Godot's `--log-file` (before `--`) so
they don't rotate your `godot.log` away. Example:

```
godot --headless --path game --log-file /tmp/sdt-test/godot.log -- --save-dir=/tmp/sdt-test --driver=res://debug/stress_costumes.gd
```

`tools/regress.sh` runs the regression tests (Git Bash or any POSIX shell, with `GODOT` set or `godot` on PATH). It
plays fixed scenarios headless (`menu`, `idle`, `grab`, `costumes`, `characters`, `cum`; name some of them to run
only those) with sound and timers following game time, so runs repeat exactly. It compares dumps of the display
list and character state with the references in `tests/golden/`. It runs without mods, in Vanilla mode (no
extensions or plugins) and with a throwaway save. On Windows it also takes pictures
of the same scenarios in a 1280 x 720 window on a hidden desktop (nothing shows on the screen) and compares them
pixel by pixel with `tests/golden/images/`; a difference leaves a picture of the changed pixels in the work folder.
The references come from one GPU, so another GPU or driver may differ slightly. Options:
- `--update` accepts the current output as the new reference; check `git diff tests/golden` first;
- `--stress` adds the costume stress test and reports memory per round;
- `--mods=<folder>` load-tests every `.swf` mod in a folder;
- `--no-images` skips the pictures.

An intended change to the game's behaviour shows up as a difference: review it, then run `--update`.

`tools/rules_checks.sh` pins ported rules to the ActionScript line they come from. `tools/check_all.sh`
parse-checks every script. It reports "Identifier not found: Flash / g" for autoloads, which can be ignored.

### Contributing

Code contributions are licensed under the MIT license (see `LICENSE`). Bug reports and pull requests are welcome.

## Credits and assets

The game's art, sounds and fonts are converted from the original `SDT.swf` into `game/assets/sdt/`. Art and sounds
from community mods whose features the port reimplements are included in `game/assets/mods/` (for example
DialogueActions' voice clips), and the ported plugins credit their mods' authors in their `plugin.cfg`. These assets
belong to their authors (the original game's author, and the mods' authors) and are not covered by this
repository's license. If you are a rights holder and want something removed, please open an issue.

The code is under the MIT license (see `LICENSE`).
