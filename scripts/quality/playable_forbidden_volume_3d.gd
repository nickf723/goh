extends Area3D
class_name PlayableForbiddenVolume3D

@export var active: bool = true


func _ready() -> void:
	collision_layer = 1 << 30
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("playable_forbidden_volume")


func set_active(value: bool) -> void:
	active = value
	monitorable = active


func contains_world_point(world_point: Vector3) -> bool:
	if not active:
		return false
	for child: Node in get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.disabled or collision.shape == null:
			continue
		var local_point: Vector3 = collision.to_local(world_point)
		if _shape_contains(collision.shape, local_point):
			return true
	return false


func _shape_contains(shape: Shape3D, point: Vector3) -> bool:
	if shape is BoxShape3D:
		var half_size: Vector3 = (shape as BoxShape3D).size * 0.5
		return (
			absf(point.x) <= half_size.x
			and absf(point.y) <= half_size.y
			and absf(point.z) <= half_size.z
		)
	if shape is SphereShape3D:
		return point.length() <= (shape as SphereShape3D).radius
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return absf(point.y) <= cylinder.height * 0.5 and Vector2(point.x, point.z).length() <= cylinder.radius
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		var half_segment: float = maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		var closest_y: float = clampf(point.y, -half_segment, half_segment)
		return Vector3(point.x, point.y - closest_y, point.z).length() <= capsule.radius
	return false


func get_debug_data() -> Dictionary:
	return {
		"active": active,
		"shapes": get_child_count(),
		"position": global_position,
	}
