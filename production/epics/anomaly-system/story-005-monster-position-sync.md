# Story 005: Monster Position Sync

> **Epic**: Anomaly System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/anomaly-system.md` (Monster Anomaly States, Interactions with Other Systems sections)
**Requirement**: `TR-AS-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `monster_state_changed` and `monster_position_updated` signals from Monster AI. Anomaly System updates tracking state; does not control monster behavior.

**ADR Governing Implementation**: ADR-0002 (Physics)
**ADR Decision Summary**: Detection area position follows monster world position. Occlusion raycast uses updated position.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Bidirectional signal subscription between Anomaly System and Monster AI. Detection area (Area3D) position update on every monster movement. Photo detection must use latest position. Fallback: monster as static scene when Monster AI not loaded.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/anomaly-system.md`, scoped to this story:*

- [ ] AC-AS-14: GIVEN a monster instance at spawn position, WHEN Monster AI calls `monster_position_updated(instance, new_pos)`, THEN `instance.detection_area.global_position` matches `new_pos` and subsequent `evaluate_photo()` calls use the updated position.

- [ ] AC-AS-15: GIVEN Monster AI is not loaded, WHEN a monster manifest entry is instantiated, THEN the monster exists as a static scene at its spawn point, is photographable via `evaluate_photo()`, and a warning is logged.

---

## Implementation Notes

*Derived from ADR-0003 Communication:*

```gdscript
# Monster AI signals that Anomaly System subscribes to:

func _on_monster_state_changed(instance: Node, new_state: StringName) -> void:
    if active_anomalies.has(instance.definition.anomaly_id):
        var ai := active_anomalies[instance.definition.anomaly_id]
        ai.state = new_state
        # Photo detection will skip non-ACTIVE states (PURSUING, ATTACKING handled separately)

func _on_monster_position_updated(instance: Node, new_pos: Vector3) -> void:
    if active_anomalies.has(instance.definition.anomaly_id):
        var ai := active_anomalies[instance.definition.anomaly_id]
        ai.detection_area.global_position = new_pos
        # Photo detection uses detection_area position for distance and occlusion checks
```

*Monster as static fallback (no Monster AI):*

```gdscript
# During instantiation, if Monster AI is not available:
if definition.anomaly_type == &"monster" and not MonsterAI.is_available():
    # Monster stays at spawn point — no movement
    # Still photographable via evaluate_photo()
    # Detection area remains at spawn position
    push_warning("Monster AI not loaded — monster %s is static at spawn" % definition.anomaly_id)
    # Set state to ACTIVE (not DORMANT) — monster visible immediately
    instance.state = &"ACTIVE"
```

*Position update frequency:*
- Monster AI calls `monster_position_updated` each physics frame (or on significant position change)
- Detection area position is authoritative for photo detection
- No interpolation — position is set directly from Monster AI

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Monster instantiation (creates the instance that gets updated)
- [Story 001]: AnomalyDefinition (provides monster archetype data)
- Monster AI: movement logic, behavior tree (controls the monster, not the Anomaly System)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AS-14**: Position sync
  - Given: Monster instance at spawn (0, 1, 0), Monster AI moves monster to (5, 1, 3)
  - When: `monster_position_updated(instance, Vector3(5, 1, 3))` fires
  - Then: `detection_area.global_position = (5, 1, 3)`; subsequent `evaluate_photo()` uses new position for distance, frustum, and occlusion checks
  - Edge cases: position changes mid-frame → photo detection uses latest position; position changes faster than photo evaluation → detection may show inconsistent results (acceptable — photo evaluation is instantaneous at shutter time); monster moves behind wall → occlusion check correctly fails

- **AC-AS-15**: Static monster fallback
  - Given: Monster manifest entry instantiated with no Monster AI loaded
  - When: Monster instance exists
  - Then: Monster at spawn position; `evaluate_photo()` returns valid detection result (monster is photographable); warning logged in output
  - Edge cases: Monster AI loads later → monster becomes dynamic; static monster has state = ACTIVE (not DORMANT); `get_monsters()` still returns the instance

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/anomaly_system/monster_position_sync_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 must be DONE (monster instances must exist), Monster AI epic must be DONE (provides position updates)
- Unlocks: Photography System (photo detection uses updated monster positions), Audio System (proximity audio follows monster position)
