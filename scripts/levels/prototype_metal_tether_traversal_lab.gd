extends Node3D
class_name PrototypeMetalTetherTraversalLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const AnchorScene: PackedScene = preload("res://scenes/traversal/metal_tether_anchor.tscn")
const LabLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_metal_tether_lab_loadout.tres"
)

@export var enable_editor_f8_reset: bool = true
@export var safety_reset_height: float = -4.5
@export_range(0.02, 0.5, 0.01) var readout_refresh_interval: float = 0.06
@export_range(0.1, 3.0, 0.05) var moving_anchor_speed: float = 0.72
@export_range(0.5, 8.0, 0.25) var moving_anchor_amplitude: float = 4.0

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var readout: Label = get_node_or_null("TetherHUD/Panel/Margin/Readout") as Label

var tether_controller: MetalTetherSpellController = null
var aerial_locomotion: PlayerAerialLocomotion = null
var action_state: PlayerActionState = null
var initial_player_transform: Transform3D
var stat_snapshot: Dictionary = {}
var anchors: Array[MetalTetherAnchor3D] = []
var moving_anchor_body: AnimatableBody3D = null
var moving_anchor_origin: Vector3 = Vector3.ZERO
var movable_load: RigidBody3D = null
var movable_load_transform: Transform3D
var elapsed: float = 0.0
var readout_timer: float = 0.0
var reset_count: int = 0
var goal_reached: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("metal_tether_traversal_lab")
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	build_laboratory()
	configure_player()
	if player != null:
		initial_player_transform = player.global_transform
		tether_controller = player.get_node_or_null("MetalTetherController") as MetalTetherSpellController
		aerial_locomotion = player.get_node_or_null("AerialLocomotion") as PlayerAerialLocomotion
		action_state = player.get_node_or_null("PlayerActionState") as PlayerActionState
	GameState.set_objective("Use Metal Tether to swing across the pit and land on the Foundry Beacon platform.")
	show_message("Metal Tether Laboratory online. Aim at a gold anchor and hold Cast.")
	refresh_readout()


func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	readout_timer -= delta
	if readout_timer <= 0.0:
		readout_timer = maxf(readout_refresh_interval, 0.02)
		refresh_readout()

	if player != null and player.global_position.y < safety_reset_height:
		reset_player_only("The foundry safety field returned Grace to the launch deck.")


func _physics_process(_delta: float) -> void:
	if moving_anchor_body == null:
		return
	moving_anchor_body.global_position = (
		moving_anchor_origin
		+ Vector3.RIGHT * sin(elapsed * moving_anchor_speed) * moving_anchor_amplitude
	)


func _exit_tree() -> void:
	if tether_controller != null:
		tether_controller.release_tether("scene exit", false)
	restore_stat_snapshot()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if (
		key_event.pressed
		and not key_event.echo
		and key_event.physical_keycode == KEY_F8
	):
		get_viewport().set_input_as_handled()
		reset_lab()


func configure_player() -> void:
	if player == null:
		return
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null:
		var runtime_loadout: AbilityLoadout = LabLoadout.duplicate(true) as AbilityLoadout
		ability_caster.set("loadout", runtime_loadout)
		ability_caster.set("current_ability_index", 0)
		if ability_caster.has_method("align_focus_menu_to_current_ability"):
			ability_caster.call("align_focus_menu_to_current_ability")
		if ability_caster.has_method("emit_current_ability"):
			ability_caster.call("emit_current_ability")

	var aerial: PlayerAerialLocomotion = player.get_node_or_null("AerialLocomotion") as PlayerAerialLocomotion
	if aerial != null:
		aerial.double_jump_unlocked = false
		aerial.hover_unlocked = false
		aerial.flight_unlocked = false
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("metal", maxi(GameState.get_stat("metal"), 5))
	GameState.set_stat("dexterity", maxi(GameState.get_stat("dexterity"), 5))


func build_laboratory() -> void:
	create_static_box(
		"SafetyFloor",
		Vector3(0.0, -6.0, -3.0),
		Vector3(34.0, 0.8, 42.0),
		Color(0.035, 0.045, 0.06, 1.0)
	)
	create_static_box(
		"LaunchDeck",
		Vector3(0.0, 0.0, 10.0),
		Vector3(9.0, 0.8, 7.0),
		Color(0.19, 0.21, 0.25, 1.0),
		0.28
	)
	create_static_box(
		"MidDeck",
		Vector3(8.0, 2.2, -2.5),
		Vector3(5.5, 0.7, 5.5),
		Color(0.28, 0.22, 0.12, 1.0),
		0.42
	)
	create_static_box(
		"GoalDeck",
		Vector3(0.0, 4.0, -16.0),
		Vector3(8.5, 0.8, 7.0),
		Color(0.36, 0.28, 0.1, 1.0),
		0.72
	)
	create_static_box(
		"LoadTestDeck",
		Vector3(9.0, 0.0, 9.0),
		Vector3(8.0, 0.8, 8.0),
		Color(0.12, 0.16, 0.2, 1.0),
		0.18
	)

	create_fixed_anchor(
		"LaunchSwingAnchor",
		Vector3(0.0, 8.2, 3.0),
		"LAUNCH ANCHOR",
		6200.0,
		false
	)
	create_fixed_anchor(
		"MidSwingAnchor",
		Vector3(5.5, 10.5, -5.0),
		"MID ANCHOR",
		6200.0,
		false
	)
	create_fixed_anchor(
		"GoalSwingAnchor",
		Vector3(0.0, 13.0, -12.5),
		"GOAL ANCHOR",
		6200.0,
		false
	)
	create_fixed_anchor(
		"BreakawayAnchor",
		Vector3(-7.8, 7.0, 0.5),
		"BREAKAWAY • 900 N",
		900.0,
		true
	)
	create_moving_anchor(Vector3(-2.0, 10.2, -6.5))
	create_movable_load(Vector3(9.0, 1.0, 9.0))
	create_instruction_board()
	create_goal_beacon()
	create_airflow_zone_marker()


func create_fixed_anchor(
	body_name: String,
	position_value: Vector3,
	label_text: String,
	strength: float,
	is_breakable: bool
) -> MetalTetherAnchor3D:
	var body: StaticBody3D = AnchorScene.instantiate() as StaticBody3D
	body.name = body_name
	body.position = position_value
	var anchor: MetalTetherAnchor3D = body.get_node("MetalTetherAnchor") as MetalTetherAnchor3D
	anchor.anchor_id = body_name.to_snake_case()
	anchor.display_name = label_text
	anchor.breakable = is_breakable
	anchor.break_strength = strength
	anchor.anchor_broken.connect(_on_anchor_broken)
	add_child(body)
	anchors.append(anchor)
	add_world_label(
		label_text,
		position_value + Vector3.UP * 0.9,
		Color(1.0, 0.76, 0.2, 1.0),
		25
	)
	return anchor


func create_moving_anchor(position_value: Vector3) -> void:
	moving_anchor_body = AnimatableBody3D.new()
	moving_anchor_body.name = "MovingAnchorBody"
	moving_anchor_body.position = position_value
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.5
	collision.shape = shape
	moving_anchor_body.add_child(collision)

	var anchor: MetalTetherAnchor3D = MetalTetherAnchor3D.new()
	anchor.name = "MetalTetherAnchor"
	anchor.anchor_id = "moving_anchor"
	anchor.display_name = "MOVING CRANE ANCHOR"
	anchor.break_strength = 6800.0
	moving_anchor_body.add_child(anchor)
	build_anchor_visual(anchor, Color(1.0, 0.62, 0.08, 1.0))
	add_child(moving_anchor_body)
	moving_anchor_origin = moving_anchor_body.global_position
	anchors.append(anchor)
	var label: Label3D = add_world_label(
		"MOVING CRANE ANCHOR",
		Vector3(0.0, 0.9, 0.0),
		Color(1.0, 0.68, 0.18, 1.0),
		24,
		anchor
	)
	label.name = "MovingAnchorLabel"


func create_movable_load(position_value: Vector3) -> void:
	movable_load = RigidBody3D.new()
	movable_load.name = "MovableTetherLoad"
	movable_load.mass = 6.0
	movable_load.position = position_value
	movable_load.linear_damp = 1.2
	movable_load.angular_damp = 1.5

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.6, 1.6, 1.6)
	collision.shape = shape
	movable_load.add_child(collision)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.6, 1.6, 1.6)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(
		Color(0.32, 0.36, 0.42, 1.0),
		0.25,
		1.0,
		false
	)
	movable_load.add_child(mesh_instance)

	var anchor: MetalTetherAnchor3D = MetalTetherAnchor3D.new()
	anchor.name = "MetalTetherAnchor"
	anchor.position = Vector3.UP * 1.1
	anchor.anchor_id = "movable_load_anchor"
	anchor.display_name = "6 KG TETHER LOAD"
	anchor.break_strength = 5200.0
	anchor.maximum_transferred_force = 3600.0
	movable_load.add_child(anchor)
	build_anchor_visual(anchor, Color(0.76, 0.84, 1.0, 1.0))
	add_world_label(
		"6 KG TETHER LOAD\nPULL IT FROM THE DECK",
		Vector3(0.0, 1.15, 0.0),
		Color(0.72, 0.84, 1.0, 1.0),
		22,
		anchor
	)
	add_child(movable_load)
	movable_load_transform = movable_load.global_transform
	anchors.append(anchor)


func build_anchor_visual(anchor: Node3D, color: Color) -> void:
	var core: MeshInstance3D = MeshInstance3D.new()
	core.name = "AnchorCore"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	core.mesh = sphere
	core.material_override = ElementVisuals.make_material(color, 1.8, 1.0, false)
	anchor.add_child(core)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "AnchorRing"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.32
	torus.outer_radius = 0.42
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring.material_override = core.material_override
	anchor.add_child(ring)


func create_instruction_board() -> void:
	create_static_box(
		"InstructionBoard",
		Vector3(0.0, 2.5, 13.2),
		Vector3(12.8, 3.3, 0.22),
		Color(0.025, 0.035, 0.055, 1.0),
		0.16
	)
	add_world_label(
		"METAL TETHER TRAVERSAL\nAim at a GOLD ANCHOR and HOLD CAST\nMove to pump the swing • D-pad Up/Down or R/F reels • Release Cast to launch\nThe gold line predicts your free swing. F8 resets the foundry.",
		Vector3(0.0, 2.5, 13.05),
		Color(1.0, 0.78, 0.28, 1.0),
		28
	)


func create_goal_beacon() -> void:
	var beacon: Node3D = Node3D.new()
	beacon.name = "FoundryBeacon"
	beacon.position = Vector3(0.0, 5.2, -16.0)
	add_child(beacon)
	ElementVisuals.add_torus(
		beacon,
		"BeaconRing",
		0.68,
		0.9,
		Color(1.0, 0.72, 0.16, 1.0),
		Vector3.ZERO,
		Vector3(90.0, 0.0, 0.0),
		2.4,
		0.9
	)
	ElementVisuals.add_capsule(
		beacon,
		"BeaconCore",
		0.22,
		1.4,
		Color(0.82, 0.9, 1.0, 1.0),
		Vector3.ZERO,
		Vector3.ONE,
		Vector3.ZERO,
		2.2,
		0.9
	)
	add_world_label(
		"FOUNDRY BEACON\nLAND HERE",
		Vector3(0.0, 1.7, 0.0),
		Color(1.0, 0.82, 0.3, 1.0),
		26,
		beacon
	)

	var trigger: Area3D = Area3D.new()
	trigger.name = "GoalTrigger"
	trigger.position = Vector3(0.0, 5.0, -16.0)
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(7.8, 2.4, 6.2)
	collision.shape = shape
	trigger.add_child(collision)
	trigger.body_entered.connect(_on_goal_body_entered)
	add_child(trigger)


func create_airflow_zone_marker() -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "CrosswindZoneMarker"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(10.0, 0.04, 8.0)
	marker.mesh = mesh
	marker.position = Vector3(0.0, 0.05, -6.5)
	marker.material_override = ElementVisuals.make_material(
		Color(0.16, 0.62, 0.86, 1.0),
		0.75,
		0.28,
		true
	)
	add_child(marker)
	add_world_label(
		"4 m/s CROSSWIND\nTHE SWING STILL SAMPLES AIRFLOW",
		Vector3(0.0, 0.65, -6.5),
		Color(0.42, 0.82, 1.0, 1.0),
		22
	)


func create_static_box(
	body_name: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color,
	emission_energy: float = 0.08
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
		emission_energy,
		1.0,
		false
	)
	body.add_child(mesh_instance)
	add_child(body)
	return body


func add_world_label(
	text_value: String,
	position_value: Vector3,
	color: Color,
	font_size: int,
	parent: Node3D = null
) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = color
	var target_parent: Node3D = parent if parent != null else self
	target_parent.add_child(label)
	return label


func refresh_readout() -> void:
	if readout == null:
		return
	var data: Dictionary = (
		tether_controller.get_debug_data()
		if tether_controller != null
		else {}
	)
	var airflow: Vector3 = data.get("airflow_acceleration", Vector3.ZERO)
	var is_active: bool = bool(data.get("active", false))
	var anchor_name: String = str(data.get("preview_anchor", "none"))
	if is_active:
		anchor_name = str(data.get("anchor", "none"))
	readout.text = (
		"TETHER " + ("ATTACHED" if is_active else "READY")
		+ "  •  " + anchor_name
		+ "  •  L " + str(data.get("length", 0.0))
		+ " / " + str(data.get("distance", 0.0)) + " m"
		+ "\nT " + str(data.get("tension", 0.0)) + " N"
		+ "  •  Peak " + str(data.get("peak_tension", 0.0)) + " N"
		+ "  •  Swing " + str(data.get("tangential_speed", 0.0)) + " m/s"
		+ "  •  Air " + str(snapped(airflow.length(), 0.1)) + " m/s²"
	)


func _on_anchor_broken(anchor: MetalTetherAnchor3D, tension: float) -> void:
	show_message(
		anchor.display_name + " failed at " + str(snapped(tension, 1.0)) + " N."
	)


func _on_goal_body_entered(body: Node3D) -> void:
	if body != player or goal_reached:
		return
	goal_reached = true
	GameState.set_objective("Foundry route complete. Test the load, moving anchor, reeling, and breakaway.")
	show_message("Foundry Beacon reached! Release momentum carried Grace across the route.")


func reset_player_only(message: String = "") -> void:
	if player == null:
		return
	if tether_controller != null:
		tether_controller.release_tether("safety reset", false)
	player.global_transform = initial_player_transform
	player.velocity = Vector3.ZERO
	if message != "":
		show_message(message)


func reset_lab() -> void:
	reset_count += 1
	goal_reached = false
	if tether_controller != null:
		tether_controller.release_tether("lab reset", false)
	if action_state != null:
		action_state.reset_for_respawn()
	if player != null:
		player.global_transform = initial_player_transform
		player.velocity = Vector3.ZERO
	for anchor: MetalTetherAnchor3D in anchors:
		if is_instance_valid(anchor):
			anchor.reset_anchor()
	if movable_load != null:
		movable_load.global_transform = movable_load_transform
		movable_load.linear_velocity = Vector3.ZERO
		movable_load.angular_velocity = Vector3.ZERO
		movable_load.sleeping = false
	configure_player()
	GameState.set_objective("Use Metal Tether to swing across the pit and land on the Foundry Beacon platform.")
	show_message("Metal Tether Laboratory reset #" + str(reset_count) + ".")
	refresh_readout()


func restore_stat_snapshot() -> void:
	for stat_name: Variant in stat_snapshot.keys():
		GameState.set_stat(str(stat_name), int(stat_snapshot[stat_name]))


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"metal_tether_lab": true,
		"goal_reached": goal_reached,
		"reset_count": reset_count,
		"anchor_count": anchors.size(),
		"tether": tether_controller.get_debug_data() if tether_controller != null else {},
	}
