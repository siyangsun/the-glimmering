extends Node2D

# A non-interactive companion that floats just ahead of the player, drawn through
# the same 2D perspective projection as the ocean (WavePhysics) so it rides the
# drawn waterline. When a wave is about to arrive it dives below the frame, then
# bobs back up once the wave has passed. Spawned/freed by Main.

const AHEAD: float     = 2.5    # metres in front of the player
const WORLD_H: float   = 0.85   # drawn height in metres (perspective-scaled)
const BOB_AMP: float   = 0.05
const BOB_FREQ: float  = 0.6
const SWAY_AMP: float     = 0.3    # metres of lateral drift
const SWAY_FREQ: float    = 0.22
const LATERAL_OFFSET: float = -1.6  # metres; negative sits the boat left of centre

# Duck-under: a one-shot dive triggered shortly before a wave lands. It commits
# to a full down-then-up cycle, so it still sinks under and returns even after
# the wave frees itself on impact.
const DUCK_LEAD_TIME: float = 1.5  # start ducking this long before the wave hits
const DUCK_DOWN_RATE: float = 0.7   # gradual dive
const DUCK_UP_RATE: float   = 0.15  # much slower return

var _tex: Texture2D  = null
var _phase: float    = 0.0
var _duck: float     = 0.0    # 0 = on the surface, 1 = fully below the frame
var _ducking: bool   = false  # a dive cycle is in progress
var _returning: bool = false  # within the cycle: false = diving, true = rising

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_phase = randf() * TAU
	if ResourceLoader.exists("res://assets/sprites/paperboat.png"):
		_tex = load("res://assets/sprites/paperboat.png")

func _process(delta: float) -> void:
	_phase += delta

	# Trigger a fresh dive when a wave is imminent — but not while already diving
	# (only allow a restart once we're on the way back up).
	if _wave_imminent() and (not _ducking or _returning):
		_ducking = true
		_returning = false

	if _ducking:
		if not _returning:
			_duck = move_toward(_duck, 1.0, DUCK_DOWN_RATE * delta)
			if _duck >= 1.0:
				_returning = true
		else:
			_duck = move_toward(_duck, 0.0, DUCK_UP_RATE * delta)
			if _duck <= 0.0:
				_ducking = false

	queue_redraw()

func _wave_imminent() -> bool:
	for w: Node in get_tree().get_nodes_in_group(&"waves"):
		if (w as Wave).time_to_hit() <= DUCK_LEAD_TIME:
			return true
	return false

func _draw() -> void:
	if _tex == null or not GameManager.is_playing:
		return

	var vp: Vector2 = get_viewport_rect().size
	var focal: float      = WavePhysics.focal_length(vp.y)
	var horizon_px: float = vp.y * WavePhysics.HORIZON_Y_FRAC
	var cam_y: float      = 0.85 if StaggerSystem.is_knocked_down else 1.7
	if ItemManager.is_enabled(&"pocketstones"):
		cam_y -= 0.2
	var eye_y: float      = WavePhysics.eye_height_above_water(cam_y, GameManager.water_level())

	var world_y: float = sin(_phase * BOB_FREQ * TAU) * BOB_AMP
	var lateral: float = LATERAL_OFFSET + sin(_phase * SWAY_FREQ * TAU) * SWAY_AMP
	var sy: float = WavePhysics.project_screen_y(world_y, AHEAD, eye_y, horizon_px, focal)
	var sx: float = vp.x * 0.5 + (lateral / AHEAD) * focal
	var h: float  = WORLD_H * focal / AHEAD

	# Dive below the bottom of the frame as _duck rises to 1.
	sy += _duck * vp.y * 1.3

	var aspect: float = float(_tex.get_width()) / float(_tex.get_height())
	var size := Vector2(h * aspect, h)
	draw_texture_rect(_tex, Rect2(Vector2(sx, sy) - size * 0.5, size), false)
