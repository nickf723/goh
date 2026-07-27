extends Node

const MissionScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_broken_waystation_mission_v1.tscn")


func _ready() -> void:
	var before_mastery: Dictionary = GameState.get_weapon_mastery_snapshot()
	var mission := MissionScene.instantiate()
	add_child(mission)
	await get_tree().process_frame

	assert(mission.mission_state == mission.STATE_BRIEFING)
	assert(mission.player != null)
	assert(mission.get_node_or_null("World/Roadblock") != null)
	assert(mission.get_node_or_null("World/SignalCache") != null)
	assert(mission.get_node_or_null("World/RepairedBeacon") != null)

	mission.player.global_position = mission.briefing_position
	mission.interact_nearby()
	assert(mission.mission_state == mission.STATE_ROADBLOCK)

	mission.player.global_position = mission.discovery_position
	mission.interact_nearby()
	assert(mission.optional_discovery)
	assert(not mission.get_node("World/SignalCache").visible)

	mission.player.global_position = mission.roadblock_position
	mission.resolve_roadblock("break")
	assert(mission.mission_state == mission.STATE_ENCOUNTER)
	assert(mission.roadblock_method == "break")
	assert(not mission.get_node("World/Roadblock").visible)
	assert(mission.enemies.size() == 3)

	mission.player.global_position = Vector3(20, 3, 20)
	mission.restore_checkpoint()
	assert(mission.player.global_position.distance_to(mission.checkpoint_position) < 0.05)
	assert(mission.enemies.size() == 3)

	mission.clear_enemies()
	await get_tree().process_frame
	mission.finish_encounter()
	assert(mission.mission_state == mission.STATE_RETURN)
	assert(mission.get_node("World/RepairedBeacon").visible)

	mission.player.global_position = mission.briefing_position
	mission.interact_nearby()
	assert(mission.mission_state == mission.STATE_COMPLETE)
	assert(mission.reward_granted)
	assert(GameState.get_weapon_mastery_points("sword") >= 12)

	mission.reset_mission()
	assert(mission.mission_state == mission.STATE_BRIEFING)
	assert(mission.get_node("World/Roadblock").visible)
	assert(not mission.optional_discovery)

	GameState.weapon_mastery = before_mastery.duplicate(true)
	mission.queue_free()
	await get_tree().process_frame
	print("BROKEN_WAYSTATION_MISSION_SMOKE_TEST: PASS")
	get_tree().quit(0)
