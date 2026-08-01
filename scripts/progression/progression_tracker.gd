extends "res://scripts/progression/progression_tracker_core.gd"

# Runtime bridge for challenge rewards. The progression core owns counting,
# persistence, and unlock grants; this layer proves that each reward is visible
# to the gameplay system that consumes it.

const SpellModifierRegistryScript = preload(
	"res://scripts/abilities/spell_modifier_registry.gd"
)
const FireboltAbility: Resource = preload(
	"res://data/abilities/firebolt_ability.tres"
)
const IceLanceAbility: Resource = preload(
	"res://data/abilities/ice_lance_ability.tres"
)
const LightningSparkAbility: Resource = preload(
	"res://data/abilities/lightning_spark_ability.tres"
)

const REWARD_ORDER: Array[String] = [
	"charged_firebolt",
	"chain_lightning",
	"piercing_ice_lance",
	"alchemy_recipe_insight",
	"gremlin_pounce",
]

const REWARD_RUNTIME_DEFS: Dictionary = {
	"charged_firebolt": {
		"name": "Charged Firebolt",
		"system": "AbilityCaster",
		"description": "Holding Firebolt charges damage, stance damage, scale, speed, and status duration.",
		"test_route": "Equip Firebolt, hold the cast trigger, then release.",
	},
	"chain_lightning": {
		"name": "Chain Lightning",
		"system": "SpellModifierRegistry",
		"description": "Lightning Spark arcs from its first victim to nearby unused enemy targets.",
		"test_route": "Cast Lightning Spark into a close group of three enemies.",
	},
	"piercing_ice_lance": {
		"name": "Piercing Ice Lance",
		"system": "SpellModifierRegistry",
		"description": "Ice Lance gains speed, stance pressure, and a four-target piercing budget.",
		"test_route": "Line up several enemies and cast Ice Lance through them.",
	},
	"alchemy_recipe_insight": {
		"name": "Alchemy Recipe Insight",
		"system": "AlchemyCauldron",
		"description": "A selected ingredient pair is classified as unstable, promising, or brew-ready before ingredients are consumed.",
		"test_route": "Select two ingredients at a cauldron and compare the insight before and after elemental treatment.",
	},
	"gremlin_pounce": {
		"name": "Gremlin Pounce",
		"system": "SpeciesKnowledge",
		"description": "Pounce appears as an equippable Gremlin familiar technique.",
		"test_route": "Open Soul → Summon Familiar and equip Pounce on the Gremlin blueprint.",
	},
}


func _ready() -> void:
	super._ready()
	if not GameState.unlock_changed.is_connected(_on_runtime_unlock_changed):
		GameState.unlock_changed.connect(_on_runtime_unlock_changed)
	if not GameState.save_loaded.is_connected(_on_runtime_save_loaded):
		GameState.save_loaded.connect(_on_runtime_save_loaded)
	call_deferred("synchronize_runtime_rewards")


func synchronize_runtime_rewards() -> Dictionary:
	var synchronized: Array[String] = []
	for reward_id: String in REWARD_ORDER:
		if not GameState.has_unlock(reward_id):
			continue
		if _apply_runtime_reward(reward_id):
			synchronized.append(reward_id)
	return {
		"synchronized": synchronized,
		"rows": get_reward_runtime_rows(),
	}


func get_reward_runtime_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for reward_id: String in REWARD_ORDER:
		rows.append(get_reward_runtime_row(reward_id))
	return rows


func get_reward_runtime_row(reward_id: String) -> Dictionary:
	var definition: Dictionary = (
		(REWARD_RUNTIME_DEFS[reward_id] as Dictionary).duplicate(true)
		if REWARD_RUNTIME_DEFS.has(reward_id)
		else {}
	)
	if definition.is_empty():
		return {}
	var unlocked: bool = GameState.has_unlock(reward_id)
	var active: bool = unlocked and _is_reward_active_in_runtime(reward_id)
	definition["id"] = reward_id
	definition["unlocked"] = unlocked
	definition["active"] = active
	definition["state"] = (
		"ACTIVE" if active else ("SYNCING" if unlocked else "LOCKED")
	)
	return definition


func get_challenge_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = super.get_challenge_rows()
	for row: Dictionary in rows:
		var challenge_id: String = str(row.get("challenge_id", ""))
		var challenge: Dictionary = ChallengeCatalogScript.get_definition(challenge_id)
		var reward_id: String = str(challenge.get("reward_id", ""))
		var runtime: Dictionary = get_reward_runtime_row(reward_id)
		if runtime.is_empty():
			continue
		var details: Array[String] = []
		for raw_detail: Variant in row.get("details", []):
			details.append(str(raw_detail))
		details.append(
			"Runtime: "
			+ str(runtime.get("state", "LOCKED"))
			+ " in "
			+ str(runtime.get("system", "gameplay"))
		)
		details.append("Test: " + str(runtime.get("test_route", "")))
		row["details"] = details
		row["reward_runtime_state"] = str(runtime.get("state", "LOCKED"))
		row["reward_runtime_active"] = bool(runtime.get("active", false))
		row["reward_system"] = str(runtime.get("system", ""))
	return rows


func _apply_runtime_reward(reward_id: String) -> bool:
	match reward_id:
		"gremlin_pounce":
			return _synchronize_gremlin_pounce()
		"charged_firebolt", "chain_lightning", "piercing_ice_lance", "alchemy_recipe_insight":
			return true
	return false


func _is_reward_active_in_runtime(reward_id: String) -> bool:
	match reward_id:
		"charged_firebolt":
			return _ability_has_active_modifier(FireboltAbility, reward_id)
		"chain_lightning":
			return _ability_has_active_modifier(LightningSparkAbility, reward_id)
		"piercing_ice_lance":
			return _ability_has_active_modifier(IceLanceAbility, reward_id)
		"alchemy_recipe_insight":
			return GameState.has_unlock(reward_id)
		"gremlin_pounce":
			var species: Node = get_node_or_null("/root/SpeciesKnowledge")
			return (
				species != null
				and species.has_method("has_unlock")
				and bool(species.call("has_unlock", "gremlin", "gremlin_pounce"))
			)
	return false


func _ability_has_active_modifier(
	ability: Resource,
	modifier_id: String
) -> bool:
	for definition: Dictionary in SpellModifierRegistryScript.get_active_modifier_definitions_for_ability(
		ability
	):
		if str(definition.get("id", "")) == modifier_id:
			return true
	return false


func _synchronize_gremlin_pounce() -> bool:
	var species: Node = get_node_or_null("/root/SpeciesKnowledge")
	if species == null:
		return false
	var earned_value: Variant = species.get("earned_unlocks")
	if not earned_value is Dictionary:
		return false
	var earned: Dictionary = earned_value as Dictionary
	var gremlin_value: Variant = earned.get("gremlin", {})
	var gremlin_unlocks: Dictionary = (
		gremlin_value as Dictionary if gremlin_value is Dictionary else {}
	)
	var newly_synchronized: bool = not gremlin_unlocks.has("gremlin_pounce")
	gremlin_unlocks["gremlin_pounce"] = "Pounce Technique"
	earned["gremlin"] = gremlin_unlocks
	species.set("earned_unlocks", earned)
	if newly_synchronized and species.has_signal("unlock_earned"):
		species.emit_signal(
			"unlock_earned",
			"gremlin",
			"gremlin_pounce",
			"Pounce Technique"
		)
	return (
		species.has_method("has_unlock")
		and bool(species.call("has_unlock", "gremlin", "gremlin_pounce"))
	)


func _on_runtime_unlock_changed(unlock_id: String, value: bool) -> void:
	if value and REWARD_ORDER.has(unlock_id):
		_apply_runtime_reward(unlock_id)


func _on_runtime_save_loaded(_save_data: Dictionary) -> void:
	call_deferred("synchronize_runtime_rewards")
