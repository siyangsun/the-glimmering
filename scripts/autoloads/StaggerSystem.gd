extends Node

const STAGGER_PER_FORCE: float = 0.15   # stagger added per effective-force unit
const STAGGER_DRAIN_RATE: float = 0.08  # per second while standing

var value: float = 0.0
var is_knocked_down: bool = false

func _process(delta: float) -> void:
	if not GameManager.is_playing or is_knocked_down:
		return
	value = max(value - STAGGER_DRAIN_RATE * delta, 0.0)

func add_stagger(effective_force: float) -> void:
	if is_knocked_down:
		return
	value = min(value + effective_force * STAGGER_PER_FORCE, 1.0)
	if value >= 1.0:
		_knock_down()

func stand_up() -> void:
	is_knocked_down = false
	value = 0.0
	SignalBus.stood_up.emit()

func reset() -> void:
	value = 0.0
	if is_knocked_down:
		is_knocked_down = false
		SignalBus.stood_up.emit()

func _knock_down() -> void:
	is_knocked_down = true
	SignalBus.knocked_down.emit()
