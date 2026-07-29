extends Node

var failures: Array[String] = []
var species_knowledge: Node
var original_snapshot: Dictionary = {}


func _ready() -> void:
	species_knowledge = get_node_or_null("/root/SpeciesKnowledge")
	_expect(species_knowledge != null, "SpeciesKnowledge autoload is available")
	if species_knowledge == null:
		_finish()
		return

	original_snapshot = species_knowledge.call("get_snapshot") as Dictionary
	species_knowledge.call("reset_species", "goose")

	var first: Dictionary = species_knowledge.call(
		"add_discovery",
		"goose",
		"walking_gait",
		"Walking gait",
		2
	)
	_expect(bool(first.get("new_discovery", false)), "First observation records")

	var duplicate: Dictionary = species_knowledge.call(
		"add_discovery",
		"goose",
		"walking_gait",
		"Walking gait",
		2
	)
	_expect(
		not bool(duplicate.get("new_discovery", true)),
		"Duplicate observation does not farm knowledge"
	)

	species_knowledge.call(
		"add_discovery",
		"goose",
		"preferred_food",
		"Preferred food",
		2
	)
	_expect(
		int(species_knowledge.call("get_rank", "goose")) >= 1,
		"Knowledge rank increases"
	)
	_expect(
		bool(species_knowledge.call("has_unlock", "goose", "goose_familiar")),
		"Goose familiar unlock is earned"
	)

	var learned_snapshot: Dictionary = species_knowledge.call("get_snapshot") as Dictionary
	_validate_game_state_bridge(learned_snapshot)

	species_knowledge.call("reset_all")
	_expect(
		int(species_knowledge.call("get_rank", "goose")) == 0,
		"Reset clears ranked study progress"
	)
	species_knowledge.call("apply_snapshot", learned_snapshot)
	var restored: Dictionary = species_knowledge.call("get_species_data", "goose") as Dictionary
	_expect(
		int(restored.get("points", 0)) == 4,
		"Snapshot restores knowledge points"
	)
	_expect(
		(restored.get("discoveries", {}) as Dictionary).size() == 2,
		"Snapshot restores unique discoveries"
	)
	_expect(
		bool(species_knowledge.call("has_unlock", "goose", "goose_familiar")),
		"Snapshot rebuilds earned unlocks"
	)

	var rows: Array = species_knowledge.call("get_all_species_rows") as Array
	_expect(rows.size() == 1, "Codex exposes one authored species row")
	if rows.size() == 1 and rows[0] is Dictionary:
		var goose_row: Dictionary = rows[0] as Dictionary
		_expect(bool(goose_row.get("observed", false)), "Codex row marks Goose observed")
		_expect(
			int(goose_row.get("discovery_count", 0)) == 2,
			"Codex row reports discovery count"
		)
		_expect(
			str(goose_row.get("next_unlock_label", "")) != "",
			"Codex row reports the next insight"
		)

	var summary: Dictionary = species_knowledge.call("get_summary") as Dictionary
	_expect(int(summary.get("species_observed", 0)) == 1, "Summary counts observed species")
	_expect(int(summary.get("observations", 0)) == 2, "Summary counts field notes")
	_finish()


func _validate_game_state_bridge(learned_snapshot: Dictionary) -> void:
	_expect(
		GameState.has_method("_append_player_records_to_save"),
		"GameState exposes the player-record save bridge"
	)
	_expect(
		GameState.has_method("_apply_player_records_from_save"),
		"GameState exposes the player-record load bridge"
	)
	if (
		not GameState.has_method("_append_player_records_to_save")
		or not GameState.has_method("_apply_player_records_from_save")
	):
		return

	var save_probe: Dictionary = {"version": 11}
	GameState.call("_append_player_records_to_save", save_probe)
	_expect(int(save_probe.get("version", 0)) == 12, "Save bridge advances records version")
	_expect(
		save_probe.get("species_knowledge", null) is Dictionary,
		"Save bridge writes species knowledge"
	)

	species_knowledge.call("reset_all")
	GameState.call("_apply_player_records_from_save", save_probe)
	var bridge_restored: Dictionary = (
		species_knowledge.call("get_species_data", "goose") as Dictionary
	)
	_expect(
		int(bridge_restored.get("points", 0)) == 4,
		"Load bridge restores species points"
	)
	_expect(
		(bridge_restored.get("discoveries", {}) as Dictionary).size() == 2,
		"Load bridge restores species discoveries"
	)

	GameState.call("_apply_player_records_from_save", {"version": 11})
	var legacy_reset: Dictionary = (
		species_knowledge.call("get_species_data", "goose") as Dictionary
	)
	_expect(
		int(legacy_reset.get("points", -1)) == 0,
		"Older save without records begins with empty study progress"
	)
	_expect(
		(legacy_reset.get("discoveries", {}) as Dictionary).is_empty(),
		"Older save without records has no phantom observations"
	)
	species_knowledge.call("apply_snapshot", learned_snapshot)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if species_knowledge != null and not original_snapshot.is_empty():
		species_knowledge.call("apply_snapshot", original_snapshot)
	if failures.is_empty():
		print("SPECIES KNOWLEDGE SMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		push_error(
			"SPECIES KNOWLEDGE SMOKE TEST FAILED: "
			+ ", ".join(failures)
		)
		get_tree().quit(1)
