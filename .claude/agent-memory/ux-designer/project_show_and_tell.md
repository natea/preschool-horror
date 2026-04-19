---
name: Show & Tell project context
description: Core game context for Show & Tell — first-person horror photography game in a haunted preschool, 7-night arc, boss twist
type: project
---

Show & Tell is a first-person horror photography game. The player explores a haunted preschool each night (7 nights total, 7-10 min per session), photographs anomalies as evidence, and submits photos to a boss who is secretly an anomaly himself.

**Why:** The boss twist (Pillar 3 "Trust No One") is the narrative spine. Every system must support dual-reading: helpful boss surface / sinister manipulator underneath.

**HUD registers (three distinct visual identities):**
- Preschool HUD: construction-paper rounded forms, Crayola saturation, Color Debt decay across nights
- Camera Viewfinder: hard right angles, monospace, warm cream — never decays (truth instrument)
- Boss Debrief: warm amber serif, official grade stamps — has its own separate corruption arc

**Hard constraints:**
- No health bars, stamina bars, or threat proximity meters
- Danger communicated through world cues (audio distortion, visual glitches) only
- Color Debt on Preschool HUD: Night 1 = full saturation, Night 6 = desaturated/cooled

**Night timer structure:**
- Night 1 = 600s, decreasing by 30s per night (Night 7 = 420s)
- Grace period: 30s after timer expires, "LEAVE NOW" state
- Player states: Normal, Camera Raised, Running, In Vent, Hiding, Cutscene, Dead, Restarting

**Key open UX decisions as of 2026-04-11:**
1. Vent prompt: tap vs. hold to enter
2. HUD auto-hide model: contextual persistence vs. other
3. Color Debt accessibility: need second decay channel beyond color (typography weight proposed)
4. RMB hold vs. toggle option for camera raise accessibility

**How to apply:** Ground all HUD/UI recommendations in the three-register framework and Color Debt mechanic. Every UI element decision should pass the dual-read test: does it work on first playthrough AND does it reward a second playthrough with new meaning?
