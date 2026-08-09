extends Resource
class_name VisualLODProfile

@export var profile_id: String = "visual_lod"
@export var display_name: String = "Visual LOD"

@export_group("Performance")
@export_range(5.0, 200.0, 1.0) var performance_foliage_distance: float = 24.0
@export_range(5.0, 200.0, 1.0) var performance_canopy_detail_distance: float = 58.0
@export_range(5.0, 200.0, 1.0) var performance_surface_detail_distance: float = 22.0
@export_range(5.0, 200.0, 1.0) var performance_architecture_detail_distance: float = 32.0
@export_range(0.0, 20.0, 0.5) var performance_margin: float = 2.5

@export_group("Balanced")
@export_range(5.0, 200.0, 1.0) var balanced_foliage_distance: float = 38.0
@export_range(5.0, 200.0, 1.0) var balanced_canopy_detail_distance: float = 78.0
@export_range(5.0, 200.0, 1.0) var balanced_surface_detail_distance: float = 36.0
@export_range(5.0, 200.0, 1.0) var balanced_architecture_detail_distance: float = 52.0
@export_range(0.0, 20.0, 0.5) var balanced_margin: float = 4.0

@export_group("Cinematic")
@export_range(5.0, 250.0, 1.0) var cinematic_foliage_distance: float = 58.0
@export_range(5.0, 250.0, 1.0) var cinematic_canopy_detail_distance: float = 115.0
@export_range(5.0, 250.0, 1.0) var cinematic_surface_detail_distance: float = 60.0
@export_range(5.0, 250.0, 1.0) var cinematic_architecture_detail_distance: float = 78.0
@export_range(0.0, 20.0, 0.5) var cinematic_margin: float = 5.0


func get_distance(category: String, quality: int) -> float:
	var normalized: String = category.strip_edges().to_lower()
	match clampi(quality, 0, 2):
		0:
			return _category_distance(
				normalized,
				performance_foliage_distance,
				performance_canopy_detail_distance,
				performance_surface_detail_distance,
				performance_architecture_detail_distance
			)
		1:
			return _category_distance(
				normalized,
				balanced_foliage_distance,
				balanced_canopy_detail_distance,
				balanced_surface_detail_distance,
				balanced_architecture_detail_distance
			)
		_:
			return _category_distance(
				normalized,
				cinematic_foliage_distance,
				cinematic_canopy_detail_distance,
				cinematic_surface_detail_distance,
				cinematic_architecture_detail_distance
			)


func get_margin(quality: int) -> float:
	match clampi(quality, 0, 2):
		0:
			return performance_margin
		1:
			return balanced_margin
		_:
			return cinematic_margin


func _category_distance(
	category: String,
	foliage: float,
	canopy_detail: float,
	surface_detail: float,
	architecture_detail: float
) -> float:
	match category:
		"foliage":
			return foliage
		"canopy_detail":
			return canopy_detail
		"surface_detail":
			return surface_detail
		"architecture_detail":
			return architecture_detail
		_:
			return 0.0


func get_debug_data() -> Dictionary:
	return {
		"visual_lod_profile": true,
		"profile_id": profile_id,
		"performance_foliage_distance": performance_foliage_distance,
		"balanced_foliage_distance": balanced_foliage_distance,
		"cinematic_foliage_distance": cinematic_foliage_distance,
		"uses_visibility_ranges": true,
	}
