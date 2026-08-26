class_name ArrayUtils


static func pick_random(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]


# Weighted random pick. weights must be same length as items, all >= 0.
static func weighted_pick(items: Array, weights: Array) -> Variant:
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return pick_random(items)
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for i: int in items.size():
		cumulative += float(weights[i])
		if roll <= cumulative:
			return items[i]
	return items.back()


# O(1) removal — swaps the element with the last, then pops. Doesn't preserve order.
static func remove_swap(arr: Array, index: int) -> void:
	arr[index] = arr[arr.size() - 1]
	arr.pop_back()


static func shuffle_copy(arr: Array) -> Array:
	var copy: Array = arr.duplicate()
	copy.shuffle()
	return copy


# Returns a new array with duplicates removed (preserves first occurrence order).
static func unique(arr: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for item in arr:
		if not seen.has(item):
			seen[item] = true
			result.append(item)
	return result


# Splits arr into chunks of at most chunk_size elements.
static func chunks(arr: Array, chunk_size: int) -> Array:
	var result: Array = []
	var i: int = 0
	while i < arr.size():
		result.append(arr.slice(i, i + chunk_size))
		i += chunk_size
	return result


# Returns the element with the highest score according to score_fn.
static func max_by(arr: Array, score_fn: Callable) -> Variant:
	if arr.is_empty():
		return null
	var best: Variant = arr[0]
	var best_score: float = float(score_fn.call(best))
	for i: int in range(1, arr.size()):
		var score: float = float(score_fn.call(arr[i]))
		if score > best_score:
			best_score = score
			best = arr[i]
	return best
