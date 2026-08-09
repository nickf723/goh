extends Resource
class_name MaterialFidelityProfile

@export var profile_id: String = "material_fidelity"
@export var display_name: String = "Material Fidelity"

@export_group("Projection")
@export_range(0.0, 24.0, 0.1) var triplanar_sharpness: float = 3.4
@export_range(0.1, 2.0, 0.05) var world_scale_multiplier: float = 0.68

@export_group("Procedural Detail")
@export_range(64, 512, 64) var texture_resolution: int = 256
@export_range(0.001, 0.5, 0.001) var normal_noise_frequency: float = 0.105
@export_range(0.001, 0.5, 0.001) var roughness_noise_frequency: float = 0.043
@export_range(0.0, 12.0, 0.1) var normal_bump_strength: float = 4.2
@export_range(0.0, 2.0, 0.01) var normal_scale: float = 0.52
@export_range(0.0, 0.5, 0.01) var roughness_variation: float = 0.16
@export var detail_seed: int = 24871

@export_group("Runtime")
@export_range(1, 64, 1) var maximum_shared_variants: int = 28
