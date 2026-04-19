# Story 003: Activation Lifecycle

> **Epic**: Anomaly System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/anomaly-system.md` (States and Transitions — Environmental Anomaly States section)
**Requirement**: `TR-AS-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `player_entered_room` / `player_exited_room` signals from Room Management. `anomaly_activated` emission on state change. No signal chains.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Stagger delay parameters from TuningKnobs (STAGGER_BASE, STAGGER_INCREMENT).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Timer-based stagger activation. State transitions on environmental anomalies only (monster states managed by Monster AI). Room boundary signals from Room Management.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/anomaly-system.md`, scoped to this story:*

- [ ] AC-AS-05: GIVEN 3 anomalies placed in Main Classroom in DORMANT state, WHEN `player_entered_room(&"main_classroom")` fires, THEN all 3 anomalies transition to ACTIVE within 0.2 s (stagger delay) and `anomaly_activated` is emitted 3 times.

- [ ] AC-AS-06: GIVEN anomalies in Main Classroom are ACTIVE, WHEN `player_exited_room(&"main_classroom")` fires, THEN anomalies remain in ACTIVE state (do not revert to DORMANT).

- [ ] AC-AS-07: GIVEN a room with 0 anomalies in the manifest, WHEN `player_entered_room` fires for that room, THEN no errors occur and no `anomaly_activated` signals are emitted.

---

## Implementation Notes

*Derived from ADR-0003 Communication + GDD States and Transitions:*

```gdscript
# Activation on room entry
func _on_player_entered_room(room_id: StringName) -> void:
    var room_anomalies := get_anomalies_in_room(room_id)
    if room_anomalies.is_empty():
        return  # AC-AS-07: empty room, no errors

    for i in range(room_anomalies.size()):
        var instance := room_anomalies[i]
        if instance.state == &"DORMANT":
            var stagger := STAGGER_BASE + (i * STAGGER_INCREMENT)
            # Use a per-anomaly timer for stagger
            instance.activate_timer = stagger
            instance.activate_delay = stagger
            # State remains DORMANT until timer expires → ACTIVE
            # anomaly_activated emitted when transition completes

# Activation timer (per anomaly, in AnomalyInstance)
func _process(delta: float) -> void:
    if activate_delay > 0.0:
        activate_delay -= delta
        if activate_delay <= 0.0:
            _activate()

func _activate() -> void:
    if state == &"DORMANT":
        state = &"ACTIVE"
        anomaly_activated.emit(self)
        # Make visible (if previously invisible)
        _set_visual_state(true)
```

*Exit behavior (DORMANT → ACTIVE is one-way):*

```gdscript
# player_exited_room does NOT revert ACTIVE → DORMANT
# Per GDD: "once the room is corrupted, it stays corrupted for the night"
func _on_player_exited_room(room_id: StringName) -> void:
    # No state changes — anomalies remain ACTIVE
    pass
```

*Stagger delay parameters (from TuningKnobs):*
- STAGGER_BASE = 0.0 s
- STAGGER_INCREMENT = 0.05 s
- Max stagger for 8 anomalies = 0.35 s (within 0.4 s GDD bound)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Manifest instantiation (creates the DORMANT instances)
- [Story 006]: Night lifecycle cleanup (clears all states)
- Monster AI: monster state management (monsters skip DORMANT, start ACTIVE)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AS-05**: DORMANT → ACTIVE on room entry
  - Given: 3 environmental anomalies in Main Classroom in DORMANT state
  - When: `player_entered_room(&"main_classroom")` fires
  - Then: Anomaly 0 activates at 0.0s, Anomaly 1 at 0.05s, Anomaly 2 at 0.10s; `anomaly_activated` emitted 3 times; all within 0.2s
  - Edge cases: 8 anomalies → stagger from 0.0s to 0.35s; room entry during stagger → no re-trigger (timers continue); rapid room entry/exit → first entry triggers, subsequent entries ignored (anomalies already ACTIVE)

- **AC-AS-06**: Active anomalies persist on exit
  - Given: 3 anomalies in Main Classroom are ACTIVE
  - When: `player_exited_room(&"main_classroom")` fires
  - Then: All 3 remain ACTIVE; no `anomaly_activated` re-emitted; no visual change
  - Edge cases: player re-enters room → no re-trigger (already ACTIVE); player exits then monster moves into room → anomaly remains ACTIVE (not a state change trigger)

- **AC-AS-07**: Empty room handling
  - Given: Room with 0 anomalies in the manifest
  - When: `player_entered_room` fires for that room
  - Then: No errors, no signals emitted, no state changes
  - Edge cases: room exists but no spawn slots → no anomalies placed, same behavior; room not in RoomData → no signal received, no error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/anomaly_system/activation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 must be DONE (instances must exist before they can activate), Room/Level Management must be DONE (room entry signals)
- Unlocks: Story 004 (photo detection only evaluates ACTIVE anomalies), Audio System (proximity audio on activation)
