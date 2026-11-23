extends Control

## Bottom-left feet, resting on foot1. Holding the mouse on them presses walk_forward,
## so it walks exactly like W. Whenever walk_forward is held (mouse or W) the feet play
## Gait loop per foot: foot0 ball lands, foot1 planted (held), foot2-5 lifting off,
## then empty while it swings through the air. The other foot lands just as this one
## starts lifting (half a cycle apart). Not walking (or letting go) shows foot1.

const FOOT_SCALE: float = 4.0
const CORNER_MARGIN: Vector2 = Vector2(-20.0, 28.0)
const FOOT_GAP: float = -110.0        # screen pixels between the two feet (negative overlaps transparent padding)
const FRAME_TIME: float = 0.1         # seconds per foot frame
const FOOT1_HOLD: int = 5            # frames planted on foot1 (>= 1)
const EMPTY_FRAMES: int = 3          # frames with no foot while it swings through the air
const _STEP: int = 6 - 1 + FOOT1_HOLD  # visible frames: foot0, foot1 x FOOT1_HOLD, foot2-5
const _CYCLE: int = _STEP + EMPTY_FRAMES
const _STRIDE: float = _CYCLE / 2.0    # other foot is half a cycle behind (may land mid-frame)
const HOVER_TINT: Color = Color(1.3, 1.3, 1.3)

const _FOOT_PX: Vector2 = Vector2(64.0, 68.0)

var _frames: Array[Texture2D] = []
var _left: TextureRect
var _right: TextureRect
var _region: Rect2 = Rect2()
var _over: bool = false
var _mouse_walking: bool = false  # we pressed walk_forward on the mouse's behalf
var _walk_frames: float = _STRIDE  # gait clock, in frames

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
	if not over:
		_set_mouse_walking(false)
	if over:
		CursorManager.request(&"feet", &"none", 20)
	else:
		CursorManager.release(&"feet")
	var tint: Color = HOVER_TINT if over else Color.WHITE
	_left.modulate = tint
	_right.modulate = tint

func _set_mouse_walking(on: bool) -> void:
	if on == _mouse_walking:
		return
	_mouse_walking = on
	if on:
		Input.action_press(&"walk_forward")
	else:
		Input.action_release(&"walk_forward")

# Feet vanish while knocked down; the area stays clickable to stand back up.
func _process(delta: float) -> void:
	visible = not StaggerSystem.is_knocked_down
	if _mouse_walking and (not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not GameManager.is_playing):
		_set_mouse_walking(false)  # release we never saw (outside window, paused)
	if not GameManager.is_playing or not Input.is_action_pressed(&"walk_forward"):
		# Start mid-gait (left lifting, right landing) so motion begins at once,
		# not with the left foot sitting planted on foot1.
		_walk_frames = _STRIDE
		_left.texture = _frames[1]
		_right.texture = _frames[1]
		return
	_left.texture = _cycle_frame(floori(_walk_frames))
	_right.texture = _cycle_frame(floori(_walk_frames - _STRIDE))
	_walk_frames += delta / FRAME_TIME

func _cycle_frame(f: int) -> Texture2D:
	var i: int = posmod(f, _CYCLE)
	if i >= _STEP:
		return null  # empty frame
	return _frames[clampi(i - FOOT1_HOLD + 1, 1, 5)] if i > 0 else _frames[0]

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_over(_region.has_point((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_set_mouse_walking(mb.pressed and _over and GameManager.is_playing)
