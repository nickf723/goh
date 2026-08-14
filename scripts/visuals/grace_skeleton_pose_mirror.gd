extends Node
class_name GraceSkeletonPoseMirror

const HumanoidContractScript = preload(
	"res://scripts/visuals/grace_humanoid_rig_contract.gd"
)
const ProductionContractScript = preload(
	"res://scripts/visuals/grace_production_skeleton_contract.gd"
)

@export var source_skeleton_path: NodePath
@export var target_skeleton_path: NodePath
@export var mirror_enabled: bool = true
@export var require_production_target: bool = false
@export var copy_root_position: bool = false
@export var copy_pelvis_position: bool = true
@export var copy_pose_scale: bool = false

var source_skeleton: Skeleton3D
var target_skeleton: Skeleton3D
var source_semantics: Dictionary = {}
var target_semantics: Dictionary = {}
var shared_semantics: Array[String] = []
var target_validation: Dictionary = {}
var translation_ratio: float = 1.0
var last_mirrored_bones: int = 0
var last_max_rotation_error_degrees: float = 0.0


func _ready() -> void:
	# The procedural proxy currently samples at priority 205. Mirroring later in
	# the frame lets a skinned production model inherit the completed pose before
	# Godot renders it, while gameplay remains untouched.
	process_priority = 225
	resolve_skeletons()
	add_to_group("grace_skeleton_pose_mirror")
	add_to_group("debuggable")


func _process(_delta: float) -> void:
	if mirror_enabled:
		mirror_pose()


func configure(
	source: Skeleton3D,
	target: Skeleton3D
) -> bool:
	source_skeleton = source
	target_skeleton = target
	return _resolve_contracts()


func resolve_skeletons() -> bool:
	if source_skeleton_path != NodePath():
		source_skeleton = get_node_or_null(
			source_skeleton_path
		) as Skeleton3D
	if target_skeleton_path != NodePath():
		target_skeleton = get_node_or_null(
			target_skeleton_path
		) as Skeleton3D
	return _resolve_contracts()


func is_ready_to_mirror() -> bool:
	if source_skeleton == null or target_skeleton == null:
		return false
	if shared_semantics.is_empty():
		return false
	if require_production_target:
		return bool(target_validation.get("production_ready", false))
	return bool(target_validation.get("mirror_ready", false))


func mirror_pose() -> void:
	if not is_ready_to_mirror():
		last_mirrored_bones = 0
		return
	last_mirrored_bones = 0
	last_max_rotation_error_degrees = 0.0
	for semantic: String in shared_semantics:
		var source_index: int = int(source_semantics.get(semantic, -1))
		var target_index: int = int(target_semantics.get(semantic, -1))
		if source_index < 0 or target_index < 0:
			continue
		var source_rotation: Quaternion = source_skeleton.get_bone_pose_rotation(
			source_index
		)
		target_skeleton.set_bone_pose_rotation(target_index, source_rotation)
		if copy_pose_scale:
			target_skeleton.set_bone_pose_scale(
				target_index,
				source_skeleton.get_bone_pose_scale(source_index)
			)
		if (
			semantic == "pelvis" and copy_pelvis_position
			or semantic == "root" and copy_root_position
		):
			target_skeleton.set_bone_pose_position(
				target_index,
				source_skeleton.get_bone_pose_position(source_index)
				* translation_ratio
			)
		var target_rotation: Quaternion = target_skeleton.get_bone_pose_rotation(
			target_index
		)
		last_max_rotation_error_degrees = maxf(
			last_max_rotation_error_degrees,
			rad_to_deg(source_rotation.angle_to(target_rotation))
		)
		last_mirrored_bones += 1


func clear_target_pose() -> void:
	if target_skeleton == null:
		return
	for semantic: String in shared_semantics:
		var target_index: int = int(target_semantics.get(semantic, -1))
		if target_index < 0:
			continue
		target_skeleton.set_bone_pose_rotation(
			target_index,
			Quaternion.IDENTITY
		)
		target_skeleton.set_bone_pose_position(target_index, Vector3.ZERO)
		target_skeleton.set_bone_pose_scale(target_index, Vector3.ONE)


func _resolve_contracts() -> bool:
	source_semantics = HumanoidContractScript.build_semantic_map(
		source_skeleton
	)
	target_semantics = HumanoidContractScript.build_semantic_map(
		target_skeleton
	)
	target_validation = ProductionContractScript.validate_production_skeleton(
		target_skeleton
	)
	shared_semantics.clear()
	for semantic: String in ProductionContractScript.PRODUCTION_REQUIRED_SEMANTICS:
		if source_semantics.has(semantic) and target_semantics.has(semantic):
			shared_semantics.append(semantic)
	var source_scale: float = ProductionContractScript.get_translation_scale(
		source_skeleton
	)
	var target_scale: float = ProductionContractScript.get_translation_scale(
		target_skeleton
	)
	translation_ratio = (
		target_scale / source_scale
		if source_scale > 0.0001
		else 1.0
	)
	return is_ready_to_mirror()


func get_debug_data() -> Dictionary:
	return {
		"skeleton_pose_mirror": true,
		"enabled": mirror_enabled,
		"ready": is_ready_to_mirror(),
		"source_found": source_skeleton != null,
		"target_found": target_skeleton != null,
		"shared_semantics": shared_semantics.size(),
		"mirrored_bones": last_mirrored_bones,
		"translation_ratio": snappedf(translation_ratio, 0.001),
		"maximum_rotation_error_degrees": snappedf(
			last_max_rotation_error_degrees,
			0.001
		),
		"target_production_ready": bool(
			target_validation.get("production_ready", false)
		),
		"target_missing_production": target_validation.get(
			"missing_production",
			[]
		),
	}
