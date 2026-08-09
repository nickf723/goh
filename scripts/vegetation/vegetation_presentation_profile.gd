extends Resource
class_name VegetationPresentationProfile

@export var profile_id: String = "vegetation_default"
@export var display_name: String = "Vegetation Presentation"

@export_group("Shared Shading")
@export_range(0.1, 8.0, 0.1) var triplanar_sharpness: float = 1.6
@export_range(0.05, 2.0, 0.01) var world_scale_multiplier: float = 0.62
@export_range(0.0, 1.0, 0.01) var normal_scale: float = 0.34
@export_range(0.001, 1.0, 0.001) var normal_noise_frequency: float = 0.13
@export_range(64, 256, 64) var texture_resolution: int = 128
@export var detail_seed: int = 4319

@export_group("Ground Foliage")
@export var ground_backlight_color: Color = Color(0.26, 0.52, 0.11, 1.0)
@export_range(0.0, 2.0, 0.01) var ground_backlight_strength: float = 0.72
@export_range(0.0, 1.0, 0.01) var ground_sss_strength: float = 0.075
@export var ground_transmittance_color: Color = Color(0.24, 0.58, 0.10, 1.0)
@export_range(0.0, 8.0, 0.05) var ground_transmittance_boost: float = 0.80
@export_range(0.001, 1.0, 0.001) var ground_transmittance_depth: float = 0.12
@export_range(0.0, 1.0, 0.01) var ground_roughness: float = 0.88

@export_group("Sunlit Foliage")
@export var sunlit_backlight_color: Color = Color(0.62, 0.78, 0.17, 1.0)
@export_range(0.0, 2.0, 0.01) var sunlit_backlight_strength: float = 0.94
@export_range(0.0, 1.0, 0.01) var sunlit_sss_strength: float = 0.11
@export var sunlit_transmittance_color: Color = Color(0.53, 0.76, 0.13, 1.0)
@export_range(0.0, 8.0, 0.05) var sunlit_transmittance_boost: float = 1.15
@export_range(0.001, 1.0, 0.001) var sunlit_transmittance_depth: float = 0.10
@export_range(0.0, 1.0, 0.01) var sunlit_roughness: float = 0.84

@export_group("Canopy")
@export var canopy_backlight_color: Color = Color(0.10, 0.31, 0.08, 1.0)
@export_range(0.0, 2.0, 0.01) var canopy_backlight_strength: float = 0.58
@export_range(0.0, 1.0, 0.01) var canopy_sss_strength: float = 0.025
@export var canopy_transmittance_color: Color = Color(0.10, 0.34, 0.07, 1.0)
@export_range(0.0, 8.0, 0.05) var canopy_transmittance_boost: float = 0.34
@export_range(0.001, 1.0, 0.001) var canopy_transmittance_depth: float = 0.18
@export_range(0.0, 1.0, 0.01) var canopy_roughness: float = 0.94

@export_group("Budgets")
@export_range(1, 16, 1) var maximum_shared_variants: int = 6


func get_debug_data() -> Dictionary:
	return {
		"vegetation_presentation_profile": true,
		"profile_id": profile_id,
		"world_scale_multiplier": world_scale_multiplier,
		"normal_scale": normal_scale,
		"ground_sss": ground_sss_strength,
		"sunlit_sss": sunlit_sss_strength,
		"canopy_sss": canopy_sss_strength,
		"maximum_shared_variants": maximum_shared_variants,
	}
