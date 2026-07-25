extends Node3D
class_name PrototypeGasDynamicsLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const AirflowFieldScript = preload("res://scripts/airflow/airflow_field_3d.gd")
const AirflowVectorVisualizerScript = preload("res://scripts/airflow/airflow_vector_visualizer.gd")
const GasVolumeGridScript = preload("res://scripts/gas/gas_volume_grid.gd")
const GasEmitterScript = preload("res://scripts/gas/gas_emitter_3d.gd")
const GasSensorScript = preload("res://scripts/gas/gas_density_sensor.gd")
const GasExposureReceiverScript = preload("res://scripts/gas/gas_exposure_receiver.gd")
const SmokeGas = preload("res://data/gas/smoke_gas.tres")
const PoisonGas = preload("res://data/gas/poison_gas.tres")
const GasLabLoadout: Resource = preload("res://data/loadouts/grace_gas_lab_loadout.tres")

@export var enable_editor_f8_reset: bool = true
@export_range(0.04, 1.0, 0.01) var readout_refresh_interval: float = 0.2
@export var safety_reset_height: float = -5.0

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var airflow_manager: Node = get_node_or_null("AirflowManager")
@onready var gas_manager: Node = get_node_or_null("GasManager")

var stat_snapshot: Dictionary = {}
var initial_player_transform: Transform3D
var readout_timer: float = 0.0
var reset_count: int = 0
var gas_visuals_visible: bool = true

var smoke_volume: GasVolumeGrid = null
var poison_volume: GasVolumeGrid = null
var exposure_receiver: GasExposureReceiver = null
var vector_visualizer: Node3D = null
var readout: Label3D = null
var sensors: Array[GasDensitySensor] = []


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	build_laboratory()
	if player != null:
		player.add_to_group("player")
		initial_player_transform = player.transform
	configure_player()
	attach_player_exposure_receiver()
	GameState.set_objective("Watch Smoke rise, compare Poison density by height, use Gust to ventilate the fields, and inspect the vortex.")
	show_message("Gas Dynamics Laboratory ready. Density has memory and airflow transports it through space.")
	update_readout()


func _process(delta: float) -> void:
	readout_timer -= max(delta, 0.0)
	if readout_timer <= 0.0:
		readout_timer = max(readout_refresh_interval, 0.04)
		update_readout()
	if player != null and player.global_position.y < safety_reset_height:
		reset_lab()


func _exit_tree() -> void:
	var aerial: Node = player.get_node_or_null("AerialLocomotion") if player != null else null
	if aerial != null and bool(aerial.get("flight_active")):
		aerial.call("finish_flight", true, false)
	restore_stat_snapshot()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if enable_editor_f8_reset and OS.has_feature("editor") and key_event.physical_keycode == KEY_F8:
		reset_lab()
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_V and vector_visualizer != null:
		vector_visualizer.visible = not vector_visualizer.visible
		show_message("Airflow vectors " + ("visible." if vector_visualizer.visible else "hidden."))
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_B:
		gas_visuals_visible = not gas_visuals_visible
		for volume: Node in get_tree().get_nodes_in_group("gas_volumes"):
			if volume != null and volume.has_method("set_density_visuals_visible"):
				volume.call("set_density_visuals_visible", gas_visuals_visible)
		show_message("Gas density voxels " + ("visible." if gas_visuals_visible else "hidden."))
		get_viewport().set_input_as_handled()


func configure_player() -> void:
	if player == null:
		return
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null:
		ability_caster.set("loadout", GasLabLoadout.duplicate(true))
		ability_caster.set("current_ability_index", 0)
		if ability_caster.has_method("align_focus_menu_to_current_ability"):
			ability_caster.call("align_focus_menu_to_current_ability")
		if ability_caster.has_method("emit_current_ability"):
			ability_caster.call("emit_current_ability")
	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	if aerial != null:
		aerial.set("double_jump_unlocked", true)
		aerial.set("hover_unlocked", true)
		aerial.set("flight_unlocked", true)
		aerial.set("maximum_air_jumps", 1)
	GameState.set_stat("max_health", 20)
	GameState.set_stat("health", 20)
	GameState.set_stat("max_mana", 12)
	GameState.set_stat("mana", 12)
	GameState.set_stat("focus", max(GameState.get_stat("focus"), 5))
	player.set("is_defeated", false)
	var action_state: Node = player.get_node_or_null("PlayerActionState")
	if action_state != null and action_state.has_method("reset_for_respawn"):
		action_state.call("reset_for_respawn")


func attach_player_exposure_receiver() -> void:
	if player == null:
		return
	var existing: Node = player.get_node_or_null("GasExposureReceiver")
	if existing is GasExposureReceiver:
		exposure_receiver = existing as GasExposureReceiver
		return
	exposure_receiver = GasExposureReceiverScript.new() as GasExposureReceiver
	exposure_receiver.name = "GasExposureReceiver"
	exposure_receiver.warning_dose_threshold = 0.18
	exposure_receiver.effect_dose_threshold = 0.45
	exposure_receiver.exposure_response_multiplier = 0.75
	exposure_receiver.maximum_obscuration_alpha = 0.16
	exposure_receiver.show_messages = true
	player.add_child(exposure_receiver)


func build_laboratory() -> void:
	create_floor_and_boundaries()
	create_instruction_board()
	create_zone_floor(Vector3(-8.5, 0.02, -1.5), Vector3(15.0, 0.05, 13.0), Color(0.24, 0.31, 0.37, 1.0), "SMOKE CHIMNEY")
	create_zone_floor(Vector3(8.5, 0.02, -1.5), Vector3(15.0, 0.05, 13.0), Color(0.2, 0.42, 0.12, 1.0), "POISON BASIN")
	create_zone_floor(Vector3(-2.5, 0.03, -11.0), Vector3(13.0, 0.06, 8.0), Color(0.34, 0.18, 0.46, 1.0), "VORTEX TRANSPORT")
	create_airflow_fields()
	create_gas_volumes()
	create_emitters()
	create_architecture()
	create_sensors()
	create_vector_visualization()
	create_readout()


func create_floor_and_boundaries() -> void:
	create_static_box("SafetyFloor", Vector3(0.0, -0.45, 0.0), Vector3(40.0, 0.9, 36.0), Color(0.045, 0.055, 0.075, 1.0), 0.04, 1.0)
	var wall_color := Color(0.03, 0.042, 0.06, 1.0)
	create_static_box("NorthWall", Vector3(0.0, 7.0, -18.0), Vector3(40.0, 14.0, 0.5), wall_color)
	create_static_box("SouthWall", Vector3(0.0, 7.0, 18.0), Vector3(40.0, 14.0, 0.5), wall_color)
	create_static_box("WestWall", Vector3(-20.0, 7.0, 0.0), Vector3(0.5, 14.0, 36.0), wall_color)
	create_static_box("EastWall", Vector3(20.0, 7.0, 0.0), Vector3(0.5, 14.0, 36.0), wall_color)


func create_instruction_board() -> void:
	var board := Node3D.new()
	board.name = "InstructionBoard"
	board.position = Vector3(0.0, 2.55, 16.2)
	add_child(board)
	ElementVisuals.add_box(board, "Board", Vector3(16.5, 3.6, 0.18), Color(0.02, 0.04, 0.065, 1.0), Vector3.ZERO, Vector3.ZERO, 0.32, 0.96)
	var label := make_label(
		"REACTIVE GAS DYNAMICS LAB\nSMOKE rises  •  POISON settles  •  AIRFLOW advects both  •  GUST relocates density\nOptimized active grids  •  V vectors  •  B density voxels  •  F8 reset",
		Vector3(0.0, 0.0, 0.11),
		Color(0.72, 0.94, 1.0, 1.0),
		27,
		0.0049
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(label)


func create_airflow_fields() -> void:
	var smoke_updraft: Node3D = create_field("smoke_updraft", AirflowFieldScript.FieldKind.UPDRAFT, AirflowFieldScript.VolumeShape.CYLINDER, Vector3(-8.5, 4.2, -1.5))
	smoke_updraft.set("radius", 3.4)
	smoke_updraft.set("cylinder_height", 8.4)
	smoke_updraft.set("strength", 3.8)
	smoke_updraft.set("turbulence_strength", 0.36)
	smoke_updraft.set("edge_fade_fraction", 0.28)

	var poison_crosswind: Node3D = create_field("poison_vent", AirflowFieldScript.FieldKind.DIRECTIONAL, AirflowFieldScript.VolumeShape.BOX, Vector3(8.5, 2.4, -1.5))
	poison_crosswind.set("box_extents", Vector3(6.8, 2.8, 5.6))
	poison_crosswind.set("local_direction", Vector3.RIGHT)
	poison_crosswind.set("strength", 1.6)
	poison_crosswind.set("turbulence_strength", 0.18)
	poison_crosswind.set("edge_fade_fraction", 0.22)

	var smoke_transfer: Node3D = create_field("smoke_transfer", AirflowFieldScript.FieldKind.DIRECTIONAL, AirflowFieldScript.VolumeShape.BOX, Vector3(-5.0, 5.0, -6.2))
	smoke_transfer.set("box_extents", Vector3(5.0, 3.2, 5.5))
	smoke_transfer.set("local_direction", Vector3(0.65, 0.0, -1.0))
	smoke_transfer.set("strength", 2.6)
	smoke_transfer.set("edge_fade_fraction", 0.35)

	var vortex: Node3D = create_field("gas_vortex", AirflowFieldScript.FieldKind.VORTEX, AirflowFieldScript.VolumeShape.CYLINDER, Vector3(-2.5, 4.2, -11.0))
	vortex.set("radius", 4.8)
	vortex.set("cylinder_height", 8.4)
	vortex.set("strength", 5.8)
	vortex.set("vortex_inward_fraction", 0.24)
	vortex.set("vortex_vertical_fraction", 0.12)
	vortex.set("turbulence_strength", 0.42)
	vortex.set("edge_fade_fraction", 0.3)


func create_field(field_id: String, kind: int, shape: int, position_value: Vector3) -> Node3D:
	var field: Node3D = AirflowFieldScript.new() as Node3D
	field.name = field_id.capitalize().replace(" ", "") + "Field"
	field.position = position_value
	field.set("field_id", field_id)
	field.set("field_kind", kind)
	field.set("volume_shape", shape)
	add_child(field)
	return field


func create_gas_volumes() -> void:
	smoke_volume = GasVolumeGridScript.new() as GasVolumeGrid
	smoke_volume.name = "SmokeDensityGrid"
	smoke_volume.position = Vector3(-6.0, 4.2, -5.0)
	smoke_volume.gas_definition = SmokeGas
	smoke_volume.grid_size = Vector3i(14, 8, 14)
	smoke_volume.cell_size = 1.2
	smoke_volume.simulation_interval = 0.18
	smoke_volume.maximum_steps_per_frame = 1
	smoke_volume.simulation_phase_offset = 0.0
	smoke_volume.visual_stride = 2
	smoke_volume.visual_update_interval = 0.28
	smoke_volume.visual_radius_scale = 0.48
	smoke_volume.active_padding_cells = 3
	add_child(smoke_volume)

	poison_volume = GasVolumeGridScript.new() as GasVolumeGrid
	poison_volume.name = "PoisonDensityGrid"
	poison_volume.position = Vector3(8.5, 3.0, -1.5)
	poison_volume.gas_definition = PoisonGas
	poison_volume.grid_size = Vector3i(12, 6, 10)
	poison_volume.cell_size = 1.15
	poison_volume.simulation_interval = 0.18
	poison_volume.maximum_steps_per_frame = 1
	poison_volume.simulation_phase_offset = 0.09
	poison_volume.visual_stride = 2
	poison_volume.visual_update_interval = 0.28
	poison_volume.visual_radius_scale = 0.48
	poison_volume.active_padding_cells = 3
	add_child(poison_volume)


func create_emitters() -> void:
	create_emitter("SmokeFurnace", "smoke", Vector3(-8.5, 0.45, -1.5), 1.35, 1.35, Color(0.52, 0.6, 0.65, 1.0), "SMOKE SOURCE")
	create_emitter("PoisonLeak", "poison", Vector3(6.0, 0.55, -1.5), 1.15, 1.8, Color(0.38, 0.88, 0.18, 1.0), "POISON LEAK")
	call_deferred("seed_initial_poison")


func create_emitter(
	emitter_name: String,
	gas_id: String,
	position_value: Vector3,
	rate: float,
	radius_value: float,
	color: Color,
	label_text: String
) -> GasEmitter3D:
	var emitter: GasEmitter3D = GasEmitterScript.new() as GasEmitter3D
	emitter.name = emitter_name
	emitter.position = position_value
	emitter.emitter_id = emitter_name.to_lower()
	emitter.gas_id = gas_id
	emitter.emission_rate_per_second = rate
	emitter.emission_radius = radius_value
	emitter.pulse_frequency = 0.32
	emitter.pulse_depth = 0.18
	add_child(emitter)
	ElementVisuals.add_sphere(emitter, "EmitterCore", 0.42, color, Vector3.ZERO, Vector3(1.0, 0.65, 1.0), 1.8, 0.55)
	ElementVisuals.add_torus(emitter, "EmitterRing", 0.55, 0.68, color, Vector3(0.0, 0.08, 0.0), Vector3.ZERO, 1.2, 0.38)
	emitter.add_child(make_label(label_text, Vector3(0.0, 1.15, 0.0), color, 24, 0.006))
	return emitter


func seed_initial_poison() -> void:
	if poison_volume == null or not is_instance_valid(poison_volume):
		return
	poison_volume.inject_density(Vector3(6.0, 0.45, -1.5), 0.65, 2.8, 0.22)
	poison_volume.inject_density(Vector3(8.0, 0.4, -1.5), 0.35, 2.4, 0.3)


func create_architecture() -> void:
	var smoke_color := Color(0.2, 0.28, 0.34, 1.0)
	for index: int in range(4):
		var ring_root := Node3D.new()
		ring_root.name = "SmokeRiseRing" + str(index)
		ring_root.position = Vector3(-8.5, 1.3 + float(index) * 1.7, -1.5)
		add_child(ring_root)
		ElementVisuals.add_torus(ring_root, "Ring", 1.55, 1.78, smoke_color.lightened(float(index) * 0.08), Vector3.ZERO, Vector3.ZERO, 0.85, 0.2)
	var crown_marker := Node3D.new()
	crown_marker.name = "SmokeCrownMarker"
	crown_marker.position = Vector3(-8.5, 7.1, -1.5)
	add_child(crown_marker)
	ElementVisuals.add_torus(crown_marker, "CrownRing", 2.15, 2.42, Color(0.28, 0.38, 0.44, 1.0), Vector3.ZERO, Vector3.ZERO, 0.85, 0.28)
	create_static_box("PoisonLowShelf", Vector3(11.4, 0.3, -1.5), Vector3(3.8, 0.6, 8.0), Color(0.16, 0.32, 0.1, 1.0), 0.15, 0.72)

	for index: int in range(4):
		var marker := Node3D.new()
		marker.name = "PoisonFlowMarker" + str(index)
		marker.position = Vector3(4.7 + float(index) * 2.3, 0.7, -4.9)
		add_child(marker)
		ElementVisuals.add_torus(marker, "Ring", 0.48, 0.62, Color(0.34, 0.84, 0.18, 1.0), Vector3.ZERO, Vector3(0.0, 0.0, 90.0), 1.1, 0.25)

	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0
		var vortex_marker := Node3D.new()
		vortex_marker.name = "GasVortexMarker" + str(index)
		vortex_marker.position = Vector3(-2.5 + cos(angle) * 3.2, 2.5 + float(index % 2) * 1.3, -11.0 + sin(angle) * 3.2)
		add_child(vortex_marker)
		ElementVisuals.add_torus(vortex_marker, "Ring", 0.72, 0.9, Color(0.68, 0.38, 0.94, 1.0), Vector3.ZERO, Vector3(90.0, 0.0, 0.0), 1.0, 0.2)


func create_sensors() -> void:
	create_sensor("Smoke Base", Vector3(-11.0, 0.0, 0.8), ["smoke"], Color(0.72, 0.82, 0.88, 1.0))
	create_sensor("Smoke Mid", Vector3(-11.0, 3.0, -1.5), ["smoke"], Color(0.66, 0.78, 0.86, 1.0))
	create_sensor("Smoke Crown", Vector3(-11.0, 6.1, -3.8), ["smoke"], Color(0.6, 0.74, 0.84, 1.0))
	var poison_low: GasDensitySensor = create_sensor("Poison Low", Vector3(5.0, 0.0, 1.3), ["poison"], Color(0.48, 0.96, 0.24, 1.0))
	poison_low.sample_offset = Vector3(0.0, 0.3, 0.0)
	var poison_high: GasDensitySensor = create_sensor("Poison High", Vector3(11.4, 0.6, 1.3), ["poison"], Color(0.7, 1.0, 0.42, 1.0))
	poison_high.sample_offset = Vector3(0.0, 2.1, 0.0)
	create_sensor("Vortex", Vector3(-2.5, 2.4, -11.0), ["smoke", "poison"], Color(0.78, 0.62, 1.0, 1.0))


func create_sensor(sensor_name: String, position_value: Vector3, gas_ids_value: Array[String], color: Color) -> GasDensitySensor:
	var sensor: GasDensitySensor = GasSensorScript.new() as GasDensitySensor
	sensor.name = sensor_name.replace(" ", "") + "Sensor"
	sensor.position = position_value
	sensor.sensor_label = sensor_name.to_upper()
	sensor.gas_ids = gas_ids_value
	sensor.label_color = color
	add_child(sensor)
	sensors.append(sensor)
	return sensor


func create_vector_visualization() -> void:
	vector_visualizer = AirflowVectorVisualizerScript.new() as Node3D
	vector_visualizer.name = "VectorVisualizer"
	vector_visualizer.position = Vector3(0.0, 4.0, -3.0)
	vector_visualizer.set("sample_extents", Vector3(17.0, 4.5, 14.0))
	vector_visualizer.set("sample_spacing", Vector3(4.5, 3.0, 4.5))
	vector_visualizer.set("refresh_interval", 0.35)
	add_child(vector_visualizer)


func create_readout() -> void:
	readout = make_label("LOCAL ATMOSPHERE", Vector3(-17.2, 3.4, 15.0), Color(0.72, 0.94, 1.0, 1.0), 26, 0.0058)
	readout.name = "GasReadout"
	add_child(readout)


func make_label(text_value: String, position_value: Vector3, color: Color, font_size_value: int, pixel_size_value: float) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = font_size_value
	label.pixel_size = pixel_size_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = color
	return label


func create_zone_floor(position_value: Vector3, size_value: Vector3, color: Color, label_text: String) -> void:
	var panel := MeshInstance3D.new()
	panel.name = label_text.replace(" ", "") + "Panel"
	var mesh := BoxMesh.new()
	mesh.size = size_value
	panel.mesh = mesh
	panel.position = position_value
	panel.material_override = ElementVisuals.make_material(color, 0.3, 0.38, true)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)
	var label := make_label(label_text, position_value + Vector3(0.0, 0.18, 0.0), color.lightened(0.3), 24, 0.006)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(label)


func create_static_box(
	name_value: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color,
	emission: float = 0.08,
	alpha: float = 1.0
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_value
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(color, emission, alpha, false)
	body.add_child(mesh_instance)
	add_child(body)
	return body


func update_readout() -> void:
	if readout == null or player == null:
		return
	var local_breakdown: Dictionary = {}
	if gas_manager != null and gas_manager.has_method("sample_breakdown"):
		var sampled_value: Variant = gas_manager.call("sample_breakdown", player.global_position + Vector3.UP * 0.85)
		if sampled_value is Dictionary:
			local_breakdown = sampled_value as Dictionary
	var smoke_density: float = float(local_breakdown.get("smoke", 0.0))
	var poison_density: float = float(local_breakdown.get("poison", 0.0))
	var smoke_dose: float = exposure_receiver.get_dose("smoke") if exposure_receiver != null else 0.0
	var poison_dose: float = exposure_receiver.get_dose("poison") if exposure_receiver != null else 0.0
	var air_velocity: Vector3 = Vector3.ZERO
	if airflow_manager != null and airflow_manager.has_method("sample_total_airflow"):
		var air_sample: Variant = airflow_manager.call("sample_total_airflow", player.global_position)
		if air_sample is Vector3:
			air_velocity = air_sample as Vector3
	var smoke_mass: float = smoke_volume.get_total_density_mass() if smoke_volume != null else 0.0
	var poison_mass: float = poison_volume.get_total_density_mass() if poison_volume != null else 0.0
	var smoke_cells: int = int(smoke_volume.get_debug_data().get("simulated_cells", 0)) if smoke_volume != null else 0
	var poison_cells: int = int(poison_volume.get_debug_data().get("simulated_cells", 0)) if poison_volume != null else 0
	readout.text = (
		"LOCAL ATMOSPHERE\nSmoke " + str(snapped(smoke_density, 0.01)) + "  •  Dose " + str(snapped(smoke_dose, 0.01))
		+ "\nPoison " + str(snapped(poison_density, 0.01)) + "  •  Dose " + str(snapped(poison_dose, 0.01))
		+ "\nAir " + format_vector(air_velocity) + "  •  " + str(snapped(air_velocity.length(), 0.1)) + " m/s"
		+ "\nGrid mass Smoke " + str(snapped(smoke_mass, 0.1)) + "  •  Poison " + str(snapped(poison_mass, 0.1))
		+ "\nSimulated cells " + str(smoke_cells) + " + " + str(poison_cells)
		+ "\nHealth " + str(GameState.get_stat("health")) + " / " + str(GameState.get_stat("max_health"))
	)


func format_vector(vector: Vector3) -> String:
	return "(" + str(snapped(vector.x, 0.1)) + ", " + str(snapped(vector.y, 0.1)) + ", " + str(snapped(vector.z, 0.1)) + ")"


func reset_lab() -> void:
	reset_count += 1
	for field_node: Node in get_tree().get_nodes_in_group("airflow_fields"):
		if field_node == null or not is_instance_valid(field_node):
			continue
		var candidate_id: String = str(field_node.get("field_id")) if field_node.get("field_id") != null else ""
		if candidate_id.begins_with("gust:"):
			field_node.queue_free()
	var aerial: Node = player.get_node_or_null("AerialLocomotion") if player != null else null
	if aerial != null and bool(aerial.get("flight_active")):
		aerial.call("finish_flight", true, false)
	for node: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if node == null or not is_instance_valid(node) or not is_ancestor_of(node):
			continue
		if node.has_method("reset_target"):
			node.call("reset_target")
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	configure_player()
	call_deferred("seed_initial_poison")
	GameState.set_objective("Watch Smoke rise, compare Poison density by height, use Gust to ventilate the fields, and inspect the vortex.")
	show_message("Gas Dynamics Laboratory reset #" + str(reset_count) + ".")
	update_readout()


func restore_stat_snapshot() -> void:
	for raw_key: Variant in stat_snapshot.keys():
		GameState.set_stat(str(raw_key), int(stat_snapshot[raw_key]))


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"gas_lab": true,
		"smoke_mass": smoke_volume.get_total_density_mass() if smoke_volume != null else 0.0,
		"poison_mass": poison_volume.get_total_density_mass() if poison_volume != null else 0.0,
		"smoke_grid": smoke_volume.get_debug_data() if smoke_volume != null else {},
		"poison_grid": poison_volume.get_debug_data() if poison_volume != null else {},
		"player_exposure": exposure_receiver.get_debug_data() if exposure_receiver != null else {},
		"sensor_count": sensors.size(),
		"gas_visuals_visible": gas_visuals_visible,
		"reset_count": reset_count,
	}
