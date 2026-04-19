# Story 004: Interaction Raycast

> **Epic**: First-Person Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-MOV-007`, `TR-MOV-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Physics Engine)
**ADR Decision Summary**: PhysicsDirectSpaceState3D for raycast from camera position forward. Collision mask configured to detect interactable objects. Ray length = 2.0m. Return contact points for UI hint positioning.

**ADR Governing Implementation**: ADR-0008 (Input)
**ADR Decision Summary**: Input Action "interact" triggers interaction. UI hint uses Control node with label — no hover-only interactions (accessibility).

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: Interaction labels from interactable object's resource (not hardcoded).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: PhysicsDirectSpaceState3D.get_state() returns SpaceStateQuery parameters. For simple raycasts, use PhysicsServer3D.space_test_ray() or CharacterBody3D.is_on_wall() patterns. GDScript 2.0: `get_world_3d().direct_space_state` for raycast queries.

**Control Manifest Rules (Foundation layer)**:
- Required: CharacterBody3D for all physical bodies
- Required: Static typing on all class members
- Guardrail: Raycast must complete within physics step — no blocking calls

---

## Acceptance Criteria

*From GDD `design/gdd/first-person-controller.md`, scoped to this story:*

- [ ] AC7: Interaction raycast — cast ray from camera forward; max range 2.0m; detects interactable objects (physics layer mask)
- [ ] AC8: When player is looking at an interactable object within range, display interaction hint UI ("Press [key] to interact")

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

```gdscript
# PlayerController.gd — interaction raycast

@onready var camera: Camera3D = $Camera3D
@onready var interact_hint: Label = $UI/InteractHint

const INTERACT_RANGE: float = 2.0
const INTERACT_MASK: int = 2  # Physics layer 2 = interactable objects

func _physics_process(delta: float) -> void:
    var space_state = get_world_3d().direct_space_state
    var origin = camera.global_position
    var end = origin + camera.global_transform.basis.z * -INTERACT_RANGE
    var query = PhysicsRayQueryParameters3D.create(origin, end, INTERACT_MASK)
    var result = space_state.intersect_ray(query)
    if result:
        _show_interact_hint(result.collider)
    else:
        _hide_interact_hint()

func _show_interact_hint(collider: Node3D) -> void:
    if collider.has_method("get_interact_label"):
        interact_hint.text = collider.get_interact_label()
        interact_hint.visible = true
    elif collider.has_meta("interact_label"):
        interact_hint.text = collider.get_meta("interact_label")
        interact_hint.visible = true

func _hide_interact_hint() -> void:
    interact_hint.visible = false

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and interact_hint.visible:
        _perform_interaction()

func _perform_interaction() -> void:
    var space_state = get_world_3d().direct.space_state
    var origin = camera.global_position
    var end = origin + camera.global_transform.basis.z * -INTERACT_RANGE
    var query = PhysicsRayQueryParameters3D.create(origin, end, INTERACT_MASK)
    var result = space_state.intersect_ray(query)
    if result and result.collider:
        var collider = result.collider
        if collider.has_method("on_interact"):
            collider.on_interact(self)
```

- Raycast direction: camera's negative Z-axis (forward in Godot's camera space)
- Physics layer 2 = interactable objects (configure in project settings)
- Interaction label from collider's `get_interact_label()` method or `interact_label` meta
- UI hint node: Label child of PlayerController scene (or referenced from UI layer)
- Input "interact" action checked in `_unhandled_input()` per ADR-0008

*Derived from ADR-0008 Implementation Guidelines:*

- Input Action "interact" defined in project settings (not at runtime)
- No hover-only interactions — hint always visible when looking at object
- Key binding shown in hint text (retrieved from InputMap action)

*Derived from ADR-0004 Implementation Guidelines:*

- Interaction labels stored on interactable objects via @export or meta — not hardcoded in player controller
- If no label available, hint shows generic "Interact" text

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 005]: Key rebinding updates hint text (settings integration)
- [Story 004b in Player Interaction epic]: Actual interaction behavior on target objects
- [Story 004 in Evidence Submission epic]: Photo evidence UI overlay

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-7**: Interaction raycast detection
  - Given: Camera aimed at object on physics layer 2 at distance 1.5m
  - When: _physics_process() runs
  - Then: Raycast result.collider = the interactable object; interact_hint.visible = true
  - Edge cases: Distance > 2.0m → no hit; object on wrong layer → no hit; no object in path → no hit

- **AC-8**: Interaction hint display
  - Given: Raycast hits object with interact_label meta = "Open"
  - When: _physics_process() runs
  - Then: interact_hint.text = "Press [E] to Open" (or bound key); interact_hint.visible = true
  - Edge cases: Object without label → hint shows "Interact"; object removed during view → hint hides immediately

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/player/interaction_raycast_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (needs camera reference), Story 003 must be DONE (needs camera direction)
- Unlocks: Story 004 in Player Interaction epic (target objects need interactable interface)
