# Epic: Player Survival

> **Layer**: Core
> **GDD**: design/gdd/player-survival.md
> **Architecture Module**: src/core/player_survival/
> **Status**: Ready
> **Stories**: 6 created

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Vulnerability Bar | Logic | Ready | ADR-0004, ADR-0003, ADR-0002 |
| 002 | Sanity Effects | Visual/Feel | Ready | ADR-0005, ADR-0009, ADR-0004 |
| 003 | Inventory System | Logic | Ready | ADR-0004, ADR-0003 |
| 004 | Item Pickup/Drop | Integration | Ready | ADR-0008, ADR-0003, ADR-0004 |
| 005 | Flashlight + Battery | Logic | Ready | ADR-0004, ADR-0009, ADR-0005, ADR-0003 |
| 006 | Player State Persistence | Integration | Ready | ADR-0010, ADR-0003, ADR-0004 |

## Overview

Implements the player's survival mechanics: hunger, thirst, and fatigue meters that decay over time and affect gameplay. When stats drop too low, sanity effects begin (environmental distortion, audio hallucinations). Includes inventory system for carrying items (flashlight, batteries, food, evidence), item pickup/drop mechanics, and player state persistence via SaveManager.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Data-Driven | All survival values in TuningKnobs resources, formulas in GDD | LOW |
| ADR-0010: Save System | Player state serialized to save slots | LOW |
| ADR-0003: Communication | Signal-based stat changes, sanity events | LOW |
| ADR-0009: Audio | Sanity hallucination audio cues | MEDIUM |
| ADR-0005: Rendering | Sanity-based visual distortion effects | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-PLA-001 | Hunger/thirst/fatigue decay over time | ADR-0004 ✅ |
| TR-PLA-002 | Stat thresholds trigger effects | ADR-0004 ✅ |
| TR-PLA-003 | Sanity effects at low stats | ADR-0005 + ADR-0009 ✅ |
| TR-PLA-004 | Inventory (max N items) | ADR-0004 ✅ |
| TR-PLA-005 | Item pickup/drop via input | ADR-0008 ✅ |
| TR-PLA-006 | Player state saved/restored | ADR-0010 ✅ |
| TR-PLA-007 | Flashlight + battery mechanic | ADR-0004 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/player-survival.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Sanity visual/audio evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
