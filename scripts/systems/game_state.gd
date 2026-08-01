extends "res://scripts/systems/game_state_core.gd"

# GameState keeps its original autoload path and UID. The mature state core lives
# in game_state_core.gd, while this integration layer owns cross-system records
# and semantic aliases that travel with the same save slot.
signal quick_spell_slot_changed(loadout_id: String, slot_index: int, spell_id: String)
signal quick_spell_selection_changed(loadout_id: String, slot_index: int)

const PLAYER_RECORDS_SAVE_VERSION: int = 14
const QUICK_SPELL_SLOT_COUNT: int = 10
const AchievementCatalogScript = preload(
	"res://scripts/progression/achievement_catalog.gd"
)
const AchievementServiceScript = preload(
	"res://scripts/progression/achievement_service.gd"
)
const SpellcastingMasteryServiceScript = preload(
	"res://scripts/progression/spellcasting_mastery_service.gd"
)
const ExtendedEquipmentCatalogScript = preload(
	"res://scripts/equipment/equipment_catalog.gd"
)

const STARTER_COMPONENT_EQUIPMENT: Dictionary = {
	"headwear": "journey_headwrap",
	"outfit": "journey_tunic",
	"gloves": "journey_wraps",
	"footwear": "trail_boots",
}

var quick_spell_loadouts: Dictionary = {}
var quick_spell_selected_slots: Dictionary = {}


func _ready() -> void:
	_ensure_component_equipment_slots()
	SpellcastingMasteryServiceScript.ensure_story_baseline()


func has_unlock(unlock_id: String) -> bool:
	if super.has_unlock(unlock_id):
		return true
	if AchievementCatalogScript.has_definition(unlock_id):
		return AchievementServiceScript.is_unlocked(unlock_id)
	return false


func equip_item(item_id: String) -> bool:
	_ensure_component_equipment_slots()
	return super.equip_item(item_id)


func unequip_slot(slot_id: String) -> bool:
	_ensure_component_equipment_slots()
	return super.unequip_slot(slot_id)


func reset_run() -> void:
	super.reset_run()
	_ensure_component_equipment_slots()
	quick_spell_loadouts.clear()
	quick_spell_selected_slots.clear()
	var species_knowledge: Node = _get_species_knowledge()
	if species_knowledge != null and species_knowledge.has_method("reset_all"):
		species_knowledge.call("reset_all")
	SpellcastingMasteryServiceScript.ensure_story_baseline()


func ensure_quick_spell_loadout(
	loadout_id: String,
	default_spell_ids: Array[String] = []
) -> Array[String]:
	var resolved_id: String = _normalize_loadout_id(loadout_id)
	if quick_spell_loadouts.has(resolved_id):
		return get_quick_spell_slots(resolved_id)
	var slots: Array[String] = []
	for slot_index: int in range(QUICK_SPELL_SLOT_COUNT):
		var spell_id: String = ""
		if slot_index < default_spell_ids.size():
			spell_id = default_spell_ids[slot_index].strip_edges()
		slots.append(spell_id)
	quick_spell_loadouts[resolved_id] = slots
	quick_spell_selected_slots[resolved_id] = 0
	return slots.duplicate()


func set_quick_spell_slot(
	loadout_id: String,
	slot_index: int,
	spell_id: String
) -> bool:
	if slot_index < 0 or slot_index >= QUICK_SPELL_SLOT_COUNT:
		return false
	var resolved_id: String = _normalize_loadout_id(loadout_id)
	var slots: Array[String] = ensure_quick_spell_loadout(resolved_id)
	slots[slot_index] = spell_id.strip_edges()
	quick_spell_loadouts[resolved_id] = slots
	quick_spell_slot_changed.emit(resolved_id, slot_index, slots[slot_index])
	return true


func set_quick_spell_slots(
	loadout_id: String,
	spell_ids: Array[String]
) -> void:
	var resolved_id: String = _normalize_loadout_id(loadout_id)
	var slots: Array[String] = []
	for slot_index: int in range(QUICK_SPELL_SLOT_COUNT):
		var spell_id: String = ""
		if slot_index < spell_ids.size():
			spell_id = spell_ids[slot_index].strip_edges()
		slots.append(spell_id)
	quick_spell_loadouts[resolved_id] = slots
	for slot_index: int in range(slots.size()):
		quick_spell_slot_changed.emit(resolved_id, slot_index, slots[slot_index])


func get_quick_spell_slot(loadout_id: String, slot_index: int) -> String:
	if slot_index < 0 or slot_index >= QUICK_SPELL_SLOT_COUNT:
		return ""
	var slots: Array[String] = get_quick_spell_slots(loadout_id)
	return slots[slot_index] if slot_index < slots.size() else ""


func get_quick_spell_slots(loadout_id: String) -> Array[String]:
	var resolved_id: String = _normalize_loadout_id(loadout_id)
	var slots: Array[String] = []
	var stored_value: Variant = quick_spell_loadouts.get(resolved_id, [])
	if stored_value is Array:
		for value: Variant in stored_value as Array:
			slots.append(str(value))
	while slots.size() < QUICK_SPELL_SLOT_COUNT:
		slots.append("")
	if slots.size() > QUICK_SPELL_SLOT_COUNT:
		slots.resize(QUICK_SPELL_SLOT_COUNT)
	return slots


func set_selected_quick_spell_slot(loadout_id: String, slot_index: int) -> int:
	var resolved_id: String = _normalize_loadout_id(loadout_id)
	var resolved_slot: int = clampi(slot_index, 0, QUICK_SPELL_SLOT_COUNT - 1)
	quick_spell_selected_slots[resolved_id] = resolved_slot
	quick_spell_selection_changed.emit(resolved_id, resolved_slot)
	return resolved_slot


func get_selected_quick_spell_slot(loadout_id: String) -> int:
	var resolved_id: String = _normalize_loadout_id(loadout_id)
	return clampi(
		int(quick_spell_selected_slots.get(resolved_id, 0)),
		0,
		QUICK_SPELL_SLOT_COUNT - 1
	)


func get_quick_spell_loadouts_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for loadout_value: Variant in quick_spell_loadouts.keys():
		var loadout_id: String = str(loadout_value)
		snapshot[loadout_id] = get_quick_spell_slots(loadout_id)
	return snapshot


func get_quick_spell_selected_slots_snapshot() -> Dictionary:
	return quick_spell_selected_slots.duplicate(true)


func write_save_data(save_data: Dictionary) -> Dictionary:
	_append_player_records_to_save(save_data)
	return super.write_save_data(save_data)


func apply_save_data(save_data: Dictionary) -> bool:
	if save_data.is_empty():
		return false
	_apply_player_records_from_save(save_data)
	var applied: bool = super.apply_save_data(save_data)
	if applied:
		_ensure_component_equipment_slots()
		SpellcastingMasteryServiceScript.ensure_story_baseline()
	return applied


func _append_player_records_to_save(save_data: Dictionary) -> void:
	_ensure_component_equipment_slots()
	save_data["version"] = maxi(
		int(save_data.get("version", 0)),
		PLAYER_RECORDS_SAVE_VERSION
	)
	save_data["quick_spell_loadouts"] = get_quick_spell_loadouts_snapshot()
	save_data["quick_spell_selected_slots"] = (
		get_quick_spell_selected_slots_snapshot()
	)
	var species_knowledge: Node = _get_species_knowledge()
	if species_knowledge == null or not species_knowledge.has_method("get_snapshot"):
		return
	var snapshot: Variant = species_knowledge.call("get_snapshot")
	if snapshot is Dictionary:
		save_data["species_knowledge"] = (snapshot as Dictionary).duplicate(true)


func _apply_player_records_from_save(save_data: Dictionary) -> void:
	_apply_quick_spell_records(save_data)
	var species_knowledge: Node = _get_species_knowledge()
	if species_knowledge == null:
		return
	var snapshot: Variant = save_data.get("species_knowledge", {})
	if snapshot is Dictionary and not (snapshot as Dictionary).is_empty():
		if species_knowledge.has_method("apply_snapshot"):
			species_knowledge.call("apply_snapshot", snapshot)
			return
	if species_knowledge.has_method("reset_all"):
		species_knowledge.call("reset_all")


func _apply_quick_spell_records(save_data: Dictionary) -> void:
	quick_spell_loadouts.clear()
	quick_spell_selected_slots.clear()
	var loadouts_value: Variant = save_data.get("quick_spell_loadouts", {})
	if loadouts_value is Dictionary:
		for loadout_value: Variant in (loadouts_value as Dictionary).keys():
			var loadout_id: String = _normalize_loadout_id(str(loadout_value))
			var slots_value: Variant = (loadouts_value as Dictionary)[loadout_value]
			var slots: Array[String] = []
			if slots_value is Array:
				for spell_value: Variant in slots_value as Array:
					slots.append(str(spell_value))
			set_quick_spell_slots(loadout_id, slots)
	var selected_value: Variant = save_data.get("quick_spell_selected_slots", {})
	if selected_value is Dictionary:
		for loadout_value: Variant in (selected_value as Dictionary).keys():
			set_selected_quick_spell_slot(
				str(loadout_value),
				int((selected_value as Dictionary)[loadout_value])
			)


func _ensure_component_equipment_slots() -> void:
	for slot_id: String in ExtendedEquipmentCatalogScript.SLOT_ORDER:
		if not equipped_items.has(slot_id):
			equipped_items[slot_id] = ""
	for slot_value: Variant in STARTER_COMPONENT_EQUIPMENT.keys():
		var slot_id: String = str(slot_value)
		var item_id: String = str(STARTER_COMPONENT_EQUIPMENT[slot_value])
		if not ExtendedEquipmentCatalogScript.has_item(item_id):
			continue
		if not bool(owned_equipment.get(item_id, false)):
			owned_equipment[item_id] = true
			equipment_owned_changed.emit(item_id, true)
		if str(equipped_items.get(slot_id, "")) == "":
			equipped_items[slot_id] = item_id
			equipment_changed.emit(slot_id, item_id)


func _normalize_loadout_id(loadout_id: String) -> String:
	var resolved: String = loadout_id.strip_edges()
	return resolved if resolved != "" else "default"


func _get_species_knowledge() -> Node:
	return get_node_or_null("/root/SpeciesKnowledge")
