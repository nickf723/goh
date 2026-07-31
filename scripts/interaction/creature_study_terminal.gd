extends Area3D
class_name CreatureStudyTerminal

@export var species_id: String = "gremlin"
@export var discovery_id: String = "first_encounter"
@export var discovery_label: String = "First encounter"
@export_range(0, 10, 1) var knowledge_points: int = 1
@export var prompt_text: String = "Study creature evidence"
@export var objective_after: String = "Open the Magic tab to inspect Familiar Blueprints."


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("creature_study_terminal")
	_refresh_label()


func interact() -> Dictionary:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null or not service.has_method("add_discovery"):
		return {
			"message": "The field record cannot be opened.",
			"objective": "",
		}
	var result_value: Variant = service.call(
		"add_discovery",
		species_id,
		discovery_id,
		discovery_label,
		knowledge_points
	)
	var result: Dictionary = result_value as Dictionary if result_value is Dictionary else {}
	var was_new: bool = bool(result.get("new_discovery", false))
	var points: int = int(result.get("points", 0))
	var rank: int = int(result.get("rank", 0))
	return {
		"message": (
			("Discovery recorded: " + discovery_label + ". ")
			if was_new
			else "Already recorded: " + discovery_label + ". "
		) + species_id.capitalize() + " knowledge " + str(points) + " • rank " + str(rank) + ".",
		"objective": objective_after,
	}


func get_debug_data() -> Dictionary:
	return {
		"species_id": species_id,
		"discovery_id": discovery_id,
		"points": knowledge_points,
	}


func _refresh_label() -> void:
	var label: Label3D = get_node_or_null("Label3D") as Label3D
	if label != null:
		label.text = discovery_label.to_upper()
