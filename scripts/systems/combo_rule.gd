extends Resource
class_name ComboRule

# Data-only reaction rule for the elemental/material chemistry registry.
# Think of this as one interesting cell in the giant interaction matrix:
# incoming effect tags x target traits -> reaction.

@export var rule_id: String = "combo_rule"
@export var display_name: String = "Combo Rule"
@export_multiline var description: String = ""

# Payload requirements. A payload matches when it has every listed incoming tag.
# Payload element and hit_type also count as tags during matching.
@export var incoming_tags: Array[String] = []

# Target requirements. target_tags can match either TagComponent tags or statuses
# for normal targets. For hazards, target_tags match get_hazard_tags().
@export var target_tags: Array[String] = []
@export var target_statuses: Array[String] = []

# Higher priority rules are listed first in debug views and future conflict resolution.
@export var priority: int = 0

@export var reaction_id: String = "reaction"
@export var reaction_name: String = "Reaction"
@export_multiline var feedback_text: String = "{target} reacts."

# Presentation metadata is deliberately data-driven so combat targets, hazards,
# UI text, and future authored VFX can agree on the same reaction identity.
@export var visual_style: String = "reaction"
@export var visual_color: Color = Color(1.0, 0.58, 0.15, 1.0)
@export var visual_radius: float = 1.25
@export var visual_duration: float = 0.42

# Optional hazard/object behavior hook. This lets a rule trigger a method on the
# matched target, such as trigger_ignite(), trigger_freeze(), or trigger_steam().
# Keep this data string based so the rule registry can stay generic.
@export var target_reaction_method: String = ""
@export var target_reaction_pass_source_position: bool = true

# Status output.
@export var output_status: String = ""
@export var output_status_duration: float = 0.0
@export var output_status_strength: float = 1.0
@export var output_status_source: String = ""
@export var remove_statuses: Array[String] = []

# Damage output. This is applied as a follow-up reaction payload.
@export var output_damage: int = 0
@export var output_stance_damage: int = 0
@export var output_element: String = "neutral"
@export var output_source_name: String = ""
@export var output_hit_type: String = "reaction"
@export var output_tags: Array[String] = ["reaction"]

@export var debug_tags: Array[String] = []
@export_multiline var design_notes: String = ""


func get_summary() -> String:
	return rule_id + " -> " + reaction_id
