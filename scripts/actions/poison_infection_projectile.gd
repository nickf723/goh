extends "res://scripts/actions/generic_projectile_safe.gd"
class_name PoisonInfectionProjectile

const InfectionVisuals = preload("res://scripts/visuals/element_visuals.gd")

signal infection_transferred(target: Node, statuses: Array[String])
signal infection_arrived_clean(target: Node)

@export_group("Infection Delivery")
@export_range(4.0, 40.0, 0.5) var projectile_speed: float = 20.0
@export_range(0.5, 6.0, 0.05) var projectile_lifetime: float = 3.0
@export_range(0.1, 1.5, 0.05) var duration_scale: float = 0.72
@export_range(0.1, 1.5, 0.05) var strength_scale: float = 0.86
@export_range(0.1, 2.0, 0.05) var minimum_transfer_duration: float = 0.65
@export_range(1, 12, 1) var maximum_transferred_statuses: int = 6

var carried_debuffs: Array[Dictionary] = []
var last_transferred_statuses: Array[String] = []
var source_snapshot_count: int = 0
var last_target_had_receiver: bool = false


func _ready() -> void:
	speed = projectile_speed
	max_lifetime = projectile_lifetime
	respond_to_airflow = true
	destroy_on_hit = true
	hit_limit = 1
	show_miss_feedback = true
	trail_interval = 0.055
	super._ready()


func set_source_actor(new_source_actor: Node) -> void:
	super.set_source_actor(new_source_actor)
	_capture_source_debuffs()


func get_element() -> String:
	return "poison"


func try_hit(raw_target: Node) -> void:
	var target: Node = find_payload_target(raw_target)
	if target == null or not is_instance_valid(target):
		return
	if should_ignore_target(target):
		return
	var target_id: int = target.get_instance_id()
	if hit_targets.has(target_id):
		return
	hit_targets[target_id] = true
	hit_count += 1

	var receiver: Node = _find_status_receiver(target)
	last_target_had_receiver = receiver != null
	last_transferred_statuses.clear()
	if receiver != null:
		_apply_carried_debuffs(receiver)

	InfectionVisuals.spawn_impact(
		get_tree(),
		global_position,
		"poison",
		0.72 if carried_debuffs.is_empty() else 1.05
	)

	if last_transferred_statuses.is_empty():
		infection_arrived_clean.emit(target)
	else:
		infection_transferred.emit(target, last_transferred_statuses.duplicate())
	queue_free()


func _capture_source_debuffs() -> void:
	carried_debuffs.clear()
	source_snapshot_count = 0
	if source_actor == null or not is_instance_valid(source_actor):
		return
	var receiver: Node = source_actor.get_node_or_null("StatusReceiver")
	if receiver == null or not receiver.has_method("get_transferable_debuffs"):
		return
	var snapshot_value: Variant = receiver.call("get_transferable_debuffs")
	if not snapshot_value is Array:
		return
	for row_value: Variant in snapshot_value as Array:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = (row_value as Dictionary).duplicate(true)
		var status_name: String = str(row.get("status", "")).strip_edges().to_lower()
		var duration: float = maxf(float(row.get("duration", 0.0)), 0.0)
		if status_name == "" or duration <= 0.0:
			continue
		carried_debuffs.append(row)
		if carried_debuffs.size() >= maximum_transferred_statuses:
			break
	source_snapshot_count = carried_debuffs.size()


func _apply_carried_debuffs(receiver: Node) -> void:
	if receiver == null or not receiver.has_method("apply_status"):
		return
	var transfer_source: String = "Infection"
	if source_actor != null and is_instance_valid(source_actor):
		transfer_source += ":" + str(source_actor.name)

	for row: Dictionary in carried_debuffs:
		var status_name: String = str(row.get("status", "")).strip_edges().to_lower()
		if status_name == "":
			continue
		var duration: float = maxf(
			float(row.get("duration", 0.0)) * duration_scale,
			minimum_transfer_duration
		)
		var strength: float = maxf(
			float(row.get("strength", 1.0)) * strength_scale,
			0.0
		)
		receiver.call(
			"apply_status",
			status_name,
			duration,
			strength,
			transfer_source
		)
		last_transferred_statuses.append(status_name)


func _find_status_receiver(target: Node) -> Node:
	if target == null or not is_instance_valid(target):
		return null
	if target.has_method("apply_status"):
		return target
	var receiver: Node = target.get_node_or_null("StatusReceiver")
	if receiver != null and receiver.has_method("apply_status"):
		return receiver
	var nested: Node = target.find_child("StatusReceiver", true, false)
	if nested != null and nested.has_method("apply_status"):
		return nested
	return null


func get_debug_data() -> Dictionary:
	var data: Dictionary = get_airflow_debug_data()
	data["spell"] = "infection"
	data["status_transfer_contract"] = true
	data["snapshot_count"] = source_snapshot_count
	data["carried_statuses"] = _carried_status_names()
	data["last_transferred_statuses"] = last_transferred_statuses.duplicate()
	data["last_target_had_receiver"] = last_target_had_receiver
	data["direct_damage"] = false
	data["fabricates_status_when_clean"] = false
	return data


func _carried_status_names() -> Array[String]:
	var names: Array[String] = []
	for row: Dictionary in carried_debuffs:
		var status_name: String = str(row.get("status", ""))
		if status_name != "":
			names.append(status_name)
	return names
