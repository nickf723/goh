extends RefCounted
class_name StaffWeaponFocusCatalogV1

const StaffRigScene: PackedScene = preload(
	"res://scenes/weapons/staff_weapon_rig.tscn"
)


static func apply_to_weapon(weapon: WeaponDefinition) -> WeaponDefinition:
	if weapon == null or weapon.weapon_class != "staff":
		return weapon
	weapon.display_name = "Training Wayfarer Staff"
	weapon.description = (
		"A low-carried quarterstaff built around flowing control, a returning toss, "
		+ "a planted spinning guard, and a repeatable aerial pole-vault rhythm."
	)
	weapon.damage = 2
	weapon.stance_damage = 2
	weapon.range = 3.35
	weapon.attack_speed = 1.12
	weapon.cooldown = 0.38
	weapon.cone_angle_degrees = 145.0
	weapon.max_targets = 5
	weapon.stamina_cost = 0
	weapon.critical_multiplier = 2.0
	weapon.visual_primary_color = Color(0.08, 0.72, 0.78, 1.0)
	weapon.visual_secondary_color = Color(0.035, 0.13, 0.16, 1.0)
	weapon.visual_accent_color = Color(0.32, 1.0, 0.94, 1.0)
	weapon.visual_scale = 1.0
	weapon.runtime_rig_scene = StaffRigScene
	weapon.moveset = build_moveset()
	weapon.scaling_stats = ["skill", "arcana"]
	weapon.scaling_note = (
		"Skill governs balance and leverage; Arcana governs the returning and "
		+ "defensive charge techniques."
	)
	weapon.set_meta("staff_focus_v1", true)
	weapon.set_meta("combat_sandbox_authored", true)
	weapon.set_meta("combat_sandbox_proxy", false)
	return weapon


static func build_moveset() -> WeaponMovesetDefinition:
	var moveset: WeaponMovesetDefinition = WeaponMovesetDefinition.new()
	moveset.moveset_id = "staff_focus_v1"
	moveset.display_name = "Wayfarer Staff Forms"
	moveset.entry_light_attack_id = "staff_l1"
	moveset.entry_heavy_attack_id = "staff_h0"

	var l1: WeaponAttackDefinition = _new_attack(
		"staff_l1",
		"Low Tide Sweep",
		"light"
	)
	l1.startup_time = 0.12
	l1.active_time = 0.085
	l1.recovery_time = 0.14
	l1.combo_timeout = 0.62
	l1.damage_multiplier = 0.94
	l1.stance_multiplier = 0.92
	l1.knockback_multiplier = 0.72
	l1.attack_range = 3.15
	l1.cone_angle_degrees = 154.0
	l1.attack_center_forward_offset = 0.74
	l1.max_targets = 5
	l1.movement_distance = 0.24
	l1.movement_duration = 0.12
	l1.next_light_attack_id = "staff_l2"
	l1.next_heavy_attack_id = "staff_h1"
	l1.footwork_profile_id = "sword_cut_right"
	_set_tags(l1, ["blunt", "staff", "flow", "sweep", "staff_low_sweep", "forward_contact_plane"])
	_set_presentation(l1, Vector3(-8.0, -68.0, -4.0), Vector3(-6.0, 62.0, 4.0), Vector3(-10.0, 12.0, 0.0))

	var l2: WeaponAttackDefinition = _new_attack(
		"staff_l2",
		"Returning Current",
		"light"
	)
	l2.startup_time = 0.115
	l2.active_time = 0.09
	l2.recovery_time = 0.15
	l2.combo_timeout = 0.64
	l2.damage_multiplier = 1.02
	l2.stance_multiplier = 1.02
	l2.knockback_multiplier = 0.78
	l2.attack_range = 3.22
	l2.cone_angle_degrees = 162.0
	l2.attack_center_forward_offset = 0.72
	l2.max_targets = 5
	l2.movement_distance = 0.27
	l2.movement_duration = 0.12
	l2.next_light_attack_id = "staff_l3"
	l2.next_heavy_attack_id = "staff_h2"
	l2.footwork_profile_id = "sword_cut_left"
	_set_tags(l2, ["blunt", "staff", "flow", "sweep", "reverse", "staff_return_sweep", "forward_contact_plane"])
	_set_presentation(l2, Vector3(-7.0, 70.0, 4.0), Vector3(-8.0, -66.0, -5.0), Vector3(-10.0, -12.0, 0.0))

	var l3: WeaponAttackDefinition = _new_attack(
		"staff_l3",
		"Passing Point",
		"light"
	)
	l3.startup_time = 0.14
	l3.active_time = 0.075
	l3.recovery_time = 0.19
	l3.combo_timeout = 0.68
	l3.damage_multiplier = 1.16
	l3.stance_multiplier = 1.18
	l3.knockback_multiplier = 0.82
	l3.attack_range = 3.72
	l3.cone_angle_degrees = 48.0
	l3.attack_center_forward_offset = 1.45
	l3.max_targets = 3
	l3.movement_distance = 0.56
	l3.movement_duration = 0.15
	l3.next_heavy_attack_id = "staff_h3"
	l3.footwork_profile_id = "sword_thrust"
	_set_tags(l3, ["blunt", "staff", "flow", "thrust", "precision", "staff_passing_point", "forward_contact_plane"])
	_set_presentation(l3, Vector3(-5.0, -10.0, 1.0), Vector3(-3.0, 2.0, 0.0), Vector3(-8.0, 0.0, 0.0))
	l3.windup_offset = Vector3(0.0, 0.0, 0.12)
	l3.strike_offset = Vector3(0.0, 0.0, -0.58)

	var h0: WeaponAttackDefinition = _new_attack(
		"staff_h0",
		"Pillar Ram",
		"heavy"
	)
	h0.startup_time = 0.24
	h0.active_time = 0.1
	h0.recovery_time = 0.3
	h0.combo_timeout = 0.34
	h0.cancel_window_start_normalized = 0.76
	h0.damage_multiplier = 1.68
	h0.stance_multiplier = 2.05
	h0.knockback_multiplier = 1.38
	h0.attack_range = 3.28
	h0.cone_angle_degrees = 74.0
	h0.attack_center_forward_offset = 1.08
	h0.max_targets = 4
	h0.movement_distance = 0.52
	h0.movement_duration = 0.17
	h0.next_light_attack_id = "staff_l1"
	h0.footwork_profile_id = "sword_thrust_heavy"
	_set_tags(h0, ["force", "blunt", "staff", "braced", "staff_pillar_ram", "forward_contact_plane"])
	_set_presentation(h0, Vector3(-8.0, -20.0, 7.0), Vector3(-4.0, 6.0, -5.0), Vector3(-9.0, 0.0, 0.0))
	h0.windup_offset = Vector3(0.0, -0.05, 0.1)
	h0.strike_offset = Vector3(0.0, -0.08, -0.52)

	var h1: WeaponAttackDefinition = _new_attack(
		"staff_h1",
		"Crossbar Drive",
		"heavy"
	)
	h1.startup_time = 0.22
	h1.active_time = 0.11
	h1.recovery_time = 0.32
	h1.combo_timeout = 0.35
	h1.damage_multiplier = 1.58
	h1.stance_multiplier = 1.85
	h1.knockback_multiplier = 1.32
	h1.attack_range = 3.48
	h1.cone_angle_degrees = 188.0
	h1.attack_center_forward_offset = 0.76
	h1.max_targets = 7
	h1.movement_distance = 0.38
	h1.movement_duration = 0.16
	h1.next_light_attack_id = "staff_l2"
	h1.footwork_profile_id = "sword_cleave_left"
	_set_tags(h1, ["force", "blunt", "staff", "cleave", "staff_crossbar_drive", "forward_contact_plane"])
	_set_presentation(h1, Vector3(-9.0, -92.0, -7.0), Vector3(-7.0, 88.0, 7.0), Vector3(-10.0, 18.0, 0.0))

	var h2: WeaponAttackDefinition = _new_attack(
		"staff_h2",
		"Hooking Return",
		"heavy"
	)
	h2.startup_time = 0.25
	h2.active_time = 0.12
	h2.recovery_time = 0.34
	h2.combo_timeout = 0.36
	h2.damage_multiplier = 1.72
	h2.stance_multiplier = 2.1
	h2.knockback_multiplier = 1.22
	h2.attack_range = 3.58
	h2.cone_angle_degrees = 218.0
	h2.attack_center_forward_offset = 0.68
	h2.max_targets = 7
	h2.movement_distance = 0.24
	h2.movement_duration = 0.15
	h2.next_light_attack_id = "staff_l3"
	h2.footwork_profile_id = "sword_spin_right"
	_set_tags(h2, ["force", "blunt", "staff", "hook", "reverse", "staff_hooking_return", "forward_contact_plane"])
	_set_presentation(h2, Vector3(-7.0, 102.0, 7.0), Vector3(-10.0, -112.0, -9.0), Vector3(-10.0, -22.0, 0.0))

	var h3: WeaponAttackDefinition = _new_attack(
		"staff_h3",
		"Spinning Ward",
		"heavy"
	)
	h3.startup_time = 0.28
	h3.active_time = 0.15
	h3.recovery_time = 0.36
	h3.combo_timeout = 0.4
	h3.cancel_window_start_normalized = 0.8
	h3.damage_multiplier = 1.12
	h3.stance_multiplier = 1.42
	h3.knockback_multiplier = 1.08
	h3.attack_range = 3.42
	h3.cone_angle_degrees = 360.0
	h3.attack_center_forward_offset = 0.1
	h3.max_targets = 10
	h3.movement_distance = 0.18
	h3.movement_duration = 0.18
	h3.next_light_attack_id = "staff_l1"
	h3.footwork_profile_id = "sword_orbit"
	_set_tags(h3, ["force", "blunt", "staff", "spin", "guard", "multi_hit_2", "staff_spinning_ward"])
	_set_presentation(h3, Vector3(-7.0, -126.0, 0.0), Vector3(-6.0, 236.0, 0.0), Vector3(-10.0, 18.0, 0.0))

	moveset.attacks = [l1, l2, l3, h0, h1, h2, h3]
	return moveset


static func build_aerial_descent_attack() -> WeaponAttackDefinition:
	var attack: WeaponAttackDefinition = _new_attack(
		"staff_aerial_vault_descent",
		"Grounding Point",
		"heavy"
	)
	attack.startup_time = 0.05
	attack.active_time = 60.0
	attack.recovery_time = 0.01
	attack.damage_multiplier = 0.0
	attack.stance_multiplier = 0.0
	attack.attack_range = 0.1
	attack.cone_angle_degrees = 1.0
	attack.max_targets = 1
	attack.movement_distance = 0.0
	attack.allow_dodge_cancel = true
	_set_tags(attack, ["staff_aerial_vault", "staff_vault_hold_state", "staff_vault_descent", "traversal", "airborne"])
	return attack


static func build_aerial_bend_attack() -> WeaponAttackDefinition:
	var attack: WeaponAttackDefinition = _new_attack(
		"staff_aerial_vault_bend",
		"Loaded Pole",
		"heavy"
	)
	attack.startup_time = 0.05
	attack.active_time = 60.0
	attack.recovery_time = 0.01
	attack.damage_multiplier = 0.0
	attack.stance_multiplier = 0.0
	attack.attack_range = 0.1
	attack.cone_angle_degrees = 1.0
	attack.max_targets = 1
	attack.movement_distance = 0.0
	attack.allow_dodge_cancel = true
	_set_tags(attack, ["staff_aerial_vault", "staff_vault_hold_state", "staff_vault_bend", "staff_pole_vault", "traversal"])
	return attack


static func build_aerial_launch_attack(bend_ratio: float) -> WeaponAttackDefinition:
	var bend: float = clampf(bend_ratio, 0.0, 1.0)
	var attack: WeaponAttackDefinition = _new_attack(
		"staff_aerial_vault_launch",
		"Springboard Vault",
		"heavy"
	)
	attack.startup_time = 0.045
	attack.active_time = 0.075
	attack.recovery_time = 0.12
	attack.combo_timeout = 0.12
	attack.damage_multiplier = lerpf(0.72, 1.1, bend)
	attack.stance_multiplier = lerpf(0.9, 1.38, bend)
	attack.knockback_multiplier = lerpf(0.82, 1.15, bend)
	attack.knockback_up_add = lerpf(0.4, 1.1, bend)
	attack.attack_range = lerpf(2.0, 2.65, bend)
	attack.cone_angle_degrees = 96.0
	attack.attack_center_forward_offset = 0.72
	attack.max_targets = 4
	attack.movement_distance = 0.0
	attack.hit_stop_duration = 0.05
	_set_tags(attack, ["staff_aerial_vault", "staff_vault_launch", "staff_pole_vault", "traversal", "airborne"])
	return attack


static func build_aerial_overheld_drop_attack() -> WeaponAttackDefinition:
	var attack: WeaponAttackDefinition = _new_attack(
		"staff_aerial_vault_overheld_drop",
		"Spent Pole",
		"heavy"
	)
	attack.startup_time = 0.04
	attack.active_time = 0.04
	attack.recovery_time = 0.16
	attack.combo_timeout = 0.0
	attack.damage_multiplier = 0.0
	attack.stance_multiplier = 0.0
	attack.attack_range = 0.1
	attack.cone_angle_degrees = 1.0
	attack.max_targets = 1
	attack.movement_distance = 0.0
	_set_tags(attack, ["staff_aerial_vault", "staff_vault_overheld_drop", "traversal"])
	return attack


static func build_aerial_plant_pulse(bend_ratio: float) -> WeaponAttackDefinition:
	var bend: float = clampf(bend_ratio, 0.0, 1.0)
	var attack: WeaponAttackDefinition = _new_attack(
		"staff_aerial_vault_plant",
		"Staff Plant",
		"light"
	)
	attack.startup_time = 0.0
	attack.active_time = 0.01
	attack.recovery_time = 0.01
	attack.damage_multiplier = lerpf(0.42, 0.6, bend)
	attack.stance_multiplier = lerpf(0.65, 0.92, bend)
	attack.knockback_multiplier = 0.5
	attack.attack_range = 1.75
	attack.cone_angle_degrees = 105.0
	attack.attack_center_forward_offset = 0.65
	attack.max_targets = 4
	attack.movement_distance = 0.0
	attack.hit_stop_duration = 0.035
	_set_tags(attack, ["weapon_charge_pulse", "staff_vault_plant", "ground_impact"])
	return attack


static func build_ring_release_attack(charge_ratio: float) -> WeaponAttackDefinition:
	var charge: float = clampf(charge_ratio, 0.0, 1.0)
	var attack: WeaponAttackDefinition = _new_attack(
		"staff_angel_ring_release",
		"Bastion Push",
		"heavy"
	)
	attack.startup_time = 0.05
	attack.active_time = 0.07
	attack.recovery_time = 0.16
	attack.combo_timeout = 0.22
	attack.damage_multiplier = lerpf(0.5, 0.72, charge)
	attack.stance_multiplier = lerpf(0.82, 1.15, charge)
	attack.knockback_multiplier = lerpf(0.92, 1.28, charge)
	attack.attack_range = lerpf(2.45, 2.9, charge)
	attack.cone_angle_degrees = 126.0
	attack.attack_center_forward_offset = 0.92
	attack.max_targets = 6
	attack.movement_distance = 0.0
	attack.hit_stop_duration = 0.04
	_set_tags(attack, ["staff_angel_ring_release", "staff_front_spin", "force", "guard_push"])
	return attack


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
	attack.allow_spell_cancel = true
	attack.allow_dodge_cancel = true
	attack.character_pose_id = "staff_focus_" + attack_id
	attack.footwork_profile_id = ""
	attack.hit_stop_time_scale = 0.04
	attack.trail_color = Color(0.32, 1.0, 0.94, 0.88)
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
