extends Node3D
class_name PrototypeSwimmingLab

var player: CharacterBody3D
var swimming: PlayerSwimmingController
var climbing: PlayerClimbingController
var status_label: Label
var treasure_collected: bool = false
var treasure: Area3D


func _ready() -> void:
	_build_environment()
	_build_pool()
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		swimming = player.get_node_or_null("SwimmingController") as PlayerSwimmingController
		climbing = player.get_node_or_null("ClimbingController") as PlayerClimbingController
	_configure_player()
	_build_hud()
	GameState.set_objective("Enter the pool, dive through the current tunnel, collect the pearl, and climb out.")


func _process(_delta: float) -> void:
	_update_hud()
	if treasure != null and player != null and not treasure_collected:
		if treasure.global_position.distance_to(player.global_position) < 1.0:
			treasure_collected = true
			treasure.visible = false
			_show_message("Abyss Pearl collected!")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		_reset_lab()
		get_viewport().set_input_as_handled()


func _configure_player() -> void:
	GameState.set_stat("max_health", 80)
	GameState.set_stat("health", 80)
	GameState.set_stat("max_stamina", 50)
	GameState.set_stat("stamina", 50)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)
	if player == null:
		return
	var weapon := player.get_node_or_null("WeaponController") as WeaponController
	if weapon != null:
		weapon.show_debug_prints = false


func _reset_lab() -> void:
	if swimming != null:
		swimming.reset_swimming()
	if climbing != null:
		climbing.reset_climbing()
	if player != null:
		player.global_position = Vector3(0, 1.1, 10.0)
		player.rotation = Vector3.ZERO
		player.velocity = Vector3.ZERO
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	treasure_collected = false
	if treasure != null:
		treasure.visible = true


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008, 0.03, 0.055)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.52, 0.72)
	environment.ambient_light_energy = 0.92
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.78
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -18, 0)
	sun.light_color = Color(0.64, 0.86, 1.0)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	add_child(sun)
	for data: Dictionary in [
		{"position": Vector3(-5, -1, 0), "color": Color(0.12, 0.62, 1.0)},
		{"position": Vector3(5, -2, -3), "color": Color(0.12, 1.0, 0.78)},
	]:
		var light := OmniLight3D.new()
		light.position = data["position"]
		light.light_color = data["color"]
		light.light_energy = 4.8
		light.omni_range = 11.0
		add_child(light)


func _build_pool() -> void:
	_add_box_body("EntryDeck", Vector3(18, 0.8, 5), Vector3(0, -0.4, 10.5), Color(0.16, 0.2, 0.25))
	_add_box_body("PoolFloor", Vector3(16, 0.8, 16), Vector3(0, -8.4, 0), Color(0.04, 0.16, 0.22))
	_add_box_body("LeftWall", Vector3(0.8, 9, 16), Vector3(-8.4, -3.9, 0), Color(0.08, 0.22, 0.3))
	_add_box_body("RightWall", Vector3(0.8, 9, 16), Vector3(8.4, -3.9, 0), Color(0.08, 0.22, 0.3))
	_add_box_body("EntryStepA", Vector3(7, 0.7, 1.4), Vector3(0, -0.35, 7.2), Color(0.1, 0.28, 0.36))
	_add_box_body("EntryStepB", Vector3(7, 0.7, 1.4), Vector3(0, -1.05, 6.0), Color(0.09, 0.25, 0.34))
	_add_box_body("EntryStepC", Vector3(7, 0.7, 1.4), Vector3(0, -1.75, 4.8), Color(0.08, 0.22, 0.32))

	_add_water_volume(
		"MainPool",
		Vector3(16, 8, 16),
		Vector3(0, -4, 0),
		4.0,
		Vector3.ZERO,
		0.0,
		Color(0.05, 0.45, 0.68, 0.18)
	)
	_add_water_volume(
		"CurrentChannel",
		Vector3(4.5, 4, 9),
		Vector3(4.8, -2, -0.5),
		2.0,
		Vector3(0, 0, -2.4),
		0.0,
		Color(0.04, 0.8, 0.72, 0.12)
	)
	_add_water_volume(
		"VortexPocket",
		Vector3(5, 6, 5),
		Vector3(-4.5, -3, -2.5),
		3.0,
		Vector3.ZERO,
		1.8,
		Color(0.3, 0.2, 0.88, 0.1)
	)

	_add_box_body("TunnelLeft", Vector3(0.45, 3.6, 7), Vector3(2.5, -4.8, -1.0), Color(0.08, 0.26, 0.34))
	_add_box_body("TunnelRight", Vector3(0.45, 3.6, 7), Vector3(7.1, -4.8, -1.0), Color(0.08, 0.26, 0.34))
	_add_box_body("TunnelRoof", Vector3(5.0, 0.45, 7), Vector3(4.8, -2.8, -1.0), Color(0.08, 0.26, 0.34))

	var exit_wall := _add_box_body("ClimbExit", Vector3(4.2, 3.4, 0.55), Vector3(0, 1.7, -7.7), Color(0.24, 0.3, 0.34))
	exit_wall.add_to_group("climbable")
	exit_wall.set_meta("climb_surface", "stone")
	_add_box_body("ExitPlatform", Vector3(4.2, 0.5, 3.2), Vector3(0, 3.15, -9.1), Color(0.24, 0.3, 0.34))

	_build_treasure()
	_build_labels()


func _add_water_volume(
	volume_name: String,
	size: Vector3,
	position: Vector3,
	surface_offset: float,
	current: Vector3,
	swirl: float,
	color: Color
) -> SwimmingWaterVolume:
	var volume := SwimmingWaterVolume.new()
	volume.name = volume_name
	volume.position = position
	volume.surface_height_offset = surface_offset
	volume.current_velocity = current
	volume.swirl_strength = swirl
	volume.inward_strength = swirl * 0.18
	volume.water_label = volume_name
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	volume.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.metallic = 0.12
	material.roughness = 0.18
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 0.35
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	volume.add_child(visual)
	add_child(volume)
	return volume


func _add_box_body(body_name: String, size: Vector3, position: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.3
	material.roughness = 0.55
	material.emission_enabled = true
	material.emission = color.darkened(0.35)
	material.emission_energy_multiplier = 0.28
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	return body


func _build_treasure() -> void:
	treasure = Area3D.new()
	treasure.name = "AbyssPearl"
	treasure.position = Vector3(4.8, -5.0, -4.0)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.75
	collision.shape = shape
	treasure.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.76
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.94, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.32, 0.8, 1.0)
	material.emission_energy_multiplier = 3.2
	visual.material_override = material
	treasure.add_child(visual)
	add_child(treasure)


func _build_labels() -> void:
	var title := Label3D.new()
	title.text = "SWIMMING & DIVING LAB"
	title.position = Vector3(0, 5.8, 7.0)
	title.font_size = 38
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 8
	title.modulate = Color(0.66, 0.9, 1.0)
	add_child(title)
	var instructions := Label3D.new()
	instructions.text = "MOVE SWIMS   •   JUMP ASCENDS   •   C / BOTTOM FACE DIVES   •   HOLD GUARD SPRINTS   •   JUMP TOWARD EXIT WALL   •   F8 RESET"
	instructions.position = Vector3(0, 5.0, 7.1)
	instructions.font_size = 17
	instructions.pixel_size = 0.008
	instructions.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	instructions.outline_size = 6
	instructions.modulate = Color(0.84, 0.94, 1.0)
	add_child(instructions)
	_add_station_label("DEEP SHAFT", Vector3(-4.5, 1.0, -2.5), Color(0.6, 0.55, 1.0))
	_add_station_label("CURRENT TUNNEL", Vector3(4.8, 1.0, -0.5), Color(0.38, 1.0, 0.82))
	_add_station_label("CLIMB EXIT", Vector3(0, 4.4, -7.4), Color(0.76, 0.9, 1.0))


func _add_station_label(text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	label.pixel_size = 0.008
	label.outline_size = 7
	label.modulate = color
	add_child(label)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 14
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(520, 108)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.034, 0.06, 0.9)
	style.border_color = Color(0.18, 0.72, 1.0, 0.86)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	panel.add_child(status_label)


func _update_hud() -> void:
	if status_label == null or swimming == null:
		return
	var data: Dictionary = swimming.get_debug_data()
	var current: Vector3 = data.get("current", Vector3.ZERO)
	status_label.text = (
		"AQUATIC  •  " + str(data.get("state", "DRY"))
		+ "     BREATH " + str(data.get("breath", 0.0)) + "/" + str(data.get("max_breath", 0.0)) + "s"
		+ "     STAMINA " + str(GameState.get_stat("stamina")) + "/" + str(GameState.get_stat("max_stamina"))
		+ "\nCURRENT  •  " + str(snappedf(current.length(), 0.1)) + " m/s"
		+ "     DEPTH " + str(snappedf(maxf(float(data.get("surface_y", 0.0)) - player.global_position.y, 0.0), 0.1)) + "m"
		+ "     WET " + str(data.get("wetness", 0.0)) + "s"
		+ "     PEARL " + ("COLLECTED" if treasure_collected else "SUBMERGED")
	)


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
