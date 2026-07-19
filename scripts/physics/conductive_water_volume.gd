extends CircuitComponent
class_name ConductiveWaterVolume

signal fill_state_changed(is_filled: bool)
signal electrode_contacts_changed(contact_keys: Array[String])
signal water_electrified(source_name: String, duration_seconds: float)

@export var volume_size: Vector3 = Vector3(3.4, 0.9, 1.8)
@export var starts_filled: bool = true
@export_range(0.01, 1.0, 0.01) var conductivity_scale: float = 0.28
@export var resistance_per_meter_ohms: float = 1.0
@export var minimum_resistance_ohms: float = 0.35
@export var scan_interval: float = 0.08
@export var terminal_contact_radius: float = 0.42
@export var electrified_duration_seconds: float = 1.2
@export var shock_tick_interval: float = 0.35
@export var shock_status_duration: float = 0.45

var filled: bool = true
var scan_timer: float = 0.0
var electrified_timer: float = 0.0
var shock_timer: float = 0.0
var immersed_terminal_keys: Array[String] = []
var excitation_port: CircuitExcitationPort
var water_area: Area3D
var water_mesh: MeshInstance3D
var state_label: Label3D
var normal_material: StandardMaterial3D
var conducting_material: StandardMaterial3D
var electrified_material: StandardMaterial3D


func _ready() -> void:
	component_kind = "conductive_water"
	display_name = "Conductive Water"
	filled = starts_filled
	ensure_terminals()
	ensure_volume_nodes()
	add_to_group("conductive_water_volumes")
	add_to_group("lab_resettable")
	super._ready()
	call_deferred("scan_immersed_terminals")
	update_visual_state()


func _process(delta: float) -> void:
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = max(scan_interval, 0.02)
		scan_immersed_terminals()

	if electrified_timer > 0.0:
		electrified_timer = max(electrified_timer - delta, 0.0)
		shock_timer -= delta
		if shock_timer <= 0.0:
			shock_timer = max(shock_tick_interval, 0.05)
			shock_overlapping_targets()
		if electrified_timer <= 0.0:
			update_visual_state()


func ensure_terminals() -> void:
	var terminal_a: CircuitTerminal = get_node_or_null("TerminalA") as CircuitTerminal
	if terminal_a == null:
		terminal_a = CircuitTerminal.new()
		terminal_a.name = "TerminalA"
		terminal_a.terminal_id = "water_a"
		add_child(terminal_a)
	terminal_a.connection_radius = max(terminal_a.connection_radius, terminal_contact_radius)

	var terminal_b: CircuitTerminal = get_node_or_null("TerminalB") as CircuitTerminal
	if terminal_b == null:
		terminal_b = CircuitTerminal.new()
		terminal_b.name = "TerminalB"
		terminal_b.terminal_id = "water_b"
		add_child(terminal_b)
	terminal_b.connection_radius = max(terminal_b.connection_radius, terminal_contact_radius)


func ensure_volume_nodes() -> void:
	water_area = get_node_or_null("WaterArea") as Area3D
	if water_area == null:
		water_area = Area3D.new()
		water_area.name = "WaterArea"
		water_area.monitoring = true
		water_area.monitorable = true
		add_child(water_area)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = volume_size
		collision.shape = shape
		water_area.add_child(collision)

	water_mesh = get_node_or_null("WaterMesh") as MeshInstance3D
	if water_mesh == null:
		water_mesh = MeshInstance3D.new()
		water_mesh.name = "WaterMesh"
		var mesh := BoxMesh.new()
		mesh.size = volume_size
		water_mesh.mesh = mesh
		add_child(water_mesh)

	normal_material = make_water_material(Color(0.08, 0.42, 0.68, 0.62), 1.3)
	conducting_material = make_water_material(Color(0.08, 0.62, 0.82, 0.7), 2.4)
	electrified_material = make_water_material(Color(0.42, 0.58, 1.0, 0.78), 4.2)
	water_mesh.material_override = normal_material

	state_label = get_node_or_null("StateLabel") as Label3D
	if state_label == null:
		state_label = Label3D.new()
		state_label.name = "StateLabel"
		state_label.position = Vector3(0.0, volume_size.y * 0.75 + 0.6, 0.0)
		state_label.font_size = 24
		state_label.pixel_size = 0.006
		state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		state_label.outline_size = 5
		add_child(state_label)


func make_water_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.18
	material.metallic = 0.05
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_energy
	return material


func configure_excitation_port(port: CircuitExcitationPort) -> void:
	excitation_port = port


func scan_immersed_terminals() -> void:
	var candidates: Array[CircuitTerminal] = []
	for candidate: Node in get_tree().get_nodes_in_group("circuit_terminals"):
		if not candidate is CircuitTerminal:
			continue
		var terminal := candidate as CircuitTerminal
		if terminal == get_terminal_a() or terminal == get_terminal_b():
			continue
		if terminal.get_component() == self or not terminal.enabled:
			continue
		if terminal.network_layer != get_terminal_a().network_layer:
			continue
		if contains_world_point(terminal.global_position):
			candidates.append(terminal)

	candidates.sort_custom(func(a: CircuitTerminal, b: CircuitTerminal) -> bool:
		return a.get_terminal_key() < b.get_terminal_key()
	)
	var selected: Array[CircuitTerminal] = select_farthest_pair(candidates)
	var next_keys: Array[String] = []
	for terminal: CircuitTerminal in selected:
		next_keys.append(terminal.get_terminal_key())

	var contacts_changed: bool = next_keys != immersed_terminal_keys
	immersed_terminal_keys = next_keys
	path_enabled = filled and selected.size() == 2

	if selected.size() == 2:
		get_terminal_a().global_position = selected[0].global_position
		get_terminal_b().global_position = selected[1].global_position
		var electrode_distance: float = selected[0].global_position.distance_to(selected[1].global_position)
		resistance_ohms = max(
			minimum_resistance_ohms,
			resistance_per_meter_ohms * electrode_distance / max(conductivity_scale, 0.01)
		)

	if contacts_changed:
		electrode_contacts_changed.emit(immersed_terminal_keys.duplicate())
		notify_topology_changed()
	elif not path_enabled:
		notify_topology_changed()
	update_visual_state()


func select_farthest_pair(candidates: Array[CircuitTerminal]) -> Array[CircuitTerminal]:
	var selected: Array[CircuitTerminal] = []
	if candidates.size() < 2:
		return selected
	var best_distance: float = -1.0
	for first_index: int in range(candidates.size()):
		for second_index: int in range(first_index + 1, candidates.size()):
			var distance: float = candidates[first_index].global_position.distance_to(
				candidates[second_index].global_position
			)
			if distance > best_distance:
				best_distance = distance
				selected.clear()
				selected.append(candidates[first_index])
				selected.append(candidates[second_index])
	return selected


func contains_world_point(world_point: Vector3) -> bool:
	var local_point: Vector3 = to_local(world_point)
	var half_size: Vector3 = volume_size * 0.5
	return (
		absf(local_point.x) <= half_size.x
		and absf(local_point.y) <= half_size.y
		and absf(local_point.z) <= half_size.z
	)


func set_filled(next_filled: bool) -> void:
	if filled == next_filled:
		return
	filled = next_filled
	if not filled:
		electrified_timer = 0.0
		path_enabled = false
		apply_circuit_state(false, 0.0, 0.0, -1)
	fill_state_changed.emit(filled)
	scan_timer = 0.0
	scan_immersed_terminals()
	notify_topology_changed()
	update_visual_state()


func toggle_filled() -> void:
	set_filled(not filled)


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {"message": "Conductive water receives an empty payload.", "objective": ""}
	if not filled:
		return {
			"message": payload.source_name + " strikes the dry basin, but there is no water to conduct it.",
			"objective": "Fill the basin before testing water conduction.",
		}
	if not payload_is_electrical(payload):
		return {
			"message": payload.source_name + " reaches the water, but it does not provide electrical excitation.",
			"objective": "Use Lightning to energize the conductive water.",
		}

	electrified_timer = max(electrified_duration_seconds, payload.status_duration, 0.1)
	shock_timer = 0.0
	water_electrified.emit(payload.source_name, electrified_timer)
	update_visual_state()
	var relay_result: Dictionary = {}
	if excitation_port != null:
		relay_result = excitation_port.receive_damage_payload(payload)
	return {
		"message": payload.source_name + " electrifies the water. " + str(relay_result.get("message", "")),
		"objective": "Observe the same water path conduct battery current and transient Lightning power.",
	}


func payload_is_electrical(payload: DamagePayload) -> bool:
	if payload.element.to_lower().strip_edges() == "lightning":
		return true
	for raw_tag: String in payload.tags:
		if raw_tag.to_lower().strip_edges() in ["lightning", "shock", "electrical"]:
			return true
	return false


func shock_overlapping_targets() -> void:
	if water_area == null or not filled:
		return
	var seen: Dictionary = {}
	var overlaps: Array[Node] = []
	for body: Node3D in water_area.get_overlapping_bodies():
		overlaps.append(body)
	for area: Area3D in water_area.get_overlapping_areas():
		overlaps.append(area)
	for raw_target: Node in overlaps:
		var target: Node = find_status_target(raw_target)
		if target == null or target == self or is_ancestor_of(target):
			continue
		var target_id: int = target.get_instance_id()
		if seen.has(target_id):
			continue
		seen[target_id] = true
		var status_receiver: Node = target.get_node_or_null("StatusReceiver")
		if status_receiver != null and status_receiver.has_method("sustain_status"):
			status_receiver.sustain_status(
				"stunned",
				shock_status_duration,
				1.0,
				"Electrified Water"
			)


func find_status_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current.get_node_or_null("StatusReceiver") != null:
			return current
		current = current.get_parent()
	return null


func get_hazard_tags() -> Array[String]:
	var tags: Array[String] = ["water", "wet", "conductive"]
	if electrified_timer > 0.0:
		tags.append("electrified")
		tags.append("lightning")
	return tags


func _on_circuit_state_applied() -> void:
	update_visual_state()


func update_visual_state() -> void:
	if water_mesh != null:
		water_mesh.visible = filled
		if electrified_timer > 0.0:
			water_mesh.material_override = electrified_material
		elif energized:
			water_mesh.material_override = conducting_material
		else:
			water_mesh.material_override = normal_material
	if water_area != null:
		water_area.monitorable = filled
	if state_label != null:
		if not filled:
			state_label.text = "WATER BASIN\nDRAINED"
		elif electrified_timer > 0.0:
			state_label.text = "WATER BASIN\nELECTRIFIED"
		elif immersed_terminal_keys.size() == 2:
			state_label.text = "WATER BASIN\n" + str(snapped(resistance_ohms, 0.01)) + " Ω"
		else:
			state_label.text = "WATER BASIN\nNEEDS 2 ELECTRODES"


func reset_target() -> void:
	filled = starts_filled
	electrified_timer = 0.0
	shock_timer = 0.0
	apply_circuit_state(false, 0.0, 0.0, -1)
	scan_timer = 0.0
	scan_immersed_terminals()
	fill_state_changed.emit(filled)
	update_visual_state()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["filled"] = filled
	data["volume_size"] = volume_size
	data["conductivity_scale"] = snapped(conductivity_scale, 0.01)
	data["immersed_electrodes"] = immersed_terminal_keys.duplicate()
	data["electrified"] = electrified_timer > 0.0
	data["electrified_remaining"] = snapped(electrified_timer, 0.01)
	data["excitation_port"] = excitation_port.component_id if excitation_port != null else "none"
	return data
