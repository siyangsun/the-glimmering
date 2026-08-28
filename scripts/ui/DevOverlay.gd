extends Control

const FONT_SIZE_REF: float = 48.0   # target size at 1080p
const HEIGHT_REF: float    = 1080.0

@onready var _label: Label = $Label

func _ready() -> void:
	get_viewport().size_changed.connect(_update_font_size)
	_update_font_size()

func _update_font_size() -> void:
	var size: int = roundi(get_viewport_rect().size.y * FONT_SIZE_REF / HEIGHT_REF)
	_label.add_theme_font_size_override(&"font_size", size)

func _process(_delta: float) -> void:
	var d: float = GameManager.distance
	var dist_rounded: int = int(d) if d < 10.0 else (int(d) / 10) * 10
	var knocked: String = "\n[KNOCKED DOWN — W to stand]" if StaggerSystem.is_knocked_down else ""
	_label.text = (
		"%d meters from shore%s\n\n"
		+ "press W to walk"
	) % [dist_rounded, knocked]
