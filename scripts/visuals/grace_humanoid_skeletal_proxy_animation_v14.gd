extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v13.gd"
class_name GraceHumanoidSkeletalProxyAnimationV14

# V14 replaces uniform whole-skeleton smoothing with regional response. The
# authored target pose is unchanged; only how quickly different body regions
# arrive there changes. Weapon hands and feet stay precise, while pelvis/spine
# carry a fraction more inertia and the head stabilizes quickly.

@export_group("Regional Pose Response")
@export_range(0.5, 1.5, 0.05) var pelvis_response_scale: float = 0.84
@export_range(0.5, 1.5, 0.05) var torso_response_scale: float = 0.9
@export_range(0.5, 1.7, 0.05) var head_response_scale: float = 1.12
@export_range(0.5, 1.7, 0.05) var upper_arm_response_scale: float = 1.0
@export_range(0.5, 1.8, 0.05) var hand_response_scale: float = 1.18
@export_range(0.5, 1.7, 0.05) var leg_response_scale: float = 0.96
@export_range(0.5, 1.9, 0.05) var foot_response_scale: float = 1.2
@export_range(0.7, 1.6, 0.05) var impact_response_boost: float = 1.18
@export_range(0.7, 1.6, 0.05) var weapon_hand_attack_boost: float = 1.2

var last_regional_response_state: String = "idle"


func _blend_skeleton_pose(
	targets: Dictionary,
	pelvis_offset: Vector3,
	delta: float
) -> void:
	if skeleton == null:
		return
	last_regional_response_state = animation_state
	var step: float = maxf(delta, 0.0)

	for bone_name_variant: Variant in bones.keys():
		var bone_name: String = str(bone_name_variant)
		var index: int = int(bones[bone_name])
		var target_euler: Vector3 = targets.get(bone_name, Vector3.ZERO) as Vector3
		var target_rotation: Quaternion = Basis.from_euler(target_euler).get_rotation_quaternion()
		var current: Quaternion = current_rotations.get(
			bone_name,
			Quaternion.IDENTITY
		) as Quaternion
		var response: float = pose_response * _get_bone_response_scale(bone_name)
		if animation_state in ["hit", "dodge"]:
			response *= impact_response_boost
		if animation_state == "attack" and bone_name in [
			"clavicle_r",
			"upper_arm_r",
			"forearm_r",
			"hand_r",
		]:
			response *= weapon_hand_attack_boost
		var blend: float = (
			1.0
			if step <= 0.0
			else 1.0 - exp(-maxf(response, 0.01) * step)
		)
		blend = clampf(blend, 0.0, 1.0)
		current = current.slerp(target_rotation, blend).normalized()
		current_rotations[bone_name] = current
		skeleton.set_bone_pose_rotation(index, current)

	var pelvis_response: float = pose_response * pelvis_response_scale
	if animation_state in ["hit", "dodge"]:
		pelvis_response *= impact_response_boost
	var pelvis_blend: float = (
		1.0
		if step <= 0.0
		else 1.0 - exp(-maxf(pelvis_response, 0.01) * step)
	)
	pelvis_blend = clampf(pelvis_blend, 0.0, 1.0)
	current_pelvis_offset = current_pelvis_offset.lerp(
		pelvis_offset,
		pelvis_blend
	)
	if bones.has("pelvis"):
		# The active weapon-language chain inherits the grounded proxy, whose pose
		# position includes the pelvis rest translation. Preserve that calibrated
		# convention while changing only regional response speed.
		var pelvis_index: int = int(bones["pelvis"])
		var pelvis_rest_position: Vector3 = skeleton.get_bone_rest(
			pelvis_index
		).origin
		skeleton.set_bone_pose_position(
			pelvis_index,
			pelvis_rest_position + current_pelvis_offset
		)


func _get_bone_response_scale(bone_name: String) -> float:
	match bone_name:
		"root", "pelvis":
			return pelvis_response_scale
		"spine_01", "spine_02", "chest":
			return torso_response_scale
		"neck", "head":
			return head_response_scale
		"clavicle_l", "clavicle_r", "upper_arm_l", "upper_arm_r":
			return upper_arm_response_scale
		"forearm_l", "forearm_r", "hand_l", "hand_r":
			return hand_response_scale
		"thigh_l", "thigh_r", "shin_l", "shin_r":
			return leg_response_scale
		"foot_l", "foot_r", "toe_l", "toe_r":
			return foot_response_scale
		_:
			return 1.0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v14"] = true
	data["regional_pose_response"] = true
	data["regional_response_state"] = last_regional_response_state
	data["torso_response_scale"] = torso_response_scale
	data["hand_response_scale"] = hand_response_scale
	data["foot_response_scale"] = foot_response_scale
	return data
