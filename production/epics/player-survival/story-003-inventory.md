# Story 003: Inventory System

> **Epic**: Player Survival
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Player Survival section)
**Requirement**: `TR-PLA-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Inventory capacity in TuningKnobs resource. No magic numbers for max slots.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Signal-based inventory events — `inventory_changed`, `item_added`, `item_removed`, `inventory_full`, `inventory_empty`. No signal chains.

**ADR Governing Implementation**: ADR-0006 (Source Code)
**ADR Decision Summary**: System-based directory structure. `src/core/player_survival/inventory.gd`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Array-based inventory with fixed capacity. No post-cutoff API changes expected for Array methods or Resource handling.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Guardrail: Non-rendering CPU budget < 4 ms on Web (physics + game logic)

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md`, scoped to this story:*

- [ ] AC-PLA-10: GIVEN the inventory has capacity (per TuningKnobs `inventory_capacity`), WHEN items are added, THEN the inventory tracks them up to the max slot count.

- [ ] AC-PLA-11: GIVEN the inventory is at capacity, WHEN the player attempts to pick up a new item, THEN the pickup is rejected and the player is notified.

- [ ] AC-PLA-12: GIVEN the inventory contains items, WHEN an item is removed (used, dropped, or consumed), THEN the `item_removed` signal fires and the item is no longer in the inventory.

- [ ] AC-PLA-13: GIVEN the inventory state, WHEN the game saves, THEN the inventory is serialized and restored on load.

---

## Implementation Notes

*Derived from ADR-0004 Data-Driven:*

- Max inventory capacity in `TuningKnobs`: `inventory_capacity` (int, default 6)
- No hardcoded slot limits — all values tunable without code changes
- Resource loaded in `_ready()`, read at runtime

*Derived from ADR-0003 Communication:*

- Emit `inventory_changed(inventory: Array)` on any modification
- Emit `item_added(item: StringName)` when an item is added
- Emit `item_removed(item: StringName)` when an item is removed
- Emit `inventory_full()` when inventory reaches capacity
- Emit `inventory_empty()` when inventory becomes empty
- Do NOT chain signals — other systems subscribe directly

*Inventory data structure:*

```gdscript
# Each slot stores: {id: StringName, quantity: int, metadata: Dictionary}
# For photo-based items: quantity = 1, metadata = {location: Vector2, night: int}
# For consumable items: quantity > 1 possible, metadata = {uses_remaining: int}
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 004]: Item pickup/drop interaction (creates the items, this manages the container)
- [Story 005]: Flashlight+battery mechanics (item usage logic)
- [Story 006]: Player state persistence (save/load wiring, this provides the data)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PLA-10**: Inventory tracks items up to capacity
  - Given: `inventory_capacity = 6` in TuningKnobs
  - When: Add 6 items one at a time
  - Then: All 6 items stored; `inventory_changed` fires 6 times; `item_added` fires 6 times
  - Edge cases: capacity = 0 → no items can be added; capacity = 1 → single slot fills; adding duplicate item type → quantity increments (if consumable) or rejects (if unique)

- **AC-PLA-11**: Pickup rejected at capacity
  - Given: Inventory at capacity (6/6 items)
  - When: Attempt to add a 7th item
  - Then: Item not added; `inventory_full` signal fires; pickup rejected
  - Edge cases: inventory has 5/6 items, add 2 at once → only 1 added, 1 rejected; capacity = 0 → any pickup rejected

- **AC-PLA-12**: Item removal
  - Given: Inventory = [photo_A, photo_B, food]
  - When: Remove photo_B
  - Then: photo_B removed from array; `item_removed` fires with photo_B ID; inventory now [photo_A, food]
  - Edge cases: remove non-existent item → no signal, no error; remove last item → `inventory_empty` fires; consumed item (quantity > 0) → quantity decrements, item persists until quantity = 0

- **AC-PLA-13**: Save/restore inventory
  - Given: Inventory = [photo_A, photo_B, food(3)]
  - When: SaveManager serializes player state
  - Then: Inventory data included in save; on load, inventory restored to [photo_A, photo_B, food(3)]
  - Edge cases: empty inventory → serialized as `[]`; inventory with metadata → metadata preserved; save with no inventory field → restores as empty

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/player_survival/inventory_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (standalone system, though other systems depend on it)
- Unlocks: Story 004 (pickup needs inventory to receive items), Story 005 (flashlight needs battery items), Story 006 (save needs inventory data)
