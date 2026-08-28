extends Node

signal wave_hit(wave_data: WaveData)
signal impairment_changed(type: StringName, is_impaired: bool)
signal action_performed(action: StringName)
signal game_ended(ending: StringName)
signal game_reset
signal knocked_down
signal stood_up
signal item_collected(id: StringName)
