extends Node3D
class_name StormLightningAttractor

@export var display_name: String = "Copper lightning rod"
@export_range(1.5, 9.0, 0.1) var rod_height: float = 4.8
@export var starts_wet: bool = false

var wet_timer: float = 0.0
var strike_count: int = 0
var flash_timer: float = 0.0
var metal_material: StandardMaterial3D = null
var cap_light: OmniLight3D = null


func _ready() -> void:
	add_to_group("lightning_attractor")
	add_to_group("lightning_chain_target")
	add_to_group("conductive")
	add_to_group("metal")
	add_to_group("weather_exposed")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	if starts_wet:
		wet_timer = 9999.0
	_build_visuals()


func _process(delta: float) -> void:
	if not starts_wet:
		wet_timer = max(wet_timer - max(delta, 0.0), 0.0)
	flash_timer = max(flash_timer - max(delta, 0.0), 0.0)
	if metal_material != null:
		metal_material.emission_energy_multiplier = lerpf(
			0.18,
			7.0,
			clampf(flash_timer / 0.42, 0.0, 1.0)
		)
	if cap_light != null:
		cap_light.light_energy = 7.5 * clampf(flash_timer / 0.42, 0.0, 1.0)


func _build_visuals() -> void:
	metal_material = StandardMaterial3D.new()
	metal_material.albedo_color = Color(0.42, 0.23, 0.12, 1.0)
	metal_material.metallic = 0.94
	metal_material.roughness = 0.24
	metal_material.emission_enabled = true
	metal_material.emission = Color(0.36, 0.62, 1.0, 1.0)
	metal_material.emission_energy_multiplier = 0.18

	var rod := MeshInstance3D.new()
	rod.name = "CopperRod"
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.055
	rod_mesh.bottom_radius = 0.13
	rod_mesh.height = rod_height
	rod_mesh.radial_segments = 12
	rod.mesh = rod_mesh
	rod.material_override = metal_material
	rod.position.y = rod_height * 0.5
	add_child(rod)

	var crown := MeshInstance3D.new()
	crown.name = "StormCrown"
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.22
	crown_mesh.height = 0.44
	crown_mesh.radial_segments = 12
	crown_mesh.rings = 8
	crown.mesh = crown_mesh
	crown.material_override = metal_material
	crown.position.y = rod_height
	add_child(crown)

	for index: int in range(3):
		var foot := MeshInstance3D.new()
		foot.name = "GroundingFoot" + str(index)
		var foot_mesh := BoxMesh.new()
		foot_mesh.size = Vector3(0.08, 0.08, 1.1)
		foot.mesh = foot_mesh
		foot.material_override = metal_material
		var angle: float = TAU * float(index) / 3.0
		foot.position = Vector3(cos(angle) * 0.42, 0.08, sin(angle) * 0.42)
		foot.rotation_degrees.y = -rad_to_deg(angle)
		add_child(foot)

	cap_light = OmniLight3D.new()
	cap_light.name = "StoredCharge"
	cap_light.position.y = rod_height
	cap_light.light_color = Color(0.44, 0.68, 1.0, 1.0)
	cap_light.light_energy = 0.0
	cap_light.omni_range = 7.0
	cap_light.shadow_enabled = false
	add_child(cap_light)


func receive_weather_payload(payload: DamagePayload) -> void:
	if payload == null:
		return
	if payload.element.to_lower().strip_edges() == "water" or payload.status_effect == "wet":
		wet_timer = max(wet_timer, max(payload.status_duration, 2.0))


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null or payload.element.to_lower().strip_edges() != "lightning":
		return {"message": display_name + " remains grounded.", "objective": ""}
	strike_count += 1
	flash_timer = 0.42
	return {
		"message": display_name + " catches the strike and bleeds its charge into nearby conductors.",
		"objective": "Watch the storm prefer wet, metallic, and elevated targets.",
	}


func get_lightning_target_position() -> Vector3:
	return global_position + Vector3.UP * rod_height


func is_wet_by_weather() -> bool:
	return starts_wet or wet_timer > 0.0


func reset_target() -> void:
	strike_count = 0
	flash_timer = 0.0
	wet_timer = 9999.0 if starts_wet else 0.0


func get_debug_data() -> Dictionary:
	return {
		"storm_attractor": true,
		"display_name": display_name,
		"wet": is_wet_by_weather(),
		"strikes": strike_count,
		"height": rod_height,
	}
