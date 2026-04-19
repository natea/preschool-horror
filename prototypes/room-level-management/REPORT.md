## Prototype Report: Room Level Management

### Hypothesis
The preschool layout at ~20m x 15m with 3 MVP rooms (Entry Hall 6x5m, Main Classroom 8x6m, Art Corner 4x4m) feels spatially correct for first-person horror — tight enough to be claustrophobic, large enough for meaningful exploration — and Area3D boundary detection works reliably at doorways without flickering.

### Approach
Built a standalone Godot 4.6 project with CSG greybox geometry for 3 rooms, Area3D boundary detection with the doorway threshold rule from the GDD, a first-person CharacterBody3D at 2.0 m/s walk speed, and a debug HUD tracking room transitions and traversal times. No art assets, no anomalies, no night progression — pure spatial skeleton testing.

Total build time: ~1 session (prototype code) + 1 session (mouse look bugfix). Shortcuts taken: CSG primitives instead of meshes, runtime collision/material setup via script, no spawn points or vent entries, hardcoded room definitions.

### Result
The prototype runs successfully on Godot 4.6.2 (Metal, Apple M5). All 3 rooms register correctly. Boundary detection works — 8 room transitions logged with zero flickering. The doorway threshold rule (last-fully-entered wins) prevents rapid signal oscillation at doorways as designed.

Key observations from the console log:
- Room registration order is deterministic (entry_hall, main_classroom, art_corner)
- First transition (entry_hall → main_classroom) logged 0.00s due to a minor double-init bug (body_entered fires before initialize_current_room — both set current_room)
- Subsequent transitions show clean, single-fire behavior
- No null current_room states observed

### Metrics

**Traversal times** (from console log, 8 transitions):

| Route | Time | Notes |
|---|---|---|
| Entry Hall → Main Classroom | 0.00s | Double-init artifact (first transition) |
| Main Classroom → Art Corner | 3.75s | Direct walk, no pausing |
| Art Corner → Main Classroom | 8.87s | Likely explored Art Corner before returning |
| Main Classroom → Entry Hall | 4.53s | Direct walk |
| Entry Hall → Main Classroom | 23.85s | Extended exploration of Entry Hall |
| Main Classroom → Art Corner | 14.03s | Extended exploration of Main Classroom |
| Art Corner → Main Classroom | 8.28s | Explored Art Corner |
| Main Classroom → Entry Hall | 6.79s | Direct-ish walk |

**Direct traversal estimates** (subtracting exploration time):
- Entry Hall ↔ Main Classroom: ~4-5 seconds
- Main Classroom ↔ Art Corner: ~3.5-4 seconds
- Full loop (Entry → Classroom → Art → back): ~12-15 seconds

**GDD comparison**: The GDD specifies "no room should feel out-of-reach" and "crossing the full building takes ~12 seconds at 2.0 m/s." The measured direct traversal times align with this — the 3-room MVP subset traverses in ~8-10 seconds end-to-end.

**Technical metrics:**
- Frame time: Not measured (no performance concerns with CSG greybox)
- Boundary flicker: 0 occurrences in 8 transitions
- Transition debounce: Threshold rule worked correctly; 3-frame timeout fallback not triggered (clean exits)
- Iteration count: 2 builds (first had mouse look blocked by await in _ready(); fixed with frame-counting approach)

**Feel assessment**: Not formally collected from user — prototype was validated technically but subjective spatial feel (claustrophobia, room identity, walk speed) requires a dedicated playtest pass with the user walking through and providing feedback.

### Recommendation: PROCEED

The spatial skeleton works. Boundary detection is reliable, traversal times match the GDD's pacing targets, and the 3-room layout provides a navigable space that can be evaluated for horror feel once art, lighting, and anomalies are layered on.

The core technical question — "does Area3D boundary detection work reliably at doorways?" — is answered: **yes**, with the threshold rule preventing flicker. The spatial question — "does the layout feel right for horror?" — is partially answered: dimensions produce correct traversal times, but subjective feel assessment is deferred to a playtest with visual dressing.

### If Proceeding
- **Fix the double-init bug**: `initialize_current_room` should skip if `current_room` is already set by `body_entered`. One-line guard clause.
- **Architecture requirements**: RoomManager as autoload singleton (validated in prototype). RoomData as exported Resource (not implemented in prototype — production needs editor-authored resources instead of hardcoded dictionaries).
- **Production additions**: Spawn point transforms, vent entry NodePaths, adjacency validation assert, night configuration API (`configure_for_night`, `unlock_room`), `RoomRuntimeState` per room.
- **Performance targets**: No concerns at this scale. 3-7 Area3D nodes with simple box collision shapes are negligible.
- **Scope adjustments**: None — the GDD's 3-room MVP layout is confirmed viable at the authored dimensions.
- **Estimated production effort**: Small. The RoomManager pattern is proven. Production implementation is the GDD's full API surface (~15 methods/signals) plus editor resource authoring.
- **Deferred feel test**: Run a playtest session with art-pass lighting (even placeholder) to evaluate claustrophobia, room identity, and walk speed feel. CSG greybox is too abstract for meaningful horror-feel feedback.

### Lessons Learned
1. **`await` in `_ready()` blocks input processing in Godot 4.6.** Mouse look was completely broken until the await was replaced with frame-counting in `_physics_process`. This applies to any node that needs both deferred initialization and immediate input handling — use `call_deferred` or manual frame counting, not `await`.
2. **Area3D `body_entered` fires before manual `overlaps_body()` checks.** The double-init (body_entered sets room, then initialize_current_room sets it again) is harmless but indicates that physics overlap detection is faster than expected. Production should guard against redundant initialization.
3. **CSG greybox is sufficient for spatial validation but not feel validation.** The traversal times and boundary detection can be validated with boxes, but horror claustrophobia requires at minimum lighting contrast and room landmarks. The Art Corner's 4x4m dimensions *should* feel intimate, but white CSG boxes don't communicate that.
4. **Doorway width matters for boundary testing.** The 2.4m and 1.6m doorways in this prototype are wide — realistic for a preschool, but they make the straddling edge case less likely to trigger. Production should test with narrower doorways (0.9m single doors) if any rooms use them.

---

*CD-PLAYTEST skipped — Lean mode.*
