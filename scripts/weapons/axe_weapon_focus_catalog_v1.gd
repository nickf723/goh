extends RefCounted
class_name AxeWeaponFocusCatalogV1

const AxeRigScene: PackedScene = preload(
	"res://scenes/weapons/axe_weapon_rig.tscn"
)


static func build_weapon() -> WeaponDefinition:
	var weapon: WeaponDefinition = WeaponDefinition.new()
	weapon.weapon_class = "axe"
	return apply_to_weapon(weapon)


static func apply_to_weapon(weapon: WeaponDefinition) -> WeaponDefinition:
	if weapon == null or weapon.weapon_class != "axe":
		return weapon
	weapon.display_name = "Training Breakwater Axe"
	weapon.description = (
		"A blue-steel bearded axe built around power, carried momentum, and "
		+ "creating brief openings before a committed finishing cut."
	)
	weapon.damage = 3
	weapon.stance_damage = 3
	weapon.range = 3.25
	weapon.attack_speed = 0.94
	weapon.cooldown = 0.4
	weapon.cone_angle_degrees = 150.0
	weapon.max_targets = 6
	weapon.stamina_cost = 0
	weapon.critical_multiplier = 2.15
	weapon.visual_primary_color = Color(0.1, 0.32, 0.9, 1.0)
	weapon.visual_secondary_color = Color(0.025, 0.06, 0.16, 1.0)
	weapon.visual_accent_color = Color(0.28, 0.72, 1.0, 1.0)
	weapon.visual_scale = 1.0
	weapon.runtime_rig_scene = AxeRigScene
	weapon.moveset = build_moveset()
	weapon.scaling_stats = ["power", "skill"]
	weapon.scaling_note = (
		"Power determines the force of the committed cut; Skill preserves momentum "
		+ "and turns stagger into a clean opening."
	)
	weapon.set_meta("axe_focus_v1", true)
	weapon.set_meta("combat_sandbox_authored", true)
	weapon.set_meta("combat_sandbox_proxy", false)
	return weapon


static func build_moveset() -> WeaponMovesetDefinition:
	var moveset: WeaponMovesetDefinition = WeaponMovesetDefinition.new()
	moveset.moveset_id = "axe_focus_v1"
	moveset.display_name = "Breakwater Axe Forms"
	moveset.entry_light_attack_id = "axe_l1"
	moveset.entry_heavy_attack_id = "axe_h0"

	var l1: WeaponAttackDefinition = _new_attack(
		"axe_l1",
		"Driving Hew",
		"light"
	)
	l1.startup_time = 0.14
	l1.active_time = 0.09
	l1.recovery_time = 0.18
	l1.combo_timeout = 0.7
	l1.damage_multiplier = 0.94
	l1.stance_multiplier = 1.0
	l1.knockback_multiplier = 0.78
	l1.attack_range = 3.12
	l1.cone_angle_degrees = 126.0
	l1.attack_center_forward_offset = 0.88
	l1.max_targets = 4
	l1.movement_distance = 0.38
	l1.movement_duration = 0.13
	l1.next_light_attack_id = "axe_l2"
	l1.next_heavy_attack_id = "axe_h1"
	l1.footwork_profile_id = "sword_cut_right"
	_set_tags(l1, [
		"slash", "cleave", "axe", "axe_side_hew",
		"axe_momentum_builder", "forward_contact_plane",
	])
	_set_presentation(
		l1,
		Vector3(-8.0, -66.0, 4.0),
		Vector3(-7.0, 74.0, -5.0),
		Vector3(-10.0, 14.0, 0.0)
	)

	var l2: WeaponAttackDefinition = _new_attack(
		"axe_l2",
		"Rebound Hew",
		"light"
	)
	l2.startup_time = 0.13
	l2.active_time = 0.095
	l2.recovery_time = 0.19
	l2.combo_timeout = 0.72
	l2.damage_multiplier = 1.02
	l2.stance_multiplier = 1.08
	l2.knockback_multiplier = 0.84
	l2.attack_range = 3.2
	l2.cone_angle_degrees = 138.0
	l2.attack_center_forward_offset = 0.86
	l2.max_targets = 5
	l2.movement_distance = 0.48
	l2.movement_duration = 0.14
	l2.next_light_attack_id = "axe_l3"
	l2.next_heavy_attack_id = "axe_h2"
	l2.footwork_profile_id = "sword_cut_left"
	_set_tags(l2, [
		"slash", "cleave", "axe", "axe_side_hew", "reverse",
		"axe_momentum_builder", "forward_contact_plane",
	])
	_set_presentation(
		l2,
		Vector3(-7.0, 78.0, -5.0),
		Vector3(-9.0, -82.0, 6.0),
		Vector3(-10.0, -18.0, 0.0)
	)

	var l3: WeaponAttackDefinition = _new_attack(
		"axe_l3",
		"Shoulder Wedge",
		"light"
	)
	l3.startup_time = 0.18
	l3.active_time = 0.105
	l3.recovery_time = 0.24
	l3.combo_timeout = 0.76
	l3.damage_multiplier = 1.16
	l3.stance_multiplier = 1.42
	l3.knockback_multiplier = 0.92
	l3.attack_range = 3.34
	l3.cone_angle_degrees = 172.0
	l3.attack_center_forward_offset = 0.82
	l3.max_targets = 6
	l3.movement_distance = 0.56
	l3.movement_duration = 0.16
	l3.next_heavy_attack_id = "axe_h3"
	l3.footwork_profile_id = "sword_cleave_right"
	_set_tags(l3, [
		"slash", "cleave", "axe", "axe_broad_hew",
		"axe_momentum_builder", "axe_opener", "opening_pressure",
		"forward_contact_plane",
	])
	_set_presentation(
		l3,
		Vector3(-10.0, -96.0, 7.0),
		Vector3(-9.0, 104.0, -8.0),
		Vector3(-12.0, 24.0, 0.0)
	)

	var h0: WeaponAttackDefinition = _new_attack(
		"axe_h0",
		"Guard Splitter",
		"heavy"
	)
	h0.startup_time = 0.32
	h0.active_time = 0.11
	h0.recovery_time = 0.36
	h0.combo_timeout = 0.52
	h0.cancel_window_start_normalized = 0.78
	h0.damage_multiplier = 1.72
	h0.stance_multiplier = 2.32
	h0.knockback_multiplier = 1.34
	h0.attack_range = 3.22
	h0.cone_angle_degrees = 88.0
	h0.attack_center_forward_offset = 1.04
	h0.max_targets = 5
	h0.movement_distance = 0.42
	h0.movement_duration = 0.18
	h0.next_light_attack_id = "axe_l1"
	h0.footwork_profile_id = "sword_overhead"
	_set_tags(h0, [
		"force", "slash", "axe", "axe_overhead", "axe_edge_aligned",
		"axe_opener", "guard_break", "sunder",
	])
	_set_overhead_presentation(h0)

	var h1: WeaponAttackDefinition = _new_attack(
		"axe_h1",
		"Rising Wedge",
		"heavy"
	)
	h1.startup_time = 0.25
	h1.active_time = 0.105
	h1.recovery_time = 0.3
	h1.combo_timeout = 0.48
	h1.damage_multiplier = 1.56
	h1.stance_multiplier = 1.68
	h1.knockback_multiplier = 1.18
	h1.knockback_up_add = 1.7
	h1.attack_range = 3.26
	h1.cone_angle_degrees = 104.0
	h1.attack_center_forward_offset = 0.96
	h1.max_targets = 5
	h1.movement_distance = 0.58
	h1.movement_duration = 0.17
	h1.next_light_attack_id = "axe_l2"
	h1.footwork_profile_id = "sword_rising_heavy"
	_set_tags(h1, [
		"force", "slash", "axe", "axe_rising", "launcher",
		"axe_exploit", "opening_exploit", "axe_edge_aligned",
	])
	_set_rising_presentation(h1)

	var h2: WeaponAttackDefinition = _new_attack(
		"axe_h2",
		"Momentum Cleave",
		"heavy"
	)
	h2.startup_time = 0.28
	h2.active_time = 0.12
	h2.recovery_time = 0.34
	h2.combo_timeout = 0.5
	h2.damage_multiplier = 1.78
	h2.stance_multiplier = 1.88
	h2.knockback_multiplier = 1.3
	h2.attack_range = 3.58
	h2.cone_angle_degrees = 218.0
	h2.attack_center_forward_offset = 0.78
	h2.max_targets = 8
	h2.movement_distance = 0.7
	h2.movement_duration = 0.19
	h2.next_light_attack_id = "axe_l3"
	h2.footwork_profile_id = "sword_cleave_left"
	_set_tags(h2, [
		"force", "slash", "cleave", "axe", "axe_broad_hew",
		"axe_exploit", "opening_exploit", "momentum",
		"forward_contact_plane",
	])
	_set_presentation(
		h2,
		Vector3(-12.0, 112.0, -8.0),
		Vector3(-10.0, -128.0, 9.0),
		Vector3(-13.0, -28.0, 0.0)
	)

	var h3: WeaponAttackDefinition = _new_attack(
		"axe_h3",
		"Execution Split",
		"heavy"
	)
	h3.startup_time = 0.36
	h3.active_time = 0.13
	h3.recovery_time = 0.44
	h3.combo_timeout = 0.54
	h3.cancel_window_start_normalized = 0.84
	h3.damage_multiplier = 2.16
	h3.stance_multiplier = 2.48
	h3.knockback_multiplier = 1.5
	h3.attack_range = 3.5
	h3.cone_angle_degrees = 108.0
	h3.attack_center_forward_offset = 1.15
	h3.max_targets = 6
	h3.movement_distance = 0.72
	h3.movement_duration = 0.22
	h3.next_light_attack_id = "axe_l1"
	h3.footwork_profile_id = "sword_overhead"
	_set_tags(h3, [
		"force", "slash", "axe", "axe_overhead", "axe_edge_aligned",
		"axe_exploit", "opening_exploit", "guard_break", "execution",
	])
	_set_overhead_presentation(h3)
	h3.windup_offset = Vector3(0.0, 0.08, 0.08)
	h3.strike_offset = Vector3(0.0, -0.13, -0.28)

	moveset.attacks = [l1, l2, l3, h0, h1, h2, h3]
	return moveset


static func _new_attack(
	attack_id: String,
	display_name: String,
	input_kind: String
) -> WeaponAttackDefinition:
	var attack: WeaponAttackDefinition = WeaponAttackDefinition.new()
	attack.attack_id = attack_id
	attack.display_name = display_name
	attack.input_kind = input_kind
	attack.stamina_cost = 0
	attack.allow_spell_cancel = false
	attack.allow_dodge_cancel = true
	attack.character_pose_id = "axe_focus_" + attack_id
	attack.footwork_profile_id = ""
	attack.hit_stop_time_scale = 0.035
	attack.trail_color = Color(0.28, 0.72, 1.0, 0.82)
	attack.trail_start_scale = Vector3(0.42, 0.72, 1.0)
	attack.trail_end_scale = Vector3(1.12, 1.42, 1.0)
	return attack


static func _set_tags(
	attack: WeaponAttackDefinition,
	tags: Array
) -> void:
	attack.extra_tags.clear()
	for raw_tag: Variant in tags:
		var tag: String = str(raw_tag)
		if tag != "" and not attack.extra_tags.has(tag):
			attack.extra_tags.append(tag)


static func _set_presentation(
	attack: WeaponAttackDefinition,
	windup: Vector3,
	strike: Vector3,
	recovery: Vector3
) -> void:
	attack.windup_rotation_degrees = windup
	attack.strike_rotation_degrees = strike
	attack.recovery_rotation_degrees = recovery


static func _set_overhead_presentation(attack: WeaponAttackDefinition) -> void:
	# The 90-degree roll aligns the axe blade plane with the vertical swing plane,
	# so the edge rather than the broad cheek reaches the floor first.
	_set_presentation(
		attack,
		Vector3(-108.0, -5.0, 90.0),
		Vector3(88.0, 4.0, 90.0),
		Vector3(26.0, 2.0, 88.0)
	)
	attack.windup_offset = Vector3(0.0, 0.06, 0.05)
	attack.strike_offset = Vector3(0.0, -0.1, -0.22)


static func _set_rising_presentation(attack: WeaponAttackDefinition) -> void:
	_set_presentation(
		attack,
		Vector3(72.0, -8.0, 90.0),
		Vector3(-42.0, 6.0, 90.0),
		Vector3(-12.0, 3.0, 88.0)
	)
	attack.windup_offset = Vector3(0.0, -0.1, -0.08)
	attack.strike_offset = Vector3(0.0, 0.12, -0.18)
