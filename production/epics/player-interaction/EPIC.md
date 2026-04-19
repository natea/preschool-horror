# Epic: Player Interaction

> **Layer**: Feature
> **GDD**: design/gdd/player-interaction.md
> **Architecture Module**: src/feature/player_interaction/
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories [epic-slug]`

## Overview

Implements the environmental interaction system: interacting with preschool objects (cabinets, drawers, toy boxes, bookshelves, nap mats), object pickup and throw mechanics (throwing creates noise that attracts the monster), state management for interactable objects (open/closed, picked up/put down), and interaction range detection via Area3D.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Physics | Area3D interaction zones, raycasting for aimed interaction | MEDIUM |
| ADR-0008: Input | Interaction input action, throw input | MEDIUM |
| ADR-0003: Communication | Interaction started/completed signals | LOW |
| ADR-0004: Data-Driven | InteractableObject resource type, throw force tuning | LOW |
| ADR-0009: Audio | Throw noise, interaction SFX | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| [TBD] | Interaction range detection (Area3D) | ADR-0002 ✅ |
| [TBD] | Cabinet/drawer open/close mechanic | ADR-0004 ✅ |
| [TBD] | Object pickup and carry | ADR-0002 ✅ |
| [TBD] | Object throw with force | ADR-0002 ✅ |
| [TBD] | Throw noise attracts monster | ADR-0009 ✅ |
| [TBD] | Preschool-specific interactions (toy boxes, nap mats) | ADR-0004 ✅ |
| [TBD] | Interaction feedback (visual/audio) | ADR-0009 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/player-interaction.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Throw noise monster attraction integration tests pass

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
