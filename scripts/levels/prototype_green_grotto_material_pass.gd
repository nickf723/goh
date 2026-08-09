extends "res://scripts/levels/prototype_green_grotto_surface_story_pass.gd"
class_name PrototypeGreenGrottoMaterialPass

var material_fidelity_director: MaterialFidelityDirector3D = null
var material_fidelity_counts: Dictionary = {}


func _ready() -> void:
	super._ready()
	material_fidelity_director = get_node_or_null(
		"MaterialFidelityDirector"
	) as MaterialFidelityDirector3D
	_register_material_fidelity_targets()
	set_meta("material_fidelity_pass", "material_fidelity_director_v1")
	set_meta("material_fidelity_authority", "MaterialFidelityDirector")
	set_meta("material_fidelity_counts", material_fidelity_counts.duplicate(true))


func _register_material_fidelity_targets() -> void:
	if material_fidelity_director == null or environment_root == null:
		return
	var material_categories: Dictionary = {}

	_register_material_category(material_categories, hero_materials.get_material("hero_rock"), "rock")
	_register_material_category(material_categories, hero_materials.get_material("hero_rock_wet"), "rock_wet")
	_register_material_category(material_categories, hero_materials.get_material("hero_paving"), "paving")
	_register_material_category(material_categories, hero_materials.get_material("hero_paving_wet"), "paving_wet")
	_register_material_category(material_categories, hero_materials.get_material("hero_masonry"), "masonry")
	_register_material_category(material_categories, hero_materials.get_material("hero_trim"), "trim")
	_register_material_category(material_categories, hero_materials.get_material("hero_wood"), "wood")
	_register_material_category(material_categories, hero_materials.get_material("hero_roof"), "roof")
	_register_material_category(material_categories, hero_materials.get_material("hero_soil"), "soil")

	_register_material_category(material_categories, detail_materials.get_material("paving"), "paving")
	_register_material_category(material_categories, detail_materials.get_material("paving_wet"), "paving_wet")
	_register_material_category(material_categories, detail_materials.get_material("river_rock"), "rock_wet")
	_register_material_category(material_categories, detail_materials.get_material("soil_wet"), "soil_wet")

	_register_material_category(material_categories, material_library.get_material("stone"), "rock")
	_register_material_category(material_categories, material_library.get_material("stone_warm"), "masonry")
	_register_material_category(material_categories, material_library.get_material("stone_dark"), "rock")
	_register_material_category(material_categories, material_library.get_material("bark"), "bark")
	_register_material_category(material_categories, material_library.get_material("root"), "root")
	_register_material_category(material_categories, material_library.get_material("roof"), "roof")
	_register_material_category(material_categories, material_library.get_material("wood"), "wood")
	_register_material_category(material_categories, material_library.get_material("soil"), "soil")

	_walk_material_nodes(environment_root, material_categories)
	material_fidelity_counts = material_fidelity_director.category_counts.duplicate(true)


func _register_material_category(
	lookup: Dictionary,
	material: StandardMaterial3D,
	category: String
) -> void:
	if material == null:
		return
	lookup[material.get_instance_id()] = category


func _walk_material_nodes(node: Node, material_categories: Dictionary) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
			var material_id: int = material.get_instance_id()
			if material_categories.has(material_id):
				material_fidelity_director.register_mesh(
					mesh_instance,
					str(material_categories[material_id])
				)
	for child: Node in node.get_children():
		_walk_material_nodes(child, material_categories)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_material_fidelity"] = true
	data["material_fidelity_authority"] = "MaterialFidelityDirector"
	data["material_fidelity_counts"] = material_fidelity_counts.duplicate(true)
	data["material_strategy"] = "shared world-triplanar PBR detail on authored surface families"
	return data
