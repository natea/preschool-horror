# Story 005: Anomaly Lock Detection

> **Epic**: Photography
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/photography-system.md` (Anomaly Lock section)
**Requirement**: `TR-PHO-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Physics)
**ADR Decision Summary**: Lock detection uses `evaluate_photo(camera_transform, camera_fov)` from Anomaly System. Frustum check via Camera3D projection. Distance and facing computed from camera global_transform.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `anomaly_locked_changed(locked, anomaly)` signal emitted on state change (not every frame). HUD/UI subscribes to signal for viewfinder corner bracket updates.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: LOCK_THRESHOLD (0.30) from TuningKnobs. Higher than PHOTO_SCORE_THRESHOLD (0.15) to indicate "good" framing.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `evaluate_photo()` called every physics frame while viewfinder active. Must be budget-limited. Anomaly System's pipeline uses early-exit checks (room → frustum → distance → occlusion → facing). Typical frame: 3–12 anomalies evaluated, most culled at room/frustum stage. Performance target: < 1.0ms per evaluation cycle.

**Control Manifest Rules (Core layer)**:
- Required: LOCK_THRESHOLD in TuningKnobs, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: All gameplay values in Resources, never hardcoded
- Guardrail: evaluate_photo() must complete within 1.0ms for 8 active anomalies

---

## Acceptance Criteria

*From GDD `design/gdd/photography-system.md`, scoped to this story:*

- [ ] AC-PHO-16: GIVEN the viewfinder is active and an anomaly has `photo_score >= LOCK_THRESHOLD`, WHEN the anomaly is centered in frame, THEN `anomaly_locked_changed(true, anomaly)` fires and the viewfinder corner brackets change to Unnatural White `#F0F0FF`.

- [ ] AC-PHO-17: GIVEN anomaly lock is active, WHEN the player pans away until `photo_score` drops below LOCK_THRESHOLD, THEN `anomaly_locked_changed(false, null)` fires and corner brackets return to `#D4C8A0` with no fade transition.

---

## Implementation Notes

*Derived from ADR-0002 Physics + ADR-0003 Communication + GDD Anomaly Lock:*

**Lock detection (every physics frame while viewfinder active):**
```gdscript
# photography_system.gd

var anomaly_locked: bool = false
var locked_anomaly: Node = null
var lock_threshold: float = 0.30

func _physics_process(delta: float) -> void:
    if not camera_raised or current_state == "INACTIVE":
        return

    # Evaluate all anomalies against current camera state
    var results := anomaly_system.evaluate_photo(camera.global_transform, camera.fov)

    # Find best-scoring anomaly that passes lock threshold
    var best_anomaly := null
    var best_score := 0.0
    for result in results:
        if result.detected and result.photo_score >= lock_threshold:
            if result.photo_score > best_score:
                best_score = result.photo_score
                best_anomaly = result.anomaly_instance

    var new_locked := best_anomaly != null

    # Only emit signal on STATE CHANGE (not every frame)
    if new_locked and not anomaly_locked:
        anomaly_locked = true
        locked_anomaly = best_anomaly
        anomaly_locked_changed.emit(true, best_anomaly)
    elif not new_locked and anomaly_locked:
        anomaly_locked = false
        locked_anomaly = null
        anomaly_locked_changed.emit(false, null)
```

**HUD consumption (signal handler):**
```gdscript
# hud_viewfinder.gd — HUD/UI System

func _ready() -> void:
    photography.photo_locked_changed.connect(_on_anomaly_locked_changed)

func _on_anomaly_locked_changed(locked: bool, anomaly: Node) -> void:
    if locked:
        corner_brackets.modulate = Color("#F0F0FF")  # Unnatural White
        inner_frame_pulse_active = true
    else:
        corner_brackets.modulate = Color("#D4C8A0")  # Warm cream
        inner_frame_pulse_active = false
```

**Performance note:** `evaluate_photo()` must use early-exit checks. The Photography System does NOT implement its own frustum/distance/facing checks — it delegates entirely to the Anomaly System's pipeline.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Camera viewfinder activation (prerequisite — lock requires `camera_raised`)
- [Story 002]: Shutter mechanics (lock is advisory, not shutter-gating)
- [Story 003]: Photo scoring (lock uses the same scoring formula but at a lower threshold)
- Anomaly System: `evaluate_photo()` implementation (Photography calls it, Anomaly implements it)
- HUD/UI: Corner bracket rendering (consumes the signal, does not evaluate lock)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PHO-16**: Lock acquired
  - Given: Viewfinder active, anomaly with photo_score = 0.45 (≥ LOCK_THRESHOLD 0.30) centered in frame
  - When: Lock detection runs (next physics frame)
  - Then: `anomaly_locked` = true; `locked_anomaly` = anomaly instance; `anomaly_locked_changed(true, anomaly)` emitted; corner brackets change to `#F0F0FF` instantly (no fade)
  - Edge cases: photo_score exactly 0.30 → lock acquired (≥ threshold); photo_score = 0.299 → no lock; multiple anomalies above threshold → highest-scoring one locked; anomaly moves in/out of frame during frame → lock state follows current frame's evaluation

- **AC-PHO-17**: Lock lost
  - Given: Anomaly lock active (anomaly centered, score = 0.45)
  - When: Player pans away until photo_score drops below 0.30
  - Then: `anomaly_locked` = false; `locked_anomaly` = null; `anomaly_locked_changed(false, null)` emitted; corner brackets return to `#D4C8A0` instantly
  - Edge cases: pan back into frame → lock re-acquired on next frame (not a one-time lock); rapid pan in/out → lock toggles each frame (signal emitted each state change, not every frame); anomaly moves away (not player) → same behavior as player panning

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/photography/anomaly_lock_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Camera Viewfinder — lock requires `camera_raised`), Anomaly System must be DONE (provides `evaluate_photo()`)
- Unlocks: HUD/UI System (viewfinder corner bracket rendering)
