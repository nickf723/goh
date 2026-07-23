extends Resource
class_name GasDefinition

@export var gas_id: String = "gas"
@export var display_name: String = "Gas"
@export_multiline var description: String = "A simulated atmospheric substance."

@export_group("Transport")
@export var maximum_density: float = 1.0
@export_range(0.0, 4.0, 0.01) var advection_scale: float = 1.0
@export_range(0.0, 4.0, 0.01) var diffusion_rate: float = 0.12
@export_range(0.0, 4.0, 0.01) var decay_rate_per_second: float = 0.03
@export var buoyancy_velocity: Vector3 = Vector3.UP

@export_group("Exposure")
@export_range(0.0, 1.0, 0.01) var exposure_threshold: float = 0.12
@export_range(0.0, 8.0, 0.01) var exposure_gain_rate: float = 0.9
@export_range(0.0, 8.0, 0.01) var exposure_decay_rate: float = 0.55
@export var harmful: bool = false
@export_range(0.05, 10.0, 0.05) var damage_interval: float = 1.0
@export_range(0, 100, 1) var damage_per_tick: int = 0
@export var status_name: String = ""
@export_range(0.0, 20.0, 0.1) var status_duration: float = 0.0
@export_range(0.0, 20.0, 0.1) var status_strength: float = 0.0
@export var obscures_vision: bool = false

@export_group("Presentation")
@export var visual_color: Color = Color(0.65, 0.72, 0.78, 0.25)
@export_range(0.0, 8.0, 0.05) var emission_energy: float = 0.45
@export_range(0.0, 1.0, 0.01) var visual_density_threshold: float = 0.025
@export var tags: Array[String] = ["gas", "atmosphere"]


func clamp_density(value: float) -> float:
	return clampf(value, 0.0, max(maximum_density, 0.001))


func get_density_ratio(value: float) -> float:
	return clamp_density(value) / max(maximum_density, 0.001)


func get_decay_multiplier(delta: float) -> float:
	return exp(-max(decay_rate_per_second, 0.0) * max(delta, 0.0))


func is_exposure_active(density: float) -> bool:
	return density >= max(exposure_threshold, 0.0)


func get_debug_data() -> Dictionary:
	return {
		"gas_id": gas_id,
		"display_name": display_name,
		"advection_scale": snapped(advection_scale, 0.01),
		"diffusion_rate": snapped(diffusion_rate, 0.01),
		"decay_rate": snapped(decay_rate_per_second, 0.01),
		"buoyancy_velocity": buoyancy_velocity,
		"exposure_threshold": snapped(exposure_threshold, 0.01),
		"harmful": harmful,
		"damage_per_tick": damage_per_tick,
		"tags": tags.duplicate(),
	}
