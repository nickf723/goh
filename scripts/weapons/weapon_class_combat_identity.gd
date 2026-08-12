extends RefCounted
class_name WeaponClassCombatIdentity

const GEOMETRY_ARC: String = "arc"
const GEOMETRY_LINE: String = "line"
const GEOMETRY_RADIAL: String = "radial"
const GEOMETRY_PRECISION_RAY: String = "precision_ray"
const GEOMETRY_FAN_RAYS: String = "fan_rays"
const GEOMETRY_RETURNING_RAY: String = "returning_ray"


static func get_geometry_mode(
	weapon_class: String,
	attack: WeaponAttackDefinition
) -> String:
	if attack == null:
		return GEOMETRY_ARC
	if attack.extra_tags.has("ground_slam"):
		return GEOMETRY_RADIAL
	match weapon_class:
		"bow":
			return GEOMETRY_PRECISION_RAY
		"shuriken":
			return GEOMETRY_FAN_RAYS
		"boomerang":
			return GEOMETRY_RETURNING_RAY
		"lance":
			if attack.extra_tags.has("thrust") or attack.cone_angle_degrees <= 54.0:
				return GEOMETRY_LINE
		"staff":
			if attack.extra_tags.has("thrust") or attack.cone_angle_degrees <= 64.0:
				return GEOMETRY_LINE
		"flail":
			if attack.input_kind == "heavy" and attack.cone_angle_degrees >= 180.0:
				return GEOMETRY_RADIAL
		"scythe":
			if attack.input_kind == "heavy" and attack.cone_angle_degrees >= 180.0:
				return GEOMETRY_RADIAL
	return GEOMETRY_ARC


static func get_line_half_width(
	weapon_class: String,
	attack: WeaponAttackDefinition
) -> float:
	var heavy: bool = attack != null and attack.input_kind == "heavy"
	match weapon_class:
		"lance":
			return 0.7 if heavy else 0.52
		"staff":
			return 0.82 if heavy else 0.62
		_:
			return 0.68 if heavy else 0.5


static func get_fan_angles(attack: WeaponAttackDefinition) -> Array[float]:
	if attack != null and attack.input_kind == "heavy":
		return [-12.0, -6.0, 0.0, 6.0, 12.0]
	return [-6.0, 0.0, 6.0]


static func get_true_range_padding(weapon_class: String) -> float:
	# Target positions generally sit at the feet while attack origins are chest
	# height. This small planar allowance represents the target's body radius, not
	# extra weapon reach.
	if weapon_class in ["bow", "shuriken", "boomerang"]:
		return 0.25
	return 0.7


static func get_return_delay(attack: WeaponAttackDefinition) -> float:
	return 0.2 if attack != null and attack.input_kind == "light" else 0.28


static func apply_payload_identity(
	payload: DamagePayload,
	weapon_class: String,
	attack: WeaponAttackDefinition,
	combo_depth: int,
	target: Node,
	target_offset: Vector3
) -> void:
	if payload == null or attack == null:
		return
	_append_tag(payload, "weapon_class_" + weapon_class)
	var heavy: bool = attack.input_kind == "heavy"
	var toward_target: Vector3 = target_offset
	toward_target.y = 0.0
	if toward_target.length_squared() > 0.0001:
		toward_target = toward_target.normalized()

	match weapon_class:
		"sword":
			payload.knockback_strength = maxf(payload.knockback_strength, 1.55 if heavy else 0.75)
		"lance":
			payload.knockback_strength = maxf(payload.knockback_strength, 1.8 if heavy else 0.72)
			if attack.extra_tags.has("thrust"):
				payload.critical_multiplier += 0.12 if heavy else 0.05
		"axe":
			payload.knockback_strength = maxf(payload.knockback_strength, 3.0 if heavy else 1.15)
			if heavy:
				payload.stance_damage += 1
				_append_tag(payload, "sunder")
		"bow":
			payload.hit_type = "projectile"
			payload.knockback_strength = maxf(payload.knockback_strength, 0.9 if heavy else 0.35)
			if heavy:
				payload.critical_multiplier += 0.4
				payload.stance_damage += 1
				_append_tag(payload, "precision_shot")
		"hammer":
			payload.knockback_strength = maxf(payload.knockback_strength, 4.2 if heavy else 1.55)
			if heavy:
				payload.knockback_up_strength += 0.45
				_append_tag(payload, "heavy_impact")
		"mace":
			payload.knockback_strength = maxf(payload.knockback_strength, 2.65 if heavy else 1.25)
			if heavy and payload.status_effect == "":
				payload.status_effect = "staggered"
				payload.status_duration = maxf(payload.status_duration, 0.34)
				payload.status_strength = maxf(payload.status_strength, 1.0)
		"daggers":
			payload.knockback_strength = maxf(payload.knockback_strength, 0.65 if heavy else 0.22)
			if not heavy and combo_depth >= 2:
				payload.critical_multiplier += 0.12
			if not heavy and combo_depth >= 3:
				payload.amount += 1
				_append_tag(payload, "flurry_peak")
		"whip":
			payload.knockback_strength = maxf(payload.knockback_strength, 1.05 if heavy else 0.42)
		"chains":
			payload.knockback_strength = maxf(payload.knockback_strength, 2.45 if heavy else 0.8)
			if payload.tags.has("pull") and toward_target.length_squared() > 0.0001:
				payload.knockback_direction = -toward_target
		"gauntlets":
			payload.knockback_strength = maxf(payload.knockback_strength, 2.15 if heavy else 0.75)
			if combo_depth >= 3:
				payload.stance_damage += 1
			if heavy and combo_depth >= 2:
				payload.knockback_up_strength += 1.15
				_append_tag(payload, "pressure_launcher")
		"flail":
			payload.knockback_strength = maxf(payload.knockback_strength, 3.35 if heavy else 1.35)
			if heavy:
				_append_tag(payload, "stored_momentum")
		"halberd":
			payload.knockback_strength = maxf(payload.knockback_strength, 2.35 if heavy else 0.9)
			if heavy and toward_target.length_squared() > 0.0001:
				payload.knockback_direction = -toward_target
				payload.knockback_up_strength = minf(payload.knockback_up_strength, 0.35)
				_append_tag(payload, "hook_pull")
		"boomerang":
			payload.hit_type = "projectile"
			payload.knockback_strength = maxf(payload.knockback_strength, 0.85 if heavy else 0.38)
			_append_tag(payload, "returning_weapon")
		"scythe":
			payload.knockback_strength = maxf(payload.knockback_strength, 1.85 if heavy else 0.72)
			if heavy and _target_health_ratio(target) <= 0.35:
				payload.amount += maxi(roundi(float(payload.amount) * 0.5), 1)
				payload.critical_multiplier += 0.55
				_append_tag(payload, "execution_window")
		"staff":
			payload.knockback_strength = maxf(payload.knockback_strength, 1.2 if heavy else 0.5)
			_append_tag(payload, "spellweave")
		"shuriken":
			payload.hit_type = "projectile"
			payload.knockback_strength = maxf(payload.knockback_strength, 0.45 if heavy else 0.18)
			var status_receiver: Node = target.get_node_or_null("StatusReceiver") if target != null else null
			var marked: bool = (
				status_receiver != null
				and status_receiver.has_method("has_status")
				and bool(status_receiver.call("has_status", "marked"))
			)
			if heavy and marked:
				payload.amount += maxi(roundi(float(payload.amount) * 0.45), 1)
				payload.critical_multiplier += 0.4
				_append_tag(payload, "consume_mark")
			elif not heavy:
				payload.status_effect = "marked"
				payload.status_duration = maxf(payload.status_duration, 3.0)
				payload.status_strength = maxf(payload.status_strength, 1.0)

	if payload.knockback_direction.length_squared() <= 0.0001 and toward_target.length_squared() > 0.0001:
		payload.knockback_direction = toward_target


static func apply_post_hit_identity(
	target: Node,
	payload: DamagePayload,
	weapon_class: String
) -> void:
	if target == null or payload == null:
		return
	if weapon_class == "shuriken" and payload.tags.has("consume_mark"):
		var status_receiver: Node = target.get_node_or_null("StatusReceiver")
		if status_receiver != null and status_receiver.has_method("remove_status"):
			status_receiver.call("remove_status", "marked")


static func build_return_payload(outbound: DamagePayload) -> DamagePayload:
	if outbound == null:
		return null
	var returned: DamagePayload = outbound.duplicate(true) as DamagePayload
	if returned == null:
		return null
	returned.amount = maxi(roundi(float(outbound.amount) * 0.65), 1)
	returned.stance_damage = maxi(roundi(float(outbound.stance_damage) * 0.55), 0)
	returned.knockback_strength *= 0.65
	returned.knockback_up_strength *= 0.4
	returned.source_name = outbound.source_name + " • Return"
	_append_tag(returned, "return_pass")
	return returned


static func _target_health_ratio(target: Node) -> float:
	if target == null:
		return 1.0
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver == null:
		return 1.0
	var maximum: float = float(hit_receiver.get("max_health"))
	var current: float = float(hit_receiver.get("current_health"))
	if maximum <= 0.0:
		return 1.0
	return clampf(current / maximum, 0.0, 1.0)


static func _append_tag(payload: DamagePayload, tag: String) -> void:
	if payload != null and tag != "" and not payload.tags.has(tag):
		payload.tags.append(tag)
