# Story 001: Debrief State Machine & Flow

> **Epic**: Evidence Submission
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/evidence-submission.md` (States and Transitions — Evidence Submission State Machine section)
**Requirement**: `TR-ES-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `night_completed` signal triggers debrief flow. `debrief_completed` signal emitted after player confirms. No signal chains — Evidence Submission emits its own `debrief_completed`, not a re-emission.

**ADR Governing Implementation**: ADR-0001 (Scene Architecture)
**ADR Decision Summary**: Evidence Submission is a scene-local node in the single-scene architecture. State machine via `enum DebriefState`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: State machine via enum + `_transition_to()` with validity guard. No special engine APIs needed.

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Required: No signal chains — each system emits its own distinct signal

---

## Acceptance Criteria

*From GDD `design/gdd/evidence-submission.md`, scoped to this story:*

- [ ] AC-ES-01: GIVEN game is in ACTIVE during any night 1–6, WHEN Night Progression emits `night_completed(n, photos_submitted, timer_expired)`, THEN Evidence Submission transitions from IDLE to RECEIVING within one frame and no further signals are accepted until `debrief_completed` is emitted.

- [ ] AC-ES-02: GIVEN `night_completed` is received for night 1–6, WHEN Evidence Submission processes the debrief, THEN it queries Photography (Step 3), updates boss state (Step 4), selects dialogue (Step 5), computes pay (Step 6), assembles DebriefData (Step 7), and calls `show_debrief()` (Step 8) — no step is skipped.

- [ ] AC-ES-03: GIVEN Evidence Submission is in DISPLAYING state, WHEN the player presses Continue after T_dwell, THEN `debrief_completed` is emitted and state returns to IDLE.

- [ ] AC-ES-04: GIVEN `debrief_continue_pressed` fires during COMPUTING or RECEIVING, WHEN the signal handler runs, THEN the signal is ignored (state check rejects it).

- [ ] AC-ES-05: GIVEN two `night_completed` signals fire in the same frame, WHEN the first is processed, THEN the second is silently dropped (state is no longer IDLE).

---

## Implementation Notes

*Derived from ADR-0003 Communication + ADR-0001 Scene Architecture:*

**State machine:**
```gdscript
# evidence_submission.gd

enum DebriefState {
    IDLE,
    RECEIVING,
    COMPUTING,
    DISPLAYING,
    EMITTING
}

var _state: DebriefState = DebriefState.IDLE
var _boss_anger: int = 0
var _cumulative_pay: int = 0
var _night_7_escaped: bool = false

func _ready() -> void:
    # Connect signals in _ready
    pass

func _process(delta: float) -> void:
    # State machine transitions happen on signal handlers, not _process
    pass

func _on_night_completed(n: int, photos_submitted: int, timer_expired: bool) -> void:
    if _state != DebriefState.IDLE:
        push_warning("Duplicate night_completed — state is %s, not IDLE" % _state)
        return

    _state = DebriefState.RECEIVING

    # Night 7 guard: skip to win debrief path
    if n == 7:
        if _night_7_escaped:
            _show_night_7_win_debrief()
        else:
            # Night 7 death — no debrief, handled by Night Progression
            return
        return

    # Steps 3–8 for nights 1–6
    _process_debrief(n, photos_submitted, timer_expired)

func _process_debrief(n: int, photos_submitted: int, timer_expired: bool) -> void:
    # Step 3: Query Photography
    var photos := PhotographySystem.get_photos_for_submission()
    var evidence_score := PhotographySystem.get_night_evidence_score()

    # Step 4: Update boss state
    var grade := _derive_grade(evidence_score, photos_submitted)
    var pay := _compute_pay(n, grade, photos_submitted)

    # Step 5: Select dialogue
    var dialogue := _select_dialogue(n, grade, pay)

    # Step 6: Pay already computed above

    # Step 7: Assemble DebriefData
    var data := DebriefData.create(n, grade, pay, dialogue, photos)

    # Step 8: Show debrief
    _state = DebriefState.DISPLAYING
    HUDUISystem.show_debrief(data)
```

**Valid transitions:**
```gdscript
# Valid transition matrix
var _valid_transitions := {
    DebriefState.IDLE: [DebriefState.RECEIVING],
    DebriefState.RECEIVING: [DebriefState.COMPUTING],
    DebriefState.COMPUTING: [DebriefState.DISPLAYING],
    DebriefState.DISPLAYING: [DebriefState.EMITTING],
    DebriefState.EMITTING: [DebriefState.IDLE],
}
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Pay calculation formulas (state machine calls `_compute_pay` but the formula logic is in Story 002)
- [Story 003]: Boss anger update (state machine calls `_update_boss_state` but the formula logic is in Story 003)
- [Story 006]: Night 7 win debrief (separate debrief path with different content)
- [Story 007]: Debrief display (HUD/UI rendering of DebriefData)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-ES-01**: Debrief trigger from ACTIVE
  - Given: Game in ACTIVE during Night 3
  - When: `night_completed(3, 5, false)` received
  - Then: State transitions IDLE → RECEIVING within one frame; no further signals accepted until `debrief_completed` emits
  - Edge cases: state is IDLE → accepted; state is DISPLAYING → ignored with warning; timer_expired = true → same flow (timer flag is informational only)

- **AC-ES-02**: Full debrief pipeline
  - Given: Night 4 `night_completed` received
  - When: `_process_debrief(4, 3, false)` runs
  - Then: All 6 steps execute in order: query Photography → update boss state → select dialogue → compute pay → assemble DebriefData → call show_debrief(); no step skipped
  - Edge cases: all steps execute in same frame (≤16.6ms); Photography returns empty array → treated as zero photos (per GDD edge case)

- **AC-ES-03**: Continue after dwell
  - Given: Debrief in DISPLAYING state, T_dwell elapsed
  - When: Player presses Continue
  - Then: `debrief_completed` emits; state returns to IDLE
  - Edge cases: T_dwell not elapsed → input ignored; state not DISPLAYING → input ignored; rapid press → only first press accepted (state check)

- **AC-ES-04**: Off-state Continue signal
  - Given: State is RECEIVING or COMPUTING
  - When: `debrief_continue_pressed` fires
  - Then: Signal ignored; no `debrief_completed` emitted
  - Edge cases: RECEIVING → ignored; COMPUTING → ignored; EMITTING → ignored (belt and suspenders: HUD only shows Continue during DISPLAYING)

- **AC-ES-05**: Duplicate night_completed
  - Given: State is RECEIVING (first `night_completed` already processed)
  - When: Second `night_completed` signal fires in same frame
  - Then: Silently dropped; warning logged; no state change
  - Edge cases: both signals in same frame → first wins; second dropped; rapid successive nights → only first processed

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/evidence-submission/debrief_flow_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Evidence Submission is a Core system that Night Progression calls into)
- Unlocks: All other Evidence Submission stories, HUD/UI debrief display (consumes `show_debrief`), Night Progression (consumes `debrief_completed`)
