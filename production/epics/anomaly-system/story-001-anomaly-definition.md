# Story 001: AnomalyDefinition Resource

> **Epic**: Anomaly System
> **Status**: Ready
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/anomaly-system.md` (Anomaly Definition Resource section)
**Requirement**: `TR-AS-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: AnomalyTemplate resource defines anomaly type, detection criteria, room eligibility. All gameplay values externalized into Resources. No hardcoded values.

**ADR Governing Implementation**: ADR-0006 (Source Code)
**ADR Decision Summary**: System-based directory structure. `res://assets/config/anomalies/` for AnomalyDefinition resources.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Custom Resource subclass for AnomalyDefinition. Resource loading via `load()` in `_ready()`. No post-cutoff API changes expected for custom Resources.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects

---

## Acceptance Criteria

*From GDD `design/gdd/anomaly-system.md`, scoped to this story:*

- [ ] AC-AS-01: GIVEN an AnomalyDefinition resource is loaded, WHEN the Anomaly System initializes, THEN all photo detection parameters (facing threshold, distance range, base score, detection shape) are accessible.

- [ ] AC-AS-02: GIVEN an AnomalyDefinition with `anomaly_type = MONSTER` and `archetype = DOLL`, WHEN the definition is loaded, THEN all archetype-specific fields (photo_min_distance_monster, photo_max_distance_monster, react_to_flash) are set correctly.

- [ ] AC-AS-03: GIVEN an AnomalyDefinition with `anomaly_type = ENVIRONMENTAL` and `severity_tier = 2`, WHEN the definition is loaded, THEN severity-appropriate defaults apply (PROXIMITY_RADIUS_T2 = 5.0 m, PHOTO_FACING_THRESHOLD_ENV = 60°).

---

## Implementation Notes

*Derived from ADR-0004 Data-Driven:*

```gdscript
# anomaly_definition.gd — Custom Resource for anomaly type definition
class_name AnomalyDefinition extends Resource

@export_group("Identity")
@export var anomaly_id: StringName
@export var display_name: String
@export var anomaly_type: StringName = &"environmental"  # "environmental" or "monster"
@export var severity_tier: int = 1  # 1, 2, or 3
@export var archetype: StringName = &"none"  # "none", "doll", "shadow", "large"

@export_group("Photo Detection")
@export var photo_facing_axis: Vector3 = Vector3.FORWARD
@export var photo_max_distance: float = 6.0
@export var photo_min_distance: float = 0.5
@export var photo_facing_threshold: float = 60.0
@export var photo_score_base: float = 0.6

@export_group("Detection Shape")
@export var detection_shape: Shape3D
@export var detection_offset: Vector3 = Vector3.ZERO

@export_group("Reactivity")
@export var react_to_flash: bool = false
@export var react_to_proximity: bool = true
@export var proximity_radius: float = 3.0
@export var audio_proximity_event: StringName = &""
@export var audio_photo_event: StringName = &""

@export_group("Persistence")
@export var is_anchor: bool = false
@export var description_hint: String = ""
```

*Severity tier defaults (from GDD Tuning Knobs):*

| Tier | photo_score_base | proximity_radius | photo_facing_threshold |
|------|-----------------|-----------------|----------------------|
| 1 (Subtle) | 0.6 | 3.0 m | 60° |
| 2 (Unsettling) | 0.8 | 5.0 m | 60° |
| 3 (Confrontational) | 1.0 | 8.0 m | 45° |

*Monster-specific distance defaults:*

| Type | photo_min_distance | photo_max_distance |
|------|-------------------|-------------------|
| Environmental | 0.5 m | 6.0 m |
| Monster | 1.0 m | 8.0 m |

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Manifest consumption (reads definitions, doesn't create them)
- [Story 004]: Photo detection formulas (uses definition parameters)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AS-01**: AnomalyDefinition fields accessible
  - Given: AnomalyDefinition with photo_max_distance = 6.0, photo_min_distance = 0.5, photo_facing_threshold = 60.0, photo_score_base = 0.8
  - When: Anomaly System loads the resource
  - Then: All fields accessible via the definition reference; values match resource exactly
  - Edge cases: null detection_shape → use default sphere; zero proximity_radius → no proximity audio; is_anchor = true → persists across nights

- **AC-AS-02**: Monster definition fields
  - Given: AnomalyDefinition with anomaly_type = "monster", archetype = "doll"
  - When: Loaded
  - Then: photo_min_distance = 1.0, photo_max_distance = 8.0, archetype = "doll"
  - Edge cases: archetype = "shadow" → photo_max_distance = 8.0 (wall-mounted); archetype = "large" → photo_max_distance = 8.0 (corridor-filling); react_to_flash = true → triggers photo-reaction animation

- **AC-AS-03**: Environmental tier defaults
  - Given: severity_tier = 2 environmental anomaly
  - When: Loaded
  - Then: photo_score_base = 0.8, proximity_radius = 5.0 m, photo_facing_threshold = 60°
  - Edge cases: tier 1 → base 0.6, radius 3.0 m; tier 3 → base 1.0, radius 8.0 m, threshold 45°

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: `production/qa/smoke-anomaly-definition.md` — smoke check pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (config resources are foundational data)
- Unlocks: Story 002 (manifest consumption reads definitions), Story 004 (photo detection reads definition parameters)
