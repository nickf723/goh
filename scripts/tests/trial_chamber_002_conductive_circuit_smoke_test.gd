extends Node

const TrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/trial_chamber_002_conductive_circuit_v1.tscn"
)
const WaterJetPayload: DamagePayload = preload(
	"res://data/damage_payloads/water_jet_payload.tres"
)
const LightningSparkPayload: DamagePayload = preload(
	"res://data/damage_payloads/lightning_spark_payload.tres"
)

var failures: Array[String] = []
var trial: Node
var player: Node3D


func _ready() -> void:
	GameState.reset_run()
	trial = TrialScene.instantiate()
	add_child(trial)
	for _index: int in range(14):
		await get_tree().process_frame
	await get_tree().physics_frame
	player = trial.get_node_or_null("Player") as Node3D

	_validate_structure()
	_validate_fixed_loadout()
	await _validate_puzzle_one_metal_link()
	await _validate_puzzle_two_water_path()
	await _validate_optional_cache()
	await _validate_puzzle_three_synthesis()
	await _validate_completion_and_reset()

	if trial != null and is_instance_valid(trial):
		trial.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_structure() -> void:
	_expect(trial != null, "Trial 002 scene instantiates")
	if trial == null:
		return
	_expect(trial.is_in_group("trial_chambers"), "Trial 002 joins trial_chambers")
	var architecture: Node = trial.get_node_or_null("TrialArchitecture")
	_expect(architecture != null, "Trial 002 owns one architecture root")
	if architecture == null:
		return
	for path: String in [
		"PuzzleOneMetalLink",
		"GateOne",
		"PuzzleTwoWaterPath",
		"GateTwo",
		"OptionalCacheAlcove",
		"OptionalRewardChest",
		"PuzzleThreeSynthesis",
		"FinalGate",
		"CompletionSeal",
		"CompletionBeacon",
		"Ceiling",
	]:
		_expect(architecture.get_node_or_null(path) != null, "Trial 002 contains " + path)
	_expect(player != null, "Trial 002 contains canonical Player")
	_expect(trial.get_node_or_null("GameUI") != null, "Trial 002 contains canonical GameUI")
	_expect(int(trial.get("stage")) == 0, "Trial 002 begins on the metal-link puzzle")


func _validate_fixed_loadout() -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "Trial 002 resolves AbilityCaster")
	if caster != null:
		var loadout_value: Variant = caster.get("loadout")
		_expect(loadout_value is AbilityLoadout, "Trial 002 assigns an AbilityLoadout")
		if loadout_value is AbilityLoadout:
			var loadout := loadout_value as AbilityLoadout
			var ids: Array[String] = []
			for ability: AbilityDefinition in loadout.get_learned_abilities():
				if ability != null:
					ids.append(ability.get_spell_id())
			ids.sort()
			_expect(
				ids == ["lightning_spark", "metal_tether", "water_jet"],
				"Trial 002 loadout is exactly Metal Tether + Water Jet + Lightning Spark"
			)
			_expect(loadout.get_equipped_ability_count() == 3, "Trial 002 equips exactly three spells")

	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	_expect(aerial != null, "Trial 002 resolves AerialLocomotion")
	if aerial != null:
		_expect(not bool(aerial.get("double_jump_unlocked")), "Trial 002 disables double jump bypass")
		_expect(not bool(aerial.get("hover_unlocked")), "Trial 002 disables hover bypass")
		_expect(not bool(aerial.get("flight_unlocked")), "Trial 002 disables flight bypass")


func _validate_puzzle_one_metal_link() -> void:
	var data: Dictionary = trial.get("puzzle_one") as Dictionary
	var solver: DCCircuitSolver = data.get("solver") as DCCircuitSolver
	var bridge: RigidBody3D = data.get("metal_bridge") as RigidBody3D
	var source: Node = data.get("source") as Node
	_expect(solver != null, "Puzzle I owns a real DC solver")
	_expect(bridge != null, "Puzzle I owns a movable copper link")
	_expect(source != null, "Puzzle I owns a Lightning excitation port")
	if solver == null or bridge == null or source == null:
		return
	_expect(bridge.get_node_or_null("MetalTetherAnchor") != null, "Puzzle I copper link exposes a Metal Tether anchor")
	_expect(not solver.circuit_closed, "Puzzle I begins as an open circuit")

	bridge.position.z = float(data.get("metal_target_z", bridge.position.z))
	bridge.linear_velocity = Vector3.ZERO
	solver.request_solve()
	await get_tree().process_frame
	_expect(not solver.circuit_closed, "placing copper alone does not power a source-less circuit")

	source.call("receive_damage_payload", LightningSparkPayload.duplicate(true))
	await _wait_for_circuit()
	_expect(bool(data.get("solved", false)), "Puzzle I completes when the placed copper link carries a Lightning pulse")
	_expect(int(trial.get("stage")) == 1, "Puzzle I advances to the water-path stage")
	var gate: Node = trial.get("gate_one") as Node
	_expect(gate != null and bool(gate.get_meta("barrier_open", false)), "Puzzle I opens Gate One")


func _validate_puzzle_two_water_path() -> void:
	var data: Dictionary = trial.get("puzzle_two") as Dictionary
	var target: Node = data.get("wet_target") as Node
	var component: CircuitComponent = data.get("wet_component") as CircuitComponent
	var source: Node = data.get("source") as Node
	_expect(target != null, "Puzzle II owns a dry water channel target")
	_expect(component != null, "Puzzle II water channel is a real CircuitComponent")
	_expect(source != null, "Puzzle II owns a Lightning excitation port")
	if target == null or component == null or source == null:
		return
	_expect(component.material_profile != null and component.material_profile.material_id == "water", "Puzzle II uses the shared water material profile")
	_expect(not component.path_enabled, "Puzzle II water path begins dry and nonconductive")

	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	_expect(payload_receiver != null, "Puzzle II water channel exposes PayloadReceiver")
	if payload_receiver == null:
		return
	payload_receiver.call("receive_payload", WaterJetPayload.duplicate(true))
	await get_tree().process_frame
	_expect(bool(data.get("water_latched", false)), "Water Jet fills Puzzle II channel")
	_expect(component.path_enabled, "filled Puzzle II channel joins the DC topology")
	_expect(int(trial.get("stage")) == 1, "Water alone does not finish Puzzle II")

	source.call("receive_damage_payload", LightningSparkPayload.duplicate(true))
	await _wait_for_circuit()
	_expect(bool(data.get("solved", false)), "Puzzle II completes when the water path carries Lightning")
	_expect(int(trial.get("stage")) == 2, "Puzzle II advances to synthesis")
	var gate: Node = trial.get("gate_two") as Node
	_expect(gate != null and bool(gate.get_meta("barrier_open", false)), "Puzzle II opens Gate Two")


func _validate_optional_cache() -> void:
	var stage_before: int = int(trial.get("stage"))
	var data: Dictionary = trial.get("optional_circuit") as Dictionary
	var bridge: RigidBody3D = data.get("metal_bridge") as RigidBody3D
	var source: Node = data.get("source") as Node
	var chest: Node = trial.get_node_or_null("TrialArchitecture/OptionalRewardChest")
	_expect(bridge != null and source != null, "optional cache uses a live movable-link circuit")
	_expect(chest != null, "optional cache owns a reward chest")
	if bridge == null or source == null or chest == null:
		return
	_expect(bool(chest.get("locked")), "optional reward begins locked")

	bridge.position.z = float(data.get("metal_target_z", bridge.position.z))
	bridge.linear_velocity = Vector3.ZERO
	var solver: DCCircuitSolver = data.get("solver") as DCCircuitSolver
	if solver != null:
		solver.request_solve()
	source.call("receive_damage_payload", LightningSparkPayload.duplicate(true))
	await _wait_for_circuit()
	_expect(bool(trial.get("optional_cache_powered")), "optional circuit powers its cache")
	_expect(not bool(chest.get("locked")), "optional circuit unlocks the reward chest")
	_expect(int(trial.get("stage")) == stage_before, "optional circuit never advances main progression")


func _validate_puzzle_three_synthesis() -> void:
	var data: Dictionary = trial.get("puzzle_three") as Dictionary
	var bridge: RigidBody3D = data.get("metal_bridge") as RigidBody3D
	var wet_target: Node = data.get("wet_target") as Node
	var wet_component: CircuitComponent = data.get("wet_component") as CircuitComponent
	var source: Node = data.get("source") as Node
	_expect(bridge != null, "Puzzle III contains a movable copper link")
	_expect(wet_target != null and wet_component != null, "Puzzle III contains a water path")
	_expect(source != null, "Puzzle III contains a Lightning input")
	if bridge == null or wet_target == null or wet_component == null or source == null:
		return

	bridge.position.z = float(data.get("metal_target_z", bridge.position.z))
	bridge.linear_velocity = Vector3.ZERO
	var solver: DCCircuitSolver = data.get("solver") as DCCircuitSolver
	if solver != null:
		solver.request_solve()
	source.call("receive_damage_payload", LightningSparkPayload.duplicate(true))
	await _wait_for_circuit()
	_expect(int(trial.get("stage")) == 2, "metal alone cannot solve the synthesis circuit")

	var payload_receiver: Node = wet_target.get_node_or_null("PayloadReceiver")
	_expect(payload_receiver != null, "Puzzle III water path exposes PayloadReceiver")
	if payload_receiver == null:
		return
	payload_receiver.call("receive_payload", WaterJetPayload.duplicate(true))
	await get_tree().process_frame
	_expect(bool(data.get("water_latched", false)), "Puzzle III latches its water conduit")

	source.call("receive_damage_payload", LightningSparkPayload.duplicate(true))
	await _wait_for_circuit()
	_expect(bool(data.get("solved", false)), "Puzzle III requires metal + water + Lightning in one complete loop")
	_expect(int(trial.get("stage")) == 3, "Puzzle III releases the final passage")
	var gate: Node = trial.get("final_gate") as Node
	_expect(gate != null and bool(gate.get_meta("barrier_open", false)), "Puzzle III opens the final gate")


func _validate_completion_and_reset() -> void:
	if player != null:
		trial.call("_on_goal_body_entered", player)
	await get_tree().process_frame
	_expect(bool(trial.get("trial_complete")), "reaching the seal after synthesis completes Trial 002")
	_expect(GameState.get_flag("trial_chamber_002_conductive_circuit_complete"), "Trial 002 writes its completion flag")

	trial.call("reset_trial")
	await get_tree().process_frame
	await get_tree().physics_frame
	_expect(int(trial.get("stage")) == 0, "reset returns Trial 002 to Puzzle I")
	_expect(not bool(trial.get("trial_complete")), "reset clears Trial 002 completion")
	_expect(not GameState.get_flag("trial_chamber_002_conductive_circuit_complete"), "reset clears Trial 002 completion flag")
	var p1: Dictionary = trial.get("puzzle_one") as Dictionary
	var p2: Dictionary = trial.get("puzzle_two") as Dictionary
	var p3: Dictionary = trial.get("puzzle_three") as Dictionary
	var p1_bridge: RigidBody3D = p1.get("metal_bridge") as RigidBody3D
	_expect(p1_bridge != null and absf(p1_bridge.position.z) < 0.05, "reset returns Puzzle I copper link to its starting rail position")
	_expect(not bool(p2.get("water_latched", false)), "reset drains Puzzle II water channel")
	_expect(not bool(p3.get("water_latched", false)), "reset drains Puzzle III water channel")
	var gate_one: Node = trial.get("gate_one") as Node
	var gate_two: Node = trial.get("gate_two") as Node
	var final_gate: Node = trial.get("final_gate") as Node
	_expect(gate_one != null and not bool(gate_one.get_meta("barrier_open", true)), "reset restores Gate One")
	_expect(gate_two != null and not bool(gate_two.get_meta("barrier_open", true)), "reset restores Gate Two")
	_expect(final_gate != null and not bool(final_gate.get_meta("barrier_open", true)), "reset restores final gate")
	if player != null:
		_expect(player.global_position.distance_to(Vector3(0.0, 1.0, 29.0)) < 0.2, "reset returns Grace to Trial 002 entrance")


func _wait_for_circuit() -> void:
	for _index: int in range(5):
		await get_tree().process_frame
	await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("TRIAL_CHAMBER_002_CONDUCTIVE_CIRCUIT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("TRIAL_CHAMBER_002_CONDUCTIVE_CIRCUIT_SMOKE_TEST: " + failure)
	get_tree().quit(1)
