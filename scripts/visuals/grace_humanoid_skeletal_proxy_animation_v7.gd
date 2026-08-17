extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v6.gd"
class_name GraceHumanoidSkeletalProxyAnimationV7

# V7 bridges authored weapon animation back into locomotion. Gameplay recovery
# still ends exactly when the weapon controller says it does; this is only a
# rapidly decaying presentation residue so hips and shoulders do not snap to a
# mathematically unrelated gait pose on the next frame.

@export_group("Attack Exit Continuity")
@export_range(0.04, 0.3, 0.01) var light_exit_seconds: float = 0.11
@export_range(0.05, 0.4, 0.01) var heavy_exit_seconds: float = 0.18
@export_range(0.0, 1.5, 0.05) var attack_exit_strength: float = 0.78

var attack_exit_remaining: float = 0.0
var attack_exit_duration: float = 0.0
var attack_exit_side: float = 1.0
var attack_exit_heavy: bool = false
var attack_exit_weight: float = 0.0
var attack_exit_id: String = "none"
var tracked_attack: WeaponAttackDefinition


func _ready() -> void:
	super._ready()
	if weapon_controller == null:
		return
	if weapon_controller.has_signal("attack_started"):
		var started := Callable(self, "_on_animation_attack_started")
		if not weapon_controller.is_connected("attack_started", started):
			weapon_controller.connect("attack_started", started)
	if weapon_controller.has_signal("attack_finished"):
		var finished := Callable(self, "_on_animation_attack_finished")
		if not weapon_controller.is_connected("attack_finished", finished):
			weapon_controller.connect("attack_finished", finished)


func _exit_tree() -> void:
	if weapon_controller != null:
		var started := Callable(self, "_on_animation_attack_started")
		var finished := Callable(self, "_on_animation_attack_finished")
		if weapon_controller.is_connected("attack_started", started):
			weapon_controller.disconnect("attack_started", started)
		if weapon_controller.is_connected("attack_finished", finished):
			weapon_controller.disconnect("attack_finished", finished)


func _process(delta: float) -> void:
	attack_exit_remaining = maxf(attack_exit_remaining - maxf(delta, 0.0), 0.0)
	super._process(delta)


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	pelvis_offset += _apply_attack_exit_residue(targets, false)
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	pelvis_offset += _apply_attack_exit_residue(targets, true)
	return pelvis_offset


func _on_animation_attack_started(attack: WeaponAttackDefinition) -> void:
	tracked_attack = attack
	attack_exit_remaining = 0.0
	attack_exit_duration = 0.0
	attack_exit_weight = 0.0
	if attack != null:
		attack_exit_id = attack.attack_id


func _on_animation_attack_finished(_attack_id: String) -> void:
	if tracked_attack == null:
		return
	attack_exit_heavy = tracked_attack.input_kind == "heavy"
	attack_exit_side = _attack_side(tracked_attack)
	attack_exit_duration = heavy_exit_seconds if attack_exit_heavy else light_exit_seconds
	attack_exit_remaining = attack_exit_duration
	attack_exit_weight = clampf(
		tracked_attack.damage_multiplier * (1.0 if attack_exit_heavy else 0.72),
		0.45,
		1.35
	)
	attack_exit_id = tracked_attack.attack_id
	tracked_attack = null


func _apply_attack_exit_residue(
	targets: Dictionary,
	moving: bool
) -> Vector3:
	if attack_exit_remaining <= 0.001 or attack_exit_duration <= 0.001:
		return Vector3.ZERO
	var age: float = 1.0 - attack_exit_remaining / attack_exit_duration
	var decay: float = 1.0 - smoothstep(0.0, 1.0, clampf(age, 0.0, 1.0))
	var weight: float = decay * attack_exit_weight * attack_exit_strength
	if moving:
		# Running absorbs the residual more quickly, but the first step still starts
		# from the side Grace just finished swinging through.
		weight *= 0.72
	var side: float = attack_exit_side
	var heavy: float = 1.0 if attack_exit_heavy else 0.0

	_add_deg(targets, "pelvis", Vector3(
		2.0 * weight + heavy * 2.0 * weight,
		side * (6.0 + heavy * 3.0) * weight,
		side * 2.0 * weight
	))
	_add_deg(targets, "spine_01", Vector3(
		2.0 * weight + heavy * 1.5 * weight,
		side * (5.0 + heavy * 2.5) * weight,
		-side * 1.5 * weight
	))
	_add_deg(targets, "spine_02", Vector3(
		1.5 * weight,
		side * (7.0 + heavy * 3.0) * weight,
		-side * 2.0 * weight
	))
	_add_deg(targets, "chest", Vector3(
		1.0 * weight,
		side * (10.0 + heavy * 4.0) * weight,
		-side * 2.5 * weight
	))
	_add_deg(targets, "head", Vector3(
		-1.0 * weight,
		-side * 3.0 * weight,
		side * 0.8 * weight
	))

	# Weapon arm finishes a fraction later than the torso, while the free hand is
	# already returning to balance. This is intentionally small after authored recovery.
	_add_deg(targets, "upper_arm_r", Vector3(
		(5.0 + heavy * 4.0) * weight,
		side * 5.0 * weight,
		-side * 5.0 * weight
	))
	_add_deg(targets, "forearm_r", Vector3(
		(3.0 + heavy * 3.0) * weight,
		-side * 2.0 * weight,
		0.0
	))
	_add_deg(targets, "upper_arm_l", Vector3(
		-2.0 * weight,
		-side * 2.0 * weight,
		side * 2.5 * weight
	))

	var catch_left: bool = side > 0.0
	_add_deg(targets, "thigh_l", Vector3((-5.0 if catch_left else -1.5) * weight, 0.0, 0.0))
	_add_deg(targets, "thigh_r", Vector3((-5.0 if not catch_left else -1.5) * weight, 0.0, 0.0))
	_add_deg(targets, "shin_l", Vector3((8.0 if catch_left else 3.0) * weight, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3((8.0 if not catch_left else 3.0) * weight, 0.0, 0.0))

	return Vector3(
		-side * 0.012 * weight,
		-(0.018 + heavy * 0.016) * weight,
		-(0.012 + heavy * 0.012) * weight
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v7"] = true
	data["attack_exit_continuity"] = true
	data["attack_exit_id"] = attack_exit_id
	data["attack_exit_remaining"] = snappedf(attack_exit_remaining, 0.001)
	data["attack_exit_heavy"] = attack_exit_heavy
	data["attack_exit_side"] = attack_exit_side
	return data
