extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const DuelistScene: PackedScene = preload("res://scenes/actors/enemies/telegraph_duelist.tscn")


func _ready() -> void:
	var player := PlayerScene.instantiate() as CharacterBody3D
	player.add_to_group("player")
	add_child(player)
	var duelist := DuelistScene.instantiate() as TelegraphDuelist
	duelist.position = Vector3(0, 0, -2)
	add_child(duelist)
	await get_tree().process_frame

	var resolver := PlayerPerfectDodgeController.new()
	resolver.name = "PlayerPerfectDodgeController"
	player.add_child(resolver)
	await get_tree().process_frame

	var profiles: Array[Dictionary] = duelist._get_attack_profiles()
	assert(profiles.size() == 4)
	assert(str(profiles[0].get("shape", "")) == "circle")
	assert(str(profiles[2].get("shape", "")) == "lane")
	assert(not bool(profiles[0].get("committed", true)))
	assert(bool(profiles[1].get("committed", false)))

	GameState.set_stat("max_stamina", 60)
	GameState.set_stat("stamina", 40)
	var dodge := player.get_node_or_null("DodgeController") as PlayerDodgeController
	assert(dodge != null)
	dodge.is_active = true
	resolver.perfect_remaining = 0.1

	var payload := DamagePayload.new()
	payload.amount = 8
	payload.stance_damage = 6
	payload.source_name = "Smoke Test Strike"
	payload.tags = ["physical", "enemy", "telegraphed"]
	var result: Dictionary = resolver.resolve_telegraphed_attack(payload, duelist)
	assert(str(result.get("outcome", "")) == "perfect_dodge")
	assert(duelist.counter_window_remaining > 0.0)
	assert(GameState.get_stat("stamina") > 40)

	duelist.phase = TelegraphDuelist.PHASE_WINDUP
	duelist.current_attack = profiles[1].duplicate(true)
	duelist.counter_window_remaining = 0.5
	duelist.receive_weapon_impact(payload, Vector3.FORWARD, null)
	assert(duelist.phase == TelegraphDuelist.PHASE_STAGGERED)
	assert(duelist.last_result == "INTERRUPTED")

	duelist.phase = TelegraphDuelist.PHASE_WINDUP
	duelist.current_attack = profiles[1].duplicate(true)
	duelist.counter_window_remaining = 0.0
	duelist.receive_weapon_impact(payload, Vector3.FORWARD, null)
	assert(duelist.phase == TelegraphDuelist.PHASE_WINDUP)
	assert(duelist.last_result == "SUPER ARMOR")

	print("TelegraphDodgeSmokeTest: PASS")
	get_tree().quit()
