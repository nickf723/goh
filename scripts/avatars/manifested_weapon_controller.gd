extends "res://scripts/weapons/safe_weapon_controller.gd"
class_name ManifestedWeaponController


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("manifested_avatar_weapon_controller")
	set_process_unhandled_input(false)
	if weapon_visual_pivot != null:
		base_visual_position = weapon_visual_pivot.position
		base_visual_rotation_degrees = weapon_visual_pivot.rotation_degrees
	setup_slash_trail()
	refresh_weapon_visual()
	emit_weapon_changed()


func _exit_tree() -> void:
	pass


func _unhandled_input(_event: InputEvent) -> void:
	pass


func start_attack(attack: WeaponAttackDefinition) -> bool:
	if attack == null:
		return false
	var runtime_attack: WeaponAttackDefinition = (
		attack.duplicate(true) as WeaponAttackDefinition
	)
	if runtime_attack == null:
		return false
	runtime_attack.stamina_cost = 0
	return super.start_attack(runtime_attack)


func resolve_attack_forward(_attack: WeaponAttackDefinition) -> Vector3:
	attack_forward_override = Vector3.ZERO
	var resolved: Vector3 = get_attack_forward()
	return (
		resolved.normalized()
		if resolved.length_squared() > 0.001
		else Vector3.FORWARD
	)


func apply_attack_facing(direction: Vector3) -> void:
	var actor: Node3D = get_actor()
	if actor == null or direction.length_squared() <= 0.001:
		return
	var planar: Vector3 = direction
	planar.y = 0.0
	if planar.length_squared() <= 0.001:
		return
	actor.rotation.y = atan2(-planar.normalized().x, -planar.normalized().z)


func find_targets(attack: WeaponAttackDefinition) -> Array[Node]:
	var candidates: Array[Node] = super.find_targets(attack)
	var filtered: Array[Node] = []
	for target: Node in candidates:
		if _is_friendly_target(target):
			continue
		filtered.append(target)
	return filtered


func award_weapon_mastery(
	_attack: WeaponAttackDefinition,
	_critical_landed: bool
) -> void:
	pass


func apply_camera_impact(
	_attack: WeaponAttackDefinition,
	_critical: bool
) -> void:
	pass


func apply_infusion_visuals() -> void:
	# A manifested god keeps the signature weapon's authored presentation instead of
	# inheriting Grace's currently equipped infusion.
	pass


func get_infusion_attack_color(base_color: Color) -> Color:
	return base_color


func show_message(_text: String) -> void:
	pass


func _is_friendly_target(target: Node) -> bool:
	if target == null:
		return false
	var root: Node = target
	while root.get_parent() != null and not root is CharacterBody3D:
		root = root.get_parent()
	if root.is_in_group("friendly_actor") or root.is_in_group("player"):
		return true
	var actor: Node3D = get_actor()
	if actor == null:
		return false
	var owner_instance_id: int = int(
		actor.get_meta("manifestation_owner_instance_id", -1)
	)
	return owner_instance_id >= 0 and root.get_instance_id() == owner_instance_id
