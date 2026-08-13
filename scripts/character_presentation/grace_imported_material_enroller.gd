extends Node
class_name GraceImportedMaterialEnroller

const ROLE_ALIASES: Dictionary = {
	"skin": ["skin", "faceskin", "bodyskin"],
	"hair": ["hair", "brows", "eyebrows"],
	"eye": ["eye", "eyes", "iris"],
	"robe": ["robe", "cloth", "outfit", "tunic", "garment"],
	"sash": ["sash", "ribbon", "clothbelt"],
	"gold": ["gold", "goldtrim", "metaltrim", "jewelry", "jewellery"],
	"leather": ["leather", "boots", "boot", "shoes", "shoe"],
	"mouth": ["mouth", "lips", "lip"],
}

@export var character_root_path: NodePath
@export var director_path: NodePath
@export var enroll_on_ready: bool = true

var director: CharacterMaterialSurfacePresentationDirector3D
var character_root: Node
var enrolled_surfaces: int = 0
var enrolled_meshes: int = 0
var unresolved_surfaces: Array[String] = []


func _ready() -> void:
	add_to_group("grace_imported_material_enroller")
	add_to_group("debuggable")
	if enroll_on_ready:
		enroll()


func enroll() -> int:
	enrolled_surfaces = 0
	enrolled_meshes = 0
	unresolved_surfaces.clear()
	director = get_node_or_null(director_path) as CharacterMaterialSurfacePresentationDirector3D
	character_root = get_node_or_null(character_root_path) if character_root_path != NodePath() else get_parent()
	if director == null or character_root == null:
		return 0
	_scan(character_root)
	return enrolled_surfaces + enrolled_meshes


func _scan(node: Node) -> void:
	if node is MeshInstance3D:
		_enroll_mesh(node as MeshInstance3D)
	for child: Node in node.get_children():
		_scan(child)


func _enroll_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	var whole_role: String = _explicit_role(mesh_instance, -1)
	if mesh_instance.mesh.get_surface_count() <= 1 and whole_role != "" and mesh_instance.material_override is StandardMaterial3D:
		if director.register_mesh(mesh_instance, whole_role):
			enrolled_meshes += 1
		return

	for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
		var role: String = _explicit_role(mesh_instance, surface_index)
		if role == "":
			role = _role_from_surface_material(mesh_instance, surface_index)
		if role != "" and director.register_surface(mesh_instance, surface_index, role):
			enrolled_surfaces += 1
			continue
		unresolved_surfaces.append("%s[%d]" % [mesh_instance.name, surface_index])


func _explicit_role(mesh_instance: MeshInstance3D, surface_index: int) -> String:
	if surface_index >= 0:
		var key: String = "character_material_surface_role_%d" % surface_index
		if mesh_instance.has_meta(key):
			return _validated_role(str(mesh_instance.get_meta(key)))
	if mesh_instance.has_meta("character_material_role"):
		return _validated_role(str(mesh_instance.get_meta("character_material_role")))
	return ""


func _role_from_surface_material(mesh_instance: MeshInstance3D, surface_index: int) -> String:
	var material: Material = mesh_instance.get_surface_override_material(surface_index)
	if material == null and mesh_instance.mesh != null:
		material = mesh_instance.mesh.surface_get_material(surface_index)
	if material == null:
		return ""
	return _role_from_name(str(material.resource_name))


func _role_from_name(value: String) -> String:
	var normalized: String = _normalize(value)
	if normalized == "":
		return ""
	for role_variant: Variant in ROLE_ALIASES.keys():
		var role: String = str(role_variant)
		for alias_variant: Variant in ROLE_ALIASES[role] as Array:
			if normalized == _normalize(str(alias_variant)):
				return role
	return ""


func _validated_role(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	return normalized if ROLE_ALIASES.has(normalized) else ""


func _normalize(value: String) -> String:
	return value.to_lower().replace("_", "").replace("-", "").replace(" ", "").replace(".", "")


func get_debug_data() -> Dictionary:
	return {
		"grace_imported_material_enroller": true,
		"director_found": director != null,
		"character_root_found": character_root != null,
		"enrolled_surfaces": enrolled_surfaces,
		"enrolled_meshes": enrolled_meshes,
		"unresolved_surface_count": unresolved_surfaces.size(),
		"unresolved_surfaces": unresolved_surfaces.duplicate(),
		"conservative_name_matching": true,
	}
