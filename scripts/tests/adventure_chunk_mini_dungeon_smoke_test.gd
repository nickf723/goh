extends Node

const ChunkedMiniDungeon: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_mini_dungeon_chunked_v1.tscn"
)

var failures: Array[String] = []
var level: Node3D
var director: AdventureSequenceDirector


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	GameState.reset_run()
	_cleanup_flags()
	level = ChunkedMiniDungeon.instantiate() as Node3D
	level.set("apply_save_on_ready", false)
	level.set("add_entry_save_bed", false)
	level.set("enable_death_retry_from_save", false)
	add_child(level)
	await _wait_frames(18)

	director = level.call("get_adventure_sequence") as AdventureSequenceDirector
	_validate_initial_state()

	var shrine: Node = level.get_node_or_null("Room1/ManaShrine")
	_expect(shrine != null, "production preparation shrine exists")
	if shrine != null:
		shrine.call("interact")
	await _wait_frames(4)
	_validate_combat_activation()

	var encounter: Node = level.get_node_or_null("Room2Combat/EncounterManager")
	_expect(encounter != null, "production combat source exists")
	if encounter != null:
		encounter.call("complete_encounter")
	await _wait_frames(4)
	_validate_puzzle_activation()

	var puzzle: Node = level.get_node_or_null("Room3Puzzle/ElementLockController")
	_expect(puzzle != null, "production puzzle source exists")
	if puzzle != null:
		puzzle.call("complete_puzzle")
	await _wait_frames(4)
	_validate_exit_activation()

	var exit_node: Node = level.get_node_or_null("Room3Puzzle/LevelExit")
	_expect(exit_node != null, "production exit source exists")
	if exit_node != null:
		exit_node.call("trigger_exit")
	await _wait_frames(4)
	_validate_sequence_completion()

	level.queue_free()
	await get_tree().process_frame
	_cleanup_flags()
	_finish()


func _validate_initial_state() -> void:
	_expect(director != null, "mini-dungeon installs an adventure sequence director")
	if director == null:
		return
	_expect(director.validation_errors.is_empty(), "production chunk graph validates")
	_expect(director.chunks.size() == 4, "mini-dungeon exposes four authored chunks")
	_expect(director.get_chunk_state("mini_dungeon_prepare") == "ACTIVE", "preparation chunk owns the opening")
	_expect(director.get_chunk_state("mini_dungeon_combat") == "LOCKED", "combat chunk starts locked")
	_expect(director.get_chunk_state("mini_dungeon_element_lock") == "LOCKED", "puzzle chunk starts locked")
	_expect(director.get_chunk_state("mini_dungeon_exit") == "LOCKED", "exit chunk starts locked")
	var room_2 := level.get_node_or_null("Room2Combat") as Node3D
	var room_3 := level.get_node_or_null("Room3Puzzle") as Node3D
	_expect(room_2 != null and not room_2.visible, "locked combat content is hidden")
	_expect(room_3 != null and not room_3.visible, "locked puzzle content is hidden")
	var gate := level.get_node_or_null("PreparationChunkGate") as AdventureChunkGate
	_expect(gate != null and gate.is_locked(), "preparation seal blocks early room skipping")


func _validate_combat_activation() -> void:
	if director == null:
		return
	_expect(director.get_chunk_state("mini_dungeon_prepare") == "COMPLETED", "shrine signal completes preparation")
	_expect(director.get_chunk_state("mini_dungeon_combat") == "ACTIVE", "combat activates from the dependency graph")
	var room_2 := level.get_node_or_null("Room2Combat") as Node3D
	_expect(room_2 != null and room_2.visible, "combat room wakes on chunk activation")
	var gate := level.get_node_or_null("PreparationChunkGate") as AdventureChunkGate
	_expect(gate != null and not gate.is_locked(), "preparation seal opens after the shrine")
	_expect(GameState.current_objective.contains("Defeat every enemy"), "combat chunk owns the objective")


func _validate_puzzle_activation() -> void:
	if director == null:
		return
	_expect(director.get_chunk_state("mini_dungeon_combat") == "COMPLETED", "encounter completion resolves the combat chunk")
	_expect(director.get_chunk_state("mini_dungeon_element_lock") == "ACTIVE", "puzzle activates after combat")
	var room_3 := level.get_node_or_null("Room3Puzzle") as Node3D
	_expect(room_3 != null and room_3.visible, "puzzle room wakes on chunk activation")
	_expect(GameState.current_objective.contains("Water and Fire"), "puzzle chunk owns the objective")


func _validate_exit_activation() -> void:
	if director == null:
		return
	_expect(director.get_chunk_state("mini_dungeon_element_lock") == "COMPLETED", "element-lock signal resolves the puzzle chunk")
	_expect(director.get_chunk_state("mini_dungeon_exit") == "ACTIVE", "exit activates after the puzzle")
	_expect(GameState.current_objective.contains("gold exit pad"), "exit chunk owns the final objective")


func _validate_sequence_completion() -> void:
	if director == null:
		return
	_expect(director.get_chunk_state("mini_dungeon_exit") == "COMPLETED", "level exit resolves the final chunk")
	_expect(director.completed, "four completed chunks resolve the sequence")
	_expect(GameState.get_flag("adventure_sequence_prototype_mini_dungeon"), "production sequence completion persists")
	_expect(
		director.completion_order == [
			"mini_dungeon_prepare",
			"mini_dungeon_combat",
			"mini_dungeon_element_lock",
			"mini_dungeon_exit",
		],
		"production sequence records deterministic completion order"
	)
	var debug: Dictionary = level.call("get_adventure_chunk_debug_data") as Dictionary
	_expect(bool(debug.get("completed", false)), "level exposes the chunk graph through its debug contract")


func _cleanup_flags() -> void:
	for flag: String in [
		"adventure_chunk_mini_dungeon_prepare",
		"adventure_chunk_mini_dungeon_combat",
		"adventure_chunk_mini_dungeon_element_lock",
		"adventure_chunk_mini_dungeon_exit",
		"adventure_sequence_prototype_mini_dungeon",
	]:
		GameState.set_flag(flag, false)


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("ADVENTURE_CHUNK_MINI_DUNGEON_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("ADVENTURE_CHUNK_MINI_DUNGEON_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ADVENTURE_CHUNK_MINI_DUNGEON_SMOKE_TEST: " + failure)
	get_tree().quit(1)
