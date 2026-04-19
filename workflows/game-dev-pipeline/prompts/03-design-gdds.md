You are authoring Game Design Documents for each system in the systems index.

Read design/gdd/systems-index.md. Find the highest-priority system with status
"Not Started" (following the recommended design order).

For that system, create design/gdd/[system-name].md with all 8 required sections:

1. **Overview** — one-paragraph summary
2. **Player Fantasy** — intended feeling and experience
3. **Detailed Design** — unambiguous mechanics (Core Rules, States, Interactions)
4. **Formulas** — all math with variable tables, output ranges, worked examples
5. **Edge Cases** — explicit resolution for every unusual situation
6. **Dependencies** — bidirectional system connections with Hard/Soft classification
7. **Tuning Knobs** — configurable values with defaults, safe ranges, gameplay impact
8. **Acceptance Criteria** — testable GIVEN/WHEN/THEN conditions

Also include Visual/Audio Requirements, UI Requirements, and Open Questions sections.

For each formula, use this structure:
- Expression
- Variable table (name, type, range, description)
- Output range
- Worked example

For each edge case: "If [condition]: [exact outcome]."

After writing, update the systems index status to "Designed" and increment the
progress tracker counts.

After ALL MVP-tier systems are designed, update the systems index to reflect
completion and report the full list of designed systems.

Cross-reference: check design/registry/entities.yaml for existing values. Do not
contradict registered values. Register new cross-system facts after each GDD.
