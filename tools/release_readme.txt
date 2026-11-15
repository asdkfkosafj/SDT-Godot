SDT Godot
=========

A port of the Flash game SDT to the Godot engine. Adult content (18+): the game is sexually explicit.

Playing
-------
Windows: run SDT.exe. Linux: run SDT.x86_64 (from a file manager, or ./SDT.x86_64 in a terminal; if it does not
start, make it executable first: chmod +x SDT.x86_64). Nothing else is needed: the game's art and sounds are
included. Linux needs a graphics driver with Vulkan.

Saves and settings are kept in (shared with development builds):
  Windows  %APPDATA%\Godot\app_userdata\SDT Godot
  Linux    ~/.local/share/godot/app_userdata/SDT Godot

Mods
----
Put mods in the Mods folder next to the program (SDT.exe or SDT.x86_64):
  Mods\Clothing      clothing, body and face mods (.swf, .mod)
  Mods\Hair          hair mods
  Mods\Backgrounds   background mods and images
  Mods\Characters    character files
  Mods\Dialogue      dialogue files
  Mods\Plugins       plugins for the port (the ones the game comes with are here)
New mods show up in the game's menus by themselves. The Mods folder must be a real folder, not a link to another
folder (Windows directory junctions are not followed).

Notes
-----
Windows may warn that the program is from an unknown publisher: the build is not code-signed.
The Linux build is new: please report what does not work (Issues on GitHub).

The game's art, sounds and fonts are converted from the original SDT. Art and sounds from community mods whose
features the port reimplements are included too. They belong to their authors (the original game's author and the
mods' authors). Source code and issues: https://github.com/asdkfkosafj/SDT-Godot
