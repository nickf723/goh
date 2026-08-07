extends "res://scripts/actions/water_jet_cast.gd"
class_name WaterJetCastReady

const GameplayEffectAccessScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)

# The production authority primes the stream transform immediately, routes
# sustained Mana through gameplay effects, preserves the complete three-
# dimensional pressure direction, and reuses its bounded contact-query resources.

var cached_stream_shape: CylinderShape3D
var cached_stream_query: PhysicsShapeQueryParameters3D


func _ready() -> void:
	super._ready()
	cached_stream_shape = CylinderShape3D.new()
	cached_stream_query = PhysicsShapeQueryParameters3D.new()
	cached_stream_query.shape = cached_stream_shape
	cached_stream_query.collide_with_bodies = true
	cached_stream_query.collide_with_areas = true


func execute(player: Node3D, requested_direction: Vector3) -> void:
	super.execute(player, requested_direction)
	if not active or source_actor == null or not is_instance_valid(source_actor):
		return
	current_origin = _get_cast_origin()
	current_direction = _get_cast_direction(current_origin)
	current_hit = _resolve_stream_hit(current_origin, current_direction)
	current_stream_length = _get_stream_length(current_origin, current_hit)
	last_hit_name = _get_hit_name(current_hit)
	_update_visuals()


func get_effective_mana_rate() -> float:
	return maxf(
		GameplayEffectAccessScript.modify_float(
			"mana_cost",
			mana_per_second
		),
		0.0
	)


func _consume_channel_mana(delta: float) -> bool:
	var rate: float = get_effective_mana_rate()
	if rate <= 0.0:
		return true
	mana_fractional_cost += rate * maxf(delta, 0.0)
	var whole_cost: int = floori(mana_fractional_cost)
	if whole_cost <= 0:
		_store_mana_debt()
		return true

	var available: int = GameState.get_stat("mana")
	var spent: int = mini(whole_cost, available)
	if spent > 0:
		GameState.spend_mana(spent)
		total_mana_spent += spent
		mana_drained.emit(spent, GameState.get_stat("mana"))
	mana_fractional_cost -= float(spent)
	if mana_fractional_cost >= 1.0:
		mana_fractional_cost = fmod(mana_fractional_cost, 1.0)
	_store_mana_debt()
	return spent >= whole_cost and GameState.get_stat("mana") > 0


func _collect_stream_targets(
	origin: Vector3,
	direction: Vector3,
	stream_length: float
) -> Array[Node]:
	var targets: Array[Node] = []
	if (
		cached_stream_shape == null
		or cached_stream_query == null
		or source_actor == null
		or not is_instance_valid(source_actor)
		or stream_length <= 0.01
	):
		return targets
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return targets

	var resolved_direction: Vector3 = direction
	if resolved_direction.length_squared() <= 0.0001:
		resolved_direction = Vector3.FORWARD
	resolved_direction = resolved_direction.normalized()
	cached_stream_shape.radius = maxf(stream_radius, 0.05)
	cached_stream_shape.height = maxf(stream_length, 0.1)
	cached_stream_query.transform = Transform3D(
		_make_axis_basis(resolved_direction),
		origin + resolved_direction * stream_length * 0.5
	)
	cached_stream_query.collision_mask = collision_mask
	cached_stream_query.exclude = collision_exclusions

	var target_ids: Dictionary = {}
	for result: Dictionary in world.direct_space_state.intersect_shape(
		cached_stream_query,
		48
	):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_effect_target(collider_value as Node)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if target_ids.has(target_id):
			continue
		target_ids[target_id] = true
		targets.append(target)
	return targets


func _apply_pressure_scan(
	targets: Array[Node],
	direction_value: Vector3
) -> void:
	var direction: Vector3 = direction_value
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var planar_direction := Vector3(direction.x, 0.0, direction.z)
	var planar_share: float = clampf(planar_direction.length(), 0.0, 1.0)
	if planar_direction.length_squared() > 0.0001:
		planar_direction = planar_direction.normalized()
	else:
		planar_direction = Vector3.FORWARD

	for target: Node in targets:
		var multiplier: float = (
			boss_force_multiplier if target.is_in_group("boss") else 1.0
		)
		if target.has_meta("water_jet_force_multiplier"):
			multiplier *= maxf(
				float(target.get_meta("water_jet_force_multiplier")),
				0.0
			)
		var impulse_strength: float = (
			force_receiver_impulse_per_scan * multiplier
		)
		var horizontal_impulse: float = impulse_strength * planar_share
		var vertical_impulse: float = (
			impulse_strength * direction.y
			+ force_receiver_up_impulse * multiplier
		)
		var force_receiver: ForceReceiver = target.get_node_or_null(
			"ForceReceiver"
		) as ForceReceiver
		if force_receiver != null:
			if horizontal_impulse > 0.001 or vertical_impulse >= 0.0:
				force_receiver.apply_impulse(
					planar_direction,
					horizontal_impulse,
					vertical_impulse,
					"Water Jet"
				)
			else:
				# ForceReceiver's public impulse method intentionally rejects a
				# purely downward impulse. Preserve the full aimed line here while
				# still respecting its authored maximum force speed.
				force_receiver.external_velocity.y += vertical_impulse
				if (
					force_receiver.external_velocity.length()
					> force_receiver.max_force_speed
				):
					force_receiver.external_velocity = (
						force_receiver.external_velocity.normalized()
						* force_receiver.max_force_speed
					)
		elif target is RigidBody3D:
			var rigid_body: RigidBody3D = target as RigidBody3D
			rigid_body.apply_central_impulse(
				direction
				* rigid_body_force_per_second
				* maxf(contact_scan_seconds, 0.01)
				* multiplier
			)
		elif target.has_method("receive_external_impulse"):
			target.call(
				"receive_external_impulse",
				planar_direction,
				horizontal_impulse,
				vertical_impulse,
				"Water Jet"
			)
		elif target is CharacterBody3D:
			var character: CharacterBody3D = target as CharacterBody3D
			character.velocity += (
				direction
				* character_acceleration
				* maxf(contact_scan_seconds, 0.01)
				* multiplier
			)
			var planar := Vector3(
				character.velocity.x,
				0.0,
				character.velocity.z
			)
			if planar.length() > character_maximum_speed:
				planar = planar.normalized() * character_maximum_speed
				character.velocity.x = planar.x
				character.velocity.z = planar.z
		total_pressure_events += 1
		target_pressured.emit(target, impulse_strength)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["start_transform_primed"] = true
	data["effective_mana_per_second"] = get_effective_mana_rate()
	data["gameplay_effect_cost_modifier"] = true
	data["full_3d_target_pressure"] = true
	data["reused_contact_shape"] = cached_stream_shape != null
	data["reused_contact_query"] = cached_stream_query != null
	return data
