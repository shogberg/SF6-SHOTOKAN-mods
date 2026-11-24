# Changelog

Notable changes to the SHOTOKAN REFramework mods, newest first. Every push adds its changes here.

## 2026-11-24 (later)
- README: the analyzer is now `tools/shared_core_analyze.py`.

## 2026-11-24
- Character names live in one place: `data/sf6_moves/char_names.json` now lists all 32 characters by ID, and `capture_replay.lua` and `export_moves.lua` read it instead of carrying their own copy of the list. Names are unchanged (`M Bison`, `E Honda`, `C.Viper`, ...), so existing captures and the database still match. Replay Capture shows a warning if the file is missing.
- Update note: copy the new `char_names.json` into `reframework\data\sf6_moves\` together with the scripts, or every character saves as `char_<id>`.

## 2026-11-22
- Moved to the shotokan-sf6 organization (was shogberg/SF6-SHOTOKAN-mods): link to shotokan-sf6/tools.
## 2026-11-21
- Replay Capture and Move Export now draw under REFramework's **Script Generated UI** (like Batch Replays) instead of their own windows.

## 2026-11-19
- capture_replay v3.4: unfinished replays are discarded.
- batch_replays: screen-driven navigation with one-frame key presses.
- Exported move names ship for the full roster.
- Added export_moves and batch_replays.
- capture_replay v3.3: saves each player's CFN ID, platform, MR and LP.
- capture_replay v3.2: reads the character names saved by Move Export.
- capture_replay v3.1: per-frame capture, hit data and battle stats.
- Initial release.
