extends Node3D
class_name GraceProductionPresentationController

const ProductionContractScript = preload(
	"res://scripts/visuals/grace_production_skeleton_contract.gd"
)
const HumanoidContractScript = preload(
	"res://scripts/visuals/grace_humanoid_rig_contract.gd"
)
const PresentationAuditorScript = preload(
	"res://scripts/visuals/grace_presentation_asset_auditor.gd"
)
const PoseMirrorScript = preload(
	"res://scripts/visuals/grace_skeleton_pose_mirror.gd"
)

const MODE_AUTO: int = 0
const MODE_PROCEDURAL_ONLY: int = 1
const MODE_IMPORTED_PREVIEW: int = 2
const MODE_IMPORTED_ACTIVE: int = 3

@export_group("Presentation Source")
@export var imported_character_scene: PackedScene
@export_enum("Auto", "Procedural Only", "Imported Preview", "Imported Active") var activation_mode: int = MODE_AUTO
@export var require_production_contract_for_auto: bool = false
@export var procedural_visual_path: NodePath = NodePath("../GraceSkeletalVisualV1")
@export var weapon_controller_path: NodePath = NodePath("../WeaponController")
@export var imported_origin_offset: Vector3 = Vector3.ZERO

@export_group("Mirrored Prototype Motion")
@export var mirror_procedural_pose: bool = true
@export var copy_root_position: bool = false
@export var copy_pelvis_position: bool = true
@export var disable_imported_animation_nodes_while_mirroring: bool = true

@export_group("Weapon Socket")
@export var drive_weapon_socket_from_imported: bool = true
@export var imported_weapon_socket_offset: Vector3 = Vector3(0.0, -0.035, -0.015)
@export var imported_weapon_socket_rotation_degrees: Vector3 = Vector3.ZERO

var procedural_visual: Node3D
var weapon_controller: Node3D
var imported_root: Node3D
var imported_instance: Node3D
var source_skeleton: Skeleton3D
var imported_skeleton: Skeleton3D
var pose_mirror: GraceSkeletonPoseMirror
var imported_audit: Dictionary = {}
var production_validation: Dictionary = {}
var active_presentation: String = "procedural"
var last_weapon_socket_error: float = 0.0


func _ready() -> void:
	process_priority = 240
	procedural_visual = get_node_or_null(
		procedural_visual_path
	) as Node3D
	weapon_controller = get_node_or_null(
		weapon_controller_path
	) as Node3D
	imported_root = get_node_or_null(
		"ImportedPresentationRoot"
	) as Node3D
	if imported_root == null:
		imported_root = Node3D.new()
		imported_root.name = "ImportedPresentationRoot"
		add_child(imported_root)
	source_skeleton = HumanoidContractScript.find_skeleton(
		procedural_visual
	)
	if imported_character_scene != null:
		install_imported_scene(imported_character_scene)
	else:
		activate_procedural()
	add_to_group("grace_production_presentation")
	add_to_group("debuggable")


func _process(_delta: float) -> void:
	_sync_imported_root_to_procedural()
	if active_presentation == "imported":
		_drive_imported_weapon_socket()


func install_imported_scene(scene: PackedScene) -> bool:
	_clear_imported_scene()
	imported_character_scene = scene
	if scene == null:
		activate_procedural()
		return false
	var raw_instance: Node = scene.instantiate()
	if not raw_instance is Node3D:
		raw_instance.free()
		activate_procedural()
		return false
	imported_instance = raw_instance as Node3D
	imported_instance.name = "ImportedGraceModel"
	imported_root.add_child(imported_instance)
	imported_skeleton = HumanoidContractScript.find_skeleton(
		imported_instance
	)
	imported_audit = PresentationAuditorScript.audit(imported_instance)
	production_validation = ProductionContractScript.validate_production_skeleton(
		imported_skeleton
	)
	_configure_pose_mirror()
	if disable_imported_animation_nodes_while_mirroring and mirror_procedural_pose:
		_disable_imported_animation_nodes(imported_instance)
	_evaluate_activation_mode()
	return active_presentation == "imported"


func activate_procedural() -> void:
	active_presentation = "procedural"
	if procedural_visual != null:
		procedural_visual.visible = true
		if "drive_weapon_socket" in procedural_visual:
			procedural_visual.set("drive_weapon_socket", true)
	if imported_instance != null:
		imported_instance.visible = false
	if pose_mirror != null:
		pose_mirror.mirror_enabled = false


func activate_imported(require_production_ready: bool = false) -> bool:
	var accepted: bool = bool(
		production_validation.get(
			"production_ready" if require_production_ready else "mirror_ready",
			false
		)
	)
	if imported_instance == null or imported_skeleton == null or not accepted:
		activate_procedural()
		return false
	active_presentation = "imported"
	if procedural_visual != null:
		procedural_visual.visible = false
		# The hidden procedural rig keeps generating combat poses, but the visible
		# imported hand becomes authoritative for weapon placement.
		if "drive_weapon_socket" in procedural_visual:
			procedural_visual.set("drive_weapon_socket", false)
	imported_instance.visible = true
	if pose_mirror != null:
		pose_mirror.mirror_enabled = mirror_procedural_pose
	return true


func set_activation_mode(mode: int) -> void:
	activation_mode = clampi(
		mode,
		MODE_AUTO,
		MODE_IMPORTED_ACTIVE
	)
	_evaluate_activation_mode()


func is_imported_active() -> bool:
	return active_presentation == "imported"


func get_active_visual() -> Node3D:
	if is_imported_active():
		return imported_instance
	return procedural_visual


func get_imported_stage() -> String:
	if imported_instance == null:
		return "no_asset"
	if not bool(production_validation.get("mirror_ready", false)):
		return "blocked_skeleton"
	if not bool(production_validation.get("production_ready", false)):
		return "mirror_candidate"
	var core_animation_ready: bool = bool(
		imported_audit.get("core_animation_ready", false)
	)
	return (
		"animated_production_candidate"
		if core_animation_ready
		else "production_model_candidate"
	)


func get_socket_world_transform(socket_id: String) -> Transform3D:
	if is_imported_active() and imported_skeleton != null:
		return ProductionContractScript.get_socket_world_transform(
			imported_skeleton,
			socket_id
		)
	if source_skeleton != null:
		return ProductionContractScript.get_socket_world_transform(
			source_skeleton,
			socket_id
		)
	return Transform3D.IDENTITY


func _evaluate_activation_mode() -> void:
	match activation_mode:
		MODE_PROCEDURAL_ONLY:
			activate_procedural()
		MODE_IMPORTED_PREVIEW:
			activate_imported(false)
		MODE_IMPORTED_ACTIVE:
			activate_imported(true)
		_:
			activate_imported(require_production_contract_for_auto)


func _configure_pose_mirror() -> void:
	if pose_mirror == null:
		pose_mirror = PoseMirrorScript.new() as GraceSkeletonPoseMirror
		pose_mirror.name = "SkeletonPoseMirror"
		add_child(pose_mirror)
	pose_mirror.copy_root_position = copy_root_position
	pose_mirror.copy_pelvis_position = copy_pelvis_position
	# Promotion strictness belongs to this controller. Preview models still need
	# the pose bridge even when they are missing a production-preferred semantic.
	pose_mirror.require_production_target = false
	pose_mirror.configure(source_skeleton, imported_skeleton)
	pose_mirror.mirror_enabled = false


func _sync_imported_root_to_procedural() -> void:
	if imported_root == null or procedural_visual == null:
		return
	imported_root.transform = procedural_visual.transform
	imported_root.position += imported_origin_offset


func _drive_imported_weapon_socket() -> void:
	last_weapon_socket_error = 0.0
	if (
		not drive_weapon_socket_from_imported
		or imported_skeleton == null
		or weapon_controller == null
	):
		return
	var hand_anchor: Node3D = weapon_controller.get_node_or_null(
		"HandAnchor"
	) as Node3D
	if hand_anchor == null:
		return
	var semantic_map: Dictionary = HumanoidContractScript.build_semantic_map(
		imported_skeleton
	)
	var hand_index: int = int(semantic_map.get("hand_r", -1))
	if hand_index < 0:
		return
	var socket_basis: Basis = Basis.from_euler(Vector3(
		deg_to_rad(imported_weapon_socket_rotation_degrees.x),
		deg_to_rad(imported_weapon_socket_rotation_degrees.y),
		deg_to_rad(imported_weapon_socket_rotation_degrees.z)
	))
	var socket_local: Transform3D = Transform3D(
		socket_basis,
		imported_weapon_socket_offset
	)
	var target_global: Transform3D = (
		imported_skeleton.global_transform
		* imported_skeleton.get_bone_global_pose(hand_index)
		* socket_local
	)
	hand_anchor.global_transform = target_global
	last_weapon_socket_error = hand_anchor.global_position.distance_to(
		target_global.origin
	)


func _disable_imported_animation_nodes(root: Node) -> void:
	if root == null:
		return
	if root is AnimationPlayer:
		(root as AnimationPlayer).stop()
		root.process_mode = Node.PROCESS_MODE_DISABLED
	elif root is AnimationTree:
		(root as AnimationTree).active = false
	for child: Node in root.get_children():
		_disable_imported_animation_nodes(child)


func _clear_imported_scene() -> void:
	if pose_mirror != null:
		pose_mirror.mirror_enabled = false
	if imported_instance != null and is_instance_valid(imported_instance):
		imported_instance.queue_free()
	imported_instance = null
	imported_skeleton = null
	imported_audit.clear()
	production_validation.clear()
	activate_procedural()


func get_debug_data() -> Dictionary:
	return {
		"production_presentation_controller": true,
		"active_presentation": active_presentation,
		"activation_mode": activation_mode,
		"imported_stage": get_imported_stage(),
		"imported_scene": (
			imported_character_scene.resource_path
			if imported_character_scene != null
			else "none"
		),
		"procedural_source_found": procedural_visual != null,
		"source_skeleton_found": source_skeleton != null,
		"imported_skeleton_found": imported_skeleton != null,
		"mirror_ready": bool(
			production_validation.get("mirror_ready", false)
		),
		"production_ready": bool(
			production_validation.get("production_ready", false)
		),
		"pose_mirror_active": (
			pose_mirror != null and pose_mirror.mirror_enabled
		),
		"weapon_socket_error": snappedf(
			last_weapon_socket_error,
			0.001
		),
		"missing_production": production_validation.get(
			"missing_production",
			[]
		),
	}
