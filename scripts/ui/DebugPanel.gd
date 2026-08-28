extends Control

@onready var _label: Label = $Label

var _max_wave_h: float = 0.0
var _expanded: bool = false
var _toggle_btn: Button
var _wave_btns: Array[Button] = []
var _item_panel: Control = null

func _ready() -> void:
	SignalBus.wave_hit.connect(_on_wave_hit)
	_label.visible = false
	_add_toggle_button()
	_add_wave_buttons()
	_add_item_section()

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
	for btn: Button in _wave_btns:
		btn.visible = _expanded
	if _item_panel:
		_item_panel.visible = _expanded
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

# ── Item spawn section ────────────────────────────────────────────────────────

func _add_item_section() -> void:
	const BTN_SIZE: float  = 56.0
	const PAD: float       = 8.0
	const HEADER_H: float  = 20.0
	const SECTION_TOP: float = 346.0  # below last wave button (bottom=330)

	var ids: Array = ItemManager.CATALOG.keys()
	if ids.is_empty():
		return

	var count: int = ids.size()
	var panel_w: float = PAD + float(count) * BTN_SIZE + float(count - 1) * PAD + PAD
	var panel_h: float = PAD + HEADER_H + PAD + BTN_SIZE + PAD

	var style := StyleBoxFlat.new()
	style.bg_color    = Color(0.0, 0.0, 0.0, 0.55)
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 1.0)

	var panel := Panel.new()
	panel.visible       = false
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left   = -(panel_w + 12.0)
	panel.offset_right  = -12.0
	panel.offset_top    = SECTION_TOP
	panel.offset_bottom = SECTION_TOP + panel_h
	panel.add_theme_stylebox_override(&"panel", style)
	add_child(panel)
	_item_panel = panel

	var header := Label.new()
	header.text     = "spawn item"
	header.position = Vector2(PAD, PAD)
	header.size     = Vector2(panel_w - PAD * 2.0, HEADER_H)
	header.add_theme_font_size_override(&"font_size", 11)
	panel.add_child(header)

	for i: int in ids.size():
		var id: StringName       = ids[i]
		var info: Dictionary     = ItemManager.CATALOG[id]
		var tex_path: String     = info["sprite"]
		var captured_id: StringName = id
		var bx: float = PAD + float(i) * (BTN_SIZE + PAD)
		var by: float = PAD + HEADER_H + PAD

		if ResourceLoader.exists(tex_path):
			var tex_btn := TextureButton.new()
			tex_btn.texture_normal = load(tex_path)
			tex_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tex_btn.stretch_mode   = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			tex_btn.position       = Vector2(bx, by)
			tex_btn.size           = Vector2(BTN_SIZE, BTN_SIZE)
			tex_btn.tooltip_text   = info["name"]
			tex_btn.pressed.connect(func() -> void: _spawn_item_debug(captured_id))
			panel.add_child(tex_btn)
		else:
			var btn := Button.new()
			btn.text     = info["name"]
			btn.position = Vector2(bx, by)
			btn.size     = Vector2(BTN_SIZE, BTN_SIZE)
			btn.pressed.connect(func() -> void: _spawn_item_debug(captured_id))
			panel.add_child(btn)

func _spawn_item_debug(id: StringName) -> void:
	var main: Node = get_tree().root.get_node_or_null("Main")
	if not main:
		return
	var dist: float = GameManager.distance + 5.0
	var item: Node3D = load("res://scripts/world/FloatingItem.gd").new()
	item.set("item_id", id)
	item.set("distance_from_shore", dist)
	item.position = Vector3(0.0, 0.0, -(GameManager.distance + 5.0))
	main.add_child(item)
