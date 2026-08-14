extends RefCounted
class_name AxeWeaponTechniqueCatalogV2


static func configure_aerial_light(
	attack: WeaponAttackDefinition
) -> WeaponAttackDefinition:
	if attack == null:
		return null
	attack.display_name = "Breakwater Rush"
	attack.startup_time = minf(attack.startup_time, 0.1)
	attack.active_time = maxf(attack.active_time, 0.1)
	attack.recovery_time = minf(attack.recovery_time, 0.17)
	attack.damage_multiplier = maxf(attack.damage_multiplier, 1.02)
	attack.stance_multiplier = maxf(attack.stance_multiplier, 1.16)
	attack.knockback_multiplier = maxf(attack.knockback_multiplier, 0.88)
	attack.attack_range = maxf(attack.attack_range, 3.45)
	attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 148.0)
	attack.attack_center_forward_offset = maxf(
		attack.attack_center_forward_offset,
		0.92
	)
	attack.max_targets = maxi(attack.max_targets, 5)
	# Aerial propulsion is owned by the controller so ordinary attack footwork
	# cannot fight the committed forward burst.
	attack.movement_distance = 0.0
	attack.movement_duration = 0.0
	attack.footwork_profile_id = ""
	attack.hit_stop_duration = maxf(attack.hit_stop_duration, 0.055)
	_add_tag(attack, "axe_aerial_drive")
	_add_tag(attack, "axe_side_hew")
	_add_tag(attack, "axe_momentum_builder")
	_add_tag(attack, "forward_contact_plane")
	_remove_tag(attack, "plunging")
	_remove_tag(attack, "ground_slam")
	return attack


static func configure_aerial_heavy(
	attack: WeaponAttackDefinition
) -> WeaponAttackDefinition:
	if attack == null:
		return null
	attack.display_name = "Skybreaker Drop"
	attack.startup_time = minf(attack.startup_time, 0.17)
	attack.active_time = maxf(attack.active_time, 0.12)
	attack.recovery_time = minf(attack.recovery_time, 0.32)
	attack.damage_multiplier = maxf(attack.damage_multiplier, 1.82)
	attack.stance_multiplier = maxf(attack.stance_multiplier, 2.25)
	attack.knockback_multiplier = maxf(attack.knockback_multiplier, 1.42)
	attack.attack_range = maxf(attack.attack_range, 3.4)
	attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 132.0)
	attack.attack_center_forward_offset = maxf(
		attack.attack_center_forward_offset,
		0.82
	)
	attack.max_targets = maxi(attack.max_targets, 6)
	attack.movement_distance = 0.0
	attack.movement_duration = 0.0
	attack.footwork_profile_id = ""
	attack.hit_stop_duration = maxf(attack.hit_stop_duration, 0.105)
	attack.hit_stop_time_scale = minf(attack.hit_stop_time_scale, 0.03)
	_add_tag(attack, "axe_aerial_crash")
	_add_tag(attack, "axe_overhead")
	_add_tag(attack, "axe_edge_aligned")
	_add_tag(attack, "axe_exploit")
	_add_tag(attack, "opening_exploit")
	_add_tag(attack, "plunging")
	# The landing controller owns the impact volume. Keeping ground_slam off the
	# airborne attack avoids an invisible radial hit while Grace is still aloft.
	_remove_tag(attack, "ground_slam")
	return attack


static func build_counter_reversal_attack(
	timing_quality: float
) -> WeaponAttackDefinition:
	var quality: float = clampf(timing_quality, 0.0, 1.0)
	var attack: WeaponAttackDefinition = WeaponAttackDefinition.new()
	attack.attack_id = "axe_counter_reversal"
	attack.display_name = (
		"Perfect Breakwater Reversal"
		if quality >= 0.72
		else "Breakwater Reversal"
	)
	attack.input_kind = "light"
	attack.startup_time = lerpf(0.14, 0.075, quality)
	attack.active_time = 0.105
	attack.recovery_time = lerpf(0.34, 0.23, quality)
	attack.combo_timeout = 0.58
	attack.cancel_window_start_normalized = lerpf(0.78, 0.66, quality)
	attack.damage_multiplier = lerpf(1.72, 2.34, quality)
	attack.stance_multiplier = lerpf(2.05, 2.86, quality)
	attack.knockback_multiplier = lerpf(1.22, 1.58, quality)
	attack.attack_range = lerpf(3.45, 3.85, quality)
	attack.cone_angle_degrees = lerpf(142.0, 172.0, quality)
	attack.attack_center_forward_offset = lerpf(0.92, 1.08, quality)
	attack.max_targets = 6
	attack.movement_distance = lerpf(0.82, 1.24, quality)
	attack.movement_duration = lerpf(0.18, 0.145, quality)
	attack.stamina_cost = 0
	attack.allow_spell_cancel = false
	attack.allow_dodge_cancel = true
	attack.hit_stop_duration = lerpf(0.095, 0.155, quality)
	attack.hit_stop_time_scale = lerpf(0.04, 0.022, quality)
	attack.character_pose_id = "axe_focus_counter_reversal"
	attack.footwork_profile_id = "sword_cleave_left"
	attack.trail_color = Color(0.28, 0.72, 1.0, 0.9)
	attack.trail_start_scale = Vector3(0.46, 0.76, 1.0)
	attack.trail_end_scale = Vector3(1.28, 1.56, 1.0)
	attack.windup_rotation_degrees = Vector3(-10.0, -76.0, 88.0)
	attack.strike_rotation_degrees = Vector3(-9.0, 108.0, 90.0)
	attack.recovery_rotation_degrees = Vector3(-14.0, 28.0, 88.0)
	attack.windup_offset = Vector3(0.0, 0.025, -0.16)
	attack.strike_offset = Vector3(0.0, -0.055, -0.34)
	attack.recovery_offset = Vector3(0.0, -0.02, -0.08)
	for tag: String in [
		"counter",
		"axe_counter_reversal",
		"axe_side_hew",
		"axe_edge_aligned",
		"axe_exploit",
		"opening_exploit",
		"guard_break",
		"forward_contact_plane",
	]:
		_add_tag(attack, tag)
	if quality >= 0.72:
		_add_tag(attack, "axe_counter_perfect")
	return attack


static func _add_tag(
	attack: WeaponAttackDefinition,
	tag: String
) -> void:
	if attack != null and tag != "" and not attack.extra_tags.has(tag):
		attack.extra_tags.append(tag)


static func _remove_tag(
	attack: WeaponAttackDefinition,
	tag: String
) -> void:
	if attack != null and attack.extra_tags.has(tag):
		attack.extra_tags.erase(tag)
