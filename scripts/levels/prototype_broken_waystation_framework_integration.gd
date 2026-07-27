extends "res://scripts/levels/prototype_broken_waystation_consequence.gd"
class_name PrototypeBrokenWaystationFrameworkIntegration

const AuthoredQuestRuntimeScript = preload("res://scripts/quests/authored_quest_runtime.gd")
const QuestRewardBundleScript = preload("res://scripts/quests/quest_reward_bundle.gd")
const WorldStateVariantScript = preload("res://scripts/quests/world_state_variant.gd")

var quest_runtime: AuthoredQuestRuntime
var aftermath_variants: WorldStateVariant


func _ready() -> void:
	quest_runtime = AuthoredQuestRuntimeScript.new(QUEST_ID, {
		"title": "The Relay Response",
		"description": "Trace the false eastern reply, secure the abandoned relay, and return its cracked signal prism to Tamsin.",
		"objective": "Follow the blue signal stakes to the abandoned eastern relay.",
		"stage": 0,
		"stages": [
			"Follow the signal trail.",
			"Secure the abandoned eastern relay.",
			"Recover the cracked signal prism.",
			"Return the evidence to Tamsin.",
		],
	})
	aftermath_variants = WorldStateVariantScript.new()
	super._ready()


func build_aftermath_world_state() -> void:
	super.build_aftermath_world_state()
	var repair_camp: Node = get_node_or_null("World/RepairCamp")
	aftermath_variants.register_variant("active", [eastern_gate_closed, repair_camp])
	aftermath_variants.register_variant("secured", [eastern_gate_open, packed_camp, supply_cache])
	aftermath_variants.apply("secured" if GameState.get_flag(FLAG_COMPLETE) else "active")


func start_relay_response_quest() -> void:
	quest_runtime.ensure_started()


func start_remote_encounter() -> void:
	super.start_remote_encounter()
	quest_runtime.set_stage(1, "Secure the abandoned eastern relay.")


func finish_remote_encounter() -> void:
	super.finish_remote_encounter()
	quest_runtime.set_stage(2, "Recover the cracked signal prism.")


func _on_prism_activated(interactable: Node) -> void:
	super._on_prism_activated(interactable)
	quest_runtime.set_stage(3, "Return the cracked signal prism to Tamsin.")


func complete_relay_response_quest() -> void:
	if GameState.get_flag(FLAG_COMPLETE):
		return
	var reward_bundle := QuestRewardBundleScript.new({
		"key_items": [
			{
				"id": CHART_ITEM_ID,
				"data": {
					"name": "Tamsin's Eastern Ridge Chart",
					"kind": "Quest Reward",
					"description": "A waykeeper's chart marking relay posts, shelters, the old survey overlook, and the safest remaining road beyond the ridge.",
					"source": "The Relay Response",
				},
			},
		],
		"mastery": {"sword": 10},
		"flags": [FLAG_COMPLETE],
	})
	reward_bundle.apply()
	quest_runtime.complete("Continue east using Tamsin's annotated ridge chart.")
	apply_completed_aftermath()
	completion_pending = true
	set_objective("The Relay Response complete. Continue east when ready.")


func apply_completed_aftermath() -> void:
	super.apply_completed_aftermath()
	if aftermath_variants != null:
		aftermath_variants.apply("secured")
