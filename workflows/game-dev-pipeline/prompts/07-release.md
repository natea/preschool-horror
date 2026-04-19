You are preparing the game for release.

Read: all source files in src/, all test results, production/sprints/ for completion status,
design/gdd/game-concept.md for the game identity.

Create these release artifacts:

1. **CHANGELOG.md**: Generated from git history and sprint data.
   Group by: Added, Changed, Fixed, Removed.
   Reference story IDs and GDD systems.

2. **Patch Notes** (production/releases/v1.0-patch-notes.md):
   Player-facing notes. Translate internal terminology to player language.
   No jargon, no story IDs. Focus on what the player experiences.

3. **Build Verification**:
   - Verify PC export succeeds: `godot --headless --export-release "PC" build/`
   - Verify Web export succeeds: `godot --headless --export-release "Web" build/`
   - Run full test suite one final time
   - Check total audio asset size (<20MB per art bible)
   - Check total build size is reasonable for target platforms

4. **Release Checklist** (production/releases/release-checklist.md):
   - All tests pass
   - No P0 bugs open
   - All MVP GDD acceptance criteria verified
   - Builds export cleanly for all target platforms
   - Credits/attribution complete
   - Store page assets ready (if applicable)
   - Version number set

Report: READY TO SHIP or BLOCKERS FOUND with specific items.
