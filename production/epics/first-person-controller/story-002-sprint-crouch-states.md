# Story 002: Sprint & Crouch States

> **Epic**: First-Person Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-MOV-003`, `TR-MOV-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Physics Engine)
**ADR Decision Summary**: State changes affect speed_modifier exported variable on PlayerController. CollisionShape3D scale changes for crouch. Jolt physics responds to collider shape changes automatically.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure, no Autoloads, no global mutable state.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Jolt handles dynamic collider shape changes. CollisionShape3D.scale changes are applied immediately in the physics step. Verify that shape scaling doesn't cause tunneling at high speeds.

**Control Manifest Rules (Foundation layer)**:
- Required: CharacterBody3D for all physical bodies
- Required: Static typing on all class members
- Forbidden: Autoloads for player state (use scene-local variables)
- Guardrail: Frame budget 16.6ms — movement physics must complete within physics step

---

## Acceptance Criteria

*From GDD `design/gdd/first-person-controller.md`, scoped to this story:*

- [ ] AC3: Sprint state — hold sprint button (Shift) to activate; SPEED_MODIFIER = 1.5 during sprint
- [ ] AC4: Crouch state — hold crouch button (Ctrl) to activate; SPEED_MODIFIER = 0.5 during crouch; collision shape scales down to prevent ceiling clipping

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

```gdscript
# PlayerController.gd — sprint and crouch within existing scene

@export var sprint_speed_modifier: float = 1.5
@export var crouch_speed_modifier: float = 0.5
@export var crouch_collision_scale: Vector3 = Vector3(1.0, 0.5, 1.0)

var is_sprinting: bool = false
var is_crouching: bool = false

func _physics_process(delta: float) -> void:
    update_sprint_state()
    update_crouch_state()
    update_speed_modifier()
    var velocity = get_input_direction() * speed_base * speed_modifier
    velocity = move_and_slide(velocity)

func update_sprint_state() -> void:
    is_sprinting = Input.is_action_pressed("sprint") and not is_crouching

func update_crouch_state() -> void:
    is_crouching = Input.is_action_pressed("crouch") and not is_sprinting
    if is_crouching:
        collision_shape.scale = crouch_collision_scale
    else:
        collision_shape.scale = Vector3.ONE
    # Note: collision_shape is a reference to the CollisionShape3D node

func update_speed_modifier() -> void:
    if is_crouching:
        speed_modifier = crouch_speed_modifier
    elif is_sprinting:
        speed_modifier = sprint_speed_modifier
    else:
        speed_modifier = 1.0
```

- Sprint and crouch are mutually exclusive (cannot do both simultaneously)
- Collision shape reference stored at ready — set via `@onready`
- Crouch collision scale: Y-axis reduced to ~50% of normal (preschool character height ~1.0m → crouch ~0.5m)
- State changes apply immediately (no interpolation in this story — smooth transition is a polish task)

*Derived from ADR-0006 Implementation Guidelines:*

- File: `src/core/player/player_controller.gd` (append to existing file from Story 001)
- Static typing: All state variables typed as `bool`
- No Autoload access — sprint/crouch state is local to PlayerController

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: Camera FOV squash during sprint (Visual/Feel)
- [Story 006]: Camera shake during sprint (Visual/Feel)
- [Story 004]: Interaction raycast (must work through crouch state)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-3**: Sprint speed modifier
  - Given: speed_base = 2.0, sprint_speed_modifier = 1.5
  - When: Sprint button pressed
  - Then: speed_modifier = 1.5, get_speed_current() = 3.0
  - Edge cases: Sprint + Crouch simultaneously → crouch wins (speed_modifier = 0.5); Sprint released → speed_modifier returns to 1.0

- **AC-4**: Crouch speed modifier and collision shape
  - Given: speed_base = 2.0, crouch_speed_modifier = 0.5
  - When: Crouch button pressed
  - Then: speed_modifier = 0.5, get_speed_current() = 1.0; CollisionShape3D.scale.y = 0.5
  - Edge cases: Crouch + Sprint simultaneously → crouch wins; Crouch released → speed_modifier returns to 1.0, collision_shape.scale = Vector3.ONE

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/player/sprint_crouch_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (builds on movement foundation)
- Unlocks: Story 003 (camera FOV squash depends on sprint state), Story 006 (camera shake depends on sprint state)
