extends Node3D
class_name RepeatEchoController

const RepeatEchoActorScript = preload(
	"res://scripts/time/repeat_echo_actor.gd"
)
const GameplayEffectAccessScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)

const POSE_PATHS: Array[String] = [
	"VisualRoot",
	"VisualRoot/BodyRoot",
	"VisualRoot/HeadRoot",
	"VisualRoot/LeftShoulderPivot",
	"VisualRoot/RightShoulderPivot",
	"VisualRoot/LeftShoulderPivot/LeftHand",
	"VisualRoot/RightShoulderPivot/RightHand",
	"VisualRoot/LeftLegPivot",
	"VisualRoot/RightLegPivot",
	"VisualRoot/SashTailPivot",
	"VisualRoot/LeftHairLockPivot",
	"VisualRoot/RightHairLockPivot",
	"VisualRoot/HeadRoot/LeftEye",
	"VisualRoot/HeadRoot/RightEye",
	"VisualRoot/HeadRoot/LeftBrow",
	"VisualRoot/HeadRoot/RightBrow",
	"VisualRoot/HeadRoot/Mouth",
]

@export_range(0.25, 3.0, 0.05) var delay_seconds: float = 1.0
@export_range(1, 8, 1) var echo_count: int = 1
@export_range(0.1, 2.0, 0.05) var echo_spacing_seconds: float = 0.42
@export_range(1.5, 12.0, 0.25) var history_seconds: float = 5.0
@export_range(0.2, 1.0, 0.05) var repeated_attack_damage_multiplier: float = 0.68
@export_range(0.2, 1.5, 0.05) var repeated_stance_multiplier: float = 0.8
@export var replay_weapon_attacks: bool = true
@export var show_debug_messages: bool = false

var source_actor: CharacterBody3D = null
var source_visual: Node3D = null
var weapon_controller: WeaponController = null
var concentration_manager: Node = null
var active_definition: Resource = null
var echoes: Array[RepeatEchoActor] = []
var history: Array[Dictionary] = []
var pending_attack_events: Array[Dictionary] = []
var elapsed: float = 0.0
var recorded_snapshot_count: int = 0
var replayed_attack_count: int = 0
var replayed_hit_count: int = 0
var last_replayed_attack_id: String = "none"
var registered_source_ids: Array[int] = []


func _ready() -> void:
	add_to_group("repeat_echo_controller")
	add_to_group("spell_effects")
	add_to_group("persistent_spell_effects")
	add_to_group("debuggable")
	process_priority = 70
	set_physics_process(false)


func bind_repeat(
	actor: Node3D,
	manager: Node,
	definition: Resource = null
) -> bool:
	if not actor is CharacterBody3D:
		return false
	source_actor = actor as CharacterBody3D
	source_visual = source_actor.get_node_or_null("GraceVisualV1") as Node3D
	weapon_controller = source_actor.get_node_or_null("WeaponController") as WeaponController
	concentration_manager = manager
	active_definition = definition
	registered_source_ids = [source_actor.get_instance_id()]
	_connect_runtime_signals()
	_spawn_echoes()
	_record_snapshot()
	set_physics_process(true)
	return not echoes.is_empty()


# Future Soul doubles can call this without changing Repeat's public contract.
# v1 records Grace as the authoritative lane; the registry is already explicit so
# a multi-source history table can replace the single lane without changing spells.
func register_repeat_source(actor: Node3D) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var source_id: int = actor.get_instance_id()
	if not registered_source_ids.has(source_id):
		registered_source_ids.append(source_id)
	return true


func _exit_tree() -> void:
	_disconnect_runtime_signals()
	_clear_echoes()


func _physics_process(delta: float) -> void:
	if not _repeat_is_still_concentrated():
		queue_free()
		return
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return
	elapsed += maxf(delta, 0.0)
	_record_snapshot()
	_trim_history()
	_replay_echoes()
	_process_attack_events()


func _record_snapshot() -> void:
	if source_actor == null or source_visual == null:
		return
	var poses: Dictionary = {}
	for path_text: String in POSE_PATHS:
		var node: Node3D = source_visual.get_node_or_null(path_text) as Node3D
		if node != null:
			poses[path_text] = node.transform
	history.append({
		"time": elapsed,
		"actor_transform": source_actor.global_transform,
		"visual_transform": source_visual.transform,
		"poses": poses,
		"body_form": str(source_actor.get_meta("body_form_id", "normal")),
	})
	recorded_snapshot_count += 1


func _trim_history() -> void:
	var oldest_needed: float = elapsed - maxf(
		history_seconds,
		delay_seconds + float(echo_count) * echo_spacing_seconds + 1.0
	)
	while history.size() > 2 and float(history[1].get("time", 0.0)) < oldest_needed:
		history.pop_front()


func _replay_echoes() -> void:
	for echo_index_value: int in range(echoes.size()):
		var echo: RepeatEchoActor = echoes[echo_index_value]
		if echo == null or not is_instance_valid(echo):
			continue
		var lane_delay: float = (
			delay_seconds + float(echo_index_value) * echo_spacing_seconds
		)
		var snapshot: Dictionary = _sample_history(elapsed - lane_delay)
		if not snapshot.is_empty():
			echo.apply_snapshot(snapshot)


func _sample_history(target_time: float) -> Dictionary:
	if history.is_empty():
		return {}
	if target_time <= float(history[0].get("time", 0.0)):
		return history[0]
	for index: int in range(history.size() - 1, -1, -1):
		var row: Dictionary = history[index]
		if float(row.get("time", 0.0)) <= target_time:
			return row
	return history[0]


func _spawn_echoes() -> void:
	_clear_echoes()
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	for index: int in range(maxi(echo_count, 1)):
		var echo := RepeatEchoActorScript.new() as RepeatEchoActor
		echo.configure(
			index,
			delay_seconds + float(index) * echo_spacing_seconds
		)
		parent.add_child(echo)
		echoes.append(echo)


func _clear_echoes() -> void:
	for echo: RepeatEchoActor in echoes:
		if echo != null and is_instance_valid(echo):
			echo.queue_free()
	echoes.clear()


func _connect_runtime_signals() -> void:
	if weapon_controller != null and replay_weapon_attacks:
		var attack_callback := Callable(self, "_on_attack_started")
		if not weapon_controller.attack_started.is_connected(attack_callback):
			weapon_controller.attack_started.connect(attack_callback)
	if concentration_manager != null:
		var release_callback := Callable(self, "_on_concentration_released")
		if concentration_manager.has_signal("effect_deactivated") and not concentration_manager.is_connected(
			"effect_deactivated",
			release_callback
		):
			concentration_manager.connect("effect_deactivated", release_callback)


func _disconnect_runtime_signals() -> void:
	if weapon_controller != null and is_instance_valid(weapon_controller):
		var attack_callback := Callable(self, "_on_attack_started")
		if weapon_controller.attack_started.is_connected(attack_callback):
			weapon_controller.attack_started.disconnect(attack_callback)
	if concentration_manager != null and is_instance_valid(concentration_manager):
		var release_callback := Callable(self, "_on_concentration_released")
		if concentration_manager.has_signal("effect_deactivated") and concentration_manager.is_connected(
			"effect_deactivated",
			release_callback
		):
			concentration_manager.disconnect("effect_deactivated", release_callback)


func _on_attack_started(attack: WeaponAttackDefinition) -> void:
	if attack == null or weapon_controller == null:
		return
	var payload: DamagePayload = attack.build_payload(weapon_controller.equipped_weapon)
	if payload == null:
		return
	payload = payload.duplicate(true) as DamagePayload
	payload.amount = maxi(
		roundi(
			float(GameplayEffectAccessScript.modify_int("weapon_damage", payload.amount))
			* repeated_attack_damage_multiplier
		),
		0
	)
	payload.stance_damage = maxi(
		roundi(
			float(GameplayEffectAccessScript.modify_int(
				"weapon_stance_damage",
				payload.stance_damage
			)) * repeated_stance_multiplier
		),
		0
	)
	payload.knockback_strength = maxf(
		GameplayEffectAccessScript.modify_float(
			"weapon_knockback",
			payload.knockback_strength
		) * repeated_attack_damage_multiplier,
		0.0
	)
	payload.source_name = "Repeat • " + payload.source_name
	for tag: String in ["time", "repeat", "echo", "delayed_copy"]:
		if not payload.tags.has(tag):
			payload.tags.append(tag)
	var body_form: String = str(source_actor.get_meta("body_form_id", "normal"))
	if body_form != "normal" and not payload.tags.has("body_form_" + body_form):
		payload.tags.append("body_form_" + body_form)
	var effective_range: float = weapon_controller.get_effective_attack_range(attack)
	for echo_index_value: int in range(echoes.size()):
		pending_attack_events.append({
			"fire_time": elapsed + delay_seconds + float(echo_index_value) * echo_spacing_seconds,
			"echo_index": echo_index_value,
			"attack_id": attack.attack_id,
			"range": effective_range,
			"cone": attack.cone_angle_degrees,
			"center_offset": attack.attack_center_forward_offset,
			"max_targets": attack.max_targets,
			"payload": payload.duplicate(true),
		})


func _process_attack_events() -> void:
	var remaining: Array[Dictionary] = []
	for event: Dictionary in pending_attack_events:
		if float(event.get("fire_time", INF)) > elapsed:
			remaining.append(event)
			continue
		_replay_attack_event(event)
	pending_attack_events = remaining


func _replay_attack_event(event: Dictionary) -> void:
	var echo_index_value: int = int(event.get("echo_index", -1))
	if echo_index_value < 0 or echo_index_value >= echoes.size():
		return
	var echo: RepeatEchoActor = echoes[echo_index_value]
	if echo == null or not is_instance_valid(echo):
		return
	var payload_value: Variant = event.get("payload")
	if not payload_value is DamagePayload:
		return
	var payload: DamagePayload = (payload_value as DamagePayload).duplicate(true) as DamagePayload
	var attack_range: float = maxf(float(event.get("range", 2.0)), 0.1)
	var center_offset: float = float(event.get("center_offset", 0.0))
	var cone_degrees: float = clampf(float(event.get("cone", 360.0)), 1.0, 360.0)
	var maximum_targets: int = maxi(int(event.get("max_targets", 3)), 1)
	var forward: Vector3 = -echo.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var center: Vector3 = echo.global_position + forward * center_offset + Vector3.UP * 0.9
	var targets: Array[Node] = _find_payload_targets(
		center,
		forward,
		attack_range,
		cone_degrees,
		maximum_targets
	)
	for target: Node in targets:
		_send_payload(target, payload)
		replayed_hit_count += 1
	replayed_attack_count += 1
	last_replayed_attack_id = str(event.get("attack_id", "attack"))
	echo.pulse_attack(attack_range)


func _find_payload_targets(
	center: Vector3,
	forward: Vector3,
	radius: float,
	cone_degrees: float,
	maximum_targets: int
) -> Array[Node]:
	var result: Array[Node] = []
	if source_actor == null or source_actor.get_world_3d() == null:
		return result
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [source_actor.get_rid()]
	var hits: Array[Dictionary] = source_actor.get_world_3d().direct_space_state.intersect_shape(
		query,
		64
	)
	var minimum_dot: float = cos(deg_to_rad(cone_degrees * 0.5))
	var seen: Dictionary = {}
	for hit: Dictionary in hits:
		var collider_value: Variant = hit.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _find_payload_target(collider_value as Node)
		if target == null or target == source_actor:
			continue
		var target_id: int = target.get_instance_id()
		if seen.has(target_id):
			continue
		var target_position: Vector3 = _get_target_position(target)
		var offset: Vector3 = target_position - center
		offset.y = 0.0
		if offset.length_squared() > 0.0001 and cone_degrees < 359.0:
			if forward.dot(offset.normalized()) < minimum_dot:
				continue
		seen[target_id] = true
		result.append(target)
		if result.size() >= maximum_targets:
			break
	return result


func _find_payload_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if _is_payload_target(current):
			return current
		var child_target: Node = _find_payload_target_in_children(current)
		if child_target != null:
			return child_target
		current = current.get_parent()
	return null


func _find_payload_target_in_children(node: Node) -> Node:
	if node == null:
		return null
	for child: Node in node.get_children():
		if _is_payload_target(child):
			return child
		var deeper: Node = _find_payload_target_in_children(child)
		if deeper != null:
			return deeper
	return null


func _is_payload_target(node: Node) -> bool:
	return (
		node.get_node_or_null("PayloadReceiver") != null
		or node.get_node_or_null("HitReceiver") != null
		or node.has_method("receive_damage_payload")
	)


func _send_payload(target: Node, payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.call("receive_payload", payload) as Dictionary
	if target.has_method("receive_damage_payload"):
		return target.call("receive_damage_payload", payload) as Dictionary
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			return hit_receiver.call("receive_payload", payload) as Dictionary
		if hit_receiver.has_method("receive_hit"):
			return hit_receiver.call("receive_hit", payload.amount) as Dictionary
	return {}


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	return (parent as Node3D).global_position if parent is Node3D else Vector3.ZERO


func _repeat_is_still_concentrated() -> bool:
	if concentration_manager == null or not is_instance_valid(concentration_manager):
		return false
	var active_value: Variant = concentration_manager.get("active_effect")
	if not active_value is Resource:
		return false
	return str((active_value as Resource).get("effect_id")) == "repeat_concentration"


func _on_concentration_released(effect_id: String) -> void:
	if effect_id == "repeat_concentration":
		queue_free()


func get_debug_data() -> Dictionary:
	return {
		"repeat_controller": true,
		"active": _repeat_is_still_concentrated(),
		"delay_seconds": delay_seconds,
		"echo_count": echoes.size(),
		"echo_spacing": echo_spacing_seconds,
		"history_samples": history.size(),
		"recorded_snapshots": recorded_snapshot_count,
		"pending_attacks": pending_attack_events.size(),
		"replayed_attacks": replayed_attack_count,
		"replayed_hits": replayed_hit_count,
		"last_attack_id": last_replayed_attack_id,
		"registered_sources": registered_source_ids.size(),
		"future_multi_source_hook": true,
	}
