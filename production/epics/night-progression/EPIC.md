# Epic: Night Progression

> **Layer**: Core
> **GDD**: design/gdd/night-progression.md
> **Architecture Module**: `src/core/night_progression/`
> **Status**: Ready
> **Stories**: 5 created

## Overview

Implements the night-to-night progression system: nightly cycle management (setup → gameplay → end), difficulty scaling across nights (anomaly frequency, monster aggression, lighting degradation), night configuration resources, configure_for_night() calls to Foundation systems at night start, and win/lose conditions (survive all nights vs. monster capture).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Data-Driven | NightConfig resource, difficulty scaling parameters | LOW |
| ADR-0003: Communication | configure_for_night() top-down calls, night_changed signal | LOW |
| ADR-0010: Save System | Night progress saved between sessions | LOW |
| ADR-0001: Scene Architecture | RoomManager configure_for_night() | LOW |
| ADR-0009: Audio | Music tension tiers per night | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-NP-001 | Night timer duration formula | ADR-0004 ✅ |
| TR-NP-002 | Difficulty scaling (anomaly target, monster count, horror tier) | ADR-0004 ✅ |
| TR-NP-003 | Night lifecycle state machine | ADR-0001 ✅ |
| TR-NP-004 | DEBRIEF counter logic (consecutive no-photos game-over) | ADR-0010 ✅ |
| TR-NP-005 | Configuration orchestration (configure_for_night calls) | ADR-0003 ✅ |

## Stories

| # | Story | Type | Status | ADR | TR-ID |
|---|-------|------|--------|-----|-------|
| 001 | Night Timer & Duration | Logic | Ready | ADR-0004 | TR-NP-001 |
| 002 | Difficulty Scaling Formulas | Logic | Ready | ADR-0004 | TR-NP-002 |
| 003 | Night Lifecycle State Machine | Integration | Ready | ADR-0001 | TR-NP-003 |
| 004 | DEBRIEF Counter Logic | Logic | Ready | ADR-0010 | TR-NP-004 |
| 005 | Configuration Orchestration | Integration | Ready | ADR-0003 | TR-NP-005 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/night-progression.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Night scaling formulas verified against GDD example calculations

## Next Step

Work through stories in order — each story's `Depends on:` field tells you what must be DONE before you can start it. Run `/story-readiness` → `/dev-story` to begin implementation.
