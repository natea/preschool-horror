# HUD/UI System

> **Status**: Designed (pending review)
> **Author**: Nate Aune + agents
> **Last Updated**: 2026-04-11
> **Implements Pillar**: Pillar 2 ("Prove It") — viewfinder is the core verb's UI; Pillar 1 ("Something's Wrong Here") — Color Debt on HUD; Pillar 3 ("Trust No One") — boss debrief deception

## Overview

The HUD/UI System is the display layer for Show & Tell. It owns three distinct visual registers — the Preschool HUD (screen-space), the Camera Viewfinder (diegetic, owned by Photography System), and the Boss Debrief (screen-space, theatrical) — and provides the rendering surface, layout rules, and state-driven visibility logic that each register uses. The system does not generate data: it consumes signals and properties from First-Person Controller (`current_state`, `camera_raised`, `interact_ray_hit`), Night Progression (`night_timer_tick`, `current_night`), and will consume from Photography, Player Survival, and Evidence Submission as those systems are designed. For each signal, the HUD maps data to a visual element following the art bible's three-register shape grammar (Section 3.4) and typography direction (Section 7.2): rounded construction-paper forms for the Preschool HUD, hard right-angle monospace for the Viewfinder, and warm serif authority for the Boss Debrief. The system enforces the art bible's explicit exclusion of health bars, stamina bars, and threat proximity meters — danger is read through world cues, not UI widgets. Color Debt applies to the Preschool HUD register: Night 1 elements use full Crayola saturation; by Night 6 they are desaturated and cooled, matching the environment's visual decay. The HUD/UI System is an MVP-tier Core-layer system depended on by 5 downstream systems (Photography, Player Survival, Evidence Submission, Photo Gallery, Main Menu).

## Player Fantasy

**"You Already Knew Something Was Wrong."** The player should feel like the one person in the room who sees the pattern — not because they have special powers, but because they are paying attention while the world around them tries to normalize its own corruption. The HUD is the record of that observation. Night 1, the construction-paper timer and film counter are bright, saturated, trustworthy — preschool colors for a preschool space. By Night 5, those same elements have cooled and faded, and the player who notices thinks: *that wasn't always like that*. Color Debt on the HUD is not a visual effect. It is a player skill. Learning to read the decay is learning to distrust everything.

The three UI registers create three distinct emotional states that form a unified arc:

- **Preschool HUD** — the unreliable narrator made visible. The player trusts the timer and film count to tell them objective facts — and the numbers remain accurate. But the shapes, the colors, the weight of the construction-paper forms... those are decaying. Trusting the HUD on Night 6 feels wrong. Not because the data has changed, but because the container has. The preschool is infecting its own interface.

- **Camera Viewfinder** — the truth instrument. When the viewfinder goes up, hard right angles replace soft curves. Monospace replaces crayon print. Warm cream frame lines hold their color regardless of night. The camera's rules never change — and in a space where all rules have collapsed, raising the camera is the one act where the player brings their own geometry into the preschool's world. The viewfinder doesn't make the player safe. It makes the player *precise*.

- **Boss Debrief** — the first lie the player learns to read. Warm amber text, serif authority font, official grade stamps. On first playthrough, this register feels like safety — the most comfortable the player is all game. On second playthrough, the player notices: the amber is darkening each night, the "Rejected" stamp is Arterial Red, the headers use the monster palette. The boss's UI has its own corruption arc, and it leads somewhere different than the preschool's. Pillar 3 lives here.

The player never thinks about "the HUD/UI System." They think: *the timer looks different tonight*. They think: *the camera feels like the only thing I can trust*. They think: *why does the boss's screen feel warmer than the preschool?* The HUD's job is to teach the player to read visual language — and then use that literacy against them.

*Serves Pillar 1: "Something's Wrong Here" — Color Debt on the HUD extends environmental dread to the interface itself. Serves Pillar 2: "Prove It" — the viewfinder's fixed visual rules anchor the investigator's identity. Serves Pillar 3: "Trust No One" — the boss debrief UI is the game's most carefully constructed lie.*

## Detailed Design

### Core Rules

#### Register Definitions

The HUD/UI System manages three independent visual registers. Each register has its own coordinate space, ownership contract, and lifecycle. They never share fonts, colors, or animation timing.

| Register | Space | Owner | Visible When | Transition |
|---|---|---|---|---|
| Preschool HUD | Screen-space CanvasLayer | HUD/UI System | All states except Cutscene, Dead, Restarting | 120ms ease-out (tacked up / peeled off) |
| Camera Viewfinder | Screen-space CanvasLayer (higher z-index) | HUD/UI System renders; Photography System provides data | `camera_raised == true` only | Instant (no animation) |
| Boss Debrief | Screen-space CanvasLayer (full-screen, max z-index) | Evidence Submission triggers; HUD/UI System renders | DEBRIEF phase only | 0.5s hold-on-black, single cut |

When the Viewfinder activates, the Preschool HUD beneath it remains rendered (not hidden). The Boss Debrief covers all other registers by full-screen overlay, not by calling `hide()`.

---

#### Register 1 — Preschool HUD

##### Elements

| Element | Data Source | Visibility Condition | Layout Position |
|---|---|---|---|
| Night Timer | Night Progression `night_timer_tick(seconds_remaining)` | Active states; hidden in Dead, Restarting, Cutscene, Debrief, Night 7 | Top-center |
| Night Number | Night Progression `current_night: int` | All except Dead, Restarting, Debrief, Night 7 | Top-left |
| Film Counter | Photography System `film_remaining: int` (provisional) | All active states | Top-right |
| Interaction Prompt | First-Person Controller `interact_ray_hit` + `interact_target_label` | Only when ray hits AND player state is Normal | Bottom-center |
| Grace Indicator | Night Progression `night_grace_started` | GRACE phase only (replaces Timer) | Top-center |

**Night Timer:**
- Format: `M:SS` (e.g., `9:30`, `0:07`). No leading zero on minutes.
- Font: Fredoka One, 28px at 1080p. Color follows Color Debt.
- Construction-paper rounded-rectangle container: border-radius 12px, padding 8px×4px. Background: Color Debt color at 60% opacity. Border: 2px solid, Color Debt color at 80%.
- **Warning state (≤60s):** Container pulses 80%→100% opacity at 0.5Hz. Color overrides to Semantic Yellow `#F5C842` regardless of Color Debt.
- **Night 7:** Timer hidden entirely. Night Progression signals `timer_visible = false`.

**Night Number:**
- Format: `NIGHT [n]` (e.g., `NIGHT 3`). All caps.
- Font: Fredoka One, 22px. Color follows Color Debt.
- No container. Top-left, 16px margin from screen edge.
- Static — updates only between nights (LOADING phase).
- **Night 7:** Hidden when `night_7_cutscene_start` fires. Both timer and night number are stripped — normal rules no longer apply.

**Film Counter:**
- Format: Film-strip icon + number (e.g., `[icon] 12`). Icon: construction-paper silhouette, 20px, same color as text.
- Font: Fredoka One, 22px. Color follows Color Debt.
- Top-right, 16px margin. No container.
- **Low film warning (≤3):** Color overrides to Semantic Yellow `#F5C842`. Icon pulses at 0.5Hz.
- **Provisional contract:** Subscribes to `film_remaining_changed(new_count: int)`. Stub value: 12 until Photography System is designed. Config: `assets/data/hud_config.tres`.

**Interaction Prompt:**
- Format: `[E] [action_text]` (keyboard) or `[A] [action_text]` (gamepad, switches on last input type).
- `action_text` sourced from interactable node's `interact_target_label`. HUD renders verbatim.
- Defined labels: Door (closed) → `Open Door`; Door (open) → `Close Door`; Vent cover → `Enter Vent`; Anomaly object → `Examine`. Fallback: empty string → `Interact`.
- Font: Fredoka One, 20px. Color: Chalk White `#F2EDE4` (does NOT follow Color Debt — must always be legible).
- Bottom-center, 72px from screen bottom. Semi-transparent background patch (`#1A1A22` at 50%) for legibility.
- Appears/disappears: 120ms ease-out. Shows only when all conditions met (Normal state + ray hit).

**Grace Indicator:**
- Replaces Night Timer in top-center when `night_grace_started` fires.
- Text: `LEAVE NOW`, pulsing at 1Hz between Semantic Yellow `#F5C842` and white `#FFFFFF`.
- Font: Fredoka One, 32px (larger than timer — urgency through size).
- **No countdown displayed.** The player does not know how many grace seconds remain. Intentional information denial — the only signal is "go now."
- Deactivates when: (a) player reaches exit, or (b) grace expires and death triggers.

---

#### Register 2 — Camera Viewfinder

Appears instantly when `camera_raised == true`, disappears instantly when `false`. No transition animation.

##### Elements

| Element | Data Source | Layout Position |
|---|---|---|
| Frame Lines | Static | 4 corner brackets, inset 12px from edges |
| Crosshair | Static | Screen center |
| Zoom Indicator | Photography `zoom_level: float` (provisional) | Bottom-left inside frame |
| Flash Charge | Photography `flash_charge: float` 0.0–1.0 (provisional) | Bottom-right inside frame |
| Anomaly Lock | Photography `anomaly_locked: bool` (provisional) | Full frame overlay |
| Photo Counter | Photography `photos_taken: int`, `film_remaining: int` (provisional) | Top-right inside frame |

**Frame Lines:** 4 corner brackets, 24×24px each, 1px line weight. Hard right angles, zero border radius. Color: Warm cream `#D4C8A0`. Immune to Color Debt.

**Crosshair:** Single-pixel horizontal (16px) and vertical (16px) lines. Center intersection. Color: `#D4C8A0`. No dot, no circle. Minimal.

**Zoom Indicator:** Format `[value]x` (e.g., `1.0x`). Share Tech Mono, 14px, `#D4C8A0`. Stub: `1.0`.

**Flash Charge:** Segmented arc, 90° sweep, 8 segments. Full: all lit Amber `#C4882A`. Charging: partial lit, dark segments Dark Amber `#6A4A14`. Low (≤2 segments): lit segments pulse 0.5Hz, Semantic Yellow. Arc radius: 20px, segment width: 8px, gap: 2px.

**Anomaly Lock:** When `anomaly_locked == true`: corner brackets change from `#D4C8A0` to Unnatural White `#F0F0FF`. A 1px rectangle traces the full inner frame (4px inset from brackets). Pulse: 1.5s sine, 70%–100% opacity. Only animation in the Viewfinder. When lock breaks: snap immediately back to `#D4C8A0` (no fade). Intentional use of monster palette — the camera speaks monster language when confirming a monster.

**Photo Counter:** Format `[taken]/[remaining]` (e.g., `3/12`). Share Tech Mono, 14px, `#D4C8A0`. Stub: `0/12`.

---

#### Register 3 — Boss Debrief

Triggered by Evidence Submission calling `HUDUISystem.show_debrief(data: DebriefData)`.

**Transition in:** Fade to black (300ms) → hold black (500ms) → single cut to debrief layout (no fade-in).

##### Elements

| Element | Layout | Timing |
|---|---|---|
| Boss Dialogue | Top section, full width | Lines fade in individually, 200ms each |
| Evidence Grade | Center, hero display | Appears after all dialogue, 500ms pause |
| Pay Display | Center, below grade | 200ms after grade stamp |
| Night Directive | Bottom, below horizontal rule | 300ms after pay |
| Continue Prompt | Bottom-right | 500ms after directive |

**Boss Dialogue:** Lora, 18px. Color: Amber-gold `#D4A855`, decaying nightly (see Boss Debrief Color Decay). Background: Warm dark `#1A1410`. Headers: Lora bold 22px, Dark red `#8B2020`. Lines fade in as whole units — no typewriter.

**Evidence Grade:** Large letter (A/B/C/D/F) in circular stamp border, 80px diameter, letter 48px Lora bold. Colors: A=`#48B04A`, B=`#8DB84A`, C=`#F5C842`, D=`#E8732A`, F=`#C0181E` (Arterial Red). Single-frame cut appearance — the impact IS the animation. Circular dashed border (6px-4px dash-gap).

**Pay Display:** Format `$[amount]`. Lora, 24px, `#D4A855` (same nightly decay). No count-up animation.

**Night Directive:** Lora italic, 18px, `#D4A855`. Separated from pay by 1px horizontal rule (`#8B2020`, 60% opacity).

**Continue Prompt:** `[E] CONTINUE` / `[A] CONTINUE`. Lora 16px, `#D4A855`. Input during delay is ignored — enforces dwell time so the player reads the debrief.

**Provisional contract:**
```
DebriefData {
    dialogue_lines: Array[String]
    grade: String        # "A" / "B" / "C" / "D" / "F"
    pay_amount: int
    directive: String
    current_night: int   # for Color Debt computation
}
```

---

#### Color Debt Rules (Preschool HUD)

Color Debt desaturates and cools Preschool HUD elements across nights. Does NOT apply to Viewfinder or Boss Debrief.

| Night | HUD Text Color | Container BG | Emotional Read |
|---|---|---|---|
| 1 | `#F5C842` Crayola Yellow | `#E8392A` 20% | Bright, trusted, childlike |
| 2 | `#D4B038` (cooling) | `#D4B038` 20% | Subtly duller — designed to be indistinguishable |
| 3 | `#B8A050` (yellow-khaki) | `#8B7A40` 20% | Noticeably different from Night 1 on comparison |
| 4 | `#9A8860` (warm khaki) | `#7A6840` 20% | Original yellow is gone |
| 5 | `#8A8C7A` (cool gray-green) | `#6A7060` 20% | No warmth left |
| 6 | `#7A8890` (cold blue-gray) | `#5A6870` 20% | Fully cooled |
| 7 | Hidden | — | Timer and night number stripped |

Stored in `assets/data/hud_color_debt.tres` as 7 Color pairs. Loaded during LOADING phase. Warning state overrides take precedence; Color Debt resumes when warning clears. Interaction Prompt is exempt (always `#F2EDE4`).

**Boss Debrief Color Decay** (separate from Color Debt — applies to dialogue text only):

| Night | Dialogue Color | Decay |
|---|---|---|
| 1 | `#D4A855` (amber-gold) | Baseline |
| 2 | `#C8A04E` | -5% brightness |
| 3 | `#BC9847` | -10% |
| 4 | `#B09040` | -15% |
| 5 | `#A48839` | -20% |
| 6 | `#988032` | -25% |
| 7 | `#8A6830` (dark amber) | -35% (accelerated final step) |

Headers remain `#8B2020` all nights — they are already in the monster register.

### States and Transitions

| Player State | Preschool HUD | Viewfinder | Boss Debrief | Notes |
|---|---|---|---|---|
| **Normal** | Visible (all elements) | Hidden | Hidden | Default exploration |
| **Camera Raised** | Visible (minus interaction prompt) | Visible | Hidden | Viewfinder overlays HUD |
| **Running** | Visible (minus interaction prompt) | Hidden | Hidden | Can't raise camera while running |
| **In Vent** | Timer + Night Number only | Hidden | Hidden | Film counter hidden (can't photograph in vents) |
| **Hiding** | Timer + Night Number only | Hidden | Hidden | Minimal info while hiding |
| **Cutscene** | Hidden | Hidden | Hidden | Night 7 boss reveal |
| **Dead** | Hidden | Hidden | Hidden | Fade to black |
| **Restarting** | Hidden | Hidden | Hidden | Scene reload |
| **Debrief** | Hidden | Hidden | Visible | Full-screen boss UI |

**Transition Rules:**
- Normal → Camera Raised: Viewfinder appears instantly. Interaction prompt hides (120ms ease-out).
- Camera Raised → Normal: Viewfinder disappears instantly. Interaction prompt eligibility resumes.
- Normal → Running: Interaction prompt hides. No Viewfinder change (already hidden).
- Any → Dead: All HUD elements fade to black with the death screen (synchronized, not independent).
- Any → Debrief: Fade to black (300ms), hold (500ms), single cut to Debrief register.
- Debrief → Normal (next night): Fade to black (300ms), LOADING phase, HUD re-appears with new Color Debt values.

### Interactions with Other Systems

#### Outputs (what HUD/UI provides)

| Signal / Property | Type | To System | When |
|---|---|---|---|
| `debrief_continue_pressed` | signal | Evidence Submission, Night Progression | Player presses Continue in debrief |
| `hud_ready` | signal | Night Progression | HUD has loaded Color Debt for current night |

#### Inputs (what HUD/UI receives)

| Signal / Property | Type | From System | Effect |
|---|---|---|---|
| `current_state` | enum | First-Person Controller | Drives visibility state machine |
| `camera_raised` | bool | First-Person Controller | Show/hide Viewfinder register |
| `interact_label` | String? | First-Person Controller | Show/hide interaction prompt (null = no valid target) |
| `night_timer_tick(seconds_remaining)` | int | Night Progression | Update timer display |
| `current_night` | int | Night Progression | Load Color Debt, configure Night 7 special state |
| `night_grace_started(grace_seconds)` | int | Night Progression | Replace timer with Grace Indicator |
| `film_remaining_changed(count)` | int | Photography (provisional) | Update film counter |
| `zoom_changed(level)` | float | Photography (provisional) | Update zoom indicator |
| `flash_charge_changed(charge)` | float | Photography (provisional) | Update flash charge arc |
| `anomaly_lock_changed(is_locked)` | bool | Photography (provisional) | Toggle anomaly lock overlay |
| `photo_taken(taken, remaining)` | int, int | Photography (provisional) | Update photo counter |
| `show_debrief(data)` | DebriefData | Evidence Submission (provisional) | Show Boss Debrief register |

## Formulas

### Debrief Dwell Time

The debrief sequence blocks player input for a minimum duration so the player reads the boss's feedback before proceeding.

`T_dwell = (T_fade_per_line * N_lines) + T_pause_pre_grade + T_post_grade + T_post_pay + T_post_directive`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Fade per line | T_fade_per_line | float | 0.1–0.5 s | Duration of each dialogue line fade-in |
| Line count | N_lines | int | 1–10 | Number of boss dialogue lines this debrief |
| Pause pre-grade | T_pause_pre_grade | float | 0.2–1.0 s | Hold after final dialogue line before grade stamp |
| Post-grade delay | T_post_grade | float | 0.1–0.5 s | Grade stamp to pay display |
| Post-pay delay | T_post_pay | float | 0.1–0.5 s | Pay display to directive |
| Post-directive delay | T_post_directive | float | 0.2–1.0 s | Directive to Continue prompt appearance |

**Output Range:** 1.7s (N_lines=1) to 3.7s (N_lines=10). Typical: ~2.3s at N_lines=3.

**Example (Night 3, 4 dialogue lines):**
- T_dwell = (0.200 × 4) + 0.500 + 0.200 + 0.300 + 0.500
- T_dwell = 0.800 + 0.500 + 0.200 + 0.300 + 0.500 = **2.300s**

---

### Boss Debrief Color Decay (tuning rationale)

The boss's dialogue text color decays from amber-gold to dark amber across 7 nights. Nights 1–6 follow a linear RGB step; Night 7 is hand-authored (accelerated final decay).

```
R(n) = BASE_R - (n - 1) * STEP_R
G(n) = BASE_G - (n - 1) * STEP_G
B(n) = BASE_B - (n - 1) * STEP_B
```

For n in [1, 6]. Night 7 uses `FINAL_COLOR` directly.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Night number | n | int | 1–6 | Night index (Night 7 bypasses formula) |
| Base color | BASE_R/G/B | int | 0–255 | Night 1 baseline: `#D4A855` = (212, 168, 85) |
| Step per night | STEP_R/G/B | int | 0–40 | Per-night RGB decrement: (12, 8, 7) |
| Final color | FINAL_COLOR | Color | — | Night 7: `#8A6830` = (138, 104, 48) |

**Output Range:** R: [152, 212], G: [128, 168], B: [50, 85] for Nights 1–6. Night 7: (138, 104, 48).

**Example (Night 4):**
- R(4) = 212 - 3×12 = 176 → `0xB0`
- G(4) = 168 - 3×8 = 144 → `0x90`
- B(4) = 85 - 3×7 = 64 → `0x40`
- Result: `#B09040` ✓

**Tuning note:** To adjust decay speed, change STEP values — all 6 non-final night colors update together. Night 7 is hand-authored to create intentional acceleration. The data file (`assets/data/hud_debrief_colors.tres`) stores all 7 values; this formula is derivation rationale, not runtime logic.

---

### Named Constants

All other HUD values are named constants stored in `assets/data/hud_config.tres`. No formulas — they drive `Tween` nodes or `if` comparisons directly.

**Warning & Timing Constants:**

| Constant | Value | Unit | Description |
|----------|-------|------|-------------|
| `WARNING_THRESHOLD` | 60 | s | Timer switches to warning state at this value |
| `LOW_FILM_THRESHOLD` | 3 | count | Film counter warning trigger |
| `FILM_COUNT_STUB` | 12 | count | Stub value until Photography System provides data |

**Animation Constants:**

| Constant | Value | Unit | Description |
|----------|-------|------|-------------|
| `WARNING_PULSE_HZ` | 0.5 | Hz | Shared heartbeat for all warning pulses (timer, film, flash). Synchronized. |
| `GRACE_PULSE_HZ` | 1.0 | Hz | Grace Indicator "LEAVE NOW" pulse |
| `ANOMALY_LOCK_PULSE_PERIOD` | 1.5 | s | Anomaly Lock sine pulse in viewfinder |
| `PROMPT_TRANSITION_MS` | 120 | ms | Interaction prompt appear/disappear |
| `HUD_TRANSITION_MS` | 120 | ms | Preschool HUD element tack up / peel off |
| `DEBRIEF_FADE_MS` | 300 | ms | Fade to black for debrief transitions |
| `DEBRIEF_HOLD_MS` | 500 | ms | Hold on black before debrief cut |

**Color Constants:**

| Constant | Value | Unit | Description |
|----------|-------|------|-------------|
| `CONTAINER_BG_OPACITY` | 0.2 | fraction | Preschool HUD container background opacity |
| `PROMPT_BG_COLOR` | `#1A1A22` | hex | Interaction prompt background |
| `PROMPT_BG_OPACITY` | 0.5 | fraction | Interaction prompt background opacity |

**Warning pulse synchronization:** All elements using `WARNING_PULSE_HZ` share a single global pulse timer. When multiple warnings are active simultaneously (e.g., timer ≤60s AND film ≤3), they pulse in unison.

## Edge Cases

### State Transition Edge Cases

- **If `current_state` changes Normal → Running while `interact_ray_hit` is true:** Interaction prompt hides (120ms ease-out). Ray hit state irrelevant during Running — re-evaluates on return to Normal.
- **If `current_state` changes Normal → Camera Raised while `interact_ray_hit` is true:** Prompt begins 120ms hide. Viewfinder appears instantly. Independent, concurrent transitions.
- **If `current_state` transitions Normal → Dead while interaction prompt is mid-transition:** Cancel tween immediately. All HUD elements fade to black synchronized with death screen.
- **If two state changes arrive in a single physics frame:** Apply only the final state. HUD evaluates once per frame; intermediate states discarded.
- **If `current_state` changes to Cutscene while `camera_raised == true`:** Viewfinder disappears first (instant), then Preschool HUD hides. HUD handles defensively even though FP Controller should lower camera first.
- **If state changes to In Vent while film counter is in low-film warning:** Film counter hides per vent rules. Warning state preserved internally; resumes when counter becomes visible again. Pulse timer continues while hidden.
- **If `camera_raised` fires true while in Hiding state:** Viewfinder does not appear. Hiding suppresses Viewfinder. HUD handles defensively.

### Timer Edge Cases

- **If `seconds_remaining == 60`:** Warning state activates (inclusive boundary — fires at exactly 60).
- **If `seconds_remaining == 0`:** Timer displays `0:00`. Warning pulse continues. HUD does not self-trigger state changes — Night Progression's responsibility.
- **If `seconds_remaining` is negative:** Clamp display to `0:00`. Log warning.
- **If `current_night == 7` during LOADING:** Timer and Night Number hidden before any tick fires. `hud_ready` emitted only after hiding applied.
- **If `night_7_cutscene_start` fires before `hud_ready`:** Hide immediately. Cutscene signal takes priority over load ordering.
- **If `night_grace_started` fires while timer shows warning (≤60s):** Grace Indicator replaces timer. Warning 0.5Hz pulse canceled. Grace 1Hz pulse begins fresh. Film counter warning continues on 0.5Hz uninterrupted.
- **If `night_grace_started` fires on Night 7 (timer already hidden):** Grace Indicator appears at top-center. Night 7 suppresses timer/night number, not the slot itself.

### Warning State Conflicts

- **If timer warning and film warning are active simultaneously:** Both use Semantic Yellow `#F5C842`. Both pulse at shared 0.5Hz heartbeat — synchronized, in phase.
- **If flash charge warning (Viewfinder) is also active:** All three pulse at shared 0.5Hz. Cross-register synchronization maintained.
- **If warning condition clears mid-pulse:** Warning color removed immediately next frame. No "finish the pulse" — clean cut. Reverts to Color Debt color.
- **If warning condition activates mid-pulse:** Element joins global pulse at current position (no snap to phase-start). Keeps multi-warning sync.
- **If Grace and film warning are active simultaneously:** Grace = 1Hz (top-center), film = 0.5Hz (top-right). Different rates intentional — Grace signals higher urgency.

### Viewfinder Edge Cases

- **If `camera_raised` toggles false→true within a single frame:** Frame-end state is true. Viewfinder renders. No visual artifact (instant transitions).
- **If `anomaly_lock_changed(true)` fires while Viewfinder not visible:** Lock state stored. Next Viewfinder open renders with lock already active.
- **If `anomaly_lock_changed(true)` and `(false)` both fire in same frame:** State at frame end is false. Brackets render normal `#D4C8A0`.
- **If `flash_charge_changed` receives value outside [0.0, 1.0]:** Clamp to [0.0, 1.0]. Log warning.
- **If `zoom_changed` receives value ≤ 0.0:** Display `--x` fallback. Log warning.

### Debrief Edge Cases

- **If player presses Continue before T_dwell elapses:** Ignored. Continue Prompt not yet visible.
- **If player holds Continue across T_dwell boundary:** Does not trigger. `debrief_continue_pressed` is edge-triggered (fresh press only), not level-triggered.
- **If `show_debrief()` called while prior debrief playing:** Second call queued. First completes fully before second displays. Log warning.
- **If `dialogue_lines` is empty array:** Skip dialogue phase. T_dwell starts from T_pause_pre_grade. Valid state.
- **If `grade` not in {A, B, C, D, F}:** Display stamp with no letter, F-grade color. Log error.
- **If `pay_amount` is negative:** Display `$0`. Log warning.
- **If `current_night` out of [1, 7] in debrief data:** Clamp. Night 0 → Night 1 colors. Night 8+ → Night 7 colors. Log warning.

### Color Debt Edge Cases

- **If `current_night` is 0:** Use Night 1 colors. Log warning.
- **If `current_night` > 7:** Use Night 7 logic (hidden). Log warning.
- **If `hud_color_debt.tres` fails to load:** Default to Night 1 colors. Log error. Player not blocked.
- **If warning state active during night LOADING phase:** Warning does not carry across nights. LOADING resets transient states. Warning reactivates only if new night's timer ≤60s (not reachable — all nights begin >60s).

### Web Export Edge Cases

- **If browser tab loses focus during warning pulse:** Process pauses. Tween suspends. On return, pulse resumes at correct phase. Synchronized warnings resume together.
- **If browser tab loses focus during debrief hold-on-black:** Tween and T_dwell clock suspend. Full dwell time delivered on return.
- **If browser window resized:** CanvasLayer anchors recalculate automatically. Margin elements maintain margins. Validate at 1280×720 and 1920×1080 during QA.
- **If non-standard aspect ratio (21:9):** Margin anchors hold. Center elements stay centered. Minimum 1280px width supported; below undefined.

## Dependencies

| System | Direction | Type | Interface |
|---|---|---|---|
| First-Person Controller | Controller → HUD | **Hard** | `current_state`, `camera_raised`, `interact_ray_hit` + `interact_target_label` |
| Night Progression | Night Progression → HUD | **Hard** | `current_night`, `night_timer_tick(seconds_remaining)`, `night_grace_started(grace_seconds)`, `night_7_cutscene_start` |
| Photography System | Photography → HUD | **Soft** (provisional) | `film_remaining_changed`, `zoom_changed`, `flash_charge_changed`, `anomaly_lock_changed`, `photo_taken` |
| Player Survival | Survival → HUD | **Soft** (provisional) | No direct interface yet — vulnerability feedback is through world cues per art bible; a subtle screen-edge vignette could be an option |
| Evidence Submission | Evidence → HUD | **Soft** (provisional) | `show_debrief(DebriefData)`, `hide_debrief()` |
| Audio System | HUD → Audio | **Soft** | HUD triggers UI sound cues: shutter click, warning pulse audio, grade stamp impact, debrief transition sounds |

**Hard dependencies** — HUD cannot function without these. First-Person Controller provides the state that drives all visibility logic. Night Progression provides the timer and night data.

**Soft dependencies** — HUD works in degraded state (stub values, no debrief) if absent. All provisional contracts documented in Detailed Design with stub values.

**Bidirectional notes:**
- First-Person Controller GDD already lists: `HUD/UI | Controller → HUD | current_state, interact_ray_hit, camera_raised` ✓
- Night Progression GDD should be updated to list HUD/UI as consumer of `night_timer_tick` and `current_night`
- Photography System (when designed) must implement provisional signal contracts
- Evidence Submission (when designed) must implement `DebriefData` schema and call `show_debrief()`

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Impact |
|---|---|---|---|
| `WARNING_THRESHOLD` | 60 s | 30–120 s | Lower = less warning, more pressure. Higher = gentler. Must be < shortest night (420s). |
| `LOW_FILM_THRESHOLD` | 3 | 1–5 | Lower = warned later, riskier. Higher = more cautious signaling. |
| `WARNING_PULSE_HZ` | 0.5 Hz | 0.25–1.0 Hz | Faster = more urgent. Slower = subtler. All warnings share this value. |
| `GRACE_PULSE_HZ` | 1.0 Hz | 0.5–2.0 Hz | Must feel faster than warning pulse. Below 0.5 Hz feels sluggish for emergency. |
| `ANOMALY_LOCK_PULSE_PERIOD` | 1.5 s | 0.5–3.0 s | Faster = aggressive confirmation. Slower = dreamy, atmospheric. |
| `PROMPT_TRANSITION_MS` | 120 ms | 60–250 ms | Below 60ms loses "tacked up" feel. Above 250ms feels laggy. |
| `HUD_TRANSITION_MS` | 120 ms | 60–250 ms | Same range as prompt. Keep in sync. |
| `DEBRIEF_HOLD_MS` | 500 ms | 200–1000 ms | Shorter = punchier cut. Longer = more dread in darkness. |
| `T_fade_per_line` | 200 ms | 100–500 ms | Shorter = fast, action feel. Longer = deliberate, authoritative. |
| `T_pause_pre_grade` | 500 ms | 200–1000 ms | Anticipation gap before grade stamp. Shorter = punchy. Longer = dramatic. |
| `CONTAINER_BG_OPACITY` | 0.2 | 0.1–0.4 | Lower = transparent, less intrusive. Higher = more visible (breaks minimal HUD above 0.4). |
| `DEBRIEF_STEP_R/G/B` | 12/8/7 | 5–20 per ch | Boss dialogue decay rate. Higher = faster (obvious). Lower = subtler (rewards attention). |

**Cross-system tuning knobs that affect this system (owned elsewhere):**
- `night_timer` formula (Night Progression) — determines timer values displayed
- `timer_grace_seconds` = 30s (Night Progression) — Grace Indicator display duration
- `night_count` = 7 (Night Progression) — number of Color Debt entries needed
- `speed_modifier_camera` = 0.75 (First-Person Controller) — affects Viewfinder activation

## Visual/Audio Requirements

### Preschool HUD — Visual and Audio

#### Governing Art Bible Principles

- **Section 3.4 Shape Grammar:** All containers use rounded rectangles (border-radius 12px). No hard angles. The HUD inherits the preschool's geometry.
- **Section 4.5 / Color Debt (4.2):** The HUD is the only UI register where Color Debt applies. Desaturation and cooling across nights is the primary horror delivery mechanism of this register.
- **Section 7.3 Iconography:** Construction-paper cut-out silhouettes. Filled single-color, no outlines, chunky weight.
- **Section 7.4 Animation:** 120ms ease-out only. Tacked up (scale 0.9→1.0 from center) and peeled off (reverse). No slides.
- **Section 4.4 Semantic Color:** Yellow (`#F5C842`) is the reserved warning color. Any warning must pair with shape cue + audio cue — color alone is never the sole signal.

#### VFX and Visual Feedback Events

**Night Timer — Warning Pulse (≤60s)**
- Visual: Container bg pulses 40%→70% opacity, 0.5Hz sine. Text and border override to Semantic Yellow `#F5C842`. Border weight increases 2px→3px (non-color backup signal).
- Audio: Low-frequency soft tick at ~300Hz, 0.5Hz sync. Bus: `UI`. Volume: -18dB relative to SFX_World baseline. Character: classroom clock second hand — metronomic, not alarming. No reverb send. Ceases when timer hides or Grace starts.

**Night Timer — Critical Warning (≤15s)**
- Visual: Pulse rate increases to 1.0Hz. Border flickers with 1-frame dropout every 3 seconds. Color holds Semantic Yellow.
- Audio: Tick pitch raises to ~440Hz. At ≤5s: single soft ascending three-note motif (Bus: `UI`, -12dB). The only musical element in the Preschool HUD — must read as diegetic clock alarm, not composed cue.

**Grace Indicator — LEAVE NOW State**
- Visual: No container. Fredoka One 32px at top-center. Color cycles 1Hz between `#F5C842` and `#FFFFFF` (sine, not hard-cut). 2px Crayola Red halo (`#E8392A` at 30% opacity) blooms 4px beyond text bounding box. Red appears only during Grace — uses Crayola Red (preschool register), not Arterial Red (monster/boss register).
- Audio: 80Hz sustained tone pulsing at 1Hz. Fast attack (10ms), full sustain, fast release (50ms) per pulse. Bus: `UI`, -10dB. Replaces timer tick entirely — do not layer.

**Film Counter — Low Film Warning (≤3 remaining)**
- Visual: Icon and number override to `#F5C842`. Icon pulse at 0.5Hz (opacity 60%→100%). On first threshold cross: single-fire particle burst — three construction-paper confetti shapes (square silhouettes, 4px, same yellow), arc outward 8px, fade over 300ms. Guard against re-firing if player adds film and re-crosses threshold.
- Audio: Soft dry click on each film decrement (shutter). On first reaching ≤3: secondary "wind-back" mechanical sound (30ms) follows the click. Bus: `SFX_World` (camera-body sound). At 0 remaining: soft empty-chamber click (0.4s) replaces shutter sound. Character: winding a disposable camera when empty.

**Color Debt Application — Night Transitions**
- Visual: Color Debt does not animate during gameplay. Applies at night start during LOADING phase. The player experiences Color Debt as discontinuity between sessions — a surprise, not a fade. Cut to black (300ms) → hold (200ms LOADING) → cut back with new values loaded. Do not interpolate during the night — this would expose the mechanism and destroy the effect.
- Audio: None. Silence is part of the design.

**Interaction Prompt — Appear/Disappear**
- Visual: 120ms ease-out appear (opacity 0→1, no position change). 80ms ease-out disappear.
- Audio: None for standard targets. Exception: anomaly targets (`interact_target_label == "Examine"`) — single quiet inorganic tone (Bus: `UI`, 600Hz, 80ms fade-in, 0 sustain, 200ms fade-out, sine with brief flutter at 40ms). Volume: -20dB. Must be subtle enough to miss on first encounter; becomes a tell on replay.

---

### Camera Viewfinder — Visual and Audio

#### Governing Art Bible Principles

- **Section 3.4 Shape Grammar:** Zero border-radius on all elements. Hard-angle break from preschool. Do not soften.
- **Section 4.5 / 7.1:** Viewfinder is diegetic. Visual rules never change with night progression — Color Debt explicitly excluded. The camera does not decay.
- **Section 2 Viewfinder Mode:** Mild vignette tightens peripheral field. In-frame colors desaturate ~10-15% (post-process by camera system, not HUD — but coordinated). Flash: single-frame 6500K overexposure.
- **Section 7.3 Iconography:** Line-only, single-pixel weight, no fill. Technical diagram aesthetic.

#### VFX and Visual Feedback Events

**Viewfinder Activation**
- Visual: Instant. Zero transition. Present in frame zero of `camera_raised == true`. Any fade or slide breaks design intent.
- Audio: Owned by Audio System (`camera_raise` SFX_World event). HUD/UI triggers no viewfinder activation audio.

**Anomaly Lock — Acquisition**
- Visual: Brackets shift from `#D4C8A0` to Unnatural White `#F0F0FF`. 1px trace rectangle materializes inside frame (4px inset from brackets). Instant appearance (frame 1 at 100%), then sine pulse begins frame 2: 1.5s period, 70%→100% opacity. Reads as "already present and active."
- Audio: Single short metallic chime (~800Hz, 100ms, fast attack, medium release). Bus: `UI`, -14dB. Character: 1990s autofocus camera lock confirmation. Not alarming — a tool confirming. The horror of lock is visual (Unnatural White), not audible.

**Anomaly Lock — Break**
- Visual: Snap immediately to `#D4C8A0`. Trace rectangle disappears same frame. No fade — a fade would imply the lock fading; the camera's honesty acknowledges loss immediately.
- Audio: Short dry click (~200Hz, 60ms, no release tail). Bus: `UI`, -18dB. Character: deadbolt snapping back.

**Shutter Fire — Standard (no anomaly)**
- Visual: Flash from camera system (single-frame, 6500K overexposure). Photo Counter increments instantly (no animation). Flash Charge segments drop immediately, then recharge bottom→top, one segment at a time. Lit: Amber `#C4882A`. No partial fills — fully lit or dark.
- Audio: Owned by Photography System. HUD triggers no independent shutter audio.

**Shutter Fire — Anomaly in Frame**
- Visual: Same flash. Additionally: Flash Charge segments flash white (`#FFFFFF`) for 1 frame each before going dark, sequenced bottom→top over 60ms total. The white borrows Unnatural White (`#F0F0FF` approximate) — a micro-contamination.
- Audio: Owned by Photography System (low-frequency thump underlay). No additional HUD audio.

**Flash Charge — Low State (≤2 segments)**
- Visual: Lit segments pulse at 0.5Hz, color shifts to Semantic Yellow `#F5C842`. Segments 1px narrower (7px from 8px) — subtle degraded appearance rewarding close readers.
- Audio: None. Would compete with environment at exactly the moments (Tier 2-3) when ambient layer is most active.

**Zoom Indicator Update**
- Visual: Instant text update. No animation. Consistent with viewfinder zero-animation rule.
- Audio: None. Zoom sound (if any) owned by Photography System.

---

### Boss Debrief — Visual and Audio

#### Governing Art Bible Principles

- **Section 7.5 / Pillar 3:** The entire debrief is a constructed lie. Every visual choice communicates "trustworthy authority" on first read and "monster register contamination" on replay.
- **Section 5.3 Boss Character:** Embedded sinister signals legible only on second playthrough. The debrief UI is the UI equivalent — same dual-read structure.
- **Section 2 Debrief Lighting:** Warmest state in the game (2700K). Most comfortable the player feels. UI must reinforce warm-office feeling, not horror UI.
- **Section 7.4 Animation:** 0.5s hold on black, single cut. Grade stamps: single-frame impact. Evidence cards: 200ms ease-out, 8px upward drift.

#### VFX and Visual Feedback Events

**Debrief Entry Sequence**
1. Fade to black: 300ms, linear (not ease — deliberate, not organic)
2. Hold black: 500ms (silence and darkness — most complete sensory break in the game. Do not fill)
3. Single cut to debrief layout: all elements at opacity 0
4. Dialogue lines fade in: 200ms ease-out each, 100ms stagger between lines
- Audio: During fade-to-black: SFX_World and Ambient buses fade to 0 synchronized. During hold: silence. On cut to debrief: music-box melody begins (Bus: `Music`). Character: thin, mechanical, slightly detuned, too slow. Begins at target volume on cut frame — no fade-in. The abrupt warmth is part of the lie. Night 7 specific: no music-box. Silence is the horror beat.

**Grade Stamp — Appearance**
- Visual: Single-frame cut to full opacity and size. No scale-up or fade. The impact IS the stamp. Circular dashed border (6px-4px dash pattern) appears simultaneously.
- **Grade F special beat:** Single-frame 40% screen desaturation for exactly 2 frames, then snap back. The F grade hits the room's palette for a blink — registers as discomfort, not consciously identified. On replay, the player notices the F-grade screen looked different.
- Audio: Grades A–D: no audio. Grade F: dull impact sound (~120Hz, 200ms, medium attack, fast release). Bus: `UI`, -10dB. Character: something heavy placed on a desk. Music does not duck — contrast is intentional.

**Pay Display**
- Visual: 200ms ease-out fade. Dollar amount appears complete — no count-up animation.
- Audio: None.

**Night Directive**
- Visual: 300ms ease-out fade after pay. 1px horizontal rule (`#8B2020` at 60% opacity) appears simultaneously with directive text (together reads as document underline; alone reads as UI separator).
- Audio: None.

**Continue Prompt**
- Visual: 500ms ease-out fade. No blinking or pulsing. Waits for the player. Urgency in this register is the boss's enemy.
- Audio: On press: soft page-turn (Bus: `UI`, 150ms, no reverb). Character: paper being set down. Volume: -16dB.

**Debrief Exit Sequence**
- Visual: Fade to black 300ms linear. Hold 200ms. LOADING phase. HUD re-appears with new Color Debt values.
- Audio: Music-box melody fade-out begins at Continue press over 400ms. Still audible as screen goes black, then gone. The preschool gets the last word: warmth ends before the player is ready.

---

### Cross-Register Requirements

#### Register Contamination Rules

**Forbidden crossings:**
- Fredoka One must not appear in Viewfinder or Debrief
- Share Tech Mono must not appear in Preschool HUD or Debrief
- Lora must not appear in Preschool HUD or Viewfinder
- Rounded rectangles (border-radius > 0) must not appear in Viewfinder
- Hard right angles (border-radius = 0) must not appear in Preschool HUD containers

**One permitted contamination (scripted):** Unnatural White (`#F0F0FF`) in the Preschool HUD is reserved for scripted Night 6-7 horror beat. Requires narrative authorization before implementation.

#### Audio Bus Boundaries

| Event | Bus | Boundary Reason |
|---|---|---|
| UI warning ticks, tones, chimes | `UI` | Not spatialized; not gameplay sounds |
| Shutter sound | `SFX_World` (Photography System) | Diegetic player action |
| Anomaly lock chime/break | `UI` | Interface confirmation, not world event |
| Debrief music-box | `Music` | Only music layer outside Night 7 |
| Continue page-turn | `UI` | Interface action |
| F-grade impact | `UI` | Interface event, not world event |

HUD/UI System must not write to `SFX_Spatial` or `Ambient` buses. Any HUD sound needing spatialization is a design error.

#### Color Debt Boundary

- **Applies to:** Preschool HUD (all elements except Interaction Prompt)
- **Does not apply to:** Camera Viewfinder (any element), Boss Debrief (any element)
- Boss Debrief Color Decay is independent (amber decay formula, Section D)
- The viewfinder holds warm cream `#D4C8A0` on Night 7 with the same conviction as Night 1. The camera does not decay. This is what makes it trustworthy. Breaking this boundary destroys Pillar 2.

#### Accessibility Backup Matrix

| Element | Primary Cue | Shape Backup | Audio Backup |
|---|---|---|---|
| Timer warning | Yellow color override | Border weight 2px→3px | 0.5Hz tick ~300Hz |
| Film counter low | Yellow color override | Icon opacity pulse | Wind-back click on threshold |
| Flash charge low | Yellow color override | 1px segment width reduction | None (env competition) |
| Anomaly lock | Unnatural White shift | Trace rectangle + brackets | Metallic chime |
| Grade F | Arterial Red stamp | Letter "F" + circular border | Impact sound |
| Grace indicator | Yellow/white cycle | Red halo | 80Hz pulsing tone |

All primary text: WCAG AA (4.5:1 minimum). Boss Debrief headers (`#8B2020`) acknowledged as intentionally low-contrast (~2.8:1) per art bible Section 7.6 — deliberate design choice for non-critical decorative text only.

## UI Requirements

### Input Handling

- **Debrief Continue:** Edge-triggered only — `debrief_continue_pressed` fires on button-down, not held state. Accepts keyboard (`E`), gamepad (`A`/`Cross`). Input blocked until `T_dwell` elapses and Continue Prompt is visible.
- **Viewfinder raise/lower:** Owned by First-Person Controller, not HUD. HUD reacts to `camera_raised` signal — no input handling in the HUD layer.
- **Interaction Prompt:** HUD displays the prompt; interaction input handling is owned by First-Person Controller (`interact_ray_hit` + player press). HUD only renders the visual.
- **No HUD-initiated input:** The HUD/UI System is display-only. It never captures, consumes, or blocks gameplay input except during Boss Debrief (full-screen modal).

### Focus & Navigation

- **Preschool HUD:** No focusable elements. Pure display layer — keyboard/gamepad focus never enters the HUD.
- **Camera Viewfinder:** No focusable elements. All viewfinder interaction is through Photography System inputs.
- **Boss Debrief:** Single focusable element: Continue Prompt. Auto-focused when it appears. No tab navigation needed (one element). Gamepad: `A`/`Cross` to confirm. Keyboard: `E` to confirm. Mouse: click on prompt text.

### Screen Flow

```
Gameplay (Preschool HUD visible)
  ├── Camera Raised → Viewfinder overlay added (HUD still visible beneath)
  ├── Camera Lowered → Viewfinder removed
  └── Night End → Evidence Submission triggers show_debrief()
        ├── Debrief full-screen overlay (covers all registers)
        ├── Player presses Continue → hide_debrief()
        └── Next night LOADING → HUD reappears with new Color Debt
```

### Layout Constraints

- **Minimum resolution:** 1280×720. Below this is undefined behavior.
- **Target resolutions:** 1280×720, 1920×1080.
- **Aspect ratios:** 16:9 primary. 21:9 ultrawide: margin anchors hold, center elements stay centered. 4:3: not officially supported but layout should not break.
- **Scaling:** Fixed pixel sizes at reference resolution 1920×1080. At 1280×720, Godot's stretch mode (`canvas_items`) handles downscale.
- **Safe area:** All HUD elements inset minimum 32px from viewport edges at reference resolution.

## Acceptance Criteria

### MVP Acceptance Criteria

**Register Visibility:**
- **AC-HUD-001**: GIVEN Normal state, WHEN game is running, THEN Night Timer (MM:SS), Night Number ("Night X"), and Film Counter are visible at their anchored positions.
- **AC-HUD-002**: GIVEN `camera_raised == true`, WHEN viewfinder activates, THEN Viewfinder overlay appears instantly (0ms transition) with brackets, zoom readout, film remaining, and flash charge segments visible.
- **AC-HUD-003**: GIVEN `current_state` changes to Cutscene or Dead, WHEN HUD evaluates next frame, THEN Preschool HUD elements hide (120ms ease-out) and Viewfinder is not visible.

**State Transitions:**
- **AC-HUD-004**: GIVEN player is in Normal state with interaction prompt visible, WHEN `current_state` changes to Running, THEN interaction prompt hides within 120ms.
- **AC-HUD-005**: GIVEN player enters In Vent state, WHEN HUD evaluates, THEN only Night Timer remains visible; Film Counter, Night Number, and interaction prompt are hidden.

**Timer & Warnings:**
- **AC-HUD-006**: GIVEN `seconds_remaining == 60`, WHEN timer updates, THEN timer text switches to Semantic Yellow (`#F5C842`) and begins 0.5Hz warning pulse.
- **AC-HUD-007**: GIVEN timer warning active AND film counter ≤ `LOW_FILM_THRESHOLD`, WHEN both warnings display, THEN both pulse at exactly 0.5Hz, synchronized and in phase.
- **AC-HUD-008**: GIVEN `night_grace_started` fires, WHEN Grace Indicator appears, THEN it replaces the timer at top-center, pulses at 1.0Hz, and displays "LEAVE NOW" text.

**Night 7 Special:**
- **AC-HUD-009**: GIVEN `current_night == 7` during LOADING phase, WHEN HUD initializes, THEN Night Timer and Night Number are both hidden. Film Counter remains visible.

**Viewfinder:**
- **AC-HUD-010**: GIVEN viewfinder is active, WHEN `anomaly_lock_changed(true)` fires, THEN corner brackets change to Lock Color (`#C8A050`) and begin 1.5s sine pulse.
- **AC-HUD-011**: GIVEN viewfinder is active, WHEN `flash_charge_changed` receives a value, THEN flash charge segments update proportionally within [0.0, 1.0]; values outside range are clamped.

**Boss Debrief:**
- **AC-HUD-012**: GIVEN `show_debrief(DebriefData)` is called, WHEN debrief sequence plays, THEN dialogue lines fade in sequentially, grade stamp appears after `T_pause_pre_grade`, and Continue Prompt appears only after `T_dwell` elapses.
- **AC-HUD-013**: GIVEN debrief is playing and T_dwell has not elapsed, WHEN player presses Continue, THEN input is ignored; Continue Prompt is not yet visible.
- **AC-HUD-014**: GIVEN `current_night == 4`, WHEN debrief displays, THEN boss dialogue text color is `#B09040` (±2 per channel tolerance for rounding).

**Color Debt:**
- **AC-HUD-015**: GIVEN Night 1, WHEN HUD renders, THEN Preschool HUD elements use Night 1 Color Debt palette (full Crayola saturation). GIVEN Night 6, WHEN HUD renders, THEN elements use Night 6 palette (desaturated, cooled). Visual difference is perceptible to a tester comparing screenshots.

---

### Deferred Acceptance Criteria (post-MVP)

- **AC-HUD-D01**: GIVEN Hiding state, WHEN `camera_raised` fires true, THEN Viewfinder does not appear.
- **AC-HUD-D02**: GIVEN two `current_state` changes in a single physics frame, WHEN HUD evaluates, THEN only the final state is applied.
- **AC-HUD-D03**: GIVEN `seconds_remaining` is negative, WHEN timer displays, THEN timer shows `0:00` and a warning is logged.
- **AC-HUD-D04**: GIVEN warning condition clears mid-pulse, WHEN next frame renders, THEN warning color is removed immediately (no pulse completion).
- **AC-HUD-D05**: GIVEN `grade` value not in {A, B, C, D, F}, WHEN debrief renders, THEN stamp shows no letter, uses F-grade color, and an error is logged.
- **AC-HUD-D06**: GIVEN `pay_amount` is negative, WHEN debrief renders, THEN `$0` is displayed and a warning is logged.
- **AC-HUD-D07**: GIVEN `hud_color_debt.tres` fails to load, WHEN HUD initializes, THEN Night 1 colors are used as fallback and an error is logged. Player is not blocked.
- **AC-HUD-D08**: GIVEN browser tab loses focus during warning pulse, WHEN tab regains focus, THEN pulse resumes at correct phase. Synchronized warnings resume together.
- **AC-HUD-D09**: GIVEN browser window resized, WHEN layout recalculates, THEN margin-anchored elements maintain margins and center elements stay centered at both 1280×720 and 1920×1080.
- **AC-HUD-D10**: GIVEN `show_debrief()` called while prior debrief is playing, WHEN second call arrives, THEN it is queued and first debrief completes fully before second displays.
- **AC-HUD-D11**: GIVEN `anomaly_lock_changed(true)` fires while Viewfinder is not visible, WHEN Viewfinder next opens, THEN lock state is already active (brackets at Lock Color with pulse).
- **AC-HUD-D12**: GIVEN `zoom_changed` receives value ≤ 0.0, WHEN viewfinder displays, THEN zoom readout shows `--x` and a warning is logged.
- **AC-HUD-D13**: GIVEN `current_night > 7`, WHEN HUD initializes, THEN Night 7 logic is applied (hidden timer/night number) and a warning is logged.
- **AC-HUD-D14**: GIVEN non-standard aspect ratio (21:9), WHEN HUD renders, THEN margin anchors hold and center elements stay centered.
- **AC-HUD-D15**: GIVEN player holds Continue key across T_dwell boundary, WHEN Continue Prompt appears, THEN held key does not trigger — only a fresh press fires `debrief_continue_pressed`.

---

**Coverage Notes:**
- 15 MVP criteria cover all core rules from Detailed Design and both formulas from Formulas section
- States with dedicated criteria: Normal, Camera Raised, In Vent. Remaining states (Running, Hiding, Grabbed, Dead, Cutscene, Restarting) follow the visibility matrix but can receive explicit criteria in a future QA pass
- `T_post_grade` confirmed at 200ms default

## Open Questions

1. **Photography System signal contract finalization** — Stub values and provisional signals defined (`film_remaining_changed`, `zoom_changed`, `flash_charge_changed`, `anomaly_lock_changed`, `photo_taken`). Exact payload shapes TBD when Photography System GDD is authored. **Owner:** Photography System designer. **Target:** Before Photography GDD review.

2. **Evidence Submission `DebriefData` schema** — Current schema is provisional (dialogue_lines, grade, pay_amount, night_directive, current_night). May expand when Evidence Submission GDD is authored. **Owner:** Evidence Submission designer. **Target:** Before Evidence Submission GDD review.

3. **Player Survival HUD integration** — Art bible excludes health/stamina/threat bars. Subtle screen-edge vignette mentioned as possibility. Decision deferred until Player Survival GDD defines its feedback mechanisms. **Owner:** Player Survival designer.

4. **Night 7 narrative HUD events** — The "permitted contamination" (Unnatural White `#F0F0FF` in Preschool HUD) is reserved for scripted Night 6-7 horror beats but not yet defined. **Owner:** Narrative Director. **Target:** Before Night 7 content authoring.

5. **Color Debt palette authoring** — 7 discrete Color Debt entries specified for `hud_color_debt.tres` but exact per-night RGB values for each HUD element not authored here. **Owner:** Art Director. **Target:** During art production, after art bible approval.

6. **Audio asset sourcing** — Visual/Audio section specifies acoustic character for 8+ new UI sounds (warning tick, grace tone, wind-back click, empty-chamber click, anomaly examine tone, lock chime, lock break click, F-grade impact, page-turn). Actual `.wav` assets need to be authored. **Owner:** Sound Designer. **Target:** During audio production.
