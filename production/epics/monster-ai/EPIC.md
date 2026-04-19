# Epic: Monster AI

> **Layer**: Core
> **GDD**: design/gdd/monster-ai.md
> **Architecture Module**: `src/core/monster_ai/`
> **Status**: Ready
> **Stories**: Created

## Overview

Implements the monster AI system: behavior tree/state machine for patrol/chase/investigate states, perception system (vision cone via Area3D raycasting, audio detection zones), pathfinding through the preschool environment, monster config resources (speed, detection range, aggression), and monster return-to-base mechanic when player uses photo mode.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Physics | Area3D vision, PhysicsDirectSpaceState3D raycasting, Jolt navigation | MEDIUM |
| ADR-0004: Data-Driven | MonsterConfig resource, all AI parameters tunable | LOW |
| ADR-0003: Communication | Perception signals, state change signals | LOW |
| ADR-0009: Audio | Audio detection zones, footstep sounds | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-MON-001 | Patrol/chase/investigate state machine | ADR-0004 ✅ |
| TR-MON-002 | Vision cone detection (Area3D) | ADR-0002 ✅ |
| TR-MON-003 | Audio-based detection | ADR-0009 ✅ |
| TR-MON-004 | Pathfinding through preschool | ADR-0002 ✅ |
| TR-MON-005 | Monster config (speed, range, aggression) | ADR-0004 ✅ |
| TR-MON-006 | Photo mode monster retreat mechanic | ADR-0004 ✅ |
| TR-MON-007 | Return-to-base when not detecting player | ADR-0004 ✅ |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | State Machine | Logic | Ready | ADR-0003 |
| 002 | Vision Cone Detection | Logic | Ready | ADR-0002 |
| 003 | Audio Detection | Integration | Ready | ADR-0009 |
| 004 | Monster Config Resources | Config/Data | Ready | ADR-0004 |
| 005 | Pathfinding | Logic | Ready | ADR-0002 |
| 006 | Photo Mode Retreat | Integration | Ready | ADR-0003 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/monster-ai.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- State machine transitions verified via automated tests

## Next Step

Run `/story-readiness` → `/dev-story` to begin implementation.
