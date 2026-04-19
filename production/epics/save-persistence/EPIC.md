# Epic: Save/Persistence

> **Layer**: Foundation
> **GDD**: design/gdd/save-persistence.md
> **Architecture Module**: src/foundation/save_manager/
> **Status**: Ready
> **Stories**: 6 created

## Overview

Implements the save/load system with SaveManager singleton, 3 save slots with metadata (timestamp, night number), auto-save every 30 seconds during gameplay, PC/Web dual-backend (FileAccess + XOR encryption on PC, ConfigFile on Web), save validation on load (version, required fields, checksum), and critical moment protection (no saves during anomaly detection or monster encounters).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0010: Save System | SaveManager singleton, JSON format, PC/Web dual-backend, 3 slots, auto-save, validation | MEDIUM |
| ADR-0003: Communication | Signal-based save events, no signal chains | LOW |
| ADR-0004: Data-Driven | NightConfig saved/restored, resource paths via StringName | LOW |
| ADR-0006: Source Code | System-based directory structure | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| [TBD] | SaveManager singleton for routing | ADR-0010 ✅ |
| [TBD] | 3 save slots with metadata | ADR-0010 ✅ |
| [TBD] | Auto-save every 30 seconds | ADR-0010 ✅ |
| [TBD] | PC: FileAccess + XOR encryption | ADR-0010 ✅ |
| [TBD] | Web: ConfigFile (no encryption) | ADR-0010 ✅ |
| [TBD] | Save validation on load | ADR-0010 ✅ |
| [TBD] | No saves during critical moments | ADR-0010 ✅ |
| [TBD] | Settings/keybindings/volume persistence | ADR-0010 ✅ |
| [TBD] | Save file size under 50 KB | ADR-0010 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/save-persistence.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Save file size verified under 50 KB
- Both PC and Web backends tested independently

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
