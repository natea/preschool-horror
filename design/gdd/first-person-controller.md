# First-Person Controller

> **Status**: Designed
> **Author**: Nate Aune + agents
> **Last Updated**: 2026-04-09
> **Implements Pillar**: All (infrastructure) — primarily "Something's Wrong Here" (enables exploration) and "Prove It" (enables camera interaction)

## Overview

The First-Person Controller is the foundational movement and input system for Show & Tell. It handles WASD movement, mouse-look, collision with the preschool environment, and interaction raycasting (for doors, vents, and triggering the camera). It provides the spatial position, facing direction, and movement state that 7 downstream systems depend on — including Photography, Monster AI, Player Survival, and HUD/UI. The player interacts with it constantly but should never think about it; the controller is invisible infrastructure that makes the preschool feel like a real place you're walking through. It does not handle the camera viewfinder (Photography System) or the vulnerability bar (Player Survival) — it provides the inputs those systems consume.

## Player Fantasy

**"Too Big for This Place."** The player is an adult trespassing in a world built for children. Every doorframe forces you to notice its height. Every hallway is a little too narrow. The furniture crowds your legs. Moving through the preschool isn't just navigation — it's a constant, low-grade reminder that you do not belong here. The space was not designed for you, and the longer you stay, the more it feels like the space knows that too.

This is an indirect fantasy — the player never thinks about the controller. They think "this hallway feels wrong and I don't want to keep walking but I have to." The controller's job is to make the space feel real, the player feel present, and the wrongness feel physical. Your body is the first thing that's wrong in this building. Everything else comes after.

*Serves Pillar 1: "Something's Wrong Here" — the player-scale mismatch creates unease before any anomaly appears.*

## Detailed Design

### Core Rules

#### Movement

- **Walk speed (SPEED_WALK):** 2.0 m/s. Slow enough to read the room, fast enough to not feel stuck. At child-scale architecture (85% of standard), 2.0 m/s feels like a careful adult trying not to knock things over.
- **Run speed (SPEED_RUN):** 4.0 m/s. A desperate shuffle, not a sprint. Slightly above average human jogging pace (~3.5 m/s) but capped to prevent the player from feeling powerful. Running raises Monster AI audio detection radius from 5.0 m to 10.0 m (value owned by Monster AI GDD; controller only emits `is_running`).
- **Run duration cap:** None. The cost of running is noise, not stamina.
- **Acceleration / deceleration:** Instant. No momentum curves. Makes the player feel heavier and more deliberate in cluttered spaces. Also reduces per-frame physics cost for web export.
- **No jump, no crouch.** Single-floor preschool. Vents have their own enter/exit mechanic.
- **Collision:** CharacterBody3D with capsule collider (height: 1.75 m, radius: 0.25 m). Child-scaled doorframes are ~1.85 m — player clears with 10 cm margin. Intentional mild friction that reinforces "Too Big for This Place."

#### Mouse-Look

- **Default sensitivity (MOUSE_SENS_DEFAULT):** 0.002 rad/pixel. Tunable via settings menu.
- **Pitch clamp:** −80° to +80°. No tilt, no roll.
- **Mouse capture:** Captured on game start. Released on pause/menu/cutscene/death. Web export: recapture requires a click (browser security model).
- **Gamepad look:** Right stick, 2.5 rad/s at full deflection (GAMEPAD_LOOK_SENS). No aim assist.

#### Interaction Raycast

- **Ray origin:** Camera center (eye position, not camera lens when raised).
- **Ray length (INTERACT_RAY_LEN):** 2.0 m. Requires deliberate positioning in child-scaled rooms.
- **Targets:**

| Target Type | Layer | On Interact |
|---|---|---|
| Door | `interactable` | Toggle open/closed, emit signal to Audio System |
| Vent cover | `interactable` | Trigger vent-enter sequence (Vent System) |
| Anomaly object | `interactable` | Emit `anomaly_touched` signal |
| Nothing | — | No UI prompt shown |

- **Input:** E key / Gamepad A button. Single press, no hold.

#### Camera Raise / Lower

- **Input:** RMB (hold) / Gamepad LT (hold). Not a toggle — requires sustained hold so the player cannot raise-and-forget while running.
- **Height offset:** +0.08 m from default eye position. Subtle visual state cue.
- **Raised state:** Transfers viewfinder authority to Photography System. Mouse-look continues. Photography System overlays viewfinder HUD and processes LMB/RT for shutter.
- **The controller does NOT handle zoom, flash, or photo evaluation.** It only emits `camera_raised: bool`.

### States and Transitions

| State | Movement | Mouse-Look | Interact | Camera Raise | Notes |
|---|---|---|---|---|---|
| **Normal** | 2.0 m/s | Yes | Yes | Yes | Default state |
| **Camera Raised** | 1.5 m/s | Yes | No | Held | Photography System active |
| **Running** | 4.0 m/s | Yes | No | No | Shift blocks interact and camera |
| **In Vent** | 0.0 m/s | No | No | No | Vent System owns movement |
| **Hiding** | 0.0 m/s | Limited (±45° from hide direction) | Exit only | No | |
| **Cutscene** | 0.0 m/s | No | No | No | Night 7 boss reveal |
| **Dead** | 0.0 m/s | No | No | No | Fade to black, death audio |
| **Restarting** | 0.0 m/s | No | No | No | Scene reload in progress |

**Transition Rules:**
- Normal → Camera Raised: RMB held AND `is_running == false`
- Camera Raised → Normal: RMB released (always immediate)
- Normal → Running: Shift held (auto-lowers camera if raised)
- Running → Normal: Shift released
- Normal/Running → In Vent: E pressed AND raycast hits vent AND Vent System accepts
- Any (except Dead/Cutscene) → Dead: Monster AI emits `player_killed`
- Dead → Restarting: Death animation completes (2.0 s fixed)
- Normal → Cutscene: Night 7 boss trigger fires
- Cutscene → Normal: Cutscene ends (Night 7 escape phase begins)

**Illegal transitions (must be guarded):** Camera Raised while Running; Interact while Running; Vent entry while Camera Raised; Dead while in Cutscene.

### Interactions with Other Systems

#### Outputs (what this system provides)

| Signal / Property | Type | To System | When |
|---|---|---|---|
| `player_position` | Vector3 | Monster AI, Audio | Every physics frame |
| `player_facing` | Vector3 | Monster AI, Photography | Every physics frame |
| `is_running` | bool | Monster AI, Audio, Player Survival | On change |
| `is_moving` | bool | Player Survival, Audio | On change (velocity > 0.05 m/s) |
| `is_stationary` | bool | Player Survival | On change (velocity < 0.05 m/s for > 0.5 s) |
| `camera_raised` | bool | Photography, HUD | On change |
| `current_state` | enum | HUD, Audio, Player Survival | On state transition |
| `interact_ray_hit` | RaycastResult | HUD (show prompt), Vent System | Every frame |
| `interact_pressed` | signal | Vent System, anomaly objects | On E key press |

**Stationary threshold:** 0.5 s debounce prevents the vulnerability bar from flickering during micro-adjustments while photographing.

#### Inputs (what this system receives)

| Signal / Property | Type | From System | Effect |
|---|---|---|---|
| `player_killed` | signal | Monster AI | → Dead state |
| `vent_entry_complete` | signal | Vent System | → In Vent state |
| `vent_exit_complete` | signal | Vent System | → Normal state |
| `cutscene_start` | signal | Night Manager | → Cutscene state |
| `cutscene_end` | signal | Night Manager | → Normal state |
| `hide_spot_entered` | signal | Hiding System | → Hiding state |
| `hide_spot_exited` | signal | Hiding System | → Normal state |

## Formulas

### Movement Speed Selection

`SPEED_CURRENT = SPEED_BASE * SPEED_MODIFIER`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| SPEED_BASE | SPEED_BASE | float | {2.0, 4.0} | Walk or run speed in m/s, selected by is_running |
| SPEED_MODIFIER | SPEED_MODIFIER | float | 0.0 – 1.0 | State-based: Normal=1.0, Camera Raised=0.75, In Vent/Hiding/Cutscene/Dead=0.0 |
| SPEED_CURRENT | SPEED_CURRENT | float | 0.0 – 4.0 | Velocity magnitude applied to CharacterBody3D |

**Output Range:** [0.0, 4.0] m/s. Clamped — prevents overspeed bugs if modifiers are chained.

**Example — walking while camera raised:**
- SPEED_BASE = 2.0 (walking)
- SPEED_MODIFIER = 0.75 (Camera Raised)
- SPEED_CURRENT = 2.0 × 0.75 = **1.5 m/s**

Raising the camera slows you down. You become a near-stationary target, feeding the vulnerability loop.

## Edge Cases

- **If player releases RMB mid-run initiation:** Shift pressed same frame RMB released → go to Running, not Normal. Running takes priority.
- **If vent entry triggered while camera raised:** Guard: camera must lower before vent sequence. Auto-lower camera, then hand to Vent System.
- **If monster kills player in Hiding state:** Allowed. Hiding is not guaranteed safe — if monster detection radius overlaps a hiding spot, `player_killed` fires normally.
- **If web browser loses focus mid-session:** Mouse uncaptured automatically. On refocus, re-request capture on next `_input` event. Discard first frame's mouse delta (garbage value from cursor travel).
- **If player velocity exactly equals stationary threshold (0.05 m/s):** Counts as moving. `is_stationary` requires strictly less than 0.05 m/s. Prevents float-equality edge case.
- **If gamepad and keyboard input arrive simultaneously:** Take the max of both inputs per axis each frame. Do not suppress either.
- **If Night 7 cutscene fires while player is in a vent:** Cutscene state overrides. Vent System handles abrupt authority handoff — teleport player to scripted cutscene position outside the vent.

## Dependencies

| System | Direction | Interface |
|---|---|---|
| Photography System | Controller → Photography | `camera_raised`, `player_facing`, `player_position` |
| Monster AI | Controller → Monster AI | `player_position`, `player_facing`, `is_running` |
| Player Survival | Controller → Survival | `is_stationary`, `is_moving`, `current_state` |
| HUD/UI | Controller → HUD | `current_state`, `interact_ray_hit`, `camera_raised` |
| Vent System | Bidirectional | Controller → `interact_pressed`; Vents → `vent_entry_complete`, `vent_exit_complete` |
| Audio System | Controller → Audio | `player_position`, `is_running`, `is_moving`, `current_state` |
| Night Manager | Night Manager → Controller | `cutscene_start`, `cutscene_end` |

All dependencies are soft except Photography System and Monster AI (the game cannot function if these cannot read player position and state).

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Impact |
|---|---|---|---|
| SPEED_WALK | 2.0 m/s | 1.5 – 2.5 | Lower = more dread, higher = less tension in small rooms |
| SPEED_RUN | 4.0 m/s | 3.5 – 5.0 | Lower = more desperate, higher = more action-y. Do not exceed 5.0 — player outruns monsters |
| SPEED_MODIFIER_CAMERA | 0.75 | 0.5 – 1.0 | 0.5 = nearly pinned while photographing; 1.0 = no penalty |
| MOUSE_SENS_DEFAULT | 0.002 rad/px | Player-adjustable | Feel only — expose in settings menu |
| GAMEPAD_LOOK_SENS | 2.5 rad/s | 1.5 – 4.0 | Feel only |
| INTERACT_RAY_LEN | 2.0 m | 1.5 – 2.5 | Longer = more forgiving; shorter = more deliberate |
| STATIONARY_THRESHOLD | 0.05 m/s | 0.01 – 0.15 | Tighter = vulnerability reacts faster to near-stillness |
| STATIONARY_DEBOUNCE | 0.5 s | 0.2 – 1.0 | Lower = more reactive to micro-pauses; higher = more grace |
| CAPSULE_HEIGHT | 1.75 m | Fixed | Tied to architecture scale contract — do not tune |
| CAPSULE_RADIUS | 0.25 m | Fixed | Determines doorframe clearance — do not tune |

## Acceptance Criteria

- **GIVEN** a measured 10m corridor, **WHEN** the player walks forward, **THEN** traversal completes in 5.0s ± 0.1s (validates SPEED_WALK = 2.0 m/s).
- **GIVEN** a measured 10m corridor, **WHEN** the player runs forward, **THEN** traversal completes in 2.5s ± 0.1s (validates SPEED_RUN = 4.0 m/s).
- **GIVEN** the player is walking, **WHEN** RMB is held, **THEN** traversal of 10m completes in 6.7s ± 0.1s (validates camera raise slowdown to 1.5 m/s).
- **GIVEN** the player faces a door at 2.0m, **WHEN** looking directly at it, **THEN** the interaction prompt appears. Moving to 2.1m hides it.
- **GIVEN** the player is running (Shift held), **WHEN** RMB or E is pressed, **THEN** nothing happens (running blocks camera raise and interact).
- **GIVEN** the player stops moving, **WHEN** 0.5s elapses with zero input, **THEN** `is_stationary` signal fires to Player Survival.
- **GIVEN** a web build loses browser focus, **WHEN** the player clicks back into the game, **THEN** mouse is recaptured with no delta spike (no camera jerk).
- **GIVEN** the player is in Dead state, **WHEN** `player_killed` fires again, **THEN** no state change occurs (Dead cannot be re-entered).
- **GIVEN** Night 7 cutscene is active, **WHEN** any input is pressed (WASD, mouse, E, RMB), **THEN** no effect on player state or position.
- **GIVEN** a child-scale doorframe (1.85m), **WHEN** the player walks through, **THEN** no collision catch occurs (capsule clears with margin).

## Open Questions

- Should footstep audio change based on floor surface type (linoleum vs carpet vs playground)? (Deferred to Audio System GDD)
- Should the player cast a visible shadow? The art bible notes the boss's shadow is hand-authored — should the player's shadow also be a design element?
- Should hiding spots be environmental objects (under desks, inside cubbies) or dedicated hiding zones? (Deferred to Level Design)
- Should run speed decrease on later nights (fatigue from repeated visits) or stay constant?
