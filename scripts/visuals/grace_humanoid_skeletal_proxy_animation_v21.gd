extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v20.gd"
class_name GraceHumanoidSkeletalProxyAnimationV21

# V21 adds a quiet exertion memory. It never changes stamina or movement; it only
# lets recently strenuous actions remain visible for a few seconds through breath,
# shoulder lift, and a tiny center-of-mass shift.

@export_group("Exertion Presentation")
@export_range(0.1, 8.0, 0.1) var exertion_rise_response: float = 2.8
@export_range(0.05, 5.0, 0.05) var exertion_recovery_response: float = 0.72
@export_range(0.0, 8.0, 0.25) var maximum_exertion_chest_degrees: float = 3.5
@export_range(0.0, 8.0, 0.25) var maximum_exertion_shoulder_degrees: float = 2.5
@export_range(0.0, 0.05, 0.002) var maximum_exertion_bob: float = 0.012

var exertion: float = 0.0
var exertion_target: float = 0.0
var last_stamina_ratio: float = 1.0
var exertion_breath_phase: float = 0.0


func _process(delta: float) -> void:
	_update_exertion(maxf(delta, 0.0))
	super._process(delta)


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	pelvis_offset += _apply_exertion_overlay(targets, 1.0)
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	pelvis_offset += _apply_exertion_overlay(targets, 0.48)
	return pelvis_offset


func _update_exertion(delta: float) -> void:
	if delta <= 0.0:
		return
	var maximum_stamina: float = maxf(float(GameState.get_stat("max_stamina")), 1.0)
	var current_stamina: float = clampf(float(GameState.get_stat("stamina")), 0.0, maximum_stamina)
	last_stamina_ratio = clampf(current_stamina / maximum_stamina, 0.0, 1.0)
	var stamina_exertion: float = 1.0 - last_stamina_ratio
	var action_exertion: float = 0.0
	if actor != null:
		var speed_ratio: float = clampf(
			Vector2(actor.velocity.x, actor.velocity.z).length()
			/ maxf(locomotion_speed_reference, 0.1),
			0.0,
			1.0
		)
		action_exertion = maxf(action_exertion, speed_ratio * 0.34)
	if dodge_controller != null and dodge_controller.is_dodge_active():
		action_exertion = maxf(action_exertion, 0.62)
	if weapon_controller != null and weapon_controller.current_attack != null:
		var attack: WeaponAttackDefinition = weapon_controller.current_attack
		var attack_weight: float = clampf(
			attack.damage_multiplier / 2.2,
			0.22,
			0.82
		)
		if attack.input_kind == "heavy":
			attack_weight = maxf(attack_weight, 0.55)
		action_exertion = maxf(action_exertion, attack_weight)
	if action_state != null and action_state.is_staggered:
		action_exertion = maxf(action_exertion, 0.72)

	exertion_target = clampf(maxf(stamina_exertion, action_exertion), 0.0, 1.0)
	var response: float = (
		exertion_rise_response
		if exertion_target > exertion
		else exertion_recovery_response
	)
	var blend: float = 1.0 - exp(-maxf(response, 0.01) * delta)
	exertion = lerpf(exertion, exertion_target, blend)
	exertion_breath_phase = fposmod(
		exertion_breath_phase
		+ delta * lerpf(2.05, 3.75, exertion),
		TAU
	)


func _apply_exertion_overlay(
	targets: Dictionary,
	state_scale: float
) -> Vector3:
	if exertion <= 0.04:
		return Vector3.ZERO
	if animation_state in ["attack", "dodge", "hit", "climb", "mantle", "swim_surface", "swim_underwater"]:
		return Vector3.ZERO
	var weight: float = smoothstep(0.04, 1.0, exertion) * clampf(state_scale, 0.0, 1.0)
	var breath: float = sin(exertion_breath_phase)
	var inhale: float = clampf(breath, 0.0, 1.0)
	var exhale: float = clampf(-breath, 0.0, 1.0)
	var chest_motion: float = maximum_exertion_chest_degrees * weight
	var shoulder_motion: float = maximum_exertion_shoulder_degrees * weight

	_add_deg(targets, "pelvis", Vector3(exhale * 0.7 * weight, 0.0, 0.0))
	_add_deg(targets, "spine_01", Vector3((-inhale * 0.6 + exhale * 0.45) * chest_motion, 0.0, 0.0))
	_add_deg(targets, "spine_02", Vector3(-inhale * 0.72 * chest_motion + exhale * 0.35 * chest_motion, 0.0, 0.0))
	_add_deg(targets, "chest", Vector3(-inhale * chest_motion + exhale * 0.28 * chest_motion, 0.0, 0.0))
	_add_deg(targets, "neck", Vector3(inhale * 0.35 * chest_motion, 0.0, 0.0))
	_add_deg(targets, "head", Vector3(inhale * 0.22 * chest_motion - exhale * 0.28 * chest_motion, 0.0, 0.0))
	_add_deg(targets, "clavicle_l", Vector3(-inhale * shoulder_motion, 0.0, -inhale * shoulder_motion * 0.35))
	_add_deg(targets, "clavicle_r", Vector3(-inhale * shoulder_motion, 0.0, inhale * shoulder_motion * 0.35))
	return Vector3(
		0.0,
		-inhale * maximum_exertion_bob * weight,
		exhale * 0.004 * weight
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v21"] = true
	data["exertion_presentation"] = true
	data["exertion"] = snappedf(exertion, 0.01)
	data["exertion_target"] = snappedf(exertion_target, 0.01)
	data["stamina_ratio"] = snappedf(last_stamina_ratio, 0.01)
	return data
