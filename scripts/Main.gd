extends Node

# ── Canvas layer stack (bottom → top) ──────────────────────────────────────────
# Every CanvasLayer.layer used in the game, in one place. The post-process at 8
# reads the screen below it, so anything under 8 is posterized into the world
# look; anything above 8 is drawn crisp on top. Layers marked (tscn) live in
# Main.tscn and are repeated here for reference only — keep the two in sync.
#
#   5   render        ocean, waves, floating items, paper boat   (tscn)
#   6   rain          rainstick streaks
#   8   post-process  posterize + dither; reads everything below (tscn)
#   9   blind         blindness darkening
#   10  eye           eye-splash droplets
#   11  goggle        goggle tint
#   12  flash         wave-hit white flash
#   13  ui            dev overlay, face widget                   (tscn)
#   14  drown         drowning tunnel vignette
#   15  top-posterize gentle second posterize over the vignette
#   20  debug         debug panel                                (tscn)
#   60  menu          title screen
#   61  lost-and-found lost-and-found screen, over the menu
#   128 cursor        software cursor                            (CursorManager)
const LAYER_RAIN: int            = 6
const LAYER_BLIND: int           = 9
const LAYER_EYE: int             = 10
const LAYER_GOGGLE: int          = 11
const LAYER_FLASH: int           = 12
const LAYER_DROWN: int           = 14
const LAYER_TOP_POSTERIZE: int   = 15
const LAYER_MENU: int            = 60
const LAYER_LOST_AND_FOUND: int  = 61

# ── Item spawning ─────────────────────────────────────────────────────────────
# Distances from shore at which items appear (ahead of the player by SPAWN_AHEAD).
const SPAWN_AHEAD: float = 14.0
var _spawn_distances: Array[float] = []
var _active_items: Array[Node] = []
var _paper_boat: Node2D = null

# ── Persistent UI ─────────────────────────────────────────────────────────────
var _flash_rect: ColorRect = null
var _goggle_tint: ColorRect = null
var _menu_layer: CanvasLayer = null

func _ready() -> void:
	_apply_font()
	_build_world()
	_build_vfx()
	SignalBus.game_ended.connect(_on_game_ended)
	SignalBus.wave_hit.connect(_on_wave_hit_flash)
	SignalBus.game_reset.connect(_on_game_reset)
	_show_menu()

func _process(_delta: float) -> void:
	if not GameManager.is_playing:
		return
	_update_item_spawns()
	_update_goggle_tint()
	_update_paper_boat()

# ── Goggle overlay ────────────────────────────────────────────────────────────

func _update_goggle_tint() -> void:
	if _goggle_tint:
		_goggle_tint.visible = ItemManager.is_enabled(&"goggles")

# ── Paper boat companion ───────────────────────────────────────────────────────

func _update_paper_boat() -> void:
	var want: bool = ItemManager.is_enabled(&"paperboat")
	var have: bool = _paper_boat != null and is_instance_valid(_paper_boat)
	if want and not have:
		_paper_boat = load("res://scripts/world/PaperBoat.gd").new()
		$RenderLayer.add_child(_paper_boat)
	elif not want and have:
		_paper_boat.queue_free()
		_paper_boat = null

# ── Item spawning ─────────────────────────────────────────────────────────────

func _generate_spawn_distances() -> void:
	_spawn_distances.clear()
	# Two items per run at random distances between 15 and 85 m.
	var positions: Array[float] = []
	while positions.size() < 2:
		var d: float = randf_range(15.0, 85.0)
		var ok: bool = true
		for p: float in positions:
			if absf(p - d) < 15.0:
				ok = false
				break
		if ok:
			positions.append(d)
	_spawn_distances = positions

func _update_item_spawns() -> void:
	var i: int = 0
	while i < _spawn_distances.size():
		if GameManager.distance + SPAWN_AHEAD >= _spawn_distances[i]:
			_spawn_item_at(_spawn_distances[i])
			_spawn_distances.remove_at(i)
		else:
			i += 1

func _spawn_item_at(shore_dist: float) -> void:
	var id: StringName = ItemManager.pick_for_spawn()
	if id == &"":
		return
	var item: Node2D = load("res://scripts/world/FloatingItem.gd").new()
	item.set("item_id", id)
	item.set("distance_from_shore", shore_dist)
	item.set("lateral", randf_range(-1.5, 1.5))
	# Draw on the ocean render layer, above WaveRenderer2D so it sits on the water.
	$RenderLayer.add_child(item)
	_active_items.append(item)

func _clear_items() -> void:
	for item: Node in _active_items:
		if is_instance_valid(item):
			item.queue_free()
	_active_items.clear()
	_spawn_distances.clear()
	if _paper_boat != null and is_instance_valid(_paper_boat):
		_paper_boat.queue_free()
		_paper_boat = null

# ── Menu ──────────────────────────────────────────────────────────────────────

func _show_menu(end_msg: String = "") -> void:
	if _menu_layer and is_instance_valid(_menu_layer):
		_menu_layer.queue_free()

	var font := _palatino()

	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = LAYER_MENU
	add_child(_menu_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.88)
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter  = Control.MOUSE_FILTER_STOP
	_menu_layer.add_child(bg)

	var center := Control.new()
	center.anchor_right  = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_menu_layer.add_child(center)

	var top_offset: float = 0.42
	if end_msg != "":
		var end_label := Label.new()
		end_label.text = end_msg
		end_label.anchor_left   = 0.5
		end_label.anchor_right  = 0.5
		end_label.anchor_top    = 0.32
		end_label.anchor_bottom = 0.32
		end_label.offset_left   = -200.0
		end_label.offset_right  =  200.0
		end_label.offset_top    = -20.0
		end_label.offset_bottom =  20.0
		end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		end_label.add_theme_font_override(&"font", font)
		end_label.add_theme_font_size_override(&"font_size", 26)
		center.add_child(end_label)
		top_offset = 0.48

	var btn_ocean := _make_menu_button("go to the ocean", font)
	btn_ocean.anchor_top    = top_offset
	btn_ocean.anchor_bottom = top_offset
	btn_ocean.offset_top    = -20.0
	btn_ocean.offset_bottom =  20.0
	btn_ocean.pressed.connect(_on_go_to_ocean)
	center.add_child(btn_ocean)

	var btn_laf := _make_menu_button("lost and found", font)
	btn_laf.anchor_top    = top_offset + 0.09
	btn_laf.anchor_bottom = top_offset + 0.09
	btn_laf.offset_top    = -20.0
	btn_laf.offset_bottom =  20.0
	btn_laf.pressed.connect(_show_lost_and_found)
	center.add_child(btn_laf)

func _on_go_to_ocean() -> void:
	if _menu_layer and is_instance_valid(_menu_layer):
		_menu_layer.queue_free()
		_menu_layer = null
	_clear_items()
	_generate_spawn_distances()
	DrownMeter.reset()
	StaggerSystem.reset()
	ImpairmentSystem.reset()
	AudioManager.reset()
	AudioManager.fade_out_elegy(0.5)
	GameManager.reset()

func _make_menu_button(txt: String, font: Font) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.anchor_left   = 0.5
	btn.anchor_right  = 0.5
	btn.add_theme_font_override(&"font", font)
	btn.add_theme_font_size_override(&"font_size", 20)
	btn.offset_left   = -120.0
	btn.offset_right  =  120.0
	return btn

# ── Lost and Found ────────────────────────────────────────────────────────────

func _show_lost_and_found() -> void:
	var font := _palatino()

	var laf_layer := CanvasLayer.new()
	laf_layer.layer = LAYER_LOST_AND_FOUND
	add_child(laf_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.96)
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter  = Control.MOUSE_FILTER_STOP
	laf_layer.add_child(bg)

	var root := Control.new()
	root.anchor_right  = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	laf_layer.add_child(root)

	var title := Label.new()
	title.text = "lost and found"
	title.anchor_left   = 0.5
	title.anchor_right  = 0.5
	title.anchor_top    = 0.12
	title.anchor_bottom = 0.12
	title.offset_left   = -200.0
	title.offset_right  =  200.0
	title.offset_top    = -20.0
	title.offset_bottom =  20.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override(&"font", font)
	title.add_theme_font_size_override(&"font_size", 28)
	root.add_child(title)

	var item_y: float = 0.26
	var has_items: bool = false

	for id: StringName in ItemManager.CATALOG:
		if not ItemManager.is_collected(id):
			continue
		has_items = true
		var entry := _build_laf_entry(id, font, item_y)
		root.add_child(entry)
		item_y += 0.14

	if not has_items:
		var empty := Label.new()
		empty.text = "nothing washed ashore yet."
		empty.anchor_left   = 0.5
		empty.anchor_right  = 0.5
		empty.anchor_top    = 0.45
		empty.anchor_bottom = 0.45
		empty.offset_left   = -200.0
		empty.offset_right  =  200.0
		empty.offset_top    = -16.0
		empty.offset_bottom =  16.0
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_override(&"font", font)
		empty.add_theme_font_size_override(&"font_size", 18)
		root.add_child(empty)

	var btn_back := _make_menu_button("back", font)
	btn_back.anchor_top    = 0.82
	btn_back.anchor_bottom = 0.82
	btn_back.offset_top    = -20.0
	btn_back.offset_bottom =  20.0
	btn_back.pressed.connect(laf_layer.queue_free)
	root.add_child(btn_back)

func _build_laf_entry(id: StringName, font: Font, anchor_top: float) -> Control:
	var catalog: Dictionary = ItemManager.CATALOG
	var info: Dictionary = catalog[id]
	var entry := Control.new()
	entry.anchor_left   = 0.5
	entry.anchor_right  = 0.5
	entry.anchor_top    = anchor_top
	entry.anchor_bottom = anchor_top
	entry.offset_left   = -220.0
	entry.offset_right  =  220.0
	entry.offset_top    = -30.0
	entry.offset_bottom =  30.0
	entry.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	# Item sprite — click to grab (equip); shows the handclosed grab cursor.
	var icon: TextureRect = null
	var tex_path: String = info["sprite"]
	if ResourceLoader.exists(tex_path):
		icon = TextureRect.new()
		icon.texture = load(tex_path)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.offset_left   = -220.0
		icon.offset_top    = -24.0
		icon.offset_right  = -160.0
		icon.offset_bottom =  24.0
		entry.add_child(icon)

	# Name + description
	var name_label := Label.new()
	name_label.text = info["name"]
	name_label.offset_left   = -148.0
	name_label.offset_top    = -28.0
	name_label.offset_right  =  140.0
	name_label.offset_bottom = -4.0
	name_label.add_theme_font_override(&"font", font)
	name_label.add_theme_font_size_override(&"font_size", 18)
	entry.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = info["description"]
	desc_label.offset_left   = -148.0
	desc_label.offset_top    =  0.0
	desc_label.offset_right  =  140.0
	desc_label.offset_bottom =  28.0
	desc_label.add_theme_font_override(&"font", font)
	desc_label.add_theme_font_size_override(&"font_size", 13)
	desc_label.modulate = Color(0.7, 0.7, 0.7)
	entry.add_child(desc_label)

	# Enable toggle
	var toggle := CheckBox.new()
	toggle.button_pressed = ItemManager.is_enabled(id)
	toggle.offset_left   =  148.0
	toggle.offset_top    = -16.0
	toggle.offset_right  =  220.0
	toggle.offset_bottom =  16.0
	toggle.add_theme_font_override(&"font", font)
	toggle.toggled.connect(func(on: bool) -> void: ItemManager.set_enabled(id, on))
	entry.add_child(toggle)

	# Click the sprite to equip it — plain default cursor (hand / handend), no grab.
	if icon:
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.gui_input.connect(func(event: InputEvent) -> void:
			if not event is InputEventMouseButton:
				return
			var mb := event as InputEventMouseButton
			if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
				return
			var new_state: bool = not ItemManager.is_enabled(id)
			ItemManager.set_enabled(id, new_state)
			toggle.set_pressed_no_signal(new_state))

	return entry

# ── Game lifecycle ────────────────────────────────────────────────────────────

func _on_game_ended(ending: StringName) -> void:
	_clear_items()
	await get_tree().create_timer(1.8).timeout
	var msg: String = "you drowned." if ending == &"drown" else "you have arrived."
	if ending == &"drown":
		AudioManager.play_elegy_loop()
	_show_menu(msg)

func _on_game_reset() -> void:
	pass  # item spawning is re-seeded in _on_go_to_ocean

# ── VFX & world ───────────────────────────────────────────────────────────────

func _on_wave_hit_flash(wave_data: WaveData) -> void:
	var eff_h: float = WavePhysics.effective_height(wave_data.height, GameManager.water_level())
	var player_h: float = 1.0 if StaggerSystem.is_knocked_down else 2.0
	if WavePhysics.wave_category(eff_h, player_h) < 2:
		return
	if not _flash_rect:
		return
	_flash_rect.size = get_viewport().get_visible_rect().size
	_flash_rect.color.a = 0.88
	var tween := create_tween()
	tween.tween_property(_flash_rect, "color:a", 0.0, 0.45)

func _build_vfx() -> void:
	# Rainstick rain — above the ocean, below the post-process shader so the
	# streaks get posterized into the world look. Toggles itself on the item.
	var rain_layer := CanvasLayer.new()
	rain_layer.layer = LAYER_RAIN
	add_child(rain_layer)
	var rain := CPUParticles2D.new()
	rain.set_script(preload("res://scripts/ui/RainEffect.gd"))
	rain_layer.add_child(rain)

	# Drowning tunnel vignette — above the post-process shader (layer 8) and the
	# other overlays, so it's a crisp tunnel laid over the finished image.
	var drown_layer := CanvasLayer.new()
	drown_layer.layer = LAYER_DROWN
	add_child(drown_layer)
	var drown_rect := ColorRect.new()
	drown_rect.set_script(preload("res://scripts/ui/DrownVignette.gd"))
	drown_layer.add_child(drown_rect)

	# A gentle second posterize pass over the vignette — far fewer bands than the
	# main post-process, just enough to give the smooth tunnel a little grain.
	var top_pp_layer := CanvasLayer.new()
	top_pp_layer.layer = LAYER_TOP_POSTERIZE
	add_child(top_pp_layer)
	var top_pp_rect := ColorRect.new()
	top_pp_rect.set_script(preload("res://scripts/rendering/PostProcess.gd"))
	var top_pp_mat := ShaderMaterial.new()
	top_pp_mat.shader = preload("res://assets/shaders/post_process.gdshader")
	top_pp_mat.set_shader_parameter(&"posterize_levels", 24.0)
	top_pp_mat.set_shader_parameter(&"dither_strength", 0.03)
	top_pp_rect.material = top_pp_mat
	top_pp_layer.add_child(top_pp_rect)

	var eye_layer := CanvasLayer.new()
	eye_layer.layer = LAYER_EYE
	add_child(eye_layer)
	var eye_rect := ColorRect.new()
	eye_rect.set_script(preload("res://scripts/ui/EyeEffect.gd"))
	eye_layer.add_child(eye_rect)

	var blind_layer := CanvasLayer.new()
	blind_layer.layer = LAYER_BLIND
	add_child(blind_layer)
	var blind_rect := ColorRect.new()
	blind_rect.set_script(preload("res://scripts/ui/BlindOverlay.gd"))
	blind_layer.add_child(blind_rect)

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = LAYER_FLASH
	add_child(flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(0.92, 0.94, 0.97, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(_flash_rect)

	# Goggle tint — teal overlay, visible only when goggles are enabled.
	var goggle_layer := CanvasLayer.new()
	goggle_layer.layer = LAYER_GOGGLE
	add_child(goggle_layer)
	_goggle_tint = ColorRect.new()
	_goggle_tint.color = Color(0.08, 0.52, 0.70, 0.5)
	_goggle_tint.anchor_right  = 1.0
	_goggle_tint.anchor_bottom = 1.0
	_goggle_tint.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_goggle_tint.visible = false
	goggle_layer.add_child(_goggle_tint)

func _apply_font() -> void:
	var font := _palatino()
	await get_tree().process_frame
	_set_font_recursive(get_tree().root, font)

func _set_font_recursive(node: Node, font: Font) -> void:
	if node is Label:
		(node as Label).add_theme_font_override(&"font", font)
	for child in node.get_children():
		_set_font_recursive(child, font)

func _palatino() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Palatino Linotype"])
	return font

func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.55, 0.60)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.55, 0.60)
	env.ambient_light_energy = 0.8
	env_node.environment = env
	add_child(env_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -20.0, 0.0)
	light.light_color = Color(0.82, 0.85, 0.90)
	light.light_energy = 0.5
	light.shadow_enabled = false
	add_child(light)
