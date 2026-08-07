extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_water_jet_spell_trial_v1.tscn"
)
const COMPLETION_FLAG: String = "pressureworks_water_jet_trial_complete"

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_completion_flag: bool = false


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_completion_flag = GameState.get_flag(COMPLETION_FLAG)
	_prepare_stats()

	var trial: PrototypeWaterJetSpellTrial = (
		TrialScene.instantiate() as PrototypeWaterJetSpellTrial
	)
	add_child(trial)
	for _frame: int in range(20):
		await get_tree().process_frame
	await get_tree().physics_frame

	var player: CharacterBody3D = trial.get_node_or_null("Player") as CharacterBody3D
	var crate: RigidBody3D = trial.get_node_or_null(
		"PressureworksActors/PressureCrate"
	) as RigidBody3D
	var pressure_gate: MechanismSlidingGate = trial.get_node_or_null(
		"PressureworksActors/PressureLaneGate"
	) as MechanismSlidingGate
	var ascent_gate: MechanismSlidingGate = trial.get_node_or_null(
		"PressureworksActors/CounterflowGate"
	) as MechanismSlidingGate
	_expect(player != null, "Pressureworks spawns Grace")
	_expect(crate != null, "Pressureworks builds the pressure cargo")
	_expect(pressure_gate != null, "Pressureworks builds the pressure gate")
	_expect(ascent_gate != null, "Pressureworks builds the ascent gate")
	if player == null or crate == null or pressure_gate == null or ascent_gate == null:
		_finish(trial)
		return

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var current_ability: AbilityDefinition = (
		caster.call("get_current_ability") as AbilityDefinition
		if caster != null and caster.has_method("get_current_ability")
		else null
	)
	_expect(
		current_ability != null and current_ability.get_spell_id() == "water_jet",
		"Pressureworks automatically equips Water Jet"
	)
	_expect(is_equal_approx(crate.mass, 12.0), "pressure lane uses the authored 12 kg cargo")

	trial.call("_on_pressure_goal_body_entered", crate)
	var pressure_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(pressure_debug.get("stage", "")) == "counterflow_ascent",
		"delivering cargo advances the trial to Counterflow Ascent"
	)
	_expect(pressure_gate.is_mechanism_active(), "pressure cargo opens the first gate")
	_expect(crate.freeze, "completed pressure cargo latches inside its basin")
	_expect(not ascent_gate.is_mechanism_active(), "upper gate remains closed after stage one")

	var launch_baseline: int = int(
		pressure_debug.get("launch_serial_at_stage_start", 0)
	)
	player.set_meta("water_jet_self_launch_serial", launch_baseline + 1)
	player.set_meta("water_jet_self_launch_speed", 6.0)
	trial.call("_on_upper_arrival_body_entered", player)
	var ascent_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(ascent_debug.get("stage", "")) == "mastery",
		"a recorded Water Jet launch completes the raised-platform stage"
	)
	_expect(ascent_gate.is_mechanism_active(), "valid counterflow ascent opens the upper gate")
	_expect(
		int(ascent_debug.get("last_arrival_launch_serial", 0)) == launch_baseline + 1,
		"trial retains the self-launch event that reached the platform"
	)

	trial.call("_on_mastery_area_body_entered", player)
	var complete_debug: Dictionary = trial.get_debug_data()
	_expect(bool(complete_debug.get("complete", false)), "mastery seal completes the Pressureworks")
	_expect(GameState.get_flag(COMPLETION_FLAG), "Pressureworks records the Water Jet mastery flag")

	trial.reset_trial()
	await get_tree().process_frame
	var reset_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(reset_debug.get("stage", "")) == "pressure_lane",
		"F8 reset returns the trial to the pressure lane"
	)
	_expect(not pressure_gate.is_mechanism_active(), "reset closes the pressure gate")
	_expect(not ascent_gate.is_mechanism_active(), "reset closes the ascent gate")
	_expect(not crate.freeze, "reset releases and restores the pressure cargo")
	_expect(not GameState.get_flag(COMPLETION_FLAG), "reset clears the temporary mastery flag")
	_expect(
		GameState.get_stat("mana") == GameState.get_stat("max_mana"),
		"reset restores Mana for another pressure run"
	)
	_expect(
		float(player.get_meta("water_jet_mana_debt", -1.0)) == 0.0,
		"reset clears Water Jet's fractional Mana debt"
	)

	_finish(trial)


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 60)
	GameState.set_stat("mana", 60)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("WATER_JET_TRIAL_SMOKE_TEST: " + label)


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
		print("WATER_JET_TRIAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WATER_JET_TRIAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
