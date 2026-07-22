extends Node3D
class_name PrototypeEcholocationChamber

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const EchoLoadout: Resource = preload("res://data/loadouts/grace_echolocation_room_loadout.tres")

@export var room_width: float = 16.0
@export var room_length: float = 28.0
@export var wall_height: float = 3.2
@export var architecture_reveal_seconds: float = 3.2
@export var goal_reveal_seconds: float = 4.6

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D

var geometry_root: Node3D = null
var exit_trigger: Area3D = null
var initial_player_transform: Transform3D
var solved: bool = false
var reset_count: int = 0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	configure_dark_environment()
	build_chamber()
	configure_player()

	if player != null:
		initial_player_transform = player.transform
		player.add_to_group("player")

	if exit_trigger != null and not exit_trigger.body_entered.is_connected(_on_exit_body_entered):
		exit_trigger.body_entered.connect(_on_exit_body_entered)

	GameState.set_objective("Cast Echolocation to map the chamber, then reach the resonant beacon.")
	show_message("There is no light here. Listen to the room instead.")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != KEY_F8:
		return

	get_viewport().set_input_as_handled()
	reset_chamber()


func configure_dark_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "LightlessEnvironment"

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 1.0)
	environment.background_energy_multiplier = 0.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.0, 0.0, 0.0, 1.0)
	environment.ambient_light_energy = 0.0
	world_environment.environment = environment
	add_child(world_environment)


func configure_player() -> void:
	if player == null:
		return

	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null:
		ability_caster.set("loadout", EchoLoadout)
		ability_caster.set("current_ability_index", 0)
		if ability_caster.has_method("align_focus_menu_to_current_ability"):
			ability_caster.call("align_focus_menu_to_current_ability")
		if ability_caster.has_method("emit_current_ability"):
			ability_caster.call("emit_current_ability")

	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	create_player_soul_anchor()


func create_player_soul_anchor() -> void:
	if player == null or player.get_node_or_null("EchoAnchor") != null:
		return

	var anchor := Node3D.new()
	anchor.name = "EchoAnchor"
	player.add_child(anchor)

	var sound_color: Color = ElementVisuals.get_element_color("sound")
	ElementVisuals.add_torus(
		anchor,
		"FootRing",
		0.22,
		0.28,
		sound_color,
		Vector3(0.0, -0.92, 0.0),
		Vector3.ZERO,
		1.2,
		0.42
	)
	ElementVisuals.add_sphere(
		anchor,
		"SoulPoint",
		0.055,
		sound_color.lightened(0.2),
		Vector3(0.0, 0.55, 0.0),
		Vector3.ONE,
		1.8,
		0.62
	)


func build_chamber() -> void:
	geometry_root = Node3D.new()
	geometry_root.name = "EchoGeometry"
	add_child(geometry_root)

	create_floor_collision()
	create_floor_echo_tiles()
	create_boundary_walls()
	create_internal_maze()
	create_resonant_beacon()
	create_exit_trigger()


func create_floor_collision() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "InvisibleFloorCollision"
	floor_body.position = Vector3(0.0, -0.5, 0.0)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(room_width, 1.0, room_length)
	collision.shape = shape
	floor_body.add_child(collision)
	geometry_root.add_child(floor_body)


func create_floor_echo_tiles() -> void:
	var floor_color: Color = Color(0.12, 0.42, 0.72, 1.0)
	var tile_size := Vector3(3.92, 0.06, 3.92)

	for x_index: int in range(4):
		for z_index: int in range(7):
			var x_position: float = -6.0 + float(x_index) * 4.0
			var z_position: float = -12.0 + float(z_index) * 4.0
			create_echo_visual_box(
				"FloorTile_" + str(x_index) + "_" + str(z_index),
				Vector3(x_position, 0.025, z_position),
				tile_size,
				floor_color,
				architecture_reveal_seconds
			)


func create_boundary_walls() -> void:
	var wall_color: Color = ElementVisuals.get_element_color("sound")
	create_echo_box("LeftBoundary", Vector3(-8.0, wall_height * 0.5, 0.0), Vector3(0.5, wall_height, room_length), wall_color)
	create_echo_box("RightBoundary", Vector3(8.0, wall_height * 0.5, 0.0), Vector3(0.5, wall_height, room_length), wall_color)
	create_echo_box("FrontBoundary", Vector3(0.0, wall_height * 0.5, 14.0), Vector3(room_width, wall_height, 0.5), wall_color)
	create_echo_box("BackBoundary", Vector3(0.0, wall_height * 0.5, -14.0), Vector3(room_width, wall_height, 0.5), wall_color)


func create_internal_maze() -> void:
	var wall_color: Color = ElementVisuals.get_element_color("sound")
	var accent_color: Color = Color(0.35, 0.82, 1.0, 1.0)

	create_echo_box("ZigWallA", Vector3(-3.0, wall_height * 0.5, 6.0), Vector3(10.0, wall_height, 0.5), wall_color)
	create_echo_box("ZigWallB", Vector3(3.0, wall_height * 0.5, 1.0), Vector3(10.0, wall_height, 0.5), wall_color)
	create_echo_box("ZigWallC", Vector3(-3.0, wall_height * 0.5, -4.0), Vector3(10.0, wall_height, 0.5), wall_color)
	create_echo_box("ZigWallD", Vector3(3.0, wall_height * 0.5, -9.0), Vector3(10.0, wall_height, 0.5), wall_color)

	create_echo_pillar("PillarA", Vector3(5.35, 1.35, 4.2), 0.6, 2.7, accent_color)
	create_echo_pillar("PillarB", Vector3(-5.2, 1.35, -1.2), 0.6, 2.7, accent_color)
	create_echo_pillar("PillarC", Vector3(5.25, 1.35, -6.3), 0.6, 2.7, accent_color)

	create_echo_box("GoalArchLeft", Vector3(-6.3, 1.55, -11.8), Vector3(0.45, 3.1, 0.65), accent_color)
	create_echo_box("GoalArchRight", Vector3(-3.7, 1.55, -11.8), Vector3(0.45, 3.1, 0.65), accent_color)
	create_echo_box("GoalArchTop", Vector3(-5.0, 3.0, -11.8), Vector3(3.0, 0.45, 0.65), accent_color)


func create_resonant_beacon() -> void:
	var beacon := Node3D.new()
	beacon.name = "ResonantBeacon"
	beacon.position = Vector3(-5.0, 1.2, -12.3)

	var beacon_color: Color = Color(1.0, 0.72, 0.16, 1.0)
	ElementVisuals.add_torus(beacon, "OuterRing", 0.72, 0.84, beacon_color, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), 3.2, 0.9)
	ElementVisuals.add_torus(beacon, "CrossRing", 0.48, 0.58, beacon_color.lightened(0.18), Vector3.ZERO, Vector3(0.0, 0.0, 90.0), 2.8, 0.82)
	ElementVisuals.add_sphere(beacon, "Core", 0.2, beacon_color.lightened(0.28), Vector3.ZERO, Vector3.ONE, 4.0, 0.95)

	var receiver := RevealableReceiver.new()
	receiver.name = "RevealableReceiver"
	receiver.starts_hidden = true
	receiver.reveal_duration_override = goal_reveal_seconds
	receiver.required_detection_tags = ["sound"]
	receiver.hide_visuals_when_hidden = true
	receiver.disable_collision_when_hidden = false
	receiver.reveal_message = "A resonant beacon answers from the far side of the chamber."
	beacon.add_child(receiver)
	geometry_root.add_child(beacon)


func create_exit_trigger() -> void:
	exit_trigger = Area3D.new()
	exit_trigger.name = "ExitTrigger"
	exit_trigger.position = Vector3(-5.0, 1.2, -12.0)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.4, 2.4)
	collision.shape = shape
	exit_trigger.add_child(collision)
	add_child(exit_trigger)


func create_echo_box(
	name_value: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color,
	reveal_duration: float = -1.0
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
	mesh_instance.material_override = ElementVisuals.make_material(color, 2.25, 0.82, true)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_instance)

	add_reveal_receiver(body, reveal_duration)
	geometry_root.add_child(body)
	return body


func create_echo_visual_box(
	name_value: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color,
	reveal_duration: float
) -> Node3D:
	var visual_root := Node3D.new()
	visual_root.name = name_value
	visual_root.position = position_value

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(color, 1.45, 0.46, true)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(mesh_instance)

	add_reveal_receiver(visual_root, reveal_duration)
	geometry_root.add_child(visual_root)
	return visual_root


func create_echo_pillar(
	name_value: String,
	position_value: Vector3,
	radius: float,
	height: float,
	color: Color
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_value
	body.position = position_value

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(color, 2.4, 0.78, true)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_instance)

	add_reveal_receiver(body, architecture_reveal_seconds)
	geometry_root.add_child(body)
	return body


func add_reveal_receiver(target: Node, reveal_duration: float = -1.0) -> void:
	var receiver := RevealableReceiver.new()
	receiver.name = "RevealableReceiver"
	receiver.starts_hidden = true
	receiver.reveal_duration_override = architecture_reveal_seconds if reveal_duration <= 0.0 else reveal_duration
	receiver.required_detection_tags = ["sound"]
	receiver.hide_visuals_when_hidden = true
	receiver.disable_collision_when_hidden = false
	receiver.reveal_message = ""
	target.add_child(receiver)


func _on_exit_body_entered(body: Node3D) -> void:
	if solved or body == null:
		return
	if body != player and not body.is_in_group("player"):
		return

	solved = true
	GameState.set_objective("Echo chamber crossed.")
	show_message("The beacon answers clearly. You mapped the darkness by sound.")
	GameFeedback.play("heavy_impact", {"source": "echolocation_chamber_complete"})


func reset_chamber() -> void:
	reset_count += 1

	for receiver: Node in get_tree().get_nodes_in_group("detectable"):
		if receiver == null or not is_instance_valid(receiver):
			continue
		if not is_ancestor_of(receiver):
			continue
		if receiver.has_method("reset_reveal"):
			receiver.call("reset_reveal")

	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO

	solved = false
	configure_player()
	GameState.set_objective("Cast Echolocation to map the chamber, then reach the resonant beacon.")
	show_message("Echo chamber reset #" + str(reset_count) + ".")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	var visible_count: int = 0
	var detectable_count: int = 0

	for receiver: Node in get_tree().get_nodes_in_group("detectable"):
		if receiver == null or not is_instance_valid(receiver) or not is_ancestor_of(receiver):
			continue
		detectable_count += 1
		if bool(receiver.get("is_revealed")):
			visible_count += 1

	return {
		"echolocation_chamber": true,
		"solved": solved,
		"detectable_count": detectable_count,
		"currently_revealed": visible_count,
		"reset_count": reset_count,
	}
