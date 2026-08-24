extends RefCounted
class_name StylizedPBRMaterialLibrary

const SHADER_PATH := "res://shaders/environment/stylized_pbr_surface_v1.gdshader"
const STONE_MATERIAL: ShaderMaterial = preload(
	"res://art/materials/environment/modular/stylized_pbr_stone_study.tres"
)
const WET_STONE_MATERIAL: ShaderMaterial = preload(
	"res://art/materials/environment/modular/stylized_pbr_wet_stone_v1.tres"
)
const DRY_EARTH_MATERIAL: ShaderMaterial = preload(
	"res://art/materials/environment/modular/stylized_pbr_dry_earth_v1.tres"
)
const AGED_WOOD_MATERIAL: ShaderMaterial = preload(
	"res://art/materials/environment/modular/stylized_pbr_aged_wood_v1.tres"
)
const AGED_METAL_MATERIAL: ShaderMaterial = preload(
	"res://art/materials/environment/modular/stylized_pbr_aged_metal_v1.tres"
)

const FAMILY_IDS: Array[String] = [
	"stone",
	"wet_stone",
	"dry_earth",
	"aged_wood",
	"aged_metal",
]
const LEGACY_PATH_TO_FAMILY: Dictionary = {
	"res://art/materials/environment/modular/weathered_stone.tres": "stone",
	"res://art/materials/environment/modular/trim_stone.tres": "stone",
	"res://art/materials/environment/modular/wet_stone.tres": "wet_stone",
	"res://art/materials/environment/modular/dry_earth.tres": "dry_earth",
	"res://art/materials/environment/modular/aged_wood.tres": "aged_wood",
	"res://art/materials/environment/modular/aged_metal.tres": "aged_metal",
}


static func get_family_ids() -> Array[String]:
	return FAMILY_IDS.duplicate()


static func get_material(family_id: String) -> ShaderMaterial:
	match family_id:
		"stone":
			return STONE_MATERIAL
		"wet_stone":
			return WET_STONE_MATERIAL
		"dry_earth":
			return DRY_EARTH_MATERIAL
		"aged_wood":
			return AGED_WOOD_MATERIAL
		"aged_metal":
			return AGED_METAL_MATERIAL
	return null


static func get_material_for_legacy_path(
	legacy_path: String
) -> ShaderMaterial:
	var family_id: String = str(
		LEGACY_PATH_TO_FAMILY.get(legacy_path, "")
	)
	return get_material(family_id)


static func apply_to_subtree(root: Node) -> Dictionary:
	var family_counts: Dictionary = {}
	for family_id: String in FAMILY_IDS:
		family_counts[family_id] = 0
	var result: Dictionary = {
		"total": 0,
		"families": family_counts,
		"unmapped": 0,
	}
	if root == null:
		return result

	var candidates: Array[Node] = []
	if root is MeshInstance3D:
		candidates.append(root)
	candidates.append_array(
		root.find_children("*", "MeshInstance3D", true, false)
	)
	for candidate: Node in candidates:
		var mesh_instance: MeshInstance3D = candidate as MeshInstance3D
		if mesh_instance == null:
			continue
		var current_material: Material = mesh_instance.material_override
		if current_material == null:
			continue
		var legacy_path: String = current_material.resource_path
		var family_id: String = str(
			LEGACY_PATH_TO_FAMILY.get(legacy_path, "")
		)
		if family_id.is_empty():
			result["unmapped"] = int(result.get("unmapped", 0)) + 1
			continue
		var replacement: ShaderMaterial = get_material(family_id)
		if replacement == null:
			continue
		mesh_instance.material_override = replacement
		result["total"] = int(result.get("total", 0)) + 1
		family_counts[family_id] = int(
			family_counts.get(family_id, 0)
		) + 1
	result["families"] = family_counts
	return result


static func validate_library() -> Array[String]:
	var failures: Array[String] = []
	for family_id: String in FAMILY_IDS:
		var material: ShaderMaterial = get_material(family_id)
		if material == null:
			failures.append(family_id + " material is missing")
			continue
		if material.shader == null:
			failures.append(family_id + " material has no shader")
			continue
		if material.shader.resource_path != SHADER_PATH:
			failures.append(
				family_id + " material does not use stylized PBR v1"
			)
		var band_softness: Variant = material.get_shader_parameter(
			"band_softness"
		)
		var rim_intensity: Variant = material.get_shader_parameter(
			"rim_intensity"
		)
		var roughness: Variant = material.get_shader_parameter(
			"roughness_value"
		)
		if not band_softness is float or float(band_softness) <= 0.0:
			failures.append(family_id + " has invalid band softness")
		if not rim_intensity is float or float(rim_intensity) < 0.0:
			failures.append(family_id + " has invalid rim intensity")
		if (
			not roughness is float
			or float(roughness) < 0.04
			or float(roughness) > 1.0
		):
			failures.append(family_id + " has invalid roughness")
	return failures
