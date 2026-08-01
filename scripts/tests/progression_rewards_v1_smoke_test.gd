extends Node

const AlchemyCauldronScript = preload(
	"res://scripts/alchemy/alchemy_cauldron.gd"
)
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

const REWARD_IDS: Array[String] = [
	"charged_firebolt",
	"chain_lightning",
	"piercing_ice_lance",
	"alchemy_recipe_insight",
	"gremlin_pounce",
]

var failures: Array[String] = []
var old_unlocks: Dictionary = {}
var old_species_snapshot: Dictionary = {}
var cauldron: Node


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	old_unlocks = GameState.get_unlock_snapshot()
	old_species_snapshot = SpeciesKnowledge.get_snapshot()
	_clear_reward_unlocks()
	SpeciesKnowledge.reset_species("gremlin")

	var tracker: Node = get_node_or_null(
		"/root/FullMenuDirector/ProgressionTracker"
	)
	assert_true(tracker != null, "Progression tracker exists")
	if tracker == null:
		_restore_state()
		_finish()
		return

	assert_true(
		not _ability_has_modifier(FireboltAbility, "charged_firebolt"),
		"Charged Firebolt is inactive while locked"
	)
	assert_true(
		not _ability_has_modifier(LightningSparkAbility, "chain_lightning"),
		"Chain Lightning is inactive while locked"
	)
	assert_true(
		not _ability_has_modifier(IceLanceAbility, "piercing_ice_lance"),
		"Piercing Ice Lance is inactive while locked"
	)

	_grant_reward("charged_firebolt")
	_grant_reward("chain_lightning")
	_grant_reward("piercing_ice_lance")
	assert_true(
		_ability_has_modifier(FireboltAbility, "charged_firebolt"),
		"Charged Firebolt activates through its challenge unlock"
	)
	assert_true(
		_ability_has_modifier(LightningSparkAbility, "chain_lightning"),
		"Chain Lightning activates through its challenge unlock"
	)
	assert_true(
		_ability_has_modifier(IceLanceAbility, "piercing_ice_lance"),
		"Piercing Ice Lance activates through its challenge unlock"
	)
	var ice_payload: Resource = (
		SpellModifierRegistryScript.build_modified_payload_for_ability(
			IceLanceAbility
		)
	)
	assert_true(
		ice_payload is DamagePayload
		and (ice_payload as DamagePayload).tags.has("piercing"),
		"Piercing Ice Lance modifies the real payload"
	)
	var lightning_payload: Resource = (
		SpellModifierRegistryScript.build_modified_payload_for_ability(
			LightningSparkAbility
		)
	)
	assert_true(
		lightning_payload is DamagePayload
		and (lightning_payload as DamagePayload).tags.has("chain_lightning"),
		"Chain Lightning modifies the real payload"
	)

	cauldron = AlchemyCauldronScript.new()
	add_child(cauldron)
	await get_tree().process_frame
	cauldron.set("selected_ingredients", ["life_bloom", "springwater"])
	cauldron.set("catalyst", "none")
	var locked_insight: Dictionary = cauldron.call("get_recipe_insight") as Dictionary
	assert_equal(
		locked_insight.get("state"),
		"locked",
		"Cauldron insight remains locked before Kitchen Chemistry"
	)
	_grant_reward("alchemy_recipe_insight")
	cauldron.call("refresh_menu")
	var promising: Dictionary = cauldron.call("get_recipe_insight") as Dictionary
	assert_equal(promising.get("state"), "promising", "Known chemistry detects a promising pair")
	assert_equal(
		promising.get("required_catalyst"),
		"fire",
		"Recipe insight identifies the required treatment"
	)
	cauldron.set("catalyst", "fire")
	var stable: Dictionary = cauldron.call("get_recipe_insight") as Dictionary
	assert_equal(stable.get("state"), "stable", "Correct treatment marks the formula brew-ready")
	assert_equal(stable.get("recipe_id"), "healing_potion", "Insight resolves the matching formula")
	cauldron.set("selected_ingredients", ["life_bloom", "spark_ore"])
	var unstable: Dictionary = cauldron.call("get_recipe_insight") as Dictionary
	assert_equal(unstable.get("state"), "unstable", "Invalid ingredient pairs are identified before consumption")
	var alchemy_debug: Dictionary = cauldron.call("get_debug_data") as Dictionary
	assert_true(
		bool(alchemy_debug.get("recipe_insight_label_present", false)),
		"Alchemy menu renders the insight readout"
	)

	SpeciesKnowledge.add_discovery("gremlin", "reward_test_sighting", "Reward Test Sighting", 1)
	SpeciesKnowledge.add_discovery("gremlin", "reward_test_behavior", "Reward Test Behavior", 1)
	assert_true(
		SpeciesKnowledge.is_familiar_unlocked("gremlin"),
		"Gremlin familiar is available for the technique test"
	)
	_grant_reward("gremlin_pounce")
	tracker.call("synchronize_runtime_rewards")
	assert_true(
		SpeciesKnowledge.has_unlock("gremlin", "gremlin_pounce"),
		"Pack Scholar synchronizes Pounce into SpeciesKnowledge"
	)
	var equip_result: Dictionary = SpeciesKnowledge.set_equipped_familiar_species("gremlin")
	assert_true(bool(equip_result.get("ok", false)), "Gremlin familiar can be equipped")
	var pounce_result: Dictionary = SpeciesKnowledge.toggle_familiar_technique(
		"gremlin",
		"pounce"
	)
	assert_true(bool(pounce_result.get("ok", false)), "Pounce can be equipped after its challenge reward")
	assert_true(
		(pounce_result.get("loadout", {}) as Dictionary).get("technique_ids", []).has("pounce"),
		"Pounce enters the live familiar loadout"
	)

	var runtime_rows: Array = tracker.call("get_reward_runtime_rows") as Array
	assert_equal(runtime_rows.size(), 5, "Reward runtime catalog covers all five starter challenges")
	assert_equal(_active_count(runtime_rows), 5, "Every unlocked starter reward reaches its runtime consumer")
	var challenge_rows: Array = tracker.call("get_challenge_rows") as Array
	for reward_id: String in REWARD_IDS:
		assert_true(
			_challenge_reward_is_runtime_active(challenge_rows, reward_id),
			"Codex reports active runtime reward: " + reward_id
		)

	cauldron.queue_free()
	_restore_state()
	_finish()


func _ability_has_modifier(ability: Resource, modifier_id: String) -> bool:
	for definition: Dictionary in SpellModifierRegistryScript.get_active_modifier_definitions_for_ability(
		ability
	):
		if str(definition.get("id", "")) == modifier_id:
			return true
	return false


func _grant_reward(reward_id: String) -> void:
	GameState.grant_unlock(
		reward_id,
		{
			"id": reward_id,
			"display_name": reward_id.replace("_", " ").capitalize(),
			"type": "modifier",
			"source": "Progression Rewards v1 smoke test",
		}
	)


func _active_count(rows: Array) -> int:
	var count: int = 0
	for raw: Variant in rows:
		if raw is Dictionary and bool((raw as Dictionary).get("active", false)):
			count += 1
	return count


func _challenge_reward_is_runtime_active(
	rows: Array,
	reward_id: String
) -> bool:
	for raw: Variant in rows:
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw as Dictionary
		var challenge_id: String = str(row.get("challenge_id", ""))
		var definition: Dictionary = (
			load("res://scripts/progression/progression_challenge_catalog.gd")
			.call("get_definition", challenge_id)
		)
		if str(definition.get("reward_id", "")) != reward_id:
			continue
		return bool(row.get("reward_runtime_active", false))
	return false


func _clear_reward_unlocks() -> void:
	for reward_id: String in REWARD_IDS:
		GameState.revoke_unlock(reward_id)


func _restore_state() -> void:
	SpeciesKnowledge.apply_snapshot(old_species_snapshot)
	var current: Dictionary = GameState.get_unlock_snapshot()
	for raw_key: Variant in current.keys():
		GameState.revoke_unlock(str(raw_key))
	for raw_key: Variant in old_unlocks.keys():
		var value: Variant = old_unlocks[raw_key]
		GameState.grant_unlock(
			str(raw_key),
			(value as Dictionary).duplicate(true) if value is Dictionary else {}
		)
	var tracker: Node = get_node_or_null(
		"/root/FullMenuDirector/ProgressionTracker"
	)
	if tracker != null and tracker.has_method("synchronize_runtime_rewards"):
		tracker.call("synchronize_runtime_rewards")


func _finish() -> void:
	if failures.is_empty():
		print("PROGRESSION_REWARDS_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PROGRESSION_REWARDS_V1_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
