# Story 003: Audio Detection

> **Epic**: Monster AI
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Core Mechanics section)
**Requirement**: `TR-MON-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Audio)
**ADR Decision Summary**: Audio detection zones use Area3D with audio monitoring. Player movement generates audio events routed through AudioManager. Monster listens via audio zone signals.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Signal-based perception events — `audio_detected`, `audio_lost`. No signal chains.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Audio detection range and sensitivity in MonsterConfig resource.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Area3D with audio monitoring for detection zones. AudioManager singleton for audio event routing. Godot 4.5+ audio API changes possible — verify via docs. Web: max 8 concurrent decoders.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

**Control Manifest Rules (Foundation layer)**:
- Required: All audio routes through AudioManager (no direct AudioStreamPlayer creation)

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md`, scoped to this story:*

- [ ] AC-MON-09: GIVEN the monster has an audio detection zone, WHEN the player generates movement audio (walking, running) within the detection range, THEN the monster detects the audio source position and updates its perception.

- [ ] AC-MON-10: GIVEN the player is moving at different speeds, WHEN the audio detection triggers, THEN the detection range scales with movement intensity (walking = short range, running = longer range).

- [ ] AC-MON-11: GIVEN the monster detects audio from the player, WHEN the player stops moving for `audio_lost_timeout` seconds, THEN the audio detection fades and the monster transitions based on its current state.

---

## Implementation Notes

*Derived from ADR-0009 Audio:*

```gdscript
# Audio detection zone:
# Area3D attached to monster, omnidirectional sphere
# detection_radius from MonsterConfig: `audio_detection_radius` (default 8.0 meters)
# audio_sensitivity from MonsterConfig: `audio_sensitivity` (default 1.0, multiplier)

# Player movement audio events:
# When player velocity > 0.05 m/s → emit audio_event("footstep") at player position
# When player velocity > walk_speed → emit audio_event("running") at player position
# Audio event includes: source_position, intensity (0.0-1.0), type
# AudioManager routes audio events to listening systems
```

*Audio detection implementation:*

```gdscript
# Monster audio listener
var audio_zone := Area3D.new()
audio_zone.collision_shape = SphereShape3D.new()
audio_zone.radius = audio_detection_radius

func _on_audio_event_received(event: Dictionary) -> void:
    var distance := global_position.distance_to(event.source_position)
    if distance <= audio_detection_radius:
        var intensity := event.intensity * audio_sensitivity
        # Scale detection range by intensity
        var effective_range := audio_detection_radius * (0.5 + intensity * 0.5)
        if distance <= effective_range:
            audio_detected.emit(event.source_position, intensity, event.type)

# Movement intensity mapping:
# Walking (0.05 - 1.5 m/s): intensity = 0.3, effective range = ~65% of max
# Running (1.5+ m/s): intensity = 1.0, effective range = 100% of max
# Stationary: no audio event emitted
```

*Audio detection fade:*

```gdscript
# Audio detection doesn't disappear instantly when player stops
# Fade out over audio_lost_timeout (from MonsterConfig, default 3.0 seconds)
var audio_timer := 0.0
const AUDIO_LOST_TIMEOUT := 3.0

func _physics_process(delta: float) -> void:
    if not audio_source_active:
        audio_timer += delta
        if audio_timer >= AUDIO_LOST_TIMEOUT:
            audio_lost.emit()
            audio_timer = 0.0
    else:
        audio_timer = 0.0
```

*Derived from ADR-0003 Communication:*

- Emit `audio_detected(position: Vector3, intensity: float, type: StringName)` on audio detection
- Emit `audio_lost()` when audio fades out
- Do NOT chain signals — state machine subscribes directly

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine (consumes audio signals)
- [Story 002]: Vision cone (separate detection modality)
- [Story 004]: MonsterConfig (provides audio parameters)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-MON-09**: Audio detection triggers
  - Given: Monster at (0,1,0), player at (5,0,0) running, `audio_detection_radius = 8.0`
  - When: Player generates running audio event
  - Then: `audio_detected` fires with position, intensity = 1.0, type = "running"
  - Edge cases: player at edge of detection radius → detection at threshold; player outside radius → no detection; monster at same position as player → intensity = 1.0

- **AC-MON-10**: Detection range scales with movement
  - Given: `audio_detection_radius = 8.0`, `audio_sensitivity = 1.0`
  - When: Player walks (intensity 0.3) → effective range = 8.0 * (0.5 + 0.3*0.5) = 6.8m
  - Then: Player must be within 6.8m to be detected; if player runs (intensity 1.0) → effective range = 8.0m
  - Edge cases: sensitivity = 0 → no audio detection; sensitivity = 2.0 → effective range = 12m; intensity = 0 → effective range = 4m (minimum)

- **AC-MON-11**: Audio detection fades
  - Given: Player detected via audio, then stops moving
  - When: `audio_lost_timeout` (3.0s) elapses without new audio events
  - Then: `audio_lost` fires; monster stops tracking player position
  - Edge cases: player moves again before timeout → timer resets; monster in CHASE state → audio_lost doesn't change state (already chasing); monster in INVESTIGATE → audio_lost may trigger PATROL transition

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/monster_ai/audio_detection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (state machine needs audio signals), Audio System must be DONE (AudioManager routing)
- Unlocks: Monster AI epic (audio detection enables stealth gameplay), Player Survival (audio detection makes staying quiet meaningful)
