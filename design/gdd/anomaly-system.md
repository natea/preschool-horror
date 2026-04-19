# Anomaly System

> **Status**: In Design
> **Author**: Nate Aune + agents
> **Last Updated**: 2026-04-12
> **Implements Pillar**: Pillar 1 ("Something's Wrong Here") — anomalies ARE the wrongness; Pillar 2 ("Prove It") — anomalies are the photography targets

## Overview

The Anomaly System is the content behavior layer for Show & Tell. It defines what anomalies *are* — their visual identity, behavioral states, and photo-detection criteria — and manages their runtime lifecycle from instantiation through photographing to night-end cleanup. At night start, the system receives a `PlacementManifest` from the Anomaly Placement Engine (which decides *where* anomalies go) and instantiates the corresponding anomaly scene instances at their assigned spawn points. Each anomaly carries an `AnomalyDefinition` resource specifying its type (environmental or monster), severity tier (1–3), compatible spawn tags, visual scene, detection zone geometry, and photo-scoring parameters. Environmental anomalies are static or subtly animated wrongness — a drawing that changed, blocks that spell something, a chair on the ceiling — that the player must notice and photograph. Monster anomalies are reactive creatures belonging to one of three archetypes (Dolls, Shadows, Large) that move, react to the player, and can kill. The system exposes a detection API that the Photography System will consume to evaluate whether an anomaly is properly framed in a photo: frustum presence, distance, facing angle, and occlusion checks. It also exposes anomaly state to Monster AI (which controls monster behavior) and to the Audio System (which drives proximity-based audio cues). The Anomaly System does not decide anomaly counts or placement (that's APE), does not control monster pathfinding or behavior trees (that's Monster AI), and does not evaluate photo quality (that's Photography). It is the bridge between placement decisions and player-facing content — the layer that turns a data manifest into a haunted preschool.

## Player Fantasy

**"That Wasn't Like That Before."** The player should feel the specific, skin-crawling moment of noticing something wrong in a space they thought they knew. Not a jumpscare — a slow realization. You walk into the Main Classroom and the finger-paintings on the bulletin board are different. You're *almost* sure. You raise the camera to prove it to yourself, and the viewfinder confirms: yes, that drawing is new, and it's watching you. The anomaly didn't move. You don't know when it changed. But you know it wasn't like that before, and now you have to decide: photograph it and stand still in a room that just proved it can change without you noticing — or leave, and wonder what else changed while you weren't looking.

The Anomaly System serves two fantasies that operate on different timescales:

- **Environmental anomalies — the detective's eye.** The indirect fantasy. Nights 1–2, every anomaly is a puzzle to spot. The player scans rooms looking for what's wrong. Finding one feels like a small victory: *I noticed. I'm paying attention. I'm the only one who sees this.* The camera confirms the observation and converts it into evidence. The fantasy is competence under unease — the player who learns to read the preschool's visual language is rewarded with the best photos. By Night 5, the wrongness is obvious and everywhere, and the detective fantasy inverts: *I can't photograph all of this. What do I prioritize?* The skill shifts from noticing to triaging.

- **Monster anomalies — the prey's dilemma.** The direct fantasy. Starting Night 3, some anomalies look back. The Doll on the floor in Cubby Hall isn't a placement puzzle — it's a threat assessment. The player must raise the camera (slowing to 1.5 m/s, feeding the vulnerability bar) to photograph a creature that might react to the flash. The fantasy is the horror-movie moment the audience screams at: *don't take the picture, just run* — but the player takes it anyway, because the evidence is why they came. Pillar 2 ("Prove It") lives in this tension. The camera makes you brave and vulnerable simultaneously.

The progression across 7 nights is the metamorphosis of the first fantasy into the second. Night 1: every anomaly is a subtle environmental detail. Night 7: the preschool is hostile territory and every room is a negotiation between evidence and survival. The player who mastered the detective's eye on Night 1 now uses that same skill to read monster behavior, spot safe angles for photography, and decide which anomalies are worth the risk.

*Serves Pillar 1: "Something's Wrong Here" — the anomalies ARE the wrongness, progressing from ambiguous to undeniable. Serves Pillar 2: "Prove It" — every anomaly exists to be photographed, creating the core gameplay verb. Serves Pillar 4: "One More Night" — the anomaly mix escalates so each night feels distinct.*

## Detailed Design

### Core Rules

#### Anomaly Definition Resource

Each anomaly type is defined once as an `AnomalyDefinition` resource (authored in the editor, loaded at runtime). The Anomaly System maintains a dictionary of all definitions keyed by `anomaly_id`.

**AnomalyDefinition fields:**

| Field | Type | Description |
|---|---|---|
| `anomaly_id` | StringName | Unique key matching `PlacementEntry.anomaly_id` (e.g., `&"drawing_replaced"`) |
| `display_name` | String | Human-readable name for debug/UI (e.g., `"Replaced Drawing"`) |
| `anomaly_type` | enum | `ENVIRONMENTAL` or `MONSTER` |
| `severity_tier` | int | 1 (Subtle), 2 (Unsettling), or 3 (Confrontational) |
| `archetype` | enum | `NONE`, `DOLL`, `SHADOW`, `LARGE` — only for monsters |
| `compatible_tags` | Array[StringName] | Spawn point tags this anomaly can occupy (OR logic) |
| `scene_path` | String | Path to the `.tscn` file instantiated at the spawn point |
| `detection_shape` | Shape3D | Collision shape defining the anomaly's photographable volume |
| `detection_offset` | Vector3 | Offset from spawn point origin to detection shape center |
| `photo_facing_axis` | Vector3 | The direction the anomaly "faces" — used for head-on angle scoring |
| `photo_max_distance` | float | Maximum distance for a valid photo (meters) |
| `photo_min_distance` | float | Minimum distance (too close = invalid/partial frame) |
| `photo_facing_threshold` | float | Maximum angle (degrees) between camera forward and anomaly facing for "head-on" |
| `photo_score_base` | float | Base score when all photo criteria are met (0.0–1.0) |
| `react_to_flash` | bool | Whether this anomaly changes state when photographed with flash |
| `react_to_proximity` | bool | Whether this anomaly reacts when the player enters its detection zone |
| `proximity_radius` | float | Radius (meters) at which proximity reaction triggers |
| `audio_proximity_event` | StringName | Audio event played when player is within proximity_radius |
| `audio_photo_event` | StringName | Audio event played when photographed |
| `is_anchor` | bool | Whether this anomaly persists/evolves across nights (Art Corner easel drawing) |
| `description_hint` | String | Flavor text for the photo gallery (e.g., `"The drawing changed overnight"`) |

#### Anomaly Categories

Anomalies fall into two major categories, with environmental anomalies further divided by interaction type:

**Environmental Anomalies:**

| Sub-Type | Description | Examples | Spawn Tags |
|---|---|---|---|
| **Replacement** | A normal object swapped for a wrong version | Drawing replaced with disturbing image, name label changed, clock showing wrong time | `WALL`, `FURNITURE_TOP` |
| **Displacement** | A normal object moved to an impossible position | Chair on ceiling, blocks arranged in a pattern, toys in a line facing the door | `FLOOR`, `CEILING`, `FURNITURE_TOP` |
| **Manifestation** | Something that should not exist at all | Shadow stain on floor, handprint on wall, written message on chalkboard | `WALL`, `FLOOR` |
| **Behavioral** | An object exhibiting impossible properties | Rocking chair moving by itself, flickering light in a pattern, dripping from dry ceiling | `FLOOR`, `FURNITURE_TOP` |

**Monster Anomalies (always Tier 3):**

| Archetype | Visual Read | Movement Style | Spawn Tags | Behavior Owner |
|---|---|---|---|---|
| **Doll** | Child-sized figure, rigid posture, toy-like proportions | Snappy, teleport-like repositioning when unobserved | `FLOOR`, `FURNITURE_TOP` | Monster AI |
| **Shadow** | 2D silhouette on vertical surfaces, fluid edges | Slides along walls, dissolves and reforms | `WALL` | Monster AI |
| **Large** | Oversized form filling corridors, irregular proportions | Slow, deliberate, irregular cadence — stops and starts | `FLOOR` | Monster AI |

#### Photo-Detection System

The Anomaly System exposes a detection API that the Photography System consumes when the player takes a photo. Detection is evaluated per-anomaly against the camera's state at shutter time.

**Detection Pipeline (executed in order, early-exit on failure):**

1. **Room check:** Is the anomaly in the same room as the player, OR in an adjacent room visible through a doorway? Skip anomalies in non-visible rooms.

2. **Frustum check:** Is any part of the anomaly's `detection_shape` inside the camera's view frustum? Uses `camera.is_position_in_frustum()` on the detection shape's AABB corners. Fail = anomaly not in frame.

3. **Distance check:** Is the distance from camera to anomaly detection center within `[photo_min_distance, photo_max_distance]`? Fail = too close or too far.

4. **Occlusion check:** Cast a ray from the camera position to the anomaly's `detection_offset` world position. If the ray hits a non-anomaly collider first, the anomaly is occluded. Uses physics layer masking — anomaly detection shapes are on a dedicated layer.

5. **Facing angle check:** Calculate the angle between the camera's forward vector and the anomaly's `photo_facing_axis`. If the angle exceeds `photo_facing_threshold`, the photo is not "head-on." This is a scoring modifier, not a binary pass/fail — oblique angles reduce the photo score.

**Detection Output (per anomaly):**

| Field | Type | Description |
|---|---|---|
| `detected` | bool | True if the anomaly passed frustum + distance + occlusion checks |
| `in_frame_ratio` | float | 0.0–1.0, fraction of detection shape AABB corners inside frustum |
| `facing_score` | float | 0.0–1.0, 1.0 = perfect head-on, decays with angle |
| `distance_score` | float | 0.0–1.0, 1.0 = optimal distance, decays toward min/max |
| `photo_score` | float | Combined score: `photo_score_base * in_frame_ratio * facing_score * distance_score` |
| `anomaly_ref` | AnomalyInstance | Reference to the runtime anomaly node |

The Photography System decides what to do with these scores (grade the photo, count it as evidence). The Anomaly System only evaluates detection — it does not grade.

#### Runtime Instantiation

When the Anomaly Placement Engine emits `placement_manifest_ready(n)`, the Anomaly System:

1. **Clear previous night's instances:** Free all anomaly scene instances from the previous night (or death restart). Emit `anomalies_cleared`.

2. **Read manifest:** Call `AnomalyPlacementEngine.get_manifest()`. Validate `manifest.night == current_night`.

3. **For each PlacementEntry in the manifest:**
   a. Look up `AnomalyDefinition` by `anomaly_id` from the definition dictionary.
   b. If definition not found: log error, skip entry.
   c. Resolve spawn point: `RoomManager.get_room_data(room_id).spawn_points[spawn_point_index]`.
   d. Instantiate `definition.scene_path` as a child of the room's anomaly container node.
   e. Position at spawn point Transform3D.
   f. Attach an `AnomalyInstance` script to the root node (or it is already part of the scene).
   g. Initialize `AnomalyInstance` with: definition reference, placement entry data, initial state (`DORMANT` for environmental, `ACTIVE` for monsters).
   h. Register the instance in the Anomaly System's `active_anomalies` dictionary.

4. **Emit `anomalies_instantiated(n, count)`** when all entries are processed.

5. **Monster handoff:** For entries where `anomaly_type == MONSTER`, emit `monster_spawned(anomaly_instance)`. Monster AI listens and takes behavioral control. The Anomaly System retains ownership of the node and detection API; Monster AI controls movement and state transitions.

#### Anomaly Instance Runtime Data

Each instantiated anomaly carries runtime state as an `AnomalyInstance` node script:

| Field | Type | Mutable | Description |
|---|---|---|---|
| `definition` | AnomalyDefinition | No | Reference to the authored resource |
| `placement` | PlacementEntry | No | The manifest entry that created this instance |
| `room_id` | StringName | No | Room this anomaly is in |
| `state` | enum | Yes | Current state (see States and Transitions) |
| `times_photographed` | int | Yes | Count of successful photo detections |
| `player_in_proximity` | bool | Yes | Whether the player is within `proximity_radius` |
| `detection_area` | Area3D | No | Child node with `detection_shape` for photo-detection |
| `proximity_area` | Area3D | No | Child node with sphere shape for proximity triggers |

### States and Transitions

#### Environmental Anomaly States

| State | Description | Visual | Audio |
|---|---|---|---|
| `DORMANT` | Placed but not yet activated — waiting for player to enter the room | Invisible or identical to normal object | Silent |
| `ACTIVE` | Visible and photographable — the anomaly is "on" | Anomalous appearance visible | Proximity audio plays when player is in range |
| `PHOTOGRAPHED` | Successfully captured in a photo — state change for tracking | Same as ACTIVE (no visual change for environmental) | Shutter confirmation from Photography System |
| `REACTING` | Responding to being photographed (Behavioral sub-type only) | Brief animation or effect (e.g., rocking chair stops) | Reaction audio cue |

**Environmental Transition Rules:**

| From | To | Trigger |
|---|---|---|
| DORMANT | ACTIVE | `player_entered_room` signal for this anomaly's room |
| ACTIVE | PHOTOGRAPHED | Photography System confirms detection with `photo_score >= PHOTO_SCORE_THRESHOLD` |
| PHOTOGRAPHED | ACTIVE | Immediate — photographed status is tracked but doesn't change behavior. Anomaly remains photographable (player can re-photograph for a better shot). |
| ACTIVE | REACTING | `react_to_flash == true` AND photographed with flash |
| REACTING | ACTIVE | Reaction animation completes (0.5–2.0s depending on anomaly) |

**DORMANT → ACTIVE timing:** Environmental anomalies activate when the player enters their room. They do NOT activate while the player is in a different room — this prevents the player from seeing anomalies "pop in" from a doorway. The activation uses a brief stagger delay (0.0–0.3s random per anomaly) to prevent all anomalies in a room from appearing on exactly the same frame.

#### Monster Anomaly States

Monsters use a simplified state set from the Anomaly System's perspective. Monster AI manages the detailed behavioral states (patrol, pursue, attack) internally.

| State | Description | Anomaly System Role |
|---|---|---|
| `ACTIVE` | Monster is alive and in the world | Photo-detection API available. Monster AI controls position and behavior. |
| `PHOTOGRAPHED` | Monster has been photographed at least once | Tracking flag set. Monster AI decides behavioral reaction (may become aggressive). |
| `PURSUING` | Monster is chasing the player | Photo-detection still available (player can photograph during chase for bonus). |
| `ATTACKING` | Monster is in attack animation | Photo-detection disabled (too close, camera forced down by FPC death transition). |
| `DESPAWNED` | Monster removed from play (e.g., player escaped its room) | Not applicable for MVP — monsters persist until night ends. Reserved for Full Vision. |

**Monster transitions are driven by Monster AI**, not the Anomaly System. The Anomaly System listens to Monster AI signals to update its tracking state but does not control the transitions.

| Signal from Monster AI | Anomaly System Action |
|---|---|
| `monster_state_changed(instance, new_state)` | Update `AnomalyInstance.state` |
| `monster_position_updated(instance, new_pos)` | Update detection area position (detection follows the monster) |

### Interactions with Other Systems

#### Inputs (other systems call into Anomaly System)

| Caller | Signal / Method | When | Data |
|---|---|---|---|
| Anomaly Placement Engine | `placement_manifest_ready(n: int)` signal | LOADING phase, after manifest built | Night number. Anomaly System queries `get_manifest()`. |
| Room/Level Management | `player_entered_room(room_id)` signal | Player crosses room boundary | Room ID. Triggers DORMANT → ACTIVE for anomalies in that room. |
| Room/Level Management | `player_exited_room(room_id)` signal | Player leaves a room | Room ID. Environmental anomalies stay ACTIVE (do not revert to DORMANT). |
| Night Progression | `night_loading_started(n)` signal | Night start/restart | Triggers anomaly cleanup from previous run. |
| Monster AI | `monster_state_changed(instance, state)` | Monster behavior changes | Updates tracking state on AnomalyInstance. |
| Monster AI | `monster_position_updated(instance, pos)` | Monster moves | Updates detection area world position. |

#### Outputs (Anomaly System emits / exposes)

**Signals:**

| Signal | Parameters | Consumed By | When |
|---|---|---|---|
| `anomalies_instantiated(n, count)` | Night number, total count | Night Progression (optional), HUD/UI (optional) | After all manifest entries processed |
| `anomaly_activated(instance)` | AnomalyInstance ref | Audio System (start proximity audio) | DORMANT → ACTIVE transition |
| `anomaly_photographed(instance, score)` | AnomalyInstance ref, photo_score | Photography System, Evidence Submission | Photo detection succeeds |
| `monster_spawned(instance)` | AnomalyInstance ref | Monster AI | During instantiation, for monster entries |
| `anomalies_cleared` | (none) | Monster AI, Audio System | Night cleanup before re-instantiation |
| `player_near_anomaly(instance, entered)` | AnomalyInstance ref, bool | Audio System, HUD/UI (optional) | Player enters/exits proximity_area |

**Query API:**

| Method | Returns | Callers |
|---|---|---|
| `get_active_anomalies() -> Array[AnomalyInstance]` | All currently instantiated anomalies | Photography System (photo evaluation) |
| `get_anomalies_in_room(room_id) -> Array[AnomalyInstance]` | Anomalies in a specific room | Photography System, Monster AI |
| `get_monsters() -> Array[AnomalyInstance]` | Active monster instances | Monster AI, Player Survival |
| `evaluate_photo(camera_transform, camera_fov) -> Array[PhotoDetectionResult]` | Detection results for all anomalies | Photography System (at shutter time) |
| `get_definition(anomaly_id) -> AnomalyDefinition` | Definition resource | APE (Fixed Mode validation), debug |
| `get_photographed_count() -> int` | Number of unique anomalies photographed this night | HUD/UI (optional), Evidence Submission |
| `get_total_count() -> int` | Total anomalies placed this night | HUD/UI (optional), debug |

## Formulas

### Photo Facing Score

The `facing_score` formula determines how "head-on" the player's camera is relative to the anomaly's preferred photo angle. This is the primary quality differentiator between a good photo and a mediocre one.

`facing_score = max(0.0, 1.0 - (angle / photo_facing_threshold))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| angle | θ | float | 0°–180° | Angle between camera forward vector and anomaly's `photo_facing_axis` |
| photo_facing_threshold | T_f | float | 30°–90° | Per-anomaly maximum angle for any score. Beyond this: score = 0. |
| facing_score | — | float | 0.0–1.0 | 1.0 = perfectly head-on, linear decay to 0 at threshold |

**Output Range:** 0.0 to 1.0. Clamped — negative values from angles beyond threshold are floored at 0.

**Example — Drawing anomaly (threshold 60°):**
- Camera directly facing drawing (0°): `max(0, 1 - 0/60) = 1.0`
- Camera at 30° angle: `max(0, 1 - 30/60) = 0.5`
- Camera at 60° angle: `max(0, 1 - 60/60) = 0.0`
- Camera at 90° angle: `max(0, 1 - 90/60) = 0.0` (clamped)

### Photo Distance Score

The `distance_score` formula rewards an optimal framing distance — not too close, not too far.

`distance_score = 1.0 - (abs(distance - OPTIMAL_DISTANCE) / (photo_max_distance - photo_min_distance))`

Where `OPTIMAL_DISTANCE = (photo_min_distance + photo_max_distance) / 2`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| distance | d | float | 0–15 m | Distance from camera to anomaly detection center |
| photo_min_distance | d_min | float | 0.5–2.0 m | Per-anomaly minimum (too close = partial frame) |
| photo_max_distance | d_max | float | 3.0–10.0 m | Per-anomaly maximum (too far = can't identify) |
| OPTIMAL_DISTANCE | d_opt | float | derived | Midpoint of min/max range |
| distance_score | — | float | 0.0–1.0 | 1.0 = at optimal distance, linear decay to edges |

**Output Range:** 0.0 to 1.0. If distance is outside `[d_min, d_max]`, the frustum/distance check in the detection pipeline fails before this formula runs — so this only scores within valid range.

**Example — Doll monster (min 1.0 m, max 6.0 m, optimal 3.5 m):**
- At 3.5 m (optimal): `1.0 - (0.0 / 5.0) = 1.0`
- At 1.0 m (min): `1.0 - (2.5 / 5.0) = 0.5`
- At 6.0 m (max): `1.0 - (2.5 / 5.0) = 0.5`
- At 2.25 m: `1.0 - (1.25 / 5.0) = 0.75`

### Composite Photo Score

The final per-anomaly photo score combines all factors.

`photo_score = photo_score_base * in_frame_ratio * facing_score * distance_score`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| photo_score_base | B | float | 0.5–1.0 | Per-anomaly base value. Tier 3 anomalies have higher base (harder to photograph = more rewarding). |
| in_frame_ratio | F | float | 0.0–1.0 | Fraction of detection AABB corners inside camera frustum |
| facing_score | S_f | float | 0.0–1.0 | Head-on alignment score |
| distance_score | S_d | float | 0.0–1.0 | Distance optimality score |
| photo_score | — | float | 0.0–1.0 | Final score. Photography System uses this for evidence grading. |

**Output Range:** 0.0 to 1.0. Multiplicative — a weakness in any dimension drags the score down. A photo can only be excellent if all four factors are strong.

**Per-tier base scores (recommended defaults):**

| Severity Tier | photo_score_base | Rationale |
|---|---|---|
| 1 (Subtle) | 0.6 | Easy to photograph but low evidence value |
| 2 (Unsettling) | 0.8 | Moderate difficulty, moderate reward |
| 3 (Confrontational/Monster) | 1.0 | Hardest to photograph safely, highest reward |

**Example — Tier 2 environmental, good photo:**
- `photo_score_base = 0.8`
- `in_frame_ratio = 0.9` (one AABB corner just outside frame)
- `facing_score = 0.7` (about 18° off head-on at 60° threshold)
- `distance_score = 0.85` (slightly closer than optimal)
- `photo_score = 0.8 * 0.9 * 0.7 * 0.85 = 0.428`

### Proximity Audio Trigger Distance

Not a gameplay formula — used for audio integration. When the player enters an anomaly's `proximity_radius`, the Audio System plays the anomaly's audio cue.

`proximity_trigger = distance(player_position, anomaly_position) <= proximity_radius`

**Per-tier default proximity radii:**

| Severity Tier | proximity_radius | Rationale |
|---|---|---|
| 1 (Subtle) | 3.0 m | Player must be close to notice — audio cue is very quiet |
| 2 (Unsettling) | 5.0 m | Larger presence — player hears it from the doorway |
| 3 (Confrontational) | 8.0 m | Fills the room — player knows something is wrong before seeing it |

### Activation Stagger Delay

`stagger_delay(i) = STAGGER_BASE + (i * STAGGER_INCREMENT)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| i | — | int | 0–N | Index of anomaly within the room's activation batch |
| STAGGER_BASE | — | float | 0.0 s | Base delay before first activation |
| STAGGER_INCREMENT | — | float | 0.05 s | Additional delay per anomaly in the batch |
| stagger_delay | — | float | 0.0–0.4 s | Time after `player_entered_room` before this anomaly activates |

**Output Range:** 0.0 to ~0.4 s (room with 8 anomalies). Prevents visual "pop-in" of all anomalies simultaneously. Player perceives anomalies appearing at the edge of attention as they scan the room.

**Example — Room with 4 anomalies:**
- Anomaly 0: `0.0 + 0 * 0.05 = 0.0s` (immediate)
- Anomaly 1: `0.0 + 1 * 0.05 = 0.05s`
- Anomaly 2: `0.0 + 2 * 0.05 = 0.10s`
- Anomaly 3: `0.0 + 3 * 0.05 = 0.15s`

## Edge Cases

### Instantiation

- **If `placement_manifest_ready(n)` fires but `get_manifest()` returns null**: Log critical error. Emit `anomalies_instantiated(n, 0)`. Night plays with zero anomalies rather than crashing. Treat as blocking build error in QA.

- **If a `PlacementEntry.anomaly_id` has no matching AnomalyDefinition**: Skip that entry. Log error with the anomaly_id and room_id. Other entries still instantiate. Total count reflects only successful instantiations.

- **If a spawn point Transform3D places the anomaly inside geometry (wall, floor)**: The scene's authored collision should prevent this for well-built anomaly scenes. If the anomaly's detection Area3D overlaps a wall collider at spawn, the occlusion raycast may permanently fail. Mitigation: anomaly scenes must have their origin at the attachment surface, not the center of the mesh. Validate during QA with a debug overlay showing detection volumes.

- **If `anomalies_instantiated` count is 0 on a night that should have anomalies**: Log critical error. Night proceeds — the player sees a "clean" preschool. Evidence Submission handles zero-photo debriefs (already specified in Night Progression).

### Activation

- **If the player enters a room and immediately exits (doorway bounce)**: Anomalies that received DORMANT → ACTIVE transition remain ACTIVE. Environmental anomalies do not revert to DORMANT once activated. This is intentional — once the room is "corrupted," it stays corrupted for the night.

- **If `player_entered_room` fires for a room with 0 anomalies**: No activation batch runs. No error. The room is clean this night.

- **If two rooms' `player_entered_room` signals fire within the stagger window (rapid room crossing)**: Each room's activation batch runs independently. Stagger timers are per-room, not global. Both batches may overlap in time — this is acceptable.

- **If a death restart occurs during stagger delay (anomalies mid-activation)**: `night_loading_started` fires, triggering full cleanup. All pending stagger timers are cancelled via `queue_free()` on the anomaly container. Fresh instantiation follows.

### Photo Detection

- **If the camera frustum check passes but the anomaly is behind transparent geometry (glass, open door frame)**: Occlusion raycast does not stop on transparent colliders. Use physics layer masking: transparent objects are NOT on the occlusion layer. This means anomalies behind glass are photographable — which is correct for a preschool setting (glass display case, window).

- **If two anomalies overlap at the same spawn point (should not happen per APE deduplication, but guarded)**: Both are photographable independently. `evaluate_photo()` returns detection results for ALL anomalies, not just the nearest. Photography System selects the highest-scoring result.

- **If a monster moves out of its spawned room into an adjacent room**: The monster's detection area follows its world position (Monster AI updates via `monster_position_updated`). `get_anomalies_in_room()` uses the monster's current position, not its spawn room. The anomaly is photographable in whatever room it currently occupies.

- **If the player photographs an anomaly through a doorway (different room, but within distance and unoccluded)**: Valid. The room check allows anomalies in adjacent rooms visible through doorways. The distance and occlusion checks handle whether the photo is actually possible from that position.

- **If `evaluate_photo()` is called while anomalies are mid-instantiation (stagger delay active)**: Only anomalies in `ACTIVE` state are evaluated. `DORMANT` anomalies return no detection result. The player cannot photograph anomalies that haven't "appeared" yet.

- **If `photo_min_distance` > `photo_max_distance` on a definition**: Clamp `photo_min_distance = photo_max_distance - 0.1`. Log authoring error.

### Monster Interaction

- **If Monster AI moves a monster to a position where its detection area overlaps a wall**: Detection area position is authoritative — it goes where Monster AI says. Occlusion raycast from the camera will fail if the wall is between camera and detection center. This is correct behavior (you can't photograph what you can't see).

- **If `monster_spawned` fires but Monster AI is not loaded (MVP build without Monster AI)**: The monster instance exists as a static scene at its spawn point. No movement, no behavior. It is still photographable as a static Tier 3 anomaly. Log warning: "Monster AI not loaded — monster is static."

- **If a monster kills the player during `evaluate_photo()` processing**: The photo is captured at shutter time (instantaneous). Death occurs on the next frame. The photo is valid and recorded before the death state wipes it (photos from the current run are discarded on death per Night Progression rules).

### Night Lifecycle

- **If `night_loading_started` fires before the previous night's anomalies are freed**: `anomalies_cleared` must fire synchronously before new instantiation begins. Use `queue_free()` on the anomaly container, then `await get_tree().process_frame` to ensure nodes are freed, then begin new instantiation.

- **If the same night restarts (death restart)**: APE rebuilds an identical manifest in Fixed Mode. The Anomaly System clears and re-instantiates. All `times_photographed` counters reset to 0. Player gets a fresh start with the same anomaly layout.

- **If an anchor anomaly's `anomaly_id` changes between nights (Art Corner easel evolves)**: Each night's `NightPlacementConfig` specifies a different `anomaly_id` at the same `spawn_point_index`. The Anomaly System instantiates whatever the manifest says — it does not track cross-night anomaly identity. The APE's `is_anchor` flag is a placement constraint, not an Anomaly System concept.

## Dependencies

### Hard Dependencies (system cannot function without these)

| System | Direction | Interface | Nature |
|---|---|---|---|
| **Anomaly Placement Engine** | Upstream → Anomaly System | `placement_manifest_ready(n)` signal + `get_manifest()`, `get_entries_for_room()` query API. APE produces the placement manifest; Anomaly System consumes it to instantiate anomalies. | Hard — no manifest means no anomalies. |
| **Room/Level Management** | Upstream → Anomaly System | `player_entered_room(room_id)`, `player_exited_room(room_id)` signals. `get_room_data(room_id)` for spawn point Transform3D resolution. `get_current_room()`, `get_adjacent_rooms()` for photo detection room checks. | Hard — anomalies exist in rooms; without room data, cannot resolve spawn positions or activation triggers. |

### Soft Dependencies (enhanced by, but works without)

| System | Direction | Interface | Nature |
|---|---|---|---|
| **Night Progression** | Upstream → Anomaly System | `night_loading_started(n)` signal triggers cleanup. `get_current_night()` for debug/validation. | Soft — Anomaly System could be triggered directly without Night Progression for testing, but in production Night Progression orchestrates the lifecycle. |
| **Photography System** | Anomaly System → Downstream | `evaluate_photo(camera_transform, fov)` query API. `anomaly_photographed(instance, score)` signal. Photography consumes detection results; Anomaly System is unaware of photo grading. | Soft — Anomaly System instantiates and exposes anomalies regardless of whether Photography exists. |
| **Monster AI** | Bidirectional | Anomaly System → Monster AI: `monster_spawned(instance)` signal during instantiation, `anomalies_cleared` signal on cleanup. Monster AI → Anomaly System: `monster_state_changed(instance, state)`, `monster_position_updated(instance, pos)` signals. | Soft — without Monster AI, monsters are static but still photographable. |
| **Audio System** | Anomaly System → Downstream | `anomaly_activated(instance)` signal starts proximity audio. `player_near_anomaly(instance, entered)` signal triggers proximity cues. Audio events are specified per `AnomalyDefinition`. | Soft — anomalies function silently without Audio. |
| **HUD/UI System** | Anomaly System → Downstream | `anomalies_instantiated(n, count)` (optional display). `player_near_anomaly` (optional proximity indicator). `get_photographed_count()`, `get_total_count()` query API. | Soft — HUD displays are optional; anomalies don't need HUD to function. |
| **First-Person Controller** | Implicit | Player's CharacterBody3D triggers room boundaries (via Room Management). `camera_raised` state determines when Photography can call `evaluate_photo()`. No direct interface between FPC and Anomaly System. | Soft — implicit via Room Management's boundary detection. |
| **Evidence Submission** | Anomaly System → Downstream (indirect) | Consumes `anomaly_photographed` signal results via Photography System. Two layers removed — no direct interface. | None — no direct dependency. |

### Bidirectional Consistency Notes

- **APE** documents Anomaly System as a downstream consumer of `PlacementManifest`. ✓ This GDD confirms consumption via `placement_manifest_ready` + query API.
- **Room/Level Management** lists Anomaly System as a listener for `player_entered_room`, `player_exited_room`, and a caller of `get_current_room()`, `get_adjacent_rooms()`. ✓ Consistent.
- **Night Progression** lists `night_loading_started(n)` as consumed by Anomaly System (reserved). ✓ This GDD confirms.
- **Photography System** is not yet designed. When designed, it must document Anomaly System as upstream and specify it consumes `evaluate_photo()` at shutter time.
- **Monster AI** is not yet designed. When designed, it must document: receives `monster_spawned` from Anomaly System, emits `monster_state_changed` and `monster_position_updated` back.

## Tuning Knobs

| # | Knob | Type | Default | Safe Range | Affects | Interaction Notes |
|---|---|---|---|---|---|---|
| 1 | `PHOTO_SCORE_THRESHOLD` | float | 0.15 | 0.05–0.40 | Minimum `photo_score` for a photo to count as "detected." Below this, the anomaly was technically in frame but too poorly captured to be evidence. | Lower = more forgiving (blurry photos count). Higher = stricter quality gate. At 0.40, only well-framed head-on shots succeed. |
| 2 | `PHOTO_FACING_THRESHOLD_ENV` | float | 60° | 30°–90° | Default `photo_facing_threshold` for environmental anomalies. Wider = more forgiving angle for flat wall-mounted anomalies. | Interacts with room layout — narrow corridors force oblique angles. Below 30°, only direct face-on shots work. |
| 3 | `PHOTO_FACING_THRESHOLD_MONSTER` | float | 45° | 20°–75° | Default `photo_facing_threshold` for monster anomalies. Narrower than environmental — monsters have a "face" that matters. | Tighter angles mean the player must face the threat directly. |
| 4 | `PHOTO_MIN_DISTANCE_ENV` | float | 0.5 m | 0.3–1.5 m | Minimum photo distance for environmental anomalies. Too close = partial frame. | At 0.3m the player is touching the anomaly. At 1.5m small anomalies might be hard to frame. |
| 5 | `PHOTO_MAX_DISTANCE_ENV` | float | 6.0 m | 3.0–10.0 m | Maximum photo distance for environmental anomalies. Beyond this, anomaly is too small to identify. | Must be less than `max_spatial_distance` (15m from Audio System). At 10m, Tier 1 anomalies are invisible. |
| 6 | `PHOTO_MIN_DISTANCE_MONSTER` | float | 1.0 m | 0.5–2.0 m | Minimum photo distance for monsters. Too close = the monster fills the entire frame and you're in danger. | Lower = allows braver close-up shots. Higher = forces the player to keep distance. |
| 7 | `PHOTO_MAX_DISTANCE_MONSTER` | float | 8.0 m | 4.0–12.0 m | Maximum photo distance for monsters. Monsters are larger and photographable from further away. | Beyond 12m no room in the preschool (20×15m footprint) would allow this distance. |
| 8 | `PROXIMITY_RADIUS_T1` | float | 3.0 m | 1.5–5.0 m | Audio proximity trigger for Tier 1 (Subtle) anomalies. | Smaller = player must be close to hear cues. Larger = cues give away the anomaly too early. |
| 9 | `PROXIMITY_RADIUS_T2` | float | 5.0 m | 3.0–8.0 m | Audio proximity trigger for Tier 2 (Unsettling). | Larger than T1 — these anomalies announce themselves from the doorway. |
| 10 | `PROXIMITY_RADIUS_T3` | float | 8.0 m | 5.0–12.0 m | Audio proximity trigger for Tier 3 (Confrontational / Monster). | Fills the room. Player knows something is there before entering. |
| 11 | `STAGGER_INCREMENT` | float | 0.05 s | 0.0–0.15 s | Delay between each anomaly's activation in a room batch. | At 0.0: all appear simultaneously (pop-in risk). At 0.15: 8-anomaly room takes 1.2s to fully populate (noticeable delay). |
| 12 | `PHOTO_SCORE_BASE_T1` | float | 0.6 | 0.4–0.8 | Base photo score for Tier 1 anomalies. | Lower base = subtle anomalies are worth less as evidence. Higher = rewards observation skill. |
| 13 | `PHOTO_SCORE_BASE_T2` | float | 0.8 | 0.6–1.0 | Base photo score for Tier 2. | Should be noticeably higher than T1 to reward photographing harder targets. |
| 14 | `PHOTO_SCORE_BASE_T3` | float | 1.0 | 0.8–1.0 | Base photo score for Tier 3 / Monsters. | Maximum value — monsters are the hardest to photograph and the best evidence. |
| 15 | `REACTION_DURATION` | float | 1.0 s | 0.5–3.0 s | How long a `react_to_flash` environmental anomaly stays in REACTING state. | Shorter = subtle flicker. Longer = dramatic reaction. |

**Knobs NOT owned by this system** (tuned elsewhere, consumed here):
- `anomaly_target(n)`, `monster_count(n)` — owned by Night Progression
- `active_spawn_slots(R, N)` — owned by Room/Level Management
- `speed_modifier_camera` (0.75) — owned by First-Person Controller (affects vulnerability during photography)
- Placement configurations — owned by Anomaly Placement Engine

## Visual/Audio Requirements

### Environmental Anomaly Visual Language

Each severity tier has a distinct visual strategy that escalates the "Cheerful Decay" art bible principle:

**Tier 1 — Subtle (Nights 1–2 primary):**
- **Visual strategy:** Objects that could *almost* be normal. The wrongness lives in small details — position, orientation, content.
- **Color treatment:** Same palette as the surrounding room. No alien colors. The anomaly IS a preschool object; it's just wrong.
- **Scale:** Small — affects a single object or surface area (~0.3–0.5 m²). A drawing, a name tag, a toy.
- **Lighting:** No self-emission. Relies entirely on room lighting. Tier 1 anomalies do not call attention to themselves.
- **Animation:** None or imperceptible. A Behavioral sub-type (rocking chair) uses a very slow loop (0.5 Hz).
- **Examples:**
  - Drawing replaced: Same crayon style, different content. Player must remember the original.
  - Blocks rearranged: Blocks now spell something. Player must notice the pattern.
  - Name label changed: A cubby name is different. Player must have read it before.

**Tier 2 — Unsettling (Nights 3–4 primary):**
- **Visual strategy:** Undeniable wrongness. Objects violating physics, spatial logic, or scale expectations.
- **Color treatment:** Begins introducing desaturation. Tier 2 anomalies may have slightly cooled colors compared to their room's palette — shifted 200–400K toward blue/green.
- **Scale:** Medium — affects an object or small group (~0.5–1.5 m²). A cluster of chairs, a full wall of drawings.
- **Lighting:** May have subtle self-emission at Tier 2. A soft `#1A0820` (Infection Violet) glow from shadows near the anomaly (material emission, not a light node — WebGL 2 constraint).
- **Animation:** Slow, looping, unmissable. A chair rotating 1°/s. Blocks floating 2cm off the surface. A drawing whose eyes track (UV offset on a sprite).
- **Examples:**
  - Chair on ceiling: Same chair model, impossible position. Gravity violation is the wrongness.
  - All drawings upside down: Batch wrongness — one was subtle, all is unsettling.
  - Toy facing the door: Multiple toys arranged in a line, facing the player's entry point.

**Tier 3 — Confrontational Environmental (Nights 5–7):**
- **Visual strategy:** Intrudes on the player's path or personal space. Cannot be ignored or avoided.
- **Color treatment:** Alien colors intrude. Deep red `#8B2020` (Arterial Red) stains, void black `#0A0A0F` patches, unnatural white `#F0F0FF` surfaces.
- **Scale:** Large — fills a significant portion of the room or blocks a pathway (~1.5–3.0 m²).
- **Lighting:** Strong self-emission. Pulsing at 0.25 Hz (slow heartbeat, NOT the HUD's 0.5 Hz warning pulse — different rhythm creates unease). Color: sickly green `#2A4A2A` or infection violet `#3A1A40`.
- **Animation:** Aggressive looping. Objects jittering at 15–20 Hz (micro-vibration), or slowly expanding/contracting.
- **Examples:**
  - Shadow stain covering half the floor: Player must walk through it to proceed.
  - Handprints crawling up a wall: Animated UV scroll, ascending at 0.5 m/s.
  - Corridor blockage: Furniture stacked in an impossible configuration, forcing a detour.

### Monster Visual Identity

| Archetype | Silhouette | Color Palette | Distinguishing Feature | Photo Read Distance |
|---|---|---|---|---|
| **Doll** | Child-sized (~0.7 m), rigid limbs, oversized head, ball-joint visible at joints | Porcelain white `#E8E0D0`, black bead eyes `#0A0A0F`, faded dress colors (desaturated pastel) | Perfectly still when observed. Moves only when the player looks away (classic weeping angel). Head is always turned toward the player. | 2–6 m. At <2 m the head fills the frame (too close). At >6 m it blends with furniture. |
| **Shadow** | 2D silhouette on walls, adult height (~1.8 m), elongated limbs, no facial features | Pure black `#0A0A0F` body, Infection Violet `#3A1A40` edge glow, eyes (if visible) are Unnatural White `#F0F0FF` | Slides along wall surfaces. When photographed with flash, momentarily reveals a 3D form that dissolves. | 3–8 m. Wall-mounted — distance from the wall matters. Player must face the wall surface. |
| **Large** | Oversized (~2.5 m), hunched to fit under preschool ceilings (1.85 m doorframes), irregular proportions | Deep red `#8B2020` body mass, void black `#0A0A0F` limbs, Crayola Red `#EE204D` mouth/eyes | Fills corridors. Irregular movement cadence — stops mid-stride, lurches forward. Breathing visible (mesh scale oscillation). | 4–8 m. At <4 m it fills the entire frame. At >8 m corridor geometry occludes it. |

### Photo-Reaction Visual Effects

**Environmental anomalies:** No visual reaction to being photographed (the camera flash illuminates them, which is Photography System's responsibility). The anomaly itself does not change. Exception: `react_to_flash` Behavioral anomalies may have a brief reaction animation (rocking chair stops, floating blocks drop momentarily, then resume).

**Monster photo-reaction:**
- **Doll:** Flash freezes it for 1.5 s (it was already still, but now it's *confirmed* still — the player knows it knows). After freeze: head snaps to face the player (if it wasn't already). No movement change for 3 s post-photo.
- **Shadow:** Flash reveals a 3D silhouette for 0.3 s (mesh with dissolve shader, brief opacity spike to 80% then rapid falloff). This is the only time the Shadow has depth. Returns to 2D wall form immediately.
- **Large:** Flash causes a 0.5 s flinch (head turn away, raised arm). Then turns toward the player. Aggression escalates if Monster AI supports it. The player gets a brief window to run.

All monster photo-reactions are Monster AI behavioral changes triggered by the `anomaly_photographed` signal. The Anomaly System emits the signal; Monster AI decides the behavioral response.

### Audio Signatures

**Environmental anomalies — proximity audio (triggered by `player_near_anomaly`):**

| Tier | Audio Character | Volume | Spatial |
|---|---|---|---|
| 1 (Subtle) | Near-subliminal. A single wrong note in the room's ambient. Slight pitch shift. A creak that shouldn't be there. | -18 dB relative to room ambient | 3D positioned at anomaly |
| 2 (Unsettling) | Distinct but sourceless. Low hum, reversed audio snippet, child's whisper (not words — phonemes). | -12 dB relative to room ambient | 3D positioned, wider attenuation |
| 3 (Confrontational) | Aggressive presence. Deep bass pulse, scraping sound, audible breathing or dripping. | -6 dB relative to room ambient | 3D positioned, fills proximity radius |

**Monster anomalies — per-archetype audio:**

| Archetype | Idle Audio | Movement Audio | Photo-Reaction Audio |
|---|---|---|---|
| **Doll** | Silence (its silence IS the audio signature — absence of room ambient when near). Occasional single wooden creak. | No footsteps. Position changes marked by a single porcelain click (like a tea cup set down). | Camera shutter echo — the flash sound reverberates unnaturally long (2 s reverb tail). |
| **Shadow** | Low electrical hum, like a dying fluorescent light. Frequency: 50 Hz base + slight modulation. | Wet sliding sound on wall surface. | Brief static burst (0.2 s white noise, -6 dB). |
| **Large** | Irregular breathing — 3 breaths then a pause, 2 breaths then a longer pause. Never rhythmic. Within `monster_breathing_threshold` (8 m) per Audio System registry. | Heavy irregular footsteps on linoleum. Furniture being nudged aside. | Low growl (1.5 s, rising pitch). |

**WebGL 2 constraints:**
- All audio is positional AudioStreamPlayer3D or 2D with distance attenuation.
- No real-time audio effects (no dynamic reverb). Use pre-baked variants per room (dry/wet).
- Monster audio uses the Audio System's existing SFX pools (6 × 2D, 8 × 3D from Audio System GDD).
- Anomaly proximity audio shares the pool — limit to 1 concurrent proximity audio per anomaly. New trigger preempts old if pool is exhausted.

**Asset Spec Flag:**
> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:anomaly-system` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

The Anomaly System has no dedicated UI surfaces. Anomaly information reaches the player through three indirect channels:

1. **World-space visual identity:** Anomalies are their own UI — their visual wrongness is the "indicator." No health bars, no floating icons, no outlines. The player must use their eyes and spatial memory.

2. **Camera Viewfinder (owned by HUD/UI System):** When the camera is raised, the Viewfinder's Anomaly Lock indicator (`anomaly_locked == true`) signals that a photographable anomaly is in frame. This is provided by `evaluate_photo()` returning a result with `detected == true`. The HUD/UI GDD already specifies the lock visual: corner brackets change to Unnatural White `#F0F0FF` with a 1px rectangle pulse.

3. **Audio proximity cues (owned by Audio System):** The `player_near_anomaly` signal triggers spatial audio. The player "hears" the anomaly before seeing it. No UI widget is involved.

**Explicitly excluded (per art bible Section 3.4):**
- No anomaly counter on the Preschool HUD (the player does not know how many anomalies are in a room)
- No anomaly radar, compass, or proximity meter
- No visual highlighting, outlining, or glow on anomalies outside the Viewfinder
- No "anomaly detected" toast or notification

The design intent is that the player's skill IS the UI. Spotting anomalies is the gameplay, not following a waypoint to them.

> **📌 UX Flag — Anomaly System**: This system's UI contribution is through the Camera Viewfinder (Anomaly Lock indicator). In Phase 4 (Pre-Production), the Photography System GDD will own the Viewfinder interaction spec. No separate UX spec is needed for the Anomaly System itself — its "UI" is the world geometry.

## Acceptance Criteria

### Instantiation

- **AC-AS-01:** **GIVEN** Night Progression triggers LOADING for night `n`, **WHEN** `placement_manifest_ready(n)` fires, **THEN** the Anomaly System instantiates one scene per manifest entry, and `anomalies_instantiated(n, count)` is emitted with `count` matching the number of successfully instantiated entries.

- **AC-AS-02:** **GIVEN** a PlacementEntry with `anomaly_id = &"drawing_replaced"` and `room_id = &"art_corner"` and `spawn_point_index = 0`, **WHEN** instantiation runs, **THEN** a scene matching the `AnomalyDefinition.scene_path` for `&"drawing_replaced"` exists as a child of art_corner's anomaly container, positioned at `RoomData.spawn_points[0]`.

- **AC-AS-03:** **GIVEN** a PlacementEntry with an `anomaly_id` that has no matching AnomalyDefinition, **WHEN** instantiation runs, **THEN** that entry is skipped, an error is logged, and all other entries still instantiate normally.

- **AC-AS-04:** **GIVEN** a manifest with 3 environmental entries and 1 monster entry, **WHEN** instantiation completes, **THEN** `monster_spawned` is emitted exactly once, and `get_monsters()` returns an array of length 1.

### Activation

- **AC-AS-05:** **GIVEN** 3 anomalies placed in Main Classroom in DORMANT state, **WHEN** `player_entered_room(&"main_classroom")` fires, **THEN** all 3 anomalies transition to ACTIVE within 0.2 s (stagger delay) and `anomaly_activated` is emitted 3 times.

- **AC-AS-06:** **GIVEN** anomalies in Main Classroom are ACTIVE, **WHEN** `player_exited_room(&"main_classroom")` fires, **THEN** anomalies remain in ACTIVE state (do not revert to DORMANT).

- **AC-AS-07:** **GIVEN** a room with 0 anomalies in the manifest, **WHEN** `player_entered_room` fires for that room, **THEN** no errors occur and no `anomaly_activated` signals are emitted.

### Photo Detection

- **AC-AS-08:** **GIVEN** an ACTIVE environmental anomaly directly in front of the camera at 3.0 m distance with 0° facing angle, **WHEN** `evaluate_photo()` is called, **THEN** the result for that anomaly has `detected == true`, `facing_score >= 0.9`, `distance_score >= 0.8`, and `photo_score >= PHOTO_SCORE_THRESHOLD`.

- **AC-AS-09:** **GIVEN** an ACTIVE anomaly behind the player (180° from camera forward), **WHEN** `evaluate_photo()` is called, **THEN** the result for that anomaly has `detected == false` (frustum check fails).

- **AC-AS-10:** **GIVEN** an ACTIVE anomaly at distance 15.0 m (beyond `photo_max_distance` of 6.0 m for environmental), **WHEN** `evaluate_photo()` is called, **THEN** `detected == false` (distance check fails).

- **AC-AS-11:** **GIVEN** an ACTIVE anomaly with a wall collider between it and the camera, **WHEN** `evaluate_photo()` is called, **THEN** `detected == false` (occlusion check fails).

- **AC-AS-12:** **GIVEN** an ACTIVE anomaly at 45° from camera forward with `photo_facing_threshold = 60°`, **WHEN** `evaluate_photo()` is called, **THEN** `facing_score = max(0, 1 - 45/60) = 0.25`.

- **AC-AS-13:** **GIVEN** a DORMANT anomaly (player has not entered its room), **WHEN** `evaluate_photo()` is called (e.g., photographing through a doorway), **THEN** that anomaly returns no detection result (DORMANT anomalies are not evaluable).

### Monster Integration

- **AC-AS-14:** **GIVEN** a monster instance at spawn position, **WHEN** Monster AI calls `monster_position_updated(instance, new_pos)`, **THEN** `instance.detection_area.global_position` matches `new_pos` and subsequent `evaluate_photo()` calls use the updated position.

- **AC-AS-15:** **GIVEN** Monster AI is not loaded, **WHEN** a monster manifest entry is instantiated, **THEN** the monster exists as a static scene at its spawn point, is photographable via `evaluate_photo()`, and a warning is logged.

### Night Lifecycle

- **AC-AS-16:** **GIVEN** anomalies from Night 2 are ACTIVE, **WHEN** `night_loading_started(3)` fires (death restart or next night), **THEN** all Night 2 anomalies are freed, `anomalies_cleared` is emitted, and new Night 3 anomalies are instantiated from the fresh manifest.

- **AC-AS-17:** **GIVEN** a death restart on Night 3 (same manifest, Fixed Mode), **WHEN** re-instantiation completes, **THEN** all `times_photographed` counters are 0 and anomaly positions match the original placement.

### Formula Validation

- **AC-AS-18:** **GIVEN** an anomaly with `photo_facing_threshold = 60°`, **WHEN** the camera faces it at exactly 60°, **THEN** `facing_score == 0.0`.

- **AC-AS-19:** **GIVEN** an anomaly with `photo_min_distance = 1.0` and `photo_max_distance = 6.0`, **WHEN** the camera is at 3.5 m (optimal), **THEN** `distance_score == 1.0`.

- **AC-AS-20:** **GIVEN** a Tier 3 monster with `photo_score_base = 1.0`, perfectly framed (in_frame_ratio=1.0), head-on (facing_score=1.0), at optimal distance (distance_score=1.0), **WHEN** `evaluate_photo()` runs, **THEN** `photo_score == 1.0`.

## Open Questions

1. **Should photographed environmental anomalies change visually after being captured?** Currently, photographed anomalies remain identical (PHOTOGRAPHED is a tracking flag, not a visual state). An alternative: subtle visual acknowledgment (brief shimmer, slight desaturation) to confirm the player's observation. Risk: could make the game feel "game-y" and break immersion. → Defer to playtest.

2. **Should environmental anomalies ever despawn or resolve after being photographed?** Current design: anomalies persist all night. Alternative: photographing an anomaly "captures" it and it fades away, clearing the room. This would create a satisfying progression loop but reduce the late-night chaos that Pillar 4 demands. → Defer to playtest.

3. **How should the Doll archetype's "moves when unobserved" behavior interact with the detection system?** If the Doll teleports while the player's back is turned, does it keep its previous `times_photographed` count? Does the detection area teleport with it? → Resolve in Monster AI GDD. Anomaly System treats it as a `monster_position_updated` call.

4. **Should anchor anomalies (Art Corner easel) have cross-night visual evolution baked into the AnomalyDefinition, or should the APE use different anomaly_ids per night?** Current approach: different `anomaly_id` per night at the same spawn point (APE manages evolution). Alternative: single `anomaly_id` with a `night_variant` parameter in the definition. → Resolve before MVP content authoring begins.

5. **What is the optimal number of environmental anomaly definitions for MVP?** The game concept mentions 5 anomalies for MVP across 3 rooms, 3 nights. With severity tiers and spawn tag compatibility, the minimum pool needs ~8–10 unique definitions to avoid obvious repetition. → Resolve during content authoring sprint.

6. **Should the photo-detection system distinguish between "anomaly partially in frame" and "anomaly fully in frame" for the player?** Currently, `in_frame_ratio` is a continuous 0.0–1.0 score with no player feedback about framing quality until the photo is graded by Evidence Submission. A Viewfinder indicator (e.g., lock color intensity mapping to in_frame_ratio) could guide the player. → Resolve in Photography System GDD.

7. **How should Large archetype monsters interact with doorway geometry?** At 2.5 m height and preschool doorframes at 1.85 m, the Large archetype must duck or squeeze through doors. Does this affect its detection shape? Does the hunched posture change the `photo_facing_axis`? → Resolve in Monster AI GDD + animation spec.
