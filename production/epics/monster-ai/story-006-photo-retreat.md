# Story 006: Photo Mode Retreat

> **Epic**: Monster AI
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Core Mechanics section)
**Requirement**: `TR-MON-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Signal-based perception events — `photo_mode_active`, `photo_mode_deactivated`. Monster subscribes to photography system signals.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Retreat behavior per-archetype via MonsterConfig `retreat_on_photo` flag and `retreat_speed` parameter.

**ADR Governing Implementation**: ADR-0009 (Audio)
**ADR Decision Summary**: Camera flash sound routed through AudioManager SFXBus. Monster retreat triggered by photo capture event.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Cross-system signal subscription (Photography → Monster AI). No signal chains — direct subscription. Retreat = state transition to RETREAT + path to base position. Post-cutoff API changes for signals in Godot 4.5/4.6 possible — verify via docs.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md`, scoped to this story:*

- [ ] AC-MON-17: GIVEN the player activates photo mode and captures a clear photo of a monster, WHEN the photo is confirmed (anomaly in frame, head-on, clear), THEN monsters with `retreat_on_photo = true` in their MonsterConfig transition to RETREAT state and move away from the player.

- [ ] AC-MON-18: GIVEN the monster is retreating, WHEN the player deactivates photo mode, THEN the monster stops retreating and returns to its previous state (per state machine rules).

- [ ] AC-MON-19: GIVEN a monster with `retreat_on_photo = false` (Dolls), WHEN the player photographs it, THEN the monster does NOT retreat and may instead transition to CHASE.

---

## Implementation Notes

*Derived from ADR-0003 Communication:*

```gdscript
# Monster subscribes directly to Photography system signals:
# photography.photo_confirmed(anomaly: Node3D, clarity: float)
# photography.photo_mode_toggled(active: bool)

# On photo_confirmed:
func _on_photo_confirmed(anomaly: Node3D, clarity: float) -> void:
    if not anomaly.is_in_group("monster_anomaly"):
        return
    if clarity < photo_retreat_threshold:  # from MonsterConfig
        return
    if not monster_config.retreat_on_photo:
        return
    # Trigger retreat
    retreat_to_base()
```

*Retreat behavior:*

```gdscript
func retreat_to_base() -> void:
    current_state = State.RETREAT
    # Path to base/last safe position (from MonsterConfig: `retreat_target` or home position)
    retreat_speed := monster_config.retreat_speed * 1.5  # retreat is faster than normal
    # During retreat: vision cone disabled (monster "fleeing")
    # Audio detection reduced (monster "panicked")
    retreating = true
    retreat_start_position = global_position

func stop_retreat() -> void:
    retreating = false
    current_state = State.PATROL  # or previous state per state machine
    # Restore normal vision/audio parameters
```

*Retreat parameters (from MonsterConfig):*

```gdscript
# MonsterConfig additions:
#   retreat_speed: float (multiplier, default 1.5x normal speed)
#   retreat_target: Vector3 (home position, default = first patrol waypoint)
#   retreat_min_duration: float (minimum retreat time, default 5.0 seconds)
#   photo_retreat_threshold: float (minimum photo clarity for retreat, default 0.7)
```

*Derived from ADR-0009 Audio:*

- Photo capture sound: `SFXManager.play_sfx("camera_shutter")` — routed through SFXBus
- Monster retreat sound: `SFXManager.play_sfx("monster_retreat")` — per-archetype variant
- All audio preloaded via `preload()`

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine (manages retreat state)
- [Story 005]: Pathfinding (retreat uses pathfinding to base)
- Photography System: photo capture logic (this consumes the signal)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-MON-17**: Monster retreats on photo
  - Given: Shadow monster (retreat_on_photo = true) in CHASE state, player takes clear photo (clarity = 0.9)
  - When: Photo confirmed via `photo_confirmed` signal
  - Then: State transitions to RETREAT; monster moves away from player toward base; retreat_speed = chase_speed * 1.5
  - Edge cases: photo clarity = 0.5 (below threshold) → no retreat; monster already at base → retreat ends immediately; multiple monsters photographed → each retreats independently

- **AC-MON-18**: Retreat ends on photo mode deactivate
  - Given: Monster in RETREAT state, player deactivates photo mode
  - When: `photo_mode_deactivated` signal fires
  - Then: Monster stops retreating; state transitions per state machine (typically PATROL); normal behavior resumes
  - Edge cases: photo mode deactivated before retreat_min_duration → monster completes minimum retreat then returns; monster detected by player during retreat → may transition to CHASE (depends on state machine rules)

- **AC-MON-19**: Dolls don't retreat
  - Given: Doll monster (retreat_on_photo = false) in any state, player takes clear photo
  - When: Photo confirmed
  - Then: State does NOT change to RETREAT; Doll may transition to CHASE (per its aggression settings)
  - Edge cases: Doll in PATROL → may transition to CHASE on photo; Doll in ATTACK → no change; Doll with aggression = 0.0 → may not chase (stays in current state)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/monster_ai/photo_retreat_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (state machine has RETREAT state), Story 004 must be DONE (MonsterConfig has retreat parameters), Photography System must be DONE (photo confirmation signals)
- Unlocks: Monster AI epic (retreat is key player interaction with monsters), Photography System (photo mechanic has meaningful consequence)
