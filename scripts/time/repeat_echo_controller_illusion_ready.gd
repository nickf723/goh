extends "res://scripts/time/repeat_echo_controller_multi_source_ready.gd"
class_name RepeatEchoControllerIllusionReady

const CloneReplayIllusion = preload(
	"res://scripts/abilities/spell_clone_replay.gd"
)


func record_illusion_cast_metadata(
	_original_instance: Node,
	metadata: Dictionary
) -> void:
	if not metadata.has("target_world_position"):
		return
	# The player action node is observed as soon as it enters the SceneTree, before
	# execute() has resolved its ground point. execute() calls back here immediately
	# afterward, so the still-pending events receive the authored point before their
	# one-second due time.
	for index: int in range(pending_spell_events.size() - 1, -1, -1):
		var event: Dictionary = pending_spell_events[index]
		if str(event.get("spell_id", "")) != "illusion":
			continue
		var existing: Dictionary = event.get("cast_metadata", {}) as Dictionary
		if existing.has("target_world_position"):
			continue
		existing.merge(metadata.duplicate(true), true)
		event["cast_metadata"] = existing
		pending_spell_events[index] = event


func record_registered_source_spell(
	actor: Node3D,
	ability: AbilityDefinition,
	original_instance: Node,
	cast_direction: Vector3,
	payload_override: Resource = null
) -> void:
	super.record_registered_source_spell(
		actor,
		ability,
		original_instance,
		cast_direction,
		payload_override
	)
	if (
		actor == null
		or ability == null
		or ability.get_spell_id() != "illusion"
		or original_instance == null
		or not original_instance.has_method("get_clone_cast_metadata")
	):
		return
	var metadata_value: Variant = original_instance.call("get_clone_cast_metadata")
	if not metadata_value is Dictionary:
		return
	var metadata: Dictionary = (metadata_value as Dictionary).duplicate(true)
	var source_id: int = actor.get_instance_id()
	for index: int in range(secondary_spell_events.size() - 1, -1, -1):
		var event: Dictionary = secondary_spell_events[index]
		if int(event.get("source_id", -1)) != source_id:
			continue
		var event_ability: Variant = event.get("ability")
		if not event_ability is AbilityDefinition:
			continue
		if (event_ability as AbilityDefinition).get_spell_id() != "illusion":
			continue
		var existing: Dictionary = event.get("cast_metadata", {}) as Dictionary
		if existing.has("target_world_position"):
			continue
		existing.merge(metadata, true)
		event["cast_metadata"] = existing
		secondary_spell_events[index] = event


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
		var metadata: Dictionary = {
			"source_kind": "soul_duplicate",
		}
		var event_metadata_value: Variant = event.get("cast_metadata", {})
		if event_metadata_value is Dictionary:
			metadata.merge(
				(event_metadata_value as Dictionary).duplicate(true),
				true
			)
		var replayed: Node = CloneReplayIllusion.replay_cast(
			get_tree(),
			echo,
			ability_value as AbilityDefinition,
			event.get("direction", Vector3.FORWARD) as Vector3,
			Vector3.UP * 0.8,
			0.3,
			payload_value as Resource if payload_value is Resource else null,
			0.0,
			"repeat",
			metadata
		)
		if replayed != null:
			secondary_replayed_spell_count += 1
	secondary_spell_events = remaining


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["illusion_target_point_memory"] = true
	return data
