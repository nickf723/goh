extends Resource
class_name ShadowFidelityProfile

@export var profile_id: String = "default_shadow_fidelity"

@export_group("Performance")
@export var performance_directional_atlas_size: int = 2048
@export var performance_positional_atlas_size: int = 1024
@export_range(0, 5, 1) var performance_filter_quality: int = 1
@export_range(10.0, 200.0, 1.0) var performance_shadow_distance: float = 48.0
@export_range(0.0, 1.0, 0.01) var performance_fade_start: float = 0.72
@export_range(0.0, 0.3, 0.005) var performance_bias: float = 0.075
@export_range(0.0, 4.0, 0.05) var performance_normal_bias: float = 1.25
@export_range(0.0, 3.0, 0.05) var performance_blur: float = 0.85
@export_range(0.0, 2.0, 0.01) var performance_angular_distance: float = 0.0
@export_range(0.0, 1.0, 0.01) var performance_shadow_opacity: float = 0.94
@export_range(0.0, 40.0, 0.5) var performance_pancake_size: float = 14.0
@export var performance_accent_shadows: bool = false

@export_group("Balanced")
@export var balanced_directional_atlas_size: int = 4096
@export var balanced_positional_atlas_size: int = 2048
@export_range(0, 5, 1) var balanced_filter_quality: int = 3
@export_range(10.0, 200.0, 1.0) var balanced_shadow_distance: float = 76.0
@export_range(0.0, 1.0, 0.01) var balanced_fade_start: float = 0.84
@export_range(0.0, 0.3, 0.005) var balanced_bias: float = 0.055
@export_range(0.0, 4.0, 0.05) var balanced_normal_bias: float = 0.92
@export_range(0.0, 3.0, 0.05) var balanced_blur: float = 1.0
@export_range(0.0, 2.0, 0.01) var balanced_angular_distance: float = 0.28
@export_range(0.0, 1.0, 0.01) var balanced_shadow_opacity: float = 0.98
@export_range(0.0, 40.0, 0.5) var balanced_pancake_size: float = 10.0
@export var balanced_accent_shadows: bool = false
@export var balanced_four_splits: bool = true

@export_group("Cinematic")
@export var cinematic_directional_atlas_size: int = 8192
@export var cinematic_positional_atlas_size: int = 4096
@export_range(0, 5, 1) var cinematic_filter_quality: int = 4
@export_range(10.0, 200.0, 1.0) var cinematic_shadow_distance: float = 96.0
@export_range(0.0, 1.0, 0.01) var cinematic_fade_start: float = 0.92
@export_range(0.0, 0.3, 0.005) var cinematic_bias: float = 0.04
@export_range(0.0, 4.0, 0.05) var cinematic_normal_bias: float = 0.72
@export_range(0.0, 3.0, 0.05) var cinematic_blur: float = 1.08
@export_range(0.0, 2.0, 0.01) var cinematic_angular_distance: float = 0.50
@export_range(0.0, 1.0, 0.01) var cinematic_shadow_opacity: float = 1.0
@export_range(0.0, 40.0, 0.5) var cinematic_pancake_size: float = 7.0
@export var cinematic_accent_shadows: bool = true
@export var cinematic_four_splits: bool = true

@export_group("PSSM")
@export_range(0.01, 0.4, 0.01) var split_1: float = 0.08
@export_range(0.02, 0.7, 0.01) var split_2: float = 0.24
@export_range(0.05, 0.9, 0.01) var split_3: float = 0.52
@export var blend_splits_balanced: bool = true
@export var blend_splits_cinematic: bool = true

@export_group("Thin Geometry")
@export_range(0.0, 0.3, 0.005) var transmittance_bias: float = 0.045
@export var balanced_double_sided_close_foliage: bool = true
@export var cinematic_double_sided_canopy: bool = true


func get_tier(quality: int) -> Dictionary:
	match quality:
		0:
			return {
				"atlas": performance_directional_atlas_size,
				"positional_atlas": performance_positional_atlas_size,
				"filter": performance_filter_quality,
				"mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
				"distance": performance_shadow_distance,
				"fade_start": performance_fade_start,
				"bias": performance_bias,
				"normal_bias": performance_normal_bias,
				"blur": performance_blur,
				"angular_distance": performance_angular_distance,
				"opacity": performance_shadow_opacity,
				"pancake": performance_pancake_size,
				"blend_splits": false,
				"accent_shadows": performance_accent_shadows,
				"double_sided_close": false,
				"double_sided_canopy": false,
			}
		1:
			return {
				"atlas": balanced_directional_atlas_size,
				"positional_atlas": balanced_positional_atlas_size,
				"filter": balanced_filter_quality,
				"mode": (
					DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
					if balanced_four_splits
					else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				),
				"distance": balanced_shadow_distance,
				"fade_start": balanced_fade_start,
				"bias": balanced_bias,
				"normal_bias": balanced_normal_bias,
				"blur": balanced_blur,
				"angular_distance": balanced_angular_distance,
				"opacity": balanced_shadow_opacity,
				"pancake": balanced_pancake_size,
				"blend_splits": blend_splits_balanced if balanced_four_splits else false,
				"accent_shadows": balanced_accent_shadows,
				"double_sided_close": balanced_double_sided_close_foliage,
				"double_sided_canopy": false,
			}
		_:
			return {
				"atlas": cinematic_directional_atlas_size,
				"positional_atlas": cinematic_positional_atlas_size,
				"filter": cinematic_filter_quality,
				"mode": (
					DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
					if cinematic_four_splits
					else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				),
				"distance": cinematic_shadow_distance,
				"fade_start": cinematic_fade_start,
				"bias": cinematic_bias,
				"normal_bias": cinematic_normal_bias,
				"blur": cinematic_blur,
				"angular_distance": cinematic_angular_distance,
				"opacity": cinematic_shadow_opacity,
				"pancake": cinematic_pancake_size,
				"blend_splits": blend_splits_cinematic if cinematic_four_splits else false,
				"accent_shadows": cinematic_accent_shadows,
				"double_sided_close": true,
				"double_sided_canopy": cinematic_double_sided_canopy,
			}
