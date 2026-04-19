# Epic: Anomaly System

> **Layer**: Core
> **GDD**: design/gdd/anomaly-system.md
> **Architecture Module**: `src/core/anomaly_system/`
> **Status**: Ready
> **Stories**: 6 created

## Overview

Implements the anomaly spawning and detection system: random anomaly generation (glowing toys, moving objects, shadow figures), anomaly detection zones via Area3D, anomaly lifecycle (spawn → persist → despawn), anomaly template resources, and the tension-building mechanic that escalates anomaly frequency and intensity across nights.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Data-Driven | AnomalyTemplate resource, spawn rates in TuningKnobs | LOW |
| ADR-0002: Physics | Area3D detection zones, collision shapes | LOW |
| ADR-0003: Communication | Anomaly spawned/ detected/ despawned signals | LOW |
| ADR-0001: Scene Architecture | All anomalies in single scene, no streaming | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-AS-001 | AnomalyDefinition resource with photo detection params | ADR-0004 ✅ |
| TR-AS-002 | Manifest consumption and scene instantiation | ADR-0001, ADR-0003, ADR-0004 ✅ |
| TR-AS-003 | DORMANT → ACTIVE activation lifecycle with stagger | ADR-0003, ADR-0004 ✅ |
| TR-AS-004 | Photo detection pipeline (frustum → distance → occlusion → facing) | ADR-0002, ADR-0004 ✅ |
| TR-AS-005 | Monster position sync via signals | ADR-0002, ADR-0003 ✅ |
| TR-AS-006 | Night lifecycle cleanup and anchor reuse | ADR-0001, ADR-0003 ✅ |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | AnomalyDefinition Resource | Config/Data | Ready | ADR-0004 |
| 002 | Manifest Consumption and Instantiation | Integration | Ready | ADR-0001, ADR-0003, ADR-0004 |
| 003 | Activation Lifecycle | Logic | Ready | ADR-0003, ADR-0004 |
| 004 | Photo Detection API | Logic | Ready | ADR-0002, ADR-0004 |
| 005 | Monster Position Sync | Integration | Ready | ADR-0002, ADR-0003 |
| 006 | Night Lifecycle Cleanup | Integration | Ready | ADR-0001, ADR-0003 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/anomaly-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Anomaly spawn/despawn integration tests pass

## Next Step

Run `/create-stories [epic-slug]` to break this epic into implementable stories.
