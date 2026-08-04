extends Node3D
class_name AnimalBehaviorLab

const AnimalScript = preload("res://scripts/animals/generic_animal_actor.gd")

var player: Node3D
var animals: Array[GenericAnimalActor] = []
var selected_index: int = 0
var threat_mode: bool = false
var overlay_label: Label
var mode_label: Label
var forage_positions: Dictionary = {}
var water_position: Vector3 = Vector3(6.0, 0.15, -6.5)
var animal_start_positions: Dictionary = {}


func _ready() -> void:
	player = get_node_or_null("Player") as Node3D
	_build_environment()
	_build_lab()
	_build_overlay()
	_spawn_animals()
	_select_animal(0)
	_update_objective()


func _process(_delta: float) -> void:
	_update_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		_reset_lab()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_1:
			_select_animal(0)
		KEY_2:
			_select_animal(1)
		KEY_3:
			_select_animal(2)
		KEY_4:
			_select_animal(3)
		KEY_TAB:
			_select_animal((selected_index + 1) % animals.size())
		KEY_P:
			threat_mode = not threat_mode
			_show_message("Player threat mode: " + ("ON" if threat_mode else "OFF"))
			_force_all_decisions()
		KEY_H:
			_set_selected_drive("hunger", 1.0, "Hunger spiked")
		KEY_F:
			_set_selected_drive("fear", 1.0, "Fear spiked")
		KEY_J:
			_set_selected_drive("social_need", 1.0, "Social need spiked")
		KEY_K:
			_set_selected_drive("curiosity", 1.0, "Curiosity spiked")
		KEY_T:
			_set_selected_drive("territorial_pressure", 1.0, "Territorial pressure spiked")
		KEY_C:
			_clear_selected_drives()
		_:
			return
	get_viewport().set_input_as_handled()


func get_animal_threat_target(_animal: GenericAnimalActor) -> Node3D:
	return player


func is_animal_threat_mode_enabled(_animal: GenericAnimalActor) -> bool:
	return threat_mode


func get_animal_forage_position(animal: GenericAnimalActor) -> Vector3:
	return forage_positions.get(animal.species_id, animal.home_position) as Vector3


func get_animal_water_position(_animal: GenericAnimalActor) -> Vector3:
	return water_position


func clamp_animal_position(value: Vector3) -> Vector3:
	return Vector3(
		clampf(value.x, -13.0, 13.0),
		value.y,
		clampf(value.z, -12.5, 9.0)
	)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.055, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.62, 0.76)
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
	sun.light_color = Color(1.0, 0.83, 0.62)
	sun.light_energy = 1.75
	sun.shadow_enabled = true
	add_child(sun)


func _build_lab() -> void:
	_add_box("Ground", Vector3(28.0, 0.6, 24.0), Vector3(0.0, -0.3, -2.0), Color(0.12, 0.22, 0.16))
	_add_box("Pasture", Vector3(8.5, 0.08, 7.0), Vector3(-7.5, 0.04, -2.0), Color(0.27, 0.48, 0.18), false)
	_add_box("Pond", Vector3(8.0, 0.12, 6.0), water_position, Color(0.06, 0.36, 0.58), false)
	_add_box("WolfRidge", Vector3(8.0, 0.16, 5.5), Vector3(0.0, 0.08, -9.0), Color(0.2, 0.23, 0.27), false)
	forage_positions["sheep"] = Vector3(-7.0, 0.1, -2.0)
	forage_positions["capybara"] = Vector3(4.1, 0.1, -3.2)
	forage_positions["wolf"] = Vector3(0.0, 0.1, -8.5)
	_add_forage_patch(forage_positions["sheep"] as Vector3, Color(0.52, 0.76, 0.18))
	_add_forage_patch(forage_positions["capybara"] as Vector3, Color(0.42, 0.66, 0.16))
	_add_world_label("SHEEP PASTURE", Vector3(-7.5, 0.2, 2.0), Color(0.84, 0.95, 0.66))
	_add_world_label("CAPYBARA POND", Vector3(6.0, 0.28, -3.0), Color(0.5, 0.86, 1.0))
	_add_world_label("WOLF RIDGE", Vector3(0.0, 0.3, -11.1), Color(0.72, 0.78, 0.88))
	for x: float in [-13.5, 13.5]:
		_add_box("Boundary", Vector3(0.35, 2.0, 24.0), Vector3(x, 1.0, -2.0), Color(0.12, 0.14, 0.18), true)
	for z: float in [-13.8, 10.2]:
		_add_box("Boundary", Vector3(27.0, 2.0, 0.35), Vector3(0.0, 1.0, z), Color(0.12, 0.14, 0.18), true)


func _spawn_animals() -> void:
	animal_start_positions = {
		"Mallow": Vector3(-7.2, 0.4, -1.5),
		"Bramble": Vector3(4.3, 0.4, -3.0),
		"Ash": Vector3(-1.2, 0.4, -8.7),
		"Cinder": Vector3(1.2, 0.4, -8.7),
	}
	_spawn_animal("Mallow", "sheep", animal_start_positions["Mallow"] as Vector3, "cautious", 2.1)
	_spawn_animal("Bramble", "capybara", animal_start_positions["Bramble"] as Vector3, "balanced", 2.0)
	_spawn_animal("Ash", "wolf", animal_start_positions["Ash"] as Vector3, "balanced", 2.75)
	_spawn_animal("Cinder", "wolf", animal_start_positions["Cinder"] as Vector3, "bold", 2.9)


func _spawn_animal(
	name_value: String,
	species: String,
	position_value: Vector3,
	profile: String,
	speed: float
) -> void:
	var animal := AnimalScript.new() as GenericAnimalActor
	animal.animal_name = name_value
	animal.species_id = species
	animal.personality_profile_id = profile
	animal.move_speed = speed
	animal.position = position_value
	add_child(animal)
	animals.append(animal)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 84.0)
	panel.custom_minimum_size = Vector2(470.0, 0.0)
	canvas.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.06, 0.9)
	style.border_color = Color(0.28, 0.58, 0.86, 0.7)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "ANIMAL PERSONALITY LAB"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.5, 0.84, 1.0))
	box.add_child(title)
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 17)
	box.add_child(mode_label)
	overlay_label = Label.new()
	overlay_label.add_theme_font_size_override("font_size", 15)
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(overlay_label)
	var controls := Label.new()
	controls.text = "1-4 / Tab: select   P: threat mode\nH: hunger   F: fear   J: social   K: curiosity   T: territory\nC: clear selected drives   Restart input: reset lab"
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color(0.74, 0.78, 0.84))
	box.add_child(controls)


func _update_overlay() -> void:
	if mode_label == null or overlay_label == null:
		return
	mode_label.text = "PLAYER THREAT: " + ("ON" if threat_mode else "OFF")
	mode_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.34, 0.22) if threat_mode else Color(0.42, 1.0, 0.6)
	)
	var animal: GenericAnimalActor = _selected_animal()
	if animal == null:
		overlay_label.text = "No animal selected."
		return
	overlay_label.text = (
		"Selected: " + animal.animal_name + " the " + animal.species_id.capitalize()
		+ "\nIntention: " + animal.current_intention_id.capitalize()
		+ "   Move: " + animal.current_action_id.replace("_", " ").capitalize()
		+ "\nHunger " + _percent(animal.get_drive("hunger"))
		+ "   Fatigue " + _percent(animal.get_drive("fatigue"))
		+ "   Fear " + _percent(animal.get_drive("fear"))
		+ "\nSocial " + _percent(animal.get_drive("social_need"))
		+ "   Curiosity " + _percent(animal.get_drive("curiosity"))
		+ "   Territory " + _percent(animal.get_drive("territorial_pressure"))
	)


func _select_animal(index: int) -> void:
	if animals.is_empty():
		return
	selected_index = clampi(index, 0, animals.size() - 1)
	for animal_index: int in range(animals.size()):
		animals[animal_index].set_selected(animal_index == selected_index)
	var selected_animal: GenericAnimalActor = _selected_animal()
	if selected_animal != null:
		_show_message("Selected " + selected_animal.animal_name + " the " + selected_animal.species_id.capitalize())


func _selected_animal() -> GenericAnimalActor:
	if animals.is_empty() or selected_index < 0 or selected_index >= animals.size():
		return null
	return animals[selected_index]


func _set_selected_drive(drive_id: String, value: float, message: String) -> void:
	var animal: GenericAnimalActor = _selected_animal()
	if animal == null:
		return
	animal.set_drive(drive_id, value)
	_show_message(message + " for " + animal.animal_name)


func _clear_selected_drives() -> void:
	var animal: GenericAnimalActor = _selected_animal()
	if animal == null or animal.brain == null:
		return
	animal.brain.reset_drives({
		"hunger": 0.08,
		"fatigue": 0.08,
		"fear": 0.0,
		"social_need": 0.08,
		"curiosity": 0.18,
		"territorial_pressure": 0.0,
	})
	animal.brain.clear_memory()
	animal.force_decision()
	_show_message("Cleared drive pressure for " + animal.animal_name)


func _force_all_decisions() -> void:
	for animal: GenericAnimalActor in animals:
		if animal.brain != null:
			animal.brain.clear_memory()
		animal.force_decision()


func _reset_lab() -> void:
	threat_mode = false
	for animal: GenericAnimalActor in animals:
		animal.reset_actor()
	if player != null:
		player.global_position = Vector3(0.0, 1.1, 7.5)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	_select_animal(0)
	_show_message("Animal Behavior Lab reset")


func _update_objective() -> void:
	var objective: String = "Observe the animals, select one with 1-4, then alter its drives. Press P to make Grace a perceived threat."
	GameState.set_objective(objective)
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui != null and game_ui.has_method("set_objective"):
		game_ui.call("set_objective", objective)


func _add_box(
	body_name: String,
	size: Vector3,
	position_value: Vector3,
	color: Color,
	collision_enabled: bool = true
) -> Node3D:
	var root: Node3D
	if collision_enabled:
		var body := StaticBody3D.new()
		body.name = body_name
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		root = body
	else:
		root = Node3D.new()
		root.name = body_name
	root.position = position_value
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.emission_enabled = true
	material.emission = color.darkened(0.42)
	material.emission_energy_multiplier = 0.18
	visual.material_override = material
	root.add_child(visual)
	add_child(root)
	return root


func _add_forage_patch(position_value: Vector3, color: Color) -> void:
	for index: int in range(11):
		var blade := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.08, 0.55 + float(index % 3) * 0.12, 0.12)
		blade.mesh = mesh
		var angle: float = float(index) / 11.0 * TAU
		blade.position = position_value + Vector3(cos(angle), 0.3, sin(angle)) * (0.25 + float(index % 4) * 0.12)
		blade.rotation_degrees.y = rad_to_deg(angle)
		var material := StandardMaterial3D.new()
		material.albedo_color = color.lightened(float(index % 3) * 0.08)
		material.roughness = 0.9
		blade.material_override = material
		add_child(blade)


func _add_world_label(text_value: String, position_value: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.rotation_degrees.x = -90.0
	label.font_size = 28
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = color
	add_child(label)


func _show_message(message: String) -> void:
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui != null and game_ui.has_method("show_message"):
		game_ui.call("show_message", message)
	else:
		print(message)


func _percent(value: float) -> String:
	return str(int(round(clampf(value, 0.0, 1.0) * 100.0))) + "%"
