# SHOTOKAN REFramework mods

In-game scripts for Street Fighter 6 that feed [SHOTOKAN](https://github.com/shogberg/SF6-SHOTOKAN), the replay-review tooling.
They run in [REFramework](https://github.com/praydog/REFramework) (Lua).

| Script | What it does |
|---|---|
| `autorun/capture_replay.lua` | Records every frame of a replay (both players' action, HP, Drive, super, burnout, position, hitstun/blockstun, inputs) plus hit data and battle stats, and saves `reframework/data/<replayid>.json` when the match ends. |
| `autorun/export_moves.lua` | Exports move names for the two loaded characters and the game's state enums to `reframework/data/sf6_moves/`, so captures get readable move names. |
| `autorun/batch_replays.lua` | Plays a queue of replays by replay ID, driven by `batch/batch_record.py` in the SHOTOKAN repo. |

## Install
Copy the files in `autorun/` into `Street Fighter 6\reframework\autorun\`, then reload scripts in the REFramework menu (Insert).

## Use
1. **Move names (once per character):** load both characters in training mode, open the REFramework menu and press **Export moves for both characters** in the **Move Export** window.
2. **Capture:** play a replay. `capture_replay.lua` saves `<replayid>.json` to `reframework\data` at match end.
3. **Batch:** see `batch/README.md` in the SHOTOKAN repo to record many replays by ID with OBS.

Then run `tools/analyze_capture.py` from the SHOTOKAN repo on the captures.

## Credits
`capture_replay.lua` and `batch_replays.lua` build on [rkaganda/SF6_replay_capture](https://github.com/rkaganda/SF6_replay_capture) and [rkaganda/sf6_replays_data](https://github.com/rkaganda/sf6_replays_data). `export_moves.lua` uses the same game structures, and alphazolam's MMDK, which documented where the move tables live.
