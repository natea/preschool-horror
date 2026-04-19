# Story 004: Spawn Slot Formula

> **Epic**: Room/Level Management
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/room-level-management.md`
**Requirement**: `TR-RLM-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: active_spawn_slots formula in GDD. Tier multipliers from constants. Output clamped to base_spawn_slots. Floor-rounded. Zero is a valid output.

**ADR Governing Implementation**: ADR-0003 (Signal Communication)
**ADR Decision Summary**: room_state_changed signal emitted when active_spawn_slots changes (via configure_for_night).

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: Static typing. System-based directory structure.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Formula: `active_spawn_slots(R, N) = floor(base_spawn_slots(R) * tier_multiplier(N))`. Tier multipliers: 0.25 (Tier 1), 0.50 (Tier 2), 1.00 (Tier 3).

**Control Manifest Rules (Foundation layer)**:
- Required: Static typing on all class members
- Guardrail: Formula must produce integer output (floor-rounded)

---

## Acceptance Criteria

*From GDD `design/gdd/room-level-management.md`, scoped to this story:*

- [ ] AC-RLM-06: GIVEN main_classroom has base_spawn_slots = 8, WHEN configure_for_night(2) is called (Tier 1, multiplier 0.25), THEN active_spawn_slots == 2.

- [ ] AC-RLM-07: GIVEN main_classroom has base_spawn_slots = 8, WHEN configure_for_night(4) is called (Tier 2, multiplier 0.50), THEN active_spawn_slots == 4.

- [ ] AC-RLM-08: GIVEN main_classroom has base_spawn_slots = 8, WHEN configure_for_night(6) is called (Tier 3, multiplier 1.00), THEN active_spawn_slots == 8.

- [ ] AC-RLM-09: GIVEN a room has base_spawn_slots = 3, WHEN configure_for_night(1) is called (Tier 1, floor(3 * 0.25) = 0), THEN active_spawn_slots == 0 AND get_room_spawn_points() returns an empty array without error.

---

## Implementation Notes

*Derived from ADR-0004 Implementation Guidelines:*

```gdscript
# RoomManager.gd — spawn slot formula

const TIER_MULTIPLIER_1: float = 0.25
const TIER_MULTIPLIER_2: float = 0.50
const TIER_MULTIPLIER_3: float = 1.00

func _calculate_active_slots(base_slots: int, tier: int) -> int:
    var multiplier := _get_tier_multiplier(tier)
    return floori(base_slots * multiplier)

func _get_tier_multiplier(tier: int) -> float:
    match tier:
        1: return TIER_MULTIPLIER_1
        2: return TIER_MULTIPLIER_2
        3: return TIER_MULTIPLIER_3
        _: return 0.0  # Invalid tier → no slots

func _apply_night_config(night: int) -> void:
    var tier := _night_to_tier(night)
    for room_id in rooms:
        var state: RoomState = rooms[room_id]
        var data: RoomData = state.data
        var old_slots := state.active_spawn_slots
        state.active_spawn_slots = _calculate_active_slots(data.base_spawn_slots, tier)
        # Emit room_state_changed if active_spawn_slots changed
        if state.active_spawn_slots != old_slots:
            room_state_changed.emit(room_id, state)
```

*Derived from GDD Formulas:*

- Main Classroom (8 base slots): Night 2 = floor(8 * 0.25) = 2, Night 4 = floor(8 * 0.50) = 4, Night 6 = floor(8 * 1.00) = 8
- Art Corner (4 base slots): Night 1 = floor(4 * 0.25) = 1, Night 3 = floor(4 * 0.50) = 2, Night 7 = floor(4 * 1.00) = 4
- Small room (3 base slots): Night 1 = floor(3 * 0.25) = 0 (valid — no anomalies)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: configure_for_night() orchestration (formula is called from within)
- [Story 005]: LOCKED room spawn point queries (get_room_spawn_points for LOCKED rooms)
- [Anomaly Placement Epic]: Using active_spawn_slots for anomaly placement

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-RLM-06**: Main Classroom Tier 1
  - Given: base_spawn_slots = 8, tier = 1 (multiplier 0.25)
  - When: _calculate_active_slots(8, 1)
  - Then: Returns 2
  - Edge cases: floor(8 * 0.25) = 2.0 exactly; no rounding error

- **AC-RLM-07**: Main Classroom Tier 2
  - Given: base_spawn_slots = 8, tier = 2 (multiplier 0.50)
  - When: _calculate_active_slots(8, 2)
  - Then: Returns 4
  - Edge cases: floor(8 * 0.50) = 4.0 exactly

- **AC-RLM-08**: Main Classroom Tier 3
  - Given: base_spawn_slots = 8, tier = 3 (multiplier 1.00)
  - When: _calculate_active_slots(8, 3)
  - Then: Returns 8
  - Edge cases: floor(8 * 1.00) = 8.0 exactly; equals base_spawn_slots

- **AC-RLM-09**: Zero active slots
  - Given: base_spawn_slots = 3, tier = 1 (multiplier 0.25)
  - When: _calculate_active_slots(3, 1)
  - Then: Returns 0; get_room_spawn_points() returns [] without error
  - Edge cases: floor(3 * 0.25) = floor(0.75) = 0; zero is intentional, not an error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/room/spawn_slots_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 must be DONE (configure_for_night must call the formula)
- Unlocks: Anomaly Placement Engine stories (consume active_spawn_slots)
