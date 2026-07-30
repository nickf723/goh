extends Control
class_name PrototypeTacticalAiLab


const RecorderScript = preload(
	"res://scripts/ai/tactical_decision_recorder.gd"
)
const OverlayScript = preload(
	"res://scripts/ui/tactical_decision_overlay.gd"
)
const WorldSnapshot = preload(
	"res://scripts/ai/tactical_world_snapshot.gd"
)
const ActionCandidate = preload(
	"res://scripts/ai/tactical_action_candidate.gd"
)
const Planner = preload(
	"res://scripts/ai/reaction_tactical_planner.gd"
)
const Blackboard = preload(
	"res://scripts/ai/tactical_blackboard.gd"
)
const ClaimRegistry = preload(
	"res://scripts/ai/reaction_claim_registry.gd"
)
const LaneRegistry = preload(
	"res://scripts/ai/engagement_lane_registry.gd"
)

const DEFAULT_EXPORT_PATH: String = "user://tactical_ai_reports/tactical_decision_replay.json"

var recorder: TacticalDecisionRecorder
var overlay: TacticalDecisionOverlay
var scenario_picker: OptionButton
var scenario_description: Label
var result_label: Label
var timeline_label: Label
var advance_button: Button
var export_button: Button
var scenario_ids: Array[String] = [
	"wet_conduction",
	"protected_shatter",
	"cover_withdrawal",
	"occupied_lane",
	"emergency_defense",
]
var decision_count: int = 0
var export_count: int = 0


func _ready() -> void:
	name = "PrototypeTacticalAILab"
	process_mode = Node.PROCESS_MODE_ALWAYS
	recorder = RecorderScript.new().configure(48)
	_build_ui()
	overlay = OverlayScript.new()
	overlay.name = "TacticalDecisionOverlay"
	overlay.show_on_start = true
	add_child(overlay)
	overlay.bind_recorder(recorder)
	_update_scenario_description()
	add_to_group("tactical_ai_lab")
	add_to_group("debuggable")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var key: Key = key_event.physical_keycode as Key
	if key == KEY_NONE:
		key = key_event.keycode as Key
	if key == KEY_SPACE or key == KEY_ENTER:
		run_selected_scenario()
		get_viewport().set_input_as_handled()
	elif key == KEY_R:
		clear_replay()
		get_viewport().set_input_as_handled()


func run_selected_scenario() -> Dictionary:
	var selected_index: int = scenario_picker.selected if scenario_picker != null else 0
	return run_scenario_by_id(scenario_ids[clampi(selected_index, 0, scenario_ids.size() - 1)])


func run_scenario_by_id(scenario_id: String) -> Dictionary:
	Blackboard.clear_all()
	var recipe: Dictionary = _build_recipe(scenario_id)
	var snapshot: Dictionary = recipe.get("snapshot", {}) as Dictionary
	var coordination: Dictionary = recipe.get("coordination", {}) as Dictionary
	for key: Variant in coordination.keys():
		snapshot[key] = coordination[key]
	var candidates: Array[TacticalActionCandidate] = []
	var raw_candidates: Variant = recipe.get("candidates", [])
	if raw_candidates is Array:
		for candidate_value: Variant in raw_candidates as Array:
			if candidate_value is TacticalActionCandidate:
				candidates.append(candidate_value as TacticalActionCandidate)
	var plan: Dictionary = Planner.choose_best(candidates, snapshot)
	decision_count += 1
	var result: Dictionary = recorder.record_frame(
		1000 + decision_count,
		"Tactical Lab Actor",
		str(recipe.get("display_name", scenario_id)),
		plan,
		coordination,
		{
			"scenario_id": scenario_id,
			"scenario_description": str(recipe.get("description", "")),
			"decision_number": decision_count,
		}
	)
	recorder.jump_to_latest()
	overlay.refresh_from_recorder(true)
	_update_result(plan, result)
	_update_timeline_label()
	return plan


func clear_replay() -> void:
	Blackboard.clear_all()
	recorder.clear()
	decision_count = 0
	overlay.refresh_from_recorder(true)
	result_label.text = "Replay cleared. Choose a scenario and advance one decision."
	_update_timeline_label()


func export_replay(path: String = DEFAULT_EXPORT_PATH) -> Dictionary:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var directory: String = absolute_path.get_base_dir()
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return {
			"ok": false,
			"path": path,
			"error": "Could not create export directory: " + str(mkdir_error),
		}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"path": path,
			"error": "Could not open replay file: " + str(FileAccess.get_open_error()),
		}
	file.store_string(recorder.to_json("  "))
	file.close()
	export_count += 1
	var result: Dictionary = {
		"ok": true,
		"path": path,
		"absolute_path": absolute_path,
		"frame_count": recorder.get_frame_count(),
	}
	result_label.text = "Exported " + str(result.get("frame_count", 0)) + " frames to " + absolute_path
	return result


func get_decision_recorder() -> TacticalDecisionRecorder:
	return recorder


func get_decision_overlay() -> TacticalDecisionOverlay:
	return overlay


func _build_recipe(scenario_id: String) -> Dictionary:
	match scenario_id:
		"protected_shatter":
			return _protected_shatter_recipe()
		"cover_withdrawal":
			return _cover_recipe()
		"occupied_lane":
			return _lane_recipe()
		"emergency_defense":
			return _emergency_recipe()
		_:
			return _conduct_recipe()


func _conduct_recipe() -> Dictionary:
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot([], ["wet"])
	return {
		"display_name": "Wet target decision",
		"description": "A Wet target should make Lightning Spark win through Conduct.",
		"snapshot": snapshot,
		"coordination": {},
		"candidates": [
			_make_candidate("firebolt", "spell", ["fire", "projectile", "ranged"], [], ["damage"]),
			_make_candidate("lightning_spark", "spell", ["lightning", "projectile", "ranged"], [], ["damage"]),
		],
	}


func _protected_shatter_recipe() -> Dictionary:
	ClaimRegistry.reserve_payoff(
		"lab_squad",
		1,
		"Hammer Specialist",
		"shatter",
		2,
		1.2
	)
	var coordination: Dictionary = Blackboard.get_coordination_context(
		"lab_squad",
		2,
		2
	)
	return {
		"display_name": "Protected Frozen state",
		"description": "A reserved Shatter payoff protects Frozen from Fire-driven Steam conversion.",
		"snapshot": WorldSnapshot.make_test_snapshot([], ["frozen"]),
		"coordination": coordination,
		"candidates": [
			_make_candidate("firebolt", "spell", ["fire", "projectile", "ranged"], ["burning"], ["damage", "setup"]),
			_make_candidate("arcane_spark", "spell", ["neutral", "projectile", "ranged"], [], ["damage"]),
		],
	}


func _cover_recipe() -> Dictionary:
	Blackboard.broadcast_intent(
		"lab_squad",
		1,
		"Retreating Scout",
		"cover_request",
		["cover_requested"],
		2,
		1.0
	)
	var coordination: Dictionary = Blackboard.get_coordination_context(
		"lab_squad",
		2,
		2
	)
	var melee: TacticalActionCandidate = _make_candidate(
		"club_charge",
		"attack",
		["physical", "melee"],
		[],
		["damage"],
		"toward_target"
	)
	melee.maximum_distance = 1.8
	return {
		"display_name": "Cover a withdrawal",
		"description": "A cover request should recruit ranged pressure instead of another charge.",
		"snapshot": WorldSnapshot.make_test_snapshot([], []),
		"coordination": coordination,
		"candidates": [
			melee,
			_make_candidate("stone_throw", "attack", ["physical", "projectile", "ranged"], [], ["damage"]),
		],
	}


func _lane_recipe() -> Dictionary:
	LaneRegistry.reserve_lane(
		"lab_squad",
		1,
		"Frontliner",
		"melee",
		2,
		1.0
	)
	var coordination: Dictionary = Blackboard.get_coordination_context(
		"lab_squad",
		2,
		2
	)
	var melee: TacticalActionCandidate = _make_candidate(
		"bite",
		"attack",
		["physical", "melee"],
		[],
		["damage"],
		"toward_target"
	)
	melee.maximum_distance = 1.5
	return {
		"display_name": "Occupied melee lane",
		"description": "An occupied melee lane should redirect the next actor to ranged pressure.",
		"snapshot": WorldSnapshot.make_test_snapshot([], []),
		"coordination": coordination,
		"candidates": [
			melee,
			_make_candidate("spit", "attack", ["poison", "projectile", "ranged"], ["poisoned"], ["damage", "setup"]),
		],
	}


func _emergency_recipe() -> Dictionary:
	ClaimRegistry.reserve_payoff(
		"lab_squad",
		1,
		"Combo Partner",
		"wet_conduction",
		2,
		1.0
	)
	var coordination: Dictionary = Blackboard.get_coordination_context(
		"lab_squad",
		2,
		2
	)
	return {
		"display_name": "Emergency defense",
		"description": "Critical health should override an attractive reaction payoff.",
		"snapshot": WorldSnapshot.make_test_snapshot(
			[],
			["wet"],
			{"actor_health_fraction": 0.12}
		),
		"coordination": coordination,
		"candidates": [
			_make_candidate("lightning_spark", "attack", ["lightning", "projectile", "ranged"], [], ["damage"]),
			_make_candidate("guard", "defense", ["guard", "defense"], [], ["defense"]),
		],
	}


func _make_candidate(
	id: String,
	kind: String,
	tags: Array[String],
	states: Array[String] = [],
	capabilities: Array[String] = [],
	movement: String = "none"
) -> TacticalActionCandidate:
	return ActionCandidate.make_test_candidate(
		id,
		kind,
		tags,
		states,
		capabilities,
		movement
	)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.012, 0.018, 0.032, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var title := Label.new()
	title.text = "TACTICAL AI LABORATORY"
	title.position = Vector2(32.0, 24.0)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Step deterministic decisions • F2 toggles flight recorder • R clears replay"
	subtitle.position = Vector2(34.0, 66.0)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.76, 0.86))
	add_child(subtitle)

	var controls := VBoxContainer.new()
	controls.position = Vector2(32.0, 112.0)
	controls.size = Vector2(500.0, 600.0)
	controls.add_theme_constant_override("separation", 12)
	add_child(controls)

	var scenario_title := Label.new()
	scenario_title.text = "SCENARIO"
	scenario_title.add_theme_font_size_override("font_size", 18)
	controls.add_child(scenario_title)

	scenario_picker = OptionButton.new()
	scenario_picker.add_item("Wet → Conduct")
	scenario_picker.add_item("Protected Frozen → preserve Shatter")
	scenario_picker.add_item("Retreat → request cover")
	scenario_picker.add_item("Occupied lane → choose ranged")
	scenario_picker.add_item("Critical health → emergency defense")
	scenario_picker.item_selected.connect(func(_index: int) -> void:
		_update_scenario_description()
	)
	controls.add_child(scenario_picker)

	scenario_description = Label.new()
	scenario_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scenario_description.custom_minimum_size = Vector2(480.0, 72.0)
	scenario_description.add_theme_font_size_override("font_size", 15)
	controls.add_child(scenario_description)

	advance_button = Button.new()
	advance_button.text = "ADVANCE ONE DECISION  [SPACE]"
	advance_button.custom_minimum_size = Vector2(0.0, 48.0)
	advance_button.pressed.connect(run_selected_scenario)
	controls.add_child(advance_button)

	var replay_row := HBoxContainer.new()
	replay_row.add_theme_constant_override("separation", 8)
	controls.add_child(replay_row)

	var previous_button := Button.new()
	previous_button.text = "← PREVIOUS"
	previous_button.pressed.connect(func() -> void:
		recorder.step_back()
		overlay.refresh_from_recorder(true)
		_update_timeline_label()
	)
	replay_row.add_child(previous_button)

	var next_button := Button.new()
	next_button.text = "NEXT →"
	next_button.pressed.connect(func() -> void:
		recorder.step_forward()
		overlay.refresh_from_recorder(true)
		_update_timeline_label()
	)
	replay_row.add_child(next_button)

	var clear_button := Button.new()
	clear_button.text = "CLEAR"
	clear_button.pressed.connect(clear_replay)
	replay_row.add_child(clear_button)

	export_button = Button.new()
	export_button.text = "EXPORT JSON"
	export_button.pressed.connect(func() -> void:
		export_replay()
	)
	replay_row.add_child(export_button)

	result_label = Label.new()
	result_label.text = "No decision recorded yet."
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size = Vector2(480.0, 110.0)
	result_label.add_theme_font_size_override("font_size", 16)
	controls.add_child(result_label)

	timeline_label = Label.new()
	timeline_label.add_theme_font_size_override("font_size", 14)
	controls.add_child(timeline_label)
	_update_timeline_label()


func _update_scenario_description() -> void:
	if scenario_description == null or scenario_picker == null:
		return
	var descriptions: Array[String] = [
		"Wet is already visible. Lightning should win through Conduct.",
		"A squadmate owns Shatter. Fire must not consume Frozen first.",
		"One actor withdraws and asks for cover. Ranged pressure should answer.",
		"The melee lane is occupied. A second approach should be vetoed.",
		"The actor is at critical health. Guard should override squad plans.",
	]
	scenario_description.text = descriptions[clampi(scenario_picker.selected, 0, descriptions.size() - 1)]


func _update_result(plan: Dictionary, record_result: Dictionary) -> void:
	var selected: String = str(plan.get("selected_name", plan.get("selected_id", "None")))
	var reason: String = str(plan.get("reason", "No reason"))
	var recorded: bool = bool(record_result.get("recorded", false))
	result_label.text = (
		"Selected: " + selected
		+ "\nReason: " + reason
		+ "\nRecorder: " + ("new frame" if recorded else "deduplicated repeat")
	)


func _update_timeline_label() -> void:
	if timeline_label == null or recorder == null:
		return
	var debug: Dictionary = recorder.get_debug_data()
	timeline_label.text = (
		"Timeline " + str(int(debug.get("cursor", -1)) + 1)
		+ "/" + str(debug.get("frame_count", 0))
		+ " • repeats collapsed " + str(debug.get("duplicate_count", 0))
		+ " • cap " + str(debug.get("max_frames", 0))
	)


func get_debug_data() -> Dictionary:
	return {
		"decision_count": decision_count,
		"export_count": export_count,
		"selected_scenario": scenario_ids[scenario_picker.selected] if scenario_picker != null else "none",
		"recorder": recorder.get_debug_data() if recorder != null else {},
		"overlay": overlay.get_debug_data() if overlay != null else {},
	}
