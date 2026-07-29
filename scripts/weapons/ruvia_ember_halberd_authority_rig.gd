extends "res://scripts/weapons/ruvia_ember_halberd_rig.gd"
class_name RuviaEmberHalberdAuthorityRig

@export_range(0.5, 8.0, 0.1) var solar_spread_radius: float = 4.2
@export_range(0.1, 5.0, 0.1) var solar_spread_duration: float = 1.5
@export_range(0.1, 3.0, 0.05) var solar_spread_strength: float = 0.75

var authority_cast_active: bool = false
var authority_cast_id: String = ""
var authority_cast_progress: float = 0.0
var authority_cast_heat: float = 0.0
var solar_spread_count: int = 0
var total_solar_spread_count: int = 0

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
	solar_spread_count = 0
	if (
		attack == null
		or attack.attack_id != "ruvia_halberd_h4"
		or targets.is_empty()
		or weapon_controller == null
	):
		return
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
	return data


func _apply_conduit_heat() -> void:
	var resolved_heat: float = maxf(active_heat, authority_cast_heat)
	var finisher: bool = active_finisher or authority_cast_id == "fire_field"
	_apply_heat(resolved_heat, finisher)


func _find_status_receiver(root: Node) -> Node:
	if root == null:
		return null
	for child: Node in root.get_children():
		if child.name == "StatusReceiver":
			return child
		var deeper: Node = _find_status_receiver(child)
		if deeper != null:
			return deeper
	return null
