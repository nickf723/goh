extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)

const STEP_COUNT: int = 6
const STEP_RISE: float = 0.3
const STEP_RUN: float = 0.82
const FIRST_STEP_CENTER_Z: float = 1.5
const PLAYER_GROUNDED_CENTER_Y: float = 0.96
const APPROACH_CENTER_OFFSET: float = 0.48
const TEST_SPEED: float = 4.0

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var floor: StaticBody3D = _make_floor()
	add_child(floor)
	var staircase: StaticBody3D = _make_staircase()
	add_child(staircase)

	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "StairTraversalTestPlayer"
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame

	var controller: PlayerControllerFreeAimStatus = (
		player as PlayerControllerFreeAimStatus
	)
	var step_up: PlayerStepUpController = (
		player.get_node_or_null("StepUpController") as PlayerStepUpController
	)
	_expect(controller != null, "Shared player uses the step-aware controller")
	_expect(step_up != null, "Shared player exposes PlayerStepUpController")
	if controller == null or step_up == null:
		_finish(player, floor, staircase)
		return

	for step_index: int in range(STEP_COUNT):
		var current_floor_height: float = STEP_RISE * float(step_index)
		var upper_front_z: float = (
			FIRST_STEP_CENTER_Z
			- STEP_RUN * float(step_index)
			+ STEP_RUN * 0.5
		)
		player.set_physics_process(false)
		player.global_position = Vector3(
			0.0,
			PLAYER_GROUNDED_CENTER_Y + current_floor_height,
			upper_front_z + APPROACH_CENTER_OFFSET
		)
		player.velocity = Vector3.ZERO
		player.set_physics_process(true)
		await get_tree().physics_frame
		await get_tree().physics_frame
		player.set_physics_process(false)

		_expect(
			player.is_on_floor(),
			"Player grounds on tread " + str(step_index)
		)
		var before_position: Vector3 = player.global_position
		var intended_velocity: Vector3 = Vector3(0.0, 0.0, -TEST_SPEED)
		player.velocity = Vector3(
			intended_velocity.x,
			-0.1,
			intended_velocity.z
		)
		var stepped: bool = controller._try_step_up(
			intended_velocity,
			1.0 / 60.0
		)
		_expect(
			stepped,
			"Step assist climbs riser " + str(step_index + 1)
		)
		if not stepped:
			continue

		_expect(
			absf(player.velocity.z) <= 0.001,
			"Duplicate planar motion is suspended during stair settlement"
		)
		player.move_and_slide()
		controller._finish_step_up()

		var expected_height: float = (
			PLAYER_GROUNDED_CENTER_Y
			+ STEP_RISE * float(step_index + 1)
		)
		_expect(
			player.global_position.y >= expected_height - 0.035,
			"Riser " + str(step_index + 1) + " reaches its tread height"
		)
		_expect(
			player.global_position.y > before_position.y + 0.22,
			"Riser " + str(step_index + 1) + " gains meaningful height"
		)
		_expect(
			player.global_position.z < before_position.z,
			"Riser " + str(step_index + 1) + " traverses forward"
		)
		_expect(
			is_equal_approx(player.velocity.z, -TEST_SPEED),
			"Ground momentum is restored after riser " + str(step_index + 1)
		)

		var debug: Dictionary = step_up.get_debug_data()
		_expect(bool(debug.get("direct_traversal", false)), "Step uses direct traversal")
		_expect(float(debug.get("forward_distance", 0.0)) > 0.0, "Step records forward travel")
		_expect(str(debug.get("reason", "")) == "stepped", "Step reports successful settlement")

	player.set_physics_process(true)
	_finish(player, floor, staircase)


func _make_floor() -> StaticBody3D:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.name = "StairTraversalFloor"
	floor.position = Vector3(0.0, -0.1, -1.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(8.0, 0.2, 12.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _make_staircase() -> StaticBody3D:
	var staircase: StaticBody3D = StaticBody3D.new()
	staircase.name = "SixRiserStaircase"
	for step_index: int in range(STEP_COUNT):
		var height: float = STEP_RISE * float(step_index + 1)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "Riser" + str(step_index + 1)
		collision.position = Vector3(
			0.0,
			height * 0.5,
			FIRST_STEP_CENTER_Z - STEP_RUN * float(step_index)
		)
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(3.0, height, STEP_RUN)
		collision.shape = shape
		staircase.add_child(collision)
	return staircase


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish(
	player: Node,
	floor: Node,
	staircase: Node
) -> void:
	if player != null:
		player.queue_free()
	if floor != null:
		floor.queue_free()
	if staircase != null:
		staircase.queue_free()
	if failures.is_empty():
		print("STAIR_TRAVERSAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("STAIR_TRAVERSAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
