extends Node3D
class_name PrototypeAerialTraversalLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const AerialLabLoadout: Resource = preload("res://data/loadouts/grace_aerial_traversal_lab_loadout.tres")

@export var enable_editor_f8_reset: bool = true
@export var readout_refresh_interval: float = 0.08
@export var safety_reset_height: float = -4.0

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var concentration_manager: Node = get_node_or_null("ConcentrationManager")

var aerial_locomotion: PlayerAerialLocomotion = null
var action_state: PlayerActionState = null
var stat_snapshot: Dictionary = {}
var initial_player_transform: Transform3D
var readout_timer: float = 0.0
var reset_count: int = 0
var goal_reached: bool = false

var traversal_readout: Label3D = null
var goal_beacon: Node3D = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	build_laboratory()
	configure_player()

	if player != null:
		initial_player_transform = player.transform
		player.add_to_group("player")
		aerial_locomotion = player.get_node_or_null("AerialLocomotion") as PlayerAerialLocomotion
		action_state = player.get_node_or_null("PlayerActionState") as PlayerActionState
		configure_traversal_unlocks()

	GameState.set_objective("Climb with Double Jump and Hover, then cast Flight and reach the crown beacon.")
	show_message("Aerial Traversal Laboratory ready. Jump twice, hold Jump near the apex to hover, then cast Flight with RT.")
	update_readout()


func _process(delta: float) -> void:
	readout_timer -= delta
	if readout_timer <= 0.0:
		readout_timer = max(readout_refresh_interval, 0.04)
		update_readout()

	if player != null and player.global_position.y < safety_reset_height:
		reset_player_only("Safety current returned Grace to the launch deck.")

	if goal_beacon != null:
		goal_beacon.rotate_y(delta * 1.35)
		var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.08
		goal_beacon.scale = Vector3.ONE * pulse


func _exit_tree() -> void:
	if aerial_locomotion != null and aerial_locomotion.flight_active:
		aerial_locomotion.finish_flight(false, false)
	if concentration_manager != null and concentration_manager.get("active_effect") != null:
		concentration_manager.call("deactivate_effect", false)
	restore_stat_snapshot()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.physical_keycode != KEY_F8:
		return
	get_viewport().set_input_as_handled()
	reset_lab()


func configure_player() -> void:
	if player == null:
		return
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null:
		var runtime_loadout: Resource = AerialLabLoadout.duplicate(true)
		ability_caster.set("loadout", runtime_loadout)
		ability_caster.set("current_ability_index", 0)
		if ability_caster.has_method("align_focus_menu_to_current_ability"):
			ability_caster.call("align_focus_menu_to_current_ability")
		if ability_caster.has_method("emit_current_ability"):
			ability_caster.call("emit_current_ability")

	GameState.set_stat("max_mana", 12)
	GameState.set_stat("mana", 12)
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("focus", max(GameState.get_stat("focus"), 5))


func configure_traversal_unlocks() -> void:
	if aerial_locomotion == null:
		return
	aerial_locomotion.double_jump_unlocked = true
	aerial_locomotion.hover_unlocked = true
	aerial_locomotion.flight_unlocked = true
	aerial_locomotion.maximum_air_jumps = 1
	aerial_locomotion.hover_duration = 1.65
	aerial_locomotion.flight_speed = 7.4
	aerial_locomotion.flight_vertical_speed = 5.4


func build_laboratory() -> void:
	create_floor()
	create_boundaries()
	create_instruction_board()
	create_traversal_course()
	create_flight_rings()
	create_goal_platform()
	create_readout()


func create_floor() -> void:
	create_static_box(
		"SafetyFloor",
		Vector3(0.0, -0.45, 0.0),
		Vector3(30.0, 0.9, 30.0),
		Color(0.055, 0.075, 0.12, 1.0),
		0.05,
		1.0
	)
	for index: int in range(6):
		var line := MeshInstance3D.new()
		line.name = "LaunchGrid" + str(index)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, 0.025, 26.0)
		line.mesh = mesh
		line.position = Vector3(-10.0 + float(index) * 4.0, 0.02, 0.0)
		line.material_override = ElementVisuals.make_material(Color(0.16, 0.38, 0.62, 1.0), 0.55, 0.75, true)
		add_child(line)


func create_boundaries() -> void:
	var wall_color := Color(0.045, 0.06, 0.095, 1.0)
	create_static_box("NorthWall", Vector3(0.0, 10.0, -15.0), Vector3(30.0, 20.0, 0.5), wall_color)
	create_static_box("SouthWall", Vector3(0.0, 10.0, 15.0), Vector3(30.0, 20.0, 0.5), wall_color)
	create_static_box("WestWall", Vector3(-15.0, 10.0, 0.0), Vector3(0.5, 20.0, 30.0), wall_color)
	create_static_box("EastWall", Vector3(15.0, 10.0, 0.0), Vector3(0.5, 20.0, 30.0), wall_color)


func create_instruction_board() -> void:
	var board := Node3D.new()
	board.name = "InstructionBoard"
	board.position = Vector3(0.0, 2.25, 13.2)
	add_child(board)
	ElementVisuals.add_box(board, "Board", Vector3(11.8, 3.0, 0.18), Color(0.025, 0.045, 0.085, 1.0), Vector3.ZERO, Vector3.ZERO, 0.35, 0.95)

	var label := Label3D.new()
	label.text = "VERTICAL TRAVERSAL LAB\nJump twice for DOUBLE JUMP  •  Hold Jump near the apex to HOVER\nCast FLIGHT with RT  •  Jump ascends  •  Dodge descends  •  Neutral holds altitude\nCast Flight again to release it. F8 resets the chamber."
	label.position = Vector3(0.0, 0.0, 0.11)
	label.font_size = 28
	label.pixel_size = 0.0054
	label.outline_size = 6
	label.modulate = Color(0.72, 0.9, 1.0, 1.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(label)


func create_traversal_course() -> void:
	create_labeled_platform(
		"DoubleJumpDeck",
		Vector3(0.0, 2.15, 7.0),
		Vector3(4.5, 0.45, 3.2),
		"DOUBLE JUMP",
		Color(0.18, 0.46, 0.82, 1.0)
	)
	create_labeled_platform(
		"ApexDeck",
		Vector3(-4.4, 4.55, 2.7),
		Vector3(3.2, 0.45, 3.2),
		"SECOND IMPULSE",
		Color(0.26, 0.58, 0.94, 1.0)
	)
	create_labeled_platform(
		"HoverDeck",
		Vector3(4.4, 4.55, -1.8),
		Vector3(3.2, 0.45, 3.2),
		"HOVER GAP",
		Color(0.46, 0.72, 1.0, 1.0)
	)

	create_static_box("PrecisionArchLeft", Vector3(2.7, 7.0, -5.2), Vector3(0.55, 5.0, 0.8), Color(0.16, 0.24, 0.42, 1.0))
	create_static_box("PrecisionArchRight", Vector3(6.1, 7.0, -5.2), Vector3(0.55, 5.0, 0.8), Color(0.16, 0.24, 0.42, 1.0))
	create_static_box("PrecisionArchTop", Vector3(4.4, 9.25, -5.2), Vector3(3.95, 0.5, 0.8), Color(0.2, 0.34, 0.58, 1.0))

	var arch_label := Label3D.new()
	arch_label.text = "PRECISION ARCH"
	arch_label.position = Vector3(4.4, 9.8, -5.2)
	arch_label.font_size = 26
	arch_label.pixel_size = 0.006
	arch_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arch_label.outline_size = 5
	arch_label.modulate = Color(0.58, 0.84, 1.0, 1.0)
	add_child(arch_label)


func create_flight_rings() -> void:
	var ring_positions: Array[Vector3] = [
		Vector3(2.0, 6.2, -5.0),
		Vector3(-1.8, 8.3, -6.8),
		Vector3(-5.2, 10.4, -4.0),
		Vector3(-3.4, 12.5, 0.2),
		Vector3(1.2, 14.3, -1.4),
		Vector3(0.0, 15.8, -6.2),
	]

	for index: int in range(ring_positions.size()):
		var ring_root := Node3D.new()
		ring_root.name = "FlightRing" + str(index + 1)
		ring_root.position = ring_positions[index]
		add_child(ring_root)
		ElementVisuals.add_torus(
			ring_root,
			"Ring",
			1.25,
			1.48,
			Color(0.3 + float(index) * 0.05, 0.74, 1.0, 1.0),
			Vector3.ZERO,
			Vector3(90.0, 0.0, 0.0),
			1.5,
			0.28
		)
		var label := Label3D.new()
		label.text = str(index + 1)
		label.position = Vector3(0.0, 1.85, 0.0)
		label.font_size = 34
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 5
		label.modulate = Color(0.7, 0.92, 1.0, 1.0)
		ring_root.add_child(label)


func create_goal_platform() -> void:
	create_static_box(
		"CrownPlatform",
		Vector3(0.0, 16.0, -9.5),
		Vector3(6.5, 0.55, 5.0),
		Color(0.22, 0.38, 0.64, 1.0),
		0.35,
		0.55
	)

	goal_beacon = Node3D.new()
	goal_beacon.name = "CrownBeacon"
	goal_beacon.position = Vector3(0.0, 17.2, -9.5)
	add_child(goal_beacon)
	ElementVisuals.add_torus(goal_beacon, "BeaconOrbit", 0.65, 0.86, Color(0.76, 0.92, 1.0, 1.0), Vector3.ZERO, Vector3(90.0, 0.0, 0.0), 2.1, 0.22)
	ElementVisuals.add_capsule(goal_beacon, "BeaconCore", 0.22, 1.45, Color(0.86, 0.97, 1.0, 1.0), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 2.4, 0.18)

	var goal_label := Label3D.new()
	goal_label.text = "CROWN BEACON\nLAND HERE"
	goal_label.position = Vector3(0.0, 1.9, 0.0)
	goal_label.font_size = 30
	goal_label.pixel_size = 0.0065
	goal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	goal_label.outline_size = 6
	goal_label.modulate = Color(0.82, 0.96, 1.0, 1.0)
	goal_beacon.add_child(goal_label)

	var trigger := Area3D.new()
	trigger.name = "GoalTrigger"
	trigger.position = Vector3(0.0, 17.0, -9.5)
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.8, 2.2, 4.2)
	collision.shape = shape
	trigger.add_child(collision)
	trigger.body_entered.connect(_on_goal_body_entered)
	add_child(trigger)


func create_readout() -> void:
	traversal_readout = Label3D.new()
	traversal_readout.name = "TraversalReadout"
	traversal_readout.position = Vector3(-11.6, 3.0, 10.5)
	traversal_readout.font_size = 29
	traversal_readout.pixel_size = 0.0065
	traversal_readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	traversal_readout.outline_size = 6
	traversal_readout.modulate = Color(0.68, 0.88, 1.0, 1.0)
	add_child(traversal_readout)


func create_labeled_platform(
	platform_name: String,
	position_value: Vector3,
	size_value: Vector3,
	label_text: String,
	color: Color
) -> void:
	create_static_box(platform_name, position_value, size_value, color, 0.32, 0.55)
	var label := Label3D.new()
	label.text = label_text
	label.position = position_value + Vector3(0.0, 0.7, 0.0)
	label.font_size = 27
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = Color(0.74, 0.92, 1.0, 1.0)
	add_child(label)


func create_static_box(
	box_name: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color,
	emission_energy: float = 0.08,
	roughness: float = 1.0
) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
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
	mesh_instance.material_override = ElementVisuals.make_material(color, emission_energy, roughness, false)
	body.add_child(mesh_instance)
	add_child(body)


func update_readout() -> void:
	if traversal_readout == null:
		return

	var state_text: String = "UNAVAILABLE"
	var velocity_value: Vector3 = Vector3.ZERO
	var hover_remaining: float = 0.0
	var hover_maximum: float = 0.0
	var flight_active: bool = false
	if aerial_locomotion != null:
		state_text = aerial_locomotion.traversal_state.to_upper()
		velocity_value = player.velocity if player != null else Vector3.ZERO
		hover_remaining = aerial_locomotion.hover_remaining
		hover_maximum = aerial_locomotion.hover_duration
		flight_active = aerial_locomotion.flight_active

	var usable_cap: int = GameState.get_stat("max_mana")
	var reserved: int = 0
	if concentration_manager != null and concentration_manager.has_method("get_usable_mana_cap"):
		usable_cap = int(concentration_manager.call("get_usable_mana_cap"))
		reserved = int(concentration_manager.call("get_reserved_mana"))

	var actions_locked: bool = action_state != null and action_state.is_flying and not action_state.can_attack()
	traversal_readout.text = (
		"AERIAL STATE: " + state_text
		+ "\nVelocity: " + format_vector(velocity_value)
		+ "\nHover: " + str(snapped(hover_remaining, 0.1)) + " / " + str(snapped(hover_maximum, 0.1)) + " s"
		+ "\nMana: " + str(GameState.get_stat("mana")) + " / " + str(usable_cap) + " usable  •  " + str(reserved) + " reserved"
		+ "\nFlight: " + ("ACTIVE" if flight_active else "DORMANT")
		+ "  •  Actions: " + ("MOVEMENT ONLY" if actions_locked else "NORMAL")
	)


func format_vector(value: Vector3) -> String:
	return "(" + str(snapped(value.x, 0.1)) + ", " + str(snapped(value.y, 0.1)) + ", " + str(snapped(value.z, 0.1)) + ")"


func _on_goal_body_entered(body: Node3D) -> void:
	if body != player or goal_reached:
		return
	goal_reached = true
	GameState.set_objective("Aerial route complete. Test landing, dismissal, and controlled descent.")
	show_message("Crown Beacon reached. Flight route complete!")


func reset_player_only(message: String = "") -> void:
	if player == null:
		return
	if aerial_locomotion != null and aerial_locomotion.flight_active:
		aerial_locomotion.finish_flight(true, false)
	player.transform = initial_player_transform
	player.velocity = Vector3.ZERO
	if message != "":
		show_message(message)


func reset_lab() -> void:
	reset_count += 1
	goal_reached = false
	if aerial_locomotion != null and aerial_locomotion.flight_active:
		aerial_locomotion.finish_flight(true, false)
	elif concentration_manager != null and concentration_manager.get("active_effect") != null:
		concentration_manager.call("deactivate_effect", false)

	if action_state != null:
		action_state.reset_for_respawn()
	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	configure_player()
	configure_traversal_unlocks()
	GameState.set_objective("Climb with Double Jump and Hover, then cast Flight and reach the crown beacon.")
	show_message("Aerial Traversal Laboratory reset #" + str(reset_count) + ".")
	update_readout()


func restore_stat_snapshot() -> void:
	if stat_snapshot.is_empty():
		return
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
		"aerial_traversal_lab": true,
		"goal_reached": goal_reached,
		"state": aerial_locomotion.traversal_state if aerial_locomotion != null else "missing",
		"flight_active": aerial_locomotion.flight_active if aerial_locomotion != null else false,
		"hover_remaining": aerial_locomotion.hover_remaining if aerial_locomotion != null else 0.0,
		"mana": GameState.get_stat("mana"),
		"reset_count": reset_count,
	}
