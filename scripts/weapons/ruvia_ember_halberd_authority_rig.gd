extends "res://scripts/weapons/ruvia_ember_halberd_rig.gd"
class_name RuviaEmberHalberdAuthorityRig

@export_range(0.5, 8.0, 0.1) var solar_spread_radius: float = 4.2
@export_range(0.1, 5.0, 0.1) var solar_spread_duration: float = 1.5
@export_range(0.1, 3.0, 0.05) var solar_spread_strength: float = 0.75
@export_range(0.5, 12.0, 0.1) var reaping_pull_strength: float = 5.2
@export_range(0.0, 4.0, 0.1) var reaping_pull_up_strength: float = 0.35

var authority_cast_active: bool = false
var authority_cast_id: String = ""
var authority_cast_progress: float = 0.0
var authority_cast_heat: float = 0.0
var solar_spread_count: int = 0
var total_solar_spread_count: int = 0
var reaping_pull_count: int = 0
var total_reaping_pull_count: int = 0

@onready var spear_tip_node: Node3D = get_node_or_null("SpearTip") as Node3D
@onready var butt_cap_node: Node3D = get_node_or_null("ButtCap") as Node3D
@onready var forward_grip_reference: Node3D = (
	get_node_or_null("ForwardGripReference") as Node3D
)


func _ready() -> void:
	super._ready()
	add_to_group("ruvia_fire_conduit")


func begin_authority_cast(ability_id: String, _duration: float) -> void:
	authority_cast_active = true
	authority_cast_id = ability_id
	authority_cast_progress = 0.0
	authority_cast_heat = 0.35
	_apply_conduit_heat()


func update_authority_cast(ability_id: String, progress: float) -> void:
	authority_cast_active = true
	authority_cast_id = ability_id
	authority_cast_progress = clampf(progress, 0.0, 1.0)
	var cast_wave: float = sin(authority_cast_progress * PI)
	authority_cast_heat = lerpf(0.45, 1.0, cast_wave)
	_apply_conduit_heat()


func end_authority_cast() -> void:
	authority_cast_active = false
	authority_cast_id = ""
	authority_cast_progress = 0.0
	authority_cast_heat = 0.0
	_apply_heat(active_heat, active_finisher)


func get_spell_cast_origin(ability_id: String = "") -> Vector3:
	if ability_id == "fire_field" and butt_cap_node != null:
		return butt_cap_node.global_position
	if spear_tip_node != null:
		return spear_tip_node.global_position
	if forward_grip_reference != null:
		return forward_grip_reference.global_position
	return global_position


func on_weapon_targets_hit(
	targets: Array[Node],
	attack: WeaponAttackDefinition
) -> void:
	super.on_weapon_targets_hit(targets, attack)
	reaping_pull_count = 0
	solar_spread_count = 0
	if attack == null or targets.is_empty() or weapon_controller == null:
		return
	if attack.attack_id == "ruvia_halberd_h2":
		_apply_reaping_hook_pull(targets)
	if attack.attack_id == "ruvia_halberd_h4":
		_apply_solar_descent_spread(targets)


func _apply_reaping_hook_pull(targets: Array[Node]) -> void:
	var actor: Node3D = weapon_controller.get_actor()
	if actor == null:
		return
	for target: Node in targets:
		if target == null or not is_instance_valid(target):
			continue
		var target_body: CharacterBody3D = _find_character_body(target)
		var target_position: Vector3 = (
			target_body.global_position
			if target_body != null
			else _get_target_position(target)
		)
		var pull_direction: Vector3 = actor.global_position - target_position
		pull_direction.y = 0.0
		if pull_direction.length_squared() <= 0.001:
			continue
		pull_direction = pull_direction.normalized()
		var motion_target: Node = target_body if target_body != null else target
		var force_receiver: Node = _find_named_component(
			motion_target,
			"ForceReceiver"
		)
		if force_receiver != null and force_receiver.has_method("apply_impulse"):
			force_receiver.call(
				"apply_impulse",
				pull_direction,
				reaping_pull_strength,
				reaping_pull_up_strength,
				"Ruvia • Reaping Hook"
			)
			reaping_pull_count += 1
		elif "recoil_velocity" in motion_target:
			var recoil_value: Variant = motion_target.get("recoil_velocity")
			if recoil_value is Vector3:
				motion_target.set(
					"recoil_velocity",
					(recoil_value as Vector3)
					+ pull_direction * reaping_pull_strength
				)
				reaping_pull_count += 1
		elif target_body != null:
			target_body.velocity += (
				pull_direction * reaping_pull_strength
				+ Vector3.UP * reaping_pull_up_strength
			)
			reaping_pull_count += 1
	total_reaping_pull_count += reaping_pull_count


func _apply_solar_descent_spread(targets: Array[Node]) -> void:
	var actor: Node3D = weapon_controller.get_actor()
	if actor == null:
		return
	var excluded_ids: Dictionary = {}
	for target: Node in targets:
		if target != null and is_instance_valid(target):
			excluded_ids[target.get_instance_id()] = true
	for candidate: Node in get_tree().get_nodes_in_group("enemy"):
		if not candidate is Node3D:
			continue
		var enemy: Node3D = candidate as Node3D
		if excluded_ids.has(enemy.get_instance_id()):
			continue
		if enemy.global_position.distance_to(actor.global_position) > solar_spread_radius:
			continue
		var status_receiver: Node = enemy.get_node_or_null("StatusReceiver")
		if status_receiver == null:
			status_receiver = _find_status_receiver(enemy)
		if status_receiver == null:
			continue
		if status_receiver.has_method("sustain_status"):
			status_receiver.call(
				"sustain_status",
				"burning",
				solar_spread_duration,
				solar_spread_strength,
				"Ruvia • Solar Descent"
			)
			solar_spread_count += 1
		elif status_receiver.has_method("apply_status"):
			status_receiver.call(
				"apply_status",
				"burning",
				solar_spread_duration,
				solar_spread_strength,
				"Ruvia • Solar Descent"
			)
			solar_spread_count += 1
	total_solar_spread_count += solar_spread_count


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["fire_conduit"] = true
	data["spell_cast_origin"] = get_spell_cast_origin(authority_cast_id)
	data["authority_cast_active"] = authority_cast_active
	data["authority_cast_id"] = authority_cast_id if authority_cast_active else "none"
	data["authority_cast_progress"] = snappedf(authority_cast_progress, 0.01)
	data["authority_cast_heat"] = snappedf(authority_cast_heat, 0.01)
	data["solar_spread_count"] = solar_spread_count
	data["total_solar_spread_count"] = total_solar_spread_count
	data["reaping_pull_count"] = reaping_pull_count
	data["total_reaping_pull_count"] = total_reaping_pull_count
	return data


func _apply_conduit_heat() -> void:
	var resolved_heat: float = maxf(active_heat, authority_cast_heat)
	var finisher: bool = active_finisher or authority_cast_id == "fire_field"
	_apply_heat(resolved_heat, finisher)


func _find_status_receiver(root: Node) -> Node:
	return _find_named_component(root, "StatusReceiver")


func _find_named_component(root: Node, component_name: String) -> Node:
	if root == null:
		return null
	if root.name == component_name:
		return root
	var direct: Node = root.get_node_or_null(component_name)
	if direct != null:
		return direct
	for child: Node in root.get_children():
		var deeper: Node = _find_named_component(child, component_name)
		if deeper != null:
			return deeper
	return null


func _find_character_body(root: Node) -> CharacterBody3D:
	var current: Node = root
	while current != null:
		if current is CharacterBody3D:
			return current as CharacterBody3D
		current = current.get_parent()
	return null


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent() if target != null else null
	if parent is Node3D:
		return (parent as Node3D).global_position
	return global_position
