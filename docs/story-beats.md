# Story beats (living doc)

## Archives (`archives`)

- Player wakes with memory loss.
- **Desk** → Researcher ID (optional for exit, required for self-naming).
- **Locker** → keycard (required for exit).
- When **both** in inventory → mandatory name registration.
- **Door** → keycard only; blocks if both items held but not named.
- Leave without ID → `missing_researcher_id` (something assigns name later).

## East corridor (`hall_papers`)

| Paper | Position | Effect |
|-------|----------|--------|
| Left | west | Flavor memo |
| **Middle** | center | Encounter triggers on second line while reading |
| Right | east | Flavor roster |

Corridor encounter: calm / flee / offer notes (if left or right paper read).

## Flags reference

| Flag | When |
|------|------|
| `has_named_player` | Player entered name |
| `missing_researcher_id` | Left Archives without ID |
| `scp1_befriended` / `scp1_hostile` | Encounter outcome |
| `named_by_scp` | (future) forced naming scene |

## Maps to add (4 remaining toward 6)

- [ ] Map 3 — _TBD from story_
- [ ] Map 4
- [ ] Map 5
- [ ] Map 6
