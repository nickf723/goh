extends Node3D
class_name PrototypeElementalAlchemyLab

const CauldronScript = preload("res://scripts/alchemy/alchemy_cauldron.gd")
const IngredientScript = preload("res://scripts/alchemy/alchemy_ingredient_pickup.gd")
const CatalystScript = preload("res://scripts/alchemy/alchemy_catalyst_station.gd")

const INGREDIENT_CONFIGS: Array[Dictionary] = [
	{"id": "life_bloom", "name": "Life Bloom", "element": "life / body", "color": Color(0.35, 0.95, 0.45), "position": Vector3(-9.0, 0.0, 4.0)},
	{"id": "springwater", "name": "Springwater", "element": "water", "color": Color(0.25, 0.72, 1.0), "position": Vector3(-5.0, 0.0, 7.0)},
	{"id": "echo_reed", "name": "Echo Reed", "element": "sound / air", "color": Color(0.8, 0.38, 1.0), "position": Vector3(0.0, 0.0, 8.0)},
	{"id": "frost_salt", "name": "Frost Salt", "element": "ice / poison", "color": Color(0.55, 0.93, 1.0), "position": Vector3(5.0, 0.0, 7.0)},
	{"id": "spark_ore", "name": "Spark Ore", "element": "metal / lightning", "color": Color(1.0, 0.78, 0.18), "position": Vector3(9.0, 0.0, 4.0)},
]

const CATALYST_CONFIGS: Array[Dictionary] = [
	{"element": "fire", "name": "Fire Heat", "color": Color(1.0, 0.25, 0.06), "position": Vector3(-8.0, 0.0, -6.0)},
	{"element": "air", "name": "Air Agitation", "color": Color(0.95, 0.55, 0.82), "position": Vector3(-4.0, 0.0, -9.0)},
	{"element": "ice", "name": "Ice Stabilization", "color": Color(0.42, 0.9, 1.0), "position": Vector3(0.0, 0.0, -10.0)},
	{"element": "water", "name": "Water Separation", "color": Color(0.18, 0.62, 1.0), "position": Vector3(4.0, 0.0, -9.0)},
	{"element": "lightning", "name": "Lightning Charge", "color": Color(1.0, 0.82, 0.18), "position": Vector3(8.0, 0.0, -6.0)},
]


func _ready() -> void:
	Engine.time_scale = 1.0
	build_environment()
	build_room()
	build_cauldron()
	build_ingredients()
	build_catalysts()
	configure_player_resources()
	GameState.set_objective("Gather ingredients, prepare an elemental treatment, and discover five potion recipes.")
	show_message("Alchemy Lab ready. Gather ingredients, apply a treatment, then interact with the cauldron.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene") and OS.has_feature("editor"):
		reset_alchemy_lab()
		get_viewport().set_input_as_handled()


func reset_alchemy_lab() -> void:
	for config: Dictionary in INGREDIENT_CONFIGS:
		GameState.set_inventory_count(str(config.get("id", "")), 0)
	for recipe_id: String in ["healing_potion", "resonance_tonic", "frost_vigor_draught", "antidote", "conductive_elixir"]:
		GameState.set_flag("recipe_discovered_" + recipe_id, false)
	for output_id: String in ["healing_potion", "resonance_tonic", "frost_vigor_draught", "antidote", "conductive_elixir"]:
		GameState.set_inventory_count(output_id, 0)
	get_tree().reload_current_scene()


func configure_player_resources() -> void:
	GameState.set_stat("max_health", maxi(GameState.get_stat("max_health"), 8))
	GameState.set_stat("health", 3)
	GameState.set_stat("max_mana", maxi(GameState.get_stat("max_mana"), 8))
	GameState.set_stat("mana", 2)
	GameState.set_stat("max_stamina", maxi(GameState.get_stat("max_stamina"), 8))
	GameState.set_stat("stamina", 2)
	GameState.set_stat("max_stance", maxi(GameState.get_stat("max_stance"), 8))
	GameState.set_stat("stance", 2)


func build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.055, 0.075)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.56, 0.66)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var skylight := DirectionalLight3D.new()
	skylight.rotation_degrees = Vector3(-58.0, -26.0, 0.0)
	skylight.light_color = Color(0.58, 0.76, 1.0)
	skylight.light_energy = 0.7
	skylight.shadow_enabled = true
	add_child(skylight)


func build_room() -> void:
	create_static_box("Floor", Vector3(0.0, -0.55, 0.0), Vector3(28.0, 1.0, 28.0), Color(0.11, 0.13, 0.16))
	create_static_box("BackWall", Vector3(0.0, 3.0, -14.0), Vector3(28.0, 6.0, 0.6), Color(0.08, 0.1, 0.13))
	create_static_box("LeftWall", Vector3(-14.0, 3.0, 0.0), Vector3(0.6, 6.0, 28.0), Color(0.08, 0.1, 0.13))
	create_static_box("RightWall", Vector3(14.0, 3.0, 0.0), Vector3(0.6, 6.0, 28.0), Color(0.08, 0.1, 0.13))
	for x: float in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		create_static_box("IngredientTable" + str(x), Vector3(x, 0.45, 10.0), Vector3(3.0, 0.9, 1.2), Color(0.26, 0.14, 0.07))
	var title := make_label("ELEMENTAL APOTHECARY", Vector3(0.0, 6.2, -13.6), Color(0.62, 0.9, 1.0), 48)
	add_child(title)
	var recipe_hint := make_label(
		"PAIR TRAITS • APPLY TREATMENT • BREW\nFailures consume ingredients; full potion stacks do not.",
		Vector3(0.0, 4.2, -13.55), Color(0.78, 0.82, 0.88), 25
	)
	add_child(recipe_hint)


func build_cauldron() -> void:
	var cauldron := Area3D.new()
	cauldron.name = "ElementalCauldron"
	cauldron.position = Vector3(0.0, 0.0, -2.0)
	cauldron.set_script(CauldronScript)
	add_child(cauldron)


func build_ingredients() -> void:
	for config: Dictionary in INGREDIENT_CONFIGS:
		var pickup := Area3D.new()
		pickup.name = str(config.get("name", "Ingredient")).replace(" ", "")
		pickup.position = config.get("position", Vector3.ZERO) as Vector3
		pickup.set_script(IngredientScript)
		pickup.set("ingredient_id", str(config.get("id", "")))
		pickup.set("display_name", str(config.get("name", "Ingredient")))
		pickup.set("element", str(config.get("element", "neutral")))
		pickup.set("ingredient_color", config.get("color", Color.WHITE))
		pickup.set("amount", 3)
		pickup.set("prompt_text", "Gather " + str(config.get("name", "ingredient")))
		add_child(pickup)


func build_catalysts() -> void:
	for config: Dictionary in CATALYST_CONFIGS:
		var station := Area3D.new()
		station.name = str(config.get("name", "Treatment")).replace(" ", "")
		station.position = config.get("position", Vector3.ZERO) as Vector3
		station.set_script(CatalystScript)
		station.set("element", str(config.get("element", "fire")))
		station.set("display_name", str(config.get("name", "Treatment")))
		station.set("station_color", config.get("color", Color.WHITE))
		station.set("prompt_text", "Apply " + str(config.get("name", "treatment")))
		add_child(station)


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
	material.roughness = 0.68
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
