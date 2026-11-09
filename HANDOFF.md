# CoD Legacy (MWR fork) - handoff log

Branch: `bo2-hud` (fork of h1-mod, C++ client + LUI Lua). Owner: sero7k.
Last updated: 2026-11-09.

## Goal
1. Put OUR CLIENT'S HUD (`crates/ui/src/hud_modern.rs` + `hud_match.rs` in CodLegacyClient; NOT the Black Ops II HUD) over MWR's HUD, no toggle, all functions intact. It already exists as LUI: `tools/hmw_hud/ui_scripts/claude_hud/__init__.lua` in CodLegacyClient, now copied to `data/cdata/ui_scripts/claude_hud/` here (replaces the abandoned `bo2_hud`). Its companion `tools/hmw_ui/claude_ui.lua` (menu/palette restyle, resource CLAUDE_UI, must load first) is not ported yet.
2. Then port the pause/scoreboard/class menus and the main menu.
3. Support all HMW usermaps and weapons in the client.
4. Build the exe as `CoD Legacy.exe` into `C:\Users\Gaming PC\Documents\mwr_game_files\`.
5. Later: BO2/BO3/Ghosts maps -> MWR format via translation layers (zonetool), not merged engines.

## Done so far
- (superseded, removed) `bo2_hud/` was a wrong-target BO2 HUD. Old notes:  Closes MWR's teamScores/weaponInfo/actionSlot/experienceBar/perks widgets and adds its own layer to `hud.static.scalable` (score bar, ammo box, streaks, player card, fps box). MWR minimap, obituary, hit markers, damage/low-health overlays, hints, scoreboard, killcam are left alone.
  - Latest change: every part is built in its own pcall, errors are printed to the console as `[bo2_hud] ...`, replaced widgets are also removed from `hud.allWidgets`. Look for `[claude_hud] ...` lines in the in-game console.
- `updater.cpp`: `cg_auto_update` defaults to false.
- Usermap support (uncommitted work at time of writing, see git log): `fastfiles::usermap_dir(name)` resolves `usermaps\` or `hmw-usermaps\`; used by fastfiles, party, ui_scripting `zoneexists`, arena (adds generated arena entries for HMW maps that have no .arena file; MAX_ARENAS is 64 so the map picker may not list all 66 maps, but `map mp_x` works).

## Not done / unknown
- The HUD has never been seen working in game. The user's screenshot (plain stock `h1-mod.exe`, team deathmatch) shows MWR's own HUD, i.e. our layer did not appear (not even the top-right fps box). Cause unknown: check console output for `[bo2_hud]` lines first. The scripts live in `<game>\h1-mod\ui_scripts\bo2_hud\`.
- `Build CoD Legacy.bat` (Desktop on the user's PC) was started once; no `build_codlegacy.txt` log was read. It needs VS 2022 with the C++ workload (VS 2022 Build Tools exist at `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`). Log goes to `C:\Users\Gaming PC\bo2\play\codlegacy-artifacts\logs\build_codlegacy.txt`.
- HMW weapon zones are not loaded yet. `hmw-mod\zone\` holds `hmw_pre_gfx`, `hmw_post_gfx`, `hmw_patch_code_post_gfx_mp`, `hmw_patch_ui_mp`, `hmw_patch_common_mp`, `hmw_files`, `hmw_attachments`, `hmw_ar1/smg/shotgun/rangers/nightshade`, `hmw_killstreak`, `hmw_dlc_*`, `*_hmw_common` (localized). Plan: register `hmw-mod` as a filesystem search path and `try_load_zone()` them from `fastfiles.cpp` (`load_pre_gfx_zones`, `load_post_gfx_and_ui_and_common_zones`); the exact HMW load order is unknown (hmw-mod.exe is closed), attachments probably before weapons.
- HMW usermap zones are in `mwr_game_files\hmw-usermaps\<map>\<map>.ff` (+ `_load.ff`, `.pak`), 66 maps.
- Lua has never been syntax-checked (no luac in the cloud sandbox).

## Environment notes
- Cloud sandbox has no Rust/VS; builds happen on the user's PC. Play dir / game files: `C:\Users\Gaming PC\Documents\mwr_game_files`.
- MWR LUI dump for reference: https://github.com/skkuull/h1_dump (cloned to /tmp/h1dump in the old session). Existing example of a HUD script: `data/cdata/ui_scripts/hud_info/`.
- User preferences: terse replies, work autonomously, no toggles, don't take over his PC unless he allows it (he uses emergency stop).
