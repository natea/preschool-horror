# Anomaly Placement Engine

> **Status**: In Design
> **Author**: Nate Aune + agents
> **Last Updated**: 2026-04-11
> **Implements Pillar**: Pillar 1 ("Something's Wrong Here") — placement quality determines whether wrongness feels intentional or random; Pillar 4 ("One More Night") — density escalation across nights

## Overview

The Anomaly Placement Engine is the per-night content configuration layer for Show & Tell. It receives a night number and anomaly target count from Night Progression during the LOADING phase, queries Room/Level Management for accessible rooms and their active spawn slots, and outputs a placement manifest — an ordered list of anomaly-type-to-spawn-point assignments that the Anomaly System consumes to instantiate the actual anomaly objects. It owns the rules for *which* anomalies go *where* on *which* night, but not what those anomalies look like or how they behave (that's Anomaly System) and not *how many* anomalies exist per night (that's Night Progression's `anomaly_target` formula). The engine supports two modes: fixed placement (hand-authored per-night configs for MVP, guaranteeing curated pacing) and template-based remixing (a pool of reusable anomaly templates assigned to compatible spawn points for the full vision, providing controlled variety across replays). The separation exists because placement quality is the delivery mechanism for Pillar 1 ("Something's Wrong Here") — if anomalies appear in random, nonsensical positions, the carefully escalated wrongness collapses into noise. The Anomaly Placement Engine ensures every anomaly feels intentionally placed, whether the placement was hand-authored or algorithmically selected.

## Player Fantasy

**No direct or indirect player fantasy.** The Anomaly Placement Engine is pure infrastructure — players experience the anomalies it places (owned by Anomaly System) and the escalation curve it follows (owned by Night Progression), but never perceive or interact with the placement decision itself. If the engine works correctly, the player thinks "the preschool is getting worse" — they never think about placement. If it fails, the player thinks "this feels random," which breaks Pillar 1.

*The system's success criterion is invisibility.*

## Detailed Design

### Core Rules

#### Placement Modes

The Anomaly Placement Engine operates in one of two modes, selected at project level:

**Fixed Mode (MVP):** Every night has a hand-authored `NightPlacementConfig` resource that explicitly maps each anomaly to a specific room and spawn point. The engine reads the config, validates it against the room's current `active_spawn_slots`, and outputs the manifest verbatim. No algorithm runs — the designer is the algorithm.

**Template Mode (Full Vision — stub):** The engine receives the `anomaly_target(n)` from Night Progression and distributes anomalies across rooms using the slot-proportional + hotspot algorithm defined in Formulas. Template mode reuses anomaly definitions from a shared pool, applying compatibility and anti-repeat rules. *Full specification deferred to post-MVP playtest.*

Both modes produce the same output: a `PlacementManifest`.

#### Placement Manifest Structure

The manifest is the contract between the Anomaly Placement Engine and the Anomaly System. It is built once per night during the LOADING phase and is immutable for the duration of that night.

| Field | Type | Description |
| --- | --- | --- |
| `night` | int | Night this manifest was built for (safety guard against stale reads) |
| `entries` | Array[PlacementEntry] | Ordered list of anomaly placements |

**PlacementEntry fields:**

| Field | Type | Description |
| --- | --- | --- |
| `anomaly_id` | StringName | Which anomaly definition to instantiate (e.g., `&"drawing_replaced"`) |
| `room_id` | StringName | Which room to place it in |
| `spawn_point_index` | int | Index into that room's `spawn_points` array |
| `spawn_point_tag` | StringName | Denormalized tag (`FLOOR`, `WALL`, `CEILING`, `FURNITURE_TOP`) |
| `anomaly_type` | enum | `ENVIRONMENTAL` or `MONSTER` |
| `severity_tier` | int | 1 (Subtle), 2 (Unsettling), or 3 (Confrontational) |
| `is_anchor` | bool | Whether this anomaly occupies a fixed spawn point across nights (not swap-eligible) |

The `spawn_point_index` references the room's `spawn_points` array — the Anomaly System resolves the actual `Transform3D` by calling `get_room_data(room_id).spawn_points[spawn_point_index]`. This keeps the manifest data-only.

#### The configure_for_night(n) Call

Night Progression calls `AnomalyPlacementEngine.configure_for_night(n: int)` during the LOADING phase.

**Inputs available at call time:**
- `n` — current night number (1-7)
- `anomaly_target(n)` — total anomalies to place (from Night Progression formula: 3-12)
- `monster_count(n)` — monsters included in the target (from Night Progression formula: 0-3)
- `get_accessible_rooms()` — rooms accessible this night (from Room Management)
- `get_room_spawn_points(room_id, tag_filter)` — available spawn points per room (from Room Management, already filtered by `active_spawn_slots`)

**Output:** A `PlacementManifest` stored as the engine's current state, queryable by the Anomaly System.

**Fixed Mode flow:**
1. Load `NightPlacementConfig` resource for night `n`
2. For each entry in the config: validate that the room is accessible and the spawn point index is within `active_spawn_slots`
3. If validation fails for any entry: log warning, skip that entry (graceful degradation — manifest may have fewer anomalies than target)
4. Build and store the `PlacementManifest`
5. Emit `placement_manifest_ready(n)`

#### Severity Tiers

Anomalies are classified into three severity tiers that control escalation quality, not just quantity:

| Tier | Name | Description | Available From | Examples |
| --- | --- | --- | --- | --- |
| 1 | **Subtle** | Requires attention and spatial memory to notice. Wrongness is ambiguous. | Night 1 | A drawing slightly different. One block moved. A chair at the wrong table. |
| 2 | **Unsettling** | Obviously, undeniably wrong. Not threatening, but uncomfortable. | Night 3 | All drawings upside down. Blocks spell a word. A chair on the ceiling. |
| 3 | **Confrontational** | Intrudes on the player's space and path. All monsters are Tier 3. | Night 3 (monsters), Night 5 (environmental) | A figure in a corridor. Objects blocking a route. |

**Per-night severity mix (target percentages):**

| Night | Tier 1 (Subtle) | Tier 2 (Unsettling) | Tier 3 (Confrontational) |
| --- | --- | --- | --- |
| 1 | 100% | 0% | 0% |
| 2 | 85% | 15% | 0% |
| 3 | 70% | 22% | 8% |
| 4 | 42% | 29% | 29% |
| 5 | 40% | 36% | 24% |
| 6 | 25% | 43% | 32% |
| 7 | 10% | 50% | 40% |

Monsters count against the Tier 3 share. Percentages are applied to `anomaly_target(n)` and floor-rounded. Remainder slots are assigned to the lowest unfilled tier.

**In Fixed Mode:** The severity tier is authored per entry in the `NightPlacementConfig`. The percentages above are guidance for the designer, not enforced by the engine.

#### Anomaly-to-Spawn-Point Compatibility

Each anomaly definition carries a `compatible_tags` list (OR logic — must match at least one):

| Anomaly Type | Compatible Tags | Rationale |
| --- | --- | --- |
| Drawing anomalies | `WALL` | Drawings are always on walls |
| Furniture anomalies (blocks, chairs) | `FLOOR`, `FURNITURE_TOP` | Can be on floor or shelves |
| Ceiling anomalies | `CEILING` | Mounted above |
| Monster: Doll archetype | `FLOOR`, `FURNITURE_TOP` | Dolls stand on surfaces |
| Monster: Shadow archetype | `WALL` | Shadows live on vertical surfaces |
| Monster: Large archetype | `FLOOR` | Large creatures occupy floor space |

**Compatibility is enforced at manifest build time.** An anomaly is never assigned to a spawn point whose tag is not in its `compatible_tags` list. If no compatible spawn points remain in a room, that anomaly is skipped for that room.

#### Monster Placement Constraints

Monsters have additional placement rules beyond tag compatibility:

1. **Entry Hall exclusion:** No monster spawns in `entry_hall` on any night. The player's start room and exit route must remain a safe anchor.
2. **Monster separation:** On nights with 2+ monsters, no two monsters may spawn in the same room AND they may not spawn in adjacent rooms (using `RoomData.adjacency`). If the constraint cannot be satisfied with available rooms, relax to same-room prohibition only.
3. **Density cap in monster rooms:** A room containing a monster has its environmental anomaly allocation capped at 75% of its normal slot-proportional share. The monster is the room's primary threat — environmental anomalies support it, not compete with it.
4. **Night 3 is authored:** The first monster placement (Night 3, Cubby Hall) is hand-authored in Fixed Mode and forced in Template Mode. The first monster experience is too important for algorithmic placement.

#### Room Heat Distribution

Each night designates one room as the **hot zone** — the room receiving disproportionately more anomalies:

| Night(s) | Hot Room | Rationale |
| --- | --- | --- |
| 1-2 | Main Classroom | Largest room, primary teaching space, establishes the loop |
| 3 | Cubby Hall | First monster night — Cubby Hall is the encounter room |
| 4-5 | Nap Room | The dread room wakes up — density spike is a story beat |
| 6 | Bathroom | Late-unlocked space, containment failing |
| 7 | Principal's Office | The locked door opens — the source |

**Entry Hall heat cap:** Max 1 anomaly (Nights 1-3), max 2 (Nights 4-6), max 3 (Night 7). Never the hot room.

**Minimum density rule (Night 3+, best-effort):** Every accessible room should receive at least 1 anomaly. No room should feel untouched once monsters are present. When `T_env < accessible_room_count`, allocate 1 per room in descending weight order until `T_env` is exhausted — remaining rooms receive 0 without error (see Edge Case #6).

#### MVP Fixed Placement Configs

For MVP (Nights 1-3, 3 rooms), the designer authors a `NightPlacementConfig` resource per night:

**Night 1 (3 anomalies, 3 rooms, 0 monsters):**
- Entry Hall: 0 anomalies (clean — establishes safe anchor)
- Main Classroom: 2 anomalies (Tier 1, leading positions — bulletin board area, block table)
- Art Corner: 1 anomaly (Tier 1, drawing on easel — this is the anchor anomaly that persists/evolves across nights)

**Night 2 (4 anomalies, 3 rooms, 0 monsters):**
- Entry Hall: 1 anomaly (Tier 1 — safe room's first violation)
- Main Classroom: 2 anomalies (1 Tier 1, 1 Tier 2 — first "obviously wrong" anomaly)
- Art Corner: 1 anomaly (Tier 1, drawing anchor — different anomaly_id from Night 1 at same spawn_point_index, creating visual continuity)

**Night 3 (6 anomalies, 3 rooms, 1 monster):**
- Entry Hall: 1 anomaly (Tier 1 — first anomaly in a previously clean spot)
- Main Classroom: 2 anomalies (1 Tier 1, 1 Tier 2) + 1 Monster: Doll (Tier 3, FLOOR spawn point facing primary doorway)
- Art Corner: 1 anomaly (Tier 2 — the drawing is now obviously wrong)
- Total: 4 environmental + 1 monster = 5. *(Shortfall of 1 vs. AT=6 is acceptable — the monster's room has reduced environmental density per the 75% cap design intent. Fixed Mode validation threshold is met: 5/6 = 83%.)*

*Decision (OQ-6 resolved 2026-04-11): Monster goes in Main Classroom for MVP. The most familiar room becomes the first threat, subverting player comfort. Full Vision Night 3 uses Cubby Hall per the original hot room table — author a separate NightPlacementConfig variant when Cubby Hall is added.*

#### Template Mode Algorithm (Stub)

*Full specification deferred to post-MVP playtest.* The interface contract is:

1. Receive `anomaly_target(n)` and `monster_count(n)` from Night Progression
2. Query Room Management for accessible rooms and active spawn slots
3. Apply slot-proportional + hotspot distribution (see Formulas)
4. Apply severity tier mix for night `n`
5. Apply tag compatibility filtering
6. Apply monster placement constraints
7. Apply anti-repeat rules (spawn point recency blacklist, anomaly type rotation, anchor exemptions)
8. Build and emit `PlacementManifest`

Anti-repeat rules, anomaly pool management, and template selection logic will be specified after MVP playtesting validates the core placement feel.

**Output Range:** 0 to `active_spawn_slots(R,N)`. Sum across all rooms equals `T_env(N)` under normal conditions. Under degraded conditions (Edge Cases #4, #10, #17), total may be less than `T_env(N)` — shortfall is logged.
### States and Transitions

The Anomaly Placement Engine is not a persistent state machine — it runs as a one-shot configuration pass during LOADING and holds its output until the next night.

| State | Description |
| --- | --- |
| `IDLE` | No manifest loaded. Waiting for `configure_for_night(n)`. |
| `BUILDING` | Processing `configure_for_night(n)`. Reading configs, validating spawn points, building manifest. |
| `READY` | Manifest built and stored. Anomaly System may query. |

**Transitions:**

| From | To | Trigger |
| --- | --- | --- |
| IDLE | BUILDING | `configure_for_night(n)` called |
| BUILDING | READY | Manifest validated, `placement_manifest_ready(n)` emitted |
| READY | IDLE | Night ends (any terminal transition in Night Progression) — manifest cleared |
| READY | BUILDING | Death restart — `configure_for_night(n)` called again with same `n` |

**Fixed Mode restart:** Rebuilding the manifest on death restart produces an identical manifest (same authored config, same `n`). Anomalies appear in the same positions.

**Template Mode restart:** Rebuilding may produce a different manifest if the algorithm has randomized elements. Whether death should reset anomaly positions or maintain them is a design decision deferred to Template Mode specification.

### Interactions with Other Systems

#### Inputs (other systems call into APE)

| Caller | Method / Signal | When | Data |
| --- | --- | --- | --- |
| Night Progression | `configure_for_night(n: int)` | LOADING phase | Night number. APE derives anomaly_target and monster_count internally or queries Night Progression. |
| Night Progression | `night_active_started(n)` signal | ACTIVE phase entry | APE may use this to confirm manifest was consumed. No action required. |

#### Outputs (APE emits / exposes)

**Signals:**

| Signal | Parameters | Consumed By | When |
| --- | --- | --- | --- |
| `placement_manifest_ready(n: int)` | Night number | Anomaly System | After manifest is built during LOADING |

**Query API:**

| Method | Returns | Callers |
| --- | --- | --- |
| `get_manifest() -> PlacementManifest` | Current night's placement manifest | Anomaly System |
| `get_entries_for_room(room_id: StringName) -> Array[PlacementEntry]` | Entries filtered by room | Anomaly System |
| `get_monster_entries() -> Array[PlacementEntry]` | Entries where `anomaly_type == MONSTER` | Monster AI, Anomaly System |
| `get_anomaly_count() -> int` | Total entries in manifest | HUD/UI (optional), debug |

#### Dependencies consumed

| System | What APE reads | Method |
| --- | --- | --- |
| Room Management | Accessible rooms, spawn points, active slot counts | `get_accessible_rooms()`, `get_room_spawn_points(room_id, tag)`, `get_room_data(room_id)` |
| Night Progression | Current night, anomaly target, monster count | `get_current_night()`, or passed directly via `configure_for_night(n)` |

**APE has no downstream dependencies.** It produces data; it does not call into Anomaly System or Monster AI. Those systems pull from APE's query API.

## Formulas

### Room Anomaly Allocation

Determines how many environmental anomalies go in each room on night N. Runs in Template Mode; in Fixed Mode, allocations are hand-authored.

`room_weight(R, N) = active_spawn_slots(R, N) * hotspot_modifier(R, N) * monster_cap_modifier(R, N)`

`room_alloc(R, N) = floor(anomaly_target_env(N) * room_weight(R, N) / total_weight(N))`

Remainder after flooring is distributed +1 using the following priority:

1. **Hot room first:** If the hot room has remaining capacity (`alloc < active_spawn_slots`), it receives +1 before any other room. This guarantees the hot room's density spike survives floor rounding even when the monster cap modifier partially cancels the hotspot modifier.
2. **Fractional sort:** Remaining +1 slots go to rooms sorted by fractional part descending until exhausted.

**Variables:**

| Variable | Symbol | Type | Range | Description |
| --- | --- | --- | --- | --- |
| active_spawn_slots | S(R,N) | int | 0-8 | Slots available in room R on night N (from Room Management — not re-derived) |
| hotspot_modifier | H(R,N) | float | {1.0, 1.75} | Hot room = 1.75, all others = 1.0 |
| monster_cap_modifier | M(R,N) | float | {0.75, 1.0} | Room contains a monster = 0.75, otherwise = 1.0 |
| total_weight | WT(N) | float | >0 | Sum of all room weights |
| anomaly_target_env | T_env(N) | int | 0-9 | `anomaly_target(N) - monster_count(N)`. 0 when AT==MC (Edge Case #2). |
| room_alloc | A(R,N) | int | 0-8 | Final integer count for room R, clamped to active_spawn_slots |


**Worked Example — Night 5 (T\_env = 7, 6 rooms, hot room = Nap Room, monsters in Cubby Hall + Nap Room):**

| Room | S | H | M | W | A_raw (7×W/32.625) | floor | +rem | Final |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| entry_hall | 4 | 1.0 | 1.0 | 4.0 | 0.858 | 0 | +1 (frac) | **1** |
| main_classroom | 8 | 1.0 | 1.0 | 8.0 | 1.716 | 1 | — | **1** |
| art_corner | 4 | 1.0 | 1.0 | 4.0 | 0.858 | 0 | +1 (frac) | **1** |
| cubby_hall | 5 | 1.0 | 0.75 | 3.75 | 0.804 | 0 | +1 (frac) | **1** |
| nap_room (hot) | 6 | 1.75 | 0.75 | 7.875 | 1.689 | 1 | +1 (hot) | **2** |
| bathroom | 5 | 1.0 | 1.0 | 5.0 | 1.073 | 1 | — | **1** |

Sum: 1+1+1+1+2+1 = 7 = T_env(5). ✓ Hot room now leads density as intended.

### Severity Tier Allocation

Determines how many anomalies of each severity tier exist globally on night N.

```
t3_raw(N) = floor(anomaly_target(N) * PCT_T3(N))
t3_env(N) = max(0, t3_raw(N) - monster_count(N))
t2_env(N) = floor(anomaly_target(N) * PCT_T2(N))
t1_env(N) = anomaly_target(N) - monster_count(N) - t3_env(N) - t2_env(N)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
| --- | --- | --- | --- | --- |
| anomaly_target | AT(N) | int | 3-12 | Total anomalies (from Night Progression) |
| monster_count | MC(N) | int | 0-3 | Monsters (from Night Progression) |
| PCT_T3 | p3(N) | float | 0.0-0.40 | Target Tier 3 percentage (table-driven) |
| PCT_T2 | p2(N) | float | 0.0-0.50 | Target Tier 2 percentage (table-driven) |
| t3_env | — | int | 0-5 | Environmental Tier 3 count |
| t2_env | — | int | 0-6 | Environmental Tier 2 count |
| t1_env | — | int | 0-9 | Environmental Tier 1 count (absorbs rounding remainder) |

**Output Range:** All non-negative. Sum = `T_env(N)`. Guard: if `t3_raw < monster_count`, clamp `t3_env = 0`.

**Full night table:**

| N | AT | MC | t3_raw | t3_env | t2_env | t1_env | T_env |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 3 | 0 | 0 | 0 | 0 | 3 | 3 |
| 2 | 4 | 0 | 0 | 0 | 0 | 4 | 4 |
| 3 | 6 | 1 | 0 | 0 | 1 | 4 | 5 |
| 4 | 7 | 1 | 2 | 1 | 2 | 3 | 6 |
| 5 | 9 | 2 | 2 | 0 | 3 | 4 | 7 |
| 6 | 10 | 2 | 3 | 1 | 4 | 3 | 8 |
| 7 | 12 | 3 | 4 | 1 | 6 | 2 | 9 |

**Design note:** Night 4's PCT_T3 is set to 29% (above the interpolated 16%) so that `t3_raw = 2` survives the monster deduction and delivers 1 environmental Tier 3 anomaly. This prevents a 2-night confrontational plateau. Night 5 still has zero environmental Tier 3 — the two monsters consume the entire confrontational budget. This is intentional: the monsters ARE the confrontation on Night 5. The single-night dip at Night 5 reads as "the monsters took over," not as a plateau.

### Entry Hall Cap

Hard ceiling on Entry Hall anomaly count, applied after room allocation. Surplus redistributed to highest-weight non-Entry-Hall room with remaining capacity.

`entry_hall_cap(N) = ENTRY_HALL_CAP_TABLE[N]`

| N | Cap | Rationale |
| --- | --- | --- |
| 1-3 | 1 | Safety anchor. One anomaly signals change; two undermines safe-room feeling. |
| 4-6 | 2 | Mid-to-late game. Exit route degrades but stays navigable. |
| 7 | 3 | Boss night. Nowhere is safe. One slot left unused — exit path symbolically preserved. |

**Output Range:** 0 to 3. Cap is a ceiling, not a target — if allocation is below the cap, no anomalies are added. Entry Hall may receive 0 anomalies on any night.

### Formula Execution Order

These formulas execute in sequence during `configure_for_night(n)` in Template Mode:

1. **T_env guard** — compute `T_env(N) = anomaly_target(N) - monster_count(N)`. If `T_env == 0`, skip steps 2-4 (only monsters are placed).
2. **Severity Tier Allocation** — determine global tier counts
3. **Room Anomaly Allocation** — distribute T_env across rooms by weight
4. **Entry Hall Cap** — clamp and redistribute surplus

## Edge Cases

### Formula Guards

1. **If `total_weight(N)` is 0** (all rooms return `active_spawn_slots = 0`): Emit `placement_manifest_ready(n)` with an empty manifest and log a critical error. Do not attempt division. Cannot occur with authored room data but guards against tuning errors.

2. **If `T_env(N)` is 0** (all anomalies are monsters, `AT == MC`): Skip room allocation entirely — only monsters are placed. Minimum density rule does not apply when there are zero environmental anomalies to distribute.

3. **If `t1_env` computes negative** (tier percentages exceed available budget after monsters are deducted): Clamp `t1_env = max(0, t1_env)`. Reduce `t2_env` by the deficit. Tuning constraint: `floor(AT(N) * PCT_T2(N)) + max(0, floor(AT(N) * PCT_T3(N)) - MC(N)) <= AT(N) - MC(N)`. This constraint accounts for floor rounding and monster deduction — validate against the full night table after any percentage change.

4. **If `room_alloc(R,N)` after remainder distribution exceeds `active_spawn_slots(R,N)`**: Clamp to `min(alloc, active_spawn_slots)`. Surplus is discarded (not redistributed). Log the shortfall. Total manifest count may be less than `T_env`.

5. **If fractional-part tiebreaker is needed during remainder distribution** (two rooms have identical fractional parts): Sort tied rooms by `room_id` alphabetically. Deterministic tiebreaker ensures identical manifests on restart.

### Constraint Conflicts

6. **If minimum density rule conflicts with `T_env`** (Night 3+, accessible rooms > `T_env`): Minimum density is best-effort. Allocate 1 anomaly per room in descending weight order until `T_env` is exhausted. Remaining rooms receive 0 anomalies without error. This can occur in Full Vision Night 3 (6 rooms, `T_env = 5`).

7. **If 75% monster-room density cap rounds below minimum density floor**: Minimum density (1 anomaly) wins. The 75% cap modifies the proportional weight calculation but cannot reduce a room below 1 environmental anomaly when the minimum density rule is active (Night 3+).

8. **If monster separation cannot be satisfied** (Night 7, 3 monsters, dense adjacency graph): Relax to same-room prohibition only. With 6 eligible rooms (Entry Hall excluded) and 3 monsters, same-room prohibition is always satisfiable. Adjacency-based separation is a preference, not a hard constraint, when the relaxation fallback fires.

9. **If the designated hot room is inaccessible** (e.g., Cubby Hall on Night 3 in MVP): In Template Mode, hotspot modifier transfers to the highest-weight accessible room. In Fixed Mode, irrelevant — author controls placements directly.

10. **If Entry Hall cap redistribution targets a room already at `active_spawn_slots` ceiling**: Try the next highest-weight room with remaining capacity. If all rooms are at capacity, surplus is discarded. Log the shortfall.

### Fixed Mode Validation

11. **If a `NightPlacementConfig` resource is missing for a night**: Transition IDLE → BUILDING → READY with an empty manifest. Emit `placement_manifest_ready(n)`. Log critical error. Night plays with zero anomalies rather than crashing. Treat as blocking build error in QA.

12. **If the same `(room_id, spawn_point_index)` pair appears twice in one night's config**: Skip the second entry. Log a warning with both `anomaly_id` values. First-wins deduplication.

13. **If a Fixed Mode entry places a monster in Entry Hall**: Skip the entry and log an error. The Entry Hall monster exclusion applies to both Fixed and Template Mode — it is a gameplay safety constraint, not a suggestion.

14. **If a Fixed Mode entry references an `anomaly_id` not in the anomaly definitions pool**: Skip the entry and log an error. Requires the Anomaly System's definition pool to be queryable at LOADING time (interface dependency).

15. **If total valid entries after all Fixed Mode validation is < 50% of `anomaly_target(n)`**: Log a critical error (not just a warning). The night's content is severely under-authored. Treat as blocking in QA.

### State and Timing

16. **If `get_manifest()` is called while state is BUILDING or IDLE**: Return null. Callers must listen to `placement_manifest_ready(n)` before querying — no polling.

17. **If `configure_for_night(n)` is called while already in BUILDING**: Ignore the duplicate call and log a warning. If the incoming `n` differs from the current build's `n`, log a critical error (Night Progression state machine failure).

18. **If death restart triggers `READY → BUILDING`**: Clear the stored manifest reference immediately. All query methods return copies (not live references), so any Anomaly System iteration in progress completes safely on its local copy. The Anomaly System must re-query after the new `placement_manifest_ready(n)`.

19. **If `manifest.night` does not match `current_night` when the Anomaly System reads it**: Anomaly System discards the manifest, places no anomalies, and logs a critical error. Does not request a rebuild — that decision belongs to Night Progression.

### Template Mode (Stub — resolve before implementation)

20. **If no spawn points with the required tag exist for an anomaly type**: Remove that anomaly from the selection pool and draw the next. If the pool is exhausted without filling a tier's count, reduce that tier and add the shortfall to `t1_env`. Design requirement: Tier 1 anomalies must include at least one anomaly compatible with each tag type.

21. **If the hot room receives `alloc = 0` after rounding despite the hotspot modifier**: Force alloc to 1 by taking 1 from the highest-alloc non-hot room (must have alloc ≥ 2 to donate). If no donor exists, hot room stays at 0 — log as a tuning warning.

22. **Template Mode death restart produces different monster positions**: Deferred design decision. Two valid options: (a) seeded RNG with night number as seed (deterministic restarts), (b) re-roll for freshness. Flag for game designer before Template Mode implementation.

### Resolved Discrepancy

23. **Entry Hall cap: Night 4 boundary**: Formulas table is canonical — cap=2 starts at Night 4 (not Night 5). Detailed Rules narrative updated to match.

## Dependencies

### Hard Dependencies (system cannot function without these)

| System | Direction | Interface | Nature |
| --- | --- | --- | --- |
| **Night Progression** | Upstream → APE | `configure_for_night(n: int)` call during LOADING phase. APE derives `anomaly_target(n)` and `monster_count(n)` from Night Progression's formulas or queries. | Hard — APE has no night number without Night Progression. |
| **Room/Level Management** | Upstream → APE | `get_accessible_rooms() -> Array[StringName]`, `get_room_spawn_points(room_id, tag) -> Array[Transform3D]`, `get_room_data(room_id) -> RoomData` (includes spawn slot counts, adjacency, tags). | Hard — APE cannot allocate without room topology. |

### Soft Dependencies (enhanced by, but works without)

| System | Direction | Interface | Nature |
| --- | --- | --- | --- |
| **Anomaly System** | APE → Downstream | `placement_manifest_ready(n)` signal + query API (`get_manifest()`, `get_entries_for_room()`, `get_monster_entries()`, `get_anomaly_count()`). | Soft — APE builds manifests regardless of whether Anomaly System consumes them. |
| **Anomaly System (definition pool)** | Upstream → APE | Fixed Mode validation checks `anomaly_id` against the definition pool (Edge Case #14). | Soft — validation is advisory. APE functions without it but produces unvalidated entries. |
| **Monster AI** | APE → Downstream | `get_monster_entries()` query API. Monster AI reads monster placement positions. | Soft — APE is unaware of Monster AI. |
| **HUD/UI System** | APE → Downstream | `get_anomaly_count()` query API (optional, for debug or UI display). | Soft — APE does not require HUD. |

### No Dependency (listed for completeness)

| System | Reason |
| --- | --- |
| **Audio System** | Audio reacts to anomalies (owned by Anomaly System), not to placement decisions. |
| **Save/Persistence** | APE rebuilds manifests from configs each night — no save state. Death restart calls `configure_for_night(n)` again. Manifests are ephemeral. |
| **Photography System** | Photography evaluates anomalies placed by Anomaly System. No direct APE interface — two layers removed. |
| **Evidence Submission** | Consumes photography results, not placement data — three layers removed. |

### Bidirectional Consistency Notes

- **Night Progression** lists APE in its downstream dependents as a reserved `configure_for_night(n)` call during LOADING. ✓ Consistent.
- **Room/Level Management** exports `get_room_spawn_points()`, `get_accessible_rooms()`, and `get_room_data()`. ✓ Consistent with APE's consumed interfaces.
- **Anomaly System** is not yet designed. When designed, it must document APE as an upstream dependency and specify that it consumes `PlacementManifest` via the query API (not by direct field access).

## Tuning Knobs

| # | Knob | Type | Default | Safe Range | Affects | Interaction Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `HOTSPOT_MODIFIER` | float | 1.75 | 1.25–2.5 | How much denser the hot room is vs. other rooms. | Below 1.25: hot room is indistinguishable. Above 2.5: other rooms feel empty by comparison. |
| 2 | `MONSTER_CAP_MODIFIER` | float | 0.75 | 0.5–1.0 | Environmental anomaly density in monster rooms. | At 0.5: monster rooms feel sparse. At 1.0: cap disabled, full density alongside monsters. |
| 3 | `ENTRY_HALL_CAP_TABLE` | int[7] | [1,1,1,2,2,2,3] | 0–4 per night | Maximum anomalies in Entry Hall per night. | Setting to 0 makes Entry Hall permanently clean. Setting above 4 exceeds Entry Hall's spawn slot count. |
| 4 | `HOT_ROOM_TABLE` | StringName[7] | [MC,MC,CH,NR,NR,BR,PO] | Any valid room_id | Which room is the hot zone per night. | Changing this reshapes the night-to-night pacing arc. Entry Hall should never be hot (enforced). |
| 5 | `SEVERITY_PCT_TABLE` | float[7][3] | See per-night severity mix table | Per-tier: 0.0–1.0, row sums ≤ 1.0 | Tier mix per night — controls escalation curve shape. | If PCT_T2 + PCT_T3 > 1.0 - MC/AT, `t1_env` goes negative (clamped per Edge Case #3). |
| 6 | `MIN_DENSITY_NIGHT` | int | 3 | 1–7 | Night at which the "every room gets ≥1 anomaly" rule activates. | Setting to 1 forces early spread (less curated feel). Setting to 7 allows sparse rooms until boss night. |
| 7 | `FIXED_MODE_VALIDATION_THRESHOLD` | float | 0.5 | 0.25–0.75 | Percentage of `anomaly_target(n)` below which a Fixed Mode config triggers a critical error. | Lower values are more permissive of sparse authoring. Higher values catch more authoring mistakes. |
| 8 | `MONSTER_SEPARATION_MODE` | enum | `ADJACENCY` | `ADJACENCY`, `ROOM_ONLY`, `NONE` | How strictly monsters are separated. | `ADJACENCY`: full separation + adjacency check. `ROOM_ONLY`: same-room prohibition only. `NONE`: no constraint (testing only). |
| 9 | `ANCHOR_PERSISTENCE` | bool | true | true/false | Whether anchor anomalies occupy the same spawn point across nights. | Only meaningful in Template Mode. If false, anchors participate in normal allocation. |
| 10 | `REMAINDER_TIEBREAK` | enum | `ALPHABETICAL` | `ALPHABETICAL`, `SLOT_COUNT_DESC` | Secondary sort when rooms have identical fractional parts during remainder distribution. | `ALPHABETICAL`: deterministic by name. `SLOT_COUNT_DESC`: larger rooms absorb remainder first. |

**Knobs NOT owned by APE** (tuned elsewhere, consumed here):
- `anomaly_target(n)` — owned by Night Progression
- `monster_count(n)` — owned by Night Progression
- `active_spawn_slots(R,N)` — owned by Room/Level Management
- Spawn point tags and adjacency — owned by Room/Level Management

## Visual/Audio Requirements

No visual or audio requirements. The APE is pure infrastructure — it produces data (PlacementManifest) consumed by the Anomaly System. All visual and audio feedback for anomalies is owned by Anomaly System and Audio System respectively.

## UI Requirements

No UI requirements. The APE has no player-facing display. The optional `get_anomaly_count()` query is available for debug overlays (owned by HUD/UI System if used).

## Acceptance Criteria

> **17 criteria testable at MVP** (Fixed Mode + state machine + core constraints).
> **22 criteria marked `[DEFERRED]`** — testable after Template Mode implementation.

### Manifest Building

- **AC-APE-001**: **GIVEN** engine in IDLE, **WHEN** `configure_for_night(3)` called during LOADING, **THEN** engine transitions IDLE→BUILDING→READY, emits `placement_manifest_ready(3)`, and `get_manifest().night` returns 3.
- **AC-APE-002**: **GIVEN** engine in READY for night 4, **WHEN** `get_manifest()` called twice, **THEN** both return identical content and mutating the returned object does not alter the engine's stored manifest (copy, not live reference).
- **AC-APE-003** `[DEFERRED]`: **GIVEN** Template Mode night 5 (AT=9, MC=2), **WHEN** manifest built, **THEN** `get_anomaly_count()` returns 9. *(Under degraded conditions — Edge Cases #4, #10, #20 — total may be less than target; shortfall is logged.)*
- **AC-APE-004**: **GIVEN** Fixed Mode with valid NightPlacementConfig for night 1 (3 entries), **WHEN** `configure_for_night(1)` completes, **THEN** manifest contains exactly those 3 entries with matching `anomaly_id`, `room_id`, and `spawn_point_index`.
- **AC-APE-005**: **GIVEN** manifest built for night 3, **WHEN** Anomaly System reads it after Night Progression advanced to night 4, **THEN** `manifest.night != current_night` detected, manifest discarded, no anomalies placed, critical error logged.

### Severity Tiers

- **AC-APE-006** `[DEFERRED]`: **GIVEN** Template Mode, **WHEN** `configure_for_night(N)` called for N=1–7, **THEN** manifest tier counts match the severity table (e.g., night 6: t1=3, t2=4, t3_env=1, monsters=2).
- **AC-APE-007** `[DEFERRED]`: **GIVEN** Template Mode night 4 (AT=7, MC=1, t3_raw=1), **WHEN** manifest built, **THEN** t3_env=0 (monster consumes entire Tier 3 budget), no environmental Tier 3 entries in manifest.
- **AC-APE-008** `[DEFERRED]`: **GIVEN** Template Mode, **WHEN** floor-rounded tier counts don't sum to T_env, **THEN** remainder assigned to lowest unfilled tier.
- **AC-APE-009**: **GIVEN** SEVERITY_PCT_TABLE misconfigured so t1_env would go negative, **WHEN** manifest built, **THEN** t1_env clamped to 0, t2_env reduced by deficit, warning logged.

### Room Distribution

- **AC-APE-010** `[DEFERRED]`: **GIVEN** Template Mode night 5 with GDD worked example inputs, **WHEN** manifest built, **THEN** room allocations match: entry_hall=1, main_classroom=2, art_corner=1, cubby_hall=1, nap_room=1, bathroom=1 (sum=7).
- **AC-APE-011** `[DEFERRED]`: **GIVEN** Template Mode, Main Classroom is hot room (S=8), **WHEN** weights computed, **THEN** Main Classroom weight=14.0 (8×1.75), non-hot room with S=4 weight=4.0.
- **AC-APE-012** `[DEFERRED]`: **GIVEN** Template Mode night 2, entry_hall alloc=2 before cap, **WHEN** cap applied (max 1), **THEN** entry_hall reduced to 1, surplus +1 to highest-weight non-Entry-Hall room with capacity, total unchanged.
- **AC-APE-013** `[DEFERRED]`: **GIVEN** Template Mode, **WHEN** `configure_for_night(N)` for N∈{3,4,7}, **THEN** Entry Hall capped at 1, 2, 3 respectively.
- **AC-APE-014** `[DEFERRED]`: **GIVEN** two rooms with identical fractional parts, **WHEN** remainder distributed, **THEN** earlier alphabetical `room_id` gets +1 first (deterministic).
- **AC-APE-015** `[DEFERRED]`: **GIVEN** Template Mode night 3 (3 rooms, T_env=5), **WHEN** manifest built, **THEN** every accessible room has ≥1 anomaly.
- **AC-APE-016** `[DEFERRED]`: **GIVEN** Template Mode night 3 (6 rooms, T_env=5), **WHEN** manifest built, **THEN** at most 5 rooms get 1 each, remaining room gets 0, no error logged, total=5.
- **AC-APE-017** `[DEFERRED]`: **GIVEN** room with active_spawn_slots=2 receiving raw alloc=4, **WHEN** cap applied, **THEN** final alloc=2, shortfall logged.

### Monster Constraints

- **AC-APE-018**: **GIVEN** any night with monster_count≥1, **WHEN** manifest built, **THEN** no entry in `get_monster_entries()` has `room_id == "entry_hall"`.
- **AC-APE-019**: **GIVEN** night 5 (MC=2), **WHEN** manifest built, **THEN** two monster entries have different `room_id` values.
- **AC-APE-020** `[DEFERRED]`: **GIVEN** MONSTER_SEPARATION_MODE=ADJACENCY, night 5 (MC=2), **WHEN** manifest built, **THEN** monster rooms do not appear in each other's adjacency lists.
- **AC-APE-021** `[DEFERRED]`: **GIVEN** night 7 (MC=3) with adjacency making non-adjacent placement impossible, **WHEN** manifest built, **THEN** engine relaxes to same-room prohibition, warning logged, no crash.
- **AC-APE-022** `[DEFERRED]`: **GIVEN** Template Mode, room R with monster (MONSTER_CAP_MODIFIER=0.75, S=8, H=1.0), **WHEN** weight computed, **THEN** weight=6.0.
- **AC-APE-023** `[DEFERRED]`: **GIVEN** Template Mode night 3, monster room's alloc rounds to 0 after 0.75 cap, **WHEN** minimum density active, **THEN** alloc raised to 1.

### Tag Compatibility

- **AC-APE-024**: **GIVEN** drawing anomaly (compatible_tags=[WALL]) and spawn point with tag=FLOOR, **WHEN** manifest built, **THEN** drawing not assigned to that spawn point.
- **AC-APE-025** `[DEFERRED]`: **GIVEN** all WALL points in a room occupied and next candidate requires WALL, **WHEN** manifest built, **THEN** anomaly skipped for that room, alloc reduced, shortfall logged.

### Fixed Mode Validation

- **AC-APE-026**: **GIVEN** Fixed Mode, no NightPlacementConfig for night 2, **WHEN** `configure_for_night(2)` called, **THEN** READY with empty manifest, `placement_manifest_ready(2)` emitted, critical error logged, no crash.
- **AC-APE-027**: **GIVEN** Fixed Mode config with duplicate (room="main_classroom", index=2), **WHEN** manifest built, **THEN** first entry wins, second skipped, warning logged.
- **AC-APE-028**: **GIVEN** Fixed Mode config with monster in entry_hall, **WHEN** manifest built, **THEN** entry skipped, error logged.
- **AC-APE-029**: **GIVEN** Fixed Mode entry with unknown `anomaly_id`, **WHEN** manifest built, **THEN** entry skipped, error logged.
- **AC-APE-030**: **GIVEN** Fixed Mode night 3 (AT=6), 4 of 6 entries invalid (33% < 50% threshold), **WHEN** manifest built, **THEN** critical error logged, 2 valid entries included.

### State Machine

- **AC-APE-031**: **GIVEN** engine in IDLE (no configure_for_night called), **WHEN** `get_manifest()` called, **THEN** returns null.
- **AC-APE-032**: **GIVEN** engine in BUILDING for night 3, **WHEN** second `configure_for_night(3)` arrives, **THEN** duplicate ignored, warning logged, build completes normally.
- **AC-APE-033**: **GIVEN** engine in BUILDING for night 3, **WHEN** `configure_for_night(4)` arrives, **THEN** critical error logged (Night Progression failure), call ignored.
- **AC-APE-034**: **GIVEN** engine in READY after night 2, **WHEN** Night Progression emits terminal transition, **THEN** engine→IDLE, manifest cleared, `get_manifest()` returns null.
- **AC-APE-035**: **GIVEN** Fixed Mode READY for night 3, **WHEN** death restart triggers `configure_for_night(3)` again, **THEN** old manifest cleared, new manifest identical to previous, `placement_manifest_ready(3)` re-emitted.
- **AC-APE-036**: **GIVEN** engine in READY, **WHEN** caller modifies array from `get_entries_for_room()`, **THEN** subsequent call returns original unmodified data.

### Formula Guards

- **AC-APE-037** `[DEFERRED]`: **GIVEN** all rooms return active_spawn_slots=0 (total_weight=0), **WHEN** Template Mode `configure_for_night(N)` called, **THEN** no division attempted, empty manifest, critical error logged, no crash.
- **AC-APE-038** `[DEFERRED]`: **GIVEN** AT==MC (T_env=0), **WHEN** Template Mode manifest built, **THEN** room allocation skipped, minimum density not applied, manifest contains only monster entries.
- **AC-APE-039** `[DEFERRED]`: **GIVEN** Entry Hall surplus redistribution but all rooms at capacity, **WHEN** redistribution runs, **THEN** surplus discarded, shortfall logged, no infinite loop.

## Open Questions

| # | Question | Owner | Target |
| --- | --- | --- | --- |
| ~~OQ-1~~ | **RESOLVED: `configure_for_night(n)` is synchronous.** BUILDING is an internal implementation state, not externally observable. AC-APE-032 and AC-APE-033 are reframed: they test duplicate/mismatched calls arriving after the previous build completes (READY state), not during BUILDING. GDScript is single-threaded; async adds complexity with no benefit for a one-shot config pass. | — | Resolved 2026-04-11 |
| OQ-2 | **How does the engine detect adjacency-mode is unsatisfiable?** Options: (a) pre-check adjacency graph before placing, (b) attempt N placements then fallback, (c) solve as constraint satisfaction. Affects AC-APE-021. | Systems Designer | Before Template Mode implementation |
| OQ-3 | **Hot room fallback ordering when designated hot room is inaccessible**: Should fallback use `active_spawn_slots` (slot count, no modifiers) or some other ordering? Current spec says "highest-weight accessible room" but weight depends on the hotspot modifier being reassigned — circular. | Systems Designer | Before Template Mode implementation |
| OQ-4 | **Template Mode degraded-path threshold**: Fixed Mode has a 50% threshold (Edge Case #15). Should Template Mode have an equivalent minimum manifest count before logging a critical error? | Game Designer | Before Template Mode implementation |
| OQ-5 | **Template Mode death restart: deterministic or re-rolled?** Seeded RNG (same positions on restart) vs. fresh roll (different positions). Player fairness vs. freshness tradeoff. See Edge Case #22. | Game Designer | Before Template Mode implementation |
| ~~OQ-6~~ | **RESOLVED: Main Classroom for MVP.** Monster goes in Main Classroom (most familiar room, subverts comfort). Full Vision uses Cubby Hall per hot room table — author a separate NightPlacementConfig variant. | — | Resolved 2026-04-11 |
