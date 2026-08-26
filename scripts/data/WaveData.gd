class_name WaveData
extends Resource

@export var size: float = 0.5    # 0–1; drives visual scale and drown meter hit
@export var force: float = 3.0   # base knockback in metres (scaled by height ratio)
@export var height: float = 1.5  # wave height in metres
@export var delay_after: float = 5.0  # seconds until next wave
