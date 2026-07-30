extends Node


const WaterPatchScene: PackedScene = preload("res://scenes/surfaces/water_patch.tscn")
const RegeneratorScript = preload("res://scripts/systems/lab_resource_regenerator.gd")
const PlayerCasterScript = preload("res://scripts/abilities/ability_caster_player_channels.gd")

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_test_water_overlap_filter()
	_test_lab_resource_regeneration()
	_test_spell_lock_on_contract()
	_test_enemy_squad_class_chain()
	_restore_stats()
	_finish()


func _test_water_overlap_filter() -> void:
	var water: Area3D = WaterPatchScene.instantiate() as Area3D
	add_child(water)
	var player := CharacterBody3D.new()
	player.name = "WaterFilterPlayer"
	player.add_to_group("player")
	var status_receiver := Node.new()
	status_receiver.name = "StatusReceiver"
	player.add_child(status_receiver)
	add_child(player)
	var sensor := Area3D.new()
	sensor.name = "RemotePlayerSensor"
	player.add_child(sensor)
	var reaction_target := Area3D.new()
	reaction_target.name = "ReactionTarget"
	var target_status := Node.new()
	target_status.name = "StatusReceiver"
	reaction_target.add_child(target_status)
	add_child(reaction_target)

	_expect(
		not bool(water.call("_is_valid_water_overlap", sensor, player)),
		"Player-owned sensor areas do not count as standing in water"
	)
	_expect(
		bool(water.call("_is_valid_water_overlap", player, player)),
		"The player's actual physics body can enter water"
	)
	_expect(
		bool(water.call("_is_valid_water_overlap", reaction_target, reaction_target)),
		"Area3D reaction targets still interact with water"
	)
	water.free()
	player.free()
	reaction_target.free()


func _test_lab_resource_regeneration() -> void:
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 10)
	GameState.set_stat("max_stamina", 60)
	GameState.set_stat("stamina", 20)
	GameState.set_stat("max_focus", 40)
	GameState.set_stat("focus", 10)
	var regenerator: Node = RegeneratorScript.new()
	regenerator.set("mana_per_second", 18.0)
	regenerator.call("_process", 0.5)
	_expect(GameState.get_stat("mana") > 10, "Reaction lab regenerates Mana")
	_expect(GameState.get_stat("stamina") > 20, "Reaction lab regenerates Stamina")
	_expect(GameState.get_stat("focus") > 10, "Reaction lab regenerates Focus")
	regenerator.free()


func _test_spell_lock_on_contract() -> void:
	var caster: Node = PlayerCasterScript.new()
	var aimed := AbilityDefinition.new()
	aimed.targeting_style = "aimed"
	aimed.delivery_type = "projectile"
	var locked := AbilityDefinition.new()
	locked.targeting_style = "lock_on"
	locked.delivery_type = "homing"
	_expect(
		not bool(caster.call("_ability_uses_lock_on_direction", aimed)),
		"Aimed untargeted spells ignore enemy lock-on steering"
	)
	_expect(
		bool(caster.call("_ability_uses_lock_on_direction", locked)),
		"Explicit target-lock spells may use enemy steering"
	)
	caster.free()


func _test_enemy_squad_class_chain() -> void:
	var script_value: Variant = load(
		"res://scripts/enemies/enemy_threat_aware_action_brain.gd"
	)
	_expect(script_value is Script, "Enemy threat brain script resolves")
	if not script_value is Script:
		return
	var brain_value: Variant = (script_value as Script).new()
	_expect(brain_value is Node, "Enemy squad tactical class chain instantiates")
	if brain_value is Node:
		(brain_value as Node).free()


func _restore_stats() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("REACTION_LAB_PLAYABILITY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("REACTION_LAB_PLAYABILITY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
