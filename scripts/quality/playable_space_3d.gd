extends Node3D
class_name PlayableSpace3D

signal recovery_anchor_changed(anchor_id: String, recovery_transform: Transform3D)

@export var use_bounds: bool = false
@export var bounds_center: Vector3 = Vector3.ZERO
@export var bounds_size: Vector3 = Vector3(100.0, 40.0, 100.0)
@export var minimum_recovery_y: float = -24.0
@export var default_recovery_path: NodePath

@export_group("Last-resort Boundaries")
@export var generate_boundary_collision: bool = false
@export var boundary_thickness: float = 1.0
@export var boundary_height: float = 16.0
@export var boundary_collision_layer: int = 1

var default_recovery_transform: Transform3D = Transform3D.IDENTITY
var active_recovery_transform: Transform3D = Transform3D.IDENTITY
var default_recovery_set: bool = false
var active_recovery_set: bool = false
var active_anchor_id: String = ""
var generated_boundaries: Node3D


func _ready() -> void:
	add_to_group("playable_space")
	if default_recovery_path != NodePath():
		var anchor: Node3D = get_node_or_null(default_recovery_path) as Node3D
		if anchor != null:
			set_default_recovery_anchor(anchor)
	if generate_boundary_collision:
		call_deferred("build_generated_boundaries")


func contains_position(world_position: Vector3) -> bool:
	if not use_bounds:
		return true
	var local_position: Vector3 = to_local(world_position)
	var safe_size := Vector3(
		maxf(bounds_size.x, 0.01),
		maxf(bounds_size.y, 0.01),
		maxf(bounds_size.z, 0.01)
	)
	var bounds := AABB(bounds_center - safe_size * 0.5, safe_size)
	return bounds.has_point(local_position)


func is_position_forbidden(world_position: Vector3) -> bool:
	if get_tree() == null:
		return false
	var current_scene: Node = get_tree().current_scene
	for volume: Node in get_tree().get_nodes_in_group("playable_forbidden_volume"):
		if current_scene != null and volume != current_scene and not current_scene.is_ancestor_of(volume):
			continue
		if volume.has_method("contains_world_point") and bool(volume.call("contains_world_point", world_position)):
			return true
	return false


func is_position_allowed(world_position: Vector3) -> bool:
	if world_position.y < minimum_recovery_y:
		return false
	if not contains_position(world_position):
		return false
	return not is_position_forbidden(world_position)


func set_default_recovery_anchor(anchor: Node3D) -> void:
	if anchor == null:
		return
	set_default_recovery_transform(anchor.global_transform)


func set_default_recovery_transform(value: Transform3D) -> void:
	default_recovery_transform = value
	default_recovery_set = true
	if not active_recovery_set:
		recovery_anchor_changed.emit("default", default_recovery_transform)


func set_active_recovery_transform(
	value: Transform3D,
	anchor_id: String = "checkpoint"
) -> void:
	active_recovery_transform = value
	active_recovery_set = true
	active_anchor_id = anchor_id
	recovery_anchor_changed.emit(active_anchor_id, active_recovery_transform)


func clear_active_recovery_transform() -> void:
	active_recovery_set = false
	active_anchor_id = ""
	if default_recovery_set:
		recovery_anchor_changed.emit("default", default_recovery_transform)


func has_recovery_anchor() -> bool:
	return active_recovery_set or default_recovery_set


func get_recovery_transform(fallback: Transform3D = Transform3D.IDENTITY) -> Transform3D:
	if active_recovery_set:
		return active_recovery_transform
	if default_recovery_set:
		return default_recovery_transform
	return fallback


func build_generated_boundaries() -> void:
	if generated_boundaries != null and is_instance_valid(generated_boundaries):
		return
	generated_boundaries = Node3D.new()
	generated_boundaries.name = "GeneratedSafetyBoundaries"
	add_child(generated_boundaries)
	var thickness: float = maxf(boundary_thickness, 0.1)
	var height: float = maxf(boundary_height, bounds_size.y, 2.0)
	var half: Vector3 = bounds_size * 0.5
	var center_y: float = bounds_center.y
	_create_boundary_box(
		"BoundaryWest",
		Vector3(thickness, height, bounds_size.z + thickness * 2.0),
		Vector3(bounds_center.x - half.x - thickness * 0.5, center_y, bounds_center.z)
	)
	_create_boundary_box(
		"BoundaryEast",
		Vector3(thickness, height, bounds_size.z + thickness * 2.0),
		Vector3(bounds_center.x + half.x + thickness * 0.5, center_y, bounds_center.z)
	)
	_create_boundary_box(
		"BoundaryNorth",
		Vector3(bounds_size.x + thickness * 2.0, height, thickness),
		Vector3(bounds_center.x, center_y, bounds_center.z - half.z - thickness * 0.5)
	)
	_create_boundary_box(
		"BoundarySouth",
		Vector3(bounds_size.x + thickness * 2.0, height, thickness),
		Vector3(bounds_center.x, center_y, bounds_center.z + half.z + thickness * 0.5)
	)


func _create_boundary_box(node_name: String, size: Vector3, position_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = boundary_collision_layer
	body.set_meta("generated_playable_boundary", true)
	generated_boundaries.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func get_debug_data() -> Dictionary:
	return {
		"bounds_enabled": use_bounds,
		"bounds_center": bounds_center,
		"bounds_size": bounds_size,
		"minimum_y": minimum_recovery_y,
		"anchor": active_anchor_id if active_recovery_set else "default",
		"has_anchor": has_recovery_anchor(),
		"generated_boundaries": generated_boundaries != null,
	}
