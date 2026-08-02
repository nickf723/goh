extends Node

const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_progression_challenge_lab_v1.tscn"
)

const REWARD_IDS: Array[String] = [
	"charged_firebolt",
	"chain_lightning",
	"piercing_ice_lance",
	"alchemy_recipe_insight",
	"gremlin_pounce",
]

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var lab: Node = LabScene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(lab.has_method("reset_challenge_progress"), "lab exposes progression reset")
	assert_true(lab.has_method("complete_all_challenges"), "lab exposes complete-all testing")
	assert_true(lab.has_method("refill_lab_supplies"), "lab exposes supply refill")

	var debug: Dictionary = lab.call("get_debug_data") as Dictionary
	assert_equal(debug.get("challenge_stations"), 5, "lab contains five challenge stations")
	assert_equal(debug.get("console_count"), 4, "lab contains four entry consoles")
	assert_equal(debug.get("study_terminal_count"), 3, "Pack Scholar uses three study terminals")
	assert_true(bool(debug.get("has_cauldron", false)), "Kitchen Chemistry contains a real cauldron")
	assert_true(bool(debug.get("public_cauldron_class", false)), "public AlchemyCauldron script resolves")

	lab.call("reset_challenge_progress")
	for reward_id: String in REWARD_IDS:
		assert_true(not GameState.has_unlock(reward_id), "reset locks " + reward_id)

	var completed: Dictionary = lab.call("complete_all_challenges") as Dictionary
	assert_true(
		str(completed.get("message", "")).contains("All starter challenges completed"),
		"complete-all console reports success"
	)
	for reward_id: String in REWARD_IDS:
		assert_true(GameState.has_unlock(reward_id), "complete-all unlocks " + reward_id)

	var tracker: Node = get_node_or_null("/root/FullMenuDirector/ProgressionTracker")
	assert_true(tracker != null, "progression tracker exists in the lab")
	if tracker != null:
		var rows: Array = tracker.call("get_challenge_rows") as Array
		assert_equal(rows.size(), 5, "tracker exposes the five starter challenges")
		assert_equal(_completed_count(rows), 5, "all five challenge rows complete in the lab")
		var runtime_rows: Array = tracker.call("get_reward_runtime_rows") as Array
		assert_equal(_active_count(runtime_rows), 5, "all five rewards reach their runtime systems")

	assert_equal(SpeciesKnowledge.get_rank("gremlin"), 3, "Pack Scholar reaches Gremlin rank three")
	assert_true(
		SpeciesKnowledge.has_unlock("gremlin", "gremlin_pounce"),
		"Gremlin Pounce synchronizes into SpeciesKnowledge"
	)

	lab.call("reset_challenge_progress")
	for reward_id: String in REWARD_IDS:
		assert_true(not GameState.has_unlock(reward_id), "second reset clears " + reward_id)

	lab.queue_free()
	_finish()


func _completed_count(rows: Array) -> int:
	var count: int = 0
	for raw: Variant in rows:
		if raw is Dictionary and bool((raw as Dictionary).get("complete", false)):
			count += 1
	return count


func _active_count(rows: Array) -> int:
	var count: int = 0
	for raw: Variant in rows:
		if raw is Dictionary and bool((raw as Dictionary).get("active", false)):
			count += 1
	return count


func _finish() -> void:
	if failures.is_empty():
		print("PROGRESSION_CHALLENGE_LAB_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PROGRESSION_CHALLENGE_LAB_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
