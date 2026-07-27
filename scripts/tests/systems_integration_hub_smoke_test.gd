extends Node

const HubScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_systems_integration_hub_v1.tscn")
const CombatArenaLoadoutScript = preload("res://scripts/systems/combat_arena_loadout.gd")


func _ready() -> void:
	var before: Dictionary = CombatArenaLoadoutScript.capture_state()
	var hub := HubScene.instantiate() as PrototypeSystemsIntegrationHub
	assert(hub != null)
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(hub.player != null)
	assert(hub.STATIONS.size() == 6)
	assert(hub.get_node_or_null("CampusFloor") != null)
	assert(hub.get_node_or_null("CombatTargets") != null)
	assert(hub.get_node_or_null("LiveEnemies") != null)
	assert(hub.target_container != null)
	assert(hub.target_container.get_child_count() >= 7)
	assert(hub.enemy_container != null)
	assert(hub.enemy_container.get_child_count() == 2)
	assert(hub.status_label != null)
	assert(hub.station_label != null)

	var destination: Vector3 = hub.STATIONS[2].get("position", Vector3.ZERO)
	hub.teleport_player(destination)
	assert(hub.player.global_position.distance_to(destination) < 0.05)

	hub.toggle_everything_unlocked()
	assert(hub.everything_unlocked)
	hub.toggle_everything_unlocked()
	assert(not hub.everything_unlocked)
	assert(GameState.get_stat_snapshot() == before.get("stats", {}))
	assert(GameState.get_owned_equipment_snapshot() == before.get("owned_equipment", {}))
	assert(GameState.get_weapon_mastery_snapshot() == before.get("weapon_mastery", {}))
	assert(GameState.get_unlock_snapshot() == before.get("unlocks", {}))

	hub.queue_free()
	await get_tree().process_frame
	print("SYSTEMS_INTEGRATION_HUB_SMOKE_TEST: PASS")
	get_tree().quit(0)
