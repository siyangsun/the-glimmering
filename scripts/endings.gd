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

# Headline shown on the end screen; shifts with how often you've been here.
# Counts already include the run that just ended.
static func message_for(ending: StringName) -> String:
	var n: int = int(GameManager.ending_counts.get(ending, 1))
	match ending:
		&"drown":
			return "you drowned..." if GameManager.ending_streak >= 2 else "you drowned."
		&"still":
			return "the sea did not mind." if n < 2 else "the sea still does not mind."
		_:
			if n >= 3:
				return "you remember this place."
			return "you have arrived. again." if n == 2 else "you have arrived."
