extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_curling_puck_spell_trial_v1.tscn"
)
const ReadyTrailScript = preload(
	"res://scripts/actions/curling_ice_trail_ready.gd"
)
const BoulderScene: PackedScene = preload(
	"res://scenes/actions/earth_boulder.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()

	var trial: PrototypeCurlingPuckSpellTrialGateReady = (
		TrialScene.instantiate() as PrototypeCurlingPuckSpellTrialGateReady
	)
	add_child(trial)
	await _wait_frames(24)
	await get_tree().physics_frame

	var player: CharacterBody3D = trial.get_node_or_null("Player") as CharacterBody3D
	var curl_gate: MechanismSlidingGate = trial.get_node_or_null(
		"RimeRinkActors/CurlRouteGate"
	) as MechanismSlidingGate
	var crossing_gate: MechanismSlidingGate = trial.get_node_or_null(
		"RimeRinkActors/FrozenCrossingGate"
	) as MechanismSlidingGate
	var momentum_gate: MechanismSlidingGate = trial.get_node_or_null(
		"RimeRinkActors/MomentumRunwayGate"
	) as MechanismSlidingGate
	var plate: PressurePlateSwitch = trial.get_node_or_null(
		"RimeRinkActors/CurlingMomentumPlate"
	) as PressurePlateSwitch
	_expect(player != null, "Rime reliability fixture resolves Grace")
	_expect(curl_gate != null, "Rime reliability fixture resolves the curl gate")
	_expect(crossing_gate != null, "Rime reliability fixture resolves the crossing gate")
	_expect(momentum_gate != null, "Rime reliability fixture resolves the momentum gate")
	_expect(plate != null, "Rime reliability fixture resolves the weighted plate")
	if player == null or curl_gate == null or crossing_gate == null or momentum_gate == null or plate == null:
		_finish(trial)
		return

	var curl_trail: CurlingIceTrailReady = ReadyTrailScript.new() as CurlingIceTrailReady
	curl_trail.name = "ReliableCurlTrail"
	trial.add_child(curl_trail)
	player.set_meta("curling_puck_cast_serial", 1)
	curl_trail.configure(player, 1)
	curl_trail.set_meta("curling_puck_curl_sign", 1.0)
	for checkpoint: Vector3 in trial.curl_checkpoints:
		curl_trail.add_sample(checkpoint, Vector3.BACK)
	trial.evaluate_gate_progression_now()
	await _wait_frames(2)
	_expect(curl_gate.is_mechanism_active(), "a valid curled route opens the first door")
	_expect(
		bool(curl_gate.get_debug_data().get("collision_disabled", false)),
		"the first open door no longer blocks Grace"
	)
	_expect(
		str(trial.get_debug_data().get("stage", "")) == "frozen_crossing",
		"the reliable curl advances exactly once"
	)
	await _wait_frames(3)

	var water_trail: CurlingIceTrailReady = ReadyTrailScript.new() as CurlingIceTrailReady
	water_trail.name = "ReliableWaterTrail"
	trial.add_child(water_trail)
	player.set_meta("curling_puck_cast_serial", 2)
	water_trail.configure(player, 2)
	water_trail.add_path_between(
		Vector3(0.0, 0.0, 16.8),
		Vector3(0.0, 0.0, 30.8),
		Vector3.BACK
	)
	player.global_position = Vector3(0.0, 1.0, 32.4)
	trial.evaluate_gate_progression_now()
	await _wait_frames(2)
	_expect(crossing_gate.is_mechanism_active(), "a frozen route and far-shore arrival open the second door")
	_expect(
		bool(crossing_gate.get_debug_data().get("collision_disabled", false)),
		"the second open door no longer blocks Grace"
	)
	_expect(
		str(trial.get_debug_data().get("stage", "")) == "momentum_runway",
		"the reliable shore check advances even without a one-frame Area signal"
	)
	await _wait_frames(3)

	var runway: CurlingIceTrailReady = ReadyTrailScript.new() as CurlingIceTrailReady
	runway.name = "ReliableMomentumTrail"
	trial.add_child(runway)
	player.set_meta("curling_puck_cast_serial", 3)
	runway.configure(player, 3)
	runway.add_path_between(
		Vector3(0.0, 0.0, 40.0),
		Vector3(0.0, 0.0, 58.0),
		Vector3.BACK
	)
	var boulder: RigidBody3D = BoulderScene.instantiate() as RigidBody3D
	boulder.name = "ReliableMomentumBoulder"
	boulder.position = plate.position + Vector3.UP * 1.15
	trial.add_child(boulder)
	await get_tree().process_frame
	boulder.freeze = true
	boulder.set_meta("boulder_cast_serial", 1)
	boulder.set_meta("ice_curl_last_trail_serial_contact", 3)
	player.set_meta("boulder_cast_serial", 1)
	plate.set_simulated_mass_kg(160.0, true)
	trial.evaluate_gate_progression_now()
	await _wait_frames(2)
	_expect(momentum_gate.is_mechanism_active(), "a fresh ice-carried Boulder opens the third door")
	_expect(
		bool(momentum_gate.get_debug_data().get("collision_disabled", false)),
		"the third open door no longer blocks Grace"
	)
	_expect(
		str(trial.get_debug_data().get("stage", "")) == "mastery",
		"the weighted plate is retried after late trail metadata"
	)
	_expect(
		int(trial.get_debug_data().get("reliable_gate_opens", 0)) == 3,
		"all three doors report one reliable opening"
	)

	trial.reset_trial()
	await _wait_frames(4)
	_expect(not curl_gate.is_mechanism_active(), "reset closes the first door")
	_expect(not crossing_gate.is_mechanism_active(), "reset closes the second door")
	_expect(not momentum_gate.is_mechanism_active(), "reset closes the third door")

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
	push_error("CURLING_PUCK_GATE_RELIABILITY_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))


func _finish(trial: Node) -> void:
	Engine.time_scale = 1.0
	_restore_state()
	if trial != null and is_instance_valid(trial):
		trial.queue_free()
	if failures.is_empty():
		print("CURLING_PUCK_GATE_RELIABILITY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CURLING_PUCK_GATE_RELIABILITY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
