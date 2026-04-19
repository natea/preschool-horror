# Architecture Overview: Show & Tell

**Status**: Living document
**Engine**: Godot 4.6 (GDScript, Vulkan Forward+, Jolt physics)
**Platforms**: PC, Web
**Last Updated**: 2026-04-11

---

## Scene Architecture

Single continuous scene — no streaming, no scene transitions. The preschool
is one Godot scene with 5-7 rooms (3 for MVP) as Area3D child nodes. Player
moves between rooms via doorways; the Room/Level Management system tracks
current room via overlap detection. This design is possible because the game
is a single-floor building with a small footprint.

**Rationale**: Streaming adds complexity for no benefit at this scale. Seamless
room transitions are critical for horror immersion — loading screens break tension.

---

## System Layer Architecture

Systems are organized into dependency layers. Each layer depends only on layers
below it, never above. Designed from Foundation → Presentation order.

| Layer | Systems | Role |
| --- | --- | --- |
| **Foundation** | FP Controller, Room/Level Mgmt, Audio, Save/Persistence | Zero-dependency infrastructure |
| **Core** | Night Progression, Anomaly Placement, HUD/UI | Configure the world per-night |
| **Feature** | Anomaly System, Photography, Monster AI, Player Survival, Vents | Moment-to-moment gameplay |
| **Presentation** | Evidence Submission, Photo Gallery | End-of-night flow |
| **Polish** | Main Menu, Cutscene System, Night 7 Finale | Meta-game and finale |

17 systems total. 9 are MVP. See `design/gdd/systems-index.md` for full
dependency graph and design order.

---

## Communication Pattern

**Signals (event bus)**: Systems communicate via Godot signals. Each system
emits domain events (e.g., `room_entered`, `night_timer_expired`,
`photo_captured`) and subscribes to events from its dependency layer.
No system directly calls methods on a system in a higher layer.

**Configuration calls (top-down)**: Night Progression calls `configure_for_night(n)`
on Foundation systems at night start. This is the only permitted top-down call
pattern — configuration, not runtime coupling.

**Data resources (static)**: Room definitions, anomaly templates, and night
configs are Godot Resources (`.tres`) authored in the editor. Runtime state
is held in companion objects, not baked into resources.

---

## Source Code Organization

```text
src/
├── core/           # Foundation layer (FP controller, room management)
├── gameplay/       # Core + Feature layers (night progression, anomalies,
│                   #   photography, monsters, survival)
├── audio/          # Audio system
├── ui/             # HUD, viewfinder, menus, debrief screens
├── persistence/    # Save/load system
└── tools/          # Debug utilities, editor helpers
```

File naming: `snake_case.gd` matching PascalCase class name.
Scene naming: `PascalCase.tscn` matching root node name.

---

## Data-Driven Design

All gameplay values are externalized into Godot Resources or config files:

- **RoomData** (`.tres`): Static room identity — name, boundaries, spawn slots
- **NightConfig** (`.tres`): Per-night timer, tier, anomaly pool, room access
- **AnomalyTemplate** (`.tres`): Anomaly type, detection criteria, room eligibility
- **TuningKnobs**: Each GDD defines tunable values with safe ranges

No magic numbers in code. Gameplay values are always loaded from resources.

---

## Performance Constraints

| Metric | Budget |
| --- | --- |
| Framerate | 60 fps (16.6 ms frame budget) |
| Draw calls | < 500 |
| Memory | < 512 MB |
| Web build | Must fit browser memory limits |

Instant acceleration/deceleration on player movement (no physics curves)
reduces per-frame cost for web export.

---

## Key Architectural Decisions

1. **Single scene, no streaming** — preschool is small enough; seamless
   transitions preserve horror immersion
2. **Jolt physics** (Godot 4.6 default) — CharacterBody3D for player,
   Area3D for room boundaries and interaction zones
3. **Signal-based decoupling** — systems only know about layers below them;
   all cross-system communication via signals
4. **Design-first workflow** — all 9 MVP systems designed before implementation
   begins; prototypes are throwaway experiments in `prototypes/`
5. **No jump, no crouch** — single-floor preschool; simplifies collision
   and level design significantly
6. **Web-compatible rendering** — Vulkan Forward+, but all visual decisions
   must respect browser memory and GPU limits

---

## Entity Registry

`design/registry/entities.yaml` tracks all named game entities (rooms, anomalies,
monsters, UI elements) with cross-references. Updated alongside each GDD.

---

## Prototype vs Production Code

- `prototypes/` — throwaway experiments, own `project.godot`, not imported into main
- `src/` — production code, follows coding standards, requires tests for logic systems

The camera-system prototype (`prototypes/camera-system/`) validated the
photography raycast approach. Its patterns will inform the production
Photography System but will not be copied directly.
