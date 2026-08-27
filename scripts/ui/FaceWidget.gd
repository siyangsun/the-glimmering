extends Control

## Bottom-right UI face. Each clickable region (eyes, nose) is described by a
## Dictionary of config + mutable state. Generic helpers handle hover, hold-loop,
## click animation, and release — adding a new region is just declaring its config.

const FACE_SCALE: float = 6.0
const EYE_SCALE: float  = 6.0
const NOSE_SCALE: float = 4.8
const CORNER_MARGIN: Vector2 = Vector2(28.0, 28.0)

const EYE_L_CENTER: Vector2 = Vector2(20.0, 28.0)
const EYE_R_CENTER: Vector2 = Vector2(46.0, 28.0)
const NOSE_CENTER: Vector2  = Vector2(33.0, 37.0)
const EYE_HOVER_PAD_SIDE: float = 22.0
const EYE_HOVER_PAD_TOP: float  = 22.0
const EYE_HOVER_PAD_BOT: float  = 4.0
const NOSE_HOVER_PAD: float     = 6.0

const _FACE_PX: Vector2 = Vector2(64.0, 64.0)
const _EYE_PX: Vector2  = Vector2(20.0, 12.0)
const _NOSE_PX: Vector2 = Vector2(28.0, 24.0)

var _tex_eye_open: Texture2D
var _tex_eye_shut: Texture2D

var _face: TextureRect
var _eye_l: TextureRect
var _eye_r: TextureRect
var _eyewater_l: TextureRect
var _eyewater_r: TextureRect
var _nose_sprite: TextureRect

var _eyes_shut: bool = false
var _nose_particles: CPUParticles2D

# Region dictionaries — config keys are fixed; state keys (region/over/anim/held/loop_running)
# are mutated at runtime. Dictionaries are reference types so helpers modify them in-place.
var _eyes_reg: Dictionary
var _nose_reg: Dictionary

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_tex_eye_open = load("res://assets/sprites/eyeopen.png")
	_tex_eye_shut = load("res://assets/sprites/eyeshut.png")

	var tex_eyewater: Texture2D = load("res://assets/sprites/eyewater.png")
	_face        = _make_sprite(load("res://assets/sprites/mysteryman.png"), FACE_SCALE)
	_eye_l       = _make_sprite(_tex_eye_open, EYE_SCALE)
	_eye_l.flip_h = true
	_eye_r       = _make_sprite(_tex_eye_open, EYE_SCALE)
	_eyewater_l  = _make_sprite(tex_eyewater, EYE_SCALE)
	_eyewater_l.flip_h = true
	_eyewater_r  = _make_sprite(tex_eyewater, EYE_SCALE)
	_nose_sprite = _make_sprite(load("res://assets/sprites/nose.png"), NOSE_SCALE)
	add_child(_face)
	add_child(_eye_l)
	add_child(_eye_r)
	add_child(_eyewater_l)
	add_child(_eyewater_r)
	add_child(_nose_sprite)

	_nose_particles = CPUParticles2D.new()
	_nose_particles.emitting            = false
	_nose_particles.amount              = 10
	_nose_particles.lifetime            = 0.45
	_nose_particles.explosiveness       = 0.3
	_nose_particles.randomness          = 0.6
	_nose_particles.direction           = Vector2(0.0, 1.0)
	_nose_particles.spread              = 50.0
	_nose_particles.gravity             = Vector2(0.0, 140.0)
	_nose_particles.initial_velocity_min = 55.0
	_nose_particles.initial_velocity_max = 110.0
	_nose_particles.scale_amount_min    = 2.0
	_nose_particles.scale_amount_max    = 4.0
	_nose_particles.color               = Color(0.72, 0.88, 1.0, 0.9)
	add_child(_nose_particles)

	_eyes_reg = {
		"cursor_id": &"face_eyes", "priority": 20,
		"hover_cursor": &"reach",
		"click_frames": [&"fists", &"fists2"],
		"click_times":  [0.05, 0.09],
		"hold_frames":  [&"fists", &"fists2", &"fists3", &"fists2"],
		"hold_frame_time": 0.08,
		"release_frame": &"fists2", "release_time": 0.07,
		"action": &"wipe_eyes",
		"region": Rect2(), "over": false, "anim": false, "held": false, "loop_running": false,
	}
	_nose_reg = {
		"cursor_id": &"face_nose", "priority": 20,
		"hover_cursor": &"reach",
		"click_frames": [&"pinch", &"pinch2"],
		"click_times":  [0.07, 0.10],
		"hold_frames":  [&"pinch", &"pinch2"],
		"hold_frame_time": 0.10,
		"release_frame": &"pinch", "release_time": 0.07,
		"action": &"blow_nose",
		"region": Rect2(), "over": false, "anim": false, "held": false, "loop_running": false,
	}

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
	_face.position        = origin
	_eye_l.position       = origin + EYE_L_CENTER * FACE_SCALE - _EYE_PX * EYE_SCALE * 0.5
	_eye_r.position       = origin + EYE_R_CENTER * FACE_SCALE - _EYE_PX * EYE_SCALE * 0.5
	_eyewater_l.position  = _eye_l.position
	_eyewater_r.position  = _eye_r.position
	_nose_sprite.position = origin + NOSE_CENTER * FACE_SCALE - _NOSE_PX * NOSE_SCALE * 0.5

	var l: Rect2 = Rect2(_eye_l.position, _EYE_PX * EYE_SCALE)
	var r: Rect2 = Rect2(_eye_r.position, _EYE_PX * EYE_SCALE)
	_eyes_reg["region"] = l.merge(r).grow_individual(EYE_HOVER_PAD_SIDE, EYE_HOVER_PAD_TOP, EYE_HOVER_PAD_SIDE, EYE_HOVER_PAD_BOT)
	_nose_reg["region"]       = Rect2(_nose_sprite.position, _NOSE_PX * NOSE_SCALE).grow(NOSE_HOVER_PAD)
	_nose_particles.position  = _nose_sprite.position + Vector2(_NOSE_PX.x * NOSE_SCALE * 0.5, _NOSE_PX.y * NOSE_SCALE)

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	_refresh_region(_eyes_reg, mouse_pos)
	_refresh_region(_nose_reg, mouse_pos)

func _process(_delta: float) -> void:
	var wet: bool = ImpairmentSystem.eyes_value > 0.0
	_eyewater_l.visible = wet
	_eyewater_r.visible = wet

	_nose_particles.emitting = _nose_reg["held"]
	ImpairmentSystem.eyes_shielded = _eyes_reg["over"]
	ImpairmentSystem.nose_shielded = _nose_reg["held"]

	var shut: bool = _eyes_reg["held"] or _nose_reg["held"] or ImpairmentSystem.eyes_value >= ImpairmentSystem.EYE_MAX
	if shut == _eyes_shut:
		return
	_eyes_shut = shut
	var tex: Texture2D = _tex_eye_shut if shut else _tex_eye_open
	_eye_l.texture = tex
	_eye_r.texture = tex

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		_refresh_region(_eyes_reg, pos)
		_refresh_region(_nose_reg, pos)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for reg: Dictionary in [_eyes_reg, _nose_reg]:
			if mb.pressed and reg["over"] and not reg["anim"] and GameManager.is_playing:
				reg["held"] = true
				_click_anim(reg)
			elif not mb.pressed and reg["held"] and not reg["anim"]:
				reg["held"] = false
				_release_anim(reg)

func _refresh_region(reg: Dictionary, mouse_pos: Vector2) -> void:
	if reg["anim"]:
		return
	var over: bool = (reg["region"] as Rect2).has_point(mouse_pos)
	if over == reg["over"]:
		return
	reg["over"] = over
	if over:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_start_hold(reg)
		else:
			CursorManager.request(reg["cursor_id"], reg["hover_cursor"], reg["priority"])
	else:
		reg["held"] = false
		CursorManager.release(reg["cursor_id"])

func _click_anim(reg: Dictionary) -> void:
	reg["anim"] = true
	SignalBus.action_performed.emit(reg["action"])
	var frames: Array = reg["click_frames"]
	var times: Array  = reg["click_times"]
	for i: int in frames.size():
		CursorManager.request(reg["cursor_id"], frames[i], reg["priority"])
		await get_tree().create_timer(times[i]).timeout
	reg["anim"] = false

	reg["over"] = (reg["region"] as Rect2).has_point(get_viewport().get_mouse_position())
	if reg["over"]:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_start_hold(reg)
		else:
			reg["held"] = false
			CursorManager.request(reg["cursor_id"], reg["hover_cursor"], reg["priority"])
	else:
		reg["held"] = false
		CursorManager.release(reg["cursor_id"])

func _start_hold(reg: Dictionary) -> void:
	reg["held"] = true
	_hold_loop(reg)

func _hold_loop(reg: Dictionary) -> void:
	if reg["loop_running"]:
		return
	reg["loop_running"] = true
	var frames: Array = reg["hold_frames"]
	var i: int = 0
	while reg["held"]:
		CursorManager.request(reg["cursor_id"], frames[i % frames.size()], reg["priority"])
		i += 1
		await get_tree().create_timer(reg["hold_frame_time"]).timeout
	reg["loop_running"] = false

func _release_anim(reg: Dictionary) -> void:
	CursorManager.request(reg["cursor_id"], reg["release_frame"], reg["priority"])
	await get_tree().create_timer(reg["release_time"]).timeout
	if reg["over"]:
		CursorManager.request(reg["cursor_id"], reg["hover_cursor"], reg["priority"])
	else:
		CursorManager.release(reg["cursor_id"])
