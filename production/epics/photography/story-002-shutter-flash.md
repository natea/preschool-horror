# Story 002: Shutter Mechanics and Flash

> **Epic**: Photography
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/photography-system.md` (Shutter Mechanics, Flash Mechanics sections)
**Requirement**: `TR-PHO-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (Input)
**ADR Decision Summary**: Shutter trigger via LMB/RT input actions. State-based input routing via GameplayInputHandler. Guard checks evaluated before shutter fires.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: FLASH_RECHARGE_TIME (3.0s), FLASH_RANGE (8.0m), FLASH_ENERGY (3.0), FLASH_AFFECT_RADIUS (10.0m) from TuningKnobs. FILM_TABLE per night from NightConfig. No hardcoded flash or film values.

**ADR Governing Implementation**: ADR-0009 (Audio)
**ADR Decision Summary**: Flash SFX via AudioManager → SFX_World bus. Shutter sound variant per horror tier. "NO FLASH" and empty-click audio cues. All audio preloaded via `preload()`, spatial SFX auto-free.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: SubViewport capture via `SubViewport.get_texture().get_image()`. OmniLight3D enabled for 1 frame via `light_enabled = true` followed by `call_deferred("set", "light_enabled", false)`. Flash recharge uses `delta` accumulation, not `Time.get_ticks_msec()`.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Forbidden: Never create AudioStreamPlayer outside AudioManager

---

## Acceptance Criteria

*From GDD `design/gdd/photography-system.md`, scoped to this story:*

- [ ] AC-PHO-05: GIVEN the viewfinder is active with `film_remaining > 0` and flash fully charged, WHEN LMB is pressed, THEN a PhotoRecord is created, `film_remaining` decrements by 1, flash fires (OmniLight3D pulses for 1 frame), and the SubViewport captures the flash-lit scene.

- [ ] AC-PHO-06: GIVEN the viewfinder is active with `film_remaining > 0` and flash recharging (`charge < 1.0`), WHEN LMB is pressed, THEN a PhotoRecord is created WITHOUT flash illumination, the "NO FLASH" indicator appears for 0.5s, and `flash_fired_at_monster` does NOT emit.

- [ ] AC-PHO-07: GIVEN `film_remaining == 0`, WHEN LMB is pressed, THEN no photo is captured, no flash fires, the empty-click audio plays, and the film counter flashes warning.

- [ ] AC-PHO-08: GIVEN the flash just fired, WHEN 3.0s elapse, THEN `flash_charge` reaches 1.0 (±0.1s) and the HUD flash charge arc shows all 8 segments lit.

---

## Implementation Notes

*Derived from ADR-0008 Input + ADR-0004 Data-Driven + ADR-0009 Audio + GDD Shutter/Flash:*

```gdscript
# photography_system.gd — Shutter and Flash logic (extends Story 001 base)

# Tuning knobs (loaded in _ready from TuningKnobs resource)
var flash_recharge_time: float = 3.0
var flash_range: float = 8.0
var flash_energy: float = 3.0
var flash_affect_radius: float = 10.0

# Runtime state
var flash_charge: float = 1.0  # 0.0–1.0, starts fully charged
var film_remaining: int = 12
var photos_this_night: Array[PhotoRecord] = []
var current_state: StringName = "INACTIVE"  # INACTIVE | VIEWFINDER_ACTIVE | CAPTURING | PHOTO_PREVIEW

# Flash recharge (runs every frame, independent of Photography state)
func _physics_process(delta: float) -> void:
    if flash_charge < 1.0:
        flash_charge = min(1.0, flash_charge + delta / flash_recharge_time)
        flash_charge_changed.emit(flash_charge)

# Shutter handler (called by GameplayInputHandler on LMB/RT)
func _on_shutter_input() -> void:
    # Guard checks — fail silently
    if current_state == "PHOTO_PREVIEW" or current_state == "CAPTURING":
        return  # Preview active or shutter already processing
    if film_remaining <= 0:
        _on_film_exhausted()
        return  # No film — blocked

    # Transition to CAPTURING (single-frame transient)
    current_state = "CAPTURING"

    # Step 1: Capture shutter state
    var shutter_transform := camera.global_transform
    var shutter_fov := camera.fov
    var zoom_level := zoom_levels[current_zoom_idx]

    # Step 2: Decrement film
    film_remaining -= 1
    film_remaining_changed.emit(film_remaining)

    # Step 3: Fire flash if charged
    var flash_active := flash_charge >= 1.0
    if flash_active:
        _fire_flash(shutter_transform.origin)
    else:
        _show_no_flash_indicator()

    # Step 4: Evaluate photo against anomalies
    var results := anomaly_system.evaluate_photo(shutter_transform, shutter_fov)
    var detected := results.filter(func(r): return r.detected and r.photo_score >= 0.15)

    # Step 5: Capture SubViewport
    var image := subviewport.get_texture().get_image()

    # Step 6: Create PhotoRecord
    var photo := _create_photo_record(image, detected, shutter_transform, shutter_fov,
                                       flash_active, zoom_level)
    photos_this_night.append(photo)

    # Step 7: Emit signals
    photo_captured.emit(photo)
    for result in detected:
        anomaly_system.anomaly_photographed.emit(result.anomaly_instance, result.photo_score)

    # Step 8: Transition to PHOTO_PREVIEW
    current_state = "PHOTO_PREVIEW"
    photo_preview_started.emit(photo)

    # Step 9: Schedule preview end
    await get_tree().create_timer(preview_duration).timeout
    if camera_raised:
        current_state = "VIEWFINDER_ACTIVE"
        photo_preview_ended.emit()
    else:
        current_state = "INACTIVE"
        photo_preview_ended.emit()

# Flash fire (1-frame OmniLight3D pulse)
func _fire_flash(position: Vector3) -> void:
    flash_fired.emit(position, flash_energy)
    # OmniLight3D at camera position
    flash_light.position = position
    flash_light.light_energy = flash_energy
    flash_light.light_range = flash_range
    flash_light.enabled = true
    flash_light.call_deferred("set", "enabled", false)

    # Check for affected monsters (ADR-0002: PhysicsDirectSpaceState3D for LOS)
    var space_state := get_world_3d().direct_space_state
    for monster in _get_monsters_in_radius(position, flash_affect_radius):
        var query := PhysicsRayQueryParameters3D.create(position, monster.detection_center)
        var hit := space_state.intersect_ray(query)
        if hit.is_empty() or hit.position == monster.detection_center:
            flash_fired_at_monster.emit(monster, position.distance_to(monster.detection_center))

    # Reset flash charge
    flash_charge = 0.0
    flash_charge_changed.emit(0.0)

# Film exhausted handler
func _on_film_exhausted() -> void:
    film_exhausted.emit()
    # Audio: hollow click via AudioManager → SFX_World bus
    audio_manager.play_sfx(empty_click_sound, spatial = false)
    # HUD: film counter flashes in Semantic Yellow at 0.5 Hz
```

*State machine transitions:*

| From | To | Trigger | Guard |
|------|------|---------|-------|
| INACTIVE | VIEWFINDER_ACTIVE | `camera_raised == true` | Player state Normal or Camera Raised |
| VIEWFINDER_ACTIVE | INACTIVE | `camera_raised == false` | Always immediate |
| VIEWFINDER_ACTIVE | CAPTURING | LMB/RT pressed | `film_remaining > 0` AND not in PHOTO_PREVIEW |
| CAPTURING | PHOTO_PREVIEW | Capture complete (same frame) | Always — CAPTURING is single-frame transient |
| PHOTO_PREVIEW | VIEWFINDER_ACTIVE | `preview_duration` elapsed | Camera still raised |
| PHOTO_PREVIEW | INACTIVE | `camera_raised == false` | RMB released during preview |
| Any | INACTIVE | `player_killed` / `cutscene_start` / `night_loading_started` | Forced override |

*CAPTURING is transient:* Steps above execute synchronously within one physics frame. No player-visible time in CAPTURING.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Camera raise/lower and zoom (prerequisite, already designed)
- [Story 003]: Photo scoring and grading (consumes PhotoRecord, doesn't create it)
- [Story 004]: Night evidence score computation (aggregate, not per-photo)
- [Story 006]: Photo preview visual rendering (consumes PhotoRecord for display)
- [Story 007]: Flash-monster interaction detail (basic version here; full interaction in Story 007)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PHO-05**: Full shutter with flash
  - Given: Viewfinder active, film_remaining = 5, flash_charge = 1.0
  - When: Press LMB
  - Then: PhotoRecord created with flash_active=true; film_remaining decremented to 4; OmniLight3D enabled for 1 frame; SubViewport captures flash-lit scene; photo_captured(signal) emitted; CAPTURING → PHOTO_PREVIEW transition
  - Edge cases: flash_charge = 0.99 → no flash (below threshold); film_remaining = 1 → decrements to 0, triggers film_exhausted; shutter during PHOTO_PREVIEW → blocked, no action

- **AC-PHO-06**: Shutter without flash
  - Given: Viewfinder active, film_remaining = 3, flash_charge = 0.5
  - When: Press LMB
  - Then: PhotoRecord created with flash_active=false; "NO FLASH" indicator appears for 0.5s; flash_fired_at_monster does NOT emit; flash_charge remains 0.5 (unchanged — no-fire means no-reset)
  - Edge cases: flash_charge = 0.0 → same behavior as 0.5; dark room photo → stored but darker (no illumination); flash_charge = 1.0001 → still fires flash (clamped to 1.0)

- **AC-PHO-07**: Film exhausted
  - Given: film_remaining = 0
  - When: Press LMB
  - Then: No PhotoRecord created; no flash fires; empty-click audio plays (via AudioManager → SFX_World); film counter flashes in Semantic Yellow at 0.5 Hz; current_state unchanged (stays in whatever state it was)
  - Edge cases: rapid LMB spam → empty-click plays each time; lower camera while film = 0 → film_exhausted does NOT re-emit; night restart → film_remaining reset to budget, film_exhausted cleared

- **AC-PHO-08**: Flash recharge timing
  - Given: Flash just fired (flash_charge = 0.0)
  - When: Wait 3.0s
  - Then: flash_charge = 1.0 (±0.1s); HUD shows all 8 segments lit
  - Edge cases: lower and re-raise camera → flash_charge persists (does NOT reset); flash fires at 2.9s → charge at ~0.97, next shot has no flash; flash fires at 3.1s → charge = 1.0 (clamped), full flash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/photography/shutter_flash_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Camera Viewfinder) must be DONE — shutter requires `camera_raised` signal
- Unlocks: Story 003 (Photo Scoring — consumes PhotoRecord), Story 006 (Photo Preview — consumes PhotoRecord)
