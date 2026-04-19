# Story 003: Room Reverb & Spatial Audio Pool

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUD-005`, `TR-AUD-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Audio System)
**ADR Decision Summary**: SFXManager manages AudioStreamPlayer3D pool. Attenuation: inverse distance squared. Max distance 15m. Pool eviction: quietest source evicted when full. Per-room reverb on SFX_Spatial bus.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: RoomData includes reverb_type. Per-room reverb parameters from RoomData.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure. Static typing.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: AudioEffectReverb on bus. AudioStreamPlayer3D.position for spatialization. PhysicsWorldQueryParameters3D for distance check. Pool management via _free() on finished signal.

**Control Manifest Rules (Foundation layer)**:
- Required: Spatial SFX auto-freed when finished
- Guardrail: No audio in _process — spatial SFX triggered by events

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] AC-AUD-06: GIVEN the player enters cubby_hall, WHEN the cross-fade completes, THEN the AudioEffectReverb on SFX_Spatial bus has Room Size 0.6 and Damping 0.2 matching the cubby_hall spec.

- [ ] AC-AUD-11: GIVEN a spatial SFX at base 0dB, WHEN the source is 4m from the listener, THEN volume is -6dB (+/-0.1dB). At 8m: -12dB. At 2m or closer: 0dB (clamped at base).

- [ ] AC-AUD-12: GIVEN play_spatial_sfx is called with a position > 15m from the listener, WHEN the call executes, THEN no pool slot is allocated, no sound plays, and the function returns without error.

- [ ] AC-AUD-13: GIVEN all 8 spatial pool slots are occupied, WHEN play_spatial_sfx is called for a 9th sound, THEN the slot with the lowest effective volume at the listener is evicted and the new sound plays. Equal volume ties evict the oldest.

---

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

```gdscript
# sfx_manager.gd — spatial audio and reverb

const MAX_SPATIAL_DISTANCE: float = 15.0
const REFERENCE_DISTANCE: float = 2.0

var _pool: Array[AudioStreamPlayer3D] = []
var _current_room: StringName = ""

# Per-room reverb params [room_size, damping]
const REVERB_PARAMS: Dictionary = {
	&"entry_hall": [0.5, 0.5],
	&"main_classroom": [0.7, 0.4],
	&"art_corner": [0.3, 0.7],
	&"cubby_hall": [0.6, 0.2],
	&"nap_room": [0.4, 0.8],
	&"bathroom": [0.5, 0.1],
	&"principals_office": [0.4, 0.6],
}

func _ready() -> void:
	for i in 8:
		var player := AudioStreamPlayer3D.new()
		player.bus = "SFX_Spatial"
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARED
		player.attenuation_distance_scale = REFERENCE_DISTANCE
		player.max_distance = MAX_SPATIAL_DISTANCE * 100.0  # Godot's max_distance is in world units
		_pool.append(player)
		player.connect("finished", player, "queue_free")

func play_spatial_sfx(position: Vector3, stream: AudioStream, bus: StringName = &"SFX_Spatial") -> void:
	# AC-AUD-12: Distance cull
	var listener_pos: Vector3 = _get_listener_position()
	var distance: float = position.distance_to(listener_pos)
	if distance > MAX_SPATIAL_DISTANCE:
		return

	# AC-AUD-13: Pool eviction
	var slot: AudioStreamPlayer3D = _get_available_slot()
	if slot == null:
		_evict_quietest(listener_pos)
		slot = _pool[0]  # First slot now available

	slot.position = position
	slot.stream = stream
	slot.play()

func _get_available_slot() -> AudioStreamPlayer3D:
	for player in _pool:
		if not player.playing:
			return player
	return null

func _evict_quietest(listener_pos: Vector3) -> void:
	var min_vol_db: float = INF
	var evict_idx: int = 0
	for i in range(_pool.size()):
		var player := _pool[i] as AudioStreamPlayer3D
		if player.playing:
			var dist: float = player.position.distance_to(listener_pos)
			var vol_db: float = _calculate_volume_db(player.base_volume_db, dist)
			if vol_db < min_vol_db:
				min_vol_db = vol_db
				evict_idx = i
			elif vol_db == min_vol_db and player.play_time < _pool[evict_idx].play_time:
				# Equal volume: evict oldest
				evict_idx = i
	_pool[evict_idx].stop()

func _calculate_volume_db(base_db: float, distance: float) -> float:
	var effective_dist: float = max(distance, REFERENCE_DISTANCE)
	return base_db - 20.0 * log(effective_dist / REFERENCE_DISTANCE) / log(10.0)

func update_reverb_for_room(room_id: StringName) -> void:
	if not REVERB_PARAMS.has(room_id):
		return
	var params: Array[float] = REVERB_PARAMS[room_id]
	var bus_idx: int = AudioServer.get_bus_index("SFX_Spatial")
	var reverb_effect: AudioEffectReverb = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectReverb
	if reverb_effect:
		reverb_effect.room_size = params[0]
		reverb_effect.room_diffusion = params[1]
```

*Derived from GDD Spatial Parameters:*

- Attenuation: ATTENUATION_INVERSE_DISTANCE_SQUARED
- Reference distance: 2.0m (full volume at arm's length)
- Max distance: 15m. Beyond 15m: do not play, save pool slot.
- If pool full: evict quietest source. Equal volume ties evict oldest.

*Derived from GDD Per-Room Reverb:*

- Each room has Room Size and Damping values
- Updated on player_entered_room after cross-fade completes
- Bathroom has longest reverb tail (0.5 size, 0.1 damping)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Pool node creation (prerequisite, already done)
- [Story 002]: Ambient cross-fade timing (reverb update is called after cross-fade)
- [Story 004]: Footstep surface raycasting (uses SFX_World, not spatial)
- [Story 005]: Monster breathing proximity (uses play_spatial_sfx but separate logic)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AUD-06**: Per-room reverb
  - Given: Player enters cubby_hall, cross-fade completes
  - When: Query SFX_Spatial bus reverb effect
  - Then: Room Size = 0.6, Damping = 0.2
  - Edge cases: Room not in REVERB_PARAMS → no change; reverb effect not on bus → no error (silently skip)

- **AC-AUD-11**: Spatial attenuation
  - Given: Spatial SFX at base 0dB
  - When: Source is at various distances from listener
  - Then: 2m → 0dB; 4m → -6dB; 8m → -12dB; 15m → -17.5dB
  - Edge cases: Distance < 2m → clamped at base (0dB); distance = 0 → clamped at base (0dB)

- **AC-AUD-12**: Distance cull
  - Given: play_spatial_sfx called with position > 15m
  - When: Call executes
  - Then: No pool slot allocated, no sound plays, function returns without error
  - Edge cases: Exactly 15m → plays; 15.1m → no play

- **AC-AUD-13**: Pool eviction
  - Given: All 8 spatial pool slots occupied
  - When: play_spatial_sfx called for 9th sound
  - Then: Quietest source evicted, new sound plays
  - Edge cases: All sources equal volume → evict oldest; evicted source is at equal volume → evict oldest among ties

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/audio/spatial_audio_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (pool nodes created)
- Unlocks: Story 005 (monster breathing uses spatial SFX), Story 006 (audio states use spatial SFX)
