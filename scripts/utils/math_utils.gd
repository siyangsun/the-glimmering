class_name MathUtils


# Returns true with the given probability (0.0–1.0).
static func chance(probability: float) -> bool:
	return randf() < probability


# Maps value from one range to another.
static func remap(value: float, from_min: float, from_max: float, to_min: float, to_max: float) -> float:
	return to_min + (value - from_min) / (from_max - from_min) * (to_max - to_min)


# Wraps an angle into [0, TAU).
static func wrap_angle(angle: float) -> float:
	return fmod(angle + TAU, TAU)


# Shortest signed angular difference from -> to, in [-PI, PI].
static func angle_diff(from_angle: float, to_angle: float) -> float:
	var diff: float = fmod(to_angle - from_angle + TAU, TAU)
	if diff > PI:
		diff -= TAU
	return diff


# Lerp along the shortest arc between two angles.
static func lerp_angle_short(from_angle: float, to_angle: float, weight: float) -> float:
	return from_angle + angle_diff(from_angle, to_angle) * weight


# Integer division rounding up.
static func ceil_div(a: int, b: int) -> int:
	return (a + b - 1) / b


# Rolls a random int in [low, high] (inclusive on both ends).
static func rand_range_i(low: int, high: int) -> int:
	return low + randi() % (high - low + 1)


# Clamps value and also returns whether it was clamped.
static func clamp_report(value: float, lo: float, hi: float) -> Dictionary:
	var clamped: float = clamp(value, lo, hi)
	return { "value": clamped, "was_clamped": clamped != value }


# Snaps value to the nearest multiple of step.
static func snap_to(value: float, step: float) -> float:
	return round(value / step) * step
