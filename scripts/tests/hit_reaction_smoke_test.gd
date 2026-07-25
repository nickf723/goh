extends Node

const TargetScene: PackedScene = preload("res://scenes/actors/enemies/hit_reaction_test_target.tscn")
const SwordMoveset: WeaponMovesetDefinition = preload("res://data/weapon_movesets/practice_sword_moveset.tres")


func _ready() -> void:
	var light := _spawn_target("light")
	var armored := _spawn_target("armored")
	var unstoppable := _spawn_target("unstoppable")
	await get_tree().process_frame

	var opening: WeaponAttackDefinition = SwordMoveset.get_attack("sword_l1")
	var heavy: WeaponAttackDefinition = SwordMoveset.get_attack("sword_h0")
	var light_payload := _make_payload(["weapon", "melee", "light"], 4, 5)
	light.receive_damage_payload(light_payload)
	light.receive_weapon_impact(light_payload, Vector3.FORWARD, opening)
	assert(light.reaction_controller.last_reaction == "FLINCH")

	armored.receive_damage_payload(light_payload)
	armored.receive_weapon_impact(light_payload, Vector3.FORWARD, opening)
	assert(armored.reaction_controller.last_reaction == "RESIST")

	var break_payload := _make_payload(["weapon", "melee", "heavy", "guard_break"], 6, 8)
	armored.receive_damage_payload(break_payload)
	armored.receive_weapon_impact(break_payload, Vector3.FORWARD, heavy)
	assert(armored.reaction_controller.last_reaction == "GUARD BREAK")

	var launch_payload := _make_payload(["weapon", "melee", "heavy", "launcher"], 5, 6)
	light.reset_target()
	light.receive_damage_payload(launch_payload)
	light.receive_weapon_impact(launch_payload, Vector3.FORWARD, heavy)
	assert(light.reaction_controller.last_reaction == "LAUNCH")
	assert(light.reaction_velocity.y > 0.0)

	unstoppable.receive_damage_payload(break_payload)
	unstoppable.receive_weapon_impact(break_payload, Vector3.FORWARD, heavy)
	assert(unstoppable.reaction_controller.last_reaction == "SUPER ARMOR")
	assert(unstoppable.reaction_velocity.length() <= 0.001)

	light.reset_target()
	for index: int in range(4):
		light.receive_damage_payload(light_payload)
		light.receive_weapon_impact(light_payload, Vector3.FORWARD, opening)
	assert(light.reaction_controller.last_reaction == "ADAPTED")
	assert(light.reaction_controller.reaction_resistance >= 0.86)

	print("HitReactionSmokeTest: PASS")
	get_tree().quit()


func _spawn_target(profile_name: String) -> HitReactionTestTarget:
	var target := TargetScene.instantiate() as HitReactionTestTarget
	target.profile = profile_name
	add_child(target)
	return target


func _make_payload(tags: Array[String], damage: int, stance_damage: int) -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = damage
	payload.stance_damage = stance_damage
	payload.knockback_strength = 2.0
	payload.source_name = "Reaction Test"
	payload.tags = tags
	return payload
