# Story 002: PC Backend (FileAccess + XOR)

> **Epic**: Save/Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-SAV-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Save System)
**ADR Decision Summary**: PC uses FileAccess for binary save files. Save data encrypted with XOR cipher on PC. File integrity via checksum. Save files stored in `user://saves/[slot]/` directory.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: Encryption key derived from game seed via hash.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure. Static typing.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `FileAccess.open()` with `FileAccess.WRITE/READ`. XOR via simple byte-level loop. CRC32 via `CRC32` class built into Godot.

**Control Manifest Rules (Foundation layer)**:
- Required: PC saves encrypted with XOR cipher
- Required: Save file includes CRC32 checksum for integrity verification
- Guardrail: Encryption key derived from game seed (not hardcoded)

---

## Acceptance Criteria

*From GDD `design/gdd/save-persistence.md`, scoped to this story:*

- [ ] AC-SAV-04: GIVEN a save data Dictionary, WHEN `PCBackend.save(slot, game_data)` is called, THEN the data is JSON-serialized, XOR-encrypted, CRC32 checksum appended, and written to `user://saves/[slot]/progress.save`. The file is NOT human-readable without decryption.

- [ ] AC-SAV-05: GIVEN an encrypted save file exists at `user://saves/[slot]/progress.save`, WHEN `PCBackend.load(slot)` is called, THEN the file is read, CRC32 verified, XOR-decrypted, JSON-deserialized, and the resulting Dictionary matches the original save data.

- [ ] AC-SAV-06: GIVEN a save file with tampered data (bytes modified after encryption), WHEN `PCBackend.load(slot)` is called, THEN CRC32 verification fails and the function returns `{}` (corrupt save treated as empty).

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

```gdscript
# pc_backend.gd — PC platform save backend

const XOR_KEY_SALT := "preschool-horror-salt"
CHECKSUM_SIZE := 4  # CRC32 is 4 bytes

var _encryption_key: PackedByteArray = PackedByteArray()

func _init(game_seed: String) -> void:
    _encryption_key = _derive_key(game_seed)

func _derive_key(seed: String) -> PackedByteArray:
    # hash(game_seed + salt) → first 16 bytes as XOR key
    var hash_input := (seed + XOR_KEY_SALT).to_ascii8_buffer()
    var hash_result := _sha256(hash_input)
    return hash_result.slice(0, 16)

func save(slot: int, game_data: Dictionary) -> bool:
    var json_string := JSON.stringify(game_data)
    var json_bytes := json_string.to_utf8_buffer()
    var encrypted := _xor_encrypt(json_bytes)
    var checksum := _crc32(encrypted)
    var path := "user://saves/%d/progress.save" % slot
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_buffer(checksum)  # Write checksum first
    file.store_buffer(encrypted)  # Then encrypted data
    file.close()
    return true

func load(slot: int) -> Dictionary:
    var path := "user://saves/%d/progress.save" % slot
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var checksum := file.get_buffer(CHECKSUM_SIZE)
    var encrypted := file.get_buffer(file.get_length() - CHECKSUM_SIZE)
    file.close()
    # Verify checksum
    if _crc32(encrypted) != checksum:
        return {}  # Corrupt save
    var decrypted := _xor_decrypt(encrypted)
    var json_string := decrypted.get_string_from_utf8()
    var variant := JSON.parse_string(json_string)
    if variant is not Dictionary:
        return {}
    return variant as Dictionary

func _xor_encrypt(data: PackedByteArray) -> PackedByteArray:
    var result := PackedByteArray()
    for i in range(data.size()):
        result.append(data[i] ^ _encryption_key[i % _encryption_key.size()])
    return result

func _xor_decrypt(data: PackedByteArray) -> PackedByteArray:
    # XOR is symmetric: encrypt and decrypt are identical
    return _xor_encrypt(data)

func _crc32(data: PackedByteArray) -> PackedByteArray:
    var crc := CRC32.new()
    crc.compute_start()
    crc.compute(data)
    var result := PackedByteArray(4)
    var value := crc.get_checksum()
    for i in range(4):
        result[i] = (value >> (i * 8)) & 0xFF
    return result

func _sha256(data: PackedByteArray) -> PackedByteArray:
    var crypto := Crypto.new()
    return crypto.sha256(data)
```

*Derived from ADR-0010 PC-Save Behavior:*

- Save files stored in `user://saves/[slot]/` directory
- XOR cipher encryption (basic deterrent, not strong encryption)
- CRC32 checksum for integrity verification
- Checksum stored before encrypted data in file
- Manual backup: players can copy `user://saves/` directory

*Derived from Encryption Key Derivation:*

- `ENCRYPTION_KEY = hash(game_seed + "preschool-horror-salt").sha256()`
- First 16 bytes of SHA-256 hash used as XOR key
- Static salt ensures same seed produces same key across devices

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Save Manager core (provides save/load API)
- [Story 003]: Web backend (separate platform implementation)
- [Story 005]: Save validation (checksum is part of PC backend, full validation in Story 005)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-SAV-04**: PC save produces encrypted file
  - Given: game_data = {"current_night": 3, "boss_anger": 5}
  - When: `PCBackend.save(1, game_data)` is called
  - Then: File exists at `user://saves/1/progress.save`; raw file content is NOT valid JSON (encrypted); file has 4-byte CRC32 header
  - Edge cases: Different game seeds → different encrypted output; same seed → same encrypted output

- **AC-SAV-05**: PC load decrypts correctly
  - Given: Encrypted save file written by `save()` with known data
  - When: `PCBackend.load(1)` is called
  - Then: Returns Dictionary matching original game_data exactly
  - Edge cases: Wrong encryption key → CRC32 fails, returns {}; file deleted → returns {}

- **AC-SAV-06**: Tampered data detected
  - Given: Valid encrypted save file
  - When: One byte in encrypted portion is modified, then `load()` is called
  - Then: CRC32 mismatch detected, returns {}
  - Edge cases: Modify checksum bytes → CRC32 of data won't match stored checksum; modify only last byte → still detected

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/save/pc_backend_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (PC backend is platform-specific, no game logic dependencies)
- Unlocks: Save/Persistence epic (PC save path), Story 005 (validation reads PC-encrypted files)
