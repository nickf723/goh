extends Node3D
class_name PrototypePerceptionInvestigationLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")
const CrateScene: PackedScene = preload("res://scenes/actors/interactables/breakable_wooden_crate.tscn")
const PerceptionBrainScript = preload("res://scripts/enemies/enemy_perception_investigation_brain.gd")
const PerceptionSensorScript = preload("res://scripts/perception/enemy_perception_sensor.gd")
const PerceptionDebugScript = preload("res://scripts/perception/perception_debug_visualizer.gd")
const MovementEmitterScript = preload("res://scripts/perception/perception_movement_emitter.gd")
const BreakableEmitterScript = preload("res://scripts/perception/perception_breakable_emitter.gd")
const NoiseBeaconScript = preload("res://scripts/perception/perception_noise_beacon.gd")
const GasVolumeGridScript = preload("res://scripts/gas/gas_volume_grid.gd")
const GasEmitterScript = preload("res://scripts/gas/gas_emitter_3d.gd")
const SmokeGas: GasDefinition = preload("res://data/gas/smoke_gas.tres")
const PerceptionLabLoadout: Resource = preload("res://data/loadouts/grace_gas_lab_loadout.tres")

const LANE_CONFIGS: Array[Dictionary] = [
	{"x": -15.0, "personality": "cautious", "name": "Cautious Observer", "color": Color(0.3, 0.78, 1.0, 1.0)},
	{"x": -5.0, "personality": "bold", "name": "Bold Observer", "color": Color(1.0, 0.38, 0.2, 1.0)},
	{"x": 5.0, "personality": "skittish", "name": "Skittish Observer", "color": Color(0.72, 0.38, 1.0, 1.0)},
	{"x": 15.0, "personality": "brute", "name": "Brute Observer", "color": Color(0.88, 0.76, 0.25, 1.0)},
]

@export var enable_editor_f8_reset: bool = true
@export_range(0.05, 1.0, 0.01) var readout_interval: float = 0.16
@export var safety_reset_height: float = -5.0

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var stimulus_manager: PerceptionStimulusManager = get_node_or_null("PerceptionStimulusManager") as PerceptionStimulusManager

var previous_invulnerable: bool = false
var previous_invulnerability_timer: float = 0.0
var initial_player_transform: Transform3D
var stat_snapshot: Dictionary = {}
var readout_timer: float = 0.0
var reset_count: int = 0
var debug_visuals_visible: bool = true
var gas_visuals_visible: bool = true
var enemies: Array[CharacterBody3D] = []
var readout: Label3D = null
var smoke_volume: GasVolumeGrid = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	protect_grace()
	build_laboratory()
	configure_player()
	GameState.set_objective("Test sight, sound, memory, searching, and Smoke concealment across four enemy personalities.")
	show_message("Perception Lab ready. Enemies know where evidence happened, not where Grace secretly moved afterward.")
	update_readout()


func _process(delta: float) -> void:
	readout_timer -= max(delta, 0.0)
	if readout_timer <= 0.0:
		readout_timer = max(readout_interval, 0.05)
		update_readout()
	if player != null and player.global_position.y < safety_reset_height:
		reset_lab()


func _exit_tree() -> void:
	GameState.player_invulnerable = previous_invulnerable
	GameState.player_invulnerability_timer = previous_invulnerability_timer
	restore_stat_snapshot()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if enable_editor_f8_reset and OS.has_feature("editor") and key_event.physical_keycode == KEY_F8:
		reset_lab()
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_V:
		debug_visuals_visible = not debug_visuals_visible
		for visualizer: Node in get_tree().get_nodes_in_group("perception_debug_visualizers"):
			visualizer.visible = debug_visuals_visible
		show_message("Perception geometry " + ("visible." if debug_visuals_visible else "hidden."))
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_B and smoke_volume != null:
		gas_visuals_visible = not gas_visuals_visible
		smoke_volume.set_density_visuals_visible(gas_visuals_visible)
		show_message("Smoke density voxels " + ("visible." if gas_visuals_visible else "hidden."))
		get_viewport().set_input_as_handled()


func protect_grace() -> void:
	previous_invulnerable = GameState.player_invulnerable
	previous_invulnerability_timer = GameState.player_invulnerability_timer
	GameState.player_invulnerable = true
	GameState.player_invulnerability_timer = INF


func configure_player() -> void:
	if player == null:
		return
	player.add_to_group("player")
	initial_player_transform = player.transform
	var movement_emitter: Node = player.get_node_or_null("PerceptionMovementEmitter")
	if movement_emitter == null:
		movement_emitter = MovementEmitterScript.new()
		movement_emitter.name = "PerceptionMovementEmitter"
		player.add_child(movement_emitter)
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster != null:
		caster.set("loadout", PerceptionLabLoadout.duplicate(true))
		caster.set("current_ability_index", 0)
		if caster.has_method("align_focus_menu_to_current_ability"):
			caster.call("align_focus_menu_to_current_ability")
		if caster.has_method("emit_current_ability"):
			caster.call("emit_current_ability")
	GameState.set_stat("max_health", 20)
	GameState.set_stat("health", 20)
	GameState.set_stat("max_mana", 12)
	GameState.set_stat("mana", 12)
	GameState.set_stat("focus", max(GameState.get_stat("focus"), 5))
	player.set("is_defeated", false)


func build_laboratory() -> void:
	create_floor_and_boundaries()
	create_instruction_board()
	create_lane_architecture()
	create_smoke_curtain()
	for config: Dictionary in LANE_CONFIGS:
		create_lane_enemy(config)
		create_noise_beacon(config)
		create_noise_crate(config)
	create_readout()


func create_floor_and_boundaries() -> void:
	create_static_box("SafetyFloor", Vector3(0.0, -0.45, 0.0), Vector3(42.0, 0.9, 30.0), Color(0.045, 0.055, 0.075, 1.0))
	var wall_color := Color(0.03, 0.04, 0.06, 1.0)
	create_static_box("NorthWall", Vector3(0.0, 2.5, -15.0), Vector3(42.0, 5.0, 0.5), wall_color)
	create_static_box("SouthWall", Vector3(0.0, 2.5, 15.0), Vector3(42.0, 5.0, 0.5), wall_color)
	create_static_box("WestWall", Vector3(-21.0, 2.5, 0.0), Vector3(0.5, 5.0, 30.0), wall_color)
	create_static_box("EastWall", Vector3(21.0, 2.5, 0.0), Vector3(0.5, 5.0, 30.0), wall_color)


func create_instruction_board() -> void:
	var board := Node3D.new()
	board.name = "InstructionBoard"
	board.position = Vector3(0.0, 3.1, 13.7)
	add_child(board)
	ElementVisuals.add_box(board, "Board", Vector3(18.0, 4.6, 0.2), Color(0.018, 0.035, 0.06, 1.0), Vector3.ZERO, Vector3.ZERO, 0.35, 0.96)
	var label := make_label(
		"WORLD-AWARE PERCEPTION LAB\nGreen unaware  •  Yellow suspicious  •  Orange investigating  •  Red alerted  •  Violet searching\nWalk, hide behind walls, trigger beacons, break crates, and cast Gust through Smoke\nV perception geometry  •  B Smoke voxels  •  F8 reset",
		Vector3(0.0, 0.0, 0.12),
		Color(0.72, 0.94, 1.0, 1.0),
		28,
		0.0048
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(label)


func create_lane_architecture() -> void:
	var divider_color := Color(0.075, 0.09, 0.13, 1.0)
	for x_value: float in [-10.0, 0.0, 10.0]:
		create_static_box("LaneDivider" + str(x_value), Vector3(x_value, 1.25, -4.0), Vector3(0.35, 2.5, 20.0), divider_color)
	for config: Dictionary in LANE_CONFIGS:
		var lane_x: float = float(config.get("x", 0.0))
		var lane_color: Color = config.get("color", Color.WHITE) as Color
		create_zone_floor(Vector3(lane_x, 0.02, -3.0), Vector3(9.4, 0.05, 22.5), lane_color.darkened(0.68), str(config.get("personality", "balanced")).to_upper())
		create_static_box("Occluder" + str(lane_x), Vector3(lane_x - 1.75, 1.35, -0.5), Vector3(3.1, 2.7, 0.55), divider_color.lightened(0.08))
		create_static_box("ReturnPost" + str(lane_x), Vector3(lane_x, 0.65, -10.4), Vector3(1.8, 1.3, 0.5), lane_color.darkened(0.5), 0.25)


func create_lane_enemy(config: Dictionary) -> void:
	var enemy: CharacterBody3D = GremlinScene.instantiate() as CharacterBody3D
	if enemy == null:
		return
	var old_brain: Node = enemy.get_node_or_null("EnemyBrain")
	var definition_value: Variant = old_brain.get("enemy_definition") if old_brain != null else null
	var attack_value: Variant = old_brain.get("default_attack") if old_brain != null else null
	var options_value: Variant = old_brain.get("action_options") if old_brain != null else []
	if old_brain != null:
		enemy.remove_child(old_brain)
		old_brain.free()

	var sensor: EnemyPerceptionSensor = PerceptionSensorScript.new() as EnemyPerceptionSensor
	sensor.name = "EnemyPerceptionSensor"
	sensor.vision_range = 14.0
	sensor.field_of_view_degrees = 96.0
	sensor.hearing_sensitivity = 1.0
	sensor.sample_interval = 0.09
	enemy.add_child(sensor)

	var brain: Node = PerceptionBrainScript.new()
	brain.name = "EnemyBrain"
	brain.set("enemy_definition", definition_value)
	brain.set("default_attack", attack_value)
	brain.set("action_options", options_value)
	brain.set("personality_id", str(config.get("personality", "balanced")))
	brain.set("allow_combat", false)
	brain.set("noncombat_stop_distance", 2.8)
	brain.set("zone_awareness_radius", 5.5)
	enemy.add_child(brain)

	var visualizer: Node3D = PerceptionDebugScript.new() as Node3D
	visualizer.name = "PerceptionDebugVisualizer"
	enemy.add_child(visualizer)

	enemy.name = str(config.get("name", "Observer")).replace(" ", "")
	enemy.position = Vector3(float(config.get("x", 0.0)), 0.85, -9.6)
	enemy.rotation.y = PI
	add_child(enemy)
	enemies.append(enemy)


func create_noise_beacon(config: Dictionary) -> void:
	var lane_x: float = float(config.get("x", 0.0))
	var color: Color = config.get("color", Color.WHITE) as Color
	var beacon: PerceptionNoiseBeacon = NoiseBeaconScript.new() as PerceptionNoiseBeacon
	beacon.name = str(config.get("personality", "balanced")).capitalize() + "NoiseBeacon"
	beacon.position = Vector3(lane_x + 2.5, 0.0, 4.0)
	beacon.loudness = 13.5
	beacon.stimulus_display_name = "Lane chime"
	beacon.message_text = "A chime rings from the " + str(config.get("personality", "balanced")) + " lane."
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	collision.position = Vector3(0.0, 0.7, 0.0)
	collision.shape = shape
	beacon.add_child(collision)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.position = Vector3(0.0, 0.72, 0.0)
	beacon.add_child(visual)
	ElementVisuals.add_sphere(visual, "Core", 0.38, color, Vector3.ZERO, Vector3.ONE, 1.7, 0.9)
	ElementVisuals.add_torus(visual, "Ring", 0.48, 0.62, color, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), 1.1, 0.55)
	beacon.add_child(make_label("INTERACT\nNOISE", Vector3(0.0, 1.65, 0.0), color.lightened(0.18), 24, 0.0055))
	add_child(beacon)


func create_noise_crate(config: Dictionary) -> void:
	var crate: Node3D = CrateScene.instantiate() as Node3D
	if crate == null:
		return
	crate.name = str(config.get("personality", "balanced")).capitalize() + "NoiseCrate"
	crate.position = Vector3(float(config.get("x", 0.0)) - 2.7, 0.0, 3.2)
	var emitter: Node = BreakableEmitterScript.new()
	emitter.name = "PerceptionBreakableEmitter"
	crate.add_child(emitter)
	add_child(crate)


func create_smoke_curtain() -> void:
	var smoke_definition: GasDefinition = SmokeGas.duplicate(true) as GasDefinition
	smoke_definition.buoyancy_velocity = Vector3(0.0, 0.32, 0.0)
	smoke_definition.diffusion_rate = 0.18
	smoke_definition.decay_rate_per_second = 0.055
	smoke_volume = GasVolumeGridScript.new() as GasVolumeGrid
	smoke_volume.name = "PerceptionSmokeGrid"
	smoke_volume.position = Vector3(0.0, 2.6, -0.4)
	smoke_volume.gas_definition = smoke_definition
	smoke_volume.grid_size = Vector3i(10, 6, 10)
	smoke_volume.cell_size = 1.15
	smoke_volume.simulation_interval = 0.2
	smoke_volume.maximum_steps_per_frame = 1
	smoke_volume.visual_stride = 2
	smoke_volume.visual_update_interval = 0.32
	smoke_volume.visual_alpha_multiplier = 0.72
	add_child(smoke_volume)

	var emitter: GasEmitter3D = GasEmitterScript.new() as GasEmitter3D
	emitter.name = "SmokeCurtainEmitter"
	emitter.position = Vector3(0.0, 0.5, -0.2)
	emitter.gas_id = "smoke"
	emitter.emission_rate_per_second = 1.4
	emitter.emission_radius = 2.1
	emitter.pulse_frequency = 0.18
	emitter.pulse_depth = 0.12
	add_child(emitter)
	ElementVisuals.add_sphere(emitter, "SmokeSource", 0.42, Color(0.58, 0.68, 0.74, 1.0), Vector3.ZERO, Vector3.ONE, 1.0, 0.5)
	emitter.add_child(make_label("SMOKE CONCEALMENT\nGust moves the density", Vector3(0.0, 1.35, 0.0), Color(0.72, 0.84, 0.9, 1.0), 24, 0.005))


func create_readout() -> void:
	readout = make_label("PERCEPTION READOUT", Vector3(-20.0, 4.2, 13.0), Color(0.74, 0.95, 1.0, 1.0), 25, 0.0055)
	readout.name = "PerceptionReadout"
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(readout)


func update_readout() -> void:
	if readout == null:
		return
	var lines: Array[String] = ["PERCEPTION READOUT"]
	for enemy: CharacterBody3D in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var brain: Node = enemy.get_node_or_null("EnemyBrain")
		if brain == null or not brain.has_method("get_debug_data"):
			continue
		var data_value: Variant = brain.call("get_debug_data")
		var data: Dictionary = data_value as Dictionary if data_value is Dictionary else {}
		lines.append(
			enemy.name.replace("Observer", "") + ": "
			+ str(data.get("awareness", "?")) + "  sus " + str(data.get("suspicion", 0.0))
			+ "  vis " + str(data.get("visibility", 0.0)) + "  smoke " + str(data.get("smoke", 0.0))
			+ "\n  last " + str(data.get("last", "none"))
		)
	var active_stimuli: int = stimulus_manager.active_stimuli.size() if stimulus_manager != null else 0
	lines.append("Active sound events: " + str(active_stimuli))
	readout.text = "\n".join(lines)


func create_zone_floor(position_value: Vector3, size_value: Vector3, color: Color, label_text: String) -> void:
	var panel := MeshInstance3D.new()
	panel.name = label_text + "LaneFloor"
	var mesh := BoxMesh.new()
	mesh.size = size_value
	panel.mesh = mesh
	panel.position = position_value
	panel.material_override = ElementVisuals.make_material(color, 0.16, 0.46, true)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)
	var label := make_label(label_text, position_value + Vector3(0.0, 0.16, 8.7), color.lightened(0.35), 24, 0.006)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(label)


func create_static_box(
	name_value: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color,
	emission: float = 0.06
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_value
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(color, emission, 1.0, false)
	body.add_child(mesh_instance)
	add_child(body)
	return body


func make_label(text_value: String, position_value: Vector3, color: Color, font_size_value: int, pixel_size_value: float) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = font_size_value
	label.pixel_size = pixel_size_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = color
	return label


func reset_lab() -> void:
	reset_count += 1
	if stimulus_manager != null:
		stimulus_manager.clear_stimuli()
	for enemy: CharacterBody3D in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var brain: Node = enemy.get_node_or_null("EnemyBrain")
		if brain != null and brain.has_method("reset_perception"):
			brain.call("reset_perception")
		var hit_receiver: Node = enemy.get_node_or_null("HitReceiver")
		if hit_receiver != null and hit_receiver.has_method("reset_health"):
			hit_receiver.call("reset_health")
	for node: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if node != null and is_instance_valid(node) and is_ancestor_of(node) and node.has_method("reset_target"):
			node.call("reset_target")
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	configure_player()
	GameState.set_objective("Test sight, sound, memory, searching, and Smoke concealment across four enemy personalities.")
	show_message("Perception Laboratory reset #" + str(reset_count) + ".")
	update_readout()


func restore_stat_snapshot() -> void:
	for raw_key: Variant in stat_snapshot.keys():
		GameState.set_stat(str(raw_key), int(stat_snapshot[raw_key]))


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"perception_lab": true,
		"enemy_count": enemies.size(),
		"active_stimuli": stimulus_manager.active_stimuli.size() if stimulus_manager != null else 0,
		"smoke": smoke_volume.get_debug_data() if smoke_volume != null else {},
		"reset_count": reset_count,
	}
