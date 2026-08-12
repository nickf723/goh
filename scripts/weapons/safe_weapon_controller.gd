extends "res://scripts/weapons/weapon_controller.gd"
class_name SafeWeaponController

const GameplayEffectAccessBodyFormScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)
const WeaponClassMotionCatalogScript = preload(
	"res://scripts/weapons/weapon_class_motion_catalog.gd"
)

@export_group("Camera-Decoupled Attack Facing")
@export_range(0.0, 1.0, 0.05) var visual_facing_blend: float = 0.78
@export_range(0.01, 0.5, 0.01) var visual_facing_return_seconds: float = 0.14

var _gesture_attack_stamina_spent: int = 0
var _attack_facing_tween: Tween


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
	return super.send_payload_to_target(target, resolved)


func start_attack(attack: WeaponAttackDefinition) -> bool:
	_kill_attack_facing_tween()
	var resolved_attack: WeaponAttackDefinition = attack
	if equipped_weapon != null:
		resolved_attack = WeaponClassMotionCatalogScript.prepare_attack(
			attack,
			equipped_weapon.weapon_class
		)
	var stamina_before: int = GameState.get_stat("stamina")
	var started: bool = super.start_attack(resolved_attack)
	_gesture_attack_stamina_spent = (
		maxi(stamina_before - GameState.get_stat("stamina"), 0)
		if started
		else 0
	)
	return started


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
