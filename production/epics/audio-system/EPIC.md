# Epic: Audio System

> **Layer**: Foundation
> **GDD**: design/gdd/audio-system.md
> **Architecture Module**: src/foundation/audio_manager/
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories [epic-slug]`

## Overview

Implements the centralized audio routing system with 6-bus architecture (Music, Ambient, SFX, Voice, UI, Master), layered audio controllers for tension-tier music crossfading, room-specific ambient loops, spatial SFX with Area3D-based volume falloff, voice interrupt handling, and Web-compatible audio constraints (max 8 concurrent decoders, all audio preloaded).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0009: Audio System | 6-bus system, layered controllers, spatial SFX auto-free, all audio preloaded | MEDIUM |
| ADR-0003: Communication | Signal-based audio events, no signal chains | LOW |
| ADR-0004: Data-Driven | RoomData audio properties, MonsterConfig audio cues | LOW |
| ADR-0005: Rendering | Web audio decoder budget (max 8 concurrent) | MEDIUM |
| ADR-0006: Source Code | System-based directory structure | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| [TBD] | 6-bus audio architecture | ADR-0009 ✅ |
| [TBD] | AudioManager singleton routing | ADR-0009 ✅ |
| [TBD] | MusicController tension-tier crossfading | ADR-0009 ✅ |
| [TBD] | AmbientController room-specific loops | ADR-0009 ✅ |
| [TBD] | SFXManager spatial + non-spatial audio | ADR-0009 ✅ |
| [TBD] | VoiceController interrupt handling | ADR-0009 ✅ |
| [TBD] | Web-compatible audio (max 8 decoders) | ADR-0009 + ADR-0005 ✅ |
| [TBD] | All audio preloaded, no dynamic loading | ADR-0009 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/audio-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Web audio decoder budget verified (max 8 concurrent)

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
