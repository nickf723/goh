extends Node3D
class_name PrototypeAirflowLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const AirflowFieldScript = preload("res://scripts/airflow/airflow_field_3d.gd")
const AirflowVectorVisualizerScript = preload("res://scripts/airflow/airflow_vector_visualizer.gd")
const AirflowTracerVolumeScript = preload("res://scripts/airflow/airflow_tracer_volume.gd")
const AirflowTurbineScript = preload("res://scripts/airflow/airflow_turbine.gd")
const AirflowCloudVolumeScript = preload("res://scripts/airflow/airflow_cloud_volume.gd")
const AirflowTestBodyScene: PackedScene = preload("res://scenes/actors/props/airflow_test_body.tscn")
const AirflowLabLoadout: Resource = preload("res://data/loadouts/grace_airflow_lab_loadout.tres")

@export var enable_editor_f8_reset: bool = true
@export var readout_refresh_interval: float = 0.1

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var concentration_manager: Node = get_node_or_null("ConcentrationManager")
@onready var airflow_manager: Node = get_node_or_null("AirflowManager")

var stat_snapshot: Dictionary = {}
var initial_player_transform: Transform3D
var readout_timer: float = 0.0
var reset_count: int = 0
var fields: Array[Node3D] = []
var test_bodies: Array[CharacterBody3D] = []
var vector_visualizer: Node3D = null
var tracer_volume: Node3D = null
var turbine: Node3D = null
var cloud: Node3D = null
var readout: Label3D = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	build_laboratory()
	configure_player()
	if player != null:
		initial_player_transform = player.transform
		player.add_to_group("player")
	GameState.set_objective("Read the vector field, test mass response, ride the updraft, cross the downdraft, and enter the vortex.")
	show_message("Airflow Laboratory ready. Gust, Firebolt, Flight, props, tracers, cloud, and turbine all sample the same vector field.")
	update_readout()


func _process(delta: float) -> void:
	readout_timer -= delta
	if readout_timer <= 0.0:
		readout_timer = max(readout_refresh_interval, 0.05)
		update_readout()


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
		get_viewport().set_input_as_handled()
		reset_lab()
	elif key_event.physical_keycode == KEY_V and vector_visualizer != null:
		vector_visualizer.visible = not vector_visualizer.visible
		show_message("Airflow vectors " + ("visible." if vector_visualizer.visible else "hidden."))
		get_viewport().set_input_as_handled()


func configure_player() -> void:
	if player == null:
		return
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null:
		var runtime_loadout: Resource = AirflowLabLoadout.duplicate(true)
		ability_caster.set("loadout", runtime_loadout)
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
		aerial.set("hover_duration", 1.65)
	GameState.set_stat("max_mana", 12)
	GameState.set_stat("mana", 12)
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("focus", max(GameState.get_stat("focus"), 5))


func build_laboratory() -> void:
	create_floor_and_boundaries()
	create_instruction_board()
	create_zone_floor(Vector3(0.0, 0.02, 7.0), Vector3(20.0, 0.05, 8.0), Color(0.12, 0.34, 0.52, 1.0), "DIRECTIONAL CROSSWIND")
	create_zone_floor(Vector3(-10.0, 0.03, -3.0), Vector3(7.0, 0.06, 9.0), Color(0.18, 0.46, 0.66, 1.0), "UPDRAFT SHAFT")
	create_zone_floor(Vector3(10.0, 0.03, -3.0), Vector3(7.0, 0.06, 9.0), Color(0.24, 0.3, 0.5, 1.0), "DOWNDRAFT")
	create_zone_floor(Vector3(0.0, 0.03, -12.0), Vector3(14.0, 0.06, 10.0), Color(0.34, 0.18, 0.52, 1.0), "VORTEX")
	create_airflow_fields()
	create_mass_comparison()
	create_turbine()
	create_cloud()
	create_updraft_course()
	create_downdraft_course()
	create_vortex_course()
	create_field_visualization()
	create_readout()


func create_floor_and_boundaries() -> void:
	create_static_box("SafetyFloor", Vector3(0.0, -0.45, 0.0), Vector3(44.0, 0.9, 40.0), Color(0.045, 0.06, 0.095, 1.0), 0.04, 1.0)
	var wall_color := Color(0.035, 0.05, 0.08, 1.0)
	create_static_box("NorthWall", Vector3(0.0, 8.0, -20.0), Vector3(44.0, 16.0, 0.5), wall_color)
	create_static_box("SouthWall", Vector3(0.0, 8.0, 20.0), Vector3(44.0, 16.0, 0.5), wall_color)
	create_static_box("WestWall", Vector3(-22.0, 8.0, 0.0), Vector3(0.5, 16.0, 40.0), wall_color)
	create_static_box("EastWall", Vector3(22.0, 8.0, 0.0), Vector3(0.5, 16.0, 40.0), wall_color)


func create_instruction_board() -> void:
	var board := Node3D.new()
	board.name = "InstructionBoard"
	board.position = Vector3(0.0, 2.45, 18.4)
	add_child(board)
	ElementVisuals.add_box(board, "Board", Vector3(14.5, 3.4, 0.18), Color(0.02, 0.045, 0.075, 1.0), Vector3.ZERO, Vector3.ZERO, 0.3, 0.95)
	var label := Label3D.new()
	label.text = "ANALYTIC AIRFLOW LAB\nGUST creates a moving field  •  FIREBOLT bends in crosswind  •  FLIGHT rides the flow\nCompare 1 / 8 / 36 kg bodies  •  Updraft lifts  •  Downdraft suppresses  •  Vortex circles inward\nV toggles vectors  •  F8 resets"
	label.position = Vector3(0.0, 0.0, 0.11)
	label.font_size = 27
	label.pixel_size = 0.0051
	label.outline_size = 6
	label.modulate = Color(0.7, 0.92, 1.0, 1.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(label)


func create_airflow_fields() -> void:
	var crosswind: Node3D = create_field("crosswind", AirflowFieldScript.FieldKind.DIRECTIONAL, AirflowFieldScript.VolumeShape.BOX, Vector3(0.0, 3.0, 7.0))
	crosswind.set("box_extents", Vector3(10.0, 3.0, 4.0))
	crosswind.set("local_direction", Vector3.RIGHT)
	crosswind.set("strength", 10.0)
	crosswind.set("turbulence_strength", 0.42)
	crosswind.set("edge_fade_fraction", 0.22)

	var updraft: Node3D = create_field("updraft", AirflowFieldScript.FieldKind.UPDRAFT, AirflowFieldScript.VolumeShape.CYLINDER, Vector3(-10.0, 6.0, -3.0))
	updraft.set("radius", 3.5)
	updraft.set("cylinder_height", 12.0)
	updraft.set("strength", 10.5)
	updraft.set("turbulence_strength", 0.55)

	var downdraft: Node3D = create_field("downdraft", AirflowFieldScript.FieldKind.DOWNDRAFT, AirflowFieldScript.VolumeShape.CYLINDER, Vector3(10.0, 6.0, -3.0))
	downdraft.set("radius", 3.5)
	downdraft.set("cylinder_height", 12.0)
	downdraft.set("strength", 8.8)
	downdraft.set("turbulence_strength", 0.35)

	var vortex: Node3D = create_field("vortex", AirflowFieldScript.FieldKind.VORTEX, AirflowFieldScript.VolumeShape.CYLINDER, Vector3(0.0, 5.0, -12.0))
	vortex.set("radius", 6.6)
	vortex.set("cylinder_height", 10.0)
	vortex.set("strength", 9.4)
	vortex.set("vortex_inward_fraction", 0.28)
	vortex.set("vortex_vertical_fraction", 0.16)
	vortex.set("turbulence_strength", 0.7)
	vortex.set("edge_fade_fraction", 0.3)


func create_field(field_id: String, kind: int, shape: int, position_value: Vector3) -> Node3D:
	var field: Node3D = AirflowFieldScript.new() as Node3D
	field.name = field_id.capitalize().replace(" ", "") + "Field"
	field.position = position_value
	field.set("field_id", field_id)
	field.set("field_kind", kind)
	field.set("volume_shape", shape)
	add_child(field)
	fields.append(field)
	return field


func create_mass_comparison() -> void:
	create_test_body("LIGHT 1 KG", 1.0, Vector3(-6.0, 0.05, 8.0), Color(0.5, 0.88, 1.0, 1.0))
	create_test_body("MEDIUM 8 KG", 8.0, Vector3(0.0, 0.05, 8.0), Color(0.4, 0.66, 0.9, 1.0))
	create_test_body("HEAVY 36 KG", 36.0, Vector3(6.0, 0.05, 8.0), Color(0.34, 0.42, 0.56, 1.0))


func create_test_body(label_text: String, mass_kg: float, position_value: Vector3, color: Color) -> void:
	var body: CharacterBody3D = AirflowTestBodyScene.instantiate() as CharacterBody3D
	body.name = label_text.replace(" ", "").replace("KG", "Kg")
	body.position = position_value
	body.set("body_label", label_text)
	body.set("mass_override_kg", mass_kg)
	var response: Node = body.get_node_or_null("AirflowResponse")
	if response != null:
		response.set("mass_override_kg", mass_kg)
	var mesh: MeshInstance3D = body.get_node_or_null("Body") as MeshInstance3D
	if mesh != null:
		mesh.material_override = ElementVisuals.make_material(color, 0.28, 1.0, false)
	add_child(body)
	test_bodies.append(body)
	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0.0, 1.75, 0.0)
	label.font_size = 24
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = color.lightened(0.18)
	body.add_child(label)


func create_turbine() -> void:
	turbine = AirflowTurbineScript.new() as Node3D
	turbine.name = "CrosswindTurbine"
	turbine.position = Vector3(8.2, 0.0, 5.0)
	turbine.set("local_capture_axis", Vector3.RIGHT)
	add_child(turbine)


func create_cloud() -> void:
	cloud = AirflowCloudVolumeScript.new() as Node3D
	cloud.name = "VortexCloud"
	cloud.position = Vector3(-3.8, 2.4, -12.0)
	cloud.set("cloud_label", "ADVECTED CLOUD")
	cloud.set("particle_count", 38)
	cloud.set("maximum_distance_from_origin", 18.0)
	add_child(cloud)


func create_updraft_course() -> void:
	for index: int in range(3):
		var height: float = 3.0 + float(index) * 3.0
		var ring_root := Node3D.new()
		ring_root.name = "UpdraftRing" + str(index)
		ring_root.position = Vector3(-10.0, height, -3.0)
		add_child(ring_root)
		ElementVisuals.add_torus(ring_root, "Ring", 1.7, 1.95, Color(0.3, 0.82, 1.0, 1.0), Vector3.ZERO, Vector3.ZERO, 1.35, 0.24)
	create_static_box("UpdraftCrown", Vector3(-10.0, 11.2, -3.0), Vector3(5.5, 0.45, 5.5), Color(0.22, 0.5, 0.72, 1.0), 0.35, 0.7)


func create_downdraft_course() -> void:
	create_static_box("DowndraftHighDeck", Vector3(10.0, 10.2, -3.0), Vector3(5.5, 0.45, 5.5), Color(0.26, 0.34, 0.54, 1.0), 0.25, 0.8)
	for index: int in range(3):
		var ring_root := Node3D.new()
		ring_root.name = "DowndraftRing" + str(index)
		ring_root.position = Vector3(10.0, 8.0 - float(index) * 2.7, -3.0)
		add_child(ring_root)
		ElementVisuals.add_torus(ring_root, "Ring", 1.7, 1.95, Color(0.5, 0.62, 0.92, 1.0), Vector3.ZERO, Vector3.ZERO, 1.0, 0.2)


func create_vortex_course() -> void:
	for index: int in range(5):
		var angle: float = TAU * float(index) / 5.0
		var ring_root := Node3D.new()
		ring_root.name = "VortexMarker" + str(index)
		ring_root.position = Vector3(cos(angle) * 4.5, 2.2 + float(index % 2) * 1.8, -12.0 + sin(angle) * 4.5)
		add_child(ring_root)
		ElementVisuals.add_torus(ring_root, "Ring", 0.82, 1.02, Color(0.68, 0.36, 1.0, 1.0), Vector3(90.0, 0.0, 0.0), Vector3.ZERO, 1.3, 0.24)


func create_field_visualization() -> void:
	vector_visualizer = AirflowVectorVisualizerScript.new() as Node3D
	vector_visualizer.name = "VectorVisualizer"
	vector_visualizer.position = Vector3(0.0, 7.0, 0.0)
	vector_visualizer.set("sample_extents", Vector3(20.0, 7.0, 18.0))
	vector_visualizer.set("sample_spacing", Vector3(4.0, 3.2, 4.0))
	add_child(vector_visualizer)

	tracer_volume = AirflowTracerVolumeScript.new() as Node3D
	tracer_volume.name = "TracerVolume"
	tracer_volume.position = Vector3(0.0, 7.0, 0.0)
	tracer_volume.set("tracer_count", 120)
	tracer_volume.set("volume_extents", Vector3(21.0, 7.0, 18.5))
	add_child(tracer_volume)


func create_readout() -> void:
	readout = Label3D.new()
	readout.name = "AirflowReadout"
	readout.position = Vector3(-15.5, 3.1, 16.8)
	readout.font_size = 27
	readout.pixel_size = 0.006
	readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	readout.outline_size = 6
	readout.modulate = Color(0.66, 0.92, 1.0, 1.0)
	add_child(readout)


func create_zone_floor(position_value: Vector3, size_value: Vector3, color: Color, label_text: String) -> void:
	var panel := MeshInstance3D.new()
	panel.name = label_text.replace(" ", "") + "Panel"
	var mesh := BoxMesh.new()
	mesh.size = size_value
	panel.mesh = mesh
	panel.position = position_value
	panel.material_override = ElementVisuals.make_material(color, 0.35, 0.42, true)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)
	var label := Label3D.new()
	label.text = label_text
	label.position = position_value + Vector3(0.0, 0.18, 0.0)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.font_size = 24
	label.pixel_size = 0.006
	label.outline_size = 4
	label.modulate = color.lightened(0.25)
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
	var air_velocity: Vector3 = Vector3.ZERO
	if airflow_manager != null and airflow_manager.has_method("sample_total_airflow"):
		var sampled_value: Variant = airflow_manager.call("sample_total_airflow", player.global_position)
		if sampled_value is Vector3:
			air_velocity = sampled_value as Vector3
	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	var state: String = str(aerial.get("traversal_state")) if aerial != null else "base"
	var active_fields: int = get_tree().get_nodes_in_group("airflow_fields").size()
	readout.text = (
		"LOCAL AIRFLOW\nVelocity " + format_vector(air_velocity) + "  •  " + str(snapped(air_velocity.length(), 0.1)) + " m/s"
		+ "\nGrace " + format_vector(player.velocity) + "  •  State " + state.to_upper()
		+ "\nFields " + str(active_fields) + "  •  Mana " + str(GameState.get_stat("mana")) + " / " + str(GameState.get_stat("max_mana"))
		+ "\nGust / Firebolt / Flight are equipped"
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
	GameState.set_objective("Read the vector field, test mass response, ride the updraft, cross the downdraft, and enter the vortex.")
	show_message("Airflow Laboratory reset #" + str(reset_count) + ".")
	update_readout()


func restore_stat_snapshot() -> void:
	if stat_snapshot.is_empty():
		return
	for stat_name: Variant in stat_snapshot.keys():
		GameState.set_stat(str(stat_name), int(stat_snapshot[stat_name]))


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	var player_air: Vector3 = Vector3.ZERO
	if player != null and airflow_manager != null and airflow_manager.has_method("sample_total_airflow"):
		var sampled_value: Variant = airflow_manager.call("sample_total_airflow", player.global_position)
		if sampled_value is Vector3:
			player_air = sampled_value as Vector3
	return {
		"airflow_lab": true,
		"analytic_fields": fields.size(),
		"active_fields": get_tree().get_nodes_in_group("airflow_fields").size(),
		"test_bodies": test_bodies.size(),
		"player_air_velocity": player_air,
		"reset_count": reset_count,
	}
