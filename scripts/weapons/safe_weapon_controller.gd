extends "res://scripts/weapons/weapon_controller.gd"
class_name SafeWeaponController


func _get_locked_weak_point(actor: Node3D, attack: WeaponAttackDefinition) -> Node:
	if actor == null or attack == null:
		return null
	var target_value: Variant = actor.get("lock_on_target")
	if target_value == null or not is_instance_valid(target_value):
		_clear_stale_lock_target(actor)
		return null
	if not (target_value is Node3D):
		return null
	var target: Node3D = target_value as Node3D
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		_clear_stale_lock_target(actor)
		return null
	if not target.is_in_group("lock_on_weak_point"):
		return null
	if target.has_method("is_targeting_enabled") and not bool(target.call("is_targeting_enabled")):
		return null
	var target_position: Vector3 = get_target_position(target)
	var maximum_distance: float = get_effective_attack_range(attack) + 0.75
	if get_attack_origin().distance_to(target_position) > maximum_distance:
		return null
	if not is_target_in_attack_cone(target, attack):
		return null
	return target


func get_target_position(target: Node) -> Vector3:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return Vector3.ZERO
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	if parent != null and is_instance_valid(parent) and parent is Node3D:
		return (parent as Node3D).global_position
	return Vector3.ZERO


func _clear_stale_lock_target(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if actor.has_method("clear_lock_on"):
		actor.call("clear_lock_on")
	else:
		actor.set("lock_on_target", null)
