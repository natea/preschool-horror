# Epic: UI/HUD

> **Layer**: Presentation
> **GDD**: design/gdd/ui-hud.md
> **Architecture Module**: `src/presentation/ui/`
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories [epic-slug]`

## Overview

Implements all player-facing UI: main menu (new game, continue, settings, quit), HUD overlay (survival stat bars, minimap/hint system, photo viewfinder overlay, evidence score display), settings screen (keybindings, volume sliders, graphics options), night start/end screens, and game over/victory screens. All UI follows Input Actions for accessibility (no hover-only interactions).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0008: Input | Input Actions for all UI navigation, Web keyboard constraints | MEDIUM |
| ADR-0010: Save System | Save slot selection UI, load game flow | LOW |
| ADR-0003: Communication | UI update signals from game systems | LOW |
| ADR-0004: Data-Driven | UI text/labels from config, not hardcoded | LOW |
| ADR-0005: Rendering | UI rendering in Forward+, Web budgets | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| [TBD] | Main menu (new game, continue, settings, quit) | ADR-0008 ✅ |
| [TBD] | HUD survival stat bars | ADR-0003 ✅ |
| [TBD] | Photo viewfinder overlay | ADR-0008 ✅ |
| [TBD] | Evidence score display | ADR-0003 ✅ |
| [TBD] | Settings screen (keybindings, volume, graphics) | ADR-0010 ✅ |
| [TBD] | Night start/end screens | ADR-0003 ✅ |
| [TBD] | Game over/victory screens | ADR-0003 ✅ |
| [TBD] | Save slot selection with metadata | ADR-0010 ✅ |
| [TBD] | No hover-only interactions (accessibility) | ADR-0008 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/ui-hud.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All UI evidence docs with walkthrough sign-off in `production/qa/evidence/`
- Manual accessibility review (no hover-only, keyboard complete navigation)

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
