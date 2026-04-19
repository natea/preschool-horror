# Story 002: Ambient Cross-fade System

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUD-003`, `TR-AUD-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Audio System)
**ADR Decision Summary**: One ambient loop plays at a time, cross-fading on player_entered_room. Fade out current over AMBIENT_CROSSFADE_TIME (1.5s), fade in new over same duration. Cancel threshold: CROSSFADE_CANCEL_THRESHOLD (0.5s).

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Subscribers to player_entered_room: Audio System, Night Progression, HUD. No signal chains.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: RoomData includes ambient_track and ambient_volume_db. Tier variants selected by configure_audio_for_night().

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: AudioStreamPlayer.stream_play() for cross-fade. Volume tween via tweening or manual _process delta accumulation. Never layer 3+ ambients.

**Control Manifest Rules (Foundation layer)**:
- Required: One ambient loop at a time (never layered)
- Guardrail: Cross-fade must not produce audible pops (smooth volume transition)

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] AC-AUD-03: GIVEN the player is in entry_hall with ambient playing, WHEN player_entered_room("main_classroom") fires, THEN entry_hall ambient fades to silent over 1.5s while main_classroom ambient fades in over 1.5s. At no point do three ambients play simultaneously.

- [ ] AC-AUD-04: GIVEN a cross-fade has been triggered, WHEN player_exited_room fires within 0.5s, THEN the cross-fade cancels, the original ambient snaps back to full volume, and the new ambient stops.

- [ ] AC-AUD-05: GIVEN a cross-fade from room A to B is in progress, WHEN player_entered_room("room_c") fires before completion, THEN the A-to-B fade cancels (A snaps silent), a fresh B-to-C cross-fade begins, and no more than two ambients play at once.

---

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

```gdscript
# ambient_controller.gd

const AMBIENT_CROSSFADE_TIME: float = 1.5
const CROSSFADE_CANCEL_THRESHOLD: float = 0.5

var _current_room: StringName = ""
var _current_player: AudioStreamPlayer = null
var _fade_out_player: AudioStreamPlayer = null
var _fade_in_player: AudioStreamPlayer = null
var _fade_progress: float = 0.0
var _is_fading: bool = false
var _time_in_room: float = 0.0

func _process(delta: float) -> void:
	if _is_fading:
		_fade_progress += delta / AMBIENT_CROSSFADE_TIME
		# Fade out old
		if _fade_out_player and _fade_out_player.playing:
			var vol: float = clampf(1.0 - _fade_progress, 0.0, 1.0)
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), linear_to_db(vol))
		# Fade in new
		if _fade_in_player and _fade_in_player.playing:
			var vol: float = clampf(_fade_progress, 0.0, 1.0)
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), linear_to_db(vol))
		if _fade_progress >= 1.0:
			_commit_fade()

func on_player_entered_room(room_id: StringName) -> void:
	_time_in_room = 0.0
	if _is_fading:
		# AC-AUD-05: Cancel current fade, start fresh
		_cancel_fade()
	_start_fade(room_id)

func on_player_exited_room(room_id: StringName) -> void:
	_time_in_room += get_process_delta_time()
	if _is_fading and _time_in_room < CROSSFADE_CANCEL_THRESHOLD:
		# AC-AUD-04: Cancel threshold not exceeded — cancel fade
		_cancel_fade()

func _cancel_fade() -> void:
	if _fade_out_player and _fade_out_player.playing:
		_fade_out_player.stop()
	if _fade_in_player and _fade_in_player.playing:
		_fade_in_player.stop()
	if _current_player:
		_current_player.play()
	_is_fading = false
	_fade_progress = 0.0
	_fade_out_player = null
	_fade_in_player = null

func _commit_fade() -> void:
	if _fade_out_player and _fade_out_player.playing:
		_fade_out_player.stop()
	_current_player = _fade_in_player
	_is_fading = false
	_fade_progress = 0.0
```

*Derived from GDD Edge Cases:*

- If player_entered_room fires during cross-fade: cancel current fade, snap outgoing to silent, start fresh cross-fade. Never layer 3 ambients.
- If player exits new room within CROSSFADE_CANCEL_THRESHOLD (0.5s): cancel cross-fade, snap back to original.
- Cross-fade completion: tier variant swap happens AFTER cross-fade completes (tier changes don't interrupt cross-fades).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Bus creation (prerequisite, already done)
- [Story 003]: Per-room reverb parameter updates (separate concern)
- [Story 006]: Audio state machine transitions (ambient is one state, not the state machine itself)
- [Night Progression Epic]: configure_audio_for_night() tier variant swapping (called after cross-fade)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AUD-03**: Normal cross-fade
  - Given: Player in entry_hall, ambient playing
  - When: player_entered_room("main_classroom") fires
  - Then: entry_hall ambient fades to silent over 1.5s; main_classroom ambient fades in over 1.5s; never 3+ ambients simultaneously
  - Edge cases: Identical rooms (already in target) → no fade; rapid re-entry during fade → cancel and restart

- **AC-AUD-04**: Cross-fade cancel via exit
  - Given: Cross-fade from A to B in progress
  - When: player_exited_room fires within 0.5s of entering B
  - Then: Cross-fade cancels; A snaps back to full volume; B ambient stops
  - Edge cases: Exit after 0.5s → commit to B (not a cancel); exit after fade completes → no-op (already committed)

- **AC-AUD-05**: Rapid room transitions
  - Given: Cross-fade from A to B in progress
  - When: player_entered_room("room_c") fires before fade completes
  - Then: A-to-B fade cancels (A snaps silent); fresh B-to-C cross-fade begins; never 3+ ambients
  - Edge cases: Three rapid transitions (A→B→C→D) → only last transition committed; intermediate fades all cancelled

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/audio/ambient_crossfade_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (buses created, pools allocated)
- Unlocks: Story 003 (reverb updates on room change), Story 006 (audio state depends on current room)
