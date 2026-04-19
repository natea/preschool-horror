# Room/Level Management

> **Status**: Designed
> **Author**: Nate Aune + agents
> **Last Updated**: 2026-04-09
> **Implements Pillar**: Pillar 1 ("Something's Wrong Here") — the spatial container that makes wrongness possible; Pillar 4 ("One More Night") — rooms must feel different across nights

## Overview

Room/Level Management is the spatial data layer for Show & Tell. It defines the preschool as a single continuous scene containing 5-7 hand-designed rooms (3 for MVP), each with a unique identity, physical boundaries, entry/exit points, and per-night state configuration. The system tracks the player's current room via boundary detection and exposes a room-query API that 4 downstream systems depend on: Night Progression (which rooms are accessible per night), Anomaly Placement Engine (which rooms receive which anomalies), Anomaly System (room-scoped anomaly behavior), and Vent System (vent entry/exit points per room). All rooms are loaded simultaneously in a single Godot scene — the small scale (5-7 rooms on one floor) makes streaming unnecessary and keeps transitions seamless. The system does not handle room decoration, anomaly placement, or lighting changes across nights — it provides the spatial skeleton that those systems dress. Players never interact with this system directly; they experience the preschool as a navigable space and never think about room boundaries or scene management.

## Player Fantasy

**"Memory Geography."** The player should develop an intimate, anxious map of the preschool — not from a UI minimap, but from accumulated dread. The cubbyholes room is where it got bad on Night 3. The nap room is where you never go alone anymore. The art corner is where the drawings changed. Room/Level Management earns this by giving each space a distinct identity — name, layout, landmarks, lighting character — that persists across nights and degrades according to the night tier. The fantasy is the slow accumulation of spatial memory under stress: knowing the layout and dreading it.

This is an indirect fantasy — the player never thinks about room boundaries or scene management. They think "I know this building now, and that makes it worse." The system delivers this by ensuring rooms are recognizable enough to remember and distinct enough that each carries its own emotional weight.

*Serves Pillar 1: "Something's Wrong Here" — rooms that the player knows well make wrongness more noticeable. Serves Pillar 4: "One More Night" — each room's identity deepens as it degrades across nights.*

## Detailed Design

### Core Rules

#### Room Definition

Each room is a named `Area3D` node in the master preschool scene. It carries a static `RoomData` resource (authored in the editor) and a runtime `RoomRuntimeState` object (mutated per night by Night Progression).

**RoomData Resource (static, authored once):**

| Field | Type | Description |
|---|---|---|
| `room_id` | StringName | Unique key (e.g., `&"nap_room"`) used by all downstream queries |
| `display_name` | String | Human-readable name for UI/debug |
| `boundary_shape` | Shape3D | Collision shape of the Area3D — defines room membership |
| `spawn_points` | Array[Transform3D] | Named positions where anomalies may be placed (4-8 per room) |
| `spawn_point_tags` | Array[StringName] | Parallel array: tag per spawn point (`FLOOR`, `WALL`, `CEILING`, `FURNITURE_TOP`) |
| `vent_entries` | Array[NodePath] | Paths to VentEntry nodes in this room |
| `adjacency` | Array[StringName] | Room IDs that border this room (used for monster routing) |
| `first_accessible_night` | int | Night number (1-7) when this room unlocks |
| `base_spawn_slots` | int | Maximum spawn points available at full horror tier |

#### Boundary Detection

The player is "in" a room when their capsule center enters that room's Area3D. Room Area3D nodes use a dedicated physics layer (e.g., layer 4) with `body_entered` / `body_exited` signals connected to a `RoomManager` singleton.

**Threshold rule:** If the player straddles two rooms (standing in a doorway), the **last room they fully entered** is the authoritative current room. This prevents rapid signal flickering at doorways. "Fully entered" = `body_entered` fired AND the previous room's `body_exited` has fired.

#### Spawn Points

Each room carries 4-8 labeled `Transform3D` positions. Spawn points are tagged by surface type: `FLOOR`, `WALL`, `CEILING`, `FURNITURE_TOP`. The Anomaly Placement Engine queries spawn points by room and tag filter. Rooms do not decide which anomaly goes where — they advertise available positions.

#### The Preschool Layout

Seven rooms, one floor, single continuous scene. MVP ships rooms marked (MVP).

```
[ENTRY HALL] ── [MAIN CLASSROOM] ── [ART CORNER]
      │                 │
 [NAP ROOM]        [CUBBY HALL]
      │                 │
  [BATHROOM]      [PRINCIPAL'S OFFICE]
```

| Room ID | Display Name | First Night | MVP | Spawn Slots | Horror Role |
|---|---|---|---|---|---|
| `entry_hall` | Entry Hall | 1 | YES | 4 | Start/exit point. Familiarity anchor — the most "normal" room, making changes here feel most wrong |
| `main_classroom` | Main Classroom | 1 | YES | 8 | Largest room. Primary anomaly density. Tiny chairs, blocks, bulletin board |
| `art_corner` | Art Corner | 1 | YES | 4 | Alcove off classroom. Drawings that change. Small, intimate, suffocating |
| `cubby_hall` | Cubby Hall | 2 | — | 5 | Connecting corridor with cubbies. Tight space. First monster appears here (Night 3) |
| `nap_room` | Nap Room | 2 | — | 6 | Dark room with cots. The room the player dreads entering alone |
| `bathroom` | Bathroom | 3 | — | 5 | Mirrors, stalls. Mirror anomalies. Vent hub — most vent routes pass through here |
| `principals_office` | Principal's Office | 7 | — | 3 | Boss's room. Locked Nights 1-6. Inaccessible mystery. Night 7 reveal location |

**Spatial scale:** The full preschool footprint is approximately 20m x 15m. At `player_walk_speed = 2.0 m/s`, crossing the full building takes ~12 seconds. No room should feel out-of-reach — the horror requires the player to go back in.

**Adjacency map:**

| Room | Adjacent To |
|---|---|
| `entry_hall` | `main_classroom`, `nap_room` |
| `main_classroom` | `entry_hall`, `art_corner`, `cubby_hall` |
| `art_corner` | `main_classroom` |
| `cubby_hall` | `main_classroom`, `principals_office` |
| `nap_room` | `entry_hall`, `bathroom` |
| `bathroom` | `nap_room` |
| `principals_office` | `cubby_hall` |

### States and Transitions

Each room maintains a `RoomRuntimeState` at runtime:

| Field | Type | Values | Description |
|---|---|---|---|
| `access_state` | enum | `LOCKED`, `ACCESSIBLE` | Whether the player can physically enter |
| `horror_tier` | int | 1-3 | Controls ambient lighting/audio variant |
| `active_spawn_slots` | int | 0-N | How many spawn points are available this night (formula in Formulas section) |
| `lights_on` | bool | true/false | Room lighting state (driven by night tier) |

**Horror Tier mapping:**

| Night | Horror Tier | Rooms Accessible |
|---|---|---|
| 1-2 | 1 | Rooms with `first_accessible_night` <= 2 |
| 3-4 | 2 | Rooms with `first_accessible_night` <= 4 |
| 5-7 | 3 | Rooms with `first_accessible_night` <= 7 (except Principal's Office: Night 7 only) |

**State transitions fire once at night-start.** Night Progression calls `RoomManager.configure_for_night(night_number: int)`. The Room system does not poll or self-transition. Night Progression owns the trigger; Room Management owns the state.

**Principal's Office special case:** `access_state = LOCKED` for Nights 1-6. On Night 7, Night Progression calls `unlock_room(&"principals_office")`, changing it to `ACCESSIBLE` and emitting `room_unlocked`.

### Interactions with Other Systems

#### Outputs (Room Management emits/exposes)

**Signals:**

| Signal | Parameters | Listeners |
|---|---|---|
| `player_entered_room(room_id: StringName)` | room_id | Anomaly System, Night Progression, Audio System, HUD |
| `player_exited_room(room_id: StringName)` | room_id | Anomaly System, Audio System |
| `room_unlocked(room_id: StringName)` | room_id | Night Progression (boss sequence trigger) |
| `room_state_changed(room_id: StringName, new_state: RoomRuntimeState)` | both | Anomaly Placement Engine |

**Query API:**

| Method | Returns | Callers |
|---|---|---|
| `get_current_room() -> StringName` | Current room ID | Anomaly System, Player Survival, Audio |
| `get_room_data(room_id) -> RoomData` | Static room data | Any system needing room properties |
| `get_room_spawn_points(room_id, tag_filter) -> Array[Transform3D]` | Filtered spawn points | Anomaly Placement Engine |
| `get_vent_entries(room_id) -> Array[NodePath]` | Vent node paths | Vent System |
| `get_accessible_rooms() -> Array[StringName]` | All ACCESSIBLE room IDs | Night Progression, Anomaly Placement |
| `get_adjacent_rooms(room_id) -> Array[StringName]` | Adjacent room IDs | Monster AI (routing) |
| `is_room_accessible(room_id) -> bool` | bool | Night Progression, Monster AI |

#### Inputs (other systems call into Room Management)

| Caller | Method | Effect |
|---|---|---|
| Night Progression | `configure_for_night(n: int)` | Sets horror_tier, access_state, lights_on, active_spawn_slots for all rooms |
| Night Progression | `unlock_room(room_id: StringName)` | Sets single room to ACCESSIBLE, emits `room_unlocked` |

**Room Management has no dependencies on downstream systems.** It is a pure data/query layer. Downstream systems depend on it; it does not depend on them.

## Formulas

### Active Spawn Slots

The `active_spawn_slots` formula determines how many of a room's spawn points are available to the Anomaly Placement Engine on a given night. This controls anomaly density escalation — sparse early, dense late.

`active_spawn_slots(R, N) = floor(base_spawn_slots(R) * tier_multiplier(N))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_spawn_slots | R | int | 3-8 | The authored maximum spawn points for room R |
| tier_multiplier | N | float | {0.25, 0.5, 1.0} | Fraction of slots available based on horror tier |
| active_spawn_slots | — | int | 0-8 | Slots available to Anomaly Placement Engine for room R on night N |

**Tier Multiplier Values:**

| Horror Tier | Nights | Multiplier | Rationale |
|---|---|---|---|
| 1 | 1-2 | 0.25 | Sparse. Wrongness is subtle. Pillar 1 requires restraint early. |
| 2 | 3-4 | 0.50 | Rising. Monsters appear. Anomaly density doubles to match threat. |
| 3 | 5-7 | 1.00 | Full. Every slot active. Maximum chaos. Pillar 4 demands it. |

**Output Range:** 0 to `base_spawn_slots(R)`. Clamped — cannot exceed authored capacity. Floor-rounded to prevent fractional slots.

**Example — Main Classroom (8 base slots):**
- Night 2 (Tier 1, multiplier 0.25): `floor(8 * 0.25) = 2 active slots`
- Night 4 (Tier 2, multiplier 0.50): `floor(8 * 0.50) = 4 active slots`
- Night 6 (Tier 3, multiplier 1.00): `floor(8 * 1.00) = 8 active slots`

**Example — Art Corner (4 base slots):**
- Night 1 (Tier 1): `floor(4 * 0.25) = 1 active slot`
- Night 3 (Tier 2): `floor(4 * 0.50) = 2 active slots`
- Night 7 (Tier 3): `floor(4 * 1.00) = 4 active slots`

### Traversal Time Estimate

`traversal_time(D) = D / player_walk_speed`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| distance | D | float | 0-25 m | Straight-line distance between two points in the preschool |
| player_walk_speed | — | float | 2.0 m/s | Locked constant from First-Person Controller GDD |
| traversal_time | — | float | 0-12.5 s | Time to walk between two points |

**Output Range:** 0 to ~12.5 s (full building diagonal). Not a gameplay formula — used for pacing validation during design. Confirms that no room is more than ~10 seconds from the entry hall at walking speed, supporting the "always go back in" design intent.

## Edge Cases

- **If the player straddles two room boundaries (standing in a doorway):** The last room fully entered remains the authoritative `current_room`. `body_entered` for the new room is queued as "pending" and only commits when the old room's `body_exited` fires. If `body_exited` does not arrive within one physics frame, commit on the next `_physics_process`. Prevents rapid `current_room` flickering.

- **If the player exits a dead-end room (Art Corner, Bathroom, Principal's Office) and stops mid-doorway:** On `body_exited`, do NOT clear `current_room` immediately. Keep the exited room as current until a new `body_entered` commits. Prevents transient null `current_room`.

- **If the game loads and no `body_entered` has fired yet:** `RoomManager._ready()` must initialize `current_room` by checking which Area3D contains the player's start position via `overlaps_body()`. Any downstream system calling `get_current_room()` before the player moves will get a valid room ID, not null.

- **If `configure_for_night()` sets a room to LOCKED while the player is inside it:** `LOCKED` blocks entry only — it never ejects a player already inside. Locking is defined as "blocks `body_entered` transition," not "teleports player out."

- **If `base_spawn_slots` is 3 and horror tier is 1:** `floor(3 * 0.25) = 0` active slots. This is a valid, intentional output — no anomalies in that room that night. The Anomaly Placement Engine must handle zero-slot rooms without error.

- **If `get_room_spawn_points()` is called on a LOCKED room:** Return an empty array. The Anomaly Placement Engine must not place anomalies in rooms the player cannot enter, regardless of the active slot count.

- **If Night 7 `configure_for_night(7)` and `unlock_room(&"principals_office")` have conflicting call order:** `configure_for_night(7)` must explicitly set Principal's Office to `ACCESSIBLE` as part of its Night 7 configuration. `unlock_room()` is a redundant safety call, not the primary mechanism. Call order: `configure_for_night(7)` first (sets all rooms including Principal's Office), then `unlock_room()` emits the `room_unlocked` signal for listeners.

- **If adjacency data is authored asymmetrically (room A lists room B, but B does not list A):** `RoomManager._ready()` must validate that all adjacency relationships are symmetric. Assert failure in debug builds. Asymmetric adjacency would break Monster AI pathfinding.

- **If `room_unlocked` signal fires before Night Progression has connected its listener:** Night Progression must connect to `room_unlocked` in `_ready()`, before `configure_for_night()` is ever called. Signal connection order is a load-time contract.

- **If `get_accessible_rooms()` is called before `configure_for_night()` runs on Night 1:** `RoomManager._ready()` must initialize all rooms to Night 1 defaults synchronously, before any other system's `_ready()` queries. Enforced via autoload priority (RoomManager loads before downstream systems).

## Dependencies

| System | Direction | Hard/Soft | Interface |
|---|---|---|---|
| Night Progression | Night Progression → Room Mgmt | Hard | `configure_for_night(n)`, `unlock_room(room_id)` — Night Progression drives all room state transitions |
| Anomaly Placement Engine | Room Mgmt → Anomaly Placement | Hard | `get_room_spawn_points(room_id, tag)`, `get_accessible_rooms()`, `room_state_changed` signal |
| Anomaly System | Room Mgmt → Anomaly System | Soft | `player_entered_room`, `player_exited_room`, `get_current_room()`, `get_adjacent_rooms()` |
| Vent System | Room Mgmt → Vent System | Soft | `get_vent_entries(room_id)` — vent nodes are authored per room but owned by Vent System |
| Monster AI | Room Mgmt → Monster AI | Soft | `get_adjacent_rooms()`, `get_current_room()`, `is_room_accessible()` — used for pathfinding/routing |
| Audio System | Room Mgmt → Audio | Soft | `player_entered_room`, `player_exited_room` — triggers room-specific ambient audio |
| HUD/UI | Room Mgmt → HUD | Soft | `player_entered_room` — optional room name display |
| First-Person Controller | FPC → Room Mgmt (implicit) | Hard | Player's CharacterBody3D triggers Area3D boundaries — FPC does not call Room Mgmt directly, but the physics body must exist |

**No upstream system dependencies.** Room Management is a pure foundation layer. Night Progression is the only system that *writes* to Room Management (via `configure_for_night` and `unlock_room`). All other connections are read-only queries or signal subscriptions.

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Impact |
|---|---|---|---|
| `TIER_MULTIPLIER_1` | 0.25 | 0.15 – 0.40 | Controls anomaly sparseness on Nights 1-2. Lower = emptier early nights (more restraint). Higher = more wrongness from the start. Below 0.15 risks zero anomalies in small rooms. |
| `TIER_MULTIPLIER_2` | 0.50 | 0.35 – 0.70 | Controls density when monsters first appear (Nights 3-4). Must feel like a step up from Tier 1. |
| `TIER_MULTIPLIER_3` | 1.00 | Fixed | Full capacity on Nights 5-7. Do not reduce — Pillar 4 demands maximum chaos late. |
| `base_spawn_slots` (per room) | 3-8 (see layout table) | 2 – 10 | More slots = more potential anomaly density. Below 2, the room feels empty. Above 10, placement becomes cluttered in small rooms. |
| `first_accessible_night` (per room) | 1-7 (see layout table) | 1 – 7 | Controls pacing of spatial expansion. Unlocking too many rooms early dilutes anomaly density. Unlocking too few makes early nights feel cramped. |
| `PRESCHOOL_FOOTPRINT` | ~20m x 15m | 15x10 – 25x20 | Affects traversal time and claustrophobia. Smaller = tighter horror, longer walks feel safer. Larger = more exploration but sparser encounters. Must respect `player_walk_speed = 2.0 m/s` pacing. |
| `ROOM_BOUNDARY_DEBOUNCE` | 1 frame | 1-3 frames | How long the "pending" room waits before committing as `current_room` when the old room's `body_exited` hasn't fired. Higher = more stable, but slower room-change detection. |

**Knobs owned by other systems (referenced here, do not duplicate):**
- `player_walk_speed` (2.0 m/s) — owned by First-Person Controller GDD
- `player_capsule_height` (1.75 m) — owned by First-Person Controller GDD
- Horror tier-to-night mapping — will be owned by Night Progression GDD

## Visual/Audio Requirements

### Art Bible Principles Applied

- **"Color Debt"** is the primary visual driver. Horror tier transitions are color temperature and saturation events: Tier 1 = 3200K warm pastels, Tier 2 = 4500K cooling with Infection Violet in shadows, Tier 3 = 5500K-6500K clinical cold with isolated Crayola Red and decayed greens.
- **"Familiar Shapes, Foreign Behavior"** governs per-room identity. Every room has one landmark object the player memorizes. Horror enters through disturbance of that landmark, not through its form.
- **"The Camera Tells the Truth"** — rooms must not hide anomalies through darkness on Tiers 1-2. Tier 3 lighting pools create genuine occlusion — the shift from "everything is lit" to "you can't see the corners" is deliberate and earned.

### Night-Start Visual Transition

When `configure_for_night()` fires, the visual shift must not be instantaneous. A 3-5 second ambient lerp: light color temperature shifts, overhead flicker increases briefly, then settles.

- **Tier 1 → Tier 2:** One overhead per room dies (flicker, spark, out). Wall material emission cools ~200K. Infection Violet appears in deep shadow vertices only.
- **Tier 2 → Tier 3:** Multiple overheads die, emergency lighting activates. Crayola Green surfaces swap to mold variant. Chalk White walls shift to cold institutional white. Surviving warm practicals become visual orphans.

**WebGL 2 constraint:** All color shifts via material property lerps (albedo tint, emission color), NOT post-process color grading. Light nodes use `color` and `energy` properties animated by Night Progression. No SSR, no SSAO — fake ambient occlusion with baked textures.

**Principal's Office unlock (Night 7):** A single cold flash from under the door. Door handle light changes warm to cold. No animation, no fanfare — the wrongness is that it opens.

### Per-Room Visual Identity

Each room has one **invariant landmark** (never removed by anomalies) that anchors the player's spatial memory and serves as the Color Debt calibration surface.

| Room | Landmark | Visual Signature | Lighting Character |
|---|---|---|---|
| Entry Hall | Cubby name labels with warm strip light | Widest, most even illumination. "Most normal" room — reference state. | Overlit for false comfort. Warm practical survives into Tier 3. |
| Main Classroom | Bulletin board with finger-paintings | Primary Color Debt surface. Paintings decay first. 8 spawn slots = maximum visual clutter escalation. | Center overhead key light. Tier 3: two dead overheads create diagonal shadow bands. |
| Art Corner | Child-sized easel with persistent drawing | Most intimate room. Proximity compression — paintings in periphery everywhere. Changes caught at edge of vision. | Table lamp only, no overhead. Always slightly underlit. |
| Cubby Hall | One named cubby that never opens | Tight corridor forces close encounters. Monster silhouette fills visual field. | Fluorescent strip down center. Tier 2+: one end dead, creating lit/unlit binary. |
| Nap Room | Named cot in fixed position | Pre-established dread room. Low baseline even at Tier 1 — never felt safe. | Floor-height practicals only. Ceiling permanently unlighted. |
| Bathroom | Mirror over sink (always reflects correctly) | Mirror correctness on Nights 1-2 trains expectation. Vent hub = audio cross-bleed. | Cold fluorescent, highest contrast. Tiles multiply light. Stall interiors unlit from Tier 1. |
| Principal's Office | Boss's desk — oversized, hero-lit | Sealed Nights 1-6. Crack of cold light under door (Nights 5-6 only). Night 7: boss debrief framing inverted — warm amber becomes clinical cold. | Night 7 only: cold practical behind desk. |

### Audio Requirements (per room, delivered via `player_entered_room` signal)

| Room | Audio Signature | Design Intent |
|---|---|---|
| Entry Hall | Distant street sounds, HVAC hum. Most "normal" audio in the game. | Its normalcy is the dread-anchor. When this stops sounding normal (Tier 3), the player has lost their last safe reference. |
| Art Corner | Paper and crayon texture. Small reverb. Anomaly sounds quieter than expected. | Proximity makes quiet more threatening than loud. |
| Cubby Hall | Corridor echo isolating footstep sounds. | Player hears themselves. Monster audio introduced here first — sonic signature before other rooms inherit it. |
| Nap Room | No ambient. Silence is the signature. | Any audio event hits harder against silence. |
| Bathroom | Echo and tile acoustics. Vent cross-bleed from adjacent rooms. | Player hears the Nap Room's silence echoing through tiles. Spatial disorientation is intentional. |
| Principal's Office | No prepared ambient — player has never heard this room. | Unfamiliarity is the final horror beat. |

## UI Requirements

Room/Level Management has no direct UI surfaces. Room identity is communicated through environment design (landmarks, lighting, audio), not through HUD elements or menus.

The `player_entered_room` signal is available to the HUD/UI System for optional room name display (e.g., a brief text overlay on first entry per night), but this is owned by the HUD/UI GDD, not this system.

## Acceptance Criteria

- **AC-RLM-01:** **GIVEN** the master preschool scene is loaded, **WHEN** `RoomManager._ready()` completes, **THEN** all 7 `RoomData` resources are registered with non-null `room_id`, `base_spawn_slots > 0`, and valid `boundary_shape`.

- **AC-RLM-02:** **GIVEN** the player's CharacterBody3D is at the authored start position, **WHEN** `get_current_room()` is called immediately after scene load (before the player moves), **THEN** the return value is a non-empty `StringName` matching a valid `room_id`.

- **AC-RLM-03:** **GIVEN** the player is in `entry_hall`, **WHEN** the player's capsule center fully crosses into `main_classroom` (`body_entered` fires AND `entry_hall`'s `body_exited` fires), **THEN** `get_current_room()` returns `&"main_classroom"` and `player_entered_room(&"main_classroom")` has been emitted.

- **AC-RLM-04:** **GIVEN** the player straddles the boundary between two rooms (`body_entered` fired for the new room but `body_exited` has NOT yet fired for the old room), **WHEN** `get_current_room()` is called, **THEN** it returns the old room (last fully entered) and does NOT change more than once per physics frame.

- **AC-RLM-05:** **GIVEN** `configure_for_night(3)` is called, **WHEN** the call completes, **THEN** every room with `first_accessible_night <= 3` has `access_state == ACCESSIBLE`, every room with `first_accessible_night > 3` has `access_state == LOCKED`, and `horror_tier == 2` on all rooms.

- **AC-RLM-06:** **GIVEN** `main_classroom` has `base_spawn_slots = 8`, **WHEN** `configure_for_night(2)` is called (Tier 1, multiplier 0.25), **THEN** `active_spawn_slots == 2`.

- **AC-RLM-07:** **GIVEN** `main_classroom` has `base_spawn_slots = 8`, **WHEN** `configure_for_night(4)` is called (Tier 2, multiplier 0.50), **THEN** `active_spawn_slots == 4`.

- **AC-RLM-08:** **GIVEN** `main_classroom` has `base_spawn_slots = 8`, **WHEN** `configure_for_night(6)` is called (Tier 3, multiplier 1.00), **THEN** `active_spawn_slots == 8`.

- **AC-RLM-09:** **GIVEN** a room has `base_spawn_slots = 3`, **WHEN** `configure_for_night(1)` is called (Tier 1, `floor(3 * 0.25) = 0`), **THEN** `active_spawn_slots == 0` AND `get_room_spawn_points()` returns an empty array without error.

- **AC-RLM-10:** **GIVEN** the player is inside a room AND `configure_for_night()` sets that room to `LOCKED`, **WHEN** the player's position is checked, **THEN** the player remains at their current position (no teleport) and `get_current_room()` still returns that room.

- **AC-RLM-11:** **GIVEN** a room with `access_state == LOCKED`, **WHEN** `get_room_spawn_points()` is called, **THEN** the return value is an empty array regardless of `active_spawn_slots`.

- **AC-RLM-12:** **GIVEN** the authored `RoomData` adjacency lists, **WHEN** `RoomManager._ready()` runs in debug build, **THEN** if any room A lists room B as adjacent but B does not list A, an assertion failure is raised.

- **AC-RLM-13:** **GIVEN** a fresh game state, **WHEN** `configure_for_night(N)` is called for any N in {1, 2, 3, 4, 5, 6}, **THEN** `principals_office.access_state == LOCKED`.

- **AC-RLM-14:** **GIVEN** Night Progression has connected to `room_unlocked`, **WHEN** `configure_for_night(7)` completes, **THEN** `principals_office.access_state == ACCESSIBLE` AND `room_unlocked` was emitted with `&"principals_office"` exactly once.

- **AC-RLM-15:** **GIVEN** a scene that has loaded but `configure_for_night()` has never been called, **WHEN** `get_accessible_rooms()` is called, **THEN** it returns at least `entry_hall`, `main_classroom`, and `art_corner` (Night 1 defaults) — never an empty array.

## Open Questions

1. **Should room boundaries overlap in doorways, or should there be a thin "hallway" zone between rooms?** Overlapping boundaries are simpler (the threshold rule handles it), but a neutral zone could prevent edge cases. → Resolve during architecture/prototyping.

2. **Should the bathroom's vent hub have visible connections to multiple rooms, or should vents be invisible until the player discovers them?** Affects both level design and the Vent System GDD. → Defer to Vent System design.

3. **Should rooms have per-night furniture rearrangement (chairs moved, blocks scattered) as a visual corruption signal, or only lighting/color changes?** Furniture state adds to "Memory Geography" fantasy but increases art authoring scope. → Decide during vertical slice.

4. **Should the Nap Room be accessible from Night 1 instead of Night 2?** Making it a Night 1 room gives the player an early dread anchor. Keeping it Night 2 preserves the feeling of the preschool "opening up." → Playtest decision.

5. **How should locked doors communicate "locked" to the player?** A visual cue (padlock, chain, different door color) or just a non-interactive door? Affects FPC interaction raycast behavior. → Resolve in HUD/UI or Level Design.

6. **3D asset sourcing:** Two asset marketplaces identified for potential low-poly preschool/horror assets — itch.io (https://itch.io/game-assets/tag-3d/tag-horror) and Quaternius (https://quaternius.com/index.html). Evaluate during pre-production for furniture, props, and room dressing.
