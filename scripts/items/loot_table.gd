extends Resource
class_name LootTable

@export var display_name: String = "Loot Table"
@export_range(0, 12, 1) var rolls: int = 1
@export var entries: Array[Resource] = []
@export var allow_duplicate_rolls: bool = true


func roll_loot(random: RandomNumberGenerator = null) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = random
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var totals: Dictionary = {}
	for entry_resource: Resource in entries:
		var entry: LootEntry = entry_resource as LootEntry
		if entry == null or not entry.is_valid() or not entry.guaranteed:
			continue
		if rng.randf() <= clampf(entry.drop_chance, 0.0, 1.0):
			add_result(totals, entry.item_definition, entry.roll_quantity(rng))

	var candidates: Array[LootEntry] = get_weighted_candidates()
	for _roll_index: int in range(maxi(rolls, 0)):
		if candidates.is_empty():
			break
		var chosen: LootEntry = choose_weighted_entry(candidates, rng)
		if chosen == null:
			break
		if rng.randf() <= clampf(chosen.drop_chance, 0.0, 1.0):
			add_result(totals, chosen.item_definition, chosen.roll_quantity(rng))
		if not allow_duplicate_rolls:
			candidates.erase(chosen)

	var results: Array[Dictionary] = []
	for item_id_variant: Variant in totals.keys():
		var result: Dictionary = totals[item_id_variant] as Dictionary
		results.append(result.duplicate(true))
	return results


func get_weighted_candidates() -> Array[LootEntry]:
	var candidates: Array[LootEntry] = []
	for entry_resource: Resource in entries:
		var entry: LootEntry = entry_resource as LootEntry
		if entry != null and entry.is_valid() and not entry.guaranteed and entry.weight > 0.0:
			candidates.append(entry)
	return candidates


func choose_weighted_entry(candidates: Array[LootEntry], random: RandomNumberGenerator) -> LootEntry:
	var total_weight: float = 0.0
	for entry: LootEntry in candidates:
		total_weight += maxf(entry.weight, 0.0)
	if total_weight <= 0.0:
		return null

	var cursor: float = random.randf_range(0.0, total_weight)
	for entry: LootEntry in candidates:
		cursor -= maxf(entry.weight, 0.0)
		if cursor <= 0.0:
			return entry
	return candidates.back()


func add_result(totals: Dictionary, item: QuickItemDefinition, quantity: int) -> void:
	if item == null or item.item_id == "" or quantity <= 0:
		return
	var existing: Dictionary = totals.get(item.item_id, {
		"item_definition": item,
		"item_id": item.item_id,
		"quantity": 0,
	})
	existing["quantity"] = int(existing.get("quantity", 0)) + quantity
	totals[item.item_id] = existing


func get_debug_summary() -> Dictionary:
	var entry_summaries: Array[String] = []
	for entry_resource: Resource in entries:
		var entry: LootEntry = entry_resource as LootEntry
		if entry != null:
			entry_summaries.append(entry.get_debug_summary())
	return {
		"name": display_name,
		"rolls": rolls,
		"allow_duplicates": allow_duplicate_rolls,
		"entries": entry_summaries,
	}
