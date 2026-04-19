# Story 005: Settings Integration

> **Epic**: First-Person Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: UI
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-MOV-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (Input)
**ADR Decision Summary**: Input Actions in project settings. Key rebinding via InputMap API at runtime. Settings screen reads/writes project configuration. Input Actions used for all UI navigation.

**ADR Governing Implementation**: ADR-0010 (Save System)
**ADR Decision Summary**: Keybindings saved to user://settings.cfg (ConfigFile). Load at game start, apply to InputMap.

**ADR Governing Implementation**: ADR-0006 (Source Code Architecture)
**ADR Decision Summary**: No Autoloads — settings loaded explicitly at game start.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: InputMap.add_action() and InputMap.action_add_event() are the APIs for runtime key rebinding. ConfigFile for persistence. Web platform: user:// path may not be accessible — Web settings stored in localStorage via OS.get_user_data_dir() workaround.

**Control Manifest Rules (Foundation layer)**:
- Required: Static typing on all class members
- Guardrail: Settings changes must not break existing Input Actions

---

## Acceptance Criteria

*From GDD `design/gdd/first-person-controller.md`, scoped to this story:*

- [ ] AC9: Settings screen allows rebinding of player keybindings (movement, sprint, crouch, interact)

---

## Implementation Notes

*Derived from ADR-0008 Implementation Guidelines:*

```gdscript
# Settings screen (UI) — keybinding rebinding

# For each bindable action (movement, sprint, crouch, interact):
# 1. Display current key from InputMap.get_action("sprint").events[0]
# 2. On button press, enter "listening" state
# 3. On any InputEventKey, replace the action's first event
# 4. Save to ConfigFile

func _rebind_action(action_name: String, current_button: String) -> void:
    # Show UI indicating "press new key"
    # On key press:
    var new_event = InputEventKey.new()
    new_event.keycode = keycode_from_scancode(event.scancode)
    var actions = InputMap.get_action(action_name).events
    if actions.size() > 0:
        actions[0] = new_event
    else:
        InputMap.get_action(action_name).events.append(new_event)
    # Save
    var config = ConfigFile.new()
    config.save("user://settings.cfg")
```

- Use InputMap API for all key changes — do NOT hardcode keycodes in player controller
- Movement keys (WASD) set in project settings at edit time — not reboundable at runtime (but documented as possible)
- Rebindable actions: sprint, crouch, interact
- Settings saved to `user://settings.cfg` (per ADR-0010)
- Settings loaded in game startup sequence (before player controller instantiates)
- Web platform: settings stored in browser localStorage — handle in ConfigFile wrapper

*Derived from ADR-0006 Implementation Guidelines:*

- Settings UI: `src/presentation/ui/screens/settings_screen.tscn`
- Keybinding logic: `src/presentation/ui/screens/settings_screen.gd`
- No Autoload — settings loaded explicitly by game manager at startup

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [UI-HUD Epic, Story on settings]: Volume sliders, graphics options (separate UI story)
- [Save Persistence Epic]: General save system (keybindings are a subset)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-9**: Settings key rebinding
  - Setup: Settings screen open, player has default keybindings
  - Verify: Player selects "rebind interact", presses new key (e.g., F)
  - Pass condition: InputMap.get_action("interact").events contains new key; player can interact using new key; old key no longer triggers interact; settings persist after restart

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: `production/qa/evidence/settings-keybinding-evidence.md` or interaction test

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (player controller must exist with Input Actions)
- Unlocks: None — this is a parallel UI task
