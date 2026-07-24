extends Resource
class_name StructuralMaterialProfile

@export var material_id: String = "generic_structure"
@export var display_name: String = "Generic Structure"
@export var physical_material: PhysicalMaterialProfile

@export_group("Capacity")
@export_range(1.0, 20000.0, 1.0) var base_capacity_n: float = 1000.0
@export_range(0.01, 2.0, 0.01) var minimum_damage_multiplier: float = 0.12
@export_range(0.0, 2.0, 0.01) var cold_capacity_multiplier: float = 0.72
@export_range(0.01, 2.0, 0.01) var overload_grace_seconds: float = 0.12

@export_group("Payload Response")
@export_range(0.0, 1000.0, 1.0) var stress_per_damage_point_n: float = 150.0
@export_range(0.0, 1000.0, 1.0) var stress_per_stance_point_n: float = 110.0
@export_range(0.0, 500.0, 1.0) var stress_per_knockback_n: float = 70.0
@export_range(0.0, 3.0, 0.01) var force_tag_multiplier: float = 1.35
@export_range(0.0, 3.0, 0.01) var heavy_tag_multiplier: float = 1.2
@export_range(0.0, 1.0, 0.01) var damage_per_payload_point: float = 0.045

@export_group("Fire and Ice")
@export var burnable: bool = false
@export_range(0.0, 2.0, 0.01) var burn_weakening_per_second: float = 0.35
@export_range(0.0, 1.0, 0.01) var burned_capacity_multiplier: float = 0.08
@export var brittle_temperature_c: float = -20.0

@export_group("Presentation")
@export var intact_color: Color = Color(0.55, 0.55, 0.58, 1.0)
@export var stressed_color: Color = Color(1.0, 0.56, 0.12, 1.0)
@export var failed_color: Color = Color(0.18, 0.12, 0.1, 1.0)


func get_effective_capacity(
	damage_fraction: float,
	burn_fraction: float,
	is_brittle: bool
) -> float:
	var damage_multiplier: float = lerpf(
		1.0,
		minimum_damage_multiplier,
		clampf(damage_fraction, 0.0, 1.0)
	)
	var burn_multiplier: float = 1.0
	if burnable:
		burn_multiplier = lerpf(
			1.0,
			burned_capacity_multiplier,
			clampf(burn_fraction, 0.0, 1.0)
		)
	var brittle_multiplier: float = cold_capacity_multiplier if is_brittle else 1.0
	return maxf(
		base_capacity_n * damage_multiplier * burn_multiplier * brittle_multiplier,
		1.0
	)


func get_payload_stress(payload: DamagePayload) -> float:
	if payload == null:
		return 0.0
	var stress_n: float = maxf(
		float(payload.amount) * stress_per_damage_point_n,
		float(payload.stance_damage) * stress_per_stance_point_n
	)
	stress_n += (
		maxf(payload.knockback_strength, 0.0)
		+ maxf(payload.knockback_up_strength, 0.0)
	) * stress_per_knockback_n
	if payload.tags.has("force") or payload.tags.has("blunt") or payload.tags.has("explosion"):
		stress_n *= force_tag_multiplier
	if payload.tags.has("heavy") or payload.tags.has("heavy_impact") or payload.tags.has("finisher"):
		stress_n *= heavy_tag_multiplier
	return stress_n


func get_debug_data() -> Dictionary:
	return {
		"structural_material": material_id,
		"capacity_n": snapped(base_capacity_n, 0.1),
		"burnable": burnable,
		"cold_capacity_multiplier": snapped(cold_capacity_multiplier, 0.01),
		"physical_material": (
			physical_material.material_id
			if physical_material != null
			else "none"
		),
	}
