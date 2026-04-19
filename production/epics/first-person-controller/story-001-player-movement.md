# Story 001: Player Movement

> **Epic**: First-Person Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-MOV-001`, `TR-MOV-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Physics Engine)
**ADR Decision Summary**: CharacterBody3D as root node, Jolt Physics as default, move_and_slide() for standard movement, PhysicsDirectSpaceState3D for raycasts. CollisionShape3D for player collider with wall_climb and ceiling_clearance properties.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure, no Autoloads, no global mutable state, static typing in GDScript.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Jolt is now the default physics engine in Godot 4.6. move_and_slide() behavior differs from 4.3 — get_floor_velocity() returns Jolt-specific values. Always verify against docs.godotengine.org/en/stable.

**Control Manifest Rules (Foundation layer)**:
- Required: CharacterBody3D for all physical bodies
- Required: Static typing on all class members
- Forbidden: Autoloads for player state (use scene-local variables)
- Guardrail: Frame budget 16.6ms — movement physics must complete within physics step

---

## Acceptance Criteria

*From GDD `design/gdd/first-person-controller.md`, scoped to this story:*

- [ ] AC1: PlayerController uses CharacterBody3D as root node
- [ ] AC2: Movement formula implemented: SPEED_CURRENT = SPEED_BASE × SPEED_MODIFIER
  - SPEED_BASE default = 2.0 m/s (walk)
  - SPEED_MODIFIER defaults to 1.0 (no modifier)
  - SPEED_MODIFIER is set by sprint/crouch states (handled by Story 002)

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

```gdscript
# PlayerController.gd — root node must be CharacterBody3D
@export var speed_base: float = 2.0
@export var speed_modifier: float = 1.0

func get_speed_current() -> float:
    return speed_base * speed_modifier

func _physics_process(delta: float) -> void:
    var velocity = get_input_direction() * speed_base * speed_modifier
    velocity = move_and_slide(velocity)
    # Jolt 4.6: move_and_slide() returns ContactInfo iterator in GDScript
```

- Use `move_and_slide()` for standard ground movement (not `move_and_collide`)
- CollisionShape3D should have appropriate radius for a preschool-character scale (~0.3-0.4m)
- Wall collision: CharacterBody3D default behavior (stop, slide along wall)
- Ceiling collision: CharacterBody3D default behavior (stop, slide under)
- No custom wall-climbing in this story — handled by interaction system (Evidence story)

*Derived from ADR-0006 Implementation Guidelines:*

- Class file: `src/core/player/player_controller.gd`
- Scene file: `src/core/player/player_controller.tscn`
- Static typing: All exported variables typed, all function signatures typed
- No Autoload access — use signal-based communication for cross-system data

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Sprint and crouch speed modifiers
- [Story 003]: Camera mouse-look and rotation
- [Story 004]: Interaction raycast and UI hints
- [Story 005]: Key rebinding in settings
- [Story 006]: Camera shake during sprint

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: CharacterBody3D root node
  - Given: PlayerController scene loaded
  - When: Inspect root node type
  - Then: Root node is CharacterBody3D
  - Edge cases: N/A (structural requirement)

- **AC-2**: Speed formula `SPEED_CURRENT = SPEED_BASE × SPEED_MODIFIER`
  - Given: speed_base = 2.0, speed_modifier = 1.0
  - When: Call get_speed_current()
  - Then: Returns 2.0
  - Edge cases: speed_modifier = 0.0 → returns 0.0 (frozen); speed_modifier = 2.0 → returns 4.0; speed_modifier < 0.0 → returns negative (movement reversed)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/player/player_movement_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (Sprint & Crouch States builds on movement foundation)
