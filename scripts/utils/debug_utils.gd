class_name DebugUtils
# Utilities for headless and editor debugging. Remove calls before shipping.


# Returns a Callable that prints elapsed time when called.
# Usage: var done := DebugUtils.timer("load cards"); ...; done.call()
static func timer(label: String) -> Callable:
	var start: int = Time.get_ticks_msec()
	return func() -> void:
		print("[%s] %.1fms" % [label, Time.get_ticks_msec() - start])


# Formats a dictionary of stats as a single readable line.
# DebugUtils.format_stats("unit", {hp=10, atk=3}) -> "[unit] hp=10, atk=3"
static func format_stats(label: String, stats: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in stats:
		parts.append("%s=%s" % [key, stats[key]])
	return "[%s] %s" % [label, ", ".join(parts)]


# Asserts that a signal has at least one connection. Useful in _ready() checks.
static func assert_connected(obj: Object, signal_name: StringName) -> void:
	assert(
		not obj.get_signal_connection_list(signal_name).is_empty(),
		"Expected signal '%s' on %s to have at least one connection" % [signal_name, obj]
	)


# Prints every connection on an object's signals — handy for debugging disconnect bugs.
static func dump_connections(obj: Object) -> void:
	for sig: Dictionary in obj.get_signal_list():
		var conns: Array = obj.get_signal_connection_list(sig["name"])
		if not conns.is_empty():
			print("[%s] signal '%s' -> %d connection(s)" % [obj, sig["name"], conns.size()])


# Runs fn N times and prints min/avg/max time in ms.
static func benchmark(label: String, fn: Callable, iterations: int = 100) -> void:
	var times: Array[float] = []
	for _i: int in iterations:
		var t: int = Time.get_ticks_usec()
		fn.call()
		times.append((Time.get_ticks_usec() - t) / 1000.0)
	times.sort()
	var avg: float = 0.0
	for t: float in times:
		avg += t
	avg /= times.size()
	print("[benchmark:%s] min=%.3fms avg=%.3fms max=%.3fms (n=%d)" % [
		label, times[0], avg, times[times.size() - 1], iterations
	])
