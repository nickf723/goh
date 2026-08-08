extends "res://scripts/time/repeat_echo_controller_multi_source.gd"
class_name RepeatEchoControllerMultiSourceReady

var secondary_bubble_events: Array[Dictionary] = []
var secondary_bubble_connections: Dictionary = {}


func register_repeat_source(actor: Node3D) -> bool:
	var registered: bool = super.register_repeat_source(actor)
	if not registered or actor == null or actor == source_actor:
		return registered
	_connect_secondary_bubble(actor)
	return true


func _exit_tree() -> void:
	_disconnect_secondary_bubbles()
	secondary_bubble_events.clear()
	super._exit_tree()


func record_registered_source_spell(
	actor: Node3D,
	ability: AbilityDefinition,
	original_instance: Node,
	cast_direction: Vector3,
	payload_override: Resource = null
) -> void:
	if (
		actor != null
		and ability != null
		and ability.get_spell_id() == "bubble"
	):
		_schedule_secondary_bubble_event(
			actor.get_instance_id(),
			"activate",
			payload_override
		)
	super.record_registered_source_spell(
		actor,
		ability,
		original_instance,
		cast_direction,
		payload_override
	)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_queued_for_deletion():
		return
	_process_secondary_bubble_events()


func _connect_secondary_bubble(actor: Node3D) -> void:
	var source_id: int = actor.get_instance_id()
	if secondary_bubble_connections.has(source_id):
		return
	var bubble: Node = actor.get_node_or_null("BubbleShieldController")
	if bubble == null:
		return
	var absorb_callback := Callable(
		self,
		"_on_secondary_bubble_absorbed"
	).bind(source_id)
	var end_callback := Callable(
		self,
		"_on_secondary_bubble_ended"
	).bind(source_id)
	if bubble.has_signal("bubble_absorbed"):
		bubble.connect("bubble_absorbed", absorb_callback)
	if bubble.has_signal("bubble_ended"):
		bubble.connect("bubble_ended", end_callback)
	secondary_bubble_connections[source_id] = {
		"bubble": weakref(bubble),
		"absorb": absorb_callback,
		"end": end_callback,
	}


func _disconnect_secondary_bubbles() -> void:
	for value: Variant in secondary_bubble_connections.values():
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		var bubble: Node = _weak_node(row.get("bubble"))
		if bubble == null:
			continue
		var absorb: Callable = row.get("absorb", Callable()) as Callable
		var end: Callable = row.get("end", Callable()) as Callable
		if absorb.is_valid() and bubble.has_signal("bubble_absorbed") and bubble.is_connected("bubble_absorbed", absorb):
			bubble.disconnect("bubble_absorbed", absorb)
		if end.is_valid() and bubble.has_signal("bubble_ended") and bubble.is_connected("bubble_ended", end):
			bubble.disconnect("bubble_ended", end)
	secondary_bubble_connections.clear()


func _on_secondary_bubble_absorbed(
	payload: DamagePayload,
	_attacker: Node3D,
	_result: Dictionary,
	source_id: int
) -> void:
	_schedule_secondary_bubble_event(source_id, "pop", payload)


func _on_secondary_bubble_ended(
	reason: String,
	source_id: int
) -> void:
	if reason == "absorbed_hit":
		return
	_schedule_secondary_bubble_event(source_id, "expire", null, reason)


func _schedule_secondary_bubble_event(
	source_id: int,
	kind: String,
	payload: Resource = null,
	reason: String = ""
) -> void:
	if not secondary_lanes.has(source_id):
		return
	var lane: Dictionary = secondary_lanes[source_id] as Dictionary
	var lane_echoes: Array = lane.get("echoes", []) as Array
	for index: int in range(lane_echoes.size()):
		var echo: RepeatEchoActor = lane_echoes[index] as RepeatEchoActor
		if echo == null:
			continue
		secondary_bubble_events.append({
			"due_time": elapsed + echo.replay_delay,
			"source_id": source_id,
			"echo_index": index,
			"kind": kind,
			"payload": payload.duplicate(true) if payload != null else null,
			"reason": reason,
		})


func _process_secondary_bubble_events() -> void:
	var remaining: Array[Dictionary] = []
	for event: Dictionary in secondary_bubble_events:
		if float(event.get("due_time", INF)) > elapsed:
			remaining.append(event)
			continue
		var echo: RepeatEchoActor = _get_secondary_echo(
			int(event.get("source_id", -1)),
			int(event.get("echo_index", -1))
		)
		if echo == null:
			continue
		var controller: PlayerBubbleShieldController = _ensure_echo_bubble_controller(echo)
		if controller == null:
			continue
		match str(event.get("kind", "")):
			"activate":
				var payload_value: Variant = event.get("payload")
				controller.activate_bubble(
					payload_value as Resource if payload_value is Resource else null
				)
			"pop":
				var payload_value: Variant = event.get("payload")
				var payload: DamagePayload = (
					payload_value as DamagePayload
					if payload_value is DamagePayload
					else DamagePayload.new()
				)
				controller.absorb_incoming_hit(payload, null)
			"expire":
				controller.expire_bubble(str(event.get("reason", "timeline_expired")))
	secondary_bubble_events = remaining


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["secondary_bubble_timeline"] = true
	data["secondary_bubble_events"] = secondary_bubble_events.size()
	return data
