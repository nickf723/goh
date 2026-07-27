extends Node

const MissionScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_broken_waystation_mission_v1.tscn")


func _ready() -> void:
	var tracked_flags: Array[String] = [
		"broken_waystation_relay_repaired",
		"broken_waystation_repaired_metal",
		"broken_waystation_repaired_earth",
		"broken_waystation_repaired_lightning",
	]
	var previous_flags: Dictionary = {}
	for flag_id: String in tracked_flags:
		previous_flags[flag_id] = GameState.get_flag(flag_id)
		GameState.set_flag(flag_id, false)

	var mission := MissionScene.instantiate()
	add_child(mission)
	await get_tree().process_frame

	assert(mission.player != null)
	assert(mission.tamsin != null)
	assert(mission.tamsin.is_in_group("conversation_npc"))
	assert(not mission.tamsin.conversation_data.is_empty())
	assert(mission.relay_root != null)
	assert(mission.relay_root.name == "DamagedRelay")
	assert(mission.broken_arm.visible)
	assert(not mission.repaired_arm.visible)
	assert(mission.foundation_rubble.visible)
	assert(not mission.raised_foundation.visible)
	assert(mission.dead_conduit.visible)
	assert(not mission.live_conduit.visible)
	assert(is_zero_approx(mission.beacon_light.light_energy))
	assert(mission.get_node_or_null("World/WaystationHouse") != null)
	assert(mission.get_node_or_null("World/RepairCamp") != null)

	mission.begin_repair("metal")
	assert(not mission.broken_arm.visible)
	assert(mission.repaired_arm.visible)
	assert(not mission.foundation_rubble.visible)
	assert(not mission.dead_conduit.visible)
	assert(mission.repair_method == "metal")
	mission.transformation_time = 2.3
	mission.animate_repair(0.0)
	assert(not mission.transformation_active)
	assert(mission.beacon_light.light_energy > 2.0)

	mission.queue_free()
	await get_tree().process_frame

	for flag_id: String in tracked_flags:
		GameState.set_flag(flag_id, bool(previous_flags[flag_id]))

	print("BROKEN_WAYSTATION_WAYKEEPER_SMOKE_TEST: PASS")
	get_tree().quit(0)
