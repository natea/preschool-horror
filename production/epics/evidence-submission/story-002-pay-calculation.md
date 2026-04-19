# Story 002: Pay Calculation Formulas

> **Epic**: Evidence Submission
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/evidence-submission.md` (Pay Calculation section)
**Requirement**: `TR-ES-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Pay formula parameters stored in TuningKnobs resource, never hardcoded. Night Progression reads these at night start.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Pay computed locally in Evidence Submission, returned via DebriefData struct. No signal for pay calculation — it's a synchronous step in the debrief flow.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Pure math functions. No special engine APIs. TuningKnobs resource loaded in `_ready()`.

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/evidence-submission.md`, scoped to this story:*

- [ ] AC-ES-06: GIVEN `evidence_score = 5`, `photos_submitted = 3`, `night = 3`, WHEN `_compute_pay()` runs, THEN base pay = 100, evidence bonus = 50, total = 150.

- [ ] AC-ES-07: GIVEN `evidence_score = 0`, `photos_submitted = 0`, `night = 1`, WHEN `_compute_pay()` runs, THEN base pay = 50 (minimum), evidence bonus = 0, total = 50.

- [ ] AC-ES-08: GIVEN `evidence_score = 10`, `photos_submitted = 10`, `night = 6`, WHEN `_compute_pay()` runs, THEN base pay = 200, evidence bonus = 200, total = 400 (max pay capped).

- [ ] AC-ES-09: GIVEN `night = n`, WHEN `_compute_pay()` runs, THEN base pay scales with night number: `base_pay = min_pay + (night - 1) * pay_scale_per_night`.

---

## Implementation Notes

*Derived from ADR-0004 Data-Driven + GDD Pay Calculation section:*

**Pay formula:**
```gdscript
# evidence_submission.gd

const MIN_PAY: int = 50
const MAX_PAY: int = 400
const PAY_SCALE_PER_NIGHT: int = 25

func _compute_pay(night: int, evidence_score: int, photos_submitted: int) -> int:
    # Base pay scales with night number
    var base_pay := MIN_PAY + (night - 1) * PAY_SCALE_PER_NIGHT
    base_pay = clampi(base_pay, MIN_PAY, MAX_PAY)

    # Evidence bonus: each point of evidence_score adds to pay
    var evidence_bonus := evidence_score * TuningKnobs.evidence_pay_multiplier

    # Total pay capped at MAX_PAY
    var total_pay := clampi(base_pay + evidence_bonus, MIN_PAY, MAX_PAY)

    return total_pay
```

**Variable mapping from GDD:**
| GDD Variable | Implementation | Source |
|---|---|---|
| `base_pay` | `MIN_PAY + (night-1) * PAY_SCALE_PER_NIGHT` | Formula in GDD |
| `evidence_bonus` | `evidence_score * evidence_pay_multiplier` | TuningKnobs resource |
| `total_pay` | `clampi(base_pay + evidence_bonus, MIN_PAY, MAX_PAY)` | GDD cap |
| `MIN_PAY` | `50` | GDD constant |
| `MAX_PAY` | `400` | GDD constant |
| `PAY_SCALE_PER_NIGHT` | `25` | GDD constant |

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine that calls `_compute_pay` (Story 001 is the debrief flow)
- [Story 003]: Boss anger update (separate formula, separate story)
- [Story 007]: Debrief display (shows pay but doesn't compute it)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-ES-06**: Normal pay calculation
  - Given: evidence_score = 5, photos_submitted = 3, night = 3
  - When: _compute_pay(3, 5, 3) runs
  - Then: base_pay = 50 + 2*25 = 100; evidence_bonus = 5*10 = 50; total = 150
  - Edge cases: evidence_score = 0 → bonus = 0; night = 1 → base_pay = 50; night = 7 → base_pay = 250

- **AC-ES-07**: Minimum pay (zero evidence)
  - Given: evidence_score = 0, photos_submitted = 0, night = 1
  - When: _compute_pay(1, 0, 0) runs
  - Then: base_pay = 50; evidence_bonus = 0; total = 50
  - Edge cases: negative evidence_score → clamped to 0; night = 0 → base_pay clamped to MIN_PAY

- **AC-ES-08**: Maximum pay cap
  - Given: evidence_score = 10, photos_submitted = 10, night = 6
  - When: _compute_pay(6, 10, 10) runs
  - Then: base_pay = 200; evidence_bonus = 100; total = 300 (not capped)
  - Edge cases: evidence_score = 20, night = 6 → base_pay = 200 + bonus = 200 + 200 = 400 (at cap); evidence_score = 25 → total = 400 (capped)

- **AC-ES-09**: Night scaling
  - Given: evidence_score = 0, photos_submitted = 0
  - When: _compute_pay(n, 0, 0) runs for n = 1 through 6
  - Then: base_pay = 50, 75, 100, 125, 150, 175 respectively
  - Edge cases: night = 7 → base_pay = 200 (but Night 7 handled separately); night = 0 → clamped to MIN_PAY

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/evidence-submission/pay_calculation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (state machine calls `_compute_pay`)
- Unlocks: Evidence Submission story complete (pay formula is a sub-function of the debrief flow)
