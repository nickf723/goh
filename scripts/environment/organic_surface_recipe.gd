extends Resource
class_name OrganicSurfaceRecipe

const GENERATOR_ID: String = "stylized_location_ground"
const USE_RECIPE_SEED: int = -2147483648
const SIGNATURE_PARAMETERS: Array[StringName] = [
	&"domain_warp_scale",
	&"domain_warp_strength",
	&"turf_scale",
	&"soil_patch_scale",
	&"micro_detail_scale",
	&"dryness",
	&"soil_amount",
	&"soil_threshold",
	&"pebble_amount",
	&"normal_strength",
]

@export var recipe_id: String = "organic_surface_default"
@export var display_name: String = "Organic Surface"
@export var generator_version: int = 1
@export var seed: int = 18890417
@export var material_template: ShaderMaterial

@export_group("Seeded Variation")
@export_range(1.0, 1024.0, 1.0) var offset_span: float = 256.0
@export_range(0.0, 0.5, 0.005) var domain_warp_variation: float = 0.12
@export_range(0.0, 0.5, 0.005) var turf_scale_variation: float = 0.08
@export_range(0.0, 0.5, 0.005) var soil_scale_variation: float = 0.12
@export_range(0.0, 0.5, 0.005) var micro_scale_variation: float = 0.08
@export_range(0.0, 0.5, 0.005) var dryness_variation: float = 0.08
@export_range(0.0, 0.5, 0.005) var soil_amount_variation: float = 0.14
@export_range(0.0, 0.25, 0.005) var soil_threshold_variation: float = 0.055
@export_range(0.0, 0.75, 0.005) var pebble_amount_variation: float = 0.24
@export_range(0.0, 0.5, 0.005) var normal_strength_variation: float = 0.10


func build_material(
	world_anchor: Vector3 = Vector3.ZERO,
	resolved_seed: int = USE_RECIPE_SEED
) -> ShaderMaterial:
	if material_template == null:
		return null
	var material: ShaderMaterial = (
		material_template.duplicate(false) as ShaderMaterial
	)
	if material == null:
		return null
	material.resource_local_to_scene = true
	var actual_seed: int = _resolve_seed(resolved_seed)
	var parameters: Dictionary = get_seed_parameters(actual_seed)
	for parameter_name: StringName in SIGNATURE_PARAMETERS:
		material.set_shader_parameter(
			parameter_name,
			parameters.get(parameter_name)
		)
	var local_offset: Vector2 = parameters.get(
		&"location_offset",
		Vector2.ZERO
	) as Vector2
	material.set_shader_parameter(
		&"location_offset",
		local_offset - Vector2(world_anchor.x, world_anchor.z)
	)
	var template_path_origin: Vector2 = _template_vector2(
		&"path_origin",
		Vector2.ZERO
	)
	material.set_shader_parameter(&"path_origin", template_path_origin)
	material.set_meta("organic_surface_recipe_id", recipe_id)
	material.set_meta("organic_surface_generator", GENERATOR_ID)
	material.set_meta("organic_surface_generator_version", generator_version)
	material.set_meta("organic_surface_seed", actual_seed)
	material.set_meta(
		"organic_surface_signature",
		get_signature(actual_seed)
	)
	return material


func get_seed_parameters(
	resolved_seed: int = USE_RECIPE_SEED
) -> Dictionary:
	var actual_seed: int = _resolve_seed(resolved_seed)
	var seeded_rng := RandomNumberGenerator.new()
	seeded_rng.seed = actual_seed
	var base_offset: Vector2 = _template_vector2(
		&"location_offset",
		Vector2.ZERO
	)
	var seeded_offset := Vector2(
		seeded_rng.randf_range(-offset_span, offset_span),
		seeded_rng.randf_range(-offset_span, offset_span)
	)
	return {
		&"location_offset": base_offset + seeded_offset,
		&"domain_warp_scale": _scaled_parameter(
			&"domain_warp_scale",
			0.04,
			seeded_rng,
			domain_warp_variation
		),
		&"domain_warp_strength": _scaled_parameter(
			&"domain_warp_strength",
			5.8,
			seeded_rng,
			domain_warp_variation
		),
		&"turf_scale": _scaled_parameter(
			&"turf_scale",
			0.17,
			seeded_rng,
			turf_scale_variation
		),
		&"soil_patch_scale": _scaled_parameter(
			&"soil_patch_scale",
			0.075,
			seeded_rng,
			soil_scale_variation
		),
		&"micro_detail_scale": _scaled_parameter(
			&"micro_detail_scale",
			1.65,
			seeded_rng,
			micro_scale_variation
		),
		&"dryness": clampf(
			_template_float(&"dryness", 0.32)
			+ seeded_rng.randf_range(-dryness_variation, dryness_variation),
			0.0,
			1.0
		),
		&"soil_amount": clampf(
			_scaled_parameter(
				&"soil_amount",
				1.15,
				seeded_rng,
				soil_amount_variation
			),
			0.0,
			1.5
		),
		&"soil_threshold": clampf(
			_template_float(&"soil_threshold", 0.44)
			+ seeded_rng.randf_range(
				-soil_threshold_variation,
				soil_threshold_variation
			),
			0.0,
			1.0
		),
		&"pebble_amount": clampf(
			_scaled_parameter(
				&"pebble_amount",
				0.28,
				seeded_rng,
				pebble_amount_variation
			),
			0.0,
			1.0
		),
		&"normal_strength": clampf(
			_scaled_parameter(
				&"normal_strength",
				0.42,
				seeded_rng,
				normal_strength_variation
			),
			0.0,
			2.0
		),
	}


func get_signature(resolved_seed: int = USE_RECIPE_SEED) -> String:
	var actual_seed: int = _resolve_seed(resolved_seed)
	var parameters: Dictionary = get_seed_parameters(actual_seed)
	var payload := PackedStringArray([
		recipe_id,
		GENERATOR_ID,
		str(generator_version),
		str(actual_seed),
	])
	var offset: Vector2 = parameters.get(
		&"location_offset",
		Vector2.ZERO
	) as Vector2
	payload.append("location_offset=%.6f,%.6f" % [offset.x, offset.y])
	for parameter_name: StringName in SIGNATURE_PARAMETERS:
		payload.append(
			"%s=%.6f" % [
				str(parameter_name),
				float(parameters.get(parameter_name, 0.0)),
			]
		)
	var digest: String = "|".join(payload).sha256_text().substr(0, 16)
	return "%s@v%d:%d:%s" % [
		recipe_id,
		generator_version,
		actual_seed,
		digest,
	]


func get_debug_data(resolved_seed: int = USE_RECIPE_SEED) -> Dictionary:
	var actual_seed: int = _resolve_seed(resolved_seed)
	return {
		"recipe_id": recipe_id,
		"display_name": display_name,
		"generator_id": GENERATOR_ID,
		"generator_version": generator_version,
		"seed": actual_seed,
		"signature": get_signature(actual_seed),
		"parameters": get_seed_parameters(actual_seed),
		"material_template": (
			material_template.resource_path
			if material_template != null
			else ""
		),
	}


func _resolve_seed(resolved_seed: int) -> int:
	return seed if resolved_seed == USE_RECIPE_SEED else resolved_seed


func _scaled_parameter(
	parameter_name: StringName,
	fallback: float,
	seeded_rng: RandomNumberGenerator,
	variation: float
) -> float:
	var base_value: float = _template_float(parameter_name, fallback)
	return base_value * seeded_rng.randf_range(
		1.0 - variation,
		1.0 + variation
	)


func _template_float(
	parameter_name: StringName,
	fallback: float
) -> float:
	if material_template == null:
		return fallback
	var value: Variant = material_template.get_shader_parameter(
		parameter_name
	)
	if value is float or value is int:
		return float(value)
	return fallback


func _template_vector2(
	parameter_name: StringName,
	fallback: Vector2
) -> Vector2:
	if material_template == null:
		return fallback
	var value: Variant = material_template.get_shader_parameter(
		parameter_name
	)
	if value is Vector2:
		return value as Vector2
	return fallback
