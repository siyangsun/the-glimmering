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
## `hand`, or `handend` while the left mouse button is held.
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
	&"fists":        "res://assets/sprites/twofists.png",
	&"fists2":       "res://assets/sprites/twofists2.png",
	&"fists3":       "res://assets/sprites/twofists3.png",
	&"pinch":        "res://assets/sprites/pinch.png",
	&"pinch2":       "res://assets/sprites/pinch2.png",
	&"smack":        "res://assets/sprites/smack.png",
	&"smack2":       "res://assets/sprites/smack2.png",
	&"drownedhand":  "res://assets/sprites/drownedhand.png",
	&"drownedhand2": "res://assets/sprites/drownedhand2.png",
	&"handend":      "res://assets/sprites/handend.png",
}

# cursor name -> hotspot in that sprite's own (unscaled) pixels
const _HOTSPOTS: Dictionary = {
	&"hand":        Vector2(3, 3),
	&"handclosed":  Vector2(3, 3),
	&"handclosed2": Vector2(3, 3),
	&"reach":       Vector2(32, 3),
	&"fists":        Vector2(32, 3),
	&"fists2":       Vector2(32, 3),
	&"fists3":       Vector2(32, 3),
	&"pinch":        Vector2(3, 3),
	&"pinch2":       Vector2(3, 3),
	&"smack":        Vector2(4, 4),
	&"smack2":       Vector2(4, 4),
	&"drownedhand":  Vector2(3, 3),
	&"drownedhand2": Vector2(3, 3),
	&"handend":      Vector2(3, 3),
}

var _textures: Dictionary = {}
var _requests: Dictionary = {}   # id: StringName -> { cursor: StringName, priority: int, flip_h: bool }
var _sprite: Sprite2D
var _active: StringName = &""
var _active_flip: bool = false
var _drowned: bool = false

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
	SignalBus.game_ended.connect(_on_game_ended)
	SignalBus.game_reset.connect(_on_game_reset)
	_apply()

func _on_game_ended(ending: StringName) -> void:
	if ending == &"drown":
		_drowned = true
	_active = &""
	_apply()

func _on_game_reset() -> void:
	_drowned = false
	_active = &""
	_apply()

## Register (or update) a cursor request under `id`. Higher priority wins.
func request(id: StringName, cursor: StringName, priority: int = 10, flip_h: bool = false) -> void:
	var existing: Dictionary = _requests.get(id, {})
	if existing.get("cursor") == cursor and existing.get("priority") == priority and existing.get("flip_h") == flip_h:
		return
	_requests[id] = { "cursor": cursor, "priority": priority, "flip_h": flip_h }
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
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_apply()

func _process(_delta: float) -> void:
	_apply()
	_place(get_viewport().get_mouse_position())

func _place(mouse_pos: Vector2) -> void:
	var hotspot: Vector2 = _HOTSPOTS.get(_active, Vector2.ZERO)
	if _active_flip and _active in _textures:
		hotspot.x = (_textures[_active] as Texture2D).get_width() - hotspot.x
	_sprite.position = mouse_pos - hotspot * CURSOR_SCALE

func _apply() -> void:
	var want: StringName = _resolve()
	var want_flip: bool = _resolve_flip()
	if want == _active and want_flip == _active_flip:
		return
	_active = want
	_active_flip = want_flip
	_sprite.flip_h = want_flip
	_sprite.texture = _textures[want]

func _resolve() -> StringName:
	if _drowned:
		return &"drownedhand2" if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else &"drownedhand"
	var best: StringName = &""
	var best_pri: int = -1
	for id: StringName in _requests:
		var r: Dictionary = _requests[id]
		if r["priority"] > best_pri:
			best_pri = r["priority"]
			best = r["cursor"]
	if best != &"":
		return best
	return &"handend" if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else &"hand"

func _resolve_flip() -> bool:
	if _drowned:
		return false
	var best_pri: int = -1
	var best_flip: bool = false
	for id: StringName in _requests:
		var r: Dictionary = _requests[id]
		if r["priority"] > best_pri:
			best_pri = r["priority"]
			best_flip = r.get("flip_h", false)
	return best_flip
