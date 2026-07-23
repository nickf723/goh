extends Node3D
class_name MetalTetherSpellController

const MetalTetherMaterial: FlexibleMaterialProfile = preload(
	"res://data/flexible_materials/metal_spell_tether.tres"
)

@export_group("Spell Channel")
@export var handled_spell_id: String = "metal_tether"
@export var channel_action: String = "cast_spell"
@export var reel_in_action: String = "tether_reel_in"
@export var reel_out_action: String = "tether_reel_out"

@export_group("Targeting")
@export_range(2.0, 40.0, 0.5) var maximum_anchor_range: float = 24.0
@export_range(5.0, 70.0, 1.0) var maximum_aim_angle_degrees: float = 31.0
@export_range(0.01, 0.5, 0.01) var target_refresh_interval: float = 0.08
@export var require_line_of_sight: bool = true

@export_group("Tether Length")
@export_range(1.0, 10.0, 0.1) var minimum_tether_length: float = 2.4
@export_range(4.0, 40.0, 0.5) var maximum_tether_length: float = 25.0
@export_range(0.5, 16.0, 0.25) var reel_speed: float = 6.0
@export_range(0.1, 3.0, 0.1) var reel_step: float = 0.75

@export_group("Swing Physics")
@export_range(1.0, 80.0, 0.5) var constraint_spring_acceleration: float = 28.0
@export_range(0.0, 20.0, 0.25) var radial_damping: float = 6.5
@export_range(0.0, 30.0, 0.5) var swing_input_acceleration: float = 12.0
@export_range(1.0, 40.0, 0.5) var maximum_swing_speed: float = 20.0
@export_range(0.01, 1.0, 0.01) var constraint_slack: float = 0.16
@export_range(0.01, 1.0, 0.01) var maximum_position_correction: float = 0.38
@export_range(1.0, 200.0, 1.0) var body_mass_kg: float = 65.0
@export_range(0.0, 2.0, 0.05) var airflow_response_multiplier: float = 0.8

@export_group("Presentation")
@export var show_messages: bool = true
@export var show_target_preview: bool = true
@export var show_predicted_arc: bool = true
@export_range(0.02, 0.5, 0.01) var prediction_refresh_interval: float = 0.08
@export_range(6, 48, 1) var prediction_steps: int = 24
@export_range(0.02, 0.2, 0.01) var prediction_step_seconds: float = 0.08

var actor: CharacterBody3D = null
var action_state: PlayerActionState = null
var airflow_response: Node = null
var aerial_locomotion: Node = null
var active_ability: AbilityDefinition = null

var tether_active: bool = false
var active_anchor: Node3D = null
var preview_anchor: Node3D = null
var tether_length: float = 0.0
var current_distance: float = 0.0
var current_tension: float = 0.0
var peak_tension: float = 0.0
var radial_speed: float = 0.0
var tangential_speed: float = 0.0
var last_airflow_acceleration: Vector3 = Vector3.ZERO

var target_refresh_timer: float = 0.0
var prediction_refresh_timer: float = 0.0
var visual_root: Node3D = null
var player_endpoint: Node3D = null
var anchor_endpoint: Node3D = null
var tether_simulation: FlexibleTether3D = null
var prediction_mesh_instance: MeshInstance3D = null
var target_marker: Node3D = null
var target_marker_material: StandardMaterial3D = null
var elapsed: float = 0.0


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor != null:
		action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
		airflow_response = actor.get_node_or_null("AirflowResponse")
		aerial_locomotion = actor.get_node_or_null("AerialLocomotion")
	add_to_group("debuggable")
	add_to_group("metal_tether_controllers")
	add_to_group("player_ability_channels")
	ensure_tether_input_map()
	call_deferred("_ensure_target_marker")


func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	if actor == null:
		return

	if tether_active:
		if not _anchor_is_available(active_anchor):
			release_tether("anchor failed", true)
		elif (
			not current_ability_is_tether()
			or not Input.is_action_pressed(channel_action)
			or (
				actor.has_method("is_focus_spell_menu_open")
				and bool(actor.call("is_focus_spell_menu_open"))
			)
		):
			release_tether("released", true)
		else:
			_update_active_visual()
		return

	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0:
		target_refresh_timer = maxf(target_refresh_interval, 0.02)
		preview_anchor = find_best_anchor() if current_ability_is_tether() else null
	_update_target_marker()


func _exit_tree() -> void:
	release_tether("scene exit", false)
	if is_instance_valid(target_marker):
		target_marker.queue_free()


func can_handle_ability(ability: AbilityDefinition) -> bool:
	return ability != null and ability.get_spell_id() == handled_spell_id


func begin_ability_channel(source_player: Node3D, ability: AbilityDefinition) -> bool:
	if source_player != actor or not can_handle_ability(ability):
		return false
	if tether_active:
		return true

	var chosen_anchor: Node3D = find_best_anchor()
	if chosen_anchor == null:
		show_message("Metal Tether found no visible anchor.")
		return false
	return attach_to_anchor(chosen_anchor, ability)


func cancel_ability_channel() -> void:
	release_tether("cancelled", false)


func attach_to_anchor(anchor: Node3D, ability: AbilityDefinition = null) -> bool:
	if actor == null or not _anchor_is_available(anchor):
		return false

	var anchor_position: Vector3 = _get_anchor_position(anchor)
	var distance: float = actor.global_position.distance_to(anchor_position)
	if distance < 0.5 or distance > maximum_anchor_range:
		return false

	active_anchor = anchor
	active_ability = ability
	tether_active = true
	tether_length = clampf(
		distance,
		minimum_tether_length,
		minf(maximum_tether_length, maximum_anchor_range)
	)
	current_distance = distance
	current_tension = 0.0
	peak_tension = 0.0
	radial_speed = 0.0
	tangential_speed = actor.velocity.length()
	preview_anchor = null
	prediction_refresh_timer = 0.0

	if active_anchor.has_method("notify_tether_attached"):
		active_anchor.call("notify_tether_attached", actor)
	_build_active_visual()
	_set_aerial_state("metal_tether")
	show_message("Metal Tether attached to " + _get_anchor_display_name(active_anchor) + ".")
	return true


func release_tether(reason: String = "released", should_show_message: bool = false) -> void:
	if not tether_active and active_anchor == null:
		return

	var released_anchor: Node3D = active_anchor
	if is_instance_valid(released_anchor) and released_anchor.has_method("notify_tether_released"):
		released_anchor.call("notify_tether_released", actor)

	tether_active = false
	active_anchor = null
	active_ability = null
	current_tension = 0.0
	radial_speed = 0.0
	tangential_speed = actor.velocity.length() if actor != null else 0.0
	_destroy_active_visual()
	_set_aerial_state("grounded" if actor != null and actor.is_on_floor() else "falling")

	if should_show_message:
		if reason == "anchor failed":
			show_message("Metal Tether released: the anchor failed.")
		elif reason == "filament failed":
			show_message("Metal Tether overloaded and snapped.")
		else:
			show_message("Metal Tether released. Momentum preserved.")


func should_handle_locomotion() -> bool:
	return tether_active and is_instance_valid(active_anchor)


func process_locomotion(delta: float) -> bool:
	if actor == null or not tether_active or not _anchor_is_available(active_anchor):
		release_tether("anchor failed", true)
		return false
	if bool(actor.get("is_defeated")):
		release_tether("defeated", false)
		return false
	if Input.is_action_just_pressed("dodge"):
		release_tether("dodge release", false)
		return false

	var anchor_position: Vector3 = _get_anchor_position(active_anchor)
	var player_position: Vector3 = actor.global_position
	var offset: Vector3 = player_position - anchor_position
	current_distance = offset.length()
	if current_distance <= 0.01:
		return false

	_update_reeling(delta)
	var radial_direction: Vector3 = offset / current_distance
	var can_move: bool = action_state == null or action_state.can_move()
	var move_direction: Vector3 = _get_camera_relative_move_direction() if can_move else Vector3.ZERO
	var was_on_floor: bool = actor.is_on_floor()
	var gravity_value: float = float(actor.get("gravity"))

	if was_on_floor:
		if Input.is_action_just_pressed("jump") and can_move:
			actor.velocity.y = float(actor.get("jump_velocity"))
		elif actor.velocity.y < 0.0:
			actor.velocity.y = -0.1
	else:
		actor.velocity.y -= gravity_value * delta

	var taut: bool = current_distance >= tether_length - constraint_slack
	if was_on_floor and not taut:
		var move_speed: float = float(actor.get("move_speed"))
		actor.velocity.x = move_toward(actor.velocity.x, move_direction.x * move_speed, 28.0 * delta)
		actor.velocity.z = move_toward(actor.velocity.z, move_direction.z * move_speed, 28.0 * delta)
	elif move_direction.length_squared() > 0.001:
		var tangent_input: Vector3 = move_direction - radial_direction * move_direction.dot(radial_direction)
		if tangent_input.length_squared() > 0.001:
			actor.velocity += tangent_input.normalized() * swing_input_acceleration * delta

	radial_speed = actor.velocity.dot(radial_direction)
	var tangential_velocity: Vector3 = actor.velocity - radial_direction * radial_speed
	tangential_speed = tangential_velocity.length()
	var extension: float = maxf(current_distance - tether_length, 0.0)
	var centripetal_acceleration: float = 0.0
	if taut:
		centripetal_acceleration = tangential_speed * tangential_speed / maxf(tether_length, 1.0)
	var constraint_acceleration: float = (
		extension * constraint_spring_acceleration
		+ maxf(radial_speed, 0.0) * radial_damping
		+ centripetal_acceleration
	)

	if taut:
		actor.velocity -= radial_direction * constraint_acceleration * delta
		var outward_speed: float = actor.velocity.dot(radial_direction)
		if outward_speed > 0.0:
			actor.velocity -= radial_direction * outward_speed

	_apply_airflow(delta)
	if actor.velocity.length() > maximum_swing_speed:
		actor.velocity = actor.velocity.normalized() * maximum_swing_speed

	actor.move_and_slide()
	_apply_position_constraint(anchor_position)

	current_tension = body_mass_kg * maxf(constraint_acceleration, 0.0)
	peak_tension = maxf(peak_tension, current_tension)
	if tether_simulation != null:
		tether_simulation.current_tension = current_tension

	if current_tension > MetalTetherMaterial.break_strength:
		release_tether("filament failed", true)
		return true
	if active_anchor.has_method("receive_tether_tension"):
		var anchor_holds: bool = bool(
			active_anchor.call("receive_tether_tension", current_tension, actor.global_position)
		)
		if not anchor_holds:
			release_tether("anchor failed", true)
			return true

	_update_active_visual()
	_set_aerial_state("metal_tether")
	return true


func find_best_anchor() -> Node3D:
	if actor == null or get_tree() == null:
		return null

	var origin: Vector3 = actor.global_position + Vector3.UP * 0.72
	var camera: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3 = -actor.global_transform.basis.z
	if camera != null:
		origin = camera.global_position
		forward = -camera.global_transform.basis.z
	forward = forward.normalized()

	var minimum_dot: float = cos(deg_to_rad(maximum_aim_angle_degrees))
	var best_anchor: Node3D = null
	var best_score: float = INF
	for candidate_node: Node in get_tree().get_nodes_in_group("metal_tether_anchors"):
		if not candidate_node is Node3D:
			continue
		var candidate: Node3D = candidate_node as Node3D
		if not _anchor_is_available(candidate):
			continue
		var target_position: Vector3 = _get_anchor_position(candidate)
		var to_target: Vector3 = target_position - origin
		var distance: float = actor.global_position.distance_to(target_position)
		if distance < 0.75 or distance > maximum_anchor_range or to_target.length_squared() <= 0.001:
			continue
		var direction: Vector3 = to_target.normalized()
		var aim_dot: float = forward.dot(direction)
		if aim_dot < minimum_dot:
			continue
		if require_line_of_sight and not _has_line_of_sight(origin, target_position, candidate):
			continue
		var angle_cost: float = (1.0 - aim_dot) * 38.0
		var distance_cost: float = distance / maximum_anchor_range
		var score: float = angle_cost + distance_cost
		if score < best_score:
			best_score = score
			best_anchor = candidate
	return best_anchor


func current_ability_is_tether() -> bool:
	if actor == null:
		return false
	var ability_caster: Node = actor.get_node_or_null("AbilityCaster")
	if ability_caster == null or not ability_caster.has_method("get_current_ability"):
		return false
	var ability: AbilityDefinition = ability_caster.call("get_current_ability") as AbilityDefinition
	return can_handle_ability(ability)


func _anchor_is_available(anchor: Node3D) -> bool:
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return false
	if anchor.has_method("can_accept_tether"):
		return bool(anchor.call("can_accept_tether", actor))
	return true


func _get_anchor_position(anchor: Node3D) -> Vector3:
	if anchor == null:
		return actor.global_position if actor != null else global_position
	if anchor.has_method("get_tether_anchor_position"):
		var value: Variant = anchor.call("get_tether_anchor_position")
		if value is Vector3:
			return value as Vector3
	return anchor.global_position


func _get_anchor_display_name(anchor: Node3D) -> String:
	if anchor == null:
		return "anchor"
	var value: Variant = anchor.get("display_name")
	return str(value) if value != null and str(value) != "" else anchor.name.capitalize()


func _has_line_of_sight(origin: Vector3, target: Vector3, anchor: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if actor is CollisionObject3D:
		query.exclude = [actor.get_rid()]
	var result: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider: Node = result.get("collider") as Node
	return _collider_matches_anchor(collider, anchor)


func _collider_matches_anchor(collider: Node, anchor: Node3D) -> bool:
	if collider == null or anchor == null:
		return false
	var anchor_body: Node = anchor.get_parent()
	if anchor.has_method("get_tether_anchor_body"):
		anchor_body = anchor.call("get_tether_anchor_body") as Node
	var current: Node = collider
	while current != null:
		if current == anchor or current == anchor_body:
			return true
		current = current.get_parent()
	return false


func _update_reeling(delta: float) -> void:
	var reel_delta: float = 0.0
	if Input.is_action_pressed(reel_in_action):
		reel_delta -= reel_speed * delta
	if Input.is_action_pressed(reel_out_action):
		reel_delta += reel_speed * delta
	if Input.is_action_just_pressed(reel_in_action):
		reel_delta -= reel_step
	if Input.is_action_just_pressed(reel_out_action):
		reel_delta += reel_step
	tether_length = clampf(
		tether_length + reel_delta,
		minimum_tether_length,
		minf(maximum_tether_length, maximum_anchor_range)
	)


func _get_camera_relative_move_direction() -> Vector3:
	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	if input_vector.length() <= 0.01:
		return Vector3.ZERO

	var forward: Vector3 = -actor.global_transform.basis.z
	var right: Vector3 = actor.global_transform.basis.x
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		forward = -camera.global_transform.basis.z
		right = camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var direction: Vector3 = right * input_vector.x + forward * -input_vector.y
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO


func _apply_airflow(delta: float) -> void:
	last_airflow_acceleration = Vector3.ZERO
	if airflow_response == null or not airflow_response.has_method("get_airflow_acceleration"):
		return
	var value: Variant = airflow_response.call(
		"get_airflow_acceleration",
		actor.global_position,
		actor.velocity,
		body_mass_kg,
		airflow_response_multiplier
	)
	if value is Vector3:
		last_airflow_acceleration = value as Vector3
		actor.velocity += last_airflow_acceleration * delta


func _apply_position_constraint(anchor_position: Vector3) -> void:
	var offset: Vector3 = actor.global_position - anchor_position
	var distance: float = offset.length()
	var maximum_distance: float = tether_length + constraint_slack
	if distance <= maximum_distance or distance <= 0.01:
		return
	var correction: float = minf(distance - maximum_distance, maximum_position_correction)
	var radial_direction: Vector3 = offset / distance
	actor.global_position -= radial_direction * correction
	var outward_speed: float = actor.velocity.dot(radial_direction)
	if outward_speed > 0.0:
		actor.velocity -= radial_direction * outward_speed


func _build_active_visual() -> void:
	_destroy_active_visual()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	visual_root = Node3D.new()
	visual_root.name = "MetalTetherRuntimeVisual"
	visual_root.top_level = true
	scene_root.add_child(visual_root)

	player_endpoint = Node3D.new()
	player_endpoint.name = "PlayerEndpoint"
	visual_root.add_child(player_endpoint)
	anchor_endpoint = Node3D.new()
	anchor_endpoint.name = "AnchorEndpoint"
	visual_root.add_child(anchor_endpoint)

	tether_simulation = FlexibleTether3D.new()
	tether_simulation.name = "FlexibleMetalTether"
	tether_simulation.endpoint_a_path = NodePath("../PlayerEndpoint")
	tether_simulation.endpoint_b_path = NodePath("../AnchorEndpoint")
	tether_simulation.material_profile = MetalTetherMaterial
	tether_simulation.rest_length = tether_length
	tether_simulation.segment_count = 18
	tether_simulation.constraint_iterations = 9
	tether_simulation.verlet_damping = 0.982
	tether_simulation.gravity_scale = 0.18
	tether_simulation.apply_endpoint_forces = false
	tether_simulation.debug_tension_color = true
	tether_simulation.tether_broken.connect(_on_visual_tether_broken)
	visual_root.add_child(tether_simulation)

	prediction_mesh_instance = MeshInstance3D.new()
	prediction_mesh_instance.name = "PredictedSwingArc"
	prediction_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(prediction_mesh_instance)
	_update_active_visual()


func _destroy_active_visual() -> void:
	if is_instance_valid(visual_root):
		visual_root.queue_free()
	visual_root = null
	player_endpoint = null
	anchor_endpoint = null
	tether_simulation = null
	prediction_mesh_instance = null


func _update_active_visual() -> void:
	if not tether_active or not is_instance_valid(active_anchor):
		return
	if player_endpoint != null:
		player_endpoint.global_position = actor.global_position + Vector3.UP * 0.62
	if anchor_endpoint != null:
		anchor_endpoint.global_position = _get_anchor_position(active_anchor)
	if tether_simulation != null:
		tether_simulation.rest_length = tether_length
	prediction_refresh_timer -= get_process_delta_time()
	if show_predicted_arc and prediction_refresh_timer <= 0.0:
		prediction_refresh_timer = maxf(prediction_refresh_interval, 0.02)
		_rebuild_prediction_arc()


func _rebuild_prediction_arc() -> void:
	if prediction_mesh_instance == null or actor == null or active_anchor == null:
		return
	var immediate: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.82, 0.18, 0.68)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.58, 0.05, 1.0)
	material.emission_energy_multiplier = 1.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)

	var point: Vector3 = actor.global_position + Vector3.UP * 0.1
	var simulated_velocity: Vector3 = actor.velocity
	var anchor_position: Vector3 = _get_anchor_position(active_anchor)
	var gravity_value: float = float(actor.get("gravity"))
	immediate.surface_add_vertex(point)
	for _step: int in range(prediction_steps):
		simulated_velocity.y -= gravity_value * prediction_step_seconds
		point += simulated_velocity * prediction_step_seconds
		var offset: Vector3 = point - anchor_position
		var distance: float = offset.length()
		if distance > tether_length and distance > 0.01:
			var radial_direction: Vector3 = offset / distance
			point = anchor_position + radial_direction * tether_length
			var outward_speed: float = simulated_velocity.dot(radial_direction)
			if outward_speed > 0.0:
				simulated_velocity -= radial_direction * outward_speed
		immediate.surface_add_vertex(point)
	immediate.surface_end()
	prediction_mesh_instance.mesh = immediate


func _ensure_target_marker() -> void:
	if target_marker != null or get_tree() == null or get_tree().current_scene == null:
		return
	target_marker = Node3D.new()
	target_marker.name = "MetalTetherTargetPreview"
	target_marker.top_level = true
	get_tree().current_scene.add_child(target_marker)

	var sphere: MeshInstance3D = MeshInstance3D.new()
	sphere.name = "AnchorCore"
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.18
	sphere_mesh.height = 0.36
	sphere.mesh = sphere_mesh
	target_marker_material = StandardMaterial3D.new()
	target_marker_material.albedo_color = Color(1.0, 0.82, 0.2, 0.76)
	target_marker_material.emission_enabled = true
	target_marker_material.emission = Color(1.0, 0.55, 0.05, 1.0)
	target_marker_material.emission_energy_multiplier = 2.2
	target_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	target_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material_override = target_marker_material
	target_marker.add_child(sphere)

	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "AimRing"
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.28
	ring_mesh.outer_radius = 0.36
	ring.mesh = ring_mesh
	ring.material_override = target_marker_material
	target_marker.add_child(ring)
	target_marker.visible = false


func _update_target_marker() -> void:
	if target_marker == null:
		return
	target_marker.visible = (
		show_target_preview
		and not tether_active
		and preview_anchor != null
		and is_instance_valid(preview_anchor)
	)
	if not target_marker.visible:
		return
	target_marker.global_position = _get_anchor_position(preview_anchor)
	target_marker.rotation.y = elapsed * 2.4
	var pulse: float = 1.0 + sin(elapsed * 7.0) * 0.12
	target_marker.scale = Vector3.ONE * pulse


func _on_visual_tether_broken(_reason: String, _peak: float) -> void:
	if tether_active:
		release_tether("filament failed", true)


func _set_aerial_state(state: String) -> void:
	if aerial_locomotion != null and aerial_locomotion.has_method("set_traversal_state"):
		aerial_locomotion.call("set_traversal_state", state)


func ensure_tether_input_map() -> void:
	_ensure_action(reel_in_action)
	_ensure_action(reel_out_action)
	_ensure_key(reel_in_action, KEY_R)
	_ensure_key(reel_out_action, KEY_F)
	_ensure_joy_button(reel_in_action, JOY_BUTTON_DPAD_UP)
	_ensure_joy_button(reel_out_action, JOY_BUTTON_DPAD_DOWN)
	_ensure_mouse_button(reel_in_action, MOUSE_BUTTON_WHEEL_UP)
	_ensure_mouse_button(reel_out_action, MOUSE_BUTTON_WHEEL_DOWN)


func _ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)


func _ensure_key(action_name: String, physical_keycode: Key) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == physical_keycode:
			return
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, event)


func _ensure_joy_button(action_name: String, button_index: JoyButton) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)


func _ensure_mouse_button(action_name: String, button_index: MouseButton) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button_index:
			return
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)


func show_message(text: String) -> void:
	if not show_messages:
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	var anchor_strength: float = 0.0
	if is_instance_valid(active_anchor):
		var strength_value: Variant = active_anchor.get("break_strength")
		if strength_value != null:
			anchor_strength = float(strength_value)
	return {
		"spell_id": handled_spell_id,
		"equipped": current_ability_is_tether(),
		"active": tether_active,
		"anchor": _get_anchor_display_name(active_anchor) if is_instance_valid(active_anchor) else "none",
		"preview_anchor": _get_anchor_display_name(preview_anchor) if is_instance_valid(preview_anchor) else "none",
		"length": snapped(tether_length, 0.1),
		"distance": snapped(current_distance, 0.1),
		"tension": snapped(current_tension, 1.0),
		"peak_tension": snapped(peak_tension, 1.0),
		"anchor_strength": snapped(anchor_strength, 1.0),
		"radial_speed": snapped(radial_speed, 0.1),
		"tangential_speed": snapped(tangential_speed, 0.1),
		"velocity": actor.velocity if actor != null else Vector3.ZERO,
		"airflow_acceleration": last_airflow_acceleration,
		"prediction_visible": show_predicted_arc and tether_active,
	}
