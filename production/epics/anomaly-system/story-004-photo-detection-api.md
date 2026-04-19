# Story 004: Photo Detection API

> **Epic**: Anomaly System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/anomaly-system.md` (Photo-Detection System section, Formulas section)
**Requirement**: `TR-AS-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Physics)
**ADR Decision Summary**: Camera frustum check via AABB corner test. PhysicsDirectSpaceState3D for occlusion raycast. Jolt physics collision layers.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Photo scoring parameters from AnomalyDefinition. TuningKnobs for global thresholds (PHOTO_SCORE_THRESHOLD, PHOTO_FACING_THRESHOLD_ENV/MONSTER).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `is_position_in_frustum()` on Camera3D for frustum check. `PhysicsDirectSpaceState3D.intersect_ray()` for occlusion. Per-frame evaluation when camera raised — must stay within frame budget. Web: evaluate all active anomalies each frame camera raised → limit anomaly count per room.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Guardrail: Photo detection must complete within 2 ms on Web (per 4 ms non-rendering budget)

---

## Acceptance Criteria

*From GDD `design/gdd/anomaly-system.md`, scoped to this story:*

- [ ] AC-AS-08: GIVEN an ACTIVE environmental anomaly directly in front of the camera at 3.0 m distance with 0° facing angle, WHEN `evaluate_photo()` is called, THEN the result for that anomaly has `detected == true`, `facing_score >= 0.9`, `distance_score >= 0.8`, and `photo_score >= PHOTO_SCORE_THRESHOLD`.

- [ ] AC-AS-09: GIVEN an ACTIVE anomaly behind the player (180° from camera forward), WHEN `evaluate_photo()` is called, THEN the result for that anomaly has `detected == false` (frustum check fails).

- [ ] AC-AS-10: GIVEN an ACTIVE anomaly at distance 15.0 m (beyond `photo_max_distance` of 6.0 m for environmental), WHEN `evaluate_photo()` is called, THEN `detected == false` (distance check fails).

- [ ] AC-AS-11: GIVEN an ACTIVE anomaly with a wall collider between it and the camera, WHEN `evaluate_photo()` is called, THEN `detected == false` (occlusion check fails).

- [ ] AC-AS-12: GIVEN an ACTIVE anomaly at 45° from camera forward with `photo_facing_threshold = 60°`, WHEN `evaluate_photo()` is called, THEN `facing_score = max(0, 1 - 45/60) = 0.25`.

- [ ] AC-AS-13: GIVEN a DORMANT anomaly (player has not entered its room), WHEN `evaluate_photo()` is called, THEN that anomaly returns no detection result (DORMANT anomalies are not evaluable).

---

## Implementation Notes

*Derived from ADR-0002 Physics + GDD Photo-Detection Pipeline:*

```gdscript
# Photo detection pipeline (executed in order, early-exit on failure)
func evaluate_photo(camera_transform: Transform3D, camera_fov: float) -> Array[PhotoDetectionResult]:
    var results := []
    var camera_pos := camera_transform.origin
    var camera_forward := -camera_transform.basis.z

    for instance in active_anomalies.values():
        if instance.state != &"ACTIVE":
            continue  # AC-AS-13: DORMANT anomalies not evaluable

        var result := PhotoDetectionResult.new()
        result.anomaly_ref = instance

        # 1. Frustum check
        var shape := instance.detection_shape
        var aabb := shape.get_aabb()
        var world_aabb := aabb  # already in world space (offset from spawn)
        var corners := _get_aabb_corners(world_aabb)
        var visible_corners := 0
        for corner in corners:
            if camera_is_position_in_frustum(camera_transform, corner):
                visible_corners += 1
        result.in_frame_ratio = visible_corners / corners.size()
        if visible_corners == 0:
            result.detected = false
            results.append(result)
            continue  # AC-AS-09: behind player → frustum fails

        # 2. Distance check
        var dist := camera_pos.distance_to(instance.detection_area.global_position)
        if dist < instance.definition.photo_min_distance or dist > instance.definition.photo_max_distance:
            result.detected = false
            results.append(result)
            continue  # AC-AS-10: beyond max distance
        var optimal_dist := (instance.definition.photo_min_distance + instance.definition.photo_max_distance) / 2.0
        var denom := instance.definition.photo_max_distance - instance.definition.photo_min_distance
        result.distance_score = clamp(1.0 - abs(dist - optimal_dist) / denom, 0.0, 1.0)

        # 3. Occlusion check
        var query := PhysicsRayQueryParameters3D.new()
        query.from = camera_pos
        query.to = instance.detection_area.global_position
        query.collide_with_areas = true
        query.collide_with_bodies = true
        query.collision_mask = occlusion_mask
        var space := get_world_3d().direct_space_state
        var hit := space.intersect_ray(query)
        if hit != null and hit.get("collider") != null:
            result.detected = false
            results.append(result)
            continue  # AC-AS-11: occluded

        # 4. Facing angle check
        var to_anomaly := (instance.detection_area.global_position - camera_pos).normalized()
        var angle := camera_forward.angle_to(to_anomaly)
        var threshold := instance.definition.photo_facing_threshold
        result.facing_score = clamp(1.0 - angle / threshold, 0.0, 1.0)  # AC-AS-12: 0.25 at 45°/60°

        # 5. Composite score
        result.photo_score = result.photo_score_base * result.in_frame_ratio * result.facing_score * result.distance_score
        result.detected = result.photo_score >= PHOTO_SCORE_THRESHOLD  # AC-AS-08: threshold check

        results.append(result)

    return results
```

*Formulas (from GDD):*
- `facing_score = max(0.0, 1.0 - (angle / photo_facing_threshold))`
- `distance_score = 1.0 - (abs(distance - OPTIMAL_DISTANCE) / (photo_max_distance - photo_min_distance))`
- `photo_score = photo_score_base * in_frame_ratio * facing_score * distance_score`

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Manifest instantiation (creates anomalies with detection shapes)
- [Story 001]: AnomalyDefinition resource (provides scoring parameters)
- Photography System: photo grading (consumes detection results, doesn't evaluate them)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-AS-08**: Good photo detection
  - Given: ACTIVE environmental anomaly at (3.0, 1.0, 0.0) from camera, 0° facing, photo_max_distance = 6.0, photo_min_distance = 0.5
  - When: `evaluate_photo(camera_transform, fov)` called
  - Then: detected = true, facing_score ≥ 0.9 (0° → 1.0), distance_score ≥ 0.8 (3.0m near optimal), photo_score ≥ PHOTO_SCORE_THRESHOLD (0.15)
  - Edge cases: facing_score at exactly 0° = 1.0; distance at optimal = 1.0; in_frame_ratio = 1.0 (all corners visible)

- **AC-AS-09**: Behind player — frustum fails
  - Given: ACTIVE anomaly at 180° from camera forward
  - When: `evaluate_photo()` called
  - Then: detected = false; in_frame_ratio = 0.0
  - Edge cases: anomaly at 170° → some corners may be in frustum; anomaly at exactly 90° to sides → edge of frustum

- **AC-AS-10**: Beyond max distance
  - Given: ACTIVE anomaly at 15.0 m, photo_max_distance = 6.0 m
  - When: `evaluate_photo()` called
  - Then: detected = false (distance check fails before occlusion or facing evaluated)
  - Edge cases: distance = 6.0 (at max) → passes distance check; distance = 0.4 (below min 0.5) → fails

- **AC-AS-11**: Occlusion by wall
  - Given: ACTIVE anomaly with wall collider between camera and anomaly detection center
  - When: `evaluate_photo()` called
  - Then: raycast hits wall collider; detected = false
  - Edge cases: wall partially blocks → raycast still hits wall (single ray); transparent geometry → raycast ignores transparent colliders (physics layer masking); anomaly at same position as wall → raycast result ambiguous, treat as occluded

- **AC-AS-12**: Facing score formula
  - Given: anomaly at 45° from camera forward, photo_facing_threshold = 60°
  - When: `evaluate_photo()` called
  - Then: facing_score = max(0, 1 - 45/60) = 0.25
  - Edge cases: angle = 60° → facing_score = 0.0; angle = 90° → facing_score = 0.0 (clamped); angle = 0° → facing_score = 1.0

- **AC-AS-13**: DORMANT anomaly not evaluable
  - Given: DORMANT anomaly (player has not entered room)
  - When: `evaluate_photo()` called (e.g., photographing through doorway)
  - Then: anomaly returns no detection result (skipped entirely)
  - Edge cases: anomaly just entered ACTIVE (stagger delay) → still DORMANT during stagger, not evaluable; anomaly in adjacent room → evaluated if in frustum and unoccluded

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/anomaly_system/photo_detection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (AnomalyDefinition provides scoring params), Story 003 must be DONE (ACTIVE anomalies must exist to evaluate)
- Unlocks: Photography System (consumes detection results), Evidence Submission (uses photo scores)
