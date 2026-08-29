extends ColorRect

const _WOBBLE_START: float = 0.50  # eyes_value fraction where wobble begins

func _ready() -> void:
	color = Color.TRANSPARENT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/blind_overlay.gdshader")
	material = mat

func _process(_delta: float) -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var eyes_pct: float = ImpairmentSystem.eyes_value / ImpairmentSystem.EYE_MAX
	# 0 below 30%, ramps to 1.0 at full blindness
	var amount: float = clampf((eyes_pct - _WOBBLE_START) / (1.0 - _WOBBLE_START), 0.0, 1.0)
	visible = amount > 0.001
	if visible:
		(material as ShaderMaterial).set_shader_parameter(&"blind_amount", amount)
