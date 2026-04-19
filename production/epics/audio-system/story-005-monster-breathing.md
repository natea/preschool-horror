# Story 005: Monster Breathing & Proximity Audio

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUD-009`, `TR-AUD-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Audio System)
**ADR Decision Summary**: When monster_proximity(distance) < MONSTER_BREATHING_THRESHOLD (8m), play spatialized breathing from monster position. Continuous looping, volume scales inversely with distance. Fade in 2s, fade out 3s. Cap at 2 simultaneous breathing sources.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Monster AI sends monster_proximity signal every AI tick.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: MONSTER_BREATHING_THRESHOLD from constants. Monster audio from MonsterConfig.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: AudioStreamPlayer3D for spatialized breathing. Continuous volume update via _process or timer. Fade in/out via volume tween. Pool slot management for 2-source cap.

**Control Manifest Rules (Foundation layer)**:
- Required: Spatial SFX auto-freed when finished
- Guardrail: Max 2 simultaneous breathing sources (separate counter, overrides pool eviction)

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] AC-AUD-14: GIVEN a monster is beyond 8m (no breathing), WHEN monster_proximity(7.0, position) fires, THEN spatialized breathing begins from the reported position and reaches target volume over 2s. WHEN the monster moves beyond 8m, THEN breathing fades out over 3s before the pool slot is released.

- [ ] AC-AUD-15: GIVEN two monsters are within 8m with breathing active (2 pool slots), WHEN a third monster enters within 8m, THEN no third breathing source starts. The 2-source breathing cap is enforced via a separate counter, overriding the normal pool eviction rule.

---

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

```gdscript
# monster_audio.gd — breathing and proximity audio

const MONSTER_BREATHING_THRESHOLD: float = 8.0
const BREATHING_FADE_IN: float = 2.0
const BREATHING_FADE_OUT: float = 3.0
const MAX_BREATHING_SOURCES: int = 2

var _breathing_players: Array[AudioStreamPlayer3D] = []
var _breathing_count: int = 0
var _breathing_monsters: Array[Vector3] = []
var _fade_direction: StringName = &"none"
var _fade_progress: float = 0.0

func monster_proximity(distance: float, position: Vector3) -> void:
	if distance >= MONSTER_BREATHING_THRESHOLD:
		_remove_breathing_for_position(position)
		return

	# AC-AUD-15: Check breathing cap
	if _breathing_count >= MAX_BREATHING_SOURCES and not _breathing_monsters.has(position):
		return  # Cap reached, ignore new monster

	# Start or update breathing
	var player: AudioStreamPlayer3D = _find_or_create_breathing_player(position)
	if player:
		player.position = position
		if not player.playing:
			_start_breathing_fade_in(player)

func _find_or_create_breathing_player(position: Vector3) -> AudioStreamPlayer3D:
	# Check if we already have a player for this monster
	for i in range(_breathing_players.size()):
		if _breathing_monsters[i] == position:
			return _breathing_players[i]

	# No existing player — allocate from pool
	var pool_slot: AudioStreamPlayer3D = _get_pool_slot()
	if pool_slot == null:
		return null  # Pool full (shouldn't happen with 8 slots and cap of 2)

	_breathing_players.append(pool_slot)
	_breathing_monsters.append(position)
	_breathing_count += 1
	return pool_slot

func _start_breathing_fade_in(player: AudioStreamPlayer3D) -> void:
	_fade_direction = &"in"
	_fade_progress = 0.0
	player.play()

func _process(delta: float) -> void:
	if _fade_direction == &"in" and _fade_progress < 1.0:
		_fade_progress += delta / BREATHING_FADE_IN
		var vol: float = clampf(_fade_progress, 0.0, 1.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX_Spatial"), linear_to_db(vol))
		if _fade_progress >= 1.0:
			_fade_direction = &"none"
	elif _fade_direction == &"out" and _fade_progress < 1.0:
		_fade_progress += delta / BREATHING_FADE_OUT
		var vol: float = clampf(1.0 - _fade_progress, 0.0, 1.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX_Spatial"), linear_to_db(vol))
		if _fade_progress >= 1.0:
			_stop_all_breathing()

func _remove_breathing_for_position(position: Vector3) -> void:
	var idx: int = _breathing_monsters.find(position)
	if idx >= 0:
		_breathing_players[idx].stop()
		_breathing_players[idx] = null
		_breathing_monsters.remove(idx)
		_breathing_count -= 1
		if _breathing_count > 0 and _fade_direction == &"none":
			_fade_direction = &"out"
			_fade_progress = 0.0

func _stop_all_breathing() -> void:
	for player in _breathing_players:
		if player:
			player.stop()
	_breathing_players.clear()
	_breathing_monsters.clear()
	_breathing_count = 0
	_fade_direction = &"none"
	_fade_progress = 0.0
```

*Derived from GDD Monster Proximity Breathing:*

- Threshold: 8m — breathing audible when monster within range
- Continuous looping, volume scales inversely with distance
- Fade in: 2s on first detection; fade out: 3s when monster moves beyond threshold
- Primary audio signature — heard before seen
- Cap at 2 simultaneous breathing sources to preserve pool slots

*Derived from GDD Edge Cases:*

- Monster in LOCKED room beyond walls: still play breathing (intentional horror — player hears what they can't reach)
- Two monsters within threshold: play both from separate pool slots
- Wall occlusion: not implemented (preschool too small, wall occlusion reduces rather than enhances dread)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: Spatial audio pool management (breathing uses pool from SFXManager)
- [Monster AI Epic]: Monster position tracking and proximity calculation (breathing is audio response, not detection)
- [Story 006]: Audio state machine (breathing is independent of audio state)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AUD-14**: Breathing fade in/out
  - Given: Monster at 9m (beyond threshold), no breathing
  - When: monster_proximity(7.0, position) fires
  - Then: Spatialized breathing starts from position; reaches full volume over 2s
  - Edge cases: Monster moves to 9m → fade out over 3s, then pool slot released; multiple proximity updates within fade-in → no restart, continue current fade

- **AC-AUD-15**: Two-source breathing cap
  - Given: Two monsters at 5m and 6m, both breathing active
  - When: Third monster enters at 4m
  - Then: No third breathing source starts; breathing cap enforced
  - Edge cases: First monster moves to 10m → its breathing stops, third monster can now start breathing; two monsters at same position → treated as one source

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/audio/monster_breathing_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 must be DONE (spatial audio pool available)
- Unlocks: Story 006 (audio state reads breathing status), Monster AI integration
