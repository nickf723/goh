extends "res://scripts/time/repeat_echo_controller.gd"
class_name RepeatEchoControllerSpellReplay

const CloneSemantics = preload(
	"res://scripts/abilities/spell_clone_semantics.gd"
)
const CloneReplay = preload(
	"res://scripts/abilities/spell_clone_replay.gd"
)
const TrajectoryEchoScript = preload(
	"res://scripts/time/repeat_trajectory_echo.gd"
)

var ability_caster: Node = null
var pending_spell_events: Array[Dictionary] = []
var trajectory_records: Array[Dictionary] = []
var replayed_spell_count: int = 0
var replayed_trajectory_count: int = 0
var suppressed_spell_count: int = 0
var world_state_noop_count: int = 0
var source_state_replay_count: int = 0
var channel_timeline_count: int = 0
var observed_player_cast_count: int = 0
var last_replayed_spell_id: String = "none"
var last_suppressed_spell_id: String = "none"
var last_suppression_reason: String = "none"
var last_cast_metadata: Dictionary = {}


func bind_repeat(
	actor: Node3D,
	manager: Node,
	definition: Resource = null
) -> bool:
	var bound: bool = super.bind_repeat(actor, manager, definition)
	if not bound:
		return false
	ability_caster = source_actor.get_node_or_null("AbilityCaster")
	var tree: SceneTree = get_tree()
	if tree != null:
		var callback := Callable(self, "_on_scene_node_added")
		if not tree.node_added.is_connected(callback):
			tree.node_added.connect(callback)
	return true


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		var callback := Callable(self, "_on_scene_node_added")
		if tree.node_added.is_connected(callback):
			tree.node_added.disconnect(callback)
	pending_spell_events.clear()
	_clear_trajectory_records()
	super._exit_tree()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_queued_for_deletion():
		return
	_advance_trajectory_records(maxf(delta, 0.0))
	_process_spell_events()


func _on_scene_node_added(node: Node) -> void:
	if (
		node == null
		or not is_instance_valid(node)
		or node == self
		or bool(node.get_meta("clone_spell_replay", false))
	):
		return
	var ability: AbilityDefinition = _get_current_player_ability()
	if ability == null or ability.ability_scene == null:
		return
	var scene_path: String = node.scene_file_path
	if scene_path == "" or scene_path != ability.ability_scene.resource_path:
		return
	var observed_source: Node = _read_source_actor(node)
	if observed_source != null and observed_source != source_actor:
		return

	observed_player_cast_count += 1
	var mode: String = CloneSemantics.get_repeat_mode(ability)
	match mode:
		CloneSemantics.REPEAT_TRAJECTORY:
			_begin_trajectory_record(node, ability)
		CloneSemantics.REPEAT_RECAST:
			_schedule_spell_replays(node, ability)
		CloneSemantics.REPEAT_SOURCE_STATE:
			source_state_replay_count += 1
			last_replayed_spell_id = ability.get_spell_id()
		CloneSemantics.REPEAT_CHANNEL:
			channel_timeline_count += 1
			last_replayed_spell_id = ability.get_spell_id()
		CloneSemantics.REPEAT_WORLD_STATE:
			world_state_noop_count += 1
			last_suppressed_spell_id = ability.get_spell_id()
			last_suppression_reason = "world state already exists; Repeat intentionally does nothing"
		_:
			suppressed_spell_count += 1
			last_suppressed_spell_id = ability.get_spell_id()
			last_suppression_reason = "ownership spell is not duplicated by Repeat"


func _get_current_player_ability() -> AbilityDefinition:
	if ability_caster == null or not is_instance_valid(ability_caster):
		return null
	if not ability_caster.has_method("get_current_ability"):
		return null
	var current_value: Variant = ability_caster.call("get_current_ability")
	return current_value as AbilityDefinition if current_value is AbilityDefinition else null


func _read_source_actor(node: Node) -> Node:
	for property_value: Variant in node.get_property_list():
		if not property_value is Dictionary:
			continue
		if str((property_value as Dictionary).get("name", "")) != "source_actor":
			continue
		var source_value: Variant = node.get("source_actor")
		return source_value as Node if source_value is Node else null
	return null


func _begin_trajectory_record(
	original_instance: Node,
	ability: AbilityDefinition
) -> void:
	if not original_instance is Node3D:
		_schedule_spell_replays(original_instance, ability)
		return
	var payload_override: Resource = _capture_payload(original_instance, ability)
	var playback_states: Array[Dictionary] = []
	for echo_index: int in range(echoes.size()):
		playback_states.append({
			"echo_index": echo_index,
			"next_sample": 0,
			"actor": null,
			"finished": false,
		})
	trajectory_records.append({
		"ability": ability,
		"original": weakref(original_instance),
		"payload": payload_override,
		"samples": [],
		"start_time": elapsed,
		"end_time": -1.0,
		"playbacks": playback_states,
	})


func _advance_trajectory_records(delta: float) -> void:
	if trajectory_records.is_empty():
		return
	var remaining_records: Array[Dictionary] = []
	for record_value: Dictionary in trajectory_records:
		var record: Dictionary = record_value
		var original_ref_value: Variant = record.get("original")
		var original: Node3D = null
		if original_ref_value is WeakRef:
			var ref_value: Variant = (original_ref_value as WeakRef).get_ref()
			if ref_value is Node3D and is_instance_valid(ref_value):
				original = ref_value as Node3D
		var samples: Array = record.get("samples", []) as Array
		if original != null and not original.is_queued_for_deletion():
			samples.append({
				"time": elapsed,
				"transform": original.global_transform,
			})
			record["samples"] = samples
		elif float(record.get("end_time", -1.0)) < 0.0:
			record["end_time"] = elapsed

		var playbacks: Array = record.get("playbacks", []) as Array
		for state_index: int in range(playbacks.size()):
			var state: Dictionary = playbacks[state_index] as Dictionary
			if bool(state.get("finished", false)):
				continue
			var echo_index: int = int(state.get("echo_index", -1))
			if echo_index < 0 or echo_index >= echoes.size():
				state["finished"] = true
				playbacks[state_index] = state
				continue
			var echo: RepeatEchoActor = echoes[echo_index]
			if echo == null or not is_instance_valid(echo):
				state["finished"] = true
				playbacks[state_index] = state
				continue
			var playback_time: float = elapsed - echo.replay_delay
			var next_sample: int = int(state.get("next_sample", 0))
			var playback_value: Variant = state.get("actor")
			var playback: RepeatTrajectoryEcho = (
				playback_value as RepeatTrajectoryEcho
				if playback_value is RepeatTrajectoryEcho
				else null
			)
			while next_sample < samples.size():
				var sample: Dictionary = samples[next_sample] as Dictionary
				if float(sample.get("time", INF)) > playback_time:
					break
				if playback == null:
					playback = _spawn_trajectory_echo(record, echo)
					state["actor"] = playback
					if playback != null:
						replayed_trajectory_count += 1
						var record_ability: AbilityDefinition = record.get("ability") as AbilityDefinition
						last_replayed_spell_id = record_ability.get_spell_id() if record_ability != null else "unknown"
				if playback != null:
					var transform_value: Variant = sample.get("transform")
					if transform_value is Transform3D:
						playback.advance_to(transform_value as Transform3D, delta)
				next_sample += 1
			state["next_sample"] = next_sample
			var end_time: float = float(record.get("end_time", -1.0))
			if end_time >= 0.0 and playback_time >= end_time and next_sample >= samples.size():
				if playback != null and is_instance_valid(playback):
					playback.finish_replay()
				state["finished"] = true
			playbacks[state_index] = state
		record["playbacks"] = playbacks
		var every_playback_finished: bool = true
		for state_value: Variant in playbacks:
			if state_value is Dictionary and not bool((state_value as Dictionary).get("finished", false)):
				every_playback_finished = false
				break
		if not every_playback_finished:
			remaining_records.append(record)
	trajectory_records = remaining_records


func _spawn_trajectory_echo(
	record: Dictionary,
	echo: RepeatEchoActor
) -> RepeatTrajectoryEcho:
	var ability_value: Variant = record.get("ability")
	if not ability_value is AbilityDefinition:
		return null
	var trajectory := TrajectoryEchoScript.new() as RepeatTrajectoryEcho
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	scene_root.add_child(trajectory)
	var payload_value: Variant = record.get("payload")
	trajectory.configure(
		ability_value as AbilityDefinition,
		echo,
		payload_value as Resource if payload_value is Resource else null
	)
	return trajectory


func _clear_trajectory_records() -> void:
	for record: Dictionary in trajectory_records:
		var playbacks: Array = record.get("playbacks", []) as Array
		for state_value: Variant in playbacks:
			if not state_value is Dictionary:
				continue
			var playback_value: Variant = (state_value as Dictionary).get("actor")
			if playback_value is RepeatTrajectoryEcho and is_instance_valid(playback_value):
				(playback_value as RepeatTrajectoryEcho).queue_free()
	trajectory_records.clear()


func _capture_payload(
	original_instance: Node,
	ability: AbilityDefinition
) -> Resource:
	if original_instance != null and original_instance.has_method("get_payload"):
		var payload_value: Variant = original_instance.call("get_payload")
		if payload_value is Resource:
			return (payload_value as Resource).duplicate(true)
	if ability != null and ability.get_action_payload() != null:
		return ability.get_action_payload().duplicate(true)
	return null


func _schedule_spell_replays(
	original_instance: Node,
	ability: AbilityDefinition
) -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		return
	var spawn_height: float = 1.2
	var spawn_distance: float = 1.0
	if ability_caster != null:
		var spawn_height_value: Variant = ability_caster.get("cast_spawn_height")
		var spawn_distance_value: Variant = ability_caster.get("cast_spawn_distance")
		if spawn_height_value != null:
			spawn_height = float(spawn_height_value)
		if spawn_distance_value != null:
			spawn_distance = float(spawn_distance_value)
	var cast_origin: Vector3 = source_actor.global_position + Vector3.UP * spawn_height
	var cast_direction: Vector3 = -source_actor.global_transform.basis.z
	if ability_caster != null and ability_caster.has_method("get_cast_direction"):
		var direction_value: Variant = ability_caster.call(
			"get_cast_direction",
			source_actor,
			cast_origin
		)
		if direction_value is Vector3:
			cast_direction = direction_value as Vector3
	if cast_direction.length_squared() <= 0.0001:
		cast_direction = Vector3.FORWARD
	cast_direction = cast_direction.normalized()
	var payload_override: Resource = _capture_payload(original_instance, ability)
	var cast_metadata: Dictionary = _capture_cast_metadata(ability, payload_override)
	last_cast_metadata = cast_metadata.duplicate(true)
	var origin_offset: Vector3 = cast_origin - source_actor.global_position
	for echo_index: int in range(echoes.size()):
		var echo: RepeatEchoActor = echoes[echo_index]
		if echo == null or not is_instance_valid(echo):
			continue
		pending_spell_events.append({
			"due_time": elapsed + echo.replay_delay,
			"echo_index": echo_index,
			"ability": ability,
			"spell_id": ability.get_spell_id(),
			"cast_direction": cast_direction,
			"origin_offset": origin_offset,
			"spawn_distance": spawn_distance,
			"payload": payload_override.duplicate(true) if payload_override != null else null,
			"cast_metadata": cast_metadata.duplicate(true),
		})


func _capture_cast_metadata(
	ability: AbilityDefinition,
	payload_override: Resource
) -> Dictionary:
	var metadata: Dictionary = {}
	if ability == null:
		return metadata
	match ability.get_spell_id():
		"curling_puck":
			var left_strength: float = Input.get_action_strength("move_left")
			var right_strength: float = Input.get_action_strength("move_right")
			if left_strength > right_strength + 0.12:
				metadata["curl_sign"] = -1.0
			elif right_strength > left_strength + 0.12:
				metadata["curl_sign"] = 1.0
			else:
				metadata["curl_sign"] = 0.0
	if payload_override is DamagePayload:
		var payload: DamagePayload = payload_override as DamagePayload
		if payload.tags.has("charged"):
			metadata["charged"] = true
	return metadata


func _process_spell_events() -> void:
	if pending_spell_events.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for event: Dictionary in pending_spell_events:
		if float(event.get("due_time", INF)) > elapsed:
			remaining.append(event)
			continue
		_replay_spell_event(event)
	pending_spell_events = remaining


func _replay_spell_event(event: Dictionary) -> void:
	var echo_index: int = int(event.get("echo_index", -1))
	if echo_index < 0 or echo_index >= echoes.size():
		return
	var echo: RepeatEchoActor = echoes[echo_index]
	if echo == null or not is_instance_valid(echo):
		return
	var ability_value: Variant = event.get("ability")
	if not ability_value is AbilityDefinition:
		return
	var ability: AbilityDefinition = ability_value as AbilityDefinition
	var payload_value: Variant = event.get("payload")
	var payload: Resource = payload_value as Resource if payload_value is Resource else null
	var metadata_value: Variant = event.get("cast_metadata", {})
	var cast_metadata: Dictionary = (
		(metadata_value as Dictionary).duplicate(true)
		if metadata_value is Dictionary
		else {}
	)
	var replayed: Node = CloneReplay.replay_cast(
		get_tree(),
		echo,
		ability,
		event.get("cast_direction", Vector3.FORWARD) as Vector3,
		event.get("origin_offset", Vector3.UP) as Vector3,
		float(event.get("spawn_distance", 1.0)),
		payload,
		1.0 if bool(cast_metadata.get("charged", false)) else 0.0,
		"repeat",
		cast_metadata
	)
	if replayed == null:
		return
	replayed_spell_count += 1
	last_replayed_spell_id = ability.get_spell_id()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["spell_replay_ready"] = true
	data["repeat_semantics"] = "timeline_reenactment"
	data["observed_player_casts"] = observed_player_cast_count
	data["pending_spell_replays"] = pending_spell_events.size()
	data["active_trajectory_records"] = trajectory_records.size()
	data["replayed_spells"] = replayed_spell_count
	data["replayed_trajectories"] = replayed_trajectory_count
	data["source_state_replays"] = source_state_replay_count
	data["channel_timelines_seen"] = channel_timeline_count
	data["world_state_noops"] = world_state_noop_count
	data["suppressed_spells"] = suppressed_spell_count
	data["last_replayed_spell"] = last_replayed_spell_id
	data["last_suppressed_spell"] = last_suppressed_spell_id
	data["last_suppression_reason"] = last_suppression_reason
	data["last_cast_metadata"] = last_cast_metadata.duplicate(true)
	data["duplicate_semantics_are_separate"] = true
	return data
