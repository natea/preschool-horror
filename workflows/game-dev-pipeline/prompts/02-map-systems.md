You are decomposing a game concept into implementable systems.

Read design/gdd/game-concept.md for the game's core loop, mechanics, and pillars.

Create design/gdd/systems-index.md with:

1. Systems Enumeration — list every system the game needs. For each:
   - System name, category, priority tier (MVP/Vertical Slice/Alpha/Full Vision)
   - Dependencies (what other systems it requires)
   - Status (Not Started)

2. Dependency Map — organize systems into layers:
   - Foundation (no dependencies)
   - Core (depends on Foundation)
   - Feature (depends on Core)
   - Presentation (depends on Features)
   - Polish (depends on everything)

3. Recommended Design Order — Foundation first, then Core, then Feature, etc.
   Within each layer, order by dependency count (most-depended-on first).

4. High-Risk Systems — flag systems with technical or design risk.

5. Progress Tracker — counts of designed/reviewed/approved systems.

Verify the dependency graph is a clean DAG (no circular dependencies).
Write the result to design/gdd/systems-index.md.
