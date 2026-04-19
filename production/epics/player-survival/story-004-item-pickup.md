# Story 004: Item Pickup/Drop

> **Epic**: Player Survival
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/game-concept.md` (Player Survival section)
**Requirement**: `TR-PLA-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (Input)
**ADR Decision Summary**: Input actions mapped in InputMap. Pickup/drop actions use standard input events. No hover-only interactions (accessibility).

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: Signal-based events — `item_pickup_attempted`, `item_dropped`. No signal chains.

**ADR Governing Implementation**: ADR-0004 (Data-Driven)
**ADR Decision Summary**: Item definitions (name, type, stackable) in TuningKnobs or item database resource.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Area3D for item detection zone. InputAction for pickup/drop. No post-cutoff API changes expected for Area3D signals or InputAction.

**Control Manifest Rules (Core layer)**:
- Required: All gameplay values in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Guardrail: Non-rendering CPU budget < 4 ms on Web (physics + game logic)

**Control Manifest Rules (Presentation layer)**:
- Required: No hover-only interactions (accessibility for all platforms)
- Required: Input actions must work with both keyboard and gamepad

---

## Acceptance Criteria

*From GDD `design/gdd/game-concept.md`, scoped to this story:*

- [ ] AC-PLA-14: GIVEN an item is in the world (photograph, food, battery), WHEN the player enters its pickup range and activates the pickup input, THEN the item is added to the inventory (if space available) and removed from the world.

- [ ] AC-PLA-15: GIVEN the player has an item in their inventory, WHEN the player activates the drop input while looking at the item, THEN the item is removed from inventory and placed in the world at the player's position.

- [ ] AC-PLA-16: GIVEN the player is interacting with an item, WHEN the interaction succeeds, THEN visual feedback is provided (item disappears, inventory HUD updates).

---

## Implementation Notes

*Derived from ADR-0008 Input:*

- Pickup input: mapped to an InputAction (e.g., `interact`)
- Drop input: mapped to an InputAction (e.g., `drop_item`)
- Both keyboard and gamepad must support these actions
- No hover-only interactions — always requires explicit activation

*Derived from ADR-0003 Communication:*

- Emit `item_pickup_attempted(item_id: StringName)` when player tries to pick up
- Emit `item_dropped(item_id: StringName, world_position: Vector3)` when item is dropped
- Do NOT chain signals — HUD and other systems subscribe directly

*Item detection:*

```gdscript
# Use Area3D for pickup detection zone around player
# detection_radius from TuningKnobs: `pickup_detection_radius`
# Only items of type "pickup" are detectable
# Raycast to check line-of-sight before allowing pickup
```

*Item drop:*

```gdscript
# Drop direction: forward from player camera direction (horizontal only, no vertical)
# Drop position: player position + forward_offset (from TuningKnobs `drop_offset`)
# Dropped items become Area3D nodes in world with pickup zone
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 003]: Inventory container (this adds/removes items from the container)
- [Story 005]: Flashlight+battery usage (item-specific behavior)
- [Story 006]: Player state persistence (drop doesn't save, death doesn't drop items)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-PLA-14**: Item pickup
  - Given: Item at position (5, 0, 0), player at (0, 0, 0), `pickup_detection_radius = 3.0`
  - When: Player enters range and activates pickup input
  - Then: Item added to inventory; item node removed from scene; `item_pickup_attempted` fires
  - Edge cases: item outside detection radius → no pickup; inventory full → pickup rejected; item behind wall → raycast blocks pickup; multiple items in range → pick up closest first

- **AC-PLA-15**: Item drop
  - Given: Player has food item in inventory
  - When: Player activates drop input while looking forward
  - Then: Food removed from inventory; food appears at `player_pos + drop_offset`; `item_dropped` fires with position
  - Edge cases: drop into wall → find nearest free position; drop at map edge → clamp to valid area; drop last item → `inventory_empty` fires

- **AC-PLA-16**: Visual feedback on interaction
  - Given: Successful pickup or drop
  - When: Interaction completes
  - Then: Item visually disappears/appears; inventory HUD reflects change
  - Edge cases: rapid pickup/drop → feedback still shows; networked (if applicable) → all clients see same state

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/player_survival/pickup_drop_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 must be DONE (inventory must exist to receive items)
- Unlocks: Story 005 (flashlight needs battery items to be pickable), evidence-submission epic (photos need to be pickable)
