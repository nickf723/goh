extends Node3D
class_name SoulGripController

signal grip_started(target: SoulManipulable)
signal grip_released(target: SoulManipulable)

@export_group("Input")
@export var grip_action: String = "soul_grip"
@export var push_action: String = "soul_grip_push"
@export var pull_action: String = "soul_grip_pull"
@export var rotate_left_action: String = "soul_grip_rotate_left"
@export var rotate_right_action: String = "soul_grip_rotate_right"

@export_group("Targeting")
@export_range(1.0, 40.0, 0.5) var maximum_target_range: float = 18.0
@export_range(1.0, 30.0, 0.5) var minimum_hold_distance: float = 2.2
@export_range(1.0, 40.0, 0.5) var maximum_hold_distance: float = 15.0
@export_range(1.0, 45.0, 1.0) var targeting_cone_degrees: float = 16.0
@export var placement_vertical_offset: float = -0.22

@export_group("Feel")
@export_range(0.5, 20.0, 0.1) var distance_change_speed: float = 5.5
@export_range(10.0, 360.0, 5.0) var rotation_speed_degrees: float = 110.0
@export_range(0.0, 1.0, 0.05) var release_velocity_retention: float = 0.35
@export_range(0.01, 0.3, 0.01) var tether_thickness: float = 0.055

var player: CharacterBody3D = null
var action_state: PlayerActionState = null
var held_target: SoulManipulable = null
var hold_distance: float = 5.0
var desired_basis: Basis = Basis.IDENTITY
var tether_visual: MeshInstance3D = null
var tether_mesh: BoxMesh = null
var target_marker: MeshInstance3D = null


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player != null:
		action_state = player.get_node_or_null("PlayerActionState") as PlayerActionState

	ensure_input_map()
	create_feedback_visuals()
	add_to_group("debuggable")
	add_to_group("soul_grip_controllers")


func _process(delta: float) -> void:
	if player == null:
		return

	if player.has_method("is_focus_spell_menu_open") and bool(player.call("is_focus_spell_menu_open")):
		release_grip()
		return

	if held_target != null and not held_target.is_being_manipulated():
		release_grip()

	if Input.is_action_just_pressed(grip_action):
		try_begin_grip()

	if not Input.is_action_pressed(grip_action):
		release_grip()
		return

	if held_target == null:
		return

	update_hold_controls(delta)
	update_target_pose()
	update_feedback_visuals()


func _exit_tree() -> void:
	release_grip()


func try_begin_grip() -> void:
	if held_target != null:
		return
	if action_state != null and action_state.has_method("can_manipulate"):
		if not bool(action_state.call("can_manipulate")):
			return

	var candidate: SoulManipulable = find_best_target()
	if candidate == null:
		show_message("No Soul-manipulable object in focus.")
		return
	if not candidate.begin_manipulation(self):
		show_message("That object's Soul is resisting manipulation.")
		return

	if action_state != null and action_state.has_method("begin_manipulation"):
		if not bool(action_state.call("begin_manipulation")):
			candidate.end_manipulation()
			return

	held_target = candidate
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		hold_distance = clampf(
			camera.global_position.distance_to(candidate.get_anchor_global_position()),
			minimum_hold_distance,
			maximum_hold_distance
		)
	else:
		hold_distance = clampf(5.0, minimum_hold_distance, maximum_hold_distance)

	var body: CharacterBody3D = candidate.body
	desired_basis = body.global_basis if body != null else Basis.IDENTITY
	GameFeedback.play("light_tick", {"source": "soul_grip"})
	show_message("Soul Grip: right stick aims, D-pad up/down changes distance, left/right rotates.")
	grip_started.emit(candidate)
	update_target_pose()
	update_feedback_visuals()


func release_grip() -> void:
	if held_target == null:
		hide_feedback_visuals()
		return

	var released_target: SoulManipulable = held_target
	var released_body: CharacterBody3D = released_target.body
	released_target.end_manipulation()
	if released_body != null:
		released_body.velocity *= release_velocity_retention

	held_target = null
	if action_state != null and action_state.has_method("end_manipulation"):
		action_state.call("end_manipulation")
	GameFeedback.play("light_tick", {"source": "soul_release"})
	hide_feedback_visuals()
	grip_released.emit(released_target)


func update_hold_controls(delta: float) -> void:
	var distance_input: float = Input.get_action_strength(push_action) - Input.get_action_strength(pull_action)
	hold_distance = clampf(
		hold_distance + distance_input * distance_change_speed * delta,
		minimum_hold_distance,
		maximum_hold_distance
	)

	var rotation_input: float = Input.get_action_strength(rotate_right_action) - Input.get_action_strength(rotate_left_action)
	if absf(rotation_input) > 0.01:
		var angle: float = deg_to_rad(rotation_speed_degrees) * rotation_input * delta
		desired_basis = Basis(Vector3.UP, angle) * desired_basis


func update_target_pose() -> void:
	if held_target == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var forward: Vector3 = -camera.global_basis.z
	if forward.length() <= 0.01:
		return

	var target_position: Vector3 = (
		camera.global_position
		+ forward.normalized() * hold_distance
		+ Vector3.UP * placement_vertical_offset
	)
	held_target.set_target_pose(target_position, desired_basis)


func find_best_target() -> SoulManipulable:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return null

	var direct_target: SoulManipulable = raycast_target(camera)
	if direct_target != null:
		return direct_target

	var camera_forward: Vector3 = -camera.global_basis.z
	var minimum_dot: float = cos(deg_to_rad(targeting_cone_degrees))
	var best_target: SoulManipulable = null
	var best_score: float = INF

	for candidate_node: Node in get_tree().get_nodes_in_group("soul_manipulable"):
		if not candidate_node is SoulManipulable:
			continue
		var candidate: SoulManipulable = candidate_node as SoulManipulable
		if not candidate.can_begin_manipulation():
			continue
		var offset: Vector3 = candidate.get_anchor_global_position() - camera.global_position
		var distance: float = offset.length()
		if distance <= 0.01 or distance > maximum_target_range:
			continue
		var forward_dot: float = camera_forward.normalized().dot(offset.normalized())
		if forward_dot < minimum_dot:
			continue
		var score: float = (1.0 - forward_dot) * 22.0 + distance * 0.035
		if score < best_score:
			best_score = score
			best_target = candidate

	return best_target


func raycast_target(camera: Camera3D) -> SoulManipulable:
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + (-camera.global_basis.z).normalized() * maximum_target_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if player != null:
		query.exclude = [player.get_rid()]

	var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider: Node = result.get("collider") as Node
	return find_manipulable_from_node(collider)


func find_manipulable_from_node(start_node: Node) -> SoulManipulable:
	var current: Node = start_node
	while current != null:
		if current is SoulManipulable:
			return current as SoulManipulable
		var direct_component: SoulManipulable = current.get_node_or_null("SoulManipulable") as SoulManipulable
		if direct_component != null:
			return direct_component
		current = current.get_parent()
	return null


func create_feedback_visuals() -> void:
	var soul_color: Color = Color(0.18, 0.92, 1.0, 0.82)
	var material := StandardMaterial3D.new()
	material.albedo_color = soul_color
	material.emission_enabled = true
	material.emission = Color(0.08, 0.7, 1.0, 1.0)
	material.emission_energy_multiplier = 2.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	tether_mesh = BoxMesh.new()
	tether_mesh.size = Vector3(tether_thickness, tether_thickness, 1.0)
	tether_visual = MeshInstance3D.new()
	tether_visual.name = "SoulTether"
	tether_visual.mesh = tether_mesh
	tether_visual.material_override = material
	tether_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tether_visual.visible = false
	add_child(tether_visual)

	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.28
	marker_mesh.height = 0.56
	marker_mesh.radial_segments = 14
	marker_mesh.rings = 8
	target_marker = MeshInstance3D.new()
	target_marker.name = "SoulGripMarker"
	target_marker.mesh = marker_mesh
	target_marker.material_override = material
	target_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_marker.visible = false
	add_child(target_marker)


func update_feedback_visuals() -> void:
	if held_target == null or player == null:
		hide_feedback_visuals()
		return

	var end_position: Vector3 = held_target.get_anchor_global_position()
	var start_position: Vector3 = player.global_position + Vector3.UP * 0.95
	var direction: Vector3 = end_position - start_position
	var length: float = direction.length()
	if length <= 0.01:
		hide_feedback_visuals()
		return

	tether_visual.visible = true
	tether_visual.global_position = (start_position + end_position) * 0.5
	var up: Vector3 = Vector3.UP
	if absf(direction.normalized().dot(up)) > 0.98:
		up = Vector3.RIGHT
	tether_visual.global_basis = Basis.looking_at(direction.normalized(), up)
	tether_mesh.size = Vector3(tether_thickness, tether_thickness, length)

	target_marker.visible = true
	target_marker.global_position = end_position
	var pulse: float = 1.0 + sin(float(Time.get_ticks_msec()) * 0.008) * 0.12
	target_marker.scale = Vector3.ONE * pulse


func hide_feedback_visuals() -> void:
	if tether_visual != null:
		tether_visual.visible = false
	if target_marker != null:
		target_marker.visible = false


func ensure_input_map() -> void:
	ensure_action(grip_action, 0.24)
	ensure_action(push_action, 0.2)
	ensure_action(pull_action, 0.2)
	ensure_action(rotate_left_action, 0.2)
	ensure_action(rotate_right_action, 0.2)

	ensure_key(grip_action, KEY_F)
	ensure_key(push_action, KEY_T)
	ensure_key(pull_action, KEY_G)
	ensure_key(rotate_left_action, KEY_Z)
	ensure_key(rotate_right_action, KEY_X)

	# Reserve the left shoulder for Soul Grip. Light attack still has its normal X
	# binding, while heavy attack remains on the right shoulder.
	remove_joy_button("weapon_light_attack", 9)
	ensure_joy_button(grip_action, 9)
	ensure_joy_button(push_action, 11)
	ensure_joy_button(pull_action, 12)
	ensure_joy_button(rotate_left_action, 13)
	ensure_joy_button(rotate_right_action, 14)


func ensure_action(action_name: String, deadzone: float) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, deadzone)


func ensure_key(action_name: String, physical_keycode: Key) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == physical_keycode:
				return
	var new_key_event := InputEventKey.new()
	new_key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, new_key_event)


func ensure_joy_button(action_name: String, button_index: int) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			var button_event: InputEventJoypadButton = event as InputEventJoypadButton
			if button_event.button_index == button_index:
				return
	var new_button_event := InputEventJoypadButton.new()
	new_button_event.button_index = button_index
	InputMap.action_add_event(action_name, new_button_event)


func remove_joy_button(action_name: String, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		return
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			var button_event: InputEventJoypadButton = event as InputEventJoypadButton
			if button_event.button_index == button_index:
				InputMap.action_erase_event(action_name, event)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"soul_grip": true,
		"active": held_target != null,
		"target": held_target.body.name if held_target != null and held_target.body != null else "none",
		"hold_distance": snapped(hold_distance, 0.01),
	}
