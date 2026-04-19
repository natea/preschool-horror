# Story 001: Camera Viewfinder Activation

> **Epic**: Photography
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/photography-system.md` (Camera Activation, Camera Optics sections)
**Requirement**: `TR-PHO-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (Input)
**ADR Decision Summary**: Camera raise/lower via `camera_raised` signal from FPC (RMB held/released). Input Actions defined in project settings. State-based input routing via GameplayInputHandler.

**ADR Governing Implementation**: ADR-0002 (Physics)
**ADR Decision Summary**: Camera is a Camera3D node (child of player head bone). FOV changes via `Camera3D.fov` property. Zoom via discrete FOV steps (70° → 47° → 35°).

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: FOV_BASE (70°), ZOOM_LEVELS ([1.0, 1.5, 2.0]), ZOOM_TRANSITION_TIME (0.15s) from TuningKnobs. No hardcoded FOV values.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Camera3D.fov` is verified in Godot 4.6 docs. Zoom transition uses `lerp_angle()` or `tween_property` for FOV interpolation. Viewfinder CanvasLayer appears/disappears instantaneously (no animation delay on camera raise).

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/photography-system.md`, scoped to this story:*

- [ ] AC-PHO-01: GIVEN the player is in Normal state, WHEN RMB is held, THEN the viewfinder activates within 1 frame (no animation delay) and `camera_raised == true` propagates to all consuming systems.

- [ ] AC-PHO-02: GIVEN the viewfinder is active at 1.0x zoom, WHEN the player scrolls up, THEN the FOV interpolates from 70° to 47° over 0.15s (±0.02s).

- [ ] AC-PHO-03: GIVEN the viewfinder is active at 2.0x zoom, WHEN the player scrolls up, THEN the FOV returns to 70° (1.0x, cycle wraps).

- [ ] AC-PHO-04: GIVEN the viewfinder is active, WHEN the player releases RMB, THEN zoom resets to 1.0x immediately and the viewfinder deactivates.

---

## Implementation Notes

*Derived from ADR-0008 Input + ADR-0002 Physics + GDD Camera Optics:*

```gdscript
# photography_system.gd — Core Photography logic
class_name PhotographySystem extends Node

# Signals to HUD/UI
signal camera_raised_changed(raised: bool)
signal zoom_level_changed(level: float)
signal flash_charge_changed(charge: float)

# Tuning knobs (from TuningKnobs resource, loaded in _ready)
var fov_base: float = 70.0
var zoom_levels: Array[float] = [1.0, 1.5, 2.0]
var zoom_transition_time: float = 0.15

# Runtime state
var current_zoom_idx: int = 0
var current_fov: float = 70.0
var camera_raised: bool = false

func _ready() -> void:
    # Load tuning knobs
    var knobs := load("res://assets/config/tuning_knobs.tres") as TuningKnobs
    fov_base = knobs.fov_base
    zoom_levels = knobs.zoom_levels
    zoom_transition_time = knobs.zoom_transition_time

func _on_fpc_camera_raised(raised: bool) -> void:
    camera_raised = raised
    camera_raised_changed.emit(raised)

    if raised:
        current_zoom_idx = 0  # Reset to 1.0x on raise
        _set_fov(fov_base)
    else:
        current_zoom_idx = 0
        _set_fov(fov_base)

func _on_zoom_input(direction: int) -> void:
    if not camera_raised:
        return
    current_zoom_idx = wrapi(current_zoom_idx + direction, 0, zoom_levels.size())
    var target_zoom := zoom_levels[current_zoom_idx]
    _tween_fov(fov_base / target_zoom)
    zoom_level_changed.emit(target_zoom)

func _set_fov(target: float) -> void:
    current_fov = target
    # camera is set by FPC — Photography provides the target FOV value
    # FPC applies it to the Camera3D node

func _tween_fov(target_fov: float) -> void:
    # Smooth FOV interpolation over zoom_transition_time
    var start_fov := current_fov
    var tween := create_tween()
    tween.tween_property(self, "_interpolated_fov", target_fov, zoom_transition_time)
    tween.tween_callback(func(): pass)  # No callback needed — FPC reads current_fov each frame

# Internal setter for tween
var _interpolated_fov: float
func _set_interpolated_fov(value: float) -> void:
    current_fov = value
    # FPC reads current_fov and applies to Camera3D.fov
```

*Viewfinder CanvasLayer lifecycle:*
- On `camera_raised == true`: set `CanvasLayer.modulate.a = 1.0` (instant, no fade)
- On `camera_raised == false`: set `CanvasLayer.modulate.a = 0.0` (instant)
- HUD/UI owns the CanvasLayer; Photography emits `camera_raised_changed` signal
- HUD/UI subscribes to the signal and toggles the viewfinder visibility

*Zoom FOV formula:*
- `zoom_fov = FOV_BASE / zoom_level`
- 1.0x → 70°, 1.5x → 47°, 2.0x → 35°
- Values are computed, not stored — avoids stale state

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Shutter and flash mechanics (camera raise is prerequisite, not shutter)
- [Story 004]: Anomaly lock (uses zoom data but is separate logic)
- HUD/UI: Viewfinder rendering (consumes Photography signals, doesn't evaluate them)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PHO-01**: Instant viewfinder activation
  - Setup: Player in Normal state, camera_raised = false
  - Action: Hold RMB (camera_raised transitions to true)
  - Verify: Viewfinder CanvasLayer visible within 1 frame; camera_raised_changed(true) emitted; consuming systems (HUD, AnomalySystem) receive signal within same frame
  - Edge cases: player in Running state → FPC blocks camera raise, Photography never receives camera_raised=true; player in Dead state → forced INACTIVE regardless; rapid RMB spam → each transition processes independently, no debounce

- **AC-PHO-02**: Zoom 1.0x → 1.5x FOV transition
  - Setup: Viewfinder active at 1.0x (FOV = 70°)
  - Action: Scroll up
  - Verify: FOV interpolates from 70° to 47° over 0.15s (±0.02s); zoom_level_changed(1.5) emitted; HUD zoom indicator updates to 1.5x
  - Edge cases: scroll during transition → cancels current tween, starts new one to next zoom level; zoom at exactly 0.13s or 0.17s → within tolerance band

- **AC-PHO-03**: Zoom 2.0x → 1.0x cycle wrap
  - Setup: Viewfinder active at 2.0x (FOV = 35°)
  - Action: Scroll up
  - Verify: FOV returns to 70° (1.0x); zoom_level_changed(1.0) emitted; zoom indicator shows 1.0x
  - Edge cases: scroll down from 1.0x → wraps to 2.0x (reverse cycle); all zoom levels cycle: 1.0 → 1.5 → 2.0 → 1.0 → 2.0 → 1.0

- **AC-PHO-04**: Camera lower resets zoom
  - Setup: Viewfinder active at 2.0x zoom
  - Action: Release RMB
  - Verify: Zoom resets to 1.0x immediately (not over time); viewfinder deactivates (CanvasLayer hidden); camera_raised_changed(false) emitted
  - Edge cases: lower during zoom transition → zoom resets instantly (aborts tween); lower during PHOTO_PREVIEW → preview cancels (handled by Story 004 logic)

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: `production/qa/evidence/photo-viewfinder-evidence.md` — screenshot of viewfinder at each zoom level + timing verification

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: First-Person Controller must be DONE (camera_raised signal source), HUD/UI System must be DONE (viewfinder CanvasLayer rendering)
- Unlocks: Story 002 (shutter requires viewfinder active), Story 004 (lock detection requires viewfinder active)
