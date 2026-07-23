extends Node3D
class_name PrototypeFlexibleTetherLab

const FlexibleTetherScript = preload("res://scripts/flexible/flexible_tether_3d.gd")
const PulleyTetherScript = preload("res://scripts/flexible/pulley_tether_3d.gd")
const HempRopeProfile: Resource = preload("res://data/flexible_materials/hemp_rope.tres")
const IronChainProfile: Resource = preload("res://data/flexible_materials/iron_chain.tres")

@export var enable_editor_f8_reset: bool = true
@export_range(0.03, 1.0, 0.01) var readout_refresh_interval: float = 0.08

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D

var rope_profile: FlexibleMaterialProfile
var chain_profile: FlexibleMaterialProfile
var pendulum_chain: FlexibleTether3D
var break_rope: FlexibleTether3D
var thermal_rope: FlexibleTether3D
var frozen_rope: FlexibleTether3D
var slack_rope: FlexibleTether3D
var pulley: PulleyTether3D
var pendulum_weight: RigidBody3D
var break_weight: RigidBody3D
var pulley_left_weight: RigidBody3D
var pulley_right_weight: RigidBody3D
var readout: Label3D
var readout_timer: float = 0.0
var load_step: int = 0
var reset_count: int = 0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	_create_profiles()
	_build_laboratory()
	if player != null:
		player.add_to_group("player")
	GameState.set_objective("Swing the chain, overload the rope, compare heat and frost, and inspect the working counterweight.")
	_show_message("Flexible Physics Laboratory ready. The tethers sag, pull, transfer load, weaken, and snap.")


func _process(delta: float) -> void:
	readout_timer -= delta
	if readout_timer <= 0.0:
		readout_timer = readout_refresh_interval
		_update_readout()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_1:
			_launch_pendulum()
		KEY_2:
			_add_break_load()
		KEY_3:
			_heat_thermal_rope()
		KEY_4:
			_freeze_and_load_rope()
		KEY_5:
			_swap_pulley_load()
		KEY_V:
			_toggle_tension_colors()
		KEY_F8:
			if enable_editor_f8_reset and OS.has_feature("editor"):
				reset_lab()
			else:
				return
		_:
			return
	get_viewport().set_input_as_handled()


func _create_profiles() -> void:
	rope_profile = HempRopeProfile.duplicate(true) as FlexibleMaterialProfile
	chain_profile = IronChainProfile.duplicate(true) as FlexibleMaterialProfile


func _build_laboratory() -> void:
	_create_static_box("Floor", Vector3(0.0, -0.5, 0.0), Vector3(28.0, 1.0, 24.0), Color(0.045, 0.055, 0.075, 1.0))
	_create_static_box("BackWall", Vector3(0.0, 5.0, -12.0), Vector3(28.0, 10.0, 0.6), Color(0.055, 0.065, 0.09, 1.0))
	_create_instruction_board()
	_create_pendulum_station()
	_create_break_station()
	_create_element_station()
	_create_pulley_station()
	_create_slack_span()
	_create_readout()


func _create_instruction_board() -> void:
	var label := Label3D.new()
	label.name = "InstructionBoard"
	label.position = Vector3(0.0, 7.8, -10.9)
	label.text = "FLEXIBLE PHYSICS LABORATORY\n1  SWING CHAIN   •   2  ADD LOAD   •   3  HEAT ROPE   •   4  FREEZE + LOAD   •   5  SWAP COUNTERWEIGHT\nV  TOGGLE TENSION COLOR   •   F8  RESET"
	label.font_size = 30
	label.pixel_size = 0.006
	label.outline_size = 7
	label.modulate = Color(0.86, 0.92, 1.0, 1.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)


func _create_pendulum_station() -> void:
	_create_station_label("PENDULUM CHAIN\nREAL MOMENTUM + TENSION", Vector3(-9.2, 7.0, -4.0), Color(0.65, 0.82, 1.0, 1.0))
	var anchor := _create_anchor("PendulumAnchor", Vector3(-9.2, 6.4, -3.6))
	pendulum_weight = _create_weight("PendulumWeight", Vector3(-9.2, 1.6, -3.6), 18.0, Color(0.22, 0.32, 0.5, 1.0), Vector3(1.15, 1.15, 1.15))
	pendulum_chain = _create_tether("PendulumChain", anchor, pendulum_weight, chain_profile, 4.95, 18)
	pendulum_chain.tether_broken.connect(_on_tether_broken.bind("Pendulum chain"))


func _create_break_station() -> void:
	_create_station_label("BREAK TEST\nLOAD UNTIL FAILURE", Vector3(-3.1, 7.0, -4.0), Color(1.0, 0.72, 0.38, 1.0))
	var anchor := _create_anchor("BreakAnchor", Vector3(-3.1, 6.4, -3.6))
	break_weight = _create_weight("BreakWeight", Vector3(-3.1, 2.45, -3.6), 24.0, Color(0.52, 0.25, 0.12, 1.0), Vector3(1.0, 1.0, 1.0))
	break_rope = _create_tether("BreakRope", anchor, break_weight, rope_profile, 4.05, 15)
	break_rope.tether_broken.connect(_on_tether_broken.bind("Load-test rope"))


func _create_element_station() -> void:
	_create_station_label("MATERIAL REACTIONS\nFIRE BURNS  •  ICE BRITTLES", Vector3(4.0, 7.0, -4.0), Color(0.75, 0.9, 1.0, 1.0))
	var hot_anchor := _create_anchor("ThermalAnchor", Vector3(2.25, 6.4, -3.6))
	var hot_weight := _create_weight("ThermalWeight", Vector3(2.25, 2.5, -3.6), 18.0, Color(0.56, 0.17, 0.06, 1.0), Vector3(0.9, 0.9, 0.9))
	thermal_rope = _create_tether("ThermalRope", hot_anchor, hot_weight, rope_profile, 4.0, 15)
	thermal_rope.tether_broken.connect(_on_tether_broken.bind("Heated rope"))

	var cold_anchor := _create_anchor("FrozenAnchor", Vector3(5.75, 6.4, -3.6))
	var cold_weight := _create_weight("FrozenWeight", Vector3(5.75, 2.5, -3.6), 18.0, Color(0.18, 0.48, 0.68, 1.0), Vector3(0.9, 0.9, 0.9))
	frozen_rope = _create_tether("FrozenRope", cold_anchor, cold_weight, rope_profile, 4.0, 15)
	frozen_rope.tether_broken.connect(_on_tether_broken.bind("Frozen rope"))


func _create_pulley_station() -> void:
	_create_station_label("COUNTERWEIGHT PULLEY\nONE SHARED LENGTH", Vector3(9.8, 7.0, -4.0), Color(0.82, 0.76, 1.0, 1.0))
	var pulley_a := _create_pulley_wheel("PulleyA", Vector3(8.35, 6.2, -3.6))
	var pulley_b := _create_pulley_wheel("PulleyB", Vector3(11.25, 6.2, -3.6))
	pulley_left_weight = _create_weight("PulleyLeftWeight", Vector3(8.35, 2.7, -3.6), 8.0, Color(0.25, 0.38, 0.62, 1.0), Vector3(0.85, 1.2, 0.85))
	pulley_right_weight = _create_weight("PulleyRightWeight", Vector3(11.25, 2.7, -3.6), 16.0, Color(0.48, 0.24, 0.58, 1.0), Vector3(0.85, 1.2, 0.85))
	for body: RigidBody3D in [pulley_left_weight, pulley_right_weight]:
		body.axis_lock_linear_x = true
		body.axis_lock_linear_z = true
		body.axis_lock_angular_x = true
		body.axis_lock_angular_y = true
		body.axis_lock_angular_z = true

	pulley = PulleyTetherScript.new()
	pulley.name = "CounterweightPulley"
	pulley.body_a_path = NodePath("../" + str(pulley_left_weight.name))
	pulley.pulley_a_path = NodePath("../" + str(pulley_a.name))
	pulley.pulley_b_path = NodePath("../" + str(pulley_b.name))
	pulley.body_b_path = NodePath("../" + str(pulley_right_weight.name))
	pulley.material_profile = chain_profile
	pulley.total_length = 10.0
	add_child(pulley)
	pulley.tether_broken.connect(_on_tether_broken.bind("Pulley chain"))


func _create_slack_span() -> void:
	_create_station_label("SLACK SPAN\nCONSTRAINT SAG", Vector3(0.0, 6.8, 3.3), Color(0.86, 0.7, 0.42, 1.0))
	var left_anchor := _create_anchor("SlackSpanLeft", Vector3(-5.0, 5.7, 3.0))
	var right_anchor := _create_anchor("SlackSpanRight", Vector3(5.0, 5.7, 3.0))
	slack_rope = _create_tether("SlackSpanRope", left_anchor, right_anchor, rope_profile, 12.0, 28)
	slack_rope.apply_endpoint_forces = false


func _create_tether(
	tether_name: String,
	endpoint_a: Node3D,
	endpoint_b: Node3D,
	profile: FlexibleMaterialProfile,
	length: float,
	segments: int
) -> FlexibleTether3D:
	var tether: FlexibleTether3D = FlexibleTetherScript.new()
	tether.name = tether_name
	tether.endpoint_a_path = NodePath("../" + str(endpoint_a.name))
	tether.endpoint_b_path = NodePath("../" + str(endpoint_b.name))
	tether.material_profile = profile
	tether.rest_length = length
	tether.segment_count = segments
	tether.constraint_iterations = 8
	add_child(tether)
	return tether


func _create_anchor(anchor_name: String, position_value: Vector3) -> StaticBody3D:
	var anchor := StaticBody3D.new()
	anchor.name = anchor_name
	anchor.position = position_value
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.24
	mesh.height = 0.48
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(Color(0.48, 0.53, 0.62, 1.0), 0.9, 0.24)
	anchor.add_child(mesh_instance)
	add_child(anchor)
	return anchor


func _create_pulley_wheel(wheel_name: String, position_value: Vector3) -> StaticBody3D:
	var wheel := _create_anchor(wheel_name, position_value)
	var mesh_instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.48
	mesh.outer_radius = 0.68
	mesh.rings = 20
	mesh.ring_segments = 8
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mesh_instance.material_override = _make_material(Color(0.38, 0.3, 0.52, 1.0), 0.75, 0.28)
	wheel.add_child(mesh_instance)
	return wheel


func _create_weight(
	body_name: String,
	position_value: Vector3,
	mass_value: float,
	color: Color,
	size_value: Vector3
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = body_name
	body.position = position_value
	body.mass = mass_value
	body.linear_damp = 0.08
	body.angular_damp = 0.35
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, 0.65, 0.36)
	body.add_child(mesh_instance)
	var label := Label3D.new()
	label.name = "MassLabel"
	label.position = Vector3(0.0, size_value.y * 0.75, 0.0)
	label.font_size = 24
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.text = str(int(mass_value)) + " kg"
	body.add_child(label)
	add_child(body)
	return body


func _create_static_box(box_name: String, position_value: Vector3, size_value: Vector3, color: Color) -> void:
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
	mesh_instance.material_override = _make_material(color, 0.05, 0.92)
	body.add_child(mesh_instance)
	add_child(body)


func _create_station_label(text_value: String, position_value: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.position = position_value
	label.text = text_value
	label.font_size = 25
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)


func _create_readout() -> void:
	readout = Label3D.new()
	readout.name = "TensionReadout"
	readout.position = Vector3(0.0, 3.6, 6.3)
	readout.font_size = 28
	readout.pixel_size = 0.006
	readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	readout.outline_size = 6
	readout.modulate = Color(0.78, 0.9, 1.0, 1.0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(readout)


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _launch_pendulum() -> void:
	if pendulum_weight == null or pendulum_chain == null or pendulum_chain.is_broken:
		return
	pendulum_weight.apply_central_impulse(Vector3(0.0, 0.5, 115.0))
	_show_message("The iron chain carries the pendulum's momentum and reports live tension.")


func _add_break_load() -> void:
	if break_weight == null or break_rope == null:
		return
	load_step += 1
	break_weight.mass = 24.0 + float(load_step) * 22.0
	_update_mass_label(break_weight)
	_show_message("Load-test mass: " + str(int(break_weight.mass)) + " kg.")


func _heat_thermal_rope() -> void:
	if thermal_rope == null:
		return
	thermal_rope.apply_heat(0.34)
	_show_message("Heat weakens the hemp fibers. Sustained ignition will burn through the tether.")


func _freeze_and_load_rope() -> void:
	if frozen_rope == null:
		return
	frozen_rope.apply_cold(0.36)
	var frozen_weight := get_node_or_null("FrozenWeight") as RigidBody3D
	if frozen_weight != null:
		frozen_weight.mass += 15.0
		_update_mass_label(frozen_weight)
	_show_message("Cold stiffens the rope but lowers its failure threshold. The test load increased.")


func _swap_pulley_load() -> void:
	if pulley_left_weight == null or pulley_right_weight == null:
		return
	var left_mass := pulley_left_weight.mass
	pulley_left_weight.mass = pulley_right_weight.mass
	pulley_right_weight.mass = left_mass
	_update_mass_label(pulley_left_weight)
	_update_mass_label(pulley_right_weight)
	_show_message("Counterweights swapped. The heavier side should descend while lifting the lighter side.")


func _toggle_tension_colors() -> void:
	for node: Node in get_tree().get_nodes_in_group("flexible_tethers"):
		if node is FlexibleTether3D and is_ancestor_of(node):
			(node as FlexibleTether3D).debug_tension_color = not (node as FlexibleTether3D).debug_tension_color
	if pulley != null:
		pulley.debug_tension_color = not pulley.debug_tension_color
	_show_message("Tension-color debugging toggled.")


func _update_mass_label(body: RigidBody3D) -> void:
	var label := body.get_node_or_null("MassLabel") as Label3D
	if label != null:
		label.text = str(int(body.mass)) + " kg"


func _on_tether_broken(reason: String, peak: float, tether_label: String) -> void:
	_show_message(tether_label + " failed by " + reason + " at " + str(snapped(peak, 1.0)) + " N.")


func _update_readout() -> void:
	if readout == null:
		return
	readout.text = (
		"LIVE TENSION\n"
		+ "Chain pendulum  " + _format_tether(pendulum_chain)
		+ "\nLoad rope  " + _format_tether(break_rope)
		+ "\nFire rope  " + _format_tether(thermal_rope)
		+ "\nFrozen rope  " + _format_tether(frozen_rope)
		+ "\nPulley  " + (_format_force(pulley.current_tension) if pulley != null and not pulley.is_broken else "BROKEN")
		+ "\nSlack span  " + str(snapped(slack_rope.rest_length - 10.0, 0.1)) + " m extra length"
	)


func _format_tether(tether: FlexibleTether3D) -> String:
	if tether == null:
		return "MISSING"
	if tether.is_broken:
		return "BROKEN (" + tether.break_reason.to_upper() + ")"
	return (
		_format_force(tether.current_tension)
		+ " / " + _format_force(tether.get_effective_break_strength())
		+ ("  BURN " + str(int(tether.burn_progress * 100.0)) + "%" if tether.burn_progress > 0.0 else "")
		+ ("  FROZEN " + str(int(tether.cold_amount * 100.0)) + "%" if tether.cold_amount > 0.0 else "")
	)


func _format_force(value: float) -> String:
	return str(int(round(value))) + " N"


func reset_lab() -> void:
	reset_count += 1
	get_tree().reload_current_scene()


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"flexible_tether_lab": true,
		"tether_count": get_tree().get_nodes_in_group("flexible_tethers").filter(func(node: Node) -> bool: return is_ancestor_of(node)).size(),
		"pulley_count": get_tree().get_nodes_in_group("pulley_tethers").filter(func(node: Node) -> bool: return is_ancestor_of(node)).size(),
		"load_step": load_step,
		"reset_count": reset_count,
	}
