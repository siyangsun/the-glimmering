extends Node2D

const _WATER_TEX: Texture2D = preload("res://assets/textures/water1.png")

const SKY_TOP:     Color = Color(0.78, 0.80, 0.82)
const SKY_HORIZON: Color = Color(0.38, 0.41, 0.45)

# Tint applied to water texture — keeps the palette cohesive.
const OCEAN_TINT:  Color = Color(0.75, 0.88, 1.00, 1.0)
const WAVE_TINT:   Color = Color(0.18, 0.38, 0.62, 1.0)

# Horizon haze: ocean surface and distant waves fade toward this grey.
const OCEAN_HORIZON_BLEND: float = 0.65  # max blend toward SKY_HORIZON at waterline
const WAVE_HORIZON_BLEND: float  = 0.55  # max blend for waves at spawn distance
const WAVE_FADE_DIST: float      = 0.25  # t_progress fraction where fade reaches zero

# Foam band that slides down the wave from t=0.5 to impact
const FOAM_START_T: float      = 0.75
const FOAM_HEIGHT_FRAC: float  = 0.25   # foam band height as fraction of wave height
const N_FOAM_STRIPS: int       = 32
const FOAM_JITTER_FREQ: float  = 8.5    # horizontal oscillations across wave width
const FOAM_JITTER_FREQ2: float = 19.0   # second frequency layered in for irregularity
const FOAM_JITTER_SPEED: float = 5.5    # animation speed
const FOAM_JITTER_AMP: float   = 0.42   # fraction of foam_h for top-edge wobble
const FOAM_COL: Color          = Color(0.96, 0.98, 1.00, 0.92)
const FOAM_SHADOW_COL: Color   = Color(0.04, 0.07, 0.14, 0.60)
const FOAM_SHADOW_FRAC: float  = 0.20   # dark gradient height below foam band

# Wave texture jitter
const WAVE_JITTER_AMP: float   = 0.06   # horizontal wobble
const WAVE_JITTER_V_AMP: float = 0.8    # vertical wobble (ripple)
const WAVE_JITTER_FREQ: float  = 3.0
const WAVE_JITTER_SPEED: float = 0.3

# Perspective floor strips — more = smoother curves near the horizon.
const N_STRIPS: int = 80
# Horizontal UV pan (in texture-widths). Negative = shift left.
const WATER_PAN_U: float    = -1.5
# >1 zooms out (shows more texture); 1.3 = 30% further out than physical.
const WATER_ZOOM: float     = 4.0
# X-axis jitter: sine wave varying per strip row, animated over time.
const WATER_JITTER_AMP: float   = 0.08   # UV units; tweak for more/less wobble
const WATER_JITTER_FREQ: float  = 6.0    # oscillations across the water height
const WATER_JITTER_SPEED: float = 0.4    # animation speed (UV units / s)

const _SPLASH_GRAVITY: float    = 900.0  # px/s² downward pull
const _SPLASH_FADE_RATE: float  = 0.65   # alpha units per second
const _SPLASH_COLOR: Color      = Color(0.96, 0.98, 1.00)

var _splash_blobs: Array = []

# Rain ripples on the calm water. Drawn under the waves (so a passing wave hides
# them), projected onto the water plane — bigger up close, smaller far off. Only
# a few at once and never far out. Spawned while the rainstick is equipped.
const _RIPPLE_LIFE: float         = 0.9    # seconds per ripple
const _RIPPLE_MAX_R: float        = 0.30   # world metres — fully expanded ring radius
const _RIPPLE_MIN_DIST: float     = 1.2    # metres ahead of the player
const _RIPPLE_MAX_DIST: float     = 6.0
# Vertical squash follows the viewing foreshortening (eye_y / dist), so far/small
# ripples read as thin flat ellipses and near ones are rounder.
const _RIPPLE_SQUASH_MIN: float   = 0.06   # farthest / flattest
const _RIPPLE_SQUASH_MAX: float   = 0.5    # nearest / roundest
const _RIPPLE_MAX_COUNT: int      = 7
const _RIPPLE_INTERVAL_MIN: float = 0.12
const _RIPPLE_INTERVAL_MAX: float = 0.40
const _RIPPLE_COLOR: Color        = Color(0.85, 0.92, 1.0)

var _ripples: Array = []
var _ripple_timer: float = 0.0

# SKY_HORIZON dimmed by the current distance-based darkening; the water haze and
# wave far-fade blend toward this so the horizon has no brightness seam.
var _horizon_col: Color = SKY_HORIZON

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	SignalBus.wave_hit.connect(_on_wave_hit_splash)

func _on_wave_hit_splash(wave_data: WaveData) -> void:
	var unsubmerged_h: float = GameManager.unsubmerged_height()
	if wave_data.height < 0.5 * unsubmerged_h:
		return
	var vp: Rect2  = get_viewport_rect()
	var vw: float  = vp.size.x
	var vh: float  = vp.size.y
	# norm_strength: 0 at the minimum threshold, 1 at 2× unsubmerged height.
	var norm: float = clampf((wave_data.height - 0.5 * unsubmerged_h) / (1.5 * unsubmerged_h), 0.0, 1.0)
	var n: int = int(randf_range(5.0, 10.0) + norm * 14.0)
	for i in range(n):
		var speed: float  = randf_range(200.0, 450.0) + norm * 500.0
		var spread: float = randf_range(-0.55, 0.55)
		_splash_blobs.append({
			"px":    vw * 0.5 + randf_range(-vw * 0.30, vw * 0.30),
			"py":    vh * randf_range(0.78, 0.96),
			"vx":    sin(spread) * speed,
			"vy":    -cos(spread) * speed,
			"r":     randf_range(7.0, 18.0) + norm * 10.0,
			"alpha": randf_range(0.65, 1.0),
		})

func _process(delta: float) -> void:
	var i: int = _splash_blobs.size() - 1
	while i >= 0:
		var b: Dictionary = _splash_blobs[i]
		b["vy"] += _SPLASH_GRAVITY * delta
		b["px"] += b["vx"] * delta
		b["py"] += b["vy"] * delta
		b["alpha"] -= _SPLASH_FADE_RATE * delta
		if b["alpha"] <= 0.0:
			_splash_blobs.remove_at(i)
		i -= 1
	_update_ripples(delta)
	queue_redraw()

func _draw() -> void:
	var vp: Rect2       = get_viewport_rect()
	var vw: float       = vp.size.x
	var vh: float       = vp.size.y
	var focal: float    = WavePhysics.focal_length(vh)
	var horizon_px: float = vh * WavePhysics.HORIZON_Y_FRAC
	var eye_y: float    = _eye_height()

	var sky_pts := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(vw, 0.0),
		Vector2(vw, horizon_px), Vector2(0.0, horizon_px),
	])
	# Sky dims by up to 30% as the player wades farther from shore. The water haze
	# and wave far-fade share the darkened horizon (_horizon_col) to avoid a seam.
	var sky_dark: float = 0.3 * clampf(GameManager.distance / GameManager.GOAL_DISTANCE, 0.0, 1.0)
	var sky_top: Color = SKY_TOP.darkened(sky_dark)
	_horizon_col = SKY_HORIZON.darkened(sky_dark)
	var sky_cols := PackedColorArray([sky_top, sky_top, _horizon_col, _horizon_col])
	draw_polygon(sky_pts, sky_cols)
	_draw_water_surface(vw, vh, horizon_px, eye_y)
	_draw_ripples(vw, focal, horizon_px, eye_y)

	var waves: Array = get_tree().get_nodes_in_group(&"waves")
	waves.sort_custom(func(a: Node, b: Node) -> bool:
		return a.dist_to_player() > b.dist_to_player()
	)
	for w in waves:
		_draw_wave(w, vw, vh, focal, horizon_px, eye_y)

	for b in _splash_blobs:
		draw_circle(Vector2(b["px"], b["py"]), b["r"],
			Color(_SPLASH_COLOR.r, _SPLASH_COLOR.g, _SPLASH_COLOR.b, b["alpha"]))

# ── Water surface ────────────────────────────────────────────────────────────

func _draw_water_surface(vw: float, vh: float, horizon_px: float, eye_y: float) -> void:
	var tex_size: float = float(_WATER_TEX.get_width())  # square texture
	var focal: float    = WavePhysics.focal_length(vh)
	var half_vw: float  = vw * 0.5
	var safe_eye: float = maxf(eye_y, 0.05)
	var time: float     = Time.get_ticks_msec() * 0.001

	# Depth-based warp: as water rises, near-horizon strips compress more.
	# compress_deep: how narrow top-of-water UV is at full submersion.
	var water_ratio: float = clamp(GameManager.water_level() / 1.7, 0.0, 1.0)

	for i in range(N_STRIPS):
		var t0: float = float(i)     / float(N_STRIPS)
		var t1: float = float(i + 1) / float(N_STRIPS)
		var y0: float = horizon_px + t0 * (vh - horizon_px)
		var y1: float = horizon_px + t1 * (vh - horizon_px)

		var py0: float   = maxf(y0 - horizon_px, 0.1)
		var py1: float   = maxf(y1 - horizon_px, 0.1)
		var dist0: float = safe_eye * focal / py0
		var dist1: float = safe_eye * focal / py1

		# Compress near-horizon strips more as player goes deeper.
		# factor = 1 at strip bottom, lerps down toward compress_deep at strip top.
		var compress_deep: float = lerpf(1.0, 0.15, water_ratio)
		var cf0: float = lerpf(compress_deep, 1.0, t0)
		var cf1: float = lerpf(compress_deep, 1.0, t1)

		# UV half-span with zoom and depth warp applied.
		var uh0: float = half_vw * dist0 / (focal * tex_size) * WATER_ZOOM * cf0
		var uh1: float = half_vw * dist1 / (focal * tex_size) * WATER_ZOOM * cf1
		var v0: float  = dist0 / tex_size
		var v1: float  = dist1 / tex_size

		# X-axis jitter: sine wave keyed to strip position + time.
		# Applied as a pan offset before the trapezoidal UV is laid out.
		var jitter0: float = sin(t0 * WATER_JITTER_FREQ + time * WATER_JITTER_SPEED) * WATER_JITTER_AMP
		var jitter1: float = sin(t1 * WATER_JITTER_FREQ + time * WATER_JITTER_SPEED) * WATER_JITTER_AMP
		var pan0: float = WATER_PAN_U + jitter0
		var pan1: float = WATER_PAN_U + jitter1

		var points := PackedVector2Array([
			Vector2(0.0, y0), Vector2(vw, y0),
			Vector2(vw,  y1), Vector2(0.0, y1),
		])
		var uvs := PackedVector2Array([
			Vector2(pan0 - uh0, v0), Vector2(pan0 + uh0, v0),
			Vector2(pan1 + uh1, v1), Vector2(pan1 - uh1, v1),
		])
		var h_top: float = (1.0 - t0) * (1.0 - t0) * OCEAN_HORIZON_BLEND
		var h_bot: float = (1.0 - t1) * (1.0 - t1) * OCEAN_HORIZON_BLEND
		var col_top: Color = OCEAN_TINT.lerp(_horizon_col, h_top)
		var col_bot: Color = OCEAN_TINT.lerp(_horizon_col, h_bot)
		var tint := PackedColorArray([col_top, col_top, col_bot, col_bot])
		draw_polygon(points, tint, uvs, _WATER_TEX)

# ── Waves ────────────────────────────────────────────────────────────────────

func _draw_wave(wave: Node, vw: float, vh: float, focal: float,
		horizon_px: float, eye_y: float) -> void:
	var dist: float  = wave.dist_to_player()
	if dist < 0.1:
		return

	var t: float     = wave.t_progress()   # cosmetics only: haze fade + foam timing
	var eff_h: float = wave.eff_height()

	var player_h: float = 1.0 if StaggerSystem.is_knocked_down else 2.0

	# Wave is a full-width wall on the waterline; both edges from one projection.
	# eff_h - water_level == wave.wave_data.height (crest above still water).
	var span: Vector2 = WavePhysics.wave_screen_span(
		eff_h - GameManager.water_level(), dist, eye_y, horizon_px, focal, vh)
	var screen_top: float = span.x
	var screen_bot: float = span.y

	if screen_top >= screen_bot:
		return

	var tex_size: float = float(_WATER_TEX.get_width())
	var wave_h: float   = screen_bot - screen_top
	var time: float     = Time.get_ticks_msec() * 0.001

	# UV span: full width at bottom, same at top (wave is a vertical slab).
	var u_span: float = vw / tex_size
	var v_span: float = wave_h / tex_size

	# UV jitter: horizontal (U) and vertical (V) components with different phases
	# to create a gentle undulating ripple rather than a lateral sweep.
	var ju_top: float = sin(0.0 * WAVE_JITTER_FREQ + time * WAVE_JITTER_SPEED) * WAVE_JITTER_AMP
	var ju_bot: float = sin(1.0 * WAVE_JITTER_FREQ + time * WAVE_JITTER_SPEED) * WAVE_JITTER_AMP
	var jv_top: float = sin(0.0 * WAVE_JITTER_FREQ + time * WAVE_JITTER_SPEED + 1.57) * WAVE_JITTER_V_AMP
	var jv_bot: float = sin(1.0 * WAVE_JITTER_FREQ + time * WAVE_JITTER_SPEED + 1.57) * WAVE_JITTER_V_AMP

	var dist_fade: float  = clampf(t / WAVE_FADE_DIST, 0.0, 1.0)
	var far_blend: float  = (1.0 - dist_fade) * WAVE_HORIZON_BLEND
	var faded_dark: Color = WAVE_TINT.lerp(_horizon_col, far_blend)
	var faded_lite: Color = Color(1.0, 1.0, 1.0, 1.0).lerp(_horizon_col, far_blend)
	var wave_type: int = WavePhysics.wave_category(eff_h, player_h)
	# Short: transparent crest → opaque dark base filling to screen bottom (darkening effect).
	# Medium: dark crest → blue-grey base.
	# Tall: dark crest → white foam base, with animated foam band on top.
	var short_top := Color(faded_dark.r, faded_dark.g, faded_dark.b, 0.0)
	var medium_bot: Color = faded_dark.lerp(faded_lite, 0.40)
	var tint: PackedColorArray
	match wave_type:
		2:  tint = PackedColorArray([faded_dark, faded_dark, faded_lite,  faded_lite])
		1:  tint = PackedColorArray([faded_dark, faded_dark, medium_bot,  medium_bot])
		_:  tint = PackedColorArray([short_top,  short_top,  faded_dark,  faded_dark])
	var points := PackedVector2Array([
		Vector2(0.0, screen_top), Vector2(vw, screen_top),
		Vector2(vw,  screen_bot), Vector2(0.0, screen_bot),
	])
	var uvs := PackedVector2Array([
		Vector2(ju_top,          jv_top),
		Vector2(ju_top + u_span, jv_top),
		Vector2(ju_bot + u_span, jv_bot + v_span),
		Vector2(ju_bot,          jv_bot + v_span),
	])
	draw_polygon(points, tint, uvs, _WATER_TEX)
	if wave_type == 2:
		_draw_wave_foam(screen_top, screen_bot, vw, t, time)

func _draw_wave_foam(screen_top: float, screen_bot: float, vw: float,
		t: float, time: float) -> void:
	if t < FOAM_START_T:
		return
	var foam_t: float  = (t - FOAM_START_T) / (1.0 - FOAM_START_T)  # 0→1
	var alpha: float   = clampf(foam_t * 4.0, 0.0, 1.0)             # quick fade-in

	var wave_h: float  = screen_bot - screen_top
	var foam_h: float  = wave_h * FOAM_HEIGHT_FRAC
	# Band top slides from screen_top (foam_t=0) down to screen_bot−foam_h (foam_t=1)
	var band_top: float = screen_top + (foam_t * foam_t * foam_t * foam_t * foam_t * foam_t) * (wave_h - foam_h)
	var band_bot: float = band_top + foam_h

	# Dark shadow gradient below the foam band — drawn first so foam sits on top
	var shadow_bot: float = minf(band_bot + wave_h * FOAM_SHADOW_FRAC, screen_bot)
	var col_dark  := Color(FOAM_SHADOW_COL.r, FOAM_SHADOW_COL.g, FOAM_SHADOW_COL.b, FOAM_SHADOW_COL.a * alpha)
	var col_dtrans := Color(FOAM_SHADOW_COL.r, FOAM_SHADOW_COL.g, FOAM_SHADOW_COL.b, 0.0)
	draw_polygon(
		PackedVector2Array([Vector2(0.0, band_bot), Vector2(vw, band_bot),
							Vector2(vw, shadow_bot), Vector2(0.0, shadow_bot)]),
		PackedColorArray([col_dark, col_dark, col_dtrans, col_dtrans]))

	# Foam strips: transparent at straight top, opaque at the squiggly bottom edge
	for i in range(N_FOAM_STRIPS):
		var cx0: float = float(i)     / float(N_FOAM_STRIPS)
		var cx1: float = float(i + 1) / float(N_FOAM_STRIPS)
		var jb0: float = (sin(cx0 * FOAM_JITTER_FREQ  + time * FOAM_JITTER_SPEED) * 0.58 +
						  sin(cx0 * FOAM_JITTER_FREQ2  + time * FOAM_JITTER_SPEED * 1.5 + 1.1) * 0.42
						 ) * foam_h * FOAM_JITTER_AMP
		var jb1: float = (sin(cx1 * FOAM_JITTER_FREQ  + time * FOAM_JITTER_SPEED) * 0.58 +
						  sin(cx1 * FOAM_JITTER_FREQ2  + time * FOAM_JITTER_SPEED * 1.5 + 1.1) * 0.42
						 ) * foam_h * FOAM_JITTER_AMP
		var pts := PackedVector2Array([
			Vector2(vw * cx0, band_top),           Vector2(vw * cx1, band_top),
			Vector2(vw * cx1, band_bot + jb1),     Vector2(vw * cx0, band_bot + jb0),
		])
		var col_edge := Color(FOAM_COL.r, FOAM_COL.g, FOAM_COL.b, 0.0)
		var col_body := Color(FOAM_COL.r, FOAM_COL.g, FOAM_COL.b, FOAM_COL.a * alpha)
		draw_polygon(pts, PackedColorArray([col_edge, col_edge, col_body, col_body]))

# ── Rain ripples ───────────────────────────────────────────────────────────────

func _update_ripples(delta: float) -> void:
	if GameManager.is_playing and ItemManager.is_enabled(&"rainstick"):
		_ripple_timer -= delta
		if _ripple_timer <= 0.0:
			_ripple_timer = randf_range(_RIPPLE_INTERVAL_MIN, _RIPPLE_INTERVAL_MAX)
			if _ripples.size() < _RIPPLE_MAX_COUNT:
				var d: float = randf_range(_RIPPLE_MIN_DIST, _RIPPLE_MAX_DIST)
				_ripples.append({ "dist": d, "lateral": randf_range(-0.8, 0.8) * d, "age": 0.0 })
	var i: int = _ripples.size() - 1
	while i >= 0:
		_ripples[i]["age"] += delta
		if _ripples[i]["age"] >= _RIPPLE_LIFE:
			_ripples.remove_at(i)
		i -= 1

func _draw_ripples(vw: float, focal: float, horizon_px: float, eye_y: float) -> void:
	for r: Dictionary in _ripples:
		var dist: float     = r["dist"]
		var age_frac: float = r["age"] / _RIPPLE_LIFE
		var sy: float = WavePhysics.project_screen_y(0.0, dist, eye_y, horizon_px, focal)
		var sx: float = vw * 0.5 + (r["lateral"] / dist) * focal
		var screen_r: float = (_RIPPLE_MAX_R * age_frac) * focal / dist
		# Quick fade-in, then out across its life.
		var alpha: float = (1.0 - age_frac) * clampf(age_frac * 5.0, 0.0, 1.0) * 0.55
		if screen_r < 0.5 or alpha <= 0.01:
			continue
		var width: float = maxf(screen_r * 0.08, 1.0)
		var squash: float = clampf(eye_y / dist, _RIPPLE_SQUASH_MIN, _RIPPLE_SQUASH_MAX)
		var col := Color(_RIPPLE_COLOR.r, _RIPPLE_COLOR.g, _RIPPLE_COLOR.b, alpha)
		draw_set_transform(Vector2(sx, sy), 0.0, Vector2(1.0, squash))
		draw_arc(Vector2.ZERO, screen_r, 0.0, TAU, 20, col, width, true)
		var inner_r: float = screen_r * 0.55
		if inner_r > 0.5:
			var inner_col := Color(_RIPPLE_COLOR.r, _RIPPLE_COLOR.g, _RIPPLE_COLOR.b, alpha * 0.55)
			draw_arc(Vector2.ZERO, inner_r, 0.0, TAU, 16, inner_col, maxf(width * 0.7, 1.0), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _eye_height() -> float:
	var cam_y: float = 0.85 if StaggerSystem.is_knocked_down else 1.7
	return WavePhysics.eye_height_above_water(cam_y, GameManager.water_level())
