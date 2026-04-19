# ADR-0002: Jolt Physics Engine

## Status
**Accepted**

## Date
2026-04-19

## Context

Godot 4.6 defaults to Jolt Physics as the 3D physics engine. The project targets PC and Web, both of which need stable and performant physics. The game involves player movement (first-person controller), collision detection for room boundaries and anomalies, and potential physics-based interactions (monster hit detection, camera raycasting).

The question is which 3D physics engine to use and how to structure the physics layer.

## Decision

Jolt Physics is used as the 3D physics engine for all new project setup. GodotPhysics3D is not used.

### Key Interfaces

- **`CharacterBody3D`** for the player controller — `move_and_slide()` for movement
- **`Area3D`** for room boundaries, interaction zones, and anomaly detection
- **`PhysicsRayQueryParameters3D`** for camera raycasting (photography system)
- **`PhysicsDirectSpaceState3D`** for direct physics queries (raycasts, shape casts)
- **`CollisionShape3D`** for all collision geometry (static environments)

### Technical Constraints

- **Jolt vs GodotPhysics3D**: Jolt is the default in Godot 4.6. It provides better determinism, stability, and performance for complex scenes.
- **2D physics unchanged**: Godot's 2D physics (used for UI, 2D gameplay elements) remains Godot Physics 2D and is unaffected by this decision.
- **No jump, no crouch**: The single-floor preschool design eliminates vertical movement mechanics, simplifying collision requirements.

### API Patterns

```gdscript
# Player movement (CharacterBody3D + Jolt)
extends CharacterBody3D

func _physics_process(delta: float) -> void:
    velocity += get_gravity() * delta
    move_and_slide()

# Camera raycasting (photography system)
func get_camera_ray_origin() -> Vector3:
    var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(camera_position, camera_position + camera_direction)
    query.collision_mask = 0b111  # Player + Anomalies + Monsters
    var result: Dictionary = space_state.intersect_ray(query)
    return result.position if result else camera_position + camera_direction * MAX_DISTANCE

# Room boundary detection (Area3D)
func _on_room_boundary_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        room_manager.current_room = self.name
```

## Alternatives

### Alternative: GodotPhysics3D (Box2D + Bullet)
- **Pros**: Mature, well-understood; `HingeJoint3D.damp` supported (not relevant for this project)
- **Cons**: Worse determinism; known stability issues in complex scenes; slower for large collision meshes; Godot 4.6's default is Jolt, meaning Jolt gets priority bug fixes
- **Rejection Reason**: No advantage for this project's use case. Jolt is the 4.6 default for good reason.

### Alternative: Custom collision layer (no physics engine)
- **Description**: Use manual bounding-box checks for collision instead of the physics engine
- **Pros**: Zero physics overhead; fully deterministic
- **Cons**: Loses all collision shape support; complex concave geometry (room boundaries) becomes impractical; Godot's Area3D system is tightly coupled to the physics engine
- **Rejection Reason**: The room boundary system relies on Area3D overlap detection, which requires the physics engine.

## Consequences

### Positive
- Better physics determinism — consistent behavior across platforms and runs
- Improved stability for complex collision scenarios (room boundaries, anomaly zones)
- Better performance for complex scenes — important for the single-scene architecture
- Future-proof — Jolt is Godot's primary direction for 3D physics

### Negative
- **HingeJoint3D `damp` property not supported** — not relevant for MVP (no hinge-based mechanisms)
- **Collision margins may differ** from GodotPhysics3D — requires testing edge cases during implementation
- **2D physics unchanged** — no impact on UI or 2D gameplay

### Risks
- **Collision margin differences**: Jolt's collision margin behavior differs from Bullet. **Mitigation**: Test all collision edge cases during gameplay implementation; adjust collision shapes if needed.
- **Runtime warnings**: Jolt emits runtime warnings for unsupported properties. **Mitigation**: Code review to catch unsupported property usage.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `fp-controller.md` | CharacterBody3D movement | Jolt provides the physics backend for `move_and_slide()` |
| `room-management.md` | Area3D boundary detection | Room boundaries use Area3D with Jolt collision detection |
| `photography.md` | Camera raycasting | Raycast queries use `PhysicsDirectSpaceState3D` |
| `monster-ai.md` | Monster collision with player | CharacterBody3D + Area3D overlap for hit detection |

## Performance Implications
- **CPU**: Jolt's better performance for complex scenes reduces per-frame physics cost
- **Memory**: No additional memory overhead vs GodotPhysics3D
- **Determinism**: Consistent physics behavior across PC and Web targets
- **Network**: Not applicable — single-player only

## Migration Plan

This is a new project — no migration needed. During implementation:

1. Create new Godot 4.6 project (Jolt is the default for new projects)
2. Verify physics engine selection in Project Settings → Physics → 3D → Physics Engine = Jolt
3. Test collision edge cases during gameplay implementation
4. Monitor runtime warnings for unsupported properties

## Validation Criteria
- [ ] Physics engine is set to Jolt in project settings
- [ ] Player collision with room boundaries works reliably at all speeds
- [ ] Camera raycasting hits anomaly zones correctly
- [ ] No runtime warnings from Jolt during normal gameplay
- [ ] Monster collision detection works at all movement speeds

## Related Decisions
- ADR-0001 (Single-Scene Architecture) — CharacterBody3D movement within single scene
- ADR-0004 (Data-Driven Design) — Tunable physics values (speed, gravity) externalized
- ADR-0005 (Web-Compatible Rendering) — Physics performance on Web targets
