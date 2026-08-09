extends Node3D
class_name EnvironmentalMotionZone3D

@export var channel: String = "world"
@export_range(-100, 100, 1) var priority: int = 0
@export var zone_extents: Vector3 = Vector3(5.0, 4.0, 5.0)
@export_range(0.0, 20.0, 0.1) var blend_distance: float = 2.5

@export_group("Ambient Motion")
@export_range(0.0, 3.0, 0.01) var wind_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.01) var gust_multiplier: float = 1.0
@export var direction_override: Vector3 = Vector3.ZERO
@export_range(0.0, 1.0, 0.01) var direction_influence: float = 0.0


func _ready() -> void:
	add_to_group("environmental_motion_zone_3d")
	set_meta("environmental_motion_channel", channel)


func get_blend_weight(world_position: Vector3) -> float:
	var local: Vector3 = to_local(world_position)
	var extents := Vector3(
		maxf(absf(zone_extents.x), 0.01),
		maxf(absf(zone_extents.y), 0.01),
		maxf(absf(zone_extents.z), 0.01)
	)
	if absf(local.x) > extents.x or absf(local.y) > extents.y or absf(local.z) > extents.z:
		return 0.0
	if blend_distance <= 0.001:
		return 1.0
	var x_weight: float = _axis_weight(absf(local.x), extents.x)
	var y_weight: float = _axis_weight(absf(local.y), extents.y)
	var z_weight: float = _axis_weight(absf(local.z), extents.z)
	return clampf(minf(x_weight, minf(y_weight, z_weight)), 0.0, 1.0)


func _axis_weight(distance_from_center: float, extent: float) -> float:
	var inner_extent: float = maxf(extent - blend_distance, 0.0)
	if distance_from_center <= inner_extent:
		return 1.0
	var width: float = maxf(extent - inner_extent, 0.001)
	return 1.0 - clampf((distance_from_center - inner_extent) / width, 0.0, 1.0)


func get_debug_data() -> Dictionary:
	return {
		"environmental_motion_zone": true,
		"channel": channel,
		"priority": priority,
		"wind_multiplier": wind_multiplier,
		"gust_multiplier": gust_multiplier,
		"direction_influence": direction_influence,
	}
