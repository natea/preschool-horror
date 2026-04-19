# Story 001: Audio Bus Architecture & Web Autoplay

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AUD-001`, `TR-AUD-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Audio System)
**ADR Decision Summary**: 6-bus system (Music, Ambient, SFX_World, SFX_Spatial, UI, Voice) all routing to Master. Pre-allocated AudioStreamPlayer nodes. Web: all buses muted, first user input un-mutes.

**ADR Governing Implementation**: ADR-0005 (Rendering)
**ADR Decision Summary**: Web audio decoder budget (max 8 concurrent). Autoplay policy: first audio requires user input.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: System-based directory structure. No Autoloads.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: AudioServer bus management. AudioStreamPlayer pre-allocation in _ready(). Web export: AudioServer set_bus_mute() for autoplay compliance.

**Control Manifest Rules (Foundation layer)**:
- Required: All audio routes through AudioManager (no direct AudioStreamPlayer creation outside manager)
- Required: All audio streams preloaded via preload() — no dynamic loading
- Guardrail: Spatial SFX instances auto-freed when finished

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`, scoped to this story:*

- [ ] AC-AUD-01: GIVEN the Audio System scene is loaded, WHEN _ready() completes, THEN AudioServer exposes buses named Master, Ambient, Music, SFX_World, SFX_Spatial, UI, and Voice, all routing to Master, and 6 non-spatial + 8 spatial AudioStreamPlayer nodes exist pre-allocated in stopped state.

- [ ] AC-AUD-02: GIVEN a web export with no user input yet, WHEN scene loads, THEN all buses are muted and no audio plays. WHEN the first discrete input event fires (key, mouse button, or gamepad button — NOT mouse motion), THEN all buses un-mute and room ambient begins.

---

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

```gdscript
# audio_manager.gd — bus architecture and autoplay

class_name AudioManager extends Node

const BUS_NAMES: Array[StringName] = [
	&"Master", &"Ambient", &"Music", &"SFX_World",
	&"SFX_Spatial", &"UI", &"Voice"
]

const SFX_POOL_2D_SIZE: int = 6
const SFX_POOL_3D_SIZE: int = 8

var _sfx_pool_2d: Array[AudioStreamPlayer] = []
var _sfx_pool_3d: Array[AudioStreamPlayer3D] = []
var _is_muted: bool = true
var _has_unmuted: bool = false

func _ready() -> void:
	_create_buses()
	_preallocate_sfx_pools()
	_setup_autoplay_guard()

func _create_buses() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus(bus_name)
	AudioServer.set_bus_send("Ambient", "Master")
	AudioServer.set_bus_send("Music", "Master")
	AudioServer.set_bus_send("SFX_World", "Master")
	AudioServer.set_bus_send("SFX_Spatial", "Master")
	AudioServer.set_bus_send("UI", "Master")
	AudioServer.set_bus_send("Voice", "Master")

func _preallocate_sfx_pools() -> void:
	for i in SFX_POOL_2D_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX_World"
		player.playback_mode = AudioStreamPlayer.PLAYBACK_MODE_BUFFERED
		_sfx_pool_2d.append(player)
		add_child(player)
	for i in SFX_POOL_3D_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = "SFX_Spatial"
		player.playback_mode = AudioStreamPlayer3D.PLAYBACK_MODE_BUFFERED
		_sfx_pool_3d.append(player)
		add_child(player)

func _setup_autoplay_guard() -> void:
	# Web: start muted, un-mute on first discrete input
	_is_muted = true
	for bus_name in BUS_NAMES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_mute(idx, true)

func _unmute_all() -> void:
	if _has_unmuted:
		return
	_has_unmuted = true
	_is_muted = false
	for bus_name in BUS_NAMES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_mute(idx, false)

func _process_input(event: InputEvent) -> void:
	if _has_unmuted:
		return
	# Only discrete input: key, mouse button, gamepad button
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		_unmute_all()
```

*Derived from ADR-0005 Web Constraints:*

- Web: max 8 concurrent audio decoders — SFX_POOL_3D_SIZE = 8 is the hard limit
- Autoplay: browsers block audio until user interaction — all buses start muted
- Discrete input only: key, mouse button, gamepad button. NOT mouse motion (scroll = continuous, not discrete)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Ambient cross-fade logic (bus creation is prerequisite only)
- [Story 003]: Spatial audio pool management and attenuation (pool is created here, eviction logic in Story 003)
- [Story 004]: Footstep system (uses SFX_World bus but is separate logic)
- [Story 007]: Music ducking (uses Music/Voice buses but separate priority logic)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AUD-01**: Bus architecture and pool pre-allocation
  - Given: Audio System scene loaded, _ready() completes
  - When: Query AudioServer and pool state
  - Then: All 7 buses exist and route to Master; 6 SFX_World + 8 SFX_Spatial players pre-allocated in stopped state
  - Edge cases: Duplicate bus name (already exists) → no error; pool node count mismatch → assert failure

- **AC-AUD-02**: Web autoplay compliance
  - Given: Web export, scene loads with no user input
  - When: Check bus mute state
  - Then: All buses muted, no audio plays
  - Edge cases: Mouse scroll (not discrete) → buses stay muted; key press → un-mute; gamepad button → un-mute; second discrete input after un-mute → no-op (already unmuted)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/audio/bus_arch_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (ambient cross-fade needs buses), Story 003 (spatial audio needs pools), Story 004 (footsteps need SFX_World bus)
