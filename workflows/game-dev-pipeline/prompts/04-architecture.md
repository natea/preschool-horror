You are creating the technical architecture for the game.

Read all GDD files in design/gdd/, the systems index, and .claude/docs/technical-preferences.md.

Create these artifacts:

1. **Master Architecture Document** (docs/architecture/architecture.md):
   - Module structure mapping to the systems index
   - Data flow between modules (signals, queries, method calls)
   - Autoload/singleton strategy
   - Scene tree structure
   - Performance strategy (frame budget allocation per system)
   - File organization mapping to directory structure

2. **Architecture Decision Records** (docs/architecture/adr-NNN-*.md):
   One ADR per significant technical decision. Each ADR must have:
   - Title, Status (Proposed → Accepted)
   - Context (what problem we're solving)
   - Decision (what we chose)
   - Consequences (tradeoffs)
   - Engine Compatibility (verified for engine version)
   - GDD Requirements Addressed

3. **Control Manifest** (docs/architecture/control-manifest.md):
   Flat rules sheet for programmers:
   - REQUIRED patterns per layer
   - FORBIDDEN patterns
   - GUARDRAILS (soft rules with exceptions)

4. **TR Registry** (docs/architecture/tr-registry.yaml):
   Technical requirement IDs linking GDD requirements to stories.

Cross-reference every GDD requirement against the architecture. Flag any
GDD requirement that has no architectural home.
