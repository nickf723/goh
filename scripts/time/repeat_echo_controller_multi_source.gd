extends "res://scripts/time/repeat_echo_controller_time_memory.gd"
class_name RepeatEchoControllerMultiSource

const RepeatEchoActorScriptMulti = preload(
	"res://scripts/time/repeat_echo_actor.gd"
)
const CloneSemanticsMulti = preload(
	"res://scripts/abilities/spell_clone_semantics.gd"
)
const CloneReplayMulti = preload(
	"res://scripts/abilities/spell_clone_replay.gd"
)
const StableTrajectoryEchoMulti = preload(
	"res://scripts/time/repeat_trajectory_echo_stable.gd"
)
const ChannelEchoMulti = preload(
	"res://scripts/time/repeat_channel_echo.gd"
)
const FirewallEchoMulti = preload(
	"res://scripts/time/repeat_firewall_echo.gd"
)

var secondary_lanes: Dictionary = {}
var secondary_attack_events: Array[Dictionary] = []
var secondary_spell_events: Array[Dictionary] = []
var secondary_trajectory_records: Array[Dictionary] = []
var secondary_channel_records: Array[Dictionary] = []
var secondary_firewall_records: Array[Dictionary] = []
var secondary_source_echo_count: int = 0
var secondary_replayed_attack_count: int = 0
var secondary_replayed_spell_count: int = 0


func bind_repeat(
	actor: Node3D,
	manager: Node,
	definition: Resource = null
) -> bool:
	var bound: bool = super.bind_repeat(actor, manager, definition)
	if not bound:
		return false
	call_deferred("_discover_existing_duplicate_sources")
	return true


func _exit_tree() -> void:
	_clear_secondary_lanes()
	secondary_attack_events.clear()
	secondary_spell_events.clear()
	_clear_secondary_records()
	super._exit_tree()


func register_repeat_source(actor: Node3D) -> bool:
	if not super.register_repeat_source(actor):
		return false
	if actor == null or not is_instance_valid(actor) or actor == source_actor:
		return actor == source_actor
	var source_id: int = actor.get_instance_id()
	if secondary_lanes.has(source_id):
		return true
	var visual: Node3D = actor.get_node_or_null("GraceVisualV1") as Node3D
	if visual == null:
		return false
	var source_echoes: Array[RepeatEchoActor] = []
	var parent: Node = get_tree().current_scene
	if parent == null:
		return false
	for index: int in range(maxi(echo_count, 1)):
		var echo := RepeatEchoActorScriptMulti.new() as RepeatEchoActor
		echo.configure(
			index,
			delay_seconds + float(index) * echo_spacing_seconds
		)
		echo.name = "RepeatEcho_Soul_%d_%02d" % [source_id, index + 1]
		echo.set_meta("repeat_source_id", source_id)
		echo.set_meta("repeat_source_kind", "soul_duplicate")
		parent.add_child(echo)
		source_echoes.append(echo)
		secondary_source_echo_count += 1
	secondary_lanes[source_id] = {
		"source": weakref(actor),
		"visual": weakref(visual),
		"history": [],
		"echoes": source_echoes,
		"recorded": 0,
	}
	_record_secondary_snapshot(source_id)
	return true


func unregister_repeat_source(actor: Node3D) -> void:
	if actor == null:
		return
	_remove_secondary_lane(actor.get_instance_id())


func record_registered_source_attack(
	actor: Node3D,
	attack: WeaponAttackDefinition,
	weapon: WeaponDefinition,
	attack_forward: Vector3
) -> void:
	if actor == null or attack == null:
		return
	var source_id: int = actor.get_instance_id()
	if not secondary_lanes.has(source_id):
		if not register_repeat_source(actor):
			return
	var lane: Dictionary = secondary_lanes[source_id] as Dictionary
	var lane_echoes: Array = lane.get("echoes", []) as Array
	var payload: DamagePayload = attack.build_payload(weapon)
	if payload == null:
		return
	for tag: String in ["time", "repeat", "echo", "soul_source"]:
		if not payload.tags.has(tag):
			payload.tags.append(tag)
	for echo_index: int in range(lane_echoes.size()):
		var echo: RepeatEchoActor = lane_echoes[echo_index] as RepeatEchoActor
		if echo == null:
			continue
		secondary_attack_events.append({
			"due_time": elapsed + echo.replay_delay,
			"source_id": source_id,
			"echo_index": echo_index,
			"attack_id": attack.attack_id,
			"range": attack.attack_range,
			"cone": attack.cone_angle_degrees,
			"offset": attack.attack_center_forward_offset,
			"max_targets": attack.max_targets,
			"forward": attack_forward,
			"payload": payload.duplicate(true),
		})


func record_registered_source_spell(
	actor: Node3D,
	ability: AbilityDefinition,
	original_instance: Node,
	cast_direction: Vector3,
	payload_override: Resource = null
) -> void:
	if actor == null or ability == null:
		return
	var source_id: int = actor.get_instance_id()
	if not secondary_lanes.has(source_id):
		if not register_repeat_source(actor):
			return
	var mode: String = CloneSemanticsMulti.get_repeat_mode(ability)
	match mode:
		CloneSemanticsMulti.REPEAT_TRAJECTORY:
			_begin_secondary_trajectory_record(source_id, original_instance, ability, payload_override)
		CloneSemanticsMulti.REPEAT_CHANNEL:
			match ability.get_spell_id():
				"water_jet", "flamethrower":
					_begin_secondary_channel_record(source_id, original_instance, ability)
				"firewall":
					_begin_secondary_firewall_record(source_id, original_instance, ability)
		CloneSemanticsMulti.REPEAT_RECAST:
			_schedule_secondary_recast(source_id, ability, cast_direction, payload_override)
		_:
			# Source-state movement/transformation is already embedded in the lane's
			# actor snapshots. Weather and ownership effects intentionally do nothing.
			pass


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_queued_for_deletion():
		return
	var step: float = maxf(delta, 0.0)
	_advance_secondary_lanes()
	_process_secondary_attacks()
	_process_secondary_spell_events()
	_advance_secondary_trajectory_records(step)
	_advance_secondary_channel_records(step)
	_advance_secondary_firewall_records(step)


func _discover_existing_duplicate_sources() -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("soul_duplicates"):
		if node is Node3D:
			register_repeat_source(node as Node3D)


func _advance_secondary_lanes() -> void:
	var stale_ids: Array[int] = []
	for source_id_value: Variant in secondary_lanes.keys():
		var source_id: int = int(source_id_value)
		var lane: Dictionary = secondary_lanes[source_id] as Dictionary
		var source: Node3D = _weak_node3d(lane.get("source"))
		if source == null or source.is_queued_for_deletion():
			stale_ids.append(source_id)
			continue
		_record_secondary_snapshot(source_id)
		var history_value: Variant = lane.get("history", [])
		var history: Array = history_value as Array if history_value is Array else []
		_trim_secondary_history(history)
		lane["history"] = history
		var lane_echoes: Array = lane.get("echoes", []) as Array
		for index: int in range(lane_echoes.size()):
			var echo: RepeatEchoActor = lane_echoes[index] as RepeatEchoActor
			if echo == null or not is_instance_valid(echo):
				continue
			var snapshot: Dictionary = _sample_secondary_history(
				history,
				elapsed - echo.replay_delay
			)
			if not snapshot.is_empty():
				echo.apply_snapshot(snapshot)
		secondary_lanes[source_id] = lane
	for source_id: int in stale_ids:
		_remove_secondary_lane(source_id)


func _record_secondary_snapshot(source_id: int) -> void:
	if not secondary_lanes.has(source_id):
		return
	var lane: Dictionary = secondary_lanes[source_id] as Dictionary
	var source: Node3D = _weak_node3d(lane.get("source"))
	var visual: Node3D = _weak_node3d(lane.get("visual"))
	if source == null or visual == null:
		return
	var poses: Dictionary = {}
	for path_text: String in POSE_PATHS:
		var node: Node3D = visual.get_node_or_null(path_text) as Node3D
		if node != null:
			poses[path_text] = node.transform
	var history: Array = lane.get("history", []) as Array
	history.append({
		"time": elapsed,
		"actor_transform": source.global_transform,
		"visual_transform": visual.transform,
		"poses": poses,
		"body_form": str(source.get("current_form")) if _has_object_property(source, "current_form") else "normal",
	})
	lane["history"] = history
	lane["recorded"] = int(lane.get("recorded", 0)) + 1
	secondary_lanes[source_id] = lane


func _trim_secondary_history(history: Array) -> void:
	var oldest_needed: float = elapsed - maxf(
		history_seconds,
		delay_seconds + float(echo_count) * echo_spacing_seconds + 1.0
	)
	while history.size() > 2 and float((history[1] as Dictionary).get("time", 0.0)) < oldest_needed:
		history.pop_front()


func _sample_secondary_history(history: Array, target_time: float) -> Dictionary:
	if history.is_empty():
		return {}
	if target_time <= float((history[0] as Dictionary).get("time", 0.0)):
		return history[0] as Dictionary
	for index: int in range(history.size() - 1, -1, -1):
		var row: Dictionary = history[index] as Dictionary
		if float(row.get("time", 0.0)) <= target_time:
			return row
	return history[0] as Dictionary


func _process_secondary_attacks() -> void:
	var remaining: Array[Dictionary] = []
	for event: Dictionary in secondary_attack_events:
		if float(event.get("due_time", INF)) > elapsed:
			remaining.append(event)
			continue
		var echo: RepeatEchoActor = _get_secondary_echo(
			int(event.get("source_id", -1)),
			int(event.get("echo_index", -1))
		)
		if echo == null:
			continue
		var forward: Vector3 = event.get("forward", Vector3.FORWARD) as Vector3
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			forward = -echo.global_transform.basis.z
		forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
		var attack_range: float = maxf(float(event.get("range", 2.0)), 0.2)
		var center: Vector3 = echo.global_position + Vector3.UP * 0.75 + forward * float(event.get("offset", 1.0))
		var targets: Array[Node] = _find_payload_targets(
			center,
			forward,
			attack_range,
			float(event.get("cone", 90.0)),
			maxi(int(event.get("max_targets", 3)), 1)
		)
		var payload_value: Variant = event.get("payload")
		if payload_value is DamagePayload:
			for target: Node in targets:
				_send_payload(target, (payload_value as DamagePayload).duplicate(true) as DamagePayload)
		secondary_replayed_attack_count += 1
		echo.pulse_attack(attack_range)
	secondary_attack_events = remaining


func _schedule_secondary_recast(
	source_id: int,
	ability: AbilityDefinition,
	cast_direction: Vector3,
	payload_override: Resource
) -> void:
	var lane: Dictionary = secondary_lanes.get(source_id, {}) as Dictionary
	var lane_echoes: Array = lane.get("echoes", []) as Array
	for index: int in range(lane_echoes.size()):
		var echo: RepeatEchoActor = lane_echoes[index] as RepeatEchoActor
		if echo == null:
			continue
		secondary_spell_events.append({
			"due_time": elapsed + echo.replay_delay,
			"source_id": source_id,
			"echo_index": index,
			"ability": ability,
			"direction": cast_direction,
			"payload": payload_override.duplicate(true) if payload_override != null else null,
		})


func _process_secondary_spell_events() -> void:
	var remaining: Array[Dictionary] = []
	for event: Dictionary in secondary_spell_events:
		if float(event.get("due_time", INF)) > elapsed:
			remaining.append(event)
			continue
		var echo: RepeatEchoActor = _get_secondary_echo(
			int(event.get("source_id", -1)),
			int(event.get("echo_index", -1))
		)
		var ability_value: Variant = event.get("ability")
		if echo == null or not ability_value is AbilityDefinition:
			continue
		var payload_value: Variant = event.get("payload")
		var replayed: Node = CloneReplayMulti.replay_cast(
			get_tree(),
			echo,
			ability_value as AbilityDefinition,
			event.get("direction", Vector3.FORWARD) as Vector3,
			Vector3.UP * 0.8,
			0.3,
			payload_value as Resource if payload_value is Resource else null,
			0.0,
			"repeat",
			{"source_kind": "soul_duplicate"}
		)
		if replayed != null:
			secondary_replayed_spell_count += 1
	secondary_spell_events = remaining


func _begin_secondary_trajectory_record(
	source_id: int,
	original_instance: Node,
	ability: AbilityDefinition,
	payload_override: Resource
) -> void:
	if not original_instance is Node3D:
		_schedule_secondary_recast(source_id, ability, Vector3.FORWARD, payload_override)
		return
	for record: Dictionary in secondary_trajectory_records:
		var existing: Node = _weak_node(record.get("original"))
		if existing == original_instance:
			return
	var lane: Dictionary = secondary_lanes.get(source_id, {}) as Dictionary
	var lane_echoes: Array = lane.get("echoes", []) as Array
	var playbacks: Array[Dictionary] = []
	for index: int in range(lane_echoes.size()):
		playbacks.append({"echo_index": index, "next_sample": 0, "actor": null, "finished": false})
	var payload: Resource = payload_override
	if payload == null and ability.get_action_payload() != null:
		payload = ability.get_action_payload().duplicate(true)
	secondary_trajectory_records.append({
		"source_id": source_id,
		"ability": ability,
		"original": weakref(original_instance),
		"payload": payload.duplicate(true) if payload != null else null,
		"samples": [],
		"end_time": -1.0,
		"playbacks": playbacks,
	})


func _advance_secondary_trajectory_records(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for record: Dictionary in secondary_trajectory_records:
		var original: Node3D = _weak_node3d(record.get("original"))
		var samples: Array = record.get("samples", []) as Array
		if original != null and not original.is_queued_for_deletion():
			samples.append({"time": elapsed, "transform": original.global_transform})
			record["samples"] = samples
		elif float(record.get("end_time", -1.0)) < 0.0:
			record["end_time"] = elapsed
		var playbacks: Array = record.get("playbacks", []) as Array
		for state_index: int in range(playbacks.size()):
			var state: Dictionary = playbacks[state_index] as Dictionary
			if bool(state.get("finished", false)):
				continue
			var echo: RepeatEchoActor = _get_secondary_echo(int(record.get("source_id", -1)), int(state.get("echo_index", -1)))
			if echo == null:
				state["finished"] = true
				playbacks[state_index] = state
				continue
			var playback_time: float = elapsed - echo.replay_delay
			var next_sample: int = int(state.get("next_sample", 0))
			var actor_value: Variant = state.get("actor")
			var playback: RepeatTrajectoryEchoStable = actor_value as RepeatTrajectoryEchoStable if actor_value is RepeatTrajectoryEchoStable else null
			while next_sample < samples.size():
				var sample: Dictionary = samples[next_sample] as Dictionary
				if float(sample.get("time", INF)) > playback_time:
					break
				if playback == null:
					playback = StableTrajectoryEchoMulti.new() as RepeatTrajectoryEchoStable
					playback.set_meta("clone_spell_replay", true)
					get_tree().current_scene.add_child(playback)
					var ability: AbilityDefinition = record.get("ability") as AbilityDefinition
					var payload_value: Variant = record.get("payload")
					playback.configure(ability, echo, payload_value as Resource if payload_value is Resource else null)
					state["actor"] = playback
				if playback != null:
					playback.advance_to(sample.get("transform") as Transform3D, delta)
				next_sample += 1
			state["next_sample"] = next_sample
			var end_time: float = float(record.get("end_time", -1.0))
			if end_time >= 0.0 and playback_time >= end_time and next_sample >= samples.size():
				if playback != null and is_instance_valid(playback):
					playback.finish_replay()
				state["finished"] = true
			playbacks[state_index] = state
		record["playbacks"] = playbacks
		if not _all_playbacks_finished(playbacks):
			remaining.append(record)
	secondary_trajectory_records = remaining


func _begin_secondary_channel_record(
	source_id: int,
	original_node: Node,
	ability: AbilityDefinition
) -> void:
	if original_node == null:
		return
	for record: Dictionary in secondary_channel_records:
		if _weak_node(record.get("original")) == original_node:
			return
	var lane: Dictionary = secondary_lanes.get(source_id, {}) as Dictionary
	var lane_echoes: Array = lane.get("echoes", []) as Array
	var playbacks: Array[Dictionary] = []
	for index: int in range(lane_echoes.size()):
		playbacks.append({"echo_index": index, "next_sample": 0, "actor": null, "finished": false})
	secondary_channel_records.append({
		"source_id": source_id,
		"spell_id": ability.get_spell_id(),
		"original": weakref(original_node),
		"payload": ability.get_action_payload().duplicate(true) if ability.get_action_payload() != null else null,
		"samples": [],
		"end_time": -1.0,
		"playbacks": playbacks,
	})


func _advance_secondary_channel_records(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for record: Dictionary in secondary_channel_records:
		var original: Node = _weak_node(record.get("original"))
		var spell_id: String = str(record.get("spell_id", ""))
		var samples: Array = record.get("samples", []) as Array
		if _channel_is_active(original, spell_id):
			var sample: Dictionary = _sample_channel(original, spell_id)
			if not sample.is_empty():
				sample["time"] = elapsed
				samples.append(sample)
			record["samples"] = samples
		elif float(record.get("end_time", -1.0)) < 0.0:
			record["end_time"] = elapsed
		var playbacks: Array = record.get("playbacks", []) as Array
		for state_index: int in range(playbacks.size()):
			var state: Dictionary = playbacks[state_index] as Dictionary
			if bool(state.get("finished", false)):
				continue
			var echo: RepeatEchoActor = _get_secondary_echo(int(record.get("source_id", -1)), int(state.get("echo_index", -1)))
			if echo == null:
				state["finished"] = true
				playbacks[state_index] = state
				continue
			var playback_time: float = elapsed - echo.replay_delay
			var next_sample: int = int(state.get("next_sample", 0))
			var actor_value: Variant = state.get("actor")
			var playback: RepeatChannelEcho = actor_value as RepeatChannelEcho if actor_value is RepeatChannelEcho else null
			while next_sample < samples.size():
				var sample: Dictionary = samples[next_sample] as Dictionary
				if float(sample.get("time", INF)) > playback_time:
					break
				if playback == null:
					playback = ChannelEchoMulti.new() as RepeatChannelEcho
					get_tree().current_scene.add_child(playback)
					var payload_value: Variant = record.get("payload")
					playback.configure(spell_id, echo, payload_value as Resource if payload_value is Resource else null)
					state["actor"] = playback
				playback.advance_sample(sample, delta)
				next_sample += 1
			state["next_sample"] = next_sample
			var end_time: float = float(record.get("end_time", -1.0))
			if end_time >= 0.0 and playback_time >= end_time and next_sample >= samples.size():
				if playback != null and is_instance_valid(playback):
					playback.finish_replay()
				state["finished"] = true
			playbacks[state_index] = state
		record["playbacks"] = playbacks
		if not _all_playbacks_finished(playbacks):
			remaining.append(record)
	secondary_channel_records = remaining


func _begin_secondary_firewall_record(
	source_id: int,
	original_node: Node,
	ability: AbilityDefinition
) -> void:
	if original_node == null:
		return
	var lane: Dictionary = secondary_lanes.get(source_id, {}) as Dictionary
	var lane_echoes: Array = lane.get("echoes", []) as Array
	var playbacks: Array[Dictionary] = []
	for index: int in range(lane_echoes.size()):
		playbacks.append({"echo_index": index, "next_sample": 0, "actor": null, "finished": false})
	secondary_firewall_records.append({
		"source_id": source_id,
		"original": weakref(original_node),
		"payload": ability.get_action_payload().duplicate(true) if ability.get_action_payload() != null else null,
		"samples": [],
		"end_time": -1.0,
		"playbacks": playbacks,
	})


func _advance_secondary_firewall_records(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for record: Dictionary in secondary_firewall_records:
		var original: Node = _weak_node(record.get("original"))
		var samples: Array = record.get("samples", []) as Array
		if original != null and not original.is_queued_for_deletion():
			var copied_points: Array = []
			var points_value: Variant = original.get("path_points")
			if points_value is Array:
				for value: Variant in points_value as Array:
					if value is Dictionary:
						copied_points.append((value as Dictionary).duplicate(true))
			samples.append({"time": elapsed, "path_points": copied_points, "phase": int(original.get("phase"))})
			record["samples"] = samples
		elif float(record.get("end_time", -1.0)) < 0.0:
			record["end_time"] = elapsed
		var playbacks: Array = record.get("playbacks", []) as Array
		for state_index: int in range(playbacks.size()):
			var state: Dictionary = playbacks[state_index] as Dictionary
			if bool(state.get("finished", false)):
				continue
			var echo: RepeatEchoActor = _get_secondary_echo(int(record.get("source_id", -1)), int(state.get("echo_index", -1)))
			if echo == null:
				state["finished"] = true
				playbacks[state_index] = state
				continue
			var playback_time: float = elapsed - echo.replay_delay
			var next_sample: int = int(state.get("next_sample", 0))
			var actor_value: Variant = state.get("actor")
			var playback: RepeatFirewallEcho = actor_value as RepeatFirewallEcho if actor_value is RepeatFirewallEcho else null
			while next_sample < samples.size():
				var sample: Dictionary = samples[next_sample] as Dictionary
				if float(sample.get("time", INF)) > playback_time:
					break
				if playback == null:
					playback = FirewallEchoMulti.new() as RepeatFirewallEcho
					get_tree().current_scene.add_child(playback)
					var payload_value: Variant = record.get("payload")
					playback.configure(echo, payload_value as Resource if payload_value is Resource else null)
					state["actor"] = playback
				playback.apply_sample(sample, delta)
				next_sample += 1
			state["next_sample"] = next_sample
			var end_time: float = float(record.get("end_time", -1.0))
			if end_time >= 0.0 and playback_time >= end_time and next_sample >= samples.size():
				if playback != null and is_instance_valid(playback):
					playback.finish_replay()
				state["finished"] = true
			playbacks[state_index] = state
		record["playbacks"] = playbacks
		if not _all_playbacks_finished(playbacks):
			remaining.append(record)
	secondary_firewall_records = remaining


func _get_secondary_echo(source_id: int, echo_index: int) -> RepeatEchoActor:
	if not secondary_lanes.has(source_id):
		return null
	var lane: Dictionary = secondary_lanes[source_id] as Dictionary
	var lane_echoes: Array = lane.get("echoes", []) as Array
	if echo_index < 0 or echo_index >= lane_echoes.size():
		return null
	var value: Variant = lane_echoes[echo_index]
	return value as RepeatEchoActor if value is RepeatEchoActor and is_instance_valid(value) else null


func _remove_secondary_lane(source_id: int) -> void:
	if not secondary_lanes.has(source_id):
		return
	var lane: Dictionary = secondary_lanes[source_id] as Dictionary
	for value: Variant in lane.get("echoes", []) as Array:
		if value is Node and is_instance_valid(value as Node):
			(value as Node).queue_free()
	secondary_lanes.erase(source_id)
	registered_source_ids.erase(source_id)


func _clear_secondary_lanes() -> void:
	var ids: Array[int] = []
	for value: Variant in secondary_lanes.keys():
		ids.append(int(value))
	for source_id: int in ids:
		_remove_secondary_lane(source_id)


func _clear_secondary_records() -> void:
	for records: Array in [secondary_trajectory_records, secondary_channel_records, secondary_firewall_records]:
		for record: Dictionary in records:
			for state_value: Variant in record.get("playbacks", []) as Array:
				if state_value is Dictionary:
					var actor_value: Variant = (state_value as Dictionary).get("actor")
					if actor_value is Node and is_instance_valid(actor_value as Node):
						(actor_value as Node).queue_free()
	secondary_trajectory_records.clear()
	secondary_channel_records.clear()
	secondary_firewall_records.clear()


func _weak_node(value: Variant) -> Node:
	if value is WeakRef:
		var resolved: Variant = (value as WeakRef).get_ref()
		return resolved as Node if resolved is Node and is_instance_valid(resolved) else null
	return null


func _weak_node3d(value: Variant) -> Node3D:
	var node: Node = _weak_node(value)
	return node as Node3D if node is Node3D else null


func _has_object_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false
	for row_value: Variant in object.get_property_list():
		if row_value is Dictionary and str((row_value as Dictionary).get("name", "")) == property_name:
			return true
	return false


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["multi_source_timeline"] = true
	data["secondary_source_count"] = secondary_lanes.size()
	data["secondary_echo_count"] = secondary_source_echo_count
	data["secondary_attack_replays"] = secondary_replayed_attack_count
	data["secondary_spell_replays"] = secondary_replayed_spell_count
	data["secondary_trajectory_records"] = secondary_trajectory_records.size()
	data["secondary_channel_records"] = secondary_channel_records.size()
	return data
