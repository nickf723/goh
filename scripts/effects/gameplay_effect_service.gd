extends Node

signal effects_changed
signal effect_source_changed(source_id: String, effect_ids: Array[String])

const EffectCatalogScript = preload("res://scripts/effects/gameplay_effect_catalog.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")

var effect_sources: Dictionary = {}


func _ready() -> void:
	if not GameState.equipment_changed.is_connected(_on_equipment_changed):
		GameState.equipment_changed.connect(_on_equipment_changed)
	sync_equipment_sources()


func _exit_tree() -> void:
	if GameState.equipment_changed.is_connected(_on_equipment_changed):
		GameState.equipment_changed.disconnect(_on_equipment_changed)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var expired_sources: Array[String] = []
	for source_variant: Variant in effect_sources.keys():
		var source_id: String = str(source_variant)
		var source: Dictionary = effect_sources[source_variant] as Dictionary
		var remaining: float = float(source.get("remaining", -1.0))
		if remaining < 0.0:
			continue
		remaining = maxf(remaining - delta, 0.0)
		source["remaining"] = remaining
		effect_sources[source_variant] = source
		if remaining <= 0.0:
			expired_sources.append(source_id)
	for source_id: String in expired_sources:
		remove_effect_source(source_id)


func set_effect_source(source_id: String, effect_ids: Array[String], duration: float = -1.0, tags: Array[String] = []) -> void:
	if source_id == "":
		return
	var valid_ids: Array[String] = []
	for effect_id: String in effect_ids:
		if EffectCatalogScript.has_effect(effect_id) and not valid_ids.has(effect_id):
			valid_ids.append(effect_id)
	if valid_ids.is_empty():
		remove_effect_source(source_id)
		return
	effect_sources[source_id] = {
		"effect_ids": valid_ids,
		"remaining": duration,
		"duration": duration,
		"tags": tags.duplicate(),
	}
	effect_source_changed.emit(source_id, valid_ids.duplicate())
	effects_changed.emit()


func add_effect(source_id: String, effect_id: String, duration: float = -1.0, tags: Array[String] = []) -> void:
	var effect_ids: Array[String] = get_source_effect_ids(source_id)
	if not effect_ids.has(effect_id):
		effect_ids.append(effect_id)
	set_effect_source(source_id, effect_ids, duration, tags)


func remove_effect_source(source_id: String) -> void:
	if not effect_sources.has(source_id):
		return
	effect_sources.erase(source_id)
	var empty_effect_ids: Array[String] = []
	effect_source_changed.emit(source_id, empty_effect_ids)
	effects_changed.emit()


func remove_sources_with_tag(tag: String) -> void:
	var source_ids: Array[String] = []
	for source_variant: Variant in effect_sources.keys():
		var source: Dictionary = effect_sources[source_variant] as Dictionary
		var tags: Array = source.get("tags", []) as Array
		if tags.has(tag):
			source_ids.append(str(source_variant))
	for source_id: String in source_ids:
		remove_effect_source(source_id)


func get_source_effect_ids(source_id: String) -> Array[String]:
	var result: Array[String] = []
	if not effect_sources.has(source_id):
		return result
	var source: Dictionary = effect_sources[source_id] as Dictionary
	var ids: Array = source.get("effect_ids", []) as Array
	for id_variant: Variant in ids:
		result.append(str(id_variant))
	return result


func get_active_effect_ids() -> Array[String]:
	var result: Array[String] = []
	for source_variant: Variant in effect_sources.keys():
		for effect_id: String in get_source_effect_ids(str(source_variant)):
			result.append(effect_id)
	return result


func has_effect(effect_id: String) -> bool:
	return get_active_effect_ids().has(effect_id)


func get_channel_flat(channel_id: String) -> float:
	var total: float = 0.0
	for effect_id: String in get_active_effect_ids():
		var modifier: Dictionary = EffectCatalogScript.get_channel_modifier(effect_id, channel_id)
		total += float(modifier.get("add", 0.0))
	return total


func get_channel_multiplier(channel_id: String) -> float:
	var multiplier: float = 1.0
	for effect_id: String in get_active_effect_ids():
		var modifier: Dictionary = EffectCatalogScript.get_channel_modifier(effect_id, channel_id)
		multiplier *= float(modifier.get("multiply", 1.0))
	return multiplier


func modify_float(channel_id: String, base_value: float) -> float:
	return (base_value + get_channel_flat(channel_id)) * get_channel_multiplier(channel_id)


func modify_int(channel_id: String, base_value: int, rounding_mode: String = "round") -> int:
	var modified: float = modify_float(channel_id, float(base_value))
	match rounding_mode:
		"ceil":
			return ceili(modified)
		"floor":
			return floori(modified)
		_:
			return roundi(modified)


func get_active_effect_rows() -> Array[Dictionary]:
	return EffectCatalogScript.get_effect_rows(get_active_effect_ids())


func get_active_source_rows(include_permanent: bool = true) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for source_variant: Variant in effect_sources.keys():
		var source_id: String = str(source_variant)
		var source: Dictionary = effect_sources[source_variant] as Dictionary
		var remaining: float = float(source.get("remaining", -1.0))
		if not include_permanent and remaining < 0.0:
			continue
		for effect_id: String in get_source_effect_ids(source_id):
			var row: Dictionary = EffectCatalogScript.get_definition(effect_id)
			if row.is_empty():
				continue
			row["source_id"] = source_id
			row["remaining"] = remaining
			row["duration"] = float(source.get("duration", remaining))
			row["tags"] = (source.get("tags", []) as Array).duplicate()
			rows.append(row)
	rows.sort_custom(sort_source_rows)
	return rows


func sort_source_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_remaining: float = float(a.get("remaining", -1.0))
	var b_remaining: float = float(b.get("remaining", -1.0))
	if is_equal_approx(a_remaining, b_remaining):
		return str(a.get("name", "")) < str(b.get("name", ""))
	if a_remaining < 0.0:
		return false
	if b_remaining < 0.0:
		return true
	return a_remaining < b_remaining




func sync_equipment_sources() -> void:
	for slot_id: String in EquipmentCatalogScript.SLOT_ORDER:
		sync_equipment_slot(slot_id, GameState.get_equipped_item(slot_id))


func sync_equipment_slot(slot_id: String, item_id: String) -> void:
	var source_id: String = "equipment:" + slot_id
	var source_tags: Array[String] = ["equipment", slot_id]
	set_effect_source(source_id, EquipmentCatalogScript.get_effect_ids(item_id), -1.0, source_tags)


func _on_equipment_changed(slot_id: String, item_id: String) -> void:
	sync_equipment_slot(slot_id, item_id)
