# Story 006: Settings and Death Persistence

> **Epic**: Save/Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-SAV-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Save System)
**ADR Decision Summary**: Settings persisted via ConfigFile (settings.cfg, keybindings.cfg, volume.cfg). Death persistence rules: boss_anger and cumulative_pay persist; consecutive_nights_no_photos resets; inventory persists.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: NightConfig saved/restored. PERSISTS_ON_DEATH and RESET_ON_DEATH constants from GDD.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure. Static typing.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: ConfigFile.get/set_value for settings. Dictionary comparison for death persistence.

**Control Manifest Rules (Foundation layer)**:
- Required: Settings saved on change, loaded on startup
- Required: Death persistence follows PERSISTS_ON_DEATH / RESET_ON_DEATH rules
- Guardrail: Save file size under 50 KB (TARGET_SAVE_SIZE)

---

## Acceptance Criteria

*From GDD `design/gdd/save-persistence.md`, scoped to this story:*

- [ ] AC-SAV-18: GIVEN settings have changed (volume, fullscreen, mouse_sensitivity), WHEN the setting is modified, THEN the change is immediately persisted to `user://settings.cfg` via ConfigFile. On game startup, settings are loaded from ConfigFile and applied before gameplay begins.

- [ ] AC-SAV-19: GIVEN a save with boss_anger=7, cumulative_pay=1750, consecutive_nights_no_photos=1, and inventory=[photo_A, photo_B], WHEN the player dies and the last save is reloaded, THEN boss_anger=7 and cumulative_pay=1750 persist; consecutive_nights_no_photos resets to 0; inventory=[photo_A, photo_B] persists.

- [ ] AC-SAV-20: GIVEN a save file, WHEN its size is measured, THEN the file size is under 50 KB (TARGET_SAVE_SIZE). The save file contains only essential data: current_night, story_flags, boss_anger, cumulative_pay, player_position.

---

## Implementation Notes

*Derived from ADR-0010 Settings Persistence:*

```gdscript
# settings_death_persistence.gd — settings and death persistence

const TARGET_SAVE_SIZE := 50 * 1024  # 50 KB
const SETTINGS_FILE := "user://settings.cfg"
const KEYBINDINGS_FILE := "user://keybindings.cfg"
const VOLUME_FILE := "user://volume.cfg"

# Death persistence rules
const PERSISTS_ON_DEATH := [
    &"current_night",
    &"boss_anger",
    &"cumulative_pay",
    &"story_flags",
]

const RESET_ON_DEATH := [
    &"consecutive_nights_no_photos",
]

# Note: inventory persists on death (not in RESET_ON_DEATH)
# It was captured, not erased.

signal settings_applied()
signal death_state_reset()

# --- Settings ---

func save_setting(key: StringName, value: Variant) -> void:
    var config := ConfigFile.new()
    # Load existing settings first
    if FileAccess.file_exists(SETTINGS_FILE):
        config.load(SETTINGS_FILE)
    config.set_value("settings", str(key), value)
    config.save(SETTINGS_FILE)

func load_settings() -> Dictionary:
    var config := ConfigFile.new()
    if config.load(SETTINGS_FILE) != OK:
        return {}
    return config.get_value("settings", {})

func save_keybinding(key: StringName, value: Variant) -> void:
    var config := ConfigFile.new()
    if FileAccess.file_exists(KEYBINDINGS_FILE):
        config.load(KEYBINDINGS_FILE)
    config.set_value("keybindings", str(key), value)
    config.save(KEYBINDINGS_FILE)

func load_keybindings() -> Dictionary:
    var config := ConfigFile.new()
    if config.load(KEYBINDINGS_FILE) != OK:
        return {}
    return config.get_value("keybindings", {})

func save_volume(bus_name: StringName, db_value: float) -> void:
    var config := ConfigFile.new()
    if FileAccess.file_exists(VOLUME_FILE):
        config.load(VOLUME_FILE)
    config.set_value("volume", str(bus_name), db_value)
    config.save(VOLUME_FILE)

func load_volume() -> Dictionary:
    var config := ConfigFile.new()
    if config.load(VOLUME_FILE) != OK:
        return {}
    return config.get_value("volume", {})

# --- Death Persistence ---

func apply_death_persistence(save_data: Dictionary) -> Dictionary:
    """Apply death persistence rules to loaded save data."""
    var result := {}

    # Fields that persist from save
    for field in PERSISTS_ON_DEATH:
        if save_data.has(field):
            result[field] = save_data[field]

    # Fields that reset on death
    result["consecutive_nights_no_photos"] = 0

    # Inventory persists (not in RESET_ON_DEATH)
    if save_data.has("inventory"):
        result["inventory"] = save_data["inventory"]

    death_state_reset.emit()
    return result

func apply_new_game_defaults() -> Dictionary:
    """Apply defaults for a new game."""
    return {
        "current_night": 1,
        "consecutive_nights_no_photos": 0,
        "story_flags": {},
        "boss_anger": 0,
        "cumulative_pay": 0,
        "inventory": [],
        "player_position": Vector3(0, 0, 0),
    }

# --- Save Size ---

func verify_save_size(file_path: String) -> bool:
    """Check if save file is under TARGET_SAVE_SIZE."""
    if not FileAccess.file_exists(file_path):
        return false
    var file := FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        return false
    var size := file.get_length()
    file.close()
    return size < TARGET_SAVE_SIZE
```

*Derived from ADR-0010 Settings Persistence:*

- Settings: `user://settings.cfg` (fullscreen, quality, mouse_sensitivity, gamepad_deadzone)
- Keybindings: `user://keybindings.cfg` (per-action key mappings)
- Volume: `user://volume.cfg` (per-bus volume in dB)
- ConfigFile (INI format) for all settings persistence
- Settings saved on change, loaded on startup

*Derived from GDD Death Persistence:*

- PERSISTS_ON_DEATH: current_night, boss_anger, cumulative_pay, story_flags
- RESET_ON_DEATH: consecutive_nights_no_photos
- Inventory persists (captured photos were earned, not erased)
- Save path: `user://save_data.dat` (single file, platform-agnostic)

*Derived from GDD Save File Size:*

- TARGET_SAVE_SIZE: 50 KB
- Only essential data saved (no unnecessary state)
- Save file is small JSON — well within web 512 MB quota

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Save Manager core (delegates save/load)
- [Story 003]: Settings file format (ConfigFile, Story 006 manages what goes in it)
- [Story 005]: Save validation (validation is a gate, not persistence logic)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-SAV-18**: Settings persistence
  - Given: Volume changed to -3.0 dB on SFX bus
  - When: `save_volume("sfx", -3.0)` is called, then game restarts
  - Then: `load_volume()` returns `{"sfx": -3.0}`; volume applied to AudioServer before gameplay
  - Edge cases: ConfigFile doesn't exist → load returns {}; volume = -80 dB (silent) → still persisted; volume = 0 dB (max) → persisted

- **AC-SAV-19**: Death persistence
  - Given: Save data = {boss_anger: 7, cumulative_pay: 1750, consecutive_nights_no_photos: 1, inventory: [photo_A, photo_B]}
  - When: Player dies, `apply_death_persistence(save_data)` called
  - Then: Result = {boss_anger: 7, cumulative_pay: 1750, consecutive_nights_no_photos: 0, inventory: [photo_A, photo_B]}
  - Edge cases: Save with no inventory field → result has inventory: []; save with empty story_flags → persists as {}; boss_anger = 10 (max) → persists

- **AC-SAV-20**: Save file size under 50 KB
  - Given: Full game state (night 6, all anomalies photographed, full inventory)
  - When: Save file is written and its size measured
  - Then: File size < 50 KB
  - Edge cases: Minimal save (night 1, no anomalies) → ~500 bytes; max save (night 6, 12 photos, all flags) → verify under 50 KB

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/save/death_persistence_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (SaveManager core API), Story 003 must be DONE (ConfigFile for settings)
- Unlocks: Save/Persistence epic complete (all Foundation save systems implemented)
