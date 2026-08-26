extends Node

const GOAL_DISTANCE: float = 100.0
const WATER_LEVEL_MAX: float = 2.0  # metres deep at 100m from shore
const KNOCKBACK_SCALE: float = 0.6
const ARRIVAL_DELAY: float = 11.0   # seconds after crossing 100m before ending

var distance: float = 0.0
var is_playing: bool = false
var run_count: int = 0
var _arrival_stinger_played: bool = false
var _arrival_timer: float = -1.0

func _ready() -> void:
	SignalBus.game_ended.connect(_on_game_ended)
	is_playing = true

func _process(delta: float) -> void:
	if not is_playing:
		return
	if distance >= GOAL_DISTANCE and not _arrival_stinger_played:
		_arrival_stinger_played = true
		AudioManager.play_stinger_bad()
		_arrival_timer = ARRIVAL_DELAY
	if _arrival_timer > 0.0:
		_arrival_timer -= delta
		if _arrival_timer <= 0.0:
			SignalBus.game_ended.emit(&"arrival")

func water_level() -> float:
	return minf((distance / GOAL_DISTANCE) * WATER_LEVEL_MAX, WATER_LEVEL_MAX)

func unsubmerged_height() -> float:
	var player_h: float = 1.0 if StaggerSystem.is_knocked_down else 2.0
	return maxf(player_h - water_level(), 0.1)

func advance(amount: float) -> void:
	if not is_playing:
		return
	distance += amount

func apply_knockback(amount: float) -> void:
	if not is_playing:
		return
	distance = max(0.0, distance - amount * KNOCKBACK_SCALE)

func _on_game_ended(ending: StringName) -> void:
	if not is_playing:
		return
	is_playing = false
	run_count += 1
	print("[GAME ENDED] %s | distance: %.1fm | drown: %.0f%%" % [
		ending, distance, DrownMeter.value * 100.0
	])

func reset() -> void:
	distance = 0.0
	is_playing = true
	_arrival_stinger_played = false
	_arrival_timer = -1.0
