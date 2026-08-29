extends CPUParticles2D

# Cosmetic rain — bluish streaks falling across the screen while the rainstick is
# equipped. Emits from a wide box just above the top of the viewport. Purely
# visual; toggles itself on the item + play state.

const DROP_COUNT: int = 240
const FALL_SPEED_MIN: float = 900.0
const FALL_SPEED_MAX: float = 1300.0
const DROP_COLOR: Color = Color(0.62, 0.76, 1.0, 0.5)

func _ready() -> void:
	texture = _make_streak_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	amount = DROP_COUNT
	lifetime = 1.4
	preprocess = 1.4        # start mid-storm rather than a curtain dropping from the top
	randomness = 0.35
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	direction = Vector2(0.1, 1.0)   # slight slant
	spread = 3.0
	gravity = Vector2(0.0, 400.0)
	initial_velocity_min = FALL_SPEED_MIN
	initial_velocity_max = FALL_SPEED_MAX
	scale_amount_min = 0.8
	scale_amount_max = 1.7
	color = DROP_COLOR
	# Vary lifetimes so a good share of drops die early — landing in the lower ~40%
	# of the screen — while the rest fall all the way through.
	lifetime_randomness = 0.58
	color_ramp = _make_fade_ramp()
	emitting = false
	_resize()
	get_viewport().size_changed.connect(_resize)

func _process(_delta: float) -> void:
	emitting = GameManager.is_playing and ItemManager.is_enabled(&"rainstick")

func _resize() -> void:
	var vp: Vector2 = get_viewport_rect().size
	position = Vector2(vp.x * 0.5, -20.0)
	emission_rect_extents = Vector2(vp.x * 0.5 + 40.0, 4.0)

# Opaque for most of the drop's life, then a quick fade to nothing at the end, so
# early-dying drops visibly vanish where they land instead of popping out.
func _make_fade_ramp() -> Gradient:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.88, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return grad

# A short vertical streak, soft at both ends.
func _make_streak_texture() -> Texture2D:
	var w: int = 2
	var h: int = 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var a: float = clampf(minf(float(y), float(h - 1 - y)) / 4.0, 0.0, 1.0)
		for x in range(w):
			img.set_pixel(x, y, Color(0.82, 0.9, 1.0, a))
	return ImageTexture.create_from_image(img)
