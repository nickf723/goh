extends "res://scripts/avatars/companion_avatar_control_driver.gd"
class_name RuviaManifestationControlDriver

@export_group("Tactical Cadence")
@export_range(0.05, 1.0, 0.01) var post_action_reassessment_seconds: float = 0.24
@export_range(0.15, 1.5, 0.05) var reposition_duration: float = 0.58
@export_range(1, 6, 1) var attacks_before_reposition: int = 2
@export_range(1, 8, 1) var attacks_before_field_setup: int = 3
@export_range(2, 12, 1) var actions_before_target_switch: int = 5
@export_range(0.25, 5.0, 0.05) var target_switch_cooldown_seconds: float = 1.25
@export_range(0.02, 0.5, 0.01) var failed_action_retry_seconds: float = 0.08

@export_group("Tactical Movement")
@export_range(0.1, 1.0, 0.05) var approach_strength: float = 0.78
@export_range(0.1, 1.0, 0.05) var orbit_strength: float = 0.52
@export_range(0.1, 1.0, 0.05) var retreat_strength: float = 0.72
@export_range(0.0, 2.0, 0.05) var ideal_range_bias: float = 0.2

const RISING_BRAND: String = "ruvia_halberd_l4"
const FURNACE_DROP: String = "ruvia_halberd_h0"
const WILDFIRE_CLEAVE: String = "ruvia_halberd_h3"

var tactical_mode: String = "observe"
var last_movement_plan: String = "idle"
var post_action_reassessment_remaining: float = 0.0
var reposition_remaining: float = 0.0
var target_switch_remaining: float = 0.0
var action_was_busy: bool = false
var reposition_requested: bool = false
var reposition_reason: String = ""
var reposition_style_index: int = 0
var attacks_since_reposition: int = 0
var attacks_since_spell: int = 0
var actions_on_current_target: int = 0
var target_switch_pending: bool = false
var last_target_instance_id: int = 0
var total_repositions: int = 0
var total_target_switches: int = 0
var recent_actions: Array[String] = []
var planned_attack_queue: Array[String] = []


func _ready() -> void:
	super._ready()
	driver_id = "companion_ai"
	display_name = "Ruvia Companion AI"
	add_to_group("ruvia_manifestation_control_driver")


func bind_actor(actor: Node3D, owner: Node3D = null) -> void:
	super.bind_actor(actor, owner)
	tactical_mode = "observe"
	last_movement_plan = "idle"
	post_action_reassessment_remaining = 0.0
	reposition_remaining = 0.0
	target_switch_remaining = 0.0
	action_was_busy = false
	reposition_requested = false
	reposition_reason = ""
	reposition_style_index = 0
	attacks_since_reposition = 0
	attacks_since_spell = 0
	actions_on_current_target = 0
	target_switch_pending = false
	last_target_instance_id = 0
	total_repositions = 0
	total_target_switches = 0
	recent_actions.clear()
	planned_attack_queue.clear()


func notify_action_result(
	action_kind: String,
	action_id: String,
	success: bool
) -> void:
	super.notify_action_result(action_kind, action_id, success)
	if not success:
		decision_remaining = maxf(
			decision_remaining,
			failed_action_retry_seconds
		)
		planned_attack_queue.clear()
		return

	match action_kind:
		"attack":
			attacks_since_reposition += 1
			attacks_since_spell += 1
			actions_on_current_target += 1
			_remember_action(action_id)
			if attacks_since_reposition >= maxi(attacks_before_reposition, 1):
				reposition_requested = true
				reposition_reason = "Break the attack line and reclaim halberd range"
			if actions_on_current_target >= maxi(actions_before_target_switch, 2):
				target_switch_pending = true
		"spell":
			attacks_since_spell = 0
			actions_on_current_target += 1
			planned_attack_queue.clear()
			reposition_requested = true
			reposition_reason = "Move while the Fire pattern develops"
		"dodge":
			attacks_since_reposition = 0
			planned_attack_queue.clear()
			reposition_requested = false
			reposition_reason = ""


func _advance_timers(delta: float) -> void:
	super._advance_timers(delta)
	var step: float = maxf(delta, 0.0)
	post_action_reassessment_remaining = maxf(
		post_action_reassessment_remaining - step,
		0.0
	)
	reposition_remaining = maxf(reposition_remaining - step, 0.0)
	target_switch_remaining = maxf(target_switch_remaining - step, 0.0)


func _build_combat_intent(intent: AvatarActionIntent) -> void:
	var can_choose_action: bool = _actor_can_choose_action()
	if (
		can_choose_action
		and target_switch_pending
		and target_switch_remaining <= 0.0
		and pending_spell_id == ""
	):
		_try_switch_target()

	_sync_target_memory()
	if current_target == null or not is_instance_valid(current_target):
		_build_follow_intent(intent)
		return

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
	last_target_near_field = _is_position_inside_fields(
		target_position,
		fields,
		1.0
	)
	last_target_burning = _target_has_status(current_target, "burning")
	last_cluster_count = _count_enemy_cluster(target_position, 3.4)

	if not can_choose_action:
		action_was_busy = true
		tactical_mode = "committed"
		last_decision_reason = "Complete the current form before choosing again"
		_build_tactical_movement(intent, direction, distance)
		intent.decision_tag = "combat_busy"
		intent.action_reason = last_decision_reason
		return

	# Contextual spell weaves should happen before the normal post-action pause.
	# This preserves the authored attack-to-spell grammar without requiring one
	# perfect input frame from the autonomous driver.
	if pending_spell_id != "" and spell_cooldown_remaining <= 0.0:
		action_was_busy = false
		tactical_mode = "weave"
		intent.spell_id = pending_spell_id
		intent.decision_tag = "planned_weave"
		intent.action_reason = pending_spell_reason
		last_decision_reason = intent.action_reason
		return

	if action_was_busy:
		action_was_busy = false
		post_action_reassessment_remaining = maxf(
			post_action_reassessment_remaining,
			post_action_reassessment_seconds
		)
		if reposition_requested:
			_begin_reposition(
				reposition_reason
				if reposition_reason != ""
				else "Re-establish the engagement"
			)

	_build_tactical_movement(intent, direction, distance)
	if reposition_remaining > 0.0:
		tactical_mode = "reposition"
		intent.decision_tag = "reposition"
		intent.action_reason = last_decision_reason
		return
	if post_action_reassessment_remaining > 0.0:
		tactical_mode = "reassess"
		last_decision_reason = "Read spacing before committing to another form"
		intent.decision_tag = "combat_reassess"
		intent.action_reason = last_decision_reason
		return
	if decision_remaining > 0.0:
		tactical_mode = "measure"
		last_decision_reason = "Measure range while moving"
		intent.decision_tag = "combat_measure"
		intent.action_reason = last_decision_reason
		return

	if distance < 1.15:
		if dodge_cooldown_remaining <= 0.0:
			var side: Vector3 = _get_lateral_direction(direction)
			intent.dodge_requested = true
			intent.dodge_direction = (
				-direction * 0.76 + side * 0.65
			).normalized()
			intent.dodge_kind = "side"
			tactical_mode = "escape"
			intent.decision_tag = "space_dodge"
			intent.action_reason = "Escape inside the halberd head"
			last_decision_reason = intent.action_reason
			return
		_request_attack(
			intent,
			HAFT_CHECK,
			"Use the haft to make immediate room"
		)
		return

	if (
		fields.is_empty()
		and spell_cooldown_remaining <= 0.0
		and distance <= 5.6
		and (
			attacks_since_spell >= maxi(attacks_before_field_setup, 1)
			or last_cluster_count >= 2
		)
	):
		tactical_mode = "field_setup"
		intent.spell_id = FIRE_FIELD
		intent.decision_tag = "field_setup"
		intent.action_reason = "Establish Fire terrain before continuing pressure"
		last_decision_reason = intent.action_reason
		return

	if (
		last_cluster_count >= 3
		and last_target_burning
		and distance <= 4.4
		and not _was_recently_used(SOLAR_DESCENT, 3)
	):
		_request_attack(
			intent,
			SOLAR_DESCENT,
			"Spread Burning through a clustered target"
		)
		return
	if (
		last_target_near_field
		and distance <= 4.8
		and not _was_recently_used(REAPING_HOOK, 2)
	):
		_request_attack(
			intent,
			REAPING_HOOK,
			"Pull the target across an owned Fire Field"
		)
		return
	if (
		last_actor_inside_field
		and distance >= 2.45
		and distance <= 6.2
		and not _was_recently_used(SCORCHING_THRUST, 2)
	):
		_request_attack(
			intent,
			SCORCHING_THRUST,
			"Carry the owned field into a burning wake"
		)
		return
	if fields.size() > 0 and last_cluster_count >= 2 and distance <= 4.8:
		var field_attack: String = (
			WILDFIRE_CLEAVE
			if _was_recently_used(EMBER_WHEEL, 2)
			else EMBER_WHEEL
		)
		_request_attack(
			intent,
			field_attack,
			"Turn the owned field into area control"
		)
		return

	if distance >= 6.1 and distance <= spell_range:
		if spell_cooldown_remaining <= 0.0:
			tactical_mode = "ranged"
			intent.spell_id = FIREBOLT
			intent.decision_tag = "ranged_firebolt"
			intent.action_reason = "Pressure from halberd-tip range"
			last_decision_reason = intent.action_reason
		return
	if distance > preferred_range_max + 0.65:
		tactical_mode = "approach"
		last_decision_reason = "Close to a deliberate halberd range"
		intent.decision_tag = "combat_approach"
		intent.action_reason = last_decision_reason
		return

	if distance < preferred_range_min and fields.is_empty():
		requested_follow_up_spell = FIRE_FIELD
		_request_attack(
			intent,
			HAFT_CHECK,
			"Check the advance, then reclaim space with Fire Field"
		)
		return

	var selected_attack: String = _next_melee_attack(distance, last_cluster_count)
	if selected_attack == "":
		tactical_mode = "measure"
		last_decision_reason = "Hold the angle and wait for a cleaner form"
		intent.decision_tag = "combat_measure"
		intent.action_reason = last_decision_reason
		return

	if (
		selected_attack in [CINDER_SWEEP, BACKDRAFT_RETURN]
		and spell_cooldown_remaining <= 0.0
		and attacks_since_spell >= 1
		and decision_index % 3 == 2
	):
		requested_follow_up_spell = FIREBOLT
	_request_attack(
		intent,
		selected_attack,
		_get_attack_reason(selected_attack)
	)


func _build_tactical_movement(
	intent: AvatarActionIntent,
	direction: Vector3,
	distance: float
) -> void:
	var lateral: Vector3 = _get_lateral_direction(direction)
	var range_middle: float = (
		preferred_range_min + preferred_range_max
	) * 0.5 + ideal_range_bias

	if reposition_remaining > 0.0:
		var reposition_direction: Vector3
		match reposition_style_index % 3:
			0:
				reposition_direction = (
					-direction * 0.72 + lateral * 0.69
				).normalized()
				last_movement_plan = "withdraw_diagonal"
			1:
				reposition_direction = (
					lateral * 0.92 + direction * 0.18
				).normalized()
				last_movement_plan = "wide_orbit"
			_:
				reposition_direction = (
					-direction * 0.38 - lateral * 0.92
				).normalized()
				last_movement_plan = "cross_reset"
		intent.set_movement(reposition_direction, retreat_strength)
		return

	if post_action_reassessment_remaining > 0.0:
		var radial_correction: float = clampf(
			(distance - range_middle) / 2.4,
			-0.38,
			0.38
		)
		var reassess_direction: Vector3 = (
			lateral * 0.86 + direction * radial_correction
		).normalized()
		intent.set_movement(reassess_direction, orbit_strength)
		last_movement_plan = "reassessment_orbit"
		return

	if distance > preferred_range_max:
		intent.set_movement(direction, approach_strength)
		last_movement_plan = "approach"
		return
	if distance < preferred_range_min:
		var retreat_direction: Vector3 = (
			-direction * 0.82 + lateral * 0.42
		).normalized()
		intent.set_movement(retreat_direction, retreat_strength)
		last_movement_plan = "retreat"
		return

	var range_correction: float = clampf(
		(distance - range_middle) / 2.2,
		-0.28,
		0.28
	)
	var orbit_direction: Vector3 = (
		lateral + direction * range_correction
	).normalized()
	intent.set_movement(orbit_direction, orbit_strength)
	last_movement_plan = "orbit"


func _begin_reposition(reason: String) -> void:
	reposition_requested = false
	reposition_reason = ""
	reposition_remaining = maxf(reposition_duration, 0.05)
	attacks_since_reposition = 0
	reposition_style_index = (reposition_style_index + 1) % 3
	total_repositions += 1
	tactical_mode = "reposition"
	last_decision_reason = reason
	planned_attack_queue.clear()


func _next_melee_attack(distance: float, cluster_count: int) -> String:
	if planned_attack_queue.is_empty():
		_build_melee_plan(distance, cluster_count)
	if planned_attack_queue.is_empty():
		return ""
	var selected: String = str(planned_attack_queue.pop_front())
	if selected == last_selected_action and not planned_attack_queue.is_empty():
		planned_attack_queue.append(selected)
		selected = str(planned_attack_queue.pop_front())
	return selected


func _build_melee_plan(distance: float, cluster_count: int) -> void:
	planned_attack_queue.clear()
	if distance < 2.35:
		planned_attack_queue.append(HAFT_CHECK)
		planned_attack_queue.append(RISING_BRAND)
		return
	if cluster_count >= 3:
		planned_attack_queue.append(WILDFIRE_CLEAVE)
		planned_attack_queue.append(EMBER_WHEEL)
		return
	if distance > 3.65:
		planned_attack_queue.append(RISING_BRAND)
		planned_attack_queue.append(CINDER_SWEEP)
		return

	var plan_index: int = (
		decision_index + total_repositions + total_target_switches
	) % 4
	match plan_index:
		0:
			planned_attack_queue.append(CINDER_SWEEP)
			planned_attack_queue.append(BACKDRAFT_RETURN)
		1:
			planned_attack_queue.append(BACKDRAFT_RETURN)
			planned_attack_queue.append(RISING_BRAND)
		2:
			planned_attack_queue.append(FURNACE_DROP)
			planned_attack_queue.append(CINDER_SWEEP)
		_:
			planned_attack_queue.append(CINDER_SWEEP)
			planned_attack_queue.append(
				WILDFIRE_CLEAVE if cluster_count >= 2 else RISING_BRAND
			)


func _get_attack_reason(attack_id: String) -> String:
	match attack_id:
		CINDER_SWEEP:
			return "Sweep the ideal range without overcommitting"
		BACKDRAFT_RETURN:
			return "Reverse the prior line and deny the flank"
		HAFT_CHECK:
			return "Use the shaft when the blade has no room"
		RISING_BRAND:
			return "Lift the target and change the engagement height"
		FURNACE_DROP:
			return "Commit to a planted guard-breaking answer"
		WILDFIRE_CLEAVE:
			return "Cut through the group instead of tunneling one target"
		EMBER_WHEEL:
			return "Rotate through the cluster and flare owned Fire"
		SCORCHING_THRUST:
			return "Drive through established Fire terrain"
		REAPING_HOOK:
			return "Drag the target across the field boundary"
		SOLAR_DESCENT:
			return "Cash out Burning across the cluster"
	return "Choose a halberd form for the current spacing"


func _request_attack(
	intent: AvatarActionIntent,
	attack_id: String,
	reason: String
) -> void:
	tactical_mode = "attack"
	super._request_attack(intent, attack_id, reason)


func _sync_target_memory() -> void:
	var target_id: int = (
		current_target.get_instance_id()
		if current_target != null and is_instance_valid(current_target)
		else 0
	)
	if target_id == last_target_instance_id:
		return
	last_target_instance_id = target_id
	actions_on_current_target = 0
	target_switch_pending = false
	planned_attack_queue.clear()


func _try_switch_target() -> bool:
	if controlled_actor == null or current_target == null:
		target_switch_pending = false
		return false
	var best_target: Node3D
	var best_score: float = INF
	for candidate_node: Node in get_tree().get_nodes_in_group("enemy"):
		if not (candidate_node is Node3D):
			continue
		var candidate: Node3D = candidate_node as Node3D
		if candidate == current_target or candidate.is_queued_for_deletion():
			continue
		if not _valid_enemy(candidate):
			continue
		var actor_distance: float = controlled_actor.global_position.distance_to(
			candidate.global_position
		)
		if actor_distance > target_search_range:
			continue
		var owner_distance: float = (
			owner_actor.global_position.distance_to(candidate.global_position)
			if owner_actor != null and is_instance_valid(owner_actor)
			else 0.0
		)
		var score: float = actor_distance + owner_distance * 0.12
		if score < best_score:
			best_score = score
			best_target = candidate

	target_switch_pending = false
	actions_on_current_target = 0
	if best_target == null:
		return false
	current_target = best_target
	last_target_instance_id = best_target.get_instance_id()
	target_switch_remaining = maxf(target_switch_cooldown_seconds, 0.05)
	total_target_switches += 1
	_begin_reposition("Shift pressure to a different threat")
	return true


func _get_lateral_direction(direction: Vector3) -> Vector3:
	var planar: Vector3 = direction
	planar.y = 0.0
	if planar.length_squared() <= 0.0001:
		planar = -controlled_actor.global_transform.basis.z
		planar.y = 0.0
	if planar.length_squared() <= 0.0001:
		planar = Vector3.FORWARD
	return Vector3.UP.cross(planar.normalized()).normalized() * strafe_sign


func _remember_action(action_id: String) -> void:
	if action_id == "":
		return
	recent_actions.append(action_id)
	while recent_actions.size() > 5:
		recent_actions.pop_front()


func _was_recently_used(action_id: String, lookback: int) -> bool:
	if action_id == "" or recent_actions.is_empty():
		return false
	var count: int = mini(maxi(lookback, 1), recent_actions.size())
	for offset: int in range(count):
		var index: int = recent_actions.size() - 1 - offset
		if recent_actions[index] == action_id:
			return true
	return false


func _get_owned_fields() -> Array[Node]:
	var fields: Array[Node] = []
	if controlled_actor == null:
		return fields
	var authority: Node = controlled_actor.get_node_or_null(
		"ElementalAuthorityController"
	)
	if authority == null or not authority.has_method("get_owned_fields"):
		return fields
	var fields_value: Variant = authority.call("get_owned_fields")
	if not (fields_value is Array):
		return fields
	var raw_fields: Array = fields_value as Array
	for field_value: Variant in raw_fields:
		if (
			field_value is Node
			and is_instance_valid(field_value)
			and not (field_value as Node).is_queued_for_deletion()
		):
			fields.append(field_value as Node)
	return fields


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["failed_action_retry"] = failed_action_retry_seconds
	data["avatar_specialist"] = "ruvia"
	data["tactical_mode"] = tactical_mode
	data["movement_plan"] = last_movement_plan
	data["post_action_reassessment"] = snappedf(
		post_action_reassessment_remaining,
		0.01
	)
	data["reposition_remaining"] = snappedf(reposition_remaining, 0.01)
	data["reposition_requested"] = reposition_requested
	data["attacks_since_reposition"] = attacks_since_reposition
	data["attacks_since_spell"] = attacks_since_spell
	data["actions_on_target"] = actions_on_current_target
	data["target_switch_pending"] = target_switch_pending
	data["target_switch_cooldown"] = snappedf(target_switch_remaining, 0.01)
	data["total_repositions"] = total_repositions
	data["total_target_switches"] = total_target_switches
	data["recent_actions"] = recent_actions.duplicate()
	data["planned_attacks"] = planned_attack_queue.duplicate()
	return data
