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

# Screen width in pixels for a world-space width at a given distance.
static func project_screen_width(world_width: float, dist: float, focal: float) -> float:
	if dist < 0.01:
		return 99999.0
	return (world_width / dist) * focal

# ── Wave visual model ───────────────────────────────────────────────────────

# Horizontal angle the wave spans at its spawn distance.
# 3D-style perspective: the same world width subtends a larger angle when close.
# Eventually drive this from player height relative to water level.
const VIEW_ANGLE_DEG: float = 60.0

# Fraction of effective height the wave shows at spawn (grows to 1.0 at impact).
const START_HEIGHT_FRACTION: float = 0.30

# Maximum Y rise of the wave base as it travels from spawn to player.
const Y_RISE_MAX: float = 0.25

# Extra base lift proportional to effective height — tall waves loom higher.
const HEIGHT_LIFT_FACTOR: float = 0.30

# World-space width that subtends VIEW_ANGLE_DEG at spawn_distance.
static func wave_spawn_width(spawn_distance: float) -> float:
	return 2.0 * spawn_distance * tan(deg_to_rad(VIEW_ANGLE_DEG * 0.5))

# Visual height of the wave box at progress t (0 = just spawned, 1 = at player).
static func wave_visual_height(eff_h: float, t: float) -> float:
	return eff_h * (START_HEIGHT_FRACTION + (1.0 - START_HEIGHT_FRACTION) * t)

# World Y of the wave's bottom face at progress t.
static func wave_base_y(t: float, eff_h: float) -> float:
	return t * Y_RISE_MAX + eff_h * HEIGHT_LIFT_FACTOR
