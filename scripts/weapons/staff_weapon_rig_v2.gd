extends "res://scripts/weapons/staff_weapon_rig_v1.gd"
class_name StaffWeaponRigV2

# V1 accumulated a spin value, but Euler rotation placed most of that motion on
# the staff's own long axis. A symmetrical pole therefore looked almost frozen.
# V2 builds the guard orientation with explicit quaternions: first stand the
# staff upright, then rotate that upright pole through the vertical plane in
# front of Grace. The planted hand is the pivot and the support-grip marker rides
# the staff, so the second hand can visibly feed the twirl through IK.

@export_group("Whirling Bastion")
@export_range(180.0, 1200.0, 10.0) var guard_spin_min_degrees_per_second: float = 520.0
@export_range(300.0, 1600.0, 10.0) var guard_spin_max_degrees_per_second: float = 920.0
@export_range(-30.0, 30.0, 1.0) var guard_plane_yaw_degrees: float = 9.0
@export_range(0.0, 0.12, 0.005) var guard_hand_orbit_radius: float = 0.035
@export_range(0.0, 0.08, 0.005) var guard_depth_bob: float = 0.025

var guard_spin_speed_ratio: float = 0.0


func _update_attack_pose(elapsed: float, delta: float) -> void:
	if (
		active_attack != null
		and active_attack.extra_tags.has("staff_angel_ring")
	):
		_update_whirling_bastion_pose(elapsed, delta)
		return
	super._update_attack_pose(elapsed, delta)


func _update_whirling_bastion_pose(
	_elapsed: float,
	delta: float
) -> void:
	var charge: float = 0.0
	if controller != null and controller.has_method("get_weapon_charge_ratio"):
		charge = clampf(
			float(controller.call("get_weapon_charge_ratio")),
			0.0,
			1.0
		)
	guard_spin_speed_ratio = smoothstep(0.0, 1.0, charge)
	var spin_speed: float = lerpf(
		guard_spin_min_degrees_per_second,
		guard_spin_max_degrees_per_second,
		guard_spin_speed_ratio
	)
	guard_spin_degrees = fmod(
		guard_spin_degrees + spin_speed * maxf(delta, 0.0),
		360.0
	)
	var angle: float = deg_to_rad(guard_spin_degrees)

	# The root remains close to Grace's planted hands, with only enough secondary
	# movement to make the twirl feel physically carried rather than motorized.
	position = Vector3(
		sin(angle) * guard_hand_orbit_radius,
		-0.08 + cos(angle * 2.0) * guard_hand_orbit_radius * 0.32,
		-0.5 + sin(angle * 2.0) * guard_depth_bob
	)

	var stand_upright: Quaternion = Quaternion(
		Vector3.RIGHT,
		deg_to_rad(-90.0)
	)
	var spin_in_front_plane: Quaternion = Quaternion(
		Vector3.FORWARD,
		angle
	)
	var plane_yaw: Quaternion = Quaternion(
		Vector3.UP,
		deg_to_rad(guard_plane_yaw_degrees)
	)
	quaternion = (
		plane_yaw
		* spin_in_front_plane
		* stand_upright
	).normalized()
	_update_geometry(0.0)


func get_guard_spin_phase_radians() -> float:
	return deg_to_rad(guard_spin_degrees)


func get_guard_spin_ratio() -> float:
	return clampf(guard_spin_speed_ratio, 0.0, 1.0)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["staff_weapon_rig_v2"] = true
	data["visible_front_plane_twirl"] = true
	data["guard_spin_degrees"] = snappedf(guard_spin_degrees, 0.1)
	data["guard_spin_speed_ratio"] = snappedf(guard_spin_speed_ratio, 0.01)
	return data
