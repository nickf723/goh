extends Node

const ShellScript = preload(
	"res://scripts/ui/full_menu_shell_feedback_v1.gd"
)

const REWARD_IDS: Array[String] = [
	"charged_firebolt",
	"chain_lightning",
	"piercing_ice_lance",
	"alchemy_recipe_insight",
	"gremlin_pounce",
]

var failures: Array[String] = []
var old_story_flags: Dictionary = {}
var old_unlocks: Dictionary = {}
var old_quests: Dictionary = {}
var old_weapon_mastery: Dictionary = {}
var old_species_snapshot: Dictionary = {}
var context_node: Node
var shell: Control


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_state()
	_clear_test_state()
	context_node = Node.new()
	context_node.name = "FeedbackGameplayContext"
	context_node.add_to_group("game_ui")
	add_child(context_node)

	var director: Node = get_node_or_null("/root/FullMenuDirector")
	var tracker: Node = get_node_or_null(
		"/root/FullMenuDirector/ProgressionTracker"
	)
	var feedback: CanvasLayer = get_node_or_null(
		"/root/FullMenuDirector/ProgressionFeedbackHUD"
	) as CanvasLayer
	assert_true(director != null, "FullMenuDirector exists")
	assert_true(tracker != null, "feedback-aware progression tracker exists")
	assert_true(feedback != null, "persistent progression feedback HUD exists")
	if tracker == null or feedback == null:
		_restore_state()
		_finish()
		return

	feedback.call("clear_feedback")
	await get_tree().process_frame

	assert_true(
		bool(tracker.call("track_challenge", "live_wire")),
		"a challenge can be pinned"
	)
	await get_tree().process_frame
	var tracked: Dictionary = tracker.call("get_tracked_progress_row") as Dictionary
	assert_equal(tracked.get("kind"), "challenge", "tracked row identifies its kind")
	assert_equal(tracked.get("id"), "live_wire", "tracked row identifies Live Wire")
	assert_equal(tracked.get("current"), 0, "tracked challenge begins at zero")
	var debug: Dictionary = feedback.call("get_debug_data") as Dictionary
	assert_true(bool(debug.get("tracked_visible", false)), "tracked card is visible in gameplay context")

	feedback.call("clear_feedback")
	tracker.call(
		"record_event",
		"reaction_triggered",
		"wet_conduction",
		{"amount": 1, "source": "feedback_test"}
	)
	var first_progress_debug: Dictionary = feedback.call("get_debug_data") as Dictionary
	assert_equal(first_progress_debug.get("toast_count"), 1, "first progress event creates one toast")
	tracker.call(
		"record_event",
		"reaction_triggered",
		"wet_conduction",
		{"amount": 1, "source": "feedback_test"}
	)
	var bundled_debug: Dictionary = feedback.call("get_debug_data") as Dictionary
	assert_equal(bundled_debug.get("toast_count"), 1, "repeated challenge progress bundles into one toast")
	tracker.call(
		"record_event",
		"reaction_triggered",
		"wet_conduction",
		{"amount": 1, "source": "feedback_test"}
	)
	assert_true(GameState.has_unlock("chain_lightning"), "Live Wire still grants Chain Lightning")
	var complete_row: Dictionary = tracker.call("get_tracked_progress_row") as Dictionary
	assert_true(bool(complete_row.get("complete", false)), "tracked card updates to complete")
	var completion_debug: Dictionary = feedback.call("get_debug_data") as Dictionary
	assert_true(
		(completion_debug.get("toast_keys", []) as Array).has("reward:chain_lightning"),
		"completion banner uses the runtime reward key"
	)

	feedback.call("clear_feedback")
	feedback.call(
		"push_feedback",
		"challenge",
		"Bundle Test",
		"First",
		"bundle:test",
		1,
		3,
		false
	)
	feedback.call(
		"push_feedback",
		"challenge",
		"Bundle Test",
		"Second",
		"bundle:test",
		2,
		3,
		false
	)
	assert_equal(
		(feedback.call("get_debug_data") as Dictionary).get("toast_count"),
		1,
		"public feedback API deduplicates matching events"
	)

	GameState.start_quest(
		"feedback_story",
		{
			"title": "A Thread to Follow",
			"quest_type": "story",
			"objective": "Reach the second marker.",
			"stages": ["Begin", "Cross", "Finish"],
		}
	)
	assert_true(
		bool(tracker.call("track_quest", "feedback_story")),
		"an active quest can replace the pinned challenge"
	)
	GameState.set_quest_stage(
		"feedback_story",
		1,
		"Reach the final marker."
	)
	var quest_row: Dictionary = tracker.call("get_tracked_progress_row") as Dictionary
	assert_equal(quest_row.get("kind"), "quest", "tracked row switches to quest")
	assert_equal(quest_row.get("current"), 2, "quest card reflects the current stage")
	assert_equal(quest_row.get("target"), 3, "quest card knows the stage count")
	assert_equal(GameState.current_objective, "Reach the final marker.", "tracked quest continues controlling the objective")

	feedback.call("clear_feedback")
	tracker.call(
		"record_discovery",
		"reaction",
		"feedback_test_reaction",
		{"source": "feedback_test"}
	)
	var discovery_debug: Dictionary = feedback.call("get_debug_data") as Dictionary
	assert_true(
		(discovery_debug.get("toast_keys", []) as Array).has(
			"discovery:reaction:feedback_test_reaction"
		),
		"Journal discoveries create a feedback banner"
	)

	shell = ShellScript.new()
	add_child(shell)
	await get_tree().process_frame
	shell.call("show_menu", _make_menu_data())
	await get_tree().process_frame
	shell.set("selected_codex_category", "challenges")
	shell.set("selected_codex_record_id", "progression.shatterproof")
	shell.call(
		"activate_action",
		{
			"kind": "select_codex_record",
			"record_id": "progression.shatterproof",
		}
	)
	var pinned_from_codex: Dictionary = tracker.call("get_tracked_progress_row") as Dictionary
	assert_equal(pinned_from_codex.get("id"), "shatterproof", "second confirm pins a Codex challenge")
	var shell_debug: Dictionary = shell.call("get_codex_debug_data") as Dictionary
	assert_true(bool(shell_debug.get("challenge_pinning", false)), "production shell reports challenge pinning")

	if director != null and director.has_method("open_full_menu"):
		director.call("open_full_menu")
		await get_tree().process_frame
		assert_true(not feedback.visible, "progression HUD hides behind the full menu")
		director.call("close_full_menu")
		await get_tree().process_frame
		assert_true(feedback.visible, "progression HUD returns after the full menu closes")

	_restore_state()
	_finish()


func _make_menu_data() -> Dictionary:
	return {
		"objective": "Test progression feedback.",
		"stats": {},
		"stat_sections": [],
		"spells": [],
		"equipped_spell_slots": [],
		"learned_spell_sections": [],
		"loadout_summary": {},
		"weapon": {},
		"quick_item_slots": [],
		"inventory_items": [],
		"key_items": [],
		"spellcasting_mastery": {},
		"familiar_mastery": {},
	}


func _capture_state() -> void:
	old_story_flags = GameState.story_flags.duplicate(true)
	old_unlocks = GameState.get_unlock_snapshot()
	old_quests = GameState.get_quest_snapshot()
	old_weapon_mastery = GameState.get_weapon_mastery_snapshot()
	old_species_snapshot = SpeciesKnowledge.get_snapshot()


func _clear_test_state() -> void:
	for raw_key: Variant in GameState.story_flags.keys():
		var key: String = str(raw_key)
		if key.begins_with("__progression__::"):
			GameState.story_flags.erase(raw_key)
	for reward_id: String in REWARD_IDS:
		GameState.revoke_unlock(reward_id)
	GameState.reset_quest("feedback_story")


func _restore_state() -> void:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
	if context_node != null and is_instance_valid(context_node):
		context_node.queue_free()
	GameState.story_flags = old_story_flags.duplicate(true)
	GameState.quests = old_quests.duplicate(true)
	GameState.weapon_mastery = old_weapon_mastery.duplicate(true)
	SpeciesKnowledge.apply_snapshot(old_species_snapshot)
	var current: Dictionary = GameState.get_unlock_snapshot()
	for raw_key: Variant in current.keys():
		GameState.revoke_unlock(str(raw_key))
	for raw_key: Variant in old_unlocks.keys():
		var value: Variant = old_unlocks[raw_key]
		GameState.grant_unlock(
			str(raw_key),
			(value as Dictionary).duplicate(true) if value is Dictionary else {}
		)
	var feedback: Node = get_node_or_null(
		"/root/FullMenuDirector/ProgressionFeedbackHUD"
	)
	if feedback != null and feedback.has_method("clear_feedback"):
		feedback.call("clear_feedback")
	var tracker: Node = get_node_or_null(
		"/root/FullMenuDirector/ProgressionTracker"
	)
	if tracker != null and tracker.has_method("synchronize_runtime_rewards"):
		tracker.call("synchronize_runtime_rewards")


func _finish() -> void:
	if failures.is_empty():
		print("PROGRESSION_FEEDBACK_TRACKING_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PROGRESSION_FEEDBACK_TRACKING_V1_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
