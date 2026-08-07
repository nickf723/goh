extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const BodyFormControllerScript = preload(
	"res://scripts/player/player_body_form_controller.gd"
)
const BodyFormDodgeBridgeScript = preload(
	"res://scripts/player/player_body_form_dodge_bridge.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var floor := StaticBody3D.new()
	floor.name = "BodyFormDodgeFloor"
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = 1
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20.0, 1.0, 20.0)
	floor_collision.shape = floor_shape
	floor.add_child(floor_collision)
	add_child(floor)

	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "BodyFormDodgePlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	await _wait_frames(16)

	var controller: PlayerBodyFormController = (
		BodyFormControllerScript.new() as PlayerBodyFormController
	)
	controller.name = "BodyFormController"
	player.add_child(controller)
	var bridge: PlayerBodyFormDodgeBridge = (
		BodyFormDodgeBridgeScript.new() as PlayerBodyFormDodgeBridge
	)
	bridge.name = "BodyFormDodgeBridge"
	player.add_child(bridge)
	await _wait_frames(3)

	var dodge: PlayerDodgeController = player.get_node_or_null(
		"PlayerDodgeController"
	) as PlayerDodgeController
	_expect(dodge != null, "body-form dodge fixture resolves the dodge controller")
	if dodge == null:
		_finish([player, floor])
		return
	var baseline_distance: float = dodge.get_profile_distance()
	var baseline_duration: float = dodge.get_profile_duration()
	var baseline_cooldown: float = dodge.get_profile_cooldown()
	var baseline_chain: int = dodge.get_maximum_consecutive_dodges()

	controller.force_form("grown", true, false)
	var grown_debug: Dictionary = bridge.get_debug_data()
	_expect(
		float(grown_debug.get("distance", 99.0)) < baseline_distance,
		"Grow shortens dodge distance"
	)
	_expect(
		float(grown_debug.get("duration", 0.0)) > baseline_duration,
		"Grow makes the heavy dodge slower"
	)
	_expect(
		float(grown_debug.get("cooldown", 0.0)) > baseline_cooldown,
		"Grow lengthens dodge recovery"
	)
	_expect(
		int(grown_debug.get("maximum_chain", 99)) <= baseline_chain,
		"Grow does not increase dodge chaining"
	)

	controller.force_form("shrunk", true, false)
	var shrunk_debug: Dictionary = bridge.get_debug_data()
	_expect(
		float(shrunk_debug.get("distance", 0.0)) > baseline_distance,
		"Shrink lengthens dodge distance"
	)
	_expect(
		float(shrunk_debug.get("duration", 99.0)) < baseline_duration,
		"Shrink makes the dodge quicker"
	)
	_expect(
		float(shrunk_debug.get("cooldown", 99.0)) < baseline_cooldown,
		"Shrink shortens dodge recovery"
	)
	_expect(
		int(shrunk_debug.get("maximum_chain", 0)) > baseline_chain,
		"Shrink grants one additional chained dodge"
	)

	controller.force_form("normal", true, false)
	_expect(
		is_equal_approx(dodge.get_profile_distance(), baseline_distance)
		and is_equal_approx(dodge.get_profile_duration(), baseline_duration)
		and is_equal_approx(dodge.get_profile_cooldown(), baseline_cooldown)
		and dodge.get_maximum_consecutive_dodges() == baseline_chain,
		"normal form restores the exact authored dodge profile"
	)

	_finish([player, floor])


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("BODY_FORMS_DODGE_SMOKE_TEST: " + label)


func _finish(nodes: Array) -> void:
	Engine.time_scale = 1.0
	for node_value: Variant in nodes:
		if node_value is Node and is_instance_valid(node_value as Node):
			(node_value as Node).queue_free()
	if failures.is_empty():
		print("BODY_FORMS_DODGE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("BODY_FORMS_DODGE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
