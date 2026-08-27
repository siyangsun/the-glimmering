extends Node

## Single owner of the mouse cursor. Software cursor: the OS pointer is hidden and
## a sprite is drawn following the mouse on its own CanvasLayer above everything.
## Platform-agnostic (identical on Windows and macOS), and gives free scaling and
## animated cursors.
##
##     CursorManager.request(&"face_eyes", &"reach", 20)
##     CursorManager.release(&"face_eyes")
##
## The highest-priority active request wins. With no requests the cursor is
## `hand`, or `handclosed` while the left mouse button is held.
##
## KNOWN LIMITATION: while the OS cursor is hidden it is also invisible over the
## window title bar and outside the window. To be handled later.

const CURSOR_SCALE: float = 4.0  # the pixel-art sprites are small at native size

# cursor name -> source sprite
const _SPRITES: Dictionary = {
	&"hand":        "res://assets/sprites/hand.png",
	&"handclosed":  "res://assets/sprites/handclosed.png",
	&"handclosed2": "res://assets/sprites/handclosed2.png",
	&"reach":       "res://assets/sprites/twohands.png",
	&"fists":       "res://assets/sprites/twofists.png",
	&"fists2":      "res://assets/sprites/twofists2.png",
}

# cursor name -> hotspot in that sprite's own (unscaled) pixels
const _HOTSPOTS: Dictionary = {
	&"hand":        Vector2(3, 3),
	&"handclosed":  Vector2(3, 3),
	&"handclosed2": Vector2(3, 3),
	&"reach":       Vector2(32, 3),
	&"fists":       Vector2(32, 3),
	&"fists2":      Vector2(32, 3),
}

const SQUEEZE_2_TIME: float = 0.09  # how long handclosed2 is shown

var _textures: Dictionary = {}
var _requests: Dictionary = {}   # id: StringName -> { cursor: StringName, priority: int }
var _sprite: Sprite2D
var _active: StringName = &""
var _squeeze_anim: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000  # after everything else, so we read the final mouse pos

	for name: StringName in _SPRITES:
		_textures[name] = load(_SPRITES[name])

	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	# Sprite2D (not a Control) — always draws at native size * scale, so swapping
	# a narrow cursor for a wide one never stretches anything.
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(CURSOR_SCALE, CURSOR_SCALE)
	layer.add_child(_sprite)

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_apply()

## Register (or update) a cursor request under `id`. Higher priority wins.
func request(id: StringName, cursor: StringName, priority: int = 10) -> void:
	var existing: Dictionary = _requests.get(id, {})
	if existing.get("cursor") == cursor and existing.get("priority") == priority:
		return
	_requests[id] = { "cursor": cursor, "priority": priority }
	_apply()

## Drop the request registered under `id`.
func release(id: StringName) -> void:
	if _requests.erase(id):
		_apply()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_place((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not _squeeze_anim and _requests.is_empty():
			_squeeze()
		else:
			_apply()  # hand <-> handclosed

func _process(_delta: float) -> void:
	_apply()
	_place(get_viewport().get_mouse_position())

func _place(mouse_pos: Vector2) -> void:
	var hotspot: Vector2 = _HOTSPOTS.get(_active, Vector2.ZERO)
	_sprite.position = mouse_pos - hotspot * CURSOR_SCALE

func _apply() -> void:
	if _squeeze_anim:
		return
	var want: StringName = _resolve()
	if want == _active:
		return
	_active = want
	_sprite.texture = _textures[want]

func _squeeze() -> void:
	_squeeze_anim = true
	_active = &"handclosed"
	_sprite.texture = _textures[&"handclosed"]
	await get_tree().create_timer(SQUEEZE_2_TIME).timeout
	_active = &"handclosed2"
	_sprite.texture = _textures[&"handclosed2"]
	await get_tree().create_timer(SQUEEZE_2_TIME).timeout
	_squeeze_anim = false
	_apply()

func _resolve() -> StringName:
	var best: StringName = &""
	var best_pri: int = -1
	for id: StringName in _requests:
		var r: Dictionary = _requests[id]
		if r["priority"] > best_pri:
			best_pri = r["priority"]
			best = r["cursor"]
	if best != &"":
		return best
	return &"handclosed" if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else &"hand"
