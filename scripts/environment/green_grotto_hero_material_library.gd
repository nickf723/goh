extends "res://scripts/environment/green_grotto_detail_material_library.gd"
class_name GreenGrottoHeroMaterialLibrary


func get_material(material_id: String) -> StandardMaterial3D:
	var normalized: String = material_id.strip_edges().to_lower()
	if materials.has(normalized):
		return materials[normalized] as StandardMaterial3D

	var material: StandardMaterial3D = null
	match normalized:
		"hero_paving":
			material = _make_noise_material(
				Color(0.038, 0.052, 0.040),
				Color(0.100, 0.120, 0.075),
				Color(0.205, 0.190, 0.115),
				14417,
				0.095,
				0.94,
				0.0,
				Vector3(6.4, 6.4, 6.4)
			)
		"hero_paving_wet":
			material = _make_noise_material(
				Color(0.018, 0.035, 0.030),
				Color(0.060, 0.090, 0.068),
				Color(0.135, 0.150, 0.095),
				22109,
				0.10,
				0.46,
				0.03,
				Vector3(6.8, 6.8, 6.8)
			)
		"hero_rock":
			material = _make_noise_material(
				Color(0.014, 0.023, 0.019),
				Color(0.048, 0.067, 0.053),
				Color(0.105, 0.115, 0.078),
				19811,
				0.052,
				0.97,
				0.0,
				Vector3(4.8, 4.8, 4.8)
			)
		"hero_rock_wet":
			material = _make_noise_material(
				Color(0.010, 0.025, 0.023),
				Color(0.035, 0.070, 0.060),
				Color(0.078, 0.118, 0.092),
				17449,
				0.060,
				0.42,
				0.04,
				Vector3(5.2, 5.2, 5.2)
			)
		"hero_masonry":
			material = _make_noise_material(
				Color(0.045, 0.055, 0.038),
				Color(0.125, 0.135, 0.080),
				Color(0.245, 0.215, 0.120),
				12577,
				0.070,
				0.93,
				0.0,
				Vector3(5.5, 5.5, 5.5)
			)
		"hero_trim":
			material = _make_noise_material(
				Color(0.055, 0.060, 0.035),
				Color(0.145, 0.135, 0.070),
				Color(0.290, 0.240, 0.110),
				2887,
				0.085,
				0.84,
				0.0,
				Vector3(7.0, 7.0, 7.0)
			)
		"hero_wood":
			material = _make_noise_material(
				Color(0.022, 0.014, 0.008),
				Color(0.072, 0.040, 0.015),
				Color(0.175, 0.095, 0.030),
				8573,
				0.075,
				0.86,
				0.0,
				Vector3(1.2, 6.0, 1.2)
			)
		"hero_roof":
			material = _make_noise_material(
				Color(0.018, 0.032, 0.022),
				Color(0.050, 0.082, 0.045),
				Color(0.135, 0.155, 0.070),
				1907,
				0.088,
				0.72,
				0.035,
				Vector3(7.0, 7.0, 7.0)
			)
		"hero_soil":
			material = _make_noise_material(
				Color(0.012, 0.015, 0.009),
				Color(0.045, 0.043, 0.020),
				Color(0.110, 0.085, 0.032),
				3313,
				0.080,
				1.0,
				0.0,
				Vector3(6.0, 6.0, 6.0)
			)
		"hero_moss":
			material = _make_noise_material(
				Color(0.012, 0.060, 0.020),
				Color(0.040, 0.170, 0.045),
				Color(0.185, 0.355, 0.080),
				911,
				0.075,
				1.0,
				0.0,
				Vector3(7.5, 7.5, 7.5),
				true
			)
		"hero_water_shallow":
			material = _make_flat_material(
				Color(0.025, 0.235, 0.185, 1.0),
				0.12,
				0.06,
				0.025,
				false
			)
		"hero_water_deep":
			material = _make_flat_material(
				Color(0.008, 0.105, 0.095, 1.0),
				0.09,
				0.10,
				0.018,
				false
			)
		"hero_waterfall":
			material = _make_flat_material(
				Color(0.22, 0.58, 0.47, 0.78),
				0.10,
				0.0,
				0.06,
				true
			)
		"hero_foam":
			material = _make_flat_material(
				Color(0.62, 0.82, 0.66, 0.48),
				0.25,
				0.0,
				0.08,
				true
			)
		"hero_leaf_litter":
			material = _make_noise_material(
				Color(0.025, 0.025, 0.010),
				Color(0.085, 0.070, 0.020),
				Color(0.190, 0.135, 0.035),
				1711,
				0.12,
				1.0,
				0.0,
				Vector3(8.0, 8.0, 8.0),
				true
			)
		_:
			return super.get_material(normalized)

	materials[normalized] = material
	return material


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_hero_materials"] = true
	data["hero_material_ids"] = [
		"hero_paving",
		"hero_paving_wet",
		"hero_rock",
		"hero_rock_wet",
		"hero_masonry",
		"hero_trim",
		"hero_wood",
		"hero_roof",
		"hero_soil",
		"hero_moss",
		"hero_water_shallow",
		"hero_water_deep",
		"hero_waterfall",
		"hero_foam",
		"hero_leaf_litter",
	]
	return data
