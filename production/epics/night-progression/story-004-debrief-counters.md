# Story 004: DEBRIEF Counter Logic

> **Epic**: Night Progression
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/night-progression.md` (Consecutive Nights No-Photos Game-Over section)
**Requirement**: `TR-NP-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Save System)
**ADR Decision Summary**: `consecutive_nights_no_photos` persisted in SaveManager. `current_night` and `story_flags` also persisted. Save on debrief_completed.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `night_completed(n, photos_submitted, timer_expired)` signal consumed by Evidence Submission and Save/Persistence. `boss_transformation_triggered` emitted for game-over condition.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Simple integer counter logic. No special engine APIs. Save/Load via SaveManager autoload (check existence before calling).

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/night-progression.md`, scoped to this story:*

- [ ] AC-NP-19: GIVEN `consecutive_nights_no_photos = 0`, WHEN a night completes with `photos_submitted > 0`, THEN counter resets to 0.

- [ ] AC-NP-20: GIVEN `consecutive_nights_no_photos = 2`, WHEN a night completes with `photos_submitted == 0` and `current_night != 7`, THEN counter increments to 3 and `boss_transformation_triggered` emits.

- [ ] AC-NP-21: GIVEN `consecutive_nights_no_photos = 2`, WHEN a night completes with `photos_submitted == 0` and `current_night == 7` (player escaped), THEN counter does NOT increment (Night 7 exempt).

- [ ] AC-NP-22: GIVEN `consecutive_nights_no_photos = 1`, WHEN a night completes with `photos_submitted == 0` and `current_night != 7`, THEN counter increments to 2 and no game-over signal is emitted.

- [ ] AC-NP-23: GIVEN player death during a night, WHEN DEBRIEF would normally run, THEN `consecutive_nights_no_photos` is NOT incremented (death skips submission).

- [ ] AC-NP-24: GIVEN `consecutive_nights_no_photos >= 3`, WHEN `boss_transformation_triggered` is emitted, THEN `SaveManager.save_night_state()` is called with the boss state.

---

## Implementation Notes

*Derived from ADR-0010 Save System + ADR-0003 Communication:*

**Counter logic:**
```gdscript
# night_progression.gd

const CONSECUTIVE_NIGHTS_THRESHOLD: int = 3

var _consecutive_nights_no_photos: int = 0
var _current_night: int = 1

func _on_debrief_complete(n: int, photos_submitted: int) -> void:
    # Night 7 is exempt from the counter
    if n == 7:
        return

    if photos_submitted > 0:
        _consecutive_nights_no_photos = 0
    else:
        _consecutive_nights_no_photos += 1
        if _consecutive_nights_no_photos >= CONSECUTIVE_NIGHTS_THRESHOLD:
            boss_transformation_triggered.emit()
            _save_boss_state()

func _save_boss_state() -> void:
    if Engine.has_singleton("SaveManager"):
        var state = {
            "consecutive_nights_no_photos": _consecutive_nights_no_photos,
            "boss_anger": _get_boss_anger_level(),
            "boss_pay": _get_boss_pay_level()
        }
        SaveManager.save_night_state(state)
```

**Death exemption:**
```gdscript
# night_progression.gd

func _on_player_dead() -> void:
    _transition_to(NightPhase.DEAD)
    player_night_restarted.emit(current_night, _photos_captured_this_run)
    # Note: _consecutive_nights_no_photos is NOT modified here
    # Death restarts the night; submission opportunity never reached
```

**Night 7 exemption:**
```gdscript
# night_progression.gd

func _on_night_7_escaped() -> void:
    # Night 7 escape → game won, not debrief counter logic
    # Counter is explicitly NOT incremented for Night 7
    # This is checked in _on_debrief_complete before any counter mutation
    game_won.emit()
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: Phase transitions to DEBRIEF (counter logic runs inside debrief flow, but phase state machine is in Story 003)
- [Story 005]: Save/Persistence integration (SaveManager calls are tested here as logic; the actual save file format is in Save Persistence epic)
- [Evidence Submission]: Evidence Submission epic handles the `debrief_completed` signal flow and photo submission UI

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-NP-19**: Counter reset on photos submitted
  - Given: consecutive_nights_no_photos = 0, current_night = 3
  - When: night completes with photos_submitted = 5
  - Then: counter resets to 0 (no-op since already 0, but verified idempotent)
  - Edge cases: photos_submitted = 1 → resets to 0; counter at 2 → resets to 0; counter at 3 → resets to 0 (once triggered, a successful submission clears it)

- **AC-NP-20**: Counter threshold → game over
  - Given: consecutive_nights_no_photos = 2, current_night = 3
  - When: night completes with photos_submitted = 0
  - Then: counter increments to 3; boss_transformation_triggered emits; SaveManager.save_night_state() called with boss state
  - Edge cases: counter at 2, photos_submitted = 0, current_night = 1 → same behavior; photos_submitted = -1 (invalid) → treated as 0 (no photos); counter at 2, photos_submitted = 0, current_night = 6 → same behavior (any night 1-6 triggers)

- **AC-NP-21**: Night 7 exemption
  - Given: consecutive_nights_no_photos = 2, current_night = 7
  - When: player escapes (photos_submitted = 0)
  - Then: counter does NOT increment; game_won emits instead
  - Edge cases: counter at 0, Night 7 escape → counter stays 0; counter at 2, Night 7 escape → counter stays 2 (but game_won fires, game ends)

- **AC-NP-22**: Counter intermediate increment
  - Given: consecutive_nights_no_photos = 1, current_night = 4
  - When: night completes with photos_submitted = 0
  - Then: counter increments to 2; no boss_transformation_triggered (threshold not reached)
  - Edge cases: counter at 0 → increments to 1; counter at 2 → increments to 3 (triggers game over, per AC-NP-20); counter at 3 → already at threshold (shouldn't reach debrief, but if it does: no-op)

- **AC-NP-23**: Death exemption
  - Given: consecutive_nights_no_photos = 2, player dies during Night 5
  - When: night restarts (DEAD → LOADING → ACTIVE), player completes night with 0 photos
  - Then: counter increments to 3 only on the post-death completion (death itself does NOT increment)
  - Edge cases: death on Night 5 → counter unchanged at death; restart Night 5, escape with 0 photos → counter goes to 3; death on Night 7 → counter unchanged (Night 7 exempt anyway)

- **AC-NP-24**: Save on game-over
  - Given: boss_transformation_triggered fires
  - When: _save_boss_state() runs
  - Then: SaveManager.save_night_state() called with consecutive_nights_no_photos, boss_anger, boss_pay
  - Edge cases: SaveManager absent → warning logged, no crash (fallback per ADR-0010); save fails → error logged, game_over still fires (signal is the source of truth)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/night-progression/debrief_counter_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (Night Lifecycle — DEBRIEF phase must exist before counter logic runs)
- Unlocks: Evidence Submission (consumes boss_transformation_triggered), Save/Persistence (writes boss state), Game Over flow (consumes boss_transformation_triggered)
