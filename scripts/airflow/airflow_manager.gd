extends Node
class_name AirflowManager

signal airflow_sampled(world_position: Vector3, total_velocity: Vector3)

@export var maximum_combined_velocity: float = 32.0
@export var emit_sample_signal: bool = false
@export_range(0.1, 5.0, 0.1) var invalid_field_prune_interval: float = 0.75

var sample_count: int = 0
var last_sample_position: Vector3 = Vector3.ZERO
var last_total_velocity: Vector3 = Vector3.ZERO
var last_contributors: Array[String] = []
var registered_fields: Array[Node] = []
var prune_timer: float = 0.0


func _ready() -> void:
	add_to_group("airflow_manager")
	add_to_group("debuggable")
	call_deferred("refresh_registered_fields")


func _process(delta: float) -> void:
	prune_timer -= max(delta, 0.0)
	if prune_timer > 0.0:
		return
	prune_timer = max(invalid_field_prune_interval, 0.1)
	prune_invalid_fields()


func register_field(field_node: Node) -> void:
	if field_node == null or not is_instance_valid(field_node):
		return
	if not registered_fields.has(field_node):
		registered_fields.append(field_node)


func unregister_field(field_node: Node) -> void:
	registered_fields.erase(field_node)


func refresh_registered_fields() -> void:
	registered_fields.clear()
	for field_node: Node in get_tree().get_nodes_in_group("airflow_fields"):
		register_field(field_node)


func prune_invalid_fields() -> void:
	for index: int in range(registered_fields.size() - 1, -1, -1):
		var field_node: Node = registered_fields[index]
		if field_node == null or not is_instance_valid(field_node) or not field_node.is_inside_tree():
			registered_fields.remove_at(index)


func ensure_field_registry() -> void:
	if registered_fields.is_empty():
		refresh_registered_fields()


func get_registered_field_snapshot() -> Array[Node]:
	ensure_field_registry()
	return registered_fields.duplicate()


func sample_total_airflow(world_position: Vector3, sample_time: float = -1.0) -> Vector3:
	ensure_field_registry()
	var total_velocity: Vector3 = Vector3.ZERO
	last_contributors.clear()
	for field_node: Node in registered_fields:
		if field_node == null or not is_instance_valid(field_node):
			continue
		if not field_node.has_method("sample_air_velocity"):
			continue
		var contribution: Variant = field_node.call("sample_air_velocity", world_position, sample_time)
		if not (contribution is Vector3):
			continue
		var velocity: Vector3 = contribution as Vector3
		if velocity.length_squared() <= 0.000001:
			continue
		total_velocity += velocity
		last_contributors.append(str(field_node.get("field_id")) if field_node.get("field_id") != null else field_node.name)

	var speed_limit: float = max(maximum_combined_velocity, 0.0)
	if speed_limit > 0.0 and total_velocity.length_squared() > speed_limit * speed_limit:
		total_velocity = total_velocity.normalized() * speed_limit

	sample_count += 1
	last_sample_position = world_position
	last_total_velocity = total_velocity
	if emit_sample_signal:
		airflow_sampled.emit(world_position, total_velocity)
	return total_velocity


func sample_breakdown(world_position: Vector3, sample_time: float = -1.0) -> Array[Dictionary]:
	ensure_field_registry()
	var breakdown: Array[Dictionary] = []
	for field_node: Node in registered_fields:
		if field_node == null or not is_instance_valid(field_node):
			continue
		if not field_node.has_method("sample_air_velocity"):
			continue
		var contribution: Variant = field_node.call("sample_air_velocity", world_position, sample_time)
		if not (contribution is Vector3):
			continue
		var velocity: Vector3 = contribution as Vector3
		if velocity.length_squared() <= 0.000001:
			continue
		breakdown.append({
			"field_id": str(field_node.get("field_id")) if field_node.get("field_id") != null else field_node.name,
			"velocity": velocity,
			"speed": velocity.length(),
		})
	return breakdown


static func find_in_tree(context: Node) -> Node:
	if context == null or context.get_tree() == null:
		return null
	return context.get_tree().get_first_node_in_group("airflow_manager")


func get_debug_data() -> Dictionary:
	return {
		"airflow_manager": true,
		"field_count": registered_fields.size(),
		"sample_count": sample_count,
		"last_position": last_sample_position,
		"last_velocity": last_total_velocity,
		"last_speed": snapped(last_total_velocity.length(), 0.01),
		"contributors": last_contributors.duplicate(),
	}
