# Systems Index: Show & Tell

> **Status**: Draft
> **Created**: 2026-04-09
> **Last Updated**: 2026-04-12
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Show & Tell is a first-person photography horror game with a core loop of
explore → spot anomaly → photograph → submit evidence → survive. The game
needs systems spanning first-person movement, camera/photography mechanics,
anomaly placement and behavior, monster AI, a vulnerability-based survival
system, a timed night structure, boss debrief presentation, vent-based escape
routes, and a Night 7 finale sequence. All systems serve four pillars:
"Something's Wrong Here" (escalating dread), "Prove It" (camera as core verb),
"Trust No One" (boss twist), and "One More Night" (distinct horror per night).

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | First-Person Controller | Core | MVP | Designed | design/gdd/first-person-controller.md | (none) |
| 2 | Room/Level Management | Core | MVP | Designed | design/gdd/room-level-management.md | (none) |
| 3 | Audio System | Audio | MVP | Designed | design/gdd/audio-system.md | (none) |
| 4 | Save/Persistence (inferred) | Persistence | Vertical Slice | Not Started | — | (none) |
| 5 | Night Progression | Gameplay | MVP | Designed | design/gdd/night-progression.md | Room/Level Management, Save/Persistence |
| 6 | Anomaly Placement Engine | Gameplay | MVP | Reviewed | design/gdd/anomaly-placement-engine.md | Room/Level Management, Night Progression |
| 7 | HUD/UI System | UI | MVP | Designed | design/gdd/hud-ui-system.md | First-Person Controller |
| 8 | Anomaly System | Gameplay | MVP | Designed | design/gdd/anomaly-system.md | Anomaly Placement Engine, Room/Level Management |
| 9 | Photography System | Gameplay | MVP | Designed | design/gdd/photography-system.md | First-Person Controller, Anomaly System, HUD/UI System |
| 10 | Monster AI (inferred) | Gameplay | Vertical Slice | Not Started | — | Anomaly System, First-Person Controller, Night Progression |
| 11 | Player Survival | Gameplay | Vertical Slice | Not Started | — | Monster AI, First-Person Controller, HUD/UI System |
| 12 | Vent System | Gameplay | Alpha | Not Started | — | Room/Level Management, First-Person Controller |
| 13 | Evidence Submission / Boss Debrief | Narrative | MVP | Designed | [evidence-submission.md](evidence-submission.md) | Photography System, Night Progression, Save/Persistence, HUD/UI System |
| 14 | Photo Gallery / Inventory (inferred) | UI | Vertical Slice | Not Started | — | Photography System, HUD/UI System |
| 15 | Main Menu / Game Flow (inferred) | Meta | Alpha | Not Started | — | Save/Persistence, Night Progression, HUD/UI System |
| 16 | Cutscene System (inferred) | Narrative | Full Vision | Not Started | — | First-Person Controller, Audio System |
| 17 | Night 7 Finale | Narrative | Full Vision | Not Started | — | Monster AI, Vent System, Cutscene System, Evidence Submission |

---

## Categories

| Category | Description |
| --- | --- |
| **Core** | Foundation systems everything depends on — movement, spatial structure |
| **Gameplay** | Systems that create the moment-to-moment experience — anomalies, photography, survival |
| **Persistence** | Save state and cross-night continuity |
| **UI** | Player-facing displays — HUD, viewfinder, photo gallery, menus |
| **Audio** | Ambient soundscape, adaptive audio, SFX |
| **Narrative** | Story delivery — boss debrief, cutscenes, Night 7 finale |
| **Meta** | Systems outside the core loop — main menu, game flow, settings |

---

## Priority Tiers

| Tier | Systems | Target |
| --- | --- | --- |
| **MVP** (9 systems) | FP Controller, Room/Level, Audio, Night Progression, Anomaly Placement, HUD/UI, Anomaly System, Photography, Evidence Submission | First playable: 3 rooms, 3 nights, core loop testable |
| **Vertical Slice** (4 systems) | Save/Persistence, Monster AI, Player Survival, Photo Gallery | Complete experience: danger, vulnerability bar, photo review |
| **Alpha** (2 systems) | Vent System, Main Menu / Game Flow | Full navigation + proper game state |
| **Full Vision** (2 systems) | Cutscene System, Night 7 Finale | Boss reveal, escape sequence, win condition |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **First-Person Controller** — The player's body. 7 systems depend on this. Highest-risk bottleneck.
2. **Room/Level Management** — The spatial container. 4 systems need rooms to exist.
3. **Audio System** — Sound API used by every gameplay system for horror feedback.
4. **Save/Persistence** — Story state and night progression need persistence across deaths and nights.

### Core Layer (depends on Foundation)

5. **Night Progression** — Defines which night, timer, anomaly pool, and difficulty tier are active. depends on: Room/Level Management, Save/Persistence.
6. **Anomaly Placement Engine** — Decides which anomalies go where on which night. depends on: Room/Level Management, Night Progression.
7. **HUD/UI System** — Three UI registers (Preschool HUD, Camera Viewfinder, Boss Debrief), Color Debt, warning system. depends on: First-Person Controller.

### Feature Layer (depends on Core)

8. **Anomaly System** — The anomalies themselves: environmental + monster types, states, photo-detection. depends on: Anomaly Placement Engine, Room/Level Management.
9. **Photography System** — Camera mechanics, photo capture, evaluation (head-on, clear, in-frame). depends on: First-Person Controller, Anomaly System, HUD/UI.
10. **Monster AI** — Three archetypes (Dolls, Shadows, Large) with patrol, react, pursue, attack states. depends on: Anomaly System, First-Person Controller, Night Progression.
11. **Player Survival** — Vulnerability bar fills when stationary. Max = monster attack = restart night. depends on: Monster AI, First-Person Controller, HUD/UI.
12. **Vent System** — Escape routes and shortcuts through the preschool. Critical for Night 7. depends on: Room/Level Management, First-Person Controller.

### Presentation Layer (depends on Features)

13. **Evidence Submission / Boss Debrief** — Photo grading, boss dialogue, pay increases, anger escalation. depends on: Photography, Night Progression, Save/Persistence, HUD/UI.
14. **Photo Gallery / Inventory** — Review and select photos before submission. depends on: Photography, HUD/UI.

### Polish Layer (depends on everything)

15. **Main Menu / Game Flow** — Title screen, pause, night transitions, win/lose states. depends on: Save/Persistence, Night Progression, HUD/UI.
16. **Cutscene System** — Scripted camera + dialogue for Night 7 reveal. depends on: First-Person Controller, Audio.
17. **Night 7 Finale** — Boss transformation cutscene + escape chase. depends on: Monster AI, Vent System, Cutscene System, Evidence Submission.

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | First-Person Controller | MVP | Foundation | S | Godot CharacterBody3D, mouse look, collision |
| 2 | Room/Level Management | MVP | Foundation | S | Scene loading, room transitions, preschool layout |
| 3 | Audio System | MVP | Foundation | M | Adaptive audio, proximity-based, per-night-tier |
| 4 | Night Progression | MVP | Core | S | Timer (10min→7min), night state, anomaly pool selection |
| 5 | Anomaly Placement Engine | MVP | Core | M | Per-night configs, room-anomaly mapping, placement rules |
| 6 | HUD/UI System | MVP | Core | M | Three UI registers (preschool, viewfinder, debrief) per art bible |
| 7 | Anomaly System | MVP | Feature | M | Environmental + monster types, states, photo-detection criteria |
| 8 | Photography System | MVP | Feature | L | Camera mechanics, photo capture, head-on evaluation, flash |
| 9 | Evidence Submission / Boss Debrief | MVP | Presentation | M | Photo grading, boss dialogue, anger/pay state, 3-night-no-submit trigger |
| 10 | Save/Persistence | VS | Foundation | S | Night progress, boss state, story flags |
| 11 | Monster AI | VS | Feature | L | 3 archetypes with distinct movement/behavior patterns |
| 12 | Player Survival | VS | Feature | S | Vulnerability bar fill rate, threshold, death/restart |
| 13 | Photo Gallery / Inventory | VS | Presentation | S | Photo browser, select for submission |
| 14 | Vent System | Alpha | Feature | M | Vent network layout, enter/exit mechanics, Night 7 escape routes |
| 15 | Main Menu / Game Flow | Alpha | Polish | S | Title, pause, transitions, win/lose |
| 16 | Cutscene System | Full | Polish | S | Scripted camera, dialogue display, trigger system |
| 17 | Night 7 Finale | Full | Polish | M | Boss transformation, chase AI, escape win condition |

Effort: S = 1 session, M = 2-3 sessions, L = 4+ sessions

---

## Circular Dependencies

None found. The dependency graph is a clean DAG (directed acyclic graph).

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
| --- | --- | --- | --- |
| Photography System | Technical + Design | Photo evaluation (is the anomaly "head-on and clear"?) is the hardest single mechanic to implement well. Raycast + frustum + angle scoring is unproven in Godot. If evaluation feels arbitrary, the core loop breaks. | Prototype early with `/prototype camera-system`. Start with binary "anomaly in frame yes/no" and iterate. |
| Monster AI | Technical + Scope | 3 distinct archetypes (Dolls: rigid/snappy, Shadows: fluid/dissolve, Large: irregular cadence) each need unique behavior trees. AI that isn't scary ruins the horror. | Design Dolls first (simplest), validate the scare factor, then extrapolate to Shadows and Large. |
| Night 7 Finale | Design | Depends on every other system working together — cutscene triggers, boss monster AI, vent pathfinding, win detection. Integration risk is high. | Design last. Ensure Vent System and Monster AI are individually solid before combining. |
| Anomaly Placement Engine | Design + Scope | 7 rooms x 7 nights x 15-20 anomalies = significant hand-authored content. If anomalies repeat or feel random, "Something's Wrong Here" pillar fails. | Define a small pool of reusable anomaly templates that remix across nights. Test with 5 anomalies in MVP. |

---

## Progress Tracker

| Metric | Count |
| --- | --- |
| Total systems identified | 17 |
| Design docs started | 9 |
| Design docs reviewed | 1 |
| Design docs approved | 0 |
| MVP systems designed | 9/9 |
| Vertical Slice systems designed | 0/4 |

---

## Next Steps

- [ ] Design MVP-tier systems first (use `/design-system [system-name]` or `/map-systems next`)
- [ ] Start with First-Person Controller (design order #1)
- [ ] Run `/design-review` on each completed GDD
- [ ] Prototype the Photography System early — highest-risk MVP system
- [ ] Run `/gate-check pre-production` when all 9 MVP systems are designed
