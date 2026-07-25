extends "res://scripts/levels/prototype_large_enemy_lab.gd"
class_name PrototypeStonebackSalamanderLab


func _ready() -> void:
	super._ready()
	GameState.set_objective("Soak the Stoneback, conduct Lightning, topple it, and climb to the heat organ.")


func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "StonebackEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.055, 0.06, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.28, 0.52, 0.44, 1.0)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.58
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.20, 0.38, 0.34, 1.0)
	environment.fog_density = 0.012
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "CanopySun"
	sun.rotation_degrees = Vector3(-54, -32, 0)
	sun.light_color = Color(0.72, 1.0, 0.78, 1.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)

	for data: Dictionary in [
		{"position": Vector3(-10, 3, -5), "color": Color(0.18, 0.65, 1.0), "energy": 4.0},
		{"position": Vector3(10, 3, -2), "color": Color(1.0, 0.32, 0.08), "energy": 3.2},
	]:
		var light := OmniLight3D.new()
		light.position = data["position"]
		light.light_color = data["color"]
		light.light_energy = data["energy"]
		light.omni_range = 13.0
		add_child(light)


func _build_arena() -> void:
	var floor := StaticBody3D.new()
	floor.name = "StonebackBasin"
	var floor_collision := CollisionShape3D.new()
	var floor_shape := CylinderShape3D.new()
	floor_shape.radius = 22.0
	floor_shape.height = 1.0
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.5
	floor.add_child(floor_collision)
	var floor_mesh := MeshInstance3D.new()
	var floor_cylinder := CylinderMesh.new()
	floor_cylinder.top_radius = 22.0
	floor_cylinder.bottom_radius = 22.0
	floor_cylinder.height = 1.0
	floor_mesh.mesh = floor_cylinder
	floor_mesh.position.y = -0.5
	floor_mesh.material_override = _make_material(Color(0.12, 0.20, 0.14), 0.0, 0.92)
	floor.add_child(floor_mesh)
	add_child(floor)

	for index: int in range(13):
		var angle: float = TAU * float(index) / 13.0
		var radius: float = 16.5 + float(index % 3)
		var stone := StaticBody3D.new()
		stone.name = "BasinStone" + str(index + 1)
		stone.position = Vector3(cos(angle) * radius, 1.2, sin(angle) * radius)
		stone.rotation_degrees.y = rad_to_deg(-angle)
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.2 + float(index % 2), 2.4 + float(index % 3), 1.8)
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _make_material(Color(0.23, 0.26, 0.20), 0.02, 0.96)
		stone.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		stone.add_child(collision)
		add_child(stone)

	_add_pool(Vector3(-10, 0.03, -5), Color(0.10, 0.48, 0.82, 0.72), "WATER → WET")
	_add_pool(Vector3(10, 0.03, -2), Color(1.0, 0.22, 0.05, 0.60), "FIRE → OVERHEAT")

	var title := Label3D.new()
	title.text = "STONEBACK SALAMANDER • LIVING TITAN"
	title.position = Vector3(0, 8.6, -16.0)
	title.font_size = 34
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 8
	title.modulate = Color(0.64, 1.0, 0.72)
	add_child(title)

	var instructions := Label3D.new()
	instructions.text = "WATER + LIGHTNING   •   FIRE + ICE   •   BREAK PLATE → HEAT ORGAN   •   TOPPLE → CLIMB MOVING BACK"
	instructions.position = Vector3(0, 7.65, -15.8)
	instructions.font_size = 20
	instructions.pixel_size = 0.008
	instructions.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	instructions.outline_size = 6
	instructions.modulate = Color(0.84, 0.94, 0.86)
	add_child(instructions)


func _add_pool(position_value: Vector3, color: Color, label_text: String) -> void:
	var pool := MeshInstance3D.new()
	pool.position = position_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = 3.2
	mesh.bottom_radius = 3.2
	mesh.height = 0.08
	pool.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 0.7
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.2
	pool.material_override = material
	add_child(pool)
	var label := Label3D.new()
	label.text = label_text
	label.position = position_value + Vector3.UP * 0.45
	label.font_size = 22
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = Color(color.r, color.g, color.b, 1.0)
	add_child(label)


func _update_hud() -> void:
	if status_label == null or construct == null:
		return
	var debug: Dictionary = construct.get_debug_data()
	var target_text: String = "BODY"
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		var target_value: Variant = player.get("lock_on_target")
		if target_value is Node:
			target_text = (target_value as Node).name.to_snake_case().to_upper()
	status_label.text = (
		"STONEBACK SALAMANDER  •  " + str(debug.get("state", "UNKNOWN"))
		+ "\nHEALTH " + str(debug.get("health", 0)) + " / " + str(debug.get("maximum_health", 0))
		+ "     STANCE " + str(debug.get("stance", 0)) + " / " + str(debug.get("maximum_stance", 0))
		+ "\nTARGET " + target_text
		+ "     PLATES " + ("BROKEN" if bool(debug.get("shell_open", false)) else "ARMORED")
		+ "     HORN " + ("INTACT" if bool(debug.get("horn_intact", true)) else "BROKEN")
		+ "\nWET " + ("YES " + str(debug.get("wet_time", 0.0)) + "s" if bool(debug.get("wet", false)) else "NO")
		+ "     OVERHEATED " + ("YES " + str(debug.get("overheat_time", 0.0)) + "s" if bool(debug.get("overheated", false)) else "NO")
		+ "\nTRAVERSAL " + (traversal_controller.get_state_name() if traversal_controller != null else "OFFLINE")
		+ "     STAMINA " + str(GameState.get_stat("stamina")) + " / " + str(GameState.get_stat("max_stamina"))
		+ "\n" + (traversal_controller.get_status_text() if traversal_controller != null else "")
	)
