# Epic: Room/Level Management

> **Layer**: Foundation
> **GDD**: design/gdd/room-level-management.md
> **Architecture Module**: src/foundation/room_manager/
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories [epic-slug]`

## Overview

Implements the single-scene room management system that tracks the player's current location within the preschool, manages room boundaries, and handles transitions between areas (classrooms, hallway, playground, etc.) without any loading screens. RoomManager is a scene-local node (not an Autoload), with RoomData resources defining each room's properties.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Scene Architecture | Single-scene, no streaming, RoomManager scene-local, RoomData resource | LOW |
| ADR-0003: Communication | Signal-based cross-layer, signal registry, no signal chains | LOW |
| ADR-0004: Data-Driven | RoomData resource, all values in .tres, read-only at runtime | LOW |
| ADR-0006: Source Code | System-based directory structure | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| [TBD] | Track player current room | ADR-0001 ✅ |
| [TBD] | Room boundary detection via Area3D | ADR-0002 ✅ |
| [TBD] | Room transition signals | ADR-0003 ✅ |
| [TBD] | RoomData properties (lighting, audio, monster spawn zones) | ADR-0004 ✅ |
| [TBD] | configure_for_night() initialization | ADR-0001 ✅ |
| [TBD] | No loading screens between rooms | ADR-0001 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/room-level-management.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
