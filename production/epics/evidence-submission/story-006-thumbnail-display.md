# Story 006: Photo Thumbnails & Dwell Time

> **Epic**: Evidence Submission
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-19

## Context

**GDD**: `design/gdd/evidence-submission.md` (Photo Thumbnails and Dwell Time sections)
**Requirement**: `TR-ES-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 (Rendering)
**ADR Decision Summary**: Photo thumbnails rendered via TextureRect nodes in the debrief UI. No custom shader needed — standard texture display.

**ADR Governing Implementation**: ADR-0003 (Communication)
**ADR Decision Summary**: `debrief_continue_pressed` signal consumed by Evidence Submission. Dwell timer managed locally, no signal for timer expiry.

**ADR Governing Implementation**: ADR-0009 (Audio)
**ADR Decision Summary**: Continue prompt audio cue plays at T_dwell. AudioManager singleton handles audio routing.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: TextureRect for thumbnails, Timer for dwell, InputEvent for continue. All standard UI controls. AudioManager singleton for audio cue.

**Control Manifest Rules (Core layer)**:
- Required: All tuning knobs in TuningKnobs resources, never hardcoded
- Required: Resources loaded in `_ready()`, never in `_physics_process()`
- Required: Resources are read-only at runtime; state in companion objects
- Required: No signal chains — each system emits its own distinct signal

---

## Acceptance Criteria

*From GDD `design/gdd/evidence-submission.md`, scoped to this story:*

- [ ] AC-ES-29: GIVEN `photos_submitted = 5`, WHEN `show_debrief(data)` is called, THEN up to 5 photo thumbnails are displayed in the debrief UI (one per photo), arranged in a row.

- [ ] AC-ES-30: GIVEN `photos_submitted = 0`, WHEN `show_debrief(data)` is called, THEN no thumbnails are displayed and a "No evidence submitted" message is shown instead.

- [ ] AC-ES-31: GIVEN debrief is displaying, WHEN T_dwell (from TuningKnobs) has elapsed, THEN a Continue prompt appears and the player can press Continue to dismiss the debrief.

---

## Implementation Notes

*Derived from ADR-0005 Rendering + GDD Thumbnail + Dwell Time sections:*

**Thumbnail display:**
```gdscript
# evidence_submission.gd

const MAX_THUMBNAILS: int = 5

func show_debrief(data: DebriefData) -> void:
    # Clear existing thumbnails
    _clear_thumbnails()

    # Add photo thumbnails (up to MAX_THUMBNAILS)
    if data.photos.size() > 0:
        for i in range(mini(data.photos.size(), MAX_THUMBNAILS)):
            var tex_rect := TextureRect.new()
            tex_rect.texture = data.photos[i]
            tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
            tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
            _thumbnail_container.add_child(tex_rect)
    else:
        # No evidence message
        var label := Label.new()
        label.text = TuningKnobs.no_evidence_message
        _thumbnail_container.add_child(label)

    # Start dwell timer
    _dwell_timer = Timer.new()
    _dwell_timer.wait_time = TuningKnobs.debrief_dwell_time
    _dwell_timer.one_shot = true
    _dwell_timer.timeout.connect(_on_dwell_timeout)
    add_child(_dwell_timer)
    _dwell_timer.start()

    # Enable continue input
    _continue_enabled = false
    _continue_timeout_id = get_tree().create_timer(TuningKnobs.debrief_dwell_time)

func _on_dwell_timeout() -> void:
    _continue_enabled = true

func _on_input(event: InputEvent) -> void:
    if _continue_enabled and event.is_action_pressed("debrief_continue"):
        _state = DebriefState.EMITTING
        debrief_completed.emit()
        _state = DebriefState.IDLE
        _continue_enabled = false
```

**Thumbnail layout:**
| Property | Value | Source |
|---|---|---|
| Max thumbnails | 5 | `MAX_THUMBNAILS` constant |
| Layout | Horizontal row | UI design |
| Stretch mode | KEEP_ASPECT | Visual quality |
| No-evidence message | From TuningKnobs | Data-driven |

**Dwell time:**
| Parameter | Source | Default |
|---|---|---|
| `debrief_dwell_time` | TuningKnobs resource | GDD value |
| Timer type | One-shot Timer | Godot Timer |
| Continue enable | Timer timeout | Automatic |

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine that triggers `show_debrief()` (Story 001 controls when debrief shows)
- [Story 002]: Pay calculation (pay value computed before thumbnails)
- [Story 003]: Boss anger update (anger computed before thumbnails)
- [Story 004]: Dialogue selection (dialogue selected before thumbnails)
- [Story 007]: Debrief display (UI styling, layout, colors — Story 006 provides the data and basic structure)
- [Story 005]: Night 7 win debrief (uses same `show_debrief` but with different data)

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-ES-29**: Photo thumbnails displayed
  - Given: photos_submitted = 5, data.photos contains 5 textures
  - When: show_debrief(data) called
  - Then: 5 TextureRect nodes created and added to _thumbnail_container; each has correct texture; stretch mode = KEEP_ASPECT
  - Edge cases: photos_submitted = 3 → 3 thumbnails; photos_submitted = 7 → 5 thumbnails (clamped to MAX_THUMBNAILS); photos_submitted = 1 → 1 thumbnail

- **AC-ES-30**: No evidence message
  - Given: photos_submitted = 0, data.photos is empty
  - When: show_debrief(data) called
  - Then: No TextureRect nodes created; Label with no_evidence_message shown instead
  - Edge cases: data.photos = null → treated as empty; data.photos.size() = 0 → same as empty

- **AC-ES-31**: Dwell time and continue prompt
  - Given: Debrief displaying, T_dwell not yet elapsed
  - When: Time passes, T_dwell elapses
  - Then: _continue_enabled = true; player can press Continue to dismiss debrief
  - Edge cases: player presses Continue before T_dwell → input ignored; T_dwell = 0 → immediately enabled; debrief dismissed via other means → timer stopped, no crash on timeout

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: `production/qa/evidence/thumbnail_display-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (state machine triggers debrief display)
- Unlocks: Evidence Submission epic complete (thumbnail display is the final piece of the debrief flow)
