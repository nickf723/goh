extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v4k.gd"

# V4L lets staff techniques face independently from the camera and gives
# Whirling Bastion a living hand-over-hand rhythm instead of a statue holding a
# rotating prop. The runtime staff rig remains the exact weapon authority; this
# layer only makes Grace counterbalance and feed that visible rotation.

const STAFF_VISUAL_FACING_META: StringName = &"staff_visual_facing_yaw"


func _process(delta: float) -> void:
	super._process(delta)
	_apply_staff_visual_facing_yaw()


func _build_staff_angel_ring_pose() -> Dictionary:
	var pose: Dictionary = super._build_staff_angel_ring_pose()
	var phase: float = _get_staff_guard_spin_phase()
	var sweep: float = sin(phase)
	var lift: float = cos(phase)
	var counter: float = sin(phase * 2.0)

	# Grace stays rooted, but her hips and ribcage counter-rotate while the hands
	# trade leverage around the planted pivot. The support-hand IK performs the
	# final grip correction against the rotating marker on the physical staff rig.
	_add_pose_deg(pose, "pelvis", Vector3(counter * 1.8, -sweep * 5.5, -lift * 2.8))
	_add_pose_deg(pose, "spine_01", Vector3(-counter * 1.2, sweep * 4.0, lift * 2.2))
	_add_pose_deg(pose, "spine_02", Vector3(-counter * 1.6, sweep * 6.0, lift * 3.0))
	_add_pose_deg(pose, "chest", Vector3(-counter * 2.0, sweep * 8.5, lift * 4.0))
	_add_pose_deg(pose, "head", Vector3(counter * 1.2, -sweep * 3.2, -lift * 1.4))

	_add_pose_deg(pose, "upper_arm_r", Vector3(lift * 8.0, sweep * 10.0, counter * 5.0))
	_add_pose_deg(pose, "forearm_r", Vector3(sweep * 15.0, -lift * 4.0, counter * 3.0))
	_add_pose_deg(pose, "hand_r", Vector3(counter * 8.0, sweep * 6.0, lift * 7.0))
	_add_pose_deg(pose, "upper_arm_l", Vector3(-lift * 7.0, sweep * 8.0, -counter * 5.0))
	_add_pose_deg(pose, "forearm_l", Vector3(-sweep * 13.0, lift * 4.0, -counter * 3.0))
	_add_pose_deg(pose, "hand_l", Vector3(-counter * 7.0, -sweep * 5.0, -lift * 6.0))

	_add_pose_deg(pose, "thigh_l", Vector3(-absf(sweep) * 2.5, 0.0, -lift * 1.8))
	_add_pose_deg(pose, "thigh_r", Vector3(-absf(lift) * 2.5, 0.0, sweep * 1.8))
	var pelvis_offset: Vector3 = pose.get("__pelvis_offset", Vector3.ZERO) as Vector3
	pelvis_offset.x += sweep * 0.012
	pelvis_offset.y -= absf(counter) * 0.006
	pelvis_offset.z += lift * 0.008
	pose["__pelvis_offset"] = pelvis_offset
	return pose


func _get_staff_guard_spin_phase() -> float:
	if weapon_controller != null:
		var rig: Node = weapon_controller.runtime_weapon_rig
		if rig != null and rig.has_method("get_guard_spin_phase_radians"):
			return float(rig.call("get_guard_spin_phase_radians"))
		return weapon_controller.current_attack_elapsed * 11.5
	return elapsed * 11.5


func _apply_staff_visual_facing_yaw() -> void:
	if actor == null or not actor.has_meta(STAFF_VISUAL_FACING_META):
		return
	var root_rotation: Vector3 = rotation
	root_rotation.y = float(actor.get_meta(STAFF_VISUAL_FACING_META, 0.0))
	rotation = root_rotation


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["weapon_language_v4l"] = true
	data["staff_camera_decoupled_facing"] = true
	data["staff_guard_body_twirl"] = true
	data["staff_visual_yaw"] = (
		float(actor.get_meta(STAFF_VISUAL_FACING_META, 0.0))
		if actor != null
		else 0.0
	)
	return data
