# Story beats (living doc)

## Archives (`archives`)

- Player wakes with memory loss.
- **Desk** → Researcher ID (optional for exit, required for self-naming).
- **Locker** → keycard (required for exit).
- When **both** in inventory → mandatory name registration.
- **Door** → keycard only; blocks if both items held but not named.
- Leave without ID → `missing_researcher_id` (something assigns name later).

## East corridor (`hall_papers`) → Corridor 3 (`corridor_forward`)

After Chase’s guide dialogue, a **black wipe** transitions to Wing C. Chase **fades in** on the new map and delivers a briefing (`corridor3_chase_briefing_gentle` / `_harsh`) on the Archives wing, the containment breach, and the evacuation order.

## East corridor (`hall_papers`) — papers and Chase at door

| Paper | Position | Effect |
|-------|----------|--------|
| Left | west | Flavor memo |
| **Middle** | center | Encounter triggers on second line while reading |
| Right | east | Flavor roster |

Center paper → **EH-14** document (full-screen reader) → inventory → door opens → **Chase** → player choices. SCP encounter comes later.

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
