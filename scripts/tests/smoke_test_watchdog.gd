extends Node
class_name SmokeTestWatchdog

@export_range(2.0, 120.0, 1.0) var timeout_seconds: float = 25.0
@export var test_name: String = "SMOKE_TEST"


func _ready() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(
		timeout_seconds,
		true,
		false,
		true
	)
	await timer.timeout
	push_error(
		test_name
		+ ": timed out before the test could report a result. "
		+ "A runtime script error likely interrupted the test body."
	)
	get_tree().quit(1)
