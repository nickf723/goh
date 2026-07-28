extends Node
class_name PlayerSpatialProfileController

@export var profile: Resource
@export var collision_shape_path: NodePath = NodePath("../CollisionShape3D")
@export var debug_capsule_mesh_path: NodePath = NodePath("../MeshInstance3D")
@export var visual_path: NodePath = NodePath("../GraceVisualV1")

var actor: CharacterBody3D
var applied: bool = false


func _ready() -> void:
	add_to_group("player_spatial_profile_controller")
	add_to_group("debuggable")
	call_deferred("apply_profile")


func apply_profile() -> void:
	actor = get_parent() as CharacterBody3D
	if actor == null or profile == null:
		return
	_apply_collision_envelope()
	_apply_debug_capsule()
	_apply_visual_silhouette()
	actor.set_meta("player_spatial_profile_id", str(_profile_value("profile_id", "grace_default_v1")))
	actor.set_meta("player_collision_radius", _profile_number("collision_radius", 0.46))
	actor.set_meta("player_collision_height", _profile_number("collision_height", 1.92))
	actor.set_meta("player_visual_width", _profile_number("visual_width", 0.94))
	actor.set_meta("player_visual_height", _profile_number("visual_height", 1.96))
	applied = true


func _apply_collision_envelope() -> void:
	var collision_shape: CollisionShape3D = get_node_or_null(collision_shape_path) as CollisionShape3D
	if collision_shape == null or not collision_shape.shape is CapsuleShape3D:
		return
	var radius: float = maxf(_profile_number("collision_radius", 0.46), 0.05)
	var height: float = maxf(_profile_number("collision_height", 1.92), radius * 2.0)
	var capsule: CapsuleShape3D = (collision_shape.shape as CapsuleShape3D).duplicate(true) as CapsuleShape3D
	capsule.radius = radius
	capsule.height = height
	collision_shape.shape = capsule


func _apply_debug_capsule() -> void:
	var debug_mesh: MeshInstance3D = get_node_or_null(debug_capsule_mesh_path) as MeshInstance3D
	if debug_mesh == null or not debug_mesh.mesh is CapsuleMesh:
		return
	var radius: float = maxf(_profile_number("collision_radius", 0.46), 0.05)
	var height: float = maxf(_profile_number("collision_height", 1.92), radius * 2.0)
	var capsule: CapsuleMesh = (debug_mesh.mesh as CapsuleMesh).duplicate(true) as CapsuleMesh
	capsule.radius = radius
	capsule.height = height
	debug_mesh.mesh = capsule


func _apply_visual_silhouette() -> void:
	var visual: Node3D = get_node_or_null(visual_path) as Node3D
	if visual == null:
		return

	_resize_cylinder(
		visual.get_node_or_null("VisualRoot/BodyRoot/RobeSkirt") as MeshInstance3D,
		_profile_number("robe_top_radius", 0.31),
		_profile_number("robe_bottom_radius", 0.50),
		_profile_number("robe_height", 1.00)
	)
	_resize_capsule(
		visual.get_node_or_null("VisualRoot/BodyRoot/Torso") as MeshInstance3D,
		_profile_number("torso_radius", 0.29)
	)
	var sash_radius: float = _profile_number("sash_radius", 0.34)
	_resize_cylinder(
		visual.get_node_or_null("VisualRoot/BodyRoot/WaistSash") as MeshInstance3D,
		sash_radius,
		sash_radius,
		0.13
	)

	var arm_radius: float = _profile_number("arm_radius", 0.075)
	var cuff_radius: float = _profile_number("cuff_radius", 0.095)
	var hand_radius: float = _profile_number("hand_radius", 0.095)
	for side_name: String in ["Left", "Right"]:
		var shoulder_path: String = "VisualRoot/%sShoulderPivot/" % side_name
		_resize_capsule(visual.get_node_or_null(shoulder_path + side_name + "Arm") as MeshInstance3D, arm_radius)
		_resize_cylinder(
			visual.get_node_or_null(shoulder_path + side_name + "Cuff") as MeshInstance3D,
			cuff_radius,
			cuff_radius,
			0.12
		)
		_resize_sphere(visual.get_node_or_null(shoulder_path + side_name + "Hand") as MeshInstance3D, hand_radius)

	var boot_width: float = _profile_number("boot_width", 0.22)
	var boot_depth: float = _profile_number("boot_depth", 0.40)
	for side_name: String in ["Left", "Right"]:
		var leg_path: String = "VisualRoot/%sLegPivot/" % side_name
		_resize_box(
			visual.get_node_or_null(leg_path + side_name + "Boot") as MeshInstance3D,
			Vector3(boot_width, 0.22, boot_depth)
		)
		_resize_box(
			visual.get_node_or_null(leg_path + side_name + "Sole") as MeshInstance3D,
			Vector3(boot_width + 0.025, 0.055, boot_depth + 0.025)
		)

	visual.set_meta("spatial_profile_id", str(_profile_value("profile_id", "grace_default_v1")))
	visual.set_meta("silhouette_width", _profile_number("visual_width", 0.94))
	visual.set_meta("silhouette_height", _profile_number("visual_height", 1.96))


func _resize_cylinder(mesh_instance: MeshInstance3D, top_radius: float, bottom_radius: float, height: float) -> void:
	if mesh_instance == null or not mesh_instance.mesh is CylinderMesh:
		return
	var mesh: CylinderMesh = (mesh_instance.mesh as CylinderMesh).duplicate(true) as CylinderMesh
	mesh.top_radius = maxf(top_radius, 0.01)
	mesh.bottom_radius = maxf(bottom_radius, 0.01)
	mesh.height = maxf(height, 0.02)
	mesh_instance.mesh = mesh


func _resize_capsule(mesh_instance: MeshInstance3D, radius: float) -> void:
	if mesh_instance == null or not mesh_instance.mesh is CapsuleMesh:
		return
	var mesh: CapsuleMesh = (mesh_instance.mesh as CapsuleMesh).duplicate(true) as CapsuleMesh
	mesh.radius = maxf(radius, 0.01)
	mesh.height = maxf(mesh.height, mesh.radius * 2.0)
	mesh_instance.mesh = mesh


func _resize_sphere(mesh_instance: MeshInstance3D, radius: float) -> void:
	if mesh_instance == null or not mesh_instance.mesh is SphereMesh:
		return
	var mesh: SphereMesh = (mesh_instance.mesh as SphereMesh).duplicate(true) as SphereMesh
	mesh.radius = maxf(radius, 0.01)
	mesh.height = mesh.radius * 2.0
	mesh_instance.mesh = mesh


func _resize_box(mesh_instance: MeshInstance3D, size: Vector3) -> void:
	if mesh_instance == null or not mesh_instance.mesh is BoxMesh:
		return
	var mesh: BoxMesh = (mesh_instance.mesh as BoxMesh).duplicate(true) as BoxMesh
	mesh.size = Vector3(maxf(size.x, 0.01), maxf(size.y, 0.01), maxf(size.z, 0.01))
	mesh_instance.mesh = mesh


func _profile_number(property_name: String, fallback: float) -> float:
	var value: Variant = _profile_value(property_name, fallback)
	return fallback if value == null else float(value)


func _profile_value(property_name: String, fallback: Variant) -> Variant:
	if profile == null:
		return fallback
	for property_variant: Variant in profile.get_property_list():
		if property_variant is Dictionary and str((property_variant as Dictionary).get("name", "")) == property_name:
			return profile.get(property_name)
	return fallback


func get_profile() -> Resource:
	return profile


func get_debug_data() -> Dictionary:
	return {
		"applied": applied,
		"profile_id": str(_profile_value("profile_id", "")),
		"collision_radius": _profile_number("collision_radius", 0.0),
		"collision_height": _profile_number("collision_height", 0.0),
		"visual_width": _profile_number("visual_width", 0.0),
		"visual_height": _profile_number("visual_height", 0.0),
	}
