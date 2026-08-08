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
	clone_kind: String = "repeat"
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

	var payload: Resource = payload_override
	if payload == null:
		payload = ability.get_action_payload()
	if payload != null and payload.has_method("duplicate"):
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
	return instance
