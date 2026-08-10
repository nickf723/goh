extends Node3D
class_name EnvironmentKitModule

@export var module_id: String = "environment_module"
@export var display_name: String = "Environment Module"
@export var kit_id: String = "environment_kit"
@export_enum("terrain", "traversal", "architecture", "prop", "ecology") var category: String = "architecture"
@export var target_dimensions_m: Vector3 = Vector3.ONE
@export_enum("ground_center", "center", "edge_center") var pivot_policy: String = "ground_center"
@export_enum("external_blockout", "module_simple", "none") var collision_policy: String = "external_blockout"
@export var authored_visual_scene: PackedScene
@export var placeholder_enabled: bool = true
@export_enum("box", "cylinder", "cross", "none") var placeholder_shape: String = "box"
@export var placeholder_tint: Color = Color(0.42, 0.45, 0.42, 1.0)
@export var authored_source_hint: String = "Blender GLB"

var visual_root: Node3D = null
var using_placeholder: bool = false


func _ready() -> void:
	add_to_group("environment_kit_module")
	add_to_group("environment_kit_" + category)
	visual_root = Node3D.new()
	visual_root.name = "Visual"
	add_child(visual_root)
	if authored_visual_scene != null:
		var authored: Node = authored_visual_scene.instantiate()
		authored.name = "AuthoredVisual"
		visual_root.add_child(authored)
		using_placeholder = false
	elif placeholder_enabled:
		_build_placeholder()
		using_placeholder = true
	set_meta("module_id", module_id)
	set_meta("kit_id", kit_id)
	set_meta("category", category)
	set_meta("target_dimensions_m", target_dimensions_m)
	set_meta("pivot_policy", pivot_policy)
	set_meta("collision_policy", collision_policy)
	set_meta("placeholder", using_placeholder)
	set_meta("authored_source_hint", authored_source_hint)


func _build_placeholder() -> void:
	match placeholder_shape:
		"cylinder":
			_build_cylinder_placeholder()
		"cross":
			_build_cross_placeholder()
		"none":
			return
		_:
			_build_box_placeholder()


func _build_box_placeholder() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PlaceholderBox"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		maxf(target_dimensions_m.x, 0.05),
		maxf(target_dimensions_m.y, 0.05),
		maxf(target_dimensions_m.z, 0.05)
	)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_placeholder_material()
	mesh_instance.position = _pivot_offset(target_dimensions_m.y)
	visual_root.add_child(mesh_instance)


func _build_cylinder_placeholder() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PlaceholderCylinder"
	var mesh := CylinderMesh.new()
	mesh.height = maxf(target_dimensions_m.y, 0.05)
	mesh.top_radius = maxf(minf(target_dimensions_m.x, target_dimensions_m.z) * 0.5, 0.025)
	mesh.bottom_radius = mesh.top_radius
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_placeholder_material()
	mesh_instance.position = _pivot_offset(target_dimensions_m.y)
	visual_root.add_child(mesh_instance)


func _build_cross_placeholder() -> void:
	var height: float = maxf(target_dimensions_m.y, 0.05)
	var width: float = maxf(target_dimensions_m.x, 0.05)
	var depth: float = maxf(target_dimensions_m.z, 0.05)
	for index: int in range(2):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "PlaceholderFrond%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, height, 0.045)
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _make_placeholder_material()
		mesh_instance.position = _pivot_offset(height)
		mesh_instance.rotation.y = float(index) * PI * 0.5
		mesh_instance.scale.z = maxf(depth / width, 0.25)
		visual_root.add_child(mesh_instance)


func _pivot_offset(height: float) -> Vector3:
	match pivot_policy:
		"center":
			return Vector3.ZERO
		_:
			return Vector3(0.0, height * 0.5, 0.0)


func _make_placeholder_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = placeholder_tint
	material.roughness = 0.92
	material.metallic = 0.0
	return material


func get_debug_data() -> Dictionary:
	return {
		"environment_kit_module": true,
		"module_id": module_id,
		"display_name": display_name,
		"kit_id": kit_id,
		"category": category,
		"target_dimensions_m": target_dimensions_m,
		"pivot_policy": pivot_policy,
		"collision_policy": collision_policy,
		"placeholder": using_placeholder,
		"authored_visual_present": authored_visual_scene != null,
		"authored_source_hint": authored_source_hint,
	}
