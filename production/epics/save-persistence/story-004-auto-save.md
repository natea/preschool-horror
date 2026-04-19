# Story 004: Auto-Save and Save Triggers

> **Epic**: Save/Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-SAV-005`, `TR-SAV-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Save System)
**ADR Decision Summary**: Auto-save every 30 seconds during gameplay. No save during anomaly detection or monster encounters (critical moments). Manual save via pause menu. Debounce saves (minimum 1 second between saves).

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Signal-based save events. `game_saved(slot)` signal for save completion.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: AUTO_SAVE_INTERVAL constant. Critical moment flags from Night Progression.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure. Static typing.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Timer-based auto-save via `_process(delta)` accumulator. Signal connections for critical moment flags.

**Control Manifest Rules (Foundation layer)**:
- Required: Auto-save every 30 seconds during gameplay
- Required: No saves during critical moments (anomaly detection, monster encounters)
- Guardrail: Debounce saves (minimum 1 second between saves)

---

## Acceptance Criteria

*From GDD `design/gdd/save-persistence.md`, scoped to this story:*

- [ ] AC-SAV-10: GIVEN gameplay is active and no critical moment is in progress, WHEN 30 seconds have elapsed since the last save, THEN an auto-save triggers to the current slot, saving player position, current night, and boss state.

- [ ] AC-SAV-11: GIVEN a critical moment signal fires (anomaly_detected or monster_encounter), WHEN an auto-save timer is active, THEN the auto-save is suppressed until the critical moment ends. Any auto-save that was due during the critical moment fires immediately after it ends (if still 30s since previous save).

- [ ] AC-SAV-12: GIVEN manual save is requested via pause menu, WHEN the save completes, THEN game state is saved to the selected slot and `game_saved(slot)` signal emits. If a save occurred less than 1 second ago, the manual save is debounced (waits 1s from the last save).

- [ ] AC-SAV-13: GIVEN the player is in an active night, WHEN a manual save is requested, THEN the save is blocked and a message is shown: "Cannot save during active night. Complete the night first."

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

```gdscript
# auto_save_system.gd — auto-save and trigger management

const AUTO_SAVE_INTERVAL: float = 30.0
const SAVE_DEBOUNCE_SECONDS: float = 1.0

var _auto_save_timer: float = 0.0
var _last_save_time: float = 0.0
var _is_in_critical_moment: bool = false
var _pending_save: bool = false
var _is_active_night: bool = false

signal auto_save_triggered(slot: int)
signal save_blocked(message: String)

func _process(delta: float) -> void:
    if _is_in_critical_moment:
        return
    if _is_active_night:
        return  # No saves during active night

    _auto_save_timer += delta
    if _auto_save_timer >= AUTO_SAVE_INTERVAL:
        _auto_save_timer = 0.0
        _trigger_auto_save()

func _trigger_auto_save() -> void:
    var game_data := _collect_game_data()
    var slot := _get_current_slot()
    if SaveManager.save_game(slot, game_data):
        _last_save_time = Time.get_unix_time_from_system()
        auto_save_triggered.emit(slot)

func on_anomaly_detected() -> void:
    _is_in_critical_moment = true

func on_anomaly_cleared() -> void:
    _is_in_critical_moment = false
    # Check if auto-save was due during critical moment
    if _auto_save_timer >= AUTO_SAVE_INTERVAL:
        _trigger_auto_save()
        _auto_save_timer = 0.0

func on_monster_encounter() -> void:
    _is_in_critical_moment = true

func on_monster_encounter_ended() -> void:
    _is_in_critical_moment = false
    if _auto_save_timer >= AUTO_SAVE_INTERVAL:
        _trigger_auto_save()
        _auto_save_timer = 0.0

func on_night_started() -> void:
    _is_active_night = true

func on_night_ended() -> void:
    _is_active_night = false

func on_debrief_completed() -> void:
    # Save after debrief (explicit trigger, not auto)
    var game_data := _collect_game_data()
    var slot := _get_current_slot()
    SaveManager.save_game(slot, game_data)

func on_boss_transformation() -> void:
    var game_data := _collect_game_data()
    var slot := _get_current_slot()
    SaveManager.save_game(slot, game_data)

func on_game_won() -> void:
    var game_data := _collect_game_data()
    var slot := _get_current_slot()
    SaveManager.save_game(slot, game_data)

func request_manual_save(slot: int) -> void:
    if _is_active_night:
        save_blocked.emit("Cannot save during active night. Complete the night first.")
        return
    var time_since_last_save := Time.get_unix_time_from_system() - _last_save_time
    if time_since_last_save < SAVE_DEBOUNCE_SECONDS:
        # Debounce: wait for remaining time
        var wait_time := SAVE_DEBOUNCE_SECONDS - time_since_last_save
        await get_tree().create_timer(wait_time).timeout
        var game_data := _collect_game_data()
        SaveManager.save_game(slot, game_data)
    else:
        var game_data := _collect_game_data()
        SaveManager.save_game(slot, game_data)

func _collect_game_data() -> Dictionary:
    return {
        "current_night": NightProgression.current_night,
        "boss_anger": NightProgression.boss_anger,
        "cumulative_pay": EvidenceSubmission.cumulative_pay,
        "story_flags": NightProgression.story_flags,
        "player_position": FPC.position,
    }

func _get_current_slot() -> int:
    return 1  # Default slot; UI selects slot for manual save
```

*Derived from ADR-0010 Save Triggers:*

- Auto-save: every 30 seconds during gameplay
- Manual save: after debrief_completed, on boss_transformation, on game_won
- No save during anomaly detection or monster encounters
- Debounce: minimum 1 second between saves

*Derived from GDD Save Triggers:*

- After debrief completed: save immediately
- On boss transformation (boss_anger reaches 10): save immediately
- On game won (Night 7 escape): save immediately

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Save Manager core (provides save/load API)
- [Story 002/003]: Platform backends (auto-save uses SaveManager which delegates to backend)
- [Story 005]: Save validation (validation happens on load, not save)
- [Story 006]: Death persistence (what persists vs resets is handled at save time)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-SAV-10**: Auto-save fires at 30s interval
  - Given: Gameplay active, critical moment = false, active night = false
  - When: 30 seconds elapse since last save
  - Then: Auto-save triggers; player position, current night, boss state saved; `auto_save_triggered(slot)` signal emits
  - Edge cases: Timer at 29.9s → no save; timer at 30.0s → save fires; rapid game state changes during interval → saves latest state

- **AC-SAV-11**: Critical moment suppresses auto-save
  - Given: Auto-save timer at 28s, critical moment begins
  - When: Critical moment lasts 5 seconds, then ends
  - Then: Auto-save fires immediately after critical moment ends (timer was at 33s, exceeds 30s threshold); timer resets to 0
  - Edge cases: Critical moment ends at 29s → no auto-save (below threshold); next critical moment at 31s → suppressed, fires at 31s after second critical moment ends

- **AC-SAV-12**: Manual save with debounce
  - Given: Last save was 0.5 seconds ago
  - When: Manual save requested
  - Then: Save is debounced — waits 0.5s, then saves; `game_saved(slot)` signal emits
  - Edge cases: Last save 2s ago → immediate save; multiple manual saves in 0.5s → only last one triggers save

- **AC-SAV-13**: Save blocked during active night
  - Given: Active night in progress
  - When: Manual save requested
  - Then: Save does NOT occur; message "Cannot save during active night. Complete the night first." shown
  - Edge cases: Night just started → blocked; night nearly ended → still blocked; debrief just completed → unblocked, save allowed

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/save/auto_save_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (SaveManager core API available)
- Unlocks: Story 006 (death persistence reads auto-save data), Night Progression integration
