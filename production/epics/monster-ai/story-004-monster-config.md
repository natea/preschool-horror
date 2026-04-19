# Story 004: Monster Config Resources

> **Epic**: Monster AI
> **Status**: Ready
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Core Mechanics section)
**Requirement**: `TR-MON-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: All AI parameters in MonsterConfig resource. No hardcoded values. Three archetypes = three MonsterConfig instances.

**ADR Governing Implementation**: ADR-0006 (Source Code)
**ADR Decision Summary**: System-based directory structure. `res://assets/config/monsters/` for MonsterConfig resources.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Custom Resource subclass for MonsterConfig. Resource loading via `load()` in `_ready()`. No post-cutoff API changes expected for custom Resources.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md` and `design/gdd/systems-index.md`, scoped to this story:*

- [ ] AC-MON-12: GIVEN a MonsterConfig resource is assigned to a monster, WHEN the monster initializes, THEN all AI parameters (speed, detection range, aggression) are loaded from the resource.

- [ ] AC-MON-13: GIVEN three monster archetypes (Dolls, Shadows, Large), WHEN each archetype's MonsterConfig is loaded, THEN each has distinct parameter sets that produce different gameplay behavior.

---

## Implementation Notes

*Derived from ADR-0004 Data-Driven:*

```gdscript
# monster_config.gd — Custom Resource for monster AI parameters
class_name MonsterConfig : Resource

# Movement
@export_group("Movement")
@export var patrol_speed: float = 2.0          # m/s during patrol
@export var chase_speed: float = 5.0           # m/s during chase
@export var investigate_speed: float = 3.0     # m/s during investigate
@export var attack_range: float = 1.5          # meters to trigger attack

# Vision
@export_group("Vision")
@export var vision_range: float = 10.0         # meters
@export var vision_angle: float = 90.0         # degrees
@export var vision_check_interval: float = 0.25 # seconds

# Audio
@export_group("Audio")
@export var audio_detection_radius: float = 8.0  # meters
@export var audio_sensitivity: float = 1.0       # multiplier
@export var audio_lost_timeout: float = 3.0      # seconds

# Behavior
@export_group("Behavior")
@export var aggression: float = 0.5              # 0.0 = passive, 1.0 = aggressive
@export var investigate_timeout: float = 5.0     # seconds before returning to patrol
@export var patrol_route: Array[Vector3] = []    # waypoints
@export var attack_cooldown: float = 10.0        # seconds between attacks
@export var retreat_on_photo: bool = true        # retreat when player uses photo mode

# Archetype modifiers (applied on top of base values)
@export_group("Archetype")
@export var archetype: StringName = &"doll"      # "doll", "shadow", "large"
@export var movement_pattern: StringName = &"rigid"  # "rigid", "fluid", "irregular"
```

*Three archetype configs:*

```gdscript
# Doll (aggressive, fast, rigid):
#   patrol_speed = 2.0, chase_speed = 6.0, aggression = 0.8
#   vision_range = 12.0, vision_angle = 120
#   movement_pattern = "rigid"
#   retreat_on_photo = false (Dolls don't retreat)

# Shadow (stealthy, fluid, moderate):
#   patrol_speed = 1.6, chase_speed = 5.5, aggression = 0.5
#   vision_range = 8.0, vision_angle = 180 (wider but shorter range)
#   movement_pattern = "fluid"
#   retreat_on_photo = true

# Large (slow, irregular, high aggression):
#   patrol_speed = 1.0, chase_speed = 4.5, aggression = 0.9
#   vision_range = 15.0, vision_angle = 60 (narrow but far)
#   movement_pattern = "irregular"
#   retreat_on_photo = true
```

*Resource loading:*

```gdscript
# In monster scene:
@export var monster_config: MonsterConfig

func _ready() -> void:
    assert(monster_config != null, "MonsterConfig must be assigned")
    # Parameters read from monster_config at runtime
    # Never modified directly — state tracked in companion object
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine (uses config parameters)
- [Story 002]: Vision cone (uses config parameters)
- [Story 003]: Audio detection (uses config parameters)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-MON-12**: Config parameters loaded
  - Given: MonsterConfig with patrol_speed = 2.0, chase_speed = 5.0, vision_range = 10.0
  - When: Monster `_ready()` completes
  - Then: All parameters accessible via `monster_config` reference; values match resource exactly
  - Edge cases: MonsterConfig not assigned → assertion fails in editor; null patrol_route → monster stays IDLE; aggression = 0.0 → monster never chases (always retreats)

- **AC-MON-13**: Three distinct archetypes
  - Given: Doll, Shadow, Large MonsterConfig instances
  - When: Parameters compared
  - Then: Doll has higher chase_speed and narrower vision; Shadow has wider but shorter vision; Large has lowest speeds and widest vision range
  - Edge cases: all archetypes have valid (non-zero, non-negative) parameters; archetype field matches config purpose; all configs load without errors

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: `production/qa/smoke-monster-config.md` — smoke check pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (config resources are foundational data)
- Unlocks: Story 001 (state machine reads config), Story 002 (vision cone reads config), Story 003 (audio detection reads config)
