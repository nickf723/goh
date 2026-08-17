extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v5.gd"
class_name GraceHumanoidSkeletalProxyAnimationV6

# V6 lets equipped mass influence ordinary movement. Attack poses remain entirely
# authored by the weapon-language stack; only idle/locomotion carries are adjusted.

@export_group("Weapon Carry Animation")
@export_range(0.0, 1.0, 0.05) var staff_carry_strength: float = 0.82
@export_range(0.0, 1.0, 0.05) var axe_carry_strength: float = 0.9


func _pose_idle(targets: Dictionary) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	_apply_weapon_idle_carry(targets)
	return pelvis_offset


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	_apply_weapon_locomotion_carry(targets)
	return pelvis_offset


func _apply_weapon_idle_carry(targets: Dictionary) -> void:
	var weapon_class: String = _get_equipped_weapon_class()
	match weapon_class:
		"staff":
			var w: float = staff_carry_strength
			# Low diagonal one-hand carry. The right shoulder stays relaxed and the
			# wrist keeps the shaft below chest height instead of skyward.
			_set_deg(targets, "clavicle_r", Vector3(0.0, -3.0 * w, 3.0 * w))
			_set_deg(targets, "upper_arm_r", Vector3(10.0 * w, -7.0 * w, 11.0 * w))
			_set_deg(targets, "forearm_r", Vector3(-31.0 * w, 4.0 * w, -2.0 * w))
			_set_deg(targets, "hand_r", Vector3(-4.0 * w, -3.0 * w, 12.0 * w))
			_add_deg(targets, "chest", Vector3(0.0, -2.5 * w, 0.0))
			# Left hand remains alive and available rather than permanently clamping
			# the staff outside combat.
			_set_deg(targets, "upper_arm_l", Vector3(-5.0, 1.0, -6.0))
			_set_deg(targets, "forearm_l", Vector3(-12.0, 0.0, 0.0))
		"axe":
			var w: float = axe_carry_strength
			# Let the axe hang low at Grace's right side. The right shoulder drops and
			# the torso counterbalances the weapon instead of pretending both arms are free.
			_set_deg(targets, "clavicle_r", Vector3(2.0 * w, -4.0 * w, 5.0 * w))
			_set_deg(targets, "upper_arm_r", Vector3(16.0 * w, -8.0 * w, 14.0 * w))
			_set_deg(targets, "forearm_r", Vector3(-25.0 * w, 2.0 * w, -2.0 * w))
			_set_deg(targets, "hand_r", Vector3(-3.0 * w, 0.0, 19.0 * w))
			_add_deg(targets, "pelvis", Vector3(0.0, 1.6 * w, -1.5 * w))
			_add_deg(targets, "spine_01", Vector3(0.0, -1.0 * w, 1.8 * w))
			_add_deg(targets, "chest", Vector3(0.0, -1.8 * w, 2.2 * w))
		_:
			pass


func _apply_weapon_locomotion_carry(targets: Dictionary) -> void:
	if actor == null:
		return
	var speed_weight: float = clampf(
		Vector2(actor.velocity.x, actor.velocity.z).length()
		/ maxf(locomotion_speed_reference, 0.1),
		0.0,
		1.0
	)
	var weapon_class: String = _get_equipped_weapon_class()
	match weapon_class:
		"staff":
			var w: float = staff_carry_strength
			var pulse: float = sin(stride_phase) * speed_weight
			# Right arm stabilizes the shaft. Most running counter-swing moves to the
			# free left arm and torso, preserving athletic cadence without whipping the staff.
			_set_deg(targets, "clavicle_r", Vector3(0.0, -4.0 * w, 3.0 * w))
			_set_deg(targets, "upper_arm_r", Vector3(
				13.0 * w - pulse * 3.0,
				-8.0 * w,
				11.0 * w
			))
			_set_deg(targets, "forearm_r", Vector3(-28.0 * w - absf(pulse) * 3.0, 4.0 * w, 0.0))
			_set_deg(targets, "hand_r", Vector3(-4.0 * w, -3.0 * w, 11.0 * w))
			_add_deg(targets, "upper_arm_l", Vector3(-pulse * 5.5 * w, 0.0, 0.0))
			_add_deg(targets, "chest", Vector3(0.0, -2.0 * w, -pulse * 1.5 * w))
		"axe":
			var w: float = axe_carry_strength
			var pulse: float = sin(stride_phase) * speed_weight
			# The weapon arm behaves almost like suspended cargo; hips and the free arm
			# compensate. A small delayed swing sells mass without making the axe floppy.
			_set_deg(targets, "clavicle_r", Vector3(2.0 * w, -4.5 * w, 5.5 * w))
			_set_deg(targets, "upper_arm_r", Vector3(
				18.0 * w - pulse * 4.0,
				-9.0 * w,
				15.0 * w
			))
			_set_deg(targets, "forearm_r", Vector3(-23.0 * w - absf(pulse) * 4.0, 2.0 * w, 0.0))
			_set_deg(targets, "hand_r", Vector3(-3.0 * w, 0.0, 20.0 * w))
			_add_deg(targets, "upper_arm_l", Vector3(-pulse * 8.0 * w, 0.0, -pulse * 1.5 * w))
			_add_deg(targets, "pelvis", Vector3(0.0, pulse * 1.5 * w, -2.0 * w))
			_add_deg(targets, "spine_01", Vector3(0.0, -pulse * 1.2 * w, 2.0 * w))
			_add_deg(targets, "chest", Vector3(0.0, -pulse * 2.0 * w, 2.8 * w))
		_:
			pass


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v6"] = true
	data["weapon_aware_locomotion"] = true
	data["locomotion_weapon_class"] = _get_equipped_weapon_class()
	return data
