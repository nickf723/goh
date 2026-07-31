extends "res://scripts/enemies/enemy_threat_aware_action_brain.gd"


const TargetCandidate = preload(
	"res://scripts/ai/tactical_target_candidate.gd"
)
const TargetAllocator = preload(
	"res://scripts/ai/target_allocation_blackboard.gd"
)
const TargetEvaluator = preload(
	"res://scripts/ai/role_aware_target_evaluator.gd"
)

@export_group("Storm Drain Pack")
@export_range(1.0, 20.0, 0.25) var guard_support_radius: float = 8.0
@export_range(0, 10, 1) var guard_stance_restore: int = 2
@export_range(0.1, 10.0, 0.1) var guard_status_duration: float = 1.8
@export_range(0.0, 10.0, 0.25) var guard_need_score_per_stance: float = 1.8
@export_range(0.0, 20.0, 0.5) var guard_full_stance_penalty: float = 10.0

@export_group("Encounter Activation")
@export var force_encounter_engagement: bool = true
@export_range(5.0, 60.0, 0.5) var encounter_join_radius: float = 32.0

@export_group("Target Allocation")
@export var enable_multi_target_allocation: bool = true
@export_range(0.05, 1.0, 0.01) var target_decision_interval: float = 0.18
@export_range(0.1, 3.0, 0.05) var target_claim_duration: float = 0.9
@export_range(0.0, 40.0, 0.5) var target_overkill_penalty: float = 18.0
@export_range(0.0, 10.0, 0.25) var target_attention_penalty: float = 1.7
@export var authored_focus_fire_target_id: int = 0
@export var targetable_groups: Array[String] = ["enemy_targetable"]

var encounter_player: Node3D = null
var allocated_target: Node3D = null
var target_decision_timer: float = 0.0
var last_target_decision: Dictionary = {}
var target_evaluation_count: int = 0
var target_switch_count: int = 0


func _ready() -> void:
	super._ready()
	if actor != null:
		actor.add_to_group("storm_drain_pack_member")
	_resolve_encounter_player()
	_refresh_target_allocation(true)
	if force_encounter_engagement and player != null:
		change_state(EnemyState.CHASE)


func update_timers(delta: float) -> void:
	super.update_timers(delta)
	target_decision_timer = maxf(target_decision_timer - maxf(delta, 0.0), 0.0)


func process_idle(delta: float) -> void:
	_resolve_encounter_player()
	_refresh_target_allocation(false)
	if (
		force_encounter_engagement
		and player != null
		and is_instance_valid(player)
		and get_distance_to_player() <= encounter_join_radius
	):
		change_state(EnemyState.CHASE)
		return
	super.process_idle(delta)


func process_chase(delta: float) -> void:
	_resolve_encounter_player()
	_refresh_target_allocation(false)
	if force_encounter_engagement and player != null and is_instance_valid(player):
		var distance: float = get_distance_to_player()
		var ordinary_lose_radius: float = get_definition().get_lose_interest_radius()
		if distance > ordinary_lose_radius and distance <= encounter_join_radius:
			reset_attack_commit()
			move_toward_player(delta)
			last_action_summary = "joining Storm Drain encounter"
			return
	super.process_chase(delta)


func _resolve_encounter_player() -> void:
	if encounter_player != null and is_instance_valid(encounter_player):
		if not encounter_player.is_in_group(player_group):
			encounter_player.add_to_group(player_group)
	else:
		encounter_player = null
		var found_player: Node = get_tree().get_first_node_in_group(player_group)
		if found_player is Node3D:
			encounter_player = found_player as Node3D
		if encounter_player == null:
			var scene_root: Node = get_tree().current_scene
			if scene_root != null:
				var candidate: Node = scene_root.get_node_or_null("Player")
				if candidate == null:
					candidate = scene_root.find_child("Player", true, false)
				if candidate is Node3D:
					encounter_player = candidate as Node3D
		if encounter_player != null and not encounter_player.is_in_group(player_group):
			encounter_player.add_to_group(player_group)
	if player == null or not is_instance_valid(player):
		player = encounter_player


func _refresh_target_allocation(force: bool = false) -> void:
	if not enable_multi_target_allocation:
		if encounter_player != null and is_instance_valid(encounter_player):
			player = encounter_player
		return
	if has_running_action():
		return
	if (
		not force
		and target_decision_timer > 0.0
		and _is_valid_target(allocated_target)
	):
		player = allocated_target
		return
	var candidates: Array[Dictionary] = _collect_target_candidates()
	if candidates.is_empty():
		allocated_target = encounter_player
		player = encounter_player
		last_target_decision = {
			"selected_name": "none",
			"reason": "No valid combat targets",
			"trace": [],
		}
		return
	var contexts: Dictionary = {}
	for candidate: Dictionary in candidates:
		var target_id: int = int(candidate.get("target_id", 0))
		contexts[target_id] = TargetAllocator.get_target_context(
			get_tactical_squad_id(),
			target_id,
			_get_owner_id()
		)
	var role_id: String = get_tactical_squad_role_id()
	var plan: Dictionary = TargetEvaluator.choose_best(
		candidates,
		contexts,
		role_id,
		{
			"preferred_distance": get_definition().get_preferred_distance(),
			"distance_span": encounter_join_radius,
			"overkill_penalty": target_overkill_penalty,
			"attention_penalty": target_attention_penalty,
			"focus_fire_target_id": authored_focus_fire_target_id,
			"focus_fire_bonus": 100.0,
		}
	)
	target_evaluation_count += 1
	var selected_value: Variant = plan.get("selected", {})
	var selected: Dictionary = (
		selected_value as Dictionary
		if selected_value is Dictionary
		else {}
	)
	var target_value: Variant = selected.get("target_ref")
	var next_target: Node3D = (
		target_value as Node3D
		if target_value is Node3D and is_instance_valid(target_value)
		else encounter_player
	)
	var switched: bool = next_target != allocated_target
	allocated_target = next_target
	player = allocated_target
	if switched:
		target_switch_count += 1
		invalidate_tactical_decision_cache()
	TargetAllocator.release_owner(
		_get_owner_id(),
		get_tactical_squad_id(),
		"attention",
		"target reconsidered"
	)
	if _is_valid_target(allocated_target):
		TargetAllocator.claim_target(
			get_tactical_squad_id(),
			_get_owner_id(),
			actor.name if actor != null else name,
			allocated_target.get_instance_id(),
			_target_name(allocated_target),
			"attention",
			0.0,
			[],
			target_decision_interval + target_claim_duration * 0.25,
			float(selected.get("target_score", 0.0)),
			{"role": role_id}
		)
	last_target_decision = {
		"selected_id": int(plan.get("selected_id", 0)),
		"selected_name": str(plan.get("selected_name", "none")),
		"selected_score": float(plan.get("selected_score", -INF)),
		"reason": str(plan.get("reason", "No target reason")),
		"selected": TargetCandidate.sanitize(selected),
		"trace": plan.get("trace", []),
		"squad_context": TargetAllocator.get_squad_context(
			get_tactical_squad_id()
		),
	}
	target_decision_timer = (
		maxf(target_decision_interval, 0.05)
		+ _target_stagger_seconds()
	)


func _collect_target_candidates() -> Array[Dictionary]:
	var targets: Array[Node3D] = []
	if _is_valid_target(encounter_player):
		targets.append(encounter_player)
	for group_name: String in targetable_groups:
		if group_name.strip_edges() == "":
			continue
		for value: Variant in get_tree().get_nodes_in_group(group_name):
			if not value is Node3D:
				continue
			var target: Node3D = value as Node3D
			if target == actor or target.is_in_group("enemy"):
				continue
			if not targets.has(target):
				targets.append(target)
	var candidates: Array[Dictionary] = []
	for target: Node3D in targets:
		if not _is_valid_target(target):
			if target != null and is_instance_valid(target):
				TargetAllocator.release_target(
					target.get_instance_id(),
					get_tactical_squad_id(),
					"target defeated"
				)
			continue
		if actor != null and actor.global_position.distance_to(target.global_position) > encounter_join_radius:
			continue
		var candidate: Dictionary = TargetCandidate.capture(actor, target)
		if not candidate.is_empty():
			candidates.append(candidate)
	return candidates


func _is_valid_target(target: Node3D) -> bool:
	return (
		target != null
		and is_instance_valid(target)
		and not target.is_queued_for_deletion()
		and not TargetCandidate.is_defeated(target)
	)


func _target_stagger_seconds() -> float:
	if actor == null or target_decision_interval <= 0.0:
		return 0.0
	return float(actor.get_instance_id() % 5) * 0.012


func _finalize_tactical_decision(option) -> void:
	super._finalize_tactical_decision(option)
	var claim_result: Dictionary = _reserve_current_target_for_option(option)
	last_tactical_decision["target_id"] = get_current_allocated_target_id()
	last_tactical_decision["target_name"] = get_current_allocated_target_name()
	last_tactical_decision["target_selection"] = last_target_decision.duplicate(true)
	last_tactical_decision["target_claim"] = claim_result.duplicate(true)
	last_coordination_result["target_allocation"] = TargetAllocator.get_squad_context(
		get_tactical_squad_id()
	)
	_record_tactical_frame("target_decision")


func _reserve_current_target_for_option(option) -> Dictionary:
	if option == null or not _is_valid_target(allocated_target):
		return {}
	var action_value: Variant = option.call("get_action") if option.has_method("get_action") else null
	if not action_value is Resource:
		return {}
	var action: Resource = action_value as Resource
	var claim_kind: String = "attention"
	var expected_damage: float = 0.0
	var control_tags: Array[String] = []
	var role_id: String = get_tactical_squad_role_id()
	if action is EnemyAttackDefinition:
		var payload: DamagePayload = (action as EnemyAttackDefinition).get_payload()
		if payload != null:
			expected_damage = float(maxi(payload.amount, 0)) + float(maxi(payload.stance_damage, 0)) * 0.45
			if payload.status_effect != "":
				control_tags.append(payload.status_effect)
			if payload.element == "lightning" and role_id == "payoff_specialist":
				claim_kind = "payoff"
			elif payload.status_effect != "" and role_id == "primer":
				claim_kind = "setup"
			elif payload.status_effect != "":
				claim_kind = "control"
			elif payload.tags.has("melee") or action.get_role_tags().has("melee"):
				claim_kind = "melee"
			else:
				claim_kind = "damage"
	elif action.get_action_kind() == "defense":
		claim_kind = "attention"
	TargetAllocator.release_owner(
		_get_owner_id(),
		get_tactical_squad_id(),
		"attention",
		"action claim replaces attention"
	)
	return TargetAllocator.claim_target(
		get_tactical_squad_id(),
		_get_owner_id(),
		actor.name if actor != null else name,
		allocated_target.get_instance_id(),
		_target_name(allocated_target),
		claim_kind,
		expected_damage,
		control_tags,
		target_claim_duration,
		float(last_tactical_decision.get("selected_score", 0.0)),
		{
			"action": option.call("get_display_name") if option.has_method("get_display_name") else "Action",
			"role": role_id,
		}
	)


func score_action_option(option: EnemyActionOption, distance: float) -> float:
	var score: float = super.score_action_option(option, distance)
	if option == null or option.get_action() == null:
		return score
	if option.get_action().get_action_id() != "storm_drain_guard_screech":
		return score
	var missing_stance: int = get_nearby_missing_stance()
	if missing_stance <= 0:
		return score - maxf(guard_full_stance_penalty, 0.0)
	return score + float(missing_stance) * maxf(guard_need_score_per_stance, 0.0)


func process_active_action(action: EnemyCombatActionDefinition) -> void:
	if action == null:
		return
	if _is_projectile_attack(action):
		_perform_projectile_attack(action)
		return
	if action.get_action_id() == "storm_drain_guard_screech":
		_perform_guard_screech(action)
		return
	super.process_active_action(action)


func _is_projectile_attack(action: EnemyCombatActionDefinition) -> bool:
	return (
		action is EnemyAttackDefinition
		and action.has_method("is_projectile_delivery")
		and bool(action.call("is_projectile_delivery"))
	)


func _perform_projectile_attack(action: EnemyCombatActionDefinition) -> void:
	if actor == null or action_runner == null or action_runner.hit_registered:
		return
	var scene_value: Variant = action.call("get_projectile_scene")
	if not scene_value is PackedScene:
		action_runner.mark_hit_registered()
		last_action_summary = action.get_display_name() + " has no projectile scene"
		return
	var projectile_value: Variant = (scene_value as PackedScene).instantiate()
	if not projectile_value is Node3D:
		action_runner.mark_hit_registered()
		last_action_summary = action.get_display_name() + " projectile is invalid"
		return
	var projectile: Node3D = projectile_value as Node3D
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = actor.get_parent()
	if scene_root == null:
		projectile.queue_free()
		return
	scene_root.add_child(projectile)
	var direction: Vector3 = action_runner.get_locked_target_direction()
	direction.y = 0.0
	if direction.length() <= 0.01:
		direction = -actor.global_transform.basis.z
	else:
		direction = direction.normalized()
	var spawn_height: float = float(action.call("get_projectile_spawn_height"))
	var spawn_distance: float = float(action.call("get_projectile_spawn_distance"))
	projectile.global_position = (
		actor.global_position
		+ Vector3.UP * spawn_height
		+ direction * spawn_distance
	)
	if projectile.has_method("set_source_actor"):
		projectile.call("set_source_actor", actor)
	if action is EnemyAttackDefinition and projectile.has_method("set_payload"):
		projectile.call("set_payload", (action as EnemyAttackDefinition).get_payload())
	projectile.set("speed", float(action.call("get_projectile_speed")))
	if projectile.has_method("launch"):
		projectile.call("launch", direction)
	action_runner.mark_hit_registered()
	last_action_summary = "launched: " + action.get_display_name()


func apply_attack_to_player(payload: DamagePayload) -> void:
	if payload == null or player == null or not is_instance_valid(player):
		return
	if player == encounter_player or player.is_in_group("player"):
		super.apply_attack_to_player(payload)
		return
	var result: Dictionary = {}
	if player.has_method("receive_damage_payload"):
		var value: Variant = player.call("receive_damage_payload", payload)
		if value is Dictionary:
			result = value as Dictionary
	else:
		var payload_receiver: Node = player.get_node_or_null("PayloadReceiver")
		if payload_receiver != null and payload_receiver.has_method("receive_payload"):
			var receiver_value: Variant = payload_receiver.call("receive_payload", payload)
			if receiver_value is Dictionary:
				result = receiver_value as Dictionary
	last_action_summary = "hit: " + payload.source_name + " → " + _target_name(player)
	var message: String = str(result.get("message", ""))
	if message != "":
		show_message(message)
	if not _is_valid_target(player):
		TargetAllocator.release_target(
			player.get_instance_id() if is_instance_valid(player) else 0,
			get_tactical_squad_id(),
			"target defeated"
		)
		allocated_target = null
		player = encounter_player
		target_decision_timer = 0.0
		invalidate_tactical_decision_cache()


func _perform_guard_screech(action: EnemyCombatActionDefinition) -> void:
	if actor == null or action_runner == null or action_runner.hit_registered:
		return
	var affected: int = 0
	for ally_value: Variant in get_tree().get_nodes_in_group("storm_drain_pack_member"):
		if not ally_value is Node3D:
			continue
		var ally: Node3D = ally_value as Node3D
		if not is_instance_valid(ally):
			continue
		if actor.global_position.distance_to(ally.global_position) > guard_support_radius:
			continue
		if _restore_ally_stance(ally):
			affected += 1
		_apply_guard_status(ally)
	action_runner.mark_hit_registered()
	last_action_summary = (
		"support: " + action.get_display_name()
		+ " protected " + str(affected) + " pack member"
		+ ("s" if affected != 1 else "")
	)


func get_nearby_missing_stance() -> int:
	if actor == null:
		return 0
	var missing_stance: int = 0
	for ally_value: Variant in get_tree().get_nodes_in_group("storm_drain_pack_member"):
		if not ally_value is Node3D:
			continue
		var ally: Node3D = ally_value as Node3D
		if not is_instance_valid(ally):
			continue
		if actor.global_position.distance_to(ally.global_position) > guard_support_radius:
			continue
		var hit_receiver: Node = ally.get_node_or_null("HitReceiver")
		if hit_receiver == null:
			continue
		var current: int = int(hit_receiver.get("current_stance"))
		var maximum: int = int(hit_receiver.get("max_stance"))
		missing_stance += maxi(maximum - current, 0)
	return missing_stance


func _restore_ally_stance(ally: Node) -> bool:
	var hit_receiver: Node = ally.get_node_or_null("HitReceiver")
	if hit_receiver == null:
		return false
	var current: int = int(hit_receiver.get("current_stance"))
	var maximum: int = int(hit_receiver.get("max_stance"))
	if maximum <= 0 or current >= maximum:
		return false
	var restored: int = mini(current + maxi(guard_stance_restore, 0), maximum)
	hit_receiver.set("current_stance", restored)
	if hit_receiver.has_signal("stance_changed"):
		hit_receiver.emit_signal("stance_changed", restored, maximum)
	if hit_receiver.has_method("refresh_overhead_hud"):
		hit_receiver.call("refresh_overhead_hud")
	return restored > current


func _apply_guard_status(ally: Node) -> void:
	var status_receiver: Node = ally.get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_method("apply_status"):
		status_receiver.call(
			"apply_status",
			"guarded",
			guard_status_duration,
			1.0,
			"Guard Screech"
		)


func on_action_completed(action) -> void:
	super.on_action_completed(action)
	_release_target_claims("action completed")


func interrupt_current_action(reason: String) -> bool:
	var interrupted: bool = super.interrupt_current_action(reason)
	if interrupted:
		_release_target_claims("interrupted: " + reason)
	return interrupted


func cancel_current_action(reason: String) -> void:
	super.cancel_current_action(reason)
	_release_target_claims("cancelled: " + reason)


func finish_action_state() -> void:
	super.finish_action_state()
	target_decision_timer = 0.0


func _release_target_claims(reason: String) -> void:
	TargetAllocator.release_owner(
		_get_owner_id(),
		get_tactical_squad_id(),
		"",
		reason
	)
	target_decision_timer = 0.0


func _exit_tree() -> void:
	_release_target_claims("actor removed")
	super._exit_tree()


func get_current_allocated_target_id() -> int:
	return allocated_target.get_instance_id() if _is_valid_target(allocated_target) else 0


func get_current_allocated_target_name() -> String:
	return _target_name(allocated_target) if _is_valid_target(allocated_target) else "none"


func _target_name(target: Node) -> String:
	if target == null or not is_instance_valid(target):
		return "none"
	if target.has_meta("active_avatar_display_name"):
		var metadata_name: String = str(target.get_meta("active_avatar_display_name"))
		if metadata_name != "":
			return metadata_name
	return str(target.name)


func get_target_allocation_debug_data() -> Dictionary:
	return {
		"current_target_id": get_current_allocated_target_id(),
		"current_target_name": get_current_allocated_target_name(),
		"decision": last_target_decision.duplicate(true),
		"squad": TargetAllocator.get_squad_context(get_tactical_squad_id()),
		"evaluations": target_evaluation_count,
		"switches": target_switch_count,
	}


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["storm_drain_pack"] = true
	data["guard_support_radius"] = guard_support_radius
	data["guard_stance_restore"] = guard_stance_restore
	data["guard_missing_stance"] = get_nearby_missing_stance()
	data["encounter_target_resolved"] = player != null and is_instance_valid(player)
	data["encounter_join_radius"] = encounter_join_radius
	data["target_allocation"] = get_target_allocation_debug_data()
	return data
