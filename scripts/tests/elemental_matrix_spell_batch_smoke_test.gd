extends Node

const EarthquakeAbility: AbilityDefinition = preload(
	"res://data/abilities/earthquake_ability.tres"
)
const PolarizeAbility: AbilityDefinition = preload(
	"res://data/abilities/polarize_ability.tres"
)
const MyceliumAbility: AbilityDefinition = preload(
	"res://data/abilities/mycelium_mesh_ability.tres"
)
const BarrierAbility: AbilityDefinition = preload(
	"res://data/abilities/barrier_ability.tres"
)
const RadioactiveRodAbility: AbilityDefinition = preload(
	"res://data/abilities/radioactive_rod_ability.tres"
)
const TornadoAbility: AbilityDefinition = preload(
	"res://data/abilities/tornado_ability.tres"
)
const InfectionAbility: AbilityDefinition = preload(
	"res://data/abilities/infection_ability.tres"
)
const InfernoAbility: AbilityDefinition = preload(
	"res://data/abilities/inferno_ability.tres"
)
const PoisonPuddleAbility: AbilityDefinition = preload(
	"res://data/abilities/poison_puddle_ability.tres"
)
const SyphonAbility: AbilityDefinition = preload(
	"res://data/abilities/syphon_ability.tres"
)
const GravityWellAbility: AbilityDefinition = preload(
	"res://data/abilities/gravity_well_ability.tres"
)
const StasisBubbleAbility: AbilityDefinition = preload(
	"res://data/abilities/stasis_bubble_ability.tres"
)
const LifeGroveAbility: AbilityDefinition = preload(
	"res://data/abilities/life_grove_ability.tres"
)
const IcePillarAbility: AbilityDefinition = preload(
	"res://data/abilities/ice_pillar_ability.tres"
)

const EarthquakeScene: PackedScene = preload(
	"res://scenes/actions/earthquake_field.tscn"
)
const PolarizeScene: PackedScene = preload(
	"res://scenes/actions/metal_polarize_cast.tscn"
)
const MyceliumScene: PackedScene = preload(
	"res://scenes/actions/life_mycelium_mesh.tscn"
)
const BarrierScene: PackedScene = preload(
	"res://scenes/actions/metal_barrier_cast.tscn"
)
const RadioactiveRodScene: PackedScene = preload(
	"res://scenes/actions/poison_radioactive_rod.tscn"
)
const TornadoScene: PackedScene = preload(
	"res://scenes/actions/air_tornado_aura.tscn"
)
const InfectionScene: PackedScene = preload(
	"res://scenes/actions/poison_infection_projectile.tscn"
)
const InfernoScene: PackedScene = preload(
	"res://scenes/actions/fire_inferno_aura.tscn"
)
const PoisonPuddleScene: PackedScene = preload(
	"res://scenes/actions/poison_puddle_surface.tscn"
)
const SyphonScene: PackedScene = preload(
	"res://scenes/actions/death_syphon_projectile.tscn"
)
const GravityWellScene: PackedScene = preload(
	"res://scenes/actions/space_gravity_well.tscn"
)
const StasisBubbleScene: PackedScene = preload(
	"res://scenes/actions/time_stasis_bubble.tscn"
)
const LifeGroveScene: PackedScene = preload(
	"res://scenes/actions/life_grove.tscn"
)
const IcePillarScene: PackedScene = preload(
	"res://scenes/actions/ice_pillar_cast.tscn"
)

const CombatPlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player_combat_v2.tscn"
)
const MatrixCasterScript: Script = preload(
	"res://scripts/abilities/ability_caster_matrix_library.gd"
)
const StatePolicyScript: Script = preload(
	"res://scripts/systems/reaction_state_policy.gd"
)
const StatusReceiverScript: Script = preload(
	"res://scripts/combat/authority_status_receiver_base.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	_validate_ability(EarthquakeAbility, "earthquake", "earth", "spatial_channel")
	_validate_ability(PolarizeAbility, "polarize", "lightning", "target_bond")
	_validate_ability(MyceliumAbility, "mycelium_mesh", "life", "spatial_field")
	_validate_ability(BarrierAbility, "barrier", "metal", "conjured_structure")
	_validate_ability(RadioactiveRodAbility, "radioactive_rod", "poison", "spatial_field")
	_validate_ability(TornadoAbility, "tornado", "air", "status_aura")
	_validate_ability(InfectionAbility, "infection", "poison", "projectile_status_transfer")
	_validate_ability(InfernoAbility, "inferno", "fire", "status_aura")
	_validate_ability(PoisonPuddleAbility, "poison_puddle", "poison", "spatial_surface")
	_validate_ability(SyphonAbility, "syphon", "death", "projectile_life_drain")
	_validate_ability(GravityWellAbility, "gravity_well", "space", "spatial_force_field")
	_validate_ability(StasisBubbleAbility, "stasis_bubble", "time", "spatial_status_field")
	_validate_ability(LifeGroveAbility, "life_grove", "life", "spatial_restoration_field")
	_validate_ability(IcePillarAbility, "ice_pillar", "ice", "conjured_vertical_structure")

	_validate_runtime_scene(EarthquakeScene, "seismic_response_contract", false)
	_validate_runtime_scene(PolarizeScene, "object_connection_contract", false)
	_validate_runtime_scene(MyceliumScene, "growth_response_contract", false)
	_validate_runtime_scene(BarrierScene, "defensive_structure", false)
	_validate_runtime_scene(RadioactiveRodScene, "cumulative_exposure", true)
	_validate_runtime_scene(TornadoScene, "airflow_vortex", false)
	_validate_runtime_scene(InfectionScene, "status_transfer_contract", false)
	_validate_runtime_scene(InfernoScene, "heat_response_contract", true)
	_validate_runtime_scene(PoisonPuddleScene, "chemical_surface_contract", false)
	_validate_runtime_scene(SyphonScene, "life_drain_contract", true)
	_validate_runtime_scene(GravityWellScene, "gravity_field_contract", false)
	_validate_runtime_scene(StasisBubbleScene, "time_stasis_contract", false)
	_validate_runtime_scene(LifeGroveScene, "restorative_growth_contract", false)
	_validate_runtime_scene(IcePillarScene, "temporary_architecture_contract", false)

	_validate_stasis_policy()
	_validate_specialized_contracts()
	_validate_library_discovery()
	_validate_live_player_wiring()
	_finish()


func _validate_ability(
	ability: AbilityDefinition,
	expected_id: String,
	expected_element: String,
	expected_delivery: String
) -> void:
	_expect(ability != null, expected_id + " ability loads")
	if ability == null:
		return
	_expect(
		ability.get_spell_id() == expected_id,
		expected_id + " has canonical spell ID"
	)
	_expect(
		ability.element == expected_element,
		expected_id + " matches matrix element"
	)
	_expect(
		ability.get_delivery_type() == expected_delivery,
		expected_id + " carries authored delivery contract"
	)
	_expect(
		ability.get_debug_tags().has("matrix_spell"),
		expected_id + " identifies matrix-source design"
	)
	_expect(
		ability.ability_scene != null,
		expected_id + " has an executable action scene"
	)
	_expect(
		not ability.get_roles().is_empty(),
		expected_id + " carries explicit gameplay roles"
	)
	_expect(
		not ability.get_combo_tags().is_empty(),
		expected_id + " participates in the spell interaction vocabulary"
	)


func _validate_runtime_scene(
	scene: PackedScene,
	contract_key: String,
	expected_direct_damage: bool
) -> void:
	var instance: Node = scene.instantiate()
	_expect(instance != null, contract_key + " action scene instantiates")
	if instance == null:
		return
	_expect(
		instance.has_method("execute") or instance.has_method("launch"),
		contract_key + " exposes a cast or launch entrypoint"
	)
	_expect(
		instance.has_method("set_source_actor"),
		contract_key + " accepts caster authority"
	)
	_expect(
		instance.has_method("get_debug_data"),
		contract_key + " exposes debug contract"
	)
	if instance.has_method("get_debug_data"):
		var data: Dictionary = instance.call("get_debug_data") as Dictionary
		_expect(bool(data.get(contract_key, false)), contract_key + " is advertised")
		_expect(
			bool(data.get("direct_damage", false)) == expected_direct_damage,
			contract_key + " reports intended direct-damage ownership"
		)
	instance.free()


func _validate_stasis_policy() -> void:
	_expect(
		str(StatePolicyScript.get_state_element("stasis")) == "time",
		"stasis resolves to the Time element"
	)
	var receiver: Node = StatusReceiverScript.new()
	_expect(receiver != null, "shared status receiver can be constructed for stasis validation")
	if receiver == null:
		return
	receiver.call("apply_status", "stasis", 1.0, 1.0, "matrix_test")
	_expect(
		is_equal_approx(float(receiver.call("get_movement_multiplier")), 0.0),
		"stasis fully blocks movement"
	)
	_expect(bool(receiver.call("blocks_actions")), "stasis blocks actions")
	receiver.free()


func _validate_specialized_contracts() -> void:
	var grove: Node = LifeGroveScene.instantiate()
	_expect(grove.has_method("execute"), "Life Grove exposes cast entrypoint")
	if grove.has_method("get_debug_data"):
		var grove_data: Dictionary = grove.call("get_debug_data") as Dictionary
		_expect(
			bool(grove_data.get("restorative_growth_contract", false)),
			"Life Grove advertises restorative growth contract"
		)
	grove.free()

	var pillar: Node = IcePillarScene.instantiate()
	_expect(pillar.has_method("receive_damage_payload"), "Ice Pillar can receive Fire payloads")
	if pillar.has_method("get_debug_data"):
		var pillar_data: Dictionary = pillar.call("get_debug_data") as Dictionary
		_expect(bool(pillar_data.get("fire_meltable", false)), "Ice Pillar advertises Fire melt behavior")
		_expect(bool(pillar_data.get("traversal_geometry", false)), "Ice Pillar advertises traversal geometry")
	pillar.free()


func _validate_library_discovery() -> void:
	var loadout := AbilityLoadout.new()
	_expect(
		loadout.get_learned_abilities().is_empty(),
		"authored discovery remains opt-in for focused loadouts"
	)
	loadout.auto_discover_authored_abilities = true
	loadout.authored_ability_root = "res://data/abilities"
	var discovered: Array[AbilityDefinition] = loadout.get_learned_abilities()
	var ids: Array[String] = []
	for ability: AbilityDefinition in discovered:
		if ability != null:
			ids.append(ability.get_spell_id())

	for expected_id: String in [
		"earthquake",
		"polarize",
		"mycelium_mesh",
		"barrier",
		"radioactive_rod",
		"tornado",
		"infection",
		"inferno",
		"poison_puddle",
		"syphon",
		"gravity_well",
		"stasis_bubble",
		"life_grove",
		"ice_pillar",
	]:
		_expect(ids.has(expected_id), "authored library discovers " + expected_id)
		_expect(
			_count_id(ids, expected_id) == 1,
			"spell-ID discovery deduplicates " + expected_id
		)

	var first_debug: Dictionary = loadout.get_library_debug_data()
	loadout.get_learned_abilities()
	var second_debug: Dictionary = loadout.get_library_debug_data()
	_expect(
		int(first_debug.get("scan_count", 0)) == int(second_debug.get("scan_count", -1)),
		"authored spell scan is cached after first discovery"
	)


func _validate_live_player_wiring() -> void:
	var player: Node = CombatPlayerScene.instantiate()
	_expect(player != null, "combat Grace scene instantiates with matrix spell integration")
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "combat Grace retains AbilityCaster")
	if caster != null:
		_expect(
			caster.get_script() == MatrixCasterScript,
			"combat Grace uses matrix-aware Focus caster"
		)
		var loadout_value: Variant = caster.get("loadout")
		_expect(
			loadout_value is AbilityLoadout,
			"matrix-aware caster retains production loadout"
		)

	var status_receiver: Node = player.get_node_or_null("StatusReceiver")
	_expect(status_receiver != null, "combat Grace retains StatusReceiver")
	if status_receiver != null:
		_expect(
			status_receiver.has_method("get_transferable_debuffs"),
			"combat Grace exposes Infection source-state snapshots"
		)
	player.free()


func _count_id(ids: Array[String], target: String) -> int:
	var count: int = 0
	for value: String in ids:
		if value == target:
			count += 1
	return count


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("ELEMENTAL_MATRIX_SPELL_BATCH_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ELEMENTAL_MATRIX_SPELL_BATCH_SMOKE_TEST: " + failure)
	get_tree().quit(1)
