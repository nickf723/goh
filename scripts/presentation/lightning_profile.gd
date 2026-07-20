extends Resource
class_name LightningProfile

@export var core_color: Color = Color(0.92, 0.98, 1.0, 1.0)
@export var glow_color: Color = Color(0.34, 0.5, 1.0, 0.68)
@export var impact_color: Color = Color(0.72, 0.86, 1.0, 1.0)
@export var thickness: float = 0.045
@export var glow_width_multiplier: float = 3.2
@export var duration_seconds: float = 0.18
@export var subdivision_count: int = 5
@export var jitter_amplitude: float = 0.52
@export var branch_chance: float = 0.28
@export var branch_depth: int = 1
@export var branch_length_ratio: float = 0.38
@export var maximum_branches: int = 12
@export var flicker_frequency: float = 34.0
@export var light_energy: float = 5.5
@export var light_range: float = 7.0
@export var impact_flash_scale: float = 0.24


func apply_to_event(event: LightningArcEvent, intensity: float = 1.0) -> LightningArcEvent:
	if event == null:
		return null
	var scale: float = clampf(intensity, 0.05, 8.0)
	event.intensity = scale
	event.thickness = thickness * lerpf(0.72, 1.55, clampf((scale - 0.5) / 2.5, 0.0, 1.0))
	event.duration_seconds = duration_seconds * lerpf(0.88, 1.28, clampf((scale - 0.5) / 2.5, 0.0, 1.0))
	event.subdivision_count = subdivision_count
	event.jitter_amplitude = jitter_amplitude * scale
	event.branch_chance = clampf(branch_chance * lerpf(0.72, 1.45, clampf(scale / 2.8, 0.0, 1.0)), 0.0, 1.0)
	event.branch_depth = branch_depth
	event.branch_length_ratio = branch_length_ratio
	event.maximum_branches = maximum_branches
	event.sanitize()
	return event


func duplicate_profile() -> LightningProfile:
	var copy := LightningProfile.new()
	copy.core_color = core_color
	copy.glow_color = glow_color
	copy.impact_color = impact_color
	copy.thickness = thickness
	copy.glow_width_multiplier = glow_width_multiplier
	copy.duration_seconds = duration_seconds
	copy.subdivision_count = subdivision_count
	copy.jitter_amplitude = jitter_amplitude
	copy.branch_chance = branch_chance
	copy.branch_depth = branch_depth
	copy.branch_length_ratio = branch_length_ratio
	copy.maximum_branches = maximum_branches
	copy.flicker_frequency = flicker_frequency
	copy.light_energy = light_energy
	copy.light_range = light_range
	copy.impact_flash_scale = impact_flash_scale
	return copy


func get_debug_data() -> Dictionary:
	return {
		"thickness": snapped(thickness, 0.001),
		"glow_width_multiplier": snapped(glow_width_multiplier, 0.01),
		"duration": snapped(duration_seconds, 0.01),
		"subdivisions": subdivision_count,
		"jitter": snapped(jitter_amplitude, 0.01),
		"branch_chance": snapped(branch_chance, 0.01),
		"branch_depth": branch_depth,
		"branch_length_ratio": snapped(branch_length_ratio, 0.01),
		"maximum_branches": maximum_branches,
		"flicker_frequency": snapped(flicker_frequency, 0.1),
		"light_energy": snapped(light_energy, 0.1),
		"light_range": snapped(light_range, 0.1),
	}
