class_name Wave
extends Node3D

const SPAWN_DISTANCE: float = 20.0

# Fire the hit as the wall fills the view, not at the player's exact Z. The
# renderer freezes a wave's on-screen size below WavePhysics.D_MIN (0.5 m), so
# without this the wave hangs at full size for several frames before impact
# registers. Keep this <= WavePhysics.D_MIN; a small gap leaves a brief loom.
const HIT_DISTANCE: float = 0.3

var wave_data: WaveData
var spawn_distance: float = SPAWN_DISTANCE

var _wave_speed: float
var _spawn_z: float

func setup(data: WaveData, player_z: float, speed: float) -> void:
	wave_data = data
	_wave_speed = speed
	spawn_distance = SPAWN_DISTANCE
	_spawn_z = player_z - SPAWN_DISTANCE
	position.z = _spawn_z
	add_to_group(&"waves")

func _process(delta: float) -> void:
	if not GameManager.is_playing:
		return
	position.z += _wave_speed * delta
	if dist_to_player() <= HIT_DISTANCE:
		SignalBus.wave_hit.emit(wave_data)
		queue_free()

# Distance in world metres from wave front to player.
func dist_to_player() -> float:
	return maxf(-GameManager.distance - position.z, 0.0)

# Progress from 0 (just spawned) to 1 (at player).
func t_progress() -> float:
	return clamp((position.z - _spawn_z) / SPAWN_DISTANCE, 0.0, 1.0)

# Seconds until the wave reaches the player and fires the hit. INF if stalled.
func time_to_hit() -> float:
	if _wave_speed <= 0.0:
		return INF
	return (dist_to_player() - HIT_DISTANCE) / _wave_speed

# Total water wall height: wave crest above surface + ambient water depth.
func eff_height() -> float:
	return WavePhysics.effective_height(wave_data.height, GameManager.water_level())
