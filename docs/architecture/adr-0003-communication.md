# ADR-0003: Signal-Based Communication

## Status
**Accepted**

## Date
2026-04-19

## Context

The game has 17 systems organized in a dependency layer architecture. Systems must communicate across layer boundaries without creating tight coupling. The system layer hierarchy (from lowest to highest):

1. **Foundation** — FP Controller, Room/Level Mgmt, Audio, Save/Persistence
2. **Core** — Night Progression, Anomaly Placement, HUD/UI
3. **Feature** — Anomaly System, Photography, Monster AI, Player Survival, Vents
4. **Presentation** — Evidence Submission, Photo Gallery
5. **Polish** — Main Menu, Cutscene System, Night 7 Finale

The question is how systems communicate across these layers without violating the dependency model.

## Decision

Three communication patterns are used, each with a specific role:

### 1. Signals (Event Bus) — Primary cross-layer pattern

Systems communicate via Godot signals. Each system emits domain events and subscribes to events from its dependency layer. No system directly calls methods on a system in a higher layer.

**Direction**: Signals flow upward (lower layer → higher layer). A Foundation system emits a signal; Core systems subscribe to it.

```gdscript
# RoomManager (Foundation) — emits signals
signal room_changed(new_room: StringName, previous_room: StringName)
signal room_access_changed(room: StringName, accessible: bool)

func _on_doorway_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        var old: StringName = current_room
        current_room = new_room
        room_changed.emit(new_room, old)
        room_access_changed.emit(new_room, true)
```

```gdscript
# NightProgression (Core) — subscribes to Foundation signals
func _ready() -> void:
    room_manager.room_changed.connect(_on_room_changed)
    room_manager.room_access_changed.connect(_on_room_access_changed)

func _on_room_changed(new_room: StringName, _previous_room: StringName) -> void:
    if new_room == "classroom":
        anomaly_spawner.activate_tier("classroom_tier")
```

### 2. Configuration Calls (Top-Down) — Nightly initialization only

Night Progression calls `configure_for_night(n: int)` on Foundation systems at night start. This is the **only** permitted top-down call pattern — configuration, not runtime coupling.

```gdscript
# NightProgression calls at night start
func _start_night(night: int) -> void:
    room_manager.configure_for_night(night)       # Room access
    anomaly_spawner.configure_for_night(night)    # Anomaly pool
    audio_manager.configure_for_night(night)      # Ambient layers
```

### 3. Data Resources (Static) — Shared data without runtime coupling

Room definitions, anomaly templates, and night configs are Godot Resources (`.tres`) authored in the editor. Runtime state is held in companion objects, not baked into resources.

```gdscript
# RoomData resource (static, authored in editor)
@export var name: StringName
@export var boundaries: Array[Vector3]
@export var spawn_slots: Array[Vector3]
@export var accessible_rooms: Array[StringName]

# Runtime state (companion object)
class RoomState:
    var name: StringName
    var accessible: bool = true
    var anomalies_active: Array[StringName] = []
```

### Technical Constraints

- **No Autoload singletons**: Systems must not directly reference Autoload singletons by name. Use dependency injection or signals instead.
- **No direct cross-layer calls**: A system in layer N may only call methods on systems in layer N-1 (via configured references), never layers below N-1 or above N.
- **Signal signature stability**: Once a signal is published (emitted by a lower layer), its signature is frozen. New parameters are added at the end with default values.
- **No signal chains**: A system that receives a signal must not re-emit it as a different signal. If a system needs to transform an event, it does so internally and emits its own signal with a distinct name.

### Signal Registry

| Signal | Emitted By | Subscribed By | Layer |
|--------|-----------|---------------|-------|
| `room_changed(new_room, previous_room)` | RoomManager | NightProgression, HUD, AnomalyPlacement | Foundation → Core |
| `room_access_changed(room, accessible)` | RoomManager | NightProgression, AnomalyPlacement | Foundation → Core |
| `night_started(night: int)` | NightProgression | All Core + Feature systems | Core → Core/Feature |
| `night_ended(night: int)` | NightProgression | HUD, EvidenceSubmission | Core → Presentation |
| `anomaly_detected(anomaly_id)` | AnomalyPlacement | AnomalySystem, Audio, HUD | Core → Feature |
| `anomaly_photographed(anomaly_id)` | AnomalySystem | NightProgression, EvidenceSubmission | Feature → Core/Presentation |
| `photo_captured(anomaly_id, quality)` | Photography | AnomalySystem, HUD | Feature → Core |
| `player_died()` | PlayerSurvival | NightProgression, Audio | Feature → Core |
| `night_progressed()` | NightProgression | EvidenceSubmission, CutsceneSystem | Core → Presentation |
| `evidence_submitted(evidence_id)` | EvidenceSubmission | PhotoGallery, NightProgression | Presentation → Core |

## Alternatives

### Alternative: Autoload singletons for cross-system communication
- **Description**: Use Godot's Autoload feature to make systems globally accessible
- **Pros**: Simple setup; no signal wiring needed; direct method calls work
- **Cons**: Tight coupling to Autoload names; hidden dependencies; untestable in isolation; load order issues; breaks the dependency layer model
- **Rejection Reason**: Autoloads create implicit coupling that violates the dependency layer model. Systems should only know about their direct dependencies.

### Alternative: Event bus with string-based events
- **Description**: A global EventBus singleton with `emit(event_name: String, data: Variant)`
- **Pros**: Flexible; no signal signature changes needed
- **Cons**: No compile-time checking; no type safety; runtime errors for typos; harder to debug; harder to discover all subscribers
- **Rejection Reason**: Type safety is critical for a project managed through automated code review. String-based events cannot be validated statically.

### Alternative: Direct method calls between all systems
- **Description**: Systems hold references to each other and call methods directly
- **Pros**: Simple; direct; no signal overhead
- **Cons**: Tight coupling; violates dependency layer model; hard to test; circular dependencies
- **Rejection Reason**: Direct calls between non-adjacent layers create bidirectional dependencies that make the system untestable and fragile.

## Consequences

### Positive
- **Loose coupling**: Systems only know about their direct dependencies via signals
- **Testability**: Each system can be tested in isolation by mocking its signal sources
- **Discoverability**: Signal registry documents all cross-system contracts
- **Layer integrity**: The dependency hierarchy is enforced by the communication pattern

### Negative
- **Signal wiring**: More initial setup — each system must connect its signals in `_ready()`
- **Debugging complexity**: Signal chains are harder to trace than direct calls (need to check signal registry)
- **Performance**: Signal emission has minor overhead vs direct calls (negligible at game frame rates)

### Risks
- **Signal signature drift**: A signal's parameters change without updating all subscribers. **Mitigation**: Signal registry with signature documentation; code review for signal changes.
- **Signal memory leaks**: Subscribers not disconnected when nodes are freed. **Mitigation**: Use `node.disconnect()` in `_exit_tree()`; prefer `connect()` with `CONNECT_ONE_SHOT` for one-time subscriptions.
- **Signal chains**: Long chains of signal re-emissions make debugging hard. **Mitigation**: No signal chains — each system transforms events internally and emits its own distinct signal.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `night-progression.md` | Night start triggers room configuration | `configure_for_night()` top-down calls |
| `anomaly-placement.md` | Anomalies notify other systems when detected | `anomaly_detected` signal |
| `photography.md` | Photo captures update multiple systems | `photo_captured` signal to HUD, AnomalySystem |
| `evidence-submission.md` | Evidence flows to gallery and progression | `evidence_submitted` signal chain |
| `fp-controller.md` | Player movement triggers room changes | `room_changed` signal from RoomManager |

## Performance Implications
- **CPU**: Signal emission is ~0.01ms per subscriber — negligible at game frame rates
- **Memory**: Signal connections use minimal memory — one callback per subscriber
- **Determinism**: Signal delivery is synchronous (immediate) — same determinism as direct calls
- **Network**: Not applicable — single-player only

## Migration Plan

This is a new project — no migration needed. During implementation:

1. Create the signal registry in this ADR and update it as new signals are added
2. When implementing each system, review the signal registry for required connections
3. Code review: verify no Autoload usage, no direct cross-layer calls, no signal chains
4. Validate signal signatures match between emitter and subscriber during integration testing

## Validation Criteria
- [ ] No system uses an Autoload singleton
- [ ] No system calls methods on a system more than one layer above it
- [ ] All cross-system communication is documented in the signal registry
- [ ] Each system can be tested in isolation (signal sources can be mocked)
- [ ] No signal chains exist (no re-emission of received signals)

## Related Decisions
- ADR-0001 (Single-Scene Architecture) — RoomManager is a scene-local node, not an Autoload
- ADR-0004 (Data-Driven Design) — RoomData resources are static data without runtime coupling
- ADR-0006 (Source Code Organization) — Layer boundaries align with signal flow direction
