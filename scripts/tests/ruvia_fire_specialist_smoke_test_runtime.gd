extends "res://scripts/tests/ruvia_fire_specialist_smoke_test.gd"

const ForceReceiverScript = preload("res://scripts/combat/force_receiver.gd")


func _validate_grace_baseline(
	authority: PlayerElementalAuthorityController,
	defense: PlayerDefenseController,
	action_state: PlayerActionState
) -> void:
	super._validate_grace_baseline(authority, defense, action_state)
	action_state.end_stagger()


func _validate_ruvia_authority(
	player: CharacterBody3D,
	manager: PlayerAvatarManager,
	authority: PlayerElementalAuthorityController,
	defense: PlayerDefenseController,
	status_receiver: PlayerStatusReceiver,
	action_state: PlayerActionState
) -> void:
	super._validate_ruvia_authority(
		player,
		manager,
		authority,
		defense,
		status_receiver,
		action_state
	)
	action_state.end_stagger()


func _validate_solar_spread(
	player: CharacterBody3D,
	weapon: WeaponController
) -> void:
	super._validate_solar_spread(player, weapon)
	if not weapon.runtime_weapon_rig is RuviaEmberHalberdAuthorityRig:
		return
	var rig: RuviaEmberHalberdAuthorityRig = (
		weapon.runtime_weapon_rig as RuviaEmberHalberdAuthorityRig
	)
	var hook_target: Node3D = Node3D.new()
	hook_target.name = "ReapingHookForceTarget"
	var force_receiver: ForceReceiver = ForceReceiverScript.new() as ForceReceiver
	force_receiver.name = "ForceReceiver"
	hook_target.add_child(force_receiver)
	add_child(hook_target)
	hook_target.global_position = (
		player.global_position + Vector3(0.0, 0.0, -3.0)
	)
	var hook_attack: WeaponAttackDefinition = weapon.get_moveset().get_attack(
		"ruvia_halberd_h2"
	)
	var pull_direction: Vector3 = (
		player.global_position - hook_target.global_position
	)
	pull_direction.y = 0.0
	pull_direction = pull_direction.normalized()
	var hook_targets: Array[Node] = [hook_target]
	rig.on_weapon_targets_hit(hook_targets, hook_attack)
	_expect(
		force_receiver.external_velocity.dot(pull_direction) > 0.5,
		"Reaping Hook pulls targets toward Ruvia"
	)
	_expect(
		int(rig.get_debug_data().get("reaping_pull_count", 0)) == 1,
		"Halberd rig reports the Reaping Hook pull"
	)
	hook_target.queue_free()
