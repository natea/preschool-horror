# Story 003: Web Backend (ConfigFile)

> **Epic**: Save/Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-SAV-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Save System)
**ADR Decision Summary**: Web uses `user://` which maps to browser storage (IndexedDB). No file system access. No encryption on Web (Crypt module not available in Web export). ConfigFile for settings persistence.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure. Static typing.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Web export has no Crypt module. `user://` maps to IndexedDB in Godot 4.6 Web export. All file I/O must be non-blocking. Browser storage limit ~5-10 MB — save files are small JSON, well within limits.

**Control Manifest Rules (Foundation layer)**:
- Required: Web saves unencrypted (documented limitation)
- Required: Settings use ConfigFile (INI format)
- Guardrail: Document that Web saves are NOT encrypted

---

## Acceptance Criteria

*From GDD `design/gdd/save-persistence.md`, scoped to this story:*

- [ ] AC-SAV-07: GIVEN a save data Dictionary, WHEN `WebBackend.save(slot, game_data)` is called, THEN the data is JSON-serialized and written to `user://saves/[slot]/progress.save` WITHOUT encryption. The file IS human-readable.

- [ ] AC-SAV-08: GIVEN a Web save file exists, WHEN `WebBackend.load(slot)` is called, THEN the file is read and JSON-deserialized. Returns `{}` if file doesn't exist or JSON is invalid.

- [ ] AC-SAV-09: GIVEN settings data, WHEN `WebBackend.save_settings(settings)` is called, THEN settings are written to `user://settings.cfg` via ConfigFile. WHEN `WebBackend.load_settings()` is called, THEN settings are read from ConfigFile and returned as Dictionary.

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

```gdscript
# web_backend.gd — Web platform save backend

const SAVE_DIR := "user://saves"
const SETTINGS_FILE := "user://settings.cfg"
const KEYBINDINGS_FILE := "user://keybindings.cfg"
const VOLUME_FILE := "user://volume.cfg"

func save(slot: int, game_data: Dictionary) -> bool:
    # Web: no encryption, plain JSON
    var save_record := {
        "version": 1,
        "metadata": {
            "timestamp": Time.get_unix_time_from_system(),
            "night": game_data.get("current_night", 1),
            "label": "Slot %d" % slot,
        },
        "data": game_data,
    }
    var json_string := JSON.stringify(save_record)
    var path := "%s/%d/progress.save" % [SAVE_DIR, slot]
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(json_string)
    file.close()
    return true

func load(slot: int) -> Dictionary:
    var path := "%s/%d/progress.save" % [SAVE_DIR, slot]
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var json_string := file.get_as_text()
    file.close()
    var variant := JSON.parse_string(json_string)
    if variant is not Dictionary:
        return {}
    var save_record := variant as Dictionary
    if not _validate_save_record(save_record):
        return {}
    return save_record.get("data", {})

func save_settings(settings: Dictionary) -> bool:
    var config := ConfigFile.new()
    for key in settings:
        config.set_value("settings", str(key), settings[key])
    return config.save(SETTINGS_FILE) == OK

func load_settings() -> Dictionary:
    var config := ConfigFile.new()
    if config.load(SETTINGS_FILE) != OK:
        return {}
    return config.get_value("settings", {})

func save_keybindings(keybindings: Dictionary) -> bool:
    var config := ConfigFile.new()
    for key in keybindings:
        config.set_value("keybindings", str(key), keybindings[key])
    return config.save(KEYBINDINGS_FILE) == OK

func load_keybindings() -> Dictionary:
    var config := ConfigFile.new()
    if config.load(KEYBINDINGS_FILE) != OK:
        return {}
    return config.get_value("keybindings", {})

func save_volume(volumes: Dictionary) -> bool:
    var config := ConfigFile.new()
    for key in volumes:
        config.set_value("volume", str(key), volumes[key])
    return config.save(VOLUME_FILE) == OK

func load_volume() -> Dictionary:
    var config := ConfigFile.new()
    if config.load(VOLUME_FILE) != OK:
        return {}
    return config.get_value("volume", {})

func _validate_save_record(record: Dictionary) -> bool:
    if not record.has("version") or not record.has("data"):
        return false
    if record["version"] != 1:
        return false
    return true
```

*Derived from ADR-0010 Web-Save Behavior:*

- Web saves: `user://` maps to browser IndexedDB storage
- No encryption on Web (Crypt module not available)
- Save limit: ~5-10 MB browser storage — JSON save files well within limits
- Auto-save works on Web (user:// supported in Web export)
- Settings stored via ConfigFile (INI format)

*Derived from ConfigFile Settings Format:*

```ini
# settings.cfg
[settings]
fullscreen = true
quality = "high"

[keybindings]
move_forward = "w"
sprint = "shift"

[volume]
master = -6.0
music = -10.0
sfx = -3.0
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Save Manager core (provides save/load API)
- [Story 002]: PC encryption (Web doesn't use encryption)
- [Story 005]: Save validation (Web has no checksum, validation is version + required fields only)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-SAV-07**: Web save writes plain JSON
  - Given: game_data = {"current_night": 3, "boss_anger": 5}
  - When: `WebBackend.save(1, game_data)` is called
  - Then: File exists at `user://saves/1/progress.save`; raw file content IS valid JSON (human-readable); no encryption applied
  - Edge cases: Large game_data (full inventory) → still within browser storage limits

- **AC-SAV-08**: Web load reads correctly
  - Given: Save file written by `save()` with known data
  - When: `WebBackend.load(1)` is called
  - Then: Returns Dictionary matching original game_data exactly
  - Edge cases: File doesn't exist → returns {}; invalid JSON → returns {}

- **AC-SAV-09**: Settings persistence via ConfigFile
  - Given: settings = {"fullscreen": true, "master_volume": -6.0}
  - When: `save_settings()` then `load_settings()` called
  - Then: Loaded settings match saved settings exactly
  - Edge cases: ConfigFile doesn't exist → load returns {}; settings key missing → returns default {}

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/save/web_backend_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Web backend is platform-specific, no game logic dependencies)
- Unlocks: Save/Persistence epic (Web save path), Story 006 (settings persistence uses Web backend)
