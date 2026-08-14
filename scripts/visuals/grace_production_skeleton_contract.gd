extends RefCounted
class_name GraceProductionSkeletonContract

const HumanoidContractScript = preload(
	"res://scripts/visuals/grace_humanoid_rig_contract.gd"
)

# The procedural calibration rig already uses this complete 23-bone spine,
# limb, clavicle, foot, and root set. Imported Grace models may keep any number
# of additional face, finger, hair, cloth, or twist bones, but these semantics
# are the stable gameplay/presentation boundary from this point forward.
const PRODUCTION_REQUIRED_SEMANTICS: Array[String] = [
	"root",
	"pelvis",
	"spine_01",
	"spine_02",
	"chest",
	"neck",
	"head",
	"clavicle_l",
	"upper_arm_l",
	"forearm_l",
	"hand_l",
	"clavicle_r",
	"upper_arm_r",
	"forearm_r",
	"hand_r",
	"thigh_l",
	"shin_l",
	"foot_l",
	"toe_l",
	"thigh_r",
	"shin_r",
	"foot_r",
	"toe_r",
]

const REFERENCE_HEAD_TO_FOOT_SPAN: float = 1.68
const MINIMUM_HEAD_TO_FOOT_SPAN: float = 1.42
const MAXIMUM_HEAD_TO_FOOT_SPAN: float = 1.98
const MAXIMUM_LIMB_ASYMMETRY_RATIO: float = 0.18
const MINIMUM_BONE_BASIS_DETERMINANT: float = 0.0001

const VIRTUAL_SOCKET_SPECS: Dictionary = {
	"weapon_hand": {
		"semantic": "hand_r",
		"offset": Vector3(0.0, -0.035, -0.015),
		"rotation_degrees": Vector3.ZERO,
	},
	"support_hand": {
		"semantic": "hand_l",
		"offset": Vector3.ZERO,
		"rotation_degrees": Vector3.ZERO,
	},
	"head_aim": {
		"semantic": "head",
		"offset": Vector3(0.0, 0.105, -0.105),
		"rotation_degrees": Vector3.ZERO,
	},
	"foot_l": {
		"semantic": "foot_l",
		"offset": Vector3(0.0, -0.035, -0.06),
		"rotation_degrees": Vector3.ZERO,
	},
	"foot_r": {
		"semantic": "foot_r",
		"offset": Vector3(0.0, -0.035, -0.06),
		"rotation_degrees": Vector3.ZERO,
	},
	"back_mount": {
		"semantic": "chest",
		"offset": Vector3(0.0, -0.04, 0.18),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
	},
	"hip_mount": {
		"semantic": "pelvis",
		"offset": Vector3(0.19, -0.06, 0.07),
		"rotation_degrees": Vector3(0.0, 90.0, 8.0),
	},
}

const SYMMETRY_PAIRS: Array[Dictionary] = [
	{"label": "upper arms", "left_a": "upper_arm_l", "left_b": "forearm_l", "right_a": "upper_arm_r", "right_b": "forearm_r"},
	{"label": "forearms", "left_a": "forearm_l", "left_b": "hand_l", "right_a": "forearm_r", "right_b": "hand_r"},
	{"label": "thighs", "left_a": "thigh_l", "left_b": "shin_l", "right_a": "thigh_r", "right_b": "shin_r"},
	{"label": "shins", "left_a": "shin_l", "left_b": "foot_l", "right_a": "shin_r", "right_b": "foot_r"},
	{"label": "feet", "left_a": "foot_l", "left_b": "toe_l", "right_a": "foot_r", "right_b": "toe_r"},
]


static func validate_production_skeleton(skeleton: Skeleton3D) -> Dictionary:
	var base_validation: Dictionary = HumanoidContractScript.validate_skeleton(
		skeleton
	)
	var semantic_map: Dictionary = base_validation.get(
		"semantic_map",
		{}
	) as Dictionary
	var missing_production: Array[String] = []
	for semantic: String in PRODUCTION_REQUIRED_SEMANTICS:
		if not semantic_map.has(semantic):
			missing_production.append(semantic)

	var basis_errors: Array[String] = _validate_rest_bases(
		skeleton,
		semantic_map
	)
	var symmetry_errors: Array[String] = _validate_symmetry(
		skeleton,
		semantic_map
	)
	var head_to_foot_span: float = _measure_head_to_foot_span(
		skeleton,
		semantic_map
	)
	var scale_errors: Array[String] = []
	if head_to_foot_span > 0.0 and (
		head_to_foot_span < MINIMUM_HEAD_TO_FOOT_SPAN
		or head_to_foot_span > MAXIMUM_HEAD_TO_FOOT_SPAN
	):
		scale_errors.append(
			"head-to-foot rest span "
			+ str(snappedf(head_to_foot_span, 0.001))
			+ "m is outside the accepted production range"
		)

	var base_compatible: bool = bool(
		base_validation.get("compatible", false)
	)
	var mirror_ready: bool = (
		base_compatible
		and basis_errors.is_empty()
		and head_to_foot_span > 0.0
	)
	var production_ready: bool = (
		mirror_ready
		and missing_production.is_empty()
		and symmetry_errors.is_empty()
		and scale_errors.is_empty()
	)

	return {
		"production_skeleton_contract": true,
		"compatible": base_compatible,
		"mirror_ready": mirror_ready,
		"production_ready": production_ready,
		"bone_count": skeleton.get_bone_count() if skeleton != null else 0,
		"semantic_map": semantic_map,
		"mapped_count": semantic_map.size(),
		"missing_required": base_validation.get("missing_required", []),
		"missing_production": missing_production,
		"missing_optional": base_validation.get("missing_optional", []),
		"hierarchy_errors": base_validation.get("hierarchy_errors", []),
		"basis_errors": basis_errors,
		"symmetry_errors": symmetry_errors,
		"scale_errors": scale_errors,
		"head_to_foot_span": snappedf(head_to_foot_span, 0.001),
		"reference_span": REFERENCE_HEAD_TO_FOOT_SPAN,
		"translation_scale": get_translation_scale(skeleton),
		"socket_count": VIRTUAL_SOCKET_SPECS.size(),
		"extra_bones_allowed": true,
	}


static func get_translation_scale(skeleton: Skeleton3D) -> float:
	var semantic_map: Dictionary = HumanoidContractScript.build_semantic_map(
		skeleton
	)
	var span: float = _measure_head_to_foot_span(skeleton, semantic_map)
	if span <= 0.0001:
		return 1.0
	return span / REFERENCE_HEAD_TO_FOOT_SPAN


static func get_socket_world_transform(
	skeleton: Skeleton3D,
	socket_id: String
) -> Transform3D:
	if skeleton == null or not VIRTUAL_SOCKET_SPECS.has(socket_id):
		return Transform3D.IDENTITY
	var spec: Dictionary = VIRTUAL_SOCKET_SPECS[socket_id] as Dictionary
	var semantic: String = str(spec.get("semantic", ""))
	var semantic_map: Dictionary = HumanoidContractScript.build_semantic_map(
		skeleton
	)
	var bone_index: int = int(semantic_map.get(semantic, -1))
	if bone_index < 0:
		return Transform3D.IDENTITY
	var offset: Vector3 = spec.get("offset", Vector3.ZERO) as Vector3
	var rotation_degrees: Vector3 = spec.get(
		"rotation_degrees",
		Vector3.ZERO
	) as Vector3
	var socket_basis: Basis = Basis.from_euler(Vector3(
		deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y),
		deg_to_rad(rotation_degrees.z)
	))
	return (
		skeleton.global_transform
		* skeleton.get_bone_global_pose(bone_index)
		* Transform3D(socket_basis, offset)
	)


static func get_global_rest_transform(
	skeleton: Skeleton3D,
	bone_index: int
) -> Transform3D:
	if skeleton == null or bone_index < 0 or bone_index >= skeleton.get_bone_count():
		return Transform3D.IDENTITY
	var result: Transform3D = skeleton.get_bone_rest(bone_index)
	var parent_index: int = skeleton.get_bone_parent(bone_index)
	while parent_index >= 0:
		result = skeleton.get_bone_rest(parent_index) * result
		parent_index = skeleton.get_bone_parent(parent_index)
	return result


static func measure_segment(
	skeleton: Skeleton3D,
	semantic_map: Dictionary,
	semantic_a: String,
	semantic_b: String
) -> float:
	if (
		skeleton == null
		or not semantic_map.has(semantic_a)
		or not semantic_map.has(semantic_b)
	):
		return 0.0
	var a: Vector3 = get_global_rest_transform(
		skeleton,
		int(semantic_map[semantic_a])
	).origin
	var b: Vector3 = get_global_rest_transform(
		skeleton,
		int(semantic_map[semantic_b])
	).origin
	return a.distance_to(b)


static func _measure_head_to_foot_span(
	skeleton: Skeleton3D,
	semantic_map: Dictionary
) -> float:
	if (
		skeleton == null
		or not semantic_map.has("head")
		or not semantic_map.has("foot_l")
		or not semantic_map.has("foot_r")
	):
		return 0.0
	var head: Vector3 = get_global_rest_transform(
		skeleton,
		int(semantic_map["head"])
	).origin
	var foot_l: Vector3 = get_global_rest_transform(
		skeleton,
		int(semantic_map["foot_l"])
	).origin
	var foot_r: Vector3 = get_global_rest_transform(
		skeleton,
		int(semantic_map["foot_r"])
	).origin
	var feet_midpoint: Vector3 = foot_l.lerp(foot_r, 0.5)
	return absf(head.y - feet_midpoint.y)


static func _validate_rest_bases(
	skeleton: Skeleton3D,
	semantic_map: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	if skeleton == null:
		errors.append("Skeleton3D is missing")
		return errors
	for semantic_variant: Variant in semantic_map.keys():
		var semantic: String = str(semantic_variant)
		var index: int = int(semantic_map[semantic])
		var determinant: float = absf(
			skeleton.get_bone_rest(index).basis.determinant()
		)
		if determinant < MINIMUM_BONE_BASIS_DETERMINANT:
			errors.append(semantic + " has a collapsed rest basis")
	return errors


static func _validate_symmetry(
	skeleton: Skeleton3D,
	semantic_map: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	for spec: Dictionary in SYMMETRY_PAIRS:
		var left_length: float = measure_segment(
			skeleton,
			semantic_map,
			str(spec.get("left_a", "")),
			str(spec.get("left_b", ""))
		)
		var right_length: float = measure_segment(
			skeleton,
			semantic_map,
			str(spec.get("right_a", "")),
			str(spec.get("right_b", ""))
		)
		if left_length <= 0.0001 or right_length <= 0.0001:
			continue
		var denominator: float = maxf(left_length, right_length)
		var asymmetry: float = absf(left_length - right_length) / denominator
		if asymmetry > MAXIMUM_LIMB_ASYMMETRY_RATIO:
			errors.append(
			str(spec.get("label", "paired limbs"))
			+ " differ by "
			+ str(snappedf(asymmetry * 100.0, 0.1))
			+ "%"
		)
	return errors
