extends Node

const FILL_RATE: float = 0.030       # per second while nose is clogged
const DRAIN_RATE: float = 0.050      # per second while nose is clear
const DRAIN_CHUNK: float = 0.03      # drain falls in discrete steps of this size
const WAVE_HIT_AMOUNT: float = 0.04  # burst per wave hit, scaled by wave size
const STONES_FILL_RATE: float = 0.010  # per second while wearing pocket stones (never drains)

var value: float = 0.0
var _drain_accum: float = 0.0

func reset() -> void:
	value = 0.0
	_drain_accum = 0.0

func _ready() -> void:
	SignalBus.wave_hit.connect(_on_wave_hit)

func _process(delta: float) -> void:
	if not GameManager.is_playing:
		return
	var shield: float = ImpairmentSystem.SHIELD_FACTOR if ImpairmentSystem.nose_shielded else 1.0
	if ImpairmentSystem.nose_impaired:
		_drain_accum = 0.0
		value = min(value + FILL_RATE * shield * delta, 1.0)
		if value >= 1.0:
			SignalBus.game_ended.emit(&"drown")
	elif ItemManager.is_enabled(&"pocketstones"):
		# Weighed down and low in the water: it seeps in and never fully drains.
		_drain_accum = 0.0
		value = min(value + STONES_FILL_RATE * delta, 1.0)
		if value >= 1.0:
			SignalBus.game_ended.emit(&"drown")
	else:
		_drain_accum += DRAIN_RATE * delta
		while _drain_accum >= DRAIN_CHUNK:
			value = maxf(value - DRAIN_CHUNK, 0.0)
			_drain_accum -= DRAIN_CHUNK

func _on_wave_hit(wave_data: WaveData) -> void:
	if not GameManager.is_playing:
		return
	var shield: float = ImpairmentSystem.SHIELD_FACTOR if ImpairmentSystem.nose_shielded else 1.0
	value = min(value + wave_data.size * WAVE_HIT_AMOUNT * shield, 1.0)
