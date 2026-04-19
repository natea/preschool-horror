# Story 005: Flashlight + Battery

> **Epic**: Player Survival
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Player Survival section)
**Requirement**: `TR-PLA-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Battery drain rate, battery capacity, and flashlight range in TuningKnobs. No magic numbers.

**ADR Governing Implementation**: ADR-0009 (Audio)
**ADR Decision Summary**: Flashlight on/off sounds route through AudioManager SFXBus. No direct AudioStreamPlayer.

**ADR Governing Implementation**: ADR-0005 (Rendering)
**ADR Decision Summary**: Flashlight uses DirectionalLight3D or SpotLight3D with Forward+ compatible settings. Web: reduced shadow quality.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Signal-based events — `flashlight_toggled`, `battery_depleted`. No signal chains.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Light3D/SpotLight3D for flashlight beam. Battery drain via Timer or manual delta accumulation. Audio via SFXManager. Post-cutoff API changes for Light3D shadow settings possible in 4.5/4.6 — verify via docs.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

**Control Manifest Rules (Presentation layer)**:
- Required: Forward+ compatible lighting for flashlight
- Guardrail: Web shadow quality reduced for flashlight light source
- Guardrail: Non-rendering CPU budget < 4 ms on Web

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md`, scoped to this story:*

- [ ] AC-PLA-17: GIVEN the player has a flashlight item in inventory, WHEN the player activates the flashlight input, THEN a light source (SpotLight3D or DirectionalLight3D) turns on in the player's view direction.

- [ ] AC-PLA-18: GIVEN the flashlight is on, WHEN time elapses, THEN the battery drains at the configured `battery_drain_rate` (per second) from TuningKnobs.

- [ ] AC-PLA-19: GIVEN the flashlight battery is depleted, WHEN the battery reaches 0%, THEN the flashlight turns off automatically and the player can insert a new battery item to restore it.

- [ ] AC-PLA-20: GIVEN the player inserts a battery item while the flashlight is depleted or off, WHEN the insertion succeeds, THEN the battery is consumed from inventory and the flashlight turns on with full charge.

---

## Implementation Notes

*Derived from ADR-0004 Data-Driven:*

```gdscript
# TuningKnobs values:
#   flashlight_battery_capacity: float (seconds of light, default 120.0 = 2 minutes)
#   flashlight_range: float (meters, default 15.0)
#   flashlight_fov: float (degrees, default 45.0)
#   flashlight_intensity: float (lumens, default 10.0)
#   flashlight_shadow_quality: enum (LOW, MEDIUM, HIGH — platform dependent)
```

*Flashlight state machine:*

```gdscript
# States: OFF, ON, DEPLETED
# OFF → ON: player activates flashlight (requires flashlight item in inventory)
# ON → DEPLETED: battery reaches 0.0
# DEPLETED → OFF: player inserts battery (consumes battery item)
# OFF → ON: player inserts battery (consumes battery item, auto-on)
# ON → OFF: player deactivates flashlight
```

*Battery drain:*

```gdscript
# In _physics_process():
# if flashlight_state == FlashlightState.ON:
#     battery_level -= battery_drain_rate * delta
#     if battery_level <= 0.0:
#         battery_level = 0.0
#         flashlight_state = FlashlightState.DEPLETED
#         battery_depleted.emit()
```

*Light source setup:*

```gdscript
# PC: SpotLight3D with shadows enabled (medium quality)
# Web: SpotLight3D with shadows disabled or low quality (per Forward+ budget)
# Light follows player camera rotation (y-axis only, no pitch)
# Range = flashlight_range from TuningKnobs
```

*Derived from ADR-0009 Audio:*

- Flashlight on: `SFXManager.play_sfx("flashlight_on")` — short mechanical click
- Flashlight off: `SFXManager.play_sfx("flashlight_off")` — short mechanical click
- Battery depleted: `SFXManager.play_sfx("flashlight_buzz")` — brief electric buzz
- All audio preloaded via `preload()`

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: Flashlight item definition (inventory creates the item)
- [Story 004]: Battery item pickup (pickup mechanism is generic)
- [Story 006]: Player state persistence (flashlight state not saved, only battery count)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PLA-17**: Flashlight turns on
  - Given: Flashlight item in inventory
  - When: Player activates flashlight input
  - Then: Light node created/enabled in player view; light follows camera rotation; light range = `flashlight_range` from TuningKnobs
  - Edge cases: no flashlight in inventory → activation does nothing; flashlight already on → no duplicate light; camera rotated 360° → light follows smoothly

- **AC-PLA-18**: Battery drains over time
  - Given: Flashlight ON, `battery_drain_rate = 1.0` (120 second battery), `battery_level = 1.0`
  - When: 60.0 seconds elapse
  - Then: `battery_level = 0.5`; light remains on
  - Edge cases: `battery_drain_rate = 0.0` → battery never drains; drain = 2.0 → battery lasts 60s; battery_level = 0.01 → flashlight still on (not yet depleted)

- **AC-PLA-19**: Flashlight turns off when depleted
  - Given: Flashlight ON, battery_level = 0.0
  - When: Drain check runs
  - Then: Light disabled; `battery_depleted` signal fires; flashlight_state = DEPLETED
  - Edge cases: rapid on/off → battery doesn't drain when off; depleted flashlight activated again → no change, stays depleted

- **AC-PLA-20**: Battery insertion
  - Given: Flashlight DEPLETED, battery item in inventory
  - When: Player activates flashlight (triggers battery insert)
  - Then: Battery consumed from inventory; battery_level = 1.0; light enabled; `battery_depleted` does NOT fire (just restored)
  - Edge cases: no battery in inventory → insertion fails; flashlight already ON → battery insert does nothing (already working); insert battery while OFF → flashlight auto-turns on

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/player_survival/flashlight_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 must be DONE (flashlight and battery items must exist in inventory)
- Unlocks: Monster AI (flashlight affects monster behavior, handled in monster-ai epic), night progression (flashlight use affects survival time)
