extends Node

const ItemsShellScript = preload(
	"res://scripts/ui/full_menu_shell_items_v1.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var shell: Control = ItemsShellScript.new()
	add_child(shell)
	await get_tree().process_frame

	var content_box: VBoxContainer = shell.get("content_box") as VBoxContainer
	assert_true(content_box != null, "the production Items shell builds its content box")
	if content_box == null:
		_finish(shell)
		return

	var selectable_actions: Array = shell.get("selectable_actions") as Array
	var action_controls: Array = shell.get("action_controls") as Array
	selectable_actions.clear()
	action_controls.clear()
	selectable_actions.append({"kind": "test_action"})

	var stale_button: Button = Button.new()
	stale_button.name = "StaleNavigationButton"
	stale_button.set_meta("menu_action_index", 0)
	content_box.add_child(stale_button)
	action_controls.append(stale_button)
	stale_button.queue_free()
	await get_tree().process_frame

	var live_button: Button = Button.new()
	live_button.name = "LiveNavigationButton"
	live_button.text = "Live"
	live_button.custom_minimum_size = Vector2(120.0, 60.0)
	live_button.set_meta("menu_action_index", 0)
	content_box.add_child(live_button)
	await get_tree().process_frame

	shell.call("_sync_live_action_controls")
	action_controls = shell.get("action_controls") as Array
	assert_equal(action_controls.size(), 1, "the rebuilt graph matches the current action count")
	if action_controls.size() == 1:
		assert_true(
			action_controls[0] == live_button,
			"the live button replaces the freed cached reference"
		)
		assert_true(
			shell.call("_get_live_control", action_controls[0]) == live_button,
			"the replacement remains a valid live Control"
		)

	# Exercise both routes that previously reached the typed
	# _control_has_geometry boundary with a freed object. The shell is hidden in
	# this headless test, so screen geometry itself is intentionally irrelevant;
	# the contract is that stale references are discarded without a type error.
	shell.set("selected_action_index", 0)
	shell.call("_select_action_from_screen_geometry", 1, 0)
	shell.call("_update_virtual_cursor_target")

	var debug_value: Variant = shell.call("get_navigation_debug_data")
	if debug_value is Dictionary:
		var debug_data: Dictionary = debug_value as Dictionary
		assert_true(
			bool(debug_data.get("navigation_graph_synchronized", false)),
			"navigation reports synchronized live controls"
		)
		assert_equal(
			int(debug_data.get("live_action_controls", -1)),
			1,
			"exactly one live action control remains"
		)
	else:
		failures.append("navigation debug data was unavailable")

	_finish(shell)


func _finish(shell: Control) -> void:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
	if failures.is_empty():
		print("MENU_FREED_CONTROL_NAVIGATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MENU_FREED_CONTROL_NAVIGATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
