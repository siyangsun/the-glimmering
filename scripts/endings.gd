class_name Endings
extends RefCounted

# Surreal closing lines shown beneath the ending message, chosen from run context.
# Returns "" when there's no epitaph for the situation.

static func epitaph_for(ending: StringName) -> String:
	if ending != &"drown":
		return ""
	# Pocket stones take priority over the deep-water line.
	if ItemManager.is_enabled(&"pocketstones"):
		return "If anybody could have saved me it would have been you.\n- Virginia Woolf"
	if GameManager.distance > 80.0:
		return "He was swimming in a sea of other people's expectations. Men had drowned in seas like that.\n― Robert Jordan"
	return ""
