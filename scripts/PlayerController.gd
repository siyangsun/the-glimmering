extends Node3D

const BASE_SPEED: float = 1.2           # m/s on dry land / very shallow water
const KNOCKED_SPEED_MULT: float = 0.20  # 80% speed reduction when down

# Speed when fully submerged (water_level >= player height).
# Linear interpolation between BASE_SPEED and this value as depth increases.
const SUBMERGED_SPEED: float = 0.22    # m/s

# Pocket stones: heavier gait, but waves can't push you around.
const STONES_SPEED_MULT: float = 0.7

const STANDING_HEIGHT: float = 2.0
const KNOCKED_HEIGHT: float = 1.0      # 50% of standing height

const STANDING_CAM_Y: float = 1.7
const KNOCKED_CAM_Y: float = 0.85
const CAM_LERP_SPEED: float = 4.0

const SWAY_AMP: float    = 0.25   # metres left/right
const SWAY_TILT: float   = 0.08   # radians of Z roll (~4.6°)
const BOB_AMP: float     = 0.06   # metres up/down (twice per lateral cycle)
const SWAY_FREQ: float   = 1.3    # full cycles per second while walking
const SWAY_RETURN: float = 5.0    # lerp speed back to centre when stopped

var _sway_phase: float = 0.0

@onready var _camera: Camera3D = $Camera

func _ready() -> void:
	SignalBus.wave_hit.connect(_on_wave_hit)

func _process(delta: float) -> void:
	if not GameManager.is_playing:
		return

	if Input.is_key_pressed(KEY_SHIFT):
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
			var speed: float = BASE_SPEED * ImpairmentSystem.get_speed_modifier() * _water_drag()
			if ItemManager.is_enabled(&"pocketstones"):
				speed *= STONES_SPEED_MULT
			GameManager.advance(speed * delta)

	# Sync Z position to distance
	position.z = -GameManager.distance

	var walking: bool = Input.is_action_pressed(&"walk_forward") and not StaggerSystem.is_knocked_down

	# Camera height: base target + vertical bob while walking
	var target_y: float = KNOCKED_CAM_Y if StaggerSystem.is_knocked_down else STANDING_CAM_Y
	if walking:
		target_y += sin(_sway_phase * 2.0) * BOB_AMP
	_camera.position.y = lerp(_camera.position.y, target_y, CAM_LERP_SPEED * delta)

	# Side-to-side sway and tilt while walking
	if walking:
		_sway_phase += delta * SWAY_FREQ * TAU
		_camera.position.x = sin(_sway_phase) * SWAY_AMP
		_camera.rotation.z = sin(_sway_phase) * SWAY_TILT
	else:
		_camera.position.x = lerpf(_camera.position.x, 0.0, SWAY_RETURN * delta)
		_camera.rotation.z = lerpf(_camera.rotation.z,  0.0, SWAY_RETURN * delta)

func _current_height() -> float:
	return KNOCKED_HEIGHT if StaggerSystem.is_knocked_down else STANDING_HEIGHT

# Water resistance scales linearly with depth ratio (water_level / player height).
# 0 = dry land (no drag), 1 = fully submerged (maximum drag).
func _water_drag() -> float:
	var depth_ratio: float = clamp(GameManager.water_level() / _current_height(), 0.0, 1.0)
	return lerpf(1.0, SUBMERGED_SPEED / BASE_SPEED, depth_ratio)

func _on_wave_hit(wave_data: WaveData) -> void:
	# Pocket stones anchor you — the wave still soaks you (impairments apply
	# elsewhere), but it can't knock you back or off your feet.
	if ItemManager.is_enabled(&"pocketstones"):
		return
	var effective_height: float = WavePhysics.effective_height(wave_data.height, GameManager.water_level())
	var ratio: float = effective_height / _current_height()
	var effective_force: float = wave_data.force * ratio
	if Input.is_action_pressed(&"walk_forward"):
		effective_force *= 1.1  # walking into the wave on impact
	GameManager.apply_knockback(effective_force)
	StaggerSystem.add_stagger(effective_force)
