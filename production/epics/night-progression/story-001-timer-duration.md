# Story 001: Night Timer & Duration

> **Epic**: Night Progression
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/night-progression.md` (Formulas — Night Timer section)
**Requirement**: `TR-NP-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Scene Architecture)
**ADR Decision Summary**: Night lifecycle state machine in Night Progression autoload. Timer countdown in `_process()`. Phase transitions via internal state variable.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `night_timer_tick(seconds_remaining)` emitted once per second during ACTIVE and GRACE. `night_timer_expired` emitted when timer reaches 0. `night_grace_started(grace_seconds)` emitted on GRACE entry.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: `BASE_DURATION` (600s), `DURATION_DECREMENT` (30s), `TIMER_GRACE_SECONDS` (30s), `DEATH_SCREEN_DURATION` (2.0s) from TuningKnobs. `INTRO_MAX_DURATION` (30s) from TuningKnobs.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Timer countdown via `_process(delta)`. No special engine APIs needed. Simple float arithmetic.

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Required: No signal chains — each system emits its own distinct signal

---

## Acceptance Criteria

*From GDD `design/gdd/night-progression.md`, scoped to this story:*

- [ ] AC-NP-01: GIVEN `BASE_DURATION = 600` and `DURATION_DECREMENT = 30`, WHEN `night_duration(n)` is evaluated for n=1-7, THEN outputs are 600, 570, 540, 510, 480, 450, 420 respectively.

- [ ] AC-NP-02: GIVEN current night is 7, WHEN ACTIVE phase begins, THEN `get_time_remaining()` returns a valid float but the timer hidden flag is set (HUD does not display countdown).

- [ ] AC-NP-09: GIVEN Nights 1-6 in ACTIVE, WHEN timer reaches 0, THEN phase transitions to GRACE, `night_timer_expired` emits, and `night_grace_started(30)` emits.

- [ ] AC-NP-12: GIVEN Night 7 ACTIVE, WHEN timer reaches 0, THEN phase transitions to FINALE (not GRACE, not DEAD). The boss "catches up."

- [ ] AC-NP-20: GIVEN phase transitions to DEAD, WHEN `DEATH_SCREEN_DURATION` (2.0s) elapses, THEN LOADING begins for the same night n (not n+1).

---

## Implementation Notes

*Derived from ADR-0001 Scene Architecture + ADR-0003 Communication + ADR-0004 Data-Driven:*

**Duration formula:**
```gdscript
# night_progression.gd

const BASE_DURATION: float = 600.0
const DURATION_DECREMENT: float = 30.0

func get_night_duration(night: int) -> float:
    return BASE_DURATION - (night - 1) * DURATION_DECREMENT
```

**Timer countdown:**
```gdscript
# night_progression.gd

var _time_remaining: float = 0.0
var _phase: NightPhase = NightPhase.LOADING

func _process(delta: float) -> void:
    if _phase == NightPhase.ACTIVE or _phase == NightPhase.GRACE:
        _time_remaining -= delta
        if _time_remaining >= 0:
            night_timer_tick.emit(_time_remaining)
        if _time_remaining <= 0:
            _on_timer_expired()

func _on_timer_expired() -> void:
    if current_night == 7:
        _transition_to(NightPhase.FINALE)
        night_7_finale_start.emit()
    else:
        _transition_to(NightPhase.GRACE)
        night_timer_expired.emit()
        night_grace_started.emit(TIMER_GRACE_SECONDS)
        _time_remaining = TIMER_GRACE_SECONDS
```

**Night 7 timer visibility:**
```gdscript
# night_progression.gd

func get_timer_visible() -> bool:
    return current_night != 7
```

**Death screen duration:**
```gdscript
# night_progression.gd

func _on_player_dead() -> void:
    _transition_to(NightPhase.DEAD)
    player_night_restarted.emit(current_night, _photos_captured_this_run)
    
    await get_tree().create_timer(DEATH_SCREEN_DURATION).timeout
    _start_loading(current_night)  # Same night, not n+1
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Difficulty scaling formulas (anomaly target, monster count, horror tier)
- [Story 003]: Night lifecycle state machine transitions (timer expiry handled here, but phase transition logic is in Story 003)
- [Story 004]: DEBRIEF counter logic (consecutive nights no-photos)
- [Story 005]: Configuration orchestration (configure_for_night calls)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-NP-01**: Duration formula
  - Given: BASE_DURATION = 600, DURATION_DECREMENT = 30
  - When: Evaluate `get_night_duration(n)` for n=1-7
  - Then: Returns 600, 570, 540, 510, 480, 450, 420 respectively
  - Edge cases: n=0 → 630 (formula works but n is clamped to 1-7 by caller); n=8 → 390 (formula works but n is clamped to 1-7 by caller); negative n → undefined (caller must validate)

- **AC-NP-02**: Night 7 timer hidden
  - Given: current_night = 7, ACTIVE phase
  - When: `get_timer_visible()` called
  - Then: Returns false; HUD does not display countdown
  - Edge cases: Night 7 GRACE → still hidden; Night 7 FINALE → still hidden; Night 6 → visible (true)

- **AC-NP-09**: Timer expiry on Nights 1-6 → GRACE
  - Given: Nights 1-6, ACTIVE phase, timer counting down
  - When: Timer reaches 0
  - Then: Phase transitions to GRACE; `night_timer_expired` emits (no params); `night_grace_started(30)` emits; timer resets to TIMER_GRACE_SECONDS (30s)
  - Edge cases: timer at 0.001s → still counts as expired (<= 0); timer expires exactly as player reaches exit → exit wins (prioritize exit per GDD edge case)

- **AC-NP-12**: Night 7 timer expiry → FINALE
  - Given: Night 7, ACTIVE phase
  - When: Timer reaches 0
  - Then: Phase transitions to FINALE (not GRACE, not DEAD); `night_7_finale_start` emits; boss "catches up"
  - Edge cases: player reached exit before timer → exit disabled on Night 7 ACTIVE (see Story 003); timer expires before `night_7_finale_start` → force `night_7_finale_start` immediately (per GDD edge case)

- **AC-NP-20**: Death screen → restart same night
  - Given: Phase transitions to DEAD
  - When: DEATH_SCREEN_DURATION (2.0s) elapses
  - Then: LOADING begins for the same night n (not n+1); player position reset to Entry Hall spawn
  - Edge cases: death on Night 7 → restart Night 7 from ACTIVE (INTRO does not replay); death during grace → same behavior (same night); rapid deaths → each triggers full 2.0s death screen

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/night-progression/timer_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (foundational — other stories depend on timer)
- Unlocks: Story 003 (Night Lifecycle — timer expiry is the GRACE/FINALE trigger), Story 004 (DEBRIEF counters — timer expiry feeds into debrief), Story 005 (Configuration — timer duration set during LOADING)
