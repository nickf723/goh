extends Node3D
class_name AnimalBehaviorLab

const AnimalScript = preload("res://scripts/animals/generic_animal_actor.gd")

var player: Node3D
var animals: Array[GenericAnimalActor] = []
var selected_index: int = 0
var grace_threatening: bool = false
var overlay_label: Label
var mode_label: Label
var posture_toggle: CheckButton
var forage_positions: Dictionary = {}
var water_position: Vector3 = Vector3(6.0, 0.72, -6.5)
var pond_surface_y: float = 1.35
var pond_volume: SwimmingWaterVolume
var animal_start_positions: Dictionary = {}
var noise_position: Vector3 = Vector3.ZERO
var noise_strength: float = 0.0
var noise_time_remaining: float = 0.0


func _ready() -> void:
	player = get_node_or_null("Player") as Node3D
	_build_environment()
	_build_lab()
	_spawn_animals()
	_build_overlay()
	_select_animal(0)
	_update_objective()


func _process(delta: float) -> void:
	noise_time_remaining = maxf(noise_time_remaining - delta, 0.0)
	if noise_time_remaining <= 0.0:
		noise_strength = 0.0
	_update_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		_reset_lab()
		get_viewport().set_input_as_handled()


func get_animal_grace_target(_animal: GenericAnimalActor) -> Node3D:
	return player


func get_animal_threat_target(_animal: GenericAnimalActor) -> Node3D:
	return player


func is_grace_threatening(_animal: GenericAnimalActor) -> bool:
	return grace_threatening


func is_animal_threat_mode_enabled(_animal: GenericAnimalActor) -> bool:
	return grace_threatening


func get_animal_noise_position(_animal: GenericAnimalActor) -> Vector3:
	return noise_position


func get_animal_noise_strength(_animal: GenericAnimalActor) -> float:
	return noise_strength if noise_time_remaining > 0.0 else 0.0


func get_animal_forage_position(animal: GenericAnimalActor) -> Vector3:
	return forage_positions.get(animal.species_id, animal.home_position) as Vector3


func get_animal_water_position(_animal: GenericAnimalActor) -> Vector3:
	return water_position


func broadcast_animal_alert(
	source: GenericAnimalActor,
	position_value: Vector3,
	severity: float
) -> void:
	for animal: GenericAnimalActor in animals:
		if animal == source or animal.species_id != source.species_id:
			continue
		if animal.global_position.distance_to(source.global_position) > 15.0:
			continue
		animal.receive_social_alert(position_value, severity)


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
	_build_water_habitat()
	_add_box("WolfRidge", Vector3(8.0, 0.16, 5.5), Vector3(0.0, 0.08, -9.0), Color(0.2, 0.23, 0.27), false)
	forage_positions["sheep"] = Vector3(-7.0, 0.1, -2.0)
	forage_positions["capybara"] = Vector3(4.1, 0.1, -3.2)
	forage_positions["wolf"] = Vector3(0.0, 0.1, -8.5)
	_add_forage_patch(forage_positions["sheep"] as Vector3, Color(0.52, 0.76, 0.18))
	_add_forage_patch(forage_positions["capybara"] as Vector3, Color(0.42, 0.66, 0.16))
	_add_world_label("SHEEP PASTURE", Vector3(-7.5, 0.2, 2.0), Color(0.84, 0.95, 0.66))
	_add_world_label(
		"SHARED WATER HABITAT",
		Vector3(6.0, 1.58, -3.0),
		Color(0.5, 0.86, 1.0)
	)
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
		"Juniper": Vector3(8.0, 4.0, -8.0),
		"Ripple": Vector3(6.0, 0.72, -6.5),
	}
	_spawn_animal("Mallow", "sheep", animal_start_positions["Mallow"] as Vector3, "cautious", 2.1)
	_spawn_animal("Bramble", "capybara", animal_start_positions["Bramble"] as Vector3, "balanced", 2.0)
	_spawn_animal("Ash", "wolf", animal_start_positions["Ash"] as Vector3, "balanced", 2.75)
	_spawn_animal("Cinder", "wolf", animal_start_positions["Cinder"] as Vector3, "bold", 2.9)
	_spawn_animal(
		"Juniper",
		"goose",
		animal_start_positions["Juniper"] as Vector3,
		"bold",
		2.45,
		"flight"
	)
	_spawn_animal(
		"Ripple",
		"trout",
		animal_start_positions["Ripple"] as Vector3,
		"cautious",
		1.9,
		"swimmer"
	)


func _spawn_animal(
	name_value: String,
	species: String,
	position_value: Vector3,
	profile: String,
	speed: float,
	initial_mode: String = ""
) -> void:
	var animal := AnimalScript.new() as GenericAnimalActor
	animal.animal_name = name_value
	animal.species_id = species
	animal.personality_profile_id = profile
	animal.move_speed = speed
	animal.initial_locomotion_mode = initial_mode
	animal.position = position_value
	add_child(animal)
	animals.append(animal)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 78.0)
	panel.custom_minimum_size = Vector2(510.0, 0.0)
	canvas.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.06, 0.93)
	style.border_color = Color(0.28, 0.58, 0.86, 0.75)
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
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title := Label.new()
	title.text = "ANIMAL PERCEPTION + RELATIONSHIP LAB"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.5, 0.84, 1.0))
	box.add_child(title)
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 16)
	box.add_child(mode_label)
	overlay_label = Label.new()
	overlay_label.add_theme_font_size_override("font_size", 14)
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(overlay_label)

	var selection_row := HBoxContainer.new()
	box.add_child(selection_row)
	_add_button(selection_row, "◀ Previous", Callable(self, "_select_relative").bind(-1))
	_add_button(selection_row, "Next ▶", Callable(self, "_select_relative").bind(1))

	var locomotion_label := Label.new()
	locomotion_label.text = "Locomotion habitat"
	locomotion_label.add_theme_color_override(
		"font_color",
		Color(0.58, 0.9, 1.0)
	)
	box.add_child(locomotion_label)
	var locomotion_grid := GridContainer.new()
	locomotion_grid.columns = 3
	box.add_child(locomotion_grid)
	_add_button(
		locomotion_grid,
		"Place in Pond",
		Callable(self, "_place_selected_in_pond")
	)
	_add_button(
		locomotion_grid,
		"Launch / Land Goose",
		Callable(self, "_toggle_goose_flight")
	)
	_add_button(
		locomotion_grid,
		"Return Selected",
		Callable(self, "_return_selected_home")
	)

	posture_toggle = CheckButton.new()
	posture_toggle.text = "Grace threatening posture"
	posture_toggle.focus_mode = Control.FOCUS_ALL
	posture_toggle.toggled.connect(_on_posture_toggled)
	box.add_child(posture_toggle)

	var social_label := Label.new()
	social_label.text = "Grace interactions"
	social_label.add_theme_color_override("font_color", Color(0.76, 0.88, 1.0))
	box.add_child(social_label)
	var interaction_grid := GridContainer.new()
	interaction_grid.columns = 4
	box.add_child(interaction_grid)
	_add_button(interaction_grid, "Feed", Callable(self, "_interact_selected").bind("feed"))
	_add_button(interaction_grid, "Soothe", Callable(self, "_interact_selected").bind("soothe"))
	_add_button(interaction_grid, "Startle", Callable(self, "_interact_selected").bind("startle"))
	_add_button(interaction_grid, "Make Noise", Callable(self, "_emit_noise"))

	var drive_label := Label.new()
	drive_label.text = "Debug pressure"
	drive_label.add_theme_color_override("font_color", Color(0.76, 0.88, 1.0))
	box.add_child(drive_label)
	var drive_grid := GridContainer.new()
	drive_grid.columns = 4
	box.add_child(drive_grid)
	_add_button(drive_grid, "Hungry", Callable(self, "_set_selected_drive").bind("hunger", 1.0, "Hunger spiked"))
	_add_button(drive_grid, "Afraid", Callable(self, "_set_selected_drive").bind("fear", 1.0, "Fear spiked"))
	_add_button(drive_grid, "Lonely", Callable(self, "_set_selected_drive").bind("social_need", 1.0, "Social need spiked"))
	_add_button(drive_grid, "Curious", Callable(self, "_set_selected_drive").bind("curiosity", 1.0, "Curiosity spiked"))
	_add_button(drive_grid, "Territorial", Callable(self, "_set_selected_drive").bind("territorial_pressure", 1.0, "Territorial pressure spiked"))
	_add_button(drive_grid, "Clear Drives", Callable(self, "_clear_selected_drives"))
	_add_button(drive_grid, "Reset Lab", Callable(self, "_reset_lab"))

	var hint := Label.new()
	hint.text = "Buttons are mouse-clickable and controller-focusable. Release the mouse with your normal cursor/menu control when needed."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.66, 0.72, 0.8))
	box.add_child(hint)


func _add_button(parent: Control, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(112.0, 34.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _update_overlay() -> void:
	if mode_label == null or overlay_label == null:
		return
	mode_label.text = "GRACE POSTURE: " + ("THREATENING" if grace_threatening else "PEACEFUL")
	mode_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.34, 0.22) if grace_threatening else Color(0.42, 1.0, 0.6)
	)
	var animal: GenericAnimalActor = _selected_animal()
	if animal == null:
		overlay_label.text = "No animal selected."
		return
	var perception_data: Dictionary = animal.get_perception_data()
	var relationship_data: Dictionary = animal.get_relationship_data()
	overlay_label.text = (
		"Selected: " + animal.animal_name + " the " + animal.species_id.capitalize()
		+ "\nRelationship: " + animal.get_relationship_label().capitalize()
		+ "   Trust " + _signed_percent(float(relationship_data.get("trust", 0.0)))
		+ "   Familiarity " + _percent(float(relationship_data.get("familiarity", 0.0)))
		+ "\nSense: " + str(perception_data.get("stimulus_kind", "none")).replace("_", " ").capitalize()
		+ "   Awareness " + _percent(float(perception_data.get("awareness", 0.0)))
		+ "   Memory " + str(snappedf(float(perception_data.get("memory_remaining", 0.0)), 0.1)) + "s"
		+ "\nIntention: " + animal.current_intention_id.capitalize()
		+ "   Action: " + animal.current_action_id.replace("_", " ").capitalize()
		+ "\nMode: " + animal.get_active_locomotion_mode().capitalize()
		+ "   Height " + str(snappedf(animal.global_position.y, 0.1))
		+ "\nHunger " + _percent(animal.get_drive("hunger"))
		+ "   Fatigue " + _percent(animal.get_drive("fatigue"))
		+ "   Fear " + _percent(animal.get_drive("fear"))
		+ "\nSocial " + _percent(animal.get_drive("social_need"))
		+ "   Curiosity " + _percent(animal.get_drive("curiosity"))
		+ "   Territory " + _percent(animal.get_drive("territorial_pressure"))
	)


func _select_relative(offset: int) -> void:
	if animals.is_empty():
		return
	_select_animal(posmod(selected_index + offset, animals.size()))


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


func _place_selected_in_pond() -> void:
	var animal: GenericAnimalActor = _selected_animal()
	if animal == null or pond_volume == null:
		return
	if animal.locomotion == null or not animal.locomotion.supports_mode(
		"swimmer"
	):
		_show_message(
			animal.animal_name + " has no validated swimming mode."
		)
		return
	animal.global_position = water_position + Vector3(
		randf_range(-1.2, 1.2),
		0.0,
		randf_range(-1.0, 1.0)
	)
	animal.velocity = Vector3.ZERO
	animal.locomotion.enter_water(pond_volume)
	animal.decision_time_remaining = 0.0
	_show_message(
		animal.animal_name
		+ " entered the pond in "
		+ animal.get_active_locomotion_mode().capitalize()
		+ " mode."
	)


func _toggle_goose_flight() -> void:
	var goose: GenericAnimalActor = _find_species_animal("goose")
	if goose == null or goose.locomotion == null:
		_show_message("No generic Goose actor is available.")
		return
	var next_mode: String = (
		"ground"
		if goose.get_active_locomotion_mode() == "flight"
		else "flight"
	)
	var medium_tags: Array[String] = (
		["land"]
		if next_mode == "ground"
		else ["air"]
	)
	var result: Dictionary = goose.request_locomotion_mode(
		next_mode,
		{
			"medium_tags": medium_tags,
			"reason": "animal_lab_control",
		}
	)
	if not bool(result.get("ok", false)):
		_show_message(
			"Goose locomotion rejected: "
			+ str(result.get("error", "unknown transition"))
		)
		return
	if next_mode == "flight":
		goose.global_position.y = maxf(
			goose.global_position.y,
			pond_surface_y + 0.45
		)
		goose.wander_time_remaining = 0.0
	goose.velocity = Vector3.ZERO
	_select_animal(animals.find(goose))
	_show_message(
		goose.animal_name
		+ (" launched into flight." if next_mode == "flight" else " is landing under gravity.")
	)


func _return_selected_home() -> void:
	var animal: GenericAnimalActor = _selected_animal()
	if animal == null:
		return
	animal.reset_actor()
	_register_initial_water_medium(animal)
	_show_message(animal.animal_name + " returned to its authored start.")


func _find_species_animal(
	requested_species_id: String
) -> GenericAnimalActor:
	for animal: GenericAnimalActor in animals:
		if animal.species_id == requested_species_id:
			return animal
	return null


func _on_posture_toggled(value: bool) -> void:
	grace_threatening = value
	_show_message("Grace posture: " + ("threatening" if value else "peaceful"))
	_force_all_decisions()


func _interact_selected(interaction_id: String) -> void:
	var animal: GenericAnimalActor = _selected_animal()
	if animal == null:
		return
	var result: Dictionary = animal.interact_with_grace(interaction_id)
	if bool(result.get("ok", false)):
		_show_message(
			interaction_id.capitalize() + " changed " + animal.animal_name
			+ " to " + animal.get_relationship_label().capitalize()
		)
	else:
		_show_message(
			"Move closer to " + animal.animal_name + " before using "
			+ interaction_id.capitalize() + "."
		)


func _emit_noise() -> void:
	noise_position = player.global_position if player != null else Vector3.ZERO
	noise_strength = 1.45
	noise_time_remaining = 0.8
	_show_message("Grace made a loud disturbance")
	_force_all_decisions()


func _set_selected_drive(drive_id: String, value: float, message: String) -> void:
	var animal: GenericAnimalActor = _selected_animal()
	if animal == null:
		return
	animal.set_drive(drive_id, value)
	animal.force_decision()
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
	grace_threatening = false
	noise_strength = 0.0
	noise_time_remaining = 0.0
	if posture_toggle != null:
		posture_toggle.set_pressed_no_signal(false)
	for animal: GenericAnimalActor in animals:
		animal.reset_actor()
		_register_initial_water_medium(animal)
	if player != null:
		player.global_position = Vector3(0.0, 1.1, 7.5)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	_select_animal(0)
	_show_message("Animal Perception and Relationship Lab reset")


func _update_objective() -> void:
	var objective: String = "Compare ground, swimming, and flight animals; use the habitat controls, then test moves, threat, trust, bonding, and reset."
	GameState.set_objective(objective)
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui != null and game_ui.has_method("set_objective"):
		game_ui.call("set_objective", objective)


func _build_water_habitat() -> void:
	pond_volume = SwimmingWaterVolume.new()
	pond_volume.name = "SharedAnimalPond"
	pond_volume.position = Vector3(
		water_position.x,
		pond_surface_y * 0.5,
		water_position.z
	)
	pond_volume.surface_height_offset = pond_surface_y * 0.5
	pond_volume.current_velocity = Vector3(-0.18, 0.0, 0.06)
	pond_volume.swirl_strength = 0.12
	pond_volume.inward_strength = 0.08

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, pond_surface_y, 6.0)
	collision.shape = shape
	pond_volume.add_child(collision)

	var water := MeshInstance3D.new()
	var water_mesh := BoxMesh.new()
	water_mesh.size = shape.size
	water.mesh = water_mesh
	var water_material := StandardMaterial3D.new()
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.albedo_color = Color(0.05, 0.42, 0.64, 0.48)
	water_material.roughness = 0.22
	water_material.metallic = 0.08
	water_material.emission_enabled = true
	water_material.emission = Color(0.02, 0.2, 0.34)
	water_material.emission_energy_multiplier = 0.32
	water.material_override = water_material
	pond_volume.add_child(water)
	add_child(pond_volume)

	var bank_color := Color(0.18, 0.24, 0.2)
	_add_box(
		"PondBankLeft",
		Vector3(0.35, 1.35, 6.4),
		Vector3(1.85, 0.68, -6.5),
		bank_color
	)
	_add_box(
		"PondBankRight",
		Vector3(0.35, 1.35, 6.4),
		Vector3(10.15, 0.68, -6.5),
		bank_color
	)
	_add_box(
		"PondBankRear",
		Vector3(8.65, 1.35, 0.35),
		Vector3(6.0, 0.68, -9.65),
		bank_color
	)
	for side: float in [-1.0, 1.0]:
		_add_box(
			"PondBankFront",
			Vector3(2.1, 0.55, 0.35),
			Vector3(6.0 + side * 3.0, 0.28, -3.35),
			bank_color
		)


func _register_initial_water_medium(
	animal: GenericAnimalActor
) -> void:
	if (
		pond_volume == null
		or animal == null
		or animal.locomotion == null
		or not animal.locomotion.supports_mode("swimmer")
	):
		return
	if (
		pond_volume.contains_horizontal_position(
			animal.global_position
		)
		and animal.global_position.y <= pond_surface_y
	):
		animal.locomotion.enter_water(pond_volume)


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


func _signed_percent(value: float) -> String:
	var amount: int = int(round(clampf(value, -1.0, 1.0) * 100.0))
	return ("+" if amount >= 0 else "") + str(amount) + "%"
