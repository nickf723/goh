extends "res://scripts/levels/prototype_recorded_object_lab.gd"
class_name PrototypeEngineeringBuildYard

const BuildCatalog = preload(
	"res://scripts/builds/engineering_build_catalog.gd"
)
const BuildManagerScript = preload(
	"res://scripts/builds/engineering_build_manager.gd"
)
const BuildStationScript = preload(
	"res://scripts/interaction/engineering_build_station.gd"
)

var build_manager: EngineeringBuildManager
var build_station_root: Node3D
var build_target_root: Node3D
var build_hud_layer: CanvasLayer
var build_selected_label: Label
var build_state_label: Label
var build_refresh_remaining: float = 0.0
var build_water_basin: FluidForceVolume
var construction_pad_position: Vector3 = Vector3(0.0, 0.0, 4.0)


func _ready() -> void:
	super._ready()
	add_to_group("engineering_build_yard")
	if manager != null:
		manager.keyboard_controls_enabled = false
		manager.controller_controls_enabled = false
		manager.cancel_placement()
		manager.clear_spawned_objects()
	if station_root != null:
		station_root.position.y = -80.0
	if target_root != null:
		target_root.position.y = -80.0
	if hud_layer != null:
		hud_layer.visible = false
	_build_engineering_manager()
	_build_construction_stations()
	_build_construction_yard()
	_build_engineering_hud()
	GameState.set_stat("max_mana", maxi(GameState.get_stat("max_mana"), 30))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_objective(
		"Record component objects, save a construction, then reproduce and test it."
	)
	_show_message(
		"Engineering Build Yard ready. F9 records components and saves all builds; F1-F4 select; V places."
	)


func _process(delta: float) -> void:
	super._process(delta)
	build_refresh_remaining = maxf(build_refresh_remaining - delta, 0.0)
	if build_refresh_remaining <= 0.0:
		build_refresh_remaining = 0.12
		_refresh_build_hud()


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F5:
			place_selected_on_construction_pad()
			get_viewport().set_input_as_handled()
		KEY_F6:
			place_raft_in_basin()
			get_viewport().set_input_as_handled()
		KEY_F7:
			reset_build_yard_for_test()
			get_viewport().set_input_as_handled()
		KEY_F9:
			save_all_builds_for_debug()
			get_viewport().set_input_as_handled()
		KEY_F10:
			reset_build_blueprints_for_debug()
			get_viewport().set_input_as_handled()


func _build_engineering_manager() -> void:
	build_manager = BuildManagerScript.new() as EngineeringBuildManager
	build_manager.name = "EngineeringBuildManager"
	build_manager.maximum_total_active = 4
	build_manager.print_debug = OS.has_feature("editor")
	player.add_child(build_manager)
	build_manager.bind_actor(player)
	build_manager.build_saved.connect(_on_build_state_changed)
	build_manager.build_selected.connect(_on_build_selected)
	build_manager.build_placed.connect(_on_build_placed)
	build_manager.active_builds_changed.connect(_on_active_builds_changed)


func _build_construction_stations() -> void:
	build_station_root = Node3D.new()
	build_station_root.name = "EngineeringBuildStations"
	add_child(build_station_root)
	var positions: Array[Vector3] = [
		Vector3(-9.0, 0.0, 15.0),
		Vector3(-3.0, 0.0, 15.0),
		Vector3(3.0, 0.0, 15.0),
		Vector3(9.0, 0.0, 15.0),
	]
	for index: int in range(BuildCatalog.BUILD_ORDER.size()):
		var build_id: String = BuildCatalog.BUILD_ORDER[index]
		var definition: Dictionary = BuildCatalog.get_definition(build_id)
		var station := Area3D.new()
		station.name = build_id.to_pascal_case() + "BuildStation"
		station.set_script(BuildStationScript)
		station.set("build_id", build_id)
		station.set("prompt_text", "Save " + str(definition.get("short_name", build_id.capitalize())))
		station.set("station_color", definition.get("color", Color.WHITE))
		station.position = positions[index]
		build_station_root.add_child(station)


func _build_construction_yard() -> void:
	build_target_root = Node3D.new()
	build_target_root.name = "EngineeringBuildTestYard"
	add_child(build_target_root)

	_create_label(
		"ENGINEERING BUILD YARD",
		Vector3(0.0, 6.5, 19.5),
		Color(0.62, 0.9, 1.0, 1.0),
		54,
		build_target_root
	)
	_create_label(
		"F5 QUICK-PLACES THE SELECTED BUILD",
		Vector3(0.0, 4.8, 8.0),
		Color(0.62, 0.74, 0.9, 1.0),
		26,
		build_target_root
	)

	var pad := MeshInstance3D.new()
	pad.name = "ConstructionPad"
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.2
	pad_mesh.bottom_radius = 2.35
	pad_mesh.height = 0.16
	pad_mesh.radial_segments = 32
	pad.mesh = pad_mesh
	pad.position = construction_pad_position + Vector3.UP * 0.12
	pad.material_override = _make_engineering_material(
		Color(0.18, 0.38, 0.58, 1.0)
	)
	build_target_root.add_child(pad)

	_build_bridge_lane()
	_build_launch_lane()
	_build_blast_lane()
	_build_raft_basin()


func _build_bridge_lane() -> void:
	_create_label(
		"BRIDGE FRAME\nSPAN THE LOWER SERVICE RUN",
		Vector3(-8.0, 3.8, 4.0),
		Color(0.44, 0.76, 1.0, 1.0),
		30,
		build_target_root
	)
	_create_static_box(
		"BridgeEndpointWest",
		Vector3(-11.0, 0.65, 0.0),
		Vector3(3.2, 1.3, 4.0),
		Color(0.13, 0.19, 0.28, 1.0),
		build_target_root
	)
	_create_static_box(
		"BridgeEndpointEast",
		Vector3(-5.0, 0.65, 0.0),
		Vector3(3.2, 1.3, 4.0),
		Color(0.13, 0.19, 0.28, 1.0),
		build_target_root
	)
	_create_static_box(
		"ServiceRun",
		Vector3(-8.0, 0.04, 0.0),
		Vector3(3.0, 0.08, 4.0),
		Color(0.025, 0.045, 0.07, 1.0),
		build_target_root
	)


func _build_launch_lane() -> void:
	_create_label(
		"LAUNCH TOWER\nREACH THE HIGH LEDGE",
		Vector3(8.0, 5.8, 4.0),
		Color(0.5, 1.0, 0.68, 1.0),
		30,
		build_target_root
	)
	_create_static_box(
		"LaunchShelf",
		Vector3(9.0, 4.4, -0.5),
		Vector3(7.0, 0.8, 5.0),
		Color(0.12, 0.28, 0.22, 1.0),
		build_target_root
	)


func _build_blast_lane() -> void:
	_create_label(
		"BLAST CART\nPUSH, DAMPEN, OR DETONATE",
		Vector3(-7.5, 4.2, -9.5),
		Color(1.0, 0.52, 0.2, 1.0),
		30,
		build_target_root
	)
	for offset: Vector3 in [
		Vector3(-9.0, 0.8, -12.0),
		Vector3(-7.0, 0.8, -12.0),
		Vector3(-5.0, 0.8, -12.0),
	]:
		var target := RigidBody3D.new()
		target.name = "EngineeringBlastTarget"
		target.position = offset
		target.mass = 2.0
		target.collision_layer = 1
		target.collision_mask = 1
		target.add_to_group("engineering_build_test_target")
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 1.4, 1.0)
		collision.shape = shape
		target.add_child(collision)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.4, 1.0)
		mesh.mesh = box
		mesh.material_override = _make_engineering_material(
			Color(0.88, 0.42, 0.16, 1.0)
		)
		target.add_child(mesh)
		build_target_root.add_child(target)


func _build_raft_basin() -> void:
	_create_label(
		"CONDUCTIVE RAFT\nF6 DEPLOYS INTO SHARED WATER",
		Vector3(7.5, 4.0, -9.5),
		Color(0.4, 0.86, 1.0, 1.0),
		30,
		build_target_root
	)
	for wall_data: Dictionary in [
		{"position": Vector3(3.8, 0.8, -11.0), "size": Vector3(0.35, 2.4, 7.0)},
		{"position": Vector3(11.2, 0.8, -11.0), "size": Vector3(0.35, 2.4, 7.0)},
		{"position": Vector3(7.5, 0.8, -14.4), "size": Vector3(7.6, 2.4, 0.35)},
		{"position": Vector3(7.5, 0.8, -7.6), "size": Vector3(7.6, 2.4, 0.35)},
	]:
		_create_static_box(
			"RaftBasinWall",
			wall_data.get("position", Vector3.ZERO) as Vector3,
			wall_data.get("size", Vector3.ONE) as Vector3,
			Color(0.08, 0.15, 0.22, 1.0),
			build_target_root
		)
	build_water_basin = FluidForceVolume.new()
	build_water_basin.name = "EngineeringBuildWaterBasin"
	build_water_basin.position = Vector3(7.5, 1.1, -11.0)
	build_water_basin.volume_size = Vector3(7.0, 2.0, 6.4)
	build_water_basin.flow_velocity_m_s = Vector3(0.65, 0.0, 0.0)
	build_water_basin.shallow_color = Color(0.1, 0.62, 0.9, 0.66)
	build_water_basin.deep_color = Color(0.015, 0.12, 0.32, 0.86)
	build_target_root.add_child(build_water_basin)


func _build_engineering_hud() -> void:
	build_hud_layer = CanvasLayer.new()
	build_hud_layer.name = "EngineeringBuildHUD"
	build_hud_layer.layer = 27
	add_child(build_hud_layer)
	var panel := PanelContainer.new()
	panel.name = "EngineeringBuildPanel"
	panel.position = Vector2(24.0, 24.0)
	panel.custom_minimum_size = Vector2(410.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.075, 0.94)
	style.border_color = Color(0.34, 0.72, 0.94, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	build_hud_layer.add_child(panel)
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
	heading.text = "ENGINEERING BUILDS"
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", Color(0.48, 0.82, 1.0, 1.0))
	stack.add_child(heading)
	build_selected_label = Label.new()
	build_selected_label.add_theme_font_size_override("font_size", 19)
	build_selected_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	stack.add_child(build_selected_label)
	build_state_label = Label.new()
	build_state_label.add_theme_font_size_override("font_size", 12)
	build_state_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.96, 1.0))
	stack.add_child(build_state_label)
	var controls := Label.new()
	controls.text = (
		"F1-F4 select  •  V / Y placement  •  Q/E or L/R cycle\n"
		+ "R rotate  •  Click / A place  •  F5 quick-place  •  F6 raft basin\n"
		+ "F7 reset yard  •  F8 clear  •  F9 save all  •  F10 reset blueprints"
	)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 10)
	controls.add_theme_color_override("font_color", Color(0.6, 0.72, 0.86, 1.0))
	stack.add_child(controls)
	_refresh_build_hud()


func save_all_builds_for_debug() -> void:
	record_all_for_debug()
	for build_id: String in BuildCatalog.BUILD_ORDER:
		build_manager.save_build(build_id)
	build_manager.select_build(BuildCatalog.BUILD_ORDER[0])
	_refresh_build_stations()
	_refresh_build_hud()
	_show_message("All four engineering constructions are saved.")


func reset_build_blueprints_for_debug() -> void:
	if build_manager != null:
		build_manager.cancel_placement()
		build_manager.clear_spawned_builds()
	for build_id: String in BuildCatalog.BUILD_ORDER:
		GameState.inventory.erase(BuildCatalog.get_item_id(build_id))
	GameState.story_flags.erase(BuildCatalog.SELECTED_BUILD_FLAG)
	GameState.inventory_changed.emit("engineering_build_blueprints", 0)
	_refresh_build_stations()
	_refresh_build_hud()
	_show_message("Engineering build blueprints reset.")


func reset_build_yard_for_test() -> void:
	if build_manager != null:
		build_manager.cancel_placement()
		build_manager.clear_spawned_builds()
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	for target: Node in get_tree().get_nodes_in_group("engineering_build_test_target"):
		if target is RigidBody3D:
			var rigid := target as RigidBody3D
			rigid.linear_velocity = Vector3.ZERO
			rigid.angular_velocity = Vector3.ZERO
	_refresh_build_hud()


func place_selected_on_construction_pad() -> EngineeringBuildInstance:
	if build_manager == null:
		return null
	if BuildCatalog.get_selected_build_id() == "":
		save_all_builds_for_debug()
	build_manager.clear_spawned_builds()
	return build_manager.place_selected_at(
		construction_pad_position,
		0.0,
		true,
		true
	)


func place_raft_in_basin() -> EngineeringBuildInstance:
	if build_manager == null:
		return null
	if not BuildCatalog.is_saved("conductive_raft"):
		save_all_builds_for_debug()
	build_manager.select_build("conductive_raft")
	return build_manager.place_selected_at(
		Vector3(7.5, 1.8, -11.0),
		0.0,
		true,
		true
	)


func get_engineering_debug_data() -> Dictionary:
	return {
		"catalog_failures": BuildCatalog.validate_catalog(),
		"saved_count": BuildCatalog.get_saved_build_ids().size(),
		"selected_build": BuildCatalog.get_selected_build_id(),
		"active_builds": build_manager.get_active_count() if build_manager != null else 0,
		"station_count": get_tree().get_nodes_in_group("engineering_build_station").size(),
		"has_water_basin": build_water_basin != null,
		"manager": build_manager.get_debug_data() if build_manager != null else {},
	}


func _refresh_build_hud() -> void:
	if build_selected_label == null or build_state_label == null or build_manager == null:
		return
	var selected_id: String = BuildCatalog.get_selected_build_id()
	var definition: Dictionary = BuildCatalog.get_definition(selected_id)
	build_selected_label.text = (
		"NO CONSTRUCTION SELECTED"
		if selected_id == ""
		else str(definition.get("icon", "⚙"))
		+ "  "
		+ str(definition.get("display_name", selected_id.capitalize()))
	)
	var debug: Dictionary = build_manager.get_debug_data()
	build_state_label.text = (
		("PLACEMENT ACTIVE" if bool(debug.get("placement_active", false)) else "PLACEMENT STOWED")
		+ "  •  "
		+ str(BuildCatalog.get_saved_build_ids().size())
		+ "/4 SAVED  •  "
		+ str(debug.get("active_count", 0))
		+ "/"
		+ str(debug.get("maximum_total_active", 0))
		+ " ACTIVE  •  "
		+ str(GameState.get_stat("mana"))
		+ " MANA"
	)
	if bool(debug.get("placement_active", false)) and not bool(debug.get("placement_valid", false)):
		build_state_label.text += "\n" + str(debug.get("invalid_reason", "Invalid placement"))


func _refresh_build_stations() -> void:
	for station: Node in get_tree().get_nodes_in_group("engineering_build_station"):
		if station.has_method("_refresh_label"):
			station.call("_refresh_label")


func _on_build_state_changed(_build_id: String, _newly_saved: bool) -> void:
	_refresh_build_stations()
	_refresh_build_hud()


func _on_build_selected(_build_id: String) -> void:
	_refresh_build_stations()
	_refresh_build_hud()


func _on_build_placed(_build: EngineeringBuildInstance) -> void:
	_refresh_build_hud()


func _on_active_builds_changed(_count: int) -> void:
	_refresh_build_hud()


func _make_engineering_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.28
	material.roughness = 0.5
	material.emission_enabled = true
	material.emission = color.darkened(0.45)
	material.emission_energy_multiplier = 0.45
	return material
