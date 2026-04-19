# Audio System

> **Status**: Designed
> **Author**: Nate Aune + agents
> **Last Updated**: 2026-04-10
> **Implements Pillar**: Pillar 1 ("Something's Wrong Here") — audio is a primary channel for communicating wrongness; Pillar 4 ("One More Night") — audio degrades across horror tiers

## Overview

The Audio System is the soundscape engine for Show & Tell. It manages four audio layers — ambient room tone, reactive sound effects, spatial 3D audio, and adaptive music — mixed through a bus hierarchy that downstream systems write to but never control directly. Each room carries a unique ambient signature (HVAC hum, corridor echo, deliberate silence) that the system cross-fades on `player_entered_room` signals from Room/Level Management. Horror tier transitions (driven by Night Progression via `configure_for_night`) shift the ambient layer's character: warm hum at Tier 1, cooling irregularity at Tier 2, hostile mechanical breakdown at Tier 3. The system exposes a `play_spatial_sfx(position, stream, bus)` API that 5+ downstream systems use to place sounds in 3D space — monster footsteps, anomaly audio cues, door creaks, vent rumbles — without needing to manage AudioStreamPlayer3D nodes themselves. All audio is OGG Vorbis, pooled (no runtime node creation), and capped at 20 MB total to meet the web export memory budget. The system respects browser autoplay policy by deferring all playback until the first user interaction. Players never think about the Audio System. They think "this room sounds wrong tonight" or "I heard something behind me." The system's job is to make the preschool feel like a real acoustic space that degrades into something hostile — audio is the first sense that registers wrongness, before the player's eyes confirm it.

## Player Fantasy

**"Silence Was the Last Safe Thing."** The player should develop an unconscious acoustic map of the preschool — not from a sound meter or audio HUD, but from accumulated trust and its betrayal. The Entry Hall hums. The Cubby Hall echoes. The Nap Room is silent. These become facts the player's body knows before their mind articulates them. The Audio System earns its horror by training acoustic expectations on early nights, then systematically violating them on later ones. Each night peels away another layer of sonic normalcy: the HVAC hum stutters, the corridor echo carries sounds that don't belong to the player's footsteps, and rooms that were warm begin to sound cold. The fantasy's climax is not a loud sound — it's a quiet one. When the Nap Room, the player's unconscious refuge of silence, finally produces a sound — a music box winding down in the dark, a breath that isn't yours — that single sound is the loudest thing in the game. Not in decibels. In dread.

This is an indirect fantasy — the player never thinks about audio buses or ambient layers. They think "this room sounds wrong tonight" and "I don't want to go in there because last time it was too quiet." The system delivers this by making every room acoustically distinct, every night acoustically different, and every silence a promise that will eventually be broken.

*Serves Pillar 1: "Something's Wrong Here" — audio wrongness registers before visual wrongness. The player's ears know something has changed before their eyes confirm it. Serves Pillar 4: "One More Night" — the progressive corruption of room audio signatures IS the escalation arc, felt through the body rather than read from a meter. Serves Pillar 3: "Trust No One" — the acoustic environment was the thing you trusted, and it betrays you.*

## Detailed Design

### Core Rules

#### Audio Bus Hierarchy

```
Master
├── Ambient          (room tone — one cross-fading source at a time)
├── Music            (boss debrief melody, Night 7 escape — two uses only)
├── SFX_World        (player-originated: footsteps, doors, camera, interactions)
├── SFX_Spatial      (3D positional: monster, anomaly, vent, environmental)
├── UI               (menu clicks, photo gallery — sparse)
└── Voice            (boss debrief dialogue — reserved)
```

**Bus rules:**
- All buses route to Master. Master volume is the only player-facing setting.
- `Ambient` uses a dedicated `AudioStreamPlayer` (stereo, not 3D) — room tone wraps the player, not positioned in space.
- `Music` operates independently of Ambient. Both can play simultaneously. Music ducks -6dB when Voice bus is active (boss dialogue takes priority).
- `SFX_World` handles non-spatial player sounds: footsteps, door interactions, camera shutter. No 3D attenuation.
- `SFX_Spatial` routes all `AudioStreamPlayer3D` pool nodes. Per-room reverb parameters update on `player_entered_room`.
- Web export: all buses muted on scene load. First `_input` event un-mutes. No audio before user interaction.

#### The Four Audio Layers

**Layer 1: Ambient Room Tone**

One ambient loop plays at a time, cross-fading when `player_entered_room` fires. Cross-fade: fade out current over `AMBIENT_CROSSFADE_TIME` (default 1.5s), fade in new over `AMBIENT_CROSSFADE_TIME`. If the player leaves a room in under 0.5s (doorway straddling per Room GDD threshold rule), cancel the fade and snap back.

| Room | Ambient Signature | Tier 1 | Tier 2 | Tier 3 |
| --- | --- | --- | --- | --- |
| `entry_hall` | Distant street noise, HVAC hum | Full, warm, steady | HVAC stutters 1-2x/min (0.3s glitch). Street sounds fade to half volume. | Street gone. HVAC distorts to low grind. Occasional hard silence cuts (0.5-1s). |
| `main_classroom` | Low chair-scrape register, bulletin board paper flutter | Near-subliminal (0.3 volume). Room breathes — the sound of a space that recently held children. | Scraping intervals shorten, flutter becomes rhythmic (patterned, not random). 0.5 volume. | Scraping becomes directional (always from the corner the player isn't facing). Flutter stops. Deep sub-bass hum enters. |
| `art_corner` | Paper texture, crayon drag, small reverb | Very quiet (0.2 volume). Anomaly sounds arrive at -6dB relative to other rooms. | Crayon drags repeat in patterns. Paper crinkle becomes wet-sounding. | Paper sounds stop. Replaced by slow tearing sound every 45-90s (random interval). |
| `cubby_hall` | Corridor echo, footstep reflection isolation | Footstep reflection delay: 80ms (short hall bounce). No other ambient. | Second reflection at 160ms. Echo starts arriving 0.1s late (de-synced from actual steps). | Echoes arrive from wrong direction. Occasional phantom footsteps in the echo that don't belong to the player. |
| `nap_room` | True silence — no ambient loop file | No playback. Silence IS the signature. | No playback. Any SFX has natural reverb only. | No ambient. Subtle infrasound at 18-20Hz (physical unease, below conscious hearing). |
| `bathroom` | Echo, tile acoustics, vent cross-bleed | Tile reverb on all sounds. Vent bleed: Nap Room silence (acoustic void through vent — uncanny). | Vent cross-bleed carries faint sounds from adjacent rooms. Dripping begins (1-4s intervals). | Tile echo reverb time doubles. Vent becomes a conductor for monster audio from anywhere in the building (false alarms by design). |
| `principals_office` | No prepared ambient — intentional unfamiliarity | N/A (locked Nights 1-6). Nights 5-6: quiet mechanical tick from behind the locked door. | N/A | Night 7 only: dead silence with a low electrical hum that gains harmonics over the session. The room sounds larger than its physical size (1.5-2.0s reverb tail). |

**Layer 2: Reactive SFX**

Pooled, non-spatial effects triggered by player actions. Pool pre-allocates `SFX_POOL_2D_SIZE` (default 6) `AudioStreamPlayer` nodes at scene load.

| Trigger | Bus | Sound Character |
| --- | --- | --- |
| Footstep (surface-typed) | SFX_World | One per step cycle. Rate = `current_speed / STEP_STRIDE_LENGTH`. Random pitch +/-4%. |
| Door interact | SFX_World | Three variants: open creak, close thud, locked rattle. Random pitch +/-4%. |
| Vent enter/exit | SFX_World | Metal scrape. Same asset reversed for exit. |
| Camera raise | SFX_World | Soft viewfinder click. |
| Camera shutter (Tier 1) | SFX_World | Mechanical click-whirr. Warm, analog. 0.3-0.4s. |
| Camera shutter (Tier 2) | SFX_World | Same click + 20ms reversed pre-transient (phantom click before real click). Subtle wrongness. |
| Camera shutter (Tier 3) | SFX_World | Same click + electrical flash crackle (0.1s). Shutter becomes the most violent sound in a hostile room. |
| Camera shutter (anomaly in frame) | SFX_World | Low-frequency thump underlies click (60-80Hz, 0.2s decay). Camera registers what the body already knew. |
| Player death | SFX_World | Impact + silence. No music. |

**Footstep surface types** (resolving FPC GDD open question):

The Audio System samples the surface below the player via a short downward raycast each step cycle. Surface type is read from the mesh material's `surface_tag` metadata field. Default fallback: `LINOLEUM`.

| Surface Tag | Rooms | Sound Character | Variations |
| --- | --- | --- | --- |
| `LINOLEUM` | Entry Hall, Cubby Hall | Hard slap, bright transient. Loudest footstep. | 4 |
| `CARPET_LOW` | Main Classroom, Art Corner | Muffled, near-silent. Very low amplitude. | 3 |
| `CARPET_THICK` | Nap Room | Near-silent thud. In the Nap Room's silence, even this is audible. | 3 |
| `TILE` | Bathroom | Hard + wet. Echo pronounced via room reverb. | 4 |
| `WOOD` | Principal's Office | Creak. Footsteps as intrusion. | 3 |

Running footsteps: step rate doubles, pitch raised +8%, volume raised +2dB.

**Layer 3: Spatial 3D Audio**

All sounds with a world-space origin use `AudioStreamPlayer3D` nodes from the pool. Pool size: `SFX_POOL_3D_SIZE` (default 8). The system exposes:

`play_spatial_sfx(position: Vector3, stream: AudioStream, bus: StringName = &"SFX_Spatial") -> void`

Callers never create or free nodes.

**Spatial parameters:**
- Attenuation: `ATTENUATION_INVERSE_DISTANCE_SQUARED`
- Reference distance: 2.0m (full volume at arm's length)
- Max distance: 15m. Beyond 15m: do not play (save pool slot).
- If pool is full, the quietest source is evicted.

**Per-room reverb** (applied to `SFX_Spatial` bus via `AudioEffectReverb`, parameters updated on `player_entered_room`):

| Room | Room Size | Damping | Effect |
| --- | --- | --- | --- |
| `entry_hall` | 0.5 | 0.5 | Medium reverb, warm decay |
| `main_classroom` | 0.7 | 0.4 | Large but dampened (carpet absorbs) |
| `art_corner` | 0.3 | 0.7 | Small, dry. Intimate. |
| `cubby_hall` | 0.6 | 0.2 | Reflective corridor. Longest echo. |
| `nap_room` | 0.4 | 0.8 | Very dead. Reinforces silence. |
| `bathroom` | 0.5 | 0.1 | Tile acoustics. Longest reverb tail. |
| `principals_office` | 0.4 | 0.6 | Uncanny neutral — neither intimate nor spacious. |

**Monster proximity breathing:** When Monster AI reports `monster_proximity(distance)` and distance < `MONSTER_BREATHING_THRESHOLD` (default 8m), the Audio System plays spatialized monster breathing from the monster's position via `play_spatial_sfx`. The breathing is continuous, looping, volume scaling inversely with distance. It fades in over 2s on first detection, fades out over 3s when monster moves beyond threshold. The breathing is the monster's primary audio signature — heard before seen.

**Layer 4: Music (Two Uses Only)**

Music is NOT a persistent layer. The game uses silence and sound design for all tension. Music appears exactly twice:

**1. Boss Debrief Melody:** A thin, mechanical music-box melody. Four bars, major key, slightly detuned, tempo slightly too slow. Plays during the boss evidence review screen. Degrades across nights:
- Nights 1-2: Clean melody. Minor relief after the night's tension.
- Nights 3-4: Notes drop out. Tempo drags. One bar contains a pitch outside the original key.
- Nights 5-6: Melody barely recognizable. Winding-down character.
- Night 7: Does not play. Boss has transformed. Silence replaces the melody.

**2. Night 7 Escape:** The only full non-diegetic music cue. Chaotic, pitched-down children's songs layered with industrial percussion. Plays for the exact duration of the escape sequence. Ends the moment the player exits the building. Credits over silence.

#### Horror Tier Audio Transitions

Tier transitions fire once at night-start via `configure_audio_for_night(night_number: int)`. The change is immediate in configuration but the ambient content is designed to feel like progression across sessions.

| Layer | Tier 1 (Nights 1-2) | Tier 2 (Nights 3-4) | Tier 3 (Nights 5-7) |
| --- | --- | --- | --- |
| Ambient | Warm, consistent, low-volume | Irregularity (stutters, pattern breaks). Volume slightly higher. | Fully corrupted. Directional errors, sounds that don't belong. |
| Reactive SFX | Normal amplitude and timing | Cubby Hall echoes de-sync. Camera gains pre-transient. | Footsteps +1dB. Doors gain longer tails. Camera gains flash crackle. |
| Spatial 3D | Anomaly audio rare. No monster audio. | Monster breathing introduced (Cubby Hall first). More anomaly audio. | All spatial slots can be active. Monster breathing in multiple rooms. Bathroom vent cross-bleed becomes false-alarm source. |
| Music | Boss debrief melody only | Boss melody degrading | Night 7 escape music. Boss melody absent. |

#### Audio Wrongness Palette

Seven techniques, each assigned to a specific context. Sparingly used — each loses power through overuse.

| Technique | Description | Context | Limit |
| --- | --- | --- | --- |
| Pitch Micro-Drift | Ambient pitch detuning 1-3 cents over 10-20s | Tier 2 anomaly proximity | Reset on photograph |
| Reversed Ambient Bleed | 0.5-1.5s reversed sample of room's own ambient at -20dB | Art Corner paper, Nap Room violation | Max 1 per room |
| Phantom Footstep | Additional footstep that doesn't correspond to any physical source | Cubby Hall Tier 2+ | Ambiguous by design |
| Formant Shift | Ambient vowel-character shifts ("uh" to "ah") | Vulnerability bar > 50% | Only technique reading player state |
| Sub-Bass Infrasound | 18-22Hz pressure variation, 0.1-0.3Hz modulation | Main Classroom Tier 3, Nap Room Tier 3 | 10s fade-in, headphones recommended |
| Silence Insertion | Hard cut to silence (0.5-2.0s) mid-ambient, then resume | Once per night, room with most significant anomaly | Max 1 per night |
| Spatial Misdirection | 3D audio source placed at incorrect position | Bathroom vent cross-bleed false alarms (Tier 3) | Tier 3 only |

#### Nap Room Silence Violation Arc

The Nap Room's silence is the player's unconscious safe harbor. Its violation is the Audio System's most important design arc.

**Nights 1-2 (Tier 1):** True silence. No ambient loop. Only player-generated sounds (footsteps, camera). The player learns: this room is safe because it is empty.

**Night 3 (Tier 2, first violation):** 8-12 seconds after entry, a music box plays. Single note, then a four-note nursery rhyme fragment. 3D-spatialized from under a specific cot. Duration: 6-8 seconds. Then silence. No visual event. No anomaly to photograph. The sound simply exists, then doesn't.

**Nights 4-5:** Music box plays on entry (2-3s delay). Longer duration (15-20s). Stops when player leaves. Resumes on re-entry at a different starting note — implying it continued while the player was gone. Night 5: melody contains one extra note that doesn't belong. Tempo slows 3-4 BPM across the loop.

**Night 6 (Tier 3, final violation):** Music box is now a photographable anomaly — physically visible under the cot. Photographing it stops all sound in the Nap Room. The silence after is harder than Tier 1 silence, because the player's ears are now calibrated to the music box as the room's ambient. Then: a single wet breath, 3D-spatialized from directly behind the player. Nothing there when they turn. Time to leave.

#### Art Bible Color-Audio Mappings

| Color Signal | Audio Response | Bus | Parameters |
| --- | --- | --- | --- |
| Red (Active Danger) | Low-frequency pulse | SFX_World | 40-80Hz, 0.5s, -12dB relative to footsteps |
| Green (Safe/Confirmed) | Soft ping | SFX_World | 800-1200Hz sine, 0.3s |
| Violet (Something Wrong) | Progressive distortion on SFX_Spatial reverb | SFX_Spatial | Low intensity: reverb wet mix increases. High intensity: reverb spread increases (stereo widening = spatial disorientation). Progressive, not stepped. |

### States and Transitions

The Audio System is a **listener** — it responds to FPC and Room Management signals, never drives state.

| State | What's Playing | Entry Condition |
| --- | --- | --- |
| `SILENT` | Nothing. All buses muted. | Scene load (web autoplay). Also: Dead state. |
| `AMBIENT_NORMAL` | Room ambient + footsteps on move. Spatial SFX active. | First user interaction un-mutes all buses. |
| `AMBIENT_RUNNING` | Room ambient. Footsteps: louder, faster, +8% pitch. | `is_running == true` from FPC. |
| `AMBIENT_IN_VENT` | Vent ambient loop (tight mechanical rumble). Room ambient fades out over 0.5s. | `current_state == In_Vent` from FPC. |
| `AMBIENT_HIDING` | Room ambient at -6dB (muffled). Heartbeat at `HEARTBEAT_BPM_HIDING` (default 80) on SFX_World. | `current_state == Hiding` from FPC. |
| `AMBIENT_CUTSCENE` | Night 7 escape music on Music bus. All other buses fade to 0 over 2s. | `current_state == Cutscene` from FPC. |
| `DEAD` | 1-2s impact SFX, then silence. All buses fade to 0 over 1s after impact. | `player_killed` from Monster AI. |

**FPC State-to-Audio Mapping:**

| FPC State | Audio State | Ambient | Footsteps | Spatial | Music |
| --- | --- | --- | --- | --- | --- |
| Normal | AMBIENT_NORMAL | Room ambient, full | Normal rate/volume | Active | Event-driven |
| Camera Raised | AMBIENT_NORMAL | Room ambient, full | Slow rate (1.5 m/s) | Active | Event-driven |
| Running | AMBIENT_RUNNING | Room ambient, full | Fast, +2dB, +8% pitch | Active | Event-driven |
| In Vent | AMBIENT_IN_VENT | Vent loop | None (crawling) | Muted | Event-driven |
| Hiding | AMBIENT_HIDING | Room ambient -6dB | None | Active, -6dB | None |
| Cutscene | AMBIENT_CUTSCENE | Fades out | None | Fades out | Night 7 escape |
| Dead | DEAD | Fades out | None | Fades out | None |
| Restarting | DEAD (held) | Off | None | Off | None |

**Transition rules:**
- State changes are immediate on signal receipt EXCEPT: entering `AMBIENT_IN_VENT` fades room ambient over 0.5s (player is crawling in, not teleporting).
- Exiting `AMBIENT_IN_VENT`: room ambient fades back in over 0.5s on `vent_exit_complete`.
- `DEAD` is a one-way trap until scene reload. No audio signals processed in Dead state.
- Camera Raised does NOT change audio state. The slower footstep rate is handled by the footstep system reading the FPC's reduced speed (1.5 m/s), not by an audio state change.
- Heartbeat BPM in Hiding state is a tuning knob: lower = more dread, higher = more panic.

### Interactions with Other Systems

#### Inputs (signals/data the Audio System receives)

| Signal / Property | Type | From System | Audio Response |
| --- | --- | --- | --- |
| `player_entered_room(room_id)` | signal | Room/Level Management | Cross-fade ambient to new room's signature. Update reverb parameters on SFX_Spatial bus. |
| `player_exited_room(room_id)` | signal | Room/Level Management | Begin fade-out of current ambient (fade-in starts on next `player_entered_room`). |
| `player_position` | Vector3 | FPC (every physics frame) | Consumed by spatial SFX pool for attenuation calculation. Used by footstep system for surface raycast origin. Not stored as state. |
| `is_running` | bool | FPC (on change) | Switch footstep variant: fast rate, +8% pitch, +2dB when true. |
| `is_moving` | bool | FPC (on change) | Start/stop footstep playback cycle. |
| `current_state` | enum | FPC (on state transition) | Drive Audio System state machine (see States and Transitions). |
| `interact_pressed` + door raycast | signal | FPC | Play door SFX variant (open/close/locked) on SFX_World. |
| `camera_raised` | bool | FPC (on change) | Play viewfinder click on raise. Footstep rate adjusts via reduced speed (1.5 m/s). |
| `configure_for_night(n)` | method call | Night Progression | Set horror tier. Swap ambient loop variants. Update reverb parameters. Set camera shutter variant. Update monster breathing threshold. |
| `anomaly_color_revealed(color, intensity)` | signal | Anomaly System | Trigger color-mapped SFX: Red pulse, Green ping, Violet progressive distortion. |
| `monster_proximity(distance, position)` | signal | Monster AI (every AI tick) | If distance < `MONSTER_BREATHING_THRESHOLD`: play/update spatialized breathing from monster position. Fade in over 2s, fade out over 3s. |
| `player_killed` | signal | Monster AI | Transition to DEAD. Play impact SFX. Fade all buses over 1s. |
| `photo_submitted` | signal | Evidence Submission | No audio response (music-only-twice rule — boss debrief melody is triggered by the debrief screen itself, not by submission). |
| `night_7_finale_start` | signal | Night Progression | Transition to AMBIENT_CUTSCENE. Play Night 7 escape music on Music bus. |
| `vent_entry_complete` | signal | Vent System | Transition to AMBIENT_IN_VENT. Fade room ambient out, start vent loop. |
| `vent_exit_complete` | signal | Vent System | Transition to AMBIENT_NORMAL. Fade vent loop out, room ambient in. |
| `hide_spot_entered` | signal | Hiding System | Transition to AMBIENT_HIDING. Apply -6dB to Ambient bus. Start heartbeat loop. |
| `hide_spot_exited` | signal | Hiding System | Transition to AMBIENT_NORMAL. Stop heartbeat. Restore Ambient bus volume. |
| `vulnerability_bar_changed(fraction)` | signal | Player Survival | If fraction > 0.5: apply Formant Shift wrongness technique to ambient layer. Scale intensity with fraction. |
| `boss_debrief_started(night)` | signal | Evidence Submission | Play boss debrief melody variant for this night on Music bus. |
| `boss_debrief_ended` | signal | Evidence Submission | Fade music. |

#### Outputs (methods/signals the Audio System provides)

| Method / Signal | Type | Consumers | Description |
| --- | --- | --- | --- |
| `play_spatial_sfx(position: Vector3, stream: AudioStream, bus: StringName = &"SFX_Spatial") -> void` | method | Monster AI, Anomaly System, Vent System, Anomaly Placement Engine | Place a sound in 3D space. Callers never manage AudioStreamPlayer3D nodes. |
| `play_sfx(stream: AudioStream, bus: StringName = &"SFX_World") -> void` | method | Photography System (shutter), FPC (door), HUD/UI | Play a non-spatial one-shot. |
| `play_music_event(event_id: StringName) -> void` | method | Night Progression (Night 7 escape), Evidence Submission (boss debrief) | Play a named music event. Only two valid event IDs: `&"boss_debrief"` and `&"night_7_escape"`. |
| `configure_audio_for_night(night: int) -> void` | method | Night Progression | Set all tier-dependent parameters: ambient variants, reverb, shutter variant, breathing threshold. |
| `get_current_audio_state() -> StringName` | method | (reserved — no current consumers) | Returns current audio state enum for debug/HUD. |
| `audio_state_changed(new_state: StringName)` | signal | (reserved — no current consumers) | Emitted on state transition. Reserved for future HUD/UI needs. |

**Audio System has no hard upstream dependencies.** It is a pure service layer. All inputs arrive via signals or method calls from other systems. It can initialize and run with no other systems present (silent, awaiting signals). Night Progression is the only system that writes configuration; all others request playback.

## Formulas

### Footstep Rate

The footstep system triggers one step sound per stride. Step rate is derived from current movement speed.

`step_interval(S) = STEP_STRIDE_LENGTH / S`

**Variables:**

| Variable | Symbol | Type | Range | Description |
| --- | --- | --- | --- | --- |
| STEP_STRIDE_LENGTH | — | float | 0.8 m | Distance per stride (fixed, authored) |
| current_speed | S | float | 0.0-4.0 m/s | From FPC: walk=2.0, camera_raised=1.5, run=4.0 |
| step_interval | — | float | 0.2-inf s | Time between footstep sounds |

**Output Range:** Walking: `0.8 / 2.0 = 0.4s` (2.5 steps/sec). Camera raised: `0.8 / 1.5 = 0.53s` (1.9 steps/sec). Running: `0.8 / 4.0 = 0.2s` (5 steps/sec). At speed 0: no footsteps (division guarded).

### Spatial Audio Attenuation

Volume of a 3D sound source at distance D from the listener.

`volume_db(D) = base_volume_db - 20 * log10(max(D, REFERENCE_DISTANCE) / REFERENCE_DISTANCE)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
| --- | --- | --- | --- | --- |
| base_volume_db | — | float | -12 to 0 dB | Authored per-sound base volume |
| distance | D | float | 0-15 m | Distance from listener to source |
| REFERENCE_DISTANCE | — | float | 2.0 m | Distance at which sound plays at base volume |
| volume_db | — | float | -inf to 0 dB | Output volume. Clamped at -80dB (effectively silent). |

**Output Range:** At 2m: base_volume_db. At 4m: base - 6dB. At 8m: base - 12dB. At 15m: base - 17.5dB. Beyond 15m (`MAX_SPATIAL_DISTANCE`): do not play.

**Example — Monster breathing (base 0dB):**
- 2m: 0dB (full volume, very close)
- 5m: -8dB (audible, present)
- 8m (threshold): -12dB (just detectable)
- 15m: -17.5dB (inaudible in practice, not played)

### Ambient Cross-fade Timing

`crossfade_time = AMBIENT_CROSSFADE_TIME` (constant, not a formula — but the doorway-straddling cancel threshold is derived):

`cancel_crossfade = time_in_new_room < CROSSFADE_CANCEL_THRESHOLD`

**Variables:**

| Variable | Symbol | Type | Range | Description |
| --- | --- | --- | --- | --- |
| AMBIENT_CROSSFADE_TIME | — | float | 1.5 s | Duration of fade-out and fade-in |
| CROSSFADE_CANCEL_THRESHOLD | — | float | 0.5 s | If player exits new room before this, snap back to previous ambient |
| time_in_new_room | — | float | 0-inf s | Elapsed since `player_entered_room` fired |

### 20MB Audio Budget Allocation

Not a runtime formula, but a design constraint that must be validated during asset production.

| Category | Allocation | Calculation |
| --- | --- | --- |
| Ambient loops | 6.3 MB | 7 rooms x 3 tiers = 21 loops. 30s loop at OGG 0.8 (~80kbps) = ~300KB each. |
| Footstep banks | 1.0 MB | 5 surfaces x ~3.4 variations avg x ~50KB = ~850KB |
| Reactive SFX | 3.0 MB | ~30 files (doors, camera, vent, death, interactions) x ~100KB |
| Music | 2.5 MB | Boss debrief: 4 variants x ~200KB = 0.8MB. Night 7 escape: ~1.7MB (90s at OGG 0.8) |
| Spatial SFX | 2.0 MB | Monster breathing, anomaly cues: ~20 files x ~100KB |
| Voice | 1.5 MB | Boss dialogue: ~10 lines, 15-30s total |
| Anomaly-specific | 1.0 MB | Music box loops, breath SFX, wrongness palette sounds |
| **Total** | **17.3 MB** | **Buffer: 2.7 MB** |

**Constraint:** If total exceeds 20MB during production, cut ambient loop length first (30s -> 15s halves the biggest line item). The Nap Room's 0MB ambient is intentional budget savings.

## Edge Cases

- **If ****`player_entered_room`**** fires while a cross-fade is already in progress (rapid room transitions):** Cancel the current cross-fade. Snap the outgoing ambient to silent. Begin a fresh cross-fade to the new room's ambient. Never layer three ambients simultaneously.

- **If the player straddles a doorway and ****`player_entered_room`**** fires but ****`player_exited_room`**** does not fire within ****`CROSSFADE_CANCEL_THRESHOLD`**** (0.5s):** Commit to the new room's ambient. This aligns with the Room GDD's "last room fully entered" threshold rule. If the player then backs out, a new `player_entered_room` for the original room fires and triggers a normal cross-fade.

- **If ****`play_spatial_sfx`**** is called and all ****`SFX_POOL_3D_SIZE`**** (8) pool slots are occupied:** Evict the quietest currently-playing source (lowest effective volume at the listener's position). If all sources are at equal volume, evict the oldest. Never fail silently — the new sound always plays.

- **If ****`play_spatial_sfx`**** is called with a position beyond ****`MAX_SPATIAL_DISTANCE`**** (15m):** Do not play. Do not allocate a pool slot. Return immediately. The caller does not need to pre-check distance.

- **If ****`configure_audio_for_night(n)`**** is called while the player is in a room whose ambient is mid-cross-fade:** Complete the cross-fade to the current target room, THEN apply the tier variant swap. Tier changes do not interrupt cross-fades. Call order: cross-fade completes first, then ambient stream is replaced with the new tier's variant.

- **If ****`monster_proximity`**** reports distance < ****`MONSTER_BREATHING_THRESHOLD`**** but the monster is in a LOCKED room the player cannot enter:** Still play the breathing. The player hearing a monster they cannot reach (through walls, through vents) is intentional horror design. The breathing is spatialized from the monster's actual position — walls do not occlude audio in this system (the preschool is small enough that wall occlusion would reduce rather than enhance dread).

- **If two monsters are simultaneously within ****`MONSTER_BREATHING_THRESHOLD`****:** Play both breathing sources from separate pool slots. Each monster has its own spatial position. The overlapping breathing is intentional — it escalates from "something is near" to "there are multiple somethings." Cap at 2 simultaneous breathing sources to preserve pool slots.

- **If the player enters the Nap Room on Night 3 and leaves before the music box trigger delay (8-12s):** The music box does NOT play. The trigger resets. On re-entry, the 8-12s delay restarts. The player must commit to being in the room to hear the violation. This rewards exploration and punishes rushed play equally.

- **If the player photographs the Nap Room music box on Night 6 and then re-enters the room on the same night:** The music box does not restart. The room remains in post-photograph silence for the rest of the night. The breath SFX plays only once per night, on the first photograph. Re-entry is silent — the violation has already occurred.

- **If ****`player_killed`**** fires while the Audio System is in ****`AMBIENT_IN_VENT`**** state:** Transition directly to DEAD. The vent loop stops immediately (hard cut, not fade). Death in a vent is abrupt — no graceful audio transition. The impact SFX plays on SFX_World (non-spatial, since the player is in a confined space).

- **If the web browser loses focus and regains it:** Audio continues playing (browsers typically suspend audio context on focus loss and resume on focus gain). On resume, do NOT restart ambient loops — let them continue from their current position. If the browser suspended the audio context, Godot's `AudioServer` handles resume automatically.

- **If the total audio asset size exceeds 20MB during production:** Cut ambient loop lengths from 30s to 15s first (saves ~3.15MB). If still over, reduce footstep variations from 3-4 per surface to 2 (saves ~0.5MB). If still over, reduce music quality from OGG 0.8 to OGG 0.6 (saves ~30% on music assets). Never cut the Nap Room music box or the Night 7 escape music — these are non-negotiable.

- **If ****`vulnerability_bar_changed(fraction)`**** reports fraction > 0.5 while the player is in the Nap Room (which has no ambient to apply Formant Shift to):** Apply the Formant Shift to the footstep reverb tail instead. The player's own movement sounds become subtly wrong. If the player is stationary (no footsteps), apply a faint sub-bass pulse (same as Tier 3 infrasound) as the vulnerability audio cue. The Nap Room's silence must never prevent the vulnerability system from communicating danger.

## Dependencies

| System | Direction | Hard/Soft | Interface |
| --- | --- | --- | --- |
| Room/Level Management | Room Mgmt → Audio | Soft | `player_entered_room`, `player_exited_room` signals — trigger ambient cross-fade and reverb parameter updates. `get_current_room()` for initialization. |
| First-Person Controller | FPC → Audio | Soft | `player_position`, `is_running`, `is_moving`, `current_state`, `camera_raised`, `interact_pressed` — drive footsteps, state machine, door SFX, camera sounds. |
| Night Progression | Night Progression → Audio | Soft | `configure_for_night(n)` — sets horror tier, swaps ambient variants, updates reverb, sets shutter variant, adjusts breathing threshold. `night_7_finale_start` — triggers escape music. |
| Monster AI | Monster AI → Audio | Soft | `monster_proximity(distance, position)` — triggers spatialized breathing. `player_killed` — triggers death audio state. |
| Anomaly System | Anomaly System → Audio | Soft | `anomaly_color_revealed(color, intensity)` — triggers color-mapped SFX (Red pulse, Green ping, Violet distortion). |
| Player Survival | Player Survival → Audio | Soft | `vulnerability_bar_changed(fraction)` — triggers Formant Shift wrongness when > 50%. |
| Vent System | Vent System → Audio | Soft | `vent_entry_complete`, `vent_exit_complete` — triggers vent ambient loop and room ambient fade. |
| Hiding System | Hiding System → Audio | Soft | `hide_spot_entered`, `hide_spot_exited` — triggers hiding audio state (muffled ambient, heartbeat). |
| Evidence Submission | Evidence Submission → Audio | Soft | `boss_debrief_started(night)`, `boss_debrief_ended` — triggers boss debrief melody on Music bus. |
| Photography System | Photography → Audio (via `play_sfx`) | Soft | Calls `play_sfx()` for shutter sound. Audio System selects the tier-appropriate variant. |
| HUD/UI | HUD → Audio (via `play_sfx`) | Soft | Calls `play_sfx()` for menu interaction sounds. |

**No upstream system dependencies.** The Audio System is a pure service layer with no hard dependencies. It initializes in SILENT state and waits for signals. Every dependency listed above is a system that *calls into* Audio, not one that Audio requires to function. If any system is absent, the Audio System simply never receives that signal — it does not error.

**No downstream dependents.** No other system queries or depends on the Audio System's state. The `audio_state_changed` signal and `get_current_audio_state()` method are reserved for future use but currently have no consumers.

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Impact |
| --- | --- | --- | --- |
| `AMBIENT_CROSSFADE_TIME` | 1.5 s | 0.5-3.0 s | Shorter = snappier room transitions, feels more game-like. Longer = smoother, more cinematic. Below 0.5s risks audible pops. Above 3.0s the player is in the new room hearing the old room's audio. |
| `CROSSFADE_CANCEL_THRESHOLD` | 0.5 s | 0.3-1.0 s | How long before a room transition commits. Lower = more responsive to doorway straddling. Higher = more stable but sluggish. Must align with Room GDD's `ROOM_BOUNDARY_DEBOUNCE`. |
| `SFX_POOL_2D_SIZE` | 6 | 4-10 | Number of concurrent non-spatial sounds. Below 4 risks footstep drops during busy moments. Above 10 wastes memory on web. |
| `SFX_POOL_3D_SIZE` | 8 | 6-12 | Number of concurrent spatial sources. Below 6 risks monster/anomaly audio eviction during Tier 3. Above 12 wastes memory. |
| `MAX_SPATIAL_DISTANCE` | 15.0 m | 10-25 m | Sounds beyond this distance are not played. Lower = tighter horror (sounds only when close). Higher = more ambient spatial texture. Must not exceed preschool footprint diagonal (~25m). |
| `REFERENCE_DISTANCE` | 2.0 m | 1.0-3.0 m | Distance at which spatial audio plays at full volume. Lower = must be very close for full volume (more intimate). Higher = fuller sound at medium range. |
| `MONSTER_BREATHING_THRESHOLD` | 8.0 m | 5.0-12.0 m | Distance at which monster breathing becomes audible. Lower = less warning, more sudden. Higher = longer dread buildup. At Tier 3, consider reducing to 5.0m for maximum tension. |
| `MONSTER_BREATHING_FADE_IN` | 2.0 s | 1.0-4.0 s | How long breathing takes to reach full volume on first detection. Shorter = more startling. Longer = more insidious. |
| `MONSTER_BREATHING_FADE_OUT` | 3.0 s | 1.5-5.0 s | How long breathing lingers after monster moves beyond threshold. Longer = residual dread ("is it still there?"). |
| `STEP_STRIDE_LENGTH` | 0.8 m | 0.6-1.0 m | Distance per stride. Shorter = faster step rate (more anxious feel). Longer = slower, heavier feel. |
| `FOOTSTEP_RUN_PITCH_SHIFT` | +8% | +4 to +15% | Pitch increase when running. Lower = subtle. Higher = more panicked character. |
| `FOOTSTEP_RUN_VOLUME_BOOST` | +2 dB | +1 to +4 dB | Volume increase when running. Feeds Monster AI detection (owned by Monster AI GDD). |
| `HEARTBEAT_BPM_HIDING` | 80 | 60-100 | Heartbeat rate while hiding. Lower = calmer dread. Higher = active panic. 60 feels like waiting for something. 100 feels like it already found you. |
| `HIDING_AMBIENT_DUCK` | -6 dB | -3 to -12 dB | How much room ambient is muffled while hiding. Less ducking = hiding feels transparent. More = hiding feels like a cocoon. |
| `NAP_ROOM_MUSICBOX_DELAY` | 10 s | 8-15 s | Delay before music box plays on Night 3 first entry. Shorter = less time to register the silence. Longer = more time to feel safe before violation. |
| `SILENCE_INSERT_DURATION` | 1.0 s | 0.5-2.0 s | Duration of the Silence Insertion wrongness technique. Shorter = blink-and-miss. Longer = unmissable void. Above 2.0s feels like a bug. |
| `FORMANT_SHIFT_THRESHOLD` | 0.5 | 0.3-0.7 | Vulnerability bar fraction that triggers Formant Shift. Lower = earlier warning. Higher = only at high danger. |

**Knobs owned by other systems (referenced here, do not duplicate):**
- `player_walk_speed` (2.0 m/s) — owned by First-Person Controller GDD
- `player_run_speed` (4.0 m/s) — owned by First-Person Controller GDD
- `SPEED_MODIFIER_CAMERA` (0.75) — owned by First-Person Controller GDD
- Horror tier-to-night mapping — will be owned by Night Progression GDD
- Monster audio detection radius expansion when running — owned by Monster AI GDD

## Visual/Audio Requirements

This IS the Audio System — all audio requirements are defined in the Detailed Design section above. No additional visual requirements exist for this system. The Audio System has no visual output; it is a pure audio service layer.

**Asset production requirements** (from Formulas section budget):
- All audio: OGG Vorbis format (.wav source, OGG export)
- Quality: 0.6 (SFX), 0.8 (ambience/music)
- Loop tagging: disabled (SFX one-shots), enabled (ambience loops, music loops)
- Total budget: <= 20 MB
- Ambient loops: 15-30s duration, seamless loop points
- Footstep banks: 3-4 variations per surface type to avoid repetition
- All reactive SFX: random pitch variation +/-4% to mask repetition

**Art bible color-audio pairings** (cross-reference, owned by Art Bible):
- Red = low-frequency pulse (40-80Hz, 0.5s)
- Green = soft ping (800-1200Hz, 0.3s)
- Violet = progressive reverb distortion (scaled with intensity)
- Flash White = shutter sound (paired, fixed duration)

## UI Requirements

The Audio System has no direct UI surfaces. Volume control is exposed via the Master bus only, through a settings menu owned by the HUD/UI System GDD.

The `play_sfx()` method is available to HUD/UI for menu interaction sounds (clicks, hovers), but the Audio System does not define or own those sounds — it only provides the playback API.

## Acceptance Criteria

- **AC-AUD-01:** **GIVEN** the Audio System scene is loaded, **WHEN** `_ready()` completes, **THEN** `AudioServer` exposes buses named `Master`, `Ambient`, `Music`, `SFX_World`, `SFX_Spatial`, `UI`, and `Voice`, all routing to Master, and 6 non-spatial + 8 spatial `AudioStreamPlayer` nodes exist pre-allocated in stopped state.

- **AC-AUD-02:** **GIVEN** a web export with no user input yet, **WHEN** scene loads, **THEN** all buses are muted and no audio plays. **WHEN** the first discrete input event fires (key, mouse button, or gamepad button — NOT mouse motion), **THEN** all buses un-mute and room ambient begins.

- **AC-AUD-03:** **GIVEN** the player is in `entry_hall` with ambient playing, **WHEN** `player_entered_room("main_classroom")` fires, **THEN** entry_hall ambient fades to silent over 1.5s while main_classroom ambient fades in over 1.5s. At no point do three ambients play simultaneously.

- **AC-AUD-04:** **GIVEN** a cross-fade has been triggered, **WHEN** `player_exited_room` fires within 0.5s, **THEN** the cross-fade cancels, the original ambient snaps back to full volume, and the new ambient stops.

- **AC-AUD-05:** **GIVEN** a cross-fade from room A to B is in progress, **WHEN** `player_entered_room("room_c")` fires before completion, **THEN** the A-to-B fade cancels (A snaps silent), a fresh B-to-C cross-fade begins, and no more than two ambients play at once.

- **AC-AUD-06:** **GIVEN** the player enters `cubby_hall`, **WHEN** the cross-fade completes, **THEN** the `AudioEffectReverb` on `SFX_Spatial` bus has Room Size 0.6 and Damping 0.2 matching the cubby_hall spec.

- **AC-AUD-07:** **GIVEN** the player walks at 2.0 m/s on any surface, **WHEN** the footstep system runs, **THEN** one footstep fires every 0.4s (+/-0.01s), with pitch randomly varied +/-4%, using the correct surface bank.

- **AC-AUD-08:** **GIVEN** the player runs at 4.0 m/s, **WHEN** footsteps fire, **THEN** step interval is 0.2s (+/-0.01s), pitch is +8% (+/-0.5%), volume is +2dB (+/-0.1dB) from base.

- **AC-AUD-09:** **GIVEN** the player is stationary (speed 0), **WHEN** the footstep system evaluates, **THEN** no division-by-zero occurs and no footstep fires.

- **AC-AUD-10:** **GIVEN** the FPC is in Camera Raised state (1.5 m/s), **WHEN** footsteps fire, **THEN** step interval is ~0.533s (+/-0.01s), audio state remains `AMBIENT_NORMAL`, and no running modifiers apply.

- **AC-AUD-11:** **GIVEN** a spatial SFX at base 0dB, **WHEN** the source is 4m from the listener, **THEN** volume is -6dB (+/-0.1dB). At 8m: -12dB. At 2m or closer: 0dB (clamped at base).

- **AC-AUD-12:** **GIVEN** `play_spatial_sfx` is called with a position > 15m from the listener, **WHEN** the call executes, **THEN** no pool slot is allocated, no sound plays, and the function returns without error.

- **AC-AUD-13:** **GIVEN** all 8 spatial pool slots are occupied, **WHEN** `play_spatial_sfx` is called for a 9th sound, **THEN** the slot with the lowest effective volume at the listener is evicted and the new sound plays. Equal volume ties evict the oldest.

- **AC-AUD-14:** **GIVEN** a monster is beyond 8m (no breathing), **WHEN** `monster_proximity(7.0, position)` fires, **THEN** spatialized breathing begins from the reported position and reaches target volume over 2s. **WHEN** the monster moves beyond 8m, **THEN** breathing fades out over 3s before the pool slot is released.

- **AC-AUD-15:** **GIVEN** two monsters are within 8m with breathing active (2 pool slots), **WHEN** a third monster enters within 8m, **THEN** no third breathing source starts. The 2-source breathing cap is enforced via a separate counter, overriding the normal pool eviction rule.

- **AC-AUD-16:** **GIVEN** audio is in `AMBIENT_NORMAL`, **WHEN** `hide_spot_entered` fires, **THEN** Ambient bus attenuates by 6dB, a heartbeat loop begins at 80 BPM on SFX_World, and spatial SFX continues at -6dB. **WHEN** `hide_spot_exited` fires, **THEN** heartbeat stops and volumes restore.

- **AC-AUD-17:** **GIVEN** audio has transitioned to `DEAD`, **WHEN** any subsequent signal fires, **THEN** no state change occurs, no new sounds play, and all buses remain at 0 until scene reload.

- **AC-AUD-18:** **GIVEN** boss debrief melody plays on Music bus, **WHEN** Voice bus becomes active, **THEN** Music bus ducks by 6dB over 0.1s. **WHEN** Voice goes silent, **THEN** Music restores over 0.1s.

- **AC-AUD-19:** **GIVEN** the player enters the Nap Room on Night 3, **WHEN** the player exits before 8 seconds, **THEN** the music box does NOT play, the timer resets, and re-entry restarts the 8-12s delay from zero.

- **AC-AUD-20:** **GIVEN** the Nap Room music box has been photographed on Night 6, **WHEN** the photograph completes, **THEN** all Nap Room sound stops, a single spatialized breath fires from behind the player, and re-entry later that night produces no music box or breath.

## Open Questions

1. **Should monster breathing vary by monster archetype?** The GDD defines one breathing sound, but Monster AI will have 3 archetypes (Dolls, Shadows, Large). Each could have a distinct breathing signature. Resolve when Monster AI GDD is designed.

2. **Should the boss debrief melody be composed early for vertical slice?** The degrading music-box melody across 7 nights is a significant audio asset. Early composition would let playtesting validate whether the degradation arc lands emotionally. Resolve during pre-production planning.

3. **Should the Cubby Hall phantom footstep (Tier 2+) be indistinguishable from the player's own footstep?** If identical, the ambiguity is maximized ("was that me?"). If slightly different (longer reverb, wrong surface), the player can learn to distinguish. Resolve during sound design asset creation.

4. **Should headphone mode be auto-detected or manual?** Sub-bass infrasound (18-22Hz) and binaural spatial audio work best on headphones. A "headphones recommended" prompt on first launch would improve the experience but adds a UI element. Resolve in HUD/UI GDD.

5. **Should the Audio System expose a debug overlay showing active bus volumes, pool usage, and current audio state?** Useful during development but must not ship. Resolve during architecture/implementation.

6. **Main Classroom audio signature backfill:** The Room/Level Management GDD is missing the Main Classroom entry in its Audio Requirements table. The signature defined here (low chair-scrape register, bulletin board flutter) should be backfilled into `design/gdd/room-level-management.md` line 281.
