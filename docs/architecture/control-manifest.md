# Control Manifest

> **Engine**: Godot 4.6
> **Last Updated**: 2026-04-19
> **Manifest Version**: 2026-04-19
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation*

### Required Patterns
- **Single-scene architecture**: The entire game runs in one scene. No room streaming, no level loading. All rooms exist in the single scene. — source: ADR-0001
- **RoomManager scene-local node**: RoomManager is a scene-local node, not an Autoload. RoomData resources define room boundaries. — source: ADR-0001
- **RoomManager interface**: Use `current_room`, `room_changed` signal, `configure_for_night()` for night initialization. — source: ADR-0001
- **Signal-based cross-layer communication**: Systems communicate via typed signals. Signals flow upward (lower layer → higher layer). — source: ADR-0003
- **Top-down configuration calls only**: Night Progression calls `configure_for_night(n)` on Foundation systems at night start. This is the only permitted top-down call pattern. — source: ADR-0003
- **No Autoload singletons**: Systems must not directly reference Autoload singletons by name. Use dependency injection or signals. — source: ADR-0003
- **No direct cross-layer calls**: A system in layer N may only call methods on systems in layer N-1, never layers below N-1 or above N. — source: ADR-0003
- **Signal signature stability**: Once a signal is published, its signature is frozen. New parameters are added at the end with default values. — source: ADR-0003
- **No signal chains**: A system that receives a signal must not re-emit it as a different signal. Transform internally and emit its own distinct signal. — source: ADR-0003
- **Signal registry**: Maintain documented signal registry with emitter, subscribers, layer, and signature. — source: ADR-0003
- **SaveManager singleton**: Central save/load routing. PC uses FileAccess + XOR encryption. Web uses ConfigFile (no encryption). — source: ADR-0010
- **Save validation on load**: Validate version, required fields, and checksum. Treat corrupt saves as empty slots. — source: ADR-0010
- **Auto-save every 30 seconds**: During gameplay, auto-save player state every 30 seconds. — source: ADR-0010
- **3 save slots**: Default 3 save slots with slot selection UI and metadata (timestamp, night number). — source: ADR-0010
- **Settings via ConfigFile**: Settings, keybindings, and volume stored in INI-format ConfigFile. Save on change, load on startup. — source: ADR-0010
- **No save during critical moments**: Never trigger saves during anomaly detection or monster encounters. — source: ADR-0010
- **Input Actions in project settings**: All input mapped via project.godot, never `Input.is_key_pressed()` directly in gameplay code. — source: ADR-0008
- **State-based input routing**: Use InputHandler base class with enabled/disabled pattern. Route via GameManager (GameplayInputHandler, MenuInputHandler, CutsceneInputHandler). — source: ADR-0008
- **AudioManager singleton**: Central audio routing via 6-bus system (Music, Ambient, SFX, Voice, UI, Master). All audio plays through this node. — source: ADR-0009
- **Layered audio controllers**: MusicController (tension-tier crossfading), AmbientController (room-specific loops), SFXManager (spatial + non-spatial), VoiceController (interrupts ambient), UIController (minimal concurrent). — source: ADR-0009
- **Spatial SFX auto-free**: AudioStreamPlayer3D instances must be auto-freed via `queue_free()` on `finished` signal. — source: ADR-0009
- **All audio preloaded**: All audio streams preloaded via `preload()`. No dynamic file loading. — source: ADR-0009
- **RoomData includes audio properties**: Each room resource has ambient_track, reverb_type, ambient_volume_db, ambient_min_distance, ambient_max_distance. — source: ADR-0009

### Forbidden Approaches
- **Never use scene streaming**: No `change_scene()`, no `load()` for room scenes, no `PackedScene` streaming at runtime. — ADR-0001: The single-scene architecture eliminates loading screens, preserves atmosphere, and avoids Web memory fragmentation.
- **Never use Autoload singletons for cross-system communication**: Autoloads create implicit coupling that violates the dependency layer model. — ADR-0003
- **Never create AudioStreamPlayer outside AudioManager**: All audio must route through the 6-bus system managed by AudioManager. — ADR-0009
- **Never use dynamic audio loading**: All audio must be preloaded via `preload()`. — ADR-0009
- **Never skip save validation**: All loaded saves must be validated for version, required fields, and checksum. — ADR-0010
- **Never save during gameplay-critical moments**: Anomaly detection and monster encounter periods must not trigger save operations. — ADR-0010
- **Never use GodotPhysics3D for new projects**: Jolt Physics is the Godot 4.6 default with better stability. — ADR-0002

### Performance Guardrails
- **RoomManager**: All room boundary checks must complete within 0.5 ms/frame. — source: ADR-0001
- **Save I/O**: Save writes are synchronous. Ensure save files stay under 50 KB to avoid UI stutters. — source: ADR-0010
- **Audio decoder budget**: Web target max 8 concurrent audio decoders. Prioritize important SFX. — source: ADR-0009

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision*

### Required Patterns
- **Jolt Physics as default**: Use Jolt Physics for all 3D physics. GodotPhysics3D is not used. — source: ADR-0002
- **CharacterBody3D for player**: Player controller uses `move_and_slide()` with Jolt backend. — source: ADR-0002
- **Area3D for detection zones**: Room boundaries, interaction zones, and anomaly detection use Area3D. — source: ADR-0002
- **PhysicsDirectSpaceState3D for raycasting**: Camera raycasting uses `get_world_3d().direct_space_state` with `PhysicsRayQueryParameters3D`. — source: ADR-0002
- **CollisionShape3D for static geometry**: All static environment collision uses CollisionShape3D. — source: ADR-0002
- **All gameplay values in Resources**: Speeds, durations, ranges, thresholds must be in `.tres` resources, never hardcoded. — source: ADR-0004
- **Resources loaded in _ready()**: All resources loaded in `_ready()` or earlier. Never in `_physics_process()`. — source: ADR-0004
- **Resources are read-only at runtime**: Resources define configuration. Never mutate resources. Runtime state in companion objects. — source: ADR-0004
- **No runtime resource creation**: Resources are authored in editor. `Resource.new()` + property assignment at runtime is forbidden. — source: ADR-0004
- **All resource scripts have class_name**: Enables type-safe loading with `as` casts. — source: ADR-0004
- **Resource paths use StringName**: Resources reference each other by StringName path only. No circular references. — source: ADR-0004
- **Inline .tres format**: All resource files must use inline text format for version control. — source: ADR-0004
- **Formula structure in code, parameters in resources**: GDDs document formula structure; resources contain parameter values (coefficients, exponents). — source: ADR-0004

### Forbidden Approaches
- **Never use GodotPhysics3D**: Jolt is the 4.6 default. GodotPhysics3D has worse determinism and stability. — ADR-0002
- **Never hardcode gameplay values**: No magic numbers for speeds, durations, thresholds, or ranges. — ADR-0004
- **Never create resources at runtime**: No `Resource.new()` + property assignment. All resources authored in editor. — ADR-0004
- **Never load resources in _physics_process**: Physics frame budgets cannot tolerate I/O. — ADR-0004
- **Never store mutable state in resources**: Resources are immutable. State goes in companion objects. — ADR-0004
- **Never use JSON for gameplay data**: Godot Resources provide editor authoring, type safety, and dependency tracking that JSON cannot match. — ADR-0004

---

## Feature Layer Rules

*Applies to: secondary mechanics, AI systems, secondary features*

### Required Patterns
- **GUT test framework**: All automated tests use GUT with `gut_cli.gd` runner. — source: ADR-0007
- **Unit tests for all logic systems**: RoomManager, NightProgression, AnomalySpawner, AnomalySystem, Photography, MonsterAI, PlayerSurvival, EvidenceSubmission, AudioManager must have unit tests. — source: ADR-0007
- **Tests co-located with source**: Test files in same directory as code, named `[name]_test.gd`. — source: ADR-0007
- **Deterministic tests**: Tests produce same result every run. No `rand()` or time-dependent logic. — source: ADR-0007
- **Test isolation**: Each test sets up and tears down its own state. No dependency on execution order. — source: ADR-0007
- **Headless execution**: Tests must run in headless mode (`--headless` flag). No visual assertions. — source: ADR-0007
- **Integration tests for critical flows**: Night start flow and anomaly detection flow must have integration tests. — source: ADR-0007
- **Test naming**: `[system]_[feature]_test.gd` for files; `test_[scenario]_[expected]` for methods. — source: ADR-0007
- **Manual testing for visual systems**: FPController, Camera, VFX, Monster appearance, UI/HUD, Main menu tested via playtest, not automation. — source: ADR-0007

### Forbidden Approaches
- **Never automate visual fidelity**: Shader output, VFX appearance, animation curves cannot be automated. — ADR-0007
- **Never use rand() in tests**: Tests must be deterministic. — ADR-0007
- **Never call external APIs in tests**: Use dependency injection. No file I/O, database calls, or network requests. — ADR-0007
- **Never use hardcoded data in test fixtures**: Use constants or factory functions (exception: boundary value tests where the number IS the point). — ADR-0007

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

### Required Patterns
- **Forward+ rendering path**: Default for Godot 4.6. Used for both PC and Web targets. — source: ADR-0005
- **PC performance budgets**: < 500 draw calls, < 512 MB memory, < 2M triangles, < 50 lights, < 4 shadow maps, < 5000 particles. — source: ADR-0005
- **Web performance budgets**: < 300 draw calls, < 256 MB memory, < 1M triangles, < 25 lights, < 2 shadow maps, < 2000 particles. — source: ADR-0005
- **Web visual effects**: Bloom (low quality) only. No SSAO. Reduced shadow resolution. Minimal post-processing. — source: ADR-0005
- **Texture compression**: S3TC/BPTC on PC; ETC2 on Web. Godot's export pipeline handles this automatically. — source: ADR-0005
- **GPUParticles3D for VFX**: All particle effects use GPUParticles3D. No compute shaders. — source: ADR-0005
- **LightmapGI for static environments**: Baked lighting for rooms. — source: ADR-0005
- **Web CPU budget**: Non-rendering CPU budget < 4 ms per frame (physics + game logic combined). — source: ADR-0005

### Forbidden Approaches
- **Never use compute shaders**: Not supported on Web export. All custom shaders must be vertex/fragment only. — ADR-0005
- **Never use ray tracing**: Not supported on Web. Not a target feature for PC. — ADR-0005
- **Never use deferred rendering**: Forward+ is required for both PC and Web. — ADR-0005
- **Never use SSAO on Web**: Too expensive for Web GPU. — ADR-0005
- **Never use reflections**: Too expensive for both PC and Web targets. — ADR-0005
- **Never use custom compute shaders**: Web export does not support compute shaders. — ADR-0005

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController`, `RoomManager` |
| Variables | snake_case | `move_speed`, `max_health` |
| Signals/Events | snake_case past tense | `health_changed`, `room_changed` |
| Files | snake_case matching class | `player_controller.gd` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `FRAME_BUDGET` |

### Performance Budgets
| Target | Value |
|--------|-------|
| Framerate | 60 fps |
| Frame budget | 16.6 ms |
| Draw calls | < 500 (PC), < 300 (Web) |
| Memory ceiling | < 512 MB (PC), < 256 MB (Web) |

### Approved Libraries / Addons
- **GUT** — approved for automated testing (logic systems)

### Forbidden APIs (Godot 4.6)
These APIs are deprecated or unverified for Godot 4.6:

**Nodes & Classes:**
- `TileMap` — use `TileMapLayer` (since 4.3)
- `VisibilityNotifier2D` — use `VisibleOnScreenNotifier2D` (since 4.0)
- `VisibilityNotifier3D` — use `VisibleOnScreenNotifier3D` (since 4.0)
- `YSort` — use `Node2D.y_sort_enabled` (since 4.0)
- `Navigation2D` / `Navigation3D` — use `NavigationServer2D` / `NavigationServer3D` (since 4.0)
- `EditorSceneFormatImporterFBX` — use `EditorSceneFormatImporterFBX2GLTF` (since 4.3)

**Methods & Properties:**
- `yield()` — use `await signal` (since 4.0)
- `connect("signal", obj, "method")` — use `signal.connect(callable)` (since 4.0)
- `instance()` — use `instantiate()` (since 4.0)
- `PackedScene.instance()` — use `PackedScene.instantiate()` (since 4.0)
- `get_world()` — use `get_world_3d()` (since 4.0)
- `OS.get_ticks_msec()` — use `Time.get_ticks_msec()` (since 4.0)
- `duplicate()` for nested resources — use `duplicate_deep()` (since 4.5)
- `Skeleton3D.bone_pose_updated` — use `skeleton_updated` (since 4.3)
- `AnimationPlayer.method_call_mode` — use `AnimationMixer.callback_mode_method` (since 4.3)
- `AnimationPlayer.playback_active` — use `AnimationMixer.active` (since 4.3)

**Patterns:**
- String-based `connect()` — use typed signal connections
- `$NodePath` in `_process()` — use `@onready var` cached reference
- Untyped `Array` / `Dictionary` — use `Array[Type]`, typed variables
- `Texture2D` in shader parameters — use `Texture` base type (changed in 4.4)
- Manual post-process viewport chains — use `Compositor` + `CompositorEffect` (4.3+)
- GodotPhysics3D for new projects — use Jolt Physics 3D (default since 4.6)

Source: `docs/engine-reference/godot/deprecated-apis.md`

### Cross-Cutting Constraints
- **No global mutable state**: All state held in scene nodes or companion objects. No module-level mutable variables. — source: ADR-0006
- **No cross-layer imports**: A system's `.gd` files may only import types from its own directory or from lower layers. — source: ADR-0006
- **No dynamic scene loading at runtime**: All scenes loaded via `load()` or `preload()` — no dynamic path strings for scene loading. — source: ADR-0006
- **Web keyboard shortcut conflicts**: `Ctrl+W`, `Ctrl+R`, `F5` are reserved by browser. Do not map these to game actions. — source: ADR-0008
- **Web gamepad is partial support**: Web Gamepad API has limited support. Document and test on Web target. — source: ADR-0008
- **Mouse capture management**: Mouse is captured during gameplay via `Input.MOUSE_MODE_CAPTURED`. Must be released when menus open. — source: ADR-0008
- **Gamepad dead zones**: All gamepad axes use configured dead zones. No raw axis values for input thresholds. — source: ADR-0008
- **System-based directory structure**: Each system owns its directory under `src/`. No cross-directory file access without going through the system's public API. — source: ADR-0006
- **Shared code threshold**: Common utilities go in `src/shared/`. Require 3+ usages before adding to shared. — source: ADR-0006
- **Tests co-located with code**: Test files in same directory as source, named `[name]_test.gd`. — source: ADR-0006
