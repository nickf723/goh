extends Node

const PreparedPlantLoadoutScript = preload(
	"res://scripts/life/prepared_plant_loadout.gd"
)
const PlantCatalog = preload(
	"res://scripts/life/plant_summon_catalog.gd"
)
const PlantSummonAbility: AbilityDefinition = preload(
	"res://data/abilities/sprout_ability.tres"
)

const TEST_SAVE_PATH: String = "user://goh_plant_preparation_smoke.json"

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_delete_test_save()
	await validate_preparation_store()
	await validate_prepared_actor_parameters()
	validate_combat_contract()
	_delete_test_save()
	_finish()


func validate_preparation_store() -> void:
	var store := PreparedPlantLoadoutScript.new() as PreparedPlantLoadout
	store.name = "PlantPreparationSmokeStore"
	store.save_path = TEST_SAVE_PATH
	add_child(store)
	await get_tree().process_frame

	var initial: Dictionary = store.get_prepared_snapshot()
	_expect(
		str(initial.get("plant_id", "")) == "broadleaf_sprout",
		"starter Broadleaf is prepared by default"
	)
	var initial_parameters_value: Variant = initial.get("parameters", {})
	var initial_parameters: Dictionary = (
		initial_parameters_value as Dictionary
		if initial_parameters_value is Dictionary
		else {}
	)
	_expect(str(initial_parameters.get("size", "")) == "standard", "size defaults to standard")
	_expect(str(initial_parameters.get("persistence", "")) == "standard", "persistence defaults to standard")
	_expect(str(initial_parameters.get("emergence", "")) == "balanced", "emergence defaults to balanced")

	store.set_parameter("size", "large", false)
	store.set_parameter("persistence", "persistent", false)
	store.set_parameter("emergence", "forceful", true)
	var prepared: Dictionary = store.get_prepared_snapshot()
	var parameters_value: Variant = prepared.get("parameters", {})
	var parameters: Dictionary = (
		parameters_value as Dictionary if parameters_value is Dictionary else {}
	)
	_expect(str(parameters.get("size", "")) == "large", "prepared size persists in blueprint")
	_expect(str(parameters.get("persistence", "")) == "persistent", "prepared persistence persists in blueprint")
	_expect(str(parameters.get("emergence", "")) == "forceful", "prepared emergence persists in blueprint")
	store.queue_free()
	await get_tree().process_frame

	var reloaded := PreparedPlantLoadoutScript.new() as PreparedPlantLoadout
	reloaded.name = "PlantPreparationReloaded"
	reloaded.save_path = TEST_SAVE_PATH
	add_child(reloaded)
	await get_tree().process_frame
	var reloaded_parameters: Dictionary = reloaded.get_prepared_parameters()
	_expect(str(reloaded_parameters.get("size", "")) == "large", "prepared size survives save/load")
	_expect(str(reloaded_parameters.get("persistence", "")) == "persistent", "prepared persistence survives save/load")
	_expect(str(reloaded_parameters.get("emergence", "")) == "forceful", "prepared emergence survives save/load")
	reloaded.queue_free()
	await get_tree().process_frame


func validate_prepared_actor_parameters() -> void:
	var definition: PlantSummonDefinition = PlantCatalog.get_definition("broadleaf_sprout")
	_expect(definition != null, "Broadleaf definition exists")
	if definition == null:
		return
	var scene_resource: Resource = load(definition.summon_scene_path)
	_expect(scene_resource is PackedScene, "prepared plant definition resolves a summon scene")
	if not scene_resource is PackedScene:
		return

	var actor: Node = (scene_resource as PackedScene).instantiate()
	actor.call("set_plant_definition", definition)
	actor.call("set_prepared_parameters", {
		"size": "large",
		"persistence": "persistent",
		"emergence": "forceful",
	})
	add_child(actor)
	await get_tree().process_frame

	var expected_size: float = PlantCatalog.get_size_multiplier({"size": "large"})
	var expected_persistence: float = PlantCatalog.get_persistence_multiplier({"persistence": "persistent"})
	var expected_emergence: float = PlantCatalog.get_emergence_multiplier({"emergence": "forceful"})
	_expect(
		absf(float(actor.get("platform_height")) - definition.growth_height * expected_size) < 0.01,
		"prepared size modifies future summon geometry"
	)
	_expect(
		absf(float(actor.get("lifetime")) - definition.lifetime * expected_persistence) < 0.01,
		"prepared persistence modifies future summon lifetime"
	)
	_expect(
		absf(float(actor.get("character_lift_speed")) - definition.character_growth_lift_speed * expected_emergence) < 0.01,
		"prepared emergence modifies future summon lift"
	)
	var debug: Dictionary = actor.call("get_debug_data") as Dictionary
	_expect(not bool(debug.get("combat_configuration_required", true)), "summoned plant requires no combat configuration")
	actor.queue_free()
	await get_tree().process_frame


func validate_combat_contract() -> void:
	_expect(PlantSummonAbility.display_name == "Plant Summon", "combat spell is generic Plant Summon")
	_expect(PlantSummonAbility.get_spell_id() == "sprout", "legacy spell id stays save-compatible")
	_expect(PlantCatalog.is_plant_summon_ability(PlantSummonAbility), "catalog recognizes Plant Summon")
	var compact: Dictionary = PlantCatalog.get_ground_spell_definition_for_prepared(
		PlantSummonAbility,
		"broadleaf_sprout",
		{"size": "compact"}
	)
	var large: Dictionary = PlantCatalog.get_ground_spell_definition_for_prepared(
		PlantSummonAbility,
		"broadleaf_sprout",
		{"size": "large"}
	)
	var compact_target_value: Variant = compact.get("target", {})
	var large_target_value: Variant = large.get("target", {})
	var compact_target: Dictionary = (
		compact_target_value as Dictionary
		if compact_target_value is Dictionary
		else {}
	)
	var large_target: Dictionary = (
		large_target_value as Dictionary
		if large_target_value is Dictionary
		else {}
	)
	_expect(
		float(large_target.get("radius", 0.0)) > float(compact_target.get("radius", 0.0)),
		"placement preview reflects prepared plant size"
	)
	var prepared_value: Variant = large.get("prepared_parameters", {})
	var prepared_parameters: Dictionary = (
		prepared_value as Dictionary if prepared_value is Dictionary else {}
	)
	_expect(
		str(prepared_parameters.get("size", "")) == "large",
		"ground targeting carries a sanitized prepared snapshot"
	)


func _delete_test_save() -> void:
	var absolute: String = ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("PLANT_PREPARATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PLANT_PREPARATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
