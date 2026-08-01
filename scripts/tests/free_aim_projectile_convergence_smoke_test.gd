extends Node

const PlayerControllerScript = preload(
	"res://scripts/player/player_controller_free_aim_status.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var controller: PlayerControllerFreeAimStatus = PlayerControllerScript.new()

	var cast_origin := Vector3(0.0, 1.2, 0.0)
	var lower_target := Vector3(0.0, 0.75, -12.0)
	var downward: Vector3 = controller.resolve_projectile_direction_to_point(
		cast_origin,
		lower_target
	)
	assert_true(downward.y < -0.01, "a lower camera target preserves downward pitch")
	assert_near(downward.length(), 1.0, 0.001, "downward convergence is normalized")

	var level_target := Vector3(0.0, 1.2, -12.0)
	var level: Vector3 = controller.resolve_projectile_direction_to_point(
		cast_origin,
		level_target
	)
	assert_near(level.y, 0.0, 0.001, "a level target remains level")

	var higher_target := Vector3(0.0, 3.0, -12.0)
	var upward: Vector3 = controller.resolve_projectile_direction_to_point(
		cast_origin,
		higher_target
	)
	assert_true(upward.y > 0.01, "an elevated target preserves upward pitch")

	var zero: Vector3 = controller.resolve_projectile_direction_to_point(
		cast_origin,
		cast_origin
	)
	assert_equal(zero, Vector3.ZERO, "zero-distance convergence is rejected")
	controller.free()

	if failures.is_empty():
		print("FREE_AIM_PROJECTILE_CONVERGENCE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FREE_AIM_PROJECTILE_CONVERGENCE_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)


func assert_near(
	actual: float,
	expected: float,
	tolerance: float,
	label: String
) -> void:
	if absf(actual - expected) > tolerance:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
