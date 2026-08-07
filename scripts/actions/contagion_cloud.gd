extends Node3D
class_name ContagionCloud

signal cloud_started(cast_serial: int, direction: Vector3)
signal target_entered_cloud(target: Node, cast_serial: int)
signal target_poisoned(target: Node, cast_serial: int)
signal target_exited_cloud(target: Node, cast_serial: int)
signal movement_stopped(reason: String, position: Vector3)
signal cloud_finished(reason: String, infected_target_count: int)

const PoisonGasDefinition: GasDefinition = preload(
	"res://data/gas/poison_gas.tres"
)

@export_group("Cloud Lifetime")
@export_range(0.5, 30.0, 0.1) var lifetime_seconds: float = 8.5
@export_range(0.5, 8.0, 0.05) var cloud_radius: float = 3.25
@export_range(0.1, 10.0, 0.05) var travel_speed: float = 2.35
@export_range(0.0, 8.0, 0.05) var spawn_distance: float = 3.2
@export_range(-2.0, 5.0, 0.05) var spawn_height: float = 0.9
@export var replace_existing_from_source: bool = true
@export var affects_source_actor: bool = false

@export_group("Movement Contact")
@export_range(0.1, 6.0, 0.05) var movement_collision_radius: float = 2.35
@export_range(0.0, 0.5, 0.01) var movement_contact_skin: float = 0.08
@export_range(1, 32, 1) var movement_contact_skip_limit: int = 16
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Poison Exposure")
@export_range(0.05, 1.0, 0.01) var exposure_scan_seconds: float = 0.2
@export_range(0.1, 10.0, 0.1) var poison_status_duration: float = 1.6
@export_range(0.1, 10.0, 0.1) var poison_status_strength: float = 1.0
@export_range(1, 128, 1) var maximum_contact_results: int = 64

@export_group("Gas Motion")
@export_range(0.0, 4.0, 0.05) var airflow_advection_scale: float = 0.28
@export_range(0.02, 1.0, 0.01) var airflow_sample_seconds: float = 0.12
@export_range(0.0, 20.0, 0.1) var drift_damping: float = 2.4
@export_range(0.0, 12.0, 0.1) var maximum_drift_speed: float = 5.0

@export_group("Reactions")
@export_range(0.0, 4.0, 0.1) var wind_radius_bonus: float = 0.45
@export_range(0.0, 10.0, 0.1) var wind_impulse_speed: float = 2.4
@export_range(0.5, 10.0, 0.1) var maximum_reaction_radius: float = 4.6
@export_range(0.0, 5.0, 0.1) var ignition_radius_bonus: float = 0.75
@export_range(0, 20, 1) var ignition_damage: int = 2
@export_range(0.0, 10.0, 0.1) var ignition_burn_duration: float = 1.8

@export_group("Presentation")
@export_range(8, 64, 1) var puff_instance_count: int = 26
@export_range(5.0, 60.0, 1.0) var visual_updates_per_second: float = 20.0
@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.65
@export var show_debug_messages: bool = false

var gas_id: String = "poison"
var gas_definition: GasDefinition = PoisonGasDefinition

var source_actor: Node3D
var runtime_payload: DamagePayload
var cast_serial: int = 0
var cast_direction: Vector3 = Vector3.FORWARD
var active: bool = false
var movement_active: bool = false
var remaining_lifetime: float = 0.0
var elapsed: float = 0.0
var distance_travelled: float = 0.0
var exposure_scan_remaining: float = 0.0
var airflow_sample_remaining: float = 0.0
var visual_accumulator: float = 0.0
var sampled_airflow: Vector3 = Vector3.ZERO
var drift_velocity: Vector3 = Vector3.ZERO
var last_velocity: Vector3 = Vector3.ZERO
var last_end_reason: String = "not_started"
var last_movement_stop_reason: String = "none"
var movement_contact_count: int = 0
var exposure_scan_count: int = 0
var poison_refresh_count: int = 0
var unique_infected_ids: Dictionary = {}
var infected_target_names: Array[String] = []
var inside_targets: Dictionary = {}
var collision_exclusions: Array[RID] = []
var airflow_manager: Node
var has_ignited: bool = false
var wind_reaction_count: int = 0
var ignition_count: int = 0

var exposure_shape: SphereShape3D
var exposure_query: PhysicsShapeQueryParameters3D

var core_visual: MeshInstance3D
var puff_visual: MultiMeshInstance3D
var puff_multimesh: MultiMesh
var puff_mesh: SphereMesh
var core_material: StandardMaterial3D
var puff_material: StandardMaterial3D
var puff_offsets: Array[Vector3] = []
var puff_scales: Array[Vector3] = []
var puff_phases: Array[float] = []
var random := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("contagion_cloud_effects")
	add_to_group("spell_effects")
	add_to_group("persistent_spell_effects")
	add_to_group("gas_volumes")
	add_to_group("hazard_reactive")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	random.seed = 30082026
	_build_query_resources()
	_build_visuals()
	_set_visuals_visible(false)
	set_physics_process(false)


func _exit_tree() -> void:
	inside_targets.clear()


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = (
			(new_payload as DamagePayload).duplicate(true) as DamagePayload
		)


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func belongs_to_source(candidate: Node) -> bool:
	return source_actor != null and source_actor == candidate


func execute(player: Node3D, requested_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	if replace_existing_from_source:
		_replace_existing_clouds()

	cast_direction = requested_direction
	cast_direction.y = 0.0
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = -source_actor.global_transform.basis.z
		cast_direction.y = 0.0
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = Vector3.FORWARD
	cast_direction = cast_direction.normalized()

	cast_serial = int(
		source_actor.get_meta("contagion_cloud_serial", 0)
	) + 1
	source_actor.set_meta("contagion_cloud_serial", cast_serial)
	source_actor.set_meta("contagion_cloud_last_direction", cast_direction)

	global_position = (
		source_actor.global_position
		+ cast_direction * spawn_distance
		+ Vector3.UP * spawn_height
	)
	collision_exclusions.clear()
	_collect_collision_rids(source_actor, collision_exclusions)
	remaining_lifetime = maxf(lifetime_seconds, 0.05)
	elapsed = 0.0
	distance_travelled = 0.0
	exposure_scan_remaining = 0.0
	airflow_sample_remaining = 0.0
	visual_accumulator = 0.0
	sampled_airflow = Vector3.ZERO
	drift_velocity = Vector3.ZERO
	last_velocity = cast_direction * travel_speed
	last_end_reason = "active"
	last_movement_stop_reason = "none"
	movement_contact_count = 0
	exposure_scan_count = 0
	poison_refresh_count = 0
	unique_infected_ids.clear()
	infected_target_names.clear()
	inside_targets.clear()
	has_ignited = false
	wind_reaction_count = 0
	ignition_count = 0
	active = true
	movement_active = true
	_configure_exposure_query()
	_set_visuals_visible(true)
	_update_visuals(true)
	set_physics_process(true)
	cloud_started.emit(cast_serial, cast_direction)
	if show_debug_messages:
		print(
			"CONTAGION_CLOUD started serial=",
			cast_serial,
			" speed=",
			travel_speed,
			" lifetime=",
			remaining_lifetime
		)


func _physics_process(delta: float) -> void:
	advance_cloud(delta)


func advance_cloud(delta: float) -> bool:
	if not active:
		return false
	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return true

	elapsed += step
	remaining_lifetime = maxf(remaining_lifetime - step, 0.0)
	if remaining_lifetime <= 0.0:
		finish_cloud("time_limit")
		return false

	airflow_sample_remaining -= step
	if airflow_sample_remaining <= 0.0:
		airflow_sample_remaining += maxf(airflow_sample_seconds, 0.02)
		sampled_airflow = _sample_airflow()

	if movement_active:
		var velocity: Vector3 = (
			cast_direction * travel_speed
			+ drift_velocity
			+ sampled_airflow * airflow_advection_scale
		)
		if velocity.length() > travel_speed + maximum_drift_speed:
			velocity = velocity.normalized() * (
				travel_speed + maximum_drift_speed
			)
		last_velocity = velocity
		_advance_movement(velocity, step)

	drift_velocity = drift_velocity.move_toward(
		Vector3.ZERO,
		maxf(drift_damping, 0.0) * step
	)

	exposure_scan_remaining -= step
	if exposure_scan_remaining <= 0.0:
		exposure_scan_remaining += maxf(exposure_scan_seconds, 0.05)
		_scan_and_poison_targets()

	visual_accumulator += step
	var visual_interval: float = 1.0 / maxf(
		visual_updates_per_second,
		1.0
	)
	if visual_accumulator >= visual_interval:
		visual_accumulator = fmod(visual_accumulator, visual_interval)
		_update_visuals(false)
	return true


func finish_cloud(reason: String = "complete") -> void:
	if not active:
		return
	active = false
	movement_active = false
	last_end_reason = reason
	set_physics_process(false)
	_set_visuals_visible(false)
	for target_value: Variant in inside_targets.values():
		if target_value is Node and is_instance_valid(target_value as Node):
			target_exited_cloud.emit(target_value as Node, cast_serial)
	inside_targets.clear()
	for group_name: String in [
		"spell_effects",
		"persistent_spell_effects",
		"gas_volumes",
		"hazard_reactive",
	]:
		if is_in_group(group_name):
			remove_from_group(group_name)
	cloud_finished.emit(reason, unique_infected_ids.size())
	queue_free()


func reset_target() -> void:
	finish_cloud("reset")


func is_cloud_active() -> bool:
	return active


func is_movement_active() -> bool:
	return movement_active


func _advance_movement(velocity: Vector3, delta: float) -> void:
	if velocity.length_squared() <= 0.0001:
		return
	var start_position: Vector3 = global_position
	var next_position: Vector3 = start_position + velocity * delta
	var travel_direction: Vector3 = velocity.normalized()
	var hit: Dictionary = _find_blocking_hit(
		start_position,
		next_position,
		travel_direction
	)
	if hit.is_empty():
		global_position = next_position
		distance_travelled += start_position.distance_to(global_position)
		return

	var hit_position: Vector3 = hit.get(
		"position",
		start_position
	) as Vector3
	global_position = (
		hit_position
		- travel_direction * (
			maxf(movement_collision_radius, 0.05)
			+ maxf(movement_contact_skin, 0.0)
		)
	)
	distance_travelled += start_position.distance_to(global_position)
	movement_active = false
	movement_contact_count += 1
	last_movement_stop_reason = "solid_contact"
	movement_stopped.emit(last_movement_stop_reason, global_position)
	if show_debug_messages:
		print(
			"CONTAGION_CLOUD stopped by ",
			_get_collider_name(hit),
			" and continues lingering."
		)


func _find_blocking_hit(
	start_position: Vector3,
	next_position: Vector3,
	travel_direction: Vector3
) -> Dictionary:
	var world: World3D = get_world_3d()
	if world == null:
		return {}
	var ray_start: Vector3 = (
		start_position
		+ travel_direction * maxf(movement_collision_radius, 0.05)
	)
	var ray_end: Vector3 = (
		next_position
		+ travel_direction * maxf(movement_collision_radius, 0.05)
	)
	var exclusions: Array[RID] = collision_exclusions.duplicate()
	for _attempt: int in range(maxi(movement_contact_skip_limit, 1)):
		var query := PhysicsRayQueryParameters3D.create(
			ray_start,
			ray_end,
			collision_mask
		)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = exclusions
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider_value: Variant = hit.get("collider")
		if collider_value is Node and _is_blocking_collider(
			collider_value as Node
		):
			return hit
		if collider_value is CollisionObject3D:
			var rid: RID = (collider_value as CollisionObject3D).get_rid()
			if rid.is_valid() and not exclusions.has(rid):
				exclusions.append(rid)
		ray_start = (
			hit.get("position", ray_start) as Vector3
		) + travel_direction * 0.025
		if ray_start.distance_to(ray_end) <= 0.01:
			break
	return {}


func _is_blocking_collider(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("contagion_cloud_pass_through"):
		return false
	if node.is_in_group("contagion_cloud_blocker"):
		return true
	return (
		node is StaticBody3D
		or node is AnimatableBody3D
		or node is GridMap
		or node is CSGShape3D
	)


func _scan_and_poison_targets() -> void:
	if exposure_shape == null or exposure_query == null:
		return
	var world: World3D = get_world_3d()
	if world == null:
		return
	_configure_exposure_query()
	var current_inside: Dictionary = {}
	for result: Dictionary in world.direct_space_state.intersect_shape(
		exposure_query,
		maxi(maximum_contact_results, 1)
	):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_status_target(collider_value as Node)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if current_inside.has(target_id):
			continue
		current_inside[target_id] = target
		if not inside_targets.has(target_id):
			target_entered_cloud.emit(target, cast_serial)
		_apply_poison_to_target(target)

	for previous_id_value: Variant in inside_targets.keys():
		var previous_id: int = int(previous_id_value)
		if current_inside.has(previous_id):
			continue
		var previous_value: Variant = inside_targets.get(previous_id)
		if previous_value is Node and is_instance_valid(previous_value as Node):
			target_exited_cloud.emit(previous_value as Node, cast_serial)
	inside_targets = current_inside
	exposure_scan_count += 1


func _resolve_status_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if not affects_source_actor and source_actor != null:
			if current == source_actor or source_actor.is_ancestor_of(current):
				return null
		if (
			_get_component(current, "StatusReceiver") != null
			or _get_component(current, "PayloadReceiver") != null
			or _get_component(current, "HitReceiver") != null
		):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _apply_poison_to_target(target: Node) -> void:
	var status_receiver: Node = _get_component(target, "StatusReceiver")
	var applied: bool = false
	if status_receiver != null:
		if status_receiver.has_method("sustain_status"):
			status_receiver.call(
				" sustain_status".strip_edges(),
				"poisoned",
				maxf(poison_status_duration, 0.1),
				maxf(poison_status_strength, 0.1),
				"Contagion Cloud"
			)
			applied = true
		elif status_receiver.has_method("apply_status"):
			status_receiver.call(
				"apply_status",
				"poisoned",
				maxf(poison_status_duration, 0.1),
				maxf(poison_status_strength, 0.1),
				"Contagion Cloud"
			)
			applied = true

	if not applied:
		var payload: DamagePayload = _get_payload().duplicate(true) as DamagePayload
		payload.amount = 0
		payload.stance_damage = 0
		payload.status_effect = "poisoned"
		payload.status_duration = maxf(poison_status_duration, 0.1)
		payload.status_strength = maxf(poison_status_strength, 0.1)
		payload.suppress_reactions = true
		var payload_receiver: Node = _get_component(target, "PayloadReceiver")
		if payload_receiver != null and payload_receiver.has_method("receive_payload"):
			payload_receiver.call("receive_payload", payload)
			applied = true
		else:
			var hit_receiver: Node = _get_component(target, "HitReceiver")
			if hit_receiver != null and hit_receiver.has_method("receive_payload"):
				hit_receiver.call("receive_payload", payload)
				applied = true

	if not applied:
		return
	poison_refresh_count += 1
	var target_id: int = target.get_instance_id()
	if not unique_infected_ids.has(target_id):
		unique_infected_ids[target_id] = true
		infected_target_names.append(str(target.name))
	target.set_meta("contagion_cloud_last_serial", cast_serial)
	target.set_meta(
		"contagion_cloud_last_source_id",
		source_actor.get_instance_id() if source_actor != null else 0
	)
	target.set_meta("contagion_cloud_last_tick_msec", Time.get_ticks_msec())
	target_poisoned.emit(target, cast_serial)


func sample_density(world_position: Vector3) -> float:
	if not active:
		return 0.0
	var distance: float = global_position.distance_to(world_position)
	var ratio: float = distance / maxf(cloud_radius, 0.01)
	if ratio >= 1.0:
		return 0.0
	var density: float = 1.0 - smoothstep(0.42, 1.0, ratio)
	return (
		gas_definition.clamp_density(density)
		if gas_definition != null
		else clampf(density, 0.0, 1.0)
	)


func get_total_density_mass() -> float:
	if not active:
		return 0.0
	return (
		(4.0 / 3.0)
		* PI
		* pow(maxf(cloud_radius, 0.01), 3.0)
		* 0.58
	)


func get_hazard_tags() -> Array[String]:
	return [
		"poison",
		"gas",
		"cloud",
		"contagion",
		"moving_field",
		"hazard",
	]


func get_payload() -> DamagePayload:
	return _get_payload()


func react_to_payload(
	incoming_payload: DamagePayload,
	source_position: Vector3 = Vector3.ZERO
) -> void:
	if incoming_payload == null or not active:
		return
	if (
		incoming_payload.element == "fire"
		or _payload_has_any_tag(incoming_payload, [
			"fire",
			"flame",
			"burning",
		])
	):
		_trigger_toxic_ignition()
		return
	if (
		incoming_payload.element == "air"
		or _payload_has_any_tag(incoming_payload, [
			"air",
			"wind",
			"gust",
			"force",
		])
	):
		_apply_wind_reaction(incoming_payload, source_position)


func _apply_wind_reaction(
	incoming_payload: DamagePayload,
	source_position: Vector3
) -> void:
	wind_reaction_count += 1
	cloud_radius = minf(
		cloud_radius + maxf(wind_radius_bonus, 0.0),
		maxf(maximum_reaction_radius, cloud_radius)
	)
	_configure_exposure_query()
	var direction: Vector3 = incoming_payload.knockback_direction
	if direction.length_squared() <= 0.0001:
		direction = global_position - source_position
	if direction.length_squared() <= 0.0001:
		direction = cast_direction
	if direction.length_squared() > 0.0001:
		drift_velocity += direction.normalized() * wind_impulse_speed
		if drift_velocity.length() > maximum_drift_speed:
			drift_velocity = drift_velocity.normalized() * maximum_drift_speed
	movement_active = true
	last_movement_stop_reason = "wind_restarted_motion"
	_update_visuals(true)


func _trigger_toxic_ignition() -> void:
	if has_ignited or not active:
		return
	has_ignited = true
	ignition_count += 1
	cloud_radius = minf(
		cloud_radius + maxf(ignition_radius_bonus, 0.0),
		maxf(maximum_reaction_radius + ignition_radius_bonus, cloud_radius)
	)
	_configure_exposure_query()
	_scan_and_poison_targets()
	var ignition_payload := DamagePayload.new()
	ignition_payload.amount = maxi(ignition_damage, 0)
	ignition_payload.stance_damage = maxi(ignition_damage, 0)
	ignition_payload.element = "poison"
	ignition_payload.source_name = "Toxic Ignition"
	ignition_payload.hit_type = "reaction"
	ignition_payload.status_effect = "burning"
	ignition_payload.status_duration = maxf(ignition_burn_duration, 0.1)
	ignition_payload.status_strength = 1.0
	ignition_payload.tags = [
		"poison",
		"fire",
		"gas",
		"explosion",
		"reaction",
	]
	for target_value: Variant in inside_targets.values():
		if not target_value is Node or not is_instance_valid(target_value as Node):
			continue
		_deliver_payload(target_value as Node, ignition_payload)
	movement_active = false
	remaining_lifetime = minf(remaining_lifetime, 0.55)
	_update_visuals(true)


func _deliver_payload(target: Node, payload: DamagePayload) -> void:
	var payload_receiver: Node = _get_component(target, "PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		payload_receiver.call(
			"receive_payload",
			payload.duplicate(true) as DamagePayload
		)
		return
	var hit_receiver: Node = _get_component(target, "HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		hit_receiver.call(
			"receive_payload",
			payload.duplicate(true) as DamagePayload
		)


func _sample_airflow() -> Vector3:
	if airflow_manager == null or not is_instance_valid(airflow_manager):
		airflow_manager = get_tree().get_first_node_in_group("airflow_manager")
	if airflow_manager == null or not airflow_manager.has_method(
		"sample_total_airflow"
	):
		return Vector3.ZERO
	var sampled_value: Variant = airflow_manager.call(
		"sample_total_airflow",
		global_position
	)
	return sampled_value as Vector3 if sampled_value is Vector3 else Vector3.ZERO


func _replace_existing_clouds() -> void:
	for existing: Node in get_tree().get_nodes_in_group(
		"contagion_cloud_effects"
	):
		if existing == self:
			continue
		if (
			existing.has_method("belongs_to_source")
			and bool(existing.call("belongs_to_source", source_actor))
			and existing.has_method("finish_cloud")
		):
			existing.call("finish_cloud", "replaced")


func _build_query_resources() -> void:
	exposure_shape = SphereShape3D.new()
	exposure_query = PhysicsShapeQueryParameters3D.new()
	exposure_query.shape = exposure_shape
	exposure_query.collide_with_bodies = true
	exposure_query.collide_with_areas = true


func _configure_exposure_query() -> void:
	if exposure_shape == null or exposure_query == null:
		return
	exposure_shape.radius = maxf(cloud_radius, 0.05)
	exposure_query.transform = Transform3D(Basis.IDENTITY, global_position)
	exposure_query.collision_mask = collision_mask
	exposure_query.exclude = collision_exclusions
	exposure_query.margin = 0.04


func _build_visuals() -> void:
	core_material = _make_gas_material(
		Color(0.3, 0.82, 0.12, 0.15),
		Color(0.42, 1.0, 0.08),
		0.72
	)
	puff_material = _make_gas_material(
		Color(0.42, 0.94, 0.16, 0.32),
		Color(0.5, 1.0, 0.12),
		1.15
	)
	puff_material.vertex_color_use_as_albedo = true

	core_visual = MeshInstance3D.new()
	core_visual.name = "ContagionCloudCore"
	core_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.0
	core_mesh.height = 2.0
	core_mesh.radial_segments = 16
	core_mesh.rings = 8
	core_visual.mesh = core_mesh
	core_visual.material_override = core_material
	add_child(core_visual)

	puff_mesh = SphereMesh.new()
	puff_mesh.radius = 0.5
	puff_mesh.height = 1.0
	puff_mesh.radial_segments = 8
	puff_mesh.rings = 4
	puff_multimesh = MultiMesh.new()
	puff_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	puff_multimesh.use_colors = true
	puff_multimesh.mesh = puff_mesh
	puff_multimesh.instance_count = maxi(puff_instance_count, 1)
	puff_visual = MultiMeshInstance3D.new()
	puff_visual.name = "ContagionCloudPuffs"
	puff_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff_visual.multimesh = puff_multimesh
	puff_visual.material_override = puff_material
	add_child(puff_visual)
	_generate_puff_layout()


func _make_gas_material(
	albedo: Color,
	emission_color: Color,
	emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = emission_energy
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return material


func _generate_puff_layout() -> void:
	puff_offsets.clear()
	puff_scales.clear()
	puff_phases.clear()
	var count: int = puff_multimesh.instance_count if puff_multimesh != null else 0
	for _index: int in range(count):
		var direction := Vector3(
			random.randf_range(-1.0, 1.0),
			random.randf_range(-0.8, 0.8),
			random.randf_range(-1.0, 1.0)
		)
		if direction.length_squared() <= 0.0001:
			direction = Vector3.UP
		direction = direction.normalized()
		var radial: float = pow(random.randf(), 0.48) * 0.76
		var offset: Vector3 = direction * radial
		offset.y *= 0.72
		puff_offsets.append(offset)
		var scale_value: float = random.randf_range(0.62, 1.42)
		puff_scales.append(Vector3(
			scale_value,
			scale_value * random.randf_range(0.68, 1.08),
			scale_value
		))
		puff_phases.append(random.randf_range(0.0, TAU))


func _update_visuals(force: bool) -> void:
	if not active and not force:
		return
	var life_ratio: float = clampf(
		remaining_lifetime / maxf(lifetime_seconds, 0.01),
		0.0,
		1.0
	)
	var fade_ratio: float = clampf(
		remaining_lifetime / maxf(fade_seconds, 0.01),
		0.0,
		1.0
	)
	var bloom_ratio: float = clampf(elapsed / 0.18, 0.0, 1.0)
	var alpha_ratio: float = fade_ratio * bloom_ratio
	var pulse: float = 1.0 + sin(elapsed * 2.7) * 0.035
	if core_visual != null:
		core_visual.scale = Vector3(
			cloud_radius * 0.92 * pulse,
			cloud_radius * 0.68 * (2.0 - pulse),
			cloud_radius * 0.92 * pulse
		)
		core_visual.transparency = 1.0 - clampf(alpha_ratio * 0.72, 0.0, 1.0)

	if puff_multimesh == null:
		return
	var ignited_color: Color = Color(1.0, 0.28, 0.04, 0.72)
	var poison_color: Color = Color(0.48, 1.0, 0.16, 0.34)
	for puff_index: int in range(puff_multimesh.instance_count):
		var base_offset: Vector3 = puff_offsets[puff_index]
		var phase: float = puff_phases[puff_index]
		var rotation := Basis(Vector3.UP, elapsed * 0.18 + phase * 0.04)
		var offset: Vector3 = rotation * base_offset
		offset.y += sin(elapsed * 1.8 + phase) * 0.055
		offset *= cloud_radius
		var scale_pulse: float = 1.0 + sin(elapsed * 2.2 + phase) * 0.09
		var scale_value: Vector3 = puff_scales[puff_index] * (
			cloud_radius * 0.68 * scale_pulse
		)
		puff_multimesh.set_instance_transform(
			puff_index,
			Transform3D(
				Basis.IDENTITY.scaled(scale_value),
				offset
			)
		)
		var color: Color = ignited_color if has_ignited else poison_color
		color.a *= alpha_ratio * lerpf(0.72, 1.0, life_ratio)
		puff_multimesh.set_instance_color(puff_index, color)


func _set_visuals_visible(value: bool) -> void:
	if core_visual != null:
		core_visual.visible = value
	if puff_visual != null:
		puff_visual.visible = value


func _get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 0
	fallback.stance_damage = 0
	fallback.element = "poison"
	fallback.source_name = "Contagion Cloud"
	fallback.hit_type = "moving_field"
	fallback.status_effect = "poisoned"
	fallback.status_duration = poison_status_duration
	fallback.status_strength = poison_status_strength
	fallback.tags = [
		"poison",
		"gas",
		"cloud",
		"contagion",
		"moving_field",
		"hazard",
		"status",
	]
	return fallback


func _get_component(target: Node, component_name: String) -> Node:
	if target == null:
		return null
	var direct: Node = target.get_node_or_null(component_name)
	if direct != null:
		return direct
	for child: Node in target.get_children():
		if str(child.name) == component_name:
			return child
	return null


func _payload_has_any_tag(
	incoming_payload: DamagePayload,
	tags_to_check: Array[String]
) -> bool:
	for tag: String in tags_to_check:
		if incoming_payload.tags.has(tag):
			return true
	return false


func _collect_collision_rids(
	node: Node,
	target: Array[RID]
) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _get_collider_name(hit: Dictionary) -> String:
	var collider_value: Variant = hit.get("collider")
	return str((collider_value as Node).name) if collider_value is Node else "solid contact"


func get_debug_data() -> Dictionary:
	return {
		"contagion_cloud": true,
		"active": active,
		"movement_active": movement_active,
		"cast_serial": cast_serial,
		"direction": cast_direction,
		"travel_speed": travel_speed,
		"player_outpace_margin": 5.0 - travel_speed,
		"radius": snappedf(cloud_radius, 0.01),
		"life_remaining": snappedf(remaining_lifetime, 0.01),
		"elapsed": snappedf(elapsed, 0.01),
		"distance_travelled": snappedf(distance_travelled, 0.01),
		"velocity": last_velocity,
		"airflow": sampled_airflow,
		"drift_velocity": drift_velocity,
		"movement_contacts": movement_contact_count,
		"movement_stop_reason": last_movement_stop_reason,
		"exposure_scans": exposure_scan_count,
		"targets_inside": inside_targets.size(),
		"unique_infected": unique_infected_ids.size(),
		"infected_names": infected_target_names.duplicate(),
		"poison_refreshes": poison_refresh_count,
		"gas_id": gas_id,
		"sample_density_center": sample_density(global_position),
		"gas_volume_registered": is_in_group("gas_volumes"),
		"hazard_reactive": is_in_group("hazard_reactive"),
		"wind_reactions": wind_reaction_count,
		"ignited": has_ignited,
		"ignitions": ignition_count,
		"visual_meshes": 1,
		"puff_multimeshes": 1,
		"puff_instances": (
			puff_multimesh.instance_count if puff_multimesh != null else 0
		),
		"per_puff_nodes": 0,
		"persistent": is_in_group("persistent_spell_effects"),
		"last_end_reason": last_end_reason,
	}
