# Night Progression

> **Status**: Designed
> **Author**: Nate Aune + agents
> **Last Updated**: 2026-04-11
> **Implements Pillar**: Pillar 4 ("One More Night") — each night is a distinct tier of horror; Pillar 1 ("Something's Wrong Here") — tier-driven wrongness escalation

## Overview

Night Progression is the clock and escalation engine for Show & Tell. It owns the per-night timer, horror tier assignment, anomaly pool selection, and the configuration calls that tell every other system what night it is and how wrong the world should feel. At the start of each night, Night Progression calls `RoomManager.configure_for_night(n)` (setting room access, horror tier, and spawn slot counts), `AudioManager.configure_audio_for_night(n)` (swapping ambient variants and reverb parameters), and will call equivalent configuration methods on Anomaly Placement Engine and Monster AI when those systems are designed. It manages a countdown timer per night (Night 1 = 600s, decreasing by 30s per night, Night 7 = 420s) and emits `night_timer_expired` when time runs out. It tracks the player's progression state across deaths (restarting the current night with photos lost but story progress kept) and across sessions (via a provisional contract with Save/Persistence). Night 7 is a special case: the timer still runs, but the boss reveal cutscene and escape sequence are triggered through `night_7_finale_start` rather than normal evidence submission. The player experiences Night Progression as the feeling that each return to the preschool is worse than the last — shorter nights, more anomalies, darker rooms, hostile audio — without ever seeing a "Night Progression" UI element. The system is the invisible ratchet that makes Pillar 4 ("One More Night") work.

## Player Fantasy

**"The Trap That Teaches You Its Shape."** The player should feel the preschool learning them back. Night 1, you walk the halls with cautious curiosity — the building is strange but manageable. By Night 4, you've memorized the layout, you know which rooms have anomalies, you've developed a route. And that's when the system punishes your confidence: the timer is shorter, the rooms are darker, the sounds are wrong, and the monsters are in the corridor you relied on. Night Progression earns its horror not by surprising the player with new spaces, but by corrupting the spaces they've mastered. The trap is that competence makes you go deeper, and going deeper makes competence insufficient.

The pressure inversion is the key design insight: nights get shorter as danger increases. Night 1 gives you 10 minutes in a safe preschool. Night 7 gives you 7 minutes in a hostile one. The player who needs MORE time gets LESS. This is not difficulty scaling — it's a ratchet. Each night tightens it. The boss's increasing pay is the bait that keeps the player clicking "Next Night," making them complicit in their own escalating danger. By Night 6, the player isn't surviving for the story. They're surviving because they chose to come back, and that choice feels increasingly indefensible.

This is a direct fantasy — the player feels the escalation in their body. The timer pressure, the darker rooms, the new sounds, the monsters where there were none. They don't think about "Night Progression" as a system. They think "last night wasn't this bad" and "I don't think I should go back in there" and then they go back in anyway.

*Serves Pillar 4: "One More Night" — this IS the pillar's delivery system. Each night is a distinct tier of horror because Night Progression configures every other system to make it so. Serves Pillar 1: "Something's Wrong Here" — the wrongness escalates because the tier drives Room lighting, Audio ambient corruption, and Anomaly density upward. Serves Pillar 3: "Trust No One" — "The Trap" retroactively reads as the boss's employment arrangement after the Night 7 reveal.*

## Detailed Design

### Core Rules

#### Night Lifecycle

A night has five phases:

**1. LOADING** (pre-night setup, not player-visible)
- Read current night number `n` from Save/Persistence (provisional).
- Call `RoomManager.configure_for_night(n)` — sets horror_tier, access_state, lights_on, active_spawn_slots.
- If `n == 7`: call `RoomManager.unlock_room(&"principals_office")` after `configure_for_night(7)`.
- Call `AudioManager.configure_audio_for_night(n)` — sets ambient variants, reverb, shutter variant, breathing threshold.
- Call `AnomalyPlacementEngine.configure_for_night(n)` (reserved — not yet designed).
- Call `MonsterAI.configure_for_night(n)` (reserved — not yet designed).
- Set timer: `night_duration = BASE_DURATION - (n - 1) * DURATION_DECREMENT`.
- Emit `night_loading_started(n)`.
- Transition to INTRO.

**2. INTRO** (Night 7 only; Nights 1-6: zero-length, immediate transition)
- Nights 1-6: zero duration. Transition to ACTIVE immediately.
- Night 7: emit `night_7_cutscene_start`. Wait for `night_7_cutscene_complete` from Cutscene System. If signal not received within `INTRO_MAX_DURATION` (30s), skip to ACTIVE (MVP safety timeout).
- Player has no control during INTRO.

**3. ACTIVE** (player is in the preschool, clock is running)
- Timer counts down from `night_duration` to 0.
- Emit `night_timer_tick(seconds_remaining)` once per second.
- Night ends via one of four exit triggers:
  - **Manual exit:** Player reaches exit trigger in Entry Hall → DEBRIEF.
  - **Timer expiry:** Timer reaches 0 → GRACE.
  - **Player death:** `player_died` received → DEAD.
  - **Night 7 finale:** `night_7_finale_start` received AND current night == 7 → FINALE.
- Night 7 exception: exit trigger in Entry Hall is disabled during ACTIVE.

**4. GRACE** (timer expired, player has `TIMER_GRACE_SECONDS` to reach exit)
- Duration: `TIMER_GRACE_SECONDS` (default 30s).
- Emit `night_grace_started(grace_seconds)` and `night_timer_expired`.
- HUD transitions timer to pulsing "LEAVE NOW" indicator (owned by HUD/UI).
- Player reaches exit → DEBRIEF (photos submitted normally).
- Grace expires without exit → forced death. Photos lost. Night restarts.
- Player dies during grace → normal DEAD behavior.

**5. DEAD** (player killed mid-night)
- Emit `player_night_restarted(n, photos_captured)`.
- Discard all photos captured this run.
- Story progress flags preserved. Night number does not regress.
- After `DEATH_SCREEN_DURATION` (2.0s): re-run LOADING with same `n`, transition to ACTIVE.
- Night 7 restart: INTRO does NOT replay (cutscene seen once per session).

**6. DEBRIEF** (night completed — success or grace exit)
- Emit `night_completed(n, photos_submitted, timer_expired)`.
- Evidence Submission / Boss Debrief takes over.
- On `debrief_completed` received:
  - Update `consecutive_nights_no_photos` counter.
  - If counter == 3: emit `boss_transformation_triggered` → GAME_OVER.
  - If `n == 7` and player escaped: emit `game_won` → GAME_WON.
  - Otherwise: increment `n` in Save/Persistence, emit `night_transition_started(n, n+1)`.
  - Wait for `player_confirmed_return` → LOADING for night `n+1`.

**FINALE** (Night 7 only — escape sequence)
- Entered when `night_7_finale_start` fires during Night 7 ACTIVE.
- Call `AudioManager.play_music_event(&"night_7_escape")`.
- Player must reach Entry Hall exit while boss pursues.
- Player reaches exit → emit `night_7_escaped` → DEBRIEF with `photos_submitted = 0`.
- Player dies → DEAD (restart Night 7 from ACTIVE, not FINALE).
- Timer expiry during FINALE → forced death, restart Night 7.

#### Night Configuration Table

| Night | Duration | Horror Tier | Rooms Accessible (Full) | Monsters | Anomaly Target | Timer Visible |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 600s (10:00) | 1 | Entry Hall, Main Classroom, Art Corner | 0 | 3 | Yes |
| 2 | 570s (9:30) | 1 | - Cubby Hall, Nap Room | 0 | 4 | Yes |
| 3 | 540s (9:00) | 2 | - Bathroom | 1 | 6 | Yes |
| 4 | 510s (8:30) | 2 | All except Principal's Office | 1 | 7 | Yes |
| 5 | 480s (8:00) | 3 | All except Principal's Office | 2 | 9 | Yes |
| 6 | 450s (7:30) | 3 | All except Principal's Office | 2 | 10 | Yes |
| 7 | 420s (7:00) | 3 | All rooms (Principal's Office unlocks) | 3 | 12 | No (hidden) |

**MVP scope:** Nights 1-3 only. 3 rooms (Entry Hall, Main Classroom, Art Corner). Night 3 has 1 monster.

#### Death and Restart Behavior

**Resets on death:**
- Photos captured this run (discarded)
- Player position (reset to Entry Hall spawn)
- Monster states (reset to night `n` starting config)
- Anomaly states requiring player interaction (reset per Anomaly System)
- Timer (reset to `night_duration` for night `n`)
- Vulnerability bar (reset to 0)

**Persists through death:**
- Current night number `n` (no regression)
- Story flags set before this night (dialogue seen, rooms unlocked in prior nights)
- `consecutive_nights_no_photos` (not incremented on death — only on completed nights with zero photos)
- Boss pay level and anger state

#### Consecutive Nights No-Photos Game-Over

**State variable:** `consecutive_nights_no_photos: int` (initialized to 0 at new game)

**Rules:**
- After each DEBRIEF: if `photos_submitted == 0` AND `current_night != 7`, increment counter.
- If `photos_submitted > 0`, reset counter to 0.
- If counter >= `CONSECUTIVE_NIGHTS_THRESHOLD` (default 3): emit `boss_transformation_triggered` → GAME_OVER.
- Night 7 is exempt (has its own win/lose condition).
- Counter is NOT incremented on death (death restarts the night, submission opportunity never reached).
- Counter is hidden from the player. Boss dialogue (Evidence Submission) hints at growing anger.

#### Provisional Save/Persistence Contract

**Minimum data Night Progression needs persisted:**

| Field | Type | Description |
| --- | --- | --- |
| `current_night` | int (1-7) | Night to load on next session |
| `consecutive_nights_no_photos` | int (0-3) | Boss anger counter |
| `story_flags` | Dictionary (StringName → bool) | Dialogue seen, rooms unlocked, etc. |

**Write triggers:** After `debrief_completed` (incremented night), on `boss_transformation_triggered`, on `game_won`.
**Read triggers:** Once during LOADING at new session start (not on death restart).
**Fallback:** If Save/Persistence is unavailable, default to `current_night = 1`, `consecutive_nights_no_photos = 0`.

### States and Transitions

#### Night Phase State Machine

```
enum NightPhase {
    LOADING,
    INTRO,
    ACTIVE,
    GRACE,
    DEAD,
    FINALE,
    DEBRIEF,
    GAME_OVER,
    GAME_WON
}
```

**Valid transitions:**

| From | To | Trigger |
| --- | --- | --- |
| LOADING | INTRO | Configuration calls complete |
| LOADING | ACTIVE | Configuration complete + Night != 7 (INTRO zero-length) |
| INTRO | ACTIVE | `night_7_cutscene_complete` received OR `INTRO_MAX_DURATION` timeout |
| ACTIVE | GRACE | `night_timer` reaches 0 (Nights 1-6) |
| ACTIVE | DEAD | `player_died` received |
| ACTIVE | FINALE | `night_7_finale_start` received AND current night == 7 |
| ACTIVE | DEBRIEF | `player_reached_exit` AND current night != 7 |
| ACTIVE | FINALE | Night 7 timer expires during ACTIVE (forced finale start) |
| GRACE | DEBRIEF | `player_reached_exit` within grace window |
| GRACE | DEAD | Grace window expires without exit |
| DEAD | LOADING | After `DEATH_SCREEN_DURATION` (2.0s), same night `n` |
| FINALE | DEAD | `player_died` during FINALE |
| FINALE | DEBRIEF | `player_reached_exit` during FINALE (Night 7 win) |
| FINALE | DEAD | Timer expires during FINALE |
| DEBRIEF | LOADING | `debrief_completed` + counters pass + `player_confirmed_return` |
| DEBRIEF | GAME_OVER | `debrief_completed` + `consecutive_nights_no_photos == 3` |
| DEBRIEF | GAME_WON | `debrief_completed` + night was 7 + player escaped |

No other transitions are valid. Any unexpected state change logs an error.

**Terminal states:** GAME_OVER and GAME_WON. No transitions out. Main Menu / Game Flow owns the "return to title" or "credits" flow from these states.

### Interactions with Other Systems

#### Signals Night Progression Emits

| Signal | Parameters | Consumed By | When |
| --- | --- | --- | --- |
| `night_loading_started(n)` | `n: int` | HUD/UI, Audio | LOADING phase entry |
| `night_active_started(n)` | `n: int` | Monster AI, Anomaly Placement | ACTIVE phase entry |
| `night_timer_tick(seconds_remaining)` | `seconds_remaining: float` | HUD/UI | Once per second during ACTIVE and GRACE |
| `night_timer_expired` | (none) | HUD/UI (triggers LEAVE NOW display) | Timer reaches 0 |
| `night_grace_started(grace_seconds)` | `grace_seconds: float` | HUD/UI | GRACE phase entry |
| `player_night_restarted(n, photos_captured)` | `n: int, photos_captured: int` | HUD/UI | DEAD phase entry |
| `night_completed(n, photos_submitted, timer_expired)` | `n: int, photos_submitted: int, timer_expired: bool` | Evidence Submission, Save/Persistence | DEBRIEF phase entry |
| `night_transition_started(from_night, to_night)` | `from_night: int, to_night: int` | Main Menu / Game Flow, HUD/UI | Between nights, after debrief |
| `night_7_cutscene_start` | (none) | Cutscene System | Night 7 INTRO phase entry |
| `boss_transformation_triggered` | (none) | Evidence Submission, Main Menu / Game Flow | Game-over condition (3 empty nights) |
| `night_7_escaped` | (none) | Main Menu / Game Flow, Cutscene System | Player wins Night 7 FINALE |
| `game_won` | (none) | Main Menu / Game Flow | Post-Night 7 win sequence |

#### Signals Night Progression Receives

| Signal | From System | Action Taken |
| --- | --- | --- |
| `player_died` | Player Survival | Transition to DEAD |
| `player_reached_exit` | Room/Level Management (exit trigger in Entry Hall) | Transition to DEBRIEF (or DEBRIEF via FINALE win on Night 7) |
| `debrief_completed` | Evidence Submission / Boss Debrief | Increment night, check counters, transition to LOADING or terminal |
| `player_confirmed_return` | Main Menu / Game Flow | Start LOADING for next night |
| `night_7_cutscene_complete` | Cutscene System | End INTRO, transition to ACTIVE |
| `night_7_finale_start` | Audio System | Transition ACTIVE → FINALE (Night 7 only) |

#### Configuration Calls Night Progression Makes

| Call | Target System | When | Parameters |
| --- | --- | --- | --- |
| `RoomManager.configure_for_night(n)` | Room/Level Management | LOADING | `n: int` |
| `RoomManager.unlock_room(&"principals_office")` | Room/Level Management | LOADING, Night 7 only, after configure | `room_id: StringName` |
| `AudioManager.configure_audio_for_night(n)` | Audio System | LOADING | `n: int` |
| `AudioManager.play_music_event(&"night_7_escape")` | Audio System | FINALE entry | `event_id: StringName` |
| `AnomalyPlacementEngine.configure_for_night(n)` | Anomaly Placement Engine | LOADING (reserved) | `n: int` |
| `MonsterAI.configure_for_night(n)` | Monster AI | LOADING (reserved) | `n: int` |
| `SaveManager.save_night_state(state)` | Save/Persistence | After DEBRIEF | `state: NightSaveData` |
| `SaveManager.load_night_state()` | Save/Persistence | LOADING, new session only | returns `NightSaveData` |

#### Query API Night Progression Exposes

| Method | Returns | Callers |
| --- | --- | --- |
| `get_current_night() -> int` | Night number 1-7 | Any system needing the current night |
| `get_current_horror_tier() -> int` | Horror tier 1-3 | Any system needing the current tier |
| `get_current_phase() -> NightPhase` | Current phase enum | HUD/UI, debug |
| `get_time_remaining() -> float` | Seconds remaining on timer | HUD/UI |
| `is_night_7() -> bool` | true if current night is 7 | Room Management (exit trigger disable), Anomaly System |

**Reserved calls:** `AnomalyPlacementEngine.configure_for_night(n)` and `MonsterAI.configure_for_night(n)` check if the autoload exists before calling. If absent, log warning and continue. This allows MVP builds to run without all downstream systems.

## Formulas

### Night Timer

`night_duration(n) = BASE_DURATION - (n - 1) * DURATION_DECREMENT`

**Variables:**

| Variable | Symbol | Type | Range | Description |
| --- | --- | --- | --- | --- |
| night_number | n | int | 1-7 | Current night |
| BASE_DURATION | — | int | 600 s | Night 1 duration (tuning knob) |
| DURATION_DECREMENT | — | int | 30 s | Seconds removed per subsequent night (tuning knob) |
| night_duration | — | int | 420-600 s | Output: night duration in seconds |

**Output Range:** Night 1: 600s (10:00). Night 7: 420s (7:00). Linear decrease.

**Example — Night 4:** `600 - (4-1) * 30 = 510s (8:30)`

### Horror Tier Assignment

`horror_tier(n) = TIER_MAP[n]`

Lookup table (not computed — tier boundaries are design decisions):

| Night | Horror Tier | Tier Multiplier |
| --- | --- | --- |
| 1 | 1 | 0.25 |
| 2 | 1 | 0.25 |
| 3 | 2 | 0.50 |
| 4 | 2 | 0.50 |
| 5 | 3 | 1.00 |
| 6 | 3 | 1.00 |
| 7 | 3 | 1.00 |

Night Progression passes `horror_tier(n)` to `configure_for_night(n)`. Room Management resolves the multiplier from its own table. Night Progression does not need to know the multiplier values.

### Anomaly Target Per Night

`anomaly_target(n) = ANOMALY_BASE + floor(ANOMALY_SCALE * (n - 1))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
| --- | --- | --- | --- | --- |
| night_number | n | int | 1-7 | Current night |
| ANOMALY_BASE | — | int | 3 | Anomalies on Night 1 (tuning knob) |
| ANOMALY_SCALE | — | float | 1.5 | Additional anomalies per night increment (tuning knob) |
| anomaly_target | — | int | 3-12 | Output: total anomalies for Anomaly Placement Engine to place |

**Output Range:** Night 1: 3. Night 7: 12. Clamped at total available room spawn slots.

| Night | Calculation | Target |
| --- | --- | --- |
| 1 | 3 + floor(1.5 * 0) | 3 |
| 2 | 3 + floor(1.5 * 1) | 4 |
| 3 | 3 + floor(1.5 * 2) | 6 |
| 4 | 3 + floor(1.5 * 3) | 7 |
| 5 | 3 + floor(1.5 * 4) | 9 |
| 6 | 3 + floor(1.5 * 5) | 10 |
| 7 | 3 + floor(1.5 * 6) | 12 |

**Design note:** The jump from Night 2 (4) to Night 3 (6) is +2, the largest single step. This is intentional: Night 3 is the first monster night and first Tier 2. The player should feel the preschool is more wrong, not just have one extra thing to notice.

### Monster Count Per Night

```
monster_count(n) = 0                                           if n < 3
                 = MONSTER_BASE                                if n == 3
                 = MONSTER_BASE + floor(MONSTER_SCALE * (n-3)) if n > 3
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
| --- | --- | --- | --- | --- |
| night_number | n | int | 1-7 | Current night |
| MONSTER_BASE | — | int | 1 | Monster count at Night 3 (tuning knob) |
| MONSTER_SCALE | — | float | 0.5 | Additional monsters per night beyond Night 3 (tuning knob) |
| monster_count | — | int | 0-3 | Output: active monsters this night |

| Night | Count | Notes |
| --- | --- | --- |
| 1 | 0 | Pure anomaly horror |
| 2 | 0 | Tier 1 ceiling |
| 3 | 1 | First monster. Cubby Hall. Landmark night. |
| 4 | 1 | Same count, expanded rooms |
| 5 | 2 | Second monster. Tier 3 begins. |
| 6 | 2 | Same count, maximally hostile rooms |
| 7 | 3 | Maximum. Principal's Office unlocks. |

**Design note:** The flat Night 3/4 (both 1) and Night 5/6 (both 2) is intentional. Holding the count for one night lets the player adapt before the next monster appears. Escalation is tier-paced, not night-paced.

### Consecutive Nights No-Photos Counter

```
on debrief_completed(photos_submitted):
    if photos_submitted == 0 AND current_night != 7:
        consecutive_nights_no_photos += 1
    else:
        consecutive_nights_no_photos = 0

    if consecutive_nights_no_photos >= CONSECUTIVE_NIGHTS_THRESHOLD:
        emit boss_transformation_triggered
```

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| CONSECUTIVE_NIGHTS_THRESHOLD | int | 3 | Nights with zero photos before game-over (tuning knob, range 2-4) |
| consecutive_nights_no_photos | int | 0 at new game | Persisted via Save/Persistence |

## Edge Cases

- **If the player quits mid-night:** No mid-night save. On next launch, Save/Persistence returns the player to the start of current night `n`. Photos lost. Night number does not regress.

- **If timer expires exactly as the player reaches the exit (same frame):** Prioritize exit. No death. Transition to DEBRIEF. The grace period begins at timer zero — `player_reached_exit` at `timer == 0` is within the grace window.

- **If the player dies during the grace period:** Normal DEAD behavior. Photos lost. Night restarts. Grace period death is the failure state of the grace period, not a special case.

- **If the player dies on Night 7 during FINALE:** Restart Night 7 from ACTIVE (not FINALE). INTRO does NOT replay — the boss reveal cutscene is seen once per session. Rationale: replaying the cutscene on every death would be punishing.

- **If \****`night_7_finale_start`**\*\* fires before the player has found any anomalies:** Normal FINALE behavior. The finale does not gate on photo count. Night 7 photos are always zero.

- **If the Night 7 timer expires during ACTIVE before \****`night_7_finale_start`**\*\*:** Force `night_7_finale_start` immediately. Do not trigger death. The boss "catches up" — the timer is a pressure tool on Night 7, not a hard fail.

- **If \****`consecutive_nights_no_photos`**\*\* reaches 3 but the current night is 7:** Night 7 is exempt. The counter check has an explicit `current_night != 7` guard. The game-over trigger cannot fire on or after Night 7.

- **If the player submits zero photos during the grace period exit:** The counter increments. Grace period submission of zero photos counts as a no-submit night. Players cannot game the counter by rushing to the exit empty-handed.

- **If Save/Persistence is unavailable on LOADING (corrupt save, first launch):** Default to `current_night = 1`, `consecutive_nights_no_photos = 0`. Log error. Do not crash.

- **If reserved configuration calls fail (Anomaly Placement, Monster AI not yet implemented):** Check if each system's autoload exists before calling. If absent, log warning and continue. MVP builds run Night Progression without all downstream systems.

- **If Night 7 Cutscene System is absent (MVP builds):** INTRO phase times out after `INTRO_MAX_DURATION` (30s) and transitions to ACTIVE. Night 7 is partially testable without the Cutscene System.

- **If the player reaches the exit trigger on Night 7 during ACTIVE (before finale fires):** The exit trigger is disabled for Night 7 during ACTIVE. If the signal fires despite this: log error, ignore.

- **If \****`debrief_completed`**\*\* fires twice in one DEBRIEF phase:** First signal is processed. All subsequent signals are ignored (guard with phase check).

- **If \****`anomaly_target(n)`**\*\* exceeds total available room spawn slots:** Clamp at `min(anomaly_target(n), total_available_slots)`. The Anomaly Placement Engine enforces per-room slot ceilings independently — Night Progression provides the global target, not the per-room distribution.

## Dependencies

| System | Direction | Hard/Soft | Interface |
| --- | --- | --- | --- |
| Room/Level Management | Night Prog → Room Mgmt | Hard | `configure_for_night(n)`, `unlock_room(room_id)` — Night Progression drives all room state transitions per night. |
| Audio System | Night Prog → Audio | Hard | `configure_audio_for_night(n)` — sets ambient variants, reverb, shutter. `play_music_event(&"night_7_escape")` — FINALE entry. `night_7_finale_start` signal received from Audio → triggers FINALE. |
| Save/Persistence | Night Prog ↔ Save (provisional) | Soft | `save_night_state(state)`, `load_night_state()` — persists night number, no-photos counter, story flags. Degrades gracefully if absent (defaults to Night 1). |
| Anomaly Placement Engine | Night Prog → APE | Soft (reserved) | `configure_for_night(n)` — provides night number and anomaly target. Not yet designed. |
| Monster AI | Night Prog → Monster AI | Soft (reserved) | `configure_for_night(n)` — provides night number and monster count. Not yet designed. |
| Player Survival | Player Survival → Night Prog | Soft | `player_died` signal — triggers DEAD phase. |
| Evidence Submission / Boss Debrief | Bidirectional | Soft | Night Prog emits `night_completed(n, photos, timer_expired)`. Evidence Submission emits `debrief_completed` back. |
| HUD/UI System | Night Prog → HUD | Soft | `night_timer_tick`, `night_timer_expired`, `night_grace_started`, `player_night_restarted` — drives timer display and death feedback. |
| Main Menu / Game Flow | Bidirectional | Soft | Night Prog emits `night_transition_started`, `boss_transformation_triggered`, `game_won`. Main Menu emits `player_confirmed_return`. |
| Cutscene System | Bidirectional | Soft | Night Prog emits `night_7_cutscene_start`. Cutscene emits `night_7_cutscene_complete`. Night 7 only. |
| First-Person Controller | FPC → Night Prog (implicit) | Soft | `player_reached_exit` — player reaching the Entry Hall exit trigger. FPC does not call Night Progression directly; the exit trigger is a Room/Level Management signal. |

**Night Progression is a hub system.** It has 2 hard dependencies (Room Management, Audio) and provides configuration to 5+ downstream systems. It is the only system that writes to both Room Management and Audio System simultaneously — it is the orchestrator of per-night world state.

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Impact |
| --- | --- | --- | --- |
| `BASE_DURATION` | 600 s | 480-720 s | Night 1 length. Higher = more exploration. Lower = pressure from the start. |
| `DURATION_DECREMENT` | 30 s | 15-45 s | Seconds removed per night. Higher = steeper pressure ramp. At 45s, Night 7 = 330s (5:30). At 15s, Night 7 = 510s (8:30). |
| `TIMER_GRACE_SECONDS` | 30 s | 15-60 s | Time after timer expiry before forced death. Lower = more punishing. Higher = more forgiving. |
| `DEATH_SCREEN_DURATION` | 2.0 s | 1.0-4.0 s | How long death screen shows before restart. Longer = more weight to death. Target: player back in control within 3s total. |
| `CONSECUTIVE_NIGHTS_THRESHOLD` | 3 | 2-4 | Nights with zero photos before boss game-over. At 2, pressure is intense. At 4, it's almost ignorable. |
| `INTRO_MAX_DURATION` | 30 s | 10-60 s | Max time Night 7 INTRO waits for cutscene signal before skipping. Safety timeout for MVP builds. |
| `TIER_MAP` | [1,1,2,2,3,3,3] | Fixed | Per-night horror tier lookup. Changing tier boundaries reshapes the entire difficulty curve. |
| `ANOMALY_BASE` | 3 | 2-5 | Anomalies on Night 1. Below 2, rooms feel empty. Above 5, Night 1 feels too busy for Pillar 1's restraint. |
| `ANOMALY_SCALE` | 1.5 | 1.0-2.5 | Anomaly growth per night. At 1.0, Night 7 = 9. At 2.5, Night 7 = 18 (likely exceeds spawn slots). |
| `MONSTER_BASE` | 1 | 1-2 | Monsters on Night 3. At 2, first monster night is immediately overwhelming. |
| `MONSTER_SCALE` | 0.5 | 0.25-1.0 | Monster growth per night beyond Night 3. At 1.0, Night 7 = 5 monsters (too many for 7 rooms). |

**Knobs owned by other systems (referenced here, do not duplicate):**
- `horror_tier_1/2/3_multiplier` (0.25/0.50/1.00) — owned by Room/Level Management GDD
- `player_walk_speed` (2.0 m/s) — owned by FPC GDD
- Boss pay values — will be owned by Evidence Submission GDD

## Visual/Audio Requirements

Night Progression has no direct visual or audio output. It is a pure state machine and configuration orchestrator. All visual effects (lighting tier shifts, room access changes) are owned by Room/Level Management. All audio effects (ambient tier swaps, reverb changes) are owned by the Audio System. Night Progression tells those systems *what* to configure via `configure_for_night(n)` — it does not execute the visual or audio changes itself.

**Night-start transition feel:** When `configure_for_night(n)` fires, the visual shift should not be instantaneous. The Room/Level Management GDD specifies a 3-5 second ambient lerp for lighting. The Audio System GDD specifies a cross-fade for ambient swaps. Night Progression's responsibility is to call both systems; the systems own their own transition timing.

## UI Requirements

Night Progression drives several UI elements but does not own their visual design:

- **Timer display (MM:SS):** Driven by `night_timer_tick(seconds_remaining)`. Visual design owned by HUD/UI GDD. Hidden on Night 7 via timer hidden flag.
- **"LEAVE NOW" indicator:** Triggered by `night_grace_started`. Pulsing red, replaces timer display. Visual design owned by HUD/UI GDD.
- **Death screen:** Triggered by `player_night_restarted(n, photos_captured)`. Shows photos lost count. Duration = `DEATH_SCREEN_DURATION`. Visual design owned by HUD/UI GDD.
- **Night transition screen:** Triggered by `night_transition_started(from, to)`. Between-nights flow (boss pay display, "Return?" prompt). Visual design and interaction owned by Main Menu / Game Flow GDD.
- **Night number display:** `get_current_night()` available for any UI element that needs it. Display location/format owned by HUD/UI GDD.

> **UX Flag — Night Progression**: This system has UI requirements. Run `/ux-design` to create UX specs for the timer HUD element, death screen, and between-nights transition screen before writing epics.

## Acceptance Criteria

- **AC-NP-01:** **GIVEN** `BASE_DURATION = 600` and `DURATION_DECREMENT = 30`, **WHEN** `night_duration(n)` is evaluated for n=1-7, **THEN** outputs are 600, 570, 540, 510, 480, 450, 420 respectively.

- **AC-NP-02:** **GIVEN** current night is 7, **WHEN** ACTIVE phase begins, **THEN** `get_time_remaining()` returns a valid float but the timer hidden flag is set (HUD does not display countdown).

- **AC-NP-03:** **GIVEN** `ANOMALY_BASE = 3` and `ANOMALY_SCALE = 1.5`, **WHEN** `anomaly_target(n)` is evaluated for n=1-7, **THEN** outputs are 3, 4, 6, 7, 9, 10, 12.

- **AC-NP-04:** **GIVEN** `anomaly_target(n)` exceeds total available spawn slots, **WHEN** Night Progression passes the target to Anomaly Placement, **THEN** the value is clamped to `min(anomaly_target(n), total_available_slots)`.

- **AC-NP-05:** **GIVEN** `MONSTER_BASE = 1` and `MONSTER_SCALE = 0.5`, **WHEN** `monster_count(n)` is evaluated for n=1-7, **THEN** outputs are 0, 0, 1, 1, 2, 2, 3.

- **AC-NP-06:** **GIVEN** current night is 7 and LOADING completes, **WHEN** phase transitions, **THEN** it enters INTRO (not ACTIVE) and `night_7_cutscene_start` is emitted.

- **AC-NP-07:** **GIVEN** current night is 1-6 and LOADING completes, **WHEN** phase transitions, **THEN** it enters ACTIVE directly (INTRO is zero-length) and no `night_7_cutscene_start` is emitted.

- **AC-NP-08:** **GIVEN** Night 7 INTRO has started, **WHEN** 30s elapses without `night_7_cutscene_complete`, **THEN** phase transitions to ACTIVE (safety timeout).

- **AC-NP-09:** **GIVEN** Nights 1-6 in ACTIVE, **WHEN** timer reaches 0, **THEN** phase transitions to GRACE, `night_timer_expired` emits, and `night_grace_started(30)` emits.

- **AC-NP-10:** **GIVEN** phase is GRACE, **WHEN** `player_reached_exit` is received before grace expires, **THEN** phase transitions to DEBRIEF (not DEAD).

- **AC-NP-11:** **GIVEN** phase is GRACE, **WHEN** `TIMER_GRACE_SECONDS` elapses without exit, **THEN** phase transitions to DEAD.

- **AC-NP-12:** **GIVEN** Night 7 ACTIVE, **WHEN** timer reaches 0, **THEN** phase transitions to FINALE (not GRACE, not DEAD). The boss "catches up."

- **AC-NP-13:** **GIVEN** Night 7 ACTIVE, **WHEN** `player_reached_exit` is received, **THEN** signal is ignored and phase does not change (exit trigger disabled).

- **AC-NP-14:** **GIVEN** Night 7 FINALE, **WHEN** `player_died` is received, **THEN** phase transitions to DEAD and restart enters ACTIVE (INTRO does not replay).

- **AC-NP-15:** **GIVEN** any phase, **WHEN** an invalid transition trigger arrives, **THEN** phase does not change and an error is logged.

- **AC-NP-16:** **GIVEN** LOADING begins for night `n`, **WHEN** configuration executes, **THEN** `RoomManager.configure_for_night(n)` and `AudioManager.configure_audio_for_night(n)` are both called exactly once before ACTIVE begins.

- **AC-NP-17:** **GIVEN** LOADING for Night 7, **WHEN** `configure_for_night(7)` completes, **THEN** `unlock_room(&"principals_office")` is called after configure (order enforced).

- **AC-NP-18:** **GIVEN** `AnomalyPlacementEngine` or `MonsterAI` autoloads are absent, **WHEN** LOADING runs, **THEN** Night Progression logs a warning and completes without crashing.

- **AC-NP-19:** **GIVEN** death occurs mid-night, **WHEN** DEAD resolves and LOADING restarts, **THEN** photos, position, monsters, timer, and vulnerability bar are reset. Night number, story flags, and `consecutive_nights_no_photos` are unchanged.

- **AC-NP-20:** **GIVEN** phase transitions to DEAD, **WHEN** `DEATH_SCREEN_DURATION` (2.0s) elapses, **THEN** LOADING begins for the same night `n` (not n+1).

- **AC-NP-21:** **GIVEN** `consecutive_nights_no_photos` is below threshold and night is not 7, **WHEN** `debrief_completed` fires with `photos_submitted == 0`, **THEN** counter increments by 1.

- **AC-NP-22:** **GIVEN** `consecutive_nights_no_photos` is at any value, **WHEN** `debrief_completed` fires with `photos_submitted > 0`, **THEN** counter resets to 0.

- **AC-NP-23:** **GIVEN** counter is 2, **WHEN** `debrief_completed` fires with `photos_submitted == 0` and night is not 7, **THEN** `boss_transformation_triggered` emits and phase transitions to GAME_OVER.

- **AC-NP-24:** **GIVEN** current night is 7, **WHEN** `debrief_completed` fires with `photos_submitted == 0`, **THEN** counter is NOT incremented (Night 7 exempt).

- **AC-NP-25:** **GIVEN** player dies mid-night before DEBRIEF, **WHEN** DEAD resolves, **THEN** `consecutive_nights_no_photos` is unchanged.

- **AC-NP-26:** **GIVEN** FINALE → DEBRIEF transition on Night 7, **WHEN** `night_completed` is emitted, **THEN** `photos_submitted` is forced to 0 by Night Progression before the signal fires.

## Open Questions

1. **Should the between-nights screen show cumulative pay or just the current night's pay?** Cumulative reinforces the "trap" fantasy (you've earned $830, are you really going to walk away?). Single-night is cleaner. Resolve in Evidence Submission GDD.

2. **Should the grace period timer be visible?** The player knows time is up ("LEAVE NOW"), but should they see a countdown of the 30s grace? Visible = more game-like, less dread. Hidden = more panic, less fair. Resolve in HUD/UI GDD.

3. **Should Night 7 have a different starting position than Nights 1-6?** The boss reveal could justify starting the player deeper in the preschool (e.g., Principal's Office) rather than the Entry Hall. Affects Room/Level Management spawn point. Resolve during vertical slice.

4. **Should the boss's anger be visible in the debrief dialogue before the game-over triggers?** The GDD specifies the counter is hidden, but the boss's dialogue should escalate. Degree of escalation and specific dialogue lines are owned by Evidence Submission GDD.

5. **Should there be a "Night Complete" screen showing stats (photos taken, time remaining, anomalies found)?** Adds a moment of reflection between the night and the boss debrief. Could slow pacing. Resolve in HUD/UI or Evidence Submission GDD.

6. **What happens if the player completes all 7 nights but the consecutive no-photos counter was at 2 entering Night 7?** Night 7 is exempt, so the counter stays at 2 and game_won fires. The counter never reaches 3. This is correct by design but worth documenting for QA.
