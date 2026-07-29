extends "res://scripts/ui/full_menu_shell_key_items_core.gd"

# Journal and Codex are presentation integrations over the existing quest,
# species-knowledge, and elemental-reaction systems. No second records database.
const RecordsComboRuleRegistryScript = preload(
	"res://scripts/systems/combo_rule_registry.gd"
)


func render_journal() -> void:
	var objective: String = str(GameState.current_objective).strip_edges()
	if objective == "":
		objective = str(menu_data.get("objective", "Look around."))

	var quest_rows: Array = []
	if GameState.has_method("get_quest_rows"):
		quest_rows = GameState.get_quest_rows()

	var active_quests: Array[Dictionary] = []
	var completed_quests: Array[Dictionary] = []
	var failed_quests: Array[Dictionary] = []
	for quest_variant: Variant in quest_rows:
		if not (quest_variant is Dictionary):
			continue
		var quest: Dictionary = (quest_variant as Dictionary).duplicate(true)
		match str(quest.get("state", "active")):
			"completed":
				completed_quests.append(quest)
			"failed":
				failed_quests.append(quest)
			_:
				active_quests.append(quest)

	add_text_card("Current Objective", objective, "📜", "Now")
	add_summary_card([
		"Active " + str(active_quests.size()),
		"Completed " + str(completed_quests.size()),
		"Failed " + str(failed_quests.size()),
	])

	if quest_rows.is_empty():
		add_text_card(
			"No Quests Recorded",
			"Accepted missions, optional goals, and completed stories will collect here.",
			"◇",
			"Journal"
		)
		return

	_records_render_quest_section("ACTIVE QUESTS", active_quests, "active")
	_records_render_quest_section("COMPLETED", completed_quests, "completed")
	_records_render_quest_section("FAILED", failed_quests, "failed")


func render_codex() -> void:
	var species_knowledge: Node = get_node_or_null("/root/SpeciesKnowledge")
	var species_rows: Array = []
	var species_summary: Dictionary = {}
	if species_knowledge != null:
		if species_knowledge.has_method("get_all_species_rows"):
			var rows_value: Variant = species_knowledge.call("get_all_species_rows")
			if rows_value is Array:
				species_rows = rows_value as Array
		if species_knowledge.has_method("get_summary"):
			var summary_value: Variant = species_knowledge.call("get_summary")
			if summary_value is Dictionary:
				species_summary = summary_value as Dictionary

	var reaction_rows: Array[Dictionary] = (
		RecordsComboRuleRegistryScript.get_debug_matrix_rows()
	)
	add_summary_card([
		(
			"Observed species "
			+ str(species_summary.get("species_observed", 0))
			+ "/"
			+ str(species_summary.get("species_total", species_rows.size()))
		),
		"Field notes " + str(species_summary.get("observations", 0)),
		(
			"Capabilities "
			+ str(species_summary.get("unlocks_earned", 0))
			+ "/"
			+ str(species_summary.get("unlocks_total", 0))
		),
		"Reactions " + str(reaction_rows.size()),
	])

	add_section_header("FIELD STUDIES")
	if species_rows.is_empty():
		add_text_card(
			"No Species Registered",
			"Animal observations will appear when a species definition is available.",
			"◇",
			"Codex"
		)
	else:
		for species_variant: Variant in species_rows:
			if species_variant is Dictionary:
				_records_render_species_card(species_variant as Dictionary)

	add_section_header("ELEMENTAL REACTIONS")
	if reaction_rows.is_empty():
		add_text_card(
			"No Reactions Recorded",
			"Authored elemental interactions will appear here.",
			"🧩",
			"Codex"
		)
		return
	for reaction: Dictionary in reaction_rows:
		_records_render_reaction_card(reaction)


func _records_render_quest_section(
	title: String,
	quests: Array[Dictionary],
	state: String
) -> void:
	if quests.is_empty():
		if state == "active":
			add_section_header(title)
			add_text_card(
				"No Active Quests",
				"Grace currently has no accepted mission competing for her attention.",
				"◇",
				"Clear"
			)
		return

	add_section_header(title)
	for quest: Dictionary in quests:
		_records_render_quest_card(quest, state)


func _records_render_quest_card(quest: Dictionary, state: String) -> void:
	var quest_id: String = str(quest.get("id", "quest"))
	var title: String = str(quest.get("title", quest_id.capitalize()))
	var description: String = str(quest.get("description", "")).strip_edges()
	var objective: String = str(quest.get("objective", "")).strip_edges()
	var stages: Array = quest.get("stages", [])
	var stage_index: int = maxi(int(quest.get("stage", 0)), 0)
	var body_parts: Array[String] = []

	if description != "":
		body_parts.append(description)
	if objective != "":
		body_parts.append("Objective: " + objective)
	if state == "active" and not stages.is_empty():
		var resolved_stage: int = clampi(stage_index, 0, stages.size() - 1)
		body_parts.append("Current step: " + str(stages[resolved_stage]))

	var optional_count: int = _records_count_true(
		quest.get("optional_completed", {})
	)
	if optional_count > 0:
		body_parts.append(
			"Optional discoveries completed: " + str(optional_count)
		)
	if body_parts.is_empty():
		body_parts.append("No additional notes have been recorded.")

	var status_label: String = state.to_upper()
	var icon: String = "★"
	match state:
		"completed":
			icon = "✓"
		"failed":
			icon = "✖"
		_:
			icon = "★"

	var progress_label: String = _records_get_quest_progress(
		state,
		stage_index,
		stages.size()
	)
	var subtitle: String = status_label
	if progress_label != "":
		subtitle += "  •  " + progress_label
	add_text_card(
		title,
		"\n".join(body_parts),
		icon,
		subtitle
	)


func _records_get_quest_progress(
	state: String,
	stage_index: int,
	stage_count: int
) -> String:
	if stage_count <= 0:
		return ""
	var completed_steps: int = stage_count if state == "completed" else clampi(
		stage_index + 1,
		1,
		stage_count
	)
	return "Step " + str(completed_steps) + "/" + str(stage_count)


func _records_count_true(value: Variant) -> int:
	if not (value is Dictionary):
		return 0
	var count: int = 0
	for completed_value: Variant in (value as Dictionary).values():
		if bool(completed_value):
			count += 1
	return count


func _records_render_species_card(row: Dictionary) -> void:
	var species_name: String = str(row.get("name", "Unknown Species"))
	var icon: String = str(row.get("icon", "◇"))
	var rank: int = maxi(int(row.get("rank", 0)), 0)
	var maximum_rank: int = maxi(int(row.get("max_rank", 0)), 0)
	var observed: bool = bool(row.get("observed", false))
	var body_parts: Array[String] = [
		str(
			row.get(
				"summary",
				"Field observations will gradually clarify this species."
			)
		)
	]

	if bool(row.get("is_max_rank", false)):
		body_parts.append(
			"Knowledge: "
			+ str(row.get("points", 0))
			+ "  •  Study complete"
		)
	else:
		body_parts.append(
			"Knowledge: "
			+ str(row.get("points", 0))
			+ "/"
			+ str(row.get("next_threshold", 0))
			+ "  •  "
			+ str(row.get("points_to_next", 0))
			+ " to next rank"
		)

	var discoveries: Array[String] = _records_string_array(
		row.get("discovery_labels", [])
	)
	if discoveries.is_empty():
		body_parts.append("Observations: none recorded")
	else:
		body_parts.append("Observations: " + ", ".join(discoveries))

	var unlocks: Array[String] = _records_string_array(
		row.get("unlock_labels", [])
	)
	if unlocks.is_empty():
		body_parts.append("Capabilities: none")
	else:
		body_parts.append("Capabilities: " + ", ".join(unlocks))

	var next_unlock: String = str(row.get("next_unlock_label", "")).strip_edges()
	if next_unlock != "":
		body_parts.append("Next insight: " + next_unlock)

	var subtitle: String = (
		str(row.get("rank_title", "Rank")).to_upper()
		+ "  •  Rank "
		+ str(rank)
		+ "/"
		+ str(maximum_rank)
	)
	if not observed:
		subtitle = "UNOBSERVED  •  " + subtitle
	add_text_card(
		species_name,
		"\n".join(body_parts),
		icon,
		subtitle
	)


func _records_render_reaction_card(row: Dictionary) -> void:
	var reaction_name: String = _records_pretty_token(
		str(row.get("reaction", "reaction"))
	)
	var body_parts: Array[String] = [
		"Trigger: " + _records_pretty_values(row.get("incoming", []))
	]

	var target_tags: String = _records_pretty_values(
		row.get("target_tags", [])
	)
	if target_tags != "None":
		body_parts.append("Target: " + target_tags)

	var target_statuses: String = _records_pretty_values(
		row.get("target_statuses", [])
	)
	if target_statuses != "None":
		body_parts.append("Condition: " + target_statuses)

	var area_radius: float = float(row.get("area_radius", 0.0))
	if area_radius > 0.0:
		body_parts.append(
			"Area: " + str(snappedf(area_radius, 0.1)) + "m"
		)

	add_text_card(
		reaction_name,
		"  •  ".join(body_parts),
		"🧩",
		"Elemental Reaction"
	)


func _records_pretty_values(value: Variant) -> String:
	if not (value is Array):
		return _records_pretty_token(str(value))
	var labels: Array[String] = []
	for raw_value: Variant in (value as Array):
		labels.append(_records_pretty_token(str(raw_value)))
	return "None" if labels.is_empty() else " / ".join(labels)


func _records_pretty_token(value: String) -> String:
	var clean: String = value.strip_edges()
	if clean == "":
		return "None"
	return clean.replace("_", " ").capitalize()


func _records_string_array(value: Variant) -> Array[String]:
	var labels: Array[String] = []
	if not (value is Array):
		return labels
	for raw_value: Variant in (value as Array):
		var label: String = str(raw_value).strip_edges()
		if label != "":
			labels.append(label)
	return labels
