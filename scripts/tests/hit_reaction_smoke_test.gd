extends Node

const TargetScene: PackedScene = preload("res://scenes/actors/enemies/hit_reaction_test_target.tscn")
const SwordMoveset: WeaponMovesetDefinition = preload("res://data/weapon_movesets/practice_sword_moveset.tres")
const ForceReceiverScript = preload("res://scripts/combat/force_receiver.gd")
const StatusReceiverScript = preload("res://scripts/combat/status_receiver.gd")
const AirborneReactionControllerScript = preload("res://scripts/combat/airborne_reaction_controller.gd")


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

	await _test_enemy_airborne_loop()

	print("HitReactionSmokeTest: PASS")
	get_tree().quit()


func _test_enemy_airborne_loop() -> void:
	var actor := CharacterBody3D.new()
	actor.name = "AirborneContractActor"
	var force_receiver := ForceReceiverScript.new()
	force_receiver.name = "ForceReceiver"
	actor.add_child(force_receiver)
	var status_receiver := StatusReceiverScript.new()
	status_receiver.name = "StatusReceiver"
	actor.add_child(status_receiver)
	var airborne_controller := AirborneReactionControllerScript.new()
	airborne_controller.name = "AirborneReactionController"
	actor.add_child(airborne_controller)
	add_child(actor)
	await get_tree().process_frame

	var launcher := _make_payload(["weapon", "melee", "heavy", "launcher"], 5, 6)
	launcher.knockback_up_strength = 6.0
	force_receiver.apply_impulse(Vector3.FORWARD, 1.5, launcher.knockback_up_strength, "Launcher Test")
	airborne_controller.register_payload(launcher)
	force_receiver.consume_external_velocity(0.016)
	airborne_controller.consume_launch_impulse()
	airborne_controller.sustain_airborne_action_lock()
	assert(str(airborne_controller.get_debug_data().get("air", "")) == "LAUNCHED")
	assert(actor.velocity.y > 0.0)
	assert(airborne_controller.juggle_resistance > 0.0)
	assert(status_receiver.has_status("staggered"))

	var first_resistance: float = airborne_controller.juggle_resistance
	var aerial_follow_up := _make_payload(["weapon", "melee", "context_aerial", "technique_aerial_forward"], 3, 2)
	airborne_controller.register_payload(aerial_follow_up)
	assert(airborne_controller.juggle_resistance > first_resistance)

	airborne_controller.set_air_state(airborne_controller.AirState.FALLING)
	actor.velocity.y = -1.0
	var plunge := _make_payload(["weapon", "melee", "context_aerial", "technique_aerial_down", "plunging"], 6, 7)
	airborne_controller.register_payload(plunge)
	assert(airborne_controller.pending_ground_bounce)
	assert(actor.velocity.y <= -airborne_controller.ground_bounce_min_fall_speed)

	airborne_controller.resolve_landing()
	assert(str(airborne_controller.get_debug_data().get("air", "")) == "LAUNCHED")
	assert(airborne_controller.ground_bounces_used == 1)
	assert(actor.velocity.y > 0.0)

	airborne_controller.pending_ground_bounce = false
	airborne_controller.set_air_state(airborne_controller.AirState.FALLING)
	actor.velocity.y = -6.0
	airborne_controller.resolve_landing()
	assert(str(airborne_controller.get_debug_data().get("air", "")) == "LANDING")
	assert(airborne_controller.air_state_timer >= airborne_controller.landing_recovery_duration)

	actor.queue_free()


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
