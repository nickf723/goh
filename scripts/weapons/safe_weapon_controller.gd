extends "res://scripts/weapons/weapon_controller.gd"
class_name SafeWeaponController

const GameplayEffectAccessBodyFormScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)
const WeaponClassMotionCatalogScript = preload(
	"res://scripts/weapons/weapon_class_motion_catalog.gd"
)
const WeaponClassCombatIdentityScript = preload(
	"res://scripts/weapons/weapon_class_combat_identity.gd"
)

@export_group("Camera-Decoupled Attack Facing")
@export_range(0.0, 1.0, 0.05) var visual_facing_blend: float = 0.78
@export_range(0.01, 0.5, 0.01) var visual_facing_return_seconds: float = 0.14

var _gesture_attack_stamina_spent: int = 0
var _attack_facing_tween: Tween
var _attack_serial: int = 0
var _return_scheduled: Dictionary = {}


func _ready() -> void:
	super._ready()
	if not attack_finished.is_connected(_on_safe_attack_finished):
		attack_finished.connect(_on_safe_attack_finished)


func get_attack_speed() -> float:
	return maxf(
		GameplayEffectAccessBodyFormScript.modify_float(
			"attack_speed",
			super.get_attack_speed()
		),
		0.05
	)


func get_effective_attack_range(
	attack: WeaponAttackDefinition
) -> float:
	return maxf(
		GameplayEffectAccessBodyFormScript.modify_float(
			"weapon_range",
			super.get_effective_attack_range(attack)
		),
		0.1
	)


func send_payload_to_target(
	target: Node,
	payload: DamagePayload
) -> Dictionary:
	if payload == null:
		return super.send_payload_to_target(target, payload)
	var resolved: DamagePayload = payload.duplicate(true) as DamagePayload
	if resolved == null:
		return super.send_payload_to_target(target, payload)
	resolved.amount = maxi(
		GameplayEffectAccessBodyFormScript.modify_int(
			"weapon_damage",
			resolved.amount,
			"round"
		),
		0
	)
	resolved.stance_damage = maxi(
		GameplayEffectAccessBodyFormScript.modify_int(
			"weapon_stance_damage",
			resolved.stance_damage,
			"round"
		),
		0
	)
	resolved.knockback_strength = maxf(
		GameplayEffectAccessBodyFormScript.modify_float(
			"weapon_knockback",
			resolved.knockback_strength
		),
		0.0
	)
	var actor: Node3D = get_actor()
	if actor != null:
		var form_id: String = str(
			actor.get_meta("body_form_id", "normal")
		)
		if form_id != "normal":
			var form_tag: String = "body_form_" + form_id
			if not resolved.tags.has(form_tag):
				resolved.tags.append(form_tag)

	var weapon_class: String = equipped_weapon.weapon_class if equipped_weapon != null else "sword"
	var attack: WeaponAttackDefinition = current_attack
	if attack != null:
		var target_offset: Vector3 = get_target_position(target) - get_attack_origin()
		WeaponClassCombatIdentityScript.apply_payload_identity(
			resolved,
			weapon_class,
			attack,
			combo_history.size(),
			target,
			target_offset
		)

	var result: Dictionary = super.send_payload_to_target(target, resolved)
	WeaponClassCombatIdentityScript.apply_post_hit_identity(
		target,
		resolved,
		weapon_class
	)

	if (
		weapon_class == "boomerang"
		and attack != null
		and not resolved.tags.has("return_pass")
		and not resolved.tags.has("boomerang_return_scheduled")
	):
		_schedule_boomerang_return(target, resolved, attack)

	return result


func start_attack(attack: WeaponAttackDefinition) -> bool:
	_kill_attack_facing_tween()
	var resolved_attack: WeaponAttackDefinition = attack
	var weapon_class: String = equipped_weapon.weapon_class if equipped_weapon != null else "sword"
	if equipped_weapon != null:
		resolved_attack = WeaponClassMotionCatalogScript.prepare_attack(
			attack,
			weapon_class
		)
	resolved_attack = _prepare_class_control_attack(
		resolved_attack,
		attack,
		weapon_class
	)
	var stamina_before: int = GameState.get_stat("stamina")
	var started: bool = super.start_attack(resolved_attack)
	if started:
		_attack_serial += 1
	_gesture_attack_stamina_spent = (
		maxi(stamina_before - GameState.get_stat("stamina"), 0)
		if started
		else 0
	)
	return started


func _prepare_class_control_attack(
	resolved_attack: WeaponAttackDefinition,
	source_attack: WeaponAttackDefinition,
	weapon_class: String
) -> WeaponAttackDefinition:
	if resolved_attack == null:
		return source_attack
	var needs_runtime_tuning: bool = weapon_class in [
		"staff", "daggers", "gauntlets", "shuriken"
	]
	if not needs_runtime_tuning:
		return resolved_attack
	var tuned: WeaponAttackDefinition = resolved_attack
	if tuned == source_attack:
		tuned = source_attack.duplicate(true) as WeaponAttackDefinition
		if tuned == null:
			return resolved_attack
	match weapon_class:
		"staff":
			tuned.allow_spell_cancel = true
			tuned.cancel_window_start_normalized = minf(
				tuned.cancel_window_start_normalized,
				0.5
			)
		"daggers", "gauntlets", "shuriken":
			tuned.allow_dodge_cancel = true
			tuned.cancel_window_start_normalized = minf(
				tuned.cancel_window_start_normalized,
				0.58 if tuned.input_kind == "heavy" else 0.42
			)
	return tuned


func find_targets(attack: WeaponAttackDefinition) -> Array[Node]:
	if attack == null or equipped_weapon == null:
		return []
	var weapon_class: String = equipped_weapon.weapon_class

	# Whip and chain already own physical swept-contact rigs. Keep those as the
	# authority, but still enforce the same true-range contract as every other
	# player weapon so a generous rig can never become a room-wide hit query.
	if (
		runtime_weapon_rig != null
		and runtime_weapon_rig.has_method("find_weapon_targets")
	):
		return _filter_targets_by_true_range(super.find_targets(attack), attack)

	var geometry: String = WeaponClassCombatIdentityScript.get_geometry_mode(
		weapon_class,
		attack
	)
	match geometry:
		WeaponClassCombatIdentityScript.GEOMETRY_LINE:
			return _find_line_targets(attack, weapon_class)
		WeaponClassCombatIdentityScript.GEOMETRY_RADIAL:
			return _find_radial_targets(attack)
		WeaponClassCombatIdentityScript.GEOMETRY_PRECISION_RAY:
			return _find_ray_targets(attack, [0.0])
		WeaponClassCombatIdentityScript.GEOMETRY_FAN_RAYS:
			return _find_ray_targets(
				attack,
				WeaponClassCombatIdentityScript.get_fan_angles(attack)
			)
		WeaponClassCombatIdentityScript.GEOMETRY_RETURNING_RAY:
			return _find_ray_targets(attack, [0.0])
		_:
			return _filter_targets_by_true_range(super.find_targets(attack), attack)


func _filter_targets_by_true_range(
	targets: Array[Node],
	attack: WeaponAttackDefinition
) -> Array[Node]:
	var filtered: Array[Node] = []
	if attack == null or equipped_weapon == null:
		return filtered
	var actor: Node3D = get_actor()
	if actor == null:
		return filtered
	var maximum_range: float = (
		get_effective_attack_range(attack)
		+ WeaponClassCombatIdentityScript.get_true_range_padding(
			equipped_weapon.weapon_class
		)
	)
	for target: Node in targets:
		if target == null or not is_instance_valid(target):
			continue
		var offset: Vector3 = get_target_position(target) - actor.global_position
		offset.y = 0.0
		if offset.length() > maximum_range:
			continue
		if not filtered.has(target):
			filtered.append(target)
		if filtered.size() >= get_effective_max_targets(attack):
			break
	return filtered


func _find_line_targets(
	attack: WeaponAttackDefinition,
	weapon_class: String
) -> Array[Node]:
	var probe: WeaponAttackDefinition = attack.duplicate(true) as WeaponAttackDefinition
	if probe == null:
		return []
	probe.max_targets = 48
	probe.cone_angle_degrees = maxf(probe.cone_angle_degrees, 100.0)
	var raw_targets: Array[Node] = super.find_targets(probe)
	var origin: Vector3 = get_attack_origin()
	var forward: Vector3 = get_attack_forward()
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var half_width: float = WeaponClassCombatIdentityScript.get_line_half_width(
		weapon_class,
		attack
	)
	var maximum_range: float = (
		get_effective_attack_range(attack)
		+ WeaponClassCombatIdentityScript.get_true_range_padding(weapon_class)
	)
	var scored: Array[Dictionary] = []
	for target: Node in raw_targets:
		if target == null or not is_instance_valid(target):
			continue
		var offset: Vector3 = get_target_position(target) - origin
		offset.y = 0.0
		var forward_distance: float = offset.dot(forward)
		if forward_distance < -0.25 or forward_distance > maximum_range:
			continue
		var lateral: Vector3 = offset - forward * forward_distance
		if lateral.length() > half_width + 0.7:
			continue
		scored.append({"target": target, "distance": forward_distance})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)
	var resolved: Array[Node] = []
	for row: Dictionary in scored:
		var target: Node = row.get("target") as Node
		if target != null and not resolved.has(target):
			resolved.append(target)
		if resolved.size() >= get_effective_max_targets(attack):
			break
	return resolved


func _find_radial_targets(attack: WeaponAttackDefinition) -> Array[Node]:
	var radial: WeaponAttackDefinition = attack.duplicate(true) as WeaponAttackDefinition
	if radial == null:
		return []
	radial.cone_angle_degrees = 360.0
	radial.attack_center_forward_offset = 0.0
	radial.max_targets = max(radial.max_targets, 12)
	return _filter_targets_by_true_range(super.find_targets(radial), radial)


func _find_ray_targets(
	attack: WeaponAttackDefinition,
	angles_degrees: Array[float]
) -> Array[Node]:
	var actor: Node3D = get_actor()
	if actor == null:
		return []
	var origin: Vector3 = _get_ranged_origin(actor)
	var base_forward: Vector3 = get_attack_forward()
	base_forward.y = 0.0
	if base_forward.length_squared() <= 0.0001:
		base_forward = Vector3.FORWARD
	else:
		base_forward = base_forward.normalized()
	var maximum_range: float = get_effective_attack_range(attack)
	var targets: Array[Node] = []
	for angle_degrees: float in angles_degrees:
		var direction: Vector3 = base_forward.rotated(
			Vector3.UP,
			deg_to_rad(angle_degrees)
		).normalized()
		var endpoint: Vector3 = origin + direction * maximum_range
		var query := PhysicsRayQueryParameters3D.new()
		query.from = origin
		query.to = endpoint
		query.collision_mask = hit_mask
		query.collide_with_bodies = true
		query.collide_with_areas = true
		if actor is CollisionObject3D:
			query.exclude = [(actor as CollisionObject3D).get_rid()]
		var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		var trace_end: Vector3 = endpoint
		if not result.is_empty():
			trace_end = result.get("position", endpoint) as Vector3
			var collider: Node = result.get("collider") as Node
			var target: Node = find_payload_target(collider)
			if target != null and target != actor and not targets.has(target):
				targets.append(target)
		_spawn_ranged_trace(origin, trace_end, attack, angle_degrees)
		if targets.size() >= get_effective_max_targets(attack):
			break
	return targets


func _get_ranged_origin(actor: Node3D = null) -> Vector3:
	var resolved_actor: Node3D = actor if actor != null else get_actor()
	if resolved_actor == null:
		return get_attack_origin()
	# Player root sits around the torso center. A modest lift tracks Grace's hand /
	# chest band while avoiding the old melee origin that skimmed over human-sized
	# targets when used as a horizontal projectile ray.
	return resolved_actor.global_position + Vector3.UP * 0.42


func _spawn_ranged_trace(
	from: Vector3,
	to: Vector3,
	attack: WeaponAttackDefinition,
	angle_degrees: float = 0.0
) -> void:
	if not is_inside_tree():
		return
	var distance: float = from.distance_to(to)
	if distance <= 0.03:
		return
	var trace_parent: Node = get_tree().current_scene
	if trace_parent == null:
		trace_parent = get_parent()
	if trace_parent == null:
		return
	var trace := MeshInstance3D.new()
	trace.name = "WeaponRangeTrace"
	var mesh := BoxMesh.new()
	var width: float = 0.035 if absf(angle_degrees) > 0.01 else 0.055
	mesh.size = Vector3(width, width, distance)
	trace.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var color: Color = (
		attack.trail_color
		if attack != null
		else equipped_weapon.visual_accent_color
	)
	color.a = 0.82
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 1.5
	trace.material_override = material
	trace_parent.add_child(trace)
	trace.global_position = (from + to) * 0.5
	trace.look_at(to, Vector3.UP)
	var tween: Tween = trace.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(trace, "scale", Vector3(0.18, 0.18, 1.0), 0.12)
	tween.finished.connect(Callable(trace, "queue_free"))


func _schedule_boomerang_return(
	target: Node,
	outbound_payload: DamagePayload,
	attack: WeaponAttackDefinition
) -> void:
	if target == null or outbound_payload == null or attack == null:
		return
	var key: String = str(_attack_serial) + ":" + str(target.get_instance_id())
	if _return_scheduled.has(key):
		return
	_return_scheduled[key] = true
	var target_ref: WeakRef = weakref(target)
	var payload_copy: DamagePayload = outbound_payload.duplicate(true) as DamagePayload
	var attack_copy: WeaponAttackDefinition = attack.duplicate(true) as WeaponAttackDefinition
	_execute_boomerang_return(
		target_ref,
		payload_copy,
		attack_copy,
		key,
		WeaponClassCombatIdentityScript.get_return_delay(attack)
	)


func _execute_boomerang_return(
	target_ref: WeakRef,
	outbound_payload: DamagePayload,
	attack: WeaponAttackDefinition,
	key: String,
	delay: float
) -> void:
	await get_tree().create_timer(maxf(delay, 0.05)).timeout
	_return_scheduled.erase(key)
	if target_ref == null:
		return
	var target_value: Variant = target_ref.get_ref()
	if not is_instance_valid(target_value) or not (target_value is Node):
		return
	var target: Node = target_value as Node
	if target.is_queued_for_deletion():
		return
	var returned: DamagePayload = WeaponClassCombatIdentityScript.build_return_payload(
		outbound_payload
	)
	if returned == null:
		return
	var return_origin: Vector3 = _get_ranged_origin()
	var target_position: Vector3 = get_target_position(target) + Vector3.UP * 0.85
	var return_direction: Vector3 = return_origin - target_position
	return_direction.y = 0.0
	if return_direction.length_squared() > 0.0001:
		returned.knockback_direction = return_direction.normalized()
	_spawn_ranged_trace(target_position, return_origin, attack)
	super.send_payload_to_target(target, returned)
	HitStop.request(maxf(attack.hit_stop_duration * 0.55, 0.025), 0.12)


# Attack geometry already caches attack_forward_override before this hook runs.
# Rotate only Grace's visible body and weapon presentation toward that heading.
# The CharacterBody3D and its CameraPivot retain their world yaw, so close-range
# facing assist cannot teleport the camera when Grace attacks beside a target.
func apply_attack_facing(direction: Vector3) -> void:
	var actor: Node3D = get_actor()
	if actor == null or direction.length_squared() <= 0.001:
		return

	var planar_direction: Vector3 = direction
	planar_direction.y = 0.0
	if planar_direction.length_squared() <= 0.001:
		return
	planar_direction = planar_direction.normalized()

	var target_world_yaw: float = atan2(-planar_direction.x, -planar_direction.z)
	var local_yaw: float = wrapf(
		target_world_yaw - actor.global_rotation.y,
		-PI,
		PI
	)
	var maximum_visual_turn: float = deg_to_rad(
		maxf(facing_assist_max_turn_degrees, 0.0)
	)
	if maximum_visual_turn > 0.0:
		local_yaw = clampf(
			local_yaw,
			-maximum_visual_turn,
			maximum_visual_turn
		)

	var blend: float = clampf(visual_facing_blend, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, local_yaw, blend)
	var grace_visual: Node3D = _get_grace_visual()
	if grace_visual != null:
		grace_visual.rotation.y = lerp_angle(
			grace_visual.rotation.y,
			local_yaw,
			blend
		)


func finish_current_attack() -> void:
	super.finish_current_attack()
	# A buffered follow-up may already be active when the base method returns.
	# Preserve its newly authored facing instead of pulling the model to neutral.
	if current_attack == null:
		reset_attack_facing_visual()


func cancel_current_attack(reason: String = "cancelled") -> void:
	super.cancel_current_attack(reason)
	reset_attack_facing_visual()


func reset_attack_facing_visual(immediate: bool = false) -> void:
	_kill_attack_facing_tween()
	var grace_visual: Node3D = _get_grace_visual()
	if immediate or visual_facing_return_seconds <= 0.0 or not is_inside_tree():
		rotation.y = 0.0
		if grace_visual != null:
			grace_visual.rotation.y = 0.0
		return

	_attack_facing_tween = create_tween()
	_attack_facing_tween.set_trans(Tween.TRANS_QUAD)
	_attack_facing_tween.set_ease(Tween.EASE_OUT)
	_attack_facing_tween.parallel().tween_property(
		self,
		"rotation:y",
		0.0,
		visual_facing_return_seconds
	)
	if grace_visual != null:
		_attack_facing_tween.parallel().tween_property(
			grace_visual,
			"rotation:y",
			0.0,
			visual_facing_return_seconds
	)


func get_attack_facing_debug_data() -> Dictionary:
	var actor: Node3D = get_actor()
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var grace_visual: Node3D = _get_grace_visual()
	return {
		"actor_yaw": actor.global_rotation.y if actor != null else 0.0,
		"camera_yaw": camera.global_rotation.y if camera != null else 0.0,
		"weapon_visual_yaw": rotation.y,
		"grace_visual_yaw": grace_visual.rotation.y if grace_visual != null else 0.0,
		"camera_decoupled": true,
		"body_form": (
			str(actor.get_meta("body_form_id", "normal"))
			if actor != null
			else "normal"
		),
		"body_form_attack_speed": get_attack_speed(),
		"class_motion_fallback": (
			current_attack != null
			and WeaponClassMotionCatalogScript.has_profile(current_attack.character_pose_id)
		),
		"combat_geometry": (
			WeaponClassCombatIdentityScript.get_geometry_mode(
				equipped_weapon.weapon_class,
				current_attack
			)
			if equipped_weapon != null and current_attack != null
			else "idle"
		),
	}


func _get_grace_visual() -> Node3D:
	var actor: Node3D = get_actor()
	if actor == null:
		return null
	return actor.get_node_or_null("GraceVisualV1") as Node3D


func _kill_attack_facing_tween() -> void:
	if _attack_facing_tween != null and _attack_facing_tween.is_valid():
		_attack_facing_tween.kill()
	_attack_facing_tween = null


func cancel_startup_attack_for_special(
	reason: String = "divine_special_chord"
) -> bool:
	if current_attack == null:
		return false
	if current_phase != "startup" or attack_hit_applied:
		return false
	var refund: int = _gesture_attack_stamina_spent
	# Call the base implementation directly so the tracked cost survives until
	# after the attack is fully cancelled.
	super.cancel_current_attack(reason)
	reset_attack_facing_visual()
	_gesture_attack_stamina_spent = 0
	if refund > 0:
		GameState.restore_stamina(refund)
	return true


func _on_safe_attack_finished(_attack_id: String) -> void:
	# The base controller emits before starting any buffered follow-up, so this
	# clears the completed attack without erasing the next attack's tracked cost.
	_gesture_attack_stamina_spent = 0


func _get_locked_weak_point(actor: Node3D, attack: WeaponAttackDefinition) -> Node:
	if actor == null or attack == null:
		return null
	var target_value: Variant = actor.get("lock_on_target")
	if not is_instance_valid(target_value):
		_clear_stale_lock_target(actor)
		return null
	if not (target_value is Node3D):
		return null
	var target: Node3D = target_value as Node3D
	if not is_instance_valid(target):
		_clear_stale_lock_target(actor)
		return null
	if target.is_queued_for_deletion():
		_clear_stale_lock_target(actor)
		return null
	if not target.is_in_group("lock_on_weak_point"):
		return null
	if target.has_method("is_targeting_enabled") and not bool(target.call("is_targeting_enabled")):
		return null
	var target_position: Vector3 = get_target_position(target)
	var maximum_distance: float = get_effective_attack_range(attack) + 0.75
	if get_attack_origin().distance_to(target_position) > maximum_distance:
		return null
	if not is_target_in_attack_cone(target, attack):
		return null
	return target


func get_target_position(target: Node) -> Vector3:
	if not is_instance_valid(target):
		return Vector3.ZERO
	if target.is_queued_for_deletion():
		return Vector3.ZERO
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	if is_instance_valid(parent) and parent is Node3D:
		return (parent as Node3D).global_position
	return Vector3.ZERO


func _clear_stale_lock_target(actor: Node) -> void:
	if not is_instance_valid(actor):
		return
	if actor.has_method("clear_lock_on"):
		actor.call("clear_lock_on")
	else:
		actor.set("lock_on_target", null)
