# Epic: Visual Effects

> **Layer**: Presentation
> **GDD**: design/gdd/visual-effects.md
> **Architecture Module**: src/presentation/vfx/
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories [epic-slug]`

## Overview

Implements all visual effects: GPU particle systems for dust and atmosphere, sanity distortion effects (screen warping at low stats), anomaly glow effects (pulsing, color-shifting), monster reveal VFX (shadow distortion, temperature drop visual cue), night-by-night lighting degradation, and flash photography burst effect. All effects must meet Web performance budgets (no compute shaders, no SSAO, bloom low quality only).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Rendering | Forward+ only, Web budgets, GPUParticles3D, no compute shaders | MEDIUM |
| ADR-0003: Communication | VFX trigger signals from game systems | LOW |
| ADR-0004: Data-Driven | VFX intensity parameters in TuningKnobs | LOW |
| ADR-0009: Audio | VFX-synced audio cues | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| [TBD] | Dust/atmosphere particle systems | ADR-0005 ✅ |
| [TBD] | Sanity distortion effects | ADR-0005 ✅ |
| [TBD] | Anomaly glow/pulse effects | ADR-0005 ✅ |
| [TBD] | Monster reveal VFX | ADR-0005 ✅ |
| [TBD] | Night lighting degradation | ADR-0005 ✅ |
| [TBD] | Flash photography burst | ADR-0005 ✅ |
| [TBD] | Web-compatible (no SSAO, bloom low quality) | ADR-0005 ✅ |
| [TBD] | PC/Web effect quality tiers | ADR-0005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/visual-effects.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel evidence docs with sign-off in `production/qa/evidence/`
- Web performance budgets verified (draw calls, memory, particles)

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
