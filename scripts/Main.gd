extends Node

var _flash_rect: ColorRect = null

func _ready() -> void:
	_apply_font()
	_build_world()
	_build_vfx()
	_setup_cursor()
	SignalBus.game_ended.connect(_on_game_ended)
	SignalBus.wave_hit.connect(_on_wave_hit_flash)

var _cursor_open: Texture2D   = null
var _cursor_closed: Texture2D = null

func _setup_cursor() -> void:
	_cursor_open   = load("res://assets/sprites/hand.png")
	_cursor_closed = load("res://assets/sprites/handclosed.png")
	Input.set_custom_mouse_cursor(_cursor_open, Input.CURSOR_ARROW, Vector2.ZERO)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var tex: Texture2D = _cursor_closed if mb.pressed else _cursor_open
			Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2.ZERO)

func _on_wave_hit_flash(wave_data: WaveData) -> void:
	var player_h: float = 1.0 if StaggerSystem.is_knocked_down else 2.0
	if wave_data.height + GameManager.water_level() < 0.9 * player_h:
		return
	if not _flash_rect:
		return
	_flash_rect.size = get_viewport().get_visible_rect().size
	_flash_rect.color.a = 0.88
	var tween := create_tween()
	tween.tween_property(_flash_rect, "color:a", 0.0, 0.45)

func _build_vfx() -> void:
	# BackBufferCopy and EyeEffect live inside RenderLayer — the same CanvasLayer
	# as WaveRenderer2D, added after it. hint_screen_texture only reliably captures
	# content rendered earlier in the same layer's pass.
	# EyeEffect renders above BlindOverlay (layer 9) so distortion doesn't reach it.
	var eye_layer := CanvasLayer.new()
	eye_layer.layer = 10
	add_child(eye_layer)
	var eye_rect := ColorRect.new()
	eye_rect.set_script(preload("res://scripts/ui/EyeEffect.gd"))
	eye_layer.add_child(eye_rect)

	# Blind overlay — plain dark gray, no shader, handles 100% eye damage.
	var blind_layer := CanvasLayer.new()
	blind_layer.layer = 9
	add_child(blind_layer)
	var blind_rect := ColorRect.new()
	blind_rect.set_script(preload("res://scripts/ui/BlindOverlay.gd"))
	blind_layer.add_child(blind_rect)

	# White flash on tall wave impact
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 12
	add_child(flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(0.92, 0.94, 0.97, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(_flash_rect)

func _on_game_ended(ending: StringName) -> void:
	await get_tree().create_timer(1.5).timeout
	_show_end_screen(ending)

func _show_end_screen(ending: StringName) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	layer.add_child(bg)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Palatino Linotype"])

	if ending == &"drown":
		AudioManager.play_elegy_loop()

	var msg := Label.new()
	msg.text = "you drowned." if ending == &"drown" else "you have arrived."
	msg.anchor_left   = 0.5
	msg.anchor_right  = 0.5
	msg.anchor_top    = 0.4
	msg.anchor_bottom = 0.4
	msg.offset_left   = -200.0
	msg.offset_right  =  200.0
	msg.offset_top    = -30.0
	msg.offset_bottom =  30.0
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_override(&"font", font)
	msg.add_theme_font_size_override(&"font_size", 28)
	layer.add_child(msg)

	var btn := Button.new()
	btn.text = "again"
	btn.anchor_left   = 0.5
	btn.anchor_right  = 0.5
	btn.anchor_top    = 0.55
	btn.anchor_bottom = 0.55
	btn.offset_left   = -60.0
	btn.offset_right  =  60.0
	btn.offset_top    = -20.0
	btn.offset_bottom =  20.0
	btn.add_theme_font_override(&"font", font)
	btn.pressed.connect(func() -> void:
		layer.queue_free()
		AudioManager.fade_out_elegy(1.0)
		if ending == &"arrival":
			AudioManager.play_you_dare_return()
		GameManager.reset()
		DrownMeter.reset()
		StaggerSystem.reset()
		ImpairmentSystem.reset()
		AudioManager.reset()
	)
	layer.add_child(btn)

func _apply_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Palatino Linotype"])
	# Wait one frame so all scene nodes are in the tree before traversing.
	await get_tree().process_frame
	_set_font_recursive(get_tree().root, font)

func _set_font_recursive(node: Node, font: Font) -> void:
	if node is Label:
		(node as Label).add_theme_font_override(&"font", font)
	for child in node.get_children():
		_set_font_recursive(child, font)

func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.55, 0.60)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.55, 0.60)
	env.ambient_light_energy = 0.8
	env_node.environment = env
	add_child(env_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -20.0, 0.0)
	light.light_color = Color(0.82, 0.85, 0.90)
	light.light_energy = 0.5
	light.shadow_enabled = false
	add_child(light)
