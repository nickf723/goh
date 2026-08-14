extends "res://scripts/weapons/safe_weapon_controller.gd"
class_name CombatWeaponControllerV2

const RANGED_AIM_CLASSES: Array[String] = ["bow", "shuriken", "boomerang"]
const TARGET_ENGAGEMENT_CLASSES: Array[String] = ["sword"]
const FLEXIBLE_WEAPON_CLASSES: Array[String] = ["whip", "chains", "flail"]

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
var flair_attack_serial: int = 0


func start_attack(attack: WeaponAttackDefinition) -> bool:
	var resolved_attack: WeaponAttackDefinition = _prepare_combat_flair_attack(attack)
	_prepare_engagement(resolved_attack)
	var started: bool = super.start_attack(resolved_attack)
	if not started:
		_clear_engagement()
		return false
	flair_attack_serial += 1
	_schedule_multi_strike_pulses(current_attack, flair_attack_serial)
	return true


func _prepare_combat_flair_attack(
	attack: WeaponAttackDefinition
) -> WeaponAttackDefinition:
	if attack == null or equipped_weapon == null:
		return attack
	var resolved: WeaponAttackDefinition = attack.duplicate(true) as WeaponAttackDefinition
	if resolved == null:
		return attack
	var weapon_class: String = equipped_weapon.weapon_class
	if resolved.extra_tags.has("aerial_light") or resolved.extra_tags.has("aerial_heavy"):
		_configure_aerial_flair(resolved, weapon_class)
	elif resolved.extra_tags.has("context_dash"):
		_configure_dash_flair(resolved, weapon_class)
	elif resolved.attack_id.contains("_proxy_"):
		_configure_proxy_ground_flair(resolved, weapon_class)
	_normalize_forward_presentation(resolved, weapon_class)
	return resolved


func _configure_aerial_flair(
	attack: WeaponAttackDefinition,
	weapon_class: String
) -> void:
	var light: bool = attack.extra_tags.has("aerial_light")
	if light:
		attack.recovery_time = maxf(attack.recovery_time * 0.88, 0.075)
		attack.movement_distance = maxf(attack.movement_distance, 0.52)
		attack.movement_duration = minf(maxf(attack.movement_duration, 0.1), 0.15)
		match weapon_class:
			"sword":
				attack.display_name = "Orbit Cut"
				attack.damage_multiplier *= 0.78
				attack.active_time = maxf(attack.active_time, 0.12)
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 285.0)
				attack.max_targets += 2
				attack.movement_distance = maxf(attack.movement_distance, 0.72)
				attack.windup_rotation_degrees = Vector3(4.0, -128.0, -8.0)
				attack.strike_rotation_degrees = Vector3(-5.0, 220.0, 8.0)
				attack.recovery_rotation_degrees = Vector3(-2.0, 318.0, 2.0)
				_append_attack_tag(attack, "spin")
				_append_attack_tag(attack, "multi_hit_2")
				_append_attack_tag(attack, "aerial_orbit")
			"lance":
				attack.display_name = "Skyline Thrust"
				attack.attack_range += 0.65
				attack.cone_angle_degrees = minf(attack.cone_angle_degrees, 38.0)
				attack.movement_distance = maxf(attack.movement_distance, 1.18)
				attack.windup_rotation_degrees = Vector3(0.0, -12.0, 88.0)
				attack.strike_rotation_degrees = Vector3(-2.0, 2.0, 90.0)
				attack.strike_offset.z = minf(attack.strike_offset.z, -0.62)
				_append_attack_tag(attack, "thrust")
				_append_attack_tag(attack, "air_dash")
			"axe":
				attack.display_name = "Cleaving Halo"
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 230.0)
				attack.stance_multiplier *= 1.12
				attack.windup_rotation_degrees = Vector3(12.0, -96.0, -10.0)
				attack.strike_rotation_degrees = Vector3(-16.0, 132.0, 10.0)
				_append_attack_tag(attack, "cleave")
			"bow":
				attack.display_name = "Cyclone Volley"
				attack.damage_multiplier *= 0.74
				attack.active_time = maxf(attack.active_time, 0.13)
				attack.movement_distance = 0.0
				_append_attack_tag(attack, "multi_hit_2")
				_append_attack_tag(attack, "air_volley")
			"hammer":
				attack.display_name = "Bell Orbit"
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 220.0)
				attack.stance_multiplier *= 1.18
				attack.windup_rotation_degrees = Vector3(10.0, -102.0, -8.0)
				attack.strike_rotation_degrees = Vector3(-12.0, 138.0, 8.0)
				_append_attack_tag(attack, "orbit")
			"mace":
				attack.display_name = "Dazing Halo"
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 210.0)
				attack.stance_multiplier *= 1.14
				_append_attack_tag(attack, "dazing_spin")
			"daggers":
				attack.display_name = "Razor Bloom"
				attack.damage_multiplier *= 0.62
				attack.active_time = maxf(attack.active_time, 0.15)
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 125.0)
				attack.movement_distance = maxf(attack.movement_distance, 0.9)
				attack.recovery_time = maxf(attack.recovery_time * 0.72, 0.065)
				_append_attack_tag(attack, "multi_hit_3")
				_append_attack_tag(attack, "air_flurry")
			"whip":
				attack.display_name = "Ribbon Cyclone"
				attack.damage_multiplier *= 0.78
				attack.active_time = maxf(attack.active_time, 0.13)
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 245.0)
				attack.attack_range += 0.7
				_append_attack_tag(attack, "multi_hit_2")
				_append_attack_tag(attack, "air_lash")
			"chains":
				attack.display_name = "Iron Orbit"
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 265.0)
				attack.attack_range += 0.55
				_append_attack_tag(attack, "orbit")
			"gauntlets":
				attack.display_name = "Cyclone Knuckles"
				attack.damage_multiplier *= 0.64
				attack.active_time = maxf(attack.active_time, 0.15)
				attack.movement_distance = maxf(attack.movement_distance, 0.86)
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 115.0)
				_append_attack_tag(attack, "multi_hit_3")
				_append_attack_tag(attack, "air_flurry")
			"flail":
				attack.display_name = "Moon Orbit"
				attack.damage_multiplier *= 0.78
				attack.active_time = maxf(attack.active_time, 0.13)
				attack.cone_angle_degrees = 360.0
				attack.max_targets += 2
				_append_attack_tag(attack, "multi_hit_2")
				_append_attack_tag(attack, "orbit")
			"halberd":
				attack.display_name = "Reaping Wheel"
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 235.0)
				attack.attack_range += 0.45
				_append_attack_tag(attack, "reap")
			"boomerang":
				attack.display_name = "Halo Cast"
				attack.movement_distance = 0.0
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 74.0)
				_append_attack_tag(attack, "air_glide")
			"scythe":
				attack.display_name = "Pale Moon"
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 285.0)
				attack.max_targets += 2
				_append_attack_tag(attack, "reap")
			"staff":
				attack.display_name = "Spinning Ward"
				attack.damage_multiplier *= 0.76
				attack.active_time = maxf(attack.active_time, 0.14)
				attack.cone_angle_degrees = 360.0
				attack.attack_center_forward_offset = 0.25
				attack.max_targets += 2
				attack.windup_rotation_degrees = Vector3(0.0, -145.0, 88.0)
				attack.strike_rotation_degrees = Vector3(0.0, 225.0, 92.0)
				attack.recovery_rotation_degrees = Vector3(0.0, 320.0, 90.0)
				_append_attack_tag(attack, "multi_hit_2")
				_append_attack_tag(attack, "staff_air_spin")
			"shuriken":
				attack.display_name = "Star Halo"
				attack.damage_multiplier *= 0.72
				attack.active_time = maxf(attack.active_time, 0.13)
				attack.movement_distance = 0.0
				_append_attack_tag(attack, "multi_hit_2")
				_append_attack_tag(attack, "air_volley")
		return

	match weapon_class:
		"sword":
			attack.display_name = "Falling Edge"
			attack.movement_distance = maxf(attack.movement_distance, 0.28)
			attack.windup_rotation_degrees = Vector3(-34.0, -22.0, -5.0)
			attack.strike_rotation_degrees = Vector3(46.0, 26.0, 5.0)
		"lance":
			attack.display_name = "Dragon Drop"
			attack.attack_range += 0.5
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 92.0)
			_append_attack_tag(attack, "thrust")
		"axe":
			attack.display_name = "Timberfall"
			attack.stance_multiplier *= 1.22
			attack.knockback_multiplier *= 1.12
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 145.0)
		"bow":
			attack.display_name = "Raptor Shot"
			_remove_attack_tag(attack, "plunging")
			attack.movement_distance = 0.0
			attack.damage_multiplier *= 1.12
			attack.attack_range += 1.0
			attack.cone_angle_degrees = minf(attack.cone_angle_degrees, 18.0)
			_append_attack_tag(attack, "air_recoil")
		"hammer":
			attack.display_name = "Meteor Drop"
			attack.stance_multiplier *= 1.28
			attack.knockback_multiplier *= 1.18
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 155.0)
			_append_attack_tag(attack, "ground_slam")
		"mace":
			attack.display_name = "Falling Star"
			attack.stance_multiplier *= 1.22
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 138.0)
		"daggers":
			attack.display_name = "Pinning Dive"
			attack.movement_distance = maxf(attack.movement_distance, 0.42)
			attack.attack_range += 0.28
			attack.cone_angle_degrees = minf(attack.cone_angle_degrees, 76.0)
			_append_attack_tag(attack, "pinning_dive")
		"whip":
			attack.display_name = "Lashing Descent"
			attack.attack_range += 0.8
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 160.0)
		"chains":
			attack.display_name = "Anchorfall"
			attack.stance_multiplier *= 1.2
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 165.0)
		"gauntlets":
			attack.display_name = "Meteor Fist"
			attack.stance_multiplier *= 1.2
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 125.0)
			_append_attack_tag(attack, "ground_slam")
		"flail":
			attack.display_name = "Deadweight Drop"
			attack.stance_multiplier *= 1.3
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 175.0)
			_append_attack_tag(attack, "ground_slam")
		"halberd":
			attack.display_name = "Guillotine Drop"
			attack.attack_range += 0.4
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 135.0)
		"boomerang":
			attack.display_name = "Swooping Return"
			_remove_attack_tag(attack, "plunging")
			attack.movement_distance = 0.0
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 68.0)
			_append_attack_tag(attack, "air_glide")
		"scythe":
			attack.display_name = "Gravefall"
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 190.0)
			attack.max_targets += 1
		"staff":
			attack.display_name = "Cloud Vault"
			_remove_attack_tag(attack, "plunging")
			attack.damage_multiplier *= 0.94
			attack.stance_multiplier *= 1.16
			attack.attack_range += 0.45
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 150.0)
			attack.movement_distance = 0.08
			attack.windup_rotation_degrees = Vector3(18.0, -18.0, 88.0)
			attack.strike_rotation_degrees = Vector3(62.0, 8.0, 90.0)
			attack.recovery_rotation_degrees = Vector3(-12.0, 18.0, 90.0)
			attack.strike_offset = Vector3(0.0, -0.48, -0.34)
			attack.recovery_offset = Vector3(0.0, 0.22, -0.56)
			_append_attack_tag(attack, "pole_vault")
			_append_attack_tag(attack, "staff_pole_vault")
		"shuriken":
			attack.display_name = "Kunai Rain"
			_remove_attack_tag(attack, "plunging")
			attack.damage_multiplier *= 0.8
			attack.active_time = maxf(attack.active_time, 0.14)
			attack.movement_distance = 0.0
			_append_attack_tag(attack, "multi_hit_2")
			_append_attack_tag(attack, "air_recoil")


func _configure_dash_flair(
	attack: WeaponAttackDefinition,
	weapon_class: String
) -> void:
	var heavy: bool = attack.extra_tags.has("dash_heavy")
	match weapon_class:
		"sword":
			attack.movement_distance = maxf(attack.movement_distance, 1.08 if not heavy else 1.18)
		"lance":
			attack.movement_distance = maxf(attack.movement_distance, 1.42 if not heavy else 1.62)
			attack.attack_range += 0.35
			attack.cone_angle_degrees = minf(attack.cone_angle_degrees, 54.0)
			_append_attack_tag(attack, "thrust")
		"daggers":
			attack.movement_distance = maxf(attack.movement_distance, 1.22)
			if not heavy:
				attack.damage_multiplier *= 0.78
				attack.active_time = maxf(attack.active_time, 0.1)
				_append_attack_tag(attack, "multi_hit_2")
		"gauntlets":
			attack.movement_distance = maxf(attack.movement_distance, 1.12)
		"staff":
			attack.movement_distance = maxf(attack.movement_distance, 1.15 if not heavy else 1.3)
			attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 145.0 if not heavy else 118.0)
		"scythe", "halberd":
			attack.movement_distance = maxf(attack.movement_distance, 1.0)
			attack.attack_range += 0.2
		"whip", "chains":
			attack.attack_range += 0.35


func _configure_proxy_ground_flair(
	attack: WeaponAttackDefinition,
	weapon_class: String
) -> void:
	var index: int = _proxy_attack_index(attack.attack_id)
	if index < 0:
		return
	var heavy: bool = attack.input_kind == "heavy"
	match weapon_class:
		"axe":
			if heavy and index == 3:
				attack.display_name = "Headsman's Drop"
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 185.0)
				attack.stance_multiplier *= 1.18
				attack.movement_distance = minf(attack.movement_distance, 0.18)
				_append_attack_tag(attack, "ground_slam")
			elif not heavy and index == 2:
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 205.0)
				attack.movement_distance = maxf(attack.movement_distance, 0.52)
		"bow":
			attack.movement_distance = 0.0
			if not heavy and index == 2:
				attack.display_name = "Twin Nock"
				attack.damage_multiplier *= 0.72
				attack.active_time = maxf(attack.active_time, 0.12)
				_append_attack_tag(attack, "multi_hit_2")
			elif heavy and index == 3:
				attack.attack_range += 2.2
				attack.cone_angle_degrees = minf(attack.cone_angle_degrees, 10.0)
		"mace":
			if heavy and index >= 2:
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 185.0)
				attack.stance_multiplier *= 1.16
			elif not heavy and index == 1:
				attack.movement_distance = maxf(attack.movement_distance, 0.5)
		"daggers":
			if not heavy:
				attack.movement_distance = maxf(attack.movement_distance, 0.68 + float(index) * 0.08)
				attack.recovery_time *= 0.84
				if index == 1:
					attack.display_name = "Twin Fang"
					attack.damage_multiplier *= 0.76
					attack.active_time = maxf(attack.active_time, 0.11)
					_append_attack_tag(attack, "multi_hit_2")
				elif index == 2:
					attack.display_name = "Razor Rush"
					attack.damage_multiplier *= 0.62
					attack.active_time = maxf(attack.active_time, 0.15)
					_append_attack_tag(attack, "multi_hit_3")
			elif index == 3:
				attack.movement_distance = maxf(attack.movement_distance, 1.05)
				attack.attack_range += 0.28
		"gauntlets":
			if not heavy and index == 1:
				attack.display_name = "One-Two"
				attack.damage_multiplier *= 0.78
				attack.active_time = maxf(attack.active_time, 0.11)
				_append_attack_tag(attack, "multi_hit_2")
			elif heavy and index == 0:
				attack.knockback_up_add = maxf(attack.knockback_up_add, 3.2)
				_append_attack_tag(attack, "launcher")
			elif heavy and index == 3:
				attack.movement_distance = maxf(attack.movement_distance, 1.0)
		"flail":
			if not heavy and index == 2:
				attack.display_name = "Double Orbit"
				attack.damage_multiplier *= 0.76
				attack.active_time = maxf(attack.active_time, 0.13)
				attack.cone_angle_degrees = 360.0
				_append_attack_tag(attack, "multi_hit_2")
			elif heavy and index == 3:
				attack.cone_angle_degrees = 360.0
				attack.attack_center_forward_offset = 0.0
				attack.max_targets += 3
		"halberd":
			if heavy and index == 1:
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 210.0)
				attack.attack_range += 0.45
			elif heavy and index == 3:
				attack.display_name = "Guillotine Line"
				attack.stance_multiplier *= 1.2
		"boomerang":
			attack.movement_distance = minf(attack.movement_distance, 0.18)
			if heavy and index == 3:
				attack.attack_range += 1.3
		"scythe":
			if not heavy and index == 2:
				attack.cone_angle_degrees = maxf(attack.cone_angle_degrees, 300.0)
				attack.max_targets += 2
			elif heavy and index == 3:
				attack.cone_angle_degrees = 360.0
				attack.attack_center_forward_offset = 0.0
				attack.max_targets += 3
		"staff":
			if not heavy and index == 2:
				attack.attack_range += 0.5
				attack.cone_angle_degrees = minf(attack.cone_angle_degrees, 58.0)
				_append_attack_tag(attack, "thrust")
			elif heavy and index == 3:
				attack.display_name = "Spinning Ward"
				attack.damage_multiplier *= 0.78
				attack.active_time = maxf(attack.active_time, 0.13)
				attack.cone_angle_degrees = 360.0
				attack.attack_center_forward_offset = 0.15
				attack.max_targets += 2
				_append_attack_tag(attack, "multi_hit_2")
		"shuriken":
			attack.movement_distance = minf(attack.movement_distance, 0.12)
			if not heavy and index == 2:
				attack.display_name = "Six-Star Volley"
				attack.damage_multiplier *= 0.72
				attack.active_time = maxf(attack.active_time, 0.12)
				_append_attack_tag(attack, "multi_hit_2")


func _normalize_forward_presentation(
	attack: WeaponAttackDefinition,
	weapon_class: String
) -> void:
	if attack == null or RANGED_AIM_CLASSES.has(weapon_class):
		return
	var deliberate_vertical: bool = (
		attack.extra_tags.has("plunging")
		or attack.extra_tags.has("launcher")
		or attack.extra_tags.has("ground_slam")
		or attack.extra_tags.has("pole_vault")
	)
	if deliberate_vertical:
		return
	var pitch_limit: float = 30.0 if attack.input_kind == "heavy" else 22.0
	attack.windup_rotation_degrees.x = clampf(
		attack.windup_rotation_degrees.x,
		-pitch_limit,
		pitch_limit
	)
	attack.strike_rotation_degrees.x = clampf(
		attack.strike_rotation_degrees.x,
		-pitch_limit,
		pitch_limit
	)
	attack.recovery_rotation_degrees.x = clampf(
		attack.recovery_rotation_degrees.x,
		-20.0,
		20.0
	)
	attack.strike_offset.y = clampf(attack.strike_offset.y, -0.14, 0.06)
	if not FLEXIBLE_WEAPON_CLASSES.has(weapon_class):
		attack.strike_offset.z = minf(attack.strike_offset.z, -0.1)
	_append_attack_tag(attack, "forward_contact_plane")


func _schedule_multi_strike_pulses(
	attack: WeaponAttackDefinition,
	serial: int
) -> void:
	if attack == null or not is_inside_tree():
		return
	var hit_count: int = 1
	if attack.extra_tags.has("multi_hit_3"):
		hit_count = 3
	elif attack.extra_tags.has("multi_hit_2"):
		hit_count = 2
	if hit_count <= 1:
		return
	var attack_speed: float = get_attack_speed()
	var startup: float = attack.get_startup_duration(attack_speed)
	var active: float = attack.get_active_duration(attack_speed)
	var recovery: float = attack.get_recovery_duration(attack_speed)
	var beat_delays: Array[float] = [
		startup + maxf(active * 0.58, 0.035),
		startup + active + minf(maxf(recovery * 0.22, 0.04), 0.09),
	]
	var beat_scales: Array[float] = [0.62, 0.5]
	for beat_index: int in range(hit_count - 1):
		var delay: float = beat_delays[beat_index]
		var damage_scale: float = beat_scales[beat_index]
		var attack_id: String = attack.attack_id
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		var callback := func():
			_execute_secondary_strike(serial, attack_id, damage_scale, beat_index + 2)
		timer.timeout.connect(callback, CONNECT_ONE_SHOT)


func _execute_secondary_strike(
	serial: int,
	attack_id: String,
	damage_scale: float,
	beat_index: int
) -> void:
	if (
		serial != flair_attack_serial
		or current_attack == null
		or equipped_weapon == null
		or current_attack.attack_id != attack_id
	):
		return
	var payload: DamagePayload = current_attack.build_payload(equipped_weapon)
	payload.amount = maxi(roundi(float(payload.amount) * damage_scale), 1)
	payload.stance_damage = maxi(roundi(float(payload.stance_damage) * damage_scale), 0)
	payload.knockback_strength *= 0.62
	payload.knockback_up_strength *= 0.6
	if not payload.tags.has("multi_strike"):
		payload.tags.append("multi_strike")
	payload.tags.append("multi_strike_beat_" + str(beat_index))
	var mastery_rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
	WeaponTechniqueCatalogScript.apply_context_tags(
		payload,
		current_attack,
		combo_history.size(),
		active_technique_id
	)
	WeaponMasteryCatalogScript.apply_payload_upgrades(
		payload,
		equipped_weapon.weapon_class,
		mastery_rank,
		current_attack,
		combo_history.size()
	)
	WeaponInfusionCatalogScript.apply_to_payload(payload, GameState.get_weapon_infusion())
	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("modify_attack_payload"):
		runtime_weapon_rig.call("modify_attack_payload", payload, current_attack)

	var targets: Array[Node] = find_targets(current_attack)
	for target: Node in targets:
		send_payload_to_target(target, payload)
		if GameState.get_weapon_infusion() != WeaponInfusionCatalogScript.DEFAULT_INFUSION_ID:
			ElementVisualsScript.spawn_impact(
				get_tree(),
				get_target_position(target),
				payload.element,
				0.48
			)
		if target.has_method("receive_weapon_impact"):
			target.call("receive_weapon_impact", payload, get_attack_forward(), current_attack)
		elif target.has_method("receive_hit_reaction"):
			target.call("receive_hit_reaction", get_attack_forward(), payload.knockback_strength)
	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("on_weapon_targets_hit"):
		runtime_weapon_rig.call("on_weapon_targets_hit", targets, current_attack)
	if targets.is_empty():
		return
	last_attack_connected = true
	current_attack_duration_bonus = 0.0
	play_slash_trail(current_attack)
	HitStop.request(
		minf(maxf(current_attack.hit_stop_duration * 0.52, 0.025), 0.055),
		0.075
	)


func _append_attack_tag(attack: WeaponAttackDefinition, tag: String) -> void:
	if attack != null and tag != "" and not attack.extra_tags.has(tag):
		attack.extra_tags.append(tag)


func _remove_attack_tag(attack: WeaponAttackDefinition, tag: String) -> void:
	if attack != null and attack.extra_tags.has(tag):
		attack.extra_tags.erase(tag)


func _proxy_attack_index(attack_id: String) -> int:
	if not attack_id.contains("_proxy_"):
		return -1
	var pieces: PackedStringArray = attack_id.split("_")
	if pieces.is_empty():
		return -1
	var token: String = pieces[pieces.size() - 1]
	if token.length() < 2:
		return -1
	return int(token.substr(1))


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


# Aerial Light / Heavy now inherits the input grammar but not one universal
# movement profile. Each class gets a recognizable airborne trick or commitment.
func apply_aerial_technique_motion(context_id: String) -> void:
	if context_id not in [
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_LIGHT,
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_HEAVY,
	]:
		super.apply_aerial_technique_motion(context_id)
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D) or equipped_weapon == null:
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	var weapon_class: String = equipped_weapon.weapon_class
	if context_id == WeaponTechniqueCatalogScript.CONTEXT_AERIAL_LIGHT:
		match weapon_class:
			"sword":
				body.velocity.y = maxf(body.velocity.y, -0.35)
				_apply_planar_aerial_speed(body, 5.6, 0.58)
			"lance":
				body.velocity.y = maxf(body.velocity.y, -0.7)
				_apply_planar_aerial_speed(body, 7.4, 0.76)
			"daggers":
				body.velocity.y = maxf(body.velocity.y, 0.15)
				_apply_planar_aerial_speed(body, 6.7, 0.72)
			"gauntlets":
				body.velocity.y = maxf(body.velocity.y, 0.1)
				_apply_planar_aerial_speed(body, 6.0, 0.68)
			"staff":
				body.velocity.y = maxf(body.velocity.y, 0.45)
				_apply_planar_aerial_speed(body, 4.8, 0.58)
			"bow", "shuriken":
				body.velocity.y = maxf(body.velocity.y, 0.35)
				_apply_planar_aerial_speed(body, -2.4, 0.46)
			"boomerang":
				body.velocity.y = maxf(body.velocity.y, 0.55)
				_apply_planar_aerial_speed(body, 3.6, 0.46)
			"whip", "chains", "flail":
				body.velocity.y = maxf(body.velocity.y, -0.15)
				_apply_planar_aerial_speed(body, 4.2, 0.48)
			_:
				body.velocity.y = maxf(body.velocity.y, -0.75)
				_apply_planar_aerial_speed(body, 4.8, 0.5)
		return

	if weapon_class == "staff":
		body.velocity.y = maxf(body.velocity.y, -0.35)
		_schedule_staff_pole_vault()
		return
	if weapon_class in ["bow", "shuriken", "boomerang"]:
		body.velocity.y = maxf(body.velocity.y, 0.45 if weapon_class != "shuriken" else 0.2)
		_apply_planar_aerial_speed(body, -4.4 if weapon_class == "bow" else -2.8, 0.72)
		return

	var fall_speed: float = 7.0
	match weapon_class:
		"hammer": fall_speed = 9.4
		"flail": fall_speed = 9.0
		"gauntlets": fall_speed = 8.8
		"chains": fall_speed = 8.6
		"halberd": fall_speed = 8.4
		"axe": fall_speed = 8.2
		"scythe": fall_speed = 8.1
		"mace": fall_speed = 7.9
		"lance": fall_speed = 7.6
		"whip": fall_speed = 6.7
		"daggers": fall_speed = 6.4
	body.velocity.y = minf(body.velocity.y, -fall_speed)
	_apply_planar_aerial_speed(body, 4.2 if weapon_class in ["sword", "daggers", "lance"] else 2.8, 0.5)
	plunge_landing_armed = true
	plunge_max_fall_speed = absf(minf(body.velocity.y, 0.0))


func _schedule_staff_pole_vault() -> void:
	if current_attack == null or not is_inside_tree():
		return
	var serial: int = flair_attack_serial
	var attack_id: String = current_attack.attack_id
	var delay: float = minf(
		maxf(current_attack.get_startup_duration(get_attack_speed()) * 0.72, 0.045),
		0.14
	)
	var timer: SceneTreeTimer = get_tree().create_timer(delay)
	var callback := func():
		_apply_staff_pole_vault_impulse(serial, attack_id)
	timer.timeout.connect(callback, CONNECT_ONE_SHOT)


func _apply_staff_pole_vault_impulse(serial: int, attack_id: String) -> void:
	if (
		serial != flair_attack_serial
		or current_attack == null
		or current_attack.attack_id != attack_id
		or not current_attack.extra_tags.has("staff_pole_vault")
	):
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	var forward: Vector3 = get_attack_forward()
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	body.velocity.x = forward.x * 8.6
	body.velocity.z = forward.z * 8.6
	body.velocity.y = maxf(body.velocity.y, 5.4)
	plunge_landing_armed = false
	plunge_max_fall_speed = 0.0


func _apply_planar_aerial_speed(
	body: CharacterBody3D,
	speed: float,
	blend: float
) -> void:
	var forward: Vector3 = get_attack_forward()
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return
	forward = forward.normalized()
	var target: Vector3 = forward * speed
	body.velocity.x = lerpf(body.velocity.x, target.x, clampf(blend, 0.0, 1.0))
	body.velocity.z = lerpf(body.velocity.z, target.z, clampf(blend, 0.0, 1.0))


func apply_aerial_hit_followthrough(targets: Array[Node]) -> void:
	if active_technique_id != WeaponTechniqueCatalogScript.CONTEXT_AERIAL_LIGHT:
		super.apply_aerial_hit_followthrough(targets)
		return
	if targets.is_empty() or equipped_weapon == null:
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	var weapon_class: String = equipped_weapon.weapon_class
	var bounce: float = 0.4
	var pursuit_speed: float = 4.8
	match weapon_class:
		"daggers":
			bounce = 1.05
			pursuit_speed = 7.0
		"gauntlets":
			bounce = 0.8
			pursuit_speed = 6.2
		"staff":
			bounce = 1.0
			pursuit_speed = 5.2
		"sword":
			bounce = 0.68
			pursuit_speed = 5.6
		"lance":
			bounce = 0.32
			pursuit_speed = 7.4
		"whip", "chains", "flail":
			bounce = 0.72
			pursuit_speed = 4.4
	body.velocity.y = maxf(body.velocity.y, bounce)
	if weapon_class in RANGED_AIM_CLASSES:
		return
	var target_position: Vector3 = get_target_position(targets[0])
	var pursuit_direction: Vector3 = target_position - body.global_position
	pursuit_direction.y = 0.0
	if pursuit_direction.length_squared() <= 0.0001:
		return
	pursuit_direction = pursuit_direction.normalized()
	body.velocity.x = lerpf(body.velocity.x, pursuit_direction.x * pursuit_speed, 0.68)
	body.velocity.z = lerpf(body.velocity.z, pursuit_direction.z * pursuit_speed, 0.68)


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
		"signature_combat_flair": true,
		"secondary_multi_strike_pulses": true,
		"staff_pole_vault": true,
		"engagement_target": engagement_target.name if _engagement_is_valid() else "none",
		"engagement_source": engagement_source,
		"engagement_start_distance": snappedf(engagement_start_distance, 0.01),
		"engagement_assisted_step": snappedf(engagement_assisted_step, 0.01),
		"engagement_aim_point": engagement_aim_point,
	}
