# Story 006: Night Lifecycle Cleanup

> **Epic**: Anomaly System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/anomaly-system.md` (Night Lifecycle — End of Night section)
**Requirement**: `TR-AS-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `night_ended` signal triggers cleanup. `anomalies_cleared` emitted after clearing. No signal chains — Anomaly System reacts, doesn't forward.

**ADR Governing Implementation**: ADR-0001 (Scene Architecture)
**ADR Decision Summary**: All anomalies in single scene — cleanup must free all children of room anomaly containers. No streaming to reload.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Night transition is a scene unload/reload. Anomaly System must clear all active state before the scene unloads. Anchor anomalies (is_anchor = true) persist across nights — track which instances to keep.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/anomaly-system.md`, scoped to this story:*

- [ ] AC-AS-16: GIVEN a night with N active anomalies across all rooms, WHEN `night_ended` fires, THEN all non-anchor anomaly instances are freed, `active_anomalies` is cleared, and `anomalies_cleared` is emitted.

- [ ] AC-AS-17: GIVEN an anchor anomaly (is_anchor = true) from the previous night, WHEN a new night begins and the manifest includes a matching anomaly_id, THEN the existing instance is reused (not re-instantiated) and its state is reset to DORMANT.

- [ ] AC-AS-18: GIVEN a night transition with no previous anomalies (first night), WHEN `night_ended` fires, THEN no errors occur and cleanup is a no-op.

- [ ] AC-AS-19: GIVEN a monster instance from the previous night, WHEN the night ends, THEN the monster is freed regardless of is_anchor (monsters do not persist across nights).

---

## Implementation Notes

*Derived from ADR-0003 Communication + ADR-0001 Scene Architecture:*

```gdscript
# Night lifecycle: cleanup on night end
func _on_night_ended() -> void:
    # 1. Free all non-anchor anomalies
    var to_keep := []
    for anomaly_id in active_anomalies.keys():
        var instance_data := active_anomalies[anomaly_id]
        if instance_data.definition.is_anchor:
            to_keep.append(anomaly_id)
        else:
            if is_instance_valid(instance_data.instance):
                instance_data.instance.queue_free()

    # 2. Clear active_anomalies (anchors handled separately)
    active_anomalies.clear()

    # 3. Reconcile anchors: reset and keep
    for anomaly_id in to_keep:
        var instance_data := _get_anchor_instance(anomaly_id)
        if instance_data != null:
            instance_data.state = &"DORMANT"
            instance_data.activate_delay = 0.0
            # Keep in a separate anchor tracking dict
            anchor_instances[anomaly_id] = instance_data

    # 4. Emit cleanup signal
    anomalies_cleared.emit()

# Night lifecycle: instantiation with anchor reconciliation
func _on_placement_manifest_ready(night: int) -> void:
    var manifest := AnomalyPlacementEngine.get_manifest()
    if manifest == null:
        return

    var success_count := 0
    for entry in manifest.entries:
        # Check if anchor exists
        if anchor_instances.has(entry.anomaly_id):
            var anchor := anchor_instances[entry.anomaly_id]
            # Reuse: move to new room, reset state
            _reuse_anchor(anchor, entry)
            active_anomalies[entry.anomaly_id] = anchor
            continue  # Skip instantiation

        # Normal instantiation (same as story-002 logic)
        # ... [same code as story-002] ...
        success_count += 1

    anomalies_instantiated.emit(night, success_count)

func _reuse_anchor(anchor: AnomalyInstance, placement: PlacementEntry) -> void:
    # Move to new spawn point
    var room_data := RoomManager.get_room_data(placement.room_id)
    if room_data == null:
        push_error("No RoomData for %s during anchor reuse" % placement.room_id)
        return

    var spawn_pos := room_data.spawn_points[placement.spawn_point_index]
    anchor.instance.global_position = spawn_pos
    anchor.state = &"DORMANT"
    anchor.room_id = placement.room_id
    anchor.placement = placement
    # Visibility reset handled by _activate() on next room entry
```

*Anchor anomaly reuse rules:*
- Anchor anomalies persist in `anchor_instances` dict between nights
- On next night's manifest consumption, check `anchor_instances` before instantiating
- If anchor exists: move to new spawn, reset to DORMANT, add to `active_anomalies`
- If anchor does NOT exist (manifest removed it): leave in `anchor_instances`, don't clean up
- Monsters NEVER persist (is_anchor always false for monsters)

*Anchor cleanup on game quit:*
- No special handling needed — `queue_free()` on all instances at app exit
- Anchor instances are just regular nodes at that point

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Manifest instantiation (creates the instances that get cleaned up)
- [Story 003]: Activation lifecycle (DORMANT reset is part of reuse, not activation)
- Night Progression: night transition timing (this handles the Anomaly System side only)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AS-16**: Full cleanup on night end
  - Given: Night with 5 active anomalies across 3 rooms, none are anchors
  - When: `night_ended` fires
  - Then: All 5 instances queued for free; `active_anomalies` is empty dict; `anomalies_cleared` emitted once
  - Edge cases: instance already freed (e.g., during playtest) → `is_instance_valid` check prevents error; cleanup during night transition → no dangling references

- **AC-AS-17**: Anchor anomaly reuse
  - Given: Anchor anomaly (is_anchor = true) from night 1, placed in art_corner; night 2 manifest also places an anomaly with same anomaly_id in hallway
  - When: Night 2 instantiation runs
  - Then: Existing instance moved to hallway spawn point; state reset to DORMANT; not re-instantiated (no duplicate); `active_anomalies` has the reused instance
  - Edge cases: anchor in different room night-to-night → moved correctly; anchor's definition unchanged → same photo detection params; anchor instance invalid → fallback to normal instantiation

- **AC-AS-18**: First-night no-op
  - Given: First night of the game, no previous anomalies
  - When: `night_ended` fires
  - Then: `anchor_instances` is empty → no anchors to reconcile; `active_anomalies` cleared; no errors
  - Edge cases: `anchor_instances` never initialized → initialized as empty dict in _ready(); `active_anomalies` already empty → clear() on empty dict is safe

- **AC-AS-19**: Monster never persists
  - Given: Monster instance from previous night (even if is_anchor were somehow true)
  - When: `night_ended` fires
  - Then: Monster freed regardless of is_anchor; not in `anchor_instances`; not reused on next night
  - Edge cases: monster definition has is_anchor = true (data error) → override: monsters always freed; multiple monsters → all freed; monster AI still referencing instance → monster AI should also clean up on `monster_spawned` handler

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/anomaly_system/night_lifecycle_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 must be DONE (instances must exist before they can be cleaned up), Night Progression epic must be DONE (night_ended signal)
- Unlocks: None (cleanup is the final step of the anomaly lifecycle)
