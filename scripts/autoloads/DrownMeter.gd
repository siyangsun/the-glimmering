extends Node

const FILL_RATE: float = 0.030       # per second while nose is clogged
const DRAIN_RATE: float = 0.125      # per second while nose is clear
const WAVE_HIT_AMOUNT: float = 0.04  # burst per wave hit, scaled by wave size

var value: float = 0.0

func reset() -> void:
	value = 0.0

func _ready() -> void:
	SignalBus.wave_hit.connect(_on_wave_hit)

func _process(delta: float) -> void:
	if not GameManager.is_playing:
		return
	var shield: float = ImpairmentSystem.SHIELD_FACTOR if ImpairmentSystem.nose_shielded else 1.0
	if ImpairmentSystem.nose_impaired:
		value = min(value + FILL_RATE * shield * delta, 1.0)
		if value >= 1.0:
			SignalBus.game_ended.emit(&"drown")
	else:
		value = maxf(value - DRAIN_RATE * delta, 0.0)

func _on_wave_hit(wave_data: WaveData) -> void:
	if not GameManager.is_playing:
		return
	var shield: float = ImpairmentSystem.SHIELD_FACTOR if ImpairmentSystem.nose_shielded else 1.0
	value = min(value + wave_data.size * WAVE_HIT_AMOUNT * shield, 1.0)
