# Story 005: Pathfinding

> **Epic**: Monster AI
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Core Mechanics section)
**Requirement**: `TR-MON-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Physics)
**ADR Decision Summary**: Jolt physics navigation. No NavMesh2D — use 3D navigation. Godot 4.6 Jolt default means navigation must work with Jolt collision layers.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Patrol routes defined in MonsterConfig. Path recalculation interval tunable.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: NavigationServer3D for pathfinding. NavigationRegion3D with NavMesh for the preschool. Jolt physics as default physics engine (4.6) — verify NavMesh compatibility with Jolt. Web: pathfinding must complete within frame budget.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Guardrail: Pathfinding must complete within 1 ms on Web (per 4 ms non-rendering budget)

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md`, scoped to this story:*

- [ ] AC-MON-14: GIVEN the monster needs to move to a target position, WHEN pathfinding is requested, THEN a valid path through the preschool navigation mesh is computed and the monster follows it.

- [ ] AC-MON-15: GIVEN the monster is following a path, WHEN the path becomes invalid (target moved or navigation mesh changed), WHEN the monster detects the invalidation, THEN the path is recalculated.

- [ ] AC-MON-16: GIVEN the monster is in PATROL state, WHEN the monster reaches its current patrol waypoint, THEN a new waypoint is selected from the patrol route in MonsterConfig and a path is computed.

---

## Implementation Notes

*Derived from ADR-0002 Physics:*

```gdscript
# Navigation setup for preschool:
# NavigationRegion3D with NavMesh covering all walkable areas
# Monster collision layer must not conflict with navigation mesh
# Navigation server query: NavigationServer3D.map_get_closest_point(nav_map, query_point)

# Path computation:
# var path := NavigationServer3D.map_get_path(nav_map, from, to, false)
# Follow path by moving toward each waypoint sequentially
# Recalculate when: target position changes significantly, or path is no longer valid
```

*Path following:*

```gdscript
var current_path := PackedVector3Array()
var path_index := 0
var path_recalc_interval := 2.0  # from MonsterConfig
var path_recalc_timer := 0.0

func _physics_process(delta: float) -> void:
    if current_path.size() == 0:
        return

    var target := current_path[path_index]
    var direction := (target - global_position).normalized()

    # Move toward target
    var velocity := direction * get_speed_for_state(current_state)
    move_and_slide(velocity)

    # Check if reached waypoint
    if global_position.distance_to(target) < 0.1:
        path_index += 1
        if path_index >= current_path.size():
            # Reached end of path
            current_path = PackedVector3Array()
            path_index = 0
        else:
            # Recalculate path to same target from new position
            if path_recalc_timer >= path_recalc_interval:
                _recalculate_path()
                path_recalc_timer = 0.0
        path_recalc_timer += delta
```

*Patrol route handling:*

```gdscript
func _select_next_patrol_waypoint() -> void:
    var route := monster_config.patrol_route
    if route.is_empty():
        return
    next_waypoint = (next_waypoint + 1) % route.size()
    var target := route[next_waypoint]
    current_path = _compute_path(global_position, target)
```

*Derived from ADR-0003 Communication:*

- Emit `path_computed(path: PackedVector3Array)` when path is ready
- Emit `path_invalidated()` when current path is no longer valid
- Do NOT chain signals — state machine subscribes directly

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine (decides when to pathfind)
- [Story 004]: Patrol route data (defines waypoints)
- [Story 006]: Retreat path (specific path target, uses same pathfinding)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-MON-14**: Path computed and followed
  - Given: Monster at (0,0,0), target at (10,0,0), valid NavMesh between them
  - When: Pathfinding requested
  - Then: Valid path returned; monster moves along path waypoints toward target
  - Edge cases: no path between monster and target → empty path, monster waits; target on monster position → empty path; path through narrow corridor → monster navigates correctly

- **AC-MON-15**: Path invalidation and recalculation
  - Given: Monster following path, target moves 5 meters
  - When: Path recalculation timer expires
  - Then: New path computed from monster's current position to new target
  - Edge cases: target moves while monster at waypoint → path recalculated from waypoint; navigation mesh temporarily invalid → monster pauses then retries; rapid target movement → path recalculated each interval

- **AC-MON-16**: Patrol waypoint transition
  - Given: Monster at patrol waypoint N, `patrol_route` = [W0, W1, W2, W3]
  - When: Monster reaches waypoint N
  - Then: Next waypoint = (N+1) % 4; path computed to new waypoint; monster continues patrol
  - Edge cases: patrol_route has 2 waypoints → loops between them; patrol_route has 1 waypoint → stays there; waypoint blocked → path invalid, retry

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/monster_ai/pathfinding_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 must be DONE (patrol route data), Room/Level Management must be DONE (preschool NavMesh must exist)
- Unlocks: Monster AI epic (pathfinding enables all monster movement), Night 7 Finale (monster chase paths)
