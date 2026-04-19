# Photography System

> **Status**: In Design
> **Author**: Nate Aune + agents
> **Last Updated**: 2026-04-12
> **Implements Pillar**: Pillar 2 ("Prove It") — the camera is the core verb; every interaction serves the loop of spotting, framing, capturing, and submitting evidence

## Overview

The Photography System is the core interaction layer for Show & Tell. It translates the player's physical act of raising, aiming, and triggering a camera into the game's primary verb: proving that the preschool is wrong. When the First-Person Controller signals `camera_raised == true` (RMB held), the Photography System takes authority over the viewfinder experience — zoom control, flash management, anomaly lock feedback, and shutter capture. At shutter time (LMB/RT), the system queries the Anomaly System's `evaluate_photo()` API to score every anomaly in the camera's frustum, captures a render-to-texture snapshot via a SubViewport, and stores the result as a `PhotoRecord` containing the image, per-anomaly scores, timestamp, and room context. The flash — a rechargeable single-pulse mechanic — illuminates the scene and provokes reactions from flash-sensitive anomalies and monsters, creating a risk/reward moment: the flash improves photo quality in dark environments but alerts nearby threats. Film is limited per night (12 shots by default, configurable per night via Night Progression), forcing the player to choose which anomalies are worth the exposure risk. The system feeds two downstream consumers: Evidence Submission (which grades the night's photo set and presents the boss debrief) and Photo Gallery (which lets the player review and select photos for submission). The player experiences the Photography System as the weight of the camera in their hands — the slowdown, the narrowed view, the commitment of each shutter press, and the tension between getting a clear shot and staying alive long enough to submit it.

## Player Fantasy

**"One More Shot."** The player should feel the specific, full-body tension of choosing to stand still in a place that punishes stillness. The camera is not a weapon. It is not a shield. It is a commitment — the moment you raise it, you are slower, your peripheral vision narrows to the viewfinder's frame, and every second you spend composing the shot is a second you are not running. The fantasy crystallizes in the instant between pressing the shutter and hearing the click: you are staring at a drawing that changed overnight, or a doll that wasn't there before, or a shadow that is looking back at you — and you chose to photograph it instead of leaving. That choice is the game.

The Photography System serves two interleaved fantasies that trade dominance across the 7-night arc:

- **The Investigator's Proof (Nights 1–2).** The camera is your authority. You are the only person who knows this preschool is haunted, and nobody believes you. The camera converts suspicion into evidence. Raising the viewfinder transforms vague unease into precise observation — the crosshair centers, the frame lines lock, and suddenly the wrongness is bounded, captured, provable. Finding an anomaly and framing it perfectly feels like a small triumph: *I see it. I can prove it. This is why I came.* The film counter ticking down from 12 creates a gentle resource pressure that makes each shot feel considered, not panicked. On Nights 1–2, the investigator's fantasy is dominant because there is nothing to fear — only puzzles to spot and evidence to collect.

- **The Prey's Last Stand (Nights 3–7).** The camera becomes the most dangerous thing you can do. Monsters react to the flash. The viewfinder narrows your awareness. The 1.5 m/s movement speed means a Doll can close on you while you're framing it. But the evidence is why you keep coming back — the boss demands photos, the pay increases each night, and walking out with nothing means getting closer to the three-night deadline that triggers the boss's transformation. The fantasy inverts: on Night 1, you raised the camera because you wanted to. On Night 5, you raise it because you have to — and every shutter press feels like daring the preschool to punish you for looking. The film limit, once a gentle constraint, now forces agonizing triage: *Do I waste a shot on this Tier 1 anomaly, or save it for the monster I heard in the next room?*

The progression across nights is the transformation of the camera from instrument of curiosity to instrument of survival. The shutter sound itself changes with horror tier (mechanical click at Tier 1, electrical crackle at Tier 3) — a constant reminder that the camera is not immune to the preschool's corruption. By Night 7, when the boss transforms and the player must escape, the camera is irrelevant — and its absence from the player's hands is the final fantasy inversion. You spent six nights training yourself to raise the camera in response to danger. Night 7 asks you to run instead. The hardest thing in the game is not taking one more shot.

*Serves Pillar 2: "Prove It" — the camera IS the verb, and every design decision serves the tension between getting proof and staying alive. Serves Pillar 1: "Something's Wrong Here" — the viewfinder is the truth instrument that confirms wrongness the player suspects. Serves Pillar 4: "One More Night" — the camera experience escalates from comfortable tool to desperate gamble across the arc.*

## Detailed Design

### Core Rules

#### Camera Activation

The Photography System activates when the First-Person Controller emits `camera_raised == true` (RMB held / Gamepad LT held). The system deactivates when `camera_raised == false` (RMB released). Activation is instant — no raise animation delay. The HUD/UI System's Camera Viewfinder register appears simultaneously.

**While active, the Photography System owns:**
- Zoom level control (scroll wheel / D-pad up/down)
- Shutter trigger (LMB / Gamepad RT)
- Flash state management
- Anomaly lock detection (continuous, every physics frame)
- Film counter

**While active, the Photography System does NOT own:**
- Player movement (First-Person Controller, slowed to 1.5 m/s via `speed_modifier_camera = 0.75`)
- Mouse-look (First-Person Controller, unchanged)
- Viewfinder element rendering (HUD/UI System consumes Photography data)

#### Camera Optics

The Photography System controls a virtual camera aligned to the player's eye position (Camera3D node, child of the player's head bone).

| Property | Default | Notes |
|---|---|---|
| Base FOV | 70° | Matches the player's default Camera3D FOV |
| Zoom levels | 3 discrete: 1.0x, 1.5x, 2.0x | Cycled by scroll wheel / D-pad |
| FOV at 1.0x | 70° | No zoom — same as unaided view |
| FOV at 1.5x | 47° | `FOV_BASE / zoom_level` |
| FOV at 2.0x | 35° | Tight framing for distant anomalies |
| Zoom transition | 0.15s lerp | Smooth FOV interpolation, not instant snap |
| Near clip | 0.05 m | Prevents clipping when close to objects |
| Far clip | 30.0 m | Exceeds any room dimension (20×15m preschool) |

**Zoom input:**
- Mouse scroll up → next zoom level (1.0x → 1.5x → 2.0x → wraps to 1.0x)
- Mouse scroll down → previous zoom level (reverse cycle)
- Gamepad D-pad up → zoom in, D-pad down → zoom out
- Zoom resets to 1.0x when camera is lowered

#### Shutter Mechanics

When the player presses LMB / Gamepad RT while the viewfinder is active:

1. **Guard checks (fail silently — no shutter fires):**
   - `film_remaining <= 0` → blocked. HUD film counter flashes warning.
   - `current_state == PHOTO_PREVIEW` → blocked. Must wait for preview to clear.
   - `current_state == CAPTURING` → blocked. Shutter already in progress.

2. **Shutter fires:**
   a. Record `shutter_transform = camera.global_transform` and `shutter_fov = camera.fov` at this exact frame.
   b. Decrement `film_remaining` by 1. Emit `film_remaining_changed(film_remaining)`.
   c. Fire flash (see Flash Mechanics below). Flash illumination applies this frame.
   d. Call `AnomalySystem.evaluate_photo(shutter_transform, shutter_fov)` → returns `Array[PhotoDetectionResult]`.
   e. Filter results: keep only entries where `detected == true` AND `photo_score >= PHOTO_SCORE_THRESHOLD` (0.15).
   f. Capture SubViewport render to `Image` (single frame, resolution: `PHOTO_RESOLUTION` default 480×270, quarter of 1080p).
   g. Create `PhotoRecord` (see Photo Storage below).
   h. Emit `photo_captured(photo_record)`.
   i. For each detected anomaly in the photo: emit `AnomalySystem.anomaly_photographed(instance, score)`.
   j. Transition to PHOTO_PREVIEW state.

3. **Shutter timing:** Steps 2a–2f are synchronous within a single frame. The SubViewport renders the scene as illuminated by the flash. No multi-frame capture.

#### Flash Mechanics

The flash is a single-pulse illumination that fires with every shutter press. It is not a separate input — the flash is integral to every photo.

**Flash behavior:**
- **Flash fires** automatically with each shutter press. No manual flash toggle.
- **Flash illumination:** An OmniLight3D at the camera position, enabled for exactly 1 physics frame (16ms at 60fps). Parameters: range 8.0m, energy 3.0, color temperature 6500K (daylight white — contrasts with the preschool's 3200K warm ambient). Attenuation: inverse-square.
- **Flash recharge:** After firing, the flash enters a recharge period of `FLASH_RECHARGE_TIME` (default 3.0s). During recharge, the player CAN still take photos, but without flash illumination — the OmniLight3D does not fire. Photos without flash have no illumination boost (darker in dark rooms) but do not provoke flash-sensitive monster reactions.
- **Flash charge state:** Exposed as `flash_charge: float` (0.0–1.0). 0.0 = just fired, 1.0 = fully charged. Linear recharge: `flash_charge += delta / FLASH_RECHARGE_TIME`. HUD renders the segmented arc from this value.
- **Flash and monsters:** When flash fires and a monster is within `FLASH_AFFECT_RADIUS` (default 10.0m) and has line-of-sight to the camera, emit `flash_fired_at_monster(monster_instance, distance)`. Monster AI consumes this signal to trigger flash reactions (freeze, collapse, orient — per Anomaly System Visual/Audio Requirements).
- **Flash and environmental anomalies:** When flash fires and a `react_to_flash == true` anomaly is in frame, `anomaly_photographed` triggers the REACTING state transition in the Anomaly System.
- **No-flash indicator:** When `flash_charge < 1.0`, the HUD's flash charge arc shows partial segments. When `flash_charge == 0.0`, a brief "NO FLASH" text appears in the viewfinder for 0.5s after shutter press (Share Tech Mono, 14px, Semantic Yellow `#F5C842`).

#### Film Limit

Each night provides a fixed number of photos the player can take.

| Property | Value | Notes |
|---|---|---|
| `FILM_PER_NIGHT` | 12 | Default. Configurable per night via `NightProgression.get_film_budget(n)`. |
| `film_remaining` | int | Decremented on each shutter press. Cannot go below 0. |
| Film reset | On night start | `film_remaining = FILM_PER_NIGHT` during LOADING phase. |
| Film on death restart | Reset to `FILM_PER_NIGHT` | Photos from the failed run are discarded; film is restored. |

**Film budget per night (recommended defaults):**

| Night | Film | Rationale |
|---|---|---|
| 1 | 12 | Generous — learning the camera, low anomaly count (3) |
| 2 | 12 | Still generous — 4 anomalies, low pressure |
| 3 | 10 | First monsters — slightly tighter, encourages precision |
| 4 | 10 | Steady pressure |
| 5 | 8 | High anomaly count (9) but limited film — forces triage |
| 6 | 8 | 10 anomalies, 8 shots — every photo matters |
| 7 | 6 | Shortest night, escape sequence — film is almost vestigial |

**When film reaches 0:**
- Shutter is blocked. LMB/RT produces no capture.
- HUD film counter shows `0` in Semantic Yellow with 0.5 Hz pulse.
- Camera can still be raised (viewfinder still functions for scouting) but cannot take photos.
- Emit `film_exhausted` signal (Audio System plays exhaustion cue).

#### Photo Storage

Each captured photo is stored as a `PhotoRecord` resource:

| Field | Type | Description |
|---|---|---|
| `photo_id` | int | Sequential ID within this night run (1, 2, 3...) |
| `image` | Image | Render-to-texture capture (480×270 px) |
| `anomalies` | Array[PhotoAnomalyEntry] | Per-anomaly detection results (see below) |
| `best_score` | float | Highest `photo_score` among detected anomalies (0.0 if none detected) |
| `grade` | String | Letter grade derived from `best_score` (A/B/C/D/F) |
| `room_id` | StringName | Room the player was in at capture time |
| `night` | int | Current night number |
| `timestamp` | float | Seconds elapsed since night start |
| `flash_active` | bool | Whether the flash fired for this photo |
| `zoom_level` | float | Zoom level at capture (1.0, 1.5, or 2.0) |

**PhotoAnomalyEntry:**

| Field | Type | Description |
|---|---|---|
| `anomaly_ref` | AnomalyInstance | Reference to the anomaly |
| `anomaly_id` | StringName | From AnomalyDefinition |
| `photo_score` | float | Composite score for this anomaly in this photo |
| `facing_score` | float | Head-on alignment component |
| `distance_score` | float | Distance optimality component |
| `in_frame_ratio` | float | Framing completeness component |

**Photo collection per night:**
- `photos_this_night: Array[PhotoRecord]` — all photos taken this run.
- On death restart: array cleared, `film_remaining` reset.
- On night completion (DEBRIEF): array passed to Evidence Submission via `get_photos_for_submission()`.
- Photos are NOT persisted across nights. Each night is a fresh roll of film.

#### Evidence Grading

The Photography System grades each individual photo and computes a per-night evidence score. Evidence Submission consumes both for the boss debrief.

**Per-photo grade (from `best_score`):**

| Grade | Score Range | Boss Reaction |
|---|---|---|
| A | ≥ 0.80 | "This is... disturbing. Clear as day." |
| B | ≥ 0.60 | "I can see it. Good work." |
| C | ≥ 0.40 | "Barely usable. Do better." |
| D | ≥ 0.20 | "What am I supposed to see here?" |
| F | < 0.20 | "This is nothing. Wasted film." |

**Per-night evidence score:**

`night_evidence_score = sum(unique_best_scores) / max(1, total_anomalies_this_night)`

Where `unique_best_scores` = for each unique anomaly photographed, take only its highest `photo_score` across all photos. Duplicate photos of the same anomaly contribute only the best score.

| Night Grade | Evidence Score Range |
|---|---|
| A | ≥ 0.70 |
| B | ≥ 0.50 |
| C | ≥ 0.30 |
| D | ≥ 0.15 |
| F | < 0.15 or no photos submitted |

The night grade determines the boss's overall tone in the debrief, the pay multiplier, and the anger escalation.

#### Anomaly Lock

The Photography System continuously evaluates whether an anomaly is currently well-framed in the viewfinder. This provides real-time feedback BEFORE the player presses the shutter.

**Lock detection (runs every physics frame while viewfinder is active):**
1. Call `AnomalySystem.evaluate_photo(camera.global_transform, camera.fov)`.
2. Filter for any result where `detected == true` AND `photo_score >= LOCK_THRESHOLD` (default 0.30 — higher than `PHOTO_SCORE_THRESHOLD` to indicate a "good" framing, not just minimum detection).
3. If any anomaly passes: `anomaly_locked = true`. Select the highest-scoring anomaly as `locked_anomaly`.
4. If none pass: `anomaly_locked = false`, `locked_anomaly = null`.

**Lock feedback (consumed by HUD/UI Viewfinder):**
- `anomaly_locked == true`: Corner brackets change to Unnatural White `#F0F0FF`. Inner frame rectangle pulses (1.5s sine, 70–100% opacity).
- `anomaly_locked == false`: Corner brackets return to Warm cream `#D4C8A0`. No rectangle.
- Transition: instant snap (no fade). Lock is binary — either the framing is good enough or it isn't.

**Performance note:** `evaluate_photo()` is called every physics frame while viewfinder is active. This must be budget-limited — the Anomaly System's pipeline uses early-exit checks (room → frustum → distance → occlusion → facing) to minimize per-frame cost. Typical frame: 3–12 anomalies evaluated, most culled at room/frustum stage.

#### Photo Preview

After a photo is captured, a brief preview shows the player what they got.

- **Duration:** `PREVIEW_DURATION` (default 1.5s). Not interruptible — the player must wait.
- **Display:** The captured Image fills the viewfinder area (replaces the live camera feed). Grade letter stamp appears at center (same styling as Boss Debrief grade — large letter in circular dashed border, per HUD/UI GDD).
- **During preview:**
  - Player movement continues at camera-raised speed (1.5 m/s). Player is NOT frozen.
  - Mouse-look continues (player can look around, but viewfinder shows the static photo, not the live view).
  - Shutter is blocked (cannot take another photo during preview).
  - Anomaly lock detection paused (irrelevant — showing static image).
- **Preview ends:** Viewfinder returns to live camera feed. All controls restored.
- **If camera is lowered during preview (RMB released):** Preview is cancelled immediately. Viewfinder deactivates. Photo is still captured and stored — lowering the camera does not delete the photo.

### States and Transitions

| State | Viewfinder | Shutter | Zoom | Lock Detection | Flash Recharge | Notes |
|---|---|---|---|---|---|---|
| **INACTIVE** | Hidden | Blocked | N/A | Off | Continues silently | Camera not raised. Default state. |
| **VIEWFINDER_ACTIVE** | Live feed | Allowed (if film > 0) | Allowed | Every physics frame | Continues | Player aiming, composing shot |
| **CAPTURING** | Freeze frame (1 frame) | Blocked | Blocked | Paused | Resets to 0 | Shutter processing (single frame) |
| **PHOTO_PREVIEW** | Static captured image | Blocked | Blocked | Paused | Recharging | 1.5s preview of captured photo |

**Transition Rules:**

| From | To | Trigger | Guard |
|---|---|---|---|
| INACTIVE | VIEWFINDER_ACTIVE | `camera_raised == true` | Player state is Normal or Camera Raised (not Running, Dead, Cutscene) |
| VIEWFINDER_ACTIVE | INACTIVE | `camera_raised == false` | Always immediate |
| VIEWFINDER_ACTIVE | CAPTURING | LMB/RT pressed | `film_remaining > 0` AND not in PHOTO_PREVIEW |
| CAPTURING | PHOTO_PREVIEW | Capture complete (same frame) | Always — CAPTURING is a single-frame transient state |
| PHOTO_PREVIEW | VIEWFINDER_ACTIVE | `PREVIEW_DURATION` elapsed | Camera still raised |
| PHOTO_PREVIEW | INACTIVE | `camera_raised == false` | RMB released during preview — cancels preview early |
| Any | INACTIVE | `player_killed` signal | Forced — death overrides all Photography states |
| Any | INACTIVE | `cutscene_start` signal | Forced — Night 7 cutscene overrides |
| Any | INACTIVE | `night_loading_started` signal | Forced — night restart clears Photography state |

**CAPTURING is a transient state:** It exists for exactly one physics frame. The shutter press, photo evaluation, SubViewport capture, PhotoRecord creation, and signal emission all happen within that frame. CAPTURING immediately transitions to PHOTO_PREVIEW. No player-visible time is spent in CAPTURING.

**Flash recharge runs independently of Photography state.** Flash begins recharging immediately after firing, including during PHOTO_PREVIEW and even when the camera is lowered (INACTIVE). The player is never penalized for lowering the camera — the flash recharges in the background.

### Interactions with Other Systems

#### Inputs (other systems → Photography)

| Caller | Signal / Property | When | Effect |
|---|---|---|---|
| First-Person Controller | `camera_raised: bool` | RMB held/released | Activates/deactivates viewfinder and all Photography processing |
| First-Person Controller | `player_position: Vector3` | Every physics frame | Used for flash OmniLight3D position and distance calculations |
| First-Person Controller | `player_facing: Vector3` | Every physics frame | Used as camera forward vector for anomaly lock |
| First-Person Controller | `current_state: enum` | On state change | Photography forces INACTIVE if state is Running, Dead, Cutscene, In Vent, Restarting |
| Night Progression | `night_loading_started(n: int)` | Night start / restart | Reset `film_remaining`, clear `photos_this_night`, reset `flash_charge` to 1.0 |
| Night Progression | `night_completed(n)` | Night ends | Lock Photography — no more photos. Evidence Submission can query stored photos. |
| Anomaly System | `evaluate_photo() -> Array[PhotoDetectionResult]` | Called by Photography at shutter time and every frame for lock | Returns per-anomaly detection data |
| Monster AI | `player_killed` | Monster attack completes | Force Photography to INACTIVE. Photos from this run will be discarded by Night Progression. |

#### Outputs (Photography → other systems)

**Signals:**

| Signal | Parameters | Consumed By | When |
|---|---|---|---|
| `photo_captured(record: PhotoRecord)` | Full photo record | Evidence Submission, Photo Gallery | After shutter processing completes |
| `film_remaining_changed(count: int)` | New film count | HUD/UI (Preschool HUD film counter, Viewfinder photo counter) | On shutter press, on night reset |
| `flash_fired(position: Vector3, energy: float)` | Camera world position, flash energy | Audio System (flash SFX), Anomaly System (react_to_flash triggers) | On shutter press when flash_charge >= 1.0 |
| `flash_fired_at_monster(instance: AnomalyInstance, distance: float)` | Monster ref, distance to flash | Monster AI (flash reaction behavior) | When flash fires and monster is within FLASH_AFFECT_RADIUS with line-of-sight |
| `flash_charge_changed(charge: float)` | 0.0–1.0 | HUD/UI (Viewfinder flash charge arc) | Every frame during recharge, and on reset |
| `zoom_level_changed(level: float)` | 1.0, 1.5, or 2.0 | HUD/UI (Viewfinder zoom indicator) | On scroll wheel / D-pad |
| `anomaly_locked_changed(locked: bool, anomaly: AnomalyInstance)` | Lock state, locked anomaly (or null) | HUD/UI (Viewfinder anomaly lock overlay) | On lock state change (every frame evaluation, signal only on change) |
| `film_exhausted` | (none) | Audio System (warning cue), HUD/UI (film counter warning state) | When `film_remaining` hits 0 |
| `photo_preview_started(record: PhotoRecord)` | Photo record | HUD/UI (switches viewfinder to static preview) | Immediately after capture |
| `photo_preview_ended` | (none) | HUD/UI (switches viewfinder back to live feed) | After PREVIEW_DURATION or camera lowered |

**Query API:**

| Method | Returns | Callers |
|---|---|---|
| `get_photos_for_submission() -> Array[PhotoRecord]` | All photos captured this night | Evidence Submission (at DEBRIEF phase) |
| `get_best_photo_for_anomaly(anomaly_id: StringName) -> PhotoRecord` | Highest-scoring photo of a specific anomaly | Photo Gallery, Evidence Submission |
| `get_film_remaining() -> int` | Current film count | HUD/UI, debug |
| `get_flash_charge() -> float` | 0.0–1.0 | HUD/UI, debug |
| `get_zoom_level() -> float` | Current zoom (1.0, 1.5, 2.0) | HUD/UI, debug |
| `is_anomaly_locked() -> bool` | Whether an anomaly is currently well-framed | HUD/UI |
| `get_locked_anomaly() -> AnomalyInstance` | Currently locked anomaly (or null) | HUD/UI, debug |
| `get_unique_anomalies_photographed() -> int` | Count of distinct anomalies captured | Evidence Submission, HUD/UI (optional) |
| `get_night_evidence_score() -> float` | Computed night evidence score | Evidence Submission |

## Formulas

### Zoom FOV

The `zoom_fov` formula maps discrete zoom levels to camera FOV.

`zoom_fov = FOV_BASE / zoom_level`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| FOV_BASE | F_b | float | 70° | Default camera FOV (no zoom) |
| zoom_level | z | float | {1.0, 1.5, 2.0} | Discrete zoom steps |
| zoom_fov | — | float | 35°–70° | Resulting camera FOV |

**Output Range:** 35° to 70°. Three discrete values only (no continuous zoom).

**Example — 1.5x zoom:**
- `zoom_fov = 70 / 1.5 = 46.67°` (rounded to 47° for display)

### Flash Recharge

The flash recharges linearly from 0.0 to 1.0 over `FLASH_RECHARGE_TIME`.

`flash_charge(t) = min(1.0, t_elapsed / FLASH_RECHARGE_TIME)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| t_elapsed | t | float | 0.0–∞ s | Time since flash last fired |
| FLASH_RECHARGE_TIME | T_r | float | 3.0 s | Time to full charge (tuning knob) |
| flash_charge | — | float | 0.0–1.0 | Current charge level. 1.0 = ready to fire with illumination. |

**Output Range:** 0.0 to 1.0. Clamped at 1.0.

**Example — 1.5s after firing:**
- `flash_charge = min(1.0, 1.5 / 3.0) = 0.5` (50% charged, 4 of 8 HUD segments lit)

**Design rationale:** Linear recharge is chosen over diminishing returns for simplicity and readability — the HUD's 8-segment arc fills at a constant rate, making the recharge feel predictable. The player learns the rhythm: fire, wait ~3 seconds, fire again.

### Film Budget Per Night

Film count per night is a lookup table, not a formula. Stored in `assets/data/night_config.tres` alongside other per-night parameters.

`film_budget(n) = FILM_TABLE[n]`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| n | n | int | 1–7 | Night number |
| FILM_TABLE | — | Array[int] | — | Per-night film counts |
| film_budget | — | int | 6–12 | Film available this night |

**Default FILM_TABLE:** `[12, 12, 10, 10, 8, 8, 6]`

**Output Range:** 6 to 12.

**Design rationale:** Stepped rather than formulaic. Each step down (12→10, 10→8, 8→6) aligns with a horror tier transition and is authored intentionally — not derived from a curve. This allows playtesting to adjust individual nights without affecting others.

### Per-Photo Grade

The per-photo letter grade maps `best_score` to a grade letter.

`grade(s) = A if s ≥ 0.80, B if s ≥ 0.60, C if s ≥ 0.40, D if s ≥ 0.20, F otherwise`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| best_score | s | float | 0.0–1.0 | Highest photo_score among detected anomalies in this photo |
| grade | — | String | {A, B, C, D, F} | Letter grade |

**Grade thresholds:**

| Grade | Threshold | Practical Meaning |
|---|---|---|
| A (≥ 0.80) | All four scoring factors strong | Head-on, optimal distance, fully framed, high-tier anomaly |
| B (≥ 0.60) | Most factors strong, one slightly weak | Good photo — maybe slightly off-angle or not perfectly centered |
| C (≥ 0.40) | Mixed quality | Anomaly is clearly visible but the photo isn't composed well |
| D (≥ 0.20) | Barely usable | Anomaly is technically in frame but poorly captured |
| F (< 0.20) | Detection threshold met but quality is terrible | Just above the 0.15 threshold — the boss can barely identify it |

**Example — Tier 2 anomaly, decent shot:**
- `photo_score = 0.8 * 0.9 * 0.7 * 0.85 = 0.428` → Grade C

### Night Evidence Score

The aggregate score for the night determines the boss's overall grade, pay, and tone.

`night_evidence_score = sum(unique_best_scores) / max(1, total_anomalies_this_night)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| unique_best_scores | U | Array[float] | — | For each unique anomaly photographed, its highest photo_score across all photos |
| total_anomalies_this_night | A_t | int | 3–12 | Total anomalies placed (from `AnomalySystem.get_total_count()`) |
| night_evidence_score | — | float | 0.0–1.0 | Aggregate quality. Rewards both coverage and quality. |

**Output Range:** 0.0 to 1.0. 0.0 = no photos or no anomalies detected. 1.0 = every anomaly photographed perfectly (theoretically impossible — would require A-grade photos of all anomalies).

**Night grade thresholds:**

| Grade | Score Range | Boss Tone |
|---|---|---|
| A | ≥ 0.70 | Impressed but unsettled — the evidence is too good |
| B | ≥ 0.50 | Professional approval — "Keep it up" |
| C | ≥ 0.30 | Dismissive — "I expected more" |
| D | ≥ 0.15 | Angry — "This barely counts" |
| F | < 0.15 | Threatening — "One more night like this..." |

**Example — Night 3 (6 anomalies total), player photographed 4:**
- Anomaly 1 best score: 0.72 (B)
- Anomaly 2 best score: 0.45 (C)
- Anomaly 3 best score: 0.38 (D)
- Anomaly 4 best score: 0.61 (B)
- `night_evidence_score = (0.72 + 0.45 + 0.38 + 0.61) / 6 = 2.16 / 6 = 0.36` → Night Grade C

**Design rationale:** Dividing by `total_anomalies_this_night` (not just photographed count) means the player cannot get an A by perfectly photographing 2 of 12 anomalies. Coverage matters — the boss wants comprehensive evidence, not cherry-picked highlights. This rewards exploration and risk-taking (going deeper into the preschool for more anomalies) over safe, minimal play.

### Photo Preview Duration

Fixed value, not a formula. `PREVIEW_DURATION = 1.5s`.

**Design rationale:** Fixed rather than score-dependent to maintain a consistent rhythm. The player's internal clock learns: click, wait, ready. Variable durations would make the camera feel unpredictable — the opposite of the Viewfinder's "truth instrument" fantasy.

## Edge Cases

### Camera Activation

- **If player presses RMB while Running:** FPC blocks camera raise. Photography System never receives `camera_raised == true`. No action needed — guarded upstream.

- **If player starts Running while camera is raised (Shift pressed while RMB held):** FPC auto-lowers camera (`camera_raised = false`). Photography transitions to INACTIVE. Zoom resets to 1.0x. Any in-progress PHOTO_PREVIEW is cancelled. Photo still stored.

- **If `camera_raised` toggles rapidly (RMB spam):** Each `false` → `true` transition resets zoom to 1.0x and re-enters VIEWFINDER_ACTIVE. No debounce — instant transitions match the FPC's instant raise/lower. Lock detection restarts from scratch each activation.

- **If player enters Dead state while camera is raised:** Photography receives `player_killed` → force INACTIVE. All Photography state resets. Photos from this run will be discarded by Night Progression (separate responsibility).

### Shutter and Film

- **If player presses LMB with 0 film remaining:** Shutter is blocked. Emit `film_exhausted` (if not already emitted). HUD film counter flashes. No SubViewport capture, no flash fire, no signals. Camera raise sound does NOT play (already raised). A soft "empty click" audio cue plays via `SFX_World` bus.

- **If player presses LMB during PHOTO_PREVIEW:** Blocked. The preview must complete (1.5s) or the player must lower the camera first.

- **If the player takes a photo with 1 film remaining:** Normal shutter sequence. `film_remaining` decrements to 0. `film_remaining_changed(0)` fires. `film_exhausted` fires. Next LMB press is blocked.

- **If two shutter presses arrive within the same physics frame (should be impossible with standard input, but guarded):** Only the first processes. CAPTURING state blocks the second.

### Flash

- **If player takes a photo while flash is recharging (charge < 1.0):** Photo is captured normally but WITHOUT flash illumination. The OmniLight3D does not fire. `flash_fired` signal does NOT emit. `flash_fired_at_monster` does NOT emit. The photo may be darker in dark rooms. Monster flash reactions do not trigger. The "NO FLASH" indicator appears briefly in the viewfinder.

- **If flash fires and multiple monsters are within FLASH_AFFECT_RADIUS:** `flash_fired_at_monster` emits once per monster (not once total). Each monster evaluates its own flash reaction independently.

- **If flash fires but the monster is behind a wall (no line-of-sight):** `flash_fired_at_monster` does NOT emit for that monster. Line-of-sight check: raycast from camera to monster detection center. If blocked by a non-transparent collider, the monster is not affected.

- **If flash fires in a fully lit room (Night 1, Tier 1):** Flash still fires. The illumination is additive — the room becomes briefly over-lit (6500K daylight flash on top of 3200K warm ambient). The visual contrast is subtle in bright rooms, dramatic in dark rooms. The mechanical behavior is identical regardless of ambient light level.

### Photo Detection

- **If the viewfinder captures a doorway showing anomalies in two rooms:** `evaluate_photo()` returns results for ALL visible anomalies across rooms (per Anomaly System's room check that includes adjacent rooms visible through doorways). Multiple anomalies can be detected in a single photo. Each gets its own PhotoAnomalyEntry.

- **If the player photographs an anomaly that was already photographed (re-photograph):** Valid. A new PhotoRecord is created. If the new photo's score is higher, `get_best_photo_for_anomaly()` returns the new one. The `unique_best_scores` array for night evidence scoring uses only the best score per anomaly — duplicates don't inflate the grade.

- **If the camera is zoomed to 2.0x and the anomaly's detection AABB is larger than the viewport:** `in_frame_ratio` will be < 1.0 (not all AABB corners in frustum). Photo is still valid but the score is reduced. This is correct — zooming too close on a large anomaly produces a partial capture.

- **If `evaluate_photo()` returns zero results (no anomalies in frame):** The photo is captured and stored with `best_score = 0.0`, `grade = "F"`, and empty `anomalies` array. Film is still consumed. Flash still fires. The player "wasted" a shot. This is intentional — film scarcity is a soft penalty.

- **If anomaly lock indicates "locked" but the shutter captures a lower score (anomaly moved between lock frame and shutter frame):** The lock is advisory — it evaluates the previous frame's state. The shutter evaluates the current frame's state. Monsters can move between frames. The photo score is authoritative, not the lock state. Rare but possible; no mitigation needed beyond documenting the expected behavior.

### Monster Interactions

- **If a monster kills the player during the same frame the shutter fires:** Per Anomaly System edge case rules, the photo is captured before the death state processes. However, the photos are discarded on death restart (Night Progression rule). The photo exists briefly in `photos_this_night` but is cleared on restart.

- **If the player photographs a monster during its ATTACKING state:** Per Anomaly System: photo detection is disabled during ATTACKING (monster is too close, camera is being forced down by death animation). Shutter fires but the monster returns `detected = false`. Photo captures the monster visually (SubViewport) but scores no anomaly. Grade F.

- **If a monster enters PURSUING state because of a flash:** The flash provoked the monster via `flash_fired_at_monster`. Monster AI decides the behavioral response. Photography System has no further responsibility — it reported the flash event and moves on.

### Night Lifecycle

- **If `night_loading_started` fires while Photography is in PHOTO_PREVIEW:** Force INACTIVE. Clear `photos_this_night`. Reset `film_remaining` to `film_budget(n)`. Reset `flash_charge` to 1.0. Reset zoom to 1.0x.

- **If the player exits to DEBRIEF while camera is raised:** Camera is lowered by FPC state transition. Photography transitions to INACTIVE. Photos remain in `photos_this_night` for Evidence Submission to query.

- **If Night 7 escape sequence starts (FINALE phase):** Photography forced to INACTIVE. Camera cannot be raised during FINALE. The player's hands are needed for running, not photographing. `film_remaining` is irrelevant.

- **If the player submits 0 photos for the night (exits without photographing):** `get_photos_for_submission()` returns an empty array. `night_evidence_score = 0.0`. Night Grade F. Evidence Submission handles the boss's response (anger escalation, consecutive-no-photo counter per Night Progression).

## Dependencies

### Hard Dependencies (system cannot function without these)

| System | Direction | Interface | Nature |
|---|---|---|---|
| **First-Person Controller** | Upstream → Photography | `camera_raised: bool` (activates/deactivates the entire system), `player_position: Vector3`, `player_facing: Vector3`, `current_state: enum`. FPC owns the RMB hold mechanic and the speed reduction to 1.5 m/s. Photography cannot activate without FPC's camera raise signal. | Hard — Photography has no input source without FPC. |
| **Anomaly System** | Upstream → Photography | `evaluate_photo(camera_transform, camera_fov) -> Array[PhotoDetectionResult]` query API at shutter time and every frame for lock detection. `anomaly_photographed(instance, score)` signal emitted by Photography back to Anomaly System. `get_total_count()`, `get_active_anomalies()` for evidence scoring. | Hard — without Anomaly System, photos have no subjects to evaluate. The camera works mechanically but cannot produce scored evidence. |
| **HUD/UI System** | Bidirectional | Photography → HUD: `film_remaining_changed`, `flash_charge_changed`, `zoom_level_changed`, `anomaly_locked_changed`, `photo_preview_started`, `photo_preview_ended`. HUD owns rendering of the Camera Viewfinder register. Photography provides all data; HUD renders all visuals. | Hard — without HUD, the player has no viewfinder feedback. The shutter would still work but the experience would be unplayable. |

### Soft Dependencies (enhanced by, but works without)

| System | Direction | Interface | Nature |
|---|---|---|---|
| **Night Progression** | Upstream → Photography | `night_loading_started(n)` triggers film/flash/photo reset. `get_film_budget(n)` provides per-night film count. `night_completed(n)` locks Photography for debrief. | Soft — Photography could be triggered directly for testing without Night Progression, using default film count. |
| **Audio System** | Photography → Downstream | `flash_fired(position, energy)` triggers flash SFX. `film_exhausted` triggers warning cue. Shutter sound selection per horror tier. Camera raise/lower sounds. | Soft — Photography functions silently without Audio. |
| **Monster AI** | Photography → Downstream | `flash_fired_at_monster(instance, distance)` triggers monster flash reactions. Monster AI's state changes (PURSUING, ATTACKING) affect photo detection validity. | Soft — without Monster AI, monsters don't react to flash but are still photographable as static anomalies. |
| **Evidence Submission** | Photography → Downstream | `get_photos_for_submission()`, `get_night_evidence_score()`, `get_best_photo_for_anomaly()` query APIs consumed during DEBRIEF phase. | Soft — Photography stores photos regardless of whether Evidence Submission exists. |
| **Photo Gallery** | Photography → Downstream | `get_photos_for_submission()`, `get_best_photo_for_anomaly()` query APIs consumed for photo review/selection UI. | Soft — not yet designed. Photography does not depend on gallery existing. |
| **Room/Level Management** | Implicit (via Anomaly System) | Photography does not directly interface with Room Management. Room context (`room_id`) is recorded in PhotoRecord from the player's current room (queried via `RoomManager.get_current_room()`). | Soft — one direct query for room_id in PhotoRecord. |

### Bidirectional Consistency Notes

- **First-Person Controller** lists Photography System as a consumer of `camera_raised`, `player_position`, `player_facing`. ✓ This GDD confirms consumption via these exact signals/properties.
- **Anomaly System** lists Photography System as a consumer of `evaluate_photo()` and as the emitter of `anomaly_photographed(instance, score)`. ✓ This GDD confirms both directions.
- **Anomaly System** dependency note states: "When Photography System is designed, it must document Anomaly System as upstream and specify it consumes `evaluate_photo()` at shutter time." ✓ Done.
- **HUD/UI System** lists provisional contracts for `film_remaining_changed`, `flash_charge`, `zoom_level`, `anomaly_locked`, `photos_taken`, `film_remaining`. ✓ This GDD provides all these as signals/properties. HUD provisional stub values can now be replaced.
- **Night Progression** references Photography indirectly through the DEBRIEF phase. ✓ This GDD specifies the photo collection handoff at DEBRIEF.
- **Evidence Submission** is not yet designed. When designed, it must document Photography System as upstream and specify it consumes `get_photos_for_submission()`, `get_night_evidence_score()`, and the `DebriefData` contract (partially defined in HUD/UI GDD).

## Tuning Knobs

| # | Knob | Type | Default | Safe Range | Affects | Interaction Notes |
|---|---|---|---|---|---|---|
| 1 | `FOV_BASE` | float | 70° | 60°–80° | Base camera field of view. Wider = more context visible, anomalies smaller. Narrower = more focused, anomalies larger in frame. | Must match the player's default Camera3D FOV in FPC. Changing this without changing FPC creates a jarring FOV shift on camera raise. |
| 2 | `ZOOM_LEVELS` | Array[float] | [1.0, 1.5, 2.0] | 2–4 discrete values, max 3.0x | Zoom steps available. More levels = finer control. Higher max = tighter framing at range. | At 3.0x zoom, FOV = 23° — very narrow. Monsters can exit frame easily. Above 3.0x, the SubViewport becomes a sniper scope — wrong for horror. |
| 3 | `ZOOM_TRANSITION_TIME` | float | 0.15 s | 0.05–0.30 s | FOV interpolation speed between zoom levels. | Lower = snappy, responsive. Higher = cinematic smoothness. At 0.0s, FOV snaps instantly (disorienting). |
| 4 | `FLASH_RECHARGE_TIME` | float | 3.0 s | 1.5–5.0 s | Seconds to recharge flash from 0 to full. | Shorter = more flash-assisted photos per night. Longer = more no-flash photos in dark rooms. At 1.5s, flash is almost always available (low tension). At 5.0s, the player must choose which shots get flash. |
| 5 | `FLASH_RANGE` | float | 8.0 m | 4.0–12.0 m | OmniLight3D range for flash illumination. | Larger = lights up more of the room (safer feeling). Smaller = narrow pool of light (more horror). Must be > `PHOTO_MAX_DISTANCE_MONSTER` (8.0m from Anomaly System) or distant monsters won't be illuminated. |
| 6 | `FLASH_ENERGY` | float | 3.0 | 1.5–5.0 | OmniLight3D energy (intensity). | Higher = brighter flash, more overexposure effect. Lower = subtle illumination boost. At 5.0, flash whites out everything briefly. At 1.5, flash is barely noticeable in lit rooms. |
| 7 | `FLASH_AFFECT_RADIUS` | float | 10.0 m | 6.0–15.0 m | Maximum distance for `flash_fired_at_monster` to trigger. | Larger = flash provokes distant monsters (more dangerous). Smaller = only nearby monsters react. Should be ≥ `FLASH_RANGE` — a monster can react to flash even if only partially illuminated. |
| 8 | `FILM_TABLE` | Array[int] | [12,12,10,10,8,8,6] | Each entry: 4–16 | Per-night film budget. | Lower values on later nights increase triage pressure. Higher values reduce decision tension. Total across 7 nights: 66 (default). Each entry is independently tunable. |
| 9 | `PREVIEW_DURATION` | float | 1.5 s | 0.5–3.0 s | How long the photo preview shows before returning to live viewfinder. | Shorter = faster rhythm, less interruption, less time to read grade. Longer = more dramatic reveal, more exposure to danger while vulnerable. At 0.5s, the grade stamp barely registers. At 3.0s, the player is frozen for a meaningful amount of time. |
| 10 | `LOCK_THRESHOLD` | float | 0.30 | 0.15–0.60 | Minimum `photo_score` for the anomaly lock indicator to activate. Higher than `PHOTO_SCORE_THRESHOLD` (0.15) to indicate "good" framing. | Lower = lock activates on mediocre framing (less useful as feedback). Higher = lock only activates on well-composed shots (more useful but harder to trigger). At 0.15, lock activates the same time as detection (no additional feedback value). |
| 11 | `PHOTO_RESOLUTION` | Vector2i | 480×270 | 240×135–960×540 | SubViewport render resolution for photo captures. | Higher = sharper photo previews, more VRAM. Lower = blurrier but faster. At 960×540 (half 1080p), each photo is ~0.5 MB uncompressed. With 12 photos, that's 6 MB per night — within the 512 MB memory budget but not trivial. |
| 12 | `GRADE_THRESHOLDS` | Array[float] | [0.80, 0.60, 0.40, 0.20] | Each: 0.10–0.95 | Score thresholds for A/B/C/D grades. F = below lowest. | Lowering all thresholds makes the boss easier to please. Raising them makes photography more demanding. Must remain in descending order. |
| 13 | `NIGHT_GRADE_THRESHOLDS` | Array[float] | [0.70, 0.50, 0.30, 0.15] | Each: 0.10–0.90 | Score thresholds for night evidence grade (A/B/C/D). | Lower = easier to get a high night grade. Higher = demands more coverage and quality. At 0.90 for A, getting an A-night is nearly impossible (would require A-grade photos of 90% of anomalies). |

**Knobs NOT owned by this system** (tuned elsewhere, consumed here):
- `speed_modifier_camera` (0.75) — owned by First-Person Controller. Determines player speed while photographing.
- `PHOTO_SCORE_THRESHOLD` (0.15) — owned by Anomaly System. Minimum score for detection.
- `photo_facing_threshold_env` (60°), `photo_facing_threshold_monster` (45°) — owned by Anomaly System. Per-anomaly-type facing angles.
- `photo_min/max_distance_env/monster` — owned by Anomaly System. Per-anomaly-type distance ranges.
- `PHOTO_SCORE_BASE_T1/T2/T3` (0.6/0.8/1.0) — owned by Anomaly System. Per-tier base scores.
- `warning_pulse_hz` (0.5 Hz) — owned by HUD/UI System. Shared pulse rate for warning states.

## Visual/Audio Requirements

### Flash VFX

**Flash illumination:**
- OmniLight3D at camera position, enabled for 1 physics frame (16ms).
- Color: 6500K daylight white (`#FFFAF0`). Deliberately colder than the preschool's 3200K warm ambient — the flash imposes clinical truth on a corrupted space.
- Range: 8.0m (FLASH_RANGE). Energy: 3.0 (FLASH_ENERGY). Attenuation: inverse-square (`ATTENUATION_INVERSE_DISTANCE_SQUARED`).
- **Night interaction:** On Nights 1–2 (well-lit rooms), flash adds subtle brightness. On Nights 5–6 (dark rooms, Tier 3), flash creates harsh shadows and high-contrast pools — the only moment the player sees the room clearly, which makes the darkness after feel worse.
- WebGL 2 safe: OmniLight3D is standard Godot lighting. No deferred rendering required.

**Flash overexposure (screen effect):**
- On shutter press with flash: a full-screen `ColorRect` on the Viewfinder CanvasLayer flashes white (`#FFFFFF`) at 80% opacity for 1 frame, then decays to 0% over 0.3s (linear fade). This simulates the camera's own sensor overexposure from the flash.
- During PHOTO_PREVIEW, the captured image includes the flash illumination (SubViewport renders the flash-lit frame).
- WebGL 2 safe: 2D overlay, no post-processing.

**Flash in darkness (Tier 3 rooms, Nights 5+):**
- The flash becomes the player's only light source for that single frame. The SubViewport capture shows a brightly lit scene surrounded by void — the photo is a frozen moment of clarity in darkness. The contrast between the flash frame and the dark room that follows is a designed horror beat.

### Photo Capture VFX

**Shutter moment:**
1. White flash overlay (see above) — 1 frame + 0.3s decay.
2. Viewfinder freeze: the live camera feed pauses for 1 frame (the CAPTURING state). Player perception: a brief "click" pause before the preview appears.
3. Transition to PHOTO_PREVIEW: the captured Image replaces the live feed. No transition animation — single-frame cut.

**Grade stamp appearance (during preview):**
- Grade letter appears at viewfinder center at `t = 0.3s` into preview (not instant — brief suspense).
- Stamp style: circular dashed border (matching Boss Debrief grade from HUD/UI GDD), 60px diameter in viewfinder, letter 36px Lora bold.
- Grade colors: A=`#48B04A`, B=`#8DB84A`, C=`#F5C842`, D=`#E8732A`, F=`#C0181E` (Arterial Red).
- Appearance animation: single-frame cut (no fade, no scale — the stamp IS the animation, per HUD/UI GDD design principle).
- If no anomaly detected (grade F, empty anomalies array): no stamp appears. The empty photo speaks for itself.

**Preview border:**
- During PHOTO_PREVIEW, the viewfinder's corner brackets pulse slowly (0.5s sine, 50–100% opacity) in the grade's color. This is the only color intrusion into the viewfinder's normally monochrome `#D4C8A0` palette — and it lasts only 1.5s.

### Viewfinder Visual Feel

The Camera Viewfinder register is defined by HUD/UI System. Photography System influences its data, not its rendering. However, these visual qualities should be applied to the viewfinder CanvasLayer:

**Film grain overlay:**
- A subtle noise texture (128×128 repeating, 5% opacity) overlaid on the viewfinder area. Static grain — not animated (animated grain costs GPU cycles for minimal horror payoff).
- Purpose: the camera is analog. The grain is a subtle reminder that this is an imperfect instrument recording an imperfect truth.
- **Does NOT degrade with horror tier.** The viewfinder is the truth instrument — it does not participate in Color Debt or environmental corruption. Its visual consistency IS the design point (per HUD/UI Player Fantasy: "the camera's rules never change").

**Vignette:**
- Soft radial darkening at viewfinder edges, 15% opacity at corners. Simulates lens vignetting.
- Implementation: a radial gradient `TextureRect` on the Viewfinder CanvasLayer. WebGL 2 safe.

### Audio Signatures

All Photography audio routes to `SFX_World` bus (non-spatial, player-originated) unless noted.

**Camera raise:**
- Soft mechanical click. 0.1s duration. Pitched at ~2000 Hz (small mechanism engaging).
- Plays on `camera_raised == true` transition. Quiet — should not mask room ambient.

**Camera lower:**
- Inverse click, slightly softer (-2dB). 0.08s duration.
- Plays on `camera_raised == false` transition.

**Zoom in/out:**
- Lens servo whirr. 0.12s duration per step. Pitch shifts with zoom level: 1.0x→1.5x = rising pitch, 1.5x→2.0x = higher rising pitch, reverse for zoom out.
- Quiet — -6dB relative to shutter. The zoom sound is feedback, not an event.

**Flash fire:**
- Sharp electrical crack, 0.05s attack, 0.15s decay. Frequency: broadband transient centered at ~4000 Hz.
- Louder than shutter (+3dB). The flash sound is designed to be startling in quiet rooms — it announces the player's presence to the preschool.
- Routes to `SFX_World` (player hears it at full volume regardless of room).
- Separate from the shutter click — plays simultaneously. The shutter is the mechanical sound; the flash is the electrical sound.

**Flash recharge tick (optional, low priority):**
- A barely audible high-frequency whine (8000–10000 Hz) that ramps from 0 to -18dB over the recharge duration. Stops at full charge. Players who learn to listen for it know when flash is ready without checking the HUD.
- Only audible in quiet rooms (Nap Room, Principal's Office).

**Shutter variants (per horror tier — already defined in Audio System GDD):**
- Tier 1: Mechanical click-whirr. Warm, analog.
- Tier 2: Same click + 20ms reversed pre-transient (phantom click before real click).
- Tier 3: Same click + electrical flash crackle.
- Anomaly in frame: Low-frequency thump underlayer (60–80 Hz, 0.2s decay).

**Anomaly lock acquired:**
- Subtle double-tap tone at 1200 Hz, 0.05s each, 0.05s gap. Total: 0.15s. -6dB relative to shutter.
- Plays once when `anomaly_locked` transitions from `false` to `true`. Does NOT repeat while locked.

**Anomaly lock lost:**
- Single low tone at 400 Hz, 0.08s, quick decay. -8dB. Barely perceptible — the absence of the viewfinder glow is the primary feedback.

**Film exhausted:**
- Hollow click (shutter mechanism with no film). 0.2s. Pitched lower than normal shutter (-200 Hz). Dry, unsatisfying.
- Plays on each LMB/RT press when `film_remaining == 0`.

**Grade reveal (during photo preview):**
- At `t = 0.3s` into preview (when grade stamp appears):
  - Grade A/B: a warm confirmation tone. Single note, 600 Hz, 0.3s sustain, gentle decay. -3dB.
  - Grade C: neutral click. Same as camera raise sound.
  - Grade D/F: a dull low thud. 120 Hz, 0.2s. Same frequency as the "anomaly in frame" thump but drier — the camera acknowledges failure.

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:photography-system` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

The Photography System's UI is entirely contained within the HUD/UI System's **Camera Viewfinder register** (Register 2). Photography provides data; HUD/UI renders it. There are no Photography-specific UI screens or overlays beyond what the Viewfinder register already defines.

**Data contracts Photography fulfills for the Viewfinder:**

| Viewfinder Element | HUD/UI Provisional Contract | Photography Signal/Property | Notes |
|---|---|---|---|
| Zoom Indicator | `zoom_level: float` (stub: 1.0) | `zoom_level_changed(level: float)` | Now fully specified: values are 1.0, 1.5, or 2.0 |
| Flash Charge Arc | `flash_charge: float` (stub: 1.0) | `flash_charge_changed(charge: float)` | 0.0–1.0, updates every frame during recharge |
| Anomaly Lock | `anomaly_locked: bool` (stub: false) | `anomaly_locked_changed(locked: bool, anomaly: AnomalyInstance)` | Triggers corner bracket color change and inner frame pulse |
| Photo Counter | `photos_taken: int`, `film_remaining: int` (stub: 0/12) | `film_remaining_changed(count: int)`, computed `photos_taken = FILM_PER_NIGHT - film_remaining` | Format: `[taken]/[total]` e.g., `3/12` |
| Photo Preview | (not provisioned) | `photo_preview_started(record: PhotoRecord)`, `photo_preview_ended` | NEW: viewfinder switches from live feed to static captured Image during preview |
| Grade Stamp | (not provisioned) | Embedded in `photo_preview_started` — grade is on the `PhotoRecord` | NEW: appears at t=0.3s into preview, uses Boss Debrief grade styling |
| No Flash Indicator | (not provisioned) | Photography manages internally | NEW: "NO FLASH" text at bottom-center of viewfinder, 0.5s display, Share Tech Mono 14px, Semantic Yellow |
| Film Exhausted | (not provisioned) | `film_exhausted` signal | NEW: HUD film counter enters permanent warning state (pulse at 0.5 Hz) |

**HUD/UI GDD updates needed:**
The HUD/UI System GDD (hud-ui-system.md) contains provisional contracts with stub values for the Viewfinder register. Now that Photography System is designed, the following stubs should be updated:
1. `zoom_level` stub (1.0) → connected to `zoom_level_changed` signal
2. `flash_charge` stub (1.0) → connected to `flash_charge_changed` signal
3. `anomaly_locked` stub (false) → connected to `anomaly_locked_changed` signal
4. `photos_taken/film_remaining` stub (0/12) → connected to `film_remaining_changed` signal
5. NEW elements to add: Photo Preview display, Grade Stamp in preview, No Flash indicator, Film Exhausted persistent warning

These updates should be made via a `/propagate-design-change` pass after this GDD is approved.

📌 **UX Flag — Photography System**: This system has UI requirements fulfilled entirely through the existing Viewfinder register. In Phase 4 (Pre-Production), run `/ux-design` to validate the viewfinder interaction flow and the photo preview timing before writing epics. Stories that reference viewfinder behavior should cite both `design/gdd/photography-system.md` and `design/gdd/hud-ui-system.md`.

## Acceptance Criteria

### Camera Mechanics

1. **GIVEN** the player is in Normal state, **WHEN** RMB is held, **THEN** the viewfinder activates within 1 frame (no animation delay) and `camera_raised == true` propagates to all consuming systems.

2. **GIVEN** the viewfinder is active at 1.0x zoom, **WHEN** the player scrolls up, **THEN** the FOV interpolates from 70° to 47° over 0.15s (±0.02s).

3. **GIVEN** the viewfinder is active at 2.0x zoom, **WHEN** the player scrolls up, **THEN** the FOV returns to 70° (1.0x, cycle wraps).

4. **GIVEN** the viewfinder is active, **WHEN** the player releases RMB, **THEN** zoom resets to 1.0x immediately and the viewfinder deactivates.

### Shutter and Flash

5. **GIVEN** the viewfinder is active with film_remaining > 0 and flash fully charged, **WHEN** LMB is pressed, **THEN** a PhotoRecord is created, film_remaining decrements by 1, flash fires (OmniLight3D pulses for 1 frame), and the SubViewport captures the flash-lit scene.

6. **GIVEN** the viewfinder is active with film_remaining > 0 and flash recharging (charge < 1.0), **WHEN** LMB is pressed, **THEN** a PhotoRecord is created WITHOUT flash illumination, the "NO FLASH" indicator appears for 0.5s, and `flash_fired_at_monster` does NOT emit.

7. **GIVEN** film_remaining == 0, **WHEN** LMB is pressed, **THEN** no photo is captured, no flash fires, the empty-click audio plays, and the film counter flashes warning.

8. **GIVEN** the flash just fired, **WHEN** 3.0s elapse, **THEN** flash_charge reaches 1.0 (±0.1s) and the HUD flash charge arc shows all 8 segments lit.

### Photo Scoring and Grading

9. **GIVEN** an environmental anomaly (Tier 2, photo_score_base 0.8) is perfectly framed (in_frame_ratio=1.0, facing_score=1.0, distance_score=1.0), **WHEN** the shutter fires, **THEN** photo_score = 0.80 and grade = A.

10. **GIVEN** a monster anomaly (Tier 3, photo_score_base 1.0) at 30° off head-on (facing_score ~0.33 with 45° threshold), optimal distance (distance_score=1.0), fully framed (in_frame_ratio=1.0), **WHEN** the shutter fires, **THEN** photo_score ≈ 0.33 and grade = D.

11. **GIVEN** no anomaly is in the camera frustum, **WHEN** the shutter fires, **THEN** the photo is stored with best_score=0.0 and grade=F, and film is consumed.

12. **GIVEN** the player photographs the same anomaly twice (scores 0.45 and 0.72), **WHEN** `get_best_photo_for_anomaly()` is called, **THEN** it returns the photo with score 0.72.

### Night Evidence Score

13. **GIVEN** Night 3 with 6 anomalies total, the player photographs 4 unique anomalies with best scores [0.72, 0.45, 0.38, 0.61], **WHEN** `get_night_evidence_score()` is called, **THEN** it returns 2.16/6 = 0.36 (Night Grade C).

14. **GIVEN** the player submits 0 photos for the night, **WHEN** Evidence Submission queries `get_night_evidence_score()`, **THEN** it returns 0.0 (Night Grade F).

15. **GIVEN** the player photographs 2 of 12 anomalies with perfect A-grade scores, **WHEN** `get_night_evidence_score()` is called, **THEN** it returns (0.80+0.80)/12 = 0.133 (Night Grade F) — comprehensive coverage is required for a high night grade.

### Anomaly Lock

16. **GIVEN** the viewfinder is active and an anomaly has photo_score ≥ 0.30, **WHEN** the anomaly is centered in frame, **THEN** `anomaly_locked_changed(true, anomaly)` fires and the viewfinder corner brackets change to Unnatural White `#F0F0FF`.

17. **GIVEN** anomaly lock is active, **WHEN** the player pans away until photo_score drops below 0.30, **THEN** `anomaly_locked_changed(false, null)` fires and corner brackets return to `#D4C8A0` with no fade transition.

### Photo Preview

18. **GIVEN** a photo is captured, **WHEN** PHOTO_PREVIEW state activates, **THEN** the viewfinder shows the captured Image (not live feed) for 1.5s (±0.1s), the grade stamp appears at t=0.3s, and the player can still move at 1.5 m/s.

19. **GIVEN** the player is in PHOTO_PREVIEW, **WHEN** RMB is released, **THEN** the preview cancels immediately, the viewfinder deactivates, and the photo remains stored.

20. **GIVEN** the player is in PHOTO_PREVIEW, **WHEN** LMB is pressed, **THEN** nothing happens (shutter blocked during preview).

### Film Budget

21. **GIVEN** Night 5 is starting, **WHEN** `night_loading_started(5)` fires, **THEN** `film_remaining` is set to 8 (per FILM_TABLE[5]).

22. **GIVEN** the player dies mid-night with 3 film remaining and 5 photos taken, **WHEN** the night restarts, **THEN** `film_remaining` resets to the night's full budget and `photos_this_night` is cleared.

### Flash and Monsters

23. **GIVEN** a Doll monster is 6m away with line-of-sight, **WHEN** the flash fires, **THEN** `flash_fired_at_monster(doll_instance, 6.0)` emits and Monster AI can process its flash reaction.

24. **GIVEN** a Shadow monster is 8m away but behind a wall (no line-of-sight), **WHEN** the flash fires, **THEN** `flash_fired_at_monster` does NOT emit for that monster.

### Night 7

25. **GIVEN** Night 7 FINALE phase is active (boss escape sequence), **WHEN** the player presses RMB, **THEN** the camera does NOT raise and Photography remains INACTIVE.

### Performance

26. **GIVEN** a room with 8 active anomalies, **WHEN** the viewfinder is active and `evaluate_photo()` runs every physics frame for anomaly lock, **THEN** the frame budget impact is < 1.0ms (verified via profiler).

## Open Questions

1. **Should the player be able to photograph the boss during Night 7 escape?** The game concept mentions this as a potential secret ending / achievement. If yes, what is the boss's AnomalyDefinition? Is the boss a special monster archetype? (Deferred to Night 7 Finale system design.)

2. **Should photo quality affect pay amount, or only the night evidence grade?** Currently, Evidence Submission uses the night grade to determine boss tone and pay. A direct pay-per-photo-quality model (e.g., A-grade photo = $50, F-grade = $0) would add granularity but complexity. (Deferred to Evidence Submission GDD.)

3. **Should the Photo Gallery allow the player to delete photos before submission?** The current design stores all photos and lets Evidence Submission grade them. If the player can curate before submission, they could hide F-grade photos to improve their night grade. This changes the night evidence scoring formula. (Deferred to Photo Gallery GDD.)

4. **Should the SubViewport photo capture include HUD elements (viewfinder frame, grade)?** Currently specified as a raw scene render (no HUD overlay in the captured image). Including the viewfinder frame would make photos feel more "found footage" but adds rendering complexity. (Decision: raw scene render for MVP. Viewfinder overlay is a polish feature.)

5. **Should flash charge carry over between camera raise/lower?** Currently it does (flash recharges in background even when camera is lowered). Alternative: flash resets to 0 when camera is lowered, creating a penalty for lowering and re-raising. (Decision: charge persists — penalizing camera lowering would discourage the player from ever lowering the camera, which breaks the raise/lower tension.)

6. **Should zoom level persist between camera raise/lower?** Currently it resets to 1.0x when camera is lowered. Alternative: remember the last zoom level. (Decision: reset to 1.0x — the player should start each camera raise with the widest view to orient before zooming in. Persisting zoom would cause disorientation.)

7. **What is the SubViewport render budget for web export?** At 480×270, each photo is ~520KB uncompressed (RGBA). 12 photos = ~6.2 MB. This is within the 512 MB memory ceiling, but 12 Images retained in memory may need conversion to a compressed format (WebP or JPEG) for the Photo Gallery. (Deferred to implementation — profile on web target.)
