extends Node

const PlayerResourceControllerScript: Script = preload("res://scripts/player/player_resource_controller.gd")
const PlayerActionStateScript: Script = preload("res://scripts/player/player_action_state.gd")
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const Movesets: Array[WeaponMovesetDefinition] = [
	preload("res://data/weapon_movesets/practice_sword_moveset.tres"),
	preload("res://data/weapon_movesets/training_hammer_moveset.tres"),
	preload("res://data/weapon_movesets/training_spear_moveset.tres"),
	preload("res://data/weapon_movesets/training_chain_moveset.tres"),
	preload("res://data/weapon_movesets/training_whip_moveset.tres"),
]

var failures: Array[String] = []
var original_snapshot: Dictionary


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_snapshot = GameState.get_stat_snapshot()
	set_resource_pair("health", 2, 5)
	set_resource_pair("stamina", 5, 5)
	set_resource_pair("mana", 2, 5)
	set_resource_pair("stance", 5, 5)

	var actor: Node = Node.new()
	actor.name = "ResourceTestActor"
	add_child(actor)

	var action_state: PlayerActionState = PlayerActionStateScript.new() as PlayerActionState
	action_state.name = "PlayerActionState"
	actor.add_child(action_state)

	var controller: PlayerResourceController = PlayerResourceControllerScript.new() as PlayerResourceController
	controller.name = "PlayerResourceController"
	actor.add_child(controller)
	controller.set_process(false)

	assert_true(GameState.spend_stamina(2), "stamina spend succeeds")
	assert_equal(GameState.get_stat("stamina"), 3, "stamina spend applies")

	controller.advance_resources(0.69)
	assert_equal(GameState.get_stat("stamina"), 3, "stamina waits through recovery delay")
	controller.advance_resources(0.02)
	assert_equal(GameState.get_stat("stamina"), 3, "delay completion does not grant a free point")
	controller.advance_resources(0.49)
	assert_equal(GameState.get_stat("stamina"), 4, "stamina recovers after the delay")

	assert_true(GameState.spend_stamina(1), "second stamina spend succeeds")
	action_state.begin_attack(2.0)
	controller.advance_resources(0.7)
	controller.advance_resources(0.8)
	assert_equal(GameState.get_stat("stamina"), 3, "stamina pauses during committed actions")
	action_state.end_attack()
	controller.advance_resources(0.49)
	assert_equal(GameState.get_stat("stamina"), 4, "stamina resumes after the action")

	GameState.damage_stance(3)
	assert_equal(GameState.get_stat("stance"), 2, "stance pressure applies")
	controller.advance_resources(1.99)
	assert_equal(GameState.get_stat("stance"), 2, "stance waits through its longer delay")
	controller.advance_resources(0.02)
	controller.advance_resources(0.81)
	assert_equal(GameState.get_stat("stance"), 3, "stance recovers after avoiding pressure")

	var health_before: int = GameState.get_stat("health")
	var mana_before: int = GameState.get_stat("mana")
	controller.advance_resources(8.0)
	assert_equal(GameState.get_stat("health"), health_before, "health has no passive regeneration")
	assert_equal(GameState.get_stat("mana"), mana_before, "mana has no passive regeneration")
	assert_equal(GameState.get_stat("stamina"), GameState.get_stat("max_stamina"), "stamina caps at maximum")
	assert_equal(GameState.get_stat("stance"), GameState.get_stat("max_stance"), "stance caps at maximum")

	assert_player_scene_contract()
	assert_action_costs()

	actor.queue_free()
	restore_snapshot()

	if failures.is_empty():
		print("PLAYER_RESOURCE_LOOP_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("PLAYER_RESOURCE_LOOP_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_player_scene_contract() -> void:
	var player: Node = PlayerScene.instantiate()
	if player.get_node_or_null("PlayerResourceController") == null:
		failures.append("reusable Player scene is missing PlayerResourceController")

	var dodge: Node = player.get_node_or_null("PlayerDodgeController")
	if dodge == null:
		failures.append("reusable Player scene is missing PlayerDodgeController")
	elif int(dodge.get("stamina_cost")) != 1:
		failures.append("dodge must cost exactly 1 stamina in v1")

	player.queue_free()


func assert_action_costs() -> void:
	for moveset: WeaponMovesetDefinition in Movesets:
		if moveset == null:
			failures.append("a required weapon moveset is missing")
			continue
		for attack: WeaponAttackDefinition in moveset.attacks:
			if attack == null:
				failures.append(moveset.moveset_id + " contains a null attack")
			elif attack.stamina_cost <= 0:
				failures.append(moveset.moveset_id + "/" + attack.attack_id + " must spend stamina")


func set_resource_pair(resource_name: String, current: int, maximum: int) -> void:
	GameState.set_stat("max_" + resource_name, maximum)
	GameState.set_stat(resource_name, current)


func restore_snapshot() -> void:
	GameState.stats = original_snapshot.duplicate(true)
	for stat_variant: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_variant)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_variant]))


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))


func assert_true(value: bool, label: String) -> void:
	if not value:
		failures.append(label + ": expected true")
