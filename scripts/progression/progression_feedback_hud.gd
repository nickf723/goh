extends CanvasLayer
class_name ProgressionFeedbackHUD

const ChallengeCatalogScript = preload(
	"res://scripts/progression/progression_challenge_catalog.gd"
)

const MAX_TOASTS: int = 3
const DEFAULT_TOAST_DURATION: float = 2.8
const MAJOR_TOAST_DURATION: float = 4.2
const TOAST_FADE_DURATION: float = 0.38
const INITIAL_SUPPRESSION_MSEC: int = 900

const COLOR_BY_KIND: Dictionary = {
	"challenge": Color(1.0, 0.72, 0.2, 1.0),
	"discovery": Color(0.3, 0.84, 1.0, 1.0),
	"achievement": Color(0.84, 0.52, 1.0, 1.0),
	"mastery": Color(0.38, 0.94, 0.58, 1.0),
	"quest": Color(1.0, 0.86, 0.4, 1.0),
	"creature": Color(0.44, 0.92, 0.76, 1.0),
	"unlock": Color(1.0, 0.58, 0.18, 1.0),
	"level": Color(1.0, 0.78, 0.24, 1.0),
	"tracked": Color(0.42, 0.72, 1.0, 1.0),
}

var tracker: Node
var root: Control
var tracked_panel: PanelContainer
var tracked_kind_label: Label
var tracked_title_label: Label
var tracked_detail_label: Label
var tracked_progress_bar: ProgressBar
var tracked_progress_label: Label
var toast_stack: VBoxContainer
var toast_entries: Array[Dictionary] = []
var refresh_remaining: float = 0.0
var suppress_until_msec: int = 0
var last_species_ranks: Dictionary = {}
var last_quest_stages: Dictionary = {}


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("progression_feedback_hud")
	_build_hud()
	_connect_game_state()
	suppress_until_msec = Time.get_ticks_msec() + INITIAL_SUPPRESSION_MSEC
	call_deferred("_bind_available_sources")


func _process(delta: float) -> void:
	_update_context_visibility()
	refresh_remaining = maxf(refresh_remaining - maxf(delta, 0.0), 0.0)
	if refresh_remaining <= 0.0:
		refresh_remaining = 0.12
		refresh_tracked_progress()
	_update_toasts(maxf(delta, 0.0))


func bind_tracker(value: Node) -> void:
	if value == tracker:
		return
	_disconnect_tracker()
	tracker = value
	_connect_tracker()
	refresh_tracked_progress()


func push_feedback(
	kind: String,
	title: String,
	body: String,
	dedupe_key: String = "",
	current: int = -1,
	target: int = -1,
	major: bool = false
) -> void:
	var resolved_title: String = title.strip_edges()
	if resolved_title == "":
		return
	var resolved_kind: String = kind.strip_edges().to_lower()
	if resolved_kind == "":
		resolved_kind = "tracked"
	var resolved_key: String = dedupe_key.strip_edges()
	if resolved_key == "":
		resolved_key = resolved_kind + ":" + resolved_title.to_lower().replace(" ", "_")
	var data: Dictionary = {
		"kind": resolved_kind,
		"title": resolved_title,
		"body": body.strip_edges(),
		"dedupe_key": resolved_key,
		"current": current,
		"target": target,
		"major": major,
		"duration": MAJOR_TOAST_DURATION if major else DEFAULT_TOAST_DURATION,
	}
	var existing_index: int = _find_toast_index(resolved_key)
	if existing_index >= 0:
		var existing: Dictionary = toast_entries[existing_index]
		existing["data"] = data
		existing["elapsed"] = 0.0
		toast_entries[existing_index] = existing
		_apply_toast_data(existing, data)
		return
	while toast_entries.size() >= MAX_TOASTS:
		_remove_toast(0)
	var entry: Dictionary = _create_toast(data)
	toast_entries.append(entry)


func clear_feedback() -> void:
	for entry: Dictionary in toast_entries:
		var panel: PanelContainer = entry.get("panel") as PanelContainer
		if panel != null and is_instance_valid(panel):
			panel.queue_free()
	toast_entries.clear()


func refresh_tracked_progress() -> void:
	if tracker == null or not is_instance_valid(tracker):
		tracked_panel.visible = false
		return
	if not tracker.has_method("get_tracked_progress_row"):
		tracked_panel.visible = false
		return
	var row_value: Variant = tracker.call("get_tracked_progress_row")
	if not row_value is Dictionary:
		tracked_panel.visible = false
		return
	var row: Dictionary = row_value as Dictionary
	if row.is_empty():
		tracked_panel.visible = false
		return
	var kind: String = str(row.get("kind", "progress"))
	var title: String = str(row.get("title", row.get("name", "Tracked Progress")))
	var detail: String = str(row.get("detail", row.get("objective", row.get("requirement", ""))))
	var current: int = int(row.get("current", row.get("progress_current", -1)))
	var target: int = int(row.get("target", row.get("progress_target", -1)))
	var complete: bool = bool(row.get("complete", false))
	tracked_kind_label.text = (
		("COMPLETE  •  " if complete else "TRACKED  •  ")
		+ kind.replace("_", " ").to_upper()
	)
	tracked_title_label.text = title
	tracked_detail_label.text = detail
	var has_progress: bool = target > 0 and current >= 0
	tracked_progress_bar.visible = has_progress
	tracked_progress_label.visible = has_progress
	if has_progress:
		tracked_progress_bar.max_value = maxi(target, 1)
		tracked_progress_bar.value = clampi(current, 0, maxi(target, 1))
		tracked_progress_label.text = str(current) + " / " + str(target)
	tracked_panel.visible = true


func get_debug_data() -> Dictionary:
	var tracked: Dictionary = {}
	if tracker != null and tracker.has_method("get_tracked_progress_row"):
		var tracked_value: Variant = tracker.call("get_tracked_progress_row")
		if tracked_value is Dictionary:
			tracked = (tracked_value as Dictionary).duplicate(true)
	var keys: Array[String] = []
	for entry: Dictionary in toast_entries:
		var data: Dictionary = entry.get("data", {}) as Dictionary
		keys.append(str(data.get("dedupe_key", "")))
	return {
		"toast_count": toast_entries.size(),
		"toast_keys": keys,
		"tracked": tracked,
		"tracked_visible": tracked_panel.visible,
		"gameplay_context": _has_gameplay_context(),
	}


func _build_hud() -> void:
	root = Control.new()
	root.name = "ProgressionFeedbackRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_tracked_panel()
	_build_toast_stack()


func _build_tracked_panel() -> void:
	tracked_panel = PanelContainer.new()
	tracked_panel.name = "TrackedProgressPanel"
	tracked_panel.anchor_left = 1.0
	tracked_panel.anchor_right = 1.0
	tracked_panel.offset_left = -410.0
	tracked_panel.offset_top = 68.0
	tracked_panel.offset_right = -24.0
	tracked_panel.offset_bottom = 184.0
	tracked_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracked_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.012, 0.02, 0.034, 0.92),
			Color(0.32, 0.64, 0.96, 0.72),
			2,
			14
		)
	)
	root.add_child(tracked_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	tracked_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	tracked_kind_label = Label.new()
	tracked_kind_label.add_theme_font_size_override("font_size", 9)
	tracked_kind_label.add_theme_color_override("font_color", Color(0.48, 0.72, 1.0, 0.94))
	stack.add_child(tracked_kind_label)
	tracked_title_label = Label.new()
	tracked_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tracked_title_label.add_theme_font_size_override("font_size", 16)
	tracked_title_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	stack.add_child(tracked_title_label)
	tracked_detail_label = Label.new()
	tracked_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tracked_detail_label.add_theme_font_size_override("font_size", 10)
	tracked_detail_label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.88, 0.92))
	stack.add_child(tracked_detail_label)
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 9)
	stack.add_child(progress_row)
	tracked_progress_bar = ProgressBar.new()
	tracked_progress_bar.show_percentage = false
	tracked_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracked_progress_bar.custom_minimum_size = Vector2(0.0, 9.0)
	tracked_progress_bar.add_theme_stylebox_override(
		"background",
		_make_panel_style(Color(0.04, 0.055, 0.08, 0.95), Color(0.14, 0.22, 0.34, 0.72), 1, 5)
	)
	tracked_progress_bar.add_theme_stylebox_override(
		"fill",
		_make_panel_style(Color(0.26, 0.66, 1.0, 0.96), Color(0.26, 0.66, 1.0, 0.96), 0, 5)
	)
	progress_row.add_child(tracked_progress_bar)
	tracked_progress_label = Label.new()
	tracked_progress_label.custom_minimum_size = Vector2(58.0, 0.0)
	tracked_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tracked_progress_label.add_theme_font_size_override("font_size", 10)
	tracked_progress_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.96))
	progress_row.add_child(tracked_progress_label)
	tracked_panel.visible = false


func _build_toast_stack() -> void:
	toast_stack = VBoxContainer.new()
	toast_stack.name = "ProgressionToastStack"
	toast_stack.anchor_left = 1.0
	toast_stack.anchor_right = 1.0
	toast_stack.offset_left = -430.0
	toast_stack.offset_top = 198.0
	toast_stack.offset_right = -24.0
	toast_stack.offset_bottom = 720.0
	toast_stack.add_theme_constant_override("separation", 8)
	toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_stack)


func _create_toast(data: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390.0, 76.0 if not bool(data.get("major", false)) else 94.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_stack.add_child(panel)
	toast_stack.move_child(panel, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 9)
	stack.add_child(header)
	var title := Label.new()
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 17 if bool(data.get("major", false)) else 14)
	stack.add_child(title)
	var body := Label.new()
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_theme_font_size_override("font_size", 10)
	stack.add_child(body)
	var progress := ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0.0, 7.0)
	progress.add_theme_stylebox_override(
		"background",
		_make_panel_style(Color(0.04, 0.05, 0.07, 0.96), Color(0.14, 0.18, 0.25, 0.66), 1, 4)
	)
	stack.add_child(progress)
	var entry: Dictionary = {
		"panel": panel,
		"header": header,
		"title": title,
		"body": body,
		"progress": progress,
		"data": data,
		"elapsed": 0.0,
	}
	_apply_toast_data(entry, data)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	panel.pivot_offset = panel.custom_minimum_size * 0.5
	var tween: Tween = panel.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.22)
	return entry


func _apply_toast_data(entry: Dictionary, data: Dictionary) -> void:
	var panel: PanelContainer = entry.get("panel") as PanelContainer
	var header: Label = entry.get("header") as Label
	var title: Label = entry.get("title") as Label
	var body: Label = entry.get("body") as Label
	var progress: ProgressBar = entry.get("progress") as ProgressBar
	if panel == null or header == null or title == null or body == null or progress == null:
		return
	var kind: String = str(data.get("kind", "tracked"))
	var color: Color = _kind_color(kind)
	var major: bool = bool(data.get("major", false))
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(color.r * 0.08, color.g * 0.08, color.b * 0.08, 0.96),
			Color(color.r, color.g, color.b, 0.92 if major else 0.68),
			3 if major else 2,
			14
		)
	)
	header.text = kind.replace("_", " ").to_upper()
	header.add_theme_color_override("font_color", color)
	title.text = str(data.get("title", "Progress"))
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	body.text = str(data.get("body", ""))
	body.visible = body.text != ""
	body.add_theme_color_override("font_color", Color(0.72, 0.8, 0.9, 0.94))
	var current: int = int(data.get("current", -1))
	var target: int = int(data.get("target", -1))
	progress.visible = current >= 0 and target > 0
	if progress.visible:
		progress.max_value = maxi(target, 1)
		progress.value = clampi(current, 0, maxi(target, 1))
		progress.add_theme_stylebox_override(
			"fill",
			_make_panel_style(color, color, 0, 4)
		)
	panel.modulate.a = 1.0


func _update_toasts(delta: float) -> void:
	for index: int in range(toast_entries.size() - 1, -1, -1):
		var entry: Dictionary = toast_entries[index]
		var panel: PanelContainer = entry.get("panel") as PanelContainer
		if panel == null or not is_instance_valid(panel):
			toast_entries.remove_at(index)
			continue
		var data: Dictionary = entry.get("data", {}) as Dictionary
		var elapsed: float = float(entry.get("elapsed", 0.0)) + delta
		entry["elapsed"] = elapsed
		toast_entries[index] = entry
		var duration: float = float(data.get("duration", DEFAULT_TOAST_DURATION))
		if elapsed <= duration:
			continue
		var fade_fraction: float = (elapsed - duration) / TOAST_FADE_DURATION
		panel.modulate.a = clampf(1.0 - fade_fraction, 0.0, 1.0)
		if fade_fraction >= 1.0:
			_remove_toast(index)


func _remove_toast(index: int) -> void:
	if index < 0 or index >= toast_entries.size():
		return
	var entry: Dictionary = toast_entries[index]
	var panel: PanelContainer = entry.get("panel") as PanelContainer
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	toast_entries.remove_at(index)


func _find_toast_index(dedupe_key: String) -> int:
	for index: int in range(toast_entries.size()):
		var entry: Dictionary = toast_entries[index]
		var data: Dictionary = entry.get("data", {}) as Dictionary
		if str(data.get("dedupe_key", "")) == dedupe_key:
			return index
	return -1


func _connect_game_state() -> void:
	if not GameState.unlock_changed.is_connected(_on_unlock_changed):
		GameState.unlock_changed.connect(_on_unlock_changed)
	if not GameState.level_gained.is_connected(_on_level_gained):
		GameState.level_gained.connect(_on_level_gained)
	if not GameState.weapon_mastery_ranked_up.is_connected(_on_weapon_mastery_ranked_up):
		GameState.weapon_mastery_ranked_up.connect(_on_weapon_mastery_ranked_up)
	if not GameState.quest_changed.is_connected(_on_quest_changed):
		GameState.quest_changed.connect(_on_quest_changed)
	if not GameState.save_loaded.is_connected(_on_save_loaded):
		GameState.save_loaded.connect(_on_save_loaded)


func _bind_available_sources() -> void:
	var resolved_tracker: Node = get_node_or_null("/root/FullMenuDirector/ProgressionTracker")
	if resolved_tracker != null:
		bind_tracker(resolved_tracker)
	var species: Node = get_node_or_null("/root/SpeciesKnowledge")
	if species != null:
		if species.has_signal("knowledge_changed") and not species.knowledge_changed.is_connected(_on_species_knowledge_changed):
			species.knowledge_changed.connect(_on_species_knowledge_changed)
		if species.has_signal("discovery_recorded") and not species.discovery_recorded.is_connected(_on_species_discovery_recorded):
			species.discovery_recorded.connect(_on_species_discovery_recorded)
		if species.has_signal("unlock_earned") and not species.unlock_earned.is_connected(_on_species_unlock_earned):
			species.unlock_earned.connect(_on_species_unlock_earned)


func _connect_tracker() -> void:
	if tracker == null:
		return
	if tracker.has_signal("challenge_progressed") and not tracker.challenge_progressed.is_connected(_on_challenge_progressed):
		tracker.challenge_progressed.connect(_on_challenge_progressed)
	if tracker.has_signal("challenge_completed") and not tracker.challenge_completed.is_connected(_on_challenge_completed):
		tracker.challenge_completed.connect(_on_challenge_completed)
	if tracker.has_signal("knowledge_discovered") and not tracker.knowledge_discovered.is_connected(_on_knowledge_discovered):
		tracker.knowledge_discovered.connect(_on_knowledge_discovered)
	if tracker.has_signal("tracked_progress_changed") and not tracker.tracked_progress_changed.is_connected(_on_tracked_progress_changed):
		tracker.tracked_progress_changed.connect(_on_tracked_progress_changed)


func _disconnect_tracker() -> void:
	if tracker == null or not is_instance_valid(tracker):
		return
	if tracker.has_signal("challenge_progressed") and tracker.challenge_progressed.is_connected(_on_challenge_progressed):
		tracker.challenge_progressed.disconnect(_on_challenge_progressed)
	if tracker.has_signal("challenge_completed") and tracker.challenge_completed.is_connected(_on_challenge_completed):
		tracker.challenge_completed.disconnect(_on_challenge_completed)
	if tracker.has_signal("knowledge_discovered") and tracker.knowledge_discovered.is_connected(_on_knowledge_discovered):
		tracker.knowledge_discovered.disconnect(_on_knowledge_discovered)
	if tracker.has_signal("tracked_progress_changed") and tracker.tracked_progress_changed.is_connected(_on_tracked_progress_changed):
		tracker.tracked_progress_changed.disconnect(_on_tracked_progress_changed)


func _on_challenge_progressed(challenge_id: String, current: int, target: int) -> void:
	if current >= target:
		refresh_tracked_progress()
		return
	var definition: Dictionary = ChallengeCatalogScript.get_definition(challenge_id)
	push_feedback(
		"challenge",
		str(definition.get("display_name", challenge_id.replace("_", " ").capitalize())),
		str(definition.get("requirement", "Challenge progress updated.")),
		"challenge_progress:" + challenge_id,
		current,
		target
	)
	refresh_tracked_progress()


func _on_challenge_completed(challenge_id: String, reward_id: String) -> void:
	var definition: Dictionary = ChallengeCatalogScript.get_definition(challenge_id)
	push_feedback(
		"unlock",
		str(definition.get("reward_name", reward_id.replace("_", " ").capitalize())),
		"Challenge complete: " + str(definition.get("display_name", challenge_id.capitalize())),
		"reward:" + reward_id,
		int(definition.get("target", 1)),
		int(definition.get("target", 1)),
		true
	)
	refresh_tracked_progress()


func _on_knowledge_discovered(category: String, record_id: String, evidence: Dictionary) -> void:
	if bool(evidence.get("bootstrap", false)) or category.begins_with("challenge_unique::"):
		return
	var label: String = record_id.replace("_", " ").capitalize()
	var body: String = "Recorded in the Journal."
	if category == "reaction":
		body = "Reaction equation revealed in Journal → Elements."
	elif category == "recipe":
		body = "Formula recorded in Journal → Potions."
	push_feedback(
		"discovery",
		label,
		body,
		"discovery:" + category + ":" + record_id,
		-1,
		-1,
		true
	)


func _on_tracked_progress_changed(kind: String, record_id: String, row: Dictionary) -> void:
	push_feedback(
		"tracked",
		str(row.get("title", row.get("name", record_id.capitalize()))),
		"Pinned to the gameplay HUD.",
		"tracked_progress",
		int(row.get("current", -1)),
		int(row.get("target", -1))
	)
	refresh_tracked_progress()


func _on_unlock_changed(unlock_id: String, value: bool) -> void:
	if not value or _notifications_suppressed() or _is_challenge_reward(unlock_id):
		return
	var unlocks: Dictionary = GameState.get_unlock_snapshot()
	var row_value: Variant = unlocks.get(unlock_id, {})
	var row: Dictionary = row_value as Dictionary if row_value is Dictionary else {}
	if _unlock_is_silent(row):
		return
	var is_achievement: bool = unlock_id.begins_with("achievement::")
	var display_name: String = str(
		row.get(
			"display_name",
			unlock_id.trim_prefix("achievement::").replace("_", " ").capitalize()
		)
	)
	push_feedback(
		"achievement" if is_achievement else "unlock",
		display_name,
		"Achievement unlocked." if is_achievement else "A new progression option is available.",
		"unlock:" + unlock_id,
		-1,
		-1,
		true
	)


func _on_level_gained(new_level: int, points_awarded: int) -> void:
	if _notifications_suppressed():
		return
	push_feedback(
		"level",
		"Level " + str(new_level),
		"+" + str(points_awarded) + " Growth Point",
		"level:" + str(new_level),
		-1,
		-1,
		true
	)


func _on_weapon_mastery_ranked_up(weapon_class: String, rank: int) -> void:
	if _notifications_suppressed():
		return
	push_feedback(
		"mastery",
		weapon_class.replace("_", " ").capitalize() + " Rank " + str(rank),
		"New weapon techniques may be available.",
		"weapon_mastery:" + weapon_class,
		rank,
		-1,
		true
	)


func _on_quest_changed(quest_id: String, quest_data: Dictionary) -> void:
	if quest_data.is_empty():
		last_quest_stages.erase(quest_id)
		refresh_tracked_progress()
		return
	var state: String = str(quest_data.get("state", ""))
	var stage: int = int(quest_data.get("stage", 0))
	var previous_stage: int = int(last_quest_stages.get(quest_id, -1))
	last_quest_stages[quest_id] = stage
	if not _notifications_suppressed():
		if state == "completed":
			push_feedback(
				"quest",
				str(quest_data.get("title", quest_id.capitalize())),
				"Quest completed.",
				"quest_complete:" + quest_id,
				-1,
				-1,
				true
			)
		elif previous_stage < 0:
			push_feedback(
				"quest",
				str(quest_data.get("title", quest_id.capitalize())),
				str(quest_data.get("objective", "Quest started.")),
				"quest_stage:" + quest_id
			)
		elif stage > previous_stage:
			push_feedback(
				"quest",
				str(quest_data.get("title", quest_id.capitalize())),
				str(quest_data.get("objective", "Quest updated.")),
				"quest_stage:" + quest_id,
				stage + 1,
				_max_quest_stage_count(quest_data)
			)
	refresh_tracked_progress()


func _on_species_discovery_recorded(species_id: String, _discovery_id: String, label: String) -> void:
	if _notifications_suppressed():
		return
	push_feedback(
		"creature",
		label,
		species_id.replace("_", " ").capitalize() + " knowledge recorded.",
		"species_discovery:" + species_id + ":" + label.to_lower().replace(" ", "_")
	)


func _on_species_knowledge_changed(species_id: String, _points: int, rank: int) -> void:
	var previous_rank: int = int(last_species_ranks.get(species_id, 0))
	last_species_ranks[species_id] = rank
	if rank <= previous_rank or _notifications_suppressed():
		return
	push_feedback(
		"creature",
		species_id.replace("_", " ").capitalize() + " Rank " + str(rank),
		"New observations or familiar capabilities may be available.",
		"species_rank:" + species_id,
		rank,
		4,
		true
	)


func _on_species_unlock_earned(species_id: String, unlock_id: String, label: String) -> void:
	if _notifications_suppressed():
		return
	push_feedback(
		"unlock",
		label,
		species_id.replace("_", " ").capitalize() + " capability unlocked.",
		"reward:" + unlock_id,
		-1,
		-1,
		true
	)


func _on_save_loaded(_save_data: Dictionary) -> void:
	suppress_until_msec = Time.get_ticks_msec() + INITIAL_SUPPRESSION_MSEC
	last_species_ranks.clear()
	last_quest_stages.clear()
	clear_feedback()
	call_deferred("refresh_tracked_progress")


func _is_challenge_reward(unlock_id: String) -> bool:
	for definition: Dictionary in ChallengeCatalogScript.get_definitions():
		if str(definition.get("reward_id", "")) == unlock_id:
			return true
	return false


func _unlock_is_silent(row: Dictionary) -> bool:
	var evidence_value: Variant = row.get("evidence", {})
	var evidence: Dictionary = evidence_value as Dictionary if evidence_value is Dictionary else {}
	var source: String = str(evidence.get("source", ""))
	return (
		source in ["story_baseline", "debug_master_all"]
		or bool(evidence.get("filled_for_sequential_integrity", false))
	)


func _notifications_suppressed() -> bool:
	return Time.get_ticks_msec() < suppress_until_msec


func _max_quest_stage_count(quest_data: Dictionary) -> int:
	var stages_value: Variant = quest_data.get("stages", [])
	if stages_value is Array:
		return maxi((stages_value as Array).size(), 1)
	return 1


func _update_context_visibility() -> void:
	root.visible = _has_gameplay_context()


func _has_gameplay_context() -> bool:
	return (
		get_tree().get_first_node_in_group("game_ui") != null
		or get_tree().get_first_node_in_group("player") != null
	)


func _kind_color(kind: String) -> Color:
	var value: Variant = COLOR_BY_KIND.get(kind, Color(0.42, 0.72, 1.0, 1.0))
	return value as Color if value is Color else Color(0.42, 0.72, 1.0, 1.0)


func _make_panel_style(
	background: Color,
	border: Color,
	border_width: int,
	corner_radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style
