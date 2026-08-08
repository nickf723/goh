extends "res://scripts/soul/soul_duplicate_controller.gd"
class_name SoulDuplicateControllerReady

const ReadyDuplicateActorScript = preload(
	"res://scripts/soul/soul_duplicate_actor_ready.gd"
)

var source_flamethrower: PlayerFlamethrowerController = null


func bind_duplicate(actor: CharacterBody3D, manager: Node) -> bool:
	var bound: bool = super.bind_duplicate(actor, manager)
	if not bound:
		return false
	source_flamethrower = actor.get_node_or_null("FlamethrowerController") as PlayerFlamethrowerController
	if source_flamethrower != null:
		var start_callback := Callable(self, "_on_source_flamethrower_started")
		var end_callback := Callable(self, "_on_source_flamethrower_ended")
		if not source_flamethrower.channel_started.is_connected(start_callback):
			source_flamethrower.channel_started.connect(start_callback)
		if not source_flamethrower.channel_ended.is_connected(end_callback):
			source_flamethrower.channel_ended.connect(end_callback)
	return true


func _exit_tree() -> void:
	if source_flamethrower != null and is_instance_valid(source_flamethrower):
		var start_callback := Callable(self, "_on_source_flamethrower_started")
		var end_callback := Callable(self, "_on_source_flamethrower_ended")
		if source_flamethrower.channel_started.is_connected(start_callback):
			source_flamethrower.channel_started.disconnect(start_callback)
		if source_flamethrower.channel_ended.is_connected(end_callback):
			source_flamethrower.channel_ended.disconnect(end_callback)
	super._exit_tree()


func _spawn_duplicates() -> void:
	_clear_duplicates()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for index: int in range(maxi(duplicate_count, 1)):
		var duplicate := ReadyDuplicateActorScript.new() as SoulDuplicateActorReady
		duplicate.name = "SoulDuplicate" + str(index + 1)
		duplicate.default_side_offset = side_spacing
		duplicate.set_meta("clone_spell_replay", true)
		duplicate.set_meta("clone_spell_kind", "soul_duplicate")
		scene_root.add_child(duplicate)
		duplicate.configure(source_actor, index)
		duplicates.append(duplicate)
		duplicate_spawned.emit(duplicate)


func _mirror_ability(ability: AbilityDefinition, original_instance: Node) -> void:
	var direction: Vector3 = _get_cast_direction()
	for duplicate: SoulDuplicateActor in duplicates:
		if duplicate is SoulDuplicateActorReady:
			(duplicate as SoulDuplicateActorReady).set_mirrored_ability(ability, direction)
	super._mirror_ability(ability, original_instance)
	if ability == null:
		return
	var mode: String = CloneSemantics.get_duplicate_mode(ability)
	if mode == CloneSemantics.DUPLICATE_SOURCE_STATE:
		for duplicate: SoulDuplicateActor in duplicates:
			_notify_repeat_spell(
				duplicate,
				ability,
				null,
				direction,
				ability.get_action_payload()
			)


func _spawn_live_spell(
	duplicate: SoulDuplicateActor,
	ability: AbilityDefinition,
	cast_direction: Vector3,
	payload_override: Resource
) -> void:
	if ability == null:
		return
	if duplicate is SoulDuplicateActorReady:
		(duplicate as SoulDuplicateActorReady).set_mirrored_ability(ability, cast_direction)
	if ability.get_spell_id() == "flamethrower":
		_start_duplicate_flamethrower(duplicate, ability)
		return
	if ability.ability_scene == null:
		return
	var instance: Node = ability.ability_scene.instantiate()
	if instance == null:
		return
	instance.set_meta("clone_spell_replay", true)
	instance.set_meta("clone_spell_kind", "soul_duplicate")
	instance.set_meta("clone_live_simulation", true)
	instance.set_meta("clone_spell_id", ability.get_spell_id())
	if _has_property(instance, "mana_per_second"):
		instance.set("mana_per_second", 0.0)
	var resolved_payload: Resource = _make_duplicate_payload(payload_override)
	if resolved_payload != null and instance.has_method("set_payload"):
		instance.call("set_payload", resolved_payload)
	if instance.has_method("set_source_actor"):
		instance.call("set_source_actor", duplicate)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(instance)
	instance.add_to_group("clone_spell_replays")
	instance.add_to_group("soul_duplicate_spell_replays")
	if instance.has_method("execute"):
		instance.call("execute", duplicate, cast_direction)
		_notify_repeat_spell(duplicate, ability, instance, cast_direction, resolved_payload)
		return
	if instance is Node3D:
		(instance as Node3D).global_position = duplicate.global_position + Vector3.UP * 0.85 + cast_direction * 0.3
	if instance.has_method("launch"):
		instance.call("launch", cast_direction)
	_notify_repeat_spell(duplicate, ability, instance, cast_direction, resolved_payload)


func _make_duplicate_payload(payload_override: Resource) -> Resource:
	if payload_override == null:
		return null
	var duplicate_value: Resource = payload_override.duplicate(true)
	if duplicate_value is DamagePayload:
		var payload: DamagePayload = duplicate_value as DamagePayload
		for tag: String in ["soul", "duplicate", "live_clone"]:
			if not payload.tags.has(tag):
				payload.tags.append(tag)
		payload.source_name = "Duplicate • " + payload.source_name
	return duplicate_value


func _on_source_flamethrower_started() -> void:
	var ability: AbilityDefinition = _get_current_player_ability()
	if ability == null or ability.get_spell_id() != "flamethrower":
		return
	var direction: Vector3 = _get_cast_direction()
	for duplicate: SoulDuplicateActor in duplicates:
		if duplicate is SoulDuplicateActorReady:
			(duplicate as SoulDuplicateActorReady).set_mirrored_ability(ability, direction)
		_start_duplicate_flamethrower(duplicate, ability)
		if duplicate != null and is_instance_valid(duplicate):
			_notify_repeat_spell(
				duplicate,
				ability,
				duplicate.flamethrower_controller,
				direction,
				null
			)
	mirrored_spell_count += 1
	last_spell_id = "flamethrower"
	last_mode = CloneSemantics.DUPLICATE_LIVE
	spell_mirrored.emit(last_spell_id, last_mode)


func _on_source_flamethrower_ended(reason: String) -> void:
	for duplicate: SoulDuplicateActor in duplicates:
		if duplicate == null or not is_instance_valid(duplicate):
			continue
		var controller: PlayerFlamethrowerController = duplicate.flamethrower_controller
		if controller != null and controller.channel_requested:
			controller.cancel_ability_channel("source_" + reason)


func _start_duplicate_flamethrower(
	duplicate: SoulDuplicateActor,
	ability: AbilityDefinition
) -> void:
	if duplicate == null or not is_instance_valid(duplicate):
		return
	var controller: PlayerFlamethrowerController = duplicate.flamethrower_controller
	if controller == null:
		return
	controller.mana_per_second = 0.0
	controller.begin_ability_channel(duplicate, ability)


func _notify_repeat_spell(
	duplicate: SoulDuplicateActor,
	ability: AbilityDefinition,
	instance: Node,
	cast_direction: Vector3,
	payload: Resource
) -> void:
	if duplicate == null or not is_instance_valid(duplicate):
		return
	var repeat_controller: Node = get_tree().get_first_node_in_group("repeat_echo_controller")
	if repeat_controller == null or not repeat_controller.has_method("record_registered_source_spell"):
		return
	repeat_controller.call(
		"record_registered_source_spell",
		duplicate,
		ability,
		instance,
		cast_direction,
		payload
	)


func _has_property(node: Object, property_name: String) -> bool:
	for row_value: Variant in node.get_property_list():
		if row_value is Dictionary and str((row_value as Dictionary).get("name", "")) == property_name:
			return true
	return false


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["free_mirrored_channels"] = true
	data["duplicate_payload_tags"] = true
	data["flamethrower_signal_bridge"] = source_flamethrower != null
	data["ability_proxy_sync"] = true
	data["repeat_spell_lane_bridge"] = true
	data["ready_duplicate_actor"] = true
	return data
