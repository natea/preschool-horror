# ADR-0008: Input System

## Status
**Accepted**

## Date
2026-04-19

## Context

The game targets PC (Keyboard/Mouse primary, Gamepad partial) and Web. The game is a horror title requiring precise movement (first-person controller), context-sensitive interactions (photography, evidence submission), and state-dependent controls (menu navigation vs. gameplay).

The question is how to structure the input system to support multiple input methods, platform targets, and game states while remaining maintainable.

## Decision

Godot's Input Action system is used with input mappings defined in project settings. Input actions are dispatched via signals to the appropriate system based on the current game state. No custom input abstraction layer is needed.

### Key Interfaces

- **`Input`** (global) — Godot's input system. Actions are defined in project settings, not in code.
- **`InputAction`** — Named input actions (e.g., `move_forward`, `photo_take`, `menu_confirm`)
- **`InputEvent`** — Raw input events (keyboard, mouse, gamepad) mapped to actions
- **`Viewport`** — Input focus management (gameplay vs. menu input routing)

### Input Action Categories

| Category | Actions | Input Methods |
|----------|---------|--------------|
| **Movement** | `move_forward`, `move_backward`, `move_left`, `move_right`, `jump` | Keyboard (WASD/Arrows), Gamepad (Left Stick) |
| **Camera** | `camera_look`, `camera_look_up`, `camera_look_down`, `camera_look_left`, `camera_look_right` | Mouse (Look), Gamepad (Right Stick) |
| **Photography** | `photo_take`, `photo_zoom_in`, `photo_zoom_out`, `photo_frame_toggle` | Mouse (Click/Scroll), Gamepad (A/RS) |
| **Interaction** | `interact`, `evidence_submit`, `inventory_open` | Mouse (E/Click), Gamepad (X) |
| **Menu** | `menu_confirm`, `menu_cancel`, `menu_up`, `menu_down`, `menu_left`, `menu_right` | Keyboard (Enter/Arrows), Gamepad (A/Buttons) |
| **Utility** | `pause`, `screenshot`, `settings_open`, `fullscreen_toggle` | Keyboard (Esc/F11), Gamepad (Start) |

### Input Mapping

Input mappings are defined in the project settings (`project.godot`), not in code:

```ini
# project.godot
[inputs]
move_forward=["w","shift_up","up"]
move_backward=["s","shift_down","down"]
move_left=["a","left"]
move_right=["d","right"]
jump=["space","button_2"]
photo_take=["button_shutter","mouse_button","button_a"]
photo_zoom_in=["mouse_wheel_up","button_rt"]
photo_zoom_out=["mouse_wheel_down","button_lt"]
interact=["e","button_x"]
menu_confirm=["enter","button_a"]
menu_cancel=["esc","button_b"]
```

### Input Dispatch Architecture

```
Input Action → Viewport → InputHandler → System
                  │            │
                  │            └──► GameManager (game state)
                  │                ├── GameplayInputHandler (during gameplay)
                  │                ├── MenuInputHandler (in menus)
                  │                └── CutsceneInputHandler (during cutscenes)
                  │
                  └──► Focus routing (viewport handles input based on focus)
```

### State-Based Input Routing

| Game State | Active Handler | Input Source |
|------------|---------------|--------------|
| **Main Menu** | MenuInputHandler | Viewport focus on menu scene |
| **Gameplay** | GameplayInputHandler | Viewport focus on game scene |
| **Pause Menu** | MenuInputHandler | Overlay on game scene |
| **Cutscene** | CutsceneInputHandler | Restricted input (skip only) |
| **Photo Gallery** | MenuInputHandler | Viewport focus on gallery scene |
| **Settings** | MenuInputHandler | Overlay on game scene |

### InputHandler Base Class

```gdscript
# input_handler.gd — base class for all input handlers
class_name InputHandler extends Node

var enabled: bool = false

func _ready() -> void:
    pass

func _input(event: InputEvent) -> void:
    if not enabled:
        return
    handle_input(event)

func handle_input(event: InputEvent) -> void:
    # Override in subclass
    pass

func enable() -> void:
    enabled = true

func disable() -> void:
    enabled = false
```

### GameplayInputHandler Example

```gdscript
# gameplay_input_handler.gd
class_name GameplayInputHandler extends InputHandler

@onready var player_controller: PlayerController = get_node("../PlayerController")
@onready var camera_controller: CameraController = get_node("../CameraController")
@onready var anomaly_system: AnomalySystem = get_node("../AnomalySystem")

func handle_input(event: InputEvent) -> void:
    if event is InputEventKey:
        if event.keycode == KEY_SPACE and event.pressed:
            player_controller.jump()
        if event.keycode == KEY_E and event.pressed:
            anomaly_system.interact_with_closest_anomaly()

    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            camera_controller.take_photo()
            anomaly_system.photo_anomaly(camera_controller.get_focal_point())

    if event is InputEventMouseMotion:
        camera_controller.add_look_rotation(event.relative)
```

### Technical Constraints

- **No raw input in code**: All input goes through `InputAction` — never `Input.is_key_pressed()` directly in gameplay code.
- **No input polling in `_physics_process`**: Input is handled via `_input()` signals. Polling is only used for continuous actions (movement, camera look) in `_process()`.
- **Gamepad dead zones**: All gamepad axes use configured dead zones. No raw axis values are used for input thresholds.
- **Input priority**: Menu input takes priority over gameplay input when menus are open. This is managed by viewport focus, not by input handling code.

### Web-Specific Constraints

- **No keyboard shortcuts that conflict with browser**: `Ctrl+W`, `Ctrl+R`, `F5` are reserved by the browser. Do not map these to game actions.
- **Touch support**: None planned. Web target is desktop browser only (no mobile).
- **Mouse capture**: Mouse look uses `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)` during gameplay. Mouse is released on pause/menu open.
- **Gamepad on Web**: Web Gamepad API has limited support. Gamepad input on Web requires the browser's Gamepad API and may not work on all devices. **Gamepad is marked as "partial" support on Web.**

## Alternatives

### Alternative: Custom input abstraction layer
- **Description**: Build a custom input system that abstracts keyboard/gamepad/mouse behind a unified API
- **Pros**: Unified input API; easier to add new input methods; input remapping is built-in
- **Cons**: Godot's Input system already provides this; reinventing the wheel; adds indirection; no meaningful benefit for this project
- **Rejection Reason**: Godot's Input Action system already provides action-based input mapping with multi-device support. A custom layer adds complexity without meaningful benefit.

### Alternative: Direct input polling
- **Description**: Use `Input.is_key_pressed()` and `Input.is_mouse_button_pressed()` directly in gameplay code
- **Pros**: Simpler code; no handler indirection
- **Cons**: No action-based mapping; no input remapping; no multi-device support; harder to test
- **Rejection Reason**: Action-based input is required for multi-device support (keyboard + gamepad) and input remapping capability.

### Alternative: Input events only (no polling)
- **Description**: Use only `_input()` events — no continuous polling for movement
- **Pros**: Event-driven; cleaner separation
- **Cons**: Movement and camera look require continuous polling (not event-driven). Events fire on press/release, not continuously.
- **Rejection Reason**: Continuous actions (movement, camera look) require polling in `_process()` or `_physics_process()`. Pure event-driven input cannot handle these.

## Consequences

### Positive
- **Multi-device support**: Keyboard and gamepad work simultaneously via Input Actions
- **Input remapping**: Players can remap inputs via project settings or in-game settings
- **State-based routing**: Input handlers are enabled/disabled based on game state
- **Web compatibility**: Web-specific constraints are documented and handled

### Negative
- **Input mapping in project settings**: Changes require project file edits (not runtime-remappable without additional work)
- **Viewport focus management**: Input routing via viewport focus requires careful scene management
- **Gamepad on Web**: Limited support — partial feature is the right description

### Risks
- **Input conflicts**: Game actions may conflict with browser shortcuts on Web. **Mitigation**: Document Web-specific constraints; test on Web target regularly.
- **Input focus leaks**: Menu input may not be disabled when returning to gameplay. **Mitigation**: Input handler enable/disable is paired with scene transitions; verified in code review.
- **Gamepad drift**: Gamepad axes may have drift. **Mitigation**: Dead zones are configured in project settings; verified during input implementation.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `fp-controller.md` | Keyboard/gamepad movement | Input Actions mapped to both devices |
| `photography.md` | Photo controls | `photo_take`, `photo_zoom_in/out` actions |
| `menu-navigation.md` | Menu controls | MenuInputHandler with game-state routing |
| `player-survival.md` | Interaction controls | `interact`, `evidence_submit` actions |
| All systems | Input method support | Input Actions provide unified action API |

## Performance Implications
- **CPU**: Input handling via `_input()` has negligible CPU cost
- **Memory**: Input Actions are managed by Godot — no additional memory overhead
- **Input latency**: Godot's input system adds < 1 ms latency — within frame budget
- **Web**: Gamepad input on Web has additional latency due to browser Gamepad API

## Migration Plan

This is a new project — no migration needed. During implementation:

1. Define all Input Actions in project settings (`project.godot`)
2. Create `InputHandler` base class in `src/shared/input/`
3. Implement `GameplayInputHandler` and `MenuInputHandler`
4. Wire input handlers to game state transitions (scene changes)
5. Code review: verify no direct `Input.is_key_pressed()` calls; verify input handler enable/disable pairing
6. Test on Web target: verify no browser shortcut conflicts; verify gamepad behavior

## Validation Criteria
- [ ] All input goes through Input Actions (no direct `Input.is_key_pressed()` in gameplay code)
- [ ] Input actions are defined in project settings
- [ ] Input handlers are enabled/disabled with scene transitions
- [ ] No input conflicts with browser shortcuts on Web
- [ ] Gamepad dead zones are configured in project settings
- [ ] Mouse capture is released when menus open
- [ ] Web gamepad input is tested and documented as "partial" support

## Related Decisions
- ADR-0001 (Single-Scene Architecture) — Input routing via viewport focus in single-scene architecture
- ADR-0005 (Web-Compatible Rendering) — Web-specific input constraints documented
- ADR-0003 (Signal Communication) — Input handlers use signals to dispatch actions to systems
