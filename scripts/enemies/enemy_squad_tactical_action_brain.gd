extends "res://scripts/enemies/enemy_tactical_action_brain.gd"
class_name EnemySquadTacticalActionBrain


const Blackboard = preload(
	"res://scripts/ai/tactical_blackboard.gd"
)
const ClaimRegistry = preload(
	"res://scripts/ai/reaction_claim_registry.gd"
)
const LaneRegistry = preload(
	"res://scripts/ai/engagement_lane_registry.gd"
)
const ActionCandidate = preload(
	"res://scripts/ai/tactical_action_candidate.gd"
)

@export_group("Squad Coordination")
@export var enable_squad_coordination: bool = true
@export var tactical_squad_id: String = "auto"
@export_range(0.1, 3.0, 0.05) var reaction_reservation_seconds: float = 0.9
@export_range(0.1, 2.0, 0.05) var lane_reservation_seconds: float = 0.55

var last_coordination_result: Dictionary = {}
var coordination_frame: int = -1


func _begin_tactical_evaluation() -> void:
	coordination_frame = -1
	super._begin_tactical_evaluation()


func _ensure_tactical_snapshot() -> void:
	super._ensure_tactical_snapshot()
	if not enable_squad_coordination:
		return
	var frame: int = Engine.get_process_frames()
	if coordination_frame == frame:
		return
	coordination_frame = frame
	var owner_id: int = actor.get_instance_id() if actor != null else get_instance_id()
	var target_id: int = player.get_instance_id() if player != null else 0
	var context: Dictionary = Blackboard.get_coordination_context(
		get_tactical_squad_id(),
		owner_id,
		target_id
	)
	for key: Variant in context.keys():
		tactical_snapshot[key] = context[key]


func _finalize_tactical_decision(option: EnemyActionOption) -> void:
	super._finalize_tactical_decision(option)
	if not enable_squad_coordination:
		last_coordination_result = {"enabled": false}
		return
	if option == null:
		_release_coordination("no selected action")
		last_coordination_result = {
			"enabled": true,
			"reserved": false,
			"reason": "No selected action",
		}
		return
	_reserve_selected_option(option)


func _reserve_selected_option(option: EnemyActionOption) -> void:
	var owner_id: int = actor.get_instance_id() if actor != null else get_instance_id()
	var owner_name: String = actor.name if actor != null else name
	var target_id: int = player.get_instance_id() if player != null else 0
	var selected_value: Variant = last_tactical_decision.get("selected", {})
	var selected: Dictionary = (
		(selected_value as Dictionary).duplicate(true)
		if selected_value is Dictionary
		else {}
	)
	var opportunities: Array[Dictionary] = _dictionary_array(
		selected.get("opportunities", [])
	)
	var result_rows: Array[Dictionary] = []
	var emergency: Dictionary = _first_opportunity(
		opportunities,
		"emergency_override"
	)
	if not emergency.is_empty():
		var emergency_result: Dictionary = Blackboard.reserve_emergency(
			get_tactical_squad_id(),
			owner_id,
			owner_name,
			str(emergency.get("emergency_id", "emergency")),
			0.5,
			100.0,
			{"action": option.get_display_name()}
		)
		result_rows.append(emergency_result)
	else:
		var payoff: Dictionary = _first_opportunity(
			opportunities,
			"reaction_payoff"
		)
		if not payoff.is_empty():
			result_rows.append(
				ClaimRegistry.reserve_payoff(
					get_tactical_squad_id(),
					owner_id,
					owner_name,
					str(payoff.get("reaction_id", "")),
					target_id,
					reaction_reservation_seconds,
					float(selected.get("total_score", 0.0)),
					{"action": option.get_display_name()}
				)
			)
		var setup: Dictionary = _first_opportunity(
			opportunities,
			"reaction_setup"
		)
		if not setup.is_empty():
			result_rows.append(
				ClaimRegistry.reserve_setup(
					get_tactical_squad_id(),
					owner_id,
					owner_name,
					str(setup.get("reaction_id", "")),
					target_id,
					reaction_reservation_seconds,
					float(selected.get("total_score", 0.0)),
					{"action": option.get_display_name()}
				)
			)

	var candidate: TacticalActionCandidate = ActionCandidate.from_enemy_option(option)
	if _candidate_uses_melee_lane(candidate):
		result_rows.append(
			LaneRegistry.reserve_lane(
				get_tactical_squad_id(),
				owner_id,
				owner_name,
				"melee",
				target_id,
				lane_reservation_seconds,
				float(selected.get("total_score", 0.0)),
				{"action": option.get_display_name()}
			)
		)
	last_coordination_result = {
		"enabled": true,
		"squad_id": get_tactical_squad_id(),
		"owner_id": owner_id,
		"target_id": target_id,
		"action": option.get_display_name(),
		"results": result_rows,
		"blackboard": Blackboard.get_coordination_context(
			get_tactical_squad_id(),
			0,
			target_id
		),
	}


func get_tactical_squad_id() -> String:
	var configured: String = tactical_squad_id.strip_edges().to_lower()
	if configured not in ["", "auto"]:
		return configured
	if actor != null and actor.has_meta("tactical_squad_id"):
		var metadata_value: String = str(actor.get_meta("tactical_squad_id"))
		if metadata_value.strip_edges() != "":
			return metadata_value.strip_edges().to_lower()
	if actor != null and actor.get_parent() != null:
		return "enemy_encounter_" + str(actor.get_parent().get_instance_id())
	return "enemy_squad"


func on_action_completed(action: EnemyCombatActionDefinition) -> void:
	super.on_action_completed(action)
	_release_coordination("action completed")


func interrupt_current_action(reason: String) -> bool:
	var interrupted: bool = super.interrupt_current_action(reason)
	if interrupted:
		_release_coordination("interrupted: " + reason)
	return interrupted


func cancel_current_action(reason: String) -> void:
	super.cancel_current_action(reason)
	_release_coordination("cancelled: " + reason)


func finish_action_state() -> void:
	super.finish_action_state()
	_release_coordination("action state finished")


func _exit_tree() -> void:
	_release_coordination("actor removed")


func _release_coordination(reason: String) -> void:
	var owner_id: int = actor.get_instance_id() if actor != null else get_instance_id()
	Blackboard.release_owner(owner_id, reason, get_tactical_squad_id())


func _candidate_uses_melee_lane(candidate: TacticalActionCandidate) -> bool:
	if candidate == null or candidate.action_kind != "attack":
		return false
	if candidate.has_tag("melee") and not candidate.has_tag("projectile"):
		return true
	return candidate.maximum_distance <= 2.5


func _first_opportunity(
	opportunities: Array[Dictionary],
	type_id: String
) -> Dictionary:
	for opportunity: Dictionary in opportunities:
		if str(opportunity.get("type", "")) == type_id:
			return opportunity
	return {}


func get_coordination_debug_data() -> Dictionary:
	return last_coordination_result.duplicate(true)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["squad_coordination"] = last_coordination_result.duplicate(true)
	data["squad_id"] = get_tactical_squad_id()
	return data
