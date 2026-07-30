extends "res://scripts/avatars/ruvia_manifestation_control_driver.gd"
class_name ReactionAwareRuviaControlDriver


const WorldSnapshot = preload(
	"res://scripts/ai/tactical_world_snapshot.gd"
)
const ActionCandidate = preload(
	"res://scripts/ai/tactical_action_candidate.gd"
)
const Planner = preload(
	"res://scripts/ai/reaction_tactical_planner.gd"
)
const SpellLibrary = preload(
	"res://scripts/ai/tactical_spell_library.gd"
)
const Blackboard = preload(
	"res://scripts/ai/tactical_blackboard.gd"
)
const ClaimRegistry = preload(
	"res://scripts/ai/reaction_claim_registry.gd"
)
const DecisionRecorderScript = preload(
	"res://scripts/ai/tactical_decision_recorder.gd"
)
const RoleAllocator = preload(
	"res://scripts/ai/squad_role_allocator.gd"
)
const RoleCatalog = preload(
	"res://scripts/ai/squad_role_catalog.gd"
)

@export_group("Reaction Coordination")
@export_range(0.0, 20.0, 0.5) var reaction_override_threshold: float = 7.0
@export var reaction_spell_ids: Array[String] = ["firebolt", "fire_field"]
@export var tactical_squad_id: String = "grace_party"
@export_range(0.1, 3.0, 0.05) var reaction_reservation_seconds: float = 1.0
@export_range(0.1, 2.0, 0.05) var owner_intent_seconds: float = 0.65

@export_group("Squad Role")
@export var tactical_squad_role_id: String = "payoff_specialist"

@export_group("Decision Replay")
@export_range(4, 128, 1) var decision_history_capacity: int = 48
@export var record_tactical_decisions: bool = true

var last_reaction_plan: Dictionary = {}
var last_coordination_result: Dictionary = {}
var last_owner_intent_signature: String = ""
var next_owner_intent_refresh_at: float = 0.0
var decision_recorder: TacticalDecisionRecorder
var squad_role_assignment: Dictionary = {}


func _ready() -> void:
	super._ready()
	_ensure_squad_role_assignment()
	_ensure_decision_recorder()
	add_to_group("tactical_decision_source")


func bind_actor(actor: Node3D, owner: Node3D = null) -> void:
	_release_coordination("rebound", false)
	_release_squad_role()
	super.bind_actor(actor, owner)
	last_reaction_plan.clear()
	last_coordination_result.clear()
	last_owner_intent_signature = ""
	next_owner_intent_refresh_at = 0.0
	_ensure_squad_role_assignment()
	_ensure_decision_recorder().clear()


func _build_combat_intent(intent: AvatarActionIntent) -> void:
	_broadcast_owner_intent()
	super._build_combat_intent(intent)
	if not _can_consider_reaction_override(intent):
		return
	var candidates: Array[TacticalActionCandidate] = []
	for record: Dictionary in SpellLibrary.get_records(reaction_spell_ids):
		var candidate: TacticalActionCandidate = ActionCandidate.from_spell_record(
			record
		)
		candidate.base_score = 1.5 if candidate.action_id == "firebolt" else 0.5
		candidate.current_distance = last_target_distance
		candidate.affordable = spell_cooldown_remaining <= 0.0
		candidates.append(candidate)
	if candidates.is_empty():
		return
	var owner_id: int = (
		controlled_actor.get_instance_id()
		if controlled_actor != null
		else get_instance_id()
	)
	var target_id: int = (
		current_target.get_instance_id()
		if current_target != null
		else 0
	)
	var role_assignment: Dictionary = _ensure_squad_role_assignment()
	var coordination: Dictionary = Blackboard.get_coordination_context(
		get_tactical_squad_id(),
		owner_id,
		target_id
	)
	var preferred_tags: Array[String] = _get_owner_selected_spell_tags()
	_append_unique_strings(
		preferred_tags,
		_string_array(coordination.get("squad_intent_tags", []))
	)
	var snapshot: Dictionary = WorldSnapshot.capture(
		controlled_actor,
		current_target,
		{
			"relation": "hostile",
			"ignored_hazard_tags": ["fire", "burning"],
			"preferred_payoff_tags": preferred_tags,
			"claimed_reactions": coordination.get(
				"claimed_reactions",
				[]
			),
		}
	)
	for key: Variant in coordination.keys():
		snapshot[key] = coordination[key]
	snapshot["squad_role_id"] = str(
		role_assignment.get("role_id", "payoff_specialist")
	)
	snapshot["squad_role_name"] = str(
		role_assignment.get("role_name", "Payoff Specialist")
	)
	var role_context: Dictionary = RoleAllocator.get_squad_context(
		get_tactical_squad_id()
	)
	for role_key: Variant in role_context.keys():
		snapshot[role_key] = role_context[role_key]
	var plan: Dictionary = Planner.choose_best(candidates, snapshot)
	last_reaction_plan = _serializable_plan(plan)
	last_coordination_result = {
		"squad_id": get_tactical_squad_id(),
		"owner_id": owner_id,
		"target_id": target_id,
		"squad_role": role_assignment.duplicate(true),
		"role_context": role_context,
		"blackboard": coordination,
		"reservation": "not requested",
	}
	if not Planner.has_meaningful_opportunity(
		plan,
		maxf(reaction_override_threshold, 0.0)
	):
		_record_tactical_frame("decision")
		return
	var selected_spell: String = str(plan.get("selected_id", ""))
	if selected_spell == "":
		_record_tactical_frame("decision")
		return
	var reservation_result: Dictionary = _reserve_plan_opportunity(
		plan,
		selected_spell,
		target_id
	)
	last_coordination_result = {
		"squad_id": get_tactical_squad_id(),
		"owner_id": owner_id,
		"target_id": target_id,
		"selected_spell": selected_spell,
		"squad_role": role_assignment.duplicate(true),
		"role_context": RoleAllocator.get_squad_context(
			get_tactical_squad_id()
		),
		"reservation": reservation_result.duplicate(true),
		"blackboard": Blackboard.get_coordination_context(
			get_tactical_squad_id(),
			0,
			target_id
		),
	}
	if not bool(reservation_result.get("granted", false)):
		_record_tactical_frame("reservation_denied")
		return
	intent.attack_id = ""
	intent.spell_id = selected_spell
	intent.dodge_requested = false
	intent.guard_requested = false
	intent.decision_tag = "reaction_payoff"
	intent.action_reason = str(
		plan.get("reason", "Exploit elemental chemistry")
	)
	tactical_mode = "reaction"
	last_decision_reason = intent.action_reason
	_record_tactical_frame("decision")


func _can_consider_reaction_override(intent: AvatarActionIntent) -> bool:
	if intent == null or controlled_actor == null or current_target == null:
		return false
	if not is_instance_valid(controlled_actor) or not is_instance_valid(current_target):
		return false
	if spell_cooldown_remaining > 0.0:
		return false
	if decision_remaining > 0.0 or post_action_reassessment_remaining > 0.0:
		return false
	if last_target_distance < 0.0 or last_target_distance > spell_range:
		return false
	if intent.recall_requested or intent.dodge_requested or intent.guard_requested:
		return false
	if intent.decision_tag in ["planned_weave", "combat_busy", "reposition"]:
		return false
	return _actor_can_choose_action()


func _broadcast_owner_intent() -> void:
	if owner_actor == null or not is_instance_valid(owner_actor):
		return
	var tags: Array[String] = _get_owner_selected_spell_tags()
	if tags.is_empty():
		return
	tags.sort()
	var target_id: int = (
		current_target.get_instance_id()
		if current_target != null
		else 0
	)
	var signature: String = ",".join(tags) + "@" + str(target_id)
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	if (
		signature == last_owner_intent_signature
		and now_seconds < next_owner_intent_refresh_at
	):
		return
	Blackboard.broadcast_intent(
		get_tactical_squad_id(),
		owner_actor.get_instance_id(),
		owner_actor.name,
		"selected_spell",
		tags,
		target_id,
		owner_intent_seconds,
		{"source": "Grace selected spell"}
	)
	last_owner_intent_signature = signature
	next_owner_intent_refresh_at = (
		now_seconds + maxf(owner_intent_seconds * 0.5, 0.1)
	)


func _reserve_plan_opportunity(
	plan: Dictionary,
	selected_spell: String,
	target_id: int
) -> Dictionary:
	var owner_id: int = (
		controlled_actor.get_instance_id()
		if controlled_actor != null
		else get_instance_id()
	)
	var owner_name: String = (
		controlled_actor.name if controlled_actor != null else name
	)
	var opportunities: Array[Dictionary] = _dictionary_array(
		plan.get("opportunities", [])
	)
	for opportunity: Dictionary in opportunities:
		var type_id: String = str(opportunity.get("type", ""))
		var reaction_id: String = str(
			opportunity.get("reaction_id", "")
		)
		if type_id == "reaction_payoff":
			return ClaimRegistry.reserve_payoff(
				get_tactical_squad_id(),
				owner_id,
				owner_name,
				reaction_id,
				target_id,
				reaction_reservation_seconds,
				float(plan.get("selected_score", 0.0)),
				{
					"spell_id": selected_spell,
					"squad_role": get_tactical_squad_role_id(),
				}
			)
		if type_id == "reaction_setup":
			return ClaimRegistry.reserve_setup(
				get_tactical_squad_id(),
				owner_id,
				owner_name,
				reaction_id,
				target_id,
				reaction_reservation_seconds,
				float(plan.get("selected_score", 0.0)),
				{
					"spell_id": selected_spell,
					"squad_role": get_tactical_squad_role_id(),
				}
			)
	return {
		"granted": false,
		"reason": "No reservable reaction opportunity",
	}


func _get_owner_selected_spell_tags() -> Array[String]:
	var tags: Array[String] = []
	if owner_actor == null:
		return tags
	var caster: Node = owner_actor.get_node_or_null("AbilityCaster")
	if caster == null or not caster.has_method("get_current_ability"):
		return tags
	var ability_value: Variant = caster.call("get_current_ability")
	if not ability_value is AbilityDefinition:
		return tags
	var ability: AbilityDefinition = ability_value as AbilityDefinition
	for tag: String in ability.get_all_spell_tags():
		var normalized: String = tag.strip_edges().to_lower()
		if normalized != "" and not tags.has(normalized):
			tags.append(normalized)
	return tags


func notify_action_result(
	action_kind: String,
	action_id: String,
	success: bool
) -> void:
	super.notify_action_result(action_kind, action_id, success)
	if action_kind == "spell" or not success:
		_release_coordination(
			("spell completed" if success else "action failed")
		)


func _exit_tree() -> void:
	_release_coordination("companion removed")
	_release_squad_role()


func get_tactical_squad_id() -> String:
	var normalized: String = tactical_squad_id.strip_edges().to_lower()
	return normalized if normalized != "" else "grace_party"


func get_tactical_squad_role_id() -> String:
	return str(
		_ensure_squad_role_assignment().get(
			"role_id",
			RoleCatalog.normalize_role_id(tactical_squad_role_id)
		)
	)


func get_tactical_squad_role_name() -> String:
	return str(
		_ensure_squad_role_assignment().get(
			"role_name",
			RoleCatalog.get_profile(tactical_squad_role_id).display_name
		)
	)


func get_tactical_squad_role_assignment() -> Dictionary:
	return _ensure_squad_role_assignment().duplicate(true)


func _ensure_squad_role_assignment() -> Dictionary:
	if not squad_role_assignment.is_empty():
		return squad_role_assignment
	var owner_id: int = (
		controlled_actor.get_instance_id()
		if controlled_actor != null
		else get_instance_id()
	)
	var owner_name: String = (
		controlled_actor.name if controlled_actor != null else name
	)
	var candidates: Array[TacticalActionCandidate] = []
	for record: Dictionary in SpellLibrary.get_records(reaction_spell_ids):
		candidates.append(ActionCandidate.from_spell_record(record))
	squad_role_assignment = RoleAllocator.assign_role(
		get_tactical_squad_id(),
		owner_id,
		owner_name,
		tactical_squad_role_id,
		candidates
	)
	return squad_role_assignment


func _release_squad_role() -> void:
	var owner_id: int = (
		controlled_actor.get_instance_id()
		if controlled_actor != null
		else get_instance_id()
	)
	RoleAllocator.release_owner(owner_id, get_tactical_squad_id())
	squad_role_assignment.clear()


func _release_coordination(reason: String, record_release: bool = true) -> void:
	if controlled_actor == null:
		return
	var owner_id: int = controlled_actor.get_instance_id()
	var target_id: int = (
		current_target.get_instance_id()
		if current_target != null
		else 0
	)
	var released_count: int = Blackboard.release_owner(
		owner_id,
		reason,
		get_tactical_squad_id()
	)
	last_coordination_result = {
		"squad_id": get_tactical_squad_id(),
		"owner_id": owner_id,
		"target_id": target_id,
		"released": released_count,
		"reason": reason,
		"squad_role": squad_role_assignment.duplicate(true),
		"role_context": RoleAllocator.get_squad_context(
			get_tactical_squad_id()
		),
		"blackboard": Blackboard.get_coordination_context(
			get_tactical_squad_id(),
			0,
			target_id
		),
	}
	if record_release:
		_record_tactical_frame("coordination_release")


func _ensure_decision_recorder() -> TacticalDecisionRecorder:
	if decision_recorder == null:
		decision_recorder = DecisionRecorderScript.new().configure(
			decision_history_capacity
		)
	return decision_recorder


func _record_tactical_frame(event_name: String) -> void:
	if not record_tactical_decisions:
		return
	var source_id: int = (
		controlled_actor.get_instance_id()
		if controlled_actor != null
		else get_instance_id()
	)
	var source_name: String = (
		controlled_actor.name if controlled_actor != null else name
	)
	_ensure_decision_recorder().record_frame(
		source_id,
		source_name,
		event_name,
		last_reaction_plan,
		last_coordination_result,
		{
			"tactical_mode": tactical_mode,
			"decision_reason": last_decision_reason,
			"target_distance": last_target_distance,
			"squad_role_id": get_tactical_squad_role_id(),
			"squad_role_name": get_tactical_squad_role_name(),
		}
	)


func get_tactical_decision_recorder() -> TacticalDecisionRecorder:
	return _ensure_decision_recorder()


func get_tactical_decision_timeline() -> Dictionary:
	return _ensure_decision_recorder().to_dictionary()


func _serializable_plan(plan: Dictionary) -> Dictionary:
	var copy: Dictionary = plan.duplicate(true)
	copy.erase("selected_candidate")
	copy.erase("snapshot")
	return copy


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).strip_edges().to_lower()
			if text != "" and not result.has(text):
				result.append(text)
	return result


func _append_unique_strings(
	target: Array[String],
	values: Array[String]
) -> void:
	for value: String in values:
		var normalized: String = value.strip_edges().to_lower()
		if normalized != "" and not target.has(normalized):
			target.append(normalized)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["reaction_plan"] = last_reaction_plan.duplicate(true)
	data["reaction_plan_summary"] = (
		Planner.summarize(last_reaction_plan)
		if not last_reaction_plan.is_empty()
		else "not evaluated"
	)
	data["squad_coordination"] = last_coordination_result.duplicate(true)
	data["squad_id"] = get_tactical_squad_id()
	data["squad_role_id"] = get_tactical_squad_role_id()
	data["squad_role_name"] = get_tactical_squad_role_name()
	data["squad_role_assignment"] = squad_role_assignment.duplicate(true)
	data["squad_role_context"] = RoleAllocator.get_squad_context(
		get_tactical_squad_id()
	)
	data["owner_intent_signature"] = last_owner_intent_signature
	data["decision_replay"] = _ensure_decision_recorder().get_debug_data()
	return data
