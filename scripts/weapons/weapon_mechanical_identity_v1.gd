extends RefCounted
class_name WeaponMechanicalIdentityV1


static func configure_attack(
	attack: WeaponAttackDefinition,
	weapon_class: String
) -> WeaponAttackDefinition:
	if attack == null:
		return attack
	match weapon_class:
		"chains": _configure_chains(attack)
		"boomerang": _configure_boomerang(attack)
		"gauntlets": _configure_gauntlets(attack)
	return attack


static func _configure_chains(attack: WeaponAttackDefinition) -> void:
	var aerial: bool = attack.extra_tags.has("aerial_light") or attack.extra_tags.has("aerial_heavy")
	var heavy: bool = attack.input_kind == "heavy"
	_add_tag(attack, "colossal_chain")
	if not aerial:
		_add_tag(attack, "chain_ground_drag")
	if attack.extra_tags.has("ground_slam"):
		_add_tag(attack, "chain_ground_blast")
	else:
		_add_tag(attack, "chain_area_sweep")
	if heavy:
		attack.startup_time *= 1.38
		attack.active_time = maxf(attack.active_time, 0.17)
		attack.recovery_time *= 1.18
		attack.damage_multiplier *= 1.32
		attack.stance_multiplier *= 1.28
		attack.knockback_multiplier *= 1.16
		attack.attack_range += 0.72
		attack.cone_angle_degrees = 360.0 if attack.extra_tags.has("ground_slam") else maxf(attack.cone_angle_degrees, 330.0)
		attack.max_targets += 5
		attack.movement_distance = minf(attack.movement_distance, 0.09)
		attack.hit_stop_duration = maxf(attack.hit_stop_duration, 0.145)
		attack.hit_stop_time_scale = minf(attack.hit_stop_time_scale, 0.03)
	else:
		attack.startup_time *= 1.22
		attack.active_time = maxf(attack.active_time, 0.12)
		attack.recovery_time *= 1.1
		attack.damage_multiplier *= 1.16
		attack.stance_multiplier *= 1.18
		attack.knockback_multiplier *= 1.08
		attack.attack_range += 0.42
		attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 265.0)
		attack.max_targets += 3
		attack.movement_distance = minf(attack.movement_distance, 0.1)
		attack.hit_stop_duration = maxf(attack.hit_stop_duration, 0.075)
	match attack.attack_id:
		"chain_l1": attack.display_name = "Dragging Orbit"
		"chain_l2": attack.display_name = "Iron Reversal"
		"chain_l3": attack.display_name = "Rising Anchor"
		"chain_h0": attack.display_name = "Anchor Crash"
		"chain_h1": attack.display_name = "Wrecking Orbit"
		"chain_h2": attack.display_name = "Wrecking Reversal"
		"chain_h3": attack.display_name = "Cathedral Meteor"


static func _configure_boomerang(attack: WeaponAttackDefinition) -> void:
	var heavy: bool = attack.input_kind == "heavy"
	var index: int = _proxy_index(attack.attack_id)
	if not heavy:
		_remove_tag(attack, "ranged")
		_remove_tag(attack, "returning")
		_remove_tag(attack, "air_glide")
		_add_tag(attack, "melee")
		_add_tag(attack, "boomerang_melee")
		_add_tag(attack, "forward_contact_plane")
		attack.attack_range = minf(attack.attack_range, 2.45)
		attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 112.0)
		attack.attack_center_forward_offset = minf(attack.attack_center_forward_offset, 0.92)
		attack.max_targets = maxi(attack.max_targets, 3)
		attack.movement_distance = maxf(attack.movement_distance, 0.28)
		attack.recovery_time = maxf(attack.recovery_time * 0.88, 0.09)
		if attack.extra_tags.has("aerial_light"):
			attack.display_name = "Sky Backhand"
		elif attack.extra_tags.has("dash_light"):
			attack.display_name = "Running Rim"
		else:
			match index:
				1: attack.display_name = "Palm Cut"
				2: attack.display_name = "Backhand Cut"
				3: attack.display_name = "Rising Rim"
		return
	_add_tag(attack, "ranged")
	_add_tag(attack, "returning")
	_add_tag(attack, "boomerang_throw")
	attack.movement_distance = 0.0
	attack.attack_center_forward_offset = maxf(attack.attack_center_forward_offset, 2.4)
	if index < 0:
		_add_tag(attack, "boomerang_straight_throw")
		attack.attack_range = maxf(attack.attack_range, 6.2)
		return
	match index:
		0:
			attack.display_name = "Straight Return"
			attack.attack_range = maxf(attack.attack_range, 7.0)
			attack.cone_angle_degrees = 16.0
			attack.max_targets = maxi(attack.max_targets, 2)
			attack.damage_multiplier = maxf(attack.damage_multiplier, 1.95)
			_add_tag(attack, "boomerang_straight_throw")
		1:
			attack.display_name = "Hook Return"
			attack.attack_range = maxf(attack.attack_range, 6.5)
			attack.max_targets = maxi(attack.max_targets, 4)
			attack.damage_multiplier = maxf(attack.damage_multiplier, 1.82)
			_add_tag(attack, "boomerang_hook_throw")
		2:
			attack.display_name = "Crosswind Arc"
			attack.attack_range = maxf(attack.attack_range, 7.0)
			attack.max_targets = maxi(attack.max_targets, 5)
			attack.damage_multiplier = maxf(attack.damage_multiplier, 1.76)
			_add_tag(attack, "boomerang_s_curve_throw")
		3:
			attack.display_name = "Orbit Finish"
			attack.attack_range = maxf(attack.attack_range, 4.5)
			attack.cone_angle_degrees = 360.0
			attack.attack_center_forward_offset = 0.0
			attack.max_targets = maxi(attack.max_targets, 9)
			attack.damage_multiplier = maxf(attack.damage_multiplier, 1.68)
			attack.stance_multiplier *= 1.18
			_add_tag(attack, "boomerang_orbit_throw")


static func _configure_gauntlets(attack: WeaponAttackDefinition) -> void:
	if attack.extra_tags.has("dash_light"):
		attack.display_name = "Gazelle Jab"
		attack.startup_time = minf(attack.startup_time, 0.085)
		attack.recovery_time = minf(attack.recovery_time, 0.14)
		attack.damage_multiplier = maxf(attack.damage_multiplier, 1.05)
		attack.cone_angle_degrees = 46.0
		attack.movement_distance = maxf(attack.movement_distance, 1.42)
		_add_tag(attack, "boxing_jab")
		return
	if attack.extra_tags.has("dash_heavy"):
		attack.display_name = "Superman Cross"
		_remove_tag(attack, "launcher")
		attack.damage_multiplier = maxf(attack.damage_multiplier, 1.85)
		attack.stance_multiplier = maxf(attack.stance_multiplier, 2.2)
		attack.cone_angle_degrees = 54.0
		attack.movement_distance = maxf(attack.movement_distance, 1.7)
		_add_tag(attack, "boxing_overhand")
		_add_tag(attack, "forward_contact_plane")
		return
	if not attack.attack_id.contains("_proxy_"):
		return
	var index: int = _proxy_index(attack.attack_id)
	if attack.input_kind == "light":
		_remove_tag(attack, "multi_hit_2")
		_remove_tag(attack, "multi_hit_3")
		attack.combo_timeout = 0.5
		match index:
			1: _set_jab(attack)
			2: _set_cross(attack)
			3: _set_hook(attack)
		return
	match index:
		0: _set_uppercut(attack, false)
		1: _set_overhand(attack)
		2: _set_body_hook(attack)
		3: _set_uppercut(attack, true)


static func _set_jab(a: WeaponAttackDefinition) -> void:
	a.display_name = "Lead Jab"; a.startup_time = 0.065; a.active_time = 0.055; a.recovery_time = 0.085
	a.damage_multiplier = 0.9; a.stance_multiplier = 0.72; a.knockback_multiplier = 0.42
	a.attack_range = 1.82; a.cone_angle_degrees = 42.0; a.max_targets = 1; a.movement_distance = 0.3
	a.hit_stop_duration = 0.035; _add_tag(a, "boxing_jab")


static func _set_cross(a: WeaponAttackDefinition) -> void:
	a.display_name = "Rear Cross"; a.startup_time = 0.095; a.active_time = 0.065; a.recovery_time = 0.115
	a.damage_multiplier = 1.24; a.stance_multiplier = 1.05; a.knockback_multiplier = 0.78
	a.attack_range = 2.0; a.cone_angle_degrees = 48.0; a.max_targets = 1; a.movement_distance = 0.5
	a.hit_stop_duration = 0.05; _add_tag(a, "boxing_cross")


static func _set_hook(a: WeaponAttackDefinition) -> void:
	a.display_name = "Lead Hook"; a.startup_time = 0.125; a.active_time = 0.075; a.recovery_time = 0.16
	a.damage_multiplier = 1.44; a.stance_multiplier = 1.32; a.knockback_multiplier = 0.92
	a.attack_range = 1.9; a.cone_angle_degrees = 108.0; a.max_targets = 2; a.movement_distance = 0.22
	a.hit_stop_duration = 0.065; _add_tag(a, "boxing_hook")


static func _set_uppercut(a: WeaponAttackDefinition, finisher: bool) -> void:
	a.display_name = "Champion Uppercut" if finisher else "Rear Uppercut"
	a.startup_time = 0.25 if finisher else 0.18; a.active_time = 0.105 if finisher else 0.085
	a.recovery_time = 0.38 if finisher else 0.26; a.damage_multiplier = 2.38 if finisher else 1.82
	a.stance_multiplier = 2.8 if finisher else 2.05; a.knockback_multiplier = 1.3 if finisher else 1.05
	a.knockback_up_add = maxf(a.knockback_up_add, 5.2 if finisher else 4.0)
	a.attack_range = 2.08 if finisher else 1.95; a.cone_angle_degrees = 68.0 if finisher else 54.0
	a.max_targets = 3 if finisher else 2; a.movement_distance = 0.72 if finisher else 0.42
	_add_tag(a, "launcher"); _add_tag(a, "boxing_uppercut")
	if finisher: _add_tag(a, "boxing_finisher")


static func _set_overhand(a: WeaponAttackDefinition) -> void:
	a.display_name = "Overhand Right"; _remove_tag(a, "launcher"); a.knockback_up_add = 0.0
	a.startup_time = 0.21; a.active_time = 0.085; a.recovery_time = 0.29; a.damage_multiplier = 1.78
	a.stance_multiplier = 2.35; a.knockback_multiplier = 1.42; a.attack_range = 2.12
	a.cone_angle_degrees = 58.0; a.max_targets = 2; a.movement_distance = 0.62
	_add_tag(a, "boxing_overhand"); _add_tag(a, "forward_contact_plane")


static func _set_body_hook(a: WeaponAttackDefinition) -> void:
	a.display_name = "Liver Hook"; _remove_tag(a, "launcher"); a.knockback_up_add = 0.0
	a.startup_time = 0.18; a.active_time = 0.09; a.recovery_time = 0.24; a.damage_multiplier = 1.58
	a.stance_multiplier = 3.05; a.knockback_multiplier = 0.68; a.attack_range = 1.82
	a.cone_angle_degrees = 104.0; a.max_targets = 2; a.movement_distance = 0.16
	_add_tag(a, "boxing_body_hook"); _add_tag(a, "forward_contact_plane")


static func _proxy_index(attack_id: String) -> int:
	if not attack_id.contains("_proxy_"): return -1
	var token: String = attack_id.split("_")[-1]
	return int(token.substr(1)) if token.length() >= 2 else -1


static func _add_tag(attack: WeaponAttackDefinition, tag: String) -> void:
	if tag != "" and not attack.extra_tags.has(tag): attack.extra_tags.append(tag)


static func _remove_tag(attack: WeaponAttackDefinition, tag: String) -> void:
	if attack.extra_tags.has(tag): attack.extra_tags.erase(tag)
