extends Control

@onready var _label: Label = $Label

func _process(_delta: float) -> void:
	var d: float = GameManager.distance
	var dist_rounded: int = int(d) if d < 10.0 else (int(d) / 10) * 10
	var knocked: String = "\n[KNOCKED DOWN — W to stand]" if StaggerSystem.is_knocked_down else ""
	_label.text = (
		"%d meters from shore%s\n\n"
		+ "press W to walk"
	) % [dist_rounded, knocked]
