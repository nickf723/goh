extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_boulder_spell_trial_v1.tscn"
)
const BoulderScene: PackedScene = preload(
	"res://scenes/actions/earth_boulder.tscn"
)
const COMPLETION_FLAG: String = "momentum_quarry_boulder_trial_complete"

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_completion_flag: bool = false


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_completion_flag = GameState.get_flag(COMPLETION_FLAG)
	_prepare_stats()

	var trial: PrototypeBoulderSpellTrial = (
		TrialScene.instantiate() as PrototypeBoulderSpellTrial
	)
	add_child(trial)
	for _frame: int in range(24):
		await get_tree().process_frame
	await get_tree().physics_frame

	var player: CharacterBody3D = trial.get_node_or_null("Player") as CharacterBody3D
	var flat_target: CharacterBody3D = trial.get_node_or_null(
		"MomentumQuarryActors/FlatMomentumTarget"
	) as CharacterBody3D
	var flat_gate: MechanismSlidingGate = trial.get_node_or_null(
		"MomentumQuarryActors/FlatMomentumGate"
	) as MechanismSlidingGate
	var gravity_gate: MechanismSlidingGate = trial.get_node_or_null(
		"MomentumQuarryActors/GravityRunGate"
	) as MechanismSlidingGate
	var mass_plate: PressurePlateSwitch = trial.get_node_or_null(
		"MomentumQuarryActors/BoulderMassPlate"
	) as PressurePlateSwitch

	_expect(player != null, "Momentum Quarry spawns Grace")
	_expect(flat_target != null, "Momentum Quarry builds the Flat Impact target")
	_expect(flat_gate != null, "Momentum Quarry builds the flat gate")
	_expect(gravity_gate != null, "Momentum Quarry builds the gravity gate")
	_expect(mass_plate != null, "Momentum Quarry builds the weighted Boulder plate")
	if (
		player == null
		or flat_target == null
		or flat_gate == null
		or gravity_gate == null
		or mass_plate == null
	):
		_finish(trial)
		return

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var current_ability: AbilityDefinition = (
		caster.call("get_current_ability") as AbilityDefinition
		if caster != null and caster.has_method("get_current_ability")
		else null
	)
	_expect(
		current_ability != null
		and current_ability.get_spell_id() == "boulder",
		"Momentum Quarry automatically equips Boulder"
	)

	var flat_serial: int = 11
	flat_target.set_meta("boulder_last_cast_serial", flat_serial)
	flat_target.set_meta("boulder_last_impact_speed", 5.2)
	flat_target.set_meta("boulder_last_impact_energy", 2163.2)
	trial.call("_evaluate_flat_run")
	var flat_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(flat_debug.get("stage", "")).to_lower() == "gravity_run",
		"one qualifying flat impact advances to the long grade"
	)
	_expect(
		int(flat_debug.get("flat_success_serial", 0)) == flat_serial
		and float(flat_debug.get("flat_success_speed", 0.0)) >= 5.0,
		"the trial records the flat Boulder impact"
	)
	_expect(flat_gate.is_mechanism_active(), "flat momentum opens the first gate")
	_expect(not gravity_gate.is_mechanism_active(), "the mastery route remains closed")

	var gravity_baseline: int = int(
		flat_debug.get("gravity_serial_baseline", 0)
	)
	var gravity_serial: int = gravity_baseline + 1
	var plate_boulder: Node = BoulderScene.instantiate()
	plate_boulder.name = "EarthBoulder_" + str(gravity_serial)
	trial.add_child(plate_boulder)
	plate_boulder.set_meta("boulder_cast_serial", gravity_serial)
	var plate_packet: Dictionary = {
		"body_masses": [
			{
				"name": plate_boulder.name,
				"instance_id": plate_boulder.get_instance_id(),
				"mass_kg": 160.0,
			}
		],
	}
	trial.call("_on_mass_plate_value_changed", 160.0, plate_packet)
	var gravity_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(gravity_debug.get("stage", "")).to_lower() == "mastery",
		"a fresh 160 kg Boulder on the lower plate advances to mastery"
	)
	_expect(
		int(gravity_debug.get("gravity_success_serial", 0)) == gravity_serial
		and is_equal_approx(
			float(gravity_debug.get("gravity_success_mass", 0.0)),
			160.0
		),
		"the trial records the downhill Boulder and supported mass"
	)
	_expect(gravity_gate.is_mechanism_active(), "the gravity run opens the mastery gate")

	trial.call("_on_mastery_area_entered", player)
	var complete_debug: Dictionary = trial.get_debug_data()
	_expect(
		bool(complete_debug.get("trial_complete", false)),
		"the mastery seal completes Momentum Quarry"
	)
	_expect(
		GameState.get_flag(COMPLETION_FLAG),
		"Momentum Quarry records Boulder mastery"
	)

	trial.reset_trial()
	await get_tree().process_frame
	var reset_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(reset_debug.get("stage", "")).to_lower() == "flat_momentum",
		"F8 reset returns to Flat Momentum"
	)
	_expect(not flat_gate.is_mechanism_active(), "reset closes the flat gate")
	_expect(not gravity_gate.is_mechanism_active(), "reset closes the gravity gate")
	_expect(
		is_equal_approx(mass_plate.get_mechanism_value(), 0.0),
		"reset clears the weighted plate"
	)
	_expect(
		get_tree().get_node_count_in_group("earth_boulder_effects") == 0,
		"reset removes every active Boulder"
	)
	_expect(
		not GameState.get_flag(COMPLETION_FLAG),
		"reset clears the temporary Boulder mastery flag"
	)
	_expect(
		GameState.get_stat("mana") == GameState.get_stat("max_mana"),
		"reset restores Mana for another Boulder"
	)

	_finish(trial)


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 80)
	GameState.set_stat("mana", 80)
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("BOULDER_SPELL_TRIAL_SMOKE_TEST: " + label)


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
		print("BOULDER_SPELL_TRIAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("BOULDER_SPELL_TRIAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
