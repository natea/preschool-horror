You are setting up pre-production: epics, stories, and sprint planning.

Read: all GDD files, docs/architecture/architecture.md, docs/architecture/tr-registry.yaml,
docs/architecture/control-manifest.md.

Create these artifacts:

1. **Epics** (production/epics/[slug]/EPIC.md):
   One epic per architectural module. Each epic defines:
   - Scope (which GDD requirements it covers)
   - Acceptance criteria (from the GDD)
   - Dependencies on other epics
   - Estimated effort

2. **Stories** (production/epics/[slug]/story-NNN-[slug].md):
   Break each epic into implementable stories. Each story must have:
   - Clear acceptance criteria (from GDD)
   - Referenced ADR decisions
   - Test evidence requirements (by story type: Logic/Integration/Visual/UI/Config)
   - Story type classification
   - Estimated effort

3. **Sprint Plan** (production/sprints/sprint-001.md):
   First sprint plan with:
   - Selected stories (respecting dependencies)
   - Capacity estimate
   - Sprint goal
   - Risk assessment

4. **UX Specs** (design/ux/*.md):
   For any system with UI Requirements in its GDD, create UX specs
   before the corresponding stories are implemented.

Validate: every story traces back to a GDD requirement via the TR Registry.
No orphan stories. No stories without acceptance criteria.
