# Archives (VN + exploration)

Godot 4 project for the Archives prologue: clickable rooms, inventory, mandatory naming when **both** ID and keycard are found, keycard-only exit, and the east corridor with **three papers** (the center paper triggers an encounter mid-read).

**Repository:** https://github.com/ReeceVinyard/SCP-VN

---

## Play the game on your computer (step-by-step)

These steps are written for someone who has never used Godot before. You only need to do the **one-time setup** once; after that, opening the project and pressing Play takes a few seconds.

### What you need

- A Mac or Windows PC with a few GB of free disk space
- An internet connection (to download Godot and the project)
- About 15–20 minutes the first time

### Step 1 — Download Godot

1. Open https://godotengine.org/download in your browser.
2. Under **Godot Engine**, download the **Standard** version (not .NET).
3. Pick the build for your computer:
   - **macOS** — choose the file that ends in `.dmg` (Apple Silicon or Intel; if unsure, try Apple Silicon first on a newer Mac).
   - **Windows** — choose the `.exe` **x86_64** download.
4. Install or run Godot:
   - **macOS:** Open the `.dmg`, drag **Godot** into Applications (or run it from the disk image). The first time macOS may say the app is from an unidentified developer — open **System Settings → Privacy & Security** and click **Open Anyway** for Godot.
   - **Windows:** Run the downloaded `.exe`; no installer is required. You can pin Godot to the taskbar if you like.

**Version:** This project uses **Godot 4.3 or newer** (4.4 / 4.6 is fine). If Godot asks to upgrade the project when you open it, choose **Convert** or **Yes** — that is normal.

### Step 2 — Get the project files from GitHub

**Option A — Download as ZIP (easiest, no Git required)**

1. Go to https://github.com/ReeceVinyard/SCP-VN
2. Click the green **Code** button → **Download ZIP**
3. Unzip the file (e.g. into `Documents` or `Desktop`)
4. You should have a folder named something like `SCP-VN-main` — remember where it is

**Option B — Clone with Git (if you already use Git)**

```bash
git clone https://github.com/ReeceVinyard/SCP-VN.git
cd SCP-VN
```

### Step 3 — Open the project in Godot

1. Launch **Godot**
2. On the **Project Manager** screen, click **Import**
3. Click the folder icon and browse to the unzipped/cloned folder
4. Select the file **`project.godot`** inside that folder (not the folder itself — the file named `project.godot`)
5. Click **Import & Edit**
6. Wait for Godot to import assets (first open can take a minute). You will see the editor with files on the left and a scene view in the center.

The project is now ready. You do **not** need to install anything else (no Node, no Python, no Steam).

### Step 4 — Run the game (playtest)

1. Make sure the Godot window is focused
2. Press **F5** on your keyboard, **or** click the **Play** button (▶) in the top-right of the editor
3. The game window opens at 1920×1080 (it may scale to fit your screen)

**If Play does nothing or shows an error:** In the Project Manager, confirm you imported **`project.godot`**. Close Godot, import again, and retry.

### Step 5 — How to play the prologue

| Control | What it does |
|--------|----------------|
| **Mouse click** | Interact with highlighted areas in the room |
| **Click / Enter** | Advance dialogue when text is on screen |
| **I** | Open or close inventory |
| **F6** / **Save** button | Quick save (full progress) |
| **F9** / **Load** button | Quick load last save |

**Suggested play order:**

1. **Archives room** — Click the **desk** (Researcher ID) and **locker** (keycard). You can click the shelf and other spots for extra text.
2. When you have **both** items, a **name entry** screen appears — type a name and confirm.
3. Click the **door** (needs keycard) to leave for the corridor.
4. **East corridor** — Read the three **papers** on the floor (left, center, right). The **center** paper triggers something on the second line of dialogue.
5. Use the **left foreground door** to return to the Archives when you are done exploring.

Hovering the mouse over objects should show a subtle **glow** on the art where interactables are set up.

### Step 6 — Run again later

1. Open Godot → select **Archives** in the project list (or **Import** again if it is not listed)
2. Press **F5**

You do not need to re-download the ZIP unless Reece tells you there is a new version on GitHub — then download or `git pull` again.

### Troubleshooting

| Problem | What to try |
|--------|-------------|
| Godot will not open on Mac | System Settings → Privacy & Security → allow Godot |
| “Failed to load” or missing files | Re-download the ZIP; make sure the whole folder was unzipped |
| Window is too big / off-screen | Godot **Display** settings use 1920×1080; resize the game window or use fullscreen in the running game if available |
| Click does nothing | Wait until dialogue finishes; click the dialogue box to advance first |
| Pink/missing textures | Open the project once in the editor and let import finish, then press F5 again |

If you are stuck, send Reece a screenshot of the Godot **Output** panel (bottom of the editor) after pressing F5.

---

## For developers (quick reference)

### Requirements

- [Godot 4.3+](https://godotengine.org/download)
- Optional: [Inky](https://github.com/inkle/inky) for editing `story/story.ink`

### Save / load (playtesting)

Quick save writes to `user://saves/quick_save.json` (see Godot **User data** path in the editor). Each save stores:

- **All story flags** (every choice in `GameState.FLAG_DEFAULTS`: Chase branch, papers read, door state, etc.)
- **Inventory** (items + ID male/female variant + selected item)
- **Current map**, consumed hotspots, player name, exploration state
- **In-progress pickup** if you saved mid item-found modal
- **Active dialogue** (knot, line, choices, or pending NPC reaction) — including mid–Chase sequence

**F9** / **Load** restores the room, overlays, and flags so you can jump back to a beat without replaying from the intro. The opening eye cinematic is skipped when loading a save that has already passed it.

When you add a new flag to `game_state.gd` `FLAG_DEFAULTS`, it is included automatically in future saves.

### Run locally

1. Open Godot → **Import** → select this folder’s `project.godot`
2. Press **F5**

### Prologue flow

| Step | What happens |
|------|----------------|
| Archives | Find **Researcher ID** (desk) and **keycard** (locker). |
| Naming | When **both** items are in inventory, naming is required before the door exit knot runs. |
| Door | Requires **keycard**. Leaving without the ID sets `missing_researcher_id`. |
| Hall | Three papers; **center** triggers encounter via `trigger:scp1_encounter` in `story/story.json`. |
| Encounter | Choice branch → `scp1_befriended` or `scp1_hostile`. |

### Project layout

```
scenes/main.tscn           # Root UI
scenes/maps/archives.tscn  # Archives room
scenes/maps/hall_papers.tscn # Corridor 2 (papers + doors)
scenes/maps/corridor_forward.tscn # Corridor 3 (vents, sign, camera, doors)
scripts/hotspot_zone.gd    # Per-clickable-area script
scripts/autoload/          # GameState, DialogueManager
scripts/data/              # Maps, items, interactable overlays
story/story.json           # Runtime narrative
story/story.ink            # Authoring source (keep in sync)
assets/backgrounds/        # Room backgrounds
assets/Interactables/      # Full-screen hover overlay art
```

### Editing clickable areas

Hover glow uses full-screen overlay PNGs in `assets/Interactables/` (1920×1080). **Clicks follow the cyan box**, which should match the opaque pixels in that overlay—not a rough guess on the background.

1. Open **`scenes/maps/archives.tscn`** (or `hall_papers.tscn`). Root has **Map Editor Canvas** (1920×1080 min size).
2. Select **ArchivesMap** / **HallPapersMap** → **Fit ALL hotspots to overlay art** (reads bounds from `InteractableRegistry.OVERLAY_HIT_RECTS`).
3. Per zone: **Fit to overlay art** for one object; **Snap click box to anchors** if offsets/scale crept in (red outline = misaligned).
4. At runtime, zones with overlay art also use **alpha hit-testing** inside the box (only non-transparent pixels click).
5. Maps play inside a **16:9 aspect wrapper** so anchors stay aligned with art when the window is resized.

To add a new object: drop a `lab1_*.png` overlay, add paths + `OVERLAY_HIT_RECTS` in `scripts/data/interactable_registry.gd` (opaque bbox at 1920×1080), then fit the hotspot.

Chase appears on **`HallPapersMap → InteractableOverlays → ChaseAtDoor`** (not a runtime-only node). Open `scenes/maps/hall_papers.tscn`, select **ChaseAtDoor**, and resize/move with anchor handles. Toggle **Show In Editor** to preview art while editing. Mood swaps (`chase.png` / `chase_angry.png` / `chase_scared.png`) still apply at runtime via `chase_at_door` in `interactable_registry.gd`.

### UI draw order (CanvasLayers)

Defined in `scripts/ui/ui_layers.gd` and applied in `scenes/main.tscn`:

| Layer | Contents |
|-------|----------|
| **0 World** | Maps, Chase / character presence, exploration |
| **5 HUD** | Inventory button, status |
| **10 Dialogue** | Dialogue box |
| **20 Choices** | Choice dim + buttons (characters stay visible **behind** this layer) |
| **30 Modals** | Reactions, documents, naming |
| **100 Cinematic** | Opening eye overlay |

New UI should use the appropriate `CanvasLayer` so it never fights map characters.

Story line tags: `"tags": ["shake:light"]` / `shake:medium` / `shake:heavy` for screen shake.

Overlay PNG mappings: `scripts/data/interactable_registry.gd`

### Narrative workflow

1. Write in **`story/story.ink`** (Inky)
2. Mirror knots in **`story/story.json`**
3. Tags like `trigger:scp1_encounter` fire mid-scene via `DialogueManager`

### Export (optional)

**macOS:** Project → Export → macOS preset → Export Project  
**Windows:** Same with Windows preset

Export presets are created in the editor; `export_presets.cfg` is gitignored.
