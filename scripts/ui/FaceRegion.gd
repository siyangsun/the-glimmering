extends RefCounted

## One clickable spot on the face (eyes, nose, an ear): config + live state.
## FaceWidget drives the animations. Hover and hold changes are broadcast on
## SignalBus, so the simulation reacts to them instead of the UI writing into it.

# ── Config (set once) ─────────────────────────────────────────────────────────
var cursor_id: StringName
var action: StringName
var hover_cursor: StringName
var flip_h: bool = false
var priority: int = 20
var click_frames: Array[StringName] = []
var click_times: Array[float] = []
var hold_frames: Array[StringName] = []
var hold_frame_time: float = 0.1
var release_frame: StringName
var release_time: float = 0.0
var particles: CPUParticles2D = null  # restarted on click (ears only)

# ── State ─────────────────────────────────────────────────────────────────────
var region: Rect2 = Rect2()
var anim: bool = false          # a click animation is playing
var loop_running: bool = false  # the hold-frame loop is running

var over: bool = false:
	set(value):
		if value == over:
			return
		over = value
		SignalBus.action_hovered.emit(action, value)

var held: bool = false:
	set(value):
		if value == held:
			return
		held = value
		SignalBus.action_held_changed.emit(action, value)

func _init(p_cursor_id: StringName, p_action: StringName, p_hover_cursor: StringName,
		p_flip_h: bool = false) -> void:
	cursor_id = p_cursor_id
	action = p_action
	hover_cursor = p_hover_cursor
	flip_h = p_flip_h
