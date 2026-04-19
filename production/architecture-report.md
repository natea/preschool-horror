# Architecture Report: Show & Tell

> **Engine**: Godot 4.6 | **Renderer**: Vulkan Forward+ | **Physics**: Jolt
> **Created**: 2026-04-19 | **Status**: Complete (all 8 phases)

---

## Phase 1: Architecture Layering

### Foundation Layer (no dependencies — boot first)

| # | System | Engine APIs | Risk |
|---|--------|-------------|------|
| 1 | First-Person Controller | CharacterBody3D, InputAction, Camera3D | HIGH (Jolt) |
| 2 | Room/Level Management | Node, SceneTree, Resource | LOW |
| 3 | Audio System | AudioServer, AudioStreamPlayer, AudioBus | LOW |
| 4 | Save/Persistence | FileAccess, ConfigFile, JSON, Crypto | MEDIUM (4.4+ return types) |

### Core Layer (depends on Foundation)

| # | System | Engine APIs | Risk |
|---|--------|-------------|------|
| 5 | Night Progression | Timer, Node | LOW |
| 6 | Anomaly Placement Engine | Resource, RandomNumberGenerator | LOW |
| 7 | HUD/UI System | Control, CanvasLayer, AccessKit | MEDIUM (4.5+) |

### Feature Layer (depends on Core)

| # | System | Engine APIs | Risk |
|---|--------|-------------|------|
| 8 | Anomaly System | Node3D, AnimationTree, VisualShader | LOW |
| 9 | Photography System | RayCast3D, Camera3D, Viewport | HIGH (Jolt) |
| 10 | Monster AI | NavigationAgent3D, BehaviorTree | HIGH (Jolt) |
| 11 | Player Survival | Timer, Control | LOW |
| 12 | Vent System | Area3D, CharacterBody3D | HIGH (Jolt) |

### Presentation Layer (depends on Features)

| # | System | Engine APIs | Risk |
|---|--------|-------------|------|
| 13 | Evidence Submission | Control, RichTextLabel, Animation | LOW |
| 14 | Photo Gallery | Control, TextureRect, GridContainer | LOW |

### Polish Layer (depends on everything)

| # | System | Engine APIs | Risk |
|---|--------|-------------|------|
| 15 | Main Menu/Game Flow | SceneTree, Control | LOW |
| 16 | Cutscene System | Camera3D, AnimationPlayer, Audio | LOW |
| 17 | Night 7 Finale | All layers combined | HIGH (integration) |

---

## Phase 2: Module Ownership Map

### First-Person Controller (`first_person_controller.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Player position/orientation, mouse look state, movement state machine, collision response, sprint/crouch state |
| **Exposes** | `get_camera_transform() → Transform3D`, `get_direction() → Vector3`, `movement_state → enum`, `is_visible() → bool` |
| **Consumes** | Input actions (move, look, sprint, crouch); room nav-masks from RoomManager |
| **Engine APIs** | CharacterBody3D (Jolt HIGH), InputAction (LOW), Camera3D (LOW), CollisionMask (Jolt HIGH) |

### Room/Level Management (`room_level_manager.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Room definitions, scene loading/unloading, room transitions, nav-mask configuration, room-to-night mapping |
| **Exposes** | `load_room(scene_path, transition_type)`, `unload_room()`, `get_current_room() → RoomData`, `get_adjacent_rooms() → Array[String]` |
| **Consumes** | Night Progression (which rooms to load), Save/Persistence (room state) |
| **Engine APIs** | Node (LOW), SceneTree (LOW), Resource (LOW), NavigationRegion3D (Jolt HIGH) |

### Audio System (`audio_system.gd`)

| Category | Details |
|----------|---------|
| **Owns** | 7-bus hierarchy, ambient cross-fade state, spatial SFX pool management, horror tier transitions, volume curves |
| **Exposes** | `play_sfx(bus, path, position?)`, `set_ambient(bus, path, fade_ms)`, `set_horror_tier(tier)`, `get_bus_volume(bus) → float` |
| **Consumes** | Night Progression (current tier), RoomManager (spatial positions), PlayerController (listener position) |
| **Engine APIs** | AudioServer (LOW), AudioStreamPlayer3D (LOW), AudioBus (LOW), AudioEffectSpectrumAnalyzer (LOW) |

### Save/Persistence (`save_manager.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Save file I/O, encryption (AES-256), CRC validation, schema migration, in-memory PlayerProgress cache |
| **Exposes** | `save(progress) → bool`, `load() → PlayerProgress`, `has_save() → bool`, `get_player_stats() → PlayerStats` |
| **Consumes** | PlayerProgress data from Night Progression, Evidence Submission, Player Stats |
| **Engine APIs** | FileAccess (MEDIUM 4.4+), JSON (LOW), Crypto (LOW), ConfigFile (LOW) |

### Night Progression (`night_progression.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Current night state, timer countdown, anomaly pool selection, difficulty tier, consecutive_nights_no_photos counter |
| **Exposes** | `get_current_night() → int`, `get_timer_remaining() → float`, `get_active_tier() → int`, `get_anomaly_pool() → Array` |
| **Consumes** | RoomManager (room configs), Save/Persistence (load night state) |
| **Engine APIs** | Timer (LOW), Node (LOW) |

### Anomaly Placement Engine (`anomaly_placement_engine.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Per-night anomaly configs, room-anomaly mapping, placement rules, anomaly ID generation |
| **Exposes** | `generate_placement(night) → Array<AnomalyInstance>`, `get_placement_rules() → PlacementRule[]` |
| **Consumes** | Night Progression (current night, tier), RoomManager (room layouts) |
| **Engine APIs** | Resource (LOW), RandomNumberGenerator (LOW) |

### HUD/UI System (`hud_system.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Three UI registers (Preschool HUD, Camera Viewfinder, Boss Debrief), color debt overlay, warning indicators, vulnerability bar |
| **Exposes** | `update_vulnerability(value)`, `update_photo_count(count)`, `show_warning(type)`, `get_viewfinder_transform() → Transform2D` |
| **Consumes** | PlayerController (camera direction), Photography System (photo count), Player Survival (vulnerability), Anomaly System (detection state) |
| **Engine APIs** | Control (LOW), CanvasLayer (LOW), AccessKit (4.5+ MEDIUM) |

### Anomaly System (`anomaly_system.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Anomaly state machines (idle/react/pursue/attack), visual behavior (dissolve, rigid, irregular), photo-detection readiness |
| **Exposes** | `get_state() → enum`, `is_photo_ready() → bool`, `get_visual_state() → VisualState`, `activate()`, `deactivate()` |
| **Consumes** | Anomaly Placement Engine (spawn config), RoomManager (spatial parent), PlayerController (visibility) |
| **Engine APIs** | Node3D (LOW), AnimationTree (LOW), VisualShader (LOW), Area3D (Jolt HIGH) |

### Photography System (`photography_system.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Camera mechanics, viewfinder rendering, photo capture pipeline, photo evaluation (head-on/clear/in-frame), flash effect |
| **Exposes** | `can_capture() → bool`, `capture() → PhotoData`, `get_evaluation(anomaly) → PhotoGrade`, `get_viewport() → Viewport` |
| **Consumes** | PlayerController (camera transform), Anomaly System (detection state), HUD (viewfinder display) |
| **Engine APIs** | RayCast3D (Jolt HIGH), Camera3D (LOW), Viewport (LOW), Texture2D (LOW) |

### Monster AI (`monster_ai.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Behavior trees per archetype (Dolls/Shadows/Large), patrol paths, detection radius, pursuit state, attack animation |
| **Exposes** | `get_state() → enum`, `get_pursuit_progress() → float`, `is_threatening() → bool`, `set_detection_radius(r)`, `on_photographed()` |
| **Consumes** | Anomaly System (type config), PlayerController (position), Night Progression (tier) |
| **Engine APIs** | NavigationAgent3D (Jolt HIGH), CharacterBody3D (Jolt HIGH), AnimationTree (LOW) |

### Player Survival (`player_survival.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Vulnerability bar fill rate, stationary detection, death condition, restart logic |
| **Exposes** | `get_vulnerability() → float`, `is_dead() → bool`, `get_fill_rate() → float` |
| **Consumes** | Monster AI (threat state), PlayerController (movement state), HUD (vulnerability bar) |
| **Engine APIs** | Timer (LOW), Control (LOW) |

### Vent System (`vent_system.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Vent network layout, enter/exit mechanics, vent pathfinding, Night 7 escape route validation |
| **Exposes** | `get_active_vents() → Array[VentNode]`, `can_enter(vent_id) → bool`, `enter(vent_id) → bool`, `get_escape_path() → Array[String]` |
| **Consumes** | RoomManager (room layouts), PlayerController (position), Night Progression (night 7 check) |
| **Engine APIs** | Area3D (Jolt HIGH), NavigationRegion3D (Jolt HIGH), CharacterBody3D (Jolt HIGH) |

### Evidence Submission (`evidence_submission.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Photo grading pipeline, boss dialogue tree, pay calculation, anger escalation, 3-night-no-submit trigger |
| **Exposes** | `get_grade(photo) → Grade`, `get_pay(night) → int`, `get_dialogue_line(anger, night) → String`, `update_anger(delta)`, `is_game_over() → bool` |
| **Consumes** | Photography System (photo grades), Night Progression (night number), Save/Persistence (write pay/anger) |
| **Engine APIs** | Control (LOW), RichTextLabel (LOW), AnimationPlayer (LOW) |

### Photo Gallery (`photo_gallery.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Photo browser UI, photo selection for submission, thumbnail generation |
| **Exposes** | `get_selected_photos() → Array<PhotoData>`, `get_all_photos() → Array<PhotoData>`, `select(photo_id)`, `deselect(photo_id)` |
| **Consumes** | Photography System (captured photos), HUD (display) |
| **Engine APIs** | Control (LOW), TextureRect (LOW), GridContainer (LOW) |

### Main Menu (`main_menu.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Title screen, pause menu, new game flow, continue game, settings |
| **Exposes** | `start_new_game()`, `continue_game()`, `show_pause()`, `get_settings() → Dictionary` |
| **Consumes** | Save/Persistence (has_save check), Night Progression (game state), HUD (overlay) |
| **Engine APIs** | SceneTree (LOW), Control (LOW), ConfigFile (LOW) |

### Cutscene System (`cutscene_system.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Scripted camera moves, dialogue display, audio cues, cutscene state machine |
| **Exposes** | `play(cutscene_id)`, `skip()`, `is_playing() → bool` |
| **Consumes** | PlayerController (camera control), Audio System (cues), Night Progression (night context) |
| **Engine APIs** | Camera3D (LOW), AnimationPlayer (LOW), AudioStreamPlayer (LOW) |

### Night 7 Finale (`night_7_finale.gd`)

| Category | Details |
|----------|---------|
| **Owns** | Boss transformation sequence, chase AI behavior, escape win detection, final cutscene orchestration |
| **Exposes** | `trigger_transformation()`, `start_chase()`, `is_escaped() → bool`, `is_caught() → bool` |
| **Consumes** | Monster AI (boss archetype), Vent System (escape path), Cutscene System (transformation), Evidence Submission (anger state) |
| **Engine APIs** | All layers combined — HIGH integration risk |

---

## Phase 3: Data Flow

### 3a. Frame Update Path

```
InputAction (Keyboard/Mouse/Gamepad)
  → InputMap (configured actions)
    → First-Person Controller (process_move + process_look per frame)
      → CharacterBody3D.move_and_slide() (Jolt physics)
        → RoomManager nav-masks (collision layers per room)
          → Anomaly System (Area3D overlap checks)
            → Monster AI (detection → pursuit state)
              → Player Survival (vulnerability fill)
                → HUD System (update all registers)
                  → Rendering (Vulkan Forward+)
```

Data: Input events → velocity/rotation → physics step → collision → state change → visual feedback

### 3b. Event/Signal Path

```
Anomaly System
  ┌─ anomaly_photographed → Evidence Submission (start debrief)
  ┌─ anomaly_detected → HUD System (warning indicator)
  ┌─ anomaly_fled → Night Progression (counter update)

Photography System
  ┌─ photo_captured → Save/Persistence (inventory update)
  ┌─ photo_captured → HUD System (photo count update)

Player Survival
  ┌─ vulnerability_full → Night Progression (trigger death)
  ┌─ player_caught → Main Menu (game over screen)

Night Progression
  ┌─ night_timer_expired → Evidence Submission (forced debrief)
  ┌─ night_completed → Save/Persistence (write progress)
  ┌─ night_changed → RoomManager (load new room layout)

Evidence Submission
  ┌─ debrief_completed → Save/Persistence (write pay/anger)
  ┌─ debrief_completed → Night Progression (advance night counter)
  ┌─ debrief_completed → HUD System (clear debrief overlay)
  ┌─ game_over → Main Menu (show game over)

Save/Persistence
  ┌─ save_loaded → Night Progression (restore night state)
  ┌─ save_loaded → Evidence Submission (restore anger/pay)
  ┌─ save_error → Main Menu (show error dialog)
```

### 3c. Save/Load Path

```
SAVE:
  Evidence Submission (pay/anger)
    └─┐
  Night Progression (current_night, timer, tier)
    └─┐
  Player Survival (vulnerability state)
    └─┐
  Photography System (inventory photos)
    └─┐
  SaveManager.collect() → PlayerProgress object
    → JSON.stringify() → JSON string
    → GZIP compress (optional)
    → AES-256 encrypt with seed-derived key
    → CRC32 checksum appended
    → FileAccess.store_buffer() → user://save_data.dat

LOAD:
  FileAccess.open_encrypted_with_pass() → bytes
    → CRC32 verify (IS_VALID check)
    → AES-256 decrypt
    → GZIP decompress
    → JSON.parse() → Dictionary
    → SaveManager.deserialize() → PlayerProgress object
    → Night Progression.restore(progress)
    → Evidence Submission.restore(progress)
```

Thread boundary: All file I/O on main thread (Godot 4.6 `FileAccess` is synchronous). Load blocking is acceptable within frame budget (<100ms).

### 3d. Initialization Order

```
1. Main Menu (SceneTree.change_scene) — boot first
2. On "New Game":
   a. SaveManager.load() — check for existing save
   b. If save exists → continue; if not → new game defaults
   c. Night Progression.init(night=1)
   d. RoomManager.load_room(night_1_rooms)
   e. AudioSystem.init() — set initial ambient bus
   f. Anomaly Placement Engine.init() — generate night 1 pool
   g. Anomaly System.spawn(placement) — instantiate room anomalies
   h. PlayerController.init() — set initial position
   i. HUD System.init() — bind to active systems
   j. Player Survival.init() — reset vulnerability
3. On night transition:
   a. SaveManager.save() — persist current state
   b. RoomManager.unload_room()
   c. Night Progression.advance_night()
   d. RoomManager.load_room(night_n_rooms)
   e. Anomaly Placement Engine.generate(night_n)
   f. Anomaly System.reinit()
```

---

## Phase 4: API Boundaries

### First-Person Controller

```gdscript
class FirstPersonController:
    var camera_transform: Transform3D
    var direction: Vector3
    var movement_state: MovementState  # enum {IDLE, WALKING, SPRINTING, CROUCHING}
    var is_visible: bool

    func get_camera_transform() -> Transform3D
    func get_direction() -> Vector3
    func get_velocity() -> Vector3
    func is_moving() -> bool

# Invariants:
# - camera_transform is valid only when is_visible == true
# - direction is normalized (length == 1.0)
# - movement_state updates are frame-accurate (no interpolation)
```

### Room/Level Management

```gdscript
class RoomLevelManager:
    func load_room(scene_path: String, transition: TransitionType = TransitionType.FADE) -> bool
    func unload_room() -> void
    func get_current_room() -> RoomData
    func get_adjacent_rooms() -> Array[StringName]
    func get_nav_region() -> NavigationRegion3D

# Invariants:
# - load_room() blocks until transition completes
# - unload_room() must be called before loading a different room
# - get_nav_region() returns null if no room is loaded
```

### Save/Persistence

```gdscript
class SaveManager:
    func save(progress: PlayerProgress) -> bool
    func load() -> PlayerProgress
    func has_save() -> bool
    func get_player_stats() -> PlayerStats
    func delete_save() -> bool

# Invariants:
# - save() returns false on I/O failure (player should be warned)
# - load() returns null if no save exists (caller must handle)
# - has_save() is fast (no I/O — checks cached state)
# - delete_save() requires explicit confirmation from caller
```

### Night Progression

```gdscript
class NightProgression:
    var current_night: int              # 1-7
    var timer_remaining: float          # seconds
    var active_tier: int                # 1-4 (horror difficulty)
    var consecutive_no_photos: int      # 0-2

    func get_anomaly_pool() -> Array[AnomalyConfig]
    func advance_night() -> bool
    func reset_night() -> void
    func is_game_over() -> bool
    func get_pay_for_night(night: int) -> int

# Invariants:
# - current_night is always 1-7 (never out of bounds)
# - timer_remaining decreases each frame (monotonically)
# - is_game_over() checks multiple conditions (anger >= 10, counter >= 3, timer expired)
```

### Photography System

```gdscript
class PhotographySystem:
    func can_capture() -> bool
    func capture() -> PhotoData
    func evaluate(anomaly: Anomaly) -> PhotoGrade
    func get_viewport() -> Viewport
    func get_flash_active() -> bool

# Invariants:
# - capture() returns null if can_capture() == false
# - evaluate() is deterministic (same inputs → same grade)
# - get_viewport() is valid only when camera is active
```

### Anomaly System

```gdscript
class Anomaly:
    var state: AnomalyState             # enum {IDLE, REACTING, PURSUING, ATTACKING, FLED}
    var is_photo_ready: bool
    var visual_state: VisualState       # enum {NORMAL, WRONGNESS, TRANSFORMED}

    func activate() -> void
    func deactivate() -> void
    func on_photographed() -> PhotoResult
    func on_detected() -> void
    func on_fled() -> void

# Invariants:
# - activate() must be called before any other method
# - state transitions are frame-accurate (no lag)
# - is_photo_ready is true only during the REACTING phase
```

### Evidence Submission

```gdscript
class EvidenceSubmission:
    var boss_anger: int                 # 0-10
    var cumulative_pay: int

    func grade_photo(photo: PhotoData) -> Grade
    func get_dialogue(night: int, anger: int) -> DialogueLine
    func update_pay(night: int) -> int
    func update_anger(delta: float) -> void
    func is_game_over() -> bool

# Invariants:
# - boss_anger is always 0-10 (clamped on every update)
# - grade_photo() is deterministic (same photo → same grade)
# - is_game_over() checks: anger >= 10 OR counter >= 3 OR night 7 + no submit
```

### Player Survival

```gdscript
class PlayerSurvival:
    var vulnerability: float            # 0.0-1.0

    func get_vulnerability() -> float
    func is_dead() -> bool
    func get_fill_rate() -> float
    func reset() -> void

# Invariants:
# - vulnerability is always 0.0-1.0 (clamped)
# - fill_rate depends on monster proximity and player movement state
# - is_dead() returns true only after vulnerability_full signal fires
```

### HUD/UI System

```gdscript
class HUDSystem:
    func update_vulnerability(value: float) -> void
    func update_photo_count(count: int) -> void
    func update_timer(remaining: float) -> void
    func show_warning(type: WarningType) -> void
    func hide_warning(type: WarningType) -> void
    func show_debrief(lines: Array[DialogueLine]) -> void
    func hide_debrief() -> void

# Invariants:
# - update_*() are idempotent (same value → no-op)
# - show_debrief() must be paired with hide_debrief()
# - all calls are safe from any thread (queued to main)
```

### Vent System

```gdscript
class VentSystem:
    func get_active_vents() -> Array[VentNode]
    func can_enter(vent_id: String) -> bool
    func enter(vent_id: String) -> bool
    func get_escape_path() -> Array[String]
    func is_vent_locked(vent_id: String) -> bool

# Invariants:
# - get_active_vents() only returns vents in current room
# - can_enter() checks both vent state and player proximity
# - get_escape_path() returns empty array if not night 7
```

### Photo Gallery

```gdscript
class PhotoGallery:
    func get_selected_photos() -> Array[PhotoData]
    func get_all_photos() -> Array[PhotoData]
    func select(photo_id: String) -> void
    func deselect(photo_id: String) -> void
    func clear_selection() -> void

# Invariants:
# - get_*_photos() return copies (caller cannot modify gallery)
# - select() is a no-op if photo not in gallery
# - clear_selection() empties selection but keeps gallery intact
```

### Main Menu

```gdscript
class MainMenu:
    func start_new_game() -> void
    func continue_game() -> void
    func show_pause() -> void
    func get_settings() -> Dictionary
    func has_save() -> bool

# Invariants:
# - has_save() is fast (cached, no I/O)
# - start_new_game() must be confirmed (no auto-start)
# - show_pause() blocks all input except pause toggle
```

### Cutscene System

```gdscript
class CutsceneSystem:
    func play(cutscene_id: String) -> void
    func skip() -> void
    func is_playing() -> bool

# Invariants:
# - play() blocks input (First-Person Controller ignores input)
# - skip() is a no-op if not playing
# - is_playing() is true from play() until completion or skip
```

---

## Phase 5: Integration Points

### 5a. Cross-Layer Dependencies

```
Foundation → Core:
  First-Person Controller → HUD System:
    - Camera3D visibility affects HUD register activation
    - CharacterBody3D movement state drives vulnerability fill rate

  RoomManager → Night Progression:
    - Room layout determines anomaly placement density
    - Room transitions trigger night state updates

  RoomManager → Anomaly Placement Engine:
    - Room nav-masks must match anomaly collision layers
    - Room dimensions constrain anomaly spawn radius

  AudioSystem → All:
    - 7-bus hierarchy must be configured before any system uses it
    - Bus effects (reverb, compression) must exist before spatial SFX

Core → Feature:
  Night Progression → Anomaly Placement Engine:
    - Night tier determines anomaly pool density
    - Night timer affects monster pursuit aggressiveness

  Night Progression → HUD System:
    - Timer countdown must update HUD every frame
    - Tier changes trigger visual overlay updates

  Anomaly Placement Engine → Anomaly System:
    - Placement IDs must match anomaly instance IDs
    - Spawn positions must be within room nav-mesh bounds

  HUD System → Photography System:
    - Viewfinder transform must update at camera refresh rate
    - Warning indicators must react to anomaly proximity

Feature → Presentation:
  Anomaly System → Evidence Submission:
    - Photo data from capture must include grade metadata
    - Anomaly state must persist through debrief

  Photography System → Evidence Submission:
    - Photo evaluation must use consistent grading algorithm
    - Flash effect must not interfere with grade calculation

  Player Survival → Night Progression:
    - Death trigger must save current state before restart
    - Vulnerability state must reset on night load

Presentation → Foundation:
  Evidence Submission → SaveManager:
    - Write must succeed before night advance
    - Corruption must halt progression (no partial writes)

  Main Menu → SaveManager:
    - has_save() check must be fast (no blocking I/O)
    - Error dialog must not crash on I/O failure
```

### 5b. Initialization Sequence

```
Boot Sequence:
  1. Main Menu loads (SceneTree.change_scene to main_menu.tscn)
  2. Main Menu calls SaveManager.has_save() → check for existing game
  3. Player selects "New Game" or "Continue"

New Game Flow:
  4. Night Progression.init(night=1) → set defaults
  5. RoomManager.load_room(preschool_night_1) → load scene, configure nav-masks
  6. Anomaly Placement Engine.generate(night=1) → create placement array
  7. Anomaly System.spawn_all(placement) → instantiate anomalies in rooms
  8. Player Controller.init() → set player position in starting room
  9. AudioSystem.init() → set ambient bus, start night 1 ambient loop
  10. HUD System.init() → bind to active systems, show initial HUD
  11. Player Survival.init() → reset vulnerability to 0
  12. Game loop begins

Continue Game Flow:
  4. SaveManager.load() → PlayerProgress
  5. Night Progression.restore(progress) → restore current_night, timer, tier
  6. Evidence Submission.restore(progress) → restore boss_anger, cumulative_pay
  7-12. Same as New Game (steps 5-12)
```

### 5c. Critical Path — Night Transition

```
Night Transition (player submits all photos / timer expires):
  1. Evidence Submission.finalize_debrief()
     → grade remaining photos, calculate pay, update anger
  2. SaveManager.save(PlayerProgress) — persist all state
  3. RoomManager.unload_room() — clear current scene
  4. Night Progression.advance_night() → increment current_night
  5. Anomaly Placement Engine.generate(night_n) — new pool
  6. RoomManager.load_room(night_n_rooms) — new layout
  7. Anomaly System.spawn_all(placement) — new anomalies
  8. Player Survival.reset() → vulnerability = 0
  9. HUD System.clear_all() → reset all registers
  10. AudioSystem.transition_to_night(night_n) → new ambient + music
  11. Player Controller.reposition(starting_room) → new spawn position
```

### 5d. Failure Modes at Integration Points

| Integration Point | Failure Mode | Mitigation |
|---|---|---|
| RoomManager.load_room() | Scene file missing or corrupted | Check file exists before load; show error dialog |
| SaveManager.save() | I/O failure (disk full, permission) | Retry once; show error dialog; block progression |
| SaveManager.load() | Save file corrupted | Check CRC32; attempt backup restore; init defaults |
| Anomaly Placement Engine | No valid placement for room | Generate fallback random placement; log warning |
| AudioSystem.init() | Audio bus config missing | Create default buses; log error; continue |
| Photography System | Camera viewport null | Disable capture; show "Camera unavailable" warning |
| Evidence Submission.grade_photo() | Photo data incomplete | Grade as lowest possible; log error |
| Player Survival.death | Called during scene unload | Guard with scene-valid check; no-op if invalid |

### 5e. Engine Awareness at Integration Points

```
HIGH RISK intersections:

1. CharacterBody3D.move_and_slide() (First-Person Controller)
   → Jolt physics engine (Godot 4.6 default)
   → Collision behavior differs from GodotPhysics
   → Must test: slide speed, wall cling, slope angle

2. NavigationAgent3D.pathfinding (Monster AI)
   → Jolt nav-mesh generation
   → Nav-masks must match between RoomManager and Monster AI
   → Nav-mesh rebuild on room load required

3. RayCast3D (Photography System)
   → Jolt raycast collision layers
   → Must verify raycast hits anomaly Area3D correctly

4. FileAccess I/O (SaveManager)
   → Godot 4.4+ return Error enum (not null)
   → Must check return value before using data

MEDIUM RISK intersections:

5. AccessKit (HUD/UI System)
   → Godot 4.5+ accessibility tree
   → Custom controls must expose proper roles
   → Test with screen reader

6. AgX Tonemapper + Bloom (Rendering)
   → Godot 4.5+ glow rework
   → Anomaly "wrongness" effect must work with AgX
   → Bloom intensity may differ from pre-4.5
```

---

## Phase 6: Performance Budget

### 6a. Per-System Frame Budget

| System | Budget | Critical Path | Measurement |
|--------|--------|--------------|-------------|
| First-Person Controller | < 0.5 ms | move_and_slide() + physics step | PhysicsServer3D query |
| RoomManager | < 2 ms | scene load/unload (cached) | SceneTree.change_scene() delta |
| AudioSystem | < 0.2 ms | spatial SFX update | AudioServer get_bus_cpu_usage |
| SaveManager | < 100 ms (load) | file I/O + decrypt + JSON | FileAccess.get_error |
| Night Progression | < 0.1 ms | timer countdown | Timer timeout handler |
| Anomaly Placement | < 1 ms | pool generation (night transition only) | RandomNumberGenerator calls |
| HUD System | < 1 ms | all register updates | Canvas draw list count |
| Anomaly System | < 2 ms | area overlap checks | Area3D query_state |
| Photography System | < 3 ms | capture + evaluate | Viewport.get_texture() |
| Monster AI | < 3 ms | pathfinding + behavior update | NavigationServer3D query |
| Player Survival | < 0.1 ms | vulnerability fill | Timer callback |
| Vent System | < 1 ms | area checks | Area3D query_state |
| Evidence Submission | < 5 ms | photo grading (debrief only) | Array iteration |
| Photo Gallery | < 1 ms | thumbnail generation | TextureRect set_texture |
| Main Menu | < 0.5 ms | UI interaction | Control input handling |
| Cutscene System | < 1 ms | camera update | Camera3D transform |
| Night 7 Finale | < 5 ms | chase AI + detection | Combined Monster AI + Vent |

**Total per frame budget: < 16.67 ms (60 fps target)**

### 6b. Frame Budget Allocation (Normal Gameplay)

```
Guaranteed per frame (player moving, no anomalies active):
  First-Person Controller:    0.5 ms  (physics)
  HUD System:                 1.0 ms  (register updates)
  Player Survival:            0.1 ms  (vulnerability check)
  AudioSystem:                0.2 ms  (bus updates)
  ──────────────────────────────────
  Base cost:                  1.8 ms

Variable per frame (anomalies active):
  Anomaly System (5 active):  10.0 ms  (2 ms each x 5)
  Monster AI (3 active):       9.0 ms  (3 ms each x 3)
  Photography System:          3.0 ms  (camera ready)
  Vent System:                 1.0 ms  (area checks)
  ──────────────────────────────────
  Anomaly overhead:           23.0 ms

Worst case (all systems active):  1.8 + 23.0 = 24.8 ms
Target (typical gameplay):      1.8 + 5.0 = 6.8 ms
```

### 6c. Optimization Strategies

```
1. Anomaly System:
   - Only check overlap for anomalies within detection radius
   - Use Area3D.query_state() with a sphere shape, not all anomalies
   - Skip update if anomaly state == FLED

2. Monster AI:
   - NavigationAgent3D.path_desired_distance = 5.0 (reduce path recalc)
   - Only recalculate path when distance to target > 2.0
   - Use separate physics layers for different archetypes

3. HUD System:
   - Batch register updates (single draw call)
   - Don't update if value hasn't changed (idempotent)
   - Use Control.set_deferred() for non-critical UI

4. Photography System:
   - Viewport texture only updated when capture requested
   - Reuse Viewport instance (don't create per capture)
   - RayCast3D enabled only during capture

5. AudioSystem:
   - Pool AudioStreamPlayer3D instances (don't instanciate per SFX)
   - Limit active spatial SFX to 16 (AudioServer max recommended)
   - Use AudioServer.get_bus_cpu_usage() for profiling only

6. SaveManager:
   - Cache PlayerProgress in memory (only write on triggers)
   - GZIP only if save size > 1 KB
   - AES-256 key derivation cached per session
```

---

## Phase 7: Error Handling Strategy

### 7a. Error Categories

```
CATEGORICAL_ERRORS (game-breaking, must stop):
  - Save file corruption (unrecoverable)
  - Audio bus configuration failure
  - Scene file missing (room, anomaly)
  - Physics engine initialization failure

RECOVERABLE_ERRORS (log, continue with fallback):
  - Save I/O failure (disk full) — retry once
  - Anomaly placement generation fails — use fallback
  - Photo evaluation incomplete — grade as lowest
  - Nav-mesh invalid — disable monster pursuit

NON-ERRORS (expected conditions, no logging):
  - No save file exists — new game
  - Photo capture while camera inactive — no-op
  - Player caught during scene unload — no-op
  - Animation skip during cutscene — no-op
```

### 7b. Error Handling by System

```
First-Person Controller:
  - Physics collision failure: log_error("Physics server error"); reset player position
  - Input action not found: log_warning("Input action '{action}' not configured"); ignore

RoomManager:
  - Scene load failure: log_error("Room scene not found: {path}"); show error dialog
  - Nav-mask mismatch: log_warning("Nav-mask mismatch between system and room"); fix automatically

AudioSystem:
  - Bus not found: log_error("Audio bus '{bus}' not found"); create default
  - Stream not found: log_warning("Audio stream not found: {path}"); skip

SaveManager:
  - Save error (I/O): log_error("Save failed: {error_code}"); retry once; show dialog
  - Load error (corruption): log_error("Save corrupted"); attempt backup; init defaults
  - Encryption failure: log_error("Encryption failed"); use fallback key with warning
  - Migration failure: log_error("Migration failed from v{v}"); log_error("Init new save"); block continue

Night Progression:
  - Timer overflow: log_warning("Timer overflow"); clamp to 0
  - Night > 7: log_error("Night {n} out of bounds"); clamp to 7
  - Tier out of range: log_warning("Tier {t} out of range"); clamp to 4

Anomaly Placement:
  - No placement for room: log_warning("No placement for room '{room}'"); use fallback
  - Invalid spawn position: log_warning("Invalid spawn at {pos}"); use room center

Anomaly System:
  - State transition invalid: log_warning("Invalid transition {from} -> {to}"); stay in current
  - Photo detection failure: log_warning("Photo detection failed for anomaly {id}"); mark as FLED

Photography System:
  - Camera null: log_warning("Camera unavailable"); disable capture
  - Viewport null: log_warning("Viewport unavailable"); disable capture
  - Flash effect failure: log_warning("Flash effect failed"); continue without flash

Monster AI:
  - Nav-mesh invalid: log_warning("Nav-mesh invalid for monster '{type}'"); disable pursuit
  - Pathfinding failure: log_warning("Pathfinding failed"); move toward target directly
  - Behavior tree error: log_warning("Behavior tree error"); default to IDLE

Player Survival:
  - Death during unload: log_warning("Death during scene unload"); no-op
  - Vulnerability overflow: log_warning("Vulnerability overflow"); clamp to 1.0

Vent System:
  - Vent not found: log_warning("Vent '{id}' not found"); return false
  - Escape path invalid: log_warning("Escape path invalid for night 7"); block escape

Evidence Submission:
  - Photo grading error: log_warning("Photo grading failed"); grade as lowest
  - Pay calculation error: log_warning("Pay calculation failed"); use base pay
  - Dialogue missing: log_warning("Dialogue missing for night {n}, anger {a}"); use default

Photo Gallery:
  - Thumbnail generation failure: log_warning("Thumbnail failed for photo {id}"); use placeholder
  - Photo not found: log_warning("Photo {id} not found"); no-op

Main Menu:
  - has_save() I/O error: log_warning("Save check failed"); assume no save
  - Error dialog failure: log_warning("Error dialog failed"); print to console

Cutscene System:
  - Cutscene not found: log_warning("Cutscene '{id}' not found"); no-op
  - Camera control failure: log_warning("Camera control failed"); skip cutscene

Night 7 Finale:
  - Integration failure: log_error("Night 7 integration failed"); fall back to standard debrief
```

### 7c. Error Reporting

```
Error severity levels:
  FATAL: Game cannot continue (save corruption, physics failure)
  ERROR: Feature broken, fallback active (scene load fail, I/O error)
  WARNING: Feature degraded, no fallback (animation skip, invalid state)
  INFO: Expected condition (no save, photo capture disabled)

Logging destination:
  Editor: OS.print() + EditorDebugLog
  Template (PC): user://debug.log (FileAccess, rotated at 1 MB)
  Template (Web): no file logging (IndexedDB not available)
  Online: sent via telemetry on next session start (if enabled)
```

---

## Phase 8: Architecture Decision Records

### ADR-001: Physics Engine — Jolt

| Field | Value |
|-------|-------|
| **Status** | PROPOSED |
| **Risk** | HIGH |
| **Decision** | Use Godot 4.6 default Jolt physics engine |
| **Rationale** | Godot 4.4+ defaults to Jolt; better performance than GodotPhysics |
| **Risk Description** | Jolt behavior differs from training data; must test collision, slide, nav-mesh |
| **Mitigation** | Prototype First-Person Controller + Monster AI early; validate Jolt behavior |

### ADR-002: Rendering — Vulkan Forward+

| Field | Value |
|-------|-------|
| **Status** | PROPOSED |
| **Risk** | LOW |
| **Decision** | Use Vulkan Forward+ renderer (default for Godot 4.6) |
| **Rationale** | Best performance for multi-light scenes; horror game needs dynamic lighting |
| **Mitigation** | Test on target platforms; fallback to gl compatibility if needed |

### ADR-003: Save Format — JSON + AES-256

| Field | Value |
|-------|-------|
| **Status** | PROPOSED |
| **Risk** | MEDIUM |
| **Decision** | JSON serialization + AES-256 encryption + CRC32 checksum |
| **Rationale** | JSON is debuggable (raw text when decrypted); AES-256 is strong encryption; CRC32 for tamper detection |
| **Mitigation** | Check FileAccess return values; test on all target platforms |

### ADR-004: Anomaly Visuals — VisualShader

| Field | Value |
|-------|-------|
| **Status** | PROPOSED |
| **Risk** | LOW |
| **Decision** | Use VisualShader for anomaly "wrongness" effects (dissolve, distortion) |
| **Rationale** | Godot 4.x VisualShader supports custom expressions; sufficient for horror effects |
| **Mitigation** | Test AgX tonemapper compatibility (4.5+) |

### ADR-005: Audio Architecture — 7-Bus Hierarchy

| Field | Value |
|-------|-------|
| **Status** | PROPOSED |
| **Risk** | LOW |
| **Decision** | 7-bus audio hierarchy (Master, Music, SFX, Ambient, Horror, Voice, UI) |
| **Rationale** | Separation of concerns; per-bus effects (reverb on Horror, compression on SFX) |
| **Mitigation** | Configure buses in project.godot before any system loads |

### ADR-006: Scene Loading — SceneTree.change_scene()

| Field | Value |
|-------|-------|
| **Status** | PROPOSED |
| **Risk** | LOW |
| **Decision** | Use SceneTree.change_scene() for room transitions; custom transition effects on top |
| **Rationale** | Simple API; handles scene unloading automatically; transition effects are UI overlay |
| **Mitigation** | Test transition timing with RoomManager.load_room() |

### ADR-007: Input — InputMap + InputAction

| Field | Value |
|-------|-------|
| **Status** | PROPOSED |
| **Risk** | LOW |
| **Decision** | Use Godot 4.x InputMap for all player input |
| **Rationale** | Standard Godot input system; supports keyboard, mouse, gamepad; remappable |
| **Mitigation** | Configure all actions in project.godot with default bindings |

### ADR-008: UI — Control Tree + CanvasLayer

| Field | Value |
|-------|-------|
| **Status** | PROPOSED |
| **Risk** | MEDIUM |
| **Decision** | Use Godot 4.x Control tree for all UI; CanvasLayer for HUD registers |
| **Rationale** | Standard UI system; AccessKit support (4.5+) for accessibility |
| **Mitigation** | Test with screen reader; use standard Control types where possible |

### ADR-009: Monster AI — Custom Behavior Tree

| Field | Value |
|-------|-------|
| **Status** | PROPOSED |
| **Risk** | HIGH |
| **Decision** | Implement custom behavior tree (not a library); patrol → react → pursue → attack |
| **Rationale** | Simple enough for custom impl; 3 archetypes with distinct patterns |
| **Mitigation** | Prototype Dolls archetype first; validate scare factor |

### ADR-010: Photography — Viewport + RayCast3D

| Field | Value |
|-------|-------|
| **Status** | PROPOSED |
| **Risk** | HIGH |
| **Decision** | Use Viewport for viewfinder rendering; RayCast3D for photo evaluation |
| **Rationale** | Viewport gives camera-independent rendering; RayCast3D detects anomaly in frame |
| **Mitigation** | Prototype early; validate raycast hits anomaly Area3D |

---

## Architecture Summary

**Project**: Show & Tell (preschool-horror)
**Engine**: Godot 4.6
**Renderer**: Vulkan Forward+
**Physics**: Jolt
**Architecture Phase**: Complete (all 8 phases done)

### Systems Mapped

| Layer | Count | Systems |
|-------|-------|---------|
| Foundation | 4 | First-Person Controller, Room/Level, Audio, Save |
| Core | 3 | Night Progression, Anomaly Placement, HUD/UI |
| Feature | 6 | Anomaly, Photography, Monster AI, Survival, Vent, Evidence Submission |
| Presentation | 2 | Evidence Submission, Photo Gallery |
| Polish | 3 | Main Menu, Cutscene, Night 7 Finale |

### Key Risks

1. **Jolt Physics** (HIGH) — 4 systems use CharacterBody3D/NavigationAgent3D/RayCast3D with Jolt. Behavior differs from GodotPhysics. Must prototype early.
2. **Monster AI** (HIGH) — Custom behavior tree + Jolt nav-mesh. AI quality determines game success. Prototype Dolls first.
3. **Photography Evaluation** (HIGH) — RayCast3D + Jolt collision accuracy. If evaluation feels arbitrary, core loop breaks.
4. **Night 7 Finale** (HIGH) — Integration of all systems. Design last; validate subsystems individually first.

### Medium Risks

5. **FileAccess return types** (MEDIUM) — Changed in Godot 4.4+. Must check Error enums.
6. **AccessKit accessibility** (MEDIUM) — Godot 4.5+ addition. Test with screen reader.
7. **AgX tonemapper** (MEDIUM) — Godot 4.5+ glow rework. Test anomaly effects with AgX.

### Performance Budget

- Base gameplay: ~2 ms/frame
- With anomalies: ~7 ms/frame
- Worst case: ~25 ms/frame (night transition, all systems active)
- All within 16.67 ms target for 60 fps

### Implementation Order

1. First-Person Controller (Jolt prototype)
2. Room/Level Management
3. Audio System
4. Save/Persistence (FileAccess fix)
5. Night Progression
6. Anomaly Placement Engine
7. HUD/UI System (AccessKit test)
8. Anomaly System
9. Photography System (Jolt RayCast3D prototype)
10. Monster AI (Jolt nav-mesh prototype)
11. Player Survival
12. Vent System
13. Evidence Submission
14. Photo Gallery
15. Main Menu
16. Cutscene System
17. Night 7 Finale

### Next Steps

1. Prototype First-Person Controller with Jolt physics (validate collision behavior)
2. Build Room/Level Management with nav-mask configuration
3. Configure Audio System 7-bus hierarchy
4. Implement Save/Persistence with FileAccess Error checking
5. Run `/gate-check pre-production` when all MVP systems are implemented
