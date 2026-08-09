extends RefCounted
class_name GreenGrottoMaterialLibrary

var materials: Dictionary = {}
var textures: Array[NoiseTexture2D] = []


func get_material(material_id: String) -> StandardMaterial3D:
	var normalized: String = material_id.strip_edges().to_lower()
	if materials.has(normalized):
		return materials[normalized] as StandardMaterial3D
	var material: StandardMaterial3D
	match normalized:
		"stone":
			material = _make_noise_material(
				Color(0.075, 0.095, 0.075),
				Color(0.19, 0.22, 0.15),
				Color(0.34, 0.31, 0.20),
				8172,
				0.018,
				0.94,
				0.0,
				Vector3(2.8, 2.8, 2.8)
			)
		"stone_warm":
			material = _make_noise_material(
				Color(0.10, 0.10, 0.07),
				Color(0.28, 0.25, 0.15),
				Color(0.49, 0.39, 0.20),
				1827,
				0.021,
				0.91,
				0.0,
				Vector3(2.4, 2.4, 2.4)
			)
		"stone_dark":
			material = _make_noise_material(
				Color(0.025, 0.035, 0.028),
				Color(0.075, 0.09, 0.065),
				Color(0.14, 0.14, 0.095),
				6713,
				0.024,
				0.98,
				0.0,
				Vector3(3.2, 3.2, 3.2)
			)
		"moss":
			material = _make_noise_material(
				Color(0.025, 0.09, 0.025),
				Color(0.08, 0.24, 0.045),
				Color(0.24, 0.43, 0.09),
				4183,
				0.034,
				1.0,
				0.0,
				Vector3(3.8, 3.8, 3.8)
			)
		"foliage":
			material = _make_noise_material(
				Color(0.015, 0.07, 0.025),
				Color(0.035, 0.20, 0.055),
				Color(0.16, 0.42, 0.12),
				9917,
				0.029,
				0.92,
				0.0,
				Vector3(2.0, 2.0, 2.0),
				true
			)
		"foliage_sunlit":
			material = _make_noise_material(
				Color(0.03, 0.11, 0.025),
				Color(0.12, 0.34, 0.06),
				Color(0.46, 0.58, 0.12),
				2369,
				0.032,
				0.9,
				0.0,
				Vector3(2.2, 2.2, 2.2),
				true
			)
		"canopy":
			material = _make_noise_material(
				Color(0.006, 0.025, 0.012),
				Color(0.015, 0.065, 0.025),
				Color(0.04, 0.13, 0.04),
				5521,
				0.026,
				0.96,
				0.0,
				Vector3(1.8, 1.8, 1.8),
				true
			)
		"bark":
			material = _make_noise_material(
				Color(0.025, 0.022, 0.014),
				Color(0.075, 0.055, 0.025),
				Color(0.15, 0.105, 0.045),
				3203,
				0.045,
				1.0,
				0.0,
				Vector3(1.35, 4.8, 1.35)
			)
		"root":
			material = _make_noise_material(
				Color(0.018, 0.02, 0.012),
				Color(0.055, 0.06, 0.025),
				Color(0.13, 0.12, 0.045),
				7321,
				0.04,
				0.99,
				0.0,
				Vector3(1.2, 5.0, 1.2)
			)
		"roof":
			material = _make_noise_material(
				Color(0.025, 0.04, 0.028),
				Color(0.065, 0.10, 0.055),
				Color(0.18, 0.20, 0.075),
				6097,
				0.036,
				0.88,
				0.04,
				Vector3(2.8, 2.8, 2.8)
			)
		"wood":
			material = _make_noise_material(
				Color(0.035, 0.022, 0.012),
				Color(0.13, 0.075, 0.025),
				Color(0.27, 0.15, 0.055),
				4901,
				0.04,
				0.9,
				0.0,
				Vector3(1.1, 4.0, 1.1)
			)
		"soil":
			material = _make_noise_material(
				Color(0.02, 0.018, 0.012),
				Color(0.075, 0.055, 0.025),
				Color(0.15, 0.105, 0.045),
				1409,
				0.028,
				1.0,
				0.0,
				Vector3(3.4, 3.4, 3.4)
			)
		"water":
			material = _make_water_material()
		"waterfall":
			material = _make_waterfall_material()
		"sun_glow":
			material = _make_flat_material(
				Color(1.0, 0.53, 0.16, 0.5),
				0.38,
				0.0,
				2.1,
				true
			)
		"fauna_dark":
			material = _make_noise_material(
				Color(0.035, 0.045, 0.035),
				Color(0.10, 0.15, 0.10),
				Color(0.24, 0.28, 0.13),
				7357,
				0.045,
				0.82,
				0.0,
				Vector3(2.0, 2.0, 2.0)
			)
		"fauna_feather":
			material = _make_noise_material(
				Color(0.07, 0.055, 0.035),
				Color(0.19, 0.12, 0.055),
				Color(0.42, 0.28, 0.10),
				2579,
				0.05,
				0.86,
				0.0,
				Vector3(2.6, 2.6, 2.6),
				true
			)
		_:
			material = _make_flat_material(Color(0.35, 0.35, 0.35), 0.9)
	materials[normalized] = material
	return material


func _make_noise_material(
	dark_color: Color,
	mid_color: Color,
	light_color: Color,
	seed_value: int,
	frequency: float,
	roughness_value: float,
	metallic_value: float,
	uv_scale: Vector3,
	cull_disabled: bool = false
) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.52

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.47, 1.0])
	gradient.colors = PackedColorArray([dark_color, mid_color, light_color])

	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	texture.color_ramp = gradient
	textures.append(texture)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = texture
	material.roughness = roughness_value
	material.metallic = metallic_value
	material.uv1_scale = uv_scale
	if cull_disabled:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_flat_material(
	color: Color,
	roughness_value: float,
	metallic_value: float = 0.0,
	emission_energy: float = 0.0,
	transparent: bool = false
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	material.metallic = metallic_value
	if transparent or color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = emission_energy
	return material


func _make_water_material() -> StandardMaterial3D:
	var material := _make_flat_material(
		Color(0.035, 0.20, 0.16, 0.72),
		0.18,
		0.02,
		0.12,
		true
	)
	material.metallic = 0.08
	return material


func _make_waterfall_material() -> StandardMaterial3D:
	var material := _make_flat_material(
		Color(0.32, 0.68, 0.56, 0.54),
		0.12,
		0.0,
		0.22,
		true
	)
	return material


func get_debug_data() -> Dictionary:
	return {
		"green_grotto_material_library": true,
		"cached_materials": materials.size(),
		"procedural_textures": textures.size(),
		"uses_external_textures": false,
	}
