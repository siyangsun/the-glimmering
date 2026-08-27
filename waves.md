# The Glimmering — Wave Model

How a wave becomes a rectangle on screen. **Projection-only**: wave height is an
input, both edges of the rectangle come from one shared perspective projection,
and the short / medium / tall split only picks surface treatment and gameplay
payload — never geometry.

Supersedes the hand-tuned screen-space model in `WaveRenderer2D._draw_wave`
(`t_ease = t³`, `display_ratio = ratio * 2.5`, the `bot_drop` fudge). That model
is broken: above `ratio ≈ 0.4` every wave slams its top edge to the top of the
screen regardless of real height, and the crest never uses perspective.

---

## Implementation scope

This is the whole change. An agent should not need visual judgement to land it.

**What changes** — only the computation of the wave quad's two horizontal edges:

- `WaveRenderer2D._draw_wave`: replace the block that computes `t_ease`,
  `display_ratio`, `screen_top`, `base_y`, `screen_bot`, `bot_drop` with a single
  call to `WavePhysics.wave_screen_span(...)` (defined below).
- Add the shared functions listed under **Shared functions** to `WavePhysics.gd`.
- Route the `_draw_wave` `wave_type` ladder and the `Main._on_wave_hit_flash`
  `0.9` test through `WavePhysics.wave_category`.
- Delete the dead code listed at the bottom.

**What does NOT change** — keep byte-for-byte:

- The tint `PackedColorArray`s and the `short_top` / `medium_bot` / `faded_dark` /
  `faded_lite` derivation in `_draw_wave` (the per-category colour gradient).
- The water texture (`_WATER_TEX`), its UV mapping, and the `WAVE_JITTER_*` ripple.
- The distance-haze fade (`WAVE_FADE_DIST`, `WAVE_HORIZON_BLEND`, `dist_fade`).
- `_draw_wave_foam` and every `FOAM_*` constant.
- The white impact flash in `Main._on_wave_hit_flash`.
- The splash-blob system in `WaveRenderer2D._on_wave_hit_splash` — left entirely
  alone. Its `0.5 · unsubmerged_height` gate feeds the same value into the `norm`
  intensity ramp, so routing only the gate through `wave_category` would split the
  criterion. Unifying it is a deferred follow-up (see **Short / medium / tall**).
- `_draw_water_surface` — the perspective ocean floor is a separate system,
  untouched.
- The painter's-order wave sort (far → near) in `_draw`.
- `Wave.gd`, `WaveSpawner.gd`, `WaveData.gd`, `GameManager.gd` — no changes.

Downstream of the new edges, `wave_h = screen_bot − screen_top` and the UV spans
flow through exactly as they do today.

---

## Concept

A wave is a **planar wavefront** — an infinite horizontal line of water sweeping
across the seabed toward the player. It is perpendicular to the view and spans the
whole horizon, so it renders as a **full-viewport-width rectangle** (x from `0` to
`vw`). As it nears, perspective alone stretches that rectangle in height (`∝ 1/d`).
That is the entire "it's approaching" effect. No easing curves.

The wave is an infinitely thin vertical sheet at distance `d` — it has no footprint
depth. Its base sits **exactly on the still-water line** for the entire approach:
no lift, no rise, no trough. The base appears to slide down the screen only because
perspective drops the waterline toward your feet as `d` shrinks.

---

## Coordinate frame

All heights are **metres above the still-water surface** (not the seabed).

| Symbol | Meaning | Source |
|---|---|---|
| `d` | distance from wavefront to player, metres | `Wave.dist_to_player()` |
| `H` | wave crest height above still water, metres | **per-wave input** — `WaveData.height`, clamped to `(0, HEIGHT_CAP]`, `HEIGHT_CAP = 1.0` |
| `w` | still-water depth **at the player** (never at the wave), metres | `GameManager.water_level()` — `0 → 2.0` over `0 → 100 m` |
| `cam_y` | eye height above seabed — **snapped**, `1.7` standing / `0.85` knocked down | see note below |
| `e` | eye height above still water, `= cam_y − w`, clamped to `E_MIN` | `WavePhysics.eye_height_above_water` |
| `player_h` | gameplay stature above seabed — `2.0` standing / `1.0` knocked down | `1.0 if StaggerSystem.is_knocked_down else 2.0` |
| `eff_h` | crest height above seabed, `= H + w` | `WavePhysics.effective_height(H, w)` |

**`cam_y` is the snapped value, not the live `Camera3D.position.y`.** The real
camera carries a stand↔knock lerp plus walk headbob (`BOB_AMP = 0.06`); feeding
those into wave geometry would make waves jitter vertically. Use `0.85` / `1.7`
keyed off `StaggerSystem.is_knocked_down`, exactly as `_eye_height()` does today.

Two reference heights, on purpose:

- **`e` (optical)** drives the projection.
- **`player_h` (gameplay)** drives the threat categories.

`eff_h ≥ k · player_h` is the same test as `H ≥ k · player_h − w` — "the crest is
`k`× my standing height". The `cam_y` / `player_h` mismatch (1.7 vs 2.0) is
intentional: optics vs gameplay, not a bug to reconcile.

Projection-only means **`w` is always evaluated at the player**. The wave does not
sample a depth field at its own position — there is no bathymetry model.

---

## Projection (core)

"Pinhole camera" here is a **formula, not a node**. There is no `Camera2D`:
`WaveRenderer2D` is a `Node2D` on a `CanvasLayer` and draws every wave as a
`draw_polygon` quad in raw screen coordinates. The scene's `Camera3D` is the
first-person viewpoint for 3D content and the source of eye height / bob / sway —
waves are painted on top of its output in 2D, never rendered through it. The
`Wave` node is a `Node3D` purely so it has a world position to measure `d` from;
nothing draws it.

Pinhole camera, fixed horizon:

```
horizon_px = vh · HORIZON_Y_FRAC          # HORIZON_Y_FRAC = 0.48
focal      = (vh / 2) / tan(VFOV / 2)     # VFOV = 75°  → WavePhysics.focal_length(vh)
```

`VFOV = 75°` must match the scene camera. `scenes/Main.tscn`'s `Camera3D` sets no
`fov`, so it uses Godot's default `75` with `keep_aspect = KEEP_HEIGHT` — i.e. a
*vertical* 75°, which is why `focal` keys off `vh`. If the camera FOV ever changes,
`WavePhysics.VFOV_DEG` must track it.

For any world point at height `y` above still water, at distance `d`:

```
screen_y(y, d) = horizon_px + focal · (e − y) / d
```

This is exactly the existing
`WavePhysics.project_screen_y(y, d, e, horizon_px, focal)` — pass `max(d, D_MIN)`.

---

## Screen rectangle

```
screen_bot = screen_y(0, d) = horizon_px + focal · e / d          # base, on the waterline
screen_top = screen_y(H, d) = horizon_px + focal · (e − H) / d    # crest

on-screen height = screen_bot − screen_top = focal · H / d
```

Because `H > 0` and `d > 0` always, `screen_bot > screen_top` is guaranteed — the
old `if screen_top >= screen_bot: return` guard becomes dead (drop it). Keep the
`if dist < 0.1: return` guard at the top of `_draw_wave`.

Behaviour that falls out for free:

- **`H < e`** (crest below eye level): `screen_top` stays *below* the horizon — the
  wave reads as a low swell that never breaks the skyline.
- **`H > e`**: `screen_top` crosses the horizon and races upward as `d → 0`.
- Pure `1/d` growth — a 1 m wave at `d = 20` is ~1/40th the screen height it has at
  `d = 0.5`.

### Clamps

All applied inside `wave_screen_span` so callers cannot get them half-right:

| Clamp | Value | Why |
|---|---|---|
| `d` → `max(d, D_MIN)` | `D_MIN = 0.5 m` | projection stays finite at impact |
| `e` → `max(e, E_MIN)` (done in `eye_height_above_water`) | `E_MIN = 0.15 m` | projection stays finite as the player submerges |
| `screen_top` → `max(screen_top, −0.5 · vh)` | — | bound the extreme close-up quad |
| `screen_bot` → `min(screen_bot, 1.5 · vh)` | — | same |

Clamping happens **after** computing the ideal edges. `wave_h` and the UV/tint
corners then use the clamped rectangle; when the true crest is off the top of the
screen its colour simply isn't visible. `D_MIN`, `E_MIN`, and the `±vh` factors are
starting values — expect one tuning pass in-editor.

`wave_hit` still fires on `d ≤ 0` (`Wave._process` frees the wave), so the fully
clamped close-up frame lasts one frame at most.

---

## Short / medium / tall

Categories are kept, but they only select **surface treatment + gameplay
payload**. Geometry is identical for all three. Thresholds are named constants on
`eff_h / player_h`:

```
CAT_MEDIUM_FRAC = 0.5     # >= this  → at least Medium
CAT_TALL_FRAC   = 0.9     # >= this  → Tall
```

`wave_category(eff_h, player_h)` returns `0` / `1` / `2`.

| Cat | Condition | Surface treatment | Payload |
|---|---|---|---|
| **0 Short** | `eff_h < 0.5 · player_h` | `short_top` (transparent) → `faded_dark` base | small knockback; **no** foam band, whiteout, or splash |
| **1 Medium** | `0.5 ≤ eff_h/player_h < 0.9` | `faded_dark` crest → `medium_bot` base | moderate knockback + stagger; splash |
| **2 Tall** | `eff_h ≥ 0.9 · player_h` | `faded_dark` crest → `faded_lite` base + `_draw_wave_foam` band | big knockback; stagger toward knockdown; whiteout flash; splash |

These three treatments are the existing `match wave_type` arms — unchanged, just
selected via `wave_category` instead of an inline ladder.

**Splash gate — deferred.** `_on_wave_hit_splash` skips when
`H < 0.5 · unsubmerged_height`, i.e. `H < 0.5·player_h − 0.5·w` — which is *not*
the same as `wave_category ≥ 1` (`H < 0.5·player_h − w`), and the same
`unsubmerged_height` value also drives the splash intensity ramp (`norm`). Routing
only the gate through `wave_category` would split gate from intensity, so the
current pass leaves `_on_wave_hit_splash` untouched. Unifying it — gate on
`wave_category` and rebase `norm` — is a clean follow-up once the category feel is
tuned in-editor. The whiteout flash gate *does* move to `wave_category == 2`,
which matches `_on_wave_hit_flash`'s existing `0.9` test exactly — no behaviour
change there.

**Category reachability.** With `HEIGHT_CAP = 1.0`, at the shoreline (`w ≈ 0`) the
maximum `eff_h/player_h` is `0.5` — **Tall is unreachable until `w ≳ 0.85 m`**
(roughly 40 m in). The DebugPanel "tall (92%)" button is subject to the same cap
and will render as Medium near shore. An agent testing at the start line should
expect this and not treat it as a projection bug.

`Wave.t_progress` is retained **for cosmetics only** — the distance-haze fade-in
and `_draw_wave_foam` timing. Never for geometry.

---

## Shared functions `WavePhysics` should expose

`WavePhysics` is pure logic (no Node references) — every input is passed in.

| Function | Contract | Replaces |
|---|---|---|
| `eye_height_above_water(cam_y: float, w: float) -> float` | returns `max(cam_y − w, E_MIN)` | `WaveRenderer2D._eye_height()` |
| `wave_screen_span(wave_height, dist, eye_y, horizon_px, focal, viewport_h) -> Vector2` | returns `Vector2(screen_top, screen_bot)` — `.x` is the top edge, `.y` the bottom. `wave_height` is the crest above still water (`WaveData.height`). Applies the `D_MIN` and `±vh` screen clamps internally. | the `t_ease` / `display_ratio` / `screen_top` / `base_y` / `bot_drop` block in `_draw_wave` |
| `wave_category(eff_h: float, player_h: float) -> int` | `0` if `eff_h < CAT_MEDIUM_FRAC·player_h`, `2` if `eff_h ≥ CAT_TALL_FRAC·player_h`, else `1` | the inline `wave_type` ladder in `_draw_wave`; the `0.9` test in `Main._on_wave_hit_flash` |

Keep as-is: `effective_height`, `wave_force`, `wave_size`, `focal_length`,
`project_screen_y`. Move `HORIZON_Y_FRAC` (currently in `WaveRenderer2D`) into
`WavePhysics` so projection and renderer share one value.

Callers still compute `player_h` and `cam_y` themselves from
`StaggerSystem.is_knocked_down` (`WavePhysics` can't see autoloads).

### Dead code to remove with the refactor

`wave_visual_height`, `wave_base_y`, `wave_spawn_width`, `project_screen_width`,
and the constants `START_HEIGHT_FRACTION`, `Y_RISE_MAX`, `HEIGHT_LIFT_FACTOR`,
`VIEW_ANGLE_DEG` — all part of the discarded hand-tuned model.

---

## Testing without an editor feedback loop

- `WaveSpawner.spawn_wave_eff_frac(frac)` spawns a wave targeting
  `eff_h = frac · player_h` (clamped by `HEIGHT_CAP`). The DebugPanel exposes
  buttons for `0.25` / `0.70` / `0.92`.
- Unit-checkable invariants for `WavePhysics` (no rendering needed), args
  `(wave_height, dist, eye_y, horizon_px, focal, viewport_h)`:
  - `span.y − span.x == focal · wave_height / max(dist, D_MIN)` (before the
    `±vh` clamp bites).
  - `span.x < horizon_px` iff `wave_height > eye_y`.
  - `wave_category` is monotonic in `eff_h` and returns exactly `{0,1,2}`.
  - `eye_height_above_water(1.7, 3.0) == E_MIN` (submerged floor holds).

---

## Boundaries / open questions

- **Submerged handoff** — when `cam_y − w ≤ 0` the waterline projects above the
  horizon and the whole frame is underwater. The model clamps `e` to `E_MIN` and
  keeps drawing, but the scene should switch to a submerged/underwater treatment
  around here. Out of scope for this doc.
- **Camera pitch / roll** — the 2D layer draws a level, fixed horizon and ignores
  the 3D camera's sway-roll and (currently absent) pitch. If the camera ever
  pitches, `horizon_px` must become dynamic and every projection call inherits it.
- **Wave–wave occlusion** — painter's sort (far → near) stays as is; a near wave
  simply overdraws a far one.
