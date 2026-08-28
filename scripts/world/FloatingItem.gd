extends Node3D

const BOB_AMP: float    = 0.06
const BOB_FREQ: float   = 0.7
const HOVER_RADIUS: float = 48.0   # screen pixels

var item_id: StringName    = &""
var distance_from_shore: float = 0.0

var _bob_phase: float  = 0.0
var _collected: bool   = false
var _screen_pos: Vector2 = Vector2(-9999.0, -9999.0)
var _cursor_id: StringName = &""
var _visual: Node3D = null

func _ready() -> void:
	_bob_phase = randf() * TAU
	_cursor_id = StringName("item_" + str(item_id))
	_build_visual()

func _build_visual() -> void:
	var catalog: Dictionary = ItemManager.CATALOG
	if item_id in catalog:
		var tex_path: String = catalog[item_id]["sprite"]
		if ResourceLoader.exists(tex_path):
			var sprite := Sprite3D.new()
			sprite.texture = load(tex_path)
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.pixel_size = 0.012
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			add_child(sprite)
			_visual = sprite
			return
	# Fallback placeholder — large bright box so it's obvious in testing.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	_visual = mesh_inst

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_phase += delta * BOB_FREQ * TAU
	var water_y: float = (distance_from_shore / GameManager.GOAL_DISTANCE) * GameManager.WATER_LEVEL_MAX
	position.y = water_y + sin(_bob_phase) * BOB_AMP

	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam or cam.is_position_behind(global_position):
		CursorManager.release(_cursor_id)
		_screen_pos = Vector2(-9999.0, -9999.0)
		return

	_screen_pos = cam.unproject_position(global_position)
	var mouse: Vector2 = get_viewport().get_mouse_position()
	if mouse.distance_to(_screen_pos) <= HOVER_RADIUS:
		CursorManager.request(_cursor_id, &"reach", 15)
	else:
		CursorManager.release(_cursor_id)

func _input(event: InputEvent) -> void:
	if _collected:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if mb.position.distance_to(_screen_pos) <= HOVER_RADIUS:
		_collect()

func _collect() -> void:
	_collected = true
	CursorManager.release(_cursor_id)
	ItemManager.collect(item_id)
	AudioManager.play_stinger_good()
	if _visual:
		var tween := create_tween()
		tween.tween_property(self, "position:y", position.y + 0.4, 0.45).set_ease(Tween.EASE_OUT)
		if _visual is Sprite3D:
			tween.parallel().tween_property(_visual as Sprite3D, "modulate:a", 0.0, 0.35)
		tween.tween_callback(queue_free)
	else:
		queue_free()
