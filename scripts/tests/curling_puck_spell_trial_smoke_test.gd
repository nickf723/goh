extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_curling_puck_spell_trial_v1.tscn"
)
const TrailScript = preload(
	"res://scripts/actions/curling_ice_trail.gd"
)
const BoulderScene: PackedScene = preload(
	"res://scenes/actions/earth_boulder.tscn"
)

const COMPLETION_FLAG: String = "rime_rink_curling_puck_trial_complete"

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_completion_flag: bool = false


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_completion_flag = GameState.get_flag(COMPLETION_FLAG)
	_prepare_stats()

	var trial: PrototypeCurlingPuckSpellTrial = (
		TrialScene.instantiate() as PrototypeCurlingPuckSpellTrial
	)
	add_child(trial)
	await _wait_frames(24)
	await get_tree().physics_frame

	var player: CharacterBody3D = trial.get_node_or_null(
		"Player"
	) as CharacterBody3D
	var curl_gate: MechanismSlidingGate = trial.get_node_or_null(
		"RimeRinkActors/CurlRouteGate"
	) as MechanismSlidingGate
	var crossing_gate: MechanismSlidingGate = trial.get_node_or_null(
		"RimeRinkActors/FrozenCrossingGate"
	) as MechanismSlidingGate
	var momentum_gate: MechanismSlidingGate = trial.get_node_or_null(
		"RimeRinkActors/MomentumRunwayGate"
	) as MechanismSlidingGate
	var momentum_plate: PressurePlateSwitch = trial.get_node_or_null(
		"RimeRinkActors/CurlingMomentumPlate"
	) as PressurePlateSwitch
	var water_volume: SwimmingWaterVolume = trial.get_node_or_null(
		"RimeRinkActors/FreezableRinkPool"
	) as SwimmingWaterVolume

	_expect(player != null, "Rime Rink spawns Grace")
	_expect(curl_gate != null, "Rime Rink builds the curl gate")
	_expect(crossing_gate != null, "Rime Rink builds the crossing gate")
	_expect(momentum_gate != null, "Rime Rink builds the momentum gate")
	_expect(momentum_plate != null, "Rime Rink builds the weighted momentum plate")
	_expect(water_volume != null, "Rime Rink builds a freezable water volume")
	if (
		player == null
		or curl_gate == null
		or crossing_gate == null
		or momentum_gate == null
		or momentum_plate == null
		or water_volume == null
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
		and current_ability.get_spell_id() == "curling_puck",
		"Rime Rink automatically equips Curling Puck"
	)

	var curl_trail: CurlingIceTrail = TrailScript.new() as CurlingIceTrail
	curl_trail.name = "CurlRouteTestTrail"
	trial.add_child(curl_trail)
	player.set_meta("curling_puck_cast_serial", 1)
	player.set_meta("curling_puck_last_curl_sign", 1.0)
	curl_trail.configure(player, 1)
	for checkpoint: Vector3 in trial.curl_checkpoints:
		curl_trail.add_sample(checkpoint, Vector3.BACK)
	trial.call("_evaluate_curl_route")
	var curl_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(curl_debug.get("stage", "")) == "frozen_crossing",
		"one right-curled trail through all marks advances to the frozen crossing"
	)
	_expect(
		int(curl_debug.get("curl_success_serial", 0)) == 1,
		"the trial records the successful curling trail serial"
	)
	_expect(curl_gate.is_mechanism_active(), "the curl route opens its gate")
	_expect(not crossing_gate.is_mechanism_active(), "the water route remains closed")
	await _wait_frames(3)

	var water_trail: CurlingIceTrail = TrailScript.new() as CurlingIceTrail
	water_trail.name = "FrozenCrossingTestTrail"
	trial.add_child(water_trail)
	player.set_meta("curling_puck_cast_serial", 2)
	water_trail.configure(player, 2)
	water_trail.add_path_between(
		Vector3(0.0, 0.0, 16.8),
		Vector3(0.0, 0.0, 30.8),
		Vector3.BACK
	)
	player.position = Vector3(0.0, 1.0, 32.4)
	trial.call("_on_bridge_arrival_entered", player)
	var crossing_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(crossing_debug.get("stage", "")) == "momentum_runway",
		"a fresh frozen water path advances to the momentum runway"
	)
	_expect(
		int(crossing_debug.get("crossing_success_serial", 0)) == 2,
		"the trial records the water-bridge trail serial"
	)
	_expect(crossing_gate.is_mechanism_active(), "the frozen crossing opens its gate")
	_expect(not momentum_gate.is_mechanism_active(), "the mastery route remains closed")
	await _wait_frames(3)

	var momentum_trail: CurlingIceTrail = TrailScript.new() as CurlingIceTrail
	momentum_trail.name = "MomentumRunwayTestTrail"
	trial.add_child(momentum_trail)
	player.set_meta("curling_puck_cast_serial", 3)
	momentum_trail.configure(player, 3)
	momentum_trail.add_path_between(
		Vector3(0.0, 0.0, 40.0),
		Vector3(0.0, 0.0, 58.0),
		Vector3.BACK
	)
	var momentum_trail_debug: Dictionary = momentum_trail.get_debug_data()
	_expect(
		int(momentum_trail_debug.get("ground_segments", 0)) >= 10,
		"the momentum stage builds a qualifying ground ice runway"
	)

	var boulder: RigidBody3D = BoulderScene.instantiate() as RigidBody3D
	boulder.name = "EarthBoulder_1"
	trial.add_child(boulder)
	await get_tree().process_frame
	boulder.freeze = true
	boulder.set_meta("boulder_cast_serial", 1)
	boulder.set_meta("ice_curl_last_trail_serial_contact", 3)
	player.set_meta("boulder_cast_serial", 1)
	var plate_packet: Dictionary = {
		"body_masses": [
			{
				"name": str(boulder.name),
				"mass_kg": 160.0,
			}
		],
	}
	trial.call(
		"_on_momentum_plate_value_changed",
		160.0,
		plate_packet
	)
	var momentum_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(momentum_debug.get("stage", "")) == "mastery",
		"a fresh Boulder that touched fresh ice advances to mastery"
	)
	_expect(
		int(momentum_debug.get("momentum_success_trail_serial", 0)) == 3
		and int(momentum_debug.get("momentum_success_boulder_serial", 0)) == 1,
		"the trial records both halves of the Puck-to-Boulder combo"
	)
	_expect(
		is_equal_approx(
			float(momentum_debug.get("momentum_success_mass", 0.0)),
			160.0
		),
		"the weighted plate records the Boulder's full supported mass"
	)
	_expect(momentum_gate.is_mechanism_active(), "the momentum runway opens the mastery gate")

	trial.call("_on_mastery_area_entered", player)
	var complete_debug: Dictionary = trial.get_debug_data()
	_expect(bool(complete_debug.get("trial_complete", false)), "the gold seal completes the Rime Rink")
	_expect(GameState.get_flag(COMPLETION_FLAG), "Rime Rink records Curling Puck mastery")

	trial.reset_trial()
	await _wait_frames(4)
	var reset_debug: Dictionary = trial.get_debug_data()
	_expect(
		str(reset_debug.get("stage", "")) == "curl_route",
		"F8 reset returns to the curling route"
	)
	_expect(not curl_gate.is_mechanism_active(), "reset closes the curl gate")
	_expect(not crossing_gate.is_mechanism_active(), "reset closes the crossing gate")
	_expect(not momentum_gate.is_mechanism_active(), "reset closes the momentum gate")
	_expect(
		get_tree().get_node_count_in_group("curling_puck_effects") == 0
		and get_tree().get_node_count_in_group("curling_ice_trails") == 0,
		"reset removes every puck and temporary ice trail"
	)
	_expect(
		get_tree().get_node_count_in_group("earth_boulder_effects") == 0,
		"reset removes the momentum Boulder"
	)
	_expect(not GameState.get_flag(COMPLETION_FLAG), "reset clears the temporary mastery flag")
	_expect(
		GameState.get_stat("mana") == GameState.get_stat("max_mana"),
		"reset restores Mana for another curling run"
	)

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
	push_error("CURLING_PUCK_TRIAL_SMOKE_TEST: " + label)


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
		print("CURLING_PUCK_TRIAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CURLING_PUCK_TRIAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
