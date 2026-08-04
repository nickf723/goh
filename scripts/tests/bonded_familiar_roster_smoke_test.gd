extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const ROSTER_PATH: String = "user://bonded_familiar_roster_smoke_test.json"
const BOND_PATH: String = "user://bonded_familiar_roster_bonds_smoke_test.json"
const JUNIPER_ID: String = "smoke_test:juniper"

var failures: Array[String] = []
var original_species_snapshot: Dictionary = {}
var original_stats: Dictionary = {}
var player: CharacterBody3D
var world_juniper: NavigationBondedAnimalActor
var bond_store: AnimalBondStore
var roster: BondedFamiliarRoster
var manager: PlayerSummonManager


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	Engine.time_scale = 1.0
	_cleanup_files()
	original_species_snapshot = SpeciesKnowledge.get_snapshot()
	original_stats = GameState.get_stat_snapshot()
	SpeciesKnowledge.reset_all()
	GameState.set_stat("max_mana", 30)
	GameState.set_stat("mana", 30)

	bond_store = AnimalBondStore.get_or_create(get_tree(), BOND_PATH)
	bond_store.clear_records("", false)
	bond_store.set_record(JUNIPER_ID, {
		"animal_name": "Juniper",
		"species_id": "sheep",
		"personality_profile_id": "cautious",
		"relationship": {
			"trust": 0.88,
			"familiarity": 0.79,
			"fear_association": 0.05,
			"peaceful_exposure": 24.0,
			"last_interaction": "bond",
			"interaction_count": 9,
		},
		"bonded": true,
		"follow_enabled": true,
		"help_events": 3,
		"harm_events": 0,
		"companion_command": {
			"command_id": "follow",
			"previous_command_id": "follow",
		},
	}, true)

	roster = BondedFamiliarRoster.get_or_create(
		get_tree(),
		ROSTER_PATH,
		BOND_PATH
	)
	_expect(roster != null, "bonded familiar roster is available")
	if roster == null:
		await _finish()
		return
	var rows: Array[Dictionary] = roster.get_roster_rows()
	_expect(rows.size() == 1, "rescued and bonded Juniper enters the roster")
	if not rows.is_empty():
		_expect(str(rows[0].get("animal_name", "")) == "Juniper", "roster preserves the animal name")
		_expect(str(rows[0].get("species_id", "")) == "sheep", "roster preserves the animal species")
		_expect(str(rows[0].get("trust_tier", "")) == "Devoted", "roster derives Juniper's trust tier")
	var equip_result: Dictionary = roster.equip_animal(JUNIPER_ID, true)
	_expect(bool(equip_result.get("ok", false)), "Juniper equips into the named familiar slot")
	_expect(roster.get_equipped_animal_id() == JUNIPER_ID, "equipped animal id persists in the roster")

	player = PlayerScene.instantiate() as CharacterBody3D
	player.name = "Player"
	player.add_to_group("player")
	add_child(player)

	world_juniper = NavigationBondedAnimalActor.new()
	world_juniper.name = "WorldJuniper"
	world_juniper.persistent_animal_id = JUNIPER_ID
	world_juniper.animal_name = "Juniper"
	world_juniper.species_id = "sheep"
	world_juniper.personality_profile_id = "cautious"
	world_juniper.rescued = true
	world_juniper.injured = false
	world_juniper.injury_ratio = 0.0
	world_juniper.global_position = Vector3(4.0, 0.0, 0.0)
	add_child(world_juniper)

	await _wait_frames(45)
	manager = player.get_node_or_null("SummonManager") as PlayerSummonManager
	_expect(manager != null, "player summon manager is available")
	if manager == null:
		await _finish()
		return
	var prepared_definition: SummonDefinition = manager.summon_definition
	_expect(
		prepared_definition != null
		and prepared_definition.summon_id == "bonded_familiar:" + JUNIPER_ID,
		"roster replaces only the manager's fallback definition"
	)
	_expect(
		prepared_definition != null and prepared_definition.display_name == "Juniper",
		"runtime definition uses the named animal identity"
	)
	_expect(world_juniper.visible, "world Juniper remains visible before summoning")

	var summon_ability := AbilityDefinition.new()
	summon_ability.spell_id = "spectral_familiar"
	summon_ability.display_name = "Summon Familiar"
	summon_ability.category = AbilityDefinition.AbilityCategory.SUMMON
	summon_ability.mana_cost = 0
	var summoned: bool = manager.begin_ability_channel(player, summon_ability)
	_expect(summoned, "actual Summon Familiar ability channel manifests Juniper")
	await _wait_frames(16)

	var active: Node3D = manager.get_active_summon()
	_expect(active is SummonedBondedAnimalFamiliar, "summon manager creates the bonded animal actor")
	if active is SummonedBondedAnimalFamiliar:
		var familiar := active as SummonedBondedAnimalFamiliar
		_expect(familiar.display_name == "Juniper", "summoned familiar keeps Juniper's name")
		_expect(familiar.animal_name == "Juniper", "summoned actor keeps the persistent animal name")
		_expect(familiar.species_id == "sheep", "summoned familiar keeps Juniper's species")
		_expect(familiar.persistent_animal_id == JUNIPER_ID, "summoned familiar links to Juniper's record")
		var command_data: Dictionary = familiar.get_familiar_command_data()
		_expect(float(command_data.get("trust", 0.0)) >= 0.87, "summoned familiar restores relationship trust")
		_expect(bool(command_data.get("bonded_individual", false)), "summoned familiar identifies as a named individual")
	_expect(roster.is_manifested(JUNIPER_ID), "roster tracks Juniper as manifested")
	_expect(not world_juniper.visible, "world Juniper hides while her manifestation is active")
	_expect(world_juniper.collision_layer == 0, "hidden world animal cannot collide with its manifestation")
	_expect(
		bool(world_juniper.get_meta("bonded_familiar_world_suppressed", false)),
		"world duplicate reports manifestation suppression"
	)

	var stay_result: Dictionary = manager.issue_familiar_command("stay")
	_expect(bool(stay_result.get("ok", false)), "named familiar accepts Stay through the global command system")
	var follow_result: Dictionary = manager.issue_familiar_command("follow")
	_expect(bool(follow_result.get("ok", false)), "named familiar accepts Follow through the global command system")
	_expect(
		str(manager.get_familiar_command_state().get("display_name", "")) == "Juniper",
		"global familiar context reports the named animal"
	)

	_expect(manager.dismiss_summon(false), "dismissing the named familiar succeeds")
	await _wait_frames(10)
	_expect(not roster.is_manifested(JUNIPER_ID), "dismissal clears manifested state")
	_expect(world_juniper.visible, "dismissal restores the original world animal")
	_expect(world_juniper.collision_layer != 0, "dismissal restores world-animal collision")
	_expect(bond_store.get_record(JUNIPER_ID).get("bonded", false), "dismissal preserves the persistent bond")

	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH))
	_expect(saved is Dictionary, "named familiar slot saves to disk")
	if saved is Dictionary:
		var saved_data: Dictionary = saved as Dictionary
		_expect(str(saved_data.get("equipped_animal_id", "")) == JUNIPER_ID, "disk save remembers equipped Juniper")
		_expect(not saved_data.has("manifested_animal_id"), "manifestation state is never persisted across crashes")

	var clear_result: Dictionary = roster.clear_equipped(false, true)
	_expect(bool(clear_result.get("ok", false)), "named familiar slot can be cleared")
	await _wait_frames(8)
	var restored_definition: SummonDefinition = manager.summon_definition
	_expect(
		restored_definition != null and restored_definition.summon_id == "spectral_familiar",
		"clearing the named slot restores Lumen's original definition"
	)

	await _finish()


func _wait_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("BONDED_FAMILIAR_ROSTER_SMOKE_TEST: " + label)


func _finish() -> void:
	Engine.time_scale = 1.0
	SpeciesKnowledge.apply_snapshot(original_species_snapshot)
	GameState.stats = original_stats.duplicate(true)
	if player != null and is_instance_valid(player):
		player.queue_free()
	if world_juniper != null and is_instance_valid(world_juniper):
		world_juniper.queue_free()
	await get_tree().process_frame
	_cleanup_files()
	if failures.is_empty():
		print("BONDED_FAMILIAR_ROSTER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("BONDED_FAMILIAR_ROSTER_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _cleanup_files() -> void:
	for path: String in [ROSTER_PATH, BOND_PATH]:
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
