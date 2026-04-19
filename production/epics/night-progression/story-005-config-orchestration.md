# Story 005: Configuration Orchestration

> **Epic**: Night Progression
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/night-progression.md` (Night Lifecycle — LOADING section, Configuration Calls table)
**Requirement**: `TR-NP-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Top-down `configure_for_night(n)` calls from Night Progression to Foundation systems. No Autoload singletons for cross-system communication — use `has_node()` / `get_node()` checks. Signal registry documents all night signals.

**ADR Governing Implementation**: ADR-0001 (Scene Architecture)
**ADR Decision Summary**: RoomManager scene-local node, not Autoload. `configure_for_night(n)` sets horror_tier, access_state, lights_on, active_spawn_slots. `unlock_room(&"principals_office")` for Night 7.

**ADR Governing Implementation**: ADR-0009 (Audio)
**ADR Decision Summary**: AudioManager singleton for audio bus routing. `configure_audio_for_night(n)` sets ambient variants, reverb, shutter variant, breathing threshold.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Autoload detection via `has_node()` pattern. Configuration calls are fire-and-forget with warning on missing targets. Reserved calls (AnomalyPlacementEngine, MonsterAI) use same pattern. No Engine API changes needed.

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Required: No signal chains — each system emits its own distinct signal
- Required: Top-down configuration calls only — Night Progression calls configure_for_night(n) on Foundation systems at night start

---

## Acceptance Criteria

*From GDD `design/gdd/night-progression.md`, scoped to this story:*

- [ ] AC-NP-25: GIVEN Night 3 LOADING begins, WHEN configuration executes, THEN `RoomManager.configure_for_night(3)` is called with horror_tier=2, `AudioManager.configure_audio_for_night(3)` is called, and `MonsterAI.configure_for_night(3)` is called with monster_count=1.

- [ ] AC-NP-26: GIVEN Night 7 LOADING begins, WHEN configuration executes, THEN RoomManager sets horror_tier=3, unlocks `principals_office`, and `AudioManager.configure_audio_for_night(7)` sets the escape music variant.

- [ ] AC-NP-27: GIVEN RoomManager autoload is missing, WHEN Night Progression LOADING runs, THEN an error is logged and the night does NOT start (RoomManager is a hard dependency).

- [ ] AC-NP-28: GIVEN AudioManager autoload is missing, WHEN Night Progression LOADING runs, THEN a warning is logged and the night starts without audio configuration (AudioManager is soft dependency for MVP).

- [ ] AC-NP-29: GIVEN all configuration calls complete, WHEN phase transitions to ACTIVE, THEN `night_active_started(n)` emits after all configure calls finish.

- [ ] AC-NP-30: GIVEN Night 1 LOADING begins, WHEN `configure_for_night(1)` completes, THEN horror_tier=1, lights_on=true, access_state=["entry_hall", "main_classroom", "art_corner"].

---

## Implementation Notes

*Derived from ADR-0003 Communication + ADR-0001 Scene Architecture + ADR-0009 Audio:*

**Configuration orchestration — full LOADING flow:**
```gdscript
# night_progression.gd

func _start_loading(night: int) -> void:
    current_night = night
    _transition_to(NightPhase.LOADING)

    # --- Hard dependency: RoomManager ---
    if not Engine.has_singleton("RoomManager"):
        push_error("RoomManager autoload not found — night cannot start (hard dependency)")
        return

    RoomManager.configure_for_night(night)

    # Night 7: unlock Principal's Office after configure
    if night == 7:
        RoomManager.unlock_room(&"principals_office")

    # --- Soft dependency: AudioManager ---
    if Engine.has_singleton("AudioManager"):
        AudioManager.configure_audio_for_night(night)
    else:
        push_warning("AudioManager autoload not found — skipping audio configuration")

    # --- Soft dependencies: reserved systems ---
    if has_node("AnomalyPlacementEngine"):
        get_node("AnomalyPlacementEngine").configure_for_night(night)
    else:
        push_warning("AnomalyPlacementEngine not found — skipping anomaly configuration")

    if has_node("MonsterAI"):
        get_node("MonsterAI").configure_for_night(night)
    else:
        push_warning("MonsterAI not found — skipping monster configuration")

    # --- Set timer duration ---
    _time_remaining = get_night_duration(night)

    # --- Load persisted state (new session only) ---
    _load_persisted_state()

    # --- Emit loading signal ---
    night_loading_started.emit(night)

    # --- Transition to next phase ---
    if night == 7:
        _transition_to(NightPhase.INTRO)
        night_7_cutscene_start.emit()
    else:
        _transition_to(NightPhase.ACTIVE)
        night_active_started.emit(night)
```

**RoomManager configure contract (interface, implemented in Room/Level Management epic):**
```gdscript
# RoomManager.gd — interface contract

func configure_for_night(night: int) -> void:
    # Sets: horror_tier, access_state, lights_on, active_spawn_slots
    # Implementation provided by Room/Level Management epic
    # Night Progression does NOT need to know the internals
    pass

func unlock_room(room_id: StringName) -> void:
    # Unlocks a room that was previously locked
    # Implementation provided by Room/Level Management epic
    pass
```

**AudioManager configure contract (interface, implemented in Audio System epic):**
```gdscript
# AudioManager.gd — interface contract

func configure_audio_for_night(night: int) -> void:
    # Sets: ambient variants, reverb parameters, shutter variant, breathing threshold
    # Night 7: also sets up night_7_escape music event
    # Implementation provided by Audio System epic
    pass
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Room/Level Management]: RoomManager.configure_for_night() implementation (Night Progression only calls the interface; Room Management implements it)
- [Audio System]: AudioManager.configure_audio_for_night() implementation (Night Progression only calls the interface; Audio System implements it)
- [Anomaly Placement]: AnomalyPlacementEngine.configure_for_night() implementation
- [Monster AI]: MonsterAI.configure_for_night() implementation
- [Story 001]: Timer duration (computed here but formula tested in Story 001)
- [Story 002]: Difficulty scaling (formulas tested in Story 002)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-NP-25**: Night 3 configuration
  - Given: Night 3 LOADING begins
  - When: _start_loading(3) runs
  - Then: RoomManager.configure_for_night(3) called; AudioManager.configure_audio_for_night(3) called; MonsterAI.configure_for_night(3) called with monster_count=1; phase transitions to ACTIVE
  - Edge cases: MonsterAI absent → warning logged, night still starts; RoomManager absent → error logged, night does NOT start; AudioManager absent → warning logged, night still starts

- **AC-NP-26**: Night 7 configuration
  - Given: Night 7 LOADING begins
  - When: _start_loading(7) runs
  - Then: RoomManager.configure_for_night(7) called with horror_tier=3; RoomManager.unlock_room(&"principals_office") called after configure; AudioManager.configure_audio_for_night(7) called; phase transitions to INTRO; night_7_cutscene_start emitted
  - Edge cases: unlock_room called before configure → incorrect order (configure must come first); unlock_room called multiple times → idempotent (no error on double-unlock)

- **AC-NP-27**: Missing RoomManager
  - Given: RoomManager autoload is absent
  - When: Night Progression LOADING runs
  - Then: Error logged via push_error; _start_loading returns early; phase stays in LOADING; night does NOT start
  - Edge cases: RoomManager added later in same session → must re-run _start_loading (no auto-detect); multiple nights attempted → all blocked until RoomManager present

- **AC-NP-28**: Missing AudioManager
  - Given: AudioManager autoload is absent
  - When: Night Progression LOADING runs
  - Then: Warning logged via push_warning; night proceeds normally without audio configuration
  - Edge cases: AudioManager added mid-session → not auto-detected (requires restart); both AudioManager and MonsterAI absent → both warnings logged, night still starts

- **AC-NP-29**: Signal ordering
  - Given: Night 3 LOADING begins
  - When: Configuration calls complete
  - Then: night_active_started(3) emits AFTER all configure calls finish (not before); night_loading_started(3) emits before configure calls
  - Edge cases: configure_for_night is slow (>100ms) → player waits in LOADING (acceptable for MVP); configure calls are synchronous (no async)

- **AC-NP-30**: Night 1 configuration
  - Given: Night 1 LOADING begins
  - When: configure_for_night(1) completes
  - Then: horror_tier=1, lights_on=true, access_state=["entry_hall", "main_classroom", "art_corner"]
  - Edge cases: access_state must match GDD room list exactly; lights_on=true is the default (no dimming on Night 1); horror_tier=1 means normal audio/visuals

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/night-progression/config_orchestration_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (configuration orchestration is foundational — other epics implement the configure_for_night methods that Night Progression calls)
- Unlocks: All feature epics (Room/Level Management, Audio System, Anomaly Placement, Monster AI all receive configure_for_night calls from Night Progression)
