# ADR-0005: Web-Compatible Rendering

## Status
**Accepted**

## Date
2026-04-19

## Context

The project targets PC and Web platforms. The game is a horror title with atmospheric lighting, shadows, and post-processing effects. Web targets (browser) have strict memory limits (~512 MB shared across all tabs), CPU constraints (single-threaded rendering on many devices), and GPU limitations (no compute shaders, limited shader complexity).

The question is how to balance visual quality with Web compatibility.

## Decision

Rendering is configured for Forward+ rendering path with Web-compatible budgets. All visual effects must meet Web performance targets while delivering quality on PC.

### Key Interfaces

- **`RenderingServer`** — Global rendering API for custom draw calls (if needed)
- **`WorldEnvironment`** — Post-processing setup (bloom, SSAO, ambient occlusion)
- **`LightmapGI`** — Baked lighting for static environments (rooms)
- **`GPUParticles3D`** — VFX for anomalies and atmosphere (dust, fog)
- **`CanvasLayer`** — UI rendering (HUD, menus)
- **`Camera3D`** — Player viewport with tunable FOV and zoom

### Technical Constraints

- **Rendering path**: Forward+ (default for Godot 4.6). Mobile path is not used — PC/Web targets support Forward+.
- **Web memory ceiling**: 512 MB total (shared across browser tabs). The game must stay within 256 MB to leave headroom.
- **Web CPU budget**: Rendering is single-threaded on Web. Physics and game logic run on the main thread. Total non-rendering CPU budget: < 4 ms per frame.
- **No compute shaders on Web**: Godot's Web export does not support compute shaders. All VFX must use `GPUParticles3D` or vertex/fragment shaders.
- **Texture compression**: Use S3TC/BPTC on PC; ETC2 on Web (for Android compatibility). Godot's export pipeline handles this automatically.

### Performance Budgets

| Metric | PC Target | Web Target | Notes |
|--------|-----------|------------|-------|
| **Frame time** | 16.6 ms | 16.6 ms | 60 fps target on both |
| **Draw calls** | < 500 | < 300 | Web has higher draw call overhead |
| **Memory** | < 512 MB | < 256 MB | Web budget is shared with browser |
| **Triangles** | < 2M | < 1M | Web GPU limitations |
| **Lights** | < 50 | < 25 | Web light processing cost |
| **Shadow maps** | < 4 | < 2 | Web shadow map cost |
| **VFX particles** | < 5000 | < 2000 | Web particle cost |

### Visual Effects Budget

| Effect | PC | Web | Notes |
|--------|----|----|-------|
| Bloom | Yes (medium quality) | Yes (low quality) | Web: reduce iterations |
| SSAO | Yes (medium quality) | No | Web: too expensive |
| Shadow maps | Yes (max 4) | Yes (max 2) | Web: reduce resolution |
| Post-processing | Full stack | Bloom only | Web: minimal post-processing |
| VFX (particles) | Full budget | Reduced budget | Web: limit active particles |
| Reflections | No | No | Too expensive for both |

### Technical Constraints

- **No deferred rendering**: Forward+ is used for both PC and Web. Deferred rendering has different memory characteristics and is not suitable for the Web target.
- **No ray tracing**: Not supported on Web; not a target feature for PC either.
- **No custom compute shaders**: Web export does not support compute shaders. All custom shaders must be vertex/fragment only.
- **Texture format**: Godot's export handles format selection. Manual format specification is not needed.

## Alternatives

### Alternative: PC-only rendering with quality scaling
- **Description**: Use high-quality rendering (SSAO, ray tracing, compute shaders) with quality scaling for Web
- **Pros**: Best visual quality on PC; simpler rendering code
- **Cons**: Ray tracing not supported on Web; compute shaders not supported on Web; quality scaling cannot fix fundamental platform differences; Web users get degraded experience
- **Rejection Reason**: Web has hard limitations that cannot be solved by quality scaling. Compute shaders and ray tracing simply do not exist on Web — they must be excluded entirely.

### Alternative: Web-only rendering with PC upscales
- **Description**: Design for the lowest common denominator (Web) and let PC have higher quality
- **Pros**: Web is the baseline; PC users get a bonus
- **Cons**: Still allows compute shaders and ray tracing on PC — both unsupported on Web; doesn't address the fundamental constraint
- **Rejection Reason**: This is essentially what "PC-only with scaling" does in reverse. The constraint is the same: Web has hard limits that must be designed within from the start.

### Alternative: Separate rendering paths
- **Description**: PC and Web use different rendering code paths
- **Pros**: Each platform gets optimized rendering
- **Cons**: Double the rendering code to maintain; divergent bug paths; higher maintenance cost
- **Rejection Reason**: The rendering codebase is small enough that a single path with budget constraints is more maintainable than two parallel paths.

## Consequences

### Positive
- **Web compatibility**: The game runs on Web targets within memory and CPU budgets
- **Single rendering path**: One codebase for both platforms — no divergence
- **Clear budgets**: Performance budgets define hard limits for each platform
- **Future-proof**: Budgets leave room for additional effects during development

### Negative
- **Reduced visual quality on Web**: SSAO, limited shadows, reduced particles — Web users get a lower-quality experience
- **PC quality constrained by Web**: Some effects are limited by the Web budget even on PC
- **Budget management**: Requires ongoing monitoring to stay within budgets

### Risks
- **Budget overflow**: Effects exceed Web budget during development. **Mitigation**: Profile early and often; use budgets as blocking gates during code review.
- **Browser updates**: Browser memory limits change over time. **Mitigation**: Monitor browser update notes; adjust budgets as needed.
- **Device fragmentation**: Web runs on everything from phones to desktops. **Mitigation**: Target mid-range devices; provide quality presets if needed.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `fp-controller.md` | Camera FOV and zoom | Tunable via `Camera3D` properties in `TuningKnobs` |
| `anomaly-system.md` | Anomaly visual effects | `GPUParticles3D` within Web budget |
| `monster-ai.md` | Monster appearance | Monster meshes within triangle budget |
| `vfx.md` | VFX budget per scene | Particle budget per scene defined by this ADR |
| `atmosphere.md` | Atmospheric lighting | `LightmapGI` for baked lighting; limited dynamic lights |

## Performance Implications
- **CPU**: Non-rendering CPU budget < 4 ms on Web — physics + game logic combined
- **GPU**: Web has no SSAO; reduced shadow count; limited particle count
- **Memory**: Web budget is 256 MB (shared with browser); PC budget is 512 MB
- **Network**: Not applicable — single-player only

## Migration Plan

This is a new project — no migration needed. During implementation:

1. Configure project for Forward+ rendering (default in Godot 4.6)
2. Set Web export memory limits in project settings
3. Profile rendering performance on Web target during gameplay implementation
4. Adjust budgets as needed based on profiling data
5. Code review: verify no compute shaders, no ray tracing, no deferred rendering

## Validation Criteria
- [ ] Game runs at 60 fps on Web target (mid-range device)
- [ ] Memory usage stays under 256 MB on Web
- [ ] No compute shaders are used
- [ ] No ray tracing features are used
- [ ] Draw calls stay under 300 on Web
- [ ] Triangle count stays under 1M on Web
- [ ] Shadow maps stay under 2 on Web

## Related Decisions
- ADR-0001 (Single-Scene Architecture) — Single-scene memory constraints inform rendering budget
- ADR-0002 (Jolt Physics) — Physics performance budget interacts with rendering budget
- ADR-0004 (Data-Driven Design) — TuningKnobs resource includes visual quality parameters
