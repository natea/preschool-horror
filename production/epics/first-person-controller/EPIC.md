# Epic: First-Person Controller

> **Layer**: Foundation
> **GDD**: design/gdd/first-person-controller.md
> **Architecture Module**: src/core/first_person_controller/
> **Status**: Ready
> **Stories**: 6 created

## Overview

Implements the player's first-person view and movement through the single preschool scene. Handles camera look, movement input, physics integration via CharacterBody3D/Jolt, and environmental interaction (sprinting, crouching, head bob). Grounded in the single-scene architecture (ADR-0001) with state-based input routing (ADR-0008).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Physics Engine | Jolt Physics default, CharacterBody3D for player, Area3D for detection | MEDIUM |
| ADR-0008: Input System | Input Actions, state-based routing via InputHandler, Web constraints | MEDIUM |
| ADR-0006: Source Code | System-based directory structure, naming conventions | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-MOV-001 | Smooth first-person camera with mouse look | ADR-0008 ✅ |
| TR-MOV-002 | Movement with WASD + gamepad | ADR-0008 ✅ |
| TR-MOV-003 | Sprint and crouch mechanics | ADR-0002 ✅ |
| TR-MOV-004 | Head bob while moving | ADR-0002 ✅ |
| TR-MOV-005 | Mouse capture/release management | ADR-0008 ✅ |
| TR-MOV-006 | Collision with preschool environment | ADR-0002 ✅ |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Player Movement | Logic | Ready | ADR-0002, ADR-0006 |
| 002 | Sprint & Crouch States | Logic | Ready | ADR-0002, ADR-0006 |
| 003 | Camera & Mouse Look | Visual/Feel | Ready | ADR-0008, ADR-0006 |
| 004 | Interaction Raycast | Integration | Ready | ADR-0002, ADR-0008, ADR-0004 |
| 005 | Settings Integration | UI | Ready | ADR-0008, ADR-0010, ADR-0006 |
| 006 | Camera Shake | Visual/Feel | Ready | ADR-0005, ADR-0003, ADR-0004 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/first-person-controller.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
