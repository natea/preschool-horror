# Story 001: Save Manager Core

> **Epic**: Save/Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-SAV-001`, `TR-SAV-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Save System)
**ADR Decision Summary**: SaveManager singleton, JSON format, 3 save slots with metadata (timestamp, night number), PlayerProgress serialization. Slot naming: `Slot 1`, `Slot 2`, `Slot 3`. Overwrite behavior on existing slot.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `game_saved(slot)` and `game_loaded(slot)` signals. No signal chains.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: NightConfig saved/restored, resource paths via StringName.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure. Static typing.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Foundation layer)**:
- Required: SaveManager as singleton for routing
- Required: 3 save slots with metadata (timestamp, night number)
- Guardrail: Slot naming convention `Slot N`

---

## Acceptance Criteria

*From GDD `design/gdd/save-persistence.md`, scoped to this story:*

- [ ] AC-SAV-01: GIVEN a PlayerProgress object with game state data, WHEN `SaveManager.save_game(slot, game_data)` is called, THEN the data is serialized to JSON, written to `user://saves/[slot]/progress.save`, and `game_saved(slot)` signal emits.

- [ ] AC-SAV-02: GIVEN a save file exists at `user://saves/[slot]/progress.save`, WHEN `SaveManager.load_game(slot)` is called, THEN the file is read, deserialized from JSON, and the resulting Dictionary contains all saved fields with correct types and values.

- [ ] AC-SAV-03: GIVEN slot metadata (timestamp, night number), WHEN a save is written, THEN metadata is embedded in the save file and available via `get_slot_metadata(slot)` returning `{timestamp: float, night: int, label: StringName}`.

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

```gdscript
# save_manager.gd — core SaveManager singleton

class_name SaveManager extends Node

const SAVE_DIR := "user://saves"
const SAVE_FILENAME := "progress.save"
const CURRENT_SAVE_VERSION := 1

signal game_saved(slot: int)
signal game_loaded(slot: int)

func _ready() -> void:
    _ensure_save_dir()

func save_game(slot: int, game_data: Dictionary) -> void:
    var path := "%s/%d/%s" % [SAVE_DIR, slot, SAVE_FILENAME]
    var metadata := {
        "timestamp": Time.get_unix_time_from_system(),
        "night": game_data.get("current_night", 1),
        "label": "Slot %d" % slot,
    }
    var save_record := {
        "version": CURRENT_SAVE_VERSION,
        "metadata": metadata,
        "data": game_data,
    }
    var json_string := JSON.stringify(save_record)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        file.store_string(json_string)
        game_saved.emit(slot)

func load_game(slot: int) -> Dictionary:
    var path := "%s/%d/%s" % [SAVE_DIR, slot, SAVE_FILENAME]
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var json_string := file.get_as_text()
    var variant := JSON.parse_string(json_string)
    if variant is not Dictionary:
        return {}
    var save_record := variant as Dictionary
    if not _validate_save_record(save_record):
        return {}
    return save_record.get("data", {})

func get_slot_metadata(slot: int) -> Dictionary:
    var path := "%s/%d/%s" % [SAVE_DIR, slot, SAVE_FILENAME]
    if not FileAccess.file_exists(path):
        return {"timestamp": 0.0, "night": 1, "label": "Slot %d" % slot}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"timestamp": 0.0, "night": 1, "label": "Slot %d" % slot}
    var json_string := file.get_as_text()
    var variant := JSON.parse_string(json_string)
    if variant is not Dictionary:
        return {"timestamp": 0.0, "night": 1, "label": "Slot %d" % slot}
    var save_record := variant as Dictionary
    return save_record.get("metadata", {"timestamp": 0.0, "night": 1, "label": "Slot %d" % slot})

func _validate_save_record(record: Dictionary) -> bool:
    if not record.has("version") or not record.has("data"):
        return false
    if record["version"] != CURRENT_SAVE_VERSION:
        return false
    var data := record["data"] as Dictionary
    # Required fields
    if not data.has("current_night"):
        return false
    return true

func _ensure_save_dir() -> void:
    if not DirAccess.dir_exists_absolute(SAVE_DIR):
        DirAccess.make_dir_absolute(SAVE_DIR)
```

*Derived from ADR-0010 Save Data Structure:*

- Save path: `user://saves/[slot]/progress.save`
- Save record format: `{"version": int, "metadata": {...}, "data": {...}}`
- Metadata: timestamp (Unix epoch), night number, slot label
- Slot naming: `Slot N` where N is slot number
- Overwrite: saving to existing slot replaces previous save

*Derived from PlayerProgress Data Structure:*

- `current_night: int` (1-7)
- `consecutive_nights_no_photos: int` (0-2)
- `story_flags: Dictionary` (StringName → bool)
- `boss_anger: int` (0-10)
- `cumulative_pay: int`
- `inventory: Array`
- `player_stats: PlayerStats`

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: PC encryption (Core handles plaintext JSON write)
- [Story 003]: Web backend (Core writes to user://, backend adapts per platform)
- [Story 004]: Auto-save triggers (Core provides save/load API, triggers use it)
- [Story 005]: Validation beyond required fields (Story 005 handles checksum, migration)
- [Story 006]: Death persistence rules (Story 006 handles what persists vs resets)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-SAV-01**: Save game writes correctly
  - Given: PlayerProgress with current_night=3, boss_anger=5, cumulative_pay=550
  - When: `save_game(1, progress_data)` is called
  - Then: File exists at `user://saves/1/progress.save`; JSON contains version=1, metadata with timestamp and night=3, data with all fields
  - Edge cases: Slot=0 → invalid, no-op; slot=4 → valid (3 slots: 1-3); called twice on same slot → overwrite

- **AC-SAV-02**: Load game restores correctly
  - Given: Save file at `user://saves/1/progress.save` with known data
  - When: `load_game(1)` is called
  - Then: Returns Dictionary matching saved data exactly (current_night=3, boss_anger=5, etc.)
  - Edge cases: File doesn't exist → returns {}; corrupted JSON → returns {}; missing required field → returns {}

- **AC-SAV-03**: Slot metadata available
  - Given: Save file written with night=5
  - When: `get_slot_metadata(1)` is called
  - Then: Returns `{timestamp: <unix_epoch>, night: 5, label: "Slot 1"}`
  - Edge cases: No save file → returns defaults (timestamp=0, night=1); corrupted file → returns defaults

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/save/save_manager_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Foundation system)
- Unlocks: Story 002 (PC backend wraps core API), Story 003 (Web backend wraps core API), Story 004 (auto-save uses core save API)
