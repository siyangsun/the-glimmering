extends Control

## Bottom-right UI face. Each clickable spot is a FaceRegion (config + state);
## generic helpers here handle hover, hold-loop, click animation and release.
## Adding a region = constructing another FaceRegion. Hover/hold changes reach the
## simulation through SignalBus (see FaceRegion), never by writing its fields.

const FACE_SCALE: float = 6.0
const EYE_SCALE: float  = 6.0
const NOSE_SCALE: float = 4.8
const CORNER_MARGIN: Vector2 = Vector2(28.0, 28.0)

const EYE_L_CENTER: Vector2 = Vector2(20.0, 30.0)
const EYE_R_CENTER: Vector2 = Vector2(46.0, 30.0)
const NOSE_CENTER: Vector2  = Vector2(33.0, 39.0)
# Nudge the worn-goggles overlay up so it sits over the eyes, not just below them.
const GOGGLES_OFFSET: Vector2 = Vector2(0.0, -4.0)  # in face-texture pixels
const EYE_HOVER_PAD_SIDE: float = 0.0
const EYE_HOVER_PAD_TOP: float  = 2.0
const EYE_HOVER_PAD_BOT: float  = -40.0
const NOSE_HOVER_PAD: float     = 6.0
const EAR_Y_CENTER: float       = 28.0  # face-local pixels
const EAR_HOVER_W: float        = 50.0  # screen pixels (outer_reach + inset)
const EAR_HOVER_H: float        = 50.0  # screen pixels
const EAR_INSET: float          = 50.0  # overlap into face edge

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

var _gogglesworn: TextureRect
var _strangewig: TextureRect
var _eyes_shut: bool = false
var _eyes_wiping_prev: bool = false
var _nose_particles: CPUParticles2D
var _left_ear_particles: CPUParticles2D
var _right_ear_particles: CPUParticles2D

var _eyes_reg: FaceRegion
var _nose_reg: FaceRegion
var _left_ear_reg: FaceRegion
var _right_ear_reg: FaceRegion

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
	_gogglesworn = _make_sprite(load("res://assets/sprites/gogglesworn.png"), FACE_SCALE)
	add_child(_gogglesworn)
	_strangewig = _make_sprite(load("res://assets/sprites/strangewig.png"), FACE_SCALE)
	add_child(_strangewig)

	_nose_particles = _make_particles(Vector2(0.0, 1.0), 50.0, 10)
	# Nose drip reads as a persistent clogged-nose runoff — make it heavier and
	# more visible than the ear bursts: bigger, opaque, longer-lived drops.
	_nose_particles.scale_amount_min = 3.5
	_nose_particles.scale_amount_max = 7.0
	_nose_particles.lifetime         = 0.7
	_nose_particles.color            = Color(0.82, 0.92, 1.0, 1.0)
	_left_ear_particles  = _make_particles(Vector2(-1.0, 0.3), 35.0, 6)
	_right_ear_particles = _make_particles(Vector2(1.0, 0.3), 35.0, 6)
	add_child(_nose_particles)
	add_child(_left_ear_particles)
	add_child(_right_ear_particles)

	_eyes_reg = FaceRegion.new(&"face_eyes", &"wipe_eyes", &"reach")
	_eyes_reg.click_frames = [&"fists", &"fists2"]
	_eyes_reg.click_times = [0.05, 0.09]
	_eyes_reg.hold_frames = [&"fists", &"fists2", &"fists3", &"fists2"]
	_eyes_reg.hold_frame_time = 0.08
	_eyes_reg.release_frame = &"fists2"
	_eyes_reg.release_time = 0.07

	_nose_reg = FaceRegion.new(&"face_nose", &"blow_nose", &"reach")
	_nose_reg.click_frames = [&"pinch", &"pinch2"]
	_nose_reg.click_times = [0.07, 0.10]
	_nose_reg.hold_frames = [&"pinch", &"pinch2"]
	_nose_reg.hold_frame_time = 0.10
	_nose_reg.release_frame = &"pinch"
	_nose_reg.release_time = 0.07

	_left_ear_reg = _make_ear_region(&"face_left_ear", &"clear_left_ear", true, _left_ear_particles)
	_right_ear_reg = _make_ear_region(&"face_right_ear", &"clear_right_ear", false, _right_ear_particles)

	get_viewport().size_changed.connect(_layout)
	_layout()

func _make_ear_region(cursor_id: StringName, action: StringName, flip: bool,
		burst: CPUParticles2D) -> FaceRegion:
	var reg := FaceRegion.new(cursor_id, action, &"smack", flip)
	reg.click_frames = [&"smack2"]
	reg.click_times = [0.08]
	reg.hold_frames = [&"smack2"]
	reg.hold_frame_time = 0.5
	reg.release_frame = &"smack"
	reg.release_time = 0.0
	reg.particles = burst
	return reg

func _make_sprite(tex: Texture2D, s: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.scale = Vector2(s, s)
	return tr

func _make_particles(dir: Vector2, spread: float, amount: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting              = false
	p.one_shot              = true
	p.amount                = amount
	p.lifetime              = 0.45
	p.explosiveness         = 0.5
	p.randomness            = 0.6
	p.direction             = dir
	p.spread                = spread
	p.gravity               = Vector2(0.0, 140.0)
	p.initial_velocity_min  = 55.0
	p.initial_velocity_max  = 110.0
	p.scale_amount_min      = 2.0
	p.scale_amount_max      = 4.0
	p.color                 = Color(0.72, 0.88, 1.0, 0.9)
	return p

func _layout() -> void:
	var origin: Vector2 = get_viewport_rect().size - _FACE_PX * FACE_SCALE - CORNER_MARGIN
	_face.position        = origin
	_eye_l.position       = origin + EYE_L_CENTER * FACE_SCALE - _EYE_PX * EYE_SCALE * 0.5
	_eye_r.position       = origin + EYE_R_CENTER * FACE_SCALE - _EYE_PX * EYE_SCALE * 0.5
	_eyewater_l.position  = _eye_l.position
	_eyewater_r.position  = _eye_r.position
	_nose_sprite.position = origin + NOSE_CENTER * FACE_SCALE - _NOSE_PX * NOSE_SCALE * 0.5
	_gogglesworn.position = origin + GOGGLES_OFFSET * FACE_SCALE
	_strangewig.position = origin

	var l: Rect2 = Rect2(_eye_l.position, _EYE_PX * EYE_SCALE)
	var r: Rect2 = Rect2(_eye_r.position, _EYE_PX * EYE_SCALE)
	_eyes_reg.region = l.merge(r).grow_individual(EYE_HOVER_PAD_SIDE, EYE_HOVER_PAD_TOP, EYE_HOVER_PAD_SIDE, EYE_HOVER_PAD_BOT)
	_nose_reg.region = Rect2(_nose_sprite.position, _NOSE_PX * NOSE_SCALE).grow(NOSE_HOVER_PAD)

	_nose_particles.position = _nose_sprite.position + Vector2(_NOSE_PX.x * NOSE_SCALE * 0.5, _NOSE_PX.y * NOSE_SCALE * 0.72)

	var ear_y: float = origin.y + EAR_Y_CENTER * FACE_SCALE - EAR_HOVER_H * 0.5
	var face_w: float = _FACE_PX.x * FACE_SCALE
	_left_ear_reg.region  = Rect2(origin.x - EAR_HOVER_W + EAR_INSET, ear_y, EAR_HOVER_W, EAR_HOVER_H)
	_right_ear_reg.region = Rect2(origin.x + face_w - EAR_INSET, ear_y, EAR_HOVER_W, EAR_HOVER_H)
	_left_ear_particles.position  = Vector2(origin.x, ear_y + EAR_HOVER_H * 0.5 + 10.0)
	_right_ear_particles.position = Vector2(origin.x + face_w, ear_y + EAR_HOVER_H * 0.5 + 10.0)

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	for reg: FaceRegion in _all_regions():
		_refresh_region(reg, mouse_pos)

func _all_regions() -> Array[FaceRegion]:
	return [_eyes_reg, _nose_reg, _left_ear_reg, _right_ear_reg]

func _process(_delta: float) -> void:
	var wet: bool = ImpairmentSystem.eyes_value > 0.0
	_eyewater_l.visible = wet
	_eyewater_r.visible = wet
	_gogglesworn.visible = ItemManager.is_enabled(&"goggles")
	_strangewig.visible = ItemManager.is_enabled(&"strangewig")

	_nose_particles.amount = clampi(roundi(DrownMeter.value * 24.0), 4, 24)
	_nose_particles.emitting = DrownMeter.value > 0.0

	# A release we never saw (mouse let go while paused, or outside the window)
	# would leave a region held forever — settle it here.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		for reg: FaceRegion in _all_regions():
			if reg.held and not reg.anim:
				reg.held = false
				_release_anim(reg)

	# Rub-eyes sound: start when wiping begins, fade out when it stops.
	var wiping: bool = _eyes_reg.held
	if wiping and not _eyes_wiping_prev:
		AudioManager.play_rub_eyes()
	elif not wiping and _eyes_wiping_prev:
		AudioManager.fade_rub_eyes(0.2)
	_eyes_wiping_prev = wiping

	var shut: bool = _eyes_reg.held or _nose_reg.held or ImpairmentSystem.eyes_value >= ImpairmentSystem.EYE_MAX
	if shut == _eyes_shut:
		return
	_eyes_shut = shut
	var tex: Texture2D = _tex_eye_shut if shut else _tex_eye_open
	_eye_l.texture = tex
	_eye_r.texture = tex

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		for reg: FaceRegion in _all_regions():
			_refresh_region(reg, pos)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for reg: FaceRegion in _all_regions():
			if mb.pressed and reg.over and not reg.anim and GameManager.is_playing:
				reg.held = true
				_click_anim(reg)
			elif not mb.pressed and reg.held and not reg.anim:
				reg.held = false
				_release_anim(reg)

func _refresh_region(reg: FaceRegion, mouse_pos: Vector2) -> void:
	if reg.anim:
		return
	var over: bool = reg.region.has_point(mouse_pos)
	if over == reg.over:
		return
	reg.over = over
	if over:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_start_hold(reg)
		else:
			_show_hover_cursor(reg)
	else:
		reg.held = false
		CursorManager.release(reg.cursor_id)

func _show_hover_cursor(reg: FaceRegion) -> void:
	CursorManager.request(reg.cursor_id, reg.hover_cursor, reg.priority, reg.flip_h)

func _click_anim(reg: FaceRegion) -> void:
	reg.anim = true
	var fire_particles: bool = reg.particles != null
	if fire_particles:
		match reg.action:
			&"clear_left_ear":  fire_particles = ImpairmentSystem.left_ear_impaired
			&"clear_right_ear": fire_particles = ImpairmentSystem.right_ear_impaired
	# Ear smack sound — read the wet state before action_performed clears it.
	# (Rub-eyes is driven by the wiping state in _process so it can fade on release.)
	match reg.action:
		&"clear_left_ear":  AudioManager.play_ear_smack(false, ImpairmentSystem.left_ear_impaired)
		&"clear_right_ear": AudioManager.play_ear_smack(true, ImpairmentSystem.right_ear_impaired)
	SignalBus.action_performed.emit(reg.action)
	if fire_particles:
		reg.particles.restart()
	for i: int in reg.click_frames.size():
		CursorManager.request(reg.cursor_id, reg.click_frames[i], reg.priority, reg.flip_h)
		await get_tree().create_timer(reg.click_times[i]).timeout
	reg.anim = false

	reg.over = reg.region.has_point(get_viewport().get_mouse_position())
	if reg.over:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_start_hold(reg)
		else:
			reg.held = false
			_show_hover_cursor(reg)
	else:
		reg.held = false
		CursorManager.release(reg.cursor_id)

func _start_hold(reg: FaceRegion) -> void:
	reg.held = true
	_hold_loop(reg)

func _hold_loop(reg: FaceRegion) -> void:
	if reg.loop_running:
		return
	reg.loop_running = true
	var i: int = 0
	while reg.held:
		CursorManager.request(reg.cursor_id, reg.hold_frames[i % reg.hold_frames.size()], reg.priority, reg.flip_h)
		i += 1
		await get_tree().create_timer(reg.hold_frame_time).timeout
	reg.loop_running = false

func _release_anim(reg: FaceRegion) -> void:
	CursorManager.request(reg.cursor_id, reg.release_frame, reg.priority, reg.flip_h)
	await get_tree().create_timer(reg.release_time).timeout
	if reg.over:
		_show_hover_cursor(reg)
	else:
		CursorManager.release(reg.cursor_id)
