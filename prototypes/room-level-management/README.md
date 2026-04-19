# Room Level Management Prototype

## Hypothesis
The preschool layout at ~20m x 15m with 3 MVP rooms (Entry Hall, Main Classroom, Art Corner) feels spatially correct for first-person horror — tight enough to be claustrophobic, large enough for meaningful exploration — and Area3D boundary detection works reliably at doorways without flickering.

## How to Run
```bash
cd prototypes/room-level-management
godot --path .
```
Or open the project in the Godot editor and press F5.

## Controls
- **WASD** — Move (2.0 m/s, matching GDD walk speed)
- **Mouse** — Look
- **ESC** — Toggle mouse cursor

## What's in the Scene
- Three greybox rooms built with CSG primitives at GDD dimensions:
  - **Entry Hall** (6m x 5m) — blue floor, cubby shelf landmark
  - **Main Classroom** (8m x 6m) — brown floor, table + chairs + bulletin board
  - **Art Corner** (4m x 4m) — purple floor, easel landmark
- Area3D boundaries per room (physics layer 4)
- RoomManager autoload with doorway threshold rule
- Debug HUD showing: current room, time in room, transition count, traversal time, position, speed

## What to Test
1. Walk between all 3 rooms — does the debug HUD always show the correct room?
2. Stand in a doorway — does the room flicker? (It shouldn't)
3. Walk from Entry Hall to Art Corner — is traversal time ~5-7 seconds?
4. Does the Main Classroom feel like "the largest room"?
5. Does the Art Corner feel intimate / suffocating?
6. Does the overall space feel navigable but claustrophobic?
7. At 2.0 m/s, does movement feel appropriately slow for horror?

## Status
In progress — first build, untested visually.

## Findings
[To be updated after testing]
