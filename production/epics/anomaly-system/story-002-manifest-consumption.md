# Story 002: Manifest Consumption and Instantiation

> **Epic**: Anomaly System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/anomaly-system.md` (Runtime Instantiation section)
**Requirement**: `TR-AS-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Scene Architecture)
**ADR Decision Summary**: All anomalies in single scene, no streaming. Anomalies spawned as children of room anomaly container nodes.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Signals — `anomalies_instantiated`, `monster_spawned`, `anomalies_cleared`. No signal chains.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: AnomalyDefinition lookup by StringName key from manifest entry.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: PackedScene instantiation via `load()` + `instantiate()`. Room spawn point resolution via RoomManager. Monster handoff via signal emission. Web: instantiate count per night must stay within scene node budget (< 15000 total).

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/anomaly-system.md`, scoped to this story:*

- [ ] AC-AS-01: GIVEN Night Progression triggers LOADING for night `n`, WHEN `placement_manifest_ready(n)` fires, THEN the Anomaly System instantiates one scene per manifest entry, and `anomalies_instantiated(n, count)` is emitted with `count` matching the number of successfully instantiated entries.

- [ ] AC-AS-02: GIVEN a PlacementEntry with `anomaly_id = &"drawing_replaced"` and `room_id = &"art_corner"` and `spawn_point_index = 0`, WHEN instantiation runs, THEN a scene matching the `AnomalyDefinition.scene_path` for `&"drawing_replaced"` exists as a child of art_corner's anomaly container, positioned at `RoomData.spawn_points[0]`.

- [ ] AC-AS-03: GIVEN a PlacementEntry with an `anomaly_id` that has no matching AnomalyDefinition, WHEN instantiation runs, THEN that entry is skipped, an error is logged, and all other entries still instantiate normally.

- [ ] AC-AS-04: GIVEN a manifest with 3 environmental entries and 1 monster entry, WHEN instantiation completes, THEN `monster_spawned` is emitted exactly once, and `get_monsters()` returns an array of length 1.

---

## Implementation Notes

*Derived from ADR-0001 Scene Architecture + ADR-0003 Communication:*

```gdscript
# On placement_manifest_ready(n) signal:
func _on_placement_manifest_ready(night: int) -> void:
    # 1. Clear previous night's instances
    anomalies_cleared.emit()
    _clear_active_anomalies()

    # 2. Read manifest
    var manifest := AnomalyPlacementEngine.get_manifest()
    if manifest == null or manifest.night != night:
        push_error("Invalid manifest for night %d" % night)
        anomalies_instantiated.emit(night, 0)
        return

    # 3. Instantiate each entry
    var success_count := 0
    for entry in manifest.entries:
        var definition := get_definition(entry.anomaly_id)
        if definition == null:
            push_error("No AnomalyDefinition for %s in room %s" % [entry.anomaly_id, entry.room_id])
            continue

        var room_data := RoomManager.get_room_data(entry.room_id)
        if room_data == null:
            push_error("No RoomData for %s" % entry.room_id)
            continue

        var spawn_pos := room_data.spawn_points[entry.spawn_point_index]
        var scene := load(definition.scene_path)
        var instance := scene.instantiate()

        # Parent to room's anomaly container
        var container := _get_anomaly_container(entry.room_id)
        container.add_child(instance)
        instance.global_transform = spawn_pos

        # Initialize instance
        var instance_data := AnomalyInstance.new()
        instance_data.definition = definition
        instance_data.placement = entry
        instance_data.room_id = entry.room_id
        instance_data.state = definition.anomaly_type  # DORMANT for environmental, ACTIVE for monsters
        instance_data.initialize()

        active_anomalies[entry.anomaly_id] = instance_data
        success_count += 1

        # Monster handoff
        if definition.anomaly_type == &"monster":
            monster_spawned.emit(instance_data)

    # 4. Emit completion
    anomalies_instantiated.emit(night, success_count)
```

*Clearing previous night:*

```gdscript
func _clear_active_anomalies() -> void:
    for instance in active_anomalies.values():
        if is_instance_valid(instance):
            instance.queue_free()
    active_anomalies.clear()
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: Activation lifecycle (triggered after instantiation)
- [Story 006]: Night lifecycle cleanup (handles the clearing; this handles instantiation)
- Anomaly Placement Engine: manifest creation (this consumes the manifest)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AS-01**: Manifest triggers full instantiation
  - Given: Manifest for night 3 with 5 entries, `placement_manifest_ready(3)` fires
  - When: Processing completes
  - Then: 5 scenes instantiated; `anomalies_instantiated(3, 5)` emitted; all in active_anomalies dictionary
  - Edge cases: manifest with 0 entries → 0 instantiated, signal emitted with count 0; manifest for wrong night → error logged, count = 0

- **AC-AS-02**: Correct placement at spawn point
  - Given: PlacementEntry for art_corner spawn_point_index = 0, RoomData.spawn_points[0] = Vector3(2.0, 1.0, -3.0)
  - When: Instantiation runs
  - Then: Instance positioned at (2.0, 1.0, -3.0); parent is art_corner's anomaly container; definition matches entry.anomaly_id
  - Edge cases: spawn_point_index out of bounds → skip entry, log error; room has no anomaly container → create one, log warning

- **AC-AS-03**: Missing definition handling
  - Given: Manifest entry with anomaly_id = &"nonexistent_anomaly"
  - When: Instantiation runs
  - Then: Entry skipped, error logged, other entries still instantiate
  - Edge cases: multiple missing definitions → all skipped, count reflects only successes; definition exists but scene_path invalid → skip, log error

- **AC-AS-04**: Monster handoff
  - Given: Manifest with 1 monster entry (archetype = doll)
  - When: Instantiation completes
  - Then: `monster_spawned` emitted once; `get_monsters()` returns array of length 1; monster AI receives signal
  - Edge cases: multiple monsters → each emits monster_spawned; monster in room with no Monster AI → static scene, warning logged

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/anomaly_system/manifest_instantiation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: AnomalyDefinition resource (Story 001) must be DONE, Anomaly Placement Engine must be DONE (produces manifest)
- Unlocks: Story 003 (activation triggered after instantiation), Story 005 (monster position sync needs instances)
