# Story 002: Vision Cone Detection

> **Epic**: Monster AI
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Core Mechanics section)
**Requirement**: `TR-MON-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Physics)
**ADR Decision Summary**: Area3D for vision cone detection zone. PhysicsDirectSpaceState3D for raycasting line-of-sight checks. Jolt physics collision layers.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Vision cone angle, detection range, and layer masks in MonsterConfig resource.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Area3D signals for overlap. PhysicsDirectSpaceState3D.get_direct_space_state() for raycasting. Godot 4.4+ changed PhysicsServer3D to PhysicsDirectSpaceState3D pattern — verify via docs. Collision layer/mask for monster vs player.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Guardrail: Non-rendering CPU budget < 4 ms on Web (physics + game logic)

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md`, scoped to this story:*

- [ ] AC-MON-06: GIVEN the monster has a vision cone (Area3D), WHEN the player enters the detection zone AND is within the cone angle, THEN the monster detects the player and emits a vision_detected signal.

- [ ] AC-MON-07: GIVEN the monster is detecting the player, WHEN an obstacle blocks the line-of-sight between monster and player, THEN the detection is cancelled (line-of-sight check via raycast).

- [ ] AC-MON-08: GIVEN the player is partially within the vision cone, WHEN the player is at the edge of the detection angle, THEN detection follows a smooth falloff (not binary on/off) based on angle from center.

---

## Implementation Notes

*Derived from ADR-0002 Physics:*

```gdscript
# Vision cone setup:
# Area3D with shape = ConeShape3D (or custom collision shape)
# detection_range from MonsterConfig: `vision_range` (default 10.0 meters)
# cone_angle from MonsterConfig: `vision_angle` (default 90 degrees)
# collision_layer = Monster collision layer
# collision_mask = Player collision layer (only detect player)

# Raycast for line-of-sight:
# From monster position → player position
# Use PhysicsDirectSpaceState3D for performance
# Obstacles on Monster's "obstacle" layer block sight
# If raycast hits obstacle before player → no detection
```

*Vision cone implementation:*

```gdscript
# Area3D vision cone attached to monster, facing forward
var vision_cone := Area3D.new()
var cone_shape := ConeShape3D.new()
cone_shape.height = vision_range
cone_shape.radius = vision_range * tan(vision_angle / 2.0)
vision_cone.add_shape(cone_shape)

# Overlap callback checks angle from monster forward vector
func _on_vision_cone_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        var to_player := body.global_position - global_position
        var angle := to_player.angle_to_forward()  # angle from monster's facing direction
        if angle <= vision_angle / 2.0:
            _check_line_of_sight(body)

# Smooth falloff: detection strength = cos(angle / (vision_angle/2))
# At cone edge → strength ~0.5; at center → strength 1.0
# If strength < threshold, don't trigger full detection (use audio detection instead)
```

*Line-of-sight check:*

```gdscript
func _check_line_of_sight(target: Node3D) -> bool:
    var space := get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.new()
    query.from = global_position
    query.to = target.global_position
    query.collide_with_areas = true
    query.collide_with_bodies = true
    query.collision_mask = monster_obstacle_mask
    var result := space.intersect_ray(query)
    # If result is empty → clear line of sight → detect
    # If result.hit is not target → blocked → no detect
    return result.is_empty() or result.get("collider") == target
```

*Derived from ADR-0003 Communication:*

- Emit `vision_detected(target: Node3D, strength: float)` when detection succeeds
- Emit `vision_lost(target: Node3D)` when detection ends
- Do NOT chain signals — state machine subscribes directly

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine (consumes detection signals)
- [Story 003]: Audio detection (separate detection modality)
- [Story 005]: Pathfinding (navigation after detection, not detection itself)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-MON-06**: Vision cone detects player
  - Given: Monster at (0,1,0), player at (5,1,0), `vision_range = 10.0`, `vision_angle = 90`
  - When: Player enters vision cone within monster's facing direction
  - Then: `vision_detected` fires with strength = 1.0; state machine receives signal
  - Edge cases: player at exactly vision_range → detection at threshold; player outside cone angle → no detection; player behind monster (180°) → no detection

- **AC-MON-07**: Line-of-sight blocks detection
  - Given: Monster and player within vision range, wall between them
  - When: Player enters vision cone
  - Then: Raycast hits wall before player; `vision_detected` does NOT fire
  - Edge cases: wall partially blocks → raycast still hits wall; wall at monster position → no detection; wall at player position → no detection; wall removed → detection resumes

- **AC-MON-08**: Smooth falloff at cone edge
  - Given: Player at edge of vision cone (angle = vision_angle/2 - epsilon)
  - When: Player crosses into detection zone
  - Then: Detection strength = ~0.5 (not full 1.0); may not trigger CHASE state (below threshold)
  - Edge cases: player at cone center → strength = 1.0; player at cone edge → strength = 0.0; moving player → strength updates each frame

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/monster_ai/vision_cone_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (state machine needs detection signals to respond to)
- Unlocks: Monster AI epic (vision is primary detection modality), Player Survival (monster detection triggers vulnerability relevance)
