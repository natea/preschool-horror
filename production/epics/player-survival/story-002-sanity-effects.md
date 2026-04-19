# Story 002: Sanity Effects

> **Epic**: Player Survival
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Player Survival section)
**Requirement**: `TR-PLA-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 (Rendering)
**ADR Decision Summary**: Sanity visual distortion uses Forward+ compatible effects only. No compute shaders. Web: bloom (low quality) only, no SSAO. PC: limited post-processing.

**ADR Governing Implementation**: ADR-0009 (Audio)
**ADR Decision Summary**: Sanity audio hallucinations route through AudioManager's SFXBus. Max 8 concurrent decoders on Web. All audio preloaded via preload().

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Sanity threshold values in TuningKnobs resource. Effect intensity scales with stat level.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Visual distortion via shader material on viewport/camera. Audio hallucination via SFXManager.play_sfx(). No post-cutoff API changes expected for ShaderMaterial or AudioStreamPlayer.

**Control Manifest Rules (Presentation layer)**:
- Required: Forward+ rendering path for all visual effects
- Required: GPUParticles3D for VFX, no compute shaders
- Required: All audio routes through AudioManager (no direct AudioStreamPlayer creation)
- Guardrail: Web visual effects = bloom (low quality) only, no SSAO
- Guardrail: Web max 8 concurrent audio decoders

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md`, scoped to this story:*

- [ ] AC-PLA-06: GIVEN player stats drop below configured sanity_threshold, WHEN the threshold is crossed, THEN sanity visual distortion effects begin (environmental distortion).

- [ ] AC-PLA-07: GIVEN sanity effects are active, WHEN the intensity scales with how far stats are below threshold, THEN distortion intensity is proportional to the gap (closer to 0 = stronger effects).

- [ ] AC-PLA-08: GIVEN sanity effects are active, WHEN audio hallucinations trigger, THEN hallucination audio plays through SFXBus via AudioManager.

- [ ] AC-PLA-09: GIVEN sanity effects are active, WHEN player stats recover above threshold, THEN all sanity effects cease immediately.

---

## Implementation Notes

*Derived from ADR-0005 Rendering:*

- Visual distortion: Apply a shader material to the viewport or a full-screen quad. Use vertex displacement or fragment distortion.
- Web target: only bloom (low quality) and simple fragment shaders. No SSAO, no reflections.
- PC target: can use slightly more complex shaders but must stay within Forward+ budget.
- No compute shaders under any target.

*Derived from ADR-0009 Audio:*

- Hallucination audio: One-shot SFX played via `SFXManager.play_sfx()`.
- SFX types: whispers, distorted ambient sounds, phantom creaks, child laughter.
- Web constraint: max 8 concurrent audio decoders. Sanity SFX must not overwhelm the SFX budget.
- All hallucination audio streams preloaded via `preload()`.
- Use non-spatial audio for hallucinations (they're "in the player's head," not world-positioned).

*Derived from ADR-0004 Data-Driven:*

- Sanity threshold in `TuningKnobs`: `sanity_threshold` (float, 0.0–1.0), `sanity_effect_intensity_curve` (lookup or formula parameters)
- Intensity formula: `intensity = clamp((sanity_threshold - current_stat) / (sanity_threshold - 0.0), 0.0, 1.0)`
- When intensity = 0.0 → no effects; intensity = 1.0 → maximum effects

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Vulnerability bar (separate system, sanity effects consume stats as input)
- [Story 003]: Inventory (hallucination audio clips are asset decisions, not inventory logic)
- [Story 006]: Player state persistence (sanity effects are runtime-only, not saved)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PLA-06**: Sanity effects trigger at threshold
  - Setup: Set sanity_threshold = 0.3 in TuningKnobs. Set current_stat = 0.2 (below threshold).
  - Verify: Visual distortion shader is active (viewport has distortion material applied). Hallucination audio can trigger.
  - Pass condition: distortion visible on screen; AudioManager logs SFXBus playback of hallucination clip

- **AC-PLA-07**: Intensity scales with gap
  - Setup: sanity_threshold = 0.3. Test at stat = 0.29 (intensity ~0.03), stat = 0.15 (intensity ~0.53), stat = 0.02 (intensity ~0.94).
  - Verify: distortion amount increases as stat decreases. Audio hallucination frequency increases.
  - Pass condition: visual difference between low and high intensity is perceptible; intensity values match formula

- **AC-PLA-08**: Hallucination audio routes through AudioManager
  - Setup: Trigger a hallucination while monitoring audio bus activity.
  - Verify: Audio plays on SFXBus, not directly on AudioServer. AudioManager handles the playback.
  - Pass condition: audio output confirmed on SFXBus; no direct AudioStreamPlayer creation detected

- **AC-PLA-09**: Effects cease when stats recover
  - Setup: Trigger sanity effects (stat below threshold). Then restore stat above threshold.
  - Verify: visual distortion shader is removed/disabled. No new hallucination audio triggers.
  - Pass condition: screen returns to normal immediately; no lingering distortion

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: `production/qa/evidence/sanity-effects-evidence.md` + lead sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (vulnerability bar provides one trigger for sanity effects)
- Unlocks: None directly (sanity effects feed into Monster AI behavior and player experience)
