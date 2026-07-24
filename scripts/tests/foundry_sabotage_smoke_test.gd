extends Node

const FoundryScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_foundry_sabotage_v1.tscn"
)
const FoundryLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_foundry_sabotage_loadout.tres"
)
const FireboltAbility: AbilityDefinition = preload(
	"res://data/abilities/firebolt_ability.tres"
)
const MetalTetherAbility: AbilityDefinition = preload(
	"res://data/abilities/metal_tether_ability.tres"
)
const GustAbility: AbilityDefinition = preload(
	"res://data/abilities/gust_ability.tres"
)

var failures: Array[String] = []


func _ready() -> void:
	validate_loadout()
	await validate_encounter_contract()
	if failures.is_empty():
		print("FOUNDRY_SABOTAGE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FOUNDRY_SABOTAGE_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func validate_loadout() -> void:
	if not FoundryLoadout.knows_ability(FireboltAbility):
		failures.append("foundry loadout is missing Firebolt")
	if not FoundryLoadout.knows_ability(MetalTetherAbility):
		failures.append("foundry loadout is missing Metal Tether")
	if not FoundryLoadout.knows_ability(GustAbility):
		failures.append("foundry loadout is missing Gust")


func validate_encounter_contract() -> void:
	var encounter: Node = FoundryScene.instantiate()
	if encounter == null:
		failures.append("Foundry Sabotage failed to instantiate")
		return
	add_child(encounter)
	await get_tree().process_frame
	await get_tree().physics_frame

	if not encounter.is_in_group("foundry_sabotage_encounter"):
		failures.append("encounter is missing its permanent feature group")
	if encounter.get_node_or_null("EncounterHUD/Panel/Margin/Readout") == null:
		failures.append("encounter is missing its compact HUD")
	if encounter.get_node_or_null("FoundrySmokeGrid") == null:
		failures.append("encounter is missing its optimized Smoke curtain")
	if encounter.get_node_or_null("StructuralCollapseConsequences") == null:
		failures.append("encounter is missing reusable collapse consequences")
	if encounter.get_node_or_null("Player/MetalTetherController") == null:
		failures.append("encounter player is missing Metal Tether integration")

	var debug_data: Dictionary = encounter.call("get_debug_data") as Dictionary
	var route_values: Array = debug_data.get("routes", []) as Array
	for required_route: String in ["burn", "hammer", "tether"]:
		if not route_values.has(required_route):
			failures.append("encounter is missing sabotage route " + required_route)

	var guard_count: int = 0
	for child: Node in encounter.get_children():
		if child is CharacterBody3D and child.is_in_group("enemy"):
			guard_count += 1
			if child.get_node_or_null("EnemyPerceptionSensor") == null:
				failures.append(child.name + " is missing world-aware perception")
	if guard_count < 2:
		failures.append("encounter requires two active foundry guards")

	var stimulus_manager: PerceptionStimulusManager = encounter.get_node_or_null(
		"PerceptionStimulusManager"
	) as PerceptionStimulusManager
	encounter.call("force_route_for_test", "hammer")
	await get_tree().process_frame
	await get_tree().physics_frame
	debug_data = encounter.call("get_debug_data") as Dictionary
	if not bool(debug_data.get("core_disabled", false)):
		failures.append("a valid sabotage route must disable the core")
	if not bool(debug_data.get("escape_unlocked", false)):
		failures.append("core shutdown must unlock the escape")
	if int(debug_data.get("collapse_count", 0)) < 1:
		failures.append("sabotage must produce a structural collapse consequence")
	if stimulus_manager == null or stimulus_manager.total_emitted < 1:
		failures.append("collapse must emit reusable perception evidence")

	var slab: StructuralMember3D = encounter.get_node_or_null(
		"MasonryCollapseAssembly/MasonrySlab"
	) as StructuralMember3D
	if slab == null or slab.supported or slab.freeze:
		failures.append("hammer route must release its masonry slab as debris")

	encounter.queue_free()
	await get_tree().process_frame
