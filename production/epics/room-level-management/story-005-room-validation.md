# Story 005: Room Validation & Queries

> **Epic**: Room/Level Management
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/room-level-management.md`
**Requirement**: `TR-RLM-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Single-Scene Architecture)
**ADR Decision Summary**: RoomManager scene-local node. Room query APIs exposed for downstream systems.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: get_room_spawn_points() returns empty array for LOCKED rooms. RoomData is read-only at runtime.

**ADR Governing Implementation**: ADR-0003 (Signal Communication)
**ADR Decision Summary**: room_unlocked signal emitted when Principal's Office unlocks on Night 7.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: Static typing. System-based directory structure.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Query APIs are read-only methods on RoomManager. No I/O in queries. Adjacency validation in _ready() via debug assertion.

**Control Manifest Rules (Foundation layer)**:
- Required: Static typing on all class members
- Guardrail: All query methods must be non-blocking and O(1) or O(N_rooms)

---

## Acceptance Criteria

*From GDD `design/gdd/room-level-management.md`, scoped to this story:*

- [ ] AC-RLM-11: GIVEN a room with access_state == LOCKED, WHEN get_room_spawn_points() is called, THEN the return value is an empty array regardless of active_spawn_slots.

- [ ] AC-RLM-12: GIVEN the authored RoomData adjacency lists, WHEN RoomManager._ready() runs in debug build, THEN if any room A lists room B as adjacent but B does not list A, an assertion failure is raised.

- [ ] AC-RLM-14: GIVEN Night Progression has connected to room_unlocked, WHEN configure_for_night(7) completes, THEN principals_office.access_state == ACCESSIBLE AND room_unlocked was emitted with &"principals_office" exactly once.

- [ ] AC-RLM-15: GIVEN a scene that has loaded but configure_for_night() has never been called, WHEN get_accessible_rooms() is called, THEN it returns at least entry_hall, main_classroom, and art_corner (Night 1 defaults) — never an empty array.

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

```gdscript
# RoomManager.gd — validation and query APIs

func get_room_spawn_points(room_id: StringName, tag_filter: StringName = "") -> Array[Transform3D]:
    # AC-RLM-11: LOCKED rooms return empty array
    if not rooms.has(room_id):
        return []
    var state: RoomState = rooms[room_id]
    if state.access_state == RoomState.AccessState.LOCKED:
        return []
    var data: RoomData = state.data
    var result: Array[Transform3D] = []
    for i in range(data.spawn_points.size()):
        if tag_filter == "" or data.spawn_point_tags[i] == tag_filter:
            result.append(data.spawn_points[i])
    return result

func get_adjacent_rooms(room_id: StringName) -> Array[StringName]:
    if not rooms.has(room_id):
        return []
    return rooms[room_id].data.adjacency.duplicate()

func get_accessible_rooms() -> Array[StringName]:
    var result: Array[StringName] = []
    for room_id in rooms:
        if rooms[room_id].access_state == RoomState.AccessState.ACCESSIBLE:
            result.append(room_id)
    # AC-RLM-15: Never return empty — ensure Night 1 defaults
    if result.is_empty():
        result.append(&"entry_hall")
        result.append(&"main_classroom")
        result.append(&"art_corner")
    return result

func _validate_adjacency() -> void:
    # AC-RLM-12: Assert symmetric adjacency in debug builds
    for room_id in rooms:
        var data: RoomData = rooms[room_id].data
        for adjacent_id in data.adjacency:
            if not rooms.has(adjacent_id):
                push_error("Room " + str(room_id) + " lists " + str(adjacent_id) + " as adjacent, but that room does not exist")
            elif not rooms[adjacent_id].data.adjacency.has(room_id):
                push_error("Asymmetric adjacency: " + str(room_id) + " → " + str(adjacent_id) + " but " + str(adjacent_id) + " does not list " + str(room_id))

func configure_for_night(night: int) -> void:
    # ... (from Story 003)
    if night == 7 and rooms.has(&"principals_office"):
        rooms[&"principals_office"].access_state = RoomState.AccessState.ACCESSIBLE
        room_unlocked.emit(&"principals_office")
```

*Derived from ADR-0003 Implementation Guidelines:*

- room_unlocked(room_id: StringName) signal — Night Progression must connect in _ready() before configure_for_night() is called
- configure_for_night(7) sets Principal's Office to ACCESSIBLE, then unlock_room() emits room_unlocked (redundant safety)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Room data registration (rooms must be registered first)
- [Story 002]: Boundary detection (separate concern)
- [Story 003]: configure_for_night() state changes (formula logic)
- [Story 004]: Spawn slot calculation (called from configure_for_night)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-RLM-11**: LOCKED room spawn points
  - Given: Room with access_state == LOCKED
  - When: get_room_spawn_points(room_id) called
  - Then: Returns [] regardless of active_spawn_slots
  - Edge cases: Room doesn't exist → also returns []; ROOM with access_state == ACCESSIBLE → returns filtered spawn points

- **AC-RLM-12**: Adjacency validation
  - Given: Authored RoomData with asymmetric adjacency (A lists B, B doesn't list A)
  - When: RoomManager._ready() runs in debug build
  - Then: Assertion/push_error raised for asymmetric adjacency
  - Edge cases: Valid symmetric adjacency → no error; self-reference → no error (valid edge case)

- **AC-RLM-14**: Principal's Office Night 7 unlock
  - Given: Night Progression connected to room_unlocked
  - When: configure_for_night(7) completes
  - Then: principals_office.access_state == ACCESSIBLE; room_unlocked emitted with &"principals_office" exactly once
  - Edge cases: unlock_room() called again → emits signal again (idempotent state, non-idempotent signal)

- **AC-RLM-15**: Default accessible rooms
  - Given: Scene loaded, configure_for_night() never called
  - When: get_accessible_rooms() called
  - Then: Returns at least entry_hall, main_classroom, art_corner (never empty)
  - Edge cases: All rooms LOCKED (shouldn't happen) → fallback to Night 1 defaults

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/room/room_validation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (room registration), Story 003 must be DONE (configure_for_night)
- Unlocks: Story 003 in Night Progression epic (configure_for_night signal), Anomaly Placement stories (query APIs)
