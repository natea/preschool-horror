# Story 001: Monster State Machine

> **Epic**: Monster AI
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Core Mechanics section, Player Survival)
**Requirement**: `TR-MON-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Physics)
**ADR Decision Summary**: CharacterBody3D for monster movement. PhysicsDirectSpaceState3D for raycasting vision checks. Jolt physics for collision.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Signal-based state change events — `state_changed`, `state_entered`, `state_exited`. No signal chains.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: MonsterConfig resource for all AI parameters. No hardcoded state transition thresholds.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: State machine via enum + _process or _physics_process. CharacterBody3D.move_and_slide() for movement. No post-cutoff API changes expected for StateMachine patterns or CharacterBody3D.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Guardrail: Non-rendering CPU budget < 4 ms on Web (physics + game logic)

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md` and `design/gdd/systems-index.md`, scoped to this story:*

- [ ] AC-MON-01: GIVEN a monster is in any state, WHEN a perception signal triggers (vision, audio, player detection), THEN the state machine evaluates the transition table and moves to the appropriate state (patrol, chase, investigate, retreat).

- [ ] AC-MON-02: GIVEN the monster is in the PATROL state, WHEN the monster reaches its next patrol waypoint, THEN it selects a new waypoint from its patrol route (per MonsterConfig `patrol_route`) and continues moving.

- [ ] AC-MON-03: GIVEN the monster is in the CHASE state, WHEN the player is no longer detected, THEN the monster transitions to INVESTIGATE (last known position) after `investigate_timeout` seconds.

- [ ] AC-MON-04: GIVEN the monster is in the INVESTIGATE state, WHEN the investigate timeout expires without finding the player, THEN the monster returns to its last patrol waypoint and transitions to PATROL.

- [ ] AC-MON-05: GIVEN three monster archetypes (Dolls, Shadows, Large), WHEN the monster state machine runs, THEN each archetype exhibits distinct movement behavior (Dolls: rigid/snappy, Shadows: fluid/dissolve, Large: irregular cadence).

---

## Implementation Notes

*Derived from systems-index.md Monster AI high-risk notes:*

```gdscript
# Three archetypes with distinct movement:
# Dolls:  rigid, snappy movement. Instant direction changes. Pause at waypoints.
#         patrol_speed = MonsterConfig.patrol_speed (lower value)
#         chase_speed = MonsterConfig.chase_speed (higher value)
# Shadows: fluid, dissolve-like movement. Smooth direction changes. Variable speed.
#         patrol_speed = MonsterConfig.patrol_speed * 0.8
#         chase_speed = MonsterConfig.chase_speed * 1.1
# Large:  irregular cadence. Fast bursts followed by pauses. Unpredictable.
#         patrol_speed = MonsterConfig.patrol_speed (variable: burst + idle cycles)
#         chase_speed = MonsterConfig.chase_speed * 0.9
```

*State machine structure:*

```gdscript
enum State {IDLE, PATROL, CHASE, INVESTIGATE, RETREAT, ATTACK}

var current_state := State.IDLE
var next_waypoint := 0
var investigate_timer := 0.0
var investigate_timeout := 5.0  # from MonsterConfig

# State transitions driven by perception input (vision/audio signals)
func _on_perception_vision_detected(whom: Node3D) -> void:
    match current_state:
        State.PATROL:  current_state = State.CHASE
        State.IDLE:    current_state = State.CHASE
        State.INVESTIGATE: current_state = State.CHASE
        State.RETREAT: current_state = State.CHASE  # player found, pursue
        State.CHASE:   pass  # already chasing

func _on_perception_lost() -> void:
    match current_state:
        State.CHASE:   current_state = State.INVESTIGATE
        State.INVESTIGATE: pass  # timer handles transition
        _: pass

signal state_changed(new_state: State)
signal state_entered(state: State)
signal state_exited(state: State)
```

*Derived from ADR-0003 Communication:*

- Emit `state_changed(new_state)` when state changes
- Emit `state_entered(state)` on state entry
- Emit `state_exited(state)` on state exit
- Do NOT chain signals — other systems subscribe directly

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: Vision cone detection (perception input source)
- [Story 003]: Audio detection (perception input source)
- [Story 005]: Pathfinding (navigation between waypoints)
- [Story 006]: Photo mode retreat (specific retreat trigger)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-MON-01**: State transitions on perception
  - Given: Monster in PATROL state
  - When: Vision detection signal fires (player in sight)
  - Then: State changes to CHASE; `state_changed` emits CHASE; `state_entered(CHASE)` emits
  - Edge cases: monster in RETREAT → transitions to CHASE (player found); monster in ATTACK → no transition (already engaged); rapid perception lost/found → transitions follow correctly

- **AC-MON-02**: Patrol waypoint selection
  - Given: Monster in PATROL at waypoint N, `patrol_route` = [W0, W1, W2, W3]
  - When: Monster reaches waypoint N
  - Then: Next waypoint = (N+1) % route_length; monster moves toward next waypoint
  - Edge cases: patrol_route has 1 waypoint → loops to itself; patrol_route empty → monster stays IDLE; waypoint unreachable → monster waits then retries

- **AC-MON-03**: Chase → Investigate transition
  - Given: Monster in CHASE, player detected then loses detection
  - When: `perception_lost` signal fires
  - Then: State changes to INVESTIGATE; `investigate_timer` starts at `investigate_timeout` (5.0s default)
  - Edge cases: player re-detected during chase → stays in CHASE; monster at max chase distance → transitions to INVESTIGATE at last known position

- **AC-MON-04**: Investigate → Patrol transition
  - Given: Monster in INVESTIGATE, `investigate_timer` counting down
  - When: Timer reaches 0
  - Then: State changes to PATROL; monster moves to last patrol waypoint
  - Edge cases: player detected during investigate → transitions to CHASE; monster at last patrol waypoint → transitions to PATROL immediately

- **AC-MON-05**: Archetype movement differences
  - Given: Doll, Shadow, and Large monsters in same state (CHASE)
  - When: Both chase a target over 5 seconds
  - Then: Doll shows rigid direction changes with pauses; Shadow shows smooth curves; Large shows burst-pause pattern
  - Edge cases: all archetypes reach target (speed balanced via MonsterConfig); movement feels distinct to player

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/monster_ai/state_machine_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 must be DONE (MonsterConfig resource must exist for parameters)
- Unlocks: Story 002 (vision cone feeds into state machine), Story 003 (audio detection feeds into state machine), Player Survival (monster attack trigger)
