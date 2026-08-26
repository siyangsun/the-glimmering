class_name StateMachine
extends Node

# Lightweight FSM. Usage:
#
#   var fsm := StateMachine.new()
#   fsm.add_state(&"idle",   _enter_idle,   _exit_idle,   _update_idle)
#   fsm.add_state(&"attack", _enter_attack, _exit_attack, _update_attack)
#   add_child(fsm)
#   fsm.transition_to(&"idle")
#
# In _process: fsm.update(delta)   (or call it from wherever fits your loop)

signal state_changed(from: StringName, to: StringName)

var current: StringName = &""

var _states: Dictionary = {}  # StringName -> {enter, exit, update}


func add_state(
	name: StringName,
	enter_fn: Callable = func() -> void: pass,
	exit_fn: Callable = func() -> void: pass,
	update_fn: Callable = func(_d: float) -> void: pass,
) -> void:
	_states[name] = { "enter": enter_fn, "exit": exit_fn, "update": update_fn }


func transition_to(new_state: StringName) -> void:
	assert(_states.has(new_state), "StateMachine: unknown state '%s'" % new_state)
	if current == new_state:
		return
	var previous: StringName = current
	if current != &"" and _states.has(current):
		_states[current]["exit"].call()
	current = new_state
	_states[new_state]["enter"].call()
	state_changed.emit(previous, new_state)


func update(delta: float) -> void:
	if current != &"" and _states.has(current):
		_states[current]["update"].call(delta)


func is_state(name: StringName) -> bool:
	return current == name
