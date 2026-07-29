extends "res://scripts/avatars/avatar_control_driver.gd"
class_name CompanionAvatarControlDriver

@export_group("Formation")
@export_range(0.5, 8.0, 0.1) var follow_distance: float = 2.8
@export_range(0.2, 3.0, 0.05) var follow_tolerance: float = 0.85
@export_range(4.0, 40.0, 0.5) var recall_distance: float = 18.0

@export_group("Targeting")
@export_range(2.0, 40.0, 0.5) var target_search_range: float = 17.0
@export_range(0.5, 8.0, 0.1) var preferred_range_min: float = 2.2
@export_range(0.5, 10.0, 0.1) var preferred_range_max: float = 4.6
@export_range(0.5, 12.0, 0.1) var spell_range: float = 10.5

@export_group("Decision Rhythm")
@export_range(0.02, 1.0, 0.01) var decision_interval: float = 0.18
@export_range(0.05, 3.0, 0.05) var spell_cooldown_seconds: float = 0.72
@export_range(0.1, 5.0, 0.05) var dodge_cooldown_seconds: float = 1.8
@export_range(0.1, 4.0, 0.05) var strafe_switch_seconds: float = 1.15

const CINDER_SWEEP: String = "ruvia_halberd_l1"
const BACKDRAFT_RETURN: String = "ruvia_halberd_l2"
const HAFT_CHECK: String = "ruvia_halberd_l3"
const EMBER_WHEEL: String = "ruvia_halberd_l5"
const SCORCHING_THRUST: String = "ruvia_halberd_h1"
const REAPING_HOOK: String = "ruvia_halberd_h2"
const SOLAR_DESCENT: String = "ruvia_halberd_h4"
const FIREBOLT: String = "firebolt"
const FIRE_FIELD: String = "fire_field"

var current_target: Node3D
var decision_remaining: float = 0.0
var spell_cooldown_remaining: float = 0.0
var dodge_cooldown_remaining: float = 0.0
var strafe_switch_remaining: float = 0.0
var strafe_sign: float = 1.0
var decision_index: int = 0
var light_alternator: bool = false
var pending_spell_id: String = ""
var pending_spell_reason: String = ""
var requested_follow_up_spell: String = ""
var last_selected_action: String = "idle"
var last_decision_reason: String = "waiting"
var last_target_distance: float = -1.0
var last_cluster_count: int = 0
var last_owned_field_count: int = 0
var last_target_burning: bool = false
var last_actor_inside_field: bool = false
var last_target_near_field: bool = false


func _ready() -> void:
	driver_id = "companion_ai"
	display_name = "Companion AI"
	add_to_group("avatar_control_driver")
	add_to_group("companion_avatar_control_driver")
	add_to_group("debuggable")


func bind_actor(actor: Node3D, owner: Node3D = null) -> void:
	super.bind_actor(actor, owner)
	current_target = null
	decision_remaining = 0.0
	spell_cooldown_remaining = 0.0
	dodge_cooldown_remaining = 0.0
	strafe_switch_remaining = strafe_switch_seconds
	strafe_sign = -1.0 if actor != null and actor.get_instance_id() % 2 == 0 else 1.0
	pending_spell_id = ""
	pending_spell_reason = ""
	requested_follow_up_spell = ""
	last_selected_action = "idle"
	last_decision_reason = "bound"


func _build_intent(delta: float, intent: AvatarActionIntent) -> void:
	_advance_timers(delta)
	if owner_actor == null or not is_instance_valid(owner_actor):
		intent.recall_requested = true
		intent.decision_tag = "owner_missing"
		intent.action_reason = "The manifestation has no mortal anchor."
		return
	if controlled_actor == null or not is_instance_valid(controlled_actor):
		return

	var owner_distance: float = controlled_actor.global_position.distance_to(
		owner_actor.global_position
	)
	if owner_distance > recall_distance:
		intent.recall_requested = true
		intent.decision_tag = "recall"
		intent.action_reason = "Separated from Grace"
		return

	_refresh_target()
	if current_target == null:
		_build_follow_intent(intent)
		return
	_build_combat_intent(intent)


func notify_action_result(
	action_kind: String,
	action_id: String,
	success: bool
) -> void:
	super.notify_action_result(action_kind, action_id, success)
	if not success:
		decision_remaining = minf(decision_remaining, 0.08)
		requested_follow_up_spell = ""
		return
	last_selected_action = action_id
	decision_index += 1
	decision_remaining = decision_interval
	match action_kind:
		"spell":
			spell_cooldown_remaining = spell_cooldown_seconds
			if pending_spell_id == action_id:
				pending_spell_id = ""
				pending_spell_reason = ""
		"dodge":
			dodge_cooldown_remaining = dodge_cooldown_seconds
		"attack":
			if requested_follow_up_spell != "":
				pending_spell_id = requested_follow_up_spell
				pending_spell_reason = "Context follow-up after " + action_id
	requested_follow_up_spell = ""


func _advance_timers(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	decision_remaining = maxf(decision_remaining - step, 0.0)
	spell_cooldown_remaining = maxf(spell_cooldown_remaining - step, 0.0)
	dodge_cooldown_remaining = maxf(dodge_cooldown_remaining - step, 0.0)
	strafe_switch_remaining = maxf(strafe_switch_remaining - step, 0.0)
	if strafe_switch_remaining <= 0.0:
		strafe_switch_remaining = strafe_switch_seconds
		strafe_sign *= -1.0


func _build_follow_intent(intent: AvatarActionIntent) -> void:
	var owner_basis: Basis = owner_actor.global_transform.basis.orthonormalized()
	var desired_position: Vector3 = (
		owner_actor.global_position
		+ owner_basis.x * strafe_sign * follow_distance
		+ owner_basis.z * 0.72
	)
	var offset: Vector3 = desired_position - controlled_actor.global_position
	offset.y = 0.0
	if offset.length() > follow_tolerance:
		intent.set_movement(offset, clampf(offset.length() / follow_distance, 0.35, 1.0))
		intent.set_facing(offset)
		intent.decision_tag = "follow"
		intent.action_reason = "Hold formation beside Grace"
		last_decision_reason = intent.action_reason
	else:
		intent.set_facing(-owner_basis.z)
		intent.decision_tag = "formation_idle"
		intent.action_reason = "Formation established"
		last_decision_reason = intent.action_reason
	last_target_distance = -1.0
	last_cluster_count = 0
	last_target_burning = false
	last_actor_inside_field = false
	last_target_near_field = false
	last_owned_field_count = _get_owned_fields().size()


func _build_combat_intent(intent: AvatarActionIntent) -> void:
	var target_position: Vector3 = _get_target_position(current_target)
	var to_target: Vector3 = target_position - controlled_actor.global_position
	to_target.y = 0.0
	var distance: float = to_target.length()
	var direction: Vector3 = (
		to_target.normalized()
		if distance > 0.01
		else -controlled_actor.global_transform.basis.z
	)
	intent.target = current_target
	intent.set_facing(direction)
	last_target_distance = distance

	var fields: Array[Node] = _get_owned_fields()
	last_owned_field_count = fields.size()
	last_actor_inside_field = _is_position_inside_fields(
		controlled_actor.global_position,
		fields,
		0.35
	)
	last_target_near_field = _is_position_inside_fields(target_position, fields, 1.0)
	last_target_burning = _target_has_status(current_target, "burning")
	last_cluster_count = _count_enemy_cluster(target_position, 3.4)

	_build_combat_movement(intent, direction, distance)
	if not _actor_can_choose_action():
		intent.decision_tag = "combat_busy"
		intent.action_reason = "Complete the current form"
		return

	if pending_spell_id != "" and spell_cooldown_remaining <= 0.0:
		intent.spell_id = pending_spell_id
		intent.decision_tag = "planned_weave"
		intent.action_reason = pending_spell_reason
		last_decision_reason = intent.action_reason
		return
	if decision_remaining > 0.0:
		intent.decision_tag = "combat_measure"
		intent.action_reason = "Read spacing and elemental state"
		return

	if distance < 1.05 and dodge_cooldown_remaining <= 0.0:
		var side: Vector3 = Vector3.UP.cross(direction).normalized() * strafe_sign
		intent.dodge_requested = true
		intent.dodge_direction = (-direction * 0.72 + side * 0.68).normalized()
		intent.dodge_kind = "side"
		intent.decision_tag = "space_dodge"
		intent.action_reason = "Escape inside the halberd head"
		last_decision_reason = intent.action_reason
		return

	if (
		last_cluster_count >= 3
		and last_target_burning
		and distance <= 4.4
	):
		_request_attack(intent, SOLAR_DESCENT, "Spread Burning through a clustered target")
		return
	if last_target_near_field and distance <= 4.8:
		_request_attack(intent, REAPING_HOOK, "Pull the target through an owned Fire Field")
		return
	if last_actor_inside_field and distance >= 2.45 and distance <= 6.2:
		_request_attack(intent, SCORCHING_THRUST, "Carry the owned field into a burning wake")
		return
	if fields.size() > 0 and last_cluster_count >= 2 and distance <= 4.8:
		_request_attack(intent, EMBER_WHEEL, "Flare nearby owned Fire Fields")
		return
	if distance >= 6.1 and distance <= spell_range and spell_cooldown_remaining <= 0.0:
		intent.spell_id = FIREBOLT
		intent.decision_tag = "ranged_firebolt"
		intent.action_reason = "Pressure from halberd-tip range"
		last_decision_reason = intent.action_reason
		return
	if distance < preferred_range_min and fields.is_empty():
		requested_follow_up_spell = FIRE_FIELD
		_request_attack(intent, HAFT_CHECK, "Create room, then reclaim it with Fire Field")
		return

	light_alternator = not light_alternator
	var light_attack: String = BACKDRAFT_RETURN if light_alternator else CINDER_SWEEP
	if spell_cooldown_remaining <= 0.0 and decision_index % 3 == 2:
		requested_follow_up_spell = FIREBOLT
	_request_attack(intent, light_attack, "Control ideal halberd range")


func _build_combat_movement(
	intent: AvatarActionIntent,
	direction: Vector3,
	distance: float
) -> void:
	if distance > preferred_range_max:
		intent.set_movement(direction, clampf(distance / spell_range, 0.45, 1.0))
		return
	if distance < preferred_range_min:
		intent.set_movement(-direction, 0.62)
		return
	var lateral: Vector3 = Vector3.UP.cross(direction).normalized() * strafe_sign
	intent.set_movement(lateral, 0.32)


func _request_attack(
	intent: AvatarActionIntent,
	attack_id: String,
	reason: String
) -> void:
	intent.attack_id = attack_id
	intent.decision_tag = "combat_form"
	intent.action_reason = reason
	last_decision_reason = reason


func _actor_can_choose_action() -> bool:
	if controlled_actor == null:
		return false
	if controlled_actor.has_method("can_accept_control_action"):
		return bool(controlled_actor.call("can_accept_control_action"))
	return true


func _refresh_target() -> void:
	var owner_target: Node3D = _get_owner_locked_target()
	if _valid_enemy(owner_target):
		current_target = owner_target
		return
	if _valid_enemy(current_target):
		if controlled_actor.global_position.distance_to(
			current_target.global_position
		) <= target_search_range * 1.35:
			return
	current_target = _find_nearest_enemy()


func _get_owner_locked_target() -> Node3D:
	if owner_actor == null or not owner_actor.has_method("has_lock_on_target"):
		return null
	if not bool(owner_actor.call("has_lock_on_target")):
		return null
	var target_value: Variant = owner_actor.get("lock_on_target")
	return target_value as Node3D if target_value is Node3D else null


func _find_nearest_enemy() -> Node3D:
	var best: Node3D
	var best_distance: float = INF
	for candidate_node: Node in get_tree().get_nodes_in_group("enemy"):
		if not candidate_node is Node3D:
			continue
		var candidate: Node3D = candidate_node as Node3D
		if not _valid_enemy(candidate):
			continue
		var distance: float = controlled_actor.global_position.distance_to(
			candidate.global_position
		)
		if distance <= target_search_range and distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _valid_enemy(candidate: Node3D) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if candidate == controlled_actor or candidate == owner_actor:
		return false
	if candidate.is_in_group("friendly_actor") or candidate.is_in_group("player"):
		return false
	if candidate.has_method("is_target_defeated") and bool(
		candidate.call("is_target_defeated")
	):
		return false
	return candidate.is_in_group("enemy")


func _get_owned_fields() -> Array[Node]:
	if controlled_actor == null:
		return []
	var authority: Node = controlled_actor.get_node_or_null(
		"ElementalAuthorityController"
	)
	if authority == null or not authority.has_method("get_owned_fields"):
		return []
	var fields_value: Variant = authority.call("get_owned_fields")
	var fields: Array[Node] = []
	if fields_value is Array:
		for field_value: Variant in fields_value as Array:
			if field_value is Node and is_instance_valid(field_value):
				fields.append(field_value as Node)
	return fields


func _is_position_inside_fields(
	world_position: Vector3,
	fields: Array[Node],
	margin: float
) -> bool:
	for field: Node in fields:
		if field.has_method("contains_world_position") and bool(
			field.call("contains_world_position", world_position, margin)
		):
			return true
	return false


func _target_has_status(target: Node, status_name: String) -> bool:
	var receiver: Node = _find_named_component(target, "StatusReceiver")
	return (
		receiver != null
		and receiver.has_method("has_status")
		and bool(receiver.call("has_status", status_name))
	)


func _count_enemy_cluster(center: Vector3, radius: float) -> int:
	var count: int = 0
	for candidate_node: Node in get_tree().get_nodes_in_group("enemy"):
		if not candidate_node is Node3D:
			continue
		var candidate: Node3D = candidate_node as Node3D
		if not _valid_enemy(candidate):
			continue
		if candidate.global_position.distance_to(center) <= radius:
			count += 1
	return count


func _find_named_component(root: Node, component_name: String) -> Node:
	if root == null:
		return null
	if root.name == component_name:
		return root
	var direct: Node = root.get_node_or_null(component_name)
	if direct != null:
		return direct
	for child: Node in root.get_children():
		var deeper: Node = _find_named_component(child, component_name)
		if deeper != null:
			return deeper
	return null


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		if target.has_method("get_targeting_aim_point"):
			var aim_value: Variant = target.call("get_targeting_aim_point")
			if aim_value is Vector3:
				return aim_value as Vector3
		return (target as Node3D).global_position
	return controlled_actor.global_position


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["target"] = (
		current_target.name
		if current_target != null and is_instance_valid(current_target)
		else "none"
	)
	data["target_distance"] = snappedf(last_target_distance, 0.1)
	data["preferred_range"] = Vector2(preferred_range_min, preferred_range_max)
	data["cluster_count"] = last_cluster_count
	data["owned_fields"] = last_owned_field_count
	data["target_burning"] = last_target_burning
	data["actor_inside_field"] = last_actor_inside_field
	data["target_near_field"] = last_target_near_field
	data["pending_spell"] = pending_spell_id if pending_spell_id != "" else "none"
	data["decision_cooldown"] = snappedf(decision_remaining, 0.01)
	data["spell_cooldown"] = snappedf(spell_cooldown_remaining, 0.01)
	data["dodge_cooldown"] = snappedf(dodge_cooldown_remaining, 0.01)
	data["selected_action"] = last_selected_action
	data["decision_reason"] = last_decision_reason
	return data
