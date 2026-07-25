extends Node

signal effects_changed
signal effect_source_changed(source_id: String, effect_ids: Array[String])
signal effect_pulsed(source_id: String, effect_id: String, operation: String, amount: int)

const EffectCatalogScript = preload("res://scripts/effects/gameplay_effect_catalog.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")

var effect_sources: Dictionary = {}


func _ready() -> void:
	if not GameState.equipment_changed.is_connected(_on_equipment_changed):
		GameState.equipment_changed.connect(_on_equipment_changed)
	if not GameState.rest_resources_restored.is_connected(_on_rest_or_defeat):
		GameState.rest_resources_restored.connect(_on_rest_or_defeat)
	if not GameState.player_defeated.is_connected(_on_rest_or_defeat):
		GameState.player_defeated.connect(_on_rest_or_defeat)
	sync_equipment_sources()


func _exit_tree() -> void:
	if GameState.equipment_changed.is_connected(_on_equipment_changed):
		GameState.equipment_changed.disconnect(_on_equipment_changed)
	if GameState.rest_resources_restored.is_connected(_on_rest_or_defeat):
		GameState.rest_resources_restored.disconnect(_on_rest_or_defeat)
	if GameState.player_defeated.is_connected(_on_rest_or_defeat):
		GameState.player_defeated.disconnect(_on_rest_or_defeat)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var expired_sources: Array[String] = []
	for source_variant: Variant in effect_sources.keys():
		var source_id: String = str(source_variant)
		if not effect_sources.has(source_id):
			continue
		var source: Dictionary = effect_sources[source_variant] as Dictionary
		source = process_source_pulses(source_id, source, delta)
		var remaining: float = float(source.get("remaining", -1.0))
		if remaining >= 0.0:
			remaining = maxf(remaining - delta, 0.0)
			source["remaining"] = remaining
			if remaining <= 0.0:
				expired_sources.append(source_id)
		if effect_sources.has(source_id):
			effect_sources[source_id] = source
	for source_id: String in expired_sources:
		remove_effect_source(source_id)


func process_source_pulses(source_id: String, source: Dictionary, delta: float) -> Dictionary:
	var pulse_timers: Dictionary = source.get("pulse_timers", {}) as Dictionary
	var effect_ids: Array = source.get("effect_ids", []) as Array
	for effect_variant: Variant in effect_ids:
		var effect_id: String = str(effect_variant)
		var definition: Dictionary = EffectCatalogScript.get_definition(effect_id)
		var pulse: Dictionary = definition.get("pulse", {}) as Dictionary
		if pulse.is_empty():
			continue
		var interval: float = maxf(float(pulse.get("interval", 1.0)), 0.05)
		var timer: float = float(pulse_timers.get(effect_id, interval)) - delta
		while timer <= 0.0:
			apply_effect_pulse(source_id, effect_id, pulse)
			timer += interval
			if not effect_sources.has(source_id):
				break
		pulse_timers[effect_id] = timer
	source["pulse_timers"] = pulse_timers
	return source


func apply_effect_pulse(source_id: String, effect_id: String, pulse: Dictionary) -> void:
	var operation: String = str(pulse.get("operation", ""))
	var amount: int = maxi(int(pulse.get("amount", 0)), 0)
	if amount <= 0:
		return
	match operation:
		"health_damage":
			GameState.take_damage(amount)
		"stamina_damage":
			GameState.spend_stamina(mini(amount, GameState.get_stat("stamina")))
		"mana_damage":
			GameState.spend_mana(mini(amount, GameState.get_stat("mana")))
		"health_restore":
			GameState.heal(amount)
		_:
			return
	effect_pulsed.emit(source_id, effect_id, operation, amount)

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
	var pulse_timers: Dictionary = {}
	if effect_sources.has(source_id):
		var existing_source: Dictionary = effect_sources[source_id] as Dictionary
		pulse_timers = (existing_source.get("pulse_timers", {}) as Dictionary).duplicate(true)
	effect_sources[source_id] = {
		"effect_ids": valid_ids,
		"remaining": duration,
		"duration": duration,
		"tags": tags.duplicate(),
		"pulse_timers": pulse_timers,
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


func has_effect_with_tag(tag: String) -> bool:
	for effect_id: String in get_active_effect_ids():
		var definition: Dictionary = EffectCatalogScript.get_definition(effect_id)
		var tags: Array = definition.get("tags", []) as Array
		if tags.has(tag):
			return true
	return false


func remove_effects_with_tag(tag: String) -> int:
	var source_ids: Array[String] = []
	for source_variant: Variant in effect_sources.keys():
		var source_id: String = str(source_variant)
		for effect_id: String in get_source_effect_ids(source_id):
			var definition: Dictionary = EffectCatalogScript.get_definition(effect_id)
			var tags: Array = definition.get("tags", []) as Array
			if tags.has(tag):
				source_ids.append(source_id)
				break
	for source_id: String in source_ids:
		remove_effect_source(source_id)
	return source_ids.size()


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
	rows.sort_custom(Callable(self, "sort_source_rows"))
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


func _on_rest_or_defeat() -> void:
	remove_sources_with_tag("consumable_buff")
	remove_effects_with_tag("harmful")
