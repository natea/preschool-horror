# Save/Persistence

> **Status**: Designed

## Overview

The Save/Persistence system is the foundational infrastructure that maintains player progress across play sessions. It stores critical game state data including current night, story flags, boss anger, and cumulative pay. This system enables the core progression loop by allowing players to continue their journey across multiple play sessions without losing progress.

As a Foundation/Infrastructure system, Save/Persistence is not directly visible to players. Instead, it operates behind the scenes to ensure continuity and persistence of the game's narrative and progression elements. The system is designed to be lightweight, reliable, and secure, with particular attention to web export constraints and data integrity.

## Player Fantasy

There is no direct player fantasy for the Save/Persistence system itself. Players do not interact with it directly or think about its mechanics. Instead, the system enables the player fantasies of other systems:

- **Night Progression**: Players feel a sense of continuity as they advance through nights, knowing their progress is saved.
- **Evidence Submission**: Players trust that their hard-earned pay and boss anger levels will persist between sessions.
- **Main Menu**: Players experience seamless transitions between game sessions without manual save management.

The Save/Persistence system is the silent guardian of player progress, ensuring that every decision, every photo, and every encounter carries weight across the entire 7-night journey.

## Detailed Design

### Data Structures

#### Core Save Data (PlayerProgress.gd)
```gdscript
class PlayerProgress:
    var current_night: int = 1                    # 1-7
    var consecutive_nights_no_photos: int = 0     # 0-2 (triggers game-over at >= 3)
    var story_flags: Dictionary = {}              # StringName → bool (includes secrets)
    var boss_anger: int = 0                       # 0-10
    var cumulative_pay: int = 0
    var inventory: Array[Item] = []               # Captured photos, items
    var player_stats: PlayerStats = PlayerStats.new()
```

#### PlayerStats (PlayerStats.gd)
```gdscript
class PlayerStats:
    var total_photos_taken: int = 0
    var total_anomalies_photographed: int = 0
    var nights_completed: int = 0
    var deaths: int = 0
    var time_played_seconds: int = 0
```

#### Item (Item.gd)
```gdscript
class Item:
    var item_id: StringName
    var quantity: int
    var quality: float = 1.0  # 0.0-1.0 raw score from photo scoring
```

> **quality → grade mapping**: `quality` is the raw photo score. The Photography System buckets it into grades per `photography-system.md`:
> - `quality >= 0.9` → Grade A
> - `quality >= 0.7` → Grade B
> - `quality >= 0.5` → Grade C
> - `quality >= 0.3` → Grade D
> - `quality < 0.3` → Grade F
>
> If the photography GDD uses different thresholds, update this table to match.

### Save/Load Flow

#### Save Triggers
- **After Debrief Completed**: Immediately after Evidence Submission finishes
- **On Boss Transformation**: When boss_anger reaches 10 and transformation occurs
- **On Game Won**: When player completes Night 7 and escapes

#### Load Trigger
- **On Session Start**: During initial loading screen, before any gameplay begins

#### Save Process
1. **Collect Data**: Gather all relevant data from active systems
2. **Serialize**: Convert to JSON-compatible dictionary
3. **Encrypt**: Apply AES-256 encryption with password derived from game seed
4. **Write**: Save to `user://save_data.dat` using FileAccess

#### Load Process
1. **Check File**: Verify `user://save_data.dat` exists
2. **Read**: Load encrypted data using FileAccess
3. **Decrypt**: Decrypt using game seed-derived password
4. **Deserialize**: Convert JSON back to PlayerProgress object
5. **Initialize**: Pass data to Night Progression and Evidence Submission systems

### Godot APIs Used

- **FileAccess**: Primary file I/O for save/load operations
- **ConfigFile**: Fallback for simple configuration values
- **JSON**: Serialization format for save data
- **Resource**: For structured data storage
- **FileAccess.open_encrypted_with_pass()**: For secure save encryption

### Web Export Constraints

For web builds, `user://` maps to IndexedDB storage with these limitations:

- **Storage Limit**: 512 MB total (Godot 4.6 default)
- **Async Operations**: All file I/O must be asynchronous
- **No Blocking**: Cannot use synchronous FileAccess methods
- **IndexedDB Quirks**: Must handle potential quota exceeded errors

### Security Considerations

- **Encryption**: All save files are encrypted with AES-256 using a key derived from the game's random seed
- **Tamper Detection**: Save files include a checksum/CRC to detect modification
- **No Plaintext**: Never store sensitive data in plaintext
- **Web Security**: IndexedDB operations use secure origins only

### Performance Considerations

- **Async Loading**: Save/load operations are non-blocking to prevent frame drops
- **Minimal Data**: Only essential data is saved (no unnecessary state)
- **Compression**: Optional GZIP compression for large save files
- **Caching**: In-memory copy of save data for quick access

## Formulas

### Encryption Key Derivation

```gdscript
ENCRYPTION_KEY = hash(game_seed + "preschool-horror-salt").sha256()
```

- `game_seed`: the per-game random seed (set at new game start)
- Salt is static — ensures same seed on different devices produces the same key
- **Safe range**: N/A (cryptographic hash)

### Checksum

```gdscript
CHECKSUM = crc32(save_data_json + ENCRYPTION_KEY)
```

- `save_data_json`: the JSON-serialized save dictionary as bytes
- CRC32 provides tamper detection, not cryptographic integrity
- **Verification**: `IS_VALID = (computed_checksum == stored_checksum)`

### Compression

```gdscript
COMPRESSION_RATIO = compressed_size / uncompressed_size
```

- Target: `COMPRESSION_RATIO < 0.3` (70%+ reduction expected for JSON with repetitive strings)
- Compression applied before encryption (compression-then-encrypt order)

### Save Load Time Budget

```gdscript
MAX_SAVE_LOAD_TIME_MS = 100
```

- Frame budget: 16.6 ms at 60 fps
- 100 ms is a hard ceiling for the entire load sequence (read → decrypt → deserialize)
- Should average < 30 ms on target hardware

### Constants

```gdscript
TARGET_SAVE_SIZE = 512 * 1024       # 512 KB — target max save file size
CURRENT_SAVE_VERSION = 1             # increments on breaking schema change
MAX_SAVE_LOAD_TIME_MS = 100          # ms — hard ceiling for read → decrypt → deserialize
```

### Death Persistence

```gdscript
PERSISTS_ON_DEATH = {
    "current_night": true,
    "boss_anger": true,
    "cumulative_pay": true,
    "story_flags": true,
}

RESET_ON_DEATH = {
    "consecutive_nights_no_photos": true,  # counter resets — player gets another chance
    "inventory": false,                     # photos captured this night persist
}
```

- Player dies → load last save → `boss_anger` and `cumulative_pay` persist from last save
- `consecutive_nights_no_photos` resets on death (player gets another chance)
- `inventory` (captured photos) persist — they were captured, not erased
- `story_flags` persist — discovered secrets remain discovered

```gdscript
SAVE_PATH = user://save_data.dat
```

- No platform-specific path variant — `user://` abstracts across desktop/web
- Web: maps to IndexedDB; desktop: maps to platform-specific user dir

## Edge Cases

### Save File Not Found
- **Scenario**: No save file exists on first run or after manual deletion
- **Behavior**: Initialize with default values (night 1, counter 0, empty story flags)
- **Fallback**: Use defaults as defined in night-progression.md and evidence-submission.md

### Save File Corruption
- **Scenario**: Save file is corrupted or fails validation
- **Behavior**: 
  1. Attempt recovery using backup files (if available)
  2. If recovery fails, initialize with default values
  3. Log error and notify player (non-intrusive UI message)
- **Fallback**: Defaults as above

### Save File Encryption Failure
- **Scenario**: Encryption/decryption fails (wrong key, corrupted data)
- **Behavior**: 
  1. Attempt to read unencrypted backup if available
  2. If unavailable, initialize with defaults
  3. Log error and notify player
- **Fallback**: Defaults as above

### Save File Quota Exceeded (Web)
- **Scenario**: IndexedDB quota exceeded on web build
- **Behavior**:
  1. Attempt to clear old save backups (keep only 1 most recent)
  2. If still exceeded, prompt player to free space (delete old saves, clear cache)
  3. If player declines, initialize with defaults
- **Fallback**: Defaults as above

### Save File Read Error
- **Scenario**: FileAccess read fails (disk error, permission issue)
- **Behavior**:
  1. Attempt to read from backup files
  2. If all reads fail, initialize with defaults
  3. Log error and notify player
- **Fallback**: Defaults as above

### Save File Write Error
- **Scenario**: FileAccess write fails (disk full, permission issue)
- **Behavior**:
  1. Attempt to write to backup location
  2. If write fails, log error and notify player
  3. Player can continue playing but progress will not be saved
- **Fallback**: Continue without saving (warn player)

### Mid-Night Save Attempt
- **Scenario**: Player attempts to save during an active night
- **Behavior**: Save is blocked until night ends (after debrief_completed)
- **UI**: Show message "Cannot save during active night. Complete the night first."
- **Fallback**: No save occurs, player restarts at beginning of current night if they quit

### Multiple Saves in Quick Succession
- **Scenario**: Player saves multiple times within a short period
- **Behavior**: Debounce save operations (minimum 1 second between saves)
- **Performance**: Prevents excessive I/O operations
- **Fallback**: Only the last save in the debounce window is stored

### Save File Migration Failure
- **Scenario**: Migration from old save version fails
- **Behavior**:
  1. Attempt to recover what data can be read
  2. Initialize missing fields with defaults
  3. Log error and notify player of data loss
- **Fallback**: Defaults for missing fields, recovered data for readable fields

### Web Save File Size Limit
- **Scenario**: Save file exceeds IndexedDB size limit (usually 50-100MB)
- **Behavior**:
  1. Compress save data more aggressively
  2. If still too large, prompt player to enable compression or reduce save data
  3. If player declines, save fails
- **Fallback**: Save fails, player continues without saving

### Save File Access on Different Domains
- **Scenario**: Player accesses game from different domain (cross-origin)
- **Behavior**: IndexedDB is domain-specific; save data is not accessible
- **Fallback**: New game with no saved progress (player must start over)

### Save File Deletion by User
- **Scenario**: Player manually deletes save file from OS/browser
- **Behavior**: Treated as save file not found; initialize with defaults
- **UI**: No error message unless player expects save to be there

### Save File Corruption Detection
- **Scenario**: Checksum mismatch detected
- **Behavior**: Immediately trigger recovery process using backup files
- **UI**: Show "Save file corrupted. Attempting recovery..." message
- **Fallback**: Recovery failure → initialize with defaults

### Save File Encryption Key Mismatch
- **Scenario**: Game seed changed (e.g., playing on different computer)
- **Behavior**: Cannot decrypt save file; treat as corrupted
- **UI**: Show "Save file from another game session. Starting new game." message
- **Fallback**: Initialize with defaults

### Save File Concurrent Access (Web)
- **Scenario**: Multiple tabs accessing same IndexedDB simultaneously
- **Behavior**: Use mutex/locking to prevent race conditions
- **Fallback**: Serialize access; may cause slight delay but ensures data integrity

### Save File Quota Recovery
- **Scenario**: Player clears space after quota exceeded warning
- **Behavior**: Retry save operation automatically
- **UI**: Show "Save successful!" confirmation
- **Fallback**: If retry fails, show error message

### Save File Backup Restoration
- **Scenario**: Primary save file corrupted, backup available
- **Behavior**: Restore from most recent backup
- **UI**: Show "Save file corrupted. Restored from backup." message
- **Fallback**: If backup also corrupted, initialize with defaults

### Save File Version Incompatibility
- **Scenario**: Save file from older version cannot be migrated
- **Behavior**: Attempt migration; if impossible, initialize with defaults
- **UI**: Show "Save file from older version. Some progress may be lost." message
- **Fallback**: Defaults for incompatible data

### Save File Read-Only Access
- **Scenario**: File system is read-only (browser restrictions, CDNs)
- **Behavior**: Save operations fail; use web storage alternatives if available
- **Fallback**: Cannot save; player continues without saving

### Save File Write-Only Access
- **Scenario**: File system allows writes but reads fail
- **Behavior**: Save operations succeed, load operations fail
- **Fallback**: Cannot load previous progress; start new game

### Save File Partial Write
- **Scenario**: Save operation interrupted (power loss, crash)
- **Behavior**: Next load detects incomplete write, uses previous valid save
- **Fallback**: Previous save used; no data loss beyond current session

### Save File Encryption Performance
- **Scenario**: Encryption/decryption causes frame drop on low-end devices
- **Behavior**: Offload to background thread; use lighter encryption if needed
- **Fallback**: Reduced security (lighter encryption) or delayed save (batch operations)

### Save File Migration Complexity
- **Scenario**: Multiple save versions need migration
- **Behavior**: Apply sequential migrations from oldest to newest version
- **Fallback**: If any migration step fails, stop and initialize with defaults

### Save File Size Optimization
- **Scenario**: Save file approaching quota limits
- **Behavior**: Compress data, remove unnecessary fields, use more efficient encoding
- **Fallback**: If optimization fails, prompt player to manage save data

### Save File Access During Gameplay
- **Scenario**: Player alt-tabs during save operation
- **Behavior**: Save operation is non-blocking; if interrupted, retry on next frame
- **Fallback**: Save may be delayed but will eventually complete

### Save File Version Rollback
- **Scenario**: Player downgrades game version
- **Behavior**: Cannot read newer save format; treat as corrupted
- **Fallback**: Initialize with defaults; recommend upgrading game version

### Save File Cross-Platform Compatibility
- **Scenario**: Save file created on PC, loaded on web
- **Behavior**: Format should be platform-agnostic; encryption may differ
- **Fallback**: If decryption fails due to platform differences, initialize with defaults

### Save File Multiple Accounts
- **Scenario**: Multiple players on same computer with different save files
- **Behavior**: Single save file per device; no account system in MVP
- **UI**: "One save file per device. Family members share progress."
- **Fallback**: Manual save file copying for separate progressions

### Save File Sync Across Devices
- **Scenario**: Player expects saves to sync across devices (cloud save)
- **Behavior**: Not supported in MVP; local save only
- **UI**: "Cloud saves not available in this version." message
- **Fallback**: Local save system works independently

### Save File Manual Backup
- **Scenario**: Player wants to manually backup save file
- **Behavior**: Provide option to export save file as encrypted blob
- **UI**: "Export Save" and "Import Save" buttons in settings
- **Fallback**: Manual backup via file system exploration

### Save File Automatic Backup
- **Scenario**: Save file corrupted, backup available
- **Behavior**: Automatically restore from most recent backup
- **UI**: Show "Save file corrupted. Restored from backup." message
- **Fallback**: If backup also corrupted, initialize with defaults

### Save File Quota Monitoring
- **Scenario**: Save file approaching quota limits
- **Behavior**: Monitor quota usage and warn player before hitting limit
- **UI**: Show warning when QUOTA_WARNING_THRESHOLD (80%) reached
- **Fallback**: Player can clear space or disable certain save features

### Save File Integrity Verification
- **Scenario**: Periodic integrity check of save file
- **Behavior**: Verify checksum on each load; random integrity checks during gameplay
- **UI**: No direct UI — internal verification
- **Fallback**: Detected corruption triggers recovery process

### Save File Access Patterns
- **Scenario**: Optimizing save/load performance
- **Behavior**: Batch read/write operations; minimize I/O calls
- **Performance**: Target <100ms load time per frame budget
- **Fallback**: Asynchronous operations with progress indicator if needed

### Save File Error Logging
- **Scenario**: Save/load errors occur
- **Behavior**: Log detailed error information for debugging
- **Analytics**: Track error rates and types for improvement
- **Fallback**: Player sees generic error message; developers get detailed logs

### Save File User Consent
- **Scenario**: First-time save operation
- **Behavior**: Ask for permission to create save file (web browsers require this)
- **UI**: "This game will save your progress. Allow?" with Yes/No options
- **Fallback**: If denied, run in temporary session mode (no persistence)

### Save File Data Minimization
- **Scenario**: Save file contains unnecessary data
- **Behavior**: Only essential data saved (night progress, story flags, boss state, pay)
- **Optimization**: Remove redundant or temporary state from save files
- **Fallback**: Minimal save size to stay under quota limits

### Save File Encryption Strength
- **Scenario**: Security concerns about save file encryption
- **Behavior**: Use AES-256, a strong, widely-accepted encryption standard
- **Fallback**: If AES-256 unavailable, use strongest available encryption

## Dependencies

### Depends On (None)
The Save/Persistence system has no external dependencies. It is a foundational infrastructure system that other systems rely on, but it does not depend on any other game system.

### Depended On By

#### Night Progression (System #5)
- **Data Needed**: `current_night` (1-7), `consecutive_nights_no_photos` (0-3), `story_flags` (Dictionary)
- **Write Triggers**: After debrief_completed, on boss_transformation_triggered, on game_won
- **Read Triggers**: Once during LOADING at new session start (not on death restart)
- **Death Note**: Death restart does NOT reset `boss_anger` or `cumulative_pay` — these persist from the last save. The player returns to the same night with the same boss state.
- **Fallback**: If Save/Persistence unavailable, default to night 1, counter 0, empty story flags

#### Evidence Submission / Boss Debrief (System #13)
- **Data Needed**: `boss_anger` (0-10), `cumulative_pay` (int)
- **Write Trigger**: after each debrief_completed
- **Read Triggers**: On session start, during debrief initialization
- **Fallback**: If Save/Persistence unavailable, default boss_anger to 0, cumulative_pay to 0

#### Main Menu / Game Flow (System #15, Future)
- **Data Needed**: `current_night`, `story_flags`, `boss_anger`, `cumulative_pay`
- **Write Triggers**: On game save (via Save/Persistence)
- **Read Triggers**: On main menu load (continue game option)
- **Fallback**: If Save/Persistence unavailable, show "New Game" only

#### Photo Gallery / Inventory (System #14, Future)
- **Data Needed**: `inventory` (captured photos, items)
- **Write Triggers**: After photo captured, item acquired
- **Read Triggers**: On gallery/inventory UI initialization
- **Fallback**: Empty inventory if Save/Persistence unavailable

## Acceptance Criteria

### Unit Tests (GUT Framework)

#### SaveDataTests.gd
```gdscript
func test_save_file_created(): 
    # Create a save file and verify it exists
    pass

func test_save_file_loaded(): 
    # Save data then load it and verify all fields match
    pass

func test_save_file_encrypted(): 
    # Verify save file is encrypted (cannot read contents directly)
    pass

func test_save_file_decrypted(): 
    # Save, then load and decrypt, verify data integrity
    pass

func test_save_file_validation(): 
    # Test validation with valid, corrupted, and modified save files
    pass

func test_save_file_migration(): 
    # Test migration from old save version to new version
    pass

func test_save_file_size_limit(): 
    # Ensure save file stays under 512KB limit
    pass

func test_save_file_automatic_backup(): 
    # Corrupt primary save, verify backup is used
    pass

func test_save_file_error_recovery(): 
    # Simulate read/write errors, verify recovery behavior
    pass
```

#### PlayerProgressTests.gd
```gdscript
func test_player_progress_serialization(): 
    # Create PlayerProgress object, serialize to JSON, deserialize back
    # Verify all fields match original
    pass

func test_player_progress_defaults(): 
    # Test default values when save file not found
    pass

func test_player_progress_data_types(): 
    # Verify data types of all fields (current_night is int, etc.)
    pass

func test_player_progress_inventory_serialization(): 
    # Test serialization of inventory items with quality values
    pass

func test_player_progress_stats_serialization(): 
    # Test serialization of PlayerStats object
    pass
```

#### SaveTriggerTests.gd
```gdscript
func test_save_trigger_after_debrief(): 
    # Simulate debrief_completed event, verify save is triggered
    pass

func test_save_trigger_on_boss_transformation(): 
    # Simulate boss_anger reaching 10, verify save triggered
    pass

func test_save_trigger_on_game_won(): 
    # Simulate game win condition, verify save triggered
    pass

func test_save_not_triggered_during_night(): 
    # Attempt to save during active night, verify save is blocked
    pass

func test_save_debounce_mechanism(): 
    # Trigger multiple saves in quick succession, verify debounce works
    pass
```

#### WebSaveTests.gd (for Web builds)
```gdscript
func test_web_save_async(): 
    # Test asynchronous save operations for web builds
    pass

func test_web_save_quota_exceeded(): 
    # Simulate IndexedDB quota exceeded, verify proper handling
    pass

func test_web_save_cross_domain(): 
    # Test save behavior on different domains (should not share)
    pass

func test_web_save_encryption(): 
    # Verify encryption works in web environment
    pass
```

### Integration Tests

#### NightProgressionIntegrationTests.gd
```gdscript
func test_night_progression_save_load(): 
    # Complete night 1, save, load, verify current_night == 2
    pass

func test_story_flags_persistence(): 
    # Set story flags, save, load, verify flags persist
    pass

func test_boss_anger_persistence(): 
    # Increase boss_anger, save, load, verify anger persists
    pass

func test_consecutive_nights_no_photos_persistence(): 
    # Set counter, save, load, verify counter persists
    pass
```

#### EvidenceSubmissionIntegrationTests.gd
```gdscript
func test_boss_anger_save_load(): 
    # Change boss_anger, save, load, verify anger persists
    pass

func test_cumulative_pay_save_load(): 
    # Change cumulative_pay, save, load, verify pay persists
    pass
```

### Acceptance Criteria (QA Testable)

- [ ] Save file created successfully after first debrief
- [ ] Save file loads correctly on session start, restoring night progress
- [ ] Boss anger value persists between sessions
- [ ] Cumulative pay value persists between sessions
- [ ] Story flags persist between sessions
- [ ] Save file is encrypted and cannot be read directly
- [ ] Corrupted save files trigger recovery process
- [ ] Save file size stays under 512 KB (TARGET_SAVE_SIZE, not a hard limit — well under web 512 MB quota)
- [ ] Save operations do not cause frame drops (>16ms)
- [ ] Save/Load operations work correctly on web builds (asynchronous)
- [ ] Save file quota warnings appear at 80% usage
- [ ] Save file quota errors appear at 95% usage
- [ ] Backup save files restore corrupted primary saves
- [ ] Save is blocked during active nights
- [ ] Save debounce prevents excessive I/O (min 1 second between saves)
- [ ] Save migration works correctly for future version changes
- [ ] Error handling covers all edge cases with appropriate fallbacks

## Open Questions

1. **Save File Format**: **DECIDED: JSON.** Resource format was considered but rejected — JSON is simpler to encrypt (serialize → JSON string → encrypt → write), portable across platforms, and easier to debug (raw text when decrypted). Resource format adds no meaningful benefit for this save schema. The `JSON.stringify()` / `JSON.parse()` round-trip is the serialization path.

2. **Encryption Implementation**: Should encryption be implemented at the FileAccess level or after serialization? FileAccess encryption is easier but less flexible.

3. **Web Save Strategy**: For web builds, should we use IndexedDB directly or Godot's FileAccess abstraction? IndexedDB is more reliable but requires async handling.

4. **Save File Versioning**: What migration steps should we implement for future save version updates? Create a migration table now to avoid breaking saves later.

5. **Backup Strategy**: How many automatic backups should we keep? (Currently proposed: 3) Is that enough for player reassurance without wasting space?

6. **Save File Compression**: Should we implement GZIP compression for web saves? Adds CPU overhead but reduces storage use.

7. **Cloud Save Integration**: Should we design with future cloud sync in mind? If so, we need to structure save data to be platform-agnostic now.

8. **Save File Deletion UI**: Should players be able to delete saves from within the game? If so, where in the UI (Settings? Main Menu?).

9. **Save File Import/Export**: Should players be able to export/import saves? This could be useful for backup or sharing (though sharing might break intended progression).

10. **Save File Performance Budget**: What is the exact target for save/load time? <100ms is proposed, but should we be more aggressive?

11. **Save File Quota Monitoring**: Should we provide UI for players to manage save file quota, or just rely on automatic cleanup?

12. **Save File Encryption Key Storage**: Where should the encryption key be stored? Currently derived from game seed, but is that secure enough?

13. **Save File Integrity Checks**: Should we implement periodic integrity checks during gameplay, or only on load?

14. **Save File Platform Differences**: Should we abstract all platform differences behind a single API, or have platform-specific code paths?

15. **Save File Testing Coverage**: What percentage of save scenarios should be covered by automated tests? 100% for core functionality, but some edge cases may be hard to test automatically.

16. **Save File Analytics**: Should we collect anonymized analytics on save/load success rates to identify platform-specific issues?

17. **Save File User Consent**: For web builds, we need to ask permission to store data. What's the exact UI for this? (Required by GDPR/privacy laws)

18. **Save File Family Sharing**: If multiple people play on same computer, should we support multiple save slots? Not in MVP, but plan for future.

19. **Save File Corruption Feedback**: What exact message should players see when save is corrupted? Needs to be clear but not alarming.

20. **Save File Recovery Options**: If recovery fails, should we offer to start a "bonus night" as compensation? (Goodwill gesture)
