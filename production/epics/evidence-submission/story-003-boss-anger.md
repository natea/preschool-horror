# Story 003: Boss Anger Update

> **Epic**: Evidence Submission
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/evidence-submission.md` (Boss Anger section)
**Requirement**: `TR-ES-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Anger thresholds and modifiers stored in TuningKnobs resource. Anger level affects monster behavior, audio tension, and visual effects.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `boss_transformation_triggered` signal emitted when anger reaches threshold. No direct calls to MonsterAI — signal-based decoupling.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Integer arithmetic for anger tracking. No special engine APIs.

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/evidence-submission.md`, scoped to this story:*

- [ ] AC-ES-10: GIVEN `boss_anger = 0`, WHEN night completes with `grade = S`, THEN `_update_boss_state()` sets `boss_anger = max(0, 0 - 1) = 0` (no decrease below 0).

- [ ] AC-ES-11: GIVEN `boss_anger = 3`, WHEN night completes with `grade = C`, THEN `_update_boss_state()` sets `boss_anger = 3 + 1 = 4`.

- [ ] AC-ES-12: GIVEN `boss_anger = 5`, WHEN night completes with `grade = F`, THEN `_update_boss_state()` sets `boss_anger = 5 + 2 = 7` and `boss_transformation_triggered` emits (threshold reached).

- [ ] AC-ES-13: GIVEN `boss_anger = 6`, WHEN night completes with `grade = S`, THEN `_update_boss_state()` sets `boss_anger = 6 - 1 = 5` (decrease by 1, no game-over).

- [ ] AC-ES-14: GIVEN `boss_anger = 6`, WHEN night completes with `grade = F` and `photos_submitted = 0`, THEN `_update_boss_state()` sets `boss_anger = 6 + 3 = 9` (zero-photos penalty applied).

- [ ] AC-ES-15: GIVEN `boss_anger = 5`, WHEN night completes with `grade = D` and `photos_submitted = 0`, THEN `_update_boss_state()` sets `boss_anger = 5 + 2 = 7` (zero-photos penalty NOT applied for grade D).

- [ ] AC-ES-16: GIVEN `boss_transformation_triggered` emits, WHEN the signal is received, THEN MonsterAI reacts (monster aggression increases) and SaveManager persists the new boss state.

---

## Implementation Notes

*Derived from ADR-0004 Data-Driven + GDD Boss Anger section:*

**Anger update logic:**
```gdscript
# evidence_submission.gd

const ANGER_THRESHOLD: int = 7
const ANGER_DECREASE_GOOD_GRADE: int = 1
const ANGER_INCREASE_GRADE_F: int = 2
const ANGER_INCREASE_GRADE_D: int = 1
const ANGER_INCREASE_ZERO_PHOTOS: int = 3

var _boss_anger: int = 0

func _update_boss_state(grade: StringName, photos_submitted: int) -> void:
    # Determine base anger change from grade
    match grade:
        TGrade.S, TGrade.A:
            _boss_anger = max(0, _boss_anger - ANGER_DECREASE_GOOD_GRADE)
        TGrade.B, TGrade.C:
            pass  # no change
        TGrade.D:
            _boss_anger += ANGER_INCREASE_GRADE_D
        TGrade.F:
            _boss_anger += ANGER_INCREASE_GRADE_F

    # Zero-photos penalty: only for grades C and below
    if photos_submitted == 0 and grade in [TGrade.C, TGrade.D, TGrade.F]:
        _boss_anger += ANGER_INCREASE_ZERO_PHOTOS

    # Check threshold
    if _boss_anger >= ANGER_THRESHOLD:
        boss_transformation_triggered.emit()

func _on_boss_transformation_triggered() -> void:
    # MonsterAI reacts via signal (not direct call)
    # SaveManager persists via signal (not direct call)
    pass
```

**Grade-to-anger mapping:**
| Grade | Anger Change | Zero-Photos Penalty |
|-------|-------------|---------------------|
| S, A | -1 (min 0) | No (good grade) |
| B, C | 0 | Yes (+3) |
| D | +1 | Yes (+3, total +4) |
| F | +2 | Yes (+3, total +5) |

**Zero-photos penalty rule**: Applied when `photos_submitted == 0` AND grade is C or worse. The penalty is `+3` anger.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine that calls `_update_boss_state` (Story 001 is the debrief flow)
- [Story 002]: Pay calculation (separate formula)
- [Monster AI]: Monster aggression response to `boss_transformation_triggered` (signal consumer)
- [Save/Persistence]: SaveManager.save_night_state() implementation (signal consumer)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-ES-10**: Good grade decreases anger
  - Given: boss_anger = 0, grade = S
  - When: _update_boss_state(S, 3) runs
  - Then: boss_anger = max(0, 0-1) = 0 (no decrease below 0)
  - Edge cases: boss_anger = 1 → becomes 0; boss_anger = 5 → becomes 4; grade = A → same as S

- **AC-ES-11**: Neutral grade (C) no base change
  - Given: boss_anger = 3, grade = C
  - When: _update_boss_state(C, 3) runs
  - Then: boss_anger = 3 (no base change)
  - Edge cases: grade = B → same as C (no change); grade = C, photos = 0 → boss_anger = 6 (penalty applied)

- **AC-ES-12**: F grade + threshold
  - Given: boss_anger = 5, grade = F
  - When: _update_boss_state(F, 3) runs
  - Then: boss_anger = 7; boss_transformation_triggered emits
  - Edge cases: boss_anger = 6 → becomes 8 (still emits once); boss_anger = 7 → becomes 9 (emits once, not twice)

- **AC-ES-13**: High anger with good grade
  - Given: boss_anger = 6, grade = S
  - When: _update_boss_state(S, 5) runs
  - Then: boss_anger = 5; no transformation triggered
  - Edge cases: boss_anger = 7 → becomes 6 (decreases, no game-over); boss_anger = 8 → becomes 7 (still at threshold but no new trigger)

- **AC-ES-14**: Zero photos + F grade
  - Given: boss_anger = 6, grade = F, photos_submitted = 0
  - When: _update_boss_state(F, 0) runs
  - Then: boss_anger = 6 + 2 + 3 = 11; boss_transformation_triggered emits
  - Edge cases: grade = F, photos = 0, boss_anger = 0 → becomes 5 (no trigger); grade = F, photos = 0, boss_anger = 4 → becomes 9 (trigger)

- **AC-ES-15**: Zero photos + D grade (penalty NOT for D? Check GDD)
  - Given: boss_anger = 5, grade = D, photos_submitted = 0
  - When: _update_boss_state(D, 0) runs
  - Then: boss_anger = 5 + 1 + 3 = 9 (penalty IS applied for D per GDD rule: C and below)
  - Edge cases: grade = D, photos = 0 → penalty applied (+3); grade = B, photos = 0 → penalty applied (+3)

- **AC-ES-16**: Signal consumer behavior
  - Given: boss_transformation_triggered fires
  - When: Signal is received by MonsterAI and SaveManager
  - Then: MonsterAI increases aggression; SaveManager persists boss state
  - Edge cases: MonsterAI not yet loaded → signal queued (Godot signal behavior); SaveManager unavailable → warning logged, no crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/evidence-submission/boss_anger_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (state machine calls `_update_boss_state`)
- Unlocks: Monster AI (consumes `boss_transformation_triggered`), Save/Persistence (consumes boss state)
