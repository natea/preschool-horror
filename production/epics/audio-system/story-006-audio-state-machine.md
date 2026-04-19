# Story 006: Audio State Machine

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUD-011`, `TR-AUD-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Audio System)
**ADR Decision Summary**: Audio System state machine: SILENT, AMBIENT_NORMAL, AMBIENT_RUNNING, AMBIENT_IN_VENT, AMBIENT_HIDING, AMBIENT_CUTSCENE, DEAD. State transitions driven by FPC signals. One-way trap in DEAD state.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: FPC sends current_state on transition. hide_spot_entered/exited from Hiding System. vent_entry_complete/exit_complete from Vent System.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: Static typing. System-based directory structure.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: State machine via enum. Signal connections for state triggers. Volume automation via tween or manual delta accumulation.

**Control Manifest Rules (Foundation layer)**:
- Required: State changes immediate on signal receipt (except AMBIENT_IN_VENT fade)
- Guardrail: DEAD is one-way trap until scene reload

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] AC-AUD-16: GIVEN audio has transitioned to DEAD, WHEN any subsequent signal fires, THEN no state change occurs, no new sounds play, and all buses remain at 0 until scene reload.

- [ ] AC-AUD-17: GIVEN the player is in AMBIENT_NORMAL, WHEN hide_spot_entered fires, THEN Ambient bus attenuates by 6dB, a heartbeat loop begins at 80 BPM on SFX_World, and spatial SFX continues at -6dB. WHEN hide_spot_exited fires, THEN heartbeat stops and volumes restore.

---

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

```gdscript
# audio_state_machine.gd

enum State {
	SILENT,
	AMBIENT_NORMAL,
	AMBIENT_RUNNING,
	AMBIENT_IN_VENT,
	AMBIENT_HIDING,
	AMBIENT_CUTSCENE,
	DEAD,
}

var _current_state: State = State.SILENT

signal audio_state_changed(new_state: StringName)

const AMBIENT_DUCK_HIDING: float = -6.0

var _heartbeat_player: AudioStreamPlayer = null
var _heartbeat_buses_restored: bool = false
var _spatial_duck_restored: bool = false

func on_fpc_state_changed(state: StringName) -> void:
	match state:
		&"Normal":
			_transition_to(State.AMBIENT_NORMAL)
		&"Camera_Raised":
			# Camera Raised does NOT change audio state (speed change handled by footstep system)
			pass
		&"Running":
			_transition_to(State.AMBIENT_RUNNING)
		&"In_Vent":
			_transition_to(State.AMBIENT_IN_VENT)
		&"Cutscene":
			_transition_to(State.AMBIENT_CUTSCENE)
		&"Dead":
			_transition_to(State.DEAD)

func on_hide_spot_entered() -> void:
	if _current_state == State.DEAD:
		return
	_current_state = State.AMBIENT_HIDING
	# Duck ambient by 6dB
	var ambient_bus: int = AudioServer.get_bus_index("Ambient")
	AudioServer.set_bus_volume_db(ambient_bus, AudioServer.get_bus_volume_db(ambient_bus) + AMBIENT_DUCK_HIDING)
	# Duck spatial SFX by 6dB
	var spatial_bus: int = AudioServer.get_bus_index("SFX_Spatial")
	AudioServer.set_bus_volume_db(spatial_bus, AudioServer.get_bus_volume_db(spatial_bus) + AMBIENT_DUCK_HIDING)
	# Start heartbeat
	_start_heartbeat()

func on_hide_spot_exited() -> void:
	if _current_state != State.AMBIENT_HIDING:
		return
	_current_state = State.AMBIENT_NORMAL
	# Restore ambient
	var ambient_bus: int = AudioServer.get_bus_index("Ambient")
	AudioServer.set_bus_volume_db(ambient_bus, AudioServer.get_bus_volume_db(ambient_bus) - AMBIENT_DUCK_HIDING)
	# Restore spatial
	var spatial_bus: int = AudioServer.get_bus_index("SFX_Spatial")
	AudioServer.set_bus_volume_db(spatial_bus, AudioServer.get_bus_volume_db(spatial_bus) - AMBIENT_DUCK_HIDING)
	_stop_heartbeat()

func on_vent_entry_complete() -> void:
	if _current_state == State.DEAD:
		return
	_transition_to(State.AMBIENT_IN_VENT)

func on_vent_exit_complete() -> void:
	if _current_state != State.AMBIENT_IN_VENT:
		return
	_transition_to(State.AMBIENT_NORMAL)

func on_player_killed() -> void:
	_transition_to(State.DEAD)

func _transition_to(new_state: State) -> void:
	if new_state == State.DEAD:
		_enter_dead_state()
		return
	if _current_state == State.DEAD:
		return  # One-way trap

	# Handle vent exit fade
	if _current_state == State.AMBIENT_IN_VENT and new_state == State.AMBIENT_NORMAL:
		_fade_ambient_in()
		return

	_current_state = new_state
	audio_state_changed.emit(_state_to_string(new_state))

func _enter_dead_state() -> void:
	_current_state = State.DEAD
	# Stop all audio
	_stop_all_audio()
	# Fade all buses to 0 over 1s
	for i in AudioServer.get_bus_count():
		var bus_name: StringName = AudioServer.get_bus_name(i)
		if bus_name != &"Master":
			var target_db: float = -80.0
			var current_db: float = AudioServer.get_bus_volume_db(i)
			_fade_bus_to(i, current_db, target_db, 1.0)

func _stop_all_audio() -> void:
	# Stop all active players, clear pools
	pass  # Implementation depends on pool management

func _state_to_string(state: State) -> StringName:
	match state:
		State.SILENT: return &"SILENT"
		State.AMBIENT_NORMAL: return &"AMBIENT_NORMAL"
		State.AMBIENT_RUNNING: return &"AMBIENT_RUNNING"
		State.AMBIENT_IN_VENT: return &"AMBIENT_IN_VENT"
		State.AMBIENT_HIDING: return &"AMBIENT_HIDING"
		State.AMBIENT_CUTSCENE: return &"AMBIENT_CUTSCENE"
		State.DEAD: return &"DEAD"
	return &"UNKNOWN"
```

*Derived from GDD States and Transitions:*

- DEAD is a one-way trap until scene reload
- Camera Raised does NOT change audio state (speed handled by footstep system)
- AMBIENT_IN_VENT: fade room ambient out over 0.5s on entry, back in on exit
- Hiding: Ambient bus -6dB, spatial SFX -6dB, heartbeat 80 BPM on SFX_World

*Derived from GDD Edge Cases:*

- player_killed while in AMBIENT_IN_VENT: transition directly to DEAD, hard cut vent loop (no fade)
- Any signal in DEAD state: no processing, no state change

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Bus creation (prerequisite)
- [Story 002]: Ambient cross-fade (state changes use cross-fade but don't implement it)
- [Story 005]: Monster breathing (independent of audio state)
- [Story 007]: Music ducking (separate priority system)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AUD-16**: DEAD state one-way trap
  - Given: Audio in DEAD state
  - When: Any signal fires (player_entered_room, monster_proximity, hide_spot_entered, etc.)
  - Then: No state change, no new sounds play, all buses at 0 (or -80dB)
  - Edge cases: player_killed called again → no-op; scene reload → resets to SILENT

- **AC-AUD-17**: Hiding audio state
  - Given: Audio in AMBIENT_NORMAL
  - When: hide_spot_entered fires
  - Then: Ambient bus at -6dB; spatial SFX at -6dB; heartbeat loop at 80 BPM on SFX_World
  - Edge cases: hide_spot_exited while in DEAD → no restore; hide_spot_entered while already HIDING → no-op; ambient bus already at -6dB → no double-duck

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/audio/audio_state_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (buses exist), Story 002 must be DONE (ambient cross-fade available)
- Unlocks: Story 008 (Nap Room music box uses audio state for violation timing)
