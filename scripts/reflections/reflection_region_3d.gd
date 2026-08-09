extends Node3D
class_name ReflectionRegion3D

@export var region_id: String = "reflection_region"
@export_range(0, 2, 1) var minimum_quality: int = 1
@export var size: Vector3 = Vector3(12.0, 8.0, 12.0)
@export_range(0.0, 8.0, 0.05) var blend_distance: float = 1.5
@export var origin_offset: Vector3 = Vector3.ZERO
@export_range(0.0, 2.0, 0.01) var intensity: float = 1.0
@export_range(1.0, 200.0, 1.0) var max_distance: float = 42.0
@export var box_projection: bool = false
@export var interior: bool = false

var probe: ReflectionProbe = null


func _ready() -> void:
	add_to_group("reflection_region_3d")
	set_meta("reflection_region_id", region_id)
	_install_probe()


func _install_probe() -> void:
	if probe != null:
		return
	probe = ReflectionProbe.new()
	probe.name = "ReflectionProbe"
	probe.size = Vector3(
		maxf(absf(size.x), 0.2),
		maxf(absf(size.y), 0.2),
		maxf(absf(size.z), 0.2)
	)
	var half_size: Vector3 = probe.size * 0.5
	probe.origin_offset = Vector3(
		clampf(origin_offset.x, -half_size.x, half_size.x),
		clampf(origin_offset.y, -half_size.y, half_size.y),
		clampf(origin_offset.z, -half_size.z, half_size.z)
	)
	probe.blend_distance = clampf(
		blend_distance,
		0.0,
		minf(half_size.x, minf(half_size.y, half_size.z))
	)
	probe.intensity = maxf(intensity, 0.0)
	probe.max_distance = maxf(max_distance, 1.0)
	probe.box_projection = box_projection
	probe.interior = interior
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.enable_shadows = false
	add_child(probe)


func get_debug_data() -> Dictionary:
	return {
		"reflection_region": true,
		"region_id": region_id,
		"minimum_quality": minimum_quality,
		"size": size,
		"blend_distance": blend_distance,
		"origin_offset": origin_offset,
		"box_projection": box_projection,
		"interior": interior,
		"probe": probe != null,
	}
