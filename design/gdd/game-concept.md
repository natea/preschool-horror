# Game Concept: Show & Tell

*Created: 2026-04-08*
*Status: Draft*

---

## Elevator Pitch

> It's a first-person horror game where you sneak into a haunted preschool each
> night to photograph anomalies — things out of place, moving objects, and
> eventually full-blown monsters — and submit the evidence to your boss. But
> your boss is actually an anomaly himself, and he's been sending you in hoping
> one of them will attack you while you're distracted taking a photo, so you can
> be turned into one of them.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | First-person horror / photography / investigation |
| **Platform** | PC, Web |
| **Target Audience** | Horror fans who enjoy atmospheric dread and escalating tension (see Player Profile) |
| **Player Count** | Single-player |
| **Session Length** | 7-10 minutes per night (~1-1.5 hours total) |
| **Monetization** | Premium (or free web release) |
| **Estimated Scope** | Medium (4-6 weeks, solo) |
| **Comparable Titles** | Phasmophobia, Fatal Frame, Content Warning, 8 Passengers |

---

## Core Fantasy

You are the only person who knows this preschool is haunted — and nobody
believes you. Armed with nothing but a camera, you sneak in after hours to
capture proof of the impossible. The cheerful children's decorations, the tiny
chairs, the finger-paintings on the walls — they're all wrong somehow, and it
gets worse every night. By the end, you realize the person who sent you in was
never on your side.

The core fantasy is **the lone investigator proving the impossible is real** —
combined with the creeping realization that **you've been the prey all along**.

---

## Unique Hook

Like Phasmophobia's ghost investigation, AND ALSO the horror escalates from
subtle environmental wrongness (a drawing that changed, blocks that moved) to
full monster chaos across 7 nights — and the person grading your evidence is
secretly the thing that's been setting you up to fail.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 2 | Audio design (ambient creaks, distant laughter), lighting shifts, camera flash in darkness |
| **Fantasy** (make-believe, role-playing) | 3 | You ARE the paranormal investigator. The camera is your identity. |
| **Narrative** (drama, story arc) | 1 | The boss twist, escalating story through evidence and dialogue, the "why" behind the preschool |
| **Challenge** (obstacle course, mastery) | 4 | Spotting subtle anomalies, getting good photos under pressure, surviving later nights |
| **Fellowship** (social connection) | N/A | Single-player (but highly streamable — social through content creation) |
| **Discovery** (exploration, secrets) | 1 | Finding anomalies, uncovering lore, piecing together the truth |
| **Expression** (self-expression, creativity) | N/A | Not a creative expression game |
| **Submission** (relaxation, comfort zone) | N/A | This game is the opposite of relaxing |

### Key Dynamics (Emergent player behaviors)

- Players will obsessively scan every room, comparing details to "normal" to spot anomalies
- Players will develop a risk/reward calculus: "Do I photograph this or run?"
- Players will replay earlier nights after the twist to catch clues they missed
- Players will share screenshots and theories about the boss's true nature
- Players will create content (streams, videos) — the escalation arc is built for reactions

### Core Mechanics (Systems we build)

1. **Photography system** — First-person camera with viewfinder, zoom, flash. Photos must capture anomalies head-on for a clear shot. Evaluation: anomaly must be within camera frustum, facing the camera, and reasonably framed. Standing still to take photos increases vulnerability.
2. **Anomaly system** — Environmental anomalies (static wrongness) and monster anomalies (reactive creatures). Each has placement rules, behavior states, and photo-detection criteria.
3. **Night progression system** — 7 nights with escalating anomaly density and type. Night 1 is 10 minutes; each subsequent night decreases by 30 seconds (Night 7 = 7 minutes). Night defines which anomaly pool is active and monster behavior aggressiveness.
4. **Evidence submission** — Morning debriefs with the boss. Photos are graded on clarity (head-on, anomaly visible). If the player submits no photos for the first 3 nights, the boss transforms into his monster form and attacks — game over. The boss gets progressively angrier when evidence is lacking. The reason the player returns each night despite the danger: the boss keeps increasing the pay.
5. **Player survival** — A vulnerability bar fills when the player stands still (especially while photographing). When full, nearby monsters attack. No combat — only running, hiding, and escaping through the preschool's vent system. Death restarts the current night; unsubmitted photos are lost, but story progress is kept.
6. **Vent system** — Interconnected vents throughout the preschool serve as escape routes and shortcuts. Critical for Night 7 escape sequence.
7. **Night 7 finale** — A cutscene plays: the boss emerges from the principal's room in his true monster form. The player must escape the school through the vent system without getting caught. Successfully escaping wins the game.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Choose which rooms to explore, which anomalies to prioritize, when to leave | Core |
| **Competence** (mastery, skill growth) | Get better at spotting subtle anomalies; learn monster patterns; take better photos | Core |
| **Relatedness** (connection, belonging) | Emotional investment in the boss relationship and the story of what happened at the preschool | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Explorers** (discovery, understanding systems, finding secrets) — Primary. The entire game is about exploring a space and uncovering what's wrong with it.
- [x] **Achievers** (goal completion, collection, progression) — Secondary. Completionists will want to photograph every anomaly and get perfect evidence ratings.
- [ ] **Socializers** (relationships, cooperation, community) — Not directly, but the game is highly streamable and will generate community discussion.
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — Not applicable.

### Flow State Design

- **Onboarding curve**: Night 1 is quiet and tutorial-like. Few anomalies, all environmental, no danger. Teaches camera mechanics and evidence submission through play.
- **Difficulty scaling**: Each night adds new anomaly types and behaviors. Nights 1-2 are observation puzzles. Nights 3-4 introduce reactive monsters. Nights 5-7 are survival horror with full monster density.
- **Feedback clarity**: Boss grades photos with specific feedback ("too blurry", "I can see it clearly — this is disturbing"). Photo quality is visible in-camera. Anomaly proximity cues (audio distortion, visual glitches).
- **Recovery from failure**: If attacked (vulnerability bar maxes out), you restart the current night. Unsubmitted photos are lost, story progress is kept. Quick restart — no game over screen, straight back to the beginning of the night.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Walk through preschool rooms. Scan the environment — something feels off. A
crayon drawing has changed, blocks have rearranged, a shadow is too dark. Stop,
raise the camera, frame the anomaly, and snap. The photo goes into the evidence
folder. In later nights, the anomaly might react when photographed — or when
you turn your back.

### Short-Term (5-15 minutes)
Each room is an investigation zone. Enter, scan for anomalies, photograph what
you find, decide whether to push deeper or head back. Risk increases as you go
further from the exit. Each room has escalating wrongness across nights.

### Session-Level (one night, 7-10 minutes)
A timed run through the preschool. Night 1 is 10 minutes; each subsequent night
decreases by 30 seconds (Night 7 = 7 minutes). Photograph as many anomalies as
possible before time runs out, then report to the boss in the morning. He grades
evidence — photos must be head-on and clear. Good evidence advances the story
and increases pay (the reason you keep coming back). Submit nothing for 3 nights
straight and the boss transforms and attacks. Each night, the preschool gets worse.
If you die (vulnerability bar maxes out → monster attack), you restart the night
and lose unsubmitted photos but keep story progress.

### Long-Term Progression (across 7 nights)
- **Nights 1-2**: Environmental anomalies only. Subtle wrongness. Pure creeping dread. 10 min / 9.5 min.
- **Nights 3-4**: First monsters appear. Small, unsettling (living dolls, shadow figures). Mix of environmental and creature anomalies. Vulnerability bar becomes relevant. 9 min / 8.5 min.
- **Nights 5-6**: Full chaos. Monsters everywhere, big jumpscares earned by the slow build. Vent system becomes essential for survival. 8 min / 7.5 min.
- **Night 7**: Boss reveal cutscene — boss emerges from the principal's room in monster form. Player must escape the school through vents without getting caught. Win condition: escape the building. 7 min.

**Why the player keeps coming back**: The boss increases the pay each night. The player character is motivated by money despite the growing danger — until Night 7, when survival replaces profit as the goal.

### Retention Hooks
- **Curiosity**: What's in the next room? What happens on the next night? What's the boss's real story?
- **Investment**: Photos collected, story progress, the building dread of the twist
- **Social**: "You won't BELIEVE what happens on Night 5" — built for sharing
- **Mastery**: Spotting anomalies faster, getting cleaner photos, surviving longer in dangerous rooms

---

## Game Pillars

### Pillar 1: "Something's Wrong Here" (Creeping Dread to Earned Terror)
Horror starts as wrongness in familiar spaces and escalates to full monster
chaos. The slow build makes the payoff hit harder.

*Design test*: If we're debating pacing — early nights must be quiet so late
nights feel explosive. Restraint early, chaos late.

### Pillar 2: "Prove It" (Evidence as Gameplay)
The camera isn't a weapon — it's your purpose. Every interaction serves the
loop of spotting, framing, capturing, and submitting evidence.

*Design test*: If a feature doesn't connect to evidence collection, it doesn't
belong. The camera is the verb.

### Pillar 3: "Trust No One" (Narrative Deception)
The story is built on a lie the player accepts. Every system supports the slow
reveal — the boss's dialogue, the anomaly behavior, the escalating danger all
point toward the truth without giving it away too early.

*Design test*: If we're debating a boss dialogue line — does it work on first
read (helpful boss) AND second read (sinister manipulator)? If not, rewrite.

### Pillar 4: "One More Night" (Escalation Arc)
Each night is a distinct tier of horror. Night 1 and Night 5 should feel like
completely different games.

*Design test*: If we're debating where to spend dev time — later nights with
monsters get priority over padding early nights.

### Anti-Pillars (What This Game Is NOT)

- **NOT an action game**: No combat, no weapons. You photograph, you run, you hide. Adding combat would undermine the vulnerability that makes the horror work.
- **NOT front-loaded scares**: Nights 1-2 must be restraint. The payoff requires patience. No monsters before Night 3 — breaking this rule would collapse the escalation arc.
- **NOT open-world**: The preschool is contained and curated. Every room is hand-designed, not procedurally generated. Tight spaces make horror more effective than vast ones.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Vigil | Blink-scare mechanic, vulnerability while using supernatural sight | Camera replaces blink — you're vulnerable while framing a shot, not while seeing | Validates that "tool-as-vulnerability" creates excellent horror tension |
| Phasmophobia | Ghost investigation loop, evidence collection, escalating danger | Single-player, narrative-driven with a twist, not procedural | Validates the core loop of investigate-document-survive |
| Fatal Frame | Camera as primary interaction with the supernatural | Anomalies are visible without the camera — camera is for proof, not sight | Validates photography as a core horror mechanic |
| Content Warning | Filming scary things for views/money, humor in horror | Darker tone, boss relationship instead of social media, deception twist | Validates "capture evidence" as engaging gameplay |
| 8 Passengers / anomaly games | Spot-the-difference horror, subtle wrongness in familiar settings | Escalates from spot-the-difference to full survival horror | Validates the "something's wrong" mechanic as compelling |

**Non-game inspirations**:
- Found-footage horror films (Blair Witch, Paranormal Activity) — the camera as both tool and limitation
- Creepypasta / internet horror (Backrooms, SCP Foundation) — familiar spaces made wrong
- Preschool/daycare horror aesthetic — the contrast between childhood innocence and supernatural threat

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 13-30 |
| **Gaming experience** | Casual to mid-core horror fans |
| **Time availability** | 15-20 minute sessions (one night per sitting, or binge the whole game in 2-3 hours) |
| **Platform preference** | PC (Steam/itch.io), Web browser |
| **Current games they play** | Phasmophobia, Lethal Company, Content Warning, Five Nights at Freddy's, indie horror on itch.io |
| **What they're looking for** | A short, intense horror experience with a satisfying story twist and great streamer moments |
| **What would turn them away** | Long tutorial sections, combat-focused gameplay, lack of scares, overly complex systems |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6 (already configured) |
| **Key Technical Challenges** | Photo evaluation system (judging framing/clarity), anomaly state management across nights, first-person camera controls in Godot, web export optimization |
| **Art Style** | Low-poly 3D — slightly uncanny, charming-gone-wrong preschool aesthetic |
| **Art Pipeline Complexity** | Medium — low-poly preschool environment (modular rooms), Mixamo for monster characters and animations, simple textures with baked lighting |
| **Audio Needs** | Heavy — ambient soundscape is critical for horror (creaks, distant laughter, music box, breathing). Adaptive audio that responds to anomaly proximity. |
| **Networking** | None (single-player) |
| **Content Volume** | 5-7 rooms, 7 nights, 15-20 environmental anomalies, 3-5 monster types, ~2-3 hours gameplay |
| **Procedural Systems** | Anomaly placement could be semi-randomized within hand-designed rooms for replayability |

---

## Visual Identity Anchor

> *This section is the seed of the art bible — it captures the visual direction
> before it can be forgotten between sessions.*

**Selected Direction**: Cheerful Decay

**Visual Rule**: Everything looks like a real preschool — bright colors,
rounded shapes, children's artwork — but something is always slightly wrong.
The horror lives in the gap between "this should be safe" and "this is not."

**Supporting Principles**:
1. **Innocence Corrupted** — Every monster and anomaly should contrast with the
   preschool setting. A teddy bear that moves. A drawing that watches. Blocks
   that spell something they shouldn't. *Design test: Would this be normal in a
   preschool? If yes, corrupt it. If no, it doesn't belong here.*
2. **Darkness as Escalation** — Early nights are well-lit with subtle wrongness.
   Later nights get darker, forcing reliance on the camera flash. *Design test:
   Does the lighting match the night's horror tier?*
3. **Low-Poly Uncanny** — The low-poly style should feel slightly "off" even
   for normal objects — like a childhood memory that isn't quite right. Not
   realistic, not cartoon. In between. *Design test: Does this model look like
   it belongs in a dream version of a preschool?*

**Color Philosophy**: Pastel primary colors (red, blue, yellow, green) for the
preschool environment. Desaturated and shifted toward sickly greens/purples as
nights progress. Monsters use colors that don't belong in a preschool (deep
red, void black, unnatural white).

---

## Risks and Open Questions

### Design Risks
- 7 nights of anomaly content may become repetitive if anomalies aren't varied enough
- The boss twist needs careful foreshadowing — too obvious ruins it, too hidden feels like a cheat
- Photo evaluation system could feel arbitrary if grading criteria aren't clear to the player

### Technical Risks
- First-person 3D in Godot with web export — performance must be carefully managed
- Photo evaluation (framing, clarity, subject detection) is non-trivial to implement well
- Anomaly state management (which anomalies are active, which rooms are modified) across 7 nights

### Market Risks
- Horror market is crowded — the game needs strong streamer/content creator appeal to stand out
- Web export limits graphical fidelity — may affect horror atmosphere
- Short game length (~2-3 hours) may limit perceived value if sold as premium

### Scope Risks
- 7 nights x 7 rooms = significant content design burden for a solo first-time developer
- Mixamo characters need integration/customization work to feel unique (not "stock model horror")
- Audio design is critical for horror but time-consuming to get right

### Open Questions
- Should anomalies be randomized per run for replayability, or fixed for tighter pacing?
- Can the player photograph the boss during the Night 7 escape (secret ending / achievement)?
- Does the vent system have its own dangers (monsters in vents, blocked routes)?
- What visual/audio cues signal the vulnerability bar filling?

---

## MVP Definition

**Core hypothesis**: Players find the loop of exploring a preschool, spotting
anomalies, photographing them, and submitting evidence to the boss engaging and
scary for at least 3 nights.

**Required for MVP**:
1. First-person movement and camera controls in a 3-room preschool
2. Photography mechanic — raise camera, frame subject, take photo, review photos
3. 5 environmental anomalies placed across 3 nights (escalating)
4. 1 monster type (appears Night 3)
5. Boss dialogue screen between nights — grades photos, advances story
6. Night timer and basic fail state (attacked = night ends)

**Explicitly NOT in MVP** (defer to later):
- Full 7-night arc (MVP tests the loop with 3)
- Boss twist reveal (MVP ends at Night 3 — twist is mid/late game)
- Multiple monster types (1 is enough to test the monster-phase feel)
- Audio design beyond basic ambient (placeholder sounds acceptable)
- Photo quality grading beyond basic "anomaly in frame yes/no"
- Semi-randomized anomaly placement (fixed placement for MVP)

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 3 rooms, 3 nights, 5 anomalies, 1 monster | Core loop + basic boss dialogue | 1-2 weeks |
| **Vertical Slice** | 5 rooms, 5 nights, 10 anomalies, 2 monsters | Photo grading, boss twist hints, audio pass | 3-4 weeks |
| **Full Vision** | 7 rooms, 7 nights, 20 anomalies, 5 monsters | Boss reveal, multiple endings, full audio, polish | 4-6 weeks |
| **Extended** | 7+ rooms, secret areas, bonus nights | Unlockable lore, boss confrontation, NG+ with harder anomalies | 8-12 weeks |

---

## Next Steps

- [x] Run `/setup-engine` to configure engine (**DONE** — Godot 4.6 / GDScript)
- [x] Run `/art-bible` to create visual identity specification (**DONE** — 9 sections at `design/art/art-bible.md`)
- [x] Run `/design-review design/gdd/game-concept.md` to validate concept completeness (**DONE** — all gaps resolved)
- [ ] Run `/map-systems` to decompose concept into individual systems
- [ ] Run `/design-system` to author per-system GDDs
- [ ] Run `/create-architecture` to produce the master architecture blueprint
- [ ] Run `/architecture-decision (xN)` to record key technical decisions
- [ ] Run `/gate-check` to validate readiness before production
- [ ] Run `/prototype camera-system` to validate the core photography loop
- [ ] Run `/playtest-report` after prototype to validate the core hypothesis
- [ ] Run `/sprint-plan new` to plan the first sprint
