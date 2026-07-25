extends Node

const WeaponInfusionCatalogScript = preload("res://scripts/weapons/weapon_infusion_catalog.gd")


func _ready() -> void:
	for infusion_id: String in WeaponInfusionCatalogScript.INFUSION_IDS:
		assert(WeaponInfusionCatalogScript.is_valid(infusion_id))
		var definition: Dictionary = WeaponInfusionCatalogScript.get_definition(infusion_id)
		assert(str(definition.get("element", "neutral")) != "neutral")
		var payload: DamagePayload = DamagePayload.new()
		payload.amount = 2
		payload.stance_damage = 1
		payload.source_name = "Infusion Smoke Test"
		payload.tags = ["weapon"]
		WeaponInfusionCatalogScript.apply_to_payload(payload, infusion_id)
		assert(payload.element == str(definition.get("element", "")))
		assert(payload.tags.has("weapon_infusion"))
		assert(payload.tags.has(infusion_id))
		assert(payload.status_effect == str(definition.get("status", "")))
	print("Weapon infusion smoke test passed.")
