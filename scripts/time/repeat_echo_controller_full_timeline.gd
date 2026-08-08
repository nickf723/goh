extends "res://scripts/time/repeat_echo_controller_spell_replay.gd"
class_name RepeatEchoControllerFullTimeline

const CloneSemanticsFull = preload(
	"res://scripts/abilities/spell_clone_semantics.gd"
)
const ChannelEchoScript = preload(
	"res://scripts/time/repeat_channel_echo.gd"
)
const FirewallEchoScript = preload(
	"res://scripts/time/repeat_firewall_echo.gd"
)
const BubbleControllerScript = preload(
	"res://scripts/player/player_bubble_shield_controller.gd"
)

var channel_records: Array[Dictionary] = []
var firewall_records: Array[Dictionary] = []
var bubble_events: Array[Dictionary] = []
var flamethrower_controller: Node = null
var source_bubble_controller: Node = null
var full_timeline_channel_replays: int = 0
var full_timeline_firewall_replays: int = 0
var full_timeline_bubble_activations: int = 0
var full_timeline_bubble_pops: int = 0


func bind_repeat(
	actor: Node3D,
	manager: Node,
	definition: Resource = null
) -> bool:
	var bound: bool = super.bind_repeat(actor, manager, definition)
	if not bound:
		return false
	flamethrower_controller = source_actor.get_node_or_null("FlamethrowerController")
	if flamethrower_controller != null:
		var start_callback := Callable(self, "_on_flamethrower_started")
		if flamethrower_controller.has_signal("channel_started") and not flamethrower_controller.is_connected("channel_started", start_callback):
			flamethrower_controller.connect("channel_started", start_callback)
	source_bubble_controller = source_actor.get_node_or_null("BubbleShieldController")
	if source_bubble_controller != null:
		var absorb_callback := Callable(self, "_on_source_bubble_absorbed")
		var end_callback := Callable(self, "_on_source_bubble_ended")
		if source_bubble_controller.has_signal("bubble_absorbed") and not source_bubble_controller.is_connected("bubble_absorbed", absorb_callback):
			source_bubble_controller.connect("bubble_absorbed", absorb_callback)
		if source_bubble_controller.has_signal("bubble_ended") and not source_bubble_controller.is_connected("bubble_ended", end_callback):
			source_bubble_controller.connect("bubble_ended", end_callback)
	return true


func _exit_tree() -> void:
	if flamethrower_controller != null and is_instance_valid(flamethrower_controller):
		var start_callback := Callable(self, "_on_flamethrower_started")
		if flamethrower_controller.has_signal("channel_started") and flamethrower_controller.is_connected("channel_started", start_callback):
			flamethrower_controller.disconnect("channel_started", start_callback)
	if source_bubble_controller != null and is_instance_valid(source_bubble_controller):
		var absorb_callback := Callable(self, "_on_source_bubble_absorbed")
		var end_callback := Callable(self, "_on_source_bubble_ended")
		if source_bubble_controller.has_signal("bubble_absorbed") and source_bubble_controller.is_connected("bubble_absorbed", absorb_callback):
			source_bubble_controller.disconnect("bubble_absorbed", absorb_callback)
		if source_bubble_controller.has_signal("bubble_ended") and source_bubble_controller.is_connected("bubble_ended", end_callback):
			source_bubble_controller.disconnect("bubble_ended", end_callback)
	_clear_full_timeline_records()
	super._exit_tree()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_queued_for_deletion():
		return
	var step: float = maxf(delta, 0.0)
	_advance_channel_records(step)
	_advance_firewall_records(step)
	_process_bubble_events()


func _on_scene_node_added(node: Node) -> void:
	super._on_scene_node_added(node)
	if node == null or not is_instance_valid(node) or bool(node.get_meta("clone_spell_replay", false)):
		return
	var ability: AbilityDefinition = _get_current_player_ability()
	if ability == null or ability.ability_scene == null:
		return
	if node.scene_file_path != ability.ability_scene.resource_path:
		return
	match ability.get_spell_id():
		"water_jet":
			_begin_channel_record(node, ability, "water_jet")
		"firewall":
			_begin_firewall_record(node, ability)
		"bubble":
			_schedule_bubble_activation(ability)


func _on_flamethrower_started() -> void:
	if flamethrower_controller == null or not is_instance_valid(flamethrower_controller):
		return
	var ability: AbilityDefinition = _find_learned_ability("flamethrower")
	if ability == null:
		return
	_begin_channel_record(flamethrower_controller, ability, "flamethrower")


func _begin_channel_record(
	original_node: Node,
	ability: AbilityDefinition,
	channel_spell_id: String
) -> void:
	for existing: Dictionary in channel_records:
		var ref_value: Variant = existing.get("original")
		if ref_value is WeakRef and (ref_value as WeakRef).get_ref() == original_node:
			return
	var playback_states: Array[Dictionary] = []
	for echo_index: int in range(echoes.size()):
		playback_states.append({"echo_index": echo_index, "next_sample": 0, "actor": null, "finished": false})
	channel_records.append({
		"spell_id": channel_spell_id,
		"ability": ability,
		"original": weakref(original_node),
		"payload": ability.get_action_payload().duplicate(true) if ability.get_action_payload() != null else null,
		"samples": [],
		"end_time": -1.0,
		"playbacks": playback_states,
	})


func _advance_channel_records(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for record: Dictionary in channel_records:
		var original: Node = _resolve_weak_node(record.get("original"))
		var samples: Array = record.get("samples", []) as Array
		var active_now: bool = _channel_is_active(original, str(record.get("spell_id", "")))
		if active_now:
			var sample: Dictionary = _sample_channel(original, str(record.get("spell_id", "")))
			if not sample.is_empty():
				sample["time"] = elapsed
				samples.append(sample)
			record["samples"] = samples
		elif float(record.get("end_time", -1.0)) < 0.0:
			record["end_time"] = elapsed
		_recorded_channel_playback(record, samples, delta)
		if not _all_playbacks_finished(record.get("playbacks", []) as Array):
			remaining.append(record)
	channel_records = remaining


func _recorded_channel_playback(record: Dictionary, samples: Array, delta: float) -> void:
	var playbacks: Array = record.get("playbacks", []) as Array
	for index: int in range(playbacks.size()):
		var state: Dictionary = playbacks[index] as Dictionary
		if bool(state.get("finished", false)):
			continue
		var echo_index: int = int(state.get("echo_index", -1))
		if echo_index < 0 or echo_index >= echoes.size():
			state["finished"] = true
			playbacks[index] = state
			continue
		var echo: RepeatEchoActor = echoes[echo_index]
		var playback_time: float = elapsed - echo.replay_delay
		var next_sample: int = int(state.get("next_sample", 0))
		var actor_value: Variant = state.get("actor")
		var actor: RepeatChannelEcho = actor_value as RepeatChannelEcho if actor_value is RepeatChannelEcho else null
		while next_sample < samples.size():
			var sample: Dictionary = samples[next_sample] as Dictionary
			if float(sample.get("time", INF)) > playback_time:
				break
			if actor == null:
				actor = ChannelEchoScript.new() as RepeatChannelEcho
				get_tree().current_scene.add_child(actor)
				var payload_value: Variant = record.get("payload")
				actor.configure(str(record.get("spell_id", "")), echo, payload_value as Resource if payload_value is Resource else null)
				state["actor"] = actor
				full_timeline_channel_replays += 1
			actor.advance_sample(sample, delta)
			next_sample += 1
		state["next_sample"] = next_sample
		var end_time: float = float(record.get("end_time", -1.0))
		if end_time >= 0.0 and playback_time >= end_time and next_sample >= samples.size():
			if actor != null and is_instance_valid(actor):
				actor.finish_replay()
			state["finished"] = true
		playbacks[index] = state
	record["playbacks"] = playbacks


func _channel_is_active(node: Node, channel_spell_id: String) -> bool:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	if channel_spell_id == "water_jet":
		return bool(node.get("active"))
	if channel_spell_id == "flamethrower":
		return bool(node.get("channel_requested"))
	return false


func _sample_channel(node: Node, channel_spell_id: String) -> Dictionary:
	if node == null:
		return {}
	if channel_spell_id == "water_jet":
		return {
			"origin": node.get("current_origin") as Vector3,
			"direction": node.get("current_direction") as Vector3,
			"length": float(node.get("current_stream_length")),
		}
	if channel_spell_id == "flamethrower":
		var origin: Vector3 = node.call("_get_cast_origin") as Vector3
		var direction: Vector3 = node.call("_get_cast_direction", origin) as Vector3
		return {"origin": origin, "direction": direction, "length": float(node.get("current_stream_range"))}
	return {}


func _begin_firewall_record(node: Node, ability: AbilityDefinition) -> void:
	var playback_states: Array[Dictionary] = []
	for echo_index: int in range(echoes.size()):
		playback_states.append({"echo_index": echo_index, "next_sample": 0, "actor": null, "finished": false})
	firewall_records.append({
		"original": weakref(node),
		"payload": ability.get_action_payload().duplicate(true) if ability.get_action_payload() != null else null,
		"samples": [],
		"end_time": -1.0,
		"playbacks": playback_states,
	})


func _advance_firewall_records(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for record: Dictionary in firewall_records:
		var original: Node = _resolve_weak_node(record.get("original"))
		var samples: Array = record.get("samples", []) as Array
		if original != null and not original.is_queued_for_deletion():
			var points_value: Variant = original.get("path_points")
			var copied_points: Array = []
			if points_value is Array:
				for value: Variant in points_value as Array:
					if value is Dictionary:
						copied_points.append((value as Dictionary).duplicate(true))
			samples.append({"time": elapsed, "path_points": copied_points, "phase": int(original.get("phase"))})
			record["samples"] = samples
		elif float(record.get("end_time", -1.0)) < 0.0:
			record["end_time"] = elapsed
		_play_firewall_record(record, samples, delta)
		if not _all_playbacks_finished(record.get("playbacks", []) as Array):
			remaining.append(record)
	firewall_records = remaining


func _play_firewall_record(record: Dictionary, samples: Array, delta: float) -> void:
	var playbacks: Array = record.get("playbacks", []) as Array
	for index: int in range(playbacks.size()):
		var state: Dictionary = playbacks[index] as Dictionary
		if bool(state.get("finished", false)):
			continue
		var echo_index: int = int(state.get("echo_index", -1))
		if echo_index < 0 or echo_index >= echoes.size():
			state["finished"] = true
			playbacks[index] = state
			continue
		var echo: RepeatEchoActor = echoes[echo_index]
		var playback_time: float = elapsed - echo.replay_delay
		var next_sample: int = int(state.get("next_sample", 0))
		var actor_value: Variant = state.get("actor")
		var actor: RepeatFirewallEcho = actor_value as RepeatFirewallEcho if actor_value is RepeatFirewallEcho else null
		while next_sample < samples.size():
			var sample: Dictionary = samples[next_sample] as Dictionary
			if float(sample.get("time", INF)) > playback_time:
				break
			if actor == null:
				actor = FirewallEchoScript.new() as RepeatFirewallEcho
				get_tree().current_scene.add_child(actor)
				var payload_value: Variant = record.get("payload")
				actor.configure(echo, payload_value as Resource if payload_value is Resource else null)
				state["actor"] = actor
				full_timeline_firewall_replays += 1
			actor.apply_sample(sample, delta)
			next_sample += 1
		state["next_sample"] = next_sample
		var end_time: float = float(record.get("end_time", -1.0))
		if end_time >= 0.0 and playback_time >= end_time and next_sample >= samples.size():
			if actor != null and is_instance_valid(actor):
				actor.finish_replay()
			state["finished"] = true
		playbacks[index] = state
	record["playbacks"] = playbacks


func _schedule_bubble_activation(ability: AbilityDefinition) -> void:
	var payload: Resource = ability.get_action_payload().duplicate(true) if ability.get_action_payload() != null else null
	for echo_index: int in range(echoes.size()):
		bubble_events.append({"due_time": elapsed + echoes[echo_index].replay_delay, "echo_index": echo_index, "kind": "activate", "payload": payload.duplicate(true) if payload != null else null})


func _on_source_bubble_absorbed(payload: DamagePayload, _attacker: Node3D, _result: Dictionary) -> void:
	for echo_index: int in range(echoes.size()):
		bubble_events.append({"due_time": elapsed + echoes[echo_index].replay_delay, "echo_index": echo_index, "kind": "pop", "payload": payload.duplicate(true)})


func _on_source_bubble_ended(reason: String) -> void:
	if reason == "absorbed_hit":
		return
	for echo_index: int in range(echoes.size()):
		bubble_events.append({"due_time": elapsed + echoes[echo_index].replay_delay, "echo_index": echo_index, "kind": "expire", "reason": reason})


func _process_bubble_events() -> void:
	var remaining: Array[Dictionary] = []
	for event: Dictionary in bubble_events:
		if float(event.get("due_time", INF)) > elapsed:
			remaining.append(event)
			continue
		var echo_index: int = int(event.get("echo_index", -1))
		if echo_index < 0 or echo_index >= echoes.size():
			continue
		var controller: PlayerBubbleShieldController = _ensure_echo_bubble_controller(echoes[echo_index])
		if controller == null:
			continue
		match str(event.get("kind", "")):
			"activate":
				var payload_value: Variant = event.get("payload")
				controller.activate_bubble(payload_value as Resource if payload_value is Resource else null)
				full_timeline_bubble_activations += 1
			"pop":
				var payload_value: Variant = event.get("payload")
				var pop_payload: DamagePayload = payload_value as DamagePayload if payload_value is DamagePayload else DamagePayload.new()
				controller.absorb_incoming_hit(pop_payload, null)
				full_timeline_bubble_pops += 1
			"expire":
				controller.expire_bubble(str(event.get("reason", "timeline_expired")))
	bubble_events = remaining


func _ensure_echo_bubble_controller(echo: RepeatEchoActor) -> PlayerBubbleShieldController:
	if echo == null or not is_instance_valid(echo):
		return null
	var existing: PlayerBubbleShieldController = echo.get_node_or_null("BubbleShieldController") as PlayerBubbleShieldController
	if existing != null:
		return existing
	var controller := BubbleControllerScript.new() as PlayerBubbleShieldController
	controller.name = "BubbleShieldController"
	echo.add_child(controller)
	return controller


func _find_learned_ability(spell_id: String) -> AbilityDefinition:
	if ability_caster == null:
		return null
	var loadout_value: Variant = ability_caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return null
	for ability: AbilityDefinition in (loadout_value as AbilityLoadout).get_learned_abilities():
		if ability != null and ability.get_spell_id() == spell_id:
			return ability
	return null


func _resolve_weak_node(value: Variant) -> Node:
	if value is WeakRef:
		var resolved: Variant = (value as WeakRef).get_ref()
		return resolved as Node if resolved is Node and is_instance_valid(resolved) else null
	return null


func _all_playbacks_finished(playbacks: Array) -> bool:
	for value: Variant in playbacks:
		if value is Dictionary and not bool((value as Dictionary).get("finished", false)):
			return false
	return true


func _clear_full_timeline_records() -> void:
	for records: Array in [channel_records, firewall_records]:
		for record_value: Variant in records:
			if not record_value is Dictionary:
				continue
			for state_value: Variant in (record_value as Dictionary).get("playbacks", []) as Array:
				if state_value is Dictionary:
					var actor_value: Variant = (state_value as Dictionary).get("actor")
					if actor_value is Node and is_instance_valid(actor_value):
						(actor_value as Node).queue_free()
	channel_records.clear()
	firewall_records.clear()
	bubble_events.clear()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["full_timeline_replay"] = true
	data["active_channel_records"] = channel_records.size()
	data["active_firewall_records"] = firewall_records.size()
	data["pending_bubble_events"] = bubble_events.size()
	data["channel_replays"] = full_timeline_channel_replays
	data["firewall_replays"] = full_timeline_firewall_replays
	data["bubble_activations"] = full_timeline_bubble_activations
	data["bubble_pops"] = full_timeline_bubble_pops
	data["repeat_is_recording_not_resimulating"] = true
	return data
