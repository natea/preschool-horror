# Story 003: Camera & Mouse Look

> **Epic**: First-Person Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-MOV-005`, `TR-MOV-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (Input)
**ADR Decision Summary**: Input Actions for mouse look (mouse_filter = PASS on Camera3D, not on Control nodes). Mouse capture/release managed by game state (not by player controller). Mouse delta applied to Camera3D rotation via _input_event().

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure, static typing.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Camera3D.rotation_degrees (not rotation) for Euler-angle access. Mouse capture via Input.set_mouse_mode() — Web platform constraint: mouse lock requires user gesture. FOV via Camera3D.fov (exported property).

**Control Manifest Rules (Foundation layer)**:
- Required: CharacterBody3D for all physical bodies
- Required: Static typing on all class members
- Guardrail: Frame budget 16.6ms — camera rotation must not add CPU overhead

---

## Acceptance Criteria

*From GDD `design/gdd/first-person-controller.md`, scoped to this story:*

- [ ] AC5: Mouse look — camera rotates with mouse movement; horizontal rotation parented to player body (Y-axis), vertical rotation on camera node (X-axis)
- [ ] AC6: Camera FOV squash effect during sprint — FOV briefly increases then returns to normal

---

## Implementation Notes

*Derived from ADR-0008 Implementation Guidelines:*

```gdscript
# PlayerController.gd — camera handling

@onready var camera: Camera3D = $Camera3D
@onready var head: Node3D = $Head  # Y-axis rotation parent for horizontal look

const MOUSE_SENSITIVITY: float = 0.002
const FOV_NORMAL: float = 70.0
const FOV_SPRINT: float = 80.0
const FOV_SQUASH_DURATION: float = 0.15

var current_fov: float = FOV_NORMAL

func _ready() -> void:
    camera.fov = FOV_NORMAL

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
        # Clamp vertical rotation to prevent flip
        camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

func _on_sprint_state_changed(is_sprinting: bool) -> void:
    if is_sprinting:
        _trigger_fov_squash()

func _trigger_fov_squash() -> void:
    # Simple tween for FOV increase and return
    var tween = create_tween()
    tween.tween_property(camera, "fov", FOV_SPRINT, 0.05)
    tween.tween_property(camera, "fov", FOV_NORMAL, FOV_SQUASH_DURATION)
```

- Head node (Node3D) is Y-axis rotation parent between CharacterBody3D root and Camera3D
- Mouse delta via `_unhandled_input()` (not `_input()`) — follows ADR-0008 pattern
- Vertical rotation clamped to ±89 degrees (prevent over-rotation)
- FOV squash: tween to higher FOV then back (0.05s up, 0.15s down)
- Web platform: mouse capture requires user click/interaction — game state manages capture lifecycle

*Derived from ADR-0006 Implementation Guidelines:*

- File: `src/core/player/player_controller.gd` (append to existing file)
- Static typing: All nodes typed with `@onready var camera: Camera3D`
- No Autoload access

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 005]: Key rebinding for mouse look (settings)
- [Story 006]: Camera shake (separate from FOV squash)
- [Story 004]: Interaction raycast (uses camera direction but separate system)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-5**: Mouse look behavior
  - Setup: PlayerController scene loaded, mouse captured
  - Verify: Moving mouse right → head rotates positive Y; moving mouse up → camera rotates negative X
  - Pass condition: Horizontal rotation persists across frames; vertical rotation clamped at ±89 degrees; camera follows head rotation

- **AC-6**: FOV squash during sprint
  - Setup: Player in sprint state
  - Verify: Camera FOV increases to FOV_SPRINT (80.0) then returns to FOV_NORMAL (70.0)
  - Pass condition: FOV completes full squash cycle within 0.2 seconds; FOV returns to 70.0 after cycle

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: `production/qa/evidence/camera-mouse-look-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (needs Camera3D node structure)
- Unlocks: None directly (camera direction used by Story 004 raycast)
