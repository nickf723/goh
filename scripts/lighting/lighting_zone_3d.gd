extends Node3D
class_name LightingZone3D

@export var profile: LightingProfile
@export var channel: String = "world"
@export_range(-100, 100, 1) var priority: int = 0
@export var zone_extents: Vector3 = Vector3(5.0, 4.0, 5.0)
@export_range(0.0, 20.0, 0.1) var blend_distance: float = 2.5

@export_group("Local Fog")
@export_range(-0.1, 0.1, 0.001) var local_fog_density: float = 0.0
@export var local_fog_color: Color = Color(0.7, 0.75, 0.7, 1.0)
@export var local_fog_emission: Color = Color(0.0, 0.0, 0.0, 1.0)
@export_range(0.0, 1.0, 0.01) var local_fog_edge_fade: float = 0.35
@export_range(0.0, 2.0, 0.01) var local_fog_height_falloff: float = 0.0

@export_group("Local Accent")
@export var accent_light_enabled: bool = false
@export var accent_light_offset: Vector3 = Vector3.ZERO
@export var accent_light_color: Color = Color(1.0, 0.55, 0.25, 1.0)
@export_range(0.0, 12.0, 0.01) var accent_light_energy: float = 1.0
@export_range(0.5, 40.0, 0.1) var accent_light_range: float = 8.0
@export_range(0.0, 8.0, 0.01) var accent_light_volumetric_energy: float = 0.5
@export var accent_light_shadows: bool = false

var fog_volume: FogVolume = null
var accent_light: OmniLight3D = null


func _ready() -> void:
	add_to_group("lighting_zone_3d")
	set_meta("lighting_zone_channel", channel)
	_install_local_fog()
	_install_accent_light()


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


func contains_world_position(world_position: Vector3) -> bool:
	return get_blend_weight(world_position) > 0.0


func _axis_weight(distance_from_center: float, extent: float) -> float:
	var inner_extent: float = maxf(extent - blend_distance, 0.0)
	if distance_from_center <= inner_extent:
		return 1.0
	var blend_width: float = maxf(extent - inner_extent, 0.001)
	return 1.0 - clampf((distance_from_center - inner_extent) / blend_width, 0.0, 1.0)


func _install_local_fog() -> void:
	if absf(local_fog_density) < 0.001:
		return
	fog_volume = FogVolume.new()
	fog_volume.name = "LocalFog"
	fog_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog_volume.size = Vector3(
		maxf(absf(zone_extents.x) * 2.0, 0.1),
		maxf(absf(zone_extents.y) * 2.0, 0.1),
		maxf(absf(zone_extents.z) * 2.0, 0.1)
	)
	var fog_material := FogMaterial.new()
	fog_material.density = local_fog_density
	fog_material.albedo = local_fog_color
	fog_material.emission = local_fog_emission
	fog_material.edge_fade = local_fog_edge_fade
	fog_material.height_falloff = local_fog_height_falloff
	fog_volume.material = fog_material
	add_child(fog_volume)


func _install_accent_light() -> void:
	if not accent_light_enabled:
		return
	accent_light = OmniLight3D.new()
	accent_light.name = "ZoneAccent"
	accent_light.position = accent_light_offset
	accent_light.light_color = accent_light_color
	accent_light.light_energy = accent_light_energy
	accent_light.omni_range = accent_light_range
	accent_light.light_volumetric_fog_energy = accent_light_volumetric_energy
	accent_light.shadow_enabled = accent_light_shadows
	add_child(accent_light)


func get_debug_data() -> Dictionary:
	return {
		"lighting_zone": true,
		"profile_id": profile.profile_id if profile != null else "",
		"channel": channel,
		"priority": priority,
		"zone_extents": zone_extents,
		"blend_distance": blend_distance,
		"local_fog": fog_volume != null,
		"accent_light": accent_light != null,
	}
