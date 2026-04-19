# Story 004: Footstep System

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUD-007`, `TR-AUD-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Audio System)
**ADR Decision Summary**: Footstep rate from STEP_STRIDE_LENGTH / current_speed. Surface-typed via downward raycast on mesh surface_tag. Random pitch +/-4%. Running: step rate doubles, pitch +8%, volume +2dB.

**ADR Governing Implementation**: ADR-0004 (Data-Driven Design)
**ADR Decision Summary**: Surface types from RoomData mesh metadata. Default fallback: LINOLEUM.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: Static typing. System-based directory structure.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: PhysicsDirectSpaceState3D for downward raycast. AudioStreamPlayer for non-spatial footstep. Division guarded at speed 0.

**Control Manifest Rules (Foundation layer)**:
- Required: Footstep rate = STEP_STRIDE_LENGTH / current_speed
- Guardrail: Division guarded at speed 0 (no footstep fires)

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] AC-AUD-07: GIVEN the player walks at 2.0 m/s on any surface, WHEN the footstep system runs, THEN one footstep fires every 0.4s (+/-0.01s), with pitch randomly varied +/-4%, using the correct surface bank.

- [ ] AC-AUD-08: GIVEN the player runs at 4.0 m/s, WHEN footsteps fire, THEN step interval is 0.2s (+/-0.01s), pitch is +8% (+/-0.5%), volume is +2dB (+/-0.1dB) from base.

- [ ] AC-AUD-09: GIVEN the player is stationary (speed 0), WHEN the footstep system evaluates, THEN no division-by-zero occurs and no footstep fires.

- [ ] AC-AUD-10: GIVEN the FPC is in Camera Raised state (1.5 m/s), WHEN footsteps fire, THEN step interval is ~0.533s (+/-0.01s), audio state remains AMBIENT_NORMAL, and no running modifiers apply.

---

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

```gdscript
# footstep_system.gd

const STEP_STRIDE_LENGTH: float = 0.8

var _step_timer: float = 0.0
var _current_speed: float = 0.0
var _is_running: bool = false
var _current_surface: StringName = &"LINOLEUM"

# Surface-to-variation count mapping
const SURFACE_VARIATIONS: Dictionary = {
	&"LINOLEUM": 4,
	&"CARPET_LOW": 3,
	&"CARPET_THICK": 3,
	&"TILE": 4,
	&"WOOD": 3,
}

func _physics_process(delta: float) -> void:
	if _current_speed == 0.0:
		_step_timer = 0.0
		return

	var step_interval: float = STEP_STRIDE_LENGTH / _current_speed
	_step_timer += delta
	if _step_timer >= step_interval:
		_step_timer -= step_interval
		_play_footstep()

func _play_footstep() -> void:
	var variation_count: int = SURFACE_VARIATIONS.get(_current_surface, 4)
	var variation_idx: int = randi() % variation_count
	var pitch_scale: float = 1.0 + (randf() - 0.5) * 0.08  # +/-4%

	if _is_running:
		pitch_scale *= 1.08  # +8% when running

	var player: AudioStreamPlayer = _get_next_sfx_player()
	if player:
		player.pitch_scale = pitch_scale
		# Volume boost for running
		if _is_running:
			var bus_idx: int = AudioServer.get_bus_index("SFX_World")
			var current_db: float = AudioServer.get_bus_volume_db(bus_idx)
			AudioServer.set_bus_volume_db(bus_idx, current_db + 2.0)
		player.play()
		if _is_running:
			AudioServer.set_bus_volume_db(bus_idx, current_db)

func _update_surface(player_position: Vector3) -> void:
	# Downward raycast to get surface_tag from mesh metadata
	var space: PhysicsDirectSpaceState3D = get_world_3d().get_direct_space_state()
	var query := PhysicsRayQueryParameters3D.create(player_position, player_position + Vector3.DOWN * 0.5)
	var result := space.intersect_ray(query)
	if result.has("custom_data") and result["custom_data"] is StringName:
		_current_surface = result["custom_data"]
	else:
		_current_surface = &"LINOLEUM"  # Default fallback
```

*Derived from GDD Formulas:*

- step_interval(S) = STEP_STRIDE_LENGTH / S
- Walking (2.0 m/s): 0.8 / 2.0 = 0.4s
- Camera raised (1.5 m/s): 0.8 / 1.5 = 0.533s
- Running (4.0 m/s): 0.8 / 4.0 = 0.2s
- At speed 0: no footsteps (division guarded)

*Derived from GDD Footstep Surface Types:*

- LINOLEUM: Entry Hall, Cubby Hall — 4 variations, hard slap
- CARPET_LOW: Main Classroom, Art Corner — 3 variations, muffled
- CARPET_THICK: Nap Room — 3 variations, near-silent
- TILE: Bathroom — 4 variations, hard + wet
- WOOD: Principal's Office — 3 variations, creak

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: SFX_World bus creation (prerequisite)
- [Story 002]: Ambient cross-fade (surface raycast is independent)
- [Story 003]: Spatial audio pool (footsteps are non-spatial, SFX_World bus)
- [Story 006]: Audio state machine (footstep rate reads from FPC state but doesn't manage states)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AUD-07**: Walking footsteps
  - Given: Player walks at 2.0 m/s on LINOLEUM
  - When: Footstep system runs for 5 seconds
  - Then: ~12-13 footsteps fire (0.4s interval, +/-0.01s tolerance); pitch within +/-4% of 1.0; LINOLEUM surface bank used
  - Edge cases: Surface raycast fails → fallback to LINOLEUM; surface not in map → fallback to LINOLEUM

- **AC-AUD-08**: Running footsteps
  - Given: Player runs at 4.0 m/s
  - When: Footsteps fire
  - Then: 0.2s interval (+/-0.01s); pitch +8% (+/-0.5%); volume +2dB from base
  - Edge cases: Running on CARPET_THICK → still +8% pitch, +2dB but quieter base volume

- **AC-AUD-09**: Stationary guard
  - Given: Player speed = 0
  - When: Footstep system evaluates for 10 seconds
  - Then: No footstep fires; no assertion failure or division-by-zero error
  - Edge cases: Speed transitions from 0.1 to 0 → step timer resets immediately

- **AC-AUD-10**: Camera raised footsteps
  - Given: FPC in Camera Raised state (1.5 m/s)
  - When: Footsteps fire
  - Then: ~0.533s interval (+/-0.01s); no running modifiers (+8% pitch, +2dB); audio state remains AMBIENT_NORMAL
  - Edge cases: Camera raised while running → use camera speed (1.5 m/s), not running speed

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/audio/footstep_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (SFX_World bus exists)
- Unlocks: Story 006 (audio states read footstep state), Monster AI (footstep volume feeds detection)
