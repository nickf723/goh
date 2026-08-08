extends RefCounted
class_name FocusGridLayout

const ELEMENT_COLUMNS: int = 4
const ELEMENT_ROWS: int = 4

# Clockwise compass ring around the 3x3 center cell (index 4).
# 0 1 2
# 3 4 5
# 6 7 8
const SPELL_RING_SLOTS: Array[int] = [1, 2, 5, 8, 7, 6, 3, 0]
const SPELL_SLOT_LAYOUTS: Dictionary = {
	0: [],
	1: [1],
	2: [3, 5],
	3: [1, 8, 6],
	4: [1, 5, 7, 3],
	5: [1, 5, 8, 6, 3],
	6: [1, 2, 5, 7, 6, 3],
	7: [1, 2, 5, 8, 7, 6, 3],
	8: [0, 1, 2, 5, 8, 7, 6, 3],
}


static func move_element_index(
	current_index: int,
	delta_x: int,
	delta_y: int,
	element_count: int = 16
) -> int:
	if element_count <= 0:
		return 0
	var safe_index: int = clampi(current_index, 0, element_count - 1)
	var row: int = int(floor(float(safe_index) / float(ELEMENT_COLUMNS)))
	var column: int = safe_index % ELEMENT_COLUMNS
	column = wrapi(column + signi(delta_x), 0, ELEMENT_COLUMNS)
	row = wrapi(row + signi(delta_y), 0, ELEMENT_ROWS)
	var candidate: int = row * ELEMENT_COLUMNS + column
	if candidate < element_count:
		return candidate

	# The production grid has exactly sixteen elements, but keep partial grids
	# safe for tests and future alternate spellbooks.
	for step: int in range(1, ELEMENT_COLUMNS * ELEMENT_ROWS + 1):
		candidate = posmod(candidate + step, ELEMENT_COLUMNS * ELEMENT_ROWS)
		if candidate < element_count:
			return candidate
	return safe_index


static func get_spell_slots(spell_count: int) -> Array[int]:
	var count: int = clampi(spell_count, 0, 8)
	var raw: Variant = SPELL_SLOT_LAYOUTS.get(count, [])
	var result: Array[int] = []
	if raw is Array:
		for value: Variant in raw as Array:
			result.append(int(value))
	return result


static func get_spell_slot(spell_index: int, spell_count: int) -> int:
	var slots: Array[int] = get_spell_slots(spell_count)
	if spell_index < 0 or spell_index >= slots.size():
		return -1
	return slots[spell_index]


static func find_directional_spell_index(
	current_index: int,
	spell_count: int,
	delta_x: int,
	delta_y: int
) -> int:
	var count: int = clampi(spell_count, 0, 8)
	if count <= 1 or (delta_x == 0 and delta_y == 0):
		return clampi(current_index, 0, maxi(count - 1, 0))

	var slots: Array[int] = get_spell_slots(count)
	var safe_index: int = clampi(current_index, 0, count - 1)
	var origin: Vector2i = slot_to_coord(slots[safe_index])
	var direction := Vector2i(signi(delta_x), signi(delta_y))
	var best_index: int = safe_index
	var best_score: float = INF

	for candidate_index: int in range(count):
		if candidate_index == safe_index:
			continue
		var candidate: Vector2i = slot_to_coord(slots[candidate_index])
		var offset: Vector2i = candidate - origin
		var projection: int = offset.x * direction.x + offset.y * direction.y
		if projection <= 0:
			continue
		var perpendicular: int = abs(offset.x * direction.y - offset.y * direction.x)
		var distance_sq: int = offset.x * offset.x + offset.y * offset.y
		var score: float = float(perpendicular) * 10.0 + float(distance_sq) - float(projection) * 0.1
		if score < best_score:
			best_score = score
			best_index = candidate_index
	return best_index


static func slot_to_coord(slot_index: int) -> Vector2i:
	var safe_slot: int = clampi(slot_index, 0, 8)
	return Vector2i(safe_slot % 3, int(floor(float(safe_slot) / 3.0)))


static func get_debug_layout(spell_count: int) -> Dictionary:
	return {
		"element_columns": ELEMENT_COLUMNS,
		"element_rows": ELEMENT_ROWS,
		"spell_slots": get_spell_slots(spell_count),
		"center_slot": 4,
	}
