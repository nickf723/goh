extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const SettingsShellScript = preload("res://scripts/ui/full_menu_shell_settings.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "PreferenceTestPlayer"
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	var service: PlayerPreferenceService = (
		player.get_node_or_null("PlayerPreferences") as PlayerPreferenceService
	)
	var weapon: WeaponController = (
		player.get_node_or_null("WeaponController") as WeaponController
	)
	var feedback: PlayerMotionFeedback = (
		player.get_node_or_null("PlayerMotionFeedback") as PlayerMotionFeedback
	)

	_expect(service != null, "Shared player installs PlayerPreferences")
	_expect(weapon != null, "Preference test resolves WeaponController")
	_expect(feedback != null, "Preference test resolves PlayerMotionFeedback")
	if service == null or weapon == null or feedback == null:
		_finish()
		return

	player.set_physics_process(false)
	service.auto_save_changes = false
	var original_snapshot: Dictionary = service.capture_snapshot()
	service.reset_defaults(false)

	var debug: Dictionary = service.get_debug_data()
	var base_mouse: float = float(debug.get("baseline_mouse_sensitivity", 0.0))
	var base_controller: float = float(debug.get("baseline_controller_sensitivity", 0.0))
	var base_impact: float = float(debug.get("baseline_weapon_camera_impact", 0.0))

	_expect(service.get_rows().size() == 6, "Preference catalog exposes six authored settings")
	_expect(str(service.get_summary().get("scope", "")) == "user_profile", "Preferences declare profile-wide scope")
	_expect(is_equal_approx(float(player.get("mouse_sensitivity")), base_mouse), "Default mouse sensitivity is preserved")
	_expect(is_equal_approx(float(player.get("controller_camera_sensitivity")), base_controller), "Default controller sensitivity is preserved")
	_expect(is_equal_approx(weapon.camera_impact_amount, base_impact), "Default weapon camera impact is preserved")

	var mouse_result: Dictionary = service.set_preference(
		"mouse_camera_scale",
		1.5,
		false
	)
	_expect(bool(mouse_result.get("ok", false)), "Mouse camera preference accepts authored option")
	_expect(is_equal_approx(float(player.get("mouse_sensitivity")), base_mouse * 1.5), "Mouse camera scale reaches the live player")

	service.set_preference("controller_camera_scale", 0.75, false)
	_expect(is_equal_approx(float(player.get("controller_camera_sensitivity")), base_controller * 0.75), "Controller camera scale reaches the live player")

	service.set_preference("controller_camera_deadzone", 0.27, false)
	_expect(is_equal_approx(float(player.get("controller_camera_deadzone")), 0.25), "Numeric input normalizes to the nearest authored deadzone")

	service.set_preference("focus_menu_camera", true, false)
	_expect(bool(player.get("allow_controller_camera_during_focus_menu")), "Focus-menu camera preference reaches the live player")

	service.set_preference("camera_impact_scale", 0.5, false)
	_expect(is_equal_approx(weapon.camera_impact_amount, base_impact * 0.5), "Camera-impact scale reaches weapon feedback")
	_expect(is_equal_approx(feedback.camera_impulse_scale, 0.5), "Camera-impact scale reaches landing feedback")

	service.set_preference("motion_effect_scale", 0.0, false)
	_expect(is_equal_approx(feedback.visual_effect_scale, 0.0), "Motion-pulse preference reaches procedural feedback")

	var changed_summary: Dictionary = service.get_summary()
	_expect(int(changed_summary.get("changed_count", 0)) == 6, "Summary counts every changed preference")

	var changed_snapshot: Dictionary = service.capture_snapshot()
	service.reset_defaults(false)
	_expect(int(service.get_summary().get("changed_count", -1)) == 0, "Reset restores every authored default")
	service.apply_snapshot(changed_snapshot, false)
	_expect(is_equal_approx(service.get_float("mouse_camera_scale"), 1.5), "Snapshot restores mouse scale")
	_expect(service.get_bool("focus_menu_camera"), "Snapshot restores boolean settings")
	_expect(is_equal_approx(feedback.visual_effect_scale, 0.0), "Snapshot reapplies live feedback settings")

	service.reset_defaults(false)
	var cycle_result: Dictionary = service.cycle_preference(
		"mouse_camera_scale",
		1,
		false
	)
	_expect(str(cycle_result.get("label", "")) == "125%", "Cycling advances to the next authored value")
	service.cycle_preference("mouse_camera_scale", -1, false)
	_expect(is_equal_approx(service.get_float("mouse_camera_scale"), 1.0), "Reverse cycling returns to the previous value")

	service.set_preference("camera_impact_scale", 0.5, false)
	var shell: Control = SettingsShellScript.new()
	add_child(shell)
	shell.call("show_menu", {})
	shell.call("select_tab", int(shell.call("get_tab_index", "system")))
	var system_text: String = _collect_node_text(shell)
	_expect(system_text.contains("CAMERA INPUT"), "System tab renders camera preference section")
	_expect(system_text.contains("Mouse Look Speed"), "System tab renders mouse sensitivity")
	_expect(system_text.contains("Camera Impact"), "System tab renders camera-impact preference")
	_expect(system_text.contains("REDUCED"), "System tab renders the current preference value")
	_expect(system_text.contains("Profile-Wide Preferences"), "System tab explains profile persistence scope")
	var actions: Variant = shell.get("selectable_actions")
	_expect(actions is Array and (actions as Array).size() >= 7, "System tab exposes six settings plus reset")

	shell.call("activate_action", {
		"kind": "cycle_player_preference",
		"preference_id": "camera_impact_scale",
	})
	_expect(is_equal_approx(service.get_float("camera_impact_scale"), 1.0), "System action cycles the live service")

	service.apply_snapshot(original_snapshot, false)
	shell.queue_free()
	player.queue_free()
	_finish()


func _collect_node_text(root: Node) -> String:
	var lines: Array[String] = []
	_collect_text_recursive(root, lines)
	return "\n".join(lines)


func _collect_text_recursive(node: Node, lines: Array[String]) -> void:
	if node is Label:
		lines.append((node as Label).text)
	elif node is Button:
		lines.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_text_recursive(child, lines)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("PLAYER_PREFERENCES_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	push_error(
		"PLAYER_PREFERENCES_SMOKE_TEST: FAILED: "
		+ ", ".join(failures)
	)
	get_tree().quit(1)
