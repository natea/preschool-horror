# ADR-0009: Audio System

## Status
**Accepted**

## Date
2026-04-19

## Context

The game is a horror title that relies heavily on audio for atmosphere. The audio system needs to support dynamic music (shifting with tension tiers), spatialized sound effects (monster sounds, anomaly sounds), ambient loops (room ambience), UI sounds, and voiceover (monster dialogue). It must work on both PC and Web targets.

The question is how to structure the audio system to support dynamic, spatialized, and layered audio while remaining performant and maintainable.

## Decision

Godot's `AudioStreamPlayer` and `AudioStreamPlayer3D` nodes are used with an `AudioManager` singleton for routing. Audio is organized into layers (ambient, SFX, music, UI, voice) with per-layer bus mixing. No custom audio engine or middleware is used.

### Audio Layers

| Layer | Bus Name | Purpose | Priority |
|-------|----------|---------|----------|
| **Music** | `MusicBus` | Dynamic music, tension shifts | High — only one music track plays at a time |
| **Ambient** | `AmbientBus` | Room ambience, environmental loops | Medium — multiple ambient tracks per room |
| **SFX** | `SFXBus` | Monster sounds, anomaly sounds, interaction sounds | High — many concurrent SFX |
| **Voice** | `VoiceBus` | Monster dialogue, voiceover | High — voice interrupts ambient music |
| **UI** | `UIBus` | Menu sounds, UI feedback | Low — minimal concurrent UI sounds |
| **Master** | `MasterBus` | Final output | N/A — all buses route to master |

### Audio Architecture

```
AudioManager (AudioManager.gd)
├── MusicController (MusicController.gd)
│   ├── plays tension-tier music
│   ├── crossfades between tiers
│   └── manages AudioStreamPlayer (MusicBus)
├── AmbientController (AmbientController.gd)
│   ├── plays room-specific ambience
│   ├── loops ambient tracks
│   └── manages AudioStreamPlayer (AmbientBus)
├── SFXManager (SFXManager.gd)
│   ├── plays one-shot SFX
│   ├── supports spatial and non-spatial audio
│   └── manages AudioStreamPlayer3D instances (SFXBus)
├── VoiceController (VoiceController.gd)
│   ├── plays voiceover clips
│   ├── interrupts ambient music
│   └── manages AudioStreamPlayer (VoiceBus)
└── UIController (UIController.gd)
    ├── plays UI feedback sounds
    ├── minimal concurrent sounds
    └── manages AudioStreamPlayer (UIBus)
```

### Key Interfaces

- **`AudioManager`** (singleton via `get_node("/root/AudioManager")`) — Central audio routing. All audio plays through this node.
- **`AudioStreamPlayer`** — Non-spatial audio (music, ambient, voice, UI)
- **`AudioStreamPlayer3D`** — Spatial audio (monster sounds, anomaly sounds, proximity SFX)
- **`AudioBus`** — Godot's bus system for mixing (6 buses: Music, Ambient, SFX, Voice, UI, Master)
- **`AudioStream`** — Audio resource (OGG/WAV files)
- **`AudioEffectDynamics`** — Compression for voice bus
- **`AudioEffectReverb`** — Reverb for room-specific audio (spatial)

### Music System

Dynamic music is handled by `MusicController`:

```gdscript
# music_controller.gd
class_name MusicController extends Node

@export var tension_tracks: Array[AudioStream]  # [calm, medium, high, terror]
@export var crossfade_duration: float = 2.0

var current_track_idx: int = 0
var player: AudioStreamPlayer

func _ready() -> void:
    player = AudioStreamPlayer.new()
    player.bus = "MusicBus"
    add_child(player)

func set_tension(tier: int) -> void:
    if tier == current_track_idx:
        return
    var new_track := tension_tracks[tier]
    player.stream = new_track
    player.play()
    current_track_idx = tier
```

### SFX System

Spatial SFX is handled by `SFXManager`:

```gdscript
# sfx_manager.gd
class_name SFXManager extends Node

func play_sfx(sfx: AudioStream, position: Vector3 = Vector3.ZERO, spatial: bool = false) -> void:
    if spatial:
        var player := AudioStreamPlayer3D.new()
        player.stream = sfx
        player.position = position
        player.bus = "SFXBus"
        add_child(player)
        player.play()
        # Auto-free when finished
        player.connect("finished", player, "queue_free")
    else:
        var player := AudioStreamPlayer.new()
        player.stream = sfx
        player.bus = "SFXBus"
        add_child(player)
        player.play()
        player.connect("finished", player, "queue_free")
```

### Room-Specific Audio

Each `RoomData` resource includes audio properties:

```gdscript
# room_data.gd
class_name RoomData extends Resource

@export var name: String
@export var ambient_track: AudioStream
@export var reverb_type: String = "room"  # room, corridor, large
@export var ambient_volume_db: float = -10.0
@export var ambient_min_distance: float = 5.0
@export var ambient_max_distance: float = 20.0
```

### Voiceover System

Voiceover interrupts ambient music:

```gdscript
# voice_controller.gd
class_name VoiceController extends Node

@onready var music_controller: MusicController = get_node("/root/AudioManager/MusicController")

var voice_player: AudioStreamPlayer

func _ready() -> void:
    voice_player = AudioStreamPlayer.new()
    voice_player.bus = "VoiceBus"
    add_child(voice_player)

func play_voice(voice_clip: AudioStream) -> void:
    voice_player.stream = voice_clip
    voice_player.play()
    # Pause music during voice
    music_controller.pause_music()
    voice_player.connect("finished", self, "_on_voice_finished")

func _on_voice_finished() -> void:
    music_controller.resume_music()
```

### Web-Specific Constraints

- **Audio format**: OGG Vorbis for music and long audio (smaller file size). WAV for short SFX (faster decoding).
- **Web audio limits**: Browsers limit concurrent audio decoders. Web target: max 8 concurrent audio decoders.
- **Autoplay policy**: Browsers block autoplay. First audio playback must be triggered by user input (e.g., first menu interaction).
- **Web audio quality**: OGG quality is reduced on Web target to save bandwidth. Quality is configurable via project settings.

### Technical Constraints

- **No audio in `_process`**: Audio playback is triggered by events, not continuous processing.
- **Auto-free spatial SFX**: `AudioStreamPlayer3D` instances are auto-freed when finished to prevent memory leaks.
- **No dynamic audio loading**: All audio streams are preloaded via `preload()` — no dynamic file loading.
- **Bus mixing**: All audio routes through the 6-bus system. No direct audio node creation outside the bus system.

## Alternatives

### Alternative: FMOD or Wwise middleware
- **Description**: Use professional audio middleware for advanced audio features
- **Pros**: Advanced audio features (spatialization, dynamic mixing, voice management); professional tooling
- **Cons**: Licensing cost; Godot integration requires plugin; overkill for this project's scope; adds external dependency
- **Rejection Reason**: Godot's built-in audio system is sufficient for this project's needs. FMOD/Wwise are overkill for an indie project with 17 systems.

### Alternative: No audio manager — direct node usage
- **Description**: Create `AudioStreamPlayer` nodes directly in each system without a manager
- **Pros**: Simpler; no indirection
- **Cons**: No centralized audio routing; no bus mixing; no volume control; harder to manage concurrent SFX
- **Rejection Reason**: The GDD requires layered audio with per-bus mixing. A centralized manager is needed for this architecture.

### Alternative: Custom audio engine
- **Description**: Build a custom audio engine with spatialization, reverb, and dynamic mixing
- **Pros**: Full control over audio behavior
- **Cons**: Reinventing Godot's audio system; no community support; high maintenance cost; Godot already has all needed features
- **Rejection Reason**: Godot's audio system provides all needed features (spatial audio, buses, reverb, streaming). A custom engine is unnecessary.

## Consequences

### Positive
- **Layered audio**: Music, SFX, voice, ambient, and UI are mixed independently via buses
- **Spatial audio**: Monster and anomaly sounds are spatialized in 3D
- **Dynamic music**: Music shifts with tension tiers via crossfading
- **Room-specific audio**: Each room has its own ambient track and reverb settings
- **Web compatibility**: Web-specific constraints are documented and handled

### Negative
- **Godot audio limitations**: Godot's audio system has limited spatialization features compared to FMOD/Wwise
- **Concurrent SFX limit**: Web has a max of 8 concurrent audio decoders — SFX budget must be managed
- **Autoplay policy**: First audio requires user interaction on Web

### Risks
- **SFX overflow**: Too many concurrent SFX on Web. **Mitigation**: Document Web SFX budget (8 decoders); prioritize important SFX; code review for SFX count.
- **Audio memory**: Too many preloaded audio streams consume memory. **Mitigation**: Use streaming for long audio (music, ambient); use memory mode for short SFX.
- **Autoplay blocking**: Web blocks initial audio. **Mitigation**: Document autoplay requirement; trigger first audio on first user interaction.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `audio-system.md` | Audio architecture | Layered bus system with dynamic music |
| `monster-ai.md` | Monster audio | Spatialized monster sounds via SFXManager |
| `anomaly-system.md` | Anomaly audio | Spatialized anomaly sounds via SFXManager |
| `night-progression.md` | Tension music | MusicController with tension-tier tracks |
| `room-management.md` | Room ambience | RoomData includes ambient track and reverb |
| `menu-navigation.md` | UI audio | UIBus for menu sounds |

## Performance Implications
- **CPU**: Audio mixing has minimal CPU cost (< 1 ms per frame). SFX decoding cost depends on format (OGG > WAV).
- **Memory**: Preloaded audio consumes memory. **Mitigation**: Stream long audio (music, ambient); use memory mode for short SFX.
- **Web**: Max 8 concurrent audio decoders on Web. SFX budget is tight — prioritize important sounds.
- **Autoplay**: First audio requires user interaction on Web. Document this constraint.

## Migration Plan

This is a new project — no migration needed. During implementation:

1. Create audio buses in project settings (Music, Ambient, SFX, Voice, UI, Master)
2. Create `AudioManager` singleton scene with all controllers
3. Create `MusicController`, `SFXManager`, `VoiceController`, `UIController`
4. Add audio properties to `RoomData` resource
5. When implementing each system, wire audio through `AudioManager`
6. Code review: verify no direct `AudioStreamPlayer` creation outside `AudioManager`; verify spatial SFX auto-free; verify Web audio constraints
7. Test on Web target: verify autoplay behavior; verify concurrent SFX limit

## Validation Criteria
- [ ] All audio routes through `AudioManager` (no direct `AudioStreamPlayer` creation outside manager)
- [ ] Audio buses are configured in project settings
- [ ] Spatial SFX instances are auto-freed when finished
- [ ] All audio streams are preloaded via `preload()` (no dynamic loading)
- [ ] Web audio autoplay is handled (first audio triggered by user input)
- [ ] Web concurrent SFX limit (8 decoders) is documented and monitored
- [ ] OGG is used for long audio; WAV is used for short SFX
- [ ] RoomData includes ambient track and reverb settings

## Related Decisions
- ADR-0001 (Single-Scene Architecture) — AudioManager singleton in single-scene architecture
- ADR-0005 (Web-Compatible Rendering) — Web audio constraints documented
- ADR-0004 (Data-Driven Design) — RoomData includes audio properties
- ADR-0003 (Signal Communication) — Audio triggers use signals from systems to AudioManager
