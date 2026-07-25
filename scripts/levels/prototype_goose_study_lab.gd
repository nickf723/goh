extends Node3D
class_name PrototypeGooseStudyLab

var player: CharacterBody3D
var status_label: Label
var unlock_label: Label
var geese: Array[ResearchableGoose] = []
var species_knowledge: Node


func _ready() -> void:
	species_knowledge = get_node_or_null("/root/SpeciesKnowledge")
	_build_environment()
	_build_wetland()
	player = get_node_or_null("Player") as CharacterBody3D
	_build_hud()
	if species_knowledge != null:
		if not species_knowledge.is_connected("discovery_recorded", _on_discovery):
			species_knowledge.connect("discovery_recorded", _on_discovery)
		if not species_knowledge.is_connected("unlock_earned", _on_unlock):
			species_knowledge.connect("unlock_earned", _on_unlock)
	GameState.set_objective("Study goose behavior with the contextual D-pad menu and unlock animal capabilities.")


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		if species_knowledge != null and species_knowledge.has_method("reset_species"):
			species_knowledge.call("reset_species", "goose")
		for goose: ResearchableGoose in geese:
			goose.reset_goose()
		if player != null:
			player.global_position = Vector3(0, 1.1, 9)
			player.velocity = Vector3.ZERO
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_G:
			var goose: ResearchableGoose = _nearest_goose()
			if goose != null:
				goose.perform_study_action("honk", player)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.1, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.68, 0.72)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.52
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color(1.0, 0.82, 0.56)
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	add_child(sun)


func _build_wetland() -> void:
	_add_box("Ground", Vector3(28, 0.6, 36), Vector3(0, -0.3, -6), Color(0.18, 0.3, 0.18))
	_add_box("Pond", Vector3(12, 0.12, 10), Vector3(0, 0.02, -10), Color(0.08, 0.42, 0.62))
	_add_box("ObservationBlind", Vector3(5, 2.2, 0.5), Vector3(0, 1.1, 3), Color(0.28, 0.18, 0.08))
	_spawn_goose("Forager", Vector3(-5, 0.1, -3), "CURIOUS")
	_spawn_goose("Sentinel", Vector3(5, 0.1, -4), "WARY")
	_spawn_goose("Pond Goose", Vector3(0, 0.18, -10), "CALM")
	_add_label("GOOSE FIELD STUDY", Vector3(0, 5.2, 7), Color(1.0, 0.82, 0.38), 38)
	_add_label("TAP D-PAD DOWN / TAB: CONTEXT ACTION  •  HOLD: COMMAND MENU  •  G: STUDY HONK  •  F8 RESET", Vector3(0, 4.4, 7), Color(0.88, 0.94, 1.0), 17)
	_add_label("OBSERVE MOVEMENT", Vector3(-5, 2.4, -3), Color(0.56, 0.9, 1.0), 22)
	_add_label("EARN TRUST", Vector3(5, 2.4, -4), Color(0.56, 1.0, 0.7), 22)
	_add_label("WETLAND BEHAVIOR", Vector3(0, 2.6, -10), Color(0.38, 0.76, 1.0), 22)


func _spawn_goose(goose_name: String, position: Vector3, temperament: String) -> void:
	var goose := ResearchableGoose.new()
	goose.goose_name = goose_name
	goose.temperament = temperament
	goose.position = position
	add_child(goose)
	geese.append(goose)


func _add_box(body_name: String, size: Vector3, position: Vector3, color: Color) -> StaticBody3D:
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
	material.roughness = 0.72
	material.metallic = 0.12
	material.emission_enabled = true
	material.emission = color.darkened(0.35)
	material.emission_energy_multiplier = 0.22
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	return body


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
	panel.custom_minimum_size = Vector2(650, 116)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.052, 0.92)
	style.border_color = Color(0.62, 0.88, 0.42, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.96, 0.82))
	box.add_child(status_label)
	unlock_label = Label.new()
	unlock_label.add_theme_font_size_override("font_size", 14)
	unlock_label.add_theme_color_override("font_color", Color(0.62, 0.86, 1.0))
	box.add_child(unlock_label)


func _update_hud() -> void:
	if status_label == null:
		return
	if species_knowledge == null or not species_knowledge.has_method("get_species_data"):
		status_label.text = "GOOSE KNOWLEDGE SERVICE UNAVAILABLE"
		return
	var data: Dictionary = species_knowledge.call("get_species_data", "goose")
	var discoveries: Dictionary = data.get("discoveries", {})
	status_label.text = (
		"GOOSE KNOWLEDGE  •  RANK " + str(data.get("rank", 0))
		+ "     POINTS " + str(data.get("points", 0)) + "/" + str(data.get("next_threshold", 0))
		+ "     DISCOVERIES " + str(discoveries.size())
	)
	var unlocks: Dictionary = data.get("unlocks", {})
	unlock_label.text = "CAPABILITIES  •  " + ("  •  ".join(unlocks.values()) if not unlocks.is_empty() else "None")


func _on_discovery(species_id: String, _discovery_id: String, label: String) -> void:
	if species_id == "goose":
		_show_message("New goose discovery: " + label)


func _on_unlock(species_id: String, _unlock_id: String, label: String) -> void:
	if species_id == "goose":
		_show_message("Goose capability unlocked: " + label)


func _nearest_goose() -> ResearchableGoose:
	if player == null:
		return null
	var best: ResearchableGoose
	var distance_best: float = INF
	for goose: ResearchableGoose in geese:
		var distance: float = player.global_position.distance_to(goose.global_position)
		if distance < 4.0 and distance < distance_best:
			best = goose
			distance_best = distance
	return best


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
