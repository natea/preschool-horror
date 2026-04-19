# Story 003: Night Lifecycle State Machine

> **Epic**: Night Progression
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/night-progression.md` (Night Lifecycle, States and Transitions sections)
**Requirement**: `TR-NP-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Scene Architecture)
**ADR Decision Summary**: Night lifecycle state machine with strict valid transitions. No unexpected transitions — error on invalid. Terminal states: GAME_OVER and GAME_WON.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `night_loading_started(n)`, `night_active_started(n)`, `night_completed(n, photos_submitted, timer_expired)`, `night_transition_started(from, to)` signals. Configuration calls to RoomManager and AudioManager.

**ADR Governing Implementation**: ADR-0010 (Save System)
**ADR Decision Summary**: `SaveManager.save_night_state(state)` and `SaveManager.load_night_state()` for night number, no-photos counter, and story flags.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: State machine via `enum NightPhase` + `_transition_to()` with validity guard. Reserved config calls check autoload existence before calling. Timer via `_process(delta)`.

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: No signal chains — each system emits its own distinct signal
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/night-progression.md`, scoped to this story:*

- [ ] AC-NP-08: GIVEN Night 7 INTRO has started, WHEN 30s elapses without `night_7_cutscene_complete`, THEN phase transitions to ACTIVE (safety timeout).

- [ ] AC-NP-10: GIVEN phase is GRACE, WHEN `player_reached_exit` is received before grace expires, THEN phase transitions to DEBRIEF (not DEAD).

- [ ] AC-NP-11: GIVEN phase is GRACE, WHEN `TIMER_GRACE_SECONDS` elapses without exit, THEN phase transitions to DEAD.

- [ ] AC-NP-13: GIVEN Night 7 ACTIVE, WHEN `player_reached_exit` is received, THEN signal is ignored and phase does not change (exit trigger disabled).

- [ ] AC-NP-14: GIVEN Night 7 FINALE, WHEN `player_died` is received, THEN phase transitions to DEAD and restart enters ACTIVE (INTRO does not replay).

- [ ] AC-NP-15: GIVEN any phase, WHEN an invalid transition trigger arrives, THEN phase does not change and an error is logged.

- [ ] AC-NP-16: GIVEN LOADING begins for night n, WHEN configuration executes, THEN `RoomManager.configure_for_night(n)` and `AudioManager.configure_audio_for_night(n)` are both called exactly once before ACTIVE begins.

- [ ] AC-NP-17: GIVEN LOADING for Night 7, WHEN `configure_for_night(7)` completes, THEN `unlock_room(&"principals_office")` is called after configure (order enforced).

- [ ] AC-NP-18: GIVEN `AnomalyPlacementEngine` or `MonsterAI` autoloads are absent, WHEN LOADING runs, THEN Night Progression logs a warning and completes without crashing.

---

## Implementation Notes

*Derived from ADR-0001 Scene Architecture + ADR-0003 Communication:*

**State machine with validity guard:**
```gdscript
# night_progression.gd

enum NightPhase {
    LOADING,
    INTRO,
    ACTIVE,
    GRACE,
    DEAD,
    FINALE,
    DEBRIEF,
    GAME_OVER,
    GAME_WON
}

# Valid transition matrix
var _valid_transitions := {
    NightPhase.LOADING: [NightPhase.INTRO, NightPhase.ACTIVE],
    NightPhase.INTRO: [NightPhase.ACTIVE],
    NightPhase.ACTIVE: [NightPhase.GRACE, NightPhase.DEAD, NightPhase.FINALE, NightPhase.DEBRIEF],
    NightPhase.GRACE: [NightPhase.DEBRIEF, NightPhase.DEAD],
    NightPhase.DEAD: [NightPhase.LOADING],
    NightPhase.FINALE: [NightPhase.DEBRIEF, NightPhase.DEAD],
    NightPhase.DEBRIEF: [NightPhase.LOADING, NightPhase.GAME_OVER, NightPhase.GAME_WON],
    NightPhase.GAME_OVER: [],
    NightPhase.GAME_WON: [],
}

func _transition_to(new_phase: NightPhase) -> bool:
    if new_phase not in _valid_transitions.get(_phase, []):
        push_error("Invalid transition: %s → %s" % [_phase_to_string(_phase), _phase_to_string(new_phase)])
        return false
    var old_phase = _phase
    _phase = new_phase
    _on_phase_changed(old_phase, _phase)
    return true
```

**Loading phase — configuration orchestration:**
```gdscript
# night_progression.gd

func _start_loading(night: int) -> void:
    current_night = night
    _transition_to(NightPhase.LOADING)

    # Configuration calls
    if Engine.has_singleton("RoomManager"):
        RoomManager.configure_for_night(night)
    if night == 7:
        RoomManager.unlock_room(&"principals_office")

    if Engine.has_singleton("AudioManager"):
        AudioManager.configure_audio_for_night(night)

    # Reserved calls — check autoload exists
    if has_node("AnomalyPlacementEngine"):
        get_node("AnomalyPlacementEngine").configure_for_night(night)
    else:
        push_warning("AnomalyPlacementEngine autoload not found — skipping anomaly configuration")

    if has_node("MonsterAI"):
        get_node("MonsterAI").configure_for_night(night)
    else:
        push_warning("MonsterAI autoload not found — skipping monster configuration")

    # Set timer
    _time_remaining = get_night_duration(night)

    # Load persisted state (new session only, not death restart)
    _load_persisted_state()

    night_loading_started.emit(night)

    # Transition to INTRO or ACTIVE
    if night == 7:
        _transition_to(NightPhase.INTRO)
        night_7_cutscene_start.emit()
    else:
        _transition_to(NightPhase.ACTIVE)
        night_active_started.emit(night)
```

**Night 7 cutscene timeout:**
```gdscript
# night_progression.gd

var _intro_timeout_timer: float = 0.0

func _process(delta: float) -> void:
    if _phase == NightPhase.INTRO:
        _intro_timeout_timer += delta
        if _intro_timeout_timer >= INTRO_MAX_DURATION:
            _intro_timeout_timer = 0.0
            _transition_to(NightPhase.ACTIVE)
            night_active_started.emit(current_night)

func _on_night_7_cutscene_complete() -> void:
    _intro_timeout_timer = 0.0
    _transition_to(NightPhase.ACTIVE)
    night_active_started.emit(current_night)
```

**Night 7 exit trigger disabled:**
```gdscript
# night_progression.gd

func _on_player_reached_exit() -> void:
    if _phase == NightPhase.ACTIVE and current_night == 7:
        push_error("Player reached exit during Night 7 ACTIVE — should be disabled")
        return  # Exit trigger disabled on Night 7

    if _phase == NightPhase.GRACE:
        _transition_to(NightPhase.DEBRIEF)

    if _phase == NightPhase.FINALE:
        _transition_to(NightPhase.DEBRIEF)
        # Force photos_submitted = 0 for FINALE escape
        night_completed.emit(current_night, 0, false)

    if _phase == NightPhase.ACTIVE and current_night != 7:
        _transition_to(NightPhase.DEBRIEF)
```

**Death restart — Night 7 special case:**
```gdscript
# night_progression.gd

func _on_player_dead() -> void:
    _transition_to(NightPhase.DEAD)
    player_night_restarted.emit(current_night, _photos_captured_this_run)
    await get_tree().create_timer(DEATH_SCREEN_DURATION).timeout

    if current_night == 7:
        # Night 7: restart from ACTIVE (INTRO does not replay)
        _transition_to(NightPhase.ACTIVE)
        night_active_started.emit(current_night)
    else:
        _start_loading(current_night)
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Timer duration formula (computed here but tested in Story 001)
- [Story 002]: Difficulty scaling formulas (computed here but tested in Story 002)
- [Story 004]: DEBRIEF counter logic (counter increment/check is in Story 004)
- [Story 005]: Configuration orchestration (configure_for_night calls are tested here as part of LOADING; Room Management and Audio implement the configure methods)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-NP-08**: Night 7 cutscene timeout
  - Given: Night 7 INTRO started, cutscene signal not received
  - When: 30s elapses without `night_7_cutscene_complete`
  - Then: Phase transitions to ACTIVE; `night_active_started(7)` emits; INTRO_MAX_DURATION timer resets
  - Edge cases: cutscene arrives at 29.9s → normal transition (not timeout); cutscene arrives at 30.0s → still normal (>= threshold, not >); INTRO_MAX_DURATION = 30s default, configurable via TuningKnobs

- **AC-NP-10**: Grace period exit
  - Given: Phase is GRACE, player has 30s grace window
  - When: `player_reached_exit` received before grace expires
  - Then: Phase transitions to DEBRIEF (not DEAD); `night_completed(n, photos_submitted, false)` emits
  - Edge cases: exit at t=0.001s → DEBRIEF; exit at t=29.999s → DEBRIEF; exit at t=30.0s → depends on timer precision (<= 0 counts as expired → DEAD); timer expires exactly as player reaches exit → exit wins (per GDD edge case)

- **AC-NP-11**: Grace period expiry
  - Given: Phase is GRACE, player has not reached exit
  - When: TIMER_GRACE_SECONDS (30s) elapses without exit
  - Then: Phase transitions to DEAD; photos lost; night restarts at same n
  - Edge cases: timer expires at exactly 0.0 → DEAD; timer expires while player is in exit trigger zone → DEAD (exit check must happen before timer check in _process ordering)

- **AC-NP-13**: Night 7 exit disabled
  - Given: Night 7, ACTIVE phase
  - When: Player reaches exit trigger
  - Then: Signal is ignored; phase does not change; error logged
  - Edge cases: exit trigger fires via Room/Level Management → ignored; exit trigger fires multiple times → each fires ignored signal; FINALE phase → exit IS allowed (different from ACTIVE)

- **AC-NP-14**: Night 7 death during FINALE
  - Given: Night 7, FINALE phase
  - When: `player_died` received
  - Then: Phase transitions to DEAD; restart enters ACTIVE (INTRO does not replay)
  - Edge cases: multiple deaths during FINALE → each restarts from ACTIVE; death during FINALE escape → same as any FINALE death (restart ACTIVE); death on Night 7 ACTIVE → restart ACTIVE (INTRO does not replay, per GDD edge case)

- **AC-NP-15**: Invalid transition
  - Given: Any phase
  - When: Invalid transition trigger arrives
  - Then: Phase does not change; error logged via push_error
  - Edge cases: GAME_OVER → any transition rejected; GAME_WON → any transition rejected; DEBRIEF → only LOADING, GAME_OVER, GAME_WON accepted; rapid double-trigger → first accepted, second rejected with error

- **AC-NP-16**: Configuration calls order
  - Given: LOADING begins for night n
  - When: Configuration executes
  - Then: `RoomManager.configure_for_night(n)` called; `AudioManager.configure_audio_for_night(n)` called; both before ACTIVE begins
  - Edge cases: RoomManager absent → error (hard dependency, no fallback); AudioManager absent → error (hard dependency, no fallback); both called exactly once (no double-calls on restart)

- **AC-NP-17**: Night 7 office unlock
  - Given: LOADING for Night 7
  - When: `configure_for_night(7)` completes
  - Then: `unlock_room(&"principals_office")` called immediately after configure (order enforced)
  - Edge cases: office already unlocked → unlock is idempotent; office unlock before configure → incorrect order (must be after)

- **AC-NP-18**: Missing autoloads
  - Given: AnomalyPlacementEngine and MonsterAI autoloads absent
  - When: LOADING runs
  - Then: Warnings logged via push_warning; night proceeds without crash; player can still play
  - Edge cases: only AnomalyPlacementEngine absent → MonsterAI config runs, anomaly skipped; only MonsterAI absent → Anomaly config runs, monster skipped; both absent → both skipped, warnings logged

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/night-progression/lifecycle_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Timer — timer duration needed for LOADING), Story 002 (Difficulty Scaling — formulas needed for configuration)
- Unlocks: Story 004 (DEBRIEF counters — DEBRIEF phase feeds into counter logic), Evidence Submission (consumes `night_completed` signal), Save/Persistence (consumes `night_completed` for state write)
