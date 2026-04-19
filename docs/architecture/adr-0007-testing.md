# ADR-0007: Testing Strategy

## Status
**Accepted**

## Date
2026-04-19

## Context

The project uses Godot with GDScript. The game has gameplay systems with complex logic (anomaly spawning, monster AI, night progression, photo scoring) that need automated testing. Visual and feel-based systems (animation, VFX, camera feel) cannot be automated.

The question is what testing framework to use, what to test, and how to structure the test suite.

## Decision

GUT (Godot Unit Test) is used as the test framework. Tests are co-located with source files in each system's directory. Core logic systems are unit-tested; visual systems are manually tested.

### Test Framework

- **Framework**: GUT (Godot Unit Test)
- **Test runner**: `gut_cli.gd` — runs all tests headless
- **Test format**: GUT's built-in test class format with `test_` prefixed methods
- **Assertions**: GUT's assertion methods (`test_equal`, `test_true`, `test_is_instance`, etc.)

### Test Structure

```
tests/
├── gut/                             # GUT framework (pinned version)
├── unit/                            # Automated unit tests
│   ├── room_manager/
│   │   ├── room_manager_room_change_test.gd
│   │   └── room_manager_access_test.gd
│   ├── night_progression/
│   │   ├── night_progression_timer_test.gd
│   │   └── night_progression_tier_test.gd
│   ├── anomaly_spawner/
│   │   ├── anomaly_spawner_pool_test.gd
│   │   └── anomaly_spawner_detection_test.gd
│   ├── anomaly_system/
│   │   ├── anomaly_photography_test.gd
│   │   └── anomaly_detection_test.gd
│   ├── photography/
│   │   └── photo_quality_formula_test.gd
│   ├── monster_ai/
│   │   └── monster_behavior_tree_test.gd
│   └── player_survival/
│       └── player_health_test.gd
├── integration/                     # Integration tests
│   ├── night_start_flow/
│   │   └── night_start_flow_test.gd
│   └── anomaly_detection_flow/
│       └── anomaly_detection_flow_test.gd
├── fixtures/                        # Test fixtures
│   ├── mock_room_data.tres
│   └── mock_night_config.tres
└── helpers/                       # Test helpers
    └── test_utility.gd
```

### Test Naming Convention

| Element | Convention | Example |
|---------|-----------|---------|
| **Test file** | `[system]_[feature]_test.gd` | `anomaly_spawner_pool_test.gd` |
| **Test method** | `test_[scenario]_[expected]` | `test_anomaly_detects_when_close` |
| **Helper function** | `_helper_[name]` | `_helper_create_mock_room` |
| **Fixture** | `mock_[name]` or `fixture_[name]` | `mock_room_data` |

### What to Test (Automated)

| System | Test Type | What to Test |
|--------|----------|-------------|
| **RoomManager** | Unit | Room transitions, access changes, boundary checks |
| **NightProgression** | Unit | Timer countdown, tier advancement, night end detection |
| **AnomalySpawner** | Unit | Spawn pool selection, tier eligibility, detection criteria |
| **AnomalySystem** | Unit | Photo scoring formula, state transitions, detection states |
| **Photography** | Unit | Photo quality formula (distance, angle, stability) |
| **MonsterAI** | Unit | Behavior tree evaluation, state transitions, detection logic |
| **PlayerSurvival** | Unit | Health reduction, death detection, recovery logic |
| **EvidenceSubmission** | Unit | Evidence flow, submission validation |
| **AudioManager** | Unit | Volume levels, audio layer selection |

### What to Test (Manual)

| System | Test Type | How to Test |
|--------|----------|-------------|
| **FPController** | Manual | Playtest: movement, jumping, camera control |
| **Camera** | Manual | Playtest: zoom, FOV, shake feel |
| **VFX** | Manual | Playtest: particle effects, visual clarity |
| **Monster appearance** | Manual | Playtest: monster visibility, scare factor |
| **UI/HUD** | Manual | Playtest: UI responsiveness, readability |
| **Main menu** | Manual | Playtest: navigation, save/load |

### Test Implementation

```gdscript
# Example: photo_quality_formula_test.gd
extends GUTTest

var photo_quality := preload("res://src/feature/photography/photo_quality.gd").new()

func test_quality_full_distance_returns_low() -> void:
    var quality := photo_quality.calculate(10.0, 0.0, 0.5)  # distance, angle, stability
    assert_eq(quality, 0.3)  # minimum quality

func test_quality_close_distance_returns_high() -> void:
    var quality := photo_quality.calculate(1.0, 0.0, 0.5)
    assert_eq(quality, 1.0)  # maximum quality

func test_quality_bad_angle_returns_reduced() -> void:
    var quality := photo_quality.calculate(2.0, 0.5, 0.5)  # 60-degree angle
    assert_true(quality < 0.8)  # angle reduces quality

func test_quality_unstable_returns_reduced() -> void:
    var quality := photo_quality.calculate(2.0, 0.0, 0.1)  # low stability
    assert_true(quality < 0.8)  # stability reduces quality
```

### Test Constraints

- **Determinism**: Tests must produce the same result every run. No `rand()` or time-dependent logic in test code.
- **Isolation**: Each test sets up and tears down its own state. Tests do not depend on execution order.
- **No hardcoded data**: Test fixtures use constants or factory functions, not inline magic numbers (exception: boundary value tests where the exact number IS the point).
- **No external dependencies**: Tests do not call external APIs, databases, or file I/O. Use dependency injection.
- **Headless execution**: Tests must run in headless mode (`--headless` flag). No visual assertions in automated tests.

### Running Tests

```bash
# Run all tests
godot --headless --script tests/gut/gut_cli.gd --path . --select all

# Run specific test file
godot --headless --script tests/gut/gut_cli.gd --path . --select room_manager_room_change_test

# Run with output
godot --headless --script tests/gut/gut_cli.gd --path . --select all --log_format detailed
```

### Technical Constraints

- **No mock frameworks**: GUT does not have a built-in mock framework. Mock objects are created manually using GDScript classes.
- **No test parallelization**: GUT does not support parallel test execution. Tests run sequentially.
- **No test coverage reporting**: GUT does not generate coverage reports. Coverage is tracked manually via code review.

## Alternatives

### Alternative: GDUnit4
- **Description**: GDUnit4 is an alternative Godot test framework with more features
- **Pros**: Better assertion API; better reporting; more features
- **Cons**: Less established than GUT; smaller community; fewer tutorials; potential compatibility issues with Godot 4.6
- **Rejection Reason**: GUT is the most established Godot test framework with the longest track record. GDUnit4 is a valid alternative but GUT is the safer choice.

### Alternative: No automated testing
- **Description**: Rely entirely on manual playtesting
- **Pros**: No test maintenance cost; no framework setup
- **Cons**: No safety net for refactoring; balance formulas cannot be verified automatically; regression testing is manual
- **Rejection Reason**: The GDD requires automated tests for logic systems. Core gameplay formulas (photo scoring, anomaly detection, monster behavior) need automated verification.

### Alternative: Custom test framework
- **Description**: Build a custom test framework tailored to the project's needs
- **Pros**: Tailored to project needs; no external dependencies
- **Cons**: Reinventing the wheel; no community support; high maintenance cost
- **Rejection Reason**: GUT already solves the testing problem. Building a custom framework is unnecessary work.

## Consequences

### Positive
- **Automated verification**: Core logic is verified by automated tests
- **Regression safety**: Refactoring is safer with automated tests
- **Formula verification**: Balance formulas can be verified mathematically
- **Documentation**: Tests serve as living documentation of expected behavior

### Negative
- **Test maintenance cost**: Tests must be updated when code changes
- **Not all systems testable**: Visual and feel-based systems cannot be automated
- **Headless limitations**: Tests run headless — rendering issues are not caught
- **Coverage gaps**: No automated coverage reporting — coverage is tracked manually

### Risks
- **Test rot**: Tests become outdated as code changes. **Mitigation**: Test updates required with code changes; code review for test changes.
- **Coverage gaps**: Important systems are not tested. **Mitigation**: Code review verifies test coverage for all logic systems.
- **Non-deterministic tests**: Tests fail intermittently. **Mitigation**: No `rand()` or time-dependent logic in tests; strict code review.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `anomaly-system.md` | Anomaly detection logic | `anomaly_detection_test.gd` |
| `photography.md` | Photo quality formula | `photo_quality_formula_test.gd` |
| `monster-ai.md` | Monster behavior | `monster_behavior_tree_test.gd` |
| `night-progression.md` | Night progression logic | `night_progression_timer_test.gd` |
| `player-survival.md` | Player health logic | `player_health_test.gd` |

## Performance Implications
- **CPU**: Tests run once during CI — no runtime performance impact
- **Memory**: Tests run in a separate Godot process — no impact on game memory
- **Build time**: Test suite adds ~30 seconds to CI build time
- **Web**: Tests do not run on Web — they are a development-only tool

## Migration Plan

This is a new project — no migration needed. During implementation:

1. Pin GUT framework version and add to `tests/gut/`
2. Create test directory structure as defined in this ADR
3. Create test fixtures for RoomData and NightConfig
4. When implementing each logic system, write corresponding unit tests
5. Code review: verify tests for all logic systems; verify test determinism
6. CI: add test runner to CI pipeline

## Validation Criteria
- [ ] All logic systems have corresponding unit tests
- [ ] All tests run in headless mode
- [ ] All tests are deterministic (same result every run)
- [ ] All tests are isolated (no dependency on execution order)
- [ ] No hardcoded data in test fixtures (except boundary value tests)
- [ ] Integration tests exist for critical flows (night start, anomaly detection)
- [ ] Tests run in CI on every push

## Related Decisions
- ADR-0004 (Data-Driven Design) — Test fixtures use mocked resource data
- ADR-0006 (Source Code Organization) — Tests co-located with source files
- ADR-0005 (Web-Compatible Rendering) — Tests run headless; no rendering assertions
