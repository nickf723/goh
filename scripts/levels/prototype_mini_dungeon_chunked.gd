extends "res://scripts/levels/prototype_mini_dungeon_chain.gd"
class_name PrototypeMiniDungeonChunked

const PREPARE_DEFINITION: AdventureChunkDefinition = preload(
	"res://data/adventure/chunks/mini_dungeon_prepare.tres"
)
const COMBAT_DEFINITION: AdventureChunkDefinition = preload(
	"res://data/adventure/chunks/mini_dungeon_combat.tres"
)
const PUZZLE_DEFINITION: AdventureChunkDefinition = preload(
	"res://data/adventure/chunks/mini_dungeon_element_lock.tres"
)
const EXIT_DEFINITION: AdventureChunkDefinition = preload(
	"res://data/adventure/chunks/mini_dungeon_exit.tres"
)

@export var install_adventure_chunk_runtime: bool = true

var adventure_chunks_root: Node
var adventure_sequence: AdventureSequenceDirector
var preparation_gate: AdventureChunkGate


func _ready() -> void:
	await super._ready()
	if install_adventure_chunk_runtime:
		_install_adventure_runtime()


func _install_adventure_runtime() -> void:
	if get_node_or_null("AdventureSequenceDirector") != null:
		return

	adventure_chunks_root = Node.new()
	adventure_chunks_root.name = "AdventureChunks"
	add_child(adventure_chunks_root)

	_create_signal_chunk(
		"PrepareChunk",
		PREPARE_DEFINITION,
		_typed_paths([NodePath("Room1")]),
		"use_mana_shrine",
		"Use the mana shrine",
		NodePath("Room1/ManaShrine"),
		&"shrine_used",
		StringName(),
		StringName()
	)
	_create_signal_chunk(
		"CombatChunk",
		COMBAT_DEFINITION,
		_typed_paths([NodePath("Room2Combat")]),
		"clear_combat_room",
		"Defeat all enemies",
		NodePath("Room2Combat/EncounterManager"),
		&"encounter_completed",
		&"encounter_complete",
		&"reset_encounter_state"
	)
	_create_signal_chunk(
		"ElementLockChunk",
		PUZZLE_DEFINITION,
		_typed_paths([NodePath("Room3Puzzle")]),
		"solve_element_lock",
		"Activate both elemental locks",
		NodePath("Room3Puzzle/ElementLockController"),
		&"puzzle_completed",
		&"puzzle_complete",
		&"reset_puzzle_state"
	)
	_create_signal_chunk(
		"ExitChunk",
		EXIT_DEFINITION,
		_typed_paths([]),
		"reach_exit",
		"Reach the final exit",
		NodePath("Room3Puzzle/LevelExit"),
		&"exit_triggered",
		&"has_triggered",
		&"reset_exit"
	)

	adventure_sequence = AdventureSequenceDirector.new()
	adventure_sequence.name = "AdventureSequenceDirector"
	adventure_sequence.sequence_id = "prototype_mini_dungeon"
	adventure_sequence.display_name = "Prototype Mini-Dungeon"
	adventure_sequence.completion_flag = "adventure_sequence_prototype_mini_dungeon"
	adventure_sequence.chunk_container_path = NodePath("AdventureChunks")
	adventure_sequence.completion_message = "The four adventure chunks resolve into one completed trial."
	adventure_sequence.objective_on_complete = "Mini-dungeon complete."
	adventure_sequence.auto_initialize = false
	adventure_sequence.auto_start = true
	add_child(adventure_sequence)
	adventure_sequence.bind_scope(self)

	preparation_gate = AdventureChunkGate.new()
	preparation_gate.name = "PreparationChunkGate"
	preparation_gate.required_chunk_id = "mini_dungeon_prepare"
	preparation_gate.gate_name = "Preparation Seal"
	preparation_gate.gate_size = Vector3(6.8, 3.0, 0.7)
	preparation_gate.position = Vector3(0.0, 1.0, 12.0)
	add_child(preparation_gate)

	adventure_sequence.initialize_sequence()
	preparation_gate.bind_director(adventure_sequence)


func _create_signal_chunk(
	node_name: String,
	chunk_definition: AdventureChunkDefinition,
	content_paths: Array[NodePath],
	requirement_id: String,
	requirement_name: String,
	source_path: NodePath,
	source_signal: StringName,
	source_property: StringName,
	source_reset_method: StringName
) -> AdventureChunk:
	var chunk := AdventureChunk.new()
	chunk.name = node_name
	chunk.definition = chunk_definition
	chunk.managed_content_paths = content_paths
	chunk.auto_bind_requirements = true

	var requirement := AdventureSignalRequirement.new()
	requirement.name = requirement_name.replace(" ", "") + "Requirement"
	requirement.requirement_id = requirement_id
	requirement.display_name = requirement_name
	requirement.source_path = source_path
	requirement.source_signal = source_signal
	requirement.source_property = source_property
	requirement.source_reset_method = source_reset_method
	chunk.add_child(requirement)

	adventure_chunks_root.add_child(chunk)
	chunk.bind_scope(self)
	return chunk


func _typed_paths(raw_paths: Array) -> Array[NodePath]:
	var paths: Array[NodePath] = []
	for value: Variant in raw_paths:
		if value is NodePath:
			paths.append(value as NodePath)
	return paths


func get_adventure_sequence() -> AdventureSequenceDirector:
	return adventure_sequence


func get_adventure_chunk(chunk_id: String) -> AdventureChunk:
	return adventure_sequence.get_chunk(chunk_id) if adventure_sequence != null else null


func reset_adventure_chunks() -> void:
	if adventure_sequence != null:
		adventure_sequence.reset_sequence(true)


func get_adventure_chunk_debug_data() -> Dictionary:
	return adventure_sequence.get_debug_data() if adventure_sequence != null else {
		"initialized": false,
		"error": "Adventure sequence unavailable",
	}
