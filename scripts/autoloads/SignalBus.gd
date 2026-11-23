extends Node

signal wave_hit(wave_data: WaveData)
signal impairment_changed(type: StringName, is_impaired: bool)
signal action_performed(action: StringName)            # a face region was clicked
signal action_held_changed(action: StringName, held: bool)   # mouse held down on a region
signal action_hovered(action: StringName, over: bool)        # cursor entered/left a region
signal game_ended(ending: StringName)
signal game_reset
