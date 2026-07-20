extends Resource
class_name PhysicalMaterialProfile

@export var material_id: String = "generic"
@export var display_name: String = "Generic Material"
@export var density_kg_m3: float = 1000.0
@export var default_mass_kg: float = 1.0

@export_group("Electrical")
@export_range(0.0, 1.0, 0.01) var electrical_conductivity: float = 0.0
@export var electrical_resistivity: float = 1.0

@export_group("Magnetic")
@export_range(0.0, 1.0, 0.01) var magnetic_susceptibility: float = 0.0
@export_range(0.0, 1.0, 0.01) var magnetic_retention: float = 0.0
@export_range(0.0, 2.0, 0.01) var permanent_magnetic_strength: float = 0.0

@export_group("Thermal")
@export var specific_heat_capacity_j_kg_c: float = 1000.0
@export var thermal_conductivity_w_m_c: float = 0.5
@export var freezing_point_c: float = 0.0
@export var boiling_point_c: float = 1000000.0
@export var ignition_temperature_c: float = 1000000.0
@export var melting_point_c: float = 1000000.0

@export_group("Combustion")
@export var combustible: bool = false
@export var default_fuel_mass_kg: float = 0.0
@export var burn_rate_kg_per_second: float = 0.0
@export var combustion_heat_j_per_second: float = 0.0
@export var sustain_temperature_c: float = 1000000.0
@export_range(0.0, 1.0, 0.01) var smoke_yield: float = 0.0
@export_range(0.0, 1.0, 0.01) var ember_yield: float = 0.0

@export_group("Classification")
@export var material_tags: Array[String] = []


func is_conductive(minimum: float = 0.1) -> bool:
	return electrical_conductivity >= minimum


func is_magnetically_responsive(minimum: float = 0.05) -> bool:
	return magnetic_susceptibility >= minimum or permanent_magnetic_strength > 0.0


func supports_retained_magnetization() -> bool:
	return magnetic_retention > 0.0 and magnetic_susceptibility > 0.0


func is_combustible() -> bool:
	return combustible and default_fuel_mass_kg > 0.0 and burn_rate_kg_per_second > 0.0


func get_effective_mass(override_mass_kg: float = 0.0) -> float:
	if override_mass_kg > 0.0:
		return override_mass_kg
	return max(default_mass_kg, 0.01)


func get_debug_data() -> Dictionary:
	return {
		"material_id": material_id,
		"material": display_name,
		"density_kg_m3": snapped(density_kg_m3, 0.1),
		"default_mass_kg": snapped(default_mass_kg, 0.01),
		"conductivity": snapped(electrical_conductivity, 0.01),
		"resistivity": snapped(electrical_resistivity, 0.001),
		"magnetic_susceptibility": snapped(magnetic_susceptibility, 0.01),
		"magnetic_retention": snapped(magnetic_retention, 0.01),
		"permanent_magnetic_strength": snapped(permanent_magnetic_strength, 0.01),
		"specific_heat_capacity": snapped(specific_heat_capacity_j_kg_c, 0.1),
		"thermal_conductivity": snapped(thermal_conductivity_w_m_c, 0.01),
		"freezing_point_c": snapped(freezing_point_c, 0.1),
		"boiling_point_c": snapped(boiling_point_c, 0.1),
		"ignition_temperature_c": snapped(ignition_temperature_c, 0.1),
		"melting_point_c": snapped(melting_point_c, 0.1),
		"combustible": combustible,
		"default_fuel_mass_kg": snapped(default_fuel_mass_kg, 0.001),
		"burn_rate_kg_per_second": snapped(burn_rate_kg_per_second, 0.001),
		"combustion_heat_j_per_second": snapped(combustion_heat_j_per_second, 0.01),
		"sustain_temperature_c": snapped(sustain_temperature_c, 0.1),
		"smoke_yield": snapped(smoke_yield, 0.01),
		"ember_yield": snapped(ember_yield, 0.01),
		"tags": material_tags.duplicate(),
	}