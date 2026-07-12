extends "res://scripts/systems/dev_sandbox_director.gd"
class_name DevTestScenarioDirector

const OIL_FIRE_SCENARIO: Resource = preload("res://data/test_scenarios/oil_fire_reaction.tres")
const WET_LIGHTNING_SCENARIO: Resource = preload("res://data/test_scenarios/wet_lightning_reaction.tres")
const SOUND_REVEAL_SCENARIO: Resource = preload("res://data/test_scenarios/sound_reveal.tres")

@export var use_resource_scenarios: bool = true

var scenario_definitions: Array[Resource] = [
	OIL_FIRE_SCENARIO,
	WET_LIGHTNING_SCENARIO,
	SOUND_REVEAL_SCENARIO,
]
var spawned_props: Array[Node] = []


func print_help() -> void:
	if not print_debug:
		return

	print("")
	print("=== DEV TEST SCENARIO DIRECTOR ===")
	print("F6: Spawn/reset selected scenario")
	print("F7: Clear spawned scenario")
	print("F9: Next scenario")
	print("F10: Previous scenario")
	print("F12: Run dev audit")
	print("==================================")
	print("")


func get_scenario_count() -> int:
	if use_resource_scenarios and scenario_definitions.size() > 0:
		return scenario_definitions.size()

	return super.get_scenario_count()


func get_current_scenario_definition() -> TestScenarioDefinition:
	if not use_resource_scenarios or scenario_definitions.size() <= 0:
		return null

	normalize_scenario_index()
	return scenario_definitions[current_scenario_index] as TestScenarioDefinition


func get_current_scenario_id() -> String:
	var definition: TestScenarioDefinition = get_current_scenario_definition()

	if definition != null:
		return definition.scenario_id

	return super.get_current_scenario_id()


func get_current_scenario_name() -> String:
	var definition: TestScenarioDefinition = get_current_scenario_definition()

	if definition != null:
		return definition.display_name

	return super.get_current_scenario_name()


func print_current_scenario() -> void:
	if print_debug:
		print(
			"Selected dev scenario: [",
			current_scenario_index + 1,
			"/",
			get_scenario_count(),
			"] ",
			get_current_scenario_name()
		)

	show_current_scenario_guidance(false)


func spawn_current_scenario() -> void:
	var definition: TestScenarioDefinition = get_current_scenario_definition()

	if definition == null:
		super.spawn_current_scenario()
		return

	cleanup_dead_spawn_references()

	if auto_clear_before_spawn:
		clear_spawned_enemies()

	var player: Node3D = find_player() as Node3D
	var base_position: Vector3 = Vector3.ZERO

	if spawn_relative_to_player and player != null:
		base_position = player.global_position
	else:
		var parent_3d: Node3D = get_parent() as Node3D

		if parent_3d != null:
			base_position = parent_3d.global_position

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		print("DevTestScenarioDirector: No current scene root found.")
		return

	var spawned_enemy_count: int = 0
	var spawned_prop_count: int = 0

	for enemy_id: String in definition.enemy_ids:
		var enemy: Node = spawn_enemy_by_id(
			scene_root,
			enemy_id,
			base_position + get_spawn_offset(spawned_enemy_count)
		)

		if enemy != null:
			spawned_enemy_count += 1

	for prop_index: int in range(definition.prop_scenes.size()):
		var prop_scene: PackedScene = definition.prop_scenes[prop_index]
		var prop: Node = spawn_scenario_prop(
			scene_root,
			prop_scene,
			base_position + definition.get_prop_offset(prop_index)
		)

		if prop != null:
			spawned_prop_count += 1

	var selected_ability: bool = select_recommended_ability(definition.recommended_ability_name)
	show_current_scenario_guidance(true, selected_ability)

	print(
		"DevTestScenarioDirector: spawned ",
		spawned_enemy_count,
		" enemies and ",
		spawned_prop_count,
		" props for ",
		definition.display_name,
		"."
	)


func spawn_scenario_prop(
	scene_root: Node,
	prop_scene: PackedScene,
	spawn_position: Vector3
) -> Node:
	if scene_root == null or prop_scene == null:
		return null

	var prop: Node = prop_scene.instantiate()
	scene_root.add_child(prop)

	if prop is Node3D:
		(prop as Node3D).global_position = spawn_position

	prop.add_to_group("dev_spawned")
	spawned_props.append(prop)
	print("Spawned scenario prop: ", prop.name, " at ", prop.get_path())
	return prop


func clear_spawned_enemies() -> void:
	var clear_count: int = 0

	for spawned_node: Node in get_tree().get_nodes_in_group("dev_spawned"):
		if is_instance_valid(spawned_node):
			spawned_node.queue_free()
			clear_count += 1

	spawned_enemies.clear()
	spawned_props.clear()

	if print_debug or clear_count > 0:
		print("DevTestScenarioDirector: cleared scenario nodes: ", clear_count)


func select_recommended_ability(ability_name: String) -> bool:
	if ability_name == "":
		return false

	var player: Node = find_player()

	if player == null:
		return false

	var ability_caster: Node = player.get_node_or_null("AbilityCaster")

	if ability_caster == null or not ability_caster.has_method("select_ability"):
		return false

	var loadout: Resource = ability_caster.get("loadout") as Resource

	if loadout == null:
		return false

	var abilities_variant: Variant = loadout.get("equipped_abilities")

	if not (abilities_variant is Array):
		return false

	var abilities: Array = abilities_variant as Array

	for ability_index: int in range(abilities.size()):
		var ability: Resource = abilities[ability_index] as Resource

		if ability == null:
			continue

		var display_name: String = str(ability.get("display_name"))

		if display_name.to_lower() == ability_name.to_lower():
			ability_caster.call("select_ability", ability_index, false)
			return true

	return false


func show_current_scenario_guidance(
	was_spawned: bool,
	selected_ability: bool = false
) -> void:
	var definition: TestScenarioDefinition = get_current_scenario_definition()

	if definition == null:
		return

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui == null:
		return

	var state_label: String = "Selected"

	if was_spawned:
		state_label = "Spawned"

	var guidance: String = (
		state_label
		+ ": "
		+ definition.get_guidance_text()
		+ "\nControls: F9 next | F10 previous | F6 spawn/reset | F7 clear | F12 audit"
	)

	if was_spawned and definition.recommended_ability_name != "" and not selected_ability:
		guidance += "\nNote: recommended ability was not found in the active loadout."

	if ui.has_method("set_objective"):
		ui.call("set_objective", "Dev test: " + definition.display_name)

	if ui.has_method("show_message"):
		ui.call("show_message", guidance)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var definition: TestScenarioDefinition = get_current_scenario_definition()

	data["resource_scenarios"] = use_resource_scenarios
	data["spawned_props"] = spawned_props.size()

	if definition != null:
		data["expected"] = definition.expected_result
		data["recommended"] = definition.recommended_ability_name

	return data
