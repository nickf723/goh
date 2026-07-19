extends Node
class_name BuoyancyReceiver

@export var body_height_m: float = 1.0
@export var volume_override_m3: float = 0.0
@export var center_offset: Vector3 = Vector3.ZERO
@export var horizontal_margin_m: float = 0.05
@export var fluid_drag_scale: float = 1.0
@export var vertical_drag_scale: float = 1.0
@export var stability_scale: float = 1.0
@export var maximum_horizontal_force: float = 120.0
@export var maximum_stability_torque: float = 18.0
@export var wake_interval_seconds: float = 0.32
@export var create_entry_ripples: bool = true
@export var create_wake_ripples: bool = true
@export var entry_splash_scale: float = 1.0
@export var wake_strength_scale: float = 1.0
@export var load_sensor_path: NodePath

var active_volume: FluidForceVolume
var submerged_fraction: float = 0.0
var effective_volume_m3: float = 0.0
var base_mass_kg: float = 0.0
var external_load_kg: float = 0.0
var total_mass_kg: float = 0.0
var effective_density_kg_m3: float = 0.0
var buoyancy_acceleration: float = 0.0
var net_vertical_acceleration: float = 0.0
var horizontal_fluid_force: Vector3 = Vector3.ZERO
var stability_torque: Vector3 = Vector3.ZERO
var fluid_state: String = "air"
var wake_timer: float = 0.0
var previous_volume: FluidForceVolume
var load_sensor: BuoyancyLoadSensor
var last_surface_distance: float = 0.0
var emitted_entry_count: int = 0
var emitted_wake_count: int = 0


func _ready() -> void:
	add_to_group("debuggable")
	if not load_sensor_path.is_empty():
		load_sensor = get_node_or_null(load_sensor_path) as BuoyancyLoadSensor
	if load_sensor == null:
		load_sensor = get_node_or_null("BuoyancyLoadSensor") as BuoyancyLoadSensor


func update_fluid_response(
	body: FieldResponsiveBody,
	force_receiver: ForceReceiver,
	delta: float
) -> float:
	base_mass_kg = body.get_effective_mass() if body != null else 1.0
	external_load_kg = load_sensor.measure_external_load(body) if load_sensor != null else 0.0
	total_mass_kg = max(base_mass_kg + external_load_kg, 0.01)
	effective_volume_m3 = calculate_effective_volume(body)
	effective_density_kg_m3 = total_mass_kg / max(effective_volume_m3, 0.0001)
	wake_timer = max(wake_timer - max(delta, 0.0), 0.0)

	var body_center: Vector3 = body.global_position + body.global_transform.basis * center_offset
	active_volume = choose_active_volume(body_center)
	if active_volume == null:
		clear_fluid_influences(force_receiver)
		previous_volume = null
		submerged_fraction = 0.0
		buoyancy_acceleration = 0.0
		net_vertical_acceleration = -body.gravity_strength
		fluid_state = "air"
		last_surface_distance = 0.0
		return net_vertical_acceleration

	submerged_fraction = active_volume.get_submerged_fraction(
		body_center,
		body_height_m,
		horizontal_margin_m
	)
	if submerged_fraction <= 0.0:
		clear_fluid_influences(force_receiver)
		previous_volume = null
		active_volume = null
		buoyancy_acceleration = 0.0
		net_vertical_acceleration = -body.gravity_strength
		fluid_state = "air"
		return net_vertical_acceleration

	var displaced_mass_kg: float = (
		active_volume.fluid_density_kg_m3
		* effective_volume_m3
		* submerged_fraction
		* max(active_volume.buoyancy_multiplier, 0.0)
	)
	buoyancy_acceleration = body.gravity_strength * displaced_mass_kg / total_mass_kg
	var vertical_drag_acceleration: float = (
		-body.gravity_velocity
		* max(active_volume.vertical_drag_coefficient, 0.0)
		* max(vertical_drag_scale, 0.0)
		* submerged_fraction
	)
	net_vertical_acceleration = -body.gravity_strength + buoyancy_acceleration + vertical_drag_acceleration

	apply_horizontal_fluid_force(body, force_receiver, body_center)
	apply_stability_torque(body, force_receiver)
	update_fluid_state(body)
	update_water_feedback(body, body_center)
	last_surface_distance = active_volume.get_surface_y() - body_center.y
	previous_volume = active_volume
	return net_vertical_acceleration


func calculate_effective_volume(body: FieldResponsiveBody) -> float:
	if volume_override_m3 > 0.0:
		return volume_override_m3
	var material_density: float = 1000.0
	if body != null and body.material_profile != null:
		material_density = max(body.material_profile.density_kg_m3, 0.01)
	return max(base_mass_kg / material_density, 0.0001)


func choose_active_volume(body_center: Vector3) -> FluidForceVolume:
	if get_tree() == null:
		return null
	var selected: FluidForceVolume
	var selected_fraction: float = 0.0
	var selected_priority: int = -2147483648
	for node: Node in get_tree().get_nodes_in_group("fluid_force_volumes"):
		var volume := node as FluidForceVolume
		if volume == null or not is_instance_valid(volume):
			continue
		var fraction: float = volume.get_submerged_fraction(
			body_center,
			body_height_m,
			horizontal_margin_m
		)
		if fraction <= 0.0:
			continue
		if volume.priority > selected_priority or (
			volume.priority == selected_priority and fraction > selected_fraction
		):
			selected = volume
			selected_fraction = fraction
			selected_priority = volume.priority
	return selected


func apply_horizontal_fluid_force(
	body: FieldResponsiveBody,
	force_receiver: ForceReceiver,
	body_center: Vector3
) -> void:
	if force_receiver == null or active_volume == null:
		return
	var body_horizontal_velocity := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var flow_velocity: Vector3 = active_volume.get_flow_velocity_at(body_center)
	flow_velocity.y = 0.0
	var relative_velocity: Vector3 = flow_velocity - body_horizontal_velocity
	horizontal_fluid_force = (
		relative_velocity
		* max(active_volume.horizontal_drag_coefficient, 0.0)
		* max(fluid_drag_scale, 0.0)
		* total_mass_kg
		* submerged_fraction
	)
	if horizontal_fluid_force.length() > maximum_horizontal_force:
		horizontal_fluid_force = horizontal_fluid_force.normalized() * maximum_horizontal_force
	force_receiver.set_continuous_force(get_force_source_id(), horizontal_fluid_force)


func apply_stability_torque(body: FieldResponsiveBody, force_receiver: ForceReceiver) -> void:
	if force_receiver == null or active_volume == null:
		return
	var current_up: Vector3 = body.global_transform.basis.y.normalized()
	var correction_axis: Vector3 = current_up.cross(Vector3.UP)
	stability_torque = (
		correction_axis
		* max(active_volume.angular_stability, 0.0)
		* max(stability_scale, 0.0)
		* submerged_fraction
		* total_mass_kg
	)
	if stability_torque.length() > maximum_stability_torque:
		stability_torque = stability_torque.normalized() * maximum_stability_torque
	force_receiver.set_continuous_torque(get_torque_source_id(), stability_torque)


func update_fluid_state(body: FieldResponsiveBody) -> void:
	if body.is_on_floor() and submerged_fraction < 0.2:
		fluid_state = "grounded"
	elif submerged_fraction >= 0.98 and buoyancy_acceleration < body.gravity_strength * 0.92:
		fluid_state = "sinking"
	elif net_vertical_acceleration > body.gravity_strength * 0.08:
		fluid_state = "rising"
	elif absf(net_vertical_acceleration) <= body.gravity_strength * 0.12:
		fluid_state = "floating"
	else:
		fluid_state = "submerged"


func update_water_feedback(body: FieldResponsiveBody, body_center: Vector3) -> void:
	if active_volume == null:
		return
	var flow_velocity: Vector3 = active_volume.get_flow_velocity_at(body_center)
	var relative_velocity: Vector3 = body.velocity - flow_velocity
	var horizontal_relative := Vector3(relative_velocity.x, 0.0, relative_velocity.z)
	var relative_speed: float = horizontal_relative.length()
	var characteristic_radius: float = clampf(
		pow(max(effective_volume_m3, 0.0001), 1.0 / 3.0) * 0.72,
		0.22,
		2.4
	)
	var surface_position := Vector3(body_center.x, active_volume.get_surface_y(), body_center.z)
	var tags: Array[String] = ["water", "physics_driven", fluid_state]
	var metadata: Dictionary = {
		"mass_kg": total_mass_kg,
		"submerged_fraction": submerged_fraction,
		"effective_volume_m3": effective_volume_m3,
		"body_name": body.name,
	}

	if create_entry_ripples and previous_volume != active_volume:
		var impact_speed: float = max(absf(body.velocity.y), body.velocity.length() * 0.42)
		var entry_strength: float = clampf(
			(impact_speed * 0.42 + sqrt(max(total_mass_kg, 0.01)) * 0.18)
			* max(entry_splash_scale, 0.0),
			0.45,
			5.0
		)
		active_volume.emit_disturbance(
			FluidDisturbanceEvent.KIND_ENTRY,
			surface_position,
			horizontal_relative,
			body.velocity,
			entry_strength,
			characteristic_radius,
			"buoyancy_entry:" + str(get_instance_id()),
			tags,
			metadata
		)
		emitted_entry_count += 1
		wake_timer = max(wake_interval_seconds, 0.08)
	elif (
		create_wake_ripples
		and wake_timer <= 0.0
		and relative_speed >= active_volume.ripple_min_speed
		and submerged_fraction > 0.08
	):
		var wake_strength: float = clampf(
			relative_speed * submerged_fraction * 0.48 * max(wake_strength_scale, 0.0),
			0.3,
			3.6
		)
		active_volume.emit_disturbance(
			FluidDisturbanceEvent.KIND_WAKE,
			surface_position,
			horizontal_relative,
			relative_velocity,
			wake_strength,
			characteristic_radius,
			"buoyancy_wake:" + str(get_instance_id()),
			tags,
			metadata
		)
		emitted_wake_count += 1
		wake_timer = max(wake_interval_seconds, 0.08)


func clear_fluid_influences(force_receiver: ForceReceiver) -> void:
	horizontal_fluid_force = Vector3.ZERO
	stability_torque = Vector3.ZERO
	if force_receiver != null:
		force_receiver.clear_continuous_force(get_force_source_id())
		force_receiver.clear_continuous_torque(get_torque_source_id())


func get_force_source_id() -> String:
	return "fluid_drag:" + str(get_instance_id())


func get_torque_source_id() -> String:
	return "fluid_stability:" + str(get_instance_id())


func reset_target() -> void:
	active_volume = null
	previous_volume = null
	submerged_fraction = 0.0
	external_load_kg = 0.0
	buoyancy_acceleration = 0.0
	net_vertical_acceleration = 0.0
	horizontal_fluid_force = Vector3.ZERO
	stability_torque = Vector3.ZERO
	fluid_state = "air"
	wake_timer = 0.0
	emitted_entry_count = 0
	emitted_wake_count = 0


func get_debug_data() -> Dictionary:
	return {
		"buoyancy_receiver": true,
		"state": fluid_state,
		"active_volume": active_volume.name if active_volume != null else "none",
		"submerged_fraction": snapped(submerged_fraction, 0.01),
		"base_mass_kg": snapped(base_mass_kg, 0.01),
		"external_load_kg": snapped(external_load_kg, 0.01),
		"total_mass_kg": snapped(total_mass_kg, 0.01),
		"effective_volume_m3": snapped(effective_volume_m3, 0.0001),
		"effective_density_kg_m3": snapped(effective_density_kg_m3, 0.1),
		"buoyancy_acceleration": snapped(buoyancy_acceleration, 0.01),
		"net_vertical_acceleration": snapped(net_vertical_acceleration, 0.01),
		"horizontal_force": horizontal_fluid_force,
		"stability_torque": stability_torque,
		"surface_distance": snapped(last_surface_distance, 0.01),
		"entry_events": emitted_entry_count,
		"wake_events": emitted_wake_count,
	}
