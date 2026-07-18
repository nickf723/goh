extends Node

const FeatureRegistryScript = preload("res://scripts/systems/feature_registry.gd")
const StatCatalogScript = preload("res://scripts/systems/stat_catalog.gd")
const EnemyActionSelectionBrainScript = preload("res://scripts/enemies/enemy_action_selection_brain.gd")
const EnemyThreatAwareActionBrainScript = preload("res://scripts/enemies/enemy_threat_aware_action_brain.gd")
const StartingLoadout: AbilityLoadout = preload("res://data/loadouts/grace_starting_loadout.tres")
const PracticeSword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")
const TrainingHammer: WeaponDefinition = preload("res://data/weapons/training_hammer.tres")
const TrainingSpear: WeaponDefinition = preload("res://data/weapons/training_spear.tres")
const GremlinBiteOption: EnemyActionOption = preload("res://data/enemy_action_options/gremlin_bite_option.tres")
const GremlinPounceOption: EnemyActionOption = preload("res://data/enemy_action_options/gremlin_pounce_option.tres")
const GremlinBackstepOption: EnemyActionOption = preload("res://data/enemy_action_options/gremlin_backstep_option.tres")

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
	validate_enemy_action_selection_contract()
	validate_enemy_threat_awareness_contract()
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


func validate_enemy_action_selection_contract() -> void:
	if (
		GremlinBiteOption == null
		or GremlinPounceOption == null
		or GremlinBackstepOption == null
	):
		failures.append("Gremlin offense and defense options must load")
		return

	var brain = EnemyActionSelectionBrainScript.new()
	var options: Array[EnemyActionOption] = [
		GremlinBiteOption,
		GremlinPounceOption,
		GremlinBackstepOption,
	]
	brain.action_options = options
	brain.personality_id = "skittish"

	var close_choice: EnemyActionOption = brain.select_action(0.9)
	if close_choice != GremlinBiteOption:
		failures.append("Gremlin must prefer Close Bite at 0.9m while Bite is ready")

	var mid_choice: EnemyActionOption = brain.select_action(2.2)
	if mid_choice != GremlinPounceOption:
		failures.append("Gremlin must select Pounce at 2.2m")

	brain.start_option_cooldown(GremlinPounceOption)
	if brain.get_option_cooldown(GremlinPounceOption) <= 0.0:
		failures.append("Pounce must enter its independent reuse cooldown")

	var close_during_pounce_cooldown: EnemyActionOption = brain.select_action(0.9)
	if close_during_pounce_cooldown != GremlinBiteOption:
		failures.append("Pounce cooldown must not block Close Bite")

	var mid_during_pounce_cooldown: EnemyActionOption = brain.select_action(2.2)
	if mid_during_pounce_cooldown != null:
		failures.append("Cooling Pounce must be unavailable at mid-range")

	brain.option_cooldowns.clear()
	brain.start_option_cooldown(GremlinBiteOption)
	var defense_during_bite_cooldown: EnemyActionOption = brain.select_action(0.9)
	if defense_during_bite_cooldown != GremlinBackstepOption:
		failures.append("Cooling Close Bite must open the Backstep defense at close range")

	if not GremlinBackstepOption.is_defensive_option():
		failures.append("Backstep must be represented as a defense, not an attack")

	var backstep: EnemyDefenseDefinition = GremlinBackstepOption.get_action() as EnemyDefenseDefinition
	if backstep == null:
		failures.append("Backstep option must resolve an EnemyDefenseDefinition")
	else:
		if backstep.get_movement_mode() != "away_from_target":
			failures.append("Backstep must move away from the committed target direction")
		if backstep.get_active_move_speed_multiplier() <= 1.0:
			failures.append("Backstep active movement must be faster than ordinary movement")

	if not GremlinBiteOption.can_interrupt_post_miss_retreat:
		failures.append("Close Bite must be allowed to interrupt retreat when cornered")

	brain.free()


func validate_enemy_threat_awareness_contract() -> void:
	var source: Node3D = Node3D.new()
	source.position = Vector3.ZERO
	var threatened_actor: Node3D = Node3D.new()
	threatened_actor.position = Vector3(0.0, 0.0, -1.2)

	var heavy_threat: CombatThreat = CombatThreat.new().configure(
		"sword_h0",
		"Practice Sword • Guardbreaker",
		source,
		1.0,
		Vector3.FORWARD,
		0.32,
		0.11,
		2.9,
		68.0,
		1.25,
		0.85,
		3.0,
		["weapon", "melee", "heavy", "sword", "guard_break"]
	)
	heavy_threat.announced_at_msec = Time.get_ticks_msec() - 100

	if not heavy_threat.contains_point(threatened_actor.position, 0.2):
		failures.append("Heavy sword threat must predict the close target inside its swing")
	if not GremlinBackstepOption.can_respond_to_threat(heavy_threat):
		failures.append("Backstep must answer a telegraphed heavy melee weapon threat")

	var light_threat: CombatThreat = CombatThreat.new().configure(
		"sword_l1",
		"Practice Sword • Opening Cut",
		source,
		1.0,
		Vector3.FORWARD,
		0.13,
		0.07,
		2.7,
		112.0,
		1.1,
		0.85,
		1.5,
		["weapon", "melee", "light", "sword"]
	)
	light_threat.announced_at_msec = Time.get_ticks_msec() - 90
	if GremlinBackstepOption.can_respond_to_threat(light_threat):
		failures.append("Backstep v1 must not react to a light sword cut after the safe window closes")

	var sensor: EnemyThreatSensor = EnemyThreatSensor.new()
	sensor.actor = threatened_actor
	sensor.base_reaction_delay = 0.0
	sensor.receive_combat_threat(heavy_threat)
	var sensed_threat: CombatThreat = sensor.get_best_actionable_threat(threatened_actor.position)
	if sensed_threat != heavy_threat:
		failures.append("Threat sensor must surface an actionable heavy sword threat")

	var threat_brain = EnemyThreatAwareActionBrainScript.new()
	threat_brain.action_options = [
		GremlinBiteOption,
		GremlinPounceOption,
		GremlinBackstepOption,
	]
	threat_brain.personality_id = "skittish"
	var threat_response: EnemyActionOption = threat_brain.select_threat_response(0.9, heavy_threat)
	if threat_response != GremlinBackstepOption:
		failures.append("Gremlin must choose Backstep as its compatible heavy-sword response")

	sensor.acknowledge_threat(heavy_threat)
	if sensor.get_best_actionable_threat(threatened_actor.position) != null:
		failures.append("Acknowledged threats must leave the sensor queue")

	threat_brain.free()
	sensor.free()
	source.free()
	threatened_actor.free()


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
