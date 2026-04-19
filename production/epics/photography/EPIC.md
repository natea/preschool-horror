# Epic: Photography

> **Layer**: Core
> **GDD**: design/gdd/photography-system.md
> **Architecture Module**: `src/core/photography/`
> **Status**: Ready
> **Stories**: 7 created

## Overview

Implements the core photography mechanic: camera viewfinder UI overlay, focus/range finding via raycast, anomaly capture detection (is the anomaly in frame?), photo quality scoring based on distance/angle/lighting, flash mechanic (attracts monster but reveals hidden anomalies), and photo storage in inventory.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Physics | Camera raycasting via PhysicsDirectSpaceState3D | MEDIUM |
| ADR-0008: Input | Camera toggle, focus, flash input actions | MEDIUM |
| ADR-0004: Data-Driven | Photo quality thresholds in TuningKnobs | LOW |
| ADR-0003: Communication | Photo captured/submitted signals | LOW |
| ADR-0009: Audio | Flash sound cue | MEDIUM |

## Stories

| # | Story | Type | Status | TR-ID |
|---|-------|------|--------|-------|
| 001 | Camera Viewfinder | Visual/Feel | Ready | TR-PHO-001 |
| 002 | Shutter & Flash | Logic | Ready | TR-PHO-002 |
| 003 | Photo Scoring & Grading | Logic | Ready | TR-PHO-003 |
| 004 | Night Evidence Score | Logic | Ready | TR-PHO-004 |
| 005 | Anomaly Lock Detection | Logic | Ready | TR-PHO-005 |
| 006 | Photo Preview | Visual/Feel | Ready | TR-PHO-006 |
| 007 | Film Budget & Flash-Monster Integration | Integration | Ready | TR-PHO-007 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/photography-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- UI evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
