# Story 002: Difficulty Scaling Formulas

> **Epic**: Night Progression
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/night-progression.md` (Horror Tier, Anomaly Target, Monster Count sections)
**Requirement**: `TR-NP-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: All tuning knobs (`ANOMALY_BASE`, `ANOMALY_SCALE`, `MONSTER_BASE`, `MONSTER_SCALE`, `TIER_MAP`) from TuningKnobs. Horror tier lookup table is design decision, not computed.

**ADR Governing Implementation**: ADR-0001 (Scene Architecture)
**ADR Decision Summary**: Night Progression passes `horror_tier(n)` to `configure_for_night(n)` but does not resolve tier multipliers — Room Management owns the multiplier values.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Simple arithmetic formulas. No special engine APIs.

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/night-progression.md`, scoped to this story:*

- [ ] AC-NP-03: GIVEN `ANOMALY_BASE = 3` and `ANOMALY_SCALE = 1.5`, WHEN `anomaly_target(n)` is evaluated for n=1-7, THEN outputs are 3, 4, 6, 7, 9, 10, 12.

- [ ] AC-NP-04: GIVEN `anomaly_target(n)` exceeds total available spawn slots, WHEN Night Progression passes the target to Anomaly Placement, THEN the value is clamped to `min(anomaly_target(n), total_available_slots)`.

- [ ] AC-NP-05: GIVEN `MONSTER_BASE = 1` and `MONSTER_SCALE = 0.5`, WHEN `monster_count(n)` is evaluated for n=1-7, THEN outputs are 0, 0, 1, 1, 2, 2, 3.

- [ ] AC-NP-06: GIVEN current night is 7 and LOADING completes, WHEN phase transitions, THEN it enters INTRO (not ACTIVE) and `night_7_cutscene_start` is emitted.

- [ ] AC-NP-07: GIVEN current night is 1-6 and LOADING completes, WHEN phase transitions, THEN it enters ACTIVE directly (INTRO is zero-length) and no `night_7_cutscene_start` is emitted.

---

## Implementation Notes

*Derived from ADR-0004 Data-Driven + ADR-0001 Scene Architecture:*

**Anomaly target formula:**
```gdscript
# night_progression.gd

const ANOMALY_BASE: int = 3
const ANOMALY_SCALE: float = 1.5

func get_anomaly_target(night: int) -> int:
    return ANOMALY_BASE + int(floor(ANOMALY_SCALE * (night - 1)))
```

**Monster count formula:**
```gdscript
# night_progression.gd

const MONSTER_BASE: int = 1
const MONSTER_SCALE: float = 0.5

func get_monster_count(night: int) -> int:
    if night < 3:
        return 0
    elif night == 3:
        return MONSTER_BASE
    else:
        return MONSTER_BASE + int(floor(MONSTER_SCALE * (night - 3)))
```

**Horror tier lookup:**
```gdscript
# night_progression.gd

const TIER_MAP: Array[int] = [1, 1, 2, 2, 3, 3, 3]

func get_horror_tier(night: int) -> int:
    if night < 1 or night > 7:
        push_error("Invalid night number: %d" % night)
        return 1
    return TIER_MAP[night - 1]
```

**Night 7 intro logic:**
```gdscript
# night_progression.gd

func _on_loading_complete() -> void:
    if current_night == 7:
        _transition_to(NightPhase.INTRO)
        night_7_cutscene_start.emit()
        # Wait for night_7_cutscene_complete or INTRO_MAX_DURATION timeout
    else:
        _transition_to(NightPhase.ACTIVE)
```

**Anomaly clamping:**
```gdscript
# night_progression.gd

func _configure_anomaly_placement(night: int) -> void:
    var target := get_anomaly_target(night)
    var total_slots := room_manager.get_total_spawn_slots()
    var clamped_target := mini(target, total_slots)
    # Call reserved config method (check autoload exists first)
    if has_node("AnomalyPlacementEngine"):
        var ape := get_node("AnomalyPlacementEngine")
        ape.configure_for_night(night, clamped_target)
    else:
        push_warning("AnomalyPlacementEngine autoload not found — skipping anomaly configuration")
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Timer duration formula (separate story for timer countdown)
- [Story 003]: Phase transitions (config calls are part of LOADING, handled in Story 005)
- [Story 004]: DEBRIEF counter logic
- [Story 005]: Configuration orchestration (Night Progression calls configure_for_night; Room Management and Audio implement the configure methods)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-NP-03**: Anomaly target formula
  - Given: ANOMALY_BASE = 3, ANOMALY_SCALE = 1.5
  - When: Evaluate `get_anomaly_target(n)` for n=1-7
  - Then: Returns 3, 4, 6, 7, 9, 10, 12 respectively
  - Edge cases: n=1 → 3 + floor(0) = 3; n=2 → 3 + floor(1.5) = 4; n=3 → 3 + floor(3.0) = 6; n=4 → 3 + floor(4.5) = 7; n=7 → 3 + floor(9.0) = 12; floor(1.5 * 5) = floor(7.5) = 7, not 8

- **AC-NP-04**: Anomaly clamping
  - Given: anomaly_target(7) = 12, total_available_slots = 10
  - When: Night Progression passes target to Anomaly Placement Engine
  - Then: Clamped value = 10 is passed
  - Edge cases: target < slots → no clamping (e.g., Night 1: 3 < 10 → passes 3); target == slots → no clamping needed; total_slots = 0 → clamped to 0 (no anomalies placed — edge case for empty build)

- **AC-NP-05**: Monster count formula
  - Given: MONSTER_BASE = 1, MONSTER_SCALE = 0.5
  - When: Evaluate `get_monster_count(n)` for n=1-7
  - Then: Returns 0, 0, 1, 1, 2, 2, 3 respectively
  - Edge cases: n<3 → always 0 (floor of negative would be handled by early return); n=3 → exactly MONSTER_BASE (1); n=4 → 1 + floor(0.5) = 1 + 0 = 1; n=5 → 1 + floor(1.0) = 2; n=7 → 1 + floor(2.5) = 1 + 2 = 3

- **AC-NP-06**: Night 7 enters INTRO
  - Given: current_night = 7, LOADING completes
  - When: Phase transition runs
  - Then: Enters INTRO phase (not ACTIVE); `night_7_cutscene_start` emits
  - Edge cases: cutscene signal not received within 30s → timeout to ACTIVE (per GDD); cutscene system absent → same timeout behavior

- **AC-NP-07**: Nights 1-6 skip INTRO
  - Given: current_night = 1-6, LOADING completes
  - When: Phase transition runs
  - Then: Enters ACTIVE directly; no `night_7_cutscene_start` emitted
  - Edge cases: n=1 → ACTIVE; n=6 → ACTIVE; all identical behavior (zero-length INTRO)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/night-progression/scaling_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (formulas are self-contained)
- Unlocks: Story 003 (Night Lifecycle — config calls use these formulas), Room/Level Management (consumes horror_tier and monster_count), Audio System (consumes horror_tier), Anomaly Placement Engine (consumes anomaly_target), Monster AI (consumes monster_count)
