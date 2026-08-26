extends Node

const PLAYER_SPEED: float = 1.5  # m/s reference for Doppler calculation
const WAVE_SCENE: PackedScene = preload("res://scenes/Wave.tscn")

var _timer: float = 2.0  # short initial delay so first wave arrives quickly

func _process(delta: float) -> void:
	if not GameManager.is_playing:
		return
	_timer -= delta
	if _timer <= 0.0:
		_fire_wave()
		_timer = WavePhysics.next_interval(GameManager.water_level(), PLAYER_SPEED)

func _fire_wave() -> void:
	spawn_wave(WavePhysics.rayleigh_height())

func spawn_wave(height: float) -> void:
	var wave := WaveData.new()
	wave.height = clampf(height, 0.0, WavePhysics.HEIGHT_CAP)
	wave.force  = WavePhysics.wave_force(wave.height)
	wave.size   = WavePhysics.wave_size(wave.height)
	var speed: float    = WavePhysics.wave_speed(GameManager.water_level())
	var player_z: float = -GameManager.distance
	var wave_inst: Node = WAVE_SCENE.instantiate()
	add_child(wave_inst)
	wave_inst.call(&"setup", wave, player_z, speed)

# Spawn a wave whose eff_h (wave_height + water_level) equals eff_h_frac * player_h.
# Clamps wave height to [0, HEIGHT_CAP] so the category may not be reachable at depth.
func spawn_wave_eff_frac(eff_h_frac: float) -> void:
	var player_h: float = 1.0 if StaggerSystem.is_knocked_down else 2.0
	var target_eff_h: float = eff_h_frac * player_h
	spawn_wave(target_eff_h - GameManager.water_level())
