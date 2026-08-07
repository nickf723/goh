extends RigidBody3D
class_name EarthBoulder

signal boulder_formed(
	cast_serial: int,
	world_position: Vector3,
	launch_speed: float
)
signal boulder_impacted(
	target: Node,
	impact_speed: float,
	impact_energy: float,
	result: Dictionary
)
signal boulder_settled(
	cast_serial: int,
	distance_travelled: float,
	active_seconds: float
)
signal boulder_dissipated(cast_serial: int, reason: String)

const BoulderVisuals = preload(
	"res://scripts/visuals/element_visuals.gd"
)

@export_group("Physical Boulder")
@export_range(0.4, 3.0, 0.05) var boulder_radius: float = 1.15
@export_range(10.0, 1000.0, 1.0) var boulder_mass_kg: float = 160.0
@export_range(0.5, 20.0, 0.1) var initial_roll_speed: float = 7.6
@export_range(0.0, 2.0, 0.05) var initial_surface_pressure: float = 0.18
@export_range(0.5, 6.0, 0.1) var spawn_forward_distance: float = 2.35
@export_range(0.0, 0.5, 0.01) var spawn_surface_clearance: float = 0.06
@export_range(0.5, 10.0, 0.1) var ground_probe_above: float = 3.2
@export_range(0.5, 20.0, 0.1) var ground_probe_below: float = 6.0
@export_flags_3d_physics var collision_query_mask: int = 1

@export_group("Motion Lifetime")
@export_range(0.01, 3.0, 0.01) var settled_linear_speed: float = 0.42
@export_range(0.01, 3.0, 0.01) var settled_surface_roll_speed: float = 0.58
@export_range(0.05, 4.0, 0.05) var settle_confirmation_seconds: float = 0.8
@export_range(0.05, 2.0, 0.05) var dissolve_seconds: float = 0.48
@export var emergency_cleanup_y: float = -180.0

@export_group("Rolling Impact")
@export_range(0.1, 20.0, 0.1) var minimum_impact_speed: float = 1.8
@export_range(0.05, 3.0, 0.05) var repeat_target_cooldown: float = 0.45
@export_range(0.1, 4.0, 0.05) var minimum_impact_multiplier: float = 0.35
@export_range(0.5, 5.0, 0.05) var maximum_impact_multiplier: float = 2.1
@export_range(0.0, 10.0, 0.1) var fallback_character_push: float = 4.8
@export_range(0.0, 5.0, 0.05) var fallback_upward_push: float = 0.35

@export_group("Presentation")
@export_range(0.01, 1.0, 0.01) var formation_seconds: float = 0.18
@export_range(0.1, 1.0, 0.01) var formation_start_scale: float = 0.68
@export_range(0.0, 10.0, 0.1) var formation_light_energy: float = 2.6
@export var show_debug_messages: bool = false

var source_actor: Node3D = null
var runtime_payload: DamagePayload = null
var cast_direction: Vector3 = Vector3.FORWARD
var surface_direction: Vector3 = Vector3.FORWARD
var launch_surface_normal: Vector3 = Vector3.UP
var cast_serial: int = 0

var active: bool = false
var dissipating: bool = false
var dissipation_reason: String = "none"
var age_seconds: float = 0.0
var settle_elapsed: float = 0.0
var dissolve_elapsed: float = 0.0
var distance_travelled: float = 0.0
var maximum_linear_speed: float = 0.0
var maximum_surface_roll_speed: float = 0.0
var last_contact_count: int = 0
var previous_position: Vector3 = Vector3.ZERO
var impact_count: int = 0
var impacted_target_ids: Dictionary = {}
var target_last_impact_times: Dictionary = {}
var visual_instances: Array[GeometryInstance3D] = []
var visual_initial_scale: Vector3 = Vector3.ONE

@onready var visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D
@onready var collision_shape: CollisionShape3D = get_node_or_null(
	"CollisionShape3D"
) as CollisionShape3D
@onready var launch_light: OmniLight3D = get_node_or_null(
	"FormationLight"
) as OmniLight3D


func _ready() -> void:
	add_to_group("earth_boulder_effects")
	add_to_group("spell_effects")
	add_to_group("persistent_spell_effects")
	add_to_group("spell_projectiles")
	add_to_group("earth_spell_objects")
	add_to_group("mechanism_weights")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	mass = maxf(boulder_mass_kg, 0.1)
	set_meta("mechanism_mass_kg", mass)
	set_meta("spell_object_kind", "rolling_boulder")
	_sync_collision_radius()
	_collect_visual_instances(visual_root)
	if visual_root != null:
		visual_initial_scale = visual_root.scale
		visual_root.scale = visual_initial_scale * formation_start_scale
	if launch_light != null:
		launch_light.light_energy = 0.0
	var body_callback: Callable = Callable(self, "_on_body_entered")
	if not body_entered.is_connected(body_callback):
		body_entered.connect(body_callback)
	set_process(false)
	set_physics_process(true)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	last_contact_count = state.get_contact_count()


func _physics_process(delta: float) -> void:
	if not active or dissipating:
		return

	var safe_delta: float = maxf(delta, 0.0)
	age_seconds += safe_delta
	distance_travelled += previous_position.distance_to(global_position)
	previous_position = global_position

	var linear_speed: float = linear_velocity.length()
	var surface_roll_speed: float = angular_velocity.length() * boulder_radius
	maximum_linear_speed = maxf(maximum_linear_speed, linear_speed)
	maximum_surface_roll_speed = maxf(
		maximum_surface_roll_speed,
		surface_roll_speed
	)
	_update_formation_presentation()

	if global_position.y <= emergency_cleanup_y:
		begin_dissolve("out_of_bounds")
		return

	var is_still_moving: bool = (
		linear_speed > settled_linear_speed
		or surface_roll_speed > settled_surface_roll_speed
	)
	var has_support: bool = sleeping or last_contact_count > 0
	if is_still_moving or not has_support:
		settle_elapsed = 0.0
	else:
		settle_elapsed += safe_delta

	if settle_elapsed >= settle_confirmation_seconds:
		begin_dissolve("settled")


func _process(delta: float) -> void:
	if not dissipating:
		return
	var safe_duration: float = maxf(dissolve_seconds, 0.01)
	dissolve_elapsed = minf(dissolve_elapsed + maxf(delta, 0.0), safe_duration)
	var ratio: float = clampf(dissolve_elapsed / safe_duration, 0.0, 1.0)
	if visual_root != null:
		visual_root.scale = visual_initial_scale * lerpf(1.0, 0.08, ratio)
	for visual: GeometryInstance3D in visual_instances:
		if visual != null and is_instance_valid(visual):
			visual.transparency = ratio
	if launch_light != null:
		launch_light.light_energy = lerpf(
			formation_light_energy * 0.32,
			0.0,
			ratio
		)
	if ratio >= 1.0:
		boulder_dissipated.emit(cast_serial, dissipation_reason)
		queue_free()


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
	if player != null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	cast_direction = requested_direction
	cast_direction.y = 0.0
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = -source_actor.global_transform.basis.z
		cast_direction.y = 0.0
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = Vector3.FORWARD
	cast_direction = cast_direction.normalized()

	cast_serial = int(source_actor.get_meta("boulder_cast_serial", 0)) + 1
	source_actor.set_meta("boulder_cast_serial", cast_serial)
	name = "EarthBoulder_" + str(cast_serial)
	set_meta("boulder_cast_serial", cast_serial)
	set_meta("boulder_source_id", source_actor.get_instance_id())

	if source_actor is PhysicsBody3D:
		add_collision_exception_with(source_actor as PhysicsBody3D)

	var spawn_data: Dictionary = _resolve_spawn_data()
	launch_surface_normal = spawn_data.get("normal", Vector3.UP) as Vector3
	global_position = spawn_data.get(
		"position",
		source_actor.global_position
	) as Vector3
	surface_direction = cast_direction.slide(launch_surface_normal)
	if surface_direction.length_squared() <= 0.0001:
		surface_direction = cast_direction
	surface_direction = surface_direction.normalized()

	var roll_axis: Vector3 = surface_direction.cross(launch_surface_normal)
	if roll_axis.length_squared() <= 0.0001:
		roll_axis = surface_direction.cross(Vector3.UP)
	if roll_axis.length_squared() <= 0.0001:
		roll_axis = Vector3.RIGHT
	roll_axis = roll_axis.normalized()

	rotation = Vector3(
		float((cast_serial * 31) % 360),
		float((cast_serial * 67) % 360),
		float((cast_serial * 103) % 360)
	) * (PI / 180.0)
	linear_velocity = (
		surface_direction * initial_roll_speed
		- launch_surface_normal * initial_surface_pressure
	)
	angular_velocity = roll_axis * (
		initial_roll_speed / maxf(boulder_radius, 0.05)
	)
	sleeping = false
	active = true
	dissipating = false
	dissipation_reason = "none"
	age_seconds = 0.0
	settle_elapsed = 0.0
	dissolve_elapsed = 0.0
	distance_travelled = 0.0
	maximum_linear_speed = linear_velocity.length()
	maximum_surface_roll_speed = angular_velocity.length() * boulder_radius
	last_contact_count = 0
	previous_position = global_position
	impact_count = 0
	impacted_target_ids.clear()
	target_last_impact_times.clear()
	if visual_root != null:
		visual_root.scale = visual_initial_scale * formation_start_scale
	for visual: GeometryInstance3D in visual_instances:
		if visual != null and is_instance_valid(visual):
			visual.transparency = 0.0
	if launch_light != null:
		launch_light.light_energy = formation_light_energy
	set_process(false)
	set_physics_process(true)
	source_actor.set_meta("boulder_last_spawn_position", global_position)
	boulder_formed.emit(cast_serial, global_position, initial_roll_speed)

	if show_debug_messages:
		print(
			"BOULDER formed serial=",
			cast_serial,
			" mass=",
			mass,
			" kg velocity=",
			linear_velocity
		)


func receive_external_impulse(
	direction: Vector3,
	strength: float,
	upward_strength: float = 0.0,
	_source_name: String = "External Force"
) -> void:
	if dissipating:
		return
	var safe_direction: Vector3 = direction
	if safe_direction.length_squared() <= 0.0001:
		safe_direction = Vector3.FORWARD
	safe_direction = safe_direction.normalized()
	apply_central_impulse(
		safe_direction * maxf(strength, 0.0)
		+ Vector3.UP * maxf(upward_strength, 0.0)
	)
	sleeping = false
	settle_elapsed = 0.0


func begin_dissolve(reason: String = "settled", immediate: bool = false) -> void:
	if dissipating:
		return
	active = false
	dissipating = true
	dissipation_reason = reason
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	if reason == "settled":
		boulder_settled.emit(
			cast_serial,
			distance_travelled,
			age_seconds
		)
	if immediate:
		boulder_dissipated.emit(cast_serial, dissipation_reason)
		queue_free()
		return
	set_process(true)


func force_dissipate(reason: String = "forced_cleanup") -> void:
	begin_dissolve(reason)


func reset_target() -> void:
	begin_dissolve("trial_reset", true)


func get_effective_mass() -> float:
	return mass


func get_mechanism_mass_kg() -> float:
	return mass


func _resolve_spawn_data() -> Dictionary:
	var fallback_position: Vector3 = (
		source_actor.global_position
		+ cast_direction * spawn_forward_distance
		+ Vector3.UP * (boulder_radius + 0.2)
	)
	var world: World3D = get_world_3d()
	if world == null:
		return {
			"position": fallback_position,
			"normal": Vector3.UP,
			"grounded": false,
		}

	var desired_horizontal: Vector3 = (
		source_actor.global_position
		+ cast_direction * spawn_forward_distance
	)
	var query := PhysicsRayQueryParameters3D.create(
		desired_horizontal + Vector3.UP * ground_probe_above,
		desired_horizontal + Vector3.DOWN * ground_probe_below
	)
	query.collision_mask = collision_query_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if source_actor is CollisionObject3D:
		query.exclude = [(source_actor as CollisionObject3D).get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {
			"position": fallback_position,
			"normal": Vector3.UP,
			"grounded": false,
		}
	var hit_position: Vector3 = hit.get(
		"position",
		desired_horizontal
	) as Vector3
	var hit_normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
	if hit_normal.length_squared() <= 0.0001:
		hit_normal = Vector3.UP
	hit_normal = hit_normal.normalized()
	return {
		"position": hit_position + hit_normal * (
			boulder_radius + spawn_surface_clearance
		),
		"normal": hit_normal,
		"grounded": true,
	}


func _on_body_entered(body: Node) -> void:
	if not active or dissipating or body == null:
		return
	if source_actor != null and (
		body == source_actor or source_actor.is_ancestor_of(body)
	):
		return
	var target: Node = _resolve_effect_target(body)
	if target == null:
		return

	var impact_speed: float = _get_relative_impact_speed(body)
	if impact_speed < minimum_impact_speed:
		return
	var target_id: int = target.get_instance_id()
	var previous_time: float = float(
		target_last_impact_times.get(target_id, -1000.0)
	)
	if age_seconds - previous_time < repeat_target_cooldown:
		return
	target_last_impact_times[target_id] = age_seconds
	impacted_target_ids[target_id] = true

	var impact_payload: DamagePayload = _make_impact_payload(impact_speed)
	var result: Dictionary = _deliver_payload(target, impact_payload)
	_apply_fallback_character_force(target, impact_payload)
	var impact_energy: float = 0.5 * mass * impact_speed * impact_speed
	impact_count += 1
	target.set_meta("boulder_last_cast_serial", cast_serial)
	target.set_meta("boulder_last_impact_speed", impact_speed)
	target.set_meta("boulder_last_impact_energy", impact_energy)
	target.set_meta("boulder_last_impact_count", impact_count)
	set_meta("boulder_last_target", str(target.name))
	set_meta("boulder_last_impact_speed", impact_speed)

	var impact_position: Vector3 = _get_target_position(target)
	BoulderVisuals.spawn_impact(
		get_tree(),
		impact_position,
		"earth",
		clampf(0.55 + impact_speed * 0.045, 0.6, 1.2)
	)
	boulder_impacted.emit(target, impact_speed, impact_energy, result)

	if show_debug_messages:
		print(
			"BOULDER impact target=",
			target.name,
			" speed=",
			snappedf(impact_speed, 0.01),
			" energy=",
			snappedf(impact_energy, 1.0)
		)


func _resolve_effect_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if source_actor != null and (
			current == source_actor
			or source_actor.is_ancestor_of(current)
		):
			return null
		if current is StaticBody3D or current is AnimatableBody3D:
			return null
		if (
			current is CharacterBody3D
			or current is RigidBody3D
			or current.get_node_or_null("PayloadReceiver") != null
			or current.get_node_or_null("HitReceiver") != null
			or current.get_node_or_null("ForceReceiver") != null
			or current.has_method("receive_damage_payload")
			or current.has_method("receive_magic_hit")
		):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _get_relative_impact_speed(body: Node) -> float:
	var other_velocity: Vector3 = Vector3.ZERO
	if body is RigidBody3D:
		other_velocity = (body as RigidBody3D).linear_velocity
	elif body is CharacterBody3D:
		other_velocity = (body as CharacterBody3D).velocity
	return (linear_velocity - other_velocity).length()


func _make_impact_payload(impact_speed: float) -> DamagePayload:
	var source_payload: DamagePayload = _get_payload()
	var duplicate_value: Resource = source_payload.duplicate(true)
	var payload: DamagePayload = (
		duplicate_value as DamagePayload
		if duplicate_value is DamagePayload
		else source_payload
	)
	var multiplier: float = clampf(
		impact_speed / maxf(initial_roll_speed, 0.1),
		minimum_impact_multiplier,
		maximum_impact_multiplier
	)
	if payload.amount > 0:
		payload.amount = maxi(1, roundi(float(payload.amount) * multiplier))
	if payload.stance_damage > 0:
		payload.stance_damage = maxi(
			1,
			roundi(float(payload.stance_damage) * multiplier)
		)
	payload.source_name = "Rolling Boulder"
	payload.hit_type = "rolling_boulder"
	payload.knockback_strength *= multiplier
	payload.knockback_up_strength *= clampf(multiplier, 0.5, 1.5)
	var direction: Vector3 = linear_velocity
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = surface_direction
	payload.knockback_direction = direction.normalized()
	for tag: String in [
		"earth",
		"stone",
		"boulder",
		"rolling",
		"crush",
		"physical",
		"projectile",
		"force",
		"heavy_impact",
	]:
		if not payload.tags.has(tag):
			payload.tags.append(tag)
	return payload


func _get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 5
	fallback.stance_damage = 11
	fallback.element = "earth"
	fallback.source_name = "Rolling Boulder"
	fallback.hit_type = "rolling_boulder"
	fallback.knockback_strength = 6.2
	fallback.knockback_up_strength = 0.35
	fallback.tags = [
		"earth",
		"stone",
		"boulder",
		"rolling",
		"crush",
		"physical",
		"projectile",
		"force",
		"heavy_impact",
	]
	return fallback


func _deliver_payload(target: Node, payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		var received: Variant = payload_receiver.call("receive_payload", payload)
		return (
			(received as Dictionary).duplicate(true)
			if received is Dictionary
			else {}
		)
	if target.has_method("receive_damage_payload"):
		var direct: Variant = target.call("receive_damage_payload", payload)
		return (
			(direct as Dictionary).duplicate(true)
			if direct is Dictionary
			else {}
		)
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		var hit_result: Variant = hit_receiver.call("receive_payload", payload)
		return (
			(hit_result as Dictionary).duplicate(true)
			if hit_result is Dictionary
			else {}
		)
	if target.has_method("receive_magic_hit"):
		target.call("receive_magic_hit", payload.amount)
	return {}


func _apply_fallback_character_force(
	target: Node,
	payload: DamagePayload
) -> void:
	if target is RigidBody3D:
		return
	if target.get_node_or_null("PayloadReceiver") != null:
		return
	var force_receiver: Node = target.get_node_or_null("ForceReceiver")
	if force_receiver != null and force_receiver.has_method("apply_impulse"):
		force_receiver.call(
			"apply_impulse",
			payload.knockback_direction,
			maxf(payload.knockback_strength, fallback_character_push),
			maxf(payload.knockback_up_strength, fallback_upward_push),
			payload.source_name
		)
		return
	if target is CharacterBody3D:
		var character := target as CharacterBody3D
		character.velocity += (
			payload.knockback_direction * fallback_character_push
			+ Vector3.UP * fallback_upward_push
		)


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	return (
		(parent as Node3D).global_position
		if parent is Node3D
		else global_position
	)


func _update_formation_presentation() -> void:
	var ratio: float = clampf(
		age_seconds / maxf(formation_seconds, 0.01),
		0.0,
		1.0
	)
	if visual_root != null:
		visual_root.scale = visual_initial_scale * lerpf(
			formation_start_scale,
			1.0,
			ratio
		)
	if launch_light != null:
		launch_light.light_energy = lerpf(
			formation_light_energy,
			0.0,
			ratio
		)


func _sync_collision_radius() -> void:
	if collision_shape == null:
		return
	if collision_shape.shape is SphereShape3D:
		(collision_shape.shape as SphereShape3D).radius = boulder_radius


func _collect_visual_instances(root: Node) -> void:
	if root == null:
		return
	if root is GeometryInstance3D:
		visual_instances.append(root as GeometryInstance3D)
	for child: Node in root.get_children():
		_collect_visual_instances(child)


func get_debug_data() -> Dictionary:
	return {
		"earth_boulder": true,
		"active": active,
		"dissipating": dissipating,
		"dissipation_reason": dissipation_reason,
		"cast_serial": cast_serial,
		"mass_kg": mass,
		"radius": boulder_radius,
		"age_seconds": age_seconds,
		"distance_travelled": distance_travelled,
		"linear_speed": linear_velocity.length(),
		"surface_roll_speed": angular_velocity.length() * boulder_radius,
		"maximum_linear_speed": maximum_linear_speed,
		"maximum_surface_roll_speed": maximum_surface_roll_speed,
		"settle_elapsed": settle_elapsed,
		"settle_confirmation_seconds": settle_confirmation_seconds,
		"contact_count": last_contact_count,
		"sleeping": sleeping,
		"impact_count": impact_count,
		"unique_impact_targets": impacted_target_ids.size(),
		"lifetime_mode": "motion_settle",
		"has_fixed_lifetime": false,
		"persistent": is_in_group("persistent_spell_effects"),
	}
