extends "res://scripts/weapons/safe_weapon_controller.gd"
class_name CombatWeaponControllerV2

const RANGED_AIM_CLASSES: Array[String] = ["bow", "shuriken", "boomerang"]


# Ranged attacks should follow the combat aim while Grace strafes. The shared
# melee resolver deliberately blends movement input into attack heading, which
# is desirable for lunges but made projectile proxies veer away from the target.
func resolve_attack_forward(attack: WeaponAttackDefinition) -> Vector3:
	if _uses_live_ranged_aim():
		var live_forward: Vector3 = _get_live_ranged_forward()
		if live_forward.length_squared() > 0.0001:
			return live_forward
	return super.resolve_attack_forward(attack)


# The ranged query happens after startup. Re-sample aim at contact time so a
# player can keep tracking a target while moving instead of firing along the
# movement-contaminated heading cached when the attack button was pressed.
func get_attack_forward() -> Vector3:
	if _uses_live_ranged_aim() and current_attack != null:
		var live_forward: Vector3 = _get_live_ranged_forward()
		if live_forward.length_squared() > 0.0001:
			return live_forward
	return super.get_attack_forward()


# Payload targets are resolved only through the collider's ancestry. The old
# shared resolver also recursively searched children at every ancestor level;
# once it reached a scene root, a floor or wall could accidentally nominate an
# unrelated sibling HitReceiver elsewhere in the level.
func find_payload_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if is_payload_target(current):
			return current
		current = current.get_parent()
	return null


# Flexible rigs can record how strongly each section of the weapon contacted a
# target. Apply that target-specific weighting before the existing Safe controller
# adds class identity, body-form modifiers, reactions, and normal hit handling.
func send_payload_to_target(
	target: Node,
	payload: DamagePayload
) -> Dictionary:
	var resolved: DamagePayload = payload
	if (
		payload != null
		and runtime_weapon_rig != null
		and runtime_weapon_rig.has_method("modify_payload_for_target")
	):
		var duplicate_payload: DamagePayload = payload.duplicate(true) as DamagePayload
		if duplicate_payload != null:
			resolved = duplicate_payload
			runtime_weapon_rig.call(
				"modify_payload_for_target",
				resolved,
				target,
				current_attack
			)
	return super.send_payload_to_target(target, resolved)


func _uses_live_ranged_aim() -> bool:
	return (
		equipped_weapon != null
		and RANGED_AIM_CLASSES.has(equipped_weapon.weapon_class)
	)


func _get_live_ranged_forward() -> Vector3:
	var actor: Node3D = get_actor()
	if actor == null:
		return Vector3.ZERO
	var origin: Vector3 = actor.global_position + Vector3.UP * 0.42
	if actor.has_method("get_combat_aim_direction"):
		var aim_value: Variant = actor.call(
			"get_combat_aim_direction",
			origin,
			true
		)
		if aim_value is Vector3:
			var aim: Vector3 = aim_value as Vector3
			aim.y = 0.0
			if aim.length_squared() > 0.0001:
				return aim.normalized()
	if actor.has_method("has_lock_on_target") and bool(actor.call("has_lock_on_target")):
		if actor.has_method("get_lock_on_cast_direction"):
			var lock_value: Variant = actor.call("get_lock_on_cast_direction", origin)
			if lock_value is Vector3:
				var lock_direction: Vector3 = lock_value as Vector3
				lock_direction.y = 0.0
				if lock_direction.length_squared() > 0.0001:
					return lock_direction.normalized()
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		var camera_forward: Vector3 = -camera.global_transform.basis.z
		camera_forward.y = 0.0
		if camera_forward.length_squared() > 0.0001:
			return camera_forward.normalized()
	var actor_forward: Vector3 = -actor.global_transform.basis.z
	actor_forward.y = 0.0
	return actor_forward.normalized() if actor_forward.length_squared() > 0.0001 else Vector3.FORWARD


func get_combat_v2_debug_data() -> Dictionary:
	return {
		"combat_weapon_controller_v2": true,
		"live_ranged_aim": _uses_live_ranged_aim(),
		"ranged_forward": _get_live_ranged_forward() if _uses_live_ranged_aim() else Vector3.ZERO,
		"safe_ancestry_target_resolution": true,
		"per_contact_payload_hook": true,
	}
