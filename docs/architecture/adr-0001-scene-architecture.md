# ADR-0001: Single-Scene Architecture

## Status
**Accepted**

## Date
2026-04-19

## Context

The game takes place in a single-floor preschool building. The GDD specifies 3 rooms for MVP (classroom, office, gym) scaling to 5-7 rooms for full release. The preschool footprint is small — approximately one floor of a typical elementary school.

The question is whether to use a single continuous scene or split the building into multiple scenes with streaming.

## Decision

The entire preschool is a single Godot scene. The building contains 5-7 rooms implemented as Area3D child nodes. Player movement between rooms occurs through doorway collisions without any scene loading or transitions.

Room state (which rooms are accessible) is managed at runtime via a RoomManager singleton pattern using a scene-local node tree, not a project-level Autoload.

### Key Interfaces

- **`RoomManager`** (scene-local node): Tracks current room, room access state, and transitions
  - Signal: `room_changed(new_room: StringName, previous_room: StringName)`
  - Method: `get_accessible_rooms() -> Array[StringName]`
  - Method: `configure_for_night(night: int)` — called by Night Progression at night start

- **`RoomData`** (`.tres` resource): Static room identity
  - Properties: `name`, `boundaries` (Array[Vector3]), `spawn_slots` (Array[Vector3]), `accessible_rooms` (Array[StringName])

- **Player entry detection**: Area3D `body_entered` signals on doorway zones trigger `room_changed` emission

### Technical Constraints

- **Scene file size**: The preschool scene will be large (~5000-10000 nodes). This is within Godot's scene limits and acceptable for PC targets.
- **Web memory**: Single scene means all room geometry is loaded into memory simultaneously. This constrains the total polygon count and texture resolution budget.
- **No scene tree disposal**: Room nodes persist for the game's lifetime. Room-specific data (anomalies, monsters) is spawned/destroyed dynamically.

## Alternatives

### Alternative 1: Multi-scene streaming
- **Description**: Split the preschool into 3-5 scenes with `ResourceLoader.load_threaded_request()` and scene tree changes
- **Pros**: Smaller individual scene files; better initial load time; each room can be optimized independently
- **Cons**: Loading screens break horror immersion; seamless transitions require expensive cross-fade tricks; complex room boundary logic across scene boundaries; Godot's scene streaming is not designed for room-level granularity
- **Rejection Reason**: The game's horror identity depends on seamless transitions. Any loading artifact between rooms breaks the "real-time" tension. At this scale (single floor, ~3000 sq ft), scene size is not a limiting factor.

### Alternative 2: Instanced sub-scenes
- **Description**: Use `PackedScene` to instantiate room sub-scenes at runtime, loading only adjacent rooms
- **Pros**: Memory efficiency; modular authoring
- **Cons**: Adds complexity for no benefit at this scale; cross-room state management becomes harder; player could notice loading when entering new rooms
- **Rejection Reason**: Premature optimization. The preschool is small enough to fit in a single scene without performance issues given the target platform constraints.

## Consequences

### Positive
- Seamless room transitions preserve horror immersion — no loading screens, no visual cuts
- Simpler development: no streaming logic, no cross-scene state management
- Easier level design: the author can see and edit the entire building in one viewport
- Room access logic is straightforward (Area3D overlap detection within one scene)

### Negative
- All room geometry loaded into memory simultaneously — constrains total asset budget
- Single scene file grows large as rooms are added — harder to navigate in the editor
- Cannot unload rooms the player has left — memory is permanently committed

### Risks
- **Scene file bloat**: As rooms are added, the scene file may become slow to open in the editor. **Mitigation**: Keep the full release under 7 rooms; use instanced sub-scenes for complex room interiors (desks, shelves) rather than whole rooms.
- **Web memory ceiling**: All geometry loaded at once may exceed browser limits. **Mitigation**: Polygon budgets per room; texture compression; profile early on target hardware.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `room-management.md` | "The preschool is a single continuous scene" | Formalizes this as a binding architectural decision |
| `night-progression.md` | Room access control per night | RoomManager handles access via `configure_for_night()` |
| `anomaly-placement.md` | Anomalies placed in specific rooms | Room-level targeting via RoomManager's room state |
| `photography.md` | Player moves between rooms to photograph anomalies | Seamless transitions enable continuous gameplay |

## Performance Implications
- **CPU**: No scene loading overhead per room transition — saves ~2-5ms per transition
- **Memory**: All room geometry loaded at startup — must fit within 512 MB budget. Per-room geometry budget: < 500k triangles total.
- **Load Time**: Single initial load — no per-room loading. Target: < 5 seconds on PC, < 15 seconds on Web.
- **Network**: Not applicable — no streaming or multiplayer.

## Migration Plan

This is a new project — no migration needed. During implementation:

1. Create the base preschool scene with MVP rooms (classroom, office, gym)
2. Validate scene performance in the editor (load time, node count)
3. Add remaining rooms incrementally, monitoring scene file size
4. If the scene becomes unmanageable (> 15000 nodes), split individual room interiors into instanced sub-scenes (not whole rooms)

## Validation Criteria
- [ ] Player can walk from any accessible room to any other without any visual cut or loading screen
- [ ] Scene file opens in < 10 seconds with all MVP rooms
- [ ] Memory usage stays under 512 MB with all rooms loaded
- [ ] Room transitions feel instant (< 1 frame of delay)

## Related Decisions
- ADR-0002 (Jolt Physics) — CharacterBody3D movement within single scene
- ADR-0003 (Signal Communication) — RoomManager emits `room_changed` signal
- ADR-0004 (Data-Driven Design) — RoomData resources define room boundaries
- ADR-0005 (Web-Compatible Rendering) — Single-scene memory constraints inform rendering budget
