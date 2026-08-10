extends Node
class_name RuinedVillageAdventureSliceDirector

const InvestigationDefinition: AdventureChunkDefinition = preload(
	"res://data/adventure/chunks/ruined_village_investigation.tres"
)
const SquareCombatDefinition: AdventureChunkDefinition = preload(
	"res://data/adventure/chunks/ruined_village_square_combat.tres"
)
const RavineChoiceDefinition: AdventureChunkDefinition = preload(
	"res://data/adventure/chunks/ruined_village_ravine_choice.tres"
)
const SoundMemoryDefinition: AdventureChunkDefinition = preload(
	"res://data/adventure/chunks/ruined_village_sound_memory.tres"
)
const ChurchThresholdDefinition: AdventureChunkDefinition = preload(
	"res://data/adventure/chunks/ruined_village_church_threshold.tres"
)
const StartingLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_starting_loadout.tres"
)

const PRODUCTION_ROOT_NAME: String = "PrototypeRuinedVillageApproach"
const INVESTIGATION_OBJECTIVE: String = (
	"Inspect the impact crater, the severed foundation, and the abandoned hearth."
)
const NON_PRODUCTION_LABEL_TOKENS: Array[String] = [
	"THE VANISHED VILLAGE",
	"CHURCH OF ANGELS",
	"VILLAGE SQUARE",
	"ABANDONED ARMORY",
	"FIRE  OR  ICE + HEAVY",
	"WATER  →  ICE",
]

var scope_root: Node
var chunks_root: Node
var sequence_director: AdventureSequenceDirector
var slice_active: bool = false
var hidden_signage_count: int = 0


func _ready() -> void:
	add_to_group("ruined_village_adventure_slice_director")
	add_to_group("debuggable")
	call_deferred("_initialize_slice")


func _initialize_slice() -> void:
	# The village root awaits save restoration during its own ready path. Give the
	# authored level time to generate its clues, encounter, puzzle routes, and exit
	# before binding the adventure graph to those existing lifecycle surfaces.
	for _index: int in range(6):
		await get_tree().process_frame

	scope_root = get_parent()
	if scope_root == null or str(scope_root.name) != PRODUCTION_ROOT_NAME:
		set_meta("production_slice_active", false)
		return

	slice_active = true
	scope_root.set_meta("first_production_adventure_slice", "v1")
	scope_root.set_meta("slice_target_minutes", 15)
	_configure_player_for_slice()
	_configure_authored_objectives()
	_hide_non_production_signage()
	_build_adventure_graph()
	set_meta("production_slice_active", true)


func _configure_player_for_slice() -> void:
	var player: Node = scope_root.get_node_or_null("Player")
	if player == null:
		return

	# The older village launch was a spell showcase that deliberately selected
	# Flight and unlocked aerial traversal. The production slice returns to the
	# shared player loadout and starts on Arcane Spark so the authored ravine
	# choices remain meaningful instead of being bypassed by a lab convenience.
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster != null:
		caster.set("loadout", StartingLoadout.duplicate(true))
		caster.set("current_ability_index", 0)
		if caster.has_method("align_focus_menu_to_current_ability"):
			caster.call("align_focus_menu_to_current_ability")
		if caster.has_method("emit_current_ability"):
			caster.call("emit_current_ability")

	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	if aerial != null:
		if "double_jump_unlocked" in aerial:
			aerial.set("double_jump_unlocked", false)
		if "hover_unlocked" in aerial:
			aerial.set("hover_unlocked", false)
		if "flight_unlocked" in aerial:
			aerial.set("flight_unlocked", false)

	GameState.restore_rest_resources()


func _configure_authored_objectives() -> void:
	# Before Adventure Chunks, each clue advanced the objective independently.
	# During the production slice all three clues form one investigation beat, so
	# keep the same objective until the chunk itself completes. The optional Sound
	# memory also stays narratively rewarding without hijacking the main route.
	for path: NodePath in [
		NodePath("VillageInteractions/ArrivalCraterClue"),
		NodePath("VillageInteractions/LiftedFoundationClue"),
		NodePath("VillageInteractions/EmptyHearthClue"),
	]:
		var clue: Node = scope_root.get_node_or_null(path)
		if clue != null and "objective_after" in clue:
			clue.set("objective_after", INVESTIGATION_OBJECTIVE)

	var memory: Node = scope_root.get_node_or_null(
		"VillageInteractions/HiddenWoodenBirdMemory"
	)
	if memory != null and "objective_after" in memory:
		memory.set("objective_after", "")


func _hide_non_production_signage() -> void:
	hidden_signage_count = 0
	for candidate: Node in scope_root.find_children("*", "Label3D", true, false):
		var label := candidate as Label3D
		if label == null:
			continue
		var copy: String = label.text.strip_edges()
		for token: String in NON_PRODUCTION_LABEL_TOKENS:
			if copy.contains(token):
				label.visible = false
				hidden_signage_count += 1
				break


func _build_adventure_graph() -> void:
	if scope_root.get_node_or_null("AdventureChunks") != null:
		return

	chunks_root = Node.new()
	chunks_root.name = "AdventureChunks"

	var investigation: AdventureChunk = _make_chunk(
		"Investigation",
		InvestigationDefinition,
		[
			_make_requirement(
				"impact_crater",
				"Inspect the impact crater",
				NodePath("VillageInteractions/ArrivalCraterClue"),
				&"clue_inspected",
				&"has_been_read",
				&"reset_clue"
			),
			_make_requirement(
				"severed_foundation",
				"Inspect the severed foundation",
				NodePath("VillageInteractions/LiftedFoundationClue"),
				&"clue_inspected",
				&"has_been_read",
				&"reset_clue"
			),
			_make_requirement(
				"abandoned_hearth",
				"Inspect the abandoned hearth",
				NodePath("VillageInteractions/EmptyHearthClue"),
				&"clue_inspected",
				&"has_been_read",
				&"reset_clue"
			),
		]
	)
	chunks_root.add_child(investigation)

	var square_combat: AdventureChunk = _make_chunk(
		"SquareCombat",
		SquareCombatDefinition,
		[
			_make_requirement(
				"clear_scavengers",
				"Clear the scavenger ambush",
				NodePath("VillageEncounters/VillageSquareEncounter"),
				&"encounter_completed",
				&"is_complete",
				&"reset_encounter"
			),
		]
	)
	chunks_root.add_child(square_combat)

	var ravine_choice: AdventureChunk = _make_chunk(
		"RavineChoice",
		RavineChoiceDefinition,
		[
			_make_requirement(
				"clear_debris_route",
				"Clear the root-choked bridge",
				NodePath("VillagePuzzles/RavineDebrisGate"),
				&"gate_opened",
				&"is_open",
				&"reset_gate"
			),
			_make_requirement(
				"freeze_water_route",
				"Freeze the flooded crossing",
				NodePath("VillagePuzzles/WaterIceRavineBridge"),
				&"bridge_frozen",
				&"is_frozen_bridge",
				&"reset_bridge"
			),
		]
	)
	chunks_root.add_child(ravine_choice)

	var sound_memory: AdventureChunk = _make_chunk(
		"SoundMemory",
		SoundMemoryDefinition,
		[
			_make_requirement(
				"recover_memory",
				"Recover the wooden-bird memory",
				NodePath("VillageInteractions/HiddenWoodenBirdMemory"),
				&"memory_found",
				&"has_been_found",
				&"reset_memory"
			),
		]
	)
	chunks_root.add_child(sound_memory)

	var church_threshold: AdventureChunk = _make_chunk(
		"ChurchThreshold",
		ChurchThresholdDefinition,
		[
			_make_requirement(
				"enter_church_trial",
				"Enter the Church Trial",
				NodePath("VillageInteractions/ChurchTrialEntrance"),
				&"exit_triggered",
				&"has_triggered",
				&"reset_exit"
			),
		]
	)
	chunks_root.add_child(church_threshold)

	# Add the fully-authored chunk subtree in one operation so every chunk already
	# owns its requirements before _ready() can initialize it.
	scope_root.add_child(chunks_root)
	for child: Node in chunks_root.get_children():
		if child is AdventureChunk:
			(child as AdventureChunk).bind_scope(scope_root)

	sequence_director = AdventureSequenceDirector.new()
	sequence_director.name = "FirstProductionAdventureSequence"
	sequence_director.sequence_id = "first_production_adventure_slice_v1"
	sequence_director.display_name = "Vanished Village to Church Trial"
	sequence_director.completion_flag = "first_production_adventure_slice_v1"
	sequence_director.chunk_container_path = NodePath("AdventureChunks")
	sequence_director.auto_initialize = false
	sequence_director.auto_start = true
	sequence_director.completion_message = "The village leg is complete. The Church Trial continues the journey."
	sequence_director.objective_on_complete = "Complete the Church Trial."
	scope_root.add_child(sequence_director)
	sequence_director.bind_scope(scope_root)
	sequence_director.initialize_sequence()


func _make_chunk(
	node_name: String,
	definition: AdventureChunkDefinition,
	requirement_nodes: Array
) -> AdventureChunk:
	var chunk := AdventureChunk.new()
	chunk.name = node_name
	chunk.definition = definition
	chunk.auto_bind_requirements = true
	for requirement_value: Variant in requirement_nodes:
		if requirement_value is AdventureSignalRequirement:
			chunk.add_child(requirement_value as AdventureSignalRequirement)
	return chunk


func _make_requirement(
	requirement_id: String,
	display_name: String,
	source_path: NodePath,
	source_signal: StringName,
	source_property: StringName,
	reset_method: StringName
) -> AdventureSignalRequirement:
	var requirement := AdventureSignalRequirement.new()
	requirement.name = requirement_id.capitalize().replace(" ", "")
	requirement.requirement_id = requirement_id
	requirement.display_name = display_name
	requirement.source_path = source_path
	requirement.source_signal = source_signal
	requirement.source_property = source_property
	requirement.source_reset_method = reset_method
	requirement.expected_boolean_value = true
	requirement.complete_on_signal = true
	return requirement


func get_debug_data() -> Dictionary:
	return {
		"ruined_village_adventure_slice_director": true,
		"active": slice_active,
		"sequence_id": (
			sequence_director.get_normalized_sequence_id()
			if sequence_director != null
			else ""
		),
		"graph": (
			sequence_director.get_graph_snapshot()
			if sequence_director != null
			else {}
		),
		"hidden_non_production_signage": hidden_signage_count,
		"production_player_start": true,
		"automatic_flight_disabled": true,
	}
