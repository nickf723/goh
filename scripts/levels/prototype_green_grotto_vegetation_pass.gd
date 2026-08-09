extends "res://scripts/levels/prototype_green_grotto_water_pass.gd"
class_name PrototypeGreenGrottoVegetationPass

var vegetation_presentation_director: VegetationPresentationDirector3D = null
var vegetation_presentation_counts: Dictionary = {}


func _ready() -> void:
	super._ready()
	vegetation_presentation_director = get_node_or_null(
		"VegetationPresentationDirector"
	) as VegetationPresentationDirector3D
	_register_vegetation_presentation()
	set_meta("vegetation_presentation_pass", "vegetation_presentation_director_v1")
	set_meta("vegetation_presentation_authority", "VegetationPresentationDirector")
	set_meta("vegetation_presentation_counts", vegetation_presentation_counts.duplicate(true))


func _register_vegetation_presentation() -> void:
	if vegetation_presentation_director == null or environment_root == null:
		return
	var material_roles: Dictionary = {}
	_register_material_role(
		material_roles,
		material_library.get_material("foliage"),
		"ground"
	)
	_register_material_role(
		material_roles,
		material_library.get_material("foliage_sunlit"),
		"sunlit"
	)
	_register_material_role(
		material_roles,
		material_library.get_material("canopy"),
		"canopy"
	)
	_walk_vegetation_meshes(environment_root, material_roles)
	vegetation_presentation_counts = (
		vegetation_presentation_director.role_counts.duplicate(true)
	)


func _register_material_role(
	lookup: Dictionary,
	material: StandardMaterial3D,
	role: String
) -> void:
	if material == null:
		return
	lookup[material.get_instance_id()] = role


func _walk_vegetation_meshes(node: Node, material_roles: Dictionary) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = (
				mesh_instance.material_override as StandardMaterial3D
			)
			var material_id: int = material.get_instance_id()
			if material_roles.has(material_id):
				vegetation_presentation_director.register_mesh(
					mesh_instance,
					str(material_roles[material_id])
				)
	for child: Node in node.get_children():
		_walk_vegetation_meshes(child, material_roles)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_vegetation_presentation"] = true
	data["vegetation_presentation_authority"] = "VegetationPresentationDirector"
	data["vegetation_presentation_counts"] = vegetation_presentation_counts.duplicate(true)
	data["vegetation_strategy"] = (
		"two-sided wrapped diffuse + backlight + restrained transmittance"
	)
	data["vegetation_geometry_unchanged"] = true
	return data
