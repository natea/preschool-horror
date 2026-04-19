# ADR-0010: Save System

## Status
**Accepted**

## Date
2026-04-19

## Context

The game needs to save game state (progress, player position, room data, anomaly status, inventory, settings) and player preferences (keybindings, volume). The game targets PC and Web. PC saves to local file system. Web saves to `localStorage` (no file system access).

The question is how to structure the save system to support both PC and Web targets with different storage backends while maintaining data integrity and security.

## Decision

A `SaveManager` singleton handles save/load operations. PC uses `FileAccess` for binary save files. Web uses `OS.get_user_data_dir()` with `ConfigFile` for settings. Save data is encrypted on PC. Web saves use `ConfigFile` (no encryption — `localStorage` is not available in Godot Web export).

### Save Data Structure

| Data | Location | Save Frequency |
|------|----------|---------------|
| **GameProgress** | `user://saves/[slot]/progress.save` | After each night |
| **PlayerState** | `user://saves/[slot]/player.save` | Every 30 seconds (auto-save) |
| **Settings** | `user://settings.cfg` | On change |
| **Keybindings** | `user://keybindings.cfg` | On change |
| **Volume** | `user://volume.cfg` | On change |

### Key Interfaces

- **`SaveManager`** (singleton) — Central save/load routing
- **`FileAccess`** — PC file I/O (read/write)
- **`ConfigFile`** — Settings persistence (INI format)
- **`JSON`** — Save data serialization
- **`Crypt`** — Save file encryption (PC only)
- **`OS.get_user_data_dir()`** — User data directory path

### Save Manager

```gdscript
# save_manager.gd
class_name SaveManager extends Node

const SAVE_DIR := "user://saves"
const SETTINGS_FILE := "user://settings.cfg"
const KEYBINDINGS_FILE := "user://keybindings.cfg"
const VOLUME_FILE := "user://volume.cfg"

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal settings_saved()
signal settings_loaded()

func save_game(slot: int, game_data: Dictionary) -> void:
    var path := "%s/%d/progress.save" % [SAVE_DIR, slot]
    _save_to_file(path, game_data)
    game_saved.emit(slot)

func load_game(slot: int) -> Dictionary:
    var path := "%s/%d/progress.save" % [SAVE_DIR, slot]
    return _load_from_file(path)

func save_settings(settings: Dictionary) -> void:
    var config := ConfigFile.new()
    for key in settings:
        config.set_value("settings", key, settings[key])
    config.save(SETTINGS_FILE)
    settings_saved.emit()

func load_settings() -> Dictionary:
    var config := ConfigFile.new()
    if config.load(SETTINGS_FILE) == OK:
        return config.get_value("settings", {})
    return {}
```

### Save Data Format

Save data is serialized as JSON:

```json
{
    "version": 1,
    "night": 3,
    "tier": 2,
    "player_position": {"x": 10.0, "y": 2.0, "z": -5.0},
    "player_rotation": {"x": 0.0, "y": 45.0, "z": 0.0},
    "rooms_visited": [1, 2, 3],
    "anomalies_detected": [101, 102],
    "anomalies_photographed": [101],
    "evidence_submitted": [201, 202],
    "inventory": {"item_1": 1, "item_2": 2},
    "health": 80.0,
    "score": 15000
}
```

### Save Slot Management

- **Default slots**: 3 save slots
- **Slot naming**: `Slot 1`, `Slot 2`, `Slot 3`
- **Slot metadata**: Each save file includes timestamp and night number for slot selection screen
- **Overwrite behavior**: Saving to an existing slot overwrites the previous save

### Web-Save Behavior

- **Web saves**: Web target uses `user://` which maps to browser storage. No file system access.
- **Save limit**: Browser storage is limited (~5-10 MB). Save files are small (JSON) — well within limits.
- **No encryption on Web**: `Crypt` module is not available in Web export. Web saves are unencrypted.
- **Auto-save**: Auto-save works on Web — `user://` is supported in Web export.

### PC-Save Behavior

- **PC saves**: Save files are stored in `user://saves/[slot]/` directory.
- **Encryption**: Save files are encrypted with a simple XOR cipher on PC.
- **File integrity**: Save files include a checksum for integrity verification.
- **Manual backup**: Players can manually copy `user://saves/` to backup saves.

### Technical Constraints

- **No save during gameplay-critical moments**: Saves are not triggered during anomaly detection or monster encounters (to avoid data corruption).
- **Auto-save interval**: Auto-save triggers every 30 seconds during gameplay.
- **Manual save**: Manual save is triggered by the player via the pause menu.
- **Save validation**: Loaded save data is validated (version check, required fields, range checks).
- **Corrupt save handling**: If a save file fails to load (checksum mismatch), it is logged and the slot is treated as empty.

### Settings Persistence

Settings are stored in `ConfigFile` (INI format):

```ini
# settings.cfg
[graphics]
fullscreen = true
quality = "high"

[audio]
master_volume = -6.0
music_volume = -10.0
sfx_volume = -3.0

[input]
mouse_sensitivity = 1.0
gamepad_deadzone = 0.2
```

## Alternatives

### Alternative: Godot's built-in Resource save
- **Description**: Use `ResourceSaver` and `ResourceLoader` to save Godot Resources directly
- **Pros**: Built-in; no serialization code needed
- **Cons**: Godot-specific format; not human-readable; harder to patch; no encryption; no cross-platform consistency
- **Rejection Reason**: JSON is more portable, human-readable, and easier to debug. Resource save format is Godot-specific and harder to maintain.

### Alternative: No save system
- **Description**: No save system — game is played in a single session
- **Pros**: No save system complexity; no data corruption concerns
- **Cons**: Player cannot save progress; not acceptable for a horror game with multiple nights
- **Rejection Reason**: The GDD requires save functionality. A single-session horror game is not acceptable for the genre.

### Alternative: Cloud saves
- **Description**: Save game state to a cloud server
- **Pros**: Cross-device saves; automatic backup
- **Cons**: Requires backend infrastructure; adds network dependency; overkill for this project
- **Rejection Reason**: Local saves are sufficient for this project. Cloud saves add complexity without meaningful benefit for a single-player game.

## Consequences

### Positive
- **Dual-backend**: PC and Web both have save functionality with appropriate backends
- **Data integrity**: Checksums verify save file integrity; corrupt saves are handled gracefully
- **Settings persistence**: Settings are saved and loaded automatically
- **Multiple slots**: 3 save slots allow players to maintain multiple progress states
- **Encryption on PC**: Save files are encrypted on PC (simple XOR cipher)

### Negative
- **No cross-device saves**: PC and Web saves are not compatible (different storage backends)
- **Web no encryption**: Web saves are unencrypted (browser limitation)
- **Manual backup**: Players must manually backup save files on PC
- **Save size limit**: Web storage is limited (~5-10 MB) — but save files are small (JSON)

### Risks
- **Save corruption**: Save files may become corrupt. **Mitigation**: Checksum verification; graceful fallback to empty slot.
- **Save encryption bypass**: XOR cipher is trivial to bypass. **Mitigation**: XOR is a basic deterrent, not strong encryption. Acceptable for an indie game.
- **Web storage limit**: Web storage may be limited. **Mitigation**: Save files are small (JSON) — well within browser limits.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `game-progression.md` | Save progress | `save_game()` with slot management |
| `player-survival.md` | Player state | `save_player_state()` with position/health |
| `menu-navigation.md` | Settings persistence | `save_settings()` via ConfigFile |
| `audio-system.md` | Volume persistence | `save_volume()` via ConfigFile |
| `input-system.md` | Keybinding persistence | `save_keybindings()` via ConfigFile |

## Performance Implications
- **CPU**: Save/load is triggered infrequently (every 30s auto-save, manual save) — no per-frame cost
- **Memory**: Save data is small (JSON) — minimal memory overhead
- **I/O**: Save file writes are synchronous — may cause brief pauses on slow storage
- **Web**: Browser storage is fast — no significant performance impact

## Migration Plan

This is a new project — no migration needed. During implementation:

1. Create `SaveManager` singleton scene
2. Implement `save_game()`, `load_game()`, `save_settings()`, `load_settings()`
3. Create save slot management UI
4. Add save/restore to `GameController` (auto-save every 30s)
5. Wire settings save/load to settings UI
6. Code review: verify save validation; verify Web/PC save paths; verify encryption on PC
7. Test on both PC and Web targets

## Validation Criteria
- [ ] Save data is validated on load (version, required fields, checksum)
- [ ] Corrupt saves are handled gracefully (slot treated as empty)
- [ ] Settings are saved on change and loaded on startup
- [ ] PC saves are encrypted; Web saves are documented as unencrypted
- [ ] Web saves work within browser storage limits
- [ ] Auto-save triggers every 30 seconds during gameplay
- [ ] 3 save slots are available with slot selection UI
- [ ] Save files are human-readable JSON format

## Related Decisions
- ADR-0001 (Single-Scene Architecture) — SaveManager singleton in single-scene architecture
- ADR-0005 (Web-Compatible Rendering) — Web save behavior documented
- ADR-0009 (Audio System) — Volume settings persisted via ConfigFile
- ADR-0008 (Input System) — Keybindings persisted via ConfigFile
