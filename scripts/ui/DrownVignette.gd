extends ColorRect

# Tunnel-vision vignette that intensifies with the drown meter. Starts at 20% of
# the effect the moment drown is nonzero and scales to 100% at full drown.
func _ready() -> void:
	color = Color.TRANSPARENT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/drown_vignette.gdshader")
	material = mat

func _process(_delta: float) -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var drown: float = DrownMeter.value
	visible = drown > 0.0
	if visible:
		var intensity: float = 0.2 + 0.8 * clampf(drown, 0.0, 1.0)
		(material as ShaderMaterial).set_shader_parameter(&"intensity", intensity)
