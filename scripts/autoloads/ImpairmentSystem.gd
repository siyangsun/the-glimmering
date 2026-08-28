extends Node

const EAR_SPEED_MODIFIER: float = 0.55
const SHIELD_FACTOR: float = 0.2  # damage multiplier when eye/nose is shielded (shared by DrownMeter)

const EAR_NOSE_THRESHOLD: float = 0.90
const EYE_DAMAGE_PER_FORCE: float = 12.0
const EYE_MAX: float = 100.0
const EYE_RECOVERY_RATE: float = 1.5  # points/s — only active when below threshold
const EYE_RECOVERY_MAX: float = 60.0  # stops auto-recovering at or above this value

const EYE_WIPE_RATE: float = 30.0  # points removed per second while wiping

var eyes_value: float = 0.0
var eyes_shielded: bool = false
var eyes_wiping: bool = false
var nose_shielded: bool = false
var eyes_impaired: bool:
	get:
		return eyes_value > 0.0

var left_ear_impaired: bool  = false
var right_ear_impaired: bool = false
var ears_impaired: bool:
	get:
		return left_ear_impaired or right_ear_impaired

var nose_impaired: bool = false

func _ready() -> void:
	SignalBus.wave_hit.connect(_on_wave_hit)
	SignalBus.action_performed.connect(_on_action_performed)

func _process(delta: float) -> void:
	if eyes_wiping and eyes_value > 0.0:
		eyes_value = maxf(eyes_value - EYE_WIPE_RATE * delta, 0.0)
	elif eyes_value > 0.0 and eyes_value < EYE_RECOVERY_MAX:
		eyes_value = maxf(eyes_value - EYE_RECOVERY_RATE * delta, 0.0)

func get_speed_modifier() -> float:
	return EAR_SPEED_MODIFIER if ears_impaired else 1.0

func reset() -> void:
	eyes_value = 0.0
	eyes_shielded = false
	eyes_wiping = false
	nose_shielded = false
	_set_impairment(&"left_ear", false)
	_set_impairment(&"right_ear", false)
	_set_impairment(&"nose", false)

func _on_wave_hit(wave_data: WaveData) -> void:
	var player_h: float = 1.0 if StaggerSystem.is_knocked_down else 2.0
	var unsubmerged_h: float = GameManager.unsubmerged_height()
	var effective_height: float = wave_data.height + GameManager.water_level()

	if wave_data.height >= 0.5 * unsubmerged_h:
		var goggle_factor: float = 0.1 if ItemManager.is_enabled(&"goggles") else 1.0
		var eye_dmg: float = wave_data.force * EYE_DAMAGE_PER_FORCE * (SHIELD_FACTOR if eyes_shielded else 1.0) * goggle_factor
		eyes_value = minf(eyes_value + eye_dmg, EYE_MAX)

	if effective_height >= EAR_NOSE_THRESHOLD * player_h:
		_set_impairment(&"nose", true)
		var which: int = randi() % 3  # 0=left, 1=right, 2=both
		if which == 0 or which == 2:
			_set_impairment(&"left_ear", true)
		if which == 1 or which == 2:
			_set_impairment(&"right_ear", true)

func _on_action_performed(action: StringName) -> void:
	match action:
		&"wipe_eyes": pass  # drains gradually via eyes_wiping in _process
		&"blow_nose":  _set_impairment(&"nose", false)
		&"clear_left_ear":  _set_impairment(&"left_ear", false)
		&"clear_right_ear": _set_impairment(&"right_ear", false)
		&"clear_ears":
			_set_impairment(&"left_ear", false)
			_set_impairment(&"right_ear", false)

func _set_impairment(type: StringName, state: bool) -> void:
	match type:
		&"left_ear":  left_ear_impaired = state
		&"right_ear": right_ear_impaired = state
		&"nose":      nose_impaired = state
	SignalBus.impairment_changed.emit(type, state)
