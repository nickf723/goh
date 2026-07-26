extends RefCounted
class_name LightningArcEvent

const KIND_DIRECT: String = "direct"
const KIND_STORM: String = "storm"
const KIND_CHAIN: String = "chain"
const KIND_CIRCUIT: String = "circuit"
const KIND_WATER_SURFACE: String = "water_surface"

var kind: String = KIND_DIRECT
var start_position: Vector3 = Vector3.ZERO
var end_position: Vector3 = Vector3.UP
var intensity: float = 1.0
var duration_seconds: float = 0.18
var thickness: float = 0.045
var subdivision_count: int = 5
var jitter_amplitude: float = 0.5
var branch_chance: float = 0.28
var branch_depth: int = 1
var branch_length_ratio: float = 0.38
var maximum_branches: int = 12
var event_seed: int = 1
var flatten_to_surface: bool = false
var surface_y: float = 0.0
var source_id: String = "unknown"
var tags: Array[String] = []
var metadata: Dictionary = {}


static func make(
	next_kind: String,
	next_start: Vector3,
	next_end: Vector3,
	next_intensity: float = 1.0,
	next_seed: int = 1,
	next_source_id: String = "unknown",
	next_tags: Array[String] = []
) -> LightningArcEvent:
	var event := LightningArcEvent.new()
	event.kind = next_kind if next_kind != "" else KIND_DIRECT
	event.start_position = next_start
	event.end_position = next_end
	event.intensity = clampf(next_intensity, 0.05, 8.0)
	event.event_seed = next_seed if next_seed != 0 else 1
	event.source_id = next_source_id if next_source_id != "" else "unknown"
	event.tags = next_tags.duplicate()
	return event


func get_distance() -> float:
	return start_position.distance_to(end_position)


func get_direction() -> Vector3:
	var delta := end_position - start_position
	if delta.length() <= 0.0001:
		return Vector3.UP
	return delta.normalized()


func is_finite_event() -> bool:
	return (
		is_finite(start_position.x)
		and is_finite(start_position.y)
		and is_finite(start_position.z)
		and is_finite(end_position.x)
		and is_finite(end_position.y)
		and is_finite(end_position.z)
		and is_finite(intensity)
		and is_finite(duration_seconds)
		and is_finite(thickness)
		and is_finite(jitter_amplitude)
		and is_finite(branch_chance)
		and is_finite(branch_length_ratio)
		and is_finite(surface_y)
	)


func sanitize() -> void:
	intensity = clampf(intensity, 0.05, 8.0)
	duration_seconds = clampf(duration_seconds, 0.04, 2.5)
	thickness = clampf(thickness, 0.004, 0.45)
	subdivision_count = clampi(subdivision_count, 1, 8)
	jitter_amplitude = clampf(jitter_amplitude, 0.0, 12.0)
	branch_chance = clampf(branch_chance, 0.0, 1.0)
	branch_depth = clampi(branch_depth, 0, 3)
	branch_length_ratio = clampf(branch_length_ratio, 0.05, 1.2)
	maximum_branches = clampi(maximum_branches, 0, 48)
	if start_position.distance_squared_to(end_position) <= 0.000001:
		end_position = start_position + Vector3.UP * 0.05


func duplicate_event() -> LightningArcEvent:
	var copy := LightningArcEvent.new()
	copy.kind = kind
	copy.start_position = start_position
	copy.end_position = end_position
	copy.intensity = intensity
	copy.duration_seconds = duration_seconds
	copy.thickness = thickness
	copy.subdivision_count = subdivision_count
	copy.jitter_amplitude = jitter_amplitude
	copy.branch_chance = branch_chance
	copy.branch_depth = branch_depth
	copy.branch_length_ratio = branch_length_ratio
	copy.maximum_branches = maximum_branches
	copy.event_seed = event_seed
	copy.flatten_to_surface = flatten_to_surface
	copy.surface_y = surface_y
	copy.source_id = source_id
	copy.tags = tags.duplicate()
	copy.metadata = metadata.duplicate(true)
	return copy


func get_debug_data() -> Dictionary:
	return {
		"kind": kind,
		"start": start_position,
		"end": end_position,
		"distance": snapped(get_distance(), 0.01),
		"intensity": snapped(intensity, 0.01),
		"duration": snapped(duration_seconds, 0.01),
		"thickness": snapped(thickness, 0.001),
		"subdivisions": subdivision_count,
		"jitter": snapped(jitter_amplitude, 0.01),
		"branch_chance": snapped(branch_chance, 0.01),
		"branch_depth": branch_depth,
		"maximum_branches": maximum_branches,
		"seed": event_seed,
		"flattened": flatten_to_surface,
		"source_id": source_id,
		"tags": tags.duplicate(),
		"metadata": metadata.duplicate(true),
	}
