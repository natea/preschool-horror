# Story 008: Nap Room Music Box Arc

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUD-014`, `TR-AUD-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Audio System)
**ADR Decision Summary**: Nap Room silence violation arc. Night 3: music box 8-12s after entry, single note then 4-note nursery rhyme fragment, 3D-spatialized from under a cot. Nights 4-5: longer, resumes on re-entry at different note. Night 6: photographable anomaly, post-photograph breath from behind player.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: nap_room_music_box_triggered signal from Audio System. Anomaly System connects to photograph completion.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: NAP_ROOM_MUSICBOX_DELAY constant. Night-dependent behavior from Night Progression.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Timer-based trigger (not physics_process). AudioStreamPlayer3D for spatialized music box. Post-photograph breath from behind player position.

**Control Manifest Rules (Foundation layer)**:
- Guardrail: Music box does NOT play if player exits before trigger delay
- Guardrail: Max 1 music box trigger per room entry (resets on exit)

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] AC-AUD-19: GIVEN the player enters the Nap Room on Night 3, WHEN the player exits before 8 seconds, THEN the music box does NOT play, the timer resets, and re-entry restarts the 8-12s delay from zero.

- [ ] AC-AUD-20: GIVEN the Nap Room music box has been photographed on Night 6, WHEN the photograph completes, THEN all Nap Room sound stops, a single spatialized breath fires from behind the player, and re-entry later that night produces no music box or breath.

---

## Implementation Notes

*Derived from GDD Nap Room Silence Violation Arc:*

```gdscript
# nap_room_music_box.gd

const NAP_ROOM_MUSICBOX_DELAY_MIN: float = 8.0
const NAP_ROOM_MUSICBOX_DELAY_MAX: float = 12.0

var _current_room: StringName = ""
var _entry_timer: float = 0.0
var _trigger_delay: float = 0.0
var _is_triggered: bool = false
var _has_been_photographed: bool = false
var _current_night: int = 1

func on_player_entered_room(room_id: StringName) -> void:
	if room_id != &"nap_room":
		return
	_current_room = room_id
	_entry_timer = 0.0
	_is_triggered = false
	_has_been_photographed = false
	# Set trigger delay based on night
	_trigger_delay = _get_night_delay()
	_entry_timer = 0.0

func on_player_exited_room(room_id: StringName) -> void:
	if room_id != &"nap_room":
		return
	_current_room = ""
	_entry_timer = 0.0
	_is_triggered = false
	_has_been_photographed = false

func _process(delta: float) -> void:
	if _current_room != &"nap_room" or _is_triggered:
		return
	_entry_timer += delta
	if _entry_timer >= _trigger_delay:
		_trigger_music_box()

func _trigger_music_box() -> void:
	_is_triggered = true
	if _current_night == 3:
		_play_night3_music_box()
	elif _current_night >= 4 and _current_night <= 5:
		_play_night45_music_box()
	elif _current_night == 6 and not _has_been_photographed:
		# Night 6: music box is a photographable anomaly, not audio-only
		pass  # Visual anomaly, audio plays on photograph

func _play_night3_music_box() -> void:
	# Single note, then 4-note nursery rhyme fragment
	# 3D-spatialized from under a specific cot
	var cot_position := _get_cot_position()
	play_spatial_sfx(cot_position, preload("res://audio/sfx/nap_room_music_box_3.ogg"))

func _play_night45_music_box() -> void:
	# Longer duration (15-20s), resumes on re-entry at different starting note
	var cot_position := _get_cot_position()
	var player := AudioStreamPlayer3D.new()
	player.stream = preload("res://audio/sfx/nap_room_music_box_45.ogg")
	player.position = cot_position
	player.bus = "SFX_Spatial"
	add_child(player)
	player.play()
	player.connect("finished", player, "queue_free")

func on_music_box_photographed() -> void:
	if _current_night != 6:
		return
	_has_been_photographed = true
	# All Nap Room sound stops
	# Single spatialized breath from behind player
	var breath_pos := _position_behind_player()
	play_spatial_sfx(breath_pos, preload("res://audio/sfx/nap_room_breath.ogg"))

func _get_night_delay() -> float:
	if _current_night == 3:
		return NAP_ROOM_MUSICBOX_DELAY_MIN  # 8s for Night 3
	return NAP_ROOM_MUSICBOX_DELAY_MIN  # Default

func _position_behind_player() -> Vector3:
	var player_pos := _get_player_position()
	return player_pos + Vector3.BACK * 1.5  # 1.5m behind player

func _get_cot_position() -> Vector3:
	# Return position of a specific cot in the Nap Room
	return Vector3(2.0, 0.0, 3.0)  # Authored position
```

*Derived from GDD Night-by-Night Arc:*

- **Night 3**: 8-12s after entry, music box plays. Single note → 4-note nursery rhyme. 3D-spatialized from under cot. Duration 6-8s. No visual event.
- **Nights 4-5**: Plays on entry (2-3s delay). Longer duration (15-20s). Stops when player leaves. Resumes on re-entry at different starting note. Night 5: extra note, tempo slows.
- **Night 6**: Music box is photographable anomaly. Photographing stops all sound. Single wet breath from behind player. Re-entry silent.

*Derived from GDD Edge Cases:*

- Player exits before trigger delay: music box does NOT play, timer resets on re-entry.
- Player must commit to being in room to hear violation.
- Night 6 post-photograph: silence is harder than Tier 1 silence.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: Spatial audio pool (music box uses play_spatial_sfx)
- [Anomaly System]: Night 6 music box as photographable anomaly (visual component)
- [Story 005]: Monster breathing (separate proximity system)
- [Night Progression Epic]: Night number tracking (music box reads _current_night from Night Progression)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AUD-19**: Nap Room exit before trigger
  - Setup: Player enters Nap Room on Night 3
  - Verify: Player exits at 5 seconds (before 8s delay)
  - Pass condition: No music box plays; entry timer resets; re-entry at 8s triggers music box
  - Edge cases: Exit at 7.9s → no play; exit at 8.1s → music box already triggered; multiple entries/exits → each resets delay

- **AC-AUD-20**: Night 6 post-photograph silence
  - Setup: Player photographs music box on Night 6
  - Verify: All Nap Room sound stops; breath fires from behind player
  - Pass condition: Breath is spatialized from behind player position; re-entry later that night produces no music box or breath
  - Edge cases: Leave and re-enter same night → silent; photograph again → no double breath; Night 7 → no music box (player has left the preschool)

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Evidence: `production/qa/evidence/nap_room_music_box-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 must be DONE (spatial audio available), Story 006 must be DONE (audio states for Nap Room silence)
- Unlocks: Anomaly System integration (Night 6 music box as visual anomaly)
