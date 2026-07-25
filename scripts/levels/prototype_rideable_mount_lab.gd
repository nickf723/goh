extends Node3D
class_name PrototypeRideableMountLab

var player: CharacterBody3D
var riding: PlayerRidingController
var mount: RideableMount
var status_label: Label
var summon_marker: MeshInstance3D


func _ready() -> void:
	_build_environment()
	_build_course()
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		riding = player.get_node_or_null("RidingController") as PlayerRidingController
	_configure_player()
	_spawn_mount()
	_build_hud()
	_ensure_lab_inputs()
	GameState.set_objective("Mount the Courser, clear the fences, gallop the straightaway, then call it back.")


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("call_mount") and riding != null:
		riding.call_mount(mount)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dismiss_mount") and riding != null and not riding.is_riding():
		if mount.summon_state == "DISMISSED":
			riding.call_mount(mount)
		else:
			riding.dismiss_mount(mount)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_scene"):
		_reset_lab()
		get_viewport().set_input_as_handled()


func _configure_player() -> void:
	GameState.set_stat("max_health", 80)
	GameState.set_stat("health", 80)
	GameState.set_stat("max_stamina", 50)
	GameState.set_stat("stamina", 50)
	if player != null:
		var weapon := player.get_node_or_null("WeaponController") as WeaponController
		if weapon != null:
			weapon.show_debug_prints = false


func _spawn_mount() -> void:
	mount = RideableMount.new()
	mount.name = "FoundryCourser"
	mount.position = Vector3(2.4, 0.1, 8.0)
	add_child(mount)


func _reset_lab() -> void:
	if riding != null and riding.is_riding():
		riding.dismount()
	if mount != null:
		mount.restore_to_home()
	if player != null:
		player.global_position = Vector3(0, 1.1, 10.0)
		player.rotation = Vector3.ZERO
		player.velocity = Vector3.ZERO
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.016, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.28, 0.55)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.75
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color(1.0, 0.72, 0.4)
	sun.light_energy = 2.1
	sun.shadow_enabled = true
	add_child(sun)


func _build_course() -> void:
	_add_box_body("Ground", Vector3(24, 0.6, 70), Vector3(0, -0.3, -20), Color(0.13, 0.11, 0.16))
	_add_box_body("LeftRail", Vector3(0.5, 1.0, 66), Vector3(-11.5, 0.5, -20), Color(0.32, 0.18, 0.08))
	_add_box_body("RightRail", Vector3(0.5, 1.0, 66), Vector3(11.5, 0.5, -20), Color(0.32, 0.18, 0.08))
	for index: int in range(3):
		var z_position: float = 1.0 - float(index) * 7.0
		_add_box_body("Fence" + str(index + 1), Vector3(8.0, 0.35 + float(index) * 0.12, 0.35), Vector3(0, 0.72 + float(index) * 0.08, z_position), Color(0.82, 0.38, 0.08))
	for index: int in range(5):
		var x_position: float = -3.2 if index % 2 == 0 else 3.2
		_add_post(Vector3(x_position, 0.8, -19.0 - float(index) * 4.3), Color(0.28, 0.76, 1.0))
	_add_box_body("ImpactWall", Vector3(10, 3.0, 0.8), Vector3(0, 1.5, -51), Color(0.58, 0.12, 0.08))
	_build_summon_marker()
	_add_label("RIDEABLE MOUNTS LAB", Vector3(0, 5.8, 8), Color(1.0, 0.72, 0.28), 38)
	_add_label("INTERACT MOUNT/DISMOUNT  •  MOVE STEERS  •  HOLD GUARD GALLOPS  •  JUMP LEAPS  •  M CALLS  •  N DISMISSES  •  F8 RESET", Vector3(0, 5.0, 8), Color(0.92, 0.84, 1.0), 16)
	_add_label("JUMP LINE", Vector3(0, 3.1, -4.5), Color(1.0, 0.48, 0.12), 24)
	_add_label("SLALOM", Vector3(0, 3.1, -28), Color(0.34, 0.8, 1.0), 24)
	_add_label("IMPACT TEST", Vector3(0, 4.0, -49), Color(1.0, 0.25, 0.18), 24)


func _build_summon_marker() -> void:
	summon_marker = MeshInstance3D.new()
	summon_marker.position = Vector3(7, 0.08, -40)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.5
	mesh.bottom_radius = 1.5
	mesh.height = 0.08
	summon_marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.18, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.55, 0.2, 1.0)
	material.emission_energy_multiplier = 2.8
	summon_marker.material_override = material
	add_child(summon_marker)
	_add_label("SUMMON SPELL CONTRACT", Vector3(7, 2.0, -40), Color(0.76, 0.48, 1.0), 22)


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
	material.metallic = 0.25
	material.roughness = 0.68
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	return body


func _add_post(position: Vector3, color: Color) -> void:
	var post := MeshInstance3D.new()
	post.position = position
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.3
	mesh.height = 1.6
	post.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.55
	post.material_override = material
	add_child(post)


func _add_label(text: String, position: Vector3, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
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
	panel.custom_minimum_size = Vector2(610, 90)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.012, 0.04, 0.9)
	style.border_color = Color(0.84, 0.42, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.96, 0.88, 1.0))
	panel.add_child(status_label)


func _update_hud() -> void:
	if status_label == null or mount == null:
		return
	var data: Dictionary = mount.get_debug_data()
	status_label.text = (
		"MOUNT  •  " + str(data.get("gait", "IDLE"))
		+ "     SPEED " + str(data.get("speed", 0.0)) + " m/s"
		+ "     STAMINA " + str(data.get("stamina", 0.0)) + "/" + str(data.get("maximum_stamina", 0.0))
		+ "\nRIDER " + ("GRACE" if bool(data.get("rider", false)) else "NONE")
		+ "     SUMMON " + str(data.get("summon_state", "READY"))
		+ "     IMPACT " + str(data.get("impact", 0.0)) + " m/s"
	)


func _ensure_lab_inputs() -> void:
	_ensure_key_action("call_mount", KEY_M)
	_ensure_key_action("dismiss_mount", KEY_N)


func _ensure_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)
