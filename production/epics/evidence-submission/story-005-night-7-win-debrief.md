# Story 005: Night 7 Win Debrief

> **Epic**: Evidence Submission
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/evidence-submission.md` (Night 7 Win Debrief section)
**Requirement**: `TR-ES-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `night_completed` signal from Night Progression triggers Night 7 win path. `debrief_completed` signal emitted after player confirms win debrief. No signal chains — Evidence Submission emits its own `debrief_completed`.

**ADR Governing Implementation**: ADR-0001 (Scene Architecture)
**ADR Decision Summary**: Night 7 win debrief is a scene-local branch in the Evidence Submission state machine. Different debrief content from standard debrief.

**ADR Governing Implementation**: ADR-0009 (Audio)
**ADR Decision Summary**: Night 7 escape music variant set by AudioManager during Night 7 LOADING phase (handled by Night Progression config orchestration).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: State machine branch for Night 7 win path. Uses same `show_debrief()` UI call as standard debrief but with different DebriefData. AudioManager singleton for audio cue.

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Required: No signal chains — each system emits its own distinct signal

---

## Acceptance Criteria

*From GDD `design/gdd/evidence-submission.md`, scoped to this story:*

- [ ] AC-ES-24: GIVEN `current_night = 7`, WHEN `night_completed(7, photos, timer_expired)` is received AND player escaped, THEN Evidence Submission transitions to DISPLAYING state and calls `show_debrief()` with win debrief data (not standard debrief data).

- [ ] AC-ES-25: GIVEN `current_night = 7`, WHEN `night_completed(7, photos, timer_expired)` is received AND player was caught (did not escape), THEN Evidence Submission does NOT show a debrief (game-over path handled by Night Progression).

- [ ] AC-ES-26: GIVEN Night 7 win debrief is displaying, WHEN the player presses Continue after T_dwell, THEN `debrief_completed` is emitted and the game transitions to the win screen.

- [ ] AC-ES-27: GIVEN `current_night = 7`, WHEN player escaped, THEN `_show_night_7_win_debrief()` includes escape route taken, total photos, and a unique dialogue line from the Night 7 win dialogue set.

- [ ] AC-ES-28: GIVEN `current_night < 7`, WHEN a `night_completed` signal fires for night 7 (out of order), THEN the signal is ignored (state is not IDLE).

---

## Implementation Notes

*Derived from ADR-0003 Communication + ADR-0001 Scene Architecture:*

**Night 7 win path:**
```gdscript
# evidence_submission.gd

var _night_7_escaped: bool = false
var _night_7_escape_route: StringName = &"none"

func _on_night_completed(n: int, photos_submitted: int, timer_expired: bool) -> void:
    if _state != DebriefState.IDLE:
        push_warning("Duplicate night_completed — state is %s, not IDLE" % _state)
        return

    _state = DebriefState.RECEIVING

    # Night 7 guard: separate path from standard debrief
    if n == 7:
        if _night_7_escaped:
            _show_night_7_win_debrief()
        else:
            # Night 7 death — no debrief, handled by Night Progression
            return
        return

    # Nights 1-6: standard debrief flow
    _process_debrief(n, photos_submitted, timer_expired)

func _show_night_7_win_debrief() -> void:
    var data := DebriefData.create_win(
        escape_route: _night_7_escape_route,
        total_photos: _get_total_photos(),
        dialogue: _select_night_7_win_dialogue()
    )

    _state = DebriefState.DISPLAYING
    HUDUISystem.show_debrief(data)
```

**Night 7 escape data (DebriefData variant):**
| Field | Source |
|---|---|
| `escape_route` | RoomManager (which door/path was used) |
| `total_photos` | Sum of all photos across all nights |
| `dialogue` | Night 7 win dialogue resource |
| `grade` | N/A (no grade for win debrief) |
| `pay` | N/A (no pay for win debrief) |

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Standard debrief flow (nights 1-6, separate path)
- [Story 006]: Photo thumbnails (win debrief may show photos but thumbnails are a display concern)
- [Night Progression]: Determining whether player escaped Night 7 (sets `_night_7_escaped`)
- [Night Progression]: Handling Night 7 death (no debrief, game-over path)
- [Story 007]: Debrief display (renders win debrief data but doesn't create it)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-ES-24**: Night 7 win debrief display
  - Given: current_night = 7, player escaped, _night_7_escaped = true
  - When: night_completed(7, 5, false) received
  - Then: State transitions IDLE → RECEIVING → DISPLAYING; show_debrief() called with win DebriefData (not standard); grade and pay fields are null/empty
  - Edge cases: photos_submitted = 0 → still shows win debrief; timer_expired = true → same path; state not IDLE → ignored

- **AC-ES-25**: Night 7 death (no debrief)
  - Given: current_night = 7, player caught, _night_7_escaped = false
  - When: night_completed(7, 0, true) received
  - Then: No debrief shown; game-over handled by Night Progression; state returns to IDLE without emitting debrief_completed
  - Edge cases: _night_7_escaped = true but photos = 0 → still shows win debrief (escape is independent of photos); state = RECEIVING → ignored

- **AC-ES-26**: Continue after win debrief
  - Given: Win debrief in DISPLAYING state, T_dwell elapsed
  - When: Player presses Continue
  - Then: debrief_completed emits; state returns to IDLE; game transitions to win screen (handled by Night Progression consumer)
  - Edge cases: T_dwell not elapsed → input ignored; state not DISPLAYING → input ignored

- **AC-ES-27**: Win debrief content
  - Given: Player escaped via `back_alley` route
  - When: _show_night_7_win_debrief() runs
  - Then: DebriefData includes escape_route = "back_alley", total_photos = sum across all nights, unique Night 7 win dialogue
  - Edge cases: escape_route = "none" (unknown route) → shows generic message; total_photos = 0 → shows "0 photos"

- **AC-ES-28**: Out-of-order night 7 signal
  - Given: State is not IDLE (e.g., DISPLAYING from previous debrief)
  - When: night_completed(7, 5, false) fires
  - Then: Signal ignored with warning; no state change; no debrief shown
  - Edge cases: state = IDLE but current_night != 7 → should not happen (Night Progression controls this); rapid signals → only first processed

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/evidence-submission/night_7_win_debrief_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (state machine provides the `_on_night_completed` entry point)
- Unlocks: Win screen display (consumes `debrief_completed` from win path)
