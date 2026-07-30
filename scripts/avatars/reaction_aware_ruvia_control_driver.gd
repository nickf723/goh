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

@export_group("Reaction Coordination")
@export_range(0.0, 20.0, 0.5) var reaction_override_threshold: float = 7.0
@export var reaction_spell_ids: Array[String] = [FIREBOLT, FIRE_FIELD]

var last_reaction_plan: Dictionary = {}


func _build_combat_intent(intent: AvatarActionIntent) -> void:
	super._build_combat_intent(intent)
	if not _can_consider_reaction_override(intent):
		return
	var candidates: Array[TacticalActionCandidate] = []
	for record: Dictionary in SpellLibrary.get_records(reaction_spell_ids):
		var candidate: TacticalActionCandidate = ActionCandidate.from_spell_record(record)
		candidate.base_score = 1.5 if candidate.action_id == FIREBOLT else 0.5
		candidate.current_distance = last_target_distance
		candidate.affordable = spell_cooldown_remaining <= 0.0
		candidates.append(candidate)
	if candidates.is_empty():
		return
	var snapshot: Dictionary = WorldSnapshot.capture(
		controlled_actor,
		current_target,
		{
			"relation": "hostile",
			"ignored_hazard_tags": ["fire", "burning"],
			"preferred_payoff_tags": _get_owner_selected_spell_tags(),
		}
	)
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
	intent.attack_id = ""
	intent.spell_id = selected_spell
	intent.dodge_requested = false
	intent.guard_requested = false
	intent.decision_tag = "reaction_payoff"
	intent.action_reason = str(plan.get("reason", "Exploit elemental chemistry"))
	tactical_mode = "reaction"
	last_decision_reason = intent.action_reason


func _can_consider_reaction_override(intent: AvatarActionIntent) -> bool:
	if intent == null or controlled_actor == null or current_target == null:
		return false
	if not is_instance_valid(controlled_actor) or not is_instance_valid(current_target):
		return false
	if spell_cooldown_remaining > 0.0:
		return false
	if last_target_distance < 0.0 or last_target_distance > spell_range:
		return false
	if intent.recall_requested or intent.dodge_requested or intent.guard_requested:
		return false
	if intent.decision_tag in ["planned_weave", "combat_busy", "reposition"]:
		return false
	return _actor_can_choose_action()


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


func _serializable_plan(plan: Dictionary) -> Dictionary:
	var copy: Dictionary = plan.duplicate(true)
	copy.erase("selected_candidate")
	copy.erase("snapshot")
	return copy


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["reaction_plan"] = last_reaction_plan.duplicate(true)
	data["reaction_plan_summary"] = (
		Planner.summarize(last_reaction_plan)
		if not last_reaction_plan.is_empty()
		else "not evaluated"
	)
	return data
