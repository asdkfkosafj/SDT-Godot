Test plugins for `game/debug/ext_checks.gd` (run by `tools/regress.sh`, which copies them into a throwaway
`Mods/Plugins` folder). `example` is a working plugin; the others are deliberately broken.
`newer_api` asks for an extension API the game does not have; `unknown_point` hooks names the game has no point for.
`faulty` raises script errors when told to (the guard switches it off); `crashed` is named in a crash note, as if the
game had crashed while its code ran.
