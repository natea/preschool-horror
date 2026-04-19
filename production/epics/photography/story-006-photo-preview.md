# Story 006: Photo Preview

> **Epic**: Photography
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/photography-system.md` (Photo Preview section)
**Requirement**: `TR-PHO-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `photo_preview_started(record)` and `photo_preview_ended` signals. HUD/UI switches viewfinder between live feed and static captured Image.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: PREVIEW_DURATION (1.5s) from TuningKnobs. Fixed value, not score-dependent. Grade stamp styling from HUD/UI GDD.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `await get_tree().create_timer(preview_duration).timeout` for non-interruptible countdown. SubViewport texture displayed via `TextureRect` on HUD/UI CanvasLayer. Grade stamp rendering in HUD/UI (Photography provides the grade on PhotoRecord). Player movement UNFROZEN during preview (1.5 m/s camera-raised speed).

**Control Manifest Rules (Core layer)**:
- Required: PREVIEW_DURATION in TuningKnobs, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/photography-system.md`, scoped to this story:*

- [ ] AC-PHO-18: GIVEN a photo is captured, WHEN PHOTO_PREVIEW state activates, THEN the viewfinder shows the captured Image (not live feed) for 1.5s (±0.1s), the grade stamp appears at t=0.3s, and the player can still move at 1.5 m/s.

- [ ] AC-PHO-19: GIVEN the player is in PHOTO_PREVIEW, WHEN RMB is released, THEN the preview cancels immediately, the viewfinder deactivates, and the photo remains stored.

- [ ] AC-PHO-20: GIVEN the player is in PHOTO_PREVIEW, WHEN LMB is pressed, THEN nothing happens (shutter blocked during preview).

---

## Implementation Notes

*Derived from ADR-0003 Communication + ADR-0004 Data-Driven + GDD Photo Preview:*

**Preview state machine:**
```gdscript
# photography_system.gd

var preview_duration: float = 1.5

func _on_shutter_complete(photo: PhotoRecord) -> void:
    # Transition to PHOTO_PREVIEW
    current_state = "PHOTO_PREVIEW"
    photo_preview_started.emit(photo)

    # Non-interruptible countdown (movement continues)
    await get_tree().create_timer(preview_duration).timeout

    if camera_raised:
        current_state = "VIEWFINDER_ACTIVE"
        photo_preview_ended.emit()
    else:
        current_state = "INACTIVE"
        photo_preview_ended.emit()

func _on_camera_raised(raised: bool) -> void:
    camera_raised = raised
    camera_raised_changed.emit(raised)

    if not raised:
        # Camera lowered — cancel preview if active
        if current_state == "PHOTO_PREVIEW":
            current_state = "VIEWFINDER_ACTIVE" if camera_raised else "INACTIVE"
            photo_preview_ended.emit()
        elif current_state == "VIEWFINDER_ACTIVE":
            current_state = "INACTIVE"

func _on_shutter_input() -> void:
    # Guard: blocked during preview
    if current_state == "PHOTO_PREVIEW":
        return  # Shutter blocked — do nothing
    # ... rest of shutter logic
```

**HUD/UI consumption:**
```gdscript
# hud_viewfinder.gd — HUD/UI System

var preview_active := false
var preview_image: Image
var preview_grade: StringName

func _ready() -> void:
    photography.photo_preview_started.connect(_on_photo_preview_started)
    photography.photo_preview_ended.connect(_on_photo_preview_ended)

func _on_photo_preview_started(photo: PhotoRecord) -> void:
    preview_active = true
    preview_image = photo.image
    preview_grade = photo.grade
    viewfinder_mode = "PREVIEW"  # Switch TextureRect from camera feed to photo
    grade_stamp.visible = false   # Hide initially — appears at t=0.3s
    start_grade_stamp_timer()

func _on_photo_preview_ended() -> void:
    preview_active = false
    viewfinder_mode = "LIVE"
    grade_stamp.visible = false

func start_grade_stamp_timer() -> void:
    await get_tree().create_timer(0.3).timeout
    if preview_active:
        grade_stamp.visible = true
        grade_stamp.grade = preview_grade
```

**Key design points:**
- Player is NOT frozen during preview (movement at 1.5 m/s, mouse-look active)
- Viewfinder shows static photo, not live camera feed
- Grade stamp appears at t=0.3s (not instant — brief suspense)
- Preview is NOT interruptible by shutter (LMB does nothing)
- Preview IS interruptible by camera lower (RMB releases)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Shutter and capture (creates the photo that gets previewed)
- [Story 003]: Grade computation (PhotoRecord.grade is already computed)
- HUD/UI: Grade stamp visual rendering (follows HUD/UI GDD styling)
- [Story 001]: Viewfinder CanvasLayer lifecycle (separate from preview display)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PHO-18**: Preview display
  - Given: Photo captured (grade = "B", image available)
  - When: PHOTO_PREVIEW state activates
  - Then: Viewfinder shows captured Image (not live feed); grade stamp "B" appears at t=0.3s into preview; player movement continues at 1.5 m/s; mouse-look continues (looking around shows static photo, not live view)
  - Edge cases: grade = "A" → stamp in `#48B04A`; grade = "F" (no anomaly) → no stamp appears; grade = "C" → stamp in `#F5C842`; preview duration = 1.5s ± 0.1s (1.4s–1.6s); grade stamp appears exactly at t=0.3s (±0.05s)

- **AC-PHO-19**: Preview cancel on camera lower
  - Given: Player in PHOTO_PREVIEW (0.8s into 1.5s preview)
  - When: Release RMB (camera_raised = false)
  - Then: Preview cancels immediately (not waiting for full 1.5s); viewfinder deactivates (INACTIVE state); photo REMAINS in photos_this_night (not deleted); photo_captured was already emitted at capture time, not affected by cancel
  - Edge cases: lower at t=0.05s → preview shows for only 0.05s (grade stamp barely visible); lower at t=1.49s → preview shows for almost full duration; grade stamp already visible → disappears immediately; grade stamp not yet visible → never appears

- **AC-PHO-20**: Shutter blocked during preview
  - Given: Player in PHOTO_PREVIEW
  - When: Press LMB
  - Then: Nothing happens — no photo captured, no flash fires, no state change, no signals emitted
  - Edge cases: rapid LMB spam → each press silently ignored; camera still raised → state stays PHOTO_PREVIEW; film_remaining = 0 → same behavior (blocked for both reasons)

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: `production/qa/evidence/photo-preview-evidence.md` — screenshot of preview with grade stamp + timing verification

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Shutter — creates the photo that gets previewed), Story 003 (Photo Scoring — computes the grade shown in preview)
- Unlocks: HUD/UI System (viewfinder preview display), Evidence Submission (photo stored before preview ends)
