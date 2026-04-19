# Story 007: Film Budget and Flash-Monster Interaction

> **Epic**: Photography
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/photography-system.md` (Film Budget, Flash and Monsters sections)
**Requirement**: `TR-PHO-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `flash_fired_at_monster(instance, distance)` signal for Monster AI consumption. `night_loading_started(n)` from Night Progression triggers film/flash/photo reset. Line-of-sight check via `PhysicsDirectSpaceState3D.ray_intersects()` (ADR-0002).

**ADR Governing Implementation**: ADR-0009 (Audio)
**ADR Decision Summary**: Flash SFX via AudioManager → SFX_World bus. Film exhausted warning cue. Shutter sound variant per horror tier. All audio preloaded.

**ADR Governing Implementation**: ADR-0001 (Scene Architecture)
**ADR Decision Summary**: Night lifecycle: `night_loading_started` forces INACTIVE, clears `photos_this_night`, resets `film_remaining` and `flash_charge`. Death forces INACTIVE. Night 7 FINALE blocks camera raise entirely.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Film budget per night from NightConfig (FILM_TABLE lookup). Flash-monster LOS via raycast from camera position to monster detection center. Non-transparent collider blocks flash effect. `night_loading_started(n)` signal from Night Progression. Night 7 FINALE phase checked in FPC (Photography reads FPC's `current_state`).

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Required: No signal chains — each system emits its own distinct signal

---

## Acceptance Criteria

*From GDD `design/gdd/photography-system.md`, scoped to this story:*

- [ ] AC-PHO-21: GIVEN Night 5 is starting, WHEN `night_loading_started(5)` fires, THEN `film_remaining` is set to 8 (per FILM_TABLE[5]).

- [ ] AC-PHO-22: GIVEN the player dies mid-night with 3 film remaining and 5 photos taken, WHEN the night restarts, THEN `film_remaining` resets to the night's full budget and `photos_this_night` is cleared.

- [ ] AC-PHO-23: GIVEN a Doll monster is 6m away with line-of-sight, WHEN the flash fires, THEN `flash_fired_at_monster(doll_instance, 6.0)` emits and Monster AI can process its flash reaction.

- [ ] AC-PHO-24: GIVEN a Shadow monster is 8m away but behind a wall (no line-of-sight), WHEN the flash fires, THEN `flash_fired_at_monster` does NOT emit for that monster.

---

## Implementation Notes

*Derived from ADR-0003 Communication + ADR-0001 Scene Architecture + ADR-0009 Audio + GDD Film/Monster:*

**Film budget integration:**
```gdscript
# photography_system.gd

# Film budget (loaded from NightConfig at night start)
var film_per_night: int = 12

func _on_night_loading_started(night: int) -> void:
    # Force INACTIVE
    current_state = "INACTIVE"
    camera_raised = false

    # Reset film
    film_per_night = night_progression.get_film_budget(night)
    film_remaining = film_per_night
    film_remaining_changed.emit(film_remaining)

    # Clear photos
    photos_this_night.clear()

    # Reset flash
    flash_charge = 1.0
    flash_charge_changed.emit(1.0)

    # Reset zoom
    current_zoom_idx = 0

    # Clear film exhausted state
    # (signal re-emitted only when transitioning from 1→0)
```

**Flash-monster interaction:**
```gdscript
# photography_system.gd — Flash fire with monster check

func _fire_flash(position: Vector3) -> void:
    # Emit flash SFX
    flash_fired.emit(position, flash_energy)
    audio_manager.play_sfx(flash_sound, spatial = false)

    # OmniLight3D pulse (1 frame)
    flash_light.position = position
    flash_light.light_energy = flash_energy
    flash_light.light_range = flash_range
    flash_light.enabled = true
    flash_light.call_deferred("set", "enabled", false)

    # Check for affected monsters
    var space_state := get_world_3d().direct_space_state
    var monsters := _get_monsters_in_radius(position, flash_affect_radius)

    for monster in monsters:
        # Line-of-sight: raycast from camera to monster detection center
        var query := PhysicsRayQueryParameters3D.create(position, monster.detection_center)
        var hit := space_state.intersect_ray(query)

        # Flash affects monster if ray hits monster OR ray passes through non-opaque collider
        # Non-transparent collider blocks flash
        if hit.is_empty():
            # No hit — clear path to monster
            flash_fired_at_monster.emit(monster, position.distance_to(monster.detection_center))
        elif hit.get("collider") == monster.detection_collider:
            # Ray hit the monster — clear path
            flash_fired_at_monster.emit(monster, position.distance_to(monster.detection_center))
        # else: ray hit something else (wall, etc.) — monster NOT affected

func _get_monsters_in_radius(origin: Vector3, radius: float) -> Array:
    var result := []
    # Query Monster AI for active monsters (or use Area3D overlap)
    for monster in monster_ai.get_active_monsters():
        if monster.detection_center.distance_to(origin) <= radius:
            result.append(monster)
    return result
```

**Night 7 FINALE — camera blocked:**
```gdscript
# photography_system.gd

func _on_fpc_state_changed(new_state: StringName) -> void:
    if new_state == "FINALE":
        current_state = "INACTIVE"
        camera_raised = false
        camera_raised_changed.emit(false)
```

*Note: Night 7 blocking is enforced by FPC (it reads the FINALE state and blocks camera raise). Photography receives `camera_raised = false` and transitions to INACTIVE.*

**Night lifecycle edge cases:**
```gdscript
# photography_system.gd

func _on_player_killed() -> void:
    # Forced INACTIVE — photos from this run will be discarded by Night Progression
    current_state = "INACTIVE"
    camera_raised = false
    camera_raised_changed.emit(false)
    # photos_this_night is NOT cleared here — Night Progression handles it on restart

func _on_night_completed(night: int) -> void:
    # Lock Photography — no more photos after night ends
    # (Photography checks night_completed before allowing shutter)
    pass  # Night Progression signals Evidence Submission to query photos
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Camera viewfinder activation (prerequisite)
- [Story 002]: Shutter mechanics (consumes film_remaining, emits flash_fired)
- [Story 003]: Photo scoring (consumes PhotoRecord)
- [Story 004]: Night evidence score (consumes photos_this_night at DEBRIEF)
- [Story 005]: Anomaly lock detection (uses evaluate_photo)
- [Story 006]: Photo preview (consumes PhotoRecord)
- Night Progression: get_film_budget(n) implementation (owns the FILM_TABLE)
- Monster AI: flash reaction behavior (consumes flash_fired_at_monster signal)
- Evidence Submission: debrief presentation (consumes get_photos_for_submission)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PHO-21**: Night 5 film budget
  - Given: Night 5 starting (FILM_TABLE[5] = 8)
  - When: `night_loading_started(5)` fires
  - Then: film_remaining = 8; film_remaining_changed(8) emitted; photos_this_night cleared; flash_charge = 1.0; current_state = INACTIVE; current_zoom_idx = 0
  - Edge cases: player had camera raised when night started → forced INACTIVE, camera_raised=false emitted; player in PHOTO_PREVIEW → preview cancelled, photo stored; film_remaining was 0 → reset to 8 (player gets fresh film); flash_charge was 0.0 → reset to 1.0

- **AC-PHO-22**: Death restart
  - Given: Player died mid-night with film_remaining = 3, 5 photos taken
  - When: Night restarts (`night_loading_started` fires after death)
  - Then: film_remaining = night's full budget (e.g., 10 for Night 3); photos_this_night cleared (all 5 photos discarded); flash_charge = 1.0; state = INACTIVE
  - Edge cases: death on Night 7 → same reset, but Night 7 has escape sequence (camera blocked anyway); death on Night 1 → film_remaining = 12; photos discarded silently (no signal about discarding)

- **AC-PHO-23**: Flash-monster with line-of-sight
  - Given: Doll monster 6m from camera, clear line-of-sight (no obstacles)
  - When: Flash fires (flash_charge >= 1.0)
  - Then: `flash_fired_at_monster(doll_instance, 6.0)` emitted; Monster AI receives signal and processes flash reaction (freeze, collapse, or orient — per Monster AI GDD); flash_sfx plays via AudioManager
  - Edge cases: exactly at flash_affect_radius boundary (10.0m) → affected (≤ radius, not <); monster at 10.01m → NOT affected; multiple monsters in radius → signal emitted for each independently; monster in PURSUING state → still affected by flash; monster in ATTACKING state → affected (photo detection disabled, but flash reaction still applies)

- **AC-PHO-24**: Flash-monster without line-of-sight
  - Given: Shadow monster 8m from camera, wall between camera and monster
  - When: Flash fires
  - Then: `flash_fired_at_monster` does NOT emit for this monster; raycast hits wall collider before reaching monster; monster does NOT react to flash
  - Edge cases: wall is partially transparent (glass) → depends on collider material property; monster partially behind wall (ray grazes edge) → ray hits monster collider → affected; monster behind two walls → first wall blocks → not affected; flash_range (8.0m) < distance to monster (8m exactly) → monster within range but behind wall → not affected (LOS check is independent of flash_range; both radius AND LOS required)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/photography/film_flash_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Shutter — flash fire), Night Progression must be DONE (provides `get_film_budget(n)` and `night_loading_started` signal), Monster AI must be DONE (consumes `flash_fired_at_monster`), Anomaly System must be DONE (provides `get_active_monsters()` for radius query)
- Unlocks: Evidence Submission (photos ready for DEBRIEF), Night 7 Finale (camera blocked)
