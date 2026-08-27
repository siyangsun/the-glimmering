extends Control

## Bottom-right UI face: the mysteryman spiral with two eyes and a nose layered
## on top. Hovering the eyes asks CursorManager for the reaching-hands cursor;
## clicking them punches (twofists → twofists2 → twofists) and clears eye damage,
## the same effect as the [Q] wipe_eyes shortcut.
##
## The cursor itself is owned by the CursorManager autoload — this node only
## detects hover / clicks on the eyes and files a request under &"face_eyes".

# --- Layout knobs (face-local pixels are 0..64 across the mysteryman sprite) ---
const FACE_SCALE: float = 6.0    # mysteryman.png is 64x64
const EYE_SCALE: float  = 6.0    # eyeopen/eyeshut.png are 20x12
const NOSE_SCALE: float = 4.8    # nose.png is 28x24
const CORNER_MARGIN: Vector2 = Vector2(28.0, 28.0)  # gap from the screen corner

const EYE_L_CENTER: Vector2 = Vector2(19.0, 28.0)
const EYE_R_CENTER: Vector2 = Vector2(45.0, 28.0)
const NOSE_CENTER: Vector2  = Vector2(32.0, 35.0)
const EYE_HOVER_PAD: float  = 14.0  # extra screen px around the eyes counting as hover

const CURSOR_ID: StringName = &"face_eyes"
const CURSOR_PRIORITY: int  = 20

# Punch animation: twofists (the single "frame") → twofists2 → rest on twofists.
const FIST_1_TIME: float = 0.05
const FIST_2_TIME: float = 0.09
const FIST_RELEASE_TIME: float = 0.07
const FIST_HOLD_FRAME_TIME: float = 0.08

const _FIST_LOOP: Array[StringName] = [&"fists", &"fists2", &"fists3", &"fists2"]

const _FACE_PX: Vector2 = Vector2(64.0, 64.0)
const _EYE_PX: Vector2  = Vector2(20.0, 12.0)
const _NOSE_PX: Vector2 = Vector2(28.0, 24.0)

var _tex_eye_open: Texture2D
var _tex_eye_shut: Texture2D

var _face: TextureRect
var _eye_l: TextureRect
var _eye_r: TextureRect
var _nose: TextureRect

var _eye_region: Rect2 = Rect2()
var _over: bool = false
var _fist_anim: bool = false
var _fist_held: bool = false  # LMB held while hovering, sitting on fists cursor
var _fist_loop_running: bool = false
var _eyes_shut: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_tex_eye_open = load("res://assets/sprites/eyeopen.png")
	_tex_eye_shut = load("res://assets/sprites/eyeshut.png")

	# Draw order: face, then eyes, then nose on top.
	_face  = _make_sprite(load("res://assets/sprites/mysteryman.png"), FACE_SCALE)
	_eye_l = _make_sprite(_tex_eye_open, EYE_SCALE)
	_eye_l.flip_h = true
	_eye_r = _make_sprite(_tex_eye_open, EYE_SCALE)
	_nose  = _make_sprite(load("res://assets/sprites/nose.png"), NOSE_SCALE)
	add_child(_face)
	add_child(_eye_l)
	add_child(_eye_r)
	add_child(_nose)

	get_viewport().size_changed.connect(_layout)
	_layout()

func _make_sprite(tex: Texture2D, s: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.scale = Vector2(s, s)
	return tr

func _layout() -> void:
	var origin: Vector2 = get_viewport_rect().size - _FACE_PX * FACE_SCALE - CORNER_MARGIN
	_face.position  = origin
	_eye_l.position = origin + EYE_L_CENTER * FACE_SCALE - _EYE_PX * EYE_SCALE * 0.5
	_eye_r.position = origin + EYE_R_CENTER * FACE_SCALE - _EYE_PX * EYE_SCALE * 0.5
	_nose.position  = origin + NOSE_CENTER * FACE_SCALE - _NOSE_PX * NOSE_SCALE * 0.5

	var l: Rect2 = Rect2(_eye_l.position, _EYE_PX * EYE_SCALE)
	var r: Rect2 = Rect2(_eye_r.position, _EYE_PX * EYE_SCALE)
	_eye_region = l.merge(r).grow(EYE_HOVER_PAD)
	_refresh_hover(get_viewport().get_mouse_position())

# eyes_value is a plain float with no change signal, so poll it — one comparison.
func _process(_delta: float) -> void:
	var shut: bool = _fist_held or ImpairmentSystem.eyes_value >= ImpairmentSystem.EYE_MAX
	if shut == _eyes_shut:
		return
	_eyes_shut = shut
	var tex: Texture2D = _tex_eye_shut if shut else _tex_eye_open
	_eye_l.texture = tex
	_eye_r.texture = tex

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_refresh_hover((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and _over and not _fist_anim and GameManager.is_playing:
			_fist_held = true
			_punch()
		elif not mb.pressed and _fist_held and not _fist_anim:
			_fist_held = false
			_fist_release()

func _refresh_hover(mouse_pos: Vector2) -> void:
	if _fist_anim:
		return
	var over: bool = _eye_region.has_point(mouse_pos)
	if over == _over:
		return
	_over = over
	if over:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_start_fist_hold()
		else:
			CursorManager.request(CURSOR_ID, &"reach", CURSOR_PRIORITY)
	else:
		_fist_held = false
		CursorManager.release(CURSOR_ID)

func _punch() -> void:
	_fist_anim = true
	SignalBus.action_performed.emit(&"wipe_eyes")
	CursorManager.request(CURSOR_ID, &"fists", CURSOR_PRIORITY)
	await get_tree().create_timer(FIST_1_TIME).timeout
	CursorManager.request(CURSOR_ID, &"fists2", CURSOR_PRIORITY)
	await get_tree().create_timer(FIST_2_TIME).timeout
	_fist_anim = false

	_over = _eye_region.has_point(get_viewport().get_mouse_position())
	if _over:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_start_fist_hold()
		else:
			_fist_held = false
			CursorManager.request(CURSOR_ID, &"reach", CURSOR_PRIORITY)
	else:
		_fist_held = false
		CursorManager.release(CURSOR_ID)

func _start_fist_hold() -> void:
	_fist_held = true
	_fist_hold_loop()

func _fist_hold_loop() -> void:
	if _fist_loop_running:
		return
	_fist_loop_running = true
	var i: int = 0
	while _fist_held:
		CursorManager.request(CURSOR_ID, _FIST_LOOP[i % _FIST_LOOP.size()], CURSOR_PRIORITY)
		i += 1
		await get_tree().create_timer(FIST_HOLD_FRAME_TIME).timeout
	_fist_loop_running = false

func _fist_release() -> void:
	CursorManager.request(CURSOR_ID, &"fists2", CURSOR_PRIORITY)
	await get_tree().create_timer(FIST_RELEASE_TIME).timeout
	if _over:
		CursorManager.request(CURSOR_ID, &"reach", CURSOR_PRIORITY)
	else:
		CursorManager.release(CURSOR_ID)
