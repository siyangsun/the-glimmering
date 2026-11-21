extends Control

## Bottom-left feet, resting on foot1. Hover brightens them; clicking plays foot0-5 per foot
## (left, then right starting just before left finishes) while holding walk_forward,
## so it walks exactly like W. Holding the mouse keeps stepping, with blank frames
## between a foot's foot5 and its next foot0; releasing snaps back to foot1.

const FOOT_SCALE: float = 4.0
const CORNER_MARGIN: Vector2 = Vector2(-20.0, 28.0)
const FOOT_GAP: float = -110.0        # screen pixels between the two feet (negative overlaps transparent padding)
const FRAME_TIME: float = 0.1         # seconds per foot frame
const OVERLAP: int = 2                # frames the next foot starts before the previous finishes
# Each foot's cycle: 6 step frames, then blanks until its next turn (6 - 2*OVERLAP blanks).
const _STRIDE: int = 6 - OVERLAP      # frames between one foot starting and the other starting
const _CYCLE: int = _STRIDE * 2
const HOVER_TINT: Color = Color(1.3, 1.3, 1.3)

const _FOOT_PX: Vector2 = Vector2(64.0, 68.0)

var _frames: Array[Texture2D] = []
var _left: TextureRect
var _right: TextureRect
var _region: Rect2 = Rect2()
var _over: bool = false
var _walking: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i: int in range(0, 6):
		_frames.append(load("res://assets/sprites/foot%d.png" % i))
	_left = _make_foot(true)
	_right = _make_foot(false)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _make_foot(flip: bool) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _frames[1]
	tr.flip_h = flip
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.scale = Vector2(FOOT_SCALE, FOOT_SCALE)
	add_child(tr)
	return tr

func _layout() -> void:
	var size_px: Vector2 = _FOOT_PX * FOOT_SCALE
	var y: float = get_viewport_rect().size.y - size_px.y - CORNER_MARGIN.y
	_left.position = Vector2(CORNER_MARGIN.x, y)
	_right.position = Vector2(CORNER_MARGIN.x + size_px.x + FOOT_GAP, y)
	_region = Rect2(_left.position, Vector2(size_px.x * 2.0 + FOOT_GAP, size_px.y))
	_set_over(_region.has_point(get_viewport().get_mouse_position()))

func _set_over(over: bool) -> void:
	if over == _over:
		return
	_over = over
	if over:
		CursorManager.request(&"feet", &"none", 20)
	else:
		CursorManager.release(&"feet")
	var tint: Color = HOVER_TINT if over else Color.WHITE
	_left.modulate = tint
	_right.modulate = tint

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_over(_region.has_point((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _over and GameManager.is_playing:
			_walk()

func _walk() -> void:
	if _walking:
		return
	_walking = true
	Input.action_press(&"walk_forward")
	var t: int = 0
	# A click plays at least one step per foot; after that, keep going only while held.
	while GameManager.is_playing and (t < _STRIDE + 6 or (_over and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))):
		_left.texture = _cycle_frame(t)
		_right.texture = _cycle_frame(t - _STRIDE) if t >= _STRIDE else _frames[1]
		t += 1
		await get_tree().create_timer(FRAME_TIME).timeout
	_left.texture = _frames[1]
	_right.texture = _frames[1]
	Input.action_release(&"walk_forward")
	_walking = false

func _cycle_frame(t: int) -> Texture2D:
	var i: int = t % _CYCLE
	return _frames[i] if i < _frames.size() else null  # null = blank frame
