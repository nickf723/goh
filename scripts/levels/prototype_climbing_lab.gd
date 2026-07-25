extends Node3D
class_name PrototypeClimbingLab

var player: CharacterBody3D
var climbing: PlayerClimbingController
var status_label: Label
var wet_wall: StaticBody3D
var wet_enabled: bool = true
var wet_material: StandardMaterial3D


func _ready() -> void:
	_build_environment()
	_build_course()
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		climbing = player.get_node_or_null("ClimbingController") as PlayerClimbingController
	_configure_player()
	_build_hud()
	GameState.set_objective("Climb each material, rest on the wall, mantle the ledge, and compare grip costs.")


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		_reset_lab()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_R:
			_toggle_wet_wall()
			get_viewport().set_input_as_handled()


func _configure_player() -> void:
	if player == null:
		return
	GameState.set_stat("max_health", 80)
	GameState.set_stat("health", 80)
	GameState.set_stat("max_stamina", 36)
	GameState.set_stat("stamina", 36)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)
	var weapon := player.get_node_or_null("WeaponController") as WeaponController
	if weapon != null:
		weapon.show_debug_prints = false


func _reset_lab() -> void:
	if climbing != null:
		climbing.reset_climbing()
	if player != null:
		player.global_position = Vector3(0, 1.1, 8.0)
		player.rotation = Vector3.ZERO
		player.velocity = Vector3.ZERO
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("health", GameState.get_stat("max_health"))


func _toggle_wet_wall() -> void:
	if wet_wall == null:
		return
	wet_enabled = not wet_enabled
	wet_wall.set_meta("climb_surface", "wet" if wet_enabled else "stone")
	if wet_material != null:
		wet_material.albedo_color = Color(0.08, 0.3, 0.42) if wet_enabled else Color(0.28, 0.32, 0.38)
		wet_material.emission = Color(0.04, 0.24, 0.38) if wet_enabled else Color(0.12, 0.16, 0.22)
	_show_message("Wet wall: " + ("RAIN-SLICK" if wet_enabled else "DRY"))


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.022, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.38, 0.46, 0.62)
	environment.ambient_light_energy = 0.84
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -24, 0)
	sun.light_color = Color(0.78, 0.87, 1.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	for data: Dictionary in [
		{"position": Vector3(-7, 5, 2), "color": Color(0.38, 0.72, 1.0)},
		{"position": Vector3(7, 5, 2), "color": Color(1.0, 0.58, 0.22)},
	]:
		var light := OmniLight3D.new()
		light.position = data["position"]
		light.light_color = data["color"]
		light.light_energy = 4.2
		light.omni_range = 12.0
		add_child(light)


func _build_course() -> void:
	_add_floor()
	_add_climb_bay(-8.0, 4.4, "stone", "STONE", Color(0.32, 0.36, 0.43))
	_add_climb_bay(-4.0, 5.7, "wood", "WOOD", Color(0.42, 0.22, 0.09))
	_add_climb_bay(0.0, 5.0, "metal", "METAL", Color(0.25, 0.32, 0.4))
	wet_wall = _add_climb_bay(4.0, 5.8, "wet", "WET STONE", Color(0.08, 0.3, 0.42))
	wet_material = wet_wall.get_meta("display_material") as StandardMaterial3D
	_add_climb_bay(8.0, 4.8, "ice", "ICE — NO GRIP", Color(0.5, 0.88, 1.0))
	_add_low_mantle(Vector3(-1.8, 0, 4.2))
	var title := Label3D.new()
	title.text = "CLIMBING & MANTLING LAB"
	title.position = Vector3(0, 8.0, -3.4)
	title.font_size = 38
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 8
	title.modulate = Color(0.72, 0.88, 1.0)
	add_child(title)
	var instructions := Label3D.new()
	instructions.text = "JUMP + FORWARD TO GRAB   •   WASD / STICK CLIMBS   •   JUMP LEAPS OFF   •   C / BOTTOM FACE DROPS   •   R RAIN TOGGLE   •   F8 RESET"
	instructions.position = Vector3(0, 7.2, -3.3)
	instructions.font_size = 17
	instructions.pixel_size = 0.008
	instructions.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	instructions.outline_size = 6
	instructions.modulate = Color(0.86, 0.93, 1.0)
	add_child(instructions)


func _add_floor() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(24, 0.8, 22)
	collision.shape = shape
	collision.position.y = -0.4
	floor.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.065, 0.08, 0.12)
	material.metallic = 0.32
	material.roughness = 0.62
	mesh_instance.material_override = material
	floor.add_child(mesh_instance)
	add_child(floor)


func _add_climb_bay(x: float, height: float, surface: String, label_text: String, color: Color) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = label_text.replace(" ", "") + "Wall"
	wall.position = Vector3(x, 0, 0)
	wall.add_to_group("climbable")
	wall.set_meta("climb_surface", surface)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.15, height, 0.5)
	collision.shape = shape
	collision.position.y = height * 0.5
	wall.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = height * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.78 if surface == "metal" else 0.08
	material.roughness = 0.2 if surface == "ice" or surface == "wet" else 0.72
	material.emission_enabled = true
	material.emission = color.darkened(0.25)
	material.emission_energy_multiplier = 0.35
	mesh_instance.material_override = material
	wall.add_child(mesh_instance)
	wall.set_meta("display_material", material)
	add_child(wall)
	var platform := StaticBody3D.new()
	platform.position = Vector3(x, height - 0.2, -1.7)
	var platform_collision := CollisionShape3D.new()
	var platform_shape := BoxShape3D.new()
	platform_shape.size = Vector3(3.15, 0.4, 3.4)
	platform_collision.shape = platform_shape
	platform.add_child(platform_collision)
	var platform_mesh := MeshInstance3D.new()
	var platform_box := BoxMesh.new()
	platform_box.size = platform_shape.size
	platform_mesh.mesh = platform_box
	platform_mesh.material_override = material
	platform.add_child(platform_mesh)
	add_child(platform)
	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(x, height + 0.8, 0.15)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.008
	label.outline_size = 7
	label.modulate = color.lightened(0.35)
	add_child(label)
	return wall


func _add_low_mantle(position: Vector3) -> void:
	var block := StaticBody3D.new()
	block.position = position
	block.add_to_group("climbable")
	block.set_meta("climb_surface", "stone")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.35, 1.2)
	collision.shape = shape
	collision.position.y = 0.675
	block.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.675
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.36, 0.48)
	material.emission_enabled = true
	material.emission = Color(0.08, 0.22, 0.4)
	material.emission_energy_multiplier = 0.45
	mesh_instance.material_override = material
	block.add_child(mesh_instance)
	add_child(block)
	var label := Label3D.new()
	label.text = "LOW MANTLE"
	label.position = position + Vector3(0, 2.0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 20
	label.pixel_size = 0.008
	label.outline_size = 6
	label.modulate = Color(0.58, 0.82, 1.0)
	add_child(label)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 14
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(475, 92)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.022, 0.043, 0.9)
	style.border_color = Color(0.3, 0.66, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	panel.add_child(status_label)


func _update_hud() -> void:
	if status_label == null or climbing == null:
		return
	var data: Dictionary = climbing.get_debug_data()
	var mode: String = "MANTLING" if bool(data.get("mantling", false)) else ("CLIMBING" if bool(data.get("climbing", false)) else "GROUND")
	status_label.text = (
		"TRAVERSAL  •  " + mode
		+ "  •  " + str(data.get("outcome", "READY"))
		+ "\nSURFACE  •  " + str(data.get("surface", "none")).to_upper()
		+ "     COST ×" + str(data.get("drain_multiplier", 1.0))
		+ "     SLIDE " + str(data.get("slide", 0.0)) + " m/s"
		+ "     STAMINA " + str(GameState.get_stat("stamina")) + "/" + str(GameState.get_stat("max_stamina"))
	)


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
