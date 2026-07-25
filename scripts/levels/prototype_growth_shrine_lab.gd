extends Node3D
class_name PrototypeGrowthShrineLab

const RewardScript = preload("res://scripts/progression/experience_reward_station.gd")
const ShrineScript = preload("res://scripts/progression/growth_shrine.gd")

const REWARD_CONFIGS: Array[Dictionary] = [
	{"name": "Exploration Discovery", "category": "exploration", "xp": 15, "color": Color(0.3, 0.78, 1.0), "position": Vector3(-8.0, 0.0, 5.0)},
	{"name": "Combat Victory", "category": "combat", "xp": 25, "color": Color(1.0, 0.32, 0.22), "position": Vector3(-3.0, 0.0, 7.5)},
	{"name": "Alchemy Discovery", "category": "crafting", "xp": 35, "color": Color(0.72, 0.35, 1.0), "position": Vector3(3.0, 0.0, 7.5)},
	{"name": "Quest Completion", "category": "quest", "xp": 50, "color": Color(1.0, 0.78, 0.22), "position": Vector3(8.0, 0.0, 5.0)},
]


func _ready() -> void:
	Engine.time_scale = 1.0
	build_environment()
	build_garden()
	build_reward_stations()
	build_shrine()
	configure_progression_trial()
	GameState.set_objective("Earn Experience, level up, and spend Growth Points at the shrine.")
	show_message("Growth Lab ready. Each activity beacon grants a different XP reward.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene") and OS.has_feature("editor"):
		reset_growth_lab()
		get_viewport().set_input_as_handled()


func configure_progression_trial() -> void:
	GameState.set_stat("level", 1)
	GameState.set_progression(0, 0)
	for resource_id: String in ["health", "stamina", "mana", "stance"]:
		GameState.set_stat("max_" + resource_id, 5)
		GameState.set_stat(resource_id, 2)
	GameState.set_stat("focus", 5)
	GameState.set_stat("charisma", 1)


func reset_growth_lab() -> void:
	configure_progression_trial()
	get_tree().reload_current_scene()


func build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.075, 0.065)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.68, 0.55)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.62)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func build_garden() -> void:
	create_static_box("GardenFloor", Vector3(0.0, -0.55, 0.0), Vector3(28.0, 1.0, 28.0), Color(0.13, 0.28, 0.16))
	create_static_box("BackCliff", Vector3(0.0, 2.5, -14.0), Vector3(28.0, 5.0, 0.7), Color(0.11, 0.16, 0.13))
	create_static_box("LeftCliff", Vector3(-14.0, 2.5, 0.0), Vector3(0.7, 5.0, 28.0), Color(0.11, 0.16, 0.13))
	create_static_box("RightCliff", Vector3(14.0, 2.5, 0.0), Vector3(0.7, 5.0, 28.0), Color(0.11, 0.16, 0.13))
	for x: float in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		var stone_color := Color(0.2, 0.3, 0.23) if x != 0.0 else Color(0.24, 0.36, 0.27)
		create_static_box("GardenStep" + str(x), Vector3(x, 0.12, -6.0), Vector3(3.2, 0.24, 2.4), stone_color)
	var title := make_label("GROWTH SANCTUARY", Vector3(0.0, 5.6, -13.55), Color(0.58, 1.0, 0.72), 47)
	add_child(title)
	var hint := make_label("EXPERIENCE BECOMES CHOICE", Vector3(0.0, 4.42, -13.5), Color(1.0, 0.82, 0.36), 27)
	add_child(hint)


func build_reward_stations() -> void:
	for config: Dictionary in REWARD_CONFIGS:
		var station := Area3D.new()
		station.name = str(config.get("name", "Reward")).replace(" ", "")
		station.position = config.get("position", Vector3.ZERO) as Vector3
		station.set_script(RewardScript)
		station.set("reward_name", str(config.get("name", "Activity")))
		station.set("reward_category", str(config.get("category", "activity")))
		station.set("experience_amount", int(config.get("xp", 20)))
		station.set("station_color", config.get("color", Color.WHITE))
		station.set("repeatable", true)
		station.set("prompt_text", "Claim " + str(config.get("name", "Experience")))
		add_child(station)


func build_shrine() -> void:
	var shrine := Area3D.new()
	shrine.name = "GrowthShrine"
	shrine.position = Vector3(0.0, 0.0, -8.0)
	shrine.set_script(ShrineScript)
	add_child(shrine)


func create_static_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_material(color)
	body.add_child(mesh_instance)
	add_child(body)
	return body


func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	return material


func make_label(text: String, position: Vector3, color: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
