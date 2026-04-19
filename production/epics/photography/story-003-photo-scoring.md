# Story 003: Photo Scoring and Grading

> **Epic**: Photography
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/photography-system.md` (Photo Scoring and Grading sections)
**Requirement**: `TR-PHO-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: GRADE_THRESHOLDS [0.80, 0.60, 0.40, 0.20] and NIGHT_GRADE_THRESHOLDS [0.70, 0.50, 0.30, 0.15] from TuningKnobs. Per-tier base scores (PHOTO_SCORE_BASE_T1/T2/T3) from Anomaly System. Scoring formula structure in code, parameters in resources.

**ADR Governing Implementation**: ADR-0002 (Physics)
**ADR Decision Summary**: Photo scoring uses distance (from camera transform), facing angle (from player facing vector), and in_frame_ratio (from frustum check). All computed from camera state at shutter time.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `photo_captured(photo_record)` signal carries full PhotoRecord with computed score and grade. Anomaly System receives `anomaly_photographed(instance, score)` per detected anomaly.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Vector3.dot()` for facing angle. `Vector3.angle_to()` for angle computation. Camera frustum bounds via `Camera3D` projection matrix. No post-cutoff API changes for these fundamentals.

**Control Manifest Rules (Core layer)**:
- Required: All scoring thresholds in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Required: Formula structure in code, parameters in resources

---

## Acceptance Criteria

*From GDD `design/gdd/photography-system.md`, scoped to this story:*

- [ ] AC-PHO-09: GIVEN an environmental anomaly (Tier 2, `photo_score_base` 0.8) is perfectly framed (`in_frame_ratio`=1.0, `facing_score`=1.0, `distance_score`=1.0), WHEN the shutter fires, THEN `photo_score` = 0.80 and grade = A.

- [ ] AC-PHO-10: GIVEN a monster anomaly (Tier 3, `photo_score_base` 1.0) at 30° off head-on (`facing_score` ≈ 0.33 with 45° threshold), optimal distance (`distance_score`=1.0), fully framed (`in_frame_ratio`=1.0), WHEN the shutter fires, THEN `photo_score` ≈ 0.33 and grade = D.

- [ ] AC-PHO-11: GIVEN no anomaly is in the camera frustum, WHEN the shutter fires, THEN the photo is stored with `best_score`=0.0 and grade=F, and film is consumed.

- [ ] AC-PHO-12: GIVEN the player photographs the same anomaly twice (scores 0.45 and 0.72), WHEN `get_best_photo_for_anomaly()` is called, THEN it returns the photo with score 0.72.

---

## Implementation Notes

*Derived from ADR-0004 Data-Driven + ADR-0002 Physics + GDD Photo Scoring:*

**Photo scoring formula:**
```
photo_score = photo_score_base * distance_score * facing_score * in_frame_ratio
```

Where:
- `photo_score_base`: From AnomalyDefinition (Tier 1 = 0.6, Tier 2 = 0.8, Tier 3 = 1.0)
- `distance_score`: `clamp(1.0 - abs(distance - optimal_distance) / distance_range, 0.0, 1.0)`
- `facing_score`: `clamp(dot(camera_forward, to_anomaly_forward) * 2.0, 0.0, 1.0)`
  - For monsters: threshold is 45° (head-on = ±45° of camera facing)
  - For environmental: threshold is 60° (head-on = ±60° of camera facing)
- `in_frame_ratio`: Number of anomaly AABB corners inside camera frustum / total corners (0.0–1.0)

**Grade mapping:**
```gdscript
func _compute_grade(best_score: float) -> StringName:
    if best_score >= grade_thresholds[0]:  # 0.80
        return "A"
    elif best_score >= grade_thresholds[1]:  # 0.60
        return "B"
    elif best_score >= grade_thresholds[2]:  # 0.40
        return "C"
    elif best_score >= grade_thresholds[3]:  # 0.20
        return "D"
    else:
        return "F"
```

**PhotoRecord creation:**
```gdscript
func _create_photo_record(image: Image, detected: Array, shutter_transform: Transform3D,
                          shutter_fov: float, flash_active: bool, zoom_level: float) -> PhotoRecord:
    var record := PhotoRecord.new()
    record.photo_id = photos_this_night.size() + 1
    record.image = image
    record.anomalies = []
    record.best_score = 0.0
    record.grade = "F"
    record.room_id = room_manager.current_room
    record.night = night_progression.current_night
    record.timestamp = night_progression.night_elapsed
    record.flash_active = flash_active
    record.zoom_level = zoom_level

    for result in detected:
        var entry := PhotoAnomalyEntry.new()
        entry.anomaly_ref = result.anomaly_instance
        entry.anomaly_id = result.anomaly_id
        entry.photo_score = result.photo_score
        entry.facing_score = result.facing_score
        entry.distance_score = result.distance_score
        entry.in_frame_ratio = result.in_frame_ratio
        record.anomalies.append(entry)

        if result.photo_score > record.best_score:
            record.best_score = result.photo_score

    record.grade = _compute_grade(record.best_score)
    return record
```

**Best photo retrieval:**
```gdscript
func get_best_photo_for_anomaly(anomaly_id: StringName) -> PhotoRecord:
    var best: PhotoRecord = null
    for photo in photos_this_night:
        for entry in photo.anomalies:
            if entry.anomaly_id == anomaly_id:
                if best == null or entry.photo_score > best.best_score:
                    best = photo
    return best
```

**Night evidence score:**
```gdscript
func get_night_evidence_score() -> float:
    var unique_best := {}
    for photo in photos_this_night:
        for entry in photo.anomalies:
            if entry.anomaly_id not in unique_best or entry.photo_score > unique_best[entry.anomaly_id]:
                unique_best[entry.anomaly_id] = entry.photo_score

    var total := anomaly_system.get_total_count()
    if total == 0:
        return 0.0

    var sum := 0.0
    for score in unique_best.values():
        sum += score

    return sum / total
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: PhotoRecord creation and shutter (creates the photo; scoring is computed within)
- [Story 004]: Night evidence score is defined here but may be a separate story for clarity
- [Story 006]: Grade stamp rendering during preview (HUD/UI consumes the grade)
- [Story 007]: Film budget per night (Night Progression owns the budget; Photography consumes it)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PHO-09**: Perfect Tier 2 photo → Grade A
  - Given: Tier 2 anomaly (photo_score_base=0.8), perfectly framed (all factors = 1.0)
  - When: Shutter fires
  - Then: photo_score = 0.8 * 1.0 * 1.0 * 1.0 = 0.80; grade = "A"; PhotoRecord.best_score = 0.80
  - Edge cases: score exactly 0.80 → Grade A (≥ threshold, not >); score 0.799 → Grade B; floating point: 0.8 * 1.0 * 1.0 * 1.0 must equal exactly 0.8 (no precision loss with unit factors)

- **AC-PHO-10**: Monster at 30° off head-on → Grade D
  - Given: Tier 3 monster (photo_score_base=1.0), 30° off head-on, optimal distance, fully framed
  - When: Shutter fires
  - Then: facing_score = clamp(dot(cos(30°) * 2.0, 0.0, 1.0) = clamp(1.732, 0.0, 1.0) = 1.0... wait — facing_score formula: dot product of normalized vectors. At 30°, dot = cos(30°) = 0.866. facing_score = clamp(0.866 * 2.0, 0.0, 1.0) = clamp(1.732, 0.0, 1.0) = 1.0. So photo_score = 1.0 * 1.0 * 1.0 * 1.0 = 1.0 → Grade A.
    - Correction: The GDD says "30° off head-on (facing_score ≈ 0.33 with 45° threshold)". This implies facing_score = max(0, 1 - angle/45) for monsters. So facing_score = 1 - 30/45 = 0.333. photo_score = 1.0 * 1.0 * 0.333 * 1.0 = 0.333 → Grade D.
  - Then: photo_score ≈ 0.33; grade = "D"
  - Edge cases: exactly 45° → facing_score = 1 - 45/45 = 0.0 → photo_score = 0.0 → Grade F (below 0.15 threshold, not detected); 0° (head-on) → facing_score = 1.0; 90° (perpendicular) → facing_score = 0.0

- **AC-PHO-11**: Empty photo (no anomaly in frame)
  - Given: Camera pointed at empty space, no anomalies in frustum
  - When: Shutter fires
  - Then: PhotoRecord created with best_score=0.0, grade="F", anomalies=[]; film_remaining decremented; flash still fires
  - Edge cases: flash charge < 1.0 → no-flash photo still stored; all anomalies in other rooms → same result; player zoomed to 2.0x on empty wall → same result (wasted shot)

- **AC-PHO-12**: Best photo retrieval for re-photographed anomaly
  - Given: Anomaly X photographed twice (scores 0.45 and 0.72)
  - When: Call `get_best_photo_for_anomaly(X.id)`
  - Then: Returns the photo with score 0.72
  - Edge cases: only lower-score photo exists → returns it; no photos of anomaly → returns null; three photos with scores 0.3, 0.5, 0.4 → returns 0.5 (highest, not latest)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/photography/photo_scoring_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Shutter — creates PhotoRecord with scores), Anomaly System must be DONE (provides `evaluate_photo()` with per-anomaly scores)
- Unlocks: Story 004 (Night Evidence Score — depends on PhotoRecord scores), Evidence Submission (consumes photo grades)
