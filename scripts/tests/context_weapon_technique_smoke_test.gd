extends Node

const WeaponMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")
const WeaponTechniqueCatalogScript = preload("res://scripts/weapons/weapon_technique_catalog.gd")


func _ready() -> void:
	for weapon_class: String in WeaponMasteryCatalogScript.WEAPON_CLASSES:
		assert(WeaponTechniqueCatalogScript.is_context_unlocked(weapon_class, "dash", 1))
		var base_attack: WeaponAttackDefinition = WeaponAttackDefinition.new()
		base_attack.attack_id = "test_light"
		base_attack.display_name = "Test Light"
		base_attack.input_kind = "light"
		base_attack.damage_multiplier = 1.0
		base_attack.stance_multiplier = 1.0
		base_attack.extra_tags = ["weapon"]
		var dash_attack: WeaponAttackDefinition = WeaponTechniqueCatalogScript.build_dash_attack(
			base_attack,
			weapon_class
		)
		assert(dash_attack != null)
		assert(dash_attack.attack_id.begins_with("technique_dash_"))
		assert(dash_attack.extra_tags.has("context_dash"))
		assert(dash_attack.movement_distance > 0.0)
		var payload: DamagePayload = DamagePayload.new()
		payload.tags = ["weapon"]
		WeaponTechniqueCatalogScript.apply_context_tags(payload, dash_attack, 3, "dash")
		assert(payload.tags.has("technique_dash"))
		assert(payload.tags.has("context_combo"))
		assert(payload.tags.has("context_deep_combo"))
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
		for aerial_context: String in [
			WeaponTechniqueCatalogScript.CONTEXT_AERIAL_NEUTRAL,
			WeaponTechniqueCatalogScript.CONTEXT_AERIAL_FORWARD,
			WeaponTechniqueCatalogScript.CONTEXT_AERIAL_DOWN,
		]:
			assert(WeaponTechniqueCatalogScript.is_context_unlocked(weapon_class, aerial_context, 1))
			var aerial_attack: WeaponAttackDefinition = WeaponTechniqueCatalogScript.build_aerial_attack(
				base_attack,
				weapon_class,
				aerial_context
			)
			assert(aerial_attack != null)
			assert(aerial_attack.extra_tags.has("context_aerial"))
			assert(aerial_attack.extra_tags.has(aerial_context))
	print("Context weapon technique smoke test passed for all 16 weapon classes.")
