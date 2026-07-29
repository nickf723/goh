extends "res://scripts/systems/game_state_core.gd"

# GameState keeps its original autoload path and UID. The mature state core lives
# in game_state_core.gd, while this integration layer owns cross-system records
# and semantic aliases that travel with the same save slot.
const PLAYER_RECORDS_SAVE_VERSION: int = 12
const AchievementCatalogScript = preload(
	"res://scripts/progression/achievement_catalog.gd"
)
const AchievementServiceScript = preload(
	"res://scripts/progression/achievement_service.gd"
)
const SpellcastingMasteryServiceScript = preload(
	"res://scripts/progression/spellcasting_mastery_service.gd"
)


func _ready() -> void:
	SpellcastingMasteryServiceScript.ensure_story_baseline()


func has_unlock(unlock_id: String) -> bool:
	if super.has_unlock(unlock_id):
		return true
	if AchievementCatalogScript.has_definition(unlock_id):
		return AchievementServiceScript.is_unlocked(unlock_id)
	return false


func reset_run() -> void:
	super.reset_run()
	var species_knowledge: Node = _get_species_knowledge()
	if species_knowledge != null and species_knowledge.has_method("reset_all"):
		species_knowledge.call("reset_all")
	SpellcastingMasteryServiceScript.ensure_story_baseline()


func write_save_data(save_data: Dictionary) -> Dictionary:
	_append_player_records_to_save(save_data)
	return super.write_save_data(save_data)


func apply_save_data(save_data: Dictionary) -> bool:
	if save_data.is_empty():
		return false
	_apply_player_records_from_save(save_data)
	var applied: bool = super.apply_save_data(save_data)
	if applied:
		SpellcastingMasteryServiceScript.ensure_story_baseline()
	return applied


func _append_player_records_to_save(save_data: Dictionary) -> void:
	save_data["version"] = maxi(
		int(save_data.get("version", 0)),
		PLAYER_RECORDS_SAVE_VERSION
	)
	var species_knowledge: Node = _get_species_knowledge()
	if species_knowledge == null or not species_knowledge.has_method("get_snapshot"):
		return
	var snapshot: Variant = species_knowledge.call("get_snapshot")
	if snapshot is Dictionary:
		save_data["species_knowledge"] = (snapshot as Dictionary).duplicate(true)


func _apply_player_records_from_save(save_data: Dictionary) -> void:
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


func _get_species_knowledge() -> Node:
	return get_node_or_null("/root/SpeciesKnowledge")
