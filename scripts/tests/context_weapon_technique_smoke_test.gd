extends Node

const WeaponMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")
const WeaponTechniqueCatalogScript = preload("res://scripts/weapons/weapon_technique_catalog.gd")


func _ready() -> void:
	for weapon_class: String in WeaponMasteryCatalogScript.WEAPON_CLASSES:
		_validate_dash_pair(weapon_class)
		_validate_aerial_pair(weapon_class)
		_validate_ground_launcher(weapon_class)
	print("Context weapon technique smoke test passed for explicit Light/Heavy contexts across all 16 weapon classes.")


func _validate_dash_pair(weapon_class: String) -> void:
	for input_kind: String in ["light", "heavy"]:
		var context_id: String = WeaponTechniqueCatalogScript.get_dash_context(input_kind)
		assert(WeaponTechniqueCatalogScript.is_dash_context(context_id))
		assert(WeaponTechniqueCatalogScript.is_context_unlocked(weapon_class, context_id, 1))
		var base_attack: WeaponAttackDefinition = _make_base_attack(input_kind)
		var dash_attack: WeaponAttackDefinition = WeaponTechniqueCatalogScript.build_dash_attack(
			base_attack,
			weapon_class,
			context_id
		)
		assert(dash_attack != null)
		assert(dash_attack.attack_id == "technique_" + context_id + "_" + weapon_class)
		assert(dash_attack.extra_tags.has("context_dash"))
		assert(dash_attack.extra_tags.has(context_id))
		assert(dash_attack.movement_distance > 0.0)
		assert(dash_attack.input_kind == input_kind)
		if input_kind == "heavy":
			assert(dash_attack.hit_stop_duration >= 0.075)
		else:
			assert(dash_attack.startup_time < base_attack.startup_time)

		if weapon_class == "sword":
			assert(dash_attack.character_pose_id == "sword_" + context_id)
			if input_kind == "light":
				assert(dash_attack.display_name == "Passing Cut")
			else:
				assert(dash_attack.display_name == "Rush Break")

		var payload: DamagePayload = DamagePayload.new()
		payload.tags = ["weapon"]
		WeaponTechniqueCatalogScript.apply_context_tags(payload, dash_attack, 3, context_id)
		assert(payload.tags.has("technique_" + context_id))
		assert(payload.tags.has("context_combo"))
		assert(payload.tags.has("context_deep_combo"))


func _validate_aerial_pair(weapon_class: String) -> void:
	for input_kind: String in ["light", "heavy"]:
		var context_id: String = WeaponTechniqueCatalogScript.get_aerial_context(input_kind, 1.0)
		assert(WeaponTechniqueCatalogScript.is_aerial_context(context_id))
		assert(WeaponTechniqueCatalogScript.is_context_unlocked(weapon_class, context_id, 1))
		var base_attack: WeaponAttackDefinition = _make_base_attack(input_kind)
		var aerial_attack: WeaponAttackDefinition = WeaponTechniqueCatalogScript.build_aerial_attack(
			base_attack,
			weapon_class,
			context_id
		)
		assert(aerial_attack != null)
		assert(aerial_attack.attack_id == "technique_" + context_id + "_" + weapon_class)
		assert(aerial_attack.extra_tags.has("context_aerial"))
		assert(aerial_attack.extra_tags.has(context_id))
		assert(aerial_attack.input_kind == input_kind)
		if input_kind == "heavy":
			assert(aerial_attack.extra_tags.has("plunging"))
			assert(aerial_attack.stance_multiplier > base_attack.stance_multiplier)
		else:
			assert(aerial_attack.movement_distance > 0.0)

		if weapon_class == "sword":
			assert(aerial_attack.character_pose_id == "sword_" + context_id)
			if input_kind == "light":
				assert(aerial_attack.display_name == "Comet Slash")
			else:
				assert(aerial_attack.display_name == "Falling Edge")

	# Legacy aerial ids remain valid so authored prototype content does not break.
	for legacy_context: String in [
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_NEUTRAL,
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_FORWARD,
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_DOWN,
	]:
		assert(WeaponTechniqueCatalogScript.is_context_unlocked(weapon_class, legacy_context, 1))


func _validate_ground_launcher(weapon_class: String) -> void:
	var launcher_payload: DamagePayload = DamagePayload.new()
	launcher_payload.tags = ["weapon", "heavy"]
	var launcher_attack: WeaponAttackDefinition = WeaponAttackDefinition.new()
	launcher_attack.input_kind = "heavy"
	WeaponTechniqueCatalogScript.apply_ground_launcher(
		launcher_payload,
		launcher_attack,
		weapon_class,
		3,
		1,
		true
	)
	assert(launcher_payload.tags.has("technique_launcher"))
	assert(launcher_payload.knockback_up_strength > 0.0)


func _make_base_attack(input_kind: String) -> WeaponAttackDefinition:
	var attack := WeaponAttackDefinition.new()
	attack.attack_id = "test_" + input_kind
	attack.display_name = "Test " + input_kind.capitalize()
	attack.input_kind = input_kind
	attack.startup_time = 0.2 if input_kind == "heavy" else 0.14
	attack.active_time = 0.08
	attack.recovery_time = 0.24 if input_kind == "heavy" else 0.16
	attack.damage_multiplier = 1.4 if input_kind == "heavy" else 1.0
	attack.stance_multiplier = 1.3 if input_kind == "heavy" else 1.0
	attack.knockback_multiplier = 1.1 if input_kind == "heavy" else 1.0
	attack.attack_range = 2.5
	attack.cone_angle_degrees = 90.0
	attack.movement_distance = 0.25
	attack.movement_duration = 0.14
	attack.cancel_window_start_normalized = 0.7
	attack.extra_tags = ["weapon"]
	return attack
