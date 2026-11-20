# SHOTOKAN REFramework mods

In-game scripts for Street Fighter 6 that feed [SHOTOKAN](https://github.com/shogberg/SF6-SHOTOKAN), the replay-review tooling.
They run in [REFramework](https://github.com/praydog/REFramework) (Lua).

| Script | What it does |
|---|---|
| `autorun/capture_replay.lua` | Records every frame of a replay (both players' action, HP, Drive, super, burnout, position, hitstun/blockstun, inputs) plus hit data and battle stats, and saves `reframework/data/<replayid>.json` when the match ends. |
| `autorun/export_moves.lua` | Exports move names for the two loaded characters and the game's state enums to `reframework/data/sf6_moves/`, so captures get readable move names. |
| `autorun/batch_replays.lua` | Plays a queue of replays by replay ID, driven by `batch/batch_record.py` in the SHOTOKAN repo. Navigates CFN > Replays by screen name, one-frame key presses (rkaganda's scheme). |

## Install
1. Copy the files in `autorun/` into `Street Fighter 6\reframework\autorun\`.
2. Copy the `data/sf6_moves/` folder into `Street Fighter 6\reframework\data\`, so you have `reframework\data\sf6_moves\09_Cammy.json` and so on.
3. Reload scripts in the REFramework menu (Insert).

## Move names (included)
`data/sf6_moves/` has move names already exported for the whole roster (32 characters: Ryu through Arjun), plus `enums.json` (the game's state enums) and `char_names.json` (names for character IDs the scripts don't list). `capture_replay.lua` and the SHOTOKAN analyzer read these to name moves, so you don't need to export them yourself.

Re-export a character after a game patch that changes moves, or to add a new character: see step 1 under **Use**. Each file is `<character id>_<name>.json`: `{char_id, char_name, moves: {action id: name}}`.

## Use
1. **Move names (only after a patch or for a new character):** load both characters in training mode, open the REFramework menu and press **Export moves for both characters** in the **Move Export** window.
2. **Capture:** play a replay. `capture_replay.lua` saves `<replayid>.json` to `reframework\data` at match end.
3. **Batch:** see `batch/README.md` in the SHOTOKAN repo to record many replays by ID with OBS.

Then run `tools/analyze_capture.py` from the SHOTOKAN repo on the captures.

## Credits
`capture_replay.lua` and `batch_replays.lua` build on [rkaganda/SF6_replay_capture](https://github.com/rkaganda/SF6_replay_capture) and [rkaganda/sf6_replays_data](https://github.com/rkaganda/sf6_replays_data). `export_moves.lua` uses the same game structures, and alphazolam's MMDK, which documented where the move tables live.
