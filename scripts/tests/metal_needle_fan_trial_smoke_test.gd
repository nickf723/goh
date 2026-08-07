extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_metal_needle_fan_spell_trial_v1.tscn"
)
const COMPLETION_FLAG: String = "needle_loom_metal_needle_trial_complete"

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_completion_flag: bool = false


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_completion_flag = GameState.get_flag(COMPLETION_FLAG)
	_prepare_stats()

	var trial: PrototypeMetalNeedleFanSpellTrial = (
		TrialScene.instantiate() as PrototypeMetalNeedleFanSpellTrial
	)
	add_child(trial)
	for _frame: int in range(22):
		await get_tree().process_frame
	await get_tree().physics_frame

	var player: CharacterBody3D = trial.get_node_or_null("Player") as CharacterBody3D
	var fan_targets: Array[CharacterBody3D] = []
	for target_index: int in range(5):
		var target: CharacterBody3D = trial.get_node_or_null(
			"NeedleLoomActors/FanTarget" + str(target_index + 1)
		) as CharacterBody3D
		if target != null:
			fan_targets.append(target)
	var close_target: CharacterBody3D = trial.get_node_or_null(
		"NeedleLoomActors/ClosePressTarget"
	) as CharacterBody3D
	var fan_gate: MechanismSlidingGate = trial.get_node_or_null(
		"NeedleLoomActors/BroadFanGate"
	) as MechanismSlidingGate
	var close_gate: MechanismSlidingGate = trial.get_node_or_null(
		"NeedleLoomActors/ClosePressGate"
	) as MechanismSlidingGate

	_expect(player != null, "Needle Loom spawns Grace")
	_expect(fan_targets.size() == 5, "Needle Loom builds five fan marks")
	_expect(close_target != null, "Needle Loom builds the Close Press")
	_expect(fan_gate != null, "Needle Loom builds the fan gate")
	_expect(close_gate != null, "Needle Loom builds the close gate")
	if (
		player == null
		or fan_targets.size() != 5
		or close_target == null
		or fan_gate == null
		or close_gate == null
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
		and current_ability.get_spell_id() == "metal_needle",
		"Needle Loom automatically equips Metal Needle"
	)

	var fan_serial: int = 11
	for target: CharacterBody3D in fan_targets:
		target.set_meta("metal_needle_fan_last_serial", fan_serial)
		target.set_meta("metal_needle_fan_hits_from_serial", 1)
	trial.call("_evaluate_broad_fan")
	var fan_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(fan_debug.get("stage", "")) == "the_close_press",
		"one shared volley serial advances to the Close Press"
	)
	_expect(
		int(fan_debug.get("fan_success_serial", 0)) == fan_serial,
		"the trial records the fan volley that reached every mark"
	)
	_expect(fan_gate.is_mechanism_active(), "the broad fan opens the first gate")
	_expect(not close_gate.is_mechanism_active(), "the mastery route remains closed")

	var close_baseline: int = int(fan_debug.get("close_serial_baseline", 0))
	var close_serial: int = close_baseline + 1
	close_target.set_meta("metal_needle_fan_last_serial", close_serial)
	close_target.set_meta("metal_needle_fan_hits_from_serial", 3)
	trial.call("_evaluate_close_press")
	var close_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(close_debug.get("stage", "")) == "mastery",
		"three close needles advance to mastery"
	)
	_expect(
		int(close_debug.get("close_success_serial", 0)) == close_serial
		and int(close_debug.get("close_success_hits", 0)) == 3,
		"the trial records the close multihit volley"
	)
	_expect(close_gate.is_mechanism_active(), "close pressure opens the mastery gate")

	trial.call("_on_mastery_area_entered", player)
	var complete_debug: Dictionary = trial.get_debug_data()
	_expect(bool(complete_debug.get("complete", false)), "mastery seal completes the Needle Loom")
	_expect(GameState.get_flag(COMPLETION_FLAG), "Needle Loom records Metal Needle mastery")

	trial.reset_trial()
	await get_tree().process_frame
	var reset_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(reset_debug.get("stage", "")) == "the_broad_fan",
		"F8 reset returns to The Broad Fan"
	)
	_expect(not fan_gate.is_mechanism_active(), "reset closes the fan gate")
	_expect(not close_gate.is_mechanism_active(), "reset closes the close gate")
	_expect(
		get_tree().get_node_count_in_group("metal_needle_fan_effects") == 0,
		"reset removes every active Metal Needle fan"
	)
	_expect(not GameState.get_flag(COMPLETION_FLAG), "reset clears the temporary mastery flag")
	_expect(
		GameState.get_stat("mana") == GameState.get_stat("max_mana"),
		"reset restores Mana for another volley"
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
	push_error("METAL_NEEDLE_FAN_TRIAL_SMOKE_TEST: " + label)


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
		print("METAL_NEEDLE_FAN_TRIAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("METAL_NEEDLE_FAN_TRIAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
