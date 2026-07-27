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
]


func _ready() -> void:
	var previous_flags: Dictionary = {}
	for flag_id: String in TRACKED_FLAGS:
		previous_flags[flag_id] = GameState.get_flag(flag_id)
		GameState.set_flag(flag_id, false)

	var mission := MissionScene.instantiate()
	add_child(mission)
	await get_tree().process_frame

	assert(mission.player != null)
	assert(mission.tamsin != null)
	assert(mission.tamsin.is_in_group("conversation_npc"))
	assert(mission.tamsin.conversation_data.get("nodes", {}).has("repaired"))
	assert(mission.tamsin.conversation_data.get("nodes", {}).has("prism_return"))

	assert(mission.get_node_or_null("World/WaystationHouse") != null)
	assert(mission.get_node_or_null("World/RepairCamp") != null)
	assert(mission.get_node_or_null("World/EasternSignalTrail") != null)
	assert(mission.get_node_or_null("World/AbandonedEasternRelay") != null)
	assert(mission.get_node_or_null("World/EasternSignalTrail/NarrowStoneBridge") != null)
	assert(mission.get_node_or_null("World/EasternSignalTrail/SignalOverlook") != null)
	assert(mission.get_node_or_null("World/AbandonedEasternRelay/RuinedMaintenanceShed") != null)
	assert(mission.get_node_or_null("World/AbandonedEasternRelay/ExposedConduitAssembly") != null)
	assert(mission.get_node_or_null("World/AbandonedEasternRelay/CrackedPrismCase") != null)

	var stake_count := 0
	for child: Node in mission.trail_root.get_children():
		if child.name.begins_with("SignalStake"):
			stake_count += 1
	assert(stake_count == 6)
	assert(not mission.prism_interactable.active)
	assert(mission.conduit_interactable.is_in_group("story_interactable"))
	assert(mission.space_interactable.is_in_group("story_interactable"))

	mission.begin_repair("metal")
	mission.transformation_time = 2.3
	mission.animate_repair(0.0)
	GameState.set_flag("broken_waystation_relay_repaired", true)
	mission._on_tamsin_choice("accept_investigation", mission.tamsin)
	assert(GameState.get_flag("broken_waystation_relay_investigation"))
	assert(mission.response_label.visible)

	mission.start_remote_encounter()
	assert(mission.encounter_started)
	assert(mission.encounter_enemies.size() == 2)
	mission.encounter_enemies.clear()
	mission.spawn_relay_captain()
	assert(mission.captain_spawned)
	assert(mission.encounter_enemies.size() == 1)
	mission.encounter_enemies.clear()
	mission.finish_remote_encounter()
	assert(mission.encounter_cleared)
	assert(mission.prism_interactable.active)

	mission._on_prism_activated(mission.prism_interactable)
	assert(GameState.get_flag("broken_waystation_prism_recovered"))
	assert(not mission.prism_visual.visible)
	assert(mission.response_label.text == "CRACKED SIGNAL PRISM RECOVERED")

	mission.queue_free()
	await get_tree().process_frame
	for flag_id: String in TRACKED_FLAGS:
		GameState.set_flag(flag_id, bool(previous_flags[flag_id]))

	print("BROKEN_WAYSTATION_RELAY_RESPONSE_SMOKE_TEST: PASS")
	get_tree().quit(0)
