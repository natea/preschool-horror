# Story 002: Boundary Detection

> **Epic**: Room/Level Management
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/room-level-management.md`
**Requirement**: `TR-RLM-003`, `TR-RLM-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Single-Scene Architecture)
**ADR Decision Summary**: Room Area3D nodes use dedicated physics layer with body_entered/body_exited signals connected to RoomManager. Threshold rule: last room fully entered is authoritative current room.

**ADR Governing Implementation**: ADR-0003 (Signal Communication)
**ADR Decision Summary**: player_entered_room and player_exited_room signals emitted on room transitions. Signal signatures frozen once published.

**ADR Governing Implementation**: ADR-0002 (Physics Engine)
**ADR Decision Summary**: Area3D body_entered/body_exited signals. Player capsule center triggers detection. Physics layer 4 for room boundaries.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Area3D body_entered fires when any body enters the area. Need to filter for player body (check is_in_group("player") or check body type). Debounce logic prevents doorway flickering.

**Control Manifest Rules (Foundation layer)**:
- Required: Area3D for room boundaries
- Guardrail: Room change must not flicker more than once per physics frame

---

## Acceptance Criteria

*From GDD `design/gdd/room-level-management.md`, scoped to this story:*

- [ ] AC-RLM-03: GIVEN the player is in entry_hall, WHEN the player's capsule center fully crosses into main_classroom (body_entered fires AND entry_hall's body_exited fires), THEN get_current_room() returns &"main_classroom" and player_entered_room(&"main_classroom") has been emitted.

- [ ] AC-RLM-04: GIVEN the player straddles the boundary between two rooms (body_entered fired for the new room but body_exited has NOT yet fired for the old room), WHEN get_current_room() is called, THEN it returns the old room (last fully entered) and does NOT change more than once per physics frame.

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

```gdscript
# RoomManager.gd — boundary detection

const ROOM_BOUNDARY_DEBOUNCE: int = 1  # frames to wait before committing

var _pending_room: StringName = ""
var _debounce_frames: int = 0

func _ready() -> void:
    _load_room_data()
    _connect_boundary_signals()
    _find_initial_room()

func _connect_boundary_signals() -> void:
    for room_id in rooms:
        var state: RoomState = rooms[room_id]
        var area := state.boundary_area as Area3D
        if area:
            area.body_entered.connect(_on_room_body_entered.bind(room_id))
            area.body_exited.connect(_on_room_body_exited.bind(room_id))

func _on_room_body_entered(body: Node3D, room_id: StringName) -> void:
    if not body.is_in_group("player"):
        return
    if room_id == current_room:
        return  # Already in this room
    # Queue as pending — will commit when old room exits
    _pending_room = room_id
    _debounce_frames = ROOM_BOUNDARY_DEBOUNCE

func _on_room_body_exited(body: Node3D, room_id: StringName) -> void:
    if not body.is_in_group("player"):
        return
    if room_id != current_room:
        return  # Not the current room
    if _pending_room != "":
        # Commit the pending room transition
        var old_room := current_room
        current_room = _pending_room
        player_entered_room.emit(current_room)
        player_exited_room.emit(old_room)
        _pending_room = ""
        _debounce_frames = 0
    else:
        # No pending room — this room just exited, stay in it
        pass  # current_room stays the same (dead-end room)

func _physics_process(delta: float) -> void:
    # If debounce timeout and no body_exited, commit pending room
    if _debounce_frames > 0:
        _debounce_frames -= 1
        if _debounce_frames <= 0 and _pending_room != "":
            var old_room := current_room
            current_room = _pending_room
            player_entered_room.emit(current_room)
            player_exited_room.emit(old_room)
            _pending_room = ""
            _debounce_frames = 0

func get_current_room() -> StringName:
    return current_room
```

*Derived from ADR-0003 Implementation Guidelines:*

- Signal signatures: `player_entered_room(room_id: StringName)`, `player_exited_room(room_id: StringName)`
- No signal chains — RoomManager emits these directly, not re-emitted from another signal
- Subscribers: Anomaly System, Night Progression, Audio System, HUD

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Room data registration (rooms must be registered before boundaries work)
- [Story 003]: configure_for_night() (room access state, not boundary detection)
- [Story 005]: Adjacency validation (separate concern)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-RLM-03**: Room transition via boundary
  - Given: Player in entry_hall, moves into main_classroom
  - When: entry_hall body_exited fires after main_classroom body_entered
  - Then: get_current_room() returns &"main_classroom"; player_entered_room(&"main_classroom") emitted
  - Edge cases: body_entered before body_exited → pending state, current_room unchanged until body_exited

- **AC-RLM-04**: Boundary straddling
  - Given: Player straddles two room boundaries
  - When: get_current_room() called during straddle
  - Then: Returns old room (last fully entered); no change within same physics frame
  - Edge cases: Debounce timeout (1 frame) without body_exited → commits pending room; rapid enter/exited → debouncing prevents flicker

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/room/boundary_detection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (rooms must be registered before boundaries can work)
- Unlocks: Story 003 (configure_for_night depends on room state), Story 005 (validation depends on room state)
