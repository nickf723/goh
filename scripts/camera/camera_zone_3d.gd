extends Node3D
class_name CameraZone3D

@export var channel: String = "world"
@export_range(-100, 100, 1) var priority: int = 0
@export var zone_extents: Vector3 = Vector3(5.0, 4.0, 5.0)
@export_range(0.0, 20.0, 0.1) var blend_distance: float = 2.5

@export_group("Framing Offsets")
@export_range(-4.0, 4.0, 0.05) var distance_offset: float = 0.0
@export_range(-20.0, 20.0, 0.1) var fov_offset: float = 0.0
@export_range(-1.5, 1.5, 0.01) var pivot_height_offset: float = 0.0
@export_range(0.0, 2.0, 0.01) var lead_scale: float = 1.0


func _ready() -> void:
	add_to_group("camera_zone_3d")
	set_meta("camera_zone_channel", channel)


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
	var blend_width: float = maxf(extent - inner_extent, 0.001)
	return 1.0 - clampf((distance_from_center - inner_extent) / blend_width, 0.0, 1.0)


func get_debug_data() -> Dictionary:
	return {
		"camera_zone": true,
		"channel": channel,
		"priority": priority,
		"zone_extents": zone_extents,
		"blend_distance": blend_distance,
		"distance_offset": distance_offset,
		"fov_offset": fov_offset,
		"pivot_height_offset": pivot_height_offset,
		"lead_scale": lead_scale,
	}
