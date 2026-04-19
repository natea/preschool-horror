You are executing a production sprint.

Read: production/sprints/ for the current sprint plan, production/epics/ for story files,
docs/architecture/ for ADRs and control manifest.

For each story in the current sprint (in dependency order):

1. **Validate readiness**: check that upstream dependencies are complete and ADRs
   are Accepted (not Proposed).

2. **Implement**: Write the GDScript code following:
   - Coding standards from .claude/docs/coding-standards.md
   - Control manifest rules from docs/architecture/control-manifest.md
   - Engine patterns from docs/engine-reference/godot/modules/
   - Naming conventions from .claude/docs/technical-preferences.md

3. **Write tests**: For Logic-type stories, write unit tests in tests/unit/[system]/.
   For Integration stories, write integration tests in tests/integration/.
   Test naming: [system]_[feature]_test.gd, function naming: test_[scenario]_[expected].

4. **Update story status**: Mark each story as Complete after implementation + tests pass.

After all stories in the sprint are done:
- Update the sprint plan with completion status
- Run a smoke check (verify critical path works end-to-end)
- Report sprint completion metrics (stories done, tests passing, blockers)

Do NOT implement stories whose upstream dependencies are incomplete.
Do NOT modify files outside the story's designated system directory without flagging it.
