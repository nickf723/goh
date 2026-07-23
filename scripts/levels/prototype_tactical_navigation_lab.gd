extends Node3D
class_name PrototypeTacticalNavigationLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")
const TacticalBrainScript = preload("res://scripts/enemies/enemy_tactical_navigation_brain.gd")
const PerceptionSensorScript = preload("res://scripts/perception/enemy_perception_sensor.gd")
const TacticalAgentScript = preload("res://scripts/navigation/tactical_navigation_agent.gd")
const TacticalHazardScript = preload("res://scripts/navigation/tactical_navigation_hazard.gd")
const TacticalRouteAnchorScript = preload("res://scripts/navigation/tactical_route_anchor.gd")
const TacticalDebugScript = preload("res://scripts/navigation/tactical_navigation_debug_visualizer.gd")

const LANE_CONFIGS: Array[Dictionary] = [
	{"lane": "cautious", "x": -15.0, "personality": "cautious", "color": Color(0.28, 0.76, 1.0, 1.0)},
	{"lane": "bold", "x": -5.0, "personality": "bold", "color": Color(1.0, 0.35, 0.18, 1.0)},
	{"lane": "skittish", "x": 5.0, "personality": "skittish", "color": Color(0.72, 0.36, 1.0, 1.0)},
	{"lane": "brute", "x": 15.0, "personality": "brute", "color": Color(0.9, 0.76, 0.22, 1.0)},
]

const LANE_HALF_WIDTH: float = 4.35
const NAVIGATION_Z_MIN: float = -12.0
const NAVIGATION_Z_MAX: float = 11.5
const WALL_NORTH_Z: float = -1.45
const WALL_SOUTH_Z: float = -0.35
const WALL_LEFT_OFFSET: float = -2.7
const WALL_RIGHT_OFFSET: float = 1.9
const START_Z: float = -10.2
const GOAL_Z: float = 8.6
const ACTOR_X_OFFSET: float = 1.0

@export var enable_editor_f8_reset: bool = true
@export_range(0.05, 1.0, 0.01) var readout_interval: float = 0.18
@export var auto_start_trial: bool = true
@export var safety_reset_height: float = -5.0

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D

var previous_invulnerable: bool = false
var previous_invulnerability_timer: float = 0.0
var stat_snapshot: Dictionary = {}
var initial_player_transform: Transform3D
var enemies: Array[CharacterBody3D] = []
var hazards: Array[TacticalNavigationHazard] = []
var enemy_initial_transforms: Dictionary = {}
var goal_positions: Dictionary = {}
var readout: Label3D = null
var readout_timer: float = 0.0
var hazards_active: bool = true
var debug_paths_visible: bool = true
var trial_count: int = 0
var reset_count: int = 0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	protect_grace()
	build_laboratory()
	configure_player()
	GameState.set_objective("Watch four personalities route around walls and weigh the dangerous shortcut differently.")
	show_message("Tactical Navigation Lab ready. T starts the route trial; H toggles shortcut danger.")
	update_readout()
	if auto_start_trial:
		call_deferred("begin_trial_after_navigation_sync")


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
	match key_event.physical_keycode:
		KEY_T:
			begin_trial()
			get_viewport().set_input_as_handled()
		KEY_H:
			toggle_shortcut_hazards()
			get_viewport().set_input_as_handled()
		KEY_V:
			toggle_debug_paths()
			get_viewport().set_input_as_handled()
		KEY_F8:
			if enable_editor_f8_reset and OS.has_feature("editor"):
				reset_lab()
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
	GameState.set_stat("max_health", 20)
	GameState.set_stat("health", 20)
	GameState.set_stat("max_mana", 12)
	GameState.set_stat("mana", 12)
	player.set("is_defeated", false)
	var action_state: Node = player.get_node_or_null("PlayerActionState")
	if action_state != null and action_state.has_method("reset_for_respawn"):
		action_state.call("reset_for_respawn")


func build_laboratory() -> void:
	create_floor_and_boundaries()
	create_instruction_board()
	for config: Dictionary in LANE_CONFIGS:
		create_navigation_lane(config)
	create_readout()


func create_floor_and_boundaries() -> void:
	create_static_box("SafetyFloor", Vector3(0.0, -0.45, 0.0), Vector3(42.0, 0.9, 30.0), Color(0.045, 0.055, 0.075, 1.0))
	var wall_color := Color(0.028, 0.038, 0.057, 1.0)
	create_static_box("NorthWall", Vector3(0.0, 2.5, -15.0), Vector3(42.0, 5.0, 0.5), wall_color)
	create_static_box("SouthWall", Vector3(0.0, 2.5, 15.0), Vector3(42.0, 5.0, 0.5), wall_color)
	create_static_box("WestWall", Vector3(-21.0, 2.5, 0.0), Vector3(0.5, 5.0, 30.0), wall_color)
	create_static_box("EastWall", Vector3(21.0, 2.5, 0.0), Vector3(0.5, 5.0, 30.0), wall_color)
	for divider_x: float in [-10.0, 0.0, 10.0]:
		create_static_box("LaneDivider" + str(divider_x), Vector3(divider_x, 1.1, -1.0), Vector3(0.35, 2.2, 24.0), wall_color.lightened(0.025))


func create_instruction_board() -> void:
	var board := Node3D.new()
	board.name = "InstructionBoard"
	board.position = Vector3(0.0, 3.25, 13.65)
	add_child(board)
	ElementVisuals.add_box(board, "Board", Vector3(19.0, 4.8, 0.2), Color(0.018, 0.035, 0.06, 1.0), Vector3.ZERO, Vector3.ZERO, 0.34, 0.96)
	var label := make_label(
		"TACTICAL NAVIGATION LAB\nEnemies must WALK AROUND the wall  •  Blue route is safe  •  Orange route is shorter but hazardous\nT start trial  •  H toggle hazard  •  V route lines  •  F8 reset",
		Vector3(0.0, 0.0, 0.12),
		Color(0.74, 0.95, 1.0, 1.0),
		28,
		0.0047
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(label)


func create_navigation_lane(config: Dictionary) -> void:
	var lane_id: String = str(config.get("lane", "lane"))
	var lane_x: float = float(config.get("x", 0.0))
	var personality: String = str(config.get("personality", "balanced"))
	var lane_color: Color = config.get("color", Color.WHITE) as Color
	create_zone_floor(Vector3(lane_x, 0.02, -1.0), Vector3(9.3, 0.05, 24.0), lane_color.darkened(0.72), personality.to_upper())
	create_lane_navigation_mesh(lane_id, lane_x)
	create_lane_obstacle(lane_id, lane_x, lane_color)
	create_lane_route_anchors(lane_id, lane_x, lane_color)
	create_lane_hazard(lane_id, lane_x)
	create_lane_goal(lane_id, lane_x, lane_color)
	create_lane_enemy(lane_id, lane_x, personality, lane_color)


func create_lane_navigation_mesh(lane_id: String, lane_x: float) -> void:
	var x_values := PackedFloat32Array([
		lane_x - LANE_HALF_WIDTH,
		lane_x + WALL_LEFT_OFFSET,
		lane_x + WALL_RIGHT_OFFSET,
		lane_x + LANE_HALF_WIDTH,
	])
	var z_values := PackedFloat32Array([
		NAVIGATION_Z_MIN,
		WALL_NORTH_Z,
		WALL_SOUTH_Z,
		NAVIGATION_Z_MAX,
	])
	var vertices := PackedVector3Array()
	for z_value: float in z_values:
		for x_value: float in x_values:
			vertices.append(Vector3(x_value, 0.04, z_value))

	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.set_vertices(vertices)
	for x_index: int in range(3):
		add_navigation_grid_quad(navigation_mesh, x_index, 0)
		add_navigation_grid_quad(navigation_mesh, x_index, 2)
	add_navigation_grid_quad(navigation_mesh, 0, 1)
	add_navigation_grid_quad(navigation_mesh, 2, 1)

	var region := NavigationRegion3D.new()
	region.name = lane_id.capitalize() + "NavigationRegion"
	region.navigation_layers = 1
	region.navigation_mesh = navigation_mesh
	add_child(region)


func add_navigation_grid_quad(navigation_mesh: NavigationMesh, x_index: int, z_index: int) -> void:
	var top_left: int = z_index * 4 + x_index
	var bottom_left: int = (z_index + 1) * 4 + x_index
	var bottom_right: int = (z_index + 1) * 4 + x_index + 1
	var top_right: int = z_index * 4 + x_index + 1
	navigation_mesh.add_polygon(PackedInt32Array([top_left, bottom_left, bottom_right, top_right]))


func create_lane_obstacle(lane_id: String, lane_x: float, lane_color: Color) -> void:
	var wall_center_x: float = lane_x + (WALL_LEFT_OFFSET + WALL_RIGHT_OFFSET) * 0.5
	var wall_width: float = WALL_RIGHT_OFFSET - WALL_LEFT_OFFSET
	var wall_depth: float = WALL_SOUTH_Z - WALL_NORTH_Z
	create_static_box(
		lane_id.capitalize() + "SightlineWall",
		Vector3(wall_center_x, 1.45, (WALL_NORTH_Z + WALL_SOUTH_Z) * 0.5),
		Vector3(wall_width, 2.9, wall_depth),
		Color(0.075, 0.09, 0.13, 1.0).lerp(lane_color.darkened(0.65), 0.22),
		0.12
	)
	var label := make_label("NO DIRECT PATH", Vector3(wall_center_x, 3.15, -0.9), lane_color.lightened(0.25), 23, 0.0052)
	add_child(label)


func create_lane_route_anchors(lane_id: String, lane_x: float, lane_color: Color) -> void:
	var safe_position := Vector3(lane_x - 3.5, 0.05, -0.9)
	var shortcut_position := Vector3(lane_x + 3.05, 0.05, -0.9)
	create_route_anchor(lane_id, lane_id + "_safe_left", safe_position, ["safe", "left"], 0.0, Color(0.2, 0.78, 1.0, 1.0), "SAFE ROUTE")
	create_route_anchor(lane_id, lane_id + "_shortcut_right", shortcut_position, ["shortcut", "hazard", "right"], -0.15, Color(1.0, 0.48, 0.12, 1.0), "SHORTCUT")
	create_route_strip(lane_x - 3.5, Color(0.12, 0.52, 0.72, 0.48))
	create_route_strip(lane_x + 3.05, Color(0.72, 0.3, 0.06, 0.48))


func create_route_anchor(
	lane_id: String,
	route_id: String,
	position_value: Vector3,
	tags: Array[String],
	bias: float,
	color: Color,
	label_text: String
) -> TacticalRouteAnchor:
	var anchor: TacticalRouteAnchor = TacticalRouteAnchorScript.new() as TacticalRouteAnchor
	anchor.name = route_id.to_pascal_case() + "Anchor"
	anchor.position = position_value
	anchor.route_id = route_id
	anchor.lane_id = lane_id
	anchor.route_tags = tags
	anchor.route_bias = bias
	add_child(anchor)
	ElementVisuals.add_torus(anchor, "RouteRing", 0.35, 0.48, color, Vector3(0.0, 0.12, 0.0), Vector3.ZERO, 1.4, 0.55)
	anchor.add_child(make_label(label_text, Vector3(0.0, 1.0, 0.0), color.lightened(0.18), 20, 0.0048))
	return anchor


func create_route_strip(x_value: float, color: Color) -> void:
	var strip := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 0.035, 3.8)
	strip.mesh = mesh
	strip.position = Vector3(x_value, 0.055, -0.9)
	strip.material_override = ElementVisuals.make_material(color, 0.35, color.a, true)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)


func create_lane_hazard(lane_id: String, lane_x: float) -> void:
	var hazard: TacticalNavigationHazard = TacticalHazardScript.new() as TacticalNavigationHazard
	hazard.name = lane_id.capitalize() + "ShortcutHazard"
	hazard.position = Vector3(lane_x + 3.05, 0.06, -0.9)
	hazard.hazard_id = lane_id + "_poison_shortcut"
	hazard.lane_id = lane_id
	hazard.behavior = "danger"
	hazard.radius = 2.15
	hazard.cost_per_meter = 2.2
	hazard.falloff_exponent = 1.35
	hazard.active = hazards_active
	add_child(hazard)
	ElementVisuals.add_sphere(hazard, "HazardCore", 0.42, Color(0.4, 0.95, 0.18, 1.0), Vector3(0.0, 0.18, 0.0), Vector3(1.5, 0.45, 1.5), 1.8, 0.42)
	ElementVisuals.add_torus(hazard, "HazardRingA", 1.45, 1.68, Color(0.34, 0.9, 0.14, 1.0), Vector3(0.0, 0.08, 0.0), Vector3.ZERO, 1.1, 0.25)
	ElementVisuals.add_torus(hazard, "HazardRingB", 1.85, 2.05, Color(0.58, 1.0, 0.22, 1.0), Vector3(0.0, 0.07, 0.0), Vector3.ZERO, 0.7, 0.18)
	hazard.add_child(make_label("DANGER COST", Vector3(0.0, 1.28, 0.0), Color(0.62, 1.0, 0.3, 1.0), 21, 0.0048))
	hazards.append(hazard)


func create_lane_goal(lane_id: String, lane_x: float, lane_color: Color) -> void:
	var goal_position := Vector3(lane_x + ACTOR_X_OFFSET, 0.05, GOAL_Z)
	goal_positions[lane_id] = goal_position
	var goal := Node3D.new()
	goal.name = lane_id.capitalize() + "EvidenceBeacon"
	goal.position = goal_position
	add_child(goal)
	ElementVisuals.add_sphere(goal, "Beacon", 0.42, lane_color, Vector3(0.0, 0.55, 0.0), Vector3.ONE, 1.8, 0.9)
	ElementVisuals.add_torus(goal, "BeaconRing", 0.58, 0.72, lane_color.lightened(0.18), Vector3(0.0, 0.55, 0.0), Vector3(90.0, 0.0, 0.0), 1.2, 0.45)
	goal.add_child(make_label("EVIDENCE", Vector3(0.0, 1.55, 0.0), lane_color.lightened(0.25), 22, 0.005))


func create_lane_enemy(lane_id: String, lane_x: float, personality: String, lane_color: Color) -> void:
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

	enemy.name = personality.capitalize() + "Navigator"
	enemy.position = Vector3(lane_x + ACTOR_X_OFFSET, 0.85, START_Z)
	enemy.rotation.y = PI
	enemy.set_meta("navigation_lane_id", lane_id)
	enemy.set_meta("navigation_personality", personality)

	var tactical_agent: TacticalNavigationAgent = TacticalAgentScript.new() as TacticalNavigationAgent
	tactical_agent.name = "TacticalNavigationAgent"
	tactical_agent.lane_id = lane_id
	tactical_agent.personality_id = personality
	tactical_agent.require_route_anchor = true
	tactical_agent.route_replan_interval = 0.55
	tactical_agent.hazard_sample_spacing = 0.65
	enemy.add_child(tactical_agent)

	var perception_sensor: EnemyPerceptionSensor = PerceptionSensorScript.new() as EnemyPerceptionSensor
	perception_sensor.name = "EnemyPerceptionSensor"
	perception_sensor.target_group = "navigation_lab_no_live_target"
	perception_sensor.vision_range = 1.0
	perception_sensor.hearing_sensitivity = 0.1
	enemy.add_child(perception_sensor)

	var brain: Node = TacticalBrainScript.new()
	brain.name = "EnemyBrain"
	brain.set("enemy_definition", definition_value)
	brain.set("default_attack", attack_value)
	brain.set("action_options", options_value)
	brain.set("player_group", "navigation_lab_no_live_target")
	brain.set("personality_id", personality)
	brain.set("allow_combat", false)
	brain.set("investigation_timeout", 18.0)
	brain.set("search_duration", 2.8)
	brain.set("return_home_after_search", true)
	brain.set("zone_awareness_radius", 3.5)
	enemy.add_child(brain)

	var debug_visualizer: TacticalNavigationDebugVisualizer = TacticalDebugScript.new() as TacticalNavigationDebugVisualizer
	debug_visualizer.name = "TacticalNavigationDebugVisualizer"
	enemy.add_child(debug_visualizer)

	add_child(enemy)
	enemies.append(enemy)
	enemy_initial_transforms[enemy] = enemy.transform

	var personality_label := make_label(
		personality.to_upper() + "\n" + get_personality_route_note(personality),
		Vector3(lane_x, 2.65, START_Z + 1.5),
		lane_color.lightened(0.22),
		24,
		0.0052
	)
	add_child(personality_label)


func get_personality_route_note(personality: String) -> String:
	match personality:
		"cautious":
			return "high danger cost"
		"bold":
			return "accepts danger"
		"skittish":
			return "maximum avoidance"
		"brute":
			return "nearly ignores danger"
	return "balanced routing"


func begin_trial_after_navigation_sync() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	begin_trial()


func begin_trial() -> void:
	trial_count += 1
	for enemy: CharacterBody3D in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var lane_id: String = str(enemy.get_meta("navigation_lane_id", ""))
		var goal_value: Variant = goal_positions.get(lane_id)
		if not goal_value is Vector3:
			continue
		var brain: Node = enemy.get_node_or_null("EnemyBrain")
		if brain != null and brain.has_method("investigate_world_position"):
			brain.call("investigate_world_position", goal_value as Vector3, "route trial beacon")
	show_message("Route trial #" + str(trial_count) + " started. Watch the chosen paths bend around the walls.")


func toggle_shortcut_hazards() -> void:
	hazards_active = not hazards_active
	for hazard: TacticalNavigationHazard in hazards:
		if hazard == null or not is_instance_valid(hazard):
			continue
		hazard.set_hazard_active(hazards_active)
		hazard.visible = hazards_active
	force_all_replans()
	show_message("Shortcut danger " + ("active. Personalities should diverge." if hazards_active else "disabled. Shortest paths should dominate."))


func force_all_replans() -> void:
	for enemy: CharacterBody3D in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var component: TacticalNavigationAgent = enemy.get_node_or_null("TacticalNavigationAgent") as TacticalNavigationAgent
		if component != null:
			component.force_replan()


func toggle_debug_paths() -> void:
	debug_paths_visible = not debug_paths_visible
	for visualizer: Node in get_tree().get_nodes_in_group("tactical_navigation_debug_visualizers"):
		visualizer.visible = debug_paths_visible
	show_message("Tactical route lines " + ("visible." if debug_paths_visible else "hidden."))


func create_readout() -> void:
	readout = make_label("TACTICAL ROUTING", Vector3(-20.0, 4.3, 13.1), Color(0.74, 0.95, 1.0, 1.0), 24, 0.0053)
	readout.name = "TacticalNavigationReadout"
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(readout)


func update_readout() -> void:
	if readout == null:
		return
	var lines: Array[String] = [
		"TACTICAL ROUTING  •  hazard " + ("ACTIVE" if hazards_active else "OFF"),
	]
	for enemy: CharacterBody3D in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var personality: String = str(enemy.get_meta("navigation_personality", enemy.name))
		var brain: Node = enemy.get_node_or_null("EnemyBrain")
		if brain == null or not brain.has_method("get_debug_data"):
			continue
		var data_value: Variant = brain.call("get_debug_data")
		var data: Dictionary = data_value as Dictionary if data_value is Dictionary else {}
		lines.append(
			personality.capitalize() + ": " + str(data.get("awareness", "?"))
			+ "  route " + simplify_route_name(str(data.get("route", "none")))
			+ "\n  score " + str(data.get("route_score", "inf"))
			+ "  distance " + str(data.get("route_distance", 0.0))
			+ "  danger " + str(data.get("route_hazard", 0.0))
			+ "  stuck " + str(data.get("route_stuck", 0.0))
		)
	readout.text = "\n".join(lines)


func simplify_route_name(route_id: String) -> String:
	if route_id.contains("safe"):
		return "SAFE LEFT"
	if route_id.contains("shortcut"):
		return "RISKY RIGHT"
	return route_id.to_upper()


func reset_lab() -> void:
	reset_count += 1
	hazards_active = true
	for hazard: TacticalNavigationHazard in hazards:
		if hazard != null and is_instance_valid(hazard):
			hazard.set_hazard_active(true)
			hazard.visible = true
	for enemy: CharacterBody3D in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var transform_value: Variant = enemy_initial_transforms.get(enemy)
		if transform_value is Transform3D:
			enemy.transform = transform_value as Transform3D
		enemy.velocity = Vector3.ZERO
		var brain: Node = enemy.get_node_or_null("EnemyBrain")
		if brain != null and brain.has_method("reset_perception"):
			brain.call("reset_perception")
		var hit_receiver: Node = enemy.get_node_or_null("HitReceiver")
		if hit_receiver != null and hit_receiver.has_method("reset_health"):
			hit_receiver.call("reset_health")
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	configure_player()
	GameState.set_objective("Watch four personalities route around walls and weigh the dangerous shortcut differently.")
	show_message("Tactical Navigation Lab reset #" + str(reset_count) + ".")
	call_deferred("begin_trial_after_navigation_sync")


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
	var label := make_label(label_text, position_value + Vector3(0.0, 0.16, 10.2), color.lightened(0.45), 23, 0.0058)
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
	var routes: Array[Dictionary] = []
	for enemy: CharacterBody3D in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var component: TacticalNavigationAgent = enemy.get_node_or_null("TacticalNavigationAgent") as TacticalNavigationAgent
		if component != null:
			routes.append(component.get_debug_data())
	return {
		"tactical_navigation_lab": true,
		"hazards_active": hazards_active,
		"enemy_count": enemies.size(),
		"hazard_count": hazards.size(),
		"trial_count": trial_count,
		"reset_count": reset_count,
		"routes": routes,
	}
