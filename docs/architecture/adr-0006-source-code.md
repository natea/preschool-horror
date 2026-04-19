# ADR-0006: Source Code Organization

## Status
**Accepted**

## Date: 2026-04-19

## Context

The project has 17 systems organized in a dependency layer architecture. The codebase needs a clear directory structure that enforces separation of concerns and makes it obvious which system owns which file.

The question is how to organize the source code directory structure.

## Decision

The project uses a system-based directory structure under `src/` that aligns with the dependency layer hierarchy. Each system has its own directory with a consistent file layout.

### Directory Structure

```
src/
├── foundation/                    # Layer 1: Foundation
│   ├── fp_controller/
│   │   ├── player_controller.gd
│   │   ├── player_controller.tscn
│   │   └── player_controller_test.gd
│   ├── room_manager/
│   │   ├── room_manager.gd
│   │   ├── room_manager.tscn
│   │   ├── room_data.gd           # Resource script
│   │   └── room_data.tres         # Resource instance
│   ├── audio_manager/
│   │   ├── audio_manager.gd
│   │   └── audio_manager.tscn
│   └── save_system/
│       ├── save_system.gd
│       └── save_slot.gd           # Resource script
├── core/                          # Layer 2: Core
│   ├── night_progression/
│   │   ├── night_progression.gd
│   │   ├── night_progression.tscn
│   │   ├── night_config.gd        # Resource script
│   │   └── night_config.tres      # Resource instance
│   └── anomaly_placement/
│       ├── anomaly_spawner.gd
│       └── anomaly_template.gd    # Resource script
├── feature/                       # Layer 3: Feature
│   ├── anomaly_system/
│   │   ├── anomaly_system.gd
│   │   └── anomaly_instance.gd
│   ├── photography/
│   │   ├── camera_controller.gd
│   │   └── camera_controller.tscn
│   ├── monster_ai/
│   │   ├── monster_ai.gd
│   │   ├── monster_config.gd      # Resource script
│   │   └── monster_ai.tscn
│   ├── player_survival/
│   │   ├── player_survival.gd
│   │   └── player_health.tscn
│   └── vents/
│       ├── vent_system.gd
│       └── vent.tscn
├── presentation/                  # Layer 4: Presentation
│   ├── evidence_submission/
│   │   ├── evidence_submission.gd
│   │   └── evidence_submission.tscn
│   └── photo_gallery/
│       ├── photo_gallery.gd
│       └── photo_gallery.tscn
├── polish/                        # Layer 5: Polish
│   ├── main_menu/
│   │   ├── main_menu.tscn
│   │   └── main_menu.gd
│   ├── cutscene_system/
│   │   ├── cutscene_system.gd
│   │   └── cutscene.tscn
│   └── night7_finale/
│       ├── night7_finale.gd
│       └── night7_finale.tscn
├── shared/                        # Cross-cutting utilities
│   ├── constants/
│   │   ├── game_constants.gd      # Global constants
│   │   └── rendering_constants.gd # Rendering budgets
│   ├── signals/
│   │   └── signal_registry.gd     # Signal documentation
│   └── types/
│       └── game_types.gd          # Global type definitions
└── data/                          # Game data (resources)
    ├── rooms/
    │   ├── classroom.tres
    │   └── office.tres
    ├── nights/
    │   ├── night_1.tres
    │   └── night_2.tres
    ├── anomalies/
    │   └── cabinet_anomaly.tres
    └── tuning/
        └── tuning_knobs.tres
```

### File Naming Convention

| File Type | Convention | Example |
|-----------|-----------|---------|
| **Script** | `snake_case` matching class name | `player_controller.gd` |
| **Scene** | `PascalCase` matching root node | `PlayerController.tscn` |
| **Test** | `[name]_test.gd` | `player_controller_test.gd` |
| **Resource script** | `snake_case` matching class name | `room_data.gd` |
| **Resource instance** | `snake_case` + `.tres` | `classroom.tres` |
| **Constants** | `snake_case_constants` | `game_constants.gd` |

### Class Naming Convention

| Type | Convention | Example |
|------|-----------|---------|
| **Game classes** | `PascalCase` | `PlayerController`, `RoomManager` |
| **Resource classes** | `PascalCase` + suffix | `RoomData`, `NightConfig` |
| **Internal helpers** | `_` prefix | `_RoomState` (private class) |
| **Interfaces** | `I` prefix | `IAudioSource` (if interfaces needed) |

### System Directory Rules

1. **Each system owns its directory**: All files belonging to a system go in its directory. No cross-directory file access without going through the system's public API.
2. **No shared code in system directories**: Common utilities go in `src/shared/`. If a pattern repeats across 3+ systems, extract to shared.
3. **Resources live with their system**: Resource scripts (`.gd`) and instances (`.tres`) for a system go in that system's directory under `data/`.
4. **Tests co-located with code**: Test files go in the same directory as the code they test, named `[name]_test.gd`.
5. **No circular system references**: System N may reference System N-1, but not System N+1 or beyond.

### Technical Constraints

- **No Autoload singletons**: Systems must not use Godot Autoloads. Systems access dependencies via scene hierarchy or dependency injection.
- **No global state**: All state is held in scene nodes or companion objects. No module-level mutable variables.
- **No cross-layer imports**: A system's `.gd` files may only import types from its own directory or from lower layers.
- **No dynamic loading at runtime**: All scenes are loaded via `load()` or `preload()` — no dynamic path strings for scene loading.

## Alternatives

### Alternative: Layer-based directory structure
- **Description**: Group files by layer (`foundation/`, `core/`, `feature/`, etc.) with systems as subdirectories
- **Pros**: Enforces layer awareness; makes layer boundaries explicit
- **Cons**: This is what we have — it works well
- **Selected**: This is the chosen approach

### Alternative: Feature-based directory structure
- **Description**: Group files by feature (`player/`, `rooms/`, `nights/`, `anomalies/`) with cross-cutting concerns as subdirectories
- **Pros**: Feature-focused; easier to find all files for a feature
- **Cons**: Blurs layer boundaries; makes it harder to enforce dependency model
- **Rejection Reason**: Layer-based structure enforces the dependency model better. Features cross layers naturally.

### Alternative: Flat directory structure
- **Description**: All scripts in `src/`, all scenes in `scenes/`, all resources in `data/`
- **Pros**: Simple; no nesting
- **Cons**: No system ownership; hard to find files; no separation of concerns
- **Rejection Reason**: With 17 systems, a flat structure becomes unmanageable quickly.

## Consequences

### Positive
- **Clear ownership**: Each system's files are in one place
- **Layer awareness**: Directory structure mirrors the dependency hierarchy
- **Discoverability**: Easy to find files for a given system
- **Test co-location**: Tests are next to the code they test

### Negative
- **Deeper paths**: File paths are longer (`src/foundation/room_manager/room_manager.gd`)
- **Resource location**: Resources live in `data/` subdirectories, not next to code

### Risks
- **Directory sprawl**: Systems may create many small files. **Mitigation**: One directory per system; no nesting within system directories.
- **Shared code drift**: `src/shared/` may accumulate unrelated utilities. **Mitigation**: Review `src/shared/` additions in code review; require 3+ usages before adding to shared.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| All systems | Code organization | System-based directories under `src/` |
| `fp-controller.md` | Player controller files | `src/foundation/fp_controller/` |
| `room-management.md` | Room management files | `src/foundation/room_manager/` |
| `night-progression.md` | Night progression files | `src/core/night_progression/` |

## Performance Implications
- **Loading**: No impact — all files are loaded at editor build time or via `preload()`
- **Memory**: No impact — directory structure does not affect runtime memory
- **Network**: No impact — single-player only

## Migration Plan

This is a new project — no migration needed. During implementation:

1. Create the directory structure as defined in this ADR
2. When implementing each system, create its directory and place files there
3. Code review: verify files are in the correct system directory; verify no cross-layer imports
4. When extracting shared code, add to `src/shared/` with code review approval

## Validation Criteria
- [ ] Each system has its own directory under the correct layer
- [ ] All system files are in the correct directory
- [ ] No cross-layer imports exist (verified by code review)
- [ ] No Autoload singletons are used
- [ ] No global mutable state exists
- [ ] Tests are co-located with the code they test

## Related Decisions
- ADR-0003 (Signal Communication) — Signal flow direction aligns with layer hierarchy
- ADR-0004 (Data-Driven Design) — `data/` directory structure for resources
- ADR-0007 (Testing Strategy) — Test files co-located with source files
