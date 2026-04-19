# ADR-0004: Data-Driven Design

## Status
**Accepted**

## Date
2026-04-19

## Context

The game has many tunable gameplay values: room dimensions, anomaly spawn rates, night timers, monster speeds, camera zoom ranges, scoring formulas. These values need to be adjustable without code changes to support balancing and iteration.

The question is how to structure data-driven design — what goes into resources, what stays in code, and how the two interact.

## Decision

All gameplay values are externalized into Godot Resources (`.tres`) or static config files. No magic numbers exist in code. Gameplay systems load their configuration from resources and hold runtime state in companion objects.

### Resource Types

| Resource | Extension | Purpose | Runtime Companion |
|----------|-----------|---------|-------------------|
| `RoomData` | `.tres` | Static room identity (name, boundaries, spawn slots) | `RoomState` (scene-local) |
| `NightConfig` | `.tres` | Per-night settings (timer, tier, anomaly pool, room access) | `NightState` (scene-local) |
| `AnomalyTemplate` | `.tres` | Anomaly type, detection criteria, room eligibility | `AnomalyInstance` (spawned dynamically) |
| `MonsterConfig` | `.tres` | Monster type, behavior tree, speed, detection radius | `MonsterState` (spawned dynamically) |
| `TuningKnobs` | `.tres` | Global tuning parameters (camera FOV, sensitivity, volume levels) | N/A (read-only at runtime) |

### Resource Structure

```gdscript
# RoomData.tres (resource script)
class_name RoomData extends Resource

@export var name: StringName
@export var display_name: String
@export var boundaries: Array[Vector3]
@export var spawn_slots: Array[Vector3]
@export var accessible_rooms: Array[StringName]

# NightConfig.tres (resource script)
class_name NightConfig extends Resource

@export var night_number: int
@export var night_duration: float = 180.0  # seconds
@export var anomaly_pool: Array[StringName] = ["kitchen_cabinet", "hallway_shadow"]
@export var accessible_rooms: Array[StringName] = ["classroom", "office"]
@export var monster_tier: int = 1

# AnomalyTemplate.tres (resource script)
class_name AnomalyTemplate extends Resource

@export var id: StringName
@export var anomaly_type: StringName = "cabinet"
@export var display_name: String
@export var description: String
@export var room_eligible: Array[StringName]
@export var detection_criteria: Dictionary  # {"min_distance": 2.0, "duration": 3.0}
@export var night_eligible: Array[int] = [1, 2, 3, 4, 5, 6]
@export var photo_quality_min: float = 0.3
@export var photo_quality_max: float = 1.0
```

### Loading Pattern

```gdscript
# Load resources at scene start
class ResourceManager:
    static func load_room_data(path: String) -> RoomData:
        return load(path) as RoomData

    static func load_night_configs() -> Array[NightConfig]:
        var configs: Array[NightConfig] = []
        for i in range(1, MAX_NIGHTS + 1):
            var path: String = "res://data/nights/night_%d.tres" % i
            var cfg: NightConfig = load(path) as NightConfig
            if cfg:
                configs.append(cfg)
        return configs
```

### Code vs Data Boundary

| Category | Goes in Resource | Stays in Code |
|----------|-----------------|---------------|
| **Tunable values** | Speeds, durations, ranges, thresholds | Constants (PI, frame rates) |
| **Static identity** | Names, descriptions, display names | Class names, file paths |
| **Configuration** | Room boundaries, spawn slots, pools | Algorithm parameters (e.g., interpolation factor) |
| **Runtime state** | Never — state is in companion objects | All mutable state |
| **Behavior** | Never — behavior is in code | Behavior trees, AI logic |
| **Formulas** | Parameter values (coefficients, exponents) | Formula structure (code) |

### Formula Documentation

Formulas are documented in GDDs, not in resources. Resources contain the parameter values; GDDs contain the formula structure.

```gdscript
# Example: Photo quality formula (documented in design/gdd/photography.md)
# quality = base_quality * distance_factor * angle_factor * stability_factor
#   base_quality: from AnomalyTemplate.photo_quality_min/max (resource)
#   distance_factor: clamp(1.0 - (distance / max_distance), 0.1, 1.0) (code)
#   angle_factor: clamp(dot(view_normal, to_anomaly_normal) * 2.0, 0.0, 1.0) (code)
#   stability_factor: clamp(stability / min_stability, 0.0, 1.0) (code)
```

### Technical Constraints

- **Resources are read-only at runtime**: Resources define configuration; they are never mutated. Runtime state is held in companion objects.
- **No resource loading in `_physics_process`**: All resources are loaded in `_ready()` or earlier. Physics frame budgets cannot tolerate I/O.
- **No runtime resource creation**: Resources are authored in the editor and loaded from disk. `Resource.new()` + property assignment at runtime is forbidden.
- **Resource paths are typed**: Use `class_name` on resource scripts to enable type-safe loading with `as` casts.

## Alternatives

### Alternative: JSON config files
- **Description**: Store all gameplay data in `.json` files loaded at runtime
- **Pros**: No Godot editor dependency; version-control friendly; easier to diff
- **Cons**: No visual editing in Godot; no type checking; manual serialization; loses Godot's resource pipeline (import, caching, dependency tracking)
- **Rejection Reason**: Godot's resource system provides editor authoring, type safety, and dependency tracking that JSON cannot match. For a Godot-native project, resources are the natural choice.

### Alternative: Hardcoded values with tuning constants
- **Description**: Define all values as `const` or `static const` in code
- **Pros**: No resource loading; fully type-checked; no serialization
- **Cons**: Every balance change requires code change and rebuild; no editor authoring; no designer iteration
- **Rejection Reason**: The GDD specifies that gameplay values must be data-driven. Hardcoded values prevent iteration without code changes.

### Alternative: Script resources (`.gd` as resources)
- **Description**: Use GDScript instances as configuration objects
- **Pros**: Flexible; can include logic
- **Cons**: No editor support; no type safety; harder to version control; serialization is fragile
- **Rejection Reason**: `.tres` resources provide editor authoring and reliable serialization that script resources lack.

## Consequences

### Positive
- **Designer iteration**: Balance changes require no code changes or rebuilds
- **Type safety**: `class_name` on resources enables type-safe loading with `as` casts
- **Editor authoring**: Designers can edit resources in the Godot editor
- **Version control**: `.tres` files are text-based (in inline format) and diffable
- **No runtime state in data**: Resources are immutable; state is in companion objects

### Negative
- **Resource file overhead**: Each resource is a separate file — more files to manage
- **Editor dependency**: Values can only be authored in the Godot editor
- **Serialization limits**: Complex data types (arrays of custom objects) require careful serialization
- **Inline vs external format**: `.tres` files can be in external (binary) or inline (text) format. **Must use inline format** for version control.

### Risks
- **Resource format drift**: Godot changes `.tres` format between versions. **Mitigation**: Keep resources in inline text format; test resource loading after engine updates.
- **Circular resource references**: Resources referencing each other can cause load order issues. **Mitigation**: No circular references; resources reference by StringName path only.
- **Resource caching**: Godot caches loaded resources. **Mitigation**: Use `ResourceLoader.load()` (cached) for normal loading; `ResourceLoader.load_threaded()` only if load time exceeds 100ms.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `night-progression.md` | Night configs per night | `NightConfig` resource per night |
| `anomaly-placement.md` | Anomaly templates with detection criteria | `AnomalyTemplate` resource per anomaly type |
| `photography.md` | Tunable camera parameters | `TuningKnobs` resource |
| `monster-ai.md` | Monster configs with behavior | `MonsterConfig` resource |
| `room-management.md` | Room definitions | `RoomData` resource per room |

## Performance Implications
- **CPU**: Resource loading happens in `_ready()` or earlier — no frame budget impact
- **Memory**: Godot caches loaded resources — single copy per resource path
- **Serialization**: Inline `.tres` format is text-based — slower to load than binary, but acceptable for this project's scale
- **Web**: Inline `.tres` files are included in the export — no runtime I/O needed

## Migration Plan

This is a new project — no migration needed. During implementation:

1. Create resource scripts for each resource type (`room_data.gd`, `night_config.gd`, etc.)
2. Create the `data/` directory structure in the project
3. Author MVP room and night resources in the Godot editor
4. Code review: verify no hardcoded gameplay values; verify resources are read-only at runtime
5. Validate resource loading in `_ready()` — no loading in `_physics_process()`

## Validation Criteria
- [ ] No gameplay value is hardcoded in code (speeds, durations, thresholds, ranges)
- [ ] All resources are loaded in `_ready()` or earlier — never in `_physics_process()`
- [ ] Resources are read-only at runtime — state is in companion objects
- [ ] All resource files are in inline text format (not external binary)
- [ ] All resource scripts have `class_name` for type-safe loading

## Related Decisions
- ADR-0001 (Single-Scene Architecture) — RoomData resources define room boundaries
- ADR-0003 (Signal Communication) — NightConfig resources drive `configure_for_night()`
- ADR-0006 (Source Code Organization) — `data/` directory structure for resources
