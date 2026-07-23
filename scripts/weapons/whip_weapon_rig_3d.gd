extends Node3D
class_name WhipWeaponRig3D

const LeatherWhip: FlexibleMaterialProfile = preload("res://data/flexible_materials/leather_whip.tres")

@export_range(2.5, 7.0, 0.05) var whip_length: float = 4.65
@export_range(0.01, 0.5, 0.01) var tip_mass: float = 0.11
@export_range(0.1, 0.8, 0.01) var contact_radius: float = 0.34
@export_range(8.0, 50.0, 0.5) var crack_speed_threshold: float = 21.0
@export_range(0.0, 0.2, 0.005) var airflow_influence: float = 0.045
@export_range(1.0, 12.0, 0.25) var pull_strength: float = 5.5
@export_range(8, 40, 1) var maximum_sweep_samples: int = 26

var weapon: WeaponDefinition
var controller: WeaponController
var handle_anchor: Node3D
var tip_endpoint: Node3D
var tether: FlexibleTether3D
var wave_marker: MeshInstance3D

var current_tip_speed: float = 0.0
var peak_tip_speed: float = 0.0
var wave_progress: float = 0.0
var wave_speed: float = 0.0
var current_airflow: Vector3 = Vector3.ZERO
var is_attacking: bool = false
var is_cracking: bool = false
var active_attack_id: String = ""
var wrapped_target_name: String = "none"

var _previous_tip_position: Vector3
var _last_attack_elapsed: float = 0.0
var _sweep_points: Array[Vector3] = []
var _tip_material: StandardMaterial3D
var _wave_material: StandardMaterial3D
var _latched_target: Node3D
var _wrap_latch_timer: float = 0.0


func _ready() -> void:
	add_to_group("weapon_runtime_rigs")
	add_to_group("whip_weapon_rigs")
	_build_rig()
	set_process(true)


func configure_weapon(new_weapon: WeaponDefinition, new_controller: WeaponController) -> void:
	weapon = new_weapon
	controller = new_controller
	if not is_node_ready():
		call_deferred("configure_weapon", new_weapon, new_controller)
		return
	_apply_weapon_identity()
	_snap_to_idle()


func _process(delta: float) -> void:
	if controller == null or tip_endpoint == null:
		return

	if _wrap_latch_timer > 0.0:
		_wrap_latch_timer = maxf(_wrap_latch_timer - delta, 0.0)
		if is_instance_valid(_latched_target):
			tip_endpoint.global_position = _get_target_position(_latched_target)
			_update_tip_kinematics(maxf(delta, 0.001))
		else:
			_clear_latch()
	elif _latched_target != null:
		_clear_latch()

	if not is_attacking:
		var idle_target: Vector3 = _get_handle_position() + _get_forward() * 0.38 + Vector3.DOWN * 0.72
		tip_endpoint.global_position = tip_endpoint.global_position.lerp(
			idle_target,
			clampf(delta * 11.0, 0.0, 1.0)
		)
		_update_handle()
		_update_tip_kinematics(maxf(delta, 0.001))
		_update_wave_marker()


func begin_attack(attack: WeaponAttackDefinition, attack_speed: float) -> void:
	if attack == null:
		return
	is_attacking = true
	is_cracking = false
	active_attack_id = attack.attack_id
	wave_progress = 0.0
	wave_speed = whip_length / maxf(attack.get_startup_duration(attack_speed), 0.01)
	peak_tip_speed = 0.0
	_last_attack_elapsed = 0.0
	_sweep_points.clear()
	_clear_latch()
	_update_handle()
	_previous_tip_position = tip_endpoint.global_position
	_sweep_points.append(_previous_tip_position)
	if wave_marker != null:
		wave_marker.visible = true
	_update_materials()


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
	if attack == null or tip_endpoint == null:
		return

	_update_handle()
	var startup: float = attack.get_startup_duration(attack_speed)
	var active_end: float = startup + attack.get_active_duration(attack_speed)
	var total: float = attack.get_total_duration(attack_speed)
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _get_forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var target: Vector3 = tip_endpoint.global_position

	if _wrap_latch_timer > 0.0 and is_instance_valid(_latched_target):
		target = _get_target_position(_latched_target)
	elif elapsed <= startup:
		var normalized_time: float = clampf(elapsed / maxf(startup, 0.01), 0.0, 1.0)
		wave_progress = smoothstep(0.0, 1.0, normalized_time)
		target = _sample_attack_tip(attack, handle, forward, right, wave_progress)
		target += _sample_airflow_offset(target, wave_progress)
		_append_sweep_point(target)
	elif elapsed <= active_end:
		wave_progress = 1.0
	else:
		var recovery_weight: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0)
		)
		var idle_target: Vector3 = handle + forward * 0.38 + Vector3.DOWN * 0.72
		target = tip_endpoint.global_position.lerp(idle_target, recovery_weight)
		wave_progress = 1.0 - recovery_weight

	tip_endpoint.global_position = target
	_update_tip_kinematics(maxf(elapsed - _last_attack_elapsed, 0.001))
	_last_attack_elapsed = elapsed
	is_cracking = is_cracking or (
		current_tip_speed >= crack_speed_threshold
		and (attack.extra_tags.has("crack") or attack.extra_tags.has("snap"))
	)
	_update_wave_marker()
	_update_materials()


func end_attack() -> void:
	is_attacking = false
	is_cracking = false
	active_attack_id = ""
	wave_progress = 0.0
	wave_speed = 0.0
	_sweep_points.clear()
	_clear_latch()
	if wave_marker != null:
		wave_marker.visible = false
	_update_materials()


func find_weapon_targets(
	weapon_controller: WeaponController,
	attack: WeaponAttackDefinition,
	collision_mask: int
) -> Array[Node]:
	var targets: Array[Node] = []
	if weapon_controller == null or attack == null:
		return targets

	var actor: Node3D = weapon_controller.get_actor()
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = contact_radius
	var seen: Dictionary = {}

	for sample_position: Vector3 in _get_contact_samples():
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), sample_position)
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = true
		if actor is CollisionObject3D:
			query.exclude = [actor.get_rid()]

		for result: Dictionary in space_state.intersect_shape(query, 20):
			var collider: Node = result.get("collider") as Node
			if collider == null:
				continue
			var target: Node = weapon_controller.find_payload_target(collider)
			if target == null or target == actor:
				continue
			var target_id: int = target.get_instance_id()
			if seen.has(target_id):
				continue
			seen[target_id] = true
			targets.append(target)
			if targets.size() >= maxi(attack.max_targets, 1):
				return targets

	return targets


func modify_attack_payload(payload: DamagePayload, attack: WeaponAttackDefinition) -> void:
	if payload == null or attack == null:
		return

	var impact_tip_speed: float = maxf(current_tip_speed, peak_tip_speed)
	var speed_ratio: float = clampf(impact_tip_speed / maxf(crack_speed_threshold, 1.0), 0.35, 1.7)
	var damage_scale: float = lerpf(0.62, 1.52, speed_ratio / 1.7)
	if attack.extra_tags.has("wrap"):
		damage_scale = minf(damage_scale, 0.78)
	payload.amount = maxi(1, roundi(float(payload.amount) * damage_scale))
	payload.stance_damage = maxi(0, roundi(float(payload.stance_damage) * lerpf(0.65, 1.0, speed_ratio / 1.7)))
	payload.knockback_strength *= lerpf(0.55, 0.95, speed_ratio / 1.7)
	_append_payload_tag(payload, "flexible_weapon")
	_append_payload_tag(payload, "whip")
	_append_payload_tag(payload, "tip_focused")
	if is_cracking:
		_append_payload_tag(payload, "whip_crack")
		_append_payload_tag(payload, "sonic")


func on_weapon_targets_hit(targets: Array[Node], attack: WeaponAttackDefinition) -> void:
	if attack == null or not attack.extra_tags.has("wrap") or targets.is_empty():
		return

	var target: Node = targets[0]
	if target is Node3D:
		_latched_target = target as Node3D
		_wrap_latch_timer = 0.38
		wrapped_target_name = target.name

	if target.has_method("receive_whip_pull"):
		target.call("receive_whip_pull", pull_strength, controller.get_actor())
		return

	var force_receiver: Node = target.get_node_or_null("ForceReceiver")
	var actor: Node3D = controller.get_actor() if controller != null else null
	if force_receiver == null or actor == null or not force_receiver.has_method("apply_impulse"):
		return
	var pull_direction: Vector3 = actor.global_position - _get_target_position(target as Node3D)
	force_receiver.call(
		"apply_impulse",
		pull_direction,
		pull_strength,
		0.35,
		(
			weapon.display_name + " • " + attack.display_name
			if weapon != null
			else attack.display_name
		)
	)


func get_debug_data() -> Dictionary:
	return {
		"type": "wave_whip",
		"attack": active_attack_id if active_attack_id != "" else "idle",
		"tip_speed": snapped(current_tip_speed, 0.1),
		"peak_tip_speed": snapped(peak_tip_speed, 0.1),
		"crack_threshold": snapped(crack_speed_threshold, 0.1),
		"cracking": is_cracking,
		"wave_progress": snapped(wave_progress, 0.01),
		"wave_front_meters": snapped(wave_progress * whip_length, 0.1),
		"wave_speed": snapped(wave_speed, 0.1),
		"tension": snapped(tether.current_tension, 0.1) if tether != null else 0.0,
		"airflow": current_airflow,
		"wrapped_target": wrapped_target_name,
		"sweep_samples": _sweep_points.size(),
	}


func _sample_attack_tip(
	attack: WeaponAttackDefinition,
	handle: Vector3,
	forward: Vector3,
	right: Vector3,
	weight: float
) -> Vector3:
	var reverse: bool = attack.extra_tags.has("reverse")
	var snap_weight: float = pow(weight, 2.45)

	if attack.extra_tags.has("precision"):
		var precision_distance: float = lerpf(0.75, minf(attack.attack_range, whip_length * 1.04), snap_weight)
		return (
			handle
			+ forward * precision_distance
			+ right * sin(weight * PI * 2.0) * (0.18 if not reverse else -0.18)
			+ Vector3.UP * sin(weight * PI) * 0.18
		)

	if attack.extra_tags.has("overhead"):
		var overhead_distance: float = lerpf(0.7, minf(attack.attack_range, whip_length), snap_weight)
		return (
			handle
			+ forward * overhead_distance
			+ Vector3.UP * lerpf(1.65, -0.38, snap_weight)
			+ right * sin(weight * PI) * 0.12
		)

	var start_angle: float = deg_to_rad(74.0 if reverse else -74.0)
	var end_angle: float = deg_to_rad(-74.0 if reverse else 74.0)
	if attack.extra_tags.has("wrap"):
		start_angle *= 0.82
		end_angle *= 0.46
	var angle: float = lerpf(start_angle, end_angle, smoothstep(0.0, 1.0, weight))
	var radius: float = lerpf(0.82, minf(attack.attack_range, whip_length), snap_weight)
	var wave_lift: float = sin(weight * PI) * 0.28
	return (
		handle
		+ forward * (cos(angle) * radius)
		+ right * (sin(angle) * radius)
		+ Vector3.UP * wave_lift
	)


func _build_rig() -> void:
	handle_anchor = Node3D.new()
	handle_anchor.name = "HandleAnchor"
	add_child(handle_anchor)

	var grip: MeshInstance3D = MeshInstance3D.new()
	grip.name = "WhipGrip"
	var grip_mesh: CylinderMesh = CylinderMesh.new()
	grip_mesh.top_radius = 0.055
	grip_mesh.bottom_radius = 0.072
	grip_mesh.height = 0.5
	grip_mesh.radial_segments = 10
	grip.mesh = grip_mesh
	grip.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	handle_anchor.add_child(grip)

	tip_endpoint = Node3D.new()
	tip_endpoint.name = "WhipTip"
	add_child(tip_endpoint)

	var tip_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	tip_mesh_instance.name = "Cracker"
	var tip_mesh: SphereMesh = SphereMesh.new()
	tip_mesh.radius = 0.085
	tip_mesh.height = 0.17
	tip_mesh.radial_segments = 10
	tip_mesh.rings = 6
	tip_mesh_instance.mesh = tip_mesh
	_tip_material = StandardMaterial3D.new()
	tip_mesh_instance.material_override = _tip_material
	tip_endpoint.add_child(tip_mesh_instance)

	tether = FlexibleTether3D.new()
	tether.name = "FlexibleWhip"
	tether.endpoint_a_path = NodePath("../HandleAnchor")
	tether.endpoint_b_path = NodePath("../WhipTip")
	tether.material_profile = LeatherWhip
	tether.rest_length = whip_length
	tether.segment_count = 20
	tether.constraint_iterations = 9
	tether.verlet_damping = 0.976
	tether.gravity_scale = 0.22
	tether.apply_endpoint_forces = false
	tether.debug_tension_color = false
	add_child(tether)

	wave_marker = MeshInstance3D.new()
	wave_marker.name = "WaveFront"
	var marker_mesh: TorusMesh = TorusMesh.new()
	marker_mesh.inner_radius = 0.09
	marker_mesh.outer_radius = 0.14
	marker_mesh.rings = 14
	marker_mesh.ring_segments = 6
	wave_marker.mesh = marker_mesh
	wave_marker.visible = false
	_wave_material = StandardMaterial3D.new()
	_wave_material.emission_enabled = true
	_wave_material.emission_energy_multiplier = 2.4
	wave_marker.material_override = _wave_material
	add_child(wave_marker)


func _apply_weapon_identity() -> void:
	if weapon == null:
		return
	for child: Node in handle_anchor.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = _make_material(weapon.visual_secondary_color)
	_update_materials()


func _update_materials() -> void:
	var base_color: Color = weapon.visual_primary_color if weapon != null else Color(0.34, 0.07, 0.03, 1.0)
	var accent: Color = weapon.visual_accent_color if weapon != null else Color(0.78, 0.22, 1.0, 1.0)
	if _tip_material != null:
		_tip_material.albedo_color = base_color.lerp(accent, 0.85 if is_cracking else 0.25)
		_tip_material.roughness = 0.44
		_tip_material.emission_enabled = is_attacking
		_tip_material.emission = accent
		_tip_material.emission_energy_multiplier = 2.2 if is_cracking else 0.55
	if _wave_material != null:
		_wave_material.albedo_color = accent
		_wave_material.emission = accent


func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	return material


func _sample_airflow_offset(world_position: Vector3, weight: float) -> Vector3:
	current_airflow = Vector3.ZERO
	var manager: Node = get_tree().get_first_node_in_group("airflow_manager")
	if manager == null or not manager.has_method("sample_total_airflow_fast"):
		return Vector3.ZERO
	var sample: Variant = manager.call("sample_total_airflow_fast", world_position)
	if sample is Vector3:
		current_airflow = sample as Vector3
	return current_airflow * airflow_influence * weight


func _update_handle() -> void:
	if handle_anchor != null:
		handle_anchor.global_position = _get_handle_position()


func _get_handle_position() -> Vector3:
	if controller == null:
		return global_position
	return controller.get_attack_origin() + Vector3.DOWN * 0.18


func _get_forward() -> Vector3:
	if controller == null:
		return Vector3.FORWARD
	return controller.get_attack_forward()


func _snap_to_idle() -> void:
	if tip_endpoint == null:
		return
	_update_handle()
	tip_endpoint.global_position = _get_handle_position() + _get_forward() * 0.38 + Vector3.DOWN * 0.72
	_previous_tip_position = tip_endpoint.global_position
	if tether != null:
		tether.reset_tether()


func _update_tip_kinematics(delta: float) -> void:
	if tip_endpoint == null or delta <= 0.0:
		return
	current_tip_speed = tip_endpoint.global_position.distance_to(_previous_tip_position) / delta
	peak_tip_speed = maxf(peak_tip_speed, current_tip_speed)
	_previous_tip_position = tip_endpoint.global_position


func _append_sweep_point(point: Vector3) -> void:
	if _sweep_points.is_empty() or _sweep_points[-1].distance_to(point) >= contact_radius * 0.42:
		_sweep_points.append(point)
	while _sweep_points.size() > maximum_sweep_samples:
		_sweep_points.remove_at(1)


func _get_contact_samples() -> Array[Vector3]:
	var samples: Array[Vector3] = []
	samples.assign(_sweep_points)
	if tip_endpoint != null and (samples.is_empty() or samples[-1].distance_to(tip_endpoint.global_position) > 0.02):
		samples.append(tip_endpoint.global_position)
	return samples


func _update_wave_marker() -> void:
	if wave_marker == null or handle_anchor == null or tip_endpoint == null:
		return
	wave_marker.global_position = handle_anchor.global_position.lerp(tip_endpoint.global_position, wave_progress)
	var direction: Vector3 = tip_endpoint.global_position - handle_anchor.global_position
	if direction.length_squared() > 0.001:
		wave_marker.quaternion = Quaternion(Vector3.UP, direction.normalized())
	wave_marker.scale = Vector3.ONE * (1.35 if is_cracking else 1.0)


func _get_target_position(target: Node3D) -> Vector3:
	if target == null:
		return tip_endpoint.global_position if tip_endpoint != null else global_position
	return target.global_position + Vector3.UP * 0.95


func _clear_latch() -> void:
	_latched_target = null
	_wrap_latch_timer = 0.0
	wrapped_target_name = "none"


func _append_payload_tag(payload: DamagePayload, tag: String) -> void:
	if payload != null and tag != "" and not payload.tags.has(tag):
		payload.tags.append(tag)
