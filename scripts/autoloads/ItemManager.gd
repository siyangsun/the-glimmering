extends Node

const CATALOG: Dictionary = {
	&"goggles": {
		"name": "goggles",
		"description": "keeps the water out of your eyes.",
		"sprite": "res://assets/sprites/goggles.png",
	},
}

const SAVE_PATH: String = "user://lost_and_found.json"

var collected: Array[StringName] = []
var enabled:   Array[StringName] = []

func _ready() -> void:
	_load()

func is_collected(id: StringName) -> bool:
	return id in collected

func is_enabled(id: StringName) -> bool:
	return id in enabled

func collect(id: StringName) -> void:
	if not is_collected(id):
		collected.append(id)
		_save()
	SignalBus.item_collected.emit(id)

func set_enabled(id: StringName, state: bool) -> void:
	if state and not is_enabled(id):
		enabled.append(id)
	elif not state:
		enabled.erase(id)

func pick_for_spawn() -> StringName:
	# Prefer uncollected items; fall back to any catalog entry.
	# Only spawn items not already in the lost and found. Items flagged
	# "repeatable" in the catalog can still wash ashore after being collected.
	var pool: Array[StringName] = []
	for id: StringName in CATALOG:
		if not is_collected(id) or CATALOG[id].get("repeatable", false):
			pool.append(id)
	if pool.is_empty():
		return &""
	return pool[randi() % pool.size()]

func _save() -> void:
	var data: Dictionary = {
		"collected": collected.map(func(x: StringName) -> String: return str(x)),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if not result is Dictionary:
		return
	var data: Dictionary = result as Dictionary
	if data.has("collected"):
		for s: Variant in data["collected"]:
			var id: StringName = StringName(str(s))
			if id in CATALOG and not is_collected(id):
				collected.append(id)
