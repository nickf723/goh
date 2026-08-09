extends Resource
class_name CameraProfile

@export var profile_id: String = "default_camera"
@export var display_name: String = "Default Camera"

@export_group("Exploration")
@export_range(2.0, 12.0, 0.05) var base_distance: float = 6.35
@export_range(40.0, 110.0, 0.1) var base_fov: float = 72.0
@export_range(0.0, 2.0, 0.01) var pivot_height: float = 0.56
@export_range(0.0, 2.5, 0.01) var speed_distance_bonus: float = 0.48
@export_range(0.0, 12.0, 0.1) var speed_fov_bonus: float = 3.2
@export_range(0.0, 1.0, 0.01) var lateral_lead: float = 0.15
@export_range(0.0, 1.0, 0.01) var forward_lead: float = 0.16
@export_range(1.0, 20.0, 0.1) var reference_run_speed: float = 6.5

@export_group("Context Framing")
@export_range(2.0, 12.0, 0.05) var aim_distance: float = 5.55
@export_range(40.0, 110.0, 0.1) var aim_fov: float = 68.5
@export_range(0.0, 2.0, 0.01) var aim_pivot_height: float = 0.64
@export_range(2.0, 12.0, 0.05) var climb_distance: float = 4.85
@export_range(40.0, 110.0, 0.1) var climb_fov: float = 68.0
@export_range(0.0, 2.0, 0.01) var climb_pivot_height: float = 0.76
@export_range(2.0, 12.0, 0.05) var swim_distance: float = 6.30
@export_range(40.0, 110.0, 0.1) var swim_fov: float = 73.0
@export_range(0.0, 2.0, 0.01) var swim_pivot_height: float = 0.52
@export_range(2.0, 12.0, 0.05) var flight_distance: float = 7.10
@export_range(40.0, 110.0, 0.1) var flight_fov: float = 77.0
@export_range(0.0, 2.0, 0.01) var flight_pivot_height: float = 0.68
@export_range(2.0, 12.0, 0.05) var dodge_distance: float = 6.85
@export_range(40.0, 110.0, 0.1) var dodge_fov: float = 76.5
@export_range(2.0, 12.0, 0.05) var defeated_distance: float = 5.20
@export_range(40.0, 110.0, 0.1) var defeated_fov: float = 64.0

@export_group("Lock On")
@export_range(2.0, 12.0, 0.05) var lock_on_min_distance: float = 5.55
@export_range(2.0, 14.0, 0.05) var lock_on_max_distance: float = 7.25
@export_range(40.0, 110.0, 0.1) var lock_on_min_fov: float = 68.5
@export_range(40.0, 110.0, 0.1) var lock_on_max_fov: float = 73.0
@export_range(1.0, 30.0, 0.1) var lock_on_near_range: float = 2.5
@export_range(1.0, 40.0, 0.1) var lock_on_far_range: float = 16.0
@export_range(0.0, 2.0, 0.01) var lock_on_pivot_height: float = 0.64

@export_group("Vertical Composition")
@export_range(0.0, 0.8, 0.01) var upward_pivot_bonus: float = 0.08
@export_range(0.0, 0.8, 0.01) var falling_pivot_drop: float = 0.13
@export_range(1.0, 30.0, 0.1) var vertical_reference_speed: float = 9.0

@export_group("Transient Motion")
@export_range(0.0, 1.0, 0.01) var acceleration_fov_bonus: float = 0.65
@export_range(0.0, 2.0, 0.01) var landing_distance_compression: float = 0.24
@export_range(0.0, 1.0, 0.01) var landing_pivot_drop: float = 0.055
@export_range(0.1, 6.0, 0.05) var landing_recovery_speed: float = 2.8

@export_group("Smoothing")
@export_range(0.1, 30.0, 0.1) var distance_smoothing: float = 7.5
@export_range(0.1, 30.0, 0.1) var fov_smoothing: float = 6.5
@export_range(0.1, 30.0, 0.1) var pivot_smoothing: float = 8.0
@export_range(0.1, 30.0, 0.1) var lead_smoothing: float = 7.0


func get_debug_data() -> Dictionary:
	return {
		"camera_profile": true,
		"profile_id": profile_id,
		"base_distance": base_distance,
		"base_fov": base_fov,
		"speed_distance_bonus": speed_distance_bonus,
		"speed_fov_bonus": speed_fov_bonus,
		"lock_on_distance_range": Vector2(lock_on_min_distance, lock_on_max_distance),
		"flight_distance": flight_distance,
		"aim_distance": aim_distance,
	}
