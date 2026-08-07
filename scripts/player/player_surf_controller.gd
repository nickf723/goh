extends Node3D
class_name PlayerSurfController

signal surf_started(speed: float, refreshed: bool)
signal surf_ended(reason: String, distance_travelled: float)
signal surface_hazard_negated(source_name: String, element: String)

@export_group("Locomotion")
@export_range(2.0, 30.0, 0.1) var launch_speed: float = 8.5
@export_range(2.0, 40.0, 0.1) var maximum_speed: float = 12.5
@export_range(1.0, 60.0, 0.5) var acceleration: float = 18.0
@export_range(1.0, 180.0, 1.0) var turn_rate_degrees: float = 72.0
@export_range(0.0, 20.0, 0.1) var coasting_drag: float = 3.0
@export_range(0.0, 1.0, 0.01) var input_deadzone: float = 0.12
@export_range(0.05, 1.0, 0.01) var startup_input_grace_seconds: float = 0.34
@export_range(0.05, 1.0, 0.01) var idle_cancel_seconds: float = 0.22
@export_range(0.1, 2.0, 0.05) var blocked_cancel_seconds: float = 0.65
@export_range(0.1, 2.0, 0.05) var airborne_cancel_seconds: float = 0.7
@export_range(0.1, 8.0, 0.1) var minimum_active_speed: float = 2.5

@export_group("Presentation")
@export_range(0.2, 2.0, 0.05) var wave_width: float = 1.15
@export_range(0.2, 3.0, 0.05) var wave_length: float = 1.65
@export_range(0.05, 1.0, 0.05) var wave_height: float = 0.22
@export_range(5.0, 120.0, 1.0) var visual_updates_per_second: float = 30.0
@export_range(3, 24, 1) var foam_segment_count: int = 9

var actor: CharacterBody3D
var active: bool = false
var surf_direction: Vector3 = Vector3.FORWARD
var current_speed: float = 0.0
var active_elapsed: float = 0.0
var idle_elapsed: float = 0.0
var blocked_elapsed: float = 0.0
var airborne_elapsed: float = 0.0
var visual_accumulator: float = 0.0
var distance_travelled: float = 0.0
var activation_count: int = 0
var cancellation_count: int = 0
var hazard_negation_count: int = 0
var last_end_reason: String = "never_started"
var last_hazard_source: String = "none"
var last_hazard_element: String = "none"
var actor_physics_was_enabled: bool = true
var saved_floor_snap_length: float = 0.0
var test_input_override_enabled: bool = false
var test_input_vector: Vector2 = Vector2.ZERO

var visual_root: Node3D
var water_hump: MeshInstance3D
var water_tail: MeshInstance3D
var foam_visual: MultiMeshInstance3D
var foam_multimesh: MultiMesh
var foam_mesh: BoxMesh
var water_material: StandardMaterial3D
var tail_material: StandardMaterial3D
var foam_material: StandardMaterial3D


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	add_to_group("surf_controllers")
	add_to_group("debuggable")
	_build_visuals()
	set_physics_process(false)


func _exit_tree() -> void:
	if active:
		_restore_actor_locomotion()


func activate_surf(initial_direction: Vector3 = Vector3.ZERO) -> Dictionary:
	if actor == null or not is_instance_valid(actor):
		return {
			"activated": false,
			"reason": "missing_actor",
		}

	var refreshed: bool = active
	var input_vector: Vector2 = _get_input_vector()
	var requested_direction: Vector3 = _input_to_world_direction(input_vector)
	if requested_direction.length_squared() <= 0.0001:
		requested_direction = initial_direction
		requested_direction.y = 0.0
	if requested_direction.length_squared() <= 0.0001:
		requested_direction = -actor.global_transform.basis.z
		requested_direction.y = 0.0
	if requested_direction.length_squared() <= 0.0001:
		requested_direction = Vector3.FORWARD
	requested_direction = requested_direction.normalized()

	if not active:
		actor_physics_was_enabled = actor.is_physics_processing()
		saved_floor_snap_length = actor.floor_snap_length
		actor.set_physics_process(false)
		active = true
		active_elapsed = 0.0
		idle_elapsed = 0.0
		blocked_elapsed = 0.0
		airborne_elapsed = 0.0
		distance_travelled = 0.0
	else:
		active_elapsed = 0.0
		idle_elapsed = 0.0

	surf_direction = requested_direction
	var existing_speed: float = Vector3(
		actor.velocity.x,
		0.0,
		actor.velocity.z
	).length()
	current_speed = maxf(maxf(current_speed, existing_speed), launch_speed)
	current_speed = minf(current_speed, maximum_speed)
	activation_count += 1
	last_end_reason = "active"
	actor.set_meta("surf_active", true)
	actor.set_meta("surf_surface_hazard_immunity", true)
	actor.set_meta("surf_speed", current_speed)
	if not actor.is_in_group("surfing_actor"):
		actor.add_to_group("surfing_actor")
	_set_spell_effect_groups(true)
	_set_visual_visible(true)
	_update_visuals(0.0)
	set_physics_process(true)
	surf_started.emit(current_speed, refreshed)
	return {
		"activated": true,
		"refreshed": refreshed,
		"speed": current_speed,
		"direction": surf_direction,
	}


func is_surf_active() -> bool:
	return active


func is_surface_hazard_protected() -> bool:
	return active


func should_handle_locomotion() -> bool:
	return active


func cancel_surf(reason: String = "cancelled") -> void:
	if not active:
		return
	active = false
	cancellation_count += 1
	last_end_reason = reason
	_restore_actor_locomotion()
	_set_spell_effect_groups(false)
	_set_visual_visible(false)
	set_physics_process(false)
	surf_ended.emit(reason, distance_travelled)


func reset_target() -> void:
	cancel_surf("reset")
	current_speed = 0.0
	active_elapsed = 0.0
	idle_elapsed = 0.0
	blocked_elapsed = 0.0
	airborne_elapsed = 0.0
	distance_travelled = 0.0
	hazard_negation_count = 0
	last_hazard_source = "none"
	last_hazard_element = "none"
	test_input_override_enabled = false
	test_input_vector = Vector2.ZERO


func set_test_input_override(
	input_vector: Vector2,
	enabled: bool = true
) -> void:
	test_input_vector = input_vector.limit_length(1.0)
	test_input_override_enabled = enabled


func record_hazard_negation(payload: DamagePayload) -> void:
	hazard_negation_count += 1
	last_hazard_source = (
		payload.source_name if payload != null else "Surface Hazard"
	)
	last_hazard_element = (
		payload.element if payload != null else "neutral"
	)
	surface_hazard_negated.emit(last_hazard_source, last_hazard_element)


func get_hazard_negation_count() -> int:
	return hazard_negation_count


func _physics_process(delta: float) -> void:
	advance_surf(delta)


func advance_surf(delta: float) -> bool:
	if not active:
		return false
	if actor == null or not is_instance_valid(actor):
		cancel_surf("missing_actor")
		return false
	if bool(actor.get("is_defeated")):
		cancel_surf("defeated")
		return false
	if _is_interrupting_state_active():
		cancel_surf("interrupted")
		return false

	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return true
	active_elapsed += step
	var input_vector: Vector2 = _get_input_vector()
	var input_strength: float = clampf(input_vector.length(), 0.0, 1.0)
	var has_input: bool = input_strength > input_deadzone

	if has_input:
		idle_elapsed = 0.0
		var desired_direction: Vector3 = _input_to_world_direction(input_vector)
		if desired_direction.length_squared() > 0.0001:
			surf_direction = _turn_toward_direction(
				surf_direction,
				desired_direction,
				deg_to_rad(turn_rate_degrees) * step
			)
		var target_speed: float = lerpf(
			launch_speed,
			maximum_speed,
			input_strength
		)
		current_speed = move_toward(
			current_speed,
			target_speed,
			maxf(acceleration, 0.0) * step
		)
	else:
		idle_elapsed += step
		current_speed = move_toward(
			current_speed,
			0.0,
			maxf(coasting_drag, 0.0) * step
		)
		if (
			active_elapsed >= startup_input_grace_seconds
			and idle_elapsed >= idle_cancel_seconds
		):
			cancel_surf("idle")
			return false

	if current_speed < minimum_active_speed:
		cancel_surf("lost_momentum")
		return false

	var before_position: Vector3 = actor.global_position
	actor.velocity.x = surf_direction.x * current_speed
	actor.velocity.z = surf_direction.z * current_speed
	if not actor.is_on_floor():
		actor.velocity.y -= _get_actor_gravity() * step
	else:
		airborne_elapsed = 0.0
		if actor.velocity.y < 0.0:
			actor.velocity.y = -0.1

	actor.move_and_slide()
	var displacement: Vector3 = actor.global_position - before_position
	var planar_displacement := Vector3(displacement.x, 0.0, displacement.z)
	var moved_distance: float = planar_displacement.length()
	distance_travelled += moved_distance
	var actual_planar_velocity := Vector3(
		actor.velocity.x,
		0.0,
		actor.velocity.z
	)
	if actual_planar_velocity.length_squared() > 0.04:
		surf_direction = actual_planar_velocity.normalized()
		current_speed = minf(
			maxf(actual_planar_velocity.length(), minimum_active_speed),
			maximum_speed
		)

	var expected_distance: float = maxf(current_speed * step, 0.001)
	if has_input and moved_distance < expected_distance * 0.12:
		blocked_elapsed += step
	else:
		blocked_elapsed = maxf(blocked_elapsed - step * 2.0, 0.0)
	if blocked_elapsed >= blocked_cancel_seconds:
		cancel_surf("blocked")
		return false

	if actor.is_on_floor():
		airborne_elapsed = 0.0
	else:
		airborne_elapsed += step
		if airborne_elapsed >= airborne_cancel_seconds:
			cancel_surf("airborne")
			return false

	actor.set_meta("surf_speed", current_speed)
	_record_external_motion()
	visual_accumulator += step
	var visual_interval: float = 1.0 / maxf(
		visual_updates_per_second,
		1.0
	)
	if visual_accumulator >= visual_interval:
		visual_accumulator = fmod(visual_accumulator, visual_interval)
		_update_visuals(active_elapsed)
	return true


func _get_input_vector() -> Vector2:
	if test_input_override_enabled:
		return test_input_vector
	return Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)


func _input_to_world_direction(input_vector: Vector2) -> Vector3:
	if actor == null or input_vector.length() <= input_deadzone:
		return Vector3.ZERO
	var direction: Vector3 = (
		actor.global_transform.basis.x * input_vector.x
		+ actor.global_transform.basis.z * input_vector.y
	)
	direction.y = 0.0
	return (
		direction.normalized()
		if direction.length_squared() > 0.0001
		else Vector3.ZERO
	)


func _turn_toward_direction(
	current: Vector3,
	desired: Vector3,
	maximum_angle: float
) -> Vector3:
	var from: Vector3 = Vector3(current.x, 0.0, current.z)
	var to: Vector3 = Vector3(desired.x, 0.0, desired.z)
	if to.length_squared() <= 0.0001:
		return from.normalized() if from.length_squared() > 0.0001 else Vector3.FORWARD
	to = to.normalized()
	if from.length_squared() <= 0.0001:
		return to
	from = from.normalized()
	var dot_value: float = clampf(from.dot(to), -1.0, 1.0)
	var angle: float = acos(dot_value)
	if angle <= maximum_angle or angle <= 0.0001:
		return to
	if dot_value <= -0.995:
		var turn_sign: float = (
			1.0 if from.cross(to).y >= 0.0 else -1.0
		)
		return from.rotated(Vector3.UP, maximum_angle * turn_sign).normalized()
	return from.slerp(to, maximum_angle / angle).normalized()


func _get_actor_gravity() -> float:
	if actor == null:
		return 18.0
	var gravity_value: Variant = actor.get("gravity")
	return maxf(float(gravity_value), 0.0) if gravity_value != null else 18.0


func _is_interrupting_state_active() -> bool:
	if actor == null:
		return false
	var defense: Node = actor.get_node_or_null("PlayerDefenseController")
	if (
		defense != null
		and defense.has_method("is_hit_reaction_active")
		and bool(defense.call("is_hit_reaction_active"))
	):
		return true
	var dodge: Node = actor.get_node_or_null("PlayerDodgeController")
	return (
		dodge != null
		and dodge.has_method("is_dodge_active")
		and bool(dodge.call("is_dodge_active"))
	)


func _record_external_motion() -> void:
	if actor == null:
		return
	var motor: Node = actor.get_node_or_null("GroundMotionMotor")
	if motor == null:
		return
	var planar_velocity := Vector3(
		actor.velocity.x,
		0.0,
		actor.velocity.z
	)
	if motor.has_method("capture_external_velocity"):
		motor.call("capture_external_velocity", planar_velocity, "surf")
	if motor.has_method("record_post_move"):
		motor.call("record_post_move", planar_velocity)


func _restore_actor_locomotion() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.remove_meta("surf_active")
	actor.remove_meta("surf_surface_hazard_immunity")
	actor.remove_meta("surf_speed")
	if actor.is_in_group("surfing_actor"):
		actor.remove_from_group("surfing_actor")
	actor.floor_snap_length = saved_floor_snap_length
	actor.set_physics_process(actor_physics_was_enabled)


func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "SurfWaveVisualRoot"
	add_child(visual_root)

	water_material = _make_water_material(
		Color(0.08, 0.52, 0.94, 0.7),
		Color(0.04, 0.42, 1.0),
		2.0
	)
	tail_material = _make_water_material(
		Color(0.04, 0.34, 0.76, 0.44),
		Color(0.02, 0.28, 0.82),
		1.35
	)
	foam_material = _make_water_material(
		Color(0.76, 0.96, 1.0, 0.86),
		Color(0.54, 0.92, 1.0),
		2.8
	)
	foam_material.vertex_color_use_as_albedo = true

	water_hump = MeshInstance3D.new()
	water_hump.name = "SurfWaveHump"
	water_hump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hump_mesh := SphereMesh.new()
	hump_mesh.radius = 1.0
	hump_mesh.height = 2.0
	hump_mesh.radial_segments = 20
	hump_mesh.rings = 10
	water_hump.mesh = hump_mesh
	water_hump.material_override = water_material
	water_hump.scale = Vector3(wave_width, wave_height, wave_length)
	visual_root.add_child(water_hump)

	water_tail = MeshInstance3D.new()
	water_tail.name = "SurfWaveTail"
	water_tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_tail.mesh = hump_mesh
	water_tail.material_override = tail_material
	water_tail.position = Vector3(0.0, -0.04, 0.7)
	water_tail.scale = Vector3(
		wave_width * 0.8,
		wave_height * 0.55,
		wave_length * 1.25
	)
	visual_root.add_child(water_tail)

	foam_mesh = BoxMesh.new()
	foam_mesh.size = Vector3.ONE
	foam_multimesh = MultiMesh.new()
	foam_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	foam_multimesh.use_colors = true
	foam_multimesh.mesh = foam_mesh
	foam_multimesh.instance_count = maxi(foam_segment_count, 1)
	foam_visual = MultiMeshInstance3D.new()
	foam_visual.name = "SurfFoamSegments"
	foam_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam_visual.material_override = foam_material
	foam_visual.multimesh = foam_multimesh
	visual_root.add_child(foam_visual)
	_set_visual_visible(false)


func _make_water_material(
	albedo: Color,
	emission_color: Color,
	energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material


func _update_visuals(time_value: float) -> void:
	if actor == null or visual_root == null:
		return
	var forward: Vector3 = surf_direction
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right: Vector3 = forward.cross(Vector3.UP)
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var basis := Basis(right, Vector3.UP, -forward).orthonormalized()
	global_transform = Transform3D(
		basis,
		actor.global_position + Vector3.UP * -0.79
	)
	var pulse: float = sin(time_value * 8.0) * 0.035
	water_hump.scale = Vector3(
		wave_width * (1.0 + pulse),
		wave_height * (1.0 - pulse * 0.5),
		wave_length * (1.0 - pulse * 0.25)
	)
	water_tail.position.y = -0.05 + sin(time_value * 6.2 + 0.8) * 0.025
	_update_foam_transforms(time_value)


func _update_foam_transforms(time_value: float) -> void:
	if foam_multimesh == null:
		return
	var count: int = foam_multimesh.instance_count
	for segment_index: int in range(count):
		var ratio: float = (
			0.5 if count <= 1 else float(segment_index) / float(count - 1)
		)
		var x_position: float = lerpf(-wave_width * 0.88, wave_width * 0.88, ratio)
		var arch: float = 1.0 - absf(ratio * 2.0 - 1.0)
		var y_position: float = wave_height * 0.78 + sin(
			time_value * 11.0 + float(segment_index) * 0.9
		) * 0.025
		var z_position: float = -wave_length * 0.45 + arch * 0.18
		var segment_basis := Basis.IDENTITY.scaled(
			Vector3(
				maxf(wave_width * 0.19, 0.06),
				0.035,
				0.2 + arch * 0.12
			)
		)
		foam_multimesh.set_instance_transform(
			segment_index,
			Transform3D(
				segment_basis,
				Vector3(x_position, y_position, z_position)
			)
		)
		foam_multimesh.set_instance_color(
			segment_index,
			Color(0.78, 0.95, 1.0, 0.64 + arch * 0.28)
		)


func _set_visual_visible(value: bool) -> void:
	if visual_root != null:
		visual_root.visible = value


func _set_spell_effect_groups(value: bool) -> void:
	for group_name: String in [
		"spell_effects",
		"persistent_spell_effects",
		"surf_spell_effects",
	]:
		if value and not is_in_group(group_name):
			add_to_group(group_name)
		elif not value and is_in_group(group_name):
			remove_from_group(group_name)


func get_debug_data() -> Dictionary:
	return {
		"surf_controller": true,
		"active": active,
		"speed": snappedf(current_speed, 0.01),
		"direction": surf_direction,
		"active_elapsed": snappedf(active_elapsed, 0.01),
		"idle_elapsed": snappedf(idle_elapsed, 0.01),
		"blocked_elapsed": snappedf(blocked_elapsed, 0.01),
		"airborne_elapsed": snappedf(airborne_elapsed, 0.01),
		"distance_travelled": snappedf(distance_travelled, 0.01),
		"activation_count": activation_count,
		"cancellation_count": cancellation_count,
		"hazard_negations": hazard_negation_count,
		"last_hazard_source": last_hazard_source,
		"last_hazard_element": last_hazard_element,
		"last_end_reason": last_end_reason,
		"actor_physics_suspended": (
			actor != null and active and not actor.is_physics_processing()
		),
		"processing": is_physics_processing(),
		"visual_meshes": 2,
		"foam_multimeshes": 1,
		"foam_segment_nodes": 0,
		"spell_effect_group": is_in_group("spell_effects"),
		"persistent_group": is_in_group("persistent_spell_effects"),
		"surface_hazard_immunity": (
			actor != null
			and bool(actor.get_meta("surf_surface_hazard_immunity", false))
		),
	}
