# Story 006: Camera Shake

> **Epic**: First-Person Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-MOV-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 (Rendering)
**ADR Decision Summary**: VFX via node transforms (Camera3D position offset), not compute shaders. Forward+ rendering. Web performance budgets apply.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Camera shake triggered by signal from player sprint state — signal-based, not direct node reference.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: Shake parameters (intensity, frequency) in tuning config — not hardcoded.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Camera3D.position local offset for shake (not rotation — rotation is used for mouse look). Use Tween for smooth return to rest position. No ParticleProcessMaterial for camera-level VFX (too expensive). Per-frame _process() with sine wave for shake is acceptable for single-camera effect.

**Control Manifest Rules (Foundation layer)**:
- Guardrail: Camera shake must not interfere with mouse-look responsiveness
- Guardrail: Shake must complete within frame budget (no persistent CPU load)

---

## Acceptance Criteria

*From GDD `design/gdd/first-person-controller.md`, scoped to this story:*

- [ ] AC10: Camera shake during sprint — shake intensity and frequency curve defined; shake intensity proportional to sprint speed

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

```gdscript
# PlayerController.gd — camera shake during sprint

@onready var camera: Camera3D = $Camera3D

const SHAKE_INTENSITY_BASE: float = 0.01
const SHAKE_FREQUENCY: float = 12.0
const SHAKE_DECAY_TIME: float = 0.3

var shake_intensity: float = 0.0
var shake_timer: float = 0.0

func _process(delta: float) -> void:
    if is_sprinting and shake_intensity > 0.0:
        var offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
        camera.position = Vector3(offset.x, offset.y, 0.0)
        shake_timer -= delta
        if shake_timer <= 0.0:
            shake_timer = 1.0 / SHAKE_FREQUENCY
    else:
        # Decay shake to zero
        if shake_intensity > 0.0:
            shake_intensity = maxf(shake_intensity - delta * 2.0, 0.0)
            var offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
            camera.position = Vector3(offset.x, offset.y, 0.0)
        else:
            camera.position = Vector3.ZERO

func _on_sprint_state_changed(is_sprinting: bool) -> void:
    if is_sprinting:
        shake_intensity = SHAKE_INTENSITY_BASE
        shake_timer = 0.0
    # When sprinting stops, shake decays naturally in _process()
```

- Camera shake via local position offset (not rotation) — avoids conflict with mouse-look
- Random offset each frame within shake_intensity radius
- Frequency controls how often offset is recalculated (12Hz — not every frame, reduces jitter)
- Intensity decays when sprint stops (2.0 decay rate — adjustable tuning knob)
- Parameters exposed as @export for tuning: SHAKE_INTENSITY_BASE, SHAKE_FREQUENCY, SHAKE_DECAY_TIME

*Derived from ADR-0003 Implementation Guidelines:*

- Signal `_on_sprint_state_changed()` emitted by sprint/crouch logic (Story 002)
- PlayerController connects to its own signal in _ready()

*Derived from ADR-0004 Implementation Guidelines:*

- Shake parameters should be moved to a tuning resource (.tres) when the tuning system is implemented
- For now, @export constants are acceptable (data-driven via Godot inspector)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: Camera FOV squash (separate effect, triggered by same sprint state)
- [Visual Effects Epic]: Anomaly glow, monster reveal VFX, sanity distortion (later epics)
- [Player Survival Epic]: Sanity-based visual distortion (later epic)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-10**: Camera shake during sprint
  - Setup: Player enters sprint state
  - Verify: Camera position oscillates with random offset proportional to SHAKE_INTENSITY_BASE
  - Pass condition: Shake visible during sprint; shake decays smoothly within ~0.5s after sprint stops; shake does not interfere with mouse-look (mouse movement still rotates camera correctly)

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: `production/qa/evidence/camera-shake-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (needs camera reference), Story 002 must be DONE (needs sprint state signal)
- Unlocks: None — this is a parallel polish task
