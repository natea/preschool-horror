# Story 004: Night Evidence Score

> **Epic**: Photography
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/photography-system.md` (Evidence Grading section)
**Requirement**: `TR-PHO-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: NIGHT_GRADE_THRESHOLDS [0.70, 0.50, 0.30, 0.15] from TuningKnobs. Evidence score formula structure in code, thresholds in resources.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `get_photos_for_submission()` returns `Array[PhotoRecord]` to Evidence Submission at DEBRIEF. `get_night_evidence_score()` returns computed float. Query API pattern, not signal-based.

**ADR Governing Implementation**: ADR-0001 (Scene Architecture)
**ADR Decision Summary**: All photos stored in-scene. `photos_this_night` cleared on death restart, persists to DEBRIEF.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Array.filter()`, `Dictionary` for unique-best tracking. No special engine APIs needed. Simple aggregation over in-memory data.

**Control Manifest Rules (Core layer)**:
- Required: All scoring thresholds in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/photography-system.md`, scoped to this story:*

- [ ] AC-PHO-13: GIVEN Night 3 with 6 anomalies total, the player photographs 4 unique anomalies with best scores [0.72, 0.45, 0.38, 0.61], WHEN `get_night_evidence_score()` is called, THEN it returns 2.16/6 = 0.36 (Night Grade C).

- [ ] AC-PHO-14: GIVEN the player submits 0 photos for the night, WHEN Evidence Submission queries `get_night_evidence_score()`, THEN it returns 0.0 (Night Grade F).

- [ ] AC-PHO-15: GIVEN the player photographs 2 of 12 anomalies with perfect A-grade scores, WHEN `get_night_evidence_score()` is called, THEN it returns (0.80+0.80)/12 = 0.133 (Night Grade F) — comprehensive coverage is required for a high night grade.

---

## Implementation Notes

*Derived from ADR-0004 Data-Driven + GDD Evidence Grading:*

**Night evidence score formula:**
```
night_evidence_score = sum(unique_best_scores) / max(1, total_anomalies_this_night)
```

Where `unique_best_scores` = for each unique anomaly photographed, take only its highest `photo_score` across all photos.

**Implementation:**
```gdscript
# photography_system.gd

func get_night_evidence_score() -> float:
    var unique_best := {}  # anomaly_id → highest photo_score
    for photo in photos_this_night:
        for entry in photo.anomalies:
            if entry.anomaly_id not in unique_best or entry.photo_score > unique_best[entry.anomaly_id]:
                unique_best[entry.anomaly_id] = entry.photo_score

    var total := anomaly_system.get_total_count()
    if total == 0:
        return 0.0

    var sum := 0.0
    for score in unique_best.values():
        sum += score

    return sum / total

func get_night_grade() -> StringName:
    var score := get_night_evidence_score()
    if score >= night_grade_thresholds[0]:  # 0.70
        return "A"
    elif score >= night_grade_thresholds[1]:  # 0.50
        return "B"
    elif score >= night_grade_thresholds[2]:  # 0.30
        return "C"
    elif score >= night_grade_thresholds[3]:  # 0.15
        return "D"
    else:
        return "F"

func get_photos_for_submission() -> Array[PhotoRecord]:
    return photos_this_night

func get_unique_anomalies_photographed() -> int:
    var ids := {}
    for photo in photos_this_night:
        for entry in photo.anomalies:
            ids[entry.anomaly_id] = true
    return ids.size()
```

**Design note:** Dividing by `total_anomalies_this_night` (not just photographed count) means the player cannot get a high grade by photographing only easy anomalies. Coverage matters — the boss wants comprehensive evidence.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: Per-photo scoring and grading (provides the `photo_score` values used in aggregation)
- [Story 007]: Film budget per night (Night Progression owns the budget; Photography consumes it)
- Evidence Submission: Boss debrief presentation (consumes the score, not the computation)
- Photo Gallery: Photo review and selection (separate presentation-layer system)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PHO-13**: Night 3 partial coverage → Grade C
  - Given: 6 anomalies total, 4 photographed with best scores [0.72, 0.45, 0.38, 0.61]
  - When: Call `get_night_evidence_score()`
  - Then: Returns (0.72 + 0.45 + 0.38 + 0.61) / 6 = 2.16 / 6 = 0.36 → Night Grade C
  - Edge cases: 0.36 exactly → Grade C (≥ 0.30 threshold); 0.299 → Grade D; duplicate photo of anomaly 1 with score 0.80 → unique_best[1] = 0.80 (replaces 0.72), score = (0.80+0.45+0.38+0.61)/6 = 0.397

- **AC-PHO-14**: Zero photos → Grade F
  - Given: Player exits night without photographing anything
  - When: Evidence Submission calls `get_night_evidence_score()`
  - Then: Returns 0.0; `get_photos_for_submission()` returns empty array; `get_unique_anomalies_photographed()` returns 0
  - Edge cases: anomalies_total = 0 (no anomalies placed) → returns 0.0 (not NaN — `max(1, 0)` = 1, sum = 0, 0/1 = 0.0); photos taken but none detected (all F grades) → unique_best is empty, sum = 0, returns 0.0

- **AC-PHO-15**: Perfect photos of few anomalies → still Grade F (coverage penalty)
  - Given: 12 anomalies total, 2 photographed with best scores [0.80, 0.80]
  - When: Call `get_night_evidence_score()`
  - Then: Returns (0.80 + 0.80) / 12 = 1.60 / 12 = 0.133 → Night Grade F (< 0.15)
  - Edge cases: need at least 2 anomalies with A-grade to reach 0.15: (0.80 + 0.95) / 12 = 0.146 → still F; (0.80 + 1.00) / 12 = 0.150 → Grade D (barely); 6 anomalies with 0.50 each → 3.0/12 = 0.25 → Grade D; all 12 with 0.50 → 6.0/12 = 0.50 → Grade B

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/photography/evidence_score_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (Photo Scoring — provides per-photo scores), Anomaly System must be DONE (provides `get_total_count()`)
- Unlocks: Evidence Submission (consumes `get_photos_for_submission()` and `get_night_evidence_score()` at DEBRIEF)
