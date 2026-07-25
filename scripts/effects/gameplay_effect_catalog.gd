extends RefCounted
class_name GameplayEffectCatalog

const DEFINITIONS: Dictionary = {
	"wayfarer_stride": {
		"id": "wayfarer_stride",
		"name": "Wayfarer's Stride",
		"description": "Stamina recovers 25% faster.",
		"tags": ["passive", "recovery", "movement"],
		"channels": {"stamina_recovery_rate": {"multiply": 1.25}},
	},
	"apprentice_flow": {
		"id": "apprentice_flow",
		"name": "Apprentice's Flow",
		"description": "Spell mana costs are reduced by 20%.",
		"tags": ["passive", "magic", "resource_cost"],
		"channels": {"mana_cost": {"multiply": 0.8}},
	},
	"ironweave_guard": {
		"id": "ironweave_guard",
		"name": "Ironweave Guard",
		"description": "Grace takes 25% less stance damage and guarding costs 15% less stamina.",
		"tags": ["passive", "defense", "guard"],
		"channels": {
			"stance_damage_taken": {"multiply": 0.75},
			"guard_stamina_cost": {"multiply": 0.85},
		},
	},
	"vital_restoration": {
		"id": "vital_restoration",
		"name": "Vital Restoration",
		"description": "Health restoration is increased by 25%.",
		"tags": ["passive", "healing", "item"],
		"channels": {"health_restore": {"multiply": 1.25}},
	},
	"resonant_focus": {
		"id": "resonant_focus",
		"name": "Resonant Focus",
		"description": "Spell Focus costs are reduced by 20%.",
		"tags": ["passive", "magic", "focus"],
		"channels": {"focus_cost": {"multiply": 0.8}},
	},
	"merchant_rapport": {
		"id": "merchant_rapport",
		"name": "Merchant Rapport",
		"description": "Shop purchases cost 10% less and equipment sells for 10% more.",
		"tags": ["passive", "economy", "shop"],
		"channels": {
			"shop_buy_price": {"multiply": 0.9},
			"shop_sell_price": {"multiply": 1.1},
		},
	},
	"fortunes_favor": {
		"id": "fortunes_favor",
		"name": "Fortune's Favor",
		"description": "Currency rewards are increased by 20%.",
		"tags": ["passive", "economy", "reward"],
		"channels": {"currency_reward": {"multiply": 1.2}},
	},
}


static func has_effect(effect_id: String) -> bool:
	return DEFINITIONS.has(effect_id)


static func get_definition(effect_id: String) -> Dictionary:
	if not DEFINITIONS.has(effect_id):
		return {}
	return (DEFINITIONS[effect_id] as Dictionary).duplicate(true)


static func get_display_name(effect_id: String) -> String:
	return str(get_definition(effect_id).get("name", effect_id.capitalize()))


static func get_description(effect_id: String) -> String:
	return str(get_definition(effect_id).get("description", ""))


static func get_channel_modifier(effect_id: String, channel_id: String) -> Dictionary:
	var definition: Dictionary = get_definition(effect_id)
	var channels: Dictionary = definition.get("channels", {}) as Dictionary
	if not channels.has(channel_id):
		return {}
	return (channels[channel_id] as Dictionary).duplicate(true)


static func get_effect_rows(effect_ids: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for effect_id: String in effect_ids:
		var definition: Dictionary = get_definition(effect_id)
		if not definition.is_empty():
			rows.append(definition)
	return rows
