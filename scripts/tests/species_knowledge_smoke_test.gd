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
	_test_goose_legacy_progression()
	_test_gremlin_familiar_progression()
	_test_snapshot_and_save_bridge()
	_test_codex_rows()
	_finish()


func _test_goose_legacy_progression() -> void:
	species_knowledge.call("reset_species", "goose")
	var first: Dictionary = species_knowledge.call(
		"add_discovery",
		"goose",
		"walking_gait",
		"Walking gait",
		2
	)
	_expect(bool(first.get("new_discovery", false)), "First Goose observation records")
	var duplicate: Dictionary = species_knowledge.call(
		"add_discovery",
		"goose",
		"walking_gait",
		"Walking gait",
		2
	)
	_expect(not bool(duplicate.get("new_discovery", true)), "Duplicate Goose observation does not farm knowledge")
	species_knowledge.call("add_discovery", "goose", "preferred_food", "Preferred food", 2)
	_expect(int(species_knowledge.call("get_rank", "goose")) >= 1, "Goose knowledge rank increases")
	_expect(bool(species_knowledge.call("has_unlock", "goose", "goose_familiar")), "Legacy Goose familiar unlock remains available")


func _test_gremlin_familiar_progression() -> void:
	species_knowledge.call("reset_species", "gremlin")
	species_knowledge.call("add_discovery", "gremlin", "first_encounter", "First encounter", 1)
	species_knowledge.call("add_discovery", "gremlin", "survived_pounce", "Survived Pounce", 1)
	_expect(bool(species_knowledge.call("has_unlock", "gremlin", "gremlin_familiar")), "Two Gremlin insights unlock the familiar")
	var default_loadout: Dictionary = species_knowledge.call("get_familiar_loadout", "gremlin") as Dictionary
	_expect(str(default_loadout.get("role", "")) == "skirmisher", "Gremlin familiar begins as Skirmisher")
	_expect((default_loadout.get("technique_ids", []) as Array).has("bite"), "Gremlin familiar begins with Bite")
	var equip_result: Dictionary = species_knowledge.call("set_equipped_familiar_species", "gremlin") as Dictionary
	_expect(bool(equip_result.get("ok", false)), "Unlocked Gremlin familiar can be equipped")
	species_knowledge.call("add_discovery", "gremlin", "witnessed_backstep", "Witnessed Backstep", 1)
	species_knowledge.call("add_discovery", "gremlin", "pack_coordination", "Pack Coordination", 2)
	_expect(bool(species_knowledge.call("has_unlock", "gremlin", "gremlin_pounce")), "Pack study unlocks Pounce")
	var pounce_result: Dictionary = species_knowledge.call("toggle_familiar_technique", "gremlin", "pounce") as Dictionary
	_expect(bool(pounce_result.get("ok", false)), "Unlocked Pounce can be equipped")
	species_knowledge.call("add_discovery", "gremlin", "conduct_susceptibility", "Conduct Susceptibility", 4)
	_expect(bool(species_knowledge.call("has_unlock", "gremlin", "gremlin_mire_spit")), "Conduct study unlocks Mire Spit")
	var role_result: Dictionary = species_knowledge.call("cycle_familiar_role", "gremlin", 1) as Dictionary
	_expect(bool(role_result.get("ok", false)), "Familiar role cycles")
	_expect(str((role_result.get("loadout", {}) as Dictionary).get("role", "")) == "primer", "Gremlin role cycles to Primer")


func _test_snapshot_and_save_bridge() -> void:
	var learned_snapshot: Dictionary = species_knowledge.call("get_snapshot") as Dictionary
	_expect(learned_snapshot.get("familiar_loadouts", null) is Dictionary, "Species snapshot includes familiar loadouts")
	_expect(str(learned_snapshot.get("equipped_familiar_species_id", "")) == "gremlin", "Species snapshot includes equipped familiar")
	species_knowledge.call("reset_all")
	_expect(int(species_knowledge.call("get_rank", "gremlin")) == 0, "Reset clears Gremlin study progress")
	species_knowledge.call("apply_snapshot", learned_snapshot)
	var restored_loadout: Dictionary = species_knowledge.call("get_familiar_loadout", "gremlin") as Dictionary
	_expect(str(restored_loadout.get("role", "")) == "primer", "Snapshot restores familiar role")
	_expect((restored_loadout.get("technique_ids", []) as Array).has("pounce"), "Snapshot restores familiar techniques")
	_expect(str(species_knowledge.call("get_equipped_familiar_species_id")) == "gremlin", "Snapshot restores equipped familiar")
	_expect(GameState.has_method("_append_player_records_to_save"), "GameState exposes player-record save bridge")
	_expect(GameState.has_method("_apply_player_records_from_save"), "GameState exposes player-record load bridge")
	if not GameState.has_method("_append_player_records_to_save") or not GameState.has_method("_apply_player_records_from_save"):
		return
	var save_probe: Dictionary = {"version": 11}
	GameState.call("_append_player_records_to_save", save_probe)
	_expect(int(save_probe.get("version", 0)) >= 13, "Save bridge advances records version")
	var saved_knowledge: Dictionary = save_probe.get("species_knowledge", {}) as Dictionary
	_expect(saved_knowledge.get("familiar_loadouts", null) is Dictionary, "Save bridge writes familiar loadouts inside species knowledge")
	species_knowledge.call("reset_all")
	GameState.call("_apply_player_records_from_save", save_probe)
	_expect(str(species_knowledge.call("get_equipped_familiar_species_id")) == "gremlin", "Load bridge restores equipped familiar")
	GameState.call("_apply_player_records_from_save", {"version": 11})
	_expect(int(species_knowledge.call("get_rank", "gremlin")) == 0, "Older save begins without phantom Gremlin knowledge")
	species_knowledge.call("apply_snapshot", learned_snapshot)


func _test_codex_rows() -> void:
	var rows: Array = species_knowledge.call("get_all_species_rows", true) as Array
	_expect(rows.size() >= 2, "Codex exposes Goose and Gremlin rows")
	var found_goose: bool = false
	var found_gremlin: bool = false
	for row_value: Variant in rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value as Dictionary
		if str(row.get("id", "")) == "goose":
			found_goose = true
		if str(row.get("id", "")) == "gremlin":
			found_gremlin = true
			_expect(bool(row.get("has_familiar", false)), "Gremlin Codex row advertises familiar mastery")
	_expect(found_goose, "Codex keeps Goose row")
	_expect(found_gremlin, "Codex adds Gremlin row")
	var familiar_rows: Array = species_knowledge.call("get_familiar_rows") as Array
	_expect(familiar_rows.size() == 1, "Familiar menu exposes one implemented creature blueprint")
	var summary: Dictionary = species_knowledge.call("get_summary") as Dictionary
	_expect(int(summary.get("species_total", 0)) >= 2, "Summary counts registered species")
	_expect(int(summary.get("familiars_available", 0)) == 1, "Summary counts implemented familiar blueprints")


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
		push_error("SPECIES KNOWLEDGE SMOKE TEST FAILED: " + ", ".join(failures))
		get_tree().quit(1)
