extends RefCounted
class_name SpellCloneReplay

const EchoTintScript = preload(
	"res://scripts/time/repeat_echo_spell_tint.gd"
)


static func replay_cast(
	tree: SceneTree,
	source_proxy: Node3D,
	ability: AbilityDefinition,
	cast_direction: Vector3,
	origin_offset: Vector3,
	cast_spawn_distance: float,
	payload_override: Resource = null,
	power_ratio: float = 0.0,
	clone_kind: String = "repeat",
	cast_metadata: Dictionary = {}
) -> Node:
	if (
		tree == null
		or source_proxy == null
		or not is_instance_valid(source_proxy)
		or ability == null
		or ability.ability_scene == null
	):
		return null
	var scene_root: Node = tree.current_scene
	if scene_root == null:
		return null
	var instance: Node = ability.ability_scene.instantiate()
	if instance == null:
		return null

	instance.set_meta("clone_spell_replay", true)
	instance.set_meta("clone_spell_kind", clone_kind)
	instance.set_meta("clone_spell_id", ability.get_spell_id())
	instance.set_meta("clone_copies_original_result", false)
	instance.set_meta("clone_fresh_world_interaction", true)
	instance.set_meta("clone_cast_metadata", cast_metadata.duplicate(true))

	# Cast-specific intent lives briefly on the source proxy so an authored spell
	# can consume it through its normal execute path. This is intent, not outcome:
	# curl direction, charge choice, etc. Never target IDs or previous hit results.
	for key_value: Variant in cast_metadata.keys():
		var key: String = str(key_value)
		source_proxy.set_meta("clone_cast_" + key, cast_metadata[key_value])

	var payload: Resource = payload_override
	if payload == null:
		payload = ability.get_action_payload()
	if payload != null:
		payload = payload.duplicate(true)
	if payload != null and instance.has_method("set_payload"):
		instance.call("set_payload", payload)
	if instance.has_method("set_source_actor"):
		instance.call("set_source_actor", source_proxy)

	var tint: Node = EchoTintScript.new()
	tint.name = "RepeatEchoSpellTint"
	instance.add_child(tint)
	scene_root.add_child(instance)
	instance.add_to_group("clone_spell_replays")
	instance.add_to_group(clone_kind + "_spell_replays")

	var direction: Vector3 = cast_direction
	if direction.length_squared() <= 0.0001:
		direction = -source_proxy.global_transform.basis.z
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	if instance.has_method("execute"):
		instance.call("execute", source_proxy, direction)
		_clear_cast_metadata(source_proxy, cast_metadata)
		return instance

	if instance is Node3D:
		var node_3d := instance as Node3D
		node_3d.global_position = (
			source_proxy.global_position
			+ origin_offset
			+ direction * cast_spawn_distance
		)
		if power_ratio > 0.0:
			var scale_bonus: float = 1.0 + 0.55 * power_ratio
			node_3d.scale *= scale_bonus
	if instance.has_method("launch"):
		instance.call("launch", direction)
	_clear_cast_metadata(source_proxy, cast_metadata)
	return instance


static func _clear_cast_metadata(
	source_proxy: Node3D,
	cast_metadata: Dictionary
) -> void:
	if source_proxy == null or not is_instance_valid(source_proxy):
		return
	for key_value: Variant in cast_metadata.keys():
		var meta_key: String = "clone_cast_" + str(key_value)
		if source_proxy.has_meta(meta_key):
			source_proxy.remove_meta(meta_key)
