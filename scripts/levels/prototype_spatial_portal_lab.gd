extends Node3D
class_name PrototypeSpatialPortalLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const CrateScene: PackedScene = preload(
	"res://scenes/actors/interactables/breakable_wooden_crate.tscn"
)
const LabLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_spatial_portal_lab_loadout.tres"
)

@export var enable_editor_f8_reset: bool = true
@export_range(0.03, 0.5, 0.01) var readout_refresh_interval: float = 0.08
@export var safety_reset_height: float = -5.0

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var readout: Label = get_node_or_null(
	"PortalHUD/Panel/Margin/Readout"
) as Label

var portals: Array[SpatialPortal3D] = []
var traversal_entry: SpatialPortal3D = null
var moving_exit: SpatialPortal3D = null
var loop_entry: SpatialPortal3D = null
var loop_exit: SpatialPortal3D = null
var projectile_entry: SpatialPortal3D = null
var projectile_exit: SpatialPortal3D = null
var momentum_crate: RigidBody3D = null
var loop_orb: RigidBody3D = null
var target_crate: Node3D = null
var readout_timer: float = 0.0
var teleport_count: int = 0
var last_traveler_name: String = "none"
var last_speed_delta: float = 0.0
var exit_configuration: int = 0
var stat_snapshot: Dictionary = {}
var initial_player_transform: Transform3D

const EXIT_CONFIGURATIONS: Array[Dictionary] = [
	{
		"position": Vector3(4.8, 1.8, -3.0),
		"rotation": Vector3(0.0, -90.0, 0.0),
		"name": "SIDEWAYS LEFT"
	},
	{
		"position": Vector3(-4.8, 3.4, -4.8),
		"rotation": Vector3(0.0, 45.0, 0.0),
		"name": "ELEVATED DIAGONAL"
	},
	{
		"position": Vector3(0.0, 6.0, -8.0),
		"rotation": Vector3(0.0, 180.0, 0.0),
		"name": "HIGH REVERSE"
	},
]


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("spatial_portal_lab")
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	build_laboratory()
	configure_player()
	if player != null:
		initial_player_transform = player.global_transform
	GameState.set_objective(
		"Carry momentum through linked portals, watch the falling loop, and redirect Firebolt."
	)
	show_message(
		"Spatial Portal Laboratory online. Interact changes the moving exit and relaunches the momentum crate."
	)
	refresh_readout()


func _process(delta: float) -> void:
	readout_timer -= delta
	if readout_timer <= 0.0:
		readout_timer = maxf(readout_refresh_interval, 0.03)
		refresh_readout()
	if player != null and player.global_position.y < safety_reset_height:
		reset_player_only()
	if loop_orb != null and (
		loop_orb.global_position.y < -2.0
		or loop_orb.global_position.y > 14.0
	):
		reset_loop_orb()


func _exit_tree() -> void:
	for stat_name: Variant in stat_snapshot.keys():
		GameState.set_stat(str(stat_name), int(stat_snapshot[stat_name]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		cycle_moving_exit()
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if (
		key_event.pressed
		and not key_event.echo
		and key_event.physical_keycode == KEY_F8
		and enable_editor_f8_reset
		and OS.has_feature("editor")
	):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func configure_player() -> void:
	if player == null:
		return
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null:
		ability_caster.set("loadout", LabLoadout.duplicate(true))
		ability_caster.set("current_ability_index", 0)
		if ability_caster.has_method("align_focus_menu_to_current_ability"):
			ability_caster.call("align_focus_menu_to_current_ability")
		if ability_caster.has_method("emit_current_ability"):
			ability_caster.call("emit_current_ability")
	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	if aerial != null:
		aerial.set("double_jump_unlocked", false)
		aerial.set("hover_unlocked", false)
		aerial.set("flight_unlocked", false)
	for resource_name: String in ["health", "stamina", "mana", "stance"]:
		var maximum_name: String = "max_" + resource_name
		GameState.set_stat(resource_name, GameState.get_stat(maximum_name))
	GameState.set_stat("fire", maxi(GameState.get_stat("fire"), 5))


func build_laboratory() -> void:
	create_static_box(
		"Floor",
		Vector3(0.0, -0.5, -1.0),
		Vector3(30.0, 1.0, 28.0),
		Color(0.035, 0.045, 0.065, 1.0)
	)
	create_static_box(
		"BackWall",
		Vector3(0.0, 5.0, -13.0),
		Vector3(30.0, 10.0, 0.6),
		Color(0.055, 0.065, 0.09, 1.0)
	)
	create_instruction_board()
	create_traversal_and_crate_station()
	create_momentum_loop_station()
	create_projectile_station()


func create_instruction_board() -> void:
	add_world_label(
		"SPATIAL PORTAL LABORATORY\n"
		+ "Walk or launch through BLUE → ORANGE  •  Momentum changes direction, not magnitude\n"
		+ "INTERACT moves the orange exit and relaunches the crate  •  Cast FIREBOLT in the gold lane  •  RESET restores",
		Vector3(0.0, 7.4, -12.5),
		Color(0.72, 0.9, 1.0, 1.0),
		25
	)


func create_traversal_and_crate_station() -> void:
	var pair: Array[SpatialPortal3D] = create_portal_pair(
		"Traversal",
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.8, 4.0)),
		transform_from_degrees(
			Vector3(4.8, 1.8, -3.0),
			Vector3(0.0, -90.0, 0.0)
		),
		Color(0.16, 0.68, 1.0, 1.0),
		Color(1.0, 0.48, 0.12, 1.0)
	)
	traversal_entry = pair[0]
	moving_exit = pair[1]
	add_world_label(
		"TRAVERSAL + CRATE MOMENTUM\nRun through—or INTERACT to fire the 12 m/s crate",
		Vector3(0.0, 5.1, 4.0),
		Color(0.45, 0.82, 1.0, 1.0),
		22
	)
	var exit_label: Label3D = add_world_label(
		"MOVING EXIT\nSIDEWAYS LEFT",
		Vector3(4.8, 4.45, -3.0),
		Color(1.0, 0.62, 0.2, 1.0),
		21
	)
	exit_label.name = "MovingExitConfigurationLabel"
	spawn_momentum_crate()


func create_momentum_loop_station() -> void:
	var pair: Array[SpatialPortal3D] = create_portal_pair(
		"Loop",
		transform_from_degrees(
			Vector3(-8.0, 0.75, -5.0),
			Vector3(-90.0, 0.0, 0.0)
		),
		transform_from_degrees(
			Vector3(-8.0, 8.6, -5.0),
			Vector3(90.0, 0.0, 0.0)
		),
		Color(0.18, 0.82, 1.0, 1.0),
		Color(1.0, 0.34, 0.7, 1.0)
	)
	loop_entry = pair[0]
	loop_exit = pair[1]
	loop_entry.keep_characters_upright = true
	loop_exit.keep_characters_upright = true
	add_world_label(
		"FALLING MOMENTUM LOOP\nThe steel orb keeps accelerating through each pass",
		Vector3(-8.0, 10.0, -5.0),
		Color(0.6, 0.88, 1.0, 1.0),
		22
	)
	spawn_loop_orb()


func create_projectile_station() -> void:
	var pair: Array[SpatialPortal3D] = create_portal_pair(
		"Projectile",
		Transform3D(Basis.IDENTITY, Vector3(8.0, 1.7, 2.0)),
		transform_from_degrees(
			Vector3(3.5, 1.7, -8.0),
			Vector3(0.0, 90.0, 0.0)
		),
		Color(0.15, 0.74, 1.0, 1.0),
		Color(1.0, 0.74, 0.12, 1.0)
	)
	projectile_entry = pair[0]
	projectile_exit = pair[1]
	add_world_label(
		"FIREBOLT REDIRECTION\nStand on the gold mark and cast through BLUE",
		Vector3(8.0, 5.0, 2.0),
		Color(1.0, 0.76, 0.24, 1.0),
		22
	)
	create_floor_marker(Vector3(8.0, 0.02, 6.5), Color(1.0, 0.7, 0.1, 1.0))
	target_crate = CrateScene.instantiate() as Node3D
	if target_crate != null:
		target_crate.name = "PortalProjectileTarget"
		target_crate.position = Vector3(9.0, 1.0, -8.0)
		add_child(target_crate)
	add_world_label(
		"PORTAL TARGET",
		Vector3(9.0, 3.1, -8.0),
		Color(1.0, 0.5, 0.18, 1.0),
		21
	)


func create_portal_pair(
	pair_name: String,
	entry_transform: Transform3D,
	exit_transform: Transform3D,
	entry_color: Color,
	exit_color: Color
) -> Array[SpatialPortal3D]:
	var entry: SpatialPortal3D = SpatialPortal3D.new()
	entry.name = pair_name + "Entry"
	entry.portal_id = pair_name.to_snake_case() + "_entry"
	entry.transform = entry_transform
	entry.portal_color = entry_color
	add_child(entry)

	var destination: SpatialPortal3D = SpatialPortal3D.new()
	destination.name = pair_name + "Exit"
	destination.portal_id = pair_name.to_snake_case() + "_exit"
	destination.transform = exit_transform
	destination.portal_color = exit_color
	add_child(destination)

	entry.set_linked_portal(destination)
	destination.set_linked_portal(entry)
	entry.traveler_teleported.connect(_on_traveler_teleported)
	destination.traveler_teleported.connect(_on_traveler_teleported)
	portals.append(entry)
	portals.append(destination)
	var result: Array[SpatialPortal3D] = [entry, destination]
	return result


func spawn_momentum_crate() -> void:
	if momentum_crate != null and is_instance_valid(momentum_crate):
		momentum_crate.queue_free()
	momentum_crate = create_rigid_box(
		"MomentumCrate",
		Vector3(0.0, 1.0, 8.0),
		Vector3(1.2, 1.2, 1.2),
		8.0,
		Color(0.28, 0.62, 0.9, 1.0)
	)
	momentum_crate.linear_velocity = Vector3(0.0, 0.0, -12.0)


func spawn_loop_orb() -> void:
	if loop_orb != null and is_instance_valid(loop_orb):
		loop_orb.queue_free()
	loop_orb = RigidBody3D.new()
	loop_orb.name = "LoopOrb"
	loop_orb.position = Vector3(-8.0, 5.6, -5.0)
	loop_orb.mass = 12.0
	loop_orb.linear_damp = 0.0
	loop_orb.angular_damp = 0.05
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.48
	collision.shape = shape
	loop_orb.add_child(collision)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.48
	mesh.height = 0.96
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(
		Color(0.68, 0.78, 0.92, 1.0),
		0.9,
		1.0,
		false
	)
	loop_orb.add_child(mesh_instance)
	add_child(loop_orb)


func reset_loop_orb() -> void:
	if loop_orb == null:
		spawn_loop_orb()
		return
	loop_orb.global_position = Vector3(-8.0, 5.6, -5.0)
	loop_orb.linear_velocity = Vector3.ZERO
	loop_orb.angular_velocity = Vector3.ZERO


func cycle_moving_exit() -> void:
	if moving_exit == null:
		return
	exit_configuration = (exit_configuration + 1) % EXIT_CONFIGURATIONS.size()
	var configuration: Dictionary = EXIT_CONFIGURATIONS[exit_configuration]
	moving_exit.position = configuration["position"] as Vector3
	moving_exit.rotation_degrees = configuration["rotation"] as Vector3
	var label: Label3D = get_node_or_null("MovingExitConfigurationLabel") as Label3D
	if label == null:
		label = add_world_label(
			"MOVING EXIT\n" + str(configuration["name"]),
			moving_exit.position + Vector3.UP * 2.65,
			Color(1.0, 0.62, 0.2, 1.0),
			21
		)
		label.name = "MovingExitConfigurationLabel"
	else:
		label.text = "MOVING EXIT\n" + str(configuration["name"])
		label.position = moving_exit.position + Vector3.UP * 2.65
	spawn_momentum_crate()
	show_message(
		"Exit configuration: "
		+ str(configuration["name"])
		+ ". The crate relaunched at 12 m/s."
	)


func _on_traveler_teleported(
	traveler: Node3D,
	_destination: SpatialPortal3D,
	entry_speed: float,
	exit_speed: float
) -> void:
	teleport_count += 1
	last_traveler_name = str(traveler.name)
	last_speed_delta = absf(exit_speed - entry_speed)
	if traveler == momentum_crate:
		show_message(
			"Crate crossed at "
			+ str(snappedf(exit_speed, 0.1))
			+ " m/s. Direction changed; speed was conserved."
		)


func refresh_readout() -> void:
	if readout == null:
		return
	var orb_speed: float = (
		loop_orb.linear_velocity.length()
		if loop_orb != null
		else 0.0
	)
	var exit_name: String = str(EXIT_CONFIGURATIONS[exit_configuration]["name"])
	readout.text = (
		"PORTALS  •  Crossings "
		+ str(teleport_count)
		+ "  •  Last "
		+ last_traveler_name
		+ "  •  |Δspeed| "
		+ str(snappedf(last_speed_delta, 0.01))
		+ " m/s\nExit "
		+ exit_name
		+ "  •  Loop orb "
		+ str(snappedf(orb_speed, 0.1))
		+ " m/s  •  INTERACT moves exit + relaunches crate"
	)


func transform_from_degrees(
	position_value: Vector3,
	rotation_degrees_value: Vector3
) -> Transform3D:
	var rotation_radians: Vector3 = Vector3(
		deg_to_rad(rotation_degrees_value.x),
		deg_to_rad(rotation_degrees_value.y),
		deg_to_rad(rotation_degrees_value.z)
	)
	return Transform3D(Basis.from_euler(rotation_radians), position_value)


func create_rigid_box(
	body_name: String,
	position_value: Vector3,
	size_value: Vector3,
	mass_value: float,
	color: Color
) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.name = body_name
	body.position = position_value
	body.mass = mass_value
	body.linear_damp = 0.05
	body.angular_damp = 0.2
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(
		color,
		0.35,
		1.0,
		false
	)
	body.add_child(mesh_instance)
	add_child(body)
	return body


func create_static_box(
	body_name: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = body_name
	body.position = position_value
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(
		color,
		0.08,
		1.0,
		false
	)
	body.add_child(mesh_instance)
	add_child(body)
	return body


func create_floor_marker(position_value: Vector3, color: Color) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "CastingMarker"
	marker.position = position_value
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.85
	mesh.bottom_radius = 0.85
	mesh.height = 0.04
	marker.mesh = mesh
	marker.material_override = ElementVisuals.make_material(
		color,
		2.0,
		1.0,
		false
	)
	add_child(marker)


func add_world_label(
	text_value: String,
	position_value: Vector3,
	color: Color,
	font_size: int
) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func reset_player_only() -> void:
	if player == null:
		return
	player.global_transform = initial_player_transform
	player.velocity = Vector3.ZERO
	show_message("The portal safety field returned Grace to the entrance.")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"spatial_portal_lab": true,
		"portals": portals.size(),
		"teleports": teleport_count,
		"last_traveler": last_traveler_name,
		"last_speed_delta": last_speed_delta,
		"exit_configuration": exit_configuration,
		"loop_speed": (
			loop_orb.linear_velocity.length()
			if loop_orb != null
			else 0.0
		),
	}
