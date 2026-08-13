extends RefCounted
class_name GraceAnimationSemanticResolver

# Presentation-only translation from gameplay state/attack identity into imported
# animation semantics. It does not play clips or modify gameplay timing.


static func resolve_state_semantic(animation_state: String) -> String:
	match animation_state:
		"idle":
			return "idle"
		"locomotion":
			return "run"
		"jump":
			return "jump"
		"fall":
			return "fall"
		"dodge":
			return "dodge"
		"hit":
			return "hit"
		_:
			return ""


static func resolve_attack_semantic(
	weapon_class: String,
	attack: WeaponAttackDefinition
) -> String:
	if attack == null or weapon_class == "":
		return ""

	if attack.extra_tags.has("dash_light"):
		return weapon_class + "_dash_light"
	if attack.extra_tags.has("dash_heavy"):
		return weapon_class + "_dash_heavy"
	if attack.extra_tags.has("aerial_light"):
		return weapon_class + "_aerial_light"
	if attack.extra_tags.has("aerial_heavy"):
		return weapon_class + "_aerial_heavy"

	if weapon_class == "sword":
		return _resolve_sword_ground_semantic(attack.attack_id)
	return ""


static func resolve_requested_semantic(
	animation_state: String,
	weapon_class: String = "",
	attack: WeaponAttackDefinition = null
) -> String:
	if animation_state == "attack":
		return resolve_attack_semantic(weapon_class, attack)
	return resolve_state_semantic(animation_state)


static func _resolve_sword_ground_semantic(attack_id: String) -> String:
	match attack_id:
		"sword_l1":
			return "sword_light_1"
		"sword_l2":
			return "sword_light_2"
		"sword_l3":
			return "sword_light_3"
		"sword_l4":
			return "sword_light_4"
		"sword_reprise":
			return "sword_reprise"
		"sword_h0":
			return "sword_heavy_neutral"
		"sword_h1":
			return "sword_heavy_1"
		"sword_h2":
			return "sword_heavy_2"
		"sword_h3":
			return "sword_heavy_3"
		"sword_h4":
			return "sword_heavy_4"
		_:
			return ""
