extends "res://scripts/player/player_controller.gd"

@export_range(0.0, 1.0, 0.01) var unlocked_cast_max_upward_component: float = 0.45


func get_lock_on_cast_direction(cast_origin: Vector3 = Vector3.ZERO) -> Vector3:
	if has_lock_on_target():
		return super.get_lock_on_cast_direction(cast_origin)

	var cast_direction: Vector3 = -global_transform.basis.z
	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera != null:
		cast_direction = -camera.global_transform.basis.z

	# The third-person camera normally looks slightly down at Grace. Passing that
	# full pitch to a chest-height projectile sends unlocked casts into the floor.
	# Keep camera-relative heading and upward aim, but make downward free aim level.
	cast_direction.y = clamp(cast_direction.y, 0.0, unlocked_cast_max_upward_component)

	if cast_direction.length() <= 0.01:
		cast_direction = -global_transform.basis.z
		cast_direction.y = 0.0

	if cast_direction.length() <= 0.01:
		return Vector3.FORWARD

	return cast_direction.normalized()
