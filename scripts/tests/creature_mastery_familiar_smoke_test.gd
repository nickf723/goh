extends Node

const TrainingYardScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_familiar_training_yard_v1.tscn"
)
const FamiliarCatalog = preload(
	"res://scripts/summons/familiar_definition_catalog.gd"
)
const AbilityCatalog = preload(
	"res://scripts/summons/creature_ability_catalog.gd"
)
const TargetAllocator = preload(
	"res://scripts/ai/target_allocation_blackboard.gd"
)

var failures: Array[String] = []
var species_knowledge: Node
var original_snapshot: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	species_knowledge = get_node_or_null("/root/SpeciesKnowledge")
	_expect(species_knowledge != null, "SpeciesKnowledge autoload resolves")
	if species_knowledge == null:
		_finish()
		return
	original_snapshot = species_knowledge.call("get_snapshot") as Dictionary
	_prepare_mastered_gremlin_loadout()
	_test_shared_catalogs()
	await _test_live_training_yard()
	_restore_snapshot()
	_finish()


func _prepare_mastered_gremlin_loadout() -> void:
	species_knowledge.call("reset_species", "gremlin")
	var discoveries_to_add: Array[Dictionary] = [
		{"id": "first_encounter", "label": "First encounter", "points": 1},
		{"id": "survived_pounce", "label": "Survived Pounce", "points": 1},
		{"id": "witnessed_backstep", "label": "Witnessed Backstep", "points": 1},
		{"id": "pack_coordination", "label": "Pack Coordination", "points": 2},
		{"id": "conduct_susceptibility", "label": "Conduct Susceptibility", "points": 4},
		{"id": "habitat_scavenging", "label": "Scavenging Habitat", "points": 1},
		{"id": "stable_familiar_bond", "label": "Stable Familiar Bond", "points": 4},
	]
	for discovery: Dictionary in discoveries_to_add:
		species_knowledge.call(
			"add_discovery",
			"gremlin",
			str(discovery.get("id", "")),
			str(discovery.get("label", "")),
			int(discovery.get("points", 0))
		)
	_expect(bool(species_knowledge.call("has_unlock", "gremlin", "gremlin_transformation")), "Gremlin mastery unlocks future transformation")
	var equip_result: Dictionary = species_knowledge.call("set_equipped_familiar_species", "gremlin") as Dictionary
	_expect(bool(equip_result.get("ok", false)), "Gremlin familiar equips")
	var role_result: Dictionary = species_knowledge.call("cycle_familiar_role", "gremlin", 1) as Dictionary
	var role_loadout: Dictionary = _dictionary(role_result.get("loadout", {}))
	_expect(str(role_loadout.get("role", "")) == "primer", "Prepared familiar uses Primer role")
	if _loadout_has("backstep"):
		species_knowledge.call("toggle_familiar_technique", "gremlin", "backstep")
	if not _loadout_has("pounce"):
		species_knowledge.call("toggle_familiar_technique", "gremlin", "pounce")
	if not _loadout_has("mire_spit"):
		species_knowledge.call("toggle_familiar_technique", "gremlin", "mire_spit")
	_expect(_loadout_has("bite"), "Prepared familiar keeps Bite")
	_expect(_loadout_has("pounce"), "Prepared familiar equips Pounce")
	_expect(_loadout_has("mire_spit"), "Prepared familiar equips Mire Spit")


func _test_shared_catalogs() -> void:
	var definition_value: Variant = FamiliarCatalog.get_definition("gremlin")
	_expect(definition_value is SummonDefinition, "Familiar catalog resolves Gremlin definition")
	if definition_value is SummonDefinition:
		var definition: SummonDefinition = definition_value as SummonDefinition
		_expect(definition.species_id == "gremlin", "Definition keeps Gremlin species identity")
		_expect(definition.transformation_supported, "Definition exposes transformation architecture hook")
	for technique_id: String in ["bite", "backstep", "pounce", "mire_spit"]:
		_expect(AbilityCatalog.get_option("gremlin", technique_id) != null, "Shared catalog resolves " + technique_id)
		_expect(AbilityCatalog.get_action("gremlin", technique_id) != null, "Shared action resolves " + technique_id)


func _test_live_training_yard() -> void:
	TargetAllocator.clear_all()
	var yard_value: Variant = TrainingYardScene.instantiate()
	_expect(yard_value is Node3D, "Familiar Training Yard instantiates")
	if not yard_value is Node3D:
		return
	var yard: Node3D = yard_value as Node3D
	yard.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(yard)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node = yard.get_node_or_null("Player")
	var enemy_root: Node = yard.get_node_or_null("EnemyRoot")
	_expect(player != null and enemy_root != null, "Training Yard resolves player and wild enemy root")
	_expect(enemy_root != null and enemy_root.get_child_count() == 2, "Training Yard spawns two wild Gremlins")
	var study_terminal: Node = yard.get_node_or_null("StudyFirstEncounter")
	_expect(study_terminal != null and study_terminal.has_method("interact"), "Training Yard exposes study terminals")
	var manager: Node = player.get_node_or_null("SummonManager") if player != null else null
	_expect(manager != null, "Player retains summon manager")
	if manager == null:
		yard.queue_free()
		return
	var resolved_value: Variant = manager.call("get_resolved_summon_definition")
	_expect(resolved_value is SummonDefinition, "Summon manager resolves prepared definition")
	if resolved_value is SummonDefinition:
		_expect((resolved_value as SummonDefinition).summon_id == "gremlin_familiar", "Summon manager selects Gremlin blueprint")
	var summoned: bool = bool(manager.call("summon_familiar"))
	_expect(summoned, "Prepared Gremlin familiar summons")
	await get_tree().process_frame
	var familiar_value: Variant = manager.call("get_active_summon")
	_expect(familiar_value is Node, "Active summon resolves as a node")
	if not familiar_value is Node:
		yard.queue_free()
		return
	var familiar: Node = familiar_value as Node
	var familiar_script: Script = familiar.get_script() as Script
	_expect(
		familiar_script != null
		and familiar_script.resource_path == "res://scripts/summons/gremlin_familiar.gd",
		"Active summon uses Gremlin familiar driver"
	)
	var familiar_debug_value: Variant = familiar.call("get_debug_data")
	var familiar_debug: Dictionary = _dictionary(familiar_debug_value)
	_expect(str(familiar_debug.get("familiar_role", "")) == "primer", "Spawned familiar receives menu-authored role")
	var active_techniques: Array[String] = _string_array(familiar_debug.get("technique_ids", []))
	_expect(active_techniques.has("mire_spit"), "Spawned familiar receives menu-authored techniques")
	familiar.call("_refresh_target")
	var target_value: Variant = familiar.get("current_target")
	_expect(target_value is Node3D and is_instance_valid(target_value), "Familiar acquires a live enemy target")
	if target_value is Node3D and is_instance_valid(target_value):
		var target: Node3D = target_value as Node3D
		(familiar as Node3D).global_position = target.global_position + Vector3(0.0, 0.0, 5.0)
		familiar.call("_attack_target")
		_expect(str(familiar.get("selected_technique_id")) == "mire_spit", "Primer familiar selects Mire Spit at range")
	var context: Dictionary = TargetAllocator.get_squad_context("grace_familiars")
	_expect(int(context.get("target_claim_count", 0)) > 0, "Familiar publishes friendly target claims")
	var projectile_found: bool = false
	for child: Node in get_children():
		if child.name == "GremlinFamiliarMireProjectile":
			projectile_found = true
			break
	_expect(projectile_found, "Mire Spit creates a friendly projectile")
	var menu_director: Node = get_node_or_null("/root/FullMenuDirector")
	_expect(menu_director != null and menu_director.has_method("build_menu_data"), "Full menu director resolves")
	if menu_director != null and menu_director.has_method("build_menu_data"):
		var menu_value: Variant = menu_director.call("build_menu_data")
		var menu_data: Dictionary = _dictionary(menu_value)
		var familiar_data: Dictionary = _dictionary(menu_data.get("familiar_mastery", {}))
		_expect(str(familiar_data.get("equipped_species_id", "")) == "gremlin", "Magic menu data exposes equipped Gremlin")
	manager.call("dismiss_summon", false)
	TargetAllocator.clear_all()
	yard.queue_free()
	await get_tree().process_frame


func _loadout_has(technique_id: String) -> bool:
	var loadout_value: Variant = species_knowledge.call("get_familiar_loadout", "gremlin")
	var loadout: Dictionary = _dictionary(loadout_value)
	return _string_array(loadout.get("technique_ids", [])).has(technique_id)


func _restore_snapshot() -> void:
	if species_knowledge != null and not original_snapshot.is_empty():
		species_knowledge.call("apply_snapshot", original_snapshot)


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			result.append(str(raw))
	return result


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("CREATURE_MASTERY_FAMILIAR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CREATURE_MASTERY_FAMILIAR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
