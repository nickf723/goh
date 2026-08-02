extends Node3D
class_name PrototypeRecordedObjectLab

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const GameUIScene: PackedScene = preload("res://scenes/ui/game_ui.tscn")
const ManagerScript = preload("res://scripts/objects/recorded_object_manager.gd")
const StationScript = preload(
	"res://scripts/interaction/recorded_object_blueprint_station.gd"
)
const Catalog = preload("res://scripts/objects/recorded_object_catalog.gd")

var player: CharacterBody3D
var manager: RecordedObjectManager
var station_root: Node3D
var target_root: Node3D
var hud_layer: CanvasLayer
var selected_label: Label
var state_label: Label
var controls_label: Label
var refresh_remaining: float = 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	add_to_group("recorded_object_lab")
	add_to_group("debuggable")
	_build_environment()
	_build_geometry()
	_build_player_and_ui()
	_build_manager()
	_build_blueprint_stations()
	_build_test_lanes()
	_build_hud()
	GameState.set_stat("max_mana", maxi(GameState.get_stat("max_mana"), 20))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_objective(
		"Record an object, enter placement mode, and solve its proving lane."
	)
	_show_message(
		"Recorded Object Lab ready. F1-F4 select recorded blueprints, V toggles placement, Q/E cycle, R rotates, and F8 clears reproduced objects."
	)


func _process(delta: float) -> void:
	refresh_remaining = maxf(refresh_remaining - delta, 0.0)
	if refresh_remaining <= 0.0:
		refresh_remaining = 0.12
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_F9:
			record_all_for_debug()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F10:
			reset_blueprints_for_debug()
			get_viewport().set_input_as_handled()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "RecordedObjectEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.04, 0.07, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.68, 0.82, 1.0)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "LabKeyLight"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(0.86, 0.92, 1.0, 1.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "LabFillLight"
	fill.position = Vector3(0.0, 8.0, 4.0)
	fill.omni_range = 32.0
	fill.light_color = Color(0.34, 0.62, 1.0, 1.0)
	fill.light_energy = 7.0
	add_child(fill)


func _build_geometry() -> void:
	_create_static_box(
		"EntryFloor",
		Vector3(0.0, -0.5, 16.0),
		Vector3(28.0, 1.0, 18.0),
		Color(0.1, 0.14, 0.2, 1.0)
	)
	_create_static_box(
		"CentralFloor",
		Vector3(0.0, -0.5, 2.0),
		Vector3(28.0, 1.0, 10.0),
		Color(0.08, 0.12, 0.17, 1.0)
	)
	_create_static_box(
		"BackFloor",
		Vector3(0.0, -0.5, -11.0),
		Vector3(28.0, 1.0, 12.0),
		Color(0.075, 0.105, 0.15, 1.0)
	)
	_create_static_box(
		"LeftBoundary",
		Vector3(-14.5, 2.0, 3.0),
		Vector3(1.0, 5.0, 38.0),
		Color(0.045, 0.07, 0.1, 1.0)
	)
	_create_static_box(
		"RightBoundary",
		Vector3(14.5, 2.0, 3.0),
		Vector3(1.0, 5.0, 38.0),
		Color(0.045, 0.07, 0.1, 1.0)
	)
	_create_static_box(
		"BackBoundary",
		Vector3(0.0, 2.0, -17.0),
		Vector3(30.0, 5.0, 1.0),
		Color(0.045, 0.07, 0.1, 1.0)
	)
	_create_label(
		"RECORDED OBJECT PROVING GROUND",
		Vector3(0.0, 6.5, 19.5),
		Color(0.46, 0.82, 1.0, 1.0),
		54
	)


func _build_player_and_ui() -> void:
	var ui: Node = GameUIScene.instantiate()
	ui.name = "GameUI"
	add_child(ui)
	player = PlayerScene.instantiate() as CharacterBody3D
	player.name = "Player"
	player.position = Vector3(0.0, 1.0, 23.0)
	player.rotation_degrees.y = 180.0
	add_child(player)


func _build_manager() -> void:
	manager = ManagerScript.new() as RecordedObjectManager
	manager.name = "RecordedObjectManager"
	manager.maximum_total_active = 7
	manager.print_debug = OS.has_feature("editor")
	player.add_child(manager)
	manager.bind_actor(player)
	manager.blueprint_recorded.connect(_on_blueprint_state_changed)
	manager.blueprint_selected.connect(_on_blueprint_selected)
	manager.object_placed.connect(_on_object_placed)
	manager.active_objects_changed.connect(_on_active_objects_changed)


func _build_blueprint_stations() -> void:
	station_root = Node3D.new()
	station_root.name = "BlueprintStations"
	add_child(station_root)
	var positions: Array[Vector3] = [
		Vector3(-9.0, 0.0, 15.0),
		Vector3(-3.0, 0.0, 15.0),
		Vector3(3.0, 0.0, 15.0),
		Vector3(9.0, 0.0, 15.0),
	]
	for index: int in range(Catalog.BLUEPRINT_ORDER.size()):
		var blueprint_id: String = Catalog.BLUEPRINT_ORDER[index]
		var station := Area3D.new()
		station.name = blueprint_id.to_pascal_case() + "BlueprintStation"
		station.set_script(StationScript)
		station.set("blueprint_id", blueprint_id)
		station.set("prompt_text", "Record " + str(Catalog.get_definition(blueprint_id).get("short_name", blueprint_id.capitalize())))
		station.position = positions[index]
		station_root.add_child(station)


func _build_test_lanes() -> void:
	target_root = Node3D.new()
	target_root.name = "ProvingLanes"
	add_child(target_root)

	_create_lane_header(
		"CRATE STACK",
		Vector3(-9.0, 4.7, 7.0),
		Color(0.78, 0.48, 0.22, 1.0)
	)
	_create_static_box(
		"CrateLedge",
		Vector3(-9.0, 1.65, 1.5),
		Vector3(5.0, 3.3, 3.0),
		Color(0.24, 0.19, 0.14, 1.0),
		target_root
	)
	_create_label(
		"STACK TWO CRATES\nTO REACH THE LEDGE",
		Vector3(-9.0, 4.0, 1.5),
		Color(0.9, 0.68, 0.34, 1.0),
		28,
		target_root
	)

	_create_lane_header(
		"PLATFORM BRIDGE",
		Vector3(-3.0, 4.7, 7.0),
		Color(0.34, 0.74, 1.0, 1.0)
	)
	_create_static_box(
		"PlatformNearBank",
		Vector3(-3.0, 0.0, 3.7),
		Vector3(5.5, 0.3, 3.5),
		Color(0.14, 0.2, 0.28, 1.0),
		target_root
	)
	_create_static_box(
		"PlatformFarBank",
		Vector3(-3.0, 0.0, -3.7),
		Vector3(5.5, 0.3, 3.5),
		Color(0.14, 0.2, 0.28, 1.0),
		target_root
	)
	_create_static_box(
		"PlatformTrenchBottom",
		Vector3(-3.0, -3.2, 0.0),
		Vector3(5.5, 0.4, 4.0),
		Color(0.025, 0.035, 0.055, 1.0),
		target_root
	)
	_create_label(
		"BRIDGE THE GAP",
		Vector3(-3.0, 2.8, 0.0),
		Color(0.52, 0.84, 1.0, 1.0),
		28,
		target_root
	)

	_create_lane_header(
		"SPRING LAUNCH",
		Vector3(4.0, 4.7, 7.0),
		Color(0.42, 1.0, 0.58, 1.0)
	)
	_create_static_box(
		"SpringTower",
		Vector3(4.0, 2.5, -2.0),
		Vector3(5.0, 5.0, 4.0),
		Color(0.12, 0.24, 0.2, 1.0),
		target_root
	)
	_create_label(
		"LAUNCH TO THE TOP",
		Vector3(4.0, 5.7, -2.0),
		Color(0.52, 1.0, 0.68, 1.0),
		28,
		target_root
	)

	_create_lane_header(
		"BLAST BARREL",
		Vector3(10.0, 4.7, 7.0),
		Color(1.0, 0.38, 0.18, 1.0)
	)
	for offset: Vector3 in [
		Vector3(-1.2, 0.6, -1.0),
		Vector3(1.2, 0.6, -1.0),
		Vector3(0.0, 0.6, 1.1),
	]:
		_create_rigid_target(Vector3(10.0, 0.0, -7.0) + offset)
	_create_label(
		"PLACE • IGNITE • SCATTER",
		Vector3(10.0, 3.2, -7.0),
		Color(1.0, 0.52, 0.26, 1.0),
		27,
		target_root
	)


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "RecordedObjectLabHUD"
	hud_layer.layer = 26
	add_child(hud_layer)
	var panel := PanelContainer.new()
	panel.name = "RecordedObjectStatus"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -450.0
	panel.offset_top = 28.0
	panel.offset_right = -24.0
	panel.offset_bottom = 224.0
	panel.add_to_group("menu_suppressed_hud")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.045, 0.94)
	style.border_color = Color(0.3, 0.68, 1.0, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	hud_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	var heading := Label.new()
	heading.text = "RECORDED OBJECTS"
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", Color(0.48, 0.78, 1.0, 1.0))
	stack.add_child(heading)
	selected_label = Label.new()
	selected_label.add_theme_font_size_override("font_size", 19)
	selected_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	stack.add_child(selected_label)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 12)
	state_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94, 1.0))
	stack.add_child(state_label)
	controls_label = Label.new()
	controls_label.text = (
		"F1-F4 select  •  V / Y placement  •  Q/E or L/R cycle\n"
		+ "R rotate  •  Click / A place  •  Right-click / B cancel\n"
		+ "F8 clear objects  •  F9 record all  •  F10 reset blueprints"
	)
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.add_theme_font_size_override("font_size", 10)
	controls_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.84, 1.0))
	stack.add_child(controls_label)
	_refresh_hud()


func record_all_for_debug() -> void:
	for blueprint_id: String in Catalog.BLUEPRINT_ORDER:
		manager.record_blueprint(blueprint_id)
	manager.select_blueprint(Catalog.BLUEPRINT_ORDER[0])
	_refresh_station_visuals()
	_show_message("All four recorded-object blueprints are available.")


func reset_blueprints_for_debug() -> void:
	manager.cancel_placement()
	manager.clear_spawned_objects()
	for blueprint_id: String in Catalog.BLUEPRINT_ORDER:
		GameState.inventory.erase(Catalog.get_item_id(blueprint_id))
	GameState.story_flags.erase(Catalog.SELECTED_BLUEPRINT_FLAG)
	GameState.inventory_changed.emit("recorded_object_blueprints", 0)
	_refresh_station_visuals()
	_refresh_hud()
	_show_message("Recorded-object blueprints reset.")


func reset_lab_for_test() -> void:
	manager.cancel_placement()
	manager.clear_spawned_objects()
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	for body: Node in get_tree().get_nodes_in_group("recorded_object_test_target"):
		if body is RigidBody3D:
			var rigid := body as RigidBody3D
			rigid.linear_velocity = Vector3.ZERO
			rigid.angular_velocity = Vector3.ZERO
	_refresh_hud()


func get_debug_data() -> Dictionary:
	return {
		"catalog_failures": Catalog.validate_catalog(),
		"recorded_count": Catalog.get_recorded_blueprint_ids().size(),
		"selected_blueprint": Catalog.get_selected_blueprint_id(),
		"active_objects": manager.get_active_count() if manager != null else 0,
		"station_count": get_tree().get_nodes_in_group("recorded_object_blueprint_station").size(),
		"target_count": get_tree().get_nodes_in_group("recorded_object_test_target").size(),
		"manager": manager.get_debug_data() if manager != null else {},
	}


func _refresh_hud() -> void:
	if selected_label == null or state_label == null or manager == null:
		return
	var selected_id: String = Catalog.get_selected_blueprint_id()
	var definition: Dictionary = Catalog.get_definition(selected_id)
	selected_label.text = (
		"NO BLUEPRINT SELECTED"
		if selected_id == ""
		else str(definition.get("icon", "▣")) + "  " + str(definition.get("display_name", selected_id.capitalize()))
	)
	var debug: Dictionary = manager.get_debug_data()
	state_label.text = (
		("PLACEMENT ACTIVE" if bool(debug.get("placement_active", false)) else "PLACEMENT STOWED")
		+ "  •  "
		+ str(debug.get("active_count", 0))
		+ " / "
		+ str(debug.get("maximum_total_active", 0))
		+ " ACTIVE  •  "
		+ str(GameState.get_stat("mana"))
		+ " MANA"
	)
	if bool(debug.get("placement_active", false)) and not bool(debug.get("placement_valid", false)):
		state_label.text += "\n" + str(debug.get("invalid_reason", "Invalid placement"))


func _refresh_station_visuals() -> void:
	for station: Node in get_tree().get_nodes_in_group("recorded_object_blueprint_station"):
		if station.has_method("_refresh_visual"):
			station.call("_refresh_visual")


func _on_blueprint_state_changed(_blueprint_id: String, _newly_recorded: bool) -> void:
	_refresh_station_visuals()
	_refresh_hud()


func _on_blueprint_selected(_blueprint_id: String) -> void:
	_refresh_station_visuals()
	_refresh_hud()


func _on_object_placed(_object: RecordedObjectInstance) -> void:
	_refresh_hud()


func _on_active_objects_changed(_count: int) -> void:
	_refresh_hud()


func _create_lane_header(text: String, position_value: Vector3, color: Color) -> void:
	_create_label(text, position_value, color, 34, target_root)


func _create_static_box(
	box_name: String,
	position_value: Vector3,
	size: Vector3,
	color: Color,
	parent_override: Node = null
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color)
	body.add_child(mesh_instance)
	(parent_override if parent_override != null else self).add_child(body)
	return body


func _create_rigid_target(position_value: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "BlastTarget"
	body.position = position_value
	body.mass = 2.0
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("recorded_object_test_target")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.2, 1.0)
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.2, 1.0)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(Color(0.9, 0.48, 0.18, 1.0))
	body.add_child(mesh_instance)
	target_root.add_child(body)
	return body


func _create_label(
	text: String,
	position_value: Vector3,
	color: Color,
	font_size: int,
	parent_override: Node = null
) -> Label3D:
	var label := Label3D.new()
	label.name = text.replace(" ", "").replace("\n", "") + "Label"
	label.text = text
	label.position = position_value
	label.font_size = font_size
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.modulate = color
	(parent_override if parent_override != null else self).add_child(label)
	return label


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.12
	material.roughness = 0.72
	return material


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)
