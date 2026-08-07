extends "res://scripts/actions/water_jet_cast_ready.gd"
class_name WaterJetCastContactSafe

# The center obstruction ray is authoritative for the visible endpoint. A shape
# query that ends exactly at that contact can miss the touching body because the
# two shapes only overlap by a tiny numerical skin. Always include the ray's
# first valid effect target, then use the cylinder query for everything else in
# the stream.

@export_group("Endpoint Contact")
@export_range(0.0, 0.5, 0.01) var contact_query_margin: float = 0.08

@export_group("Rigid Body Pressure")
@export_range(0.0, 30.0, 0.1) var rigid_body_maximum_speed: float = 10.0

var endpoint_target_addition_count: int = 0
var rigid_body_pressure_count: int = 0
var frozen_rigid_body_skip_count: int = 0
var last_rigid_body_name: String = "none"
var last_rigid_body_speed: float = 0.0


func _ready() -> void:
	super._ready()
	if cached_stream_query != null:
		cached_stream_query.margin = maxf(contact_query_margin, 0.0)


func _collect_stream_targets(
	origin: Vector3,
	direction: Vector3,
	stream_length: float
) -> Array[Node]:
	var targets: Array[Node] = super._collect_stream_targets(
		origin,
		direction,
		stream_length
	)
	var endpoint_target: Node = _resolve_current_endpoint_target()
	if endpoint_target != null and not targets.has(endpoint_target):
		targets.append(endpoint_target)
		endpoint_target_addition_count += 1
	return targets


func _resolve_current_endpoint_target() -> Node:
	if not bool(current_hit.get("valid", false)):
		return null
	var collider_value: Variant = current_hit.get("collider")
	if not collider_value is Node:
		return null
	return _resolve_effect_target(collider_value as Node)


func _apply_pressure_scan(
	targets: Array[Node],
	direction_value: Vector3
) -> void:
	var movable_targets: Array[Node] = []
	var rigid_targets: Array[RigidBody3D] = []
	for target: Node in targets:
		if target is RigidBody3D:
			var rigid_body: RigidBody3D = target as RigidBody3D
			if rigid_body.freeze:
				frozen_rigid_body_skip_count += 1
				continue
			rigid_body.sleeping = false
			rigid_targets.append(rigid_body)
		movable_targets.append(target)

	super._apply_pressure_scan(movable_targets, direction_value)

	for rigid_body: RigidBody3D in rigid_targets:
		if not is_instance_valid(rigid_body):
			continue
		var speed_limit: float = maxf(rigid_body_maximum_speed, 0.0)
		if speed_limit > 0.0 and rigid_body.linear_velocity.length() > speed_limit:
			rigid_body.linear_velocity = (
				rigid_body.linear_velocity.normalized() * speed_limit
			)
		rigid_body_pressure_count += 1
		last_rigid_body_name = str(rigid_body.name)
		last_rigid_body_speed = rigid_body.linear_velocity.length()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["endpoint_contact_guarantee"] = true
	data["contact_query_margin"] = contact_query_margin
	data["endpoint_target_additions"] = endpoint_target_addition_count
	data["rigid_body_force_per_second"] = rigid_body_force_per_second
	data["rigid_body_maximum_speed"] = rigid_body_maximum_speed
	data["rigid_body_pressure_events"] = rigid_body_pressure_count
	data["frozen_rigid_body_skips"] = frozen_rigid_body_skip_count
	data["last_rigid_body"] = last_rigid_body_name
	data["last_rigid_body_speed"] = snappedf(last_rigid_body_speed, 0.01)
	return data
