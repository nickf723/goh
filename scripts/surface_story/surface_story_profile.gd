extends Resource
class_name SurfaceStoryProfile

@export var profile_id: String = "surface_story"
@export var display_name: String = "Surface Story"
@export_range(64, 256, 32) var texture_resolution: int = 128
@export_range(0.0, 1.0, 0.01) var global_intensity: float = 0.86
@export_range(1.0, 200.0, 1.0) var distance_fade_begin: float = 34.0
@export_range(1.0, 100.0, 1.0) var distance_fade_length: float = 18.0
@export_range(0.0, 1.0, 0.01) var normal_fade: float = 0.72
@export_range(0.01, 1.0, 0.01) var floor_projection_depth: float = 0.18
@export_range(0.01, 1.0, 0.01) var wall_projection_depth: float = 0.28

@export_group("Green Grotto Mix")
@export_range(0.0, 2.0, 0.01) var crack_intensity: float = 0.82
@export_range(0.0, 2.0, 0.01) var moss_intensity: float = 0.78
@export_range(0.0, 2.0, 0.01) var wet_intensity: float = 0.82
@export_range(0.0, 2.0, 0.01) var grime_intensity: float = 0.66
@export_range(0.0, 2.0, 0.01) var wear_intensity: float = 0.52
@export_range(0.0, 2.0, 0.01) var carving_intensity: float = 0.58
