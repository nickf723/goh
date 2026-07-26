extends Resource
class_name AirbornePresentationProfile

@export var profile_id: String = "medium"
@export var display_name: String = "Standard"

@export_group("Flight Pose")
@export var launch_rotation_degrees: Vector3 = Vector3(-18.0, 0.0, 12.0)
@export var spin_degrees_per_second: Vector3 = Vector3(110.0, 70.0, 145.0)
@export var falling_rotation_degrees: Vector3 = Vector3(42.0, 0.0, 28.0)
@export var plunge_rotation_degrees: Vector3 = Vector3(78.0, 0.0, 8.0)
@export var airborne_scale: Vector3 = Vector3(0.98, 1.04, 0.98)
@export var pose_response: float = 10.0

@export_group("Impact Pose")
@export var bounce_scale: Vector3 = Vector3(1.08, 0.74, 1.08)
@export var landing_rotation_degrees: Vector3 = Vector3(24.0, 0.0, 12.0)
@export var landing_scale: Vector3 = Vector3(1.05, 0.82, 1.05)
@export var landing_drop: float = 0.16
@export var bounce_pose_time: float = 0.16
@export var landing_recover_time: float = 0.28

@export_group("Reaction Rhythm")
@export var bounce_height_multiplier: float = 1.0
@export var landing_recovery_multiplier: float = 1.0
@export var juggle_resistance_multiplier: float = 1.0
@export var air_hitstun_multiplier: float = 1.0

func get_spin_radians_per_second() -> Vector3:
	return Vector3(
		deg_to_rad(spin_degrees_per_second.x),
		deg_to_rad(spin_degrees_per_second.y),
		deg_to_rad(spin_degrees_per_second.z)
	)

func get_rotation_radians(rotation_degrees: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y),
		deg_to_rad(rotation_degrees.z)
	)

func get_debug_summary() -> String:
	return display_name + " | spin " + str(roundi(spin_degrees_per_second.length())) + " deg/s"
