extends Node
class_name MobMoveEffectExecutor

const TargetResolver = preload(
	"res://scripts/mobs/mob_effect_target_resolver.gd"
)
const PayloadBridge = preload(
	"res://scripts/mobs/mob_payload_bridge.gd"
)
const RecoveryBridge = preload(
	"res://scripts/mobs/mob_recovery_bridge.gd"
)
const DefaultProjectileScene: PackedScene = preload(
	"res://scenes/actions/generic_projectile.tscn"
)

signal effect_execution_started(request: Dictionary, targets: Array[Node])
signal effect_execution_completed(request: Dictionary, result: Dictionary)
signal projectile_spawned(request: Dictionary, projectile: Node)
signal executor_effect_requested(request: Dictionary, targets: Array[Node])

@export var automatic_execution: bool = true
@export var brain_path: NodePath = NodePath("../MobBrainComponent")
@export var target_provider_path: NodePath = NodePath("..")
@export var projectile_scene: PackedScene = DefaultProjectileScene
@export var projectile_origin_height: float = 0.8
@export var projectile_forward_offset: float = 0.55
@export var collision_mask: int = 0xFFFFFFFF
@export var fallback_enemy_groups: Array[String] = ["enemy", "player"]
@export var fallback_ally_groups: Array[String] = [
	"generic_animals",
	"summon",
	"friendly_actor",
]
@export var fallback_environment_groups: Array[String] = []
@export_range(1, 128, 1) var request_memory_limit: int = 32

var brain: MobBrainComponent
var source_actor: Node
var executed_request_ids: Dictionary = {}
var request_order: Array[String] = []
var last_request: Dictionary = {}
var last_result: Dictionary = {}
var execution_count: int = 0
var projectile_count: int = 0


func _ready() -> void:
	source_actor = get_parent()
	add_to_group("mob_move_effect_executor")
	add_to_group("debuggable")
	if brain == null:
		var candidate: Node = get_node_or_null(brain_path)
		if candidate is MobBrainComponent:
			bind_brain(candidate as MobBrainComponent)


func bind_brain(new_brain: MobBrainComponent) -> void:
	if brain == new_brain:
		return
	if (
		brain != null
		and brain.move_effect_requested.is_connected(_on_move_effect_requested)
	):
		brain.move_effect_requested.disconnect(_on_move_effect_requested)
	brain = new_brain
	if (
		brain != null
		and not brain.move_effect_requested.is_connected(_on_move_effect_requested)
	):
		brain.move_effect_requested.connect(_on_move_effect_requested)


func execute_request(
	request: Dictionary,
	execution: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var validation_failures: Array[String] = MobMoveEffectRequest.validate_request(
		request
	)
	if not validation_failures.is_empty():
		return _complete(request, {
			"ok": false,
			"error": "; ".join(validation_failures),
		})
	var request_id: String = str(request.get("request_id", ""))
	if request_id != "" and executed_request_ids.has(request_id):
		return {
			"ok": false,
			"duplicate": true,
			"request_id": request_id,
			"move_id": str(request.get("move_id", "")),
			"previous_result": (
				executed_request_ids[request_id] as Dictionary
			).duplicate(true),
		}
	_remember_request(request_id, {})
	var resolved_options: Dictionary = {
		"enemy_groups": fallback_enemy_groups,
		"ally_groups": fallback_ally_groups,
		"environment_groups": fallback_environment_groups,
		"collision_mask": collision_mask,
	}
	resolved_options.merge(options, true)
	var targets: Array[Node] = TargetResolver.resolve_targets(
		source_actor,
		request,
		_resolve_target_provider(),
		resolved_options
	)
	effect_execution_started.emit(request, targets)
	var delivery: String = str(request.get("delivery", ""))
	var result: Dictionary
	match delivery:
		MobMoveEffectRequest.DELIVERY_CONTACT_PAYLOAD:
			result = _execute_contact(request, targets)
		MobMoveEffectRequest.DELIVERY_AREA_PAYLOAD:
			result = PayloadBridge.deliver_to_targets(
				request,
				targets,
				source_actor
			)
		MobMoveEffectRequest.DELIVERY_PROJECTILE_PAYLOAD:
			result = _spawn_projectile(request, targets, execution)
		MobMoveEffectRequest.DELIVERY_RECOVERY:
			result = _execute_recovery(request, targets)
		_:
			executor_effect_requested.emit(request, targets)
			result = {
				"ok": true,
				"requires_executor": true,
				"delivery": delivery,
				"target_count": targets.size(),
			}
	return _complete(request, result)


func confirm_projectile_impact(
	request: Dictionary,
	target: Node
) -> Dictionary:
	return PayloadBridge.deliver_to_target(
		request,
		target,
		source_actor,
		{"impact_confirmed": true}
	)


func clear_request_memory() -> void:
	executed_request_ids.clear()
	request_order.clear()
	last_request.clear()
	last_result.clear()


func reset_executor() -> void:
	clear_request_memory()
	execution_count = 0
	projectile_count = 0


func get_debug_data() -> Dictionary:
	return {
		"automatic_execution": automatic_execution,
		"source_actor": str(source_actor.name) if source_actor != null else "none",
		"brain_bound": brain != null,
		"execution_count": execution_count,
		"projectile_count": projectile_count,
		"remembered_request_count": request_order.size(),
		"last_request": last_request.duplicate(true),
		"last_result": last_result.duplicate(true),
	}


func _on_move_effect_requested(
	_move_id: String,
	request: Dictionary,
	execution: Dictionary
) -> void:
	if automatic_execution:
		execute_request(request, execution)


func _execute_contact(
	request: Dictionary,
	targets: Array[Node]
) -> Dictionary:
	if targets.is_empty():
		return {
			"ok": false,
			"error": "no confirmed contact target",
			"requires_target": true,
		}
	return PayloadBridge.deliver_to_target(
		request,
		targets[0],
		source_actor
	)


func _execute_recovery(
	request: Dictionary,
	targets: Array[Node]
) -> Dictionary:
	var recovery_targets: Array[Node] = targets.duplicate()
	if recovery_targets.is_empty() and source_actor != null:
		recovery_targets.append(source_actor)
	var results: Array[Dictionary] = []
	var applied_count: int = 0
	for target: Node in recovery_targets:
		var result: Dictionary = RecoveryBridge.apply_request(request, target)
		results.append(result)
		if bool(result.get("ok", false)):
			applied_count += 1
	return {
		"ok": applied_count > 0,
		"applied_count": applied_count,
		"target_count": recovery_targets.size(),
		"results": results,
	}


func _spawn_projectile(
	request: Dictionary,
	targets: Array[Node],
	execution: Dictionary
) -> Dictionary:
	if projectile_scene == null:
		return {"ok": false, "error": "projectile scene is missing"}
	if source_actor == null or not source_actor is Node3D:
		return {"ok": false, "error": "projectile source is not a Node3D"}
	var payload: DamagePayload = PayloadBridge.create_damage_payload(
		request,
		source_actor,
		targets[0] if not targets.is_empty() else null
	)
	if payload == null:
		return {"ok": false, "error": "projectile request has no payload"}
	var raw_projectile: Node = projectile_scene.instantiate()
	if not raw_projectile is Node3D:
		if raw_projectile != null:
			raw_projectile.queue_free()
		return {"ok": false, "error": "projectile scene root is not Node3D"}
	var projectile: Node3D = raw_projectile as Node3D
	var direction: Vector3 = _projectile_direction(
		projectile,
		targets[0] if not targets.is_empty() else null,
		execution
	)
	if projectile.has_method("set_payload"):
		projectile.call("set_payload", payload)
	if projectile.has_method("set_source_actor"):
		projectile.call("set_source_actor", source_actor)
	var effect: Dictionary = request.get("effect", {}) as Dictionary
	if effect.has("speed"):
		projectile.set("speed", maxf(float(effect.get("speed", 1.0)), 0.1))
	var maximum_range: float = maxf(float(request.get("maximum_range", 0.0)), 0.0)
	var projectile_speed: float = maxf(float(effect.get("speed", 12.0)), 0.1)
	if maximum_range > 0.0:
		projectile.set(
			"max_lifetime",
			maxf(maximum_range / projectile_speed + 0.25, 0.35)
		)
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = source_actor.get_parent()
	if parent == null:
		projectile.queue_free()
		return {"ok": false, "error": "projectile has no world parent"}
	parent.add_child(projectile)
	projectile.global_position = _projectile_origin(direction, request)
	if projectile.has_method("launch"):
		projectile.call("launch", direction)
	else:
		projectile.queue_free()
		return {"ok": false, "error": "projectile has no launch method"}
	projectile_count += 1
	projectile_spawned.emit(request, projectile)
	return {
		"ok": true,
		"delivery": MobMoveEffectRequest.DELIVERY_PROJECTILE_PAYLOAD,
		"projectile_instance_id": projectile.get_instance_id(),
		"target_instance_id": (
			targets[0].get_instance_id()
			if not targets.is_empty()
			else 0
		),
		"direction": direction,
	}


func _projectile_origin(
	direction: Vector3,
	request: Dictionary
) -> Vector3:
	var provider: Node = _resolve_target_provider()
	if provider != null and provider.has_method("get_mob_effect_origin"):
		var raw_origin: Variant = provider.call("get_mob_effect_origin", request)
		if raw_origin is Vector3:
			return raw_origin as Vector3
	var source_3d: Node3D = source_actor as Node3D
	return (
		source_3d.global_position
		+ Vector3.UP * projectile_origin_height
		+ direction * projectile_forward_offset
	)


func _projectile_direction(
	_projectile: Node3D,
	target: Node,
	execution: Dictionary
) -> Vector3:
	var source_3d: Node3D = source_actor as Node3D
	if target is Node3D:
		var target_position: Vector3 = (target as Node3D).global_position
		var direction: Vector3 = target_position - source_3d.global_position
		if direction.length_squared() > 0.0001:
			return direction.normalized()
	var context: Dictionary = execution.get("context", {}) as Dictionary
	var raw_direction: Variant = context.get("aim_direction")
	if raw_direction is Vector3 and (raw_direction as Vector3).length_squared() > 0.0001:
		return (raw_direction as Vector3).normalized()
	return -source_3d.global_basis.z.normalized()


func _resolve_target_provider() -> Node:
	if target_provider_path.is_empty():
		return source_actor
	var provider: Node = get_node_or_null(target_provider_path)
	return provider if provider != null else source_actor


func _remember_request(
	request_id: String,
	result: Dictionary
) -> void:
	if request_id == "":
		return
	executed_request_ids[request_id] = result.duplicate(true)
	request_order.erase(request_id)
	request_order.append(request_id)
	while request_order.size() > request_memory_limit:
		var expired_id: String = request_order.pop_front()
		executed_request_ids.erase(expired_id)


func _complete(
	request: Dictionary,
	result: Dictionary
) -> Dictionary:
	var completed_result: Dictionary = result.duplicate(true)
	completed_result["request_id"] = str(request.get("request_id", ""))
	completed_result["move_id"] = str(request.get("move_id", ""))
	last_request = request.duplicate(true)
	last_result = completed_result.duplicate(true)
	execution_count += 1
	var request_id: String = str(request.get("request_id", ""))
	if request_id != "":
		executed_request_ids[request_id] = completed_result.duplicate(true)
	effect_execution_completed.emit(request, completed_result)
	return completed_result
