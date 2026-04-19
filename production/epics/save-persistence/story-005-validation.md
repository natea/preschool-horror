# Story 005: Save Validation and Error Recovery

> **Epic**: Save/Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-SAV-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Save System)
**ADR Decision Summary**: Save validation on load (version check, required fields, range checks). Corrupt save handling (checksum mismatch → slot treated as empty). Save file migration for version changes.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: CURRENT_SAVE_VERSION constant. Required fields from PlayerProgress schema.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure. Static typing.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: JSON.parse_string returns null on invalid JSON. Dictionary.has() for field checks. Version comparison for migration.

**Control Manifest Rules (Foundation layer)**:
- Required: Save validation on load (version, required fields, checksum)
- Required: Corrupt saves handled gracefully (slot treated as empty)
- Guardrail: Save file version check prevents loading incompatible formats

---

## Acceptance Criteria

*From GDD `design/gdd/save-persistence.md`, scoped to this story:*

- [ ] AC-SAV-14: GIVEN a save file with valid version (1), required fields (current_night), and matching CRC32 checksum, WHEN `SaveValidator.validate(save_record)` is called, THEN validation passes and the record is accepted.

- [ ] AC-SAV-15: GIVEN a save file with mismatched CRC32 checksum, WHEN `SaveValidator.validate(save_record)` is called, THEN validation fails, the error is logged, and the slot is treated as empty (returns `{}`).

- [ ] AC-SAV-16: GIVEN a save file with unknown version (e.g., version 2 when CURRENT_SAVE_VERSION is 1), WHEN `SaveValidator.validate(save_record)` is called, THEN validation fails with a migration error, the slot is treated as empty, and a migration attempt is logged.

- [ ] AC-SAV-17: GIVEN a save file with missing required fields (e.g., no current_night), WHEN `SaveValidator.validate(save_record)` is called, THEN validation fails, the error is logged, and the slot is treated as empty.

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

```gdscript
# save_validator.gd — save file validation and recovery

const CURRENT_SAVE_VERSION := 1
const REQUIRED_FIELDS := ["current_night", "boss_anger", "cumulative_pay"]

enum ValidationResult {
    VALID,
    CORRUPT_CHECKSUM,
    UNKNOWN_VERSION,
    MISSING_FIELDS,
    INVALID_JSON,
}

signal validation_failed(slot: int, reason: ValidationResult)
signal validation_passed(slot: int)

func validate(slot: int, save_record: Dictionary, backend_type: StringName) -> ValidationResult:
    # Check JSON validity (caller ensures save_record is a Dictionary)
    if save_record is not Dictionary:
        validation_failed.emit(slot, ValidationResult.INVALID_JSON)
        return ValidationResult.INVALID_JSON

    # Check version
    var version := save_record.get("version", -1)
    if version == -1:
        validation_failed.emit(slot, ValidationResult.UNKNOWN_VERSION)
        return ValidationResult.UNKNOWN_VERSION
    if version != CURRENT_SAVE_VERSION:
        _attempt_migration(slot, version)
        validation_failed.emit(slot, ValidationResult.UNKNOWN_VERSION)
        return ValidationResult.UNKNOWN_VERSION

    # Check required fields
    var data := save_record.get("data", {})
    if data is not Dictionary:
        validation_failed.emit(slot, ValidationResult.MISSING_FIELDS)
        return ValidationResult.MISSING_FIELDS
    for field in REQUIRED_FIELDS:
        if not data.has(field):
            validation_failed.emit(slot, ValidationResult.MISSING_FIELDS)
            return ValidationResult.MISSING_FIELDS

    # Check checksum (PC backend only)
    if backend_type == &"pc":
        var path := "user://saves/%d/progress.save" % slot
        var file := FileAccess.open(path, FileAccess.READ)
        if file != null:
            var stored_checksum := file.get_buffer(4)
            var encrypted := file.get_buffer(file.get_length() - 4)
            file.close()
            if _verify_checksum(encrypted, stored_checksum) != ValidationResult.VALID:
                validation_failed.emit(slot, ValidationResult.CORRUPT_CHECKSUM)
                return ValidationResult.CORRUPT_CHECKSUM

    validation_passed.emit(slot)
    return ValidationResult.VALID

func _attempt_migration(slot: int, old_version: int) -> void:
    # Migration from old version to CURRENT_SAVE_VERSION
    # For now, migration is not supported — log and treat as empty
    push_warning("Save migration: slot %d, version %d → %d (not supported)" % [
        slot, old_version, CURRENT_SAVE_VERSION
    ])

func _verify_checksum(data: PackedByteArray, expected: PackedByteArray) -> ValidationResult:
    var crc := CRC32.new()
    crc.compute_start()
    crc.compute(data)
    var actual := crc.get_checksum()
    var expected_value := 0
    for i in range(4):
        expected_value |= expected[i] << (i * 8)
    if actual == expected_value:
        return ValidationResult.VALID
    return ValidationResult.CORRUPT_CHECKSUM
```

*Derived from ADR-0010 Save Validation:*

- Version check: `save_record["version"] == CURRENT_SAVE_VERSION`
- Required fields: `current_night`, `boss_anger`, `cumulative_pay`
- Checksum verification: PC backend only (CRC32)
- Corrupt save → slot treated as empty
- Migration: attempt for unknown versions, currently not supported

*Derived from GDD Error Handling:*

- Save file corruption → recovery via backup files
- Save file encryption failure → read unencrypted backup
- Save file read error → read from backup
- Save file version incompatibility → attempt migration, fallback to defaults

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Save Manager core (validation is called by load, core provides API)
- [Story 002]: PC checksum implementation (validator calls it, doesn't implement it)
- [Story 003]: Web backend (no checksum on Web, validation is version + fields only)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-SAV-14**: Valid save passes validation
  - Given: save_record = {"version": 1, "data": {"current_night": 3, "boss_anger": 5, "cumulative_pay": 550}}
  - When: `validate(1, save_record, &"web")` is called
  - Then: Returns ValidationResult.VALID; `validation_passed(1)` signal emits
  - Edge cases: Extra fields in data → still valid; all required fields present with correct types → valid

- **AC-SAV-15**: Corrupt checksum detected
  - Given: PC backend save with tampered encrypted data
  - When: `validate(1, save_record, &"pc")` is called
  - Then: Returns ValidationResult.CORRUPT_CHECKSUM; `validation_failed(1, CORRUPT_CHECKSUM)` signal emits
  - Edge cases: Single byte flip in encrypted data → checksum mismatch; checksum bytes themselves tampered → mismatch

- **AC-SAV-16**: Unknown version rejected
  - Given: save_record = {"version": 2, "data": {"current_night": 3, ...}}
  - When: `validate(1, save_record, &"web")` is called (CURRENT_SAVE_VERSION = 1)
  - Then: Returns ValidationResult.UNKNOWN_VERSION; migration attempted and logged; slot treated as empty
  - Edge cases: version = 0 → rejected; version = 999 → rejected; version field missing → rejected

- **AC-SAV-17**: Missing required fields rejected
  - Given: save_record = {"version": 1, "data": {"current_night": 3}}  (missing boss_anger, cumulative_pay)
  - When: `validate(1, save_record, &"web")` is called
  - Then: Returns ValidationResult.MISSING_FIELDS; `validation_failed(1, MISSING_FIELDS)` signal emits
  - Edge cases: data is not Dictionary → MISSING_FIELDS; data is empty Dictionary → MISSING_FIELDS

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/save/validation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (SaveManager core API), Story 002 must be DONE (PC checksum available)
- Unlocks: Save/Persistence epic (validation gate for all loads), Story 006 (death persistence reads validated data)
