extends ConductiveWaterVolume
class_name ThermalWaterVolume

@export var starting_water_temperature_c: float = 20.0
@export var water_heat_capacity_j_per_c: float = 8.0
@export var water_ambient_conductance: float = 0.02
@export var water_freezing_point_c: float = 0.0
@export var water_boiling_point_c: float = 100.0

var thermal_state: ThermalState
var frozen_material: StandardMaterial3D
var steam_material: StandardMaterial3D
var steam_mesh: MeshInstance3D


func _ready() -> void:
	ensure_thermal_state()
	super._ready()
	ensure_phase_visuals()
	if not thermal_state.phase_changed.is_connected(_on_thermal_phase_changed):
		thermal_state.phase_changed.connect(_on_thermal_phase_changed)
	if not thermal_state.temperature_changed.is_connected(_on_water_temperature_changed):
		thermal_state.temperature_changed.connect(_on_water_temperature_changed)
	apply_thermal_phase_to_conduction()
	update_visual_state()


func ensure_thermal_state() -> void:
	thermal_state = get_node_or_null("ThermalState") as ThermalState
	var created_state: bool = thermal_state == null
	if created_state:
		thermal_state = ThermalState.new()
		thermal_state.name = "ThermalState"
	thermal_state.material_profile = material_profile
	thermal_state.starting_temperature_c = starting_water_temperature_c
	thermal_state.ambient_temperature_c = 20.0
	thermal_state.heat_capacity_override_j_per_c = max(water_heat_capacity_j_per_c, 0.01)
	thermal_state.ambient_conductance_j_per_second_c = max(water_ambient_conductance, 0.0)
	thermal_state.phase_changes_enabled = true
	thermal_state.use_material_phase_points = false
	thermal_state.freezing_point_c = water_freezing_point_c
	thermal_state.boiling_point_c = max(water_boiling_point_c, water_freezing_point_c + 0.1)
	thermal_state.phase_hysteresis_c = 1.5
	thermal_state.fire_energy_j_per_intensity = 180.0
	thermal_state.ice_energy_j_per_intensity = 180.0
	if created_state:
		add_child(thermal_state)


func ensure_phase_visuals() -> void:
	frozen_material = make_water_material(Color(0.64, 0.88, 1.0, 0.82), 2.8)
	frozen_material.roughness = 0.42
	steam_material = make_water_material(Color(0.82, 0.9, 1.0, 0.34), 1.5)
	steam_material.roughness = 0.62

	steam_mesh = get_node_or_null("SteamMesh") as MeshInstance3D
	if steam_mesh == null:
		steam_mesh = MeshInstance3D.new()
		steam_mesh.name = "SteamMesh"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(volume_size.x * 0.95, volume_size.y * 2.2, volume_size.z * 0.95)
		steam_mesh.mesh = mesh
		steam_mesh.position = Vector3(0.0, volume_size.y * 0.8, 0.0)
		add_child(steam_mesh)
	steam_mesh.material_override = steam_material
	steam_mesh.visible = false


func scan_immersed_terminals() -> void:
	super.scan_immersed_terminals()
	apply_thermal_phase_to_conduction()


func apply_thermal_phase_to_conduction() -> void:
	if thermal_state == null:
		return
	var should_conduct: bool = (
		filled
		and thermal_state.is_liquid()
		and immersed_terminal_keys.size() == 2
	)
	if path_enabled != should_conduct:
		path_enabled = should_conduct
		if not path_enabled:
			apply_circuit_state(false, 0.0, 0.0, -1)
		notify_topology_changed()
	update_visual_state()


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	var thermal_result: Dictionary = thermal_state.receive_damage_payload(payload) if thermal_state != null else {}
	if not thermal_result.is_empty():
		apply_thermal_phase_to_conduction()
		return thermal_result
	if thermal_state != null and not thermal_state.is_liquid():
		return {
			"message": payload.source_name + " reaches " + thermal_state.phase + " water, but this phase does not carry circuit current in v1.",
			"objective": "Return the water to liquid before testing electrical conduction.",
		}
	return super.receive_damage_payload(payload)


func set_filled(next_filled: bool) -> void:
	var was_filled: bool = filled
	super.set_filled(next_filled)
	if next_filled and not was_filled and thermal_state != null:
		thermal_state.set_temperature(starting_water_temperature_c, "Refilled water")
	apply_thermal_phase_to_conduction()


func _on_thermal_phase_changed(_previous_phase: String, _next_phase: String) -> void:
	apply_thermal_phase_to_conduction()


func _on_water_temperature_changed(_temperature_c: float, _delta_c: float, _source_name: String) -> void:
	update_visual_state()


func update_visual_state() -> void:
	super.update_visual_state()
	if thermal_state == null:
		return
	if steam_mesh != null:
		steam_mesh.visible = filled and thermal_state.is_gas()
	if water_mesh != null and filled:
		if thermal_state.is_solid() and frozen_material != null:
			water_mesh.visible = true
			water_mesh.material_override = frozen_material
		elif thermal_state.is_gas():
			water_mesh.visible = false
	if water_area != null:
		water_area.monitorable = filled and not thermal_state.is_gas()
	if state_label != null and filled:
		state_label.text = (
			"WATER BASIN\n"
			+ thermal_state.phase.to_upper()
			+ "  "
			+ str(snapped(thermal_state.temperature_c, 0.1))
			+ " °C"
		)


func get_hazard_tags() -> Array[String]:
	if thermal_state != null and thermal_state.is_solid():
		return ["water", "ice", "frozen", "cold", "insulating"]
	if thermal_state != null and thermal_state.is_gas():
		return ["water", "steam", "water_vapor", "hot", "nonconductive"]
	return super.get_hazard_tags()


func reset_target() -> void:
	if thermal_state != null:
		thermal_state.reset_target()
	super.reset_target()
	apply_thermal_phase_to_conduction()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["thermal_water"] = true
	data["thermal"] = thermal_state.get_debug_data() if thermal_state != null else {}
	data["phase_conductive"] = thermal_state != null and thermal_state.is_liquid()
	return data
