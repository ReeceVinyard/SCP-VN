# SCP Archives (VN + exploration)

Godot 4.3+ project for the Archives prologue: clickable tutorial, inventory, mandatory naming when **both** ID and keycard are found, keycard-only exit, and the east corridor with **three papers** (center paper triggers the SCP mid-read).

## Requirements

- [Godot 4.3+](https://godotengine.org/download) (macOS build for playtest; Windows export for PC release)
- Optional: [Inky](https://github.com/inkle/inky) for editing `story/story.ink`

## Run on Mac (playtest)

1. Open Godot → **Import** → select this folder (`project.godot`).
2. Press **F5** (Play).
3. **Controls:** click hotspots on the room; **Inventory (I)**; dialogue **Enter / click** to advance.

## Prologue flow (implemented)

| Step | What happens |
|------|----------------|
| Archives | Find **Researcher ID** (desk) and **keycard** (locker). Click flavor hotspots. |
| Naming | When **both** items are in inventory, a modal forces a name before the door works. |
| Door | Requires **keycard** only. If you leave **without** the ID, `missing_researcher_id` is set (SCPs name you later). |
| Hall | Three papers; **center** triggers SCP on the second line of its text. |
| SCP | Choice / skill-style branch → `scp1_befriended` or `scp1_hostile`. |

Placeholder backgrounds are flat colors; swap in art under `assets/backgrounds/` and wire `MapRegistry` when ready.

## Project layout

```
scenes/main.tscn          # Root UI
scripts/autoload/         # GameState, DialogueManager
scripts/data/             # Maps, items
scripts/exploration_map.gd
story/story.json          # Runtime narrative (edit via Ink or JSON)
story/story.ink           # Authoring source (keep in sync)
```

## Narrative workflow

1. Write branches in **`story/story.ink`** (Inky).
2. Update **`story/story.json`** with the same knots (or add an Ink compile step to your pipeline).
3. Knot tags like `trigger:scp1_encounter` fire mid-scene; choices set flags via `set_flag` in JSON.

## Maps (6 planned; 2 in slice)

- `archives` — tutorial
- `hall_papers` — three papers + SCP
- Add four more in `scripts/data/map_registry.gd` as story beats land.

## Export

**macOS:** Project → Export → add macOS preset → Export Project.  
**Windows:** Same with Windows preset (build on Windows or use CI).

Enable presets in Godot the first time you export (Editor will create `export_presets.cfg`; file is gitignored).

## Next content hooks

- SCP naming knot when `missing_researcher_id` (e.g. `scp_assign_name` in Ink/JSON).
- Replace `???` speaker with final SCP name and art.
- Save/load on `GameState` dictionary.
