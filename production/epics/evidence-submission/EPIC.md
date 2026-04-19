# Epic: Evidence Submission

> **Layer**: Core
> **GDD**: design/gdd/evidence-submission.md
> **Architecture Module**: `src/core/evidence_submission/`
> **Status**: Ready
> **Stories**: 6 created

## Overview

Implements the evidence submission system: evidence booth location and interaction, photo submission UI flow, evidence scoring rubric (quality × anomaly rarity × night multiplier), score persistence via SaveManager, and nightly score reporting.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Data-Driven | Scoring formula in TuningKnobs, anomaly rarity config | LOW |
| ADR-0010: Save System | Night scores saved/restored | LOW |
| ADR-0003: Communication | Evidence submitted signal | LOW |
| ADR-0008: Input | Booth interaction input | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ES-001 | Debrief state machine & flow | ADR-0003 ✅ |
| TR-ES-005 | Pay calculation formulas | ADR-0004 ✅ |
| TR-ES-006 | Boss anger update | ADR-0004 ✅ |
| TR-ES-007 | Dialogue selection | ADR-0004 ✅ |
| TR-ES-008 | Night 7 win debrief | ADR-0003 ✅ |
| TR-ES-009 | Photo thumbnails & dwell time | ADR-0005 ✅ |

## Stories

| # | Story | Type | Status | ADR | TR-ID |
|---|-------|------|--------|-----|-------|
| 001 | Debrief State Machine & Flow | Integration | Ready | ADR-0003 | TR-ES-001 |
| 002 | Pay Calculation Formulas | Logic | Ready | ADR-0004 | TR-ES-005 |
| 003 | Boss Anger Update | Logic | Ready | ADR-0004 | TR-ES-006 |
| 004 | Dialogue Selection | Logic | Ready | ADR-0004 | TR-ES-007 |
| 005 | Night 7 Win Debrief | Integration | Ready | ADR-0003 | TR-ES-008 |
| 006 | Photo Thumbnails & Dwell Time | Visual/Feel | Ready | ADR-0005 | TR-ES-009 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/evidence-submission.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Scoring formula tests verify exact values from GDD formulas

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
