# Story 003: Night Configuration

> **Epic**: Room/Level Management
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/room-level-management.md`
**Requirement**: `TR-RLM-005`, `TR-RLM-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Single-Scene Architecture)
**ADR Decision Summary**: RoomManager scene-local node. configure_for_night() called by Night Progression at night start. State transitions fire once, not polled.

**ADR Governing Implementation**: ADR-0003 (Signal Communication)
**ADR Decision Summary**: configure_for_night() is a top-down configuration call (permitted pattern). room_unlocked signal emitted when Principal's Office unlocks.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: Horror tier multipliers from constants (tier_multipliers in entities.yaml). RoomData.first_accessible_night used for access control.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: No Autoloads. Static typing. System-based directory structure.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Tier multipliers: 0.25 (Tier 1), 0.50 (Tier 2), 1.00 (Tier 3). Night-to-tier mapping: Nights 1-2 = Tier 1, Nights 3-4 = Tier 2, Nights 5-7 = Tier 3.

**Control Manifest Rules (Foundation layer)**:
- Required: Static typing on all class members
- Forbidden: Autoloads for room state
- Guardrail: configure_for_night() must complete synchronously

---

## Acceptance Criteria

*From GDD `design/gdd/room-level-management.md`, scoped to this story:*

- [ ] AC-RLM-05: GIVEN configure_for_night(3) is called, WHEN the call completes, THEN every room with first_accessible_night <= 3 has access_state == ACCESSIBLE, every room with first_accessible_night > 3 has access_state == LOCKED, and horror_tier == 2 on all rooms.

- [ ] AC-RLM-10: GIVEN the player is inside a room AND configure_for_night() sets that room to LOCKED, WHEN the player's position is checked, THEN the player remains at their current position (no teleport) and get_current_room() still returns that room.

- [ ] AC-RLM-13: GIVEN a fresh game state, WHEN configure_for_night(N) is called for any N in {1, 2, 3, 4, 5, 6}, THEN principals_office.access_state == LOCKED.

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

```gdscript
# RoomManager.gd — night configuration

const TIER_1_NIGHTS: int = 2
const TIER_2_NIGHTS: int = 4
# Tier 3: Nights 5-7 (implicit)

func configure_for_night(night: int) -> void:
    var tier := _night_to_tier(night)
    for room_id in rooms:
        var state: RoomState = rooms[room_id]
        var data: RoomData = state.data
        # Access state
        if data.first_accessible_night <= night:
            state.access_state = RoomState.AccessState.ACCESSIBLE
        else:
            state.access_state = RoomState.AccessState.LOCKED
        # Horror tier
        state.horror_tier = tier
        # Active spawn slots (delegated to Story 004 formula)
        state.active_spawn_slots = _calculate_active_slots(data.base_spawn_slots, tier)
        # Lights on (driven by horror tier)
        state.lights_on = tier < 3  # Tier 3: some lights off
    # Principal's Office special case: always LOCKED Nights 1-6
    if night < 7 and rooms.has(&"principals_office"):
        rooms[&"principals_office"].access_state = RoomState.AccessState.LOCKED

func _night_to_tier(night: int) -> int:
    if night <= TIER_1_NIGHTS:
        return 1
    elif night <= TIER_2_NIGHTS:
        return 2
    else:
        return 3

func unlock_room(room_id: StringName) -> void:
    if rooms.has(room_id):
        rooms[room_id].access_state = RoomState.AccessState.ACCESSIBLE
        room_unlocked.emit(room_id)
```

*Derived from ADR-0004 Implementation Guidelines:*

- Horror tier multipliers (from entities.yaml): TIER_1 = 0.25, TIER_2 = 0.50, TIER_3 = 1.00
- RoomData.first_accessible_night: entry_hall=1, main_classroom=1, art_corner=1, cubby_hall=2, nap_room=2, bathroom=3, principals_office=7

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 004]: Spawn slot formula (active_spawn_slots calculation)
- [Story 005]: Principal's Office unlock signal (room_unlocked emission)
- [Night Progression Epic]: configure_for_night call timing (driven by Night Progression)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-RLM-05**: configure_for_night(3) room access
  - Given: configure_for_night(3) called
  - When: Call completes
  - Then: Rooms with first_accessible_night <= 3 are ACCESSIBLE; rooms with first_accessible_night > 3 are LOCKED; all rooms have horror_tier = 2
  - Edge cases: Night 1 → Tier 1, only entry_hall/main_classroom/art_corner accessible; Night 7 → Tier 3, all rooms accessible except Principals Office (LOCKED until unlock_room called)

- **AC-RLM-10**: LOCKED room player safety
  - Given: Player inside a room
  - When: configure_for_night() sets that room to LOCKED
  - Then: Player position unchanged (no teleport); get_current_room() still returns that room
  - Edge cases: LOCKED blocks entry only, never ejects player; LOCKED room still returns valid current_room

- **AC-RLM-13**: Principal's Office locked Nights 1-6
  - Given: Fresh game state
  - When: configure_for_night(N) called for N in {1, 2, 3, 4, 5, 6}
  - Then: principals_office.access_state == LOCKED
  - Edge cases: Night 7 → LOCKED still (must call unlock_room separately)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/room/night_config_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (RoomState objects must exist)
- Unlocks: Story 004 (spawn slots depend on horror tier set by configure_for_night)
