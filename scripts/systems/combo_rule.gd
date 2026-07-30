extends Resource
class_name ComboRule

# Data-only reaction rule for the elemental/material chemistry registry.
# Incoming payload identity is matched against a snapshot of the target state
# taken before this impact applies any new direct status.

@export var rule_id: String = "combo_rule"
@export var display_name: String = "Combo Rule"
@export_multiline var description: String = ""

@export_group("Requirements")
# Payload element and hit_type also count as tags.
@export var incoming_tags: Array[String] = []
# At least one of these must match when the list is non-empty.
@export var incoming_any_tags: Array[String] = []

# target_tags may match TagComponent tags or pre-existing statuses for actors.
# For hazards, they match get_hazard_tags().
@export var target_tags: Array[String] = []
@export var target_any_tags: Array[String] = []
@export var target_statuses: Array[String] = []
@export var target_any_statuses: Array[String] = []
@export var required_absent_statuses: Array[String] = []

@export_group("Resolution")
# Higher priority rules resolve first. Ties are broken by rule_id.
@export var priority: int = 0
# Only one rule in an exclusive group may resolve for one target transaction.
@export var exclusive_group: String = ""
@export_range(1, 8, 1) var max_triggers_per_transaction: int = 1
@export_range(0, 8, 1) var maximum_reaction_depth: int = 4
# Whether this rule may be activated by damage produced by another reaction.
@export var allow_reaction_payloads: bool = true
# Whether this rule's own output damage may open another chemistry transaction.
@export var output_triggers_reactions: bool = false
# Stops lower-priority rules after this one resolves.
@export var stop_after_match: bool = false
# Prevents the incoming payload's direct status from being applied afterward.
@export var consume_incoming_status: bool = false

@export_group("Identity")
@export var reaction_id: String = "reaction"
@export var reaction_name: String = "Reaction"
@export_multiline var feedback_text: String = "{target} reacts."

# Presentation metadata is data-driven so combat targets, hazards, UI, and VFX
# agree on one reaction identity.
@export_group("Presentation")
@export var visual_style: String = "reaction"
@export var visual_color: Color = Color(1.0, 0.58, 0.15, 1.0)
@export var visual_radius: float = 1.25
@export var visual_duration: float = 0.42

# Optional behavior hook on the matched target or hazard.
@export_group("Behavior Hook")
@export var target_reaction_method: String = ""
@export var target_reaction_pass_source_position: bool = true

@export_group("Primary Target Output")
@export var output_status: String = ""
@export var output_status_duration: float = 0.0
@export var output_status_strength: float = 1.0
@export var output_status_source: String = ""
@export var remove_statuses: Array[String] = []

@export var output_damage: int = 0
@export var output_stance_damage: int = 0
@export var output_element: String = "neutral"
@export var output_source_name: String = ""
@export var output_hit_type: String = "reaction"
@export var output_tags: Array[String] = ["reaction"]

# Optional radial consequence emitted from the matched target or hazard.
@export_group("Area Effect")
@export var area_effect_radius: float = 0.0
@export var area_output_status: String = ""
@export var area_output_status_duration: float = 0.0
@export var area_output_status_strength: float = 1.0
@export var area_output_status_source: String = ""
@export var area_output_damage: int = 0
@export var area_output_stance_damage: int = 0
@export var area_output_element: String = "neutral"
@export var area_output_tags: Array[String] = ["reaction", "area"]
@export var area_force_strength: float = 0.0
@export var area_force_up_strength: float = 0.0
@export var area_show_status_feedback: bool = true

@export_group("Debug")
@export var debug_tags: Array[String] = []
@export_multiline var design_notes: String = ""


func get_summary() -> String:
	return (
		rule_id
		+ " -> "
		+ reaction_id
		+ " [priority="
		+ str(priority)
		+ "]"
	)


func validate_rule() -> Array[String]:
	var errors: Array[String] = []
	if rule_id.strip_edges() == "":
		errors.append("Reaction rule requires rule_id.")
	if reaction_id.strip_edges() == "":
		errors.append(rule_id + " requires reaction_id.")
	if incoming_tags.is_empty() and incoming_any_tags.is_empty():
		errors.append(rule_id + " has no incoming payload requirement.")
	if (
		target_tags.is_empty()
		and target_any_tags.is_empty()
		and target_statuses.is_empty()
		and target_any_statuses.is_empty()
	):
		errors.append(rule_id + " has no target-state requirement.")
	if max_triggers_per_transaction <= 0:
		errors.append(rule_id + " must allow at least one trigger per transaction.")
	if maximum_reaction_depth < 0:
		errors.append(rule_id + " cannot use a negative reaction depth.")
	return errors
