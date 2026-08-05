extends Node

const WeightBlockScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_weight_block.tscn"
)
const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_mechanism_network_lab_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	await _test_reusable_weight_block()
	await _test_production_lab_weights()
	_finish()


func _test_reusable_weight_block() -> void:
	var block: MechanismWeightBlock = (
		WeightBlockScene.instantiate() as MechanismWeightBlock
	)
	_expect(block != null, "reusable mechanism weight block instantiates")
	if block == null:
		return

	block.name = "SoulWeightFixture"
	block.gravity_strength = 0.0
	block.position = Vector3(0.0, 2.0, 0.0)
	block.configure_weight_block(
		4.0,
		Vector3(1.1, 1.1, 1.1),
		Color(0.25, 0.65, 0.8),
		"Four Kilogram Test Weight"
	)
	add_child(block)
	await _wait_physics_frames(2)

	_expect(block.is_in_group("mechanism_weights"), "weight block joins the mechanism weight group")
	_expect(block.is_in_group("soul_grip_puzzle_weights"), "weight block advertises puzzle Soul Grip support")
	_expect(is_equal_approx(block.get_mechanism_mass_kg(), 4.0), "weight block exposes its authored mass")
	_expect(block.get_node_or_null("CollisionShape3D") != null, "weight block retains physical collision")
	_expect(block.get_node_or_null("SoulMark") != null, "weight block presents a visible Soul mark")

	var soul: SoulManipulable = block.get_node_or_null(
		"SoulManipulable"
	) as SoulManipulable
	_expect(soul != null, "weight block contains a SoulManipulable component")
	if soul != null:
		_expect(soul.is_in_group("soul_manipulable"), "Soul Grip targeting can discover the weight block")
		_expect(soul.can_begin_manipulation(), "weight block begins in a grippable state")
		var authored_transform: Transform3D = block.transform
		var start_position: Vector3 = block.global_position
		var began: bool = soul.begin_manipulation(self)
		_expect(began, "Soul Grip can claim the reusable weight block")
		if began:
			soul.set_target_pose(
				start_position + Vector3(1.5, 0.6, 0.0),
				block.global_basis
			)
			await _wait_physics_frames(12)
			_expect(
				block.global_position.distance_to(start_position) > 0.2,
				"claimed weight block follows a Soul Grip target pose"
			)
			soul.end_manipulation()
		block.reset_target()
		_expect(
			block.transform.origin.distance_to(authored_transform.origin) <= 0.001,
			"weight block reset restores its authored position"
		)
		_expect(block.velocity.length() <= 0.001, "weight block reset clears velocity")

	block.queue_free()
	await get_tree().process_frame


func _test_production_lab_weights() -> void:
	var lab: Node = LabScene.instantiate()
	_expect(lab != null, "production mechanism laboratory instantiates")
	if lab == null:
		return
	lab.name = "SoulWeightLabFixture"
	add_child(lab)
	await _wait_physics_frames(12)

	_expect(
		lab is MechanismNetworkLabSoulWeights,
		"production mechanism lab installs the Soul-weight runtime"
	)

	var blocks: Array[MechanismWeightBlock] = []
	var rigid_weight_count: int = 0
	for candidate: Node in get_tree().get_nodes_in_group("mechanism_weights"):
		if not lab.is_ancestor_of(candidate):
			continue
		if candidate is MechanismWeightBlock:
			blocks.append(candidate as MechanismWeightBlock)
		elif candidate is RigidBody3D:
			rigid_weight_count += 1

	_expect(blocks.size() >= 12, "every Boolean and value-wing puzzle weight is Soul-grippable")
	_expect(rigid_weight_count == 0, "production lab contains no legacy raw RigidBody puzzle weights")

	for block: MechanismWeightBlock in blocks:
		var soul: SoulManipulable = block.get_node_or_null(
			"SoulManipulable"
		) as SoulManipulable
		_expect(soul != null, str(block.name) + " includes Soul manipulation")
		if soul != null:
			_expect(
				soul.can_begin_manipulation(),
				str(block.name) + " is available to Soul Grip"
			)

	var threshold_block: MechanismWeightBlock = lab.get_node_or_null(
		"Mechanisms/ThresholdCrate7kg"
	) as MechanismWeightBlock
	var threshold_plate: PressurePlateSwitch = lab.get_node_or_null(
		"Mechanisms/ThresholdWeightPlate"
	) as PressurePlateSwitch
	_expect(threshold_block != null, "seven-kilogram threshold block was upgraded")
	_expect(threshold_plate != null, "threshold station retains its pressure plate")
	if threshold_block != null:
		_expect(
			is_equal_approx(threshold_block.get_mechanism_mass_kg(), 7.0),
			"upgraded threshold block preserves its seven-kilogram value"
		)
	if threshold_block != null and threshold_plate != null:
		threshold_plate._on_body_entered(threshold_block)
		_expect(
			is_equal_approx(threshold_plate.get_mechanism_value(), 7.0),
			"weighted pressure plate reads a Soul-grippable block's mass"
		)
		threshold_plate._on_body_exited(threshold_block)

	var movable_block: MechanismWeightBlock = lab.get_node_or_null(
		"Mechanisms/ThresholdCrate2kg"
	) as MechanismWeightBlock
	if movable_block != null:
		var soul: SoulManipulable = movable_block.get_node_or_null(
			"SoulManipulable"
		) as SoulManipulable
		var authored_transform: Transform3D = movable_block.initial_transform
		var start_position: Vector3 = movable_block.global_position
		var began: bool = soul != null and soul.begin_manipulation(self)
		_expect(began, "production puzzle weight can be claimed by Soul Grip")
		if began:
			soul.set_target_pose(
				start_position + Vector3(0.0, 1.2, 0.0),
				movable_block.global_basis
			)
			await _wait_physics_frames(8)
			_expect(
				movable_block.global_position.distance_to(start_position) > 0.1,
				"production puzzle weight physically follows Soul Grip"
			)
		lab.call("reset_lab")
		_expect(
			movable_block.transform.origin.distance_to(
				authored_transform.origin
			) <= 0.001,
			"laboratory reset restores a manipulated puzzle weight"
		)
		await get_tree().process_frame

	var debug_value: Variant = (
		lab.call("get_debug_data")
		if lab.has_method("get_debug_data")
		else {}
	)
	var debug: Dictionary = (
		debug_value as Dictionary
		if debug_value is Dictionary
		else {}
	)
	_expect(bool(debug.get("soul_weight_runtime", false)), "lab debug data advertises Soul-weight support")
	_expect(
		int(debug.get("soul_grippable_weights", 0)) == blocks.size(),
		"lab debug count matches the discovered Soul-grippable weights"
	)

	lab.queue_free()
	await get_tree().process_frame


func _wait_physics_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("MECHANISM_SOUL_WEIGHT_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("MECHANISM_SOUL_WEIGHT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MECHANISM_SOUL_WEIGHT_SMOKE_TEST: " + failure)
	get_tree().quit(1)
