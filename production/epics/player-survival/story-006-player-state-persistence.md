# Story 006: Player State Persistence

> **Epic**: Player Survival
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Player Survival section)
**Requirement**: `TR-PLA-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Save System)
**ADR Decision Summary**: Player state serialized to save slots via SaveManager. Player position, vulnerability bar, inventory, and flashlight battery level saved per slot.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Signal-based save events — `player_state_saved`, `player_state_loaded`. No signal chains.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Player state dictionary structure defined in TuningKnobs schema. No hardcoded field names.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Serialization via JSON.stringify/JSON.parse for Dictionary. SaveManager handles file I/O. No post-cutoff API changes expected for JSON or Dictionary serialization.

**Control Manifest Rules (Foundation layer)**:
- Required: Player state saved on exit, on night change, and on manual save
- Required: Save validation before state restoration
- Required: No saves during critical moments (anomaly detection, monster encounters)

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md`, scoped to this story:*

- [ ] AC-PLA-21: GIVEN the player has been playing, WHEN a save is triggered (manual, auto-save, or night change), THEN the following player state is saved: current vulnerability bar value, inventory contents, flashlight battery level, player position.

- [ ] AC-PLA-22: GIVEN a saved game, WHEN the player loads the save, THEN the player state is restored: vulnerability bar restored to saved value, inventory restored, flashlight battery restored, player position restored.

- [ ] AC-PLA-23: GIVEN the player dies, WHEN the last save is reloaded, THEN the player state is restored to the saved values minus death-penalty adjustments (per GDD death persistence rules).

---

## Implementation Notes

*Derived from ADR-0010 Save System:*

```gdscript
# Player state dictionary structure:
var player_state := {
    "vulnerability_bar": 0.0,
    "inventory": [],
    "flashlight_battery": 1.0,
    "flashlight_state": "off",  # "on", "off", "depleted"
    "player_position": Vector3(0, 0, 0),
    "player_rotation": Vector3(0, 0, 0),
}

# Save via SaveManager:
# SaveManager.save_slot(slot_index, player_state, additional_data)

# Load via SaveManager:
# var state := SaveManager.load_slot(slot_index)
```

*Save triggers:*

- Manual save: player activates save input
- Auto-save: every 30 seconds during gameplay (delegated to SaveManager)
- Night change: at end of each night
- Game exit: before scene unload

*Load behavior:*

```gdscript
# On load, apply restored state:
func apply_loaded_state(state: Dictionary) -> void:
    vulnerability_bar = state.get("vulnerability_bar", 0.0)
    inventory = state.get("inventory", [])
    flashlight_battery = state.get("flashlight_battery", 1.0)
    flashlight_state = state.get("flashlight_state", "off")
    player_position = state.get("player_position", Vector3.ZERO)
    player_rotation = state.get("player_rotation", Vector3.ZERO)

    # Emit signal after restoration
    player_state_loaded.emit(state)
```

*Derived from ADR-0003 Communication:*

- Emit `player_state_saved(state: Dictionary)` after successful save
- Emit `player_state_loaded(state: Dictionary)` after successful load
- Do NOT chain signals — HUD and other systems subscribe directly

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: SaveManager core API (this uses the API, doesn't define it)
- [Story 006 of Save Persistence]: Settings death persistence (separate persistence rules)
- [Night Progression epic]: Night-specific state (night number, story flags)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PLA-21**: Player state saved
  - Given: vulnerability_bar = 0.7, inventory = [photo_A, flashlight], flashlight_battery = 0.5, player at (3.0, 1.0, -2.0)
  - When: Save triggered (manual/auto/night change)
  - Then: Save slot contains {vulnerability_bar: 0.7, inventory: [...], flashlight_battery: 0.5, player_position: (3.0, 1.0, -2.0)}
  - Edge cases: save with empty inventory → saved as `[]`; save with flashlight off → flashlight_battery still recorded; save at midnight → save still proceeds (no critical moment)

- **AC-PLA-22**: Player state restored on load
  - Given: Save with vulnerability_bar = 0.7, inventory = [photo_A], flashlight_battery = 0.5, player at (3.0, 1.0, -2.0)
  - When: Load save
  - Then: All player state values match saved values; `player_state_loaded` signal fires
  - Edge cases: save file missing a field → use default (vulnerability_bar = 0.0, battery = 1.0, position = origin); save with corrupted inventory → load fails, state resets to defaults

- **AC-PLA-23**: Death reload with penalty
  - Given: Save with vulnerability_bar = 0.3, inventory = [photo_A, photo_B], flashlight_battery = 0.8
  - When: Player dies, last save reloaded
  - Then: State restored from save; death-penalty adjustments applied (per GDD: boss_anger and cumulative_pay persist; consecutive_nights_no_photos resets; inventory persists)
  - Edge cases: no previous save → start new game; save from night 1 death → minimal penalties applied

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/player_survival/state_persistence_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (SaveManager core API), Story 003 must be DONE (inventory data to save), Story 005 must be DONE (flashlight state to save)
- Unlocks: Player Survival epic complete
