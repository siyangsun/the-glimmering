extends ColorRect

# Tunnel-vision vignette that intensifies with the drown meter. Starts at 20% of
# the effect the moment drown is nonzero and scales to 100% at full drown.
func _ready() -> void:
	color = Color.TRANSPARENT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/drown_vignette.gdshader")
	material = mat

# Heartbeat rate (rad/s) grows exponentially: ~2.1 at the first hint of drown, 9 at full.
const BEAT_RATE_MIN: float = 1.5
const BEAT_RATE_GROWTH: float = 6.0

var _beat_phase: float = 0.0

func _process(delta: float) -> void:
	var drown: float = DrownMeter.value
	visible = drown > 0.0
	if visible:
		var intensity: float = 0.2 + 0.8 * clampf(drown, 0.0, 1.0)
		_beat_phase = fmod(_beat_phase + delta * BEAT_RATE_MIN * pow(BEAT_RATE_GROWTH, intensity), TAU)
		(material as ShaderMaterial).set_shader_parameter(&"intensity", intensity)
		(material as ShaderMaterial).set_shader_parameter(&"beat_phase", _beat_phase)
