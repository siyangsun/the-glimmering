extends Control

@onready var _label: Label = $Label

var _max_wave_h: float = 0.0
var _expanded: bool = false
var _toggle_btn: Button
var _wave_btns: Array[Button] = []

func _ready() -> void:
	SignalBus.wave_hit.connect(_on_wave_hit)
	_label.visible = false
	_add_toggle_button()
	_add_wave_buttons()

func _add_toggle_button() -> void:
	_toggle_btn = Button.new()
	_toggle_btn.text = "DEBUG ▶"
	_toggle_btn.anchor_left   = 1.0
	_toggle_btn.anchor_right  = 1.0
	_toggle_btn.anchor_top    = 0.0
	_toggle_btn.anchor_bottom = 0.0
	_toggle_btn.offset_left   = -200.0
	_toggle_btn.offset_right  = -12.0
	_toggle_btn.offset_top    = 12.0
	_toggle_btn.offset_bottom = 42.0
	_toggle_btn.pressed.connect(_on_toggle)
	add_child(_toggle_btn)

func _on_toggle() -> void:
	_expanded = not _expanded
	_toggle_btn.text = "DEBUG ▼" if _expanded else "DEBUG ▶"
	_label.visible = _expanded
	for btn in _wave_btns:
		btn.visible = _expanded
	queue_redraw()

func _on_wave_hit(data: WaveData) -> void:
	_max_wave_h = maxf(_max_wave_h, data.height + GameManager.water_level())

func _process(_delta: float) -> void:
	if not _expanded:
		return
	queue_redraw()
	var eyes: String    = "%.0f" % ImpairmentSystem.eyes_value
	var ears: String    = "[X]" if ImpairmentSystem.ears_impaired else " ok"
	var nose: String    = "[X]" if ImpairmentSystem.nose_impaired else " ok"
	var drown: String   = str(int(DrownMeter.value * 100.0)) + "%"
	var stagger: String = str(int(StaggerSystem.value * 100.0)) + "%"
	var down: String    = " [DOWN]" if StaggerSystem.is_knocked_down else ""
	var water: String   = "%.2fm" % GameManager.water_level()
	_label.text = (
		"dist:     %.1fm / 100m\n"
		+ "water:    %s\n"
		+ "drown:    %s\n"
		+ "stagger:  %s%s\n"
		+ "eyes:     %s / 100\n"
		+ "max wave: %.2fm\n"
		+ "ears:%s  nose:%s"
	) % [GameManager.distance, water, drown, stagger, down, eyes, _max_wave_h, ears, nose]

func _draw() -> void:
	if not _expanded:
		return
	var rect: Rect2 = _label.get_rect()
	if rect.size == Vector2.ZERO:
		return
	var padded: Rect2 = rect.grow(8.0)
	draw_rect(padded, Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(padded, Color(1.0, 1.0, 1.0, 1.0), false, 1.0)

func _add_wave_buttons() -> void:
	var labels: Array[String] = ["small (25%)", "medium (70%)", "tall (92%)"]
	var fracs:  Array[float]  = [0.25, 0.70, 0.92]
	for i in range(3):
		var btn := Button.new()
		btn.text = labels[i]
		btn.visible = false
		btn.anchor_left   = 1.0
		btn.anchor_right  = 1.0
		btn.anchor_top    = 0.0
		btn.anchor_bottom = 0.0
		btn.offset_left   = -200.0
		btn.offset_right  = -12.0
		btn.offset_top    = 228.0 + float(i) * 36.0
		btn.offset_bottom = 258.0 + float(i) * 36.0
		var f: float = fracs[i]
		btn.pressed.connect(func() -> void: _spawn_wave_frac(f))
		add_child(btn)
		_wave_btns.append(btn)

func _spawn_wave_frac(eff_h_frac: float) -> void:
	var spawner: Node = get_tree().root.find_child("WaveSpawner", true, false)
	if spawner:
		spawner.spawn_wave_eff_frac(eff_h_frac)
