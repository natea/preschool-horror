# Review Log: Anomaly Placement Engine

> **GDD**: design/gdd/anomaly-placement-engine.md
> **Review Date**: 2026-04-11
> **Reviewer**: design-review skill (full depth)
> **Verdict**: PASS with revisions (6 blockers fixed in-session)

---

## Blocking Issues (all resolved)

| # | Issue | Severity | Fix Applied |
| --- | --- | --- | --- |
| B1 | Hot room paradox — weighted allocation gave hot room fewer anomalies than plain rooms due to H×M=1.3125 vs S=8 | BLOCKING | Remainder priority: hot room gets +1 first, then fractional sort |
| B2 | Tier 3 severity plateau — Nights 4-5 both had zero environmental T3 anomalies | BLOCKING | Night 4 PCT_T3 bumped 16%→29%, producing t3_env=1 |
| B3 | Tuning constraint formula violated by Night 7 table values (0.90 > 0.75) | BLOCKING | Rewritten with floor() + monster deduction; execution order clarified as 4-step |
| B4 | OQ-1 unresolved — sync vs async placement undefined | BLOCKING | Resolved: synchronous (BUILDING state internal only) |
| B5 | OQ-6 unresolved — Night 3 MVP monster room unspecified | BLOCKING | Resolved: Main Classroom; all MVP configs fixed to exact counts |
| B6 | Minimum density "must" too rigid for 3-room MVP nights | BLOCKING | Softened to "should" with best-effort qualifier (Night 3+ only) |

## Additional Fixes (non-blocking, applied during revision)

- Worked example (Night 5) corrected: Nap Room now gets 2 anomalies (hot priority), Main Classroom 1
- Entry Hall cap output range: "1 to 3" → "0 to 3"
- T_env variable range: "1-9" → "0-9"
- Template Mode output range: added degraded conditions qualification

## Recommended Items (deferred — non-blocking)

| # | Issue | Notes |
| --- | --- | --- |
| R1 | Interface gap: `get_room_spawn_points()` returns Transform3D but APE needs indices | Address when designing Anomaly System GDD |
| R2 | ~20 ACs reference "logged" with no testable log interface defined | Define debug log contract in implementation phase |
| R3 | Anchor anomaly `is_anchor` has no mechanical specification for Fixed Mode | Specify in Anomaly System GDD |
| R4 | Monster placement lacks positive spatial guidance (only prohibitions) | Address in Monster AI GDD |

## Specialist Findings Summary

- **Game Designer**: Severity escalation plateau and hot room paradox identified as design-breaking
- **Systems Designer**: Formula execution order ambiguity and tuning constraint mathematical error
- **Lead Programmer**: Interface contract gaps between APE and Room Management
- **QA Lead**: Untestable "logged" acceptance criteria, missing Fixed Mode anchor spec

## Cross-Reference Checks

- Night Progression: `anomaly_target(n)` and `monster_count(n)` values confirmed consistent
- Room Management: `get_accessible_rooms()`, `get_room_spawn_points()`, `get_room_data()` confirmed exported
- Game Concept: Four pillars alignment verified (APE serves "Something's Wrong Here" and "One More Night")

---

## Next Actions

- [ ] Run `/design-review` on remaining designed GDDs (First-Person Controller, Room Management, Audio, Night Progression)
- [ ] Address R1 and R3 when designing Anomaly System GDD (#8)
- [ ] Address R4 when designing Monster AI GDD (#10)
- [ ] Design next MVP system: HUD/UI System (#7) or Anomaly System (#8)
