extends "res://scripts/time/repeat_echo_controller.gd"
class_name RepeatEchoControllerSpellReplay

const ClonePolicy = preload(
	"res://scripts/abilities/spell_clone_replay_policy.gd"
)
const CloneReplay = preload(
	"res://scripts/abilities/spell_clone_replay.gd"
)

var ability_caster: Node = null
var ability_by_scene_path: Dictionary = {}
var pending_spell_events: Array[Dictionary] = []
var replayed_spell_count: int = 0
var suppressed_spell_count: int = 0
var observed_player_cast_count: int = 0
var last_replayed_spell_id: String = "none"
var last_suppressed_spell_id: String = "none"
var last_suppression_reason: String = "none"


func bind_repeat(
	actor: Node3D,
	manager: Node,
	definition: Resource = null
) -> bool:
	var bound: bool = super.bind_repeat(actor, manager, definition)
	if not bound:
		return false
	ability_caster = source_actor.get_node_or_null("AbilityCaster")
	_rebuild_ability_scene_map()
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
	super._exit_tree()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_queued_for_deletion():
		return
	_process_spell_events()


func _rebuild_ability_scene_map() -> void:
	ability_by_scene_path.clear()
	if ability_caster == null or not is_instance_valid(ability_caster):
		return
	var loadout_value: Variant = ability_caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability: AbilityDefinition in loadout.get_learned_abilities():
		if ability == null or ability.ability_scene == null:
			continue
		var path: String = ability.ability_scene.resource_path
		if path != "":
			ability_by_scene_path[path] = ability


func _on_scene_node_added(node: Node) -> void:
	if (
		node == null
		or not is_instance_valid(node)
		or node == self
		or bool(node.get_meta("clone_spell_replay", false))
	):
		return
	var scene_path: String = node.scene_file_path
	if scene_path == "" or not ability_by_scene_path.has(scene_path):
		return
	var ability: AbilityDefinition = ability_by_scene_path[scene_path] as AbilityDefinition
	if ability == null:
		return
	var observed_source: Node = _read_source_actor(node)
	if observed_source != null and observed_source != source_actor:
		return
	if observed_source == null and not _matches_current_player_ability(ability):
		return

	observed_player_cast_count += 1
	var policy: Dictionary = ClonePolicy.get_policy(ability)
	if str(policy.get("mode", "suppress")) != ClonePolicy.MODE_REPLAY:
		suppressed_spell_count += 1
		last_suppressed_spell_id = ability.get_spell_id()
		last_suppression_reason = str(policy.get("reason", "suppressed"))
		return
	_schedule_spell_replays(node, ability)


func _matches_current_player_ability(ability: AbilityDefinition) -> bool:
	if ability_caster == null or not is_instance_valid(ability_caster):
		return false
	if not ability_caster.has_method("get_current_ability"):
		return false
	var current_value: Variant = ability_caster.call("get_current_ability")
	return (
		current_value is AbilityDefinition
		and (current_value as AbilityDefinition).get_spell_id() == ability.get_spell_id()
	)


func _read_source_actor(node: Node) -> Node:
	for property_value: Variant in node.get_property_list():
		if not property_value is Dictionary:
			continue
		if str((property_value as Dictionary).get("name", "")) != "source_actor":
			continue
		var source_value: Variant = node.get("source_actor")
		return source_value as Node if source_value is Node else null
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

	var payload_override: Resource = null
	if original_instance.has_method("get_payload"):
		var payload_value: Variant = original_instance.call("get_payload")
		if payload_value is Resource:
			payload_override = (payload_value as Resource).duplicate(true)
	elif ability.get_action_payload() != null:
		payload_override = ability.get_action_payload().duplicate(true)

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
		})


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
	var replayed: Node = CloneReplay.replay_cast(
		get_tree(),
		echo,
		ability,
		event.get("cast_direction", Vector3.FORWARD) as Vector3,
		event.get("origin_offset", Vector3.UP) as Vector3,
		float(event.get("spawn_distance", 1.0)),
		event.get("payload") as Resource,
		0.0,
		"repeat"
	)
	if replayed == null:
		return
	replayed_spell_count += 1
	last_replayed_spell_id = ability.get_spell_id()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["spell_replay_ready"] = true
	data["observed_player_casts"] = observed_player_cast_count
	data["pending_spell_replays"] = pending_spell_events.size()
	data["replayed_spells"] = replayed_spell_count
	data["suppressed_spells"] = suppressed_spell_count
	data["last_replayed_spell"] = last_replayed_spell_id
	data["last_suppressed_spell"] = last_suppressed_spell_id
	data["last_suppression_reason"] = last_suppression_reason
	data["policy_shared_with_future_soul_duplicates"] = true
	return data
