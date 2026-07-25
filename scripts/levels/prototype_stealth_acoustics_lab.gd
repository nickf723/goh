extends Node3D
class_name PrototypeStealthAcousticsLab

const StimulusManagerScript = preload("res://scripts/perception/perception_stimulus_manager.gd")
const PerceptionSensorScript = preload("res://scripts/perception/enemy_perception_sensor.gd")
const PerceptionBrainScript = preload("res://scripts/enemies/enemy_perception_investigation_brain.gd")
const PerceptionDebugScript = preload("res://scripts/perception/perception_debug_visualizer.gd")
const NoiseBeaconScript = preload("res://scripts/perception/perception_noise_beacon.gd")
const StealthObjectiveScript = preload("res://scripts/stealth/stealth_objective.gd")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")
const EcholocationLoadout: AbilityLoadout = preload("res://data/loadouts/grace_echolocation_room_loadout.tres")

var manager: PerceptionStimulusManager
var enemies: Array[CharacterBody3D] = []
var readout: Label3D
var initial_player_transform: Transform3D
var reset_count: int = 0


func _ready() -> void:
	Engine.time_scale = 1.0
	build_environment()
	build_manager()
	build_encampment()
	configure_player()
	GameState.set_objective("Steal the patrol plans using concealment, quiet movement, or a distraction.")
	show_message("Moonlit Encampment ready. L3 / Ctrl crouches; Echolocation reveals the camp but loudly reveals Grace.")
	update_readout()


func _process(_delta: float) -> void:
	update_readout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene") and OS.has_feature("editor"):
		GameState.set_flag("stealth_lab_plans_stolen", false)
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event := event as InputEventKey
		if key_event.physical_keycode == KEY_V:
			for visualizer: Node in get_tree().get_nodes_in_group("perception_debug_visualizers"):
				visualizer.visible = not visualizer.visible
			get_viewport().set_input_as_handled()


func build_manager() -> void:
	manager = StimulusManagerScript.new() as PerceptionStimulusManager
	manager.name = "PerceptionStimulusManager"
	add_child(manager)


func configure_player() -> void:
	var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	initial_player_transform = player.transform
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster != null:
		caster.set("loadout", EcholocationLoadout.duplicate(true))
		caster.set("current_ability_index", 0)
		if caster.has_method("align_focus_menu_to_current_ability"):
			caster.call("align_focus_menu_to_current_ability")
		if caster.has_method("emit_current_ability"):
			caster.call("emit_current_ability")
	GameState.set_stat("max_mana", 12)
	GameState.set_stat("mana", 12)
	GameState.player_invulnerable = true
	GameState.player_invulnerability_timer = INF


func build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.028, 0.065)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.18, 0.24, 0.42)
	environment.ambient_light_energy = 0.46
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.08, 0.12, 0.22)
	environment.fog_density = 0.012
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55.0, 28.0, 0.0)
	moon.light_color = Color(0.48, 0.62, 1.0)
	moon.light_energy = 0.72
	moon.shadow_enabled = true
	add_child(moon)


func build_encampment() -> void:
	create_surface("Ground", Vector3(0.0, -0.55, 0.0), Vector3(34.0, 1.0, 42.0), Color(0.06, 0.09, 0.08), "dirt")
	create_surface("StoneLane", Vector3(0.0, 0.02, 2.0), Vector3(5.0, 0.12, 30.0), Color(0.22, 0.24, 0.3), "stone")
	create_surface("MetalWalkway", Vector3(8.0, 0.08, -2.0), Vector3(4.0, 0.2, 24.0), Color(0.2, 0.27, 0.34), "metal")
	create_surface("GrassPath", Vector3(-8.0, 0.03, -1.0), Vector3(5.0, 0.14, 26.0), Color(0.08, 0.24, 0.1), "grass")
	create_static_box("CampWall", Vector3(0.0, 1.5, -15.0), Vector3(26.0, 3.0, 0.6), Color(0.08, 0.1, 0.14))
	create_static_box("LeftCover", Vector3(-3.5, 1.2, -4.0), Vector3(3.0, 2.4, 0.7), Color(0.12, 0.1, 0.09))
	create_static_box("RightCover", Vector3(4.0, 1.2, -8.0), Vector3(3.2, 2.4, 0.7), Color(0.12, 0.1, 0.09))
	create_tall_grass(Vector3(-8.0, 0.0, 1.0), Vector3(5.0, 2.0, 8.0))
	create_tall_grass(Vector3(-7.0, 0.0, -9.0), Vector3(6.0, 2.0, 7.0))
	create_campfire(Vector3(1.5, 0.0, -10.5))
	create_enemy("GateSentry", Vector3(0.0, 0.8, -7.0), PI)
	create_enemy("FireSentry", Vector3(4.0, 0.8, -12.0), PI * 0.7)
	create_noise_beacon(Vector3(-10.0, 0.0, -5.5))
	var objective := Area3D.new()
	objective.name = "PatrolPlans"
	objective.position = Vector3(0.0, 0.15, -13.0)
	objective.set_script(StealthObjectiveScript)
	add_child(objective)
	readout = make_label("STEALTH READOUT", Vector3(-15.5, 4.5, 13.5), Color(0.62, 0.85, 1.0), 24)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(readout)
	var title := make_label("MOONLIT ENCAMPMENT", Vector3(0.0, 6.0, -14.5), Color(0.7, 0.82, 1.0), 46)
	add_child(title)


func create_enemy(enemy_name: String, position: Vector3, rotation_y: float) -> void:
	var enemy: CharacterBody3D = GremlinScene.instantiate() as CharacterBody3D
	var old_brain: Node = enemy.get_node_or_null("EnemyBrain")
	var definition: Variant = old_brain.get("enemy_definition") if old_brain != null else null
	var attack: Variant = old_brain.get("default_attack") if old_brain != null else null
	var options: Variant = old_brain.get("action_options") if old_brain != null else []
	if old_brain != null:
		enemy.remove_child(old_brain)
		old_brain.free()
	var sensor: EnemyPerceptionSensor = PerceptionSensorScript.new() as EnemyPerceptionSensor
	sensor.name = "EnemyPerceptionSensor"
	sensor.vision_range = 15.0
	sensor.field_of_view_degrees = 92.0
	sensor.hearing_sensitivity = 1.1
	sensor.sample_interval = 0.08
	enemy.add_child(sensor)
	var brain: Node = PerceptionBrainScript.new()
	brain.name = "EnemyBrain"
	brain.set("enemy_definition", definition)
	brain.set("default_attack", attack)
	brain.set("action_options", options)
	brain.set("personality_id", "cautious")
	brain.set("allow_combat", false)
	brain.set("noncombat_stop_distance", 2.4)
	enemy.add_child(brain)
	var visualizer: Node3D = PerceptionDebugScript.new() as Node3D
	visualizer.name = "PerceptionDebugVisualizer"
	enemy.add_child(visualizer)
	enemy.name = enemy_name
	enemy.position = position
	enemy.rotation.y = rotation_y
	add_child(enemy)
	enemies.append(enemy)


func create_noise_beacon(position: Vector3) -> void:
	var beacon: PerceptionNoiseBeacon = NoiseBeaconScript.new() as PerceptionNoiseBeacon
	beacon.name = "CampDistractionBell"
	beacon.position = position
	beacon.prompt_text = "Ring distant bell"
	beacon.message_text = "The bell rings from the far grass. Both sentries hear the same acoustic event."
	beacon.loudness = 17.0
	beacon.stimulus_category = "distraction"
	beacon.stimulus_display_name = "Distant camp bell"
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.75
	collision.shape = shape
	collision.position.y = 0.7
	beacon.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.25
	mesh.bottom_radius = 0.42
	mesh.height = 0.7
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.75
	mesh_instance.material_override = make_material(Color(0.72, 0.48, 0.12))
	beacon.add_child(mesh_instance)
	beacon.add_child(make_label("DISTRACTION BELL", Vector3(0.0, 1.55, 0.0), Color(1.0, 0.72, 0.28), 22))
	add_child(beacon)


func create_tall_grass(position: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = "TallGrass"
	area.position = position
	area.add_to_group("stealth_concealment")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	area.add_child(collision)
	for index: int in range(14):
		var blade := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.16, 1.25 + float(index % 3) * 0.18, 0.08)
		blade.mesh = mesh
		blade.position = Vector3(
			-size.x * 0.42 + float(index % 7) * size.x * 0.14,
			0.65,
			-size.z * 0.32 + float(index / 7) * size.z * 0.64
		)
		blade.rotation_degrees.z = -8.0 + float(index % 4) * 5.0
		blade.material_override = make_material(Color(0.09, 0.31, 0.12))
		area.add_child(blade)
	add_child(area)


func create_campfire(position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = position + Vector3.UP * 0.7
	light.light_color = Color(1.0, 0.36, 0.08)
	light.light_energy = 3.0
	light.omni_range = 7.0
	light.shadow_enabled = true
	add_child(light)
	var ember := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	ember.mesh = mesh
	ember.position = position + Vector3.UP * 0.35
	var material := make_material(Color(1.0, 0.25, 0.04))
	material.emission_enabled = true
	material.emission = Color(1.0, 0.12, 0.01)
	material.emission_energy_multiplier = 2.0
	ember.material_override = material
	add_child(ember)


func update_readout() -> void:
	if readout == null:
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	var stealth: Node = player.get_node_or_null("StealthController") if player != null else null
	var lines: Array[String] = ["STEALTH + ACOUSTICS"]
	if stealth != null:
		var data: Dictionary = stealth.call("get_debug_data") as Dictionary
		lines.append("Grace: " + ("CROUCHED" if bool(data.get("crouched", false)) else "STANDING")
			+ "  concealed " + str(data.get("concealed", false))
			+ "  noise ×" + str(snappedf(float(data.get("noise_multiplier", 1.0)), 0.01))
			+ "  visibility ×" + str(snappedf(float(data.get("visibility_multiplier", 1.0)), 0.01)))
	for enemy: CharacterBody3D in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var brain: Node = enemy.get_node_or_null("EnemyBrain")
		if brain != null and brain.has_method("get_debug_data"):
			var data: Dictionary = brain.call("get_debug_data") as Dictionary
			lines.append(enemy.name + ": " + str(data.get("awareness", "?"))
				+ "  suspicion " + str(data.get("suspicion", 0.0))
				+ "  heard " + str(data.get("last", "none")))
	lines.append("Active acoustic events: " + str(manager.active_stimuli.size() if manager != null else 0))
	lines.append("L3/Ctrl crouch • Interact takedown • Cast Echolocation • V geometry • F8 reset")
	readout.text = "\n".join(lines)


func create_surface(node_name: String, position: Vector3, size: Vector3, color: Color, surface: String) -> StaticBody3D:
	var body: StaticBody3D = create_static_box(node_name, position, size, color)
	body.set_meta("acoustic_surface", surface)
	return body


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
	material.roughness = 0.72
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
	return label


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
