extends Node

const ChamberScene: PackedScene = preload(
	"res://scenes/environment/church/church_trial_chamber_of_accord_v1.tscn"
)
const ChurchTrialScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn"
)
const COMPLETION_FLAG: String = (
	"church_trial_chamber_of_accord_complete"
)

var failures: Array[String] = []
var fixture: Node3D


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	GameState.reset_run()
	GameState.set_flag(COMPLETION_FLAG, false)
	fixture = Node3D.new()
	fixture.name = "ChamberOfAccordFixture"
	add_child(fixture)
	await _test_standalone_chamber_behavior()
	await _test_church_trial_integration()
	GameState.set_flag(COMPLETION_FLAG, false)
	if fixture != null and is_instance_valid(fixture):
		fixture.queue_free()
	await get_tree().process_frame
	_finish()


func _test_standalone_chamber_behavior() -> void:
	var chamber: ChurchTrialChamberOfAccord = (
		ChamberScene.instantiate() as ChurchTrialChamberOfAccord
	)
	_expect(chamber != null, "Chamber of Accord scene instantiates")
	if chamber == null:
		return
	chamber.name = "StandaloneChamber"
	fixture.add_child(chamber)
	await _wait_physics_frames(6)
	await _wait_frames(5)

	var left_plate: PressurePlateSwitch = chamber.get_node_or_null(
		"Mechanisms/LeftOfferingScale"
	) as PressurePlateSwitch
	var right_plate: PressurePlateSwitch = chamber.get_node_or_null(
		"Mechanisms/RightOfferingScale"
	) as PressurePlateSwitch
	var water_altar: MechanismElementSensor = chamber.get_node_or_null(
		"Mechanisms/WaterRiteAltar"
	) as MechanismElementSensor
	var fire_altar: MechanismElementSensor = chamber.get_node_or_null(
		"Mechanisms/FireRiteAltar"
	) as MechanismElementSensor
	var balance: MechanismValueComparator = chamber.get_node_or_null(
		"SignalNetwork/ScaleBalanceComparator"
	) as MechanismValueComparator
	var sequence: MechanismLogicNode = chamber.get_node_or_null(
		"SignalNetwork/ElementalRiteSequence"
	) as MechanismLogicNode
	var completion: MechanismLogicNode = chamber.get_node_or_null(
		"SignalNetwork/AccordCompletionLatch"
	) as MechanismLogicNode
	var gate: MechanismSlidingGate = chamber.get_node_or_null(
		"Mechanisms/AccordPassageGate"
	) as MechanismSlidingGate

	_expect(
		left_plate != null
		and right_plate != null
		and water_altar != null
		and fire_altar != null
		and balance != null
		and sequence != null
		and completion != null
		and gate != null,
		"standalone chamber contains its complete mechanism graph"
	)
	if (
		left_plate == null
		or right_plate == null
		or water_altar == null
		or fire_altar == null
		or balance == null
		or sequence == null
		or completion == null
		or gate == null
	):
		chamber.queue_free()
		await get_tree().process_frame
		return

	_expect(not left_plate.active and not right_plate.active, "offering scales begin released")
	_expect(is_equal_approx(left_plate.get_mechanism_value(), 0.0), "left scale begins at zero kilograms")
	_expect(is_equal_approx(right_plate.get_mechanism_value(), 0.0), "right scale begins at zero kilograms")
	_expect(not gate.active, "passage gate begins sealed")
	_expect(not GameState.get_flag(COMPLETION_FLAG), "chamber completion begins transient and unsaved")

	var soul_weight_count: int = 0
	for node_name: String in ["OfferingII", "OfferingIII", "OfferingV"]:
		var weight: MechanismWeightBlock = chamber.get_node_or_null(
			"Mechanisms/" + node_name
		) as MechanismWeightBlock
		_expect(weight != null, node_name + " exists as a reusable weight")
		if weight == null:
			continue
		var soul: SoulManipulable = weight.get_node_or_null(
			"SoulManipulable"
		) as SoulManipulable
		_expect(soul != null and soul.can_begin_manipulation(), node_name + " is Soul-Grippable")
		if soul != null:
			soul_weight_count += 1
	_expect(soul_weight_count == 3, "all three offerings expose Soul Grip")

	left_plate.set_simulated_mass_kg(5.0)
	right_plate.set_simulated_mass_kg(4.0)
	await _wait_frames(2)
	_expect(not balance.active, "unequal offerings do not power the rite")
	right_plate.set_simulated_mass_kg(5.0)
	await _wait_frames(2)
	_expect(balance.active, "V equals II plus III and powers the rite")

	await _pulse_altar(fire_altar, "wrong_fire_first")
	_expect(sequence.sequence_index == 0, "Fire-first input does not advance the rite")
	_expect(sequence.sequence_wrong_input_count == 1, "Fire-first input records a wrong sequence attempt")
	_expect(not completion.active and not gate.active, "wrong order cannot open the passage")

	await _pulse_altar(water_altar, "water_before_balance_loss")
	_expect(sequence.sequence_index == 1, "Water advances the balanced rite to its second step")
	right_plate.set_simulated_mass_kg(4.0)
	await _wait_frames(2)
	_expect(sequence.sequence_index == 0, "losing balance clears an unfinished elemental attempt")
	_expect(chamber.balance_loss_reset_count == 1, "chamber records the balance-loss reset")

	right_plate.set_simulated_mass_kg(5.0)
	await _wait_frames(2)
	await _pulse_altar(water_altar, "correct_water")
	_expect(sequence.sequence_index == 1, "correct Water input begins the final rite")
	await _pulse_altar(fire_altar, "correct_fire")
	await _wait_frames(3)
	_expect(sequence.memory_active, "Water then Fire completes sequence memory")
	_expect(completion.active, "balanced completed rite activates the completion latch")
	_expect(gate.active, "completion latch opens the Church passage")
	_expect(GameState.get_flag(COMPLETION_FLAG), "completion latch writes the durable Church flag")

	left_plate.set_simulated_mass_kg(0.0)
	right_plate.set_simulated_mass_kg(0.0)
	await _wait_frames(2)
	_expect(gate.active, "moving offerings after completion cannot reseal the passage")

	chamber.queue_free()
	await get_tree().process_frame

	var restored: ChurchTrialChamberOfAccord = (
		ChamberScene.instantiate() as ChurchTrialChamberOfAccord
	)
	restored.name = "RestoredChamber"
	fixture.add_child(restored)
	await _wait_physics_frames(4)
	await _wait_frames(5)
	var restored_gate: MechanismSlidingGate = restored.get_node_or_null(
		"Mechanisms/AccordPassageGate"
	) as MechanismSlidingGate
	var restored_completion: MechanismLogicNode = restored.get_node_or_null(
		"SignalNetwork/AccordCompletionLatch"
	) as MechanismLogicNode
	_expect(
		restored_completion != null and restored_completion.active,
		"a new chamber instance restores completion from the saved story flag"
	)
	_expect(restored_gate != null and restored_gate.active, "restored completion reopens the passage")
	_expect(
		restored.elemental_sequence != null
		and restored.elemental_sequence.sequence_index == 0,
		"partial elemental progress is not persisted with completion"
	)

	restored.reset_chamber(true)
	await _wait_frames(3)
	_expect(not GameState.get_flag(COMPLETION_FLAG), "explicit fresh reset clears the completion flag")
	_expect(restored_gate != null and not restored_gate.active, "fresh reset reseals the passage")
	_expect(
		restored.left_plate != null
		and restored.right_plate != null
		and is_equal_approx(restored.left_plate.get_mechanism_value(), 0.0)
		and is_equal_approx(restored.right_plate.get_mechanism_value(), 0.0),
		"fresh reset clears both scale values"
	)

	restored.queue_free()
	await get_tree().process_frame


func _test_church_trial_integration() -> void:
	GameState.set_flag(COMPLETION_FLAG, false)
	var church: Node = ChurchTrialScene.instantiate()
	_expect(church != null, "Church Trial scene instantiates with Chamber integration")
	if church == null:
		return
	church.name = "ChurchTrialAccordFixture"
	church.set("apply_save_on_ready", false)
	church.set("add_guard_test_enemy", false)
	add_child(church)
	await _wait_physics_frames(8)
	await _wait_frames(8)

	var room: Node = church.get_node_or_null("Room3Puzzle")
	var chamber: ChurchTrialChamberOfAccord = church.get_node_or_null(
		"Room3Puzzle/ChamberOfAccord"
	) as ChurchTrialChamberOfAccord
	_expect(room != null, "Church Trial retains its third puzzle room")
	_expect(chamber != null, "Church Trial installs the packed Chamber of Accord")
	if room != null:
		_expect(room.get_node_or_null("WaterLockTarget") == null, "legacy Water cube is removed from the production route")
		_expect(room.get_node_or_null("FireLockTarget") == null, "legacy Fire cube is removed from the production route")
		_expect(room.get_node_or_null("ElementLockController") == null, "legacy double-lock controller is removed at runtime")
		_expect(room.get_node_or_null("PuzzleGate") == null, "legacy lock gate is replaced by the chamber seal")

	_expect(church.get_node_or_null("SoundTrialTransition") != null, "Sound transition remains installed beyond the chamber")
	_expect(church.get_node_or_null("Room4Boss/AnimatedArmorBoss") != null, "Animated Armor boss remains in the production route")
	_expect(church.get_node_or_null("Room4Boss/BossSaveBed") != null, "boss save bed remains available")
	_expect(church.get_node_or_null("ChurchTrialRewardAltar") != null, "Church Trial reward altar remains available")
	_expect(church.get_node_or_null("Room4Boss/LevelExit") != null, "final Church exit remains available")

	if chamber != null:
		var debug: Dictionary = chamber.get_debug_data()
		_expect(bool(debug.get("church_trial_chamber_of_accord", false)), "integrated chamber exposes its debug contract")
		_expect(int(debug.get("weight_count", 0)) == 3, "integrated chamber contains three authored offerings")

	church.queue_free()
	await get_tree().process_frame


func _pulse_altar(
	altar: MechanismElementSensor,
	reason: String
) -> void:
	altar.set_sensor_active(true, {
		"test": reason,
		"phase": "on",
	})
	await get_tree().process_frame
	altar.set_sensor_active(false, {
		"test": reason,
		"phase": "off",
	})
	await get_tree().process_frame


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("CHURCH_TRIAL_CHAMBER_OF_ACCORD_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("CHURCH_TRIAL_CHAMBER_OF_ACCORD_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CHURCH_TRIAL_CHAMBER_OF_ACCORD_SMOKE_TEST: " + failure)
	get_tree().quit(1)
