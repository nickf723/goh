extends Resource
class_name GroundContactPresentationProfile

@export var profile_id: String = "ground_contact_default"
@export var display_name: String = "Ground Contact Presentation"

@export_group("Quality")
@export_range(0.0, 1.0, 0.05) var performance_density: float = 0.0
@export_range(0.0, 1.0, 0.05) var balanced_density: float = 0.68
@export_range(0.0, 1.0, 0.05) var cinematic_density: float = 1.0

@export_group("Pool")
@export_range(16, 256, 1) var maximum_particles: int = 72
@export_range(0.1, 2.0, 0.05) var maximum_lifetime: float = 0.62
@export_range(0.0, 12.0, 0.1) var gravity: float = 3.6
@export_range(0.0, 8.0, 0.1) var drag: float = 2.2

@export_group("Footsteps")
@export_range(0, 12, 1) var stone_footstep_particles: int = 2
@export_range(0, 12, 1) var soil_footstep_particles: int = 4
@export_range(0, 12, 1) var wet_footstep_particles: int = 3
@export_range(0.0, 2.0, 0.01) var footstep_velocity_scale: float = 0.58

@export_group("Landings")
@export_range(0, 24, 1) var stone_landing_particles: int = 6
@export_range(0, 24, 1) var soil_landing_particles: int = 10
@export_range(0, 24, 1) var wet_landing_particles: int = 8
@export_range(0.0, 3.0, 0.01) var landing_velocity_scale: float = 1.05

@export_group("Colors")
@export var stone_color: Color = Color(0.43, 0.40, 0.31, 0.42)
@export var paving_color: Color = Color(0.50, 0.46, 0.33, 0.38)
@export var soil_color: Color = Color(0.27, 0.24, 0.10, 0.46)
@export var moss_color: Color = Color(0.23, 0.39, 0.12, 0.46)
@export var wet_color: Color = Color(0.34, 0.68, 0.60, 0.40)


func get_density_scale(quality: int) -> float:
	match clampi(quality, 0, 2):
		0:
			return performance_density
		1:
			return balanced_density
		_:
			return cinematic_density


func get_debug_data() -> Dictionary:
	return {
		"ground_contact_presentation_profile": true,
		"profile_id": profile_id,
		"maximum_particles": maximum_particles,
		"performance_density": performance_density,
		"balanced_density": balanced_density,
		"cinematic_density": cinematic_density,
	}
