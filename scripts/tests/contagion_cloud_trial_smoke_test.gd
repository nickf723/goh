extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_contagion_cloud_spell_trial_v1.tscn"
)
const ContagionAbility: AbilityDefinition = preload(
	"res://data/abilities/contagion_cloud_ability.tres"
)
const COMPLETION_FLAG: String = (
	"pestilent_procession_contagion_cloud_trial_complete"
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

	var trial: PrototypeContagionCloudSpellTrial = (
		TrialScene.instantiate() as PrototypeContagionCloudSpellTrial
	)
	add_child(trial)
	for _frame: int in range(22):
		await get_tree().process_frame
	await get_tree().physics_frame

	var player: CharacterBody3D = trial.get_node_or_null(
		"Player"
	) as CharacterBody3D
	var targets: Array[CharacterBody3D] = []
	for target_index: int in range(3):
		var target: CharacterBody3D = trial.get_node_or_null(
			"PestilentProcessionActors/ProcessionWitness"
			+ str(target_index + 1)
		) as CharacterBody3D
		if target != null:
			targets.append(target)
	var procession_gate: MechanismSlidingGate = trial.get_node_or_null(
		"PestilentProcessionActors/ProcessionGate"
	) as MechanismSlidingGate
	var race_gate: MechanismSlidingGate = trial.get_node_or_null(
		"PestilentProcessionActors/OutpaceGate"
	) as MechanismSlidingGate
	_expect(player != null, "Pestilent Procession spawns Grace")
	_expect(targets.size() == 3, "Pestilent Procession builds three witnesses")
	_expect(procession_gate != null, "Pestilent Procession builds the first gate")
	_expect(race_gate != null, "Pestilent Procession builds the race gate")
	if (
		player == null
		or targets.size() != 3
		or procession_gate == null
		or race_gate == null
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
		and current_ability.get_spell_id() == "contagion_cloud",
		"Pestilent Procession automatically equips Contagion Cloud"
	)

	# The first room requires the same cloud serial on all three targets.
	var procession_test_serial: int = 7
	for target: CharacterBody3D in targets:
		target.set_meta(
			"contagion_cloud_last_serial",
			procession_test_serial
		)
	trial.call("_evaluate_procession")
	var procession_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(procession_debug.get("stage", "")) == "outpace_the_plume",
		"one shared infection serial advances to Outpace the Plume"
	)
	_expect(
		int(procession_debug.get("procession_serial", 0))
		== procession_test_serial,
		"the trial records the cloud that crossed every witness"
	)
	_expect(
		procession_gate.is_mechanism_active(),
		"the unbroken moving front opens the first gate"
	)
	_expect(
		not race_gate.is_mechanism_active(),
		"the mastery route remains closed after stage one"
	)

	# Cast a real cloud from the race mark, let it travel, then place Grace at the
	# finish while the slower cloud remains behind.
	player.global_position = Vector3(0.0, 1.0, 18.5)
	player.velocity = Vector3.ZERO
	var race_cloud: ContagionCloud = (
		ContagionAbility.ability_scene.instantiate() as ContagionCloud
	)
	_expect(race_cloud != null, "race fixture creates a real Contagion Cloud")
	if race_cloud == null:
		_finish(trial)
		return
	race_cloud.set_payload(ContagionAbility.get_action_payload())
	race_cloud.set_source_actor(player)
	trial.add_child(race_cloud)
	race_cloud.execute(player, Vector3(0.0, 0.0, 1.0))
	race_cloud.set_physics_process(false)
	for _tick: int in range(16):
		race_cloud.advance_cloud(0.1)
		await get_tree().physics_frame
	var race_cloud_debug: Dictionary = race_cloud.get_debug_data()
	_expect(
		float(race_cloud_debug.get("distance_travelled", 0.0)) >= 3.0,
		"the race cloud establishes a real moving front"
	)
	_expect(
		race_cloud.global_position.z < 31.0,
		"the slow cloud remains behind the finish line"
	)
	player.global_position = Vector3(0.0, 1.0, 31.0)
	trial.call("_on_race_finish_entered", player)
	var race_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(race_debug.get("stage", "")) == "mastery",
		"Grace reaching the line ahead of an active cloud completes the race"
	)
	_expect(
		race_gate.is_mechanism_active(),
		"outpacing the plume opens the mastery route"
	)
	_expect(
		int(race_debug.get("successful_race_serial", 0))
		== int(race_cloud_debug.get("cast_serial", -1)),
		"the trial records the active cloud Grace outran"
	)
	_expect(
		race_cloud.is_cloud_active(),
		"race success does not destroy the still-timed cloud"
	)

	trial.call("_on_mastery_area_entered", player)
	var complete_debug: Dictionary = trial.get_debug_data()
	_expect(
		bool(complete_debug.get("complete", false)),
		"the mastery seal completes the Pestilent Procession"
	)
	_expect(
		GameState.get_flag(COMPLETION_FLAG),
		"the trial records Contagion Cloud mastery"
	)

	trial.reset_trial()
	await get_tree().process_frame
	var reset_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(reset_debug.get("stage", "")) == "unbroken_front",
		"F8 reset returns to the first procession room"
	)
	_expect(
		not procession_gate.is_mechanism_active(),
		"reset closes the procession gate"
	)
	_expect(not race_gate.is_mechanism_active(), "reset closes the race gate")
	_expect(
		get_tree().get_node_count_in_group("contagion_cloud_effects") == 0,
		"reset removes every active Contagion Cloud"
	)
	_expect(
		not GameState.get_flag(COMPLETION_FLAG),
		"reset clears the temporary mastery flag"
	)
	_expect(
		GameState.get_stat("mana") == GameState.get_stat("max_mana"),
		"reset restores Mana for another procession"
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
	push_error("CONTAGION_CLOUD_TRIAL_SMOKE_TEST: " + label)


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
		print("CONTAGION_CLOUD_TRIAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CONTAGION_CLOUD_TRIAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
