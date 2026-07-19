extends Resource
class_name FluidPresentationProfile

@export_group("Surface Palette")
@export var shallow_color: Color = Color(0.08, 0.62, 0.88, 0.7)
@export var deep_color: Color = Color(0.012, 0.1, 0.3, 0.88)
@export var foam_color: Color = Color(0.72, 0.96, 1.0, 0.92)
@export var electrical_color: Color = Color(0.45, 0.65, 1.0, 1.0)
@export var hot_color: Color = Color(0.36, 0.78, 0.94, 1.0)

@export_group("Surface Motion")
@export var large_wave_scale: float = 0.75
@export var small_wave_scale: float = 2.4
@export var wave_amplitude: float = 0.09
@export var wave_speed: float = 1.0
@export var normal_strength: float = 0.52
@export var flow_band_scale: float = 34.0
@export var flow_band_strength: float = 0.16
@export var roughness: float = 0.08
@export var specular: float = 0.92
@export var surface_emission: float = 0.12

@export_group("Disturbances")
@export var ripple_duration: float = 0.95
@export var ripple_expansion: float = 3.2
@export var wake_duration: float = 1.15
@export var wake_length_scale: float = 2.4
@export var splash_lifetime: float = 0.8
@export var splash_droplets_per_strength: float = 9.0
@export var splash_velocity_scale: float = 1.0
@export var churn_interval_seconds: float = 0.12
@export var churn_particle_scale: float = 1.0
@export var maximum_active_effects: int = 96


func get_debug_data() -> Dictionary:
	return {
		"shallow_color": shallow_color,
		"deep_color": deep_color,
		"foam_color": foam_color,
		"wave_amplitude": snapped(wave_amplitude, 0.001),
		"wave_speed": snapped(wave_speed, 0.01),
		"normal_strength": snapped(normal_strength, 0.01),
		"flow_band_strength": snapped(flow_band_strength, 0.01),
		"ripple_duration": snapped(ripple_duration, 0.01),
		"wake_duration": snapped(wake_duration, 0.01),
		"splash_lifetime": snapped(splash_lifetime, 0.01),
		"maximum_active_effects": maximum_active_effects,
	}
