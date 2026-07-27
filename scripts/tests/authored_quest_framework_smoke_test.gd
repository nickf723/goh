extends Node

const MissionScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_broken_waystation_mission_v1.tscn")
const AuthoredQuestRuntimeScript = preload("res://scripts/quests/authored_quest_runtime.gd")
const QuestRewardBundleScript = preload("res://scripts/quests/quest_reward_bundle.gd")
const WorldStateVariantScript = preload("res://scripts/quests/world_state_variant.gd")
const AuthoredEncounterSequenceScript = preload("res://scripts/quests/authored_encounter_sequence.gd")

const TEST_QUEST_ID := "framework_smoke_quest"
const TEST_FLAG := "framework_smoke_reward"


func _ready() -> void:
	var previous_mastery: int = GameState.get_weapon_mastery_points("sword")
	var previous_flag: bool = GameState.get_flag(TEST_FLAG)
	GameState.reset_quest(TEST_QUEST_ID)
	GameState.set_flag(TEST_FLAG, false)

	var runtime := AuthoredQuestRuntimeScript.new(TEST_QUEST_ID, {
		"title": "Framework Smoke Quest",
		"description": "Exercise reusable authored quest lifecycle.",
		"objective": "Begin.",
		"stage": 0,
		"stages": ["Begin", "Finish"],
	})
	runtime.ensure_started()
	assert(runtime.is_active())
	runtime.set_stage(1, "Finish.")
	assert(runtime.get_stage() == 1)
	runtime.complete("Done.")
	assert(runtime.is_complete())

	var reward_bundle := QuestRewardBundleScript.new({
		"mastery": {"sword": 3},
		"flags": [TEST_FLAG],
	})
	var granted: Dictionary = reward_bundle.apply()
	assert(GameState.get_weapon_mastery_points("sword") == previous_mastery + 3)
	assert(GameState.get_flag(TEST_FLAG))
	assert(int((granted.get("mastery", {}) as Dictionary).get("sword", 0)) == 3)

	var inactive := Node3D.new()
	var active := Node3D.new()
	add_child(inactive)
	add_child(active)
	var variants := WorldStateVariantScript.new()
	variants.register_variant("before", [inactive])
	variants.register_variant("after", [active])
	variants.apply("before")
	assert(inactive.visible and not active.visible)
	variants.apply("after")
	assert(not inactive.visible and active.visible)

	var sequence := AuthoredEncounterSequenceScript.new()
	sequence.configure([
		{"spawns": [{"name": "First"}]},
		{"spawns": [{"name": "Second"}]},
	])
	var first_wave: Array[Node3D] = sequence.begin_next_wave(self, _spawn_dummy)
	assert(first_wave.size() == 1)
	first_wave[0].free()
	sequence.prune()
	assert(sequence.can_advance())
	var second_wave: Array[Node3D] = sequence.begin_next_wave(self, _spawn_dummy)
	assert(second_wave.size() == 1)
	second_wave[0].free()
	sequence.prune()
	assert(sequence.is_complete())

	var mission := MissionScene.instantiate()
	add_child(mission)
	await get_tree().process_frame
	assert(mission is PrototypeBrokenWaystationFrameworkIntegration)
	assert(mission.quest_runtime != null)
	assert(mission.aftermath_variants != null)
	assert(mission.aftermath_variants.get_active_id() in ["active", "secured"])

	mission.queue_free()
	GameState.set_weapon_mastery_points("sword", previous_mastery)
	GameState.set_flag(TEST_FLAG, previous_flag)
	GameState.reset_quest(TEST_QUEST_ID)
	await get_tree().process_frame
	print("AUTHORED_QUEST_FRAMEWORK_SMOKE_TEST: PASS")
	get_tree().quit(0)


func _spawn_dummy(parent: Node, definition: Dictionary) -> Node3D:
	var dummy := Node3D.new()
	dummy.name = str(definition.get("name", "Dummy"))
	parent.add_child(dummy)
	return dummy
