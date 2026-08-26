extends Control

@onready var _label: Label = $Label

func _process(_delta: float) -> void:
	var d: float = GameManager.distance
	var dist_rounded: int = int(d) if d < 10.0 else (int(d) / 10) * 10
	var eyes: String  = "[X]" if ImpairmentSystem.eyes_impaired else " ok"
	var ears: String  = "[X]" if ImpairmentSystem.ears_impaired else " ok"
	var nose: String  = "[X]" if ImpairmentSystem.nose_impaired else " ok"
	var knocked: String = "\n[KNOCKED DOWN — W to stand]" if StaggerSystem.is_knocked_down else ""
	_label.text = (
		"%d meters from shore%s\n\n"
		+ "eyes:%s  ears:%s  nose:%s\n\n"
		+ "[W] walk  [Q] eyes  [E] nose  [R] ears"
	) % [dist_rounded, knocked, eyes, ears, nose]
