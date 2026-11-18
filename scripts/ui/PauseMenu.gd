class_name PauseMenu
extends CanvasLayer

## Esc or P pauses a run. Only reacts while a run is live (or already paused), so
## it never pops up over the title / ending screens. Pausing freezes the whole
## tree (waves, audio, tweens); this node and CursorManager keep running.

var font: Font = null  # set by Main before this enters the tree

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = Main.LAYER_PAUSE
	visible = false
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or (key.keycode != KEY_ESCAPE and key.keycode != KEY_P):
		return
	if get_tree().paused:
		_set_paused(false)
	elif GameManager.is_playing:
		_set_paused(true)
	get_viewport().set_input_as_handled()

func _set_paused(on: bool) -> void:
	get_tree().paused = on
	visible = on

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override(&"separation", 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	var title := Label.new()
	title.text = "the sea waits."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override(&"font", font)
	title.add_theme_font_size_override(&"font_size", 26)
	box.add_child(title)

	box.add_child(_button("resume", func() -> void: _set_paused(false)))
	box.add_child(_button("quit", func() -> void: get_tree().quit()))

func _button(text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240.0, 40.0)
	btn.add_theme_font_override(&"font", font)
	btn.add_theme_font_size_override(&"font_size", 20)
	btn.pressed.connect(on_press)
	return btn
