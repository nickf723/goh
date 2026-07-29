extends "res://scripts/weapons/weapon_controller.gd"
class_name SafeWeaponController


var _gesture_attack_stamina_spent: int = 0


func _ready() -> void:
	super._ready()
	if not attack_finished.is_connected(_on_safe_attack_finished):
		attack_finished.connect(_on_safe_attack_finished)


func start_attack(attack: WeaponAttackDefinition) -> bool:
	var stamina_before: int = GameState.get_stat("stamina")
	var started: bool = super.start_attack(attack)
	_gesture_attack_stamina_spent = (
		maxi(stamina_before - GameState.get_stat("stamina"), 0)
		if started
		else 0
	)
	return started


func cancel_current_attack(reason: String = "cancelled") -> void:
	super.cancel_current_attack(reason)
	_gesture_attack_stamina_spent = 0


func cancel_startup_attack_for_special(
	reason: String = "divine_special_chord"
) -> bool:
	if current_attack == null:
		return false
	if current_phase != "startup" or attack_hit_applied:
		return false
	var refund: int = _gesture_attack_stamina_spent
	# Call the base implementation directly so the tracked cost survives until
	# after the attack is fully cancelled.
	super.cancel_current_attack(reason)
	_gesture_attack_stamina_spent = 0
	if refund > 0:
		GameState.restore_stamina(refund)
	return true


func _on_safe_attack_finished(_attack_id: String) -> void:
	# The base controller emits before starting any buffered follow-up, so this
	# clears the completed attack without erasing the next attack's tracked cost.
	_gesture_attack_stamina_spent = 0


func _get_locked_weak_point(actor: Node3D, attack: WeaponAttackDefinition) -> Node:
	if actor == null or attack == null:
		return null
	var target_value: Variant = actor.get("lock_on_target")
	if not is_instance_valid(target_value):
		_clear_stale_lock_target(actor)
		return null
	if not (target_value is Node3D):
		return null
	var target: Node3D = target_value as Node3D
	if not is_instance_valid(target):
		_clear_stale_lock_target(actor)
		return null
	if target.is_queued_for_deletion():
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
	if not is_instance_valid(target):
		return Vector3.ZERO
	if target.is_queued_for_deletion():
		return Vector3.ZERO
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	if is_instance_valid(parent) and parent is Node3D:
		return (parent as Node3D).global_position
	return Vector3.ZERO


func _clear_stale_lock_target(actor: Node) -> void:
	if not is_instance_valid(actor):
		return
	if actor.has_method("clear_lock_on"):
		actor.call("clear_lock_on")
	else:
		actor.set("lock_on_target", null)
