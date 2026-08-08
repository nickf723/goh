extends Node
class_name SoulDuplicateController

const DuplicateActorScript = preload(
	"res://scripts/soul/soul_duplicate_actor.gd"
)
const CloneSemantics = preload(
	"res://scripts/abilities/spell_clone_semantics.gd"
)

signal duplicate_spawned(duplicate: SoulDuplicateActor)
signal duplicate_removed
signal spell_mirrored(spell_id: String, mode: String)

@export_range(1, 8, 1) var duplicate_count: int = 1
@export_range(0.5, 5.0, 0.1) var side_spacing: float = 1.7

var source_actor: CharacterBody3D = null
var concentration_manager: Node = null
var ability_caster: Node = null
var weapon_controller: WeaponController = null
var duplicates: Array[SoulDuplicateActor] = []
var observed_spell_instances: Dictionary = {}
var mirrored_spell_count: int = 0
var suppressed_spell_count: int = 0
var world_state_noop_count: int = 0
var last_spell_id: String = "none"
var last_mode: String = "none"


func bind_duplicate(actor: CharacterBody3D, manager: Node) -> bool:
	source_actor = actor
	concentration_manager = manager
	if source_actor == null or not is_instance_valid(source_actor):
		return false
	ability_caster = source_actor.get_node_or_null("AbilityCaster")
	weapon_controller = source_actor.get_node_or_null("WeaponController") as WeaponController
	if weapon_controller != null:
		var callback := Callable(self, "_on_weapon_attack_started")
		if not weapon_controller.attack_started.is_connected(callback):
			weapon_controller.attack_started.connect(callback)
	if concentration_manager != null and concentration_manager.has_signal("effect_deactivated"):
		var concentration_callback := Callable(self, "_on_concentration_released")
		if not concentration_manager.is_connected("effect_deactivated", concentration_callback):
			concentration_manager.connect("effect_deactivated", concentration_callback)
	var tree: SceneTree = get_tree()
	if tree != null:
		var node_callback := Callable(self, "_on_scene_node_added")
		if not tree.node_added.is_connected(node_callback):
			tree.node_added.connect(node_callback)
	_spawn_duplicates()
	_register_with_repeat()
	add_to_group("soul_duplicate_controller")
	add_to_group("debuggable")
	return not duplicates.is_empty()


func _exit_tree() -> void:
	if weapon_controller != null and is_instance_valid(weapon_controller):
		var callback := Callable(self, "_on_weapon_attack_started")
		if weapon_controller.attack_started.is_connected(callback):
			weapon_controller.attack_started.disconnect(callback)
	if concentration_manager != null and is_instance_valid(concentration_manager) and concentration_manager.has_signal("effect_deactivated"):
		var concentration_callback := Callable(self, "_on_concentration_released")
		if concentration_manager.is_connected("effect_deactivated", concentration_callback):
			concentration_manager.disconnect("effect_deactivated", concentration_callback)
	var tree: SceneTree = get_tree()
	if tree != null:
		var node_callback := Callable(self, "_on_scene_node_added")
		if tree.node_added.is_connected(node_callback):
			tree.node_added.disconnect(node_callback)
	_clear_duplicates()


func _spawn_duplicates() -> void:
	_clear_duplicates()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for index: int in range(maxi(duplicate_count, 1)):
		var duplicate := DuplicateActorScript.new() as SoulDuplicateActor
		duplicate.name = "SoulDuplicate" + str(index + 1)
		duplicate.default_side_offset = side_spacing
		duplicate.set_meta("clone_spell_replay", true)
		duplicate.set_meta("clone_spell_kind", "soul_duplicate")
		scene_root.add_child(duplicate)
		duplicate.configure(source_actor, index)
		duplicates.append(duplicate)
		duplicate_spawned.emit(duplicate)


func _clear_duplicates() -> void:
	for duplicate: SoulDuplicateActor in duplicates:
		if duplicate != null and is_instance_valid(duplicate):
			duplicate.queue_free()
	duplicates.clear()
	duplicate_removed.emit()


func _on_weapon_attack_started(attack: WeaponAttackDefinition) -> void:
	var weapon: WeaponDefinition = weapon_controller.equipped_weapon if weapon_controller != null else null
	for duplicate: SoulDuplicateActor in duplicates:
		if duplicate != null and is_instance_valid(duplicate):
			duplicate.mirror_weapon_attack(attack, weapon)


func _on_scene_node_added(node: Node) -> void:
	if node == null or not is_instance_valid(node) or _belongs_to_clone(node):
		return
	var ability: AbilityDefinition = _get_current_player_ability()
	if ability == null:
		return
	var source_value: Node = _read_source_actor(node)
	if source_value != null and source_value != source_actor:
		return
	if ability.ability_scene != null:
		var path: String = node.scene_file_path
		if path == "" or path != ability.ability_scene.resource_path:
			return
	var node_id: int = node.get_instance_id()
	if observed_spell_instances.has(node_id):
		return
	observed_spell_instances[node_id] = true
	_mirror_ability(ability, node)


func _mirror_ability(ability: AbilityDefinition, original_instance: Node) -> void:
	var mode: String = CloneSemantics.get_duplicate_mode(ability)
	last_spell_id = ability.get_spell_id()
	last_mode = mode
	match mode:
		CloneSemantics.DUPLICATE_WORLD_STATE:
			world_state_noop_count += 1
			spell_mirrored.emit(last_spell_id, mode)
			return
		CloneSemantics.DUPLICATE_SUPPRESS:
			suppressed_spell_count += 1
			spell_mirrored.emit(last_spell_id, mode)
			return
		CloneSemantics.DUPLICATE_SOURCE_STATE:
			var direction: Vector3 = _get_cast_direction()
			for duplicate: SoulDuplicateActor in duplicates:
				if duplicate != null and is_instance_valid(duplicate):
					duplicate.apply_source_state_spell(last_spell_id, direction)
			mirrored_spell_count += 1
			spell_mirrored.emit(last_spell_id, mode)
			return
		_:
			pass

	var cast_direction: Vector3 = _get_cast_direction()
	var payload: Resource = _capture_payload(original_instance, ability)
	for duplicate: SoulDuplicateActor in duplicates:
		if duplicate == null or not is_instance_valid(duplicate):
			continue
		_spawn_live_spell(duplicate, ability, cast_direction, payload)
	mirrored_spell_count += 1
	spell_mirrored.emit(last_spell_id, mode)


func _spawn_live_spell(
	duplicate: SoulDuplicateActor,
	ability: AbilityDefinition,
	cast_direction: Vector3,
	payload_override: Resource
) -> void:
	if ability == null:
		return
	if ability.get_spell_id() == "flamethrower":
		var controller: PlayerFlamethrowerController = duplicate.flamethrower_controller
		if controller != null:
			controller.begin_ability_channel(duplicate, ability)
		return
	if ability.ability_scene == null:
		return
	var instance: Node = ability.ability_scene.instantiate()
	if instance == null:
		return
	instance.set_meta("clone_spell_replay", true)
	instance.set_meta("clone_spell_kind", "soul_duplicate")
	instance.set_meta("clone_live_simulation", true)
	if payload_override != null and instance.has_method("set_payload"):
		instance.call("set_payload", payload_override.duplicate(true))
	if instance.has_method("set_source_actor"):
		instance.call("set_source_actor", duplicate)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(instance)
	if instance.has_method("execute"):
		instance.call("execute", duplicate, cast_direction)
		return
	if instance is Node3D:
		(instance as Node3D).global_position = duplicate.global_position + Vector3.UP * 0.85 + cast_direction * 0.3
	if instance.has_method("launch"):
		instance.call("launch", cast_direction)


func _get_current_player_ability() -> AbilityDefinition:
	if ability_caster == null or not is_instance_valid(ability_caster) or not ability_caster.has_method("get_current_ability"):
		return null
	var value: Variant = ability_caster.call("get_current_ability")
	return value as AbilityDefinition if value is AbilityDefinition else null


func _get_cast_direction() -> Vector3:
	if source_actor == null:
		return Vector3.FORWARD
	var origin: Vector3 = source_actor.global_position + Vector3.UP
	if ability_caster != null and ability_caster.has_method("get_cast_direction"):
		var value: Variant = ability_caster.call("get_cast_direction", source_actor, origin)
		if value is Vector3 and (value as Vector3).length_squared() > 0.001:
			return (value as Vector3).normalized()
	var direction: Vector3 = -source_actor.global_transform.basis.z
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD


func _capture_payload(original_instance: Node, ability: AbilityDefinition) -> Resource:
	if original_instance != null and original_instance.has_method("get_payload"):
		var value: Variant = original_instance.call("get_payload")
		if value is Resource:
			return (value as Resource).duplicate(true)
	if ability != null and ability.get_action_payload() != null:
		return ability.get_action_payload().duplicate(true)
	return null


func _read_source_actor(node: Node) -> Node:
	for property_value: Variant in node.get_property_list():
		if property_value is Dictionary and str((property_value as Dictionary).get("name", "")) == "source_actor":
			var value: Variant = node.get("source_actor")
			return value as Node if value is Node else null
	return null


func _belongs_to_clone(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if bool(current.get_meta("clone_spell_replay", false)) or current.is_in_group("clone_spell_replays") or current.is_in_group("soul_duplicates"):
			return true
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return false


func _register_with_repeat() -> void:
	var repeat_controller: Node = get_tree().get_first_node_in_group("repeat_echo_controller")
	if repeat_controller == null or not repeat_controller.has_method("register_repeat_source"):
		return
	for duplicate: SoulDuplicateActor in duplicates:
		if duplicate != null and is_instance_valid(duplicate):
			repeat_controller.call("register_repeat_source", duplicate)


func _on_concentration_released(effect_id: String) -> void:
	if effect_id == "duplicate_concentration":
		queue_free()


func get_debug_data() -> Dictionary:
	return {
		"soul_duplicate_controller": true,
		"duplicate_count": duplicates.size(),
		"mirrored_spells": mirrored_spell_count,
		"suppressed_spells": suppressed_spell_count,
		"world_state_noops": world_state_noop_count,
		"last_spell": last_spell_id,
		"last_mode": last_mode,
		"live_simulation": true,
		"repeat_source_registration": true,
	}
