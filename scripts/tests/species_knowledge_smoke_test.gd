extends Node

var failures: Array[String] = []
var species_knowledge: Node


func _ready() -> void:
	species_knowledge = get_node_or_null("/root/SpeciesKnowledge")
	_expect(species_knowledge != null, "SpeciesKnowledge autoload is available")
	if species_knowledge == null:
		_finish()
		return
	species_knowledge.call("reset_species", "goose")
	var first: Dictionary = species_knowledge.call("add_discovery", "goose", "walking_gait", "Walking gait", 2)
	_expect(bool(first.get("new_discovery", false)), "First observation records")
	var duplicate: Dictionary = species_knowledge.call("add_discovery", "goose", "walking_gait", "Walking gait", 2)
	_expect(not bool(duplicate.get("new_discovery", true)), "Duplicate observation does not farm knowledge")
	species_knowledge.call("add_discovery", "goose", "preferred_food", "Preferred food", 2)
	_expect(int(species_knowledge.call("get_rank", "goose")) >= 1, "Knowledge rank increases")
	_expect(bool(species_knowledge.call("has_unlock", "goose", "goose_familiar")), "Goose familiar unlock is earned")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("SPECIES KNOWLEDGE SMOKE TEST PASSED")
	else:
		push_error("SPECIES KNOWLEDGE SMOKE TEST FAILED: " + ", ".join(failures))
