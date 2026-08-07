extends Node3D
class_name WaterJetCast

signal channel_started
signal channel_ended(reason: String)
signal mana_drained(amount: int, current_mana: int)
signal target_pressured(target: Node, impulse_strength: float)
signal chip_tick_resolved(target: Node, result: Dictionary)
signal self_launch_started(upward_speed: float)

@export_group("Channel")
@export var channel_action: StringName = &"cast_spell"
@export_range(0.0, 20.0, 0.1) var mana_per_second: float = 2.5

@export_group("Jet Geometry")
@export_range(1.0, 20.0, 0.1) var maximum_range: float = 9.0
@export_range(0.05, 2.0, 0.05) var stream_radius: float = 0.42
@export_range(0.05, 1.5, 0.05) var endpoint_radius: float = 0.58
@export_range(0.01, 0.25, 0.01) var contact_scan_seconds: float = 0.05
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Target Pressure")
@export_range(0.0, 5.0, 0.05) var force_receiver_impulse_per_scan: float = 0.72
@export_range(0.0, 5.0, 0.05) var force_receiver_up_impulse: float = 0.08
@export_range(0.0, 100.0, 0.5) var rigid_body_force_per_second: float = 28.0
@export_range(0.0, 100.0, 0.5) var character_acceleration: float = 30.0
@export_range(0.0, 30.0, 0.1) var character_maximum_speed: float = 10.0
@export_range(0.0, 1.0, 0.05) var boss_force_multiplier: float = 0.18

@export_group("Rapid Chip")
@export_range(0.05, 1.0, 0.01) var damage_tick_seconds: float = 0.12
@export_range(0, 10, 1) var chip_damage: int = 1
@export_range(0, 10, 1) var chip_stance_damage: int = 0
@export_range(0.0, 10.0, 0.1) var wet_duration_seconds: float = 1.2
@export_range(0.0, 5.0, 0.1) var wet_strength: float = 1.0

@export_group("Self Propulsion")
@export_range(0.5, 10.0, 0.1) var recoil_surface_range: float = 4.2
@export_range(0.0, 100.0, 0.5) var self_recoil_acceleration: float = 34.0
@export_range(0.0, 30.0, 0.1) var maximum_self_upward_speed: float = 10.5
@export_range(0.0, 30.0, 0.1) var maximum_self_planar_speed: float = 8.0
@export_range(0.0, 1.0, 0.05) var minimum_recoil_factor: float = 0.22
@export_range(0.0, 1.0, 0.05) var ground_normal_blend: float = 0.32
@export_range(0.1, 12.0, 0.1) var launch_report_speed: float = 3.4

@export_group("Presentation")
@export_range(5.0, 120.0, 1.0) var visual_updates_per_second: float = 30.0
@export_range(4, 24, 1) var splash_instance_count: int = 12

var source_actor: CharacterBody3D
var action_state: PlayerActionState
var ability_caster: Node
var runtime_payload: DamagePayload
var collision_exclusions: Array[RID] = []

var active: bool = false
var current_origin: Vector3 = Vector3.ZERO
var current_direction: Vector3 = Vector3.FORWARD
var current_stream_length: float = 0.0
var current_hit: Dictionary = {}
var current_targets: Array[Node] = []
var contact_scan_remaining: float = 0.0
var damage_tick_remaining: float = 0.0
var visual_accumulator: float = 0.0
var visual_age: float = 0.0
var mana_fractional_cost: float = 0.0
var last_end_reason: String = "not_started"
var last_hit_name: String = "none"
var last_recoil_strength: float = 0.0
var self_launch_reported: bool = false
var total_channel_seconds: float = 0.0
var total_mana_spent: int = 0
var total_contact_scans: int = 0
var total_pressure_events: int = 0
var total_chip_ticks: int = 0
var total_self_recoil_seconds: float = 0.0

var test_cast_held_override_enabled: bool = false
var test_cast_held: bool = true
var test_direction_override_enabled: bool = false
var test_direction_override: Vector3 = Vector3.FORWARD

var outer_stream: MeshInstance3D
var inner_stream: MeshInstance3D
var endpoint_splash: MultiMeshInstance3D
var endpoint_multimesh: MultiMesh
var endpoint_mesh: SphereMesh
var outer_material: StandardMaterial3D
var inner_material: StandardMaterial3D
var splash_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("water_jet_effects")
	add_to_group("spell_effects")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	global_transform = Transform3D.IDENTITY
	_build_visuals()
	_set_visuals_visible(false)
	set_physics_process(false)


func _exit_tree() -> void:
	_release_cast_channel()
	_store_mana_debt()


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = (
			(new_payload as DamagePayload).duplicate(true) as DamagePayload
		)


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is CharacterBody3D:
		source_actor = new_source_actor as CharacterBody3D


func belongs_to_source(candidate: Node) -> bool:
	return source_actor != null and source_actor == candidate


func execute(player: Node3D, _requested_direction: Vector3) -> void:
	if player is CharacterBody3D:
		source_actor = player as CharacterBody3D
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	action_state = source_actor.get_node_or_null(
		"PlayerActionState"
	) as PlayerActionState
	ability_caster = source_actor.get_node_or_null("AbilityCaster")
	_collect_collision_rids(source_actor, collision_exclusions)
	_cancel_previous_water_jets()
	mana_fractional_cost = clampf(
		float(source_actor.get_meta("water_jet_mana_debt", 0.0)),
		0.0,
		0.9999
	)

	if GameState.get_stat("mana") <= 0:
		last_end_reason = "mana_empty"
		if action_state != null:
			action_state.end_cast()
		_show_message("Water Jet needs Mana to begin.")
		queue_free()
		return

	if action_state != null:
		action_state.end_cast()
		if not action_state.begin_cast_channel():
			last_end_reason = "channel_rejected"
			queue_free()
			return

	active = true
	contact_scan_remaining = 0.0
	damage_tick_remaining = 0.0
	visual_accumulator = 0.0
	visual_age = 0.0
	self_launch_reported = false
	last_end_reason = "active"
	_set_visuals_visible(true)
	set_physics_process(true)
	channel_started.emit()
	_show_message(
		"Water Jet: hold Cast to sustain pressure. Aim into nearby ground to launch Grace."
	)


func _physics_process(delta: float) -> void:
	advance_channel(delta, _is_cast_held())


func advance_channel(delta: float, cast_held: bool = true) -> bool:
	if not active:
		return false
	if not cast_held:
		finish_channel("released")
		return false
	if _channel_interrupted():
		finish_channel("interrupted")
		return false
	if not _water_jet_is_still_equipped():
		finish_channel("spell_changed")
		return false
	if GameState.get_stat("mana") <= 0:
		finish_channel("mana_empty")
		return false

	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return true
	total_channel_seconds += step
	visual_age += step
	current_origin = _get_cast_origin()
	current_direction = _get_cast_direction(current_origin)
	current_hit = _resolve_stream_hit(current_origin, current_direction)
	current_stream_length = _get_stream_length(current_origin, current_hit)
	last_hit_name = _get_hit_name(current_hit)
	_apply_self_recoil(step, current_origin, current_direction, current_hit)

	contact_scan_remaining -= step
	if contact_scan_remaining <= 0.0:
		contact_scan_remaining += maxf(contact_scan_seconds, 0.01)
		current_targets = _collect_stream_targets(
			current_origin,
			current_direction,
			current_stream_length
		)
		total_contact_scans += 1
		_apply_pressure_scan(current_targets, current_direction)

	damage_tick_remaining -= step
	if damage_tick_remaining <= 0.0:
		damage_tick_remaining += maxf(damage_tick_seconds, 0.05)
		_apply_chip_tick(current_targets)

	visual_accumulator += step
	var visual_interval: float = 1.0 / maxf(
		visual_updates_per_second,
		1.0
	)
	if visual_accumulator >= visual_interval:
		visual_accumulator = fmod(visual_accumulator, visual_interval)
		_update_visuals()

	if not _consume_channel_mana(step):
		finish_channel("mana_empty")
		return false
	return true


func finish_channel(reason: String = "released") -> void:
	if not active:
		return
	active = false
	last_end_reason = reason
	set_physics_process(false)
	_set_visuals_visible(false)
	_release_cast_channel()
	_store_mana_debt()
	channel_ended.emit(reason)
	if reason == "mana_empty":
		_show_message("Water Jet sputters out: Mana depleted.")
	queue_free()


func reset_target() -> void:
	if active:
		finish_channel("reset")
	if source_actor != null and is_instance_valid(source_actor):
		source_actor.set_meta("water_jet_mana_debt", 0.0)
	mana_fractional_cost = 0.0


func set_test_cast_held_override(
	held: bool,
	enabled: bool = true
) -> void:
	test_cast_held = held
	test_cast_held_override_enabled = enabled


func set_test_direction_override(
	direction: Vector3,
	enabled: bool = true
) -> void:
	test_direction_override = direction
	test_direction_override_enabled = enabled


func _is_cast_held() -> bool:
	if test_cast_held_override_enabled:
		return test_cast_held
	return Input.is_action_pressed(channel_action)


func _channel_interrupted() -> bool:
	if source_actor == null or not is_instance_valid(source_actor):
		return true
	if bool(source_actor.get("is_defeated")):
		return true
	if action_state == null:
		return false
	return (
		action_state.is_defeated
		or action_state.is_focus_menu_open
		or action_state.is_staggered
		or action_state.is_dodging
		or action_state.is_interacting
		or action_state.is_manipulating
		or action_state.is_guarding
		or action_state.is_using_item
		or not action_state.is_cast_channel_active()
	)


func _water_jet_is_still_equipped() -> bool:
	if ability_caster == null or not ability_caster.has_method(
		"get_current_ability"
	):
		return true
	var current_value: Variant = ability_caster.call("get_current_ability")
	return (
		current_value is AbilityDefinition
		and (current_value as AbilityDefinition).get_spell_id() == "water_jet"
	)


func _consume_channel_mana(delta: float) -> bool:
	var rate: float = maxf(mana_per_second, 0.0)
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


func _store_mana_debt() -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		return
	source_actor.set_meta(
		"water_jet_mana_debt",
		clampf(mana_fractional_cost, 0.0, 0.9999)
	)


func _get_cast_origin() -> Vector3:
	if ability_caster != null and ability_caster.has_method(
		"get_player_cast_origin"
	):
		var origin_value: Variant = ability_caster.call(
			"get_player_cast_origin",
			source_actor
		)
		if origin_value is Vector3:
			return origin_value as Vector3
	return source_actor.global_position + Vector3.UP * 1.05


func _get_cast_direction(origin: Vector3) -> Vector3:
	if test_direction_override_enabled:
		var test_direction: Vector3 = test_direction_override
		if test_direction.length_squared() > 0.0001:
			return test_direction.normalized()
	if ability_caster != null and ability_caster.has_method("get_cast_direction"):
		var direction_value: Variant = ability_caster.call(
			"get_cast_direction",
			source_actor,
			origin
		)
		if direction_value is Vector3:
			var direction: Vector3 = direction_value as Vector3
			if direction.length_squared() > 0.0001:
				return direction.normalized()
	var fallback: Vector3 = -source_actor.global_transform.basis.z
	return (
		fallback.normalized()
		if fallback.length_squared() > 0.0001
		else Vector3.FORWARD
	)


func _resolve_stream_hit(
	origin: Vector3,
	direction: Vector3
) -> Dictionary:
	var result: Dictionary = {
		"valid": false,
		"position": origin + direction * maximum_range,
		"normal": -direction,
		"collider": null,
	}
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return result
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * maximum_range,
		collision_mask
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = collision_exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return result
	result["valid"] = true
	result["position"] = hit.get(
		"position",
		result["position"]
	) as Vector3
	result["normal"] = hit.get("normal", -direction) as Vector3
	result["collider"] = hit.get("collider")
	return result


func _get_stream_length(origin: Vector3, hit: Dictionary) -> float:
	if not bool(hit.get("valid", false)):
		return maximum_range
	return clampf(
		origin.distance_to(hit.get("position", origin) as Vector3) + 0.16,
		0.18,
		maximum_range
	)


func _get_hit_name(hit: Dictionary) -> String:
	var collider_value: Variant = hit.get("collider")
	return str((collider_value as Node).name) if collider_value is Node else "none"


func _collect_stream_targets(
	origin: Vector3,
	direction: Vector3,
	stream_length: float
) -> Array[Node]:
	var targets: Array[Node] = []
	var target_ids: Dictionary = {}
	var world: World3D = source_actor.get_world_3d()
	if world == null or stream_length <= 0.01:
		return targets

	var shape := CylinderShape3D.new()
	shape.radius = maxf(stream_radius, 0.05)
	shape.height = maxf(stream_length, 0.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		_make_axis_basis(direction),
		origin + direction * stream_length * 0.5
	)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = collision_exclusions
	for result: Dictionary in world.direct_space_state.intersect_shape(
		query,
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


func _resolve_effect_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == source_actor or source_actor.is_ancestor_of(current):
			return null
		if _is_effect_target(current):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_effect_target(node: Node) -> bool:
	if node == null or node is StaticBody3D or node is AnimatableBody3D:
		return false
	return (
		node is CharacterBody3D
		or node is RigidBody3D
		or node.get_node_or_null("ForceReceiver") != null
		or node.get_node_or_null("PayloadReceiver") != null
		or node.get_node_or_null("HitReceiver") != null
		or node.has_method("receive_external_impulse")
		or node.has_method("receive_damage_payload")
		or node.has_method("receive_magic_hit")
	)


func _apply_pressure_scan(
	targets: Array[Node],
	direction: Vector3
) -> void:
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
		var force_receiver: ForceReceiver = target.get_node_or_null(
			"ForceReceiver"
		) as ForceReceiver
		if force_receiver != null:
			force_receiver.apply_impulse(
				direction,
				impulse_strength,
				force_receiver_up_impulse * multiplier,
				"Water Jet"
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
				direction,
				impulse_strength,
				force_receiver_up_impulse * multiplier,
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


func _apply_chip_tick(targets: Array[Node]) -> void:
	for target: Node in targets:
		var payload: DamagePayload = _get_payload().duplicate(true) as DamagePayload
		payload.amount = maxi(chip_damage, 0)
		payload.stance_damage = maxi(chip_stance_damage, 0)
		payload.source_name = "Water Jet"
		payload.hit_type = "channel"
		payload.status_effect = "wet"
		payload.status_duration = wet_duration_seconds
		payload.status_strength = wet_strength
		payload.knockback_strength = 0.0
		payload.knockback_up_strength = 0.0
		payload.knockback_direction = Vector3.ZERO
		payload.suppress_reactions = true
		for tag: String in [
			"water",
			"magic",
			"channel",
			"continuous",
			"water_jet",
			"pressure",
			"wet",
		]:
			if not payload.tags.has(tag):
				payload.tags.append(tag)

		var result: Dictionary = _deliver_payload(target, payload)
		total_chip_ticks += 1
		chip_tick_resolved.emit(target, result)


func _deliver_payload(
	target: Node,
	payload: DamagePayload
) -> Dictionary:
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


func _get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 1
	fallback.stance_damage = 0
	fallback.element = "water"
	fallback.source_name = "Water Jet"
	fallback.hit_type = "channel"
	fallback.status_effect = "wet"
	fallback.status_duration = 1.2
	fallback.status_strength = 1.0
	fallback.tags = [
		"water",
		"magic",
		"channel",
		"continuous",
		"water_jet",
		"pressure",
		"wet",
	]
	return fallback


func _apply_self_recoil(
	delta: float,
	origin: Vector3,
	direction: Vector3,
	hit: Dictionary
) -> void:
	last_recoil_strength = 0.0
	if not bool(hit.get("valid", false)):
		return
	var collider_value: Variant = hit.get("collider")
	if not collider_value is Node or not _is_recoil_surface(
		collider_value as Node
	):
		return
	var hit_position: Vector3 = hit.get("position", origin) as Vector3
	var distance: float = origin.distance_to(hit_position)
	if distance > recoil_surface_range:
		return
	var hit_normal: Vector3 = hit.get("normal", -direction) as Vector3
	if hit_normal.length_squared() <= 0.0001:
		hit_normal = -direction
	hit_normal = hit_normal.normalized()

	var proximity: float = 1.0 - clampf(
		distance / maxf(recoil_surface_range, 0.01),
		0.0,
		1.0
	)
	var downward_factor: float = clampf(-direction.y, 0.0, 1.0)
	var recoil_factor: float = maxf(
		minimum_recoil_factor,
		proximity * lerpf(0.42, 1.0, downward_factor)
	)
	var recoil_direction: Vector3 = -direction
	if hit_normal.y > 0.25:
		recoil_direction = recoil_direction.lerp(
			hit_normal,
			clampf(ground_normal_blend, 0.0, 1.0)
		)
	if recoil_direction.length_squared() <= 0.0001:
		recoil_direction = hit_normal
	recoil_direction = recoil_direction.normalized()
	last_recoil_strength = self_recoil_acceleration * recoil_factor
	source_actor.velocity += (
		recoil_direction * last_recoil_strength * maxf(delta, 0.0)
	)
	if source_actor.velocity.y > maximum_self_upward_speed:
		source_actor.velocity.y = maximum_self_upward_speed
	var planar := Vector3(
		source_actor.velocity.x,
		0.0,
		source_actor.velocity.z
	)
	if planar.length() > maximum_self_planar_speed:
		planar = planar.normalized() * maximum_self_planar_speed
		source_actor.velocity.x = planar.x
		source_actor.velocity.z = planar.z
	total_self_recoil_seconds += maxf(delta, 0.0)

	if not self_launch_reported and source_actor.velocity.y >= launch_report_speed:
		self_launch_reported = true
		var serial: int = int(
			source_actor.get_meta("water_jet_self_launch_serial", 0)
		) + 1
		source_actor.set_meta("water_jet_self_launch_serial", serial)
		source_actor.set_meta(
			"water_jet_self_launch_speed",
			source_actor.velocity.y
		)
		self_launch_started.emit(source_actor.velocity.y)


func _is_recoil_surface(node: Node) -> bool:
	return (
		node is StaticBody3D
		or node is AnimatableBody3D
		or node is GridMap
		or node is CSGShape3D
		or node.is_in_group("water_jet_recoil_surface")
	)


func _build_visuals() -> void:
	var stream_mesh := CylinderMesh.new()
	stream_mesh.top_radius = 1.0
	stream_mesh.bottom_radius = 1.0
	stream_mesh.height = 1.0
	stream_mesh.radial_segments = 12
	stream_mesh.rings = 1

	outer_material = _make_water_material(
		Color(0.05, 0.42, 0.98, 0.42),
		Color(0.03, 0.24, 0.72),
		1.2
	)
	inner_material = _make_water_material(
		Color(0.64, 0.94, 1.0, 0.78),
		Color(0.25, 0.78, 1.0),
		2.2
	)
	splash_material = _make_water_material(
		Color(0.72, 0.96, 1.0, 0.8),
		Color(0.35, 0.86, 1.0),
		2.4
	)
	splash_material.vertex_color_use_as_albedo = true

	outer_stream = MeshInstance3D.new()
	outer_stream.name = "WaterJetOuterStream"
	outer_stream.mesh = stream_mesh
	outer_stream.material_override = outer_material
	outer_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outer_stream)

	inner_stream = MeshInstance3D.new()
	inner_stream.name = "WaterJetInnerStream"
	inner_stream.mesh = stream_mesh
	inner_stream.material_override = inner_material
	inner_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inner_stream)

	endpoint_mesh = SphereMesh.new()
	endpoint_mesh.radius = 0.08
	endpoint_mesh.height = 0.16
	endpoint_mesh.radial_segments = 8
	endpoint_mesh.rings = 4
	endpoint_multimesh = MultiMesh.new()
	endpoint_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	endpoint_multimesh.use_colors = true
	endpoint_multimesh.mesh = endpoint_mesh
	endpoint_multimesh.instance_count = maxi(splash_instance_count, 1)
	endpoint_splash = MultiMeshInstance3D.new()
	endpoint_splash.name = "WaterJetEndpointSplash"
	endpoint_splash.multimesh = endpoint_multimesh
	endpoint_splash.material_override = splash_material
	endpoint_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(endpoint_splash)


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


func _update_visuals() -> void:
	if not active:
		return
	var pulse: float = 1.0 + sin(visual_age * 34.0) * 0.035
	_set_cylinder_between(
		outer_stream,
		current_origin,
		current_origin + current_direction * current_stream_length,
		stream_radius * pulse
	)
	_set_cylinder_between(
		inner_stream,
		current_origin,
		current_origin + current_direction * current_stream_length,
		stream_radius * 0.42 * (2.0 - pulse)
	)
	var hit_valid: bool = bool(current_hit.get("valid", false))
	endpoint_splash.visible = hit_valid
	if hit_valid:
		endpoint_splash.global_transform = Transform3D(
			Basis.IDENTITY,
			current_hit.get(
				"position",
				current_origin + current_direction * current_stream_length
			) as Vector3
		)
		_update_splash_instances(
			current_hit.get("normal", -current_direction) as Vector3
		)


func _set_cylinder_between(
	mesh_instance: MeshInstance3D,
	start: Vector3,
	finish: Vector3,
	radius: float
) -> void:
	var delta: Vector3 = finish - start
	var length: float = delta.length()
	if length <= 0.01:
		mesh_instance.visible = false
		return
	mesh_instance.visible = true
	var direction: Vector3 = delta / length
	var basis: Basis = _make_axis_basis(direction)
	mesh_instance.global_transform = Transform3D(
		Basis(
			basis.x * maxf(radius, 0.01),
			basis.y * length,
			basis.z * maxf(radius, 0.01)
		),
		(start + finish) * 0.5
	)


func _update_splash_instances(normal_value: Vector3) -> void:
	if endpoint_multimesh == null:
		return
	var normal: Vector3 = normal_value
	if normal.length_squared() <= 0.0001:
		normal = -current_direction
	normal = normal.normalized()
	var tangent_basis: Basis = _make_axis_basis(normal)
	var tangent: Vector3 = tangent_basis.x
	var binormal: Vector3 = tangent_basis.z
	var count: int = endpoint_multimesh.instance_count
	for instance_index: int in range(count):
		var ratio: float = (
			float(instance_index) / float(maxi(count, 1))
		)
		var phase: float = fmod(
			visual_age * 3.4 + ratio * 1.7,
			1.0
		)
		var angle: float = TAU * ratio * 2.7 + visual_age * 2.2
		var radial: Vector3 = (
			tangent * cos(angle) + binormal * sin(angle)
		)
		var distance: float = endpoint_radius * (0.18 + phase * 0.82)
		var local_position: Vector3 = (
			radial * distance
			+ normal * (0.04 + phase * 0.18)
			- current_direction * phase * 0.12
		)
		var scale_value: float = maxf(0.18, (1.0 - phase) * 0.75)
		endpoint_multimesh.set_instance_transform(
			instance_index,
			Transform3D(
				Basis.IDENTITY.scaled(Vector3.ONE * scale_value),
				local_position
			)
		)
		endpoint_multimesh.set_instance_color(
			instance_index,
			Color(0.68, 0.94, 1.0, 0.25 + (1.0 - phase) * 0.68)
		)


func _make_axis_basis(direction_value: Vector3) -> Basis:
	var direction: Vector3 = direction_value
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var reference: Vector3 = (
		Vector3.UP
		if absf(direction.dot(Vector3.UP)) < 0.94
		else Vector3.RIGHT
	)
	var right: Vector3 = reference.cross(direction).normalized()
	var forward: Vector3 = direction.cross(right).normalized()
	return Basis(right, direction, forward).orthonormalized()


func _set_visuals_visible(value: bool) -> void:
	if outer_stream != null:
		outer_stream.visible = value
	if inner_stream != null:
		inner_stream.visible = value
	if endpoint_splash != null:
		endpoint_splash.visible = false


func _release_cast_channel() -> void:
	if action_state != null and action_state.is_cast_channel_active():
		action_state.end_cast()


func _cancel_previous_water_jets() -> void:
	for existing: Node in get_tree().get_nodes_in_group("water_jet_effects"):
		if existing == self:
			continue
		if (
			existing.has_method("belongs_to_source")
			and bool(existing.call("belongs_to_source", source_actor))
			and existing.has_method("finish_channel")
		):
			existing.call("finish_channel", "replaced")


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


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	var target_names: Array[String] = []
	for target: Node in current_targets:
		if target != null and is_instance_valid(target):
			target_names.append(str(target.name))
	return {
		"water_jet_cast": true,
		"active": active,
		"mana_per_second": mana_per_second,
		"mana_debt": snappedf(mana_fractional_cost, 0.001),
		"stream_length": snappedf(current_stream_length, 0.01),
		"stream_radius": stream_radius,
		"direction": current_direction,
		"targets": target_names,
		"last_hit": last_hit_name,
		"last_recoil_strength": snappedf(last_recoil_strength, 0.01),
		"self_launch_reported": self_launch_reported,
		"channel_seconds": snappedf(total_channel_seconds, 0.01),
		"mana_spent": total_mana_spent,
		"contact_scans": total_contact_scans,
		"pressure_events": total_pressure_events,
		"chip_ticks": total_chip_ticks,
		"self_recoil_seconds": snappedf(total_self_recoil_seconds, 0.01),
		"visual_meshes": 2,
		"splash_multimeshes": 1,
		"per_splash_nodes": 0,
		"persistent": is_in_group("persistent_spell_effects"),
		"last_end_reason": last_end_reason,
	}
