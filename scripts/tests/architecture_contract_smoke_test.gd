extends Node

const FeatureRegistryScript = preload("res://scripts/systems/feature_registry.gd")
const StatCatalogScript = preload("res://scripts/systems/stat_catalog.gd")
const StartingLoadout: AbilityLoadout = preload("res://data/loadouts/grace_starting_loadout.tres")
const PracticeSword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")
const TrainingHammer: WeaponDefinition = preload("res://data/weapons/training_hammer.tres")
const TrainingSpear: WeaponDefinition = preload("res://data/weapons/training_spear.tres")

const REQUIRED_INPUT_ACTIONS: Array[String] = [
	"ui_up",
	"ui_down",
	"ui_accept",
	"ui_cancel",
	"interact",
	"weapon_light_attack",
	"weapon_heavy_attack",
	"spell_menu",
	"cast_spell",
	"dodge",
]

var failures: Array[String] = []


func _ready() -> void:
	run_tests()

	if failures.is_empty():
		print("ARCHITECTURE_CONTRACT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("ARCHITECTURE_CONTRACT_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func run_tests() -> void:
	validate_feature_registry_contract()
	validate_action_resource_pairs()
	validate_input_contract()
	validate_weapon_contracts()
	validate_ability_contracts()


func validate_feature_registry_contract() -> void:
	var registry: Dictionary = FeatureRegistryScript.load_registry()
	if not bool(registry.get("ok", false)):
		var raw_errors: Variant = registry.get("errors", [])
		if raw_errors is Array:
			for raw_error: Variant in raw_errors as Array:
				failures.append("registry: " + str(raw_error))
		else:
			failures.append("registry validation failed without an error list")
		return

	var raw_features: Variant = registry.get("features", [])
	if not raw_features is Array:
		failures.append("registry features must be an Array")
		return

	var features: Array = raw_features as Array
	if features.size() < 6:
		failures.append("registry should contain at least six permanent development features")

	var visible_count: int = 0
	var control_center_found: bool = false
	for raw_feature: Variant in features:
		if not raw_feature is Dictionary:
			failures.append("registry contains a non-Dictionary feature")
			continue

		var feature: Dictionary = raw_feature as Dictionary
		var feature_id: String = str(feature.get("id", "unknown"))
		if bool(feature.get("visible_in_launcher", false)):
			visible_count += 1
		if feature_id == "development_control_center":
			control_center_found = true

		validate_registered_resource_path(feature_id, "scene", str(feature.get("scene", "")))
		validate_registered_resource_array(
			feature_id,
			"validation_scenes",
			feature.get("validation_scenes", [])
		)
		validate_registered_resource_array(
			feature_id,
			"automated_tests",
			feature.get("automated_tests", [])
		)

	if visible_count < 5:
		failures.append("Control Center should expose at least five launchable development features")
	if not control_center_found:
		failures.append("registry is missing development_control_center")


func validate_registered_resource_path(feature_id: String, field_name: String, path: String) -> void:
	if path == "":
		failures.append(feature_id + " has an empty " + field_name)
		return
	if not ResourceLoader.exists(path):
		failures.append(feature_id + " has a missing " + field_name + ": " + path)


func validate_registered_resource_array(feature_id: String, field_name: String, raw_paths: Variant) -> void:
	if not raw_paths is Array:
		failures.append(feature_id + " " + field_name + " must be an Array")
		return
	for raw_path: Variant in raw_paths as Array:
		validate_registered_resource_path(feature_id, field_name, str(raw_path))


func validate_action_resource_pairs() -> void:
	var defaults: Dictionary = StatCatalogScript.get_default_stats()
	for resource_id: String in StatCatalogScript.ACTION_RESOURCE_IDS:
		var maximum_id: String = "max_" + resource_id
		if not defaults.has(resource_id):
			failures.append("StatCatalog is missing current action resource: " + resource_id)
		if not defaults.has(maximum_id):
			failures.append("StatCatalog is missing maximum action resource: " + maximum_id)
		if int(defaults.get(resource_id, 0)) < 0:
			failures.append(resource_id + " default must not be negative")
		if int(defaults.get(maximum_id, 0)) <= 0:
			failures.append(maximum_id + " default must be positive")
		if int(defaults.get(resource_id, 0)) > int(defaults.get(maximum_id, 0)):
			failures.append(resource_id + " default exceeds " + maximum_id)


func validate_input_contract() -> void:
	for action_name: String in REQUIRED_INPUT_ACTIONS:
		if not InputMap.has_action(action_name):
			failures.append("missing semantic input action: " + action_name)
			continue
		if InputMap.action_get_events(action_name).is_empty():
			failures.append("semantic input action has no events: " + action_name)


func validate_weapon_contracts() -> void:
	validate_weapon(PracticeSword, "sword")
	validate_weapon(TrainingHammer, "hammer")
	validate_weapon(TrainingSpear, "lance")


func validate_weapon(weapon: WeaponDefinition, expected_class: String) -> void:
	if weapon == null:
		failures.append("missing weapon resource for class " + expected_class)
		return
	if weapon.display_name.strip_edges() == "":
		failures.append(expected_class + " weapon has an empty display name")
	if weapon.weapon_class != expected_class:
		failures.append(
			weapon.display_name
			+ " expected weapon_class "
			+ expected_class
			+ " but found "
			+ weapon.weapon_class
		)
	if weapon.moveset == null:
		failures.append(weapon.display_name + " has no moveset")
		return

	for graph_error: String in weapon.moveset.validate_graph():
		failures.append(weapon.display_name + " graph: " + graph_error)

	if weapon.moveset.get_entry_attack("light") == null:
		failures.append(weapon.display_name + " has no Light entry attack")
	if weapon.moveset.get_entry_attack("heavy") == null:
		failures.append(weapon.display_name + " has no Heavy entry attack")

	for attack: WeaponAttackDefinition in weapon.moveset.attacks:
		if attack == null:
			failures.append(weapon.display_name + " contains a null attack")
			continue
		var payload: DamagePayload = attack.build_payload(weapon)
		if payload == null:
			failures.append(weapon.display_name + " failed to build payload for " + attack.attack_id)
			continue
		if payload.source_name.strip_edges() == "":
			failures.append(weapon.display_name + " payload has no source name: " + attack.attack_id)
		if not payload.tags.has("weapon") or not payload.tags.has("melee"):
			failures.append(weapon.display_name + " payload lacks weapon/melee tags: " + attack.attack_id)


func validate_ability_contracts() -> void:
	if StartingLoadout == null:
		failures.append("Grace starting loadout is missing")
		return

	var abilities: Array[AbilityDefinition] = StartingLoadout.get_learned_abilities()
	if abilities.is_empty():
		failures.append("Grace starting loadout has no learned abilities")
		return

	var defaults: Dictionary = StatCatalogScript.get_default_stats()
	var seen_spell_ids: Dictionary = {}
	for ability: AbilityDefinition in abilities:
		if ability == null:
			failures.append("Grace starting loadout contains a null ability")
			continue

		var spell_id: String = ability.get_spell_id()
		if spell_id.strip_edges() == "":
			failures.append("ability has an empty spell id: " + ability.display_name)
		elif seen_spell_ids.has(spell_id):
			failures.append("duplicate ability spell id: " + spell_id)
		else:
			seen_spell_ids[spell_id] = true

		if ability.display_name.strip_edges() == "":
			failures.append(spell_id + " has an empty display name")
		if ability.ability_scene == null:
			failures.append(spell_id + " has no ability scene")

		var payload: Resource = ability.get_action_payload()
		var delivery_type: String = ability.get_delivery_type()
		if payload == null and delivery_type != "instant":
			failures.append(spell_id + " has no action payload for delivery type " + delivery_type)

		for scaling_stat: String in ability.get_scaling_stats():
			if not defaults.has(scaling_stat):
				failures.append(spell_id + " references unknown scaling stat: " + scaling_stat)
