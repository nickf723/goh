extends Node

var failures: Array[String] = []


func _ready() -> void:
	SpeciesKnowledge.reset_species("goose")
	var first: Dictionary = SpeciesKnowledge.add_discovery("goose", "walking_gait", "Walking gait", 2)
	_expect(bool(first.get("new_discovery", false)), "First observation records")
	var duplicate: Dictionary = SpeciesKnowledge.add_discovery("goose", "walking_gait", "Walking gait", 2)
	_expect(not bool(duplicate.get("new_discovery", true)), "Duplicate observation does not farm knowledge")
	SpeciesKnowledge.add_discovery("goose", "preferred_food", "Preferred food", 2)
	_expect(SpeciesKnowledge.get_rank("goose") >= 1, "Knowledge rank increases")
	_expect(SpeciesKnowledge.has_unlock("goose", "goose_familiar"), "Goose familiar unlock is earned")
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
