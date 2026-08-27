class_name WavePhysics
extends RefCounted

# ── Ocean physics ───────────────────────────────────────────────────────────

const GRAVITY: float = 9.8
const NATURAL_PERIOD: float = 10.0   # s — typical open-ocean swell
const MIN_DEPTH: float = 0.1         # m — prevents division by zero near shore

const RAYLEIGH_SIGMA: float = 0.35   # modal wave height ~0.25 m
const HEIGHT_CAP: float = 1.0        # m

const FORCE_BASE: float = 1.0
const FORCE_PER_METRE: float = 2.5

const MIN_INTERVAL: float = 1.5      # s — hard floor on inter-arrival time

static func wave_speed(water_depth: float) -> float:
	return sqrt(GRAVITY * max(water_depth, MIN_DEPTH))

static func encounter_period(water_depth: float, player_speed: float) -> float:
	return NATURAL_PERIOD / (1.0 + player_speed / wave_speed(water_depth))

static func next_interval(water_depth: float, player_speed: float) -> float:
	var ep: float = encounter_period(water_depth, player_speed)
	return max(-ep * log(clamp(randf(), 0.0001, 0.9999)), MIN_INTERVAL)

static func rayleigh_height() -> float:
	return min(RAYLEIGH_SIGMA * sqrt(-2.0 * log(clamp(randf(), 0.0001, 0.9999))), HEIGHT_CAP)

static func effective_height(wave_height: float, water_level: float) -> float:
	return wave_height + water_level

static func wave_force(wave_height: float) -> float:
	return FORCE_BASE + wave_height * FORCE_PER_METRE

static func wave_size(wave_height: float) -> float:
	return clamp(wave_height / HEIGHT_CAP, 0.0, 1.0)

# ── 2D perspective projection ───────────────────────────────────────────────

# Vertical FOV of the camera — used to derive focal length.
const VFOV_DEG: float = 75.0

# Focal length in pixels given a viewport height.
static func focal_length(viewport_h: float) -> float:
	return (viewport_h * 0.5) / tan(deg_to_rad(VFOV_DEG * 0.5))

# Screen Y (pixels from top) for a world point at (world_y, dist) from the eye.
# horizon_px is the pixel Y of the flat-ocean vanishing line.
static func project_screen_y(world_y: float, dist: float, eye_y: float,
		horizon_px: float, focal: float) -> float:
	if dist < 0.01:
		return horizon_px
	return horizon_px - ((world_y - eye_y) / dist) * focal

# ── Wave visual model (projection-only) ─────────────────────────────────────
#
# A wave is a full-viewport-width vertical wall standing on the still-water line.
# Project its base (y = 0) and crest (y = H) through project_screen_y; the quad
# between them stretches as 1/d. See waves.md for the full model.

const HORIZON_Y_FRAC: float = 0.48   # vanishing-line Y as a fraction of viewport height

const E_MIN: float = 0.15            # m — floor on eye-above-water, projection stability
const D_MIN: float = 0.5             # m — floor on wave distance, caps the final close-up
const TOP_CLAMP_FRAC: float = 0.5    # screen_top >= -TOP_CLAMP_FRAC * viewport_h
const BOT_CLAMP_FRAC: float = 1.5    # screen_bot <=  BOT_CLAMP_FRAC * viewport_h
const CAT_MEDIUM_FRAC: float = 0.5   # eff_h / player_h at/above which a wave is >= Medium
const CAT_TALL_FRAC: float   = 0.9   # eff_h / player_h at/above which a wave is Tall

# Eye height above the still-water surface, floored for projection stability.
static func eye_height_above_water(cam_y: float, water_level: float) -> float:
	return maxf(cam_y - water_level, E_MIN)

# Screen span of a wave's full-width quad.
# wave_height: crest height above still water (WaveData.height).
# Returns Vector2(screen_top, screen_bot) — .x is the top edge, .y the bottom.
static func wave_screen_span(wave_height: float, dist: float, eye_y: float,
		horizon_px: float, focal: float, viewport_h: float) -> Vector2:
	var d: float = maxf(dist, D_MIN)
	var top: float = project_screen_y(wave_height, d, eye_y, horizon_px, focal)
	var bot: float = project_screen_y(0.0, d, eye_y, horizon_px, focal)
	top = maxf(top, -TOP_CLAMP_FRAC * viewport_h)
	bot = minf(bot,  BOT_CLAMP_FRAC * viewport_h)
	return Vector2(top, bot)

# Threat category: 0 short / 1 medium / 2 tall. Selects surface treatment and
# gameplay payload only — never geometry.
static func wave_category(eff_h: float, player_h: float) -> int:
	if eff_h >= CAT_TALL_FRAC * player_h:
		return 2
	if eff_h >= CAT_MEDIUM_FRAC * player_h:
		return 1
	return 0
