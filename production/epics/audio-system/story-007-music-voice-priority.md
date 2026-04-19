# Story 007: Music & Voice Priority

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUD-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Audio System)
**ADR Decision Summary**: Music ducks -6dB when Voice bus active (boss dialogue takes priority). Two music events only: boss_debrief and night_7_escape.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Voice bus activation triggers music ducking. No signal chains.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: Static typing. System-based directory structure.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: AudioServer.set_bus_volume_db() for ducking. Detect Voice bus activity via playback monitoring or signal from VoiceController.

**Control Manifest Rules (Foundation layer)**:
- Required: Music ducks -6dB when Voice active, restores over 0.1s when Voice silent
- Guardrail: Only two valid music event IDs: boss_debrief and night_7_escape

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] AC-AUD-18: GIVEN boss debrief melody plays on Music bus, WHEN Voice bus becomes active, THEN Music bus ducks by 6dB over 0.1s. WHEN Voice goes silent, THEN Music restores over 0.1s.

---

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

```gdscript
# music_voice_priority.gd — music ducking for voice

const MUSIC_DUCK_DB: float = -6.0
const DUCK_RESTORE_TIME: float = 0.1

var _music_base_volume_db: float = 0.0
var _is_ducked: bool = false
var _restore_timer: float = 0.0

func _ready() -> void:
	_music_base_volume_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))

func on_voice_started() -> void:
	if _is_ducked:
		return
	_is_ducked = true
	var music_bus: int = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music_bus, _music_base_volume_db + MUSIC_DUCK_DB)

func on_voice_finished() -> void:
	if not _is_ducked:
		return
	_restore_timer = DUCK_RESTORE_TIME

func _process(delta: float) -> void:
	if _is_ducked and _restore_timer > 0.0:
		_restore_timer -= delta
		if _restore_timer <= 0.0:
			# Restore music
			var music_bus: int = AudioServer.get_bus_index("Music")
			AudioServer.set_bus_volume_db(music_bus, _music_base_volume_db)
			_is_ducked = false
			_restore_timer = 0.0
```

*Derived from ADR-0009 Music System:*

- Music operates independently of Ambient. Both can play simultaneously.
- Music ducks -6dB when Voice bus active.
- Only two valid music event IDs: `&"boss_debrief"` and `&"night_7_escape"`.
- Boss debrief melody: thin, mechanical music-box. Four bars, major key, slightly detuned.
- Night 7 escape: chaotic, pitched-down children's songs + industrial percussion.

*Derived from GDD Music — Two Uses Only:*

- Boss Debrief Melody: degrades across nights (Nights 1-2 clean, Nights 3-4 degrading, Nights 5-6 barely recognizable, Night 7 silence).
- Night 7 Escape: only full non-diegetic music cue. Plays for escape sequence duration.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Music bus creation (prerequisite)
- [Story 002]: Boss debrief melody composition and night variants (asset-level concern)
- [Story 003]: Night 7 escape music (asset-level concern)
- [Story 008]: Nap Room music box (separate audio event, not Music bus)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AUD-18**: Music ducking for voice
  - Given: Boss debrief melody playing on Music bus at base volume
  - When: Voice bus becomes active
  - Then: Music bus ducks by 6dB over 0.1s
  - Edge cases: Voice bus active while already ducked → no-op; Voice goes silent → restore over 0.1s; rapid voice on/off → each triggers duck/restore cycle

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/audio/music_voice_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (Music and Voice buses exist)
- Unlocks: Evidence Submission integration (boss debrief melody), Night Progression integration (Night 7 escape)
