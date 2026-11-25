extends Node

const BASE_SPEED: float = 1.2           # m/s on dry land / very shallow water
const KNOCKED_SPEED_MULT: float = 0.20  # 80% speed reduction when down

# Speed when fully submerged (water_level >= player height).
# Linear interpolation between BASE_SPEED and this value as depth increases.
const SUBMERGED_SPEED: float = 0.22    # m/s

const CAM_LERP_SPEED: float = 4.0

# Walking motion. Kept subtle on purpose. The world is drawn in 2D, so these feed
# GameManager.cam_* and the renderers shift/roll the projection — there is no 3D camera.
const SWAY_AMP: float    = 0.05   # metres left/right
const SWAY_TILT: float   = 0.015  # radians of roll (~0.9°)
const BOB_AMP: float     = 0.025  # metres up/down (twice per lateral cycle)
const STEP_FREQ: float   = 0.325  # full cycles/s at BASE_SPEED
const PACE_EASE: float   = 5.0    # how fast sway fades in/out as you start/stop

var _sway_phase: float = 0.0
var _base_y: float = GameManager.STANDING_CAM_Y  # smoothed eye height, before bob
var _bob: float = 0.0
var _pace: float = 0.0  # eased speed / BASE_SPEED; scales sway rate and size

func _ready() -> void:
	SignalBus.wave_hit.connect(_on_wave_hit)
	SignalBus.game_reset.connect(_on_game_reset)

func _on_game_reset() -> void:
	_sway_phase = 0.0
	_base_y = GameManager.STANDING_CAM_Y
	_bob = 0.0
	_pace = 0.0
	GameManager.cam_y = _base_y
	GameManager.cam_x = 0.0
	GameManager.cam_roll = 0.0

func _process(delta: float) -> void:
	if not GameManager.is_playing:
		return

	var speed: float = 0.0
	if OS.is_debug_build() and Input.is_key_pressed(KEY_SHIFT) and Input.is_action_pressed(&"walk_forward"):  # dev sprint: shift only counts while walking
		GameManager.advance(10.0 * delta)
	elif StaggerSystem.is_knocked_down:
		# W stands you up when knocked down
		if Input.is_action_just_pressed(&"walk_forward"):
			StaggerSystem.stand_up()
		# Still shuffle forward at greatly reduced speed
		elif Input.is_action_pressed(&"walk_forward"):
			GameManager.advance(BASE_SPEED * KNOCKED_SPEED_MULT * delta)
	else:
		if Input.is_action_pressed(&"walk_forward"):
			speed = BASE_SPEED * ImpairmentSystem.get_speed_modifier() * _water_drag()
			GameManager.advance(speed * delta)

	# Eye height eases between standing and knocked-down; bob rides on top.
	var target_y: float = GameManager.KNOCKED_CAM_Y if StaggerSystem.is_knocked_down else GameManager.STANDING_CAM_Y
	_base_y = lerpf(_base_y, target_y, CAM_LERP_SPEED * delta)

	# Sway rate and size both follow actual walking speed (0 when not walking),
	# so wading deep or with clogged ears is a slower, shallower roll.
	_pace = lerpf(_pace, speed / BASE_SPEED, PACE_EASE * delta)
	_sway_phase += delta * STEP_FREQ * TAU * _pace
	_bob = sin(_sway_phase * 2.0) * BOB_AMP * _pace
	GameManager.cam_x = sin(_sway_phase) * SWAY_AMP * _pace
	GameManager.cam_roll = sin(_sway_phase) * SWAY_TILT * _pace
	GameManager.cam_y = _base_y + _bob

# Water resistance scales linearly with depth ratio (water_level / player height).
# 0 = dry land (no drag), 1 = fully submerged (maximum drag).
func _water_drag() -> float:
	var depth_ratio: float = clampf(GameManager.water_level() / GameManager.player_height(), 0.0, 1.0)
	return lerpf(1.0, SUBMERGED_SPEED / BASE_SPEED, depth_ratio)

func _on_wave_hit(wave_data: WaveData) -> void:
	var effective_height: float = WavePhysics.effective_height(wave_data.height, GameManager.water_level())
	var ratio: float = effective_height / GameManager.player_height()
	var effective_force: float = wave_data.force * ratio
	if Input.is_action_pressed(&"walk_forward"):
		effective_force *= 1.1  # walking into the wave on impact
	GameManager.apply_knockback(effective_force)
	StaggerSystem.add_stagger(effective_force)
