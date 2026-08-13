extends "res://scripts/weapons/safe_weapon_controller.gd"
class_name CombatWeaponControllerV2

const RANGED_AIM_CLASSES: Array[String] = ["bow", "shuriken", "boomerang"]
const TARGET_ENGAGEMENT_CLASSES: Array[String] = ["sword"]

@export_group("Target Engagement")
@export_range(0.0, 2.0, 0.05) var engagement_capture_padding: float = 0.9
@export_range(0.5, 3.0, 0.05) var engagement_min_spacing: float = 1.35
@export_range(0.5, 3.0, 0.05) var engagement_max_spacing: float = 1.75
@export_range(0.0, 1.5, 0.05) var engagement_max_assisted_step: float = 0.72
@export_range(0.0, 90.0, 1.0) var engagement_max_turn_degrees: float = 48.0
@export_range(0.0, 1.0, 0.05) var engagement_heading_strength: float = 0.9

var engagement_target: Node3D
var engagement_aim_point: Vector3 = Vector3.ZERO
var engagement_start_distance: float = 0.0
var engagement_assisted_step: float = 0.0
var engagement_source: String = "none"


func start_attack(attack: WeaponAttackDefinition) -> bool:
	_prepare_engagement(attack)
	var started: bool = super.start_attack(attack)
	if not started:
		_clear_engagement()
	return started


# Ranged attacks should follow the combat aim while Grace strafes. The shared
# melee resolver deliberately blends movement input into attack heading, which
# is desirable for lunges but made projectile proxies veer away from the target.
# Sword attacks additionally bias their committed heading toward the target that
# this attack actually engaged, so feet, hit geometry, and body intent agree.
func resolve_attack_forward(attack: WeaponAttackDefinition) -> Vector3:
	if _uses_live_ranged_aim():
		var live_forward: Vector3 = _get_live_ranged_forward()
		if live_forward.length_squared() > 0.0001:
			return live_forward

	var resolved: Vector3 = super.resolve_attack_forward(attack)
	if not _engagement_is_valid() or attack == null:
		return resolved
	var actor: Node3D = get_actor()
	if actor == null:
		return resolved
	var target_direction: Vector3 = engagement_aim_point - actor.global_position
	target_direction.y = 0.0
	if target_direction.length_squared() <= 0.0001:
		return resolved
	target_direction = target_direction.normalized()
	var angle: float = resolved.angle_to(target_direction)
	var maximum_turn: float = deg_to_rad(maxf(engagement_max_turn_degrees, 0.0))
	if maximum_turn <= 0.0 or angle > maximum_turn:
		return resolved
	var angle_weight: float = 1.0 - clampf(angle / maxf(maximum_turn, 0.001), 0.0, 1.0) * 0.28
	return resolved.slerp(
		target_direction,
		clampf(engagement_heading_strength * angle_weight, 0.0, 1.0)
	).normalized()


# The ranged query happens after startup. Re-sample aim at contact time so a
# player can keep tracking a target while moving instead of firing along the
# movement-contaminated heading cached when the attack button was pressed.
func get_attack_forward() -> Vector3:
	if _uses_live_ranged_aim() and current_attack != null:
		var live_forward: Vector3 = _get_live_ranged_forward()
		if live_forward.length_squared() > 0.0001:
			return live_forward
	return super.get_attack_forward()


# Target-aware footwork closes only the amount of space required to put Grace
# in a believable striking pocket. A nearby enemy shortens the authored lunge;
# a slightly distant enemy can add a modest catch-up step. The target is chosen
# before the attack begins and never re-homed during the swing.
func request_combat_motion(attack: WeaponAttackDefinition) -> void:
	if attack == null or not _engagement_is_valid():
		super.request_combat_motion(attack)
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D) or not (actor as CharacterBody3D).is_on_floor():
		super.request_combat_motion(attack)
		return

	var body: CharacterBody3D = actor as CharacterBody3D
	var planar_offset: Vector3 = engagement_aim_point - body.global_position
	planar_offset.y = 0.0
	var distance: float = planar_offset.length()
	if distance <= 0.001:
		super.request_combat_motion(attack)
		return

	var preferred_spacing: float = clampf(
		attack.attack_range * 0.58,
		engagement_min_spacing,
		engagement_max_spacing
	)
	var required_closing: float = maxf(distance - preferred_spacing, 0.0)
	var maximum_step: float = maxf(
		attack.movement_distance,
		engagement_max_assisted_step
	)
	var assisted_distance: float = minf(required_closing, maximum_step)
	# Preserve a tiny authored weight shift when already in the pocket, but do not
	# slide through a target simply because the resource normally lunges forward.
	if required_closing <= 0.04:
		assisted_distance = minf(attack.movement_distance * 0.22, 0.08)
	engagement_assisted_step = assisted_distance

	if assisted_distance <= 0.001:
		return
	if body.has_method("begin_combat_motion"):
		body.call(
			"begin_combat_motion",
			planar_offset.normalized(),
			assisted_distance,
			maxf(attack.movement_duration, 0.01)
		)
		return
	super.request_combat_motion(attack)


# Explicit aerial Light / Heavy contexts keep the input grammar predictable:
# Light carries Grace through the target while preserving jump arc; Heavy turns
# into a committed descending strike and arms the existing landing impact.
func apply_aerial_technique_motion(context_id: String) -> void:
	if context_id not in [
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_LIGHT,
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_HEAVY,
	]:
		super.apply_aerial_technique_motion(context_id)
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	if context_id == WeaponTechniqueCatalogScript.CONTEXT_AERIAL_LIGHT:
		body.velocity.y = maxf(body.velocity.y, -1.2)
		return
	body.velocity.y = minf(body.velocity.y, -6.8)
	plunge_landing_armed = true
	plunge_max_fall_speed = absf(minf(body.velocity.y, 0.0))


func apply_aerial_hit_followthrough(targets: Array[Node]) -> void:
	if active_technique_id != WeaponTechniqueCatalogScript.CONTEXT_AERIAL_LIGHT:
		super.apply_aerial_hit_followthrough(targets)
		return
	if targets.is_empty():
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	body.velocity.y = maxf(body.velocity.y, 0.4)
	var target_position: Vector3 = get_target_position(targets[0])
	var pursuit_direction: Vector3 = target_position - body.global_position
	pursuit_direction.y = 0.0
	if pursuit_direction.length_squared() <= 0.0001:
		return
	pursuit_direction = pursuit_direction.normalized()
	body.velocity.x = lerpf(body.velocity.x, pursuit_direction.x * 4.8, 0.62)
	body.velocity.z = lerpf(body.velocity.z, pursuit_direction.z * 4.8, 0.62)


# Payload targets are resolved only through the collider's ancestry. The old
# shared resolver also recursively searched children at every ancestor level;
# once it reached a scene root, a floor or wall could accidentally nominate an
# unrelated sibling HitReceiver elsewhere in the level.
func find_payload_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if is_payload_target(current):
			return current
		current = current.get_parent()
	return null


# Flexible rigs can record how strongly each section of the weapon contacted a
# target. Apply that target-specific weighting before the existing Safe controller
# adds class identity, body-form modifiers, reactions, and normal hit handling.
func send_payload_to_target(
	target: Node,
	payload: DamagePayload
) -> Dictionary:
	var resolved: DamagePayload = payload
	if (
		payload != null
		and runtime_weapon_rig != null
		and runtime_weapon_rig.has_method("modify_payload_for_target")
	):
		var duplicate_payload: DamagePayload = payload.duplicate(true) as DamagePayload
		if duplicate_payload != null:
			resolved = duplicate_payload
			runtime_weapon_rig.call(
				"modify_payload_for_target",
				resolved,
				target,
				current_attack
			)
	return super.send_payload_to_target(target, resolved)


func finish_current_attack() -> void:
	super.finish_current_attack()
	if current_attack == null:
		_clear_engagement()


func cancel_current_attack(reason: String = "cancelled") -> void:
	super.cancel_current_attack(reason)
	_clear_engagement()


func get_engagement_target() -> Node3D:
	return engagement_target if _engagement_is_valid() else null


func get_engagement_aim_point() -> Vector3:
	if not _engagement_is_valid():
		return Vector3.ZERO
	return engagement_aim_point


func _prepare_engagement(attack: WeaponAttackDefinition) -> void:
	_clear_engagement()
	if attack == null or equipped_weapon == null:
		return
	if not TARGET_ENGAGEMENT_CLASSES.has(equipped_weapon.weapon_class):
		return
	var actor: Node3D = get_actor()
	if actor == null:
		return
	if actor is CharacterBody3D and not (actor as CharacterBody3D).is_on_floor():
		return

	var candidate: Node3D = null
	var targeting: Node = actor.get_node_or_null("CombatTargetingAssist")
	var locked_value: Variant = actor.get("lock_on_target")
	if locked_value is Node3D and is_instance_valid(locked_value):
		candidate = locked_value as Node3D
		engagement_source = "hard_lock"
	elif targeting != null:
		var hard_value: Variant = targeting.get("hard_target")
		var soft_value: Variant = targeting.get("soft_target")
		if hard_value is Node3D and is_instance_valid(hard_value):
			candidate = hard_value as Node3D
			engagement_source = "hard_assist"
		elif soft_value is Node3D and is_instance_valid(soft_value):
			candidate = soft_value as Node3D
			engagement_source = "soft_aim"

	if candidate == null:
		var base_forward: Vector3 = super.get_attack_forward()
		candidate = find_facing_assist_target(base_forward, attack)
		if candidate != null:
			engagement_source = "facing_assist"
	if candidate == null:
		return

	var aim_point: Vector3 = _get_engagement_target_point(candidate, targeting)
	var planar_offset: Vector3 = aim_point - actor.global_position
	planar_offset.y = 0.0
	var distance: float = planar_offset.length()
	if distance <= 0.01 or distance > attack.attack_range + engagement_capture_padding:
		_clear_engagement()
		return
	var base_direction: Vector3 = super.get_attack_forward()
	if base_direction.length_squared() > 0.0001:
		var alignment_angle: float = base_direction.angle_to(planar_offset.normalized())
		if alignment_angle > deg_to_rad(engagement_max_turn_degrees):
			_clear_engagement()
			return

	engagement_target = candidate
	engagement_aim_point = aim_point
	engagement_start_distance = distance


func _get_engagement_target_point(target: Node3D, targeting: Node) -> Vector3:
	if target == null:
		return Vector3.ZERO
	if targeting != null and targeting.has_method("get_target_aim_point"):
		var value: Variant = targeting.call("get_target_aim_point", target)
		if value is Vector3:
			return value as Vector3
	if target.has_method("get_targeting_aim_point"):
		var custom: Variant = target.call("get_targeting_aim_point")
		if custom is Vector3:
			return custom as Vector3
	return target.global_position + Vector3.UP * 0.9


func _engagement_is_valid() -> bool:
	return engagement_target != null and is_instance_valid(engagement_target)


func _clear_engagement() -> void:
	engagement_target = null
	engagement_aim_point = Vector3.ZERO
	engagement_start_distance = 0.0
	engagement_assisted_step = 0.0
	engagement_source = "none"


func _uses_live_ranged_aim() -> bool:
	return (
		equipped_weapon != null
		and RANGED_AIM_CLASSES.has(equipped_weapon.weapon_class)
	)


func _get_live_ranged_forward() -> Vector3:
	var actor: Node3D = get_actor()
	if actor == null:
		return Vector3.ZERO
	var origin: Vector3 = actor.global_position + Vector3.UP * 0.42
	if actor.has_method("get_combat_aim_direction"):
		var aim_value: Variant = actor.call(
			"get_combat_aim_direction",
			origin,
			true
		)
		if aim_value is Vector3:
			var aim: Vector3 = aim_value as Vector3
			aim.y = 0.0
			if aim.length_squared() > 0.0001:
				return aim.normalized()
	if actor.has_method("has_lock_on_target") and bool(actor.call("has_lock_on_target")):
		if actor.has_method("get_lock_on_cast_direction"):
			var lock_value: Variant = actor.call("get_lock_on_cast_direction", origin)
			if lock_value is Vector3:
				var lock_direction: Vector3 = lock_value as Vector3
				lock_direction.y = 0.0
				if lock_direction.length_squared() > 0.0001:
					return lock_direction.normalized()
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		var camera_forward: Vector3 = -camera.global_transform.basis.z
		camera_forward.y = 0.0
		if camera_forward.length_squared() > 0.0001:
			return camera_forward.normalized()
	var actor_forward: Vector3 = -actor.global_transform.basis.z
	actor_forward.y = 0.0
	return actor_forward.normalized() if actor_forward.length_squared() > 0.0001 else Vector3.FORWARD


func get_combat_v2_debug_data() -> Dictionary:
	return {
		"combat_weapon_controller_v2": true,
		"live_ranged_aim": _uses_live_ranged_aim(),
		"ranged_forward": _get_live_ranged_forward() if _uses_live_ranged_aim() else Vector3.ZERO,
		"safe_ancestry_target_resolution": true,
		"per_contact_payload_hook": true,
		"explicit_dash_light_heavy": true,
		"explicit_aerial_light_heavy": true,
		"engagement_target": engagement_target.name if _engagement_is_valid() else "none",
		"engagement_source": engagement_source,
		"engagement_start_distance": snappedf(engagement_start_distance, 0.01),
		"engagement_assisted_step": snappedf(engagement_assisted_step, 0.01),
		"engagement_aim_point": engagement_aim_point,
	}
