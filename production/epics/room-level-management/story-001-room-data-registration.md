# Story 001: Room Data Registration

> **Epic**: Room/Level Management
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/room-level-management.md`
**Requirement**: `TR-RLM-001`, `TR-RLM-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Single-Scene Architecture)
**ADR Decision Summary**: RoomManager is a scene-local node (not Autoload). RoomData resources define room boundaries. All 7 rooms loaded in single scene. RoomManager._ready() initializes room state.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: RoomData is a .tres resource with class_name. Resources are read-only at runtime. Runtime state in companion objects.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure. No Autoloads. No global mutable state. Static typing.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: RoomData.tres resource scripts use `class_name` for type safety. `load()` returns typed resource with `as RoomData` cast. Resource loading in _ready() only.

**Control Manifest Rules (Foundation layer)**:
- Required: Static typing on all class members
- Forbidden: Autoloads for RoomManager (use scene-local node)
- Guardrail: All resources loaded in _ready() or earlier

---

## Acceptance Criteria

*From GDD `design/gdd/room-level-management.md`, scoped to this story:*

- [ ] AC-RLM-01: GIVEN the master preschool scene is loaded, WHEN RoomManager._ready() completes, THEN all 7 RoomData resources are registered with non-null room_id, base_spawn_slots > 0, and valid boundary_shape.

- [ ] AC-RLM-02: GIVEN the player's CharacterBody3D is at the authored start position, WHEN get_current_room() is called immediately after scene load (before the player moves), THEN the return value is a non-empty StringName matching a valid room_id.

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

```gdscript
# RoomManager.gd — room data registration

class_name RoomManager extends Node

signal player_entered_room(room_id: StringName)
signal player_exited_room(room_id: StringName)
signal room_unlocked(room_id: StringName)

@export var room_data_paths: Array[String] = [
    "res://data/rooms/entry_hall.tres",
    "res://data/rooms/main_classroom.tres",
    "res://data/rooms/art_corner.tres",
    "res://data/rooms/cubby_hall.tres",
    "res://data/rooms/nap_room.tres",
    "res://data/rooms/bathroom.tres",
    "res://data/rooms/principals_office.tres"
]

var rooms: Dictionary = {}          # room_id (StringName) → RoomState
var current_room: StringName = ""

func _ready() -> void:
    _load_room_data()
    _initialize_default_state()
    _find_initial_room()

func _load_room_data() -> void:
    for path in room_data_paths:
        var data: RoomData = load(path) as RoomData
        assert(data != null, "RoomData not found: " + path)
        assert(data.room_id != null, "RoomData has null room_id: " + path)
        assert(data.base_spawn_slots > 0, "RoomData base_spawn_slots must be > 0: " + str(data.room_id))
        rooms[data.room_id] = RoomState.new(data)

func _find_initial_room() -> void:
    # Check which Area3D contains player's start position via overlaps_body()
    var player := get_node_or_null("^/Player") as CharacterBody3D
    if player:
        for room_id in rooms:
            var state: RoomState = rooms[room_id]
            if state.boundary_area.overlaps_body(player):
                current_room = room_id
                return
    assert(false, "Player start position not inside any room")
```

*Derived from ADR-0004 Implementation Guidelines:*

- RoomData resource fields: room_id (StringName), display_name (String), base_spawn_slots (int), first_accessible_night (int), adjacency (Array[StringName]), spawn_points (Array[Transform3D])
- Resources are read-only at runtime — state in RoomState companion objects
- RoomState class holds: access_state (enum), horror_tier (int), active_spawn_slots (int), lights_on (bool)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Boundary detection via Area3D signals (physics integration)
- [Story 003]: configure_for_night() (night state management)
- [Story 004]: Spawn slot formula calculation
- [Story 005]: Room validation and query APIs

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-RLM-01**: RoomData registration
  - Given: Master preschool scene loaded, RoomManager._ready() completes
  - When: Iterate all registered rooms
  - Then: All 7 rooms have non-null room_id, base_spawn_slots > 0, valid boundary_shape
  - Edge cases: Missing RoomData file → assert failure; null room_id → assert failure; base_spawn_slots = 0 → assert failure

- **AC-RLM-02**: Initial room detection
  - Given: Player CharacterBody3D at authored start position (entry_hall)
  - When: get_current_room() called immediately after scene load
  - Then: Returns &"entry_hall" (non-empty StringName matching valid room_id)
  - Edge cases: Player not inside any room → assert failure (developer error)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/room/room_registration_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (boundary detection needs registered rooms), Story 003 (configure_for_night needs RoomState objects)
