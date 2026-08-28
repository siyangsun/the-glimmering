extends Node2D

# Rendered through the same 2D perspective projection as the ocean (WavePhysics),
# so the item sits exactly on the drawn waterline. Lives on the RenderLayer above
# WaveRenderer2D; no Camera3D / Sprite3D involved.

const BOB_AMP: float    = 0.06   # metres above the still-water line
const BOB_FREQ: float   = 0.7

const ITEM_WORLD_H: float = 0.55  # drawn height in metres (perspective-scaled)
const NEAR_CLIP: float    = 0.25  # metres; below this the player has reached/passed it
const HOVER_SCALE: float  = 0.65  # hover radius as a fraction of the drawn size
const MIN_HOVER_PX: float = 22.0  # floor so distant (tiny) items stay clickable

# Two-handed grab played on the cursor when an item is picked up — mirrors the
# eyes region in FaceWidget (reach hover → fists grab).
const GRAB_FRAMES: Array = [&"handclosed", &"handclosed2"]
const GRAB_TIMES: Array  = [0.05, 0.09]

var item_id: StringName        = &""
var distance_from_shore: float = 0.0
var lateral: float             = 0.0   # world x offset in metres

var _tex: Texture2D    = null
var _bob_phase: float  = 0.0
var _collected: bool   = false
var _visible_now: bool = false
var _screen_pos: Vector2   = Vector2(-9999.0, -9999.0)
var _screen_h: float       = 0.0
var _pop_y: float          = 0.0    # collect animation rise, in pixels
var _alpha: float          = 1.0
var _cursor_id: StringName = &""

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bob_phase = randf() * TAU
	_cursor_id = StringName("item_" + str(item_id))
	_build_visual()

func _build_visual() -> void:
	var catalog: Dictionary = ItemManager.CATALOG
	if item_id in catalog:
		var tex_path: String = catalog[item_id]["sprite"]
		if ResourceLoader.exists(tex_path):
			_tex = load(tex_path)

func _process(delta: float) -> void:
	if _collected:
		queue_redraw()
		return

	_bob_phase += delta * BOB_FREQ * TAU

	var dist: float = distance_from_shore - GameManager.distance
	if dist < NEAR_CLIP:
		_visible_now = false
		CursorManager.release(_cursor_id)
		queue_redraw()
		return

	var vp: Vector2 = get_viewport_rect().size
	var focal: float      = WavePhysics.focal_length(vp.y)
	var horizon_px: float = vp.y * WavePhysics.HORIZON_Y_FRAC
	var cam_y: float      = 0.85 if StaggerSystem.is_knocked_down else 1.7
	if ItemManager.is_enabled(&"pocketstones"):
		cam_y -= 0.2  # keep items on the same waterline WaveRenderer2D draws
	var eye_y: float      = WavePhysics.eye_height_above_water(cam_y, GameManager.water_level())

	var world_y: float = sin(_bob_phase) * BOB_AMP
	var sy: float = WavePhysics.project_screen_y(world_y, dist, eye_y, horizon_px, focal)
	var sx: float = vp.x * 0.5 + (lateral / dist) * focal
	_screen_pos = Vector2(sx, sy)
	_screen_h   = ITEM_WORLD_H * focal / dist
	_visible_now = true

	queue_redraw()

func _draw() -> void:
	if not _visible_now:
		return
	var center: Vector2 = _screen_pos - Vector2(0.0, _pop_y)
	if _tex:
		var aspect: float = float(_tex.get_width()) / float(_tex.get_height())
		var size := Vector2(_screen_h * aspect, _screen_h)
		draw_texture_rect(_tex, Rect2(center - size * 0.5, size), false, Color(1.0, 1.0, 1.0, _alpha))
	else:
		# Fallback placeholder — bright square so it's obvious in testing.
		var s := Vector2(_screen_h, _screen_h)
		draw_rect(Rect2(center - s * 0.5, s), Color(1.0, 0.9, 0.2, _alpha))

func _hover_radius() -> float:
	return maxf(_screen_h * HOVER_SCALE, MIN_HOVER_PX)

func _input(event: InputEvent) -> void:
	if _collected or not _visible_now:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if mb.position.distance_to(_screen_pos) <= _hover_radius():
		_collect()

func _collect() -> void:
	_collected = true
	ItemManager.collect(item_id)
	AudioManager.play_stinger_good()
	_play_grab()
	var tween := create_tween()
	tween.tween_property(self, "_pop_y", 26.0, 0.45).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "_alpha", 0.0, 0.35)
	tween.tween_callback(queue_free)

# Grab animation on the cursor: fists → fists2, then hand the cursor back.
# Runs faster than the pickup tween, so it always finishes before queue_free.
func _play_grab() -> void:
	for i: int in GRAB_FRAMES.size():
		CursorManager.request(_cursor_id, GRAB_FRAMES[i] as StringName, 15)
		await get_tree().create_timer(GRAB_TIMES[i] as float).timeout
	CursorManager.release(_cursor_id)
