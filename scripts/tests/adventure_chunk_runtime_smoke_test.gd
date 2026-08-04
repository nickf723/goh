extends Node

var failures: Array[String] = []
var scope: Node3D
var container: Node
var director: AdventureSequenceDirector
var gate: AdventureChunkGate
var emitters: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	GameState.reset_run()
	_build_graph()
	await _wait_frames(5)
	_validate_initial_graph()

	_emit("prepare_done")
	await _wait_frames(3)
	_validate_after_prepare()

	_emit("combat_done")
	await _wait_frames(3)
	_validate_after_combat()

	var optional_chunk: AdventureChunk = director.get_chunk("optional_cache")
	_expect(optional_chunk != null and optional_chunk.is_available(), "optional branch becomes available independently")
	if optional_chunk != null:
		_expect(director.activate_chunk("optional_cache"), "optional branch activates manually")
		_expect(director.complete_chunk("optional_cache"), "optional branch can complete without changing the main path")

	_emit("exit_done")
	await _wait_frames(3)
	_validate_completed_graph()
	await _validate_persistence_restore()

	director.reset_sequence(true)
	await _wait_frames(3)
	_validate_reset_graph()
	_cleanup_flags()
	_finish()


func _build_graph() -> void:
	scope = Node3D.new()
	scope.name = "AdventureChunkFixture"
	add_child(scope)

	container = Node.new()
	container.name = "AdventureChunks"
	scope.add_child(container)

	_create_content("PrepareContent")
	_create_content("CombatContent")
	_create_content("ExitContent")

	_create_signal_emitter("PrepareEmitter", "prepare_done")
	_create_signal_emitter("CombatEmitter", "combat_done")
	_create_signal_emitter("ExitEmitter", "exit_done")

	_create_signal_chunk(
		"PrepareChunk",
		_make_definition("prepare", [], false, true),
		NodePath("PrepareContent"),
		NodePath("PrepareEmitter"),
		&"done"
	)
	_create_signal_chunk(
		"CombatChunk",
		_make_definition("combat", ["prepare"], false, true),
		NodePath("CombatContent"),
		NodePath("CombatEmitter"),
		&"done"
	)
	_create_signal_chunk(
		"ExitChunk",
		_make_definition("exit", ["combat"], false, true),
		NodePath("ExitContent"),
		NodePath("ExitEmitter"),
		&"done"
	)
	_create_manual_chunk(
		"OptionalCacheChunk",
		_make_definition("optional_cache", ["prepare"], true, false)
	)

	director = AdventureSequenceDirector.new()
	director.name = "AdventureSequenceDirector"
	director.sequence_id = "adventure_chunk_smoke"
	director.completion_flag = "adventure_sequence_adventure_chunk_smoke"
	director.chunk_container_path = NodePath("AdventureChunks")
	director.auto_initialize = false
	director.auto_start = true
	scope.add_child(director)
	director.bind_scope(scope)

	gate = AdventureChunkGate.new()
	gate.name = "PrepareGate"
	gate.required_chunk_id = "prepare"
	gate.hide_when_unlocked = false
	scope.add_child(gate)

	_expect(director.initialize_sequence(), "sequence graph initializes")
	gate.bind_director(director)


func _make_definition(
	chunk_id: String,
	dependencies: Array[String],
	optional: bool,
	auto_activate: bool
) -> AdventureChunkDefinition:
	var definition := AdventureChunkDefinition.new()
	definition.chunk_id = chunk_id
	definition.display_name = chunk_id.replace("_", " ").capitalize()
	definition.required_chunk_ids = dependencies
	definition.optional = optional
	definition.auto_activate_when_available = auto_activate
	definition.completion_policy = (
		AdventureChunkDefinition.CompletionPolicy.MANUAL
		if optional
		else AdventureChunkDefinition.CompletionPolicy.ALL_REQUIREMENTS
	)
	definition.completion_flag = "adventure_chunk_smoke_" + chunk_id
	definition.hide_content_when_locked = true
	definition.disable_content_when_locked = true
	definition.keep_content_after_complete = true
	return definition


func _create_content(node_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 1
	scope.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE
	collision.shape = shape
	body.add_child(collision)
	return body


func _create_signal_emitter(node_name: String, key: String) -> Node:
	var emitter := Node.new()
	emitter.name = node_name
	emitter.add_user_signal("done")
	scope.add_child(emitter)
	emitters[key] = emitter
	return emitter


func _create_signal_chunk(
	node_name: String,
	definition: AdventureChunkDefinition,
	content_path: NodePath,
	source_path: NodePath,
	source_signal: StringName
) -> AdventureChunk:
	var chunk := AdventureChunk.new()
	chunk.name = node_name
	chunk.definition = definition
	var paths: Array[NodePath] = [content_path]
	chunk.managed_content_paths = paths
	var requirement := AdventureSignalRequirement.new()
	requirement.name = "CompletionRequirement"
	requirement.requirement_id = definition.chunk_id + "_complete"
	requirement.display_name = "Complete " + definition.display_name
	requirement.source_path = source_path
	requirement.source_signal = source_signal
	chunk.add_child(requirement)
	container.add_child(chunk)
	chunk.bind_scope(scope)
	return chunk


func _create_manual_chunk(
	node_name: String,
	definition: AdventureChunkDefinition
) -> AdventureChunk:
	var chunk := AdventureChunk.new()
	chunk.name = node_name
	chunk.definition = definition
	container.add_child(chunk)
	chunk.bind_scope(scope)
	return chunk


func _emit(key: String) -> void:
	var emitter: Node = emitters.get(key) as Node
	if emitter != null:
		emitter.emit_signal("done")


func _validate_initial_graph() -> void:
	_expect(director.validation_errors.is_empty(), "graph validation has no errors")
	_expect(director.get_chunk_state("prepare") == "ACTIVE", "root chunk auto-activates")
	_expect(director.get_chunk_state("combat") == "LOCKED", "dependent combat chunk starts locked")
	_expect(director.get_chunk_state("exit") == "LOCKED", "deep dependent chunk starts locked")
	_expect(director.get_chunk_state("optional_cache") == "LOCKED", "optional dependency remains locked before prerequisite")
	_expect(scope.get_node("PrepareContent").visible, "active content remains visible")
	_expect(not scope.get_node("CombatContent").visible, "locked content is hidden")
	_expect((scope.get_node("CombatContent") as CollisionObject3D).collision_layer == 0, "locked content collision is disabled")
	_expect(gate.is_locked(), "dependency gate starts locked")


func _validate_after_prepare() -> void:
	_expect(director.get_chunk_state("prepare") == "COMPLETED", "signal completes the preparation chunk")
	_expect(director.get_chunk_state("combat") == "ACTIVE", "combat chunk activates after its dependency")
	_expect(director.get_chunk_state("optional_cache") == "AVAILABLE", "optional branch becomes available after its dependency")
	_expect(scope.get_node("CombatContent").visible, "combat content becomes visible on activation")
	_expect((scope.get_node("CombatContent") as CollisionObject3D).collision_layer != 0, "combat collision restores on activation")
	_expect(not gate.is_locked(), "dependency gate unlocks when its chunk completes")


func _validate_after_combat() -> void:
	_expect(director.get_chunk_state("combat") == "COMPLETED", "combat signal completes its chunk")
	_expect(director.get_chunk_state("exit") == "ACTIVE", "exit chunk activates after combat")
	_expect(not director.completed, "main sequence waits for the final required chunk")


func _validate_completed_graph() -> void:
	_expect(director.completed, "all required chunks complete the sequence")
	_expect(GameState.get_flag("adventure_sequence_adventure_chunk_smoke"), "sequence completion persists to a flag")
	_expect(director.completion_order == ["prepare", "combat", "optional_cache", "exit"], "completion order records the graph journey")
	_expect(director.get_completed_chunk_ids().size() == 4, "required and optional completions share one snapshot")


func _validate_persistence_restore() -> void:
	var restore_scope := Node3D.new()
	restore_scope.name = "RestoreFixture"
	add_child(restore_scope)
	var restore_container := Node.new()
	restore_container.name = "AdventureChunks"
	restore_scope.add_child(restore_container)
	for chunk_id: String in ["prepare", "combat", "exit"]:
		var dependencies: Array[String] = []
		if chunk_id == "combat":
			dependencies = ["prepare"]
		elif chunk_id == "exit":
			dependencies = ["combat"]
		var chunk := AdventureChunk.new()
		chunk.name = chunk_id.capitalize() + "RestoreChunk"
		chunk.definition = _make_definition(chunk_id, dependencies, false, true)
		restore_container.add_child(chunk)
		chunk.bind_scope(restore_scope)
	var restore_director := AdventureSequenceDirector.new()
	restore_director.name = "RestoreDirector"
	restore_director.sequence_id = "adventure_chunk_smoke"
	restore_director.completion_flag = "adventure_sequence_adventure_chunk_smoke"
	restore_director.chunk_container_path = NodePath("AdventureChunks")
	restore_director.auto_initialize = false
	restore_scope.add_child(restore_director)
	restore_director.bind_scope(restore_scope)
	_expect(restore_director.initialize_sequence(), "restored sequence initializes")
	await _wait_frames(2)
	_expect(restore_director.completed, "sequence completion restores from GameState")
	_expect(restore_director.get_completed_chunk_ids().size() == 3, "individual chunk flags restore their states")
	restore_scope.queue_free()
	await get_tree().process_frame


func _validate_reset_graph() -> void:
	_expect(not director.completed, "reset clears sequence completion")
	_expect(director.get_chunk_state("prepare") == "ACTIVE", "reset restarts the root chunk")
	_expect(director.get_chunk_state("combat") == "LOCKED", "reset relocks dependent content")
	_expect(gate.is_locked(), "reset relocks dependency gates")
	_expect(not GameState.get_flag("adventure_sequence_adventure_chunk_smoke"), "reset clears the sequence flag")


func _cleanup_flags() -> void:
	for flag: String in [
		"adventure_sequence_adventure_chunk_smoke",
		"adventure_chunk_smoke_prepare",
		"adventure_chunk_smoke_combat",
		"adventure_chunk_smoke_exit",
		"adventure_chunk_smoke_optional_cache",
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
	push_error("ADVENTURE_CHUNK_RUNTIME_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("ADVENTURE_CHUNK_RUNTIME_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ADVENTURE_CHUNK_RUNTIME_SMOKE_TEST: " + failure)
	get_tree().quit(1)
