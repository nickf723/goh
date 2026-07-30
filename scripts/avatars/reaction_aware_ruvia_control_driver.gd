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

@export_group("Reaction Coordination")
@export_range(0.0, 20.0, 0.5) var reaction_override_threshold: float = 7.0
@export var reaction_spell_ids: Array[String] = ["firebolt", "fire_field"]
@export var tactical_squad_id: String = "grace_party"
@export_range(0.1, 3.0, 0.05) var reaction_reservation_seconds: float = 1.0
@export_range(0.1, 2.0, 0.05) var owner_intent_seconds: float = 0.65

var last_reaction_plan: Dictionary = {}
var last_coordination_result: Dictionary = {}


func bind_actor(actor: Node3D, owner: Node3D = null) -> void:
	_release_coordination("rebound")
	super.bind_actor(actor, owner)
	last_reaction_plan.clear()
	last_coordination_result.clear()


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
	var plan: Dictionary = Planner.choose_best(candidates, snapshot)
	last_reaction_plan = _serializable_plan(plan)
	if not Planner.has_meaningful_opportunity(
		plan,
		maxf(reaction_override_threshold, 0.0)
	):
		return
	var selected_spell: String = str(plan.get("selected_id", ""))
	if selected_spell == "":
		return
	var reservation_result: Dictionary = _reserve_plan_opportunity(
		plan,
		selected_spell,
		target_id
	)
	last_coordination_result = reservation_result.duplicate(true)
	if not bool(reservation_result.get("granted", false)):
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
	Blackboard.broadcast_intent(
		get_tactical_squad_id(),
		owner_actor.get_instance_id(),
		owner_actor.name,
		"selected_spell",
		tags,
		current_target.get_instance_id() if current_target != null else 0,
		owner_intent_seconds,
		{"source": "Grace selected spell"}
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
				{"spell_id": selected_spell}
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
				{"spell_id": selected_spell}
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


func get_tactical_squad_id() -> String:
	var normalized: String = tactical_squad_id.strip_edges().to_lower()
	return normalized if normalized != "" else "grace_party"


func _release_coordination(reason: String) -> void:
	if controlled_actor == null:
		return
	Blackboard.release_owner(
		controlled_actor.get_instance_id(),
		reason,
		get_tactical_squad_id()
	)


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
	return data
