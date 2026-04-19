# Evidence Submission / Boss Debrief

> **Status**: Designed
> **Author**: Nate Aune + agents
> **Last Updated**: 2026-04-12
> **Implements Pillar**: Pillar 3 ("Trust No One") — the boss debrief is the game's most carefully constructed lie

## Overview

The Evidence Submission / Boss Debrief system is the narrative punctuation between nights in Show & Tell. It owns the morning-after interaction where the player presents their photographic evidence to the boss, receives a grade, collects pay, and hears dialogue that — on first playthrough — reads as a demanding but fair employer, and on second playthrough reveals itself as manipulation by an anomaly wearing a human mask. When Night Progression transitions to DEBRIEF, Evidence Submission queries the Photography System's `get_photos_for_submission()` and `get_night_evidence_score()` to assemble a `DebriefData` payload: boss dialogue lines (selected from a tone-appropriate pool based on night number, night grade, and boss anger state), the night's letter grade, calculated pay, and a directive for the next night. The HUD/UI System's Boss Debrief register renders this payload with enforced dwell time (1.7–3.7s) before the player can press Continue. Pay escalates each night regardless of performance — the financial bait that justifies the player's return to an increasingly hostile preschool. Boss anger tracks separately: good evidence resets it, poor or absent evidence builds it, and three consecutive nights with zero photos triggers `boss_transformation_triggered` — a game-over where the boss drops the pretense and attacks. The player experiences Evidence Submission as the only safe moment in the game — warm amber text, serif authority, official grade stamps — and does not realize until the twist that "safe" was always the most dangerous place to be. Night 7's debrief is replaced by the escape outcome: either the player wins or they don't reach the debrief at all.

## Player Fantasy

**"Good Work. Come Back Tomorrow."** The player should feel the specific, dangerous comfort of being praised by the only person who talks to them. The debrief is the game's exhale — you survived the night, the warm amber screen replaces the dark preschool, and a calm authority figure tells you whether you did a good job. On first playthrough, this is the part of the game you look forward to. On second playthrough, it's the part that makes your skin crawl.

The Evidence Submission system serves two layered fantasies that trade meaning after the Night 7 reveal:

- **The Good Employee (first playthrough).** The boss is the only human connection in the game. He grades your photos with specific feedback, pays you fairly, and gives you directives that feel like guidance. Getting an A grade triggers a genuine flush of validation — someone sees what you saw, someone believes you, someone thinks you're good at this. The pay escalation feels earned: the job is getting harder, so the compensation rises. The player develops real affection for this character because he is calm when the world is wrong, professional when everything else is chaos, and interested in your wellbeing in a way that feels paternal. "Be careful in there tomorrow" reads as concern. The debrief is safety. The debrief is home base. The debrief is the reason you come back.

- **The Handler's Assessment (second playthrough).** Every "good work" was encouragement to go deeper. Every pay raise was calibrated to keep you just past your threshold of fear. Every directive — "check the art room tonight, I've heard reports about the east wing" — was steering you toward the most dangerous anomalies, because the boss needs you in close proximity to them. The grading wasn't evaluating your photography. It was evaluating *you*: how brave, how thorough, how perfectly you walk into the trap. The warm amber text was never comfort. It was the color of a lure. The player realizes they weren't being employed. They were being prepared.

The anchor moment is Night 3 or Night 4. The player has just survived their first monster encounter. Hands shaking. They submit the photos. The boss says something like: "These are excellent. You're the only person who could do this." First read: validation from a demanding employer. Second read: a predator confirming its prey is ready. The player felt *seen* and *valued* — and that feeling is what Pillar 3 weaponizes.

The boss's tone evolves across seven nights to serve the escalation arc:
- **Nights 1–2**: Friendly onboarding. Professional warmth. "Take your time. Get comfortable with the space." The debrief is brief and encouraging. The player is being acclimated.
- **Nights 3–4**: Engaged mentor. "You're getting really good at this. I knew I picked the right person." The boss asks pointed questions about what the player saw — first read: scientific curiosity; second read: he already knows what's in there. Pay increases noticeably.
- **Nights 5–6**: Urgent investment. "We're so close to getting what we need. Just a few more nights." First read: research deadline pressure. Second read: the transformation ritual is almost complete. Pay is now uncomfortable — why is this job worth this much?
- **Night 7**: No debrief. The boss is in the building. The mask is off.

The pay mechanic exists in the background, not the foreground. It justifies the player-character's return but does not dominate the emotional experience. The player should think "the money is good" on Night 1 and "why is the money *this* good?" by Night 5. The grade is the emotional anchor. The pay is the rationalization.

*Serves Pillar 3: "Trust No One" — the debrief IS the lie, and its warm visual identity is the game's most carefully constructed piece of emotional manipulation. Serves Pillar 2: "Prove It" — the grade validates the player's photography skill and makes evidence-gathering feel purposeful. Serves Pillar 4: "One More Night" — the boss's escalating pay and encouraging tone are the explicit mechanic that pulls the player into the next night.*

## Detailed Design

### Core Rules

#### Debrief Flow

When Night Progression transitions to DEBRIEF, Evidence Submission executes these steps in order:

**Step 1 — Receive trigger.**
Evidence Submission receives `night_completed(n, photos_submitted, timer_expired)` from Night Progression. The system locks — no further photo or night signals are processed.

**Step 2 — Night 7 guard.**
If `n == 7`: skip Steps 3–6, enter Night 7 Win Debrief path (see below). Night 7 always means the player escaped — death restarts Night 7, never reaches DEBRIEF.

**Step 3 — Query Photography System.**
- Call `PhotographySystem.get_photos_for_submission()` → `Array[PhotoRecord]`.
- Call `PhotographySystem.get_night_evidence_score()` → `float` (0.0–1.0).
- Derive `night_grade` from `night_evidence_score` against `NIGHT_GRADE_THRESHOLDS` (A≥0.70, B≥0.50, C≥0.30, D≥0.15, F<0.15).
- If `photos_submitted == 0`: force `night_grade = F`, `night_evidence_score = 0.0`.

**Step 4 — Update boss state.**
- Compute `boss_anger_new` from `boss_anger_prev`, `night_grade`, and `n` (see Formulas).
- The `consecutive_nights_no_photos` counter is owned by Night Progression — Evidence Submission reads it but does not modify it. Night Progression increments it after receiving `debrief_completed`.

**Step 5 — Select dialogue.**
Pull dialogue lines from the dialogue table based on `(current_night, night_grade, boss_tone_state)`. The tone state is derived from `boss_anger_new`:

| Anger Range | Tone State | Boss Behavior |
|---|---|---|
| 0–2 | CALM | Pleased, professional, encouraging. Warm greeting. |
| 3–5 | IRRITATED | Clipped, demanding, passive-aggressive. Shortened greeting. |
| 6–8 | THREATENING | Explicit warnings, veiled references to "the arrangement." No greeting — straight to business. |
| 9–10 | FURIOUS | Barely contained. Transformation affect visible in word choice. The mask slips. |

Dialogue is composed from four categories:
1. **Opening** (1 line): Sets tone. CALM: warm greeting. THREATENING+: skipped entirely.
2. **Evidence Observation** (1–2 lines): Reacts to photos. References the grade tier, not individual photos. On zero photos: 1 terse line only.
3. **Pay Statement** (1 line): Always mentions the dollar amount. "There's $350 for your trouble." / "I'm paying you $160. Consider it a courtesy."
4. **Directive** (1 line): Night-specific instruction for the next night. Fixed per night number regardless of grade — the boss's plan doesn't change based on the player's performance.

The boss does NOT speak the grade aloud. The grade stamp appears silently — the boss's omission is more threatening than announcement.

**Step 6 — Compute pay.**
Apply `night_pay(n, night_grade)` (see Formulas). Pay always escalates by night regardless of grade. Even F-grade earns 80% of base. Zero photos earn $0.

**Step 7 — Assemble DebriefData.**
```
DebriefData {
    dialogue_lines: Array[String]   # 2–4 lines (opening + observation + pay + directive)
    grade: String                   # "A" | "B" | "C" | "D" | "F"
    pay_amount: int                 # Computed pay, always >= 0
    directive: String               # Night directive (final line)
    current_night: int              # 1–7, for HUD Color Debt computation
}
```

**Step 8 — Show debrief.**
Call `HUDUISystem.show_debrief(data)`. HUD renders the Boss Debrief register with enforced dwell time (`T_dwell` = 1.7–3.7s) before the Continue prompt appears. Evidence Submission waits for `debrief_continue_pressed`.

**Step 9 — Emit completion.**
On `debrief_continue_pressed`: persist `boss_anger_new` for next night. Emit `debrief_completed`. Return to IDLE. Night Progression then handles the `consecutive_nights_no_photos` check, night increment, and `player_confirmed_return`.

#### Night 7 Win Debrief

When `n == 7` and the player escaped the FINALE:

- No photo grading. No pay calculation.
- `grade = "—"` (em dash, not a letter grade).
- `pay_amount = 0`.
- Dialogue: 2 pre-authored lines. The boss is quiet. No greeting, no evidence observation, no pay statement. The dialogue reads as unsettling on first playthrough ("where is he? why is he so calm?") and revealing on second playthrough.
- Directive: replaced by a single closing line.
- After `debrief_continue_pressed`: emit `debrief_completed`. Night Progression handles `game_won`.

#### Photo Thumbnail Strip

The debrief displays a small thumbnail strip below the boss dialogue showing each photo submitted this night with its individual grade letter stamped on it. This is a passive receipt — the boss does not reference individual photos. The strip serves the feedback loop: the player sees which photos were C/D quality and understands why their night grade is what it is.

- Maximum 4 thumbnails visible at once. Scrollable if more photos taken.
- No animation. Thumbnails appear simultaneously with the pay display (after the grade stamp).
- Zero photos: no strip shown. Empty space below dialogue — more unsettling than a placeholder.

#### Dialogue Dual-Read Rule (Pillar 3)

Every authored dialogue line MUST pass the two-read test:
- **First read (helpful employer)**: The line must be plausible as professional, if demanding, workplace communication.
- **Second read (sinister manipulator)**: The same line must carry a darker meaning once the player knows the boss is an anomaly.

Lines that only work one way fail the test and must be rewritten.

**Example — Night 3, CALM tone:**
> "You're getting better at this. The photo from the bathroom is exactly what I needed."
> - First read: "encouraging boss with specific feedback"
> - Second read: "he needed confirmation that the bathroom creature is active"

#### Directives Per Night

Directives are fixed per night number. They guide the player toward specific areas and serve as foreshadowing on second playthrough.

| Night | Directive | First Read | Second Read |
|---|---|---|---|
| 1 | "Take your time tomorrow. Get comfortable with the space." | Friendly onboarding | Wants you deeper in the building |
| 2 | "Focus on the classrooms. That's where the reports come from." | Directing investigation | Steering you toward active anomalies |
| 3 | "The bathroom area has been getting worse. I need documentation." | Research urgency | Sending you where the first monster spawns |
| 4 | "Cover more ground. Every room matters now." | Thorough investigation | Maximum exposure to every threat |
| 5 | "We're close. Push further than you have before." | Research deadline | The ritual is almost ready |
| 6 | "One more night after this. Make it count." | Final push encouragement | Last chance to prepare the trap |

#### Authored Content Budget

Total dialogue lines: 6 nights × 4 tone states × ~4 lines per state + 6 directives + 2 Night 7 lines ≈ **104 authored lines**. Achievable for solo development — each line is 1–2 sentences.

### States and Transitions

#### Evidence Submission State Machine

```
enum DebriefState {
    IDLE,
    RECEIVING,
    COMPUTING,
    DISPLAYING,
    EMITTING
}
```

| State | Duration | Activity |
|---|---|---|
| **IDLE** | Indefinite | Default between nights. No processing. |
| **RECEIVING** | 1 frame | Receives `night_completed`, locks input, queries Photography. |
| **COMPUTING** | 1 frame | Builds boss state, selects dialogue, computes pay, assembles DebriefData. |
| **DISPLAYING** | T_dwell + player wait | HUD renders debrief. Waits for `debrief_continue_pressed`. |
| **EMITTING** | 1 frame | Persists boss_anger, emits `debrief_completed`. Returns to IDLE. |

**Transition Rules:**

| From | To | Trigger |
|---|---|---|
| IDLE | RECEIVING | `night_completed` signal received |
| RECEIVING | COMPUTING | Photography queries complete (same frame) |
| COMPUTING | DISPLAYING | DebriefData assembled, `show_debrief()` called |
| DISPLAYING | EMITTING | `debrief_continue_pressed` received |
| EMITTING | IDLE | `debrief_completed` emitted |

RECEIVING, COMPUTING, and EMITTING are instantaneous (single-frame transient states). DISPLAYING is the only state with player-visible duration — timing is owned by the HUD/UI System's `T_dwell` formula.

### Interactions with Other Systems

#### Inputs (other systems → Evidence Submission)

| Signal / Method | From System | When | Effect |
|---|---|---|---|
| `night_completed(n, photos_submitted, timer_expired)` | Night Progression | Night ends (ACTIVE→DEBRIEF) | Triggers debrief flow. Only entry point. |
| `night_7_escaped` | Night Progression | Player wins FINALE | Sets internal `_night_7_escaped` flag for win debrief path |
| `get_photos_for_submission() → Array[PhotoRecord]` | Photography System (query) | Step 3 of debrief flow | Returns all photos captured this night |
| `get_night_evidence_score() → float` | Photography System (query) | Step 3 of debrief flow | Returns aggregate evidence quality (0.0–1.0) |
| `debrief_continue_pressed` | HUD/UI System | Player presses Continue after T_dwell | Advances from DISPLAYING to EMITTING |

#### Outputs (Evidence Submission → other systems)

**Signals:**

| Signal | Parameters | Consumed By | When |
|---|---|---|---|
| `debrief_completed` | (none) | Night Progression | After player presses Continue and state updates complete |
| `show_debrief(data: DebriefData)` | DebriefData struct | HUD/UI System | Step 8 — triggers Boss Debrief register rendering |

**Query API:**

| Method | Returns | Callers |
|---|---|---|
| `get_boss_anger() → int` | Current boss anger (0–10) | Save/Persistence, debug |
| `get_last_pay() → int` | Pay from most recent debrief | Save/Persistence, debug |
| `get_cumulative_pay() → int` | Total pay earned across all nights | Main Menu / Game Flow (optional display) |

#### Internal State (persisted across nights, not exposed as signals)

| Variable | Type | Range | Description |
|---|---|---|---|
| `boss_anger` | int | 0–10 | Cumulative anger score. Starts at 0. Updated each debrief. |
| `cumulative_pay` | int | 0–∞ | Total pay earned. Display only — no gameplay effect. |
| `_night_7_escaped` | bool | — | Flag set by `night_7_escaped` signal, consumed in Night 7 debrief path |

## Formulas

### Night Pay

The `night_pay` formula calculates the player's earnings for a completed night. Pay escalates by night to serve as the retention bait (Pillar 4) — the player-character returns because the money justifies the danger.

`night_pay(n, G) = floor(BASE_PAY_TABLE[n] * GRADE_MULTIPLIER[G])`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Night number | n | int | 1–6 | Current night (Night 7 has no pay) |
| Night grade | G | enum | {A,B,C,D,F} | From Photography System's night_grade_thresholds |
| Base pay table | BASE_PAY_TABLE | int[] | [200,200,350,350,600,600] | Per-night base pay in dollars |
| Grade multiplier | GRADE_MULTIPLIER | float | 0.80–1.25 | Grade-indexed bonus/penalty |
| Night pay | night_pay | int | 0–750 | Final pay displayed in Boss Debrief |

**Grade Multiplier Lookup:**

| Grade | Multiplier | Rationale |
|---|---|---|
| A | 1.25 | Meaningful bonus without making grade optimization dominant |
| B | 1.10 | Good work acknowledged |
| C | 1.00 | Base rate — competent effort |
| D | 0.90 | Slight penalty, still worth returning |
| F | 0.80 | Floor penalty — boss still pays, needs player to come back |

**Special case:** If `photos_submitted == 0`, `night_pay = 0` regardless of formula. This is the only path to zero pay. A player who submits terrible photos still earns the 0.80x floor.

**Pay Table (all combinations):**

| Night | Base | A ($) | B ($) | C ($) | D ($) | F ($) |
|---|---|---|---|---|---|---|
| 1 | 200 | 250 | 220 | 200 | 180 | 160 |
| 2 | 200 | 250 | 220 | 200 | 180 | 160 |
| 3 | 350 | 437 | 385 | 350 | 315 | 280 |
| 4 | 350 | 437 | 385 | 350 | 315 | 280 |
| 5 | 600 | 750 | 660 | 600 | 540 | 480 |
| 6 | 600 | 750 | 660 | 600 | 540 | 480 |
| 7 | — | — | — | — | — | — |

**Output Range:** $0 (zero photos) to $750 (Night 5/6, A-grade).

**Example — Night 4, Grade B:**
- `BASE_PAY_TABLE[4] = 350`
- `GRADE_MULTIPLIER[B] = 1.10`
- `night_pay = floor(350 × 1.10) = floor(385.0) = $385`

**Tuning rationale:** Nights pair up (1/2, 3/4, 5/6) to create plateaus — the jump happens when danger tier changes, not every night. The 75% jump from $200→$350 at Night 3 coincides with the first monster appearance. The 71% jump from $350→$600 at Night 5 coincides with Tier 3 horror. The F-grade floor at 80% ensures the player always has a reason to try the next night.

---

### Boss Anger Update

The `boss_anger_update` formula tracks the boss's cumulative satisfaction/displeasure across the game. Anger drives dialogue tone selection. It is **separate from pay** — pay always escalates; anger varies based on performance.

`boss_anger_new = clamp(boss_anger_prev + anger_delta(G, n), 0, 10)`

Where:

`anger_delta(G, n) = BASE_GRADE_DELTA[G] + NIGHT_PRESSURE_BONUS[n]`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Previous anger | boss_anger_prev | int | 0–10 | Anger entering this debrief |
| Night grade | G | enum | {A,B,C,D,F} | Night grade from Photography System |
| Night number | n | int | 1–6 | Current night (Night 7 skipped) |
| Grade delta | BASE_GRADE_DELTA | int | -2 to +3 | Per-grade anger change |
| Night pressure | NIGHT_PRESSURE_BONUS | int | 0–2 | Late-night expectation increase |
| Anger delta | anger_delta | int | -2 to +5 | Total change this debrief |
| New anger | boss_anger_new | int | 0–10 | Clamped result, persisted |

**Grade Delta Lookup:**

| Grade | Delta | Meaning |
|---|---|---|
| A | -2 | Boss is impressed, anger decreases |
| B | -1 | Boss is satisfied |
| C | 0 | Neutral — no change |
| D | +1 | Boss is displeased |
| F | +3 | Boss is angry (F is a big deal) |

**Night Pressure Bonus:**

| Night Range | Bonus | Rationale |
|---|---|---|
| n ≤ 2 | 0 | Boss is patient during onboarding |
| n = 3–4 | +1 | Monsters appeared; boss expects results |
| n ≥ 5 | +2 | Late game — boss stops being patient |

**Dialogue Tone Bands:**

| Anger Range | Tone State | Boss Behavior |
|---|---|---|
| 0–2 | CALM | Pleased, professional, encouraging |
| 3–5 | IRRITATED | Clipped, demanding, passive-aggressive |
| 6–8 | THREATENING | Explicit warnings, veiled references to "the arrangement" |
| 9–10 | FURIOUS | Barely contained. The mask slips in word choice. |

**Output Range:** Clamped 0–10. Initial value: 0 (new game). Cannot go below 0 (floor of professional composure). Cannot exceed 10. The boss transformation trigger is the separate `consecutive_nights_no_photos` counter (owned by Night Progression), NOT an anger overflow.

**Example — Night 3, Grade C (first dangerous night, mediocre evidence):**
- `boss_anger_prev = 0` (CALM after Nights 1–2)
- `BASE_GRADE_DELTA[C] = 0`
- `NIGHT_PRESSURE_BONUS[3] = +1`
- `anger_delta = 0 + 1 = +1`
- `boss_anger_new = clamp(0 + 1, 0, 10) = 1` → CALM (barely)

**Example — Night 5, Grade A (great recovery under pressure):**
- `boss_anger_prev = 5` (IRRITATED from prior bad nights)
- `BASE_GRADE_DELTA[A] = -2`
- `NIGHT_PRESSURE_BONUS[5] = +2`
- `anger_delta = -2 + 2 = 0`
- `boss_anger_new = clamp(5 + 0, 0, 10) = 5` → IRRITATED (held — even A can't fully recover late)

**Tuning rationale:** The night pressure bonus means that from Night 5 onward, even A-grade evidence only barely holds anger steady. The boss is permanently on edge in the late game regardless of performance — this serves Pillar 1's escalation arc. Early good performance creates a buffer (anger stays low through Nights 1–2), which means Night 3–4's first pressure hits are absorbed. A consistently good player stays in CALM through Night 4. A consistently poor player reaches THREATENING by Night 4. This creates meaningfully different narrative experiences based on play quality.

## Edge Cases

- **If the player takes photos but ALL score below PHOTO_SCORE_THRESHOLD (0.15)**: Treated as `photos_submitted > 0` (they tried) but `night_evidence_score = 0.0`, so `night_grade = F`. Pay applies at F-grade multiplier (0.80× base), NOT $0. This is distinct from zero photos — the player made an effort. `consecutive_nights_no_photos` is NOT incremented (photos exist, they're just bad). Boss tone reflects F-grade anger, not the no-photo warning path.

- **If the timer expired AND photos were submitted (grace period exit)**: The `timer_expired` flag in `night_completed` is informational only — Evidence Submission does not modify grading or pay based on it. Photos are graded normally. The boss may reference the late exit in dialogue ("Cutting it close tonight") but the grade and pay formulas are unaffected.

- **If boss_anger is at 10 and the player gets an A-grade**: `anger_delta = -2 + night_pressure_bonus(n)`. On Night 5+, delta = 0 (held at 10). On Night 3–4, delta = -1 (drops to 9). On Night 1–2, delta = -2 (drops to 8). Anger CAN decrease from max — the clamp is 0–10, not a ratchet. But late-game pressure makes recovery very difficult.

- **If boss_anger is at 0 and the player gets an A-grade on Night 1**: `anger_delta = -2 + 0 = -2`. `clamp(0 + (-2), 0, 10) = 0`. Anger cannot go below 0. The boss has a floor of professional composure.

- **If the player submits zero photos for Nights 1 and 2, then submits on Night 3**: `consecutive_nights_no_photos` resets to 0 on Night 3 (photos submitted). No game-over risk. Boss anger was incremented by F+0 each of those nights: Night 1 delta = +3, Night 2 delta = +3, so `boss_anger = 6` (THREATENING). Night 3 with a good grade can start recovering, but the Night 3 pressure bonus (+1) partially offsets.

- **If the player submits zero photos for Nights 1, 2, and 3**: Night Progression fires `boss_transformation_triggered` after Night 3's `debrief_completed`. The boss transformation game-over plays. This is the earliest possible game-over: Night 3 debrief.

- **If `debrief_continue_pressed` fires during COMPUTING or RECEIVING (race condition)**: Signal is ignored. Evidence Submission only listens for `debrief_continue_pressed` while in DISPLAYING state. The HUD/UI System's `T_dwell` ensures the Continue prompt cannot appear before DISPLAYING is entered. Belt and suspenders: Evidence Submission also guards the signal handler with a state check.

- **If Photography System returns empty array but `photos_submitted > 0` (data mismatch)**: Treat as zero photos. Evidence Submission uses `get_photos_for_submission().size()` as the authoritative photo count, overriding the `photos_submitted` parameter from Night Progression. Log a warning for debugging.

- **If two `night_completed` signals fire in the same frame (duplicate signal)**: The first transitions IDLE→RECEIVING. The second is silently dropped because the state is no longer IDLE. Log a warning.

- **If the player gets F-grade every single night (worst-case anger trajectory)**: Night 1: 0 + 3 + 0 = 3 (IRRITATED). Night 2: 3 + 3 + 0 = 6 (THREATENING). Night 3: 6 + 3 + 1 = 10 (FURIOUS, clamped). Night 4+: held at 10. The boss reaches FURIOUS by Night 3 if evidence is consistently terrible. This is the maximum anger curve — players on this path are likely also on the no-photo streak, so they'll hit transformation before the FURIOUS state has much time to express.

- **If Night 7 debrief receives `photos_submitted > 0`**: Ignored. Night 7 always uses the win debrief path. Photos taken during the FINALE escape are not graded — the camera is mechanically irrelevant during the chase. Any photos captured before FINALE started (during ACTIVE) are discarded when FINALE begins.

## Dependencies

### Upstream (systems this one depends on)

| System | Dependency Type | Interface | What Evidence Submission Needs |
|---|---|---|---|
| **Photography System** | Hard | `get_photos_for_submission()`, `get_night_evidence_score()`, PhotoRecord struct | Photo data, per-photo grades, night evidence score. Without Photography, there is nothing to grade. |
| **Night Progression** | Hard | `night_completed(n, photos_submitted, timer_expired)` signal, `night_7_escaped` signal | Trigger to start debrief, night number, photo count, Night 7 escape flag. Without Night Progression, debrief never fires. |
| **HUD/UI System** | Hard | `show_debrief(data: DebriefData)`, `debrief_continue_pressed` signal, Boss Debrief register rendering | Display layer. Without HUD/UI, player sees nothing. Evidence Submission owns content; HUD/UI owns presentation. |
| **Save/Persistence** | Soft | `SaveManager.save_debrief_state(state)`, `SaveManager.load_debrief_state()` (provisional) | Persist `boss_anger` and `cumulative_pay` across sessions. Without Save/Persistence, `boss_anger` resets to 0 each session (graceful degradation). |

### Downstream (systems that depend on this one)

| System | Dependency Type | Interface | What They Need from Evidence Submission |
|---|---|---|---|
| **Night Progression** | Hard | `debrief_completed` signal | Signal to proceed with night increment, counter checks, and transition to next night or terminal state. |
| **Night 7 Finale** | Soft | `boss_anger` query (optional) | May reference boss anger state to adjust Night 7 boss behavior intensity. Design TBD — Night 7 Finale GDD will specify. |
| **Main Menu / Game Flow** | Soft | `get_cumulative_pay()` query | Optional display of total earnings on between-nights screen or end-game summary. |

### Data Flow Summary

```
Night Progression --[night_completed]--> Evidence Submission
Photography System --[query: photos, score]--> Evidence Submission
Evidence Submission --[show_debrief(DebriefData)]--> HUD/UI System
HUD/UI System --[debrief_continue_pressed]--> Evidence Submission
Evidence Submission --[debrief_completed]--> Night Progression
```

### Bidirectional Consistency Notes

- Night Progression's GDD lists `debrief_completed` as a received signal from Evidence Submission ✓
- Night Progression's GDD lists `night_completed` as an emitted signal consumed by Evidence Submission ✓
- Photography System's GDD lists `get_photos_for_submission()` and `get_night_evidence_score()` as query API exposed to Evidence Submission ✓
- HUD/UI System's GDD lists `show_debrief(data)` as a received input and `debrief_continue_pressed` as an emitted signal ✓
- HUD/UI System's `DebriefData` provisional contract matches the struct defined here ✓

### Provisional Contracts

**Save/Persistence contract (minimum data to persist):**

| Field | Type | Description |
|---|---|---|
| `boss_anger` | int (0–10) | Current boss anger level |
| `cumulative_pay` | int | Total pay earned across all nights |

Write trigger: after each `debrief_completed`. Read trigger: session start only (not on death restart — `boss_anger` persists through death because it's cross-night state).

## Tuning Knobs

All tuning knobs are stored in `assets/data/evidence_config.tres` and can be modified without code changes.

### Pay Tuning

| Knob | Default | Safe Range | Too Low | Too High | Interacts With |
|---|---|---|---|---|---|
| `BASE_PAY_TABLE` | [200,200,350,350,600,600] | [50–1000] per entry | Player doesn't feel motivated to return | Pay overshadows the horror — feels like a numbers game | Night Progression (player motivation to continue) |
| `GRADE_MULTIPLIER_A` | 1.25 | 1.10–1.50 | A-grade feels unrewarded | Grade optimization becomes dominant strategy | Photography System (photo quality incentive) |
| `GRADE_MULTIPLIER_B` | 1.10 | 1.00–1.25 | B/C feel identical | B-grade too easy to distinguish from A | — |
| `GRADE_MULTIPLIER_C` | 1.00 | 1.00 (fixed) | — | — | — |
| `GRADE_MULTIPLIER_D` | 0.90 | 0.75–1.00 | D penalty feels punishing (discourages returning) | D and C feel identical | — |
| `GRADE_MULTIPLIER_F` | 0.80 | 0.50–1.00 | F feels punishing, player gives up | F feels rewarding, no incentive to improve | — |
| `ZERO_PHOTO_PAY` | 0 | 0 (fixed) | — | Any value > 0 weakens the no-photo consequence | consecutive_nights_no_photos counter |

### Anger Tuning

| Knob | Default | Safe Range | Too Low | Too High | Interacts With |
|---|---|---|---|---|---|
| `GRADE_DELTA_A` | -2 | -3 to -1 | Good play barely affects anger | Single A-grade resets everything | NIGHT_PRESSURE_BONUS (must offset) |
| `GRADE_DELTA_B` | -1 | -2 to 0 | B feels unrewarded | B and A feel too similar | — |
| `GRADE_DELTA_C` | 0 | 0 (fixed) | — | — | — |
| `GRADE_DELTA_D` | +1 | +1 to +2 | D feels consequence-free | D and F feel too similar | — |
| `GRADE_DELTA_F` | +3 | +2 to +5 | F doesn't feel impactful | Single F pushes boss to THREATENING | Consecutive no-photo counter |
| `NIGHT_PRESSURE_EARLY` | 0 | 0 (fixed for n≤2) | — | — | — |
| `NIGHT_PRESSURE_MID` | +1 | +1 to +2 | Mid-game feels too easy | Mid-game anger spikes regardless of play quality | GRADE_DELTA_A (must be able to counter) |
| `NIGHT_PRESSURE_LATE` | +2 | +1 to +3 | Late game has no tension | A-grade can't reduce anger at all | — |
| `ANGER_MAX` | 10 | 8–12 | Boss reaches FURIOUS too easily | FURIOUS state is unreachable | Tone band thresholds |
| `TONE_BAND_CALM` | 0–2 | 0–3 | CALM range too narrow | CALM persists despite poor play | Dialogue selection |
| `TONE_BAND_IRRITATED` | 3–5 | — | — | — | — |
| `TONE_BAND_THREATENING` | 6–8 | — | — | — | — |
| `TONE_BAND_FURIOUS` | 9–10 | — | — | — | — |

### Dialogue Tuning

| Knob | Default | Safe Range | Too Low | Too High | Notes |
|---|---|---|---|---|---|
| `DIALOGUE_LINES_MIN` | 2 | 2–3 | Debrief feels too abrupt | — | Minimum lines per debrief |
| `DIALOGUE_LINES_MAX` | 4 | 3–5 | — | Debrief drags, breaks pacing | Maximum lines per debrief |

### Interaction Notes

- **BASE_PAY_TABLE and GRADE_MULTIPLIERS interact**: Changing base pay shifts the entire reward curve. Changing multipliers shifts the spread between grades. Tune base pay first, then adjust multipliers for feel.
- **GRADE_DELTA and NIGHT_PRESSURE interact**: The net anger change per debrief is their sum. Ensure that `GRADE_DELTA_A + NIGHT_PRESSURE_LATE` ≤ 0 if you want A-grades to always reduce or hold anger. Currently: -2 + 2 = 0 (hold). If NIGHT_PRESSURE_LATE increases to 3, A-grades will increase anger in late game — this may be desired for maximum Pillar 1 escalation but makes good play feel unrewarded.
- **TONE_BAND thresholds must be contiguous and cover 0–ANGER_MAX**: No gaps allowed. If ANGER_MAX changes, adjust FURIOUS band upper bound to match.

## Visual/Audio Requirements

### Visual Direction

The Boss Debrief register is the game's most carefully constructed visual lie. Every element — color, typography, layout — must feel like safety on first playthrough and read as manipulation on second playthrough.

**Register Identity (from HUD/UI GDD, Section Register 3):**
- Background: Warm dark `#1A1410`
- Typography: Lora (serif, authority). Dialogue 18px, headers 22px bold, grade stamp 48px bold
- Color: Amber-gold `#D4A855` dialogue text with per-night decay (see below)
- Headers: Dark red `#8B2020` (already in the monster register — a Pillar 3 tell)
- Layout: Full-screen overlay on CanvasLayer (max z-index). Transition: 300ms fade to black, 500ms hold, single cut to debrief

**Boss Debrief Color Decay (from HUD/UI GDD):**

| Night | Dialogue Color | Decay |
|---|---|---|
| 1 | `#D4A855` (amber-gold) | Baseline |
| 2 | `#C8A04E` | -5% brightness |
| 3 | `#BC9847` | -10% |
| 4 | `#B09040` | -15% |
| 5 | `#A48839` | -20% |
| 6 | `#988032` | -25% |
| 7 | `#8A6830` (dark amber) | -35% (accelerated) |

**Grade Stamp Visual:**
- Large letter (A/B/C/D/F) in circular dashed border (6px-4px dash-gap), 80px diameter
- Colors: A=`#48B04A` green, B=`#8DB84A` lime, C=`#F5C842` yellow, D=`#E8732A` orange, F=`#C0181E` arterial red
- Single-frame cut appearance — no animation. The impact IS the visual.
- Night 7 win: em dash "—" in the stamp, color `#D4A855` (neutral amber)

**Tone State Visual Tells:**

| Tone | Visual Modifier | Notes |
|---|---|---|
| CALM | None — standard warm amber | Baseline debrief. Pillar 3: this IS the lie. |
| IRRITATED | Dialogue text kerning tightens by 2% | Barely perceptible. Player won't notice consciously. |
| THREATENING | Header underlines pulse at 0.5Hz, 60–100% opacity | First overtly unusual visual. Headers were static before. |
| FURIOUS | Background color shifts from `#1A1410` to `#1A1015` (warmer red tint, -5 green, +5 red). Dialogue line fade-in accelerated (150ms instead of 200ms). | Boss is losing control of his own register. The warm dark is bleeding toward arterial. |

**Photo Thumbnail Strip:**
- Small thumbnails (60×34px, matching 480×270 aspect ratio), spaced 8px apart
- Background card per thumbnail: `#1A1410` with 1px border `#8B2020` at 40% opacity
- Grade letter stamp per thumbnail: 14px Lora bold, same color as full grade stamp
- Position: below dialogue, above the horizontal rule that separates pay from directive
- Maximum 4 visible. Scrollable via horizontal mouse-wheel or D-pad left/right. Scroll indicators: `<` / `>` in `#D4A855` at 50% opacity, appearing only when overflow exists

### Audio Requirements

**Debrief Ambient:**
- On debrief enter (after black hold): a soft, warm room tone. Muffled HVAC hum. Distant clock tick at ~1Hz. This is the ONLY safe-feeling soundscape in the game.
- Per-night ambient corruption: Night 1 is clean. Night 3+: faint low-frequency throb beneath the room tone (20–40Hz, barely audible). Night 5+: the clock tick becomes irregular (random ±200ms jitter on the 1Hz interval). Night 7: room tone cuts to silence. Two dialogue lines play against dead air.
- Ambient does NOT crossfade from the preschool night audio — the 500ms black hold creates a clean audio boundary.

**Grade Stamp SFX:**
- A single percussive impact — a rubber stamp hitting a desk. Dry, authoritative, slightly too loud. The sound carries the emotional weight of the boss's judgment.
- Different pitch per grade: A = low (satisfying), F = high and sharp (punishing). B/C/D interpolated.
- No musical sting. The stamp IS the sting.

**Pay Display SFX:**
- Soft paper-on-desk sound, 200ms after grade stamp. Cash register tick is explicitly forbidden — too playful for the tone.

**Boss Voice:**
- No voice acting. Text only. The boss's voice is in the player's head — each player imagines a different boss, which makes the betrayal more personal.

**Continue Prompt SFX:**
- Subtle single-note chime when the Continue prompt appears (after T_dwell). Warm tone on Nights 1–3. Same note but detuned -15 cents on Nights 4–6. Night 7: no chime — silence.

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:evidence-submission` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

The Boss Debrief is rendered entirely by the HUD/UI System's Register 3 (Boss Debrief). Evidence Submission provides content via `DebriefData`; HUD/UI owns all layout, animation, and input.

**Screen Layout (1080p reference, all elements anchored to vertical center):**

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│  [BOSS DIALOGUE]                                     │
│  Line 1 (fade-in 200ms)                              │
│  Line 2 (fade-in 200ms after line 1)                 │
│  Line 3 (fade-in 200ms after line 2)                 │
│                                                      │
│            ┌──────────┐                               │
│            │  [GRADE]  │  (stamp, 80px)               │
│            └──────────┘                               │
│                                                      │
│  [PHOTO THUMBNAILS]  📷 B  📷 C  📷 A  📷 D          │
│                                                      │
│           $385                                        │
│  ────────────────────── (1px rule, #8B2020 60%)       │
│  "Cover more ground. Every room matters now."         │
│                                                      │
│                              [E] CONTINUE             │
└──────────────────────────────────────────────────────┘
```

**Input Contract:**
- Continue prompt accepts: Keyboard `E`, Gamepad `A`. Switches icon based on last input type.
- Input is ignored during T_dwell (1.7–3.7s). After T_dwell, first valid press emits `debrief_continue_pressed`.
- No other input is accepted during DISPLAYING. Pause menu is disabled during debrief.

**Accessibility Notes:**
- All text must be readable at 1080p minimum. Lora at 18px dialogue, 48px grade stamp.
- Grade stamp uses both color AND the letter — color-blind players can still read the grade.
- No hover-only interactions (per technical preferences — web build constraint).

📌 **UX Flag — Evidence Submission**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the Boss Debrief screen before writing epics. Stories that reference the debrief UI should cite `design/ux/boss-debrief.md`, not the GDD directly.

## Acceptance Criteria

### Debrief Flow (BLOCKING)

- **AC-01**: GIVEN the game is in ACTIVE state during any night 1–6, WHEN Night Progression emits `night_completed(n, photos_submitted, timer_expired)`, THEN Evidence Submission transitions from IDLE to RECEIVING within one frame and no further signals are accepted until `debrief_completed` is emitted.

- **AC-02**: GIVEN `night_completed` is received for night 1–6, WHEN Evidence Submission processes the debrief, THEN it queries Photography (Step 3), updates boss state (Step 4), selects dialogue (Step 5), computes pay (Step 6), assembles DebriefData (Step 7), and calls `show_debrief()` (Step 8) — no step is skipped.

- **AC-03**: GIVEN a debrief is computed for any night 1–6 with at least one photo submitted, WHEN DebriefData is assembled, THEN `dialogue_lines` has 2–4 entries, `grade` is one of "A"/"B"/"C"/"D"/"F", `pay_amount` matches the formula output, `directive` matches the night's fixed directive, and `current_night` equals `n`.

- **AC-04**: GIVEN Evidence Submission is in DISPLAYING state, WHEN the player presses Continue after T_dwell, THEN `debrief_completed` is emitted and state returns to IDLE.

### Pay Calculation (BLOCKING)

- **AC-05**: GIVEN night 1 or 2 and `night_grade = A`, WHEN pay is computed, THEN `pay_amount = floor(200 × 1.25) = 250`.

- **AC-06**: GIVEN night 3 or 4 and `night_grade = B`, WHEN pay is computed, THEN `pay_amount = floor(350 × 1.10) = 385`.

- **AC-07**: GIVEN night 5 or 6 and `night_grade = A`, WHEN pay is computed, THEN `pay_amount = floor(600 × 1.25) = 750`.

- **AC-08**: GIVEN night 3 or 4 and `night_grade = A`, WHEN pay is computed, THEN `pay_amount = floor(350 × 1.25) = floor(437.5) = 437` (floor, not round).

- **AC-09**: GIVEN `photos_submitted == 0` for any night, WHEN pay is computed, THEN `pay_amount = 0` regardless of the formula.

### Boss Anger (BLOCKING)

- **AC-10**: GIVEN `boss_anger_prev = 3`, night = 2, `night_grade = A`, WHEN anger updates, THEN `anger_delta = -2 + 0 = -2`, `boss_anger_new = clamp(1, 0, 10) = 1`.

- **AC-11**: GIVEN `boss_anger_prev = 4`, night = 4, `night_grade = F` with photos submitted, WHEN anger updates, THEN `anger_delta = +3 + 1 = +4`, `boss_anger_new = clamp(8, 0, 10) = 8`.

- **AC-12**: GIVEN `boss_anger_prev = 9`, night = 5, `night_grade = F`, WHEN anger updates, THEN `anger_delta = +3 + 2 = +5`, `boss_anger_new = clamp(14, 0, 10) = 10` (clamped).

- **AC-13**: GIVEN `boss_anger_prev = 1`, night = 1, `night_grade = A`, WHEN anger updates, THEN `boss_anger_new = clamp(-1, 0, 10) = 0` (floored).

- **AC-14**: GIVEN `boss_anger_new` is in range 0–2, WHEN dialogue is selected, THEN the CALM tone pool is used and a warm greeting (Opening line) is included.

- **AC-15**: GIVEN `boss_anger_new` is in range 6–8, WHEN dialogue is selected, THEN the THREATENING tone pool is used and no Opening line is included.

- **AC-16**: GIVEN `boss_anger_new` is derived from the update formula, WHEN dialogue tone is selected, THEN the tone reflects `boss_anger_new` (post-update), not `boss_anger_prev`.

### Zero-Photos Behavior (BLOCKING)

- **AC-17**: GIVEN `photos_submitted == 0`, WHEN the debrief computes, THEN `night_grade` is forced to F and `night_evidence_score` is set to 0.0.

- **AC-18**: GIVEN `photos_submitted == 0`, WHEN the thumbnail strip would render, THEN no strip is shown — the space below dialogue is empty.

### Three-Consecutive Game Over (BLOCKING)

- **AC-19**: GIVEN the player has submitted zero photos for two consecutive nights (counter = 2), WHEN the third debrief completes with zero photos and Night Progression increments the counter to 3, THEN `boss_transformation_triggered` is emitted.

- **AC-20**: GIVEN the player has submitted zero photos for two consecutive nights (counter = 2), WHEN the current debrief completes with at least one photo, THEN Night Progression resets the counter to 0 and no transformation occurs.

- **AC-21**: GIVEN `boss_anger = 10` but the player has submitted photos every night, WHEN the debrief completes, THEN `boss_transformation_triggered` is NOT emitted — transformation is triggered by the no-photo counter, not anger level.

### Night 7 Win Debrief (BLOCKING)

- **AC-22**: GIVEN `night_completed(n=7)` and `_night_7_escaped` flag is set, WHEN the debrief flow executes, THEN Steps 3–6 are skipped entirely.

- **AC-23**: GIVEN the Night 7 win debrief, WHEN DebriefData is assembled, THEN `grade = "—"`, `pay_amount = 0`, and `dialogue_lines` contains exactly 2 pre-authored lines.

- **AC-24**: GIVEN the Night 7 win debrief DISPLAYING, WHEN the player presses Continue, THEN `debrief_completed` is emitted and Night Progression handles `game_won`.

### Dwell Time (BLOCKING)

- **AC-25**: GIVEN the Boss Debrief register is displayed and T_dwell has not elapsed, WHEN the player attempts to press Continue, THEN the input is ignored and `debrief_continue_pressed` is NOT emitted.

- **AC-26**: GIVEN T_dwell has elapsed (minimum 1.7s, maximum 3.7s), WHEN the player presses Continue, THEN `debrief_continue_pressed` is emitted on the next valid input.

### Photo Thumbnail Strip (ADVISORY)

- **AC-27**: GIVEN at least one photo was submitted, WHEN the pay display appears after the grade stamp, THEN each photo appears as a thumbnail with its individual grade letter stamped on it.

- **AC-28**: GIVEN more than 4 photos were submitted, WHEN the strip renders, THEN only 4 are visible at once and the strip is scrollable.

### Dialogue Authoring (ADVISORY)

- **AC-29**: GIVEN any authored dialogue line for the boss, WHEN read in the context of "helpful employer" (first playthrough) AND "sinister manipulator" (second playthrough), THEN both interpretations must be plausible and grammatically natural. Lines that only work one way fail the Pillar 3 dual-read test.

- **AC-30**: GIVEN any night 1–6, WHEN the directive is displayed, THEN it matches the fixed directive text for that night number regardless of grade or tone state.

### Performance (BLOCKING)

- **AC-31**: GIVEN the debrief flow from RECEIVING to DISPLAYING, WHEN the system processes Steps 1–8, THEN total computation time does not exceed 1 frame (16.6ms at 60fps). RECEIVING, COMPUTING, and EMITTING are single-frame transient states.

## Open Questions

1. **Cumulative pay display**: Should the between-nights screen (owned by Main Menu/Game Flow) show cumulative earnings? This is a UX decision — cumulative pay makes the "golden handcuffs" bait more visible, but it's also a number the player might optimize around rather than feeling.
   - **Owner**: Main Menu / Game Flow GDD
   - **Target**: When that system is designed

2. **Boss visual presence**: Should the boss have a portrait, silhouette, or icon on the debrief screen? The current design is text-only — the boss's "voice" exists in the player's imagination, which personalizes the betrayal. A visual presence would anchor the character but might reduce the uncanny effect.
   - **Owner**: Art Director / UX design phase
   - **Target**: UX spec for boss-debrief screen

3. **Night 7 boss anger influence**: Should `boss_anger` at the time of Night 7 affect the boss's behavior during the FINALE escape? A FURIOUS boss might move faster or be more aggressive. This would create a cross-system consequence for debrief performance.
   - **Owner**: Night 7 Finale GDD
   - **Target**: When that system is designed

4. **New Game Plus dialogue**: If NG+ is implemented, should the boss's dialogue change to acknowledge the player's knowledge? Second-playthrough awareness could transform the debrief from "lie" to "mutual awareness" — the boss knows you know.
   - **Owner**: Extended scope / post-launch
   - **Target**: After Full Vision milestone

5. **Photo Gallery integration**: Should the player be able to select which photos to submit (via Photo Gallery) before the boss grades them? The current design grades ALL photos from the night. A selection mechanic adds strategy (submit only your best) but also adds a UI step and system dependency.
   - **Owner**: Photo Gallery / Inventory GDD
   - **Target**: When that system is designed (Vertical Slice tier)

6. **Counter exploitation**: A player can avoid the 3-night game-over by submitting one deliberately bad photo per night. The anger system handles this (anger will spike to FURIOUS from F-grades), but the transformation trigger never fires. Is this acceptable, or should a `photos_above_threshold` check replace `photos_submitted > 0`?
   - **Owner**: Playtesting
   - **Target**: After MVP playtest
