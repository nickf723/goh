extends Node3D

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const TaskReceiverScript: Script = preload(
	"res://scripts/summons/familiar_task_receiver.gd"
)
const TaskStoreScript: Script = preload(
	"res://scripts/summons/familiar_task_state_store.gd"
)
const ROSTER_PATH: String = "user://familiar_utility_roster_test.json"
const BOND_PATH: String = "user://familiar_utility_bonds_test.json"
const TASK_PATH: String = "user://familiar_utility_tasks_test.json"
const JUNIPER_ID: String = "smoke_test:utility_juniper"

var failures: Array[String] = []
var original_species_snapshot: Dictionary = {}
var original_stats: Dictionary = {}
var player: CharacterBody3D
var manager: PlayerSummonManager
var roster: BondedFamiliarRoster
var bond_store: AnimalBondStore
var task_store: FamiliarTaskStateStore
var task_root: Node3D


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	Engine.time_scale = 1.0
	_cleanup_files()
	original_species_snapshot = SpeciesKnowledge.get_snapshot()
	original_stats = GameState.get_stat_snapshot()
	SpeciesKnowledge.reset_all()
	GameState.set_stat("max_mana", 40)
	GameState.set_stat("mana", 40)

	task_store = TaskStoreScript.get_or_create(get_tree(), TASK_PATH) as FamiliarTaskStateStore
	task_store.clear_states("", true)
	bond_store = AnimalBondStore.get_or_create(get_tree(), BOND_PATH)
	bond_store.clear_records("", false)
	bond_store.set_record(JUNIPER_ID, {
		"animal_name": "Juniper",
		"species_id": "sheep",
		"personality_profile_id": "cautious",
		"relationship": {
			"trust": 0.9,
			"familiarity": 0.84,
			"fear_association": 0.02,
		},
		"bonded": true,
		"follow_enabled": true,
		"help_events": 4,
		"harm_events": 0,
	}, true)
	roster = BondedFamiliarRoster.get_or_create(get_tree(), ROSTER_PATH, BOND_PATH)
	roster.equip_animal(JUNIPER_ID, true)

	_build_floor()
	_build_task_fixture()
	player = PlayerScene.instantiate() as CharacterBody3D
	player.name = "Player"
	player.add_to_group("player")
	player.position = Vector3(0.0, 1.0, 3.0)
	add_child(player)
	await _wait_frames(45)
	manager = player.get_node_or_null("SummonManager") as PlayerSummonManager
	_expect(manager != null, "player exposes the familiar summon manager")
	if manager == null:
		await _finish()
		return

	var familiar: SummonedBondedAnimalFamiliar = await _summon_juniper()
	if familiar == null:
		await _finish()
		return
	_expect(familiar.has_familiar_task_capability("hold"), "Juniper can hold mechanisms")
	_expect(familiar.has_familiar_task_capability("ram"), "sheep familiar can ram obstacles")
	_expect(familiar.has_familiar_task_capability("forage"), "Juniper can forage terrain")
	_expect(not familiar.has_familiar_task_capability("scout"), "Juniper does not inherit unrelated bird utility")

	await _test_hold_task(familiar)
	await _test_ram_task(familiar)

	_expect(manager.dismiss_summon(false), "Juniper can be dismissed between utility tasks")
	await _wait_frames(8)
	familiar = await _summon_juniper()
	if familiar == null:
		await _finish()
		return
	await _test_forage_task(familiar)
	await _test_persistent_world_state(familiar)

	await _finish()


func _test_hold_task(familiar: SummonedBondedAnimalFamiliar) -> void:
	var receiver: FamiliarTaskReceiver = task_root.get_node("HoldReceiver") as FamiliarTaskReceiver
	familiar.navigation_enabled = false
	familiar.global_position = receiver.get_task_anchor(familiar)
	var preview: Dictionary = manager.get_ability_context_target_preview(
		"move_to",
		receiver.global_position,
		receiver
	)
	_expect(str(preview.get("label", "")) == "Hold Pressure Plate", "Go There reticle becomes Hold Pressure Plate")
	_expect(bool(preview.get("valid", false)), "hold preview is valid for Juniper")
	var result: Dictionary = manager.execute_ability_context_action(
		"move_to",
		preview.get("payload", {})
	)
	_expect(bool(result.get("ok", false)), "task-aware Go There accepts the hold payload")
	await _wait_physics(5)
	_expect(receiver.active, "pressure plate receiver remains active while Juniper holds it")
	var task_state: Dictionary = familiar.get_familiar_task_state()
	_expect(str(task_state.get("task_id", "")) == "hold", "familiar reports the active hold task")
	_expect(str(task_state.get("phase", "")) == "active", "hold task reaches its sustained phase")
	manager.issue_familiar_command("follow")
	await _wait_physics(2)
	_expect(not receiver.active, "Follow releases the held pressure plate")


func _test_ram_task(familiar: SummonedBondedAnimalFamiliar) -> void:
	var receiver: FamiliarTaskReceiver = task_root.get_node("RamReceiver") as FamiliarTaskReceiver
	var obstacle: StaticBody3D = task_root.get_node("RamObstacle") as StaticBody3D
	familiar.navigation_enabled = false
	familiar.global_position = receiver.get_task_anchor(familiar)
	var preview: Dictionary = manager.get_ability_context_target_preview(
		"move_to",
		receiver.global_position,
		receiver
	)
	_expect(str(preview.get("label", "")) == "Ram Barricade", "Go There reticle becomes Ram Barricade")
	var result: Dictionary = manager.execute_ability_context_action("move_to", preview.get("payload", {}))
	_expect(bool(result.get("ok", false)), "Juniper accepts the ram task")
	await _wait_physics(5)
	_expect(receiver.completed, "ram receiver completes after Juniper arrives")
	_expect(not obstacle.visible, "ram task removes the barricade")
	_expect(task_store.is_completed("smoke_test:ram"), "ram completion saves to the task store")
	var repeated: Dictionary = receiver.get_familiar_task_preview(familiar)
	_expect(not bool(repeated.get("valid", true)), "completed barricade cannot be rammed repeatedly")


func _test_forage_task(familiar: SummonedBondedAnimalFamiliar) -> void:
	var receiver: FamiliarTaskReceiver = task_root.get_node("ForageReceiver") as FamiliarTaskReceiver
	var cache: Node3D = task_root.get_node("ForageCache") as Node3D
	var before: int = GameState.get_inventory_count("life_bloom")
	familiar.navigation_enabled = false
	familiar.global_position = receiver.get_task_anchor(familiar)
	var preview: Dictionary = manager.get_ability_context_target_preview(
		"move_to",
		receiver.global_position,
		receiver
	)
	_expect(str(preview.get("label", "")) == "Search Brush", "Go There reticle becomes Search Brush")
	var result: Dictionary = manager.execute_ability_context_action("move_to", preview.get("payload", {}))
	_expect(bool(result.get("ok", false)), "Juniper accepts the forage task")
	await _wait_physics(5)
	_expect(receiver.completed, "forage receiver completes")
	_expect(cache.visible, "forage task reveals the hidden cache")
	_expect(GameState.get_inventory_count("life_bloom") == before + 2, "forage task awards its ingredient reward once")
	_expect(task_store.is_completed("smoke_test:forage"), "forage completion saves to disk-backed state")


func _test_persistent_world_state(familiar: SummonedBondedAnimalFamiliar) -> void:
	var old_ram: FamiliarTaskReceiver = task_root.get_node("RamReceiver") as FamiliarTaskReceiver
	old_ram.queue_free()
	await get_tree().process_frame
	var replacement := TaskReceiverScript.new() as FamiliarTaskReceiver
	replacement.name = "RamReceiverReloaded"
	replacement.task_id = "ram"
	replacement.task_key = "smoke_test:ram"
	replacement.display_name = "Reloaded Barricade"
	replacement.action_label = "Ram Barricade"
	replacement.capability_tag = "ram"
	replacement.one_shot = true
	task_root.add_child(replacement)
	await get_tree().process_frame
	_expect(replacement.completed, "new receiver instance restores completed ram state from disk")
	var preview: Dictionary = replacement.get_familiar_task_preview(familiar)
	_expect(not bool(preview.get("valid", true)), "restored task state remains unavailable after resummoning")
	var unsupported := TaskReceiverScript.new() as FamiliarTaskReceiver
	unsupported.name = "ScoutReceiver"
	unsupported.task_id = "scout"
	unsupported.task_key = "smoke_test:scout"
	unsupported.action_label = "Scout Ahead"
	unsupported.capability_tag = "scout"
	task_root.add_child(unsupported)
	await get_tree().process_frame
	var unsupported_preview: Dictionary = unsupported.get_familiar_task_preview(familiar)
	_expect(not bool(unsupported_preview.get("valid", true)), "receiver rejects a familiar without the required capability")


func _summon_juniper() -> SummonedBondedAnimalFamiliar:
	var ability := AbilityDefinition.new()
	ability.spell_id = "spectral_familiar"
	ability.display_name = "Summon Familiar"
	ability.category = AbilityDefinition.AbilityCategory.SUMMON
	ability.mana_cost = 0
	var summoned: bool = manager.begin_ability_channel(player, ability)
	_expect(summoned, "Summon Familiar manifests equipped Juniper")
	await _wait_frames(12)
	var active: Node3D = manager.get_active_summon()
	_expect(active is SummonedBondedAnimalFamiliar, "active summon uses the bonded familiar actor")
	if active is SummonedBondedAnimalFamiliar:
		var familiar := active as SummonedBondedAnimalFamiliar
		familiar.navigation_enabled = false
		return familiar
	return null


func _build_floor() -> void:
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	floor.collision_layer = 1
	floor.collision_mask = 1
	add_child(floor)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.5, 30.0)
	collision.shape = shape
	collision.position.y = -0.25
	floor.add_child(collision)


func _build_task_fixture() -> void:
	task_root = Node3D.new()
	task_root.name = "TaskFixture"
	add_child(task_root)
	var hold := TaskReceiverScript.new() as FamiliarTaskReceiver
	hold.name = "HoldReceiver"
	hold.position = Vector3(-3.0, 0.15, 0.0)
	hold.task_id = "hold"
	hold.task_key = "smoke_test:hold"
	hold.display_name = "Test Plate"
	hold.action_label = "Hold Pressure Plate"
	hold.capability_tag = "hold"
	hold.persist_completion = false
	task_root.add_child(hold)

	var obstacle := StaticBody3D.new()
	obstacle.name = "RamObstacle"
	obstacle.position = Vector3(0.0, 0.9, 0.0)
	obstacle.collision_layer = 1
	task_root.add_child(obstacle)
	var obstacle_collision := CollisionShape3D.new()
	var obstacle_shape := BoxShape3D.new()
	obstacle_shape.size = Vector3(2.0, 1.8, 0.5)
	obstacle_collision.shape = obstacle_shape
	obstacle.add_child(obstacle_collision)
	var ram := TaskReceiverScript.new() as FamiliarTaskReceiver
	ram.name = "RamReceiver"
	ram.position = Vector3(0.0, 0.15, 1.0)
	ram.task_id = "ram"
	ram.task_key = "smoke_test:ram"
	ram.display_name = "Test Barricade"
	ram.action_label = "Ram Barricade"
	ram.capability_tag = "ram"
	ram.one_shot = true
	ram.affected_node_path = NodePath("../RamObstacle")
	task_root.add_child(ram)

	var cache := Node3D.new()
	cache.name = "ForageCache"
	cache.visible = false
	task_root.add_child(cache)
	var forage := TaskReceiverScript.new() as FamiliarTaskReceiver
	forage.name = "ForageReceiver"
	forage.position = Vector3(3.0, 0.15, 0.0)
	forage.task_id = "forage"
	forage.task_key = "smoke_test:forage"
	forage.display_name = "Test Brush"
	forage.action_label = "Search Brush"
	forage.capability_tag = "forage"
	forage.one_shot = true
	forage.reward_item_id = "life_bloom"
	forage.reward_amount = 2
	forage.revealed_node_path = NodePath("../ForageCache")
	task_root.add_child(forage)


func _wait_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("FAMILIAR_UTILITY_ACTIONS_SMOKE_TEST: " + label)


func _finish() -> void:
	Engine.time_scale = 1.0
	if manager != null and is_instance_valid(manager):
		manager.dismiss_summon(false)
	SpeciesKnowledge.apply_snapshot(original_species_snapshot)
	GameState.stats = original_stats.duplicate(true)
	if player != null and is_instance_valid(player):
		player.queue_free()
	if task_root != null and is_instance_valid(task_root):
		task_root.queue_free()
	await get_tree().process_frame
	_cleanup_files()
	if failures.is_empty():
		print("FAMILIAR_UTILITY_ACTIONS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FAMILIAR_UTILITY_ACTIONS_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _cleanup_files() -> void:
	for path: String in [ROSTER_PATH, BOND_PATH, TASK_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
