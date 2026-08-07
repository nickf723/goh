extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_body_forms_spell_trial_v1.tscn"
)
const BodyFormControllerScript = preload(
	"res://scripts/player/player_body_form_controller.gd"
)

const COMPLETION_FLAG: String = (
	"hall_of_measure_body_forms_trial_complete"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_completion_flag: bool = false


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_completion_flag = GameState.get_flag(COMPLETION_FLAG)
	_prepare_stats()

	var trial: PrototypeBodyFormsSpellTrial = (
		TrialScene.instantiate() as PrototypeBodyFormsSpellTrial
	)
	add_child(trial)
	await _wait_frames(24)
	await get_tree().physics_frame

	var player: CharacterBody3D = trial.get_node_or_null(
		"Player"
	) as CharacterBody3D
	var mass_plate: PressurePlateSwitch = trial.get_node_or_null(
		"HallOfMeasureActors/BodyMassPlate"
	) as PressurePlateSwitch
	var mass_gate: MechanismSlidingGate = trial.get_node_or_null(
		"HallOfMeasureActors/MassGate"
	) as MechanismSlidingGate
	var passage_gate: MechanismSlidingGate = trial.get_node_or_null(
		"HallOfMeasureActors/PassageGate"
	) as MechanismSlidingGate

	_expect(player != null, "Hall of Measure spawns Grace")
	_expect(mass_plate != null, "Hall of Measure builds the weighted plate")
	_expect(mass_gate != null, "Hall of Measure builds the mass gate")
	_expect(passage_gate != null, "Hall of Measure builds the passage gate")
	if player == null or mass_plate == null or mass_gate == null or passage_gate == null:
		_finish(trial)
		return

	var controller: PlayerBodyFormController = (
		BodyFormControllerScript.new() as PlayerBodyFormController
	)
	controller.name = "BodyFormController"
	player.add_child(controller)
	await _wait_frames(3)
	_expect(controller.force_form("grown", true, false), "test fixture enters Grow")
	mass_plate.call("_on_body_entered", player)
	await _wait_frames(3)
	trial.evaluate_gate_progression_now()
	await _wait_frames(2)

	var mass_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(mass_debug.get("stage", "")) == "narrow_passage",
		"150 kg Grow advances the lab to the narrow passage"
	)
	_expect(
		float(mass_debug.get("last_mass_kg", 0.0)) >= 149.0,
		"the mass gate records Grow's dynamic mechanism mass"
	)
	_expect(mass_gate.is_mechanism_active(), "the mass gate opens")
	_expect(
		bool(mass_gate.get_debug_data().get("collision_disabled", false)),
		"the opened mass gate removes its blocking collision"
	)

	_expect(controller.force_form("shrunk", true, false), "test fixture enters Shrink")
	player.global_position.z = trial.passage_finish_z
	trial.evaluate_gate_progression_now()
	await _wait_frames(2)
	var passage_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(passage_debug.get("stage", "")) == "mastery",
		"the periodically checked Shrink arrival advances to mastery"
	)
	_expect(
		str(passage_debug.get("last_passage_form", "")) == "shrunk"
		and float(passage_debug.get("last_passage_height", 9.0))
		<= trial.maximum_passage_height,
		"the passage verifies the actual small collision capsule"
	)
	_expect(passage_gate.is_mechanism_active(), "the passage gate opens")
	_expect(
		bool(passage_gate.get_debug_data().get("collision_disabled", false)),
		"the opened passage gate removes its blocking collision"
	)

	trial.call("_on_mastery_area_entered", player)
	var complete_debug: Dictionary = trial.get_debug_data()
	_expect(bool(complete_debug.get("trial_complete", false)), "the mastery seal completes the lab")
	_expect(GameState.get_flag(COMPLETION_FLAG), "the Hall of Measure records mastery")

	trial.reset_trial()
	await _wait_frames(4)
	var reset_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(reset_debug.get("stage", "")) == "mass_chamber",
		"F8 reset returns to the mass chamber"
	)
	_expect(controller.get_current_form() == "normal", "reset restores normal size")
	_expect(not mass_gate.is_mechanism_active(), "reset closes the mass gate")
	_expect(not passage_gate.is_mechanism_active(), "reset closes the passage gate")
	_expect(
		GameState.get_stat("mana") == GameState.get_stat("max_mana"),
		"reset restores Mana"
	)
	_expect(not GameState.get_flag(COMPLETION_FLAG), "reset clears the temporary mastery flag")

	_finish(trial)


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("BODY_FORMS_SPELL_TRIAL_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.set_flag(COMPLETION_FLAG, original_completion_flag)


func _finish(trial: Node) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if trial != null and is_instance_valid(trial):
		trial.queue_free()
	if failures.is_empty():
		print("BODY_FORMS_SPELL_TRIAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("BODY_FORMS_SPELL_TRIAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
