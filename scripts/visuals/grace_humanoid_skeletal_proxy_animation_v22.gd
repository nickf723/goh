extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v21.gd"
class_name GraceHumanoidSkeletalProxyAnimationV22

# V22 preserves a fraction of the previous attack's follow-through when another
# attack begins immediately. Gameplay combo timing is untouched; this is only a
# short presentation bridge inside the next attack's startup.

@export_group("Combo Animation Continuity")
@export_range(0.0, 1.0, 0.05) var combo_handoff_strength: float = 0.72
@export_range(0.1, 0.8, 0.05) var combo_handoff_startup_fraction: float = 0.42

var combo_handoff_active: bool = false
var combo_handoff_side: float = 1.0
var combo_handoff_heavy: bool = false
var combo_handoff_weight: float = 0.0
var combo_handoff_from_id: String = "none"
var combo_handoff_to_id: String = "none"
var last_combo_handoff_sample: float = 0.0


func _on_animation_attack_started(attack: WeaponAttackDefinition) -> void:
	# V7 leaves a presentation residue when an attack finishes. If the next attack
	# begins while that residue is alive, convert it into a combo-specific handoff
	# before the normal start callback clears the residue.
	var inherited_exit_alive: bool = (
		attack_exit_remaining > 0.001
		and attack_exit_duration > 0.001
		and attack_exit_id != "none"
	)
	var inherited_side: float = attack_exit_side
	var inherited_heavy: bool = attack_exit_heavy
	var inherited_weight: float = attack_exit_weight
	var inherited_id: String = attack_exit_id

	super._on_animation_attack_started(attack)

	combo_handoff_active = inherited_exit_alive and attack != null
	combo_handoff_side = inherited_side
	combo_handoff_heavy = inherited_heavy
	combo_handoff_weight = inherited_weight
	combo_handoff_from_id = inherited_id if combo_handoff_active else "none"
	combo_handoff_to_id = attack.attack_id if combo_handoff_active and attack != null else "none"
	last_combo_handoff_sample = 0.0


func _on_animation_attack_finished(attack_id: String) -> void:
	super._on_animation_attack_finished(attack_id)
	if combo_handoff_active and attack_id == combo_handoff_to_id:
		combo_handoff_active = false


func _pose_attack(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_attack(targets)
	last_combo_handoff_sample = 0.0
	if (
		not combo_handoff_active
		or weapon_controller == null
		or weapon_controller.current_attack == null
	):
		return pelvis_offset
	var attack: WeaponAttackDefinition = weapon_controller.current_attack
	var speed: float = maxf(weapon_controller.get_attack_speed(), 0.05)
	var startup: float = maxf(attack.get_startup_duration(speed), 0.001)
	var elapsed_attack: float = maxf(weapon_controller.current_attack_elapsed, 0.0)
	if elapsed_attack >= startup:
		combo_handoff_active = false
		return pelvis_offset
	var progress: float = clampf(elapsed_attack / startup, 0.0, 1.0)
	var fraction: float = clampf(combo_handoff_startup_fraction, 0.1, 0.9)
	var residue: float = 1.0 - smoothstep(0.0, fraction, progress)
	var weight: float = (
		residue
		* combo_handoff_strength
		* clampf(combo_handoff_weight, 0.45, 1.35)
	)
	last_combo_handoff_sample = weight
	if weight <= 0.001:
		return pelvis_offset

	var side: float = combo_handoff_side
	var heavy: float = 1.0 if combo_handoff_heavy else 0.0
	# Torso continues a few degrees past the previous contact before the new windup
	# redirects it. Opposite-side follow-ups especially benefit from this elastic
	# recoil because they no longer appear to teleport through neutral.
	_add_deg(targets, "pelvis", Vector3(
		2.0 * weight + heavy * 1.5 * weight,
		side * (6.0 + heavy * 2.5) * weight,
		side * 1.5 * weight
	))
	_add_deg(targets, "spine_01", Vector3(
		1.5 * weight,
		side * (5.0 + heavy * 2.0) * weight,
		-side * 1.0 * weight
	))
	_add_deg(targets, "spine_02", Vector3(
		1.0 * weight,
		side * (7.0 + heavy * 2.5) * weight,
		-side * 1.8 * weight
	))
	_add_deg(targets, "chest", Vector3(
		0.5 * weight,
		side * (9.0 + heavy * 3.0) * weight,
		-side * 2.3 * weight
	))
	_add_deg(targets, "head", Vector3(
		-1.0 * weight,
		-side * 3.0 * weight,
		side * 0.8 * weight
	))
	_add_deg(targets, "upper_arm_r", Vector3(
		(5.0 + heavy * 3.0) * weight,
		side * 7.0 * weight,
		-side * 6.0 * weight
	))
	_add_deg(targets, "forearm_r", Vector3(
		(3.0 + heavy * 2.0) * weight,
		-side * 3.0 * weight,
		0.0
	))

	var catch_left: bool = side > 0.0
	_add_deg(targets, "thigh_l", Vector3((-5.0 if catch_left else 2.0) * weight, 0.0, 0.0))
	_add_deg(targets, "thigh_r", Vector3((-5.0 if not catch_left else 2.0) * weight, 0.0, 0.0))
	_add_deg(targets, "shin_l", Vector3((8.0 if catch_left else 2.0) * weight, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3((8.0 if not catch_left else 2.0) * weight, 0.0, 0.0))
	pelvis_offset += Vector3(
		-side * 0.01 * weight,
		-(0.014 + heavy * 0.01) * weight,
		-0.012 * weight
	)
	return pelvis_offset


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v22"] = true
	data["combo_handoff"] = true
	data["combo_handoff_active"] = combo_handoff_active
	data["combo_handoff_from"] = combo_handoff_from_id
	data["combo_handoff_to"] = combo_handoff_to_id
	data["combo_handoff_weight"] = snappedf(last_combo_handoff_sample, 0.01)
	return data
