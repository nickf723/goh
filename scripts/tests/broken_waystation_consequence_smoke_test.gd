extends Node

const MissionScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_broken_waystation_mission_v1.tscn")

const TRACKED_FLAGS: Array[String] = [
	"broken_waystation_relay_repaired",
	"broken_waystation_repaired_metal",
	"broken_waystation_repaired_earth",
	"broken_waystation_repaired_lightning",
	"broken_waystation_relay_investigation",
	"broken_waystation_remote_conduit_disabled",
	"broken_waystation_prism_recovered",
	"broken_waystation_prism_returned",
	"broken_waystation_space_overlook",
	"broken_waystation_quest_complete",
]


func _ready() -> void:
	var previous_flags: Dictionary = {}
	for flag_id: String in TRACKED_FLAGS:
		previous_flags[flag_id] = GameState.get_flag(flag_id)
		GameState.set_flag(flag_id, false)
	GameState.reset_quest("broken_waystation_relay_response")

	GameState.set_flag("broken_waystation_relay_repaired", true)
	GameState.set_flag("broken_waystation_repaired_metal", true)
	var mission := MissionScene.instantiate()
	add_child(mission)
	await get_tree().process_frame

	assert(mission is PrototypeBrokenWaystationConsequence)
	assert(mission.aftermath_root != null)
	assert(mission.eastern_gate_closed.visible)
	assert(not mission.eastern_gate_open.visible)
	assert(not mission.packed_camp.visible)
	assert(not mission.supply_cache.visible)
	assert(mission.completion_layer != null)
	assert(not mission.completion_layer.visible)

	mission.start_relay_response_quest()
	var quest: Dictionary = GameState.get_quest(mission.QUEST_ID)
	assert(not quest.is_empty())
	assert(str(quest.get("state", "")) == "active")
	assert(int(quest.get("stage", -1)) == 0)

	mission.start_remote_encounter()
	quest = GameState.get_quest(mission.QUEST_ID)
	assert(int(quest.get("stage", -1)) == 1)

	mission.encounter_started = true
	mission.captain_spawned = true
	mission.finish_remote_encounter()
	quest = GameState.get_quest(mission.QUEST_ID)
	assert(int(quest.get("stage", -1)) == 2)

	mission._on_prism_activated(mission.prism_interactable)
	quest = GameState.get_quest(mission.QUEST_ID)
	assert(int(quest.get("stage", -1)) == 3)
	assert(GameState.get_flag(mission.FLAG_PRISM_RECOVERED))

	GameState.set_flag(mission.FLAG_CONDUIT_DISABLED, true)
	GameState.set_flag(mission.FLAG_SPACE_OVERLOOK, true)
	GameState.set_flag(mission.FLAG_PRISM_RETURNED, true)
	mission.complete_relay_response_quest()
	assert(GameState.get_flag(mission.FLAG_COMPLETE))
	quest = GameState.get_quest(mission.QUEST_ID)
	assert(str(quest.get("state", "")) == "completed")
	assert(not mission.eastern_gate_closed.visible)
	assert(mission.eastern_gate_open.visible)
	assert(mission.packed_camp.visible)
	assert(mission.supply_cache.visible)
	assert(not mission.get_node("World/RepairCamp").visible)
	var summary: String = mission.build_completion_summary()
	assert(summary.contains("Metal arm reconstruction"))
	assert(summary.contains("Disabled before the final confrontation"))
	assert(summary.contains("Surveyed through Space"))
	mission.show_completion_screen()
	assert(mission.completion_layer.visible)

	mission.queue_free()
	await get_tree().process_frame
	GameState.reset_quest("broken_waystation_relay_response")
	for flag_id: String in TRACKED_FLAGS:
		GameState.set_flag(flag_id, bool(previous_flags[flag_id]))
	print("BROKEN_WAYSTATION_CONSEQUENCE_SMOKE_TEST: PASS")
	get_tree().quit(0)
