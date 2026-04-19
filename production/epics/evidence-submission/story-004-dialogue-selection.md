# Story 004: Dialogue Selection

> **Epic**: Evidence Submission
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/evidence-submission.md` (Dialogue Authoring section)
**Requirement**: `TR-ES-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Dialogue entries stored in a dialogue resource (JSON or CSV), keyed by night, grade, and anger level. No hardcoded dialogue strings.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Dialogue selected synchronously during debrief computation, embedded in DebriefData struct. No signal for dialogue selection.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Resource loading via `load()` in `_ready()`. String lookup by key. No special engine APIs.

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/evidence-submission.md`, scoped to this story:*

- [ ] AC-ES-17: GIVEN `night = 3`, `grade = S`, `boss_anger = 0`, WHEN `_select_dialogue()` runs, THEN returns dialogue entry keyed by `night_3_grade_S_low_anger`.

- [ ] AC-ES-18: GIVEN `night = 3`, `grade = F`, `boss_anger = 8`, WHEN `_select_dialogue()` runs, THEN returns dialogue entry keyed by `night_3_grade_F_high_anger`.

- [ ] AC-ES-19: GIVEN `night = 3`, `grade = C`, `boss_anger = 3`, WHEN `_select_dialogue()` runs, THEN returns dialogue entry keyed by `night_3_grade_C_mid_anger`.

- [ ] AC-ES-20: GIVEN `night = 3`, `grade = B`, `boss_anger = 0`, WHEN `_select_dialogue()` runs, THEN returns dialogue entry keyed by `night_3_grade_B_low_anger`.

- [ ] AC-ES-21: GIVEN `night = 3`, `grade = D`, `boss_anger = 7`, WHEN `_select_dialogue()` runs, THEN returns dialogue entry keyed by `night_3_grade_D_high_anger`.

- [ ] AC-ES-22: GIVEN `boss_anger = 7`, `grade = C`, WHEN `_select_dialogue()` runs, THEN anger level is mapped to `high_anger` (anger >= threshold/2).

- [ ] AC-ES-23: GIVEN a dialogue key is requested but no entry exists in the resource, WHEN `_select_dialogue()` runs, THEN returns a default fallback entry (`default_grade_X`).

---

## Implementation Notes

*Derived from ADR-0004 Data-Driven + GDD Dialogue Authoring section:*

**Dialogue selection logic:**
```gdscript
# evidence_submission.gd

var _dialogue_resource: Resource

func _ready() -> void:
    _dialogue_resource = load("res://assets/data/dialogue/evidence_debrief.tres")

func _select_dialogue(night: int, grade: StringName, anger: int) -> String:
    # Determine anger bucket
    var anger_bucket: StringName
    if anger >= ANGER_THRESHOLD:
        anger_bucket = "high_anger"
    elif anger >= ANGER_THRESHOLD / 2:
        anger_bucket = "mid_anger"
    else:
        anger_bucket = "low_anger"

    # Build key: night_N_grade_X_anger_bucket
    var key := "night_%d_grade_%s_%s" % [night, grade, anger_bucket]

    # Look up dialogue entry
    if _dialogue_resource.has_key(key):
        return _dialogue_resource.get(key)

    # Fallback: default_grade_X
    var fallback_key := "default_grade_%s" % grade
    if _dialogue_resource.has_key(fallback_key):
        return _dialogue_resource.get(fallback_key)

    # Ultimate fallback
    return "[no dialogue available]"
```

**Dialogue key format:**
| Component | Format | Example |
|---|---|---|
| Night | `night_N` | `night_3` |
| Grade | `grade_X` | `grade_S` |
| Anger | `low_anger`, `mid_anger`, `high_anger` | `low_anger` |
| Full key | `night_N_grade_X_anger_bucket` | `night_3_grade_S_low_anger` |

**Anger bucket mapping:**
| Anger Level | Bucket | Condition |
|---|---|---|
| Low | `low_anger` | `anger < threshold/2` |
| Mid | `mid_anger` | `threshold/2 <= anger < threshold` |
| High | `high_anger` | `anger >= threshold` |

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine that calls `_select_dialogue` (Story 001 is the debrief flow)
- [Story 007]: Debrief display (renders dialogue text but doesn't select it)
- [Narrative]: Actual dialogue content authoring (written by writer, loaded as resource)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-ES-17**: Low anger + S grade
  - Given: night = 3, grade = S, boss_anger = 0
  - When: _select_dialogue(3, S, 0) runs
  - Then: Returns entry with key `night_3_grade_S_low_anger`
  - Edge cases: grade = A → same bucket (low_anger); anger = 3 → mid_anger bucket

- **AC-ES-18**: High anger + F grade
  - Given: night = 3, grade = F, boss_anger = 8
  - When: _select_dialogue(3, F, 8) runs
  - Then: Returns entry with key `night_3_grade_F_high_anger`
  - Edge cases: anger = 7 → high_anger (at threshold); anger = 6 → mid_anger (below threshold)

- **AC-ES-19**: Mid anger + C grade
  - Given: night = 3, grade = C, boss_anger = 3
  - When: _select_dialogue(3, C, 3) runs
  - Then: Returns entry with key `night_3_grade_C_mid_anger`
  - Edge cases: anger = 3 → mid_anger (threshold/2 = 3.5, so 3 < 3.5 → low_anger? Check boundary); anger = 4 → mid_anger

- **AC-ES-20**: Low anger + B grade
  - Given: night = 3, grade = B, boss_anger = 0
  - When: _select_dialogue(3, B, 0) runs
  - Then: Returns entry with key `night_3_grade_B_low_anger`
  - Edge cases: grade = B, anger = 3 → mid_anger; grade = B, anger = 0 → low_anger

- **AC-ES-21**: High anger + D grade
  - Given: night = 3, grade = D, boss_anger = 7
  - When: _select_dialogue(3, D, 7) runs
  - Then: Returns entry with key `night_3_grade_D_high_anger`
  - Edge cases: anger = 7 → high_anger (at threshold); anger = 6 → mid_anger

- **AC-ES-22**: Anger threshold boundary
  - Given: boss_anger = 7 (threshold), grade = C
  - When: _select_dialogue(3, C, 7) runs
  - Then: anger_bucket = "high_anger" (anger >= threshold)
  - Edge cases: anger = 6 → mid_anger; anger = 3 → low_anger (if threshold/2 = 3.5); anger = 4 → mid_anger

- **AC-ES-23**: Missing dialogue entry
  - Given: night = 3, grade = S, boss_anger = 0, but no `night_3_grade_S_low_anger` key
  - When: _select_dialogue(3, S, 0) runs
  - Then: Falls back to `default_grade_S`; if that also missing, returns `"[no dialogue available]"`
  - Edge cases: dialogue resource empty → ultimate fallback; only default_grade_S exists → returns that

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/evidence-submission/dialogue_selection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (state machine calls `_select_dialogue`)
- Unlocks: Evidence Submission story complete (dialogue is a sub-function of the debrief flow)
