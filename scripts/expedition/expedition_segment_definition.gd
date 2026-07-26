extends Resource
class_name ExpeditionSegmentDefinition

@export var segment_id: String = "segment"
@export var display_name: String = "Wilds Segment"
@export var biome_id: String = "temperate"
@export_enum("passage", "traversal", "combat", "resource", "discovery", "rest", "transition") var role: String = "passage"

@export_group("Footprint")
@export_range(10.0, 60.0, 0.5) var length: float = 24.0
@export_range(8.0, 36.0, 0.5) var width: float = 18.0
@export_range(3.0, 12.0, 0.25) var path_width: float = 5.5
@export_range(-8.0, 8.0, 0.25) var elevation_delta: float = 0.0

@export_group("Geography")
@export_enum("forest", "cliff", "marsh", "mixed") var boundary_style: String = "forest"
@export_range(0.0, 1.0, 0.05) var water_fraction: float = 0.0
@export_range(0.0, 1.0, 0.05) var obstacle_density: float = 0.25
@export var ground_color: Color = Color(0.18, 0.24, 0.16, 1.0)
@export var path_color: Color = Color(0.34, 0.31, 0.22, 1.0)
@export var boundary_color: Color = Color(0.08, 0.18, 0.08, 1.0)
@export var accent_color: Color = Color(0.55, 0.8, 0.38, 1.0)

@export_group("Sockets and Content")
@export var allows_optional_branch: bool = false
@export_enum("left", "right") var branch_side: String = "right"
@export_range(0.25, 0.8, 0.05) var branch_distance_normalized: float = 0.55
@export var landmark_id: String = ""
@export var tags: Array[String] = []


func get_exit_local_position() -> Vector3:
	return Vector3(0.0, elevation_delta, length)


func get_branch_local_position() -> Vector3:
	var side_sign: float = -1.0 if branch_side == "left" else 1.0
	return Vector3(
		side_sign * width * 0.5,
		elevation_delta * branch_distance_normalized,
		length * branch_distance_normalized
	)


func get_debug_summary() -> String:
	return (
		segment_id
		+ " | "
		+ biome_id
		+ " | "
		+ role
		+ " | "
		+ str(snapped(length, 0.1))
		+ "m"
	)
