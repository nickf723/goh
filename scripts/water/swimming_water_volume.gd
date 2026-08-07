extends Area3D
class_name SwimmingWaterVolume

@export var surface_height_offset: float = 3.0
@export var current_velocity: Vector3 = Vector3.ZERO
@export var swirl_strength: float = 0.0
@export var inward_strength: float = 0.0
@export var water_label: String = "Water"

var frozen_surface_sample_count: int = 0
var successful_frozen_surface_samples: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("swimming_water_volume")
	add_to_group("freezable_water_volume")


func get_surface_y() -> float:
	return global_position.y + surface_height_offset


func sample_current(world_position: Vector3) -> Vector3:
	var result: Vector3 = current_velocity
	var radial: Vector3 = world_position - global_position
	radial.y = 0.0
	if radial.length_squared() > 0.001:
		var radial_direction: Vector3 = radial.normalized()
		var tangent := Vector3(
			-radial_direction.z,
			0.0,
			radial_direction.x
		)
		result += tangent * swirl_strength
		result -= radial_direction * inward_strength
	return result


func get_frozen_surface_sample(
	world_position: Vector3,
	horizontal_margin: float = 0.0
) -> Dictionary:
	frozen_surface_sample_count += 1
	if not contains_horizontal_position(world_position, horizontal_margin):
		return {
			"found": false,
			"volume": self,
			"surface_y": get_surface_y(),
		}
	successful_frozen_surface_samples += 1
	return {
		"found": true,
		"volume": self,
		"surface_y": get_surface_y(),
		"position": Vector3(
			world_position.x,
			get_surface_y(),
			world_position.z
		),
		"normal": Vector3.UP,
		"support_kind": "water",
		"water_label": water_label,
	}


func contains_horizontal_position(
	world_position: Vector3,
	horizontal_margin: float = 0.0
) -> bool:
	var collision_shapes: Array[CollisionShape3D] = []
	_collect_collision_shapes(self, collision_shapes)
	for collision_shape: CollisionShape3D in collision_shapes:
		if (
			collision_shape == null
			or not is_instance_valid(collision_shape)
			or collision_shape.disabled
			or collision_shape.shape == null
		):
			continue
		var sample_world := Vector3(
			world_position.x,
			collision_shape.global_position.y,
			world_position.z
		)
		var local_position: Vector3 = (
			collision_shape.global_transform.affine_inverse()
			* sample_world
		)
		if _shape_contains_horizontal_position(
			collision_shape.shape,
			local_position,
			maxf(horizontal_margin, 0.0)
		):
			return true
	return false


func _shape_contains_horizontal_position(
	shape: Shape3D,
	local_position: Vector3,
	margin: float
) -> bool:
	if shape is BoxShape3D:
		var size: Vector3 = (shape as BoxShape3D).size
		return (
			absf(local_position.x) <= size.x * 0.5 + margin
			and absf(local_position.z) <= size.z * 0.5 + margin
		)
	if shape is SphereShape3D:
		var radius: float = (shape as SphereShape3D).radius + margin
		return Vector2(local_position.x, local_position.z).length_squared() <= radius * radius
	if shape is CylinderShape3D:
		var cylinder_radius: float = (
			(shape as CylinderShape3D).radius + margin
		)
		return (
			Vector2(local_position.x, local_position.z).length_squared()
			<= cylinder_radius * cylinder_radius
		)
	if shape is CapsuleShape3D:
		var capsule_radius: float = (
			(shape as CapsuleShape3D).radius + margin
		)
		return (
			Vector2(local_position.x, local_position.z).length_squared()
			<= capsule_radius * capsule_radius
		)
	return false


func _collect_collision_shapes(
	root: Node,
	target: Array[CollisionShape3D]
) -> void:
	for child: Node in root.get_children():
		if child is CollisionShape3D:
			target.append(child as CollisionShape3D)
		_collect_collision_shapes(child, target)


func _on_body_entered(body: Node3D) -> void:
	var controller: Node = body.get_node_or_null("SwimmingController")
	if controller != null and controller.has_method("enter_water"):
		controller.call("enter_water", self)


func _on_body_exited(body: Node3D) -> void:
	var controller: Node = body.get_node_or_null("SwimmingController")
	if controller != null and controller.has_method("exit_water"):
		controller.call("exit_water", self)


func get_debug_data() -> Dictionary:
	return {
		"label": water_label,
		"surface_y": snappedf(get_surface_y(), 0.01),
		"current": current_velocity,
		"swirl": swirl_strength,
		"inward": inward_strength,
		"freezable": is_in_group("freezable_water_volume"),
		"frozen_surface_samples": frozen_surface_sample_count,
		"successful_frozen_samples": successful_frozen_surface_samples,
	}
