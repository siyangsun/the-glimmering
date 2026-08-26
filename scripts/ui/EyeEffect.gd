extends ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.TRANSPARENT  # safe fallback if shader fails to apply
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/eye_splash.gdshader")
	material = mat

func _process(_delta: float) -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	(material as ShaderMaterial).set_shader_parameter(
		&"wet_amount", ImpairmentSystem.eyes_value / ImpairmentSystem.EYE_MAX)
