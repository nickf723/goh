extends "res://scripts/environment/green_grotto_material_library.gd"
class_name GreenGrottoDetailMaterialLibrary


func get_material(material_id: String) -> StandardMaterial3D:
	var normalized: String = material_id.strip_edges().to_lower()
	if materials.has(normalized):
		return materials[normalized] as StandardMaterial3D

	var material: StandardMaterial3D = null
	match normalized:
		"paving":
			material = _make_noise_material(
				Color(0.045, 0.060, 0.045),
				Color(0.115, 0.135, 0.080),
				Color(0.205, 0.195, 0.120),
				9137,
				0.072,
				0.96,
				0.0,
				Vector3(5.2, 5.2, 5.2)
			)
		"paving_wet":
			material = _make_noise_material(
				Color(0.025, 0.045, 0.038),
				Color(0.075, 0.105, 0.080),
				Color(0.145, 0.160, 0.105),
				6541,
				0.078,
				0.55,
				0.02,
				Vector3(5.4, 5.4, 5.4)
			)
		"river_rock":
			material = _make_noise_material(
				Color(0.018, 0.030, 0.027),
				Color(0.055, 0.075, 0.062),
				Color(0.105, 0.120, 0.090),
				7719,
				0.061,
				0.78,
				0.015,
				Vector3(4.4, 4.4, 4.4)
			)
		"soil_wet":
			material = _make_noise_material(
				Color(0.012, 0.016, 0.010),
				Color(0.040, 0.048, 0.025),
				Color(0.095, 0.075, 0.035),
				3491,
				0.055,
				0.88,
				0.0,
				Vector3(4.6, 4.6, 4.6)
			)
		"leaf_litter":
			material = _make_noise_material(
				Color(0.035, 0.030, 0.012),
				Color(0.115, 0.090, 0.025),
				Color(0.225, 0.175, 0.050),
				2251,
				0.090,
				0.97,
				0.0,
				Vector3(6.0, 6.0, 6.0),
				true
			)
		"water_shallow":
			material = _make_flat_material(
				Color(0.030, 0.205, 0.155, 0.78),
				0.10,
				0.035,
				0.06,
				true
			)
		"water_deep":
			material = _make_flat_material(
				Color(0.012, 0.095, 0.085, 0.88),
				0.16,
				0.055,
				0.04,
				true
			)
		"water_foam":
			material = _make_flat_material(
				Color(0.48, 0.74, 0.58, 0.42),
				0.22,
				0.0,
				0.08,
				true
			)
		_:
			return super.get_material(normalized)

	materials[normalized] = material
	return material


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_detail_materials"] = true
	data["detail_material_ids"] = [
		"paving",
		"paving_wet",
		"river_rock",
		"soil_wet",
		"leaf_litter",
		"water_shallow",
		"water_deep",
		"water_foam",
	]
	return data
