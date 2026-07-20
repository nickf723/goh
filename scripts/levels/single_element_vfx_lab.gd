extends Node3D
class_name SingleElementVfxLab

const LabGeometry = preload("res://scripts/levels/thermal_lab_geometry.gd")
const LabConsoleScript = preload("res://scripts/levels/element_vfx_lab_console.gd")

var element_name: String = "Element"
var accent_color: Color = Color(0.4, 0.7, 1.0, 1.0)
var intensity_steps: Array[float] = [0.55, 1.0, 1.45, 2.0]
var intensity_index: int = 1
var auto_replay_enabled: bool = true
var slow_motion_enabled: bool = false
var status_label: Label3D
var control_label: Label3D
var shell_built: bool = false


func setup_lab(title: String, subtitle: String, accent: Color) -> void:
	element_name = title
	accent_color = accent
	build_shell(subtitle)


func build_shell(subtitle: String) -> void:
	if shell_built:
		return
	shell_built = true
	add_to_group("single_element_vfx_lab")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	LabGeometry.add_static_box(self, "LabFloor", Vector3(0.0, -0.1, 1.5), Vector3(34.0, 0.2, 32.0), Color(0.025, 0.055, 0.085, 1.0))
	LabGeometry.add_static_box(self, "RearWall", Vector3(0.0, 5.0, 17.5), Vector3(34.0, 10.0, 0.35), Color(0.035, 0.09, 0.13, 1.0))
	LabGeometry.add_static_box(self, "LeftWall", Vector3(-17.0, 4.0, 1.5), Vector3(0.35, 8.0, 32.0), Color(0.025, 0.075, 0.11, 1.0))
	LabGeometry.add_static_box(self, "RightWall", Vector3(17.0, 4.0, 1.5), Vector3(0.35, 8.0, 32.0), Color(0.025, 0.075, 0.11, 1.0))
	LabGeometry.add_label(self, "LabTitle", element_name.to_upper(), Vector3(0.0, 8.2, 16.8), 38, accent_color)
	LabGeometry.add_label(self, "LabSubtitle", subtitle, Vector3(0.0, 7.35, 16.75), 17, Color(0.74, 0.9, 1.0, 1.0))
	status_label = LabGeometry.add_label(self, "LabStatus", "SYSTEM READY", Vector3(0.0, 5.95, 16.7), 18, Color(0.86, 0.96, 1.0, 1.0))
	control_label = LabGeometry.add_label(self, "ControlReadout", "INTENSITY 1.00  •  AUTO ON  •  TIME 1.00", Vector3(0.0, 2.55, -13.25), 16, Color(0.78, 0.9, 1.0, 1.0))
	add_global_console("intensity", "INTENSITY", Vector3(-4.8, 0.75, -13.0), accent_color)
	add_global_console("toggle_auto", "AUTO", Vector3(-1.6, 0.75, -13.0), accent_color.darkened(0.12))
	add_global_console("slow_motion", "SLOW TIME", Vector3(1.6, 0.75, -13.0), accent_color.lightened(0.08))
	add_global_console("reset", "RESET", Vector3(4.8, 0.75, -13.0), Color(0.28, 0.42, 0.58, 1.0))
	var key_light := DirectionalLight3D.new()
	key_light.name = "ElementLabKeyLight"
	key_light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	key_light.light_color = accent_color.lightened(0.35)
	key_light.light_energy = 1.1
	key_light.shadow_enabled = true
	add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.name = "ElementLabFillLight"
	fill_light.position = Vector3(0.0, 6.0, 3.0)
	fill_light.light_color = accent_color
	fill_light.light_energy = 2.2
	fill_light.omni_range = 24.0
	add_child(fill_light)
	update_control_readout()


func add_global_console(action_id: String, label_text: String, position_value: Vector3, color: Color) -> Area3D:
	var console: Area3D = LabConsoleScript.new()
	console.name = label_text.replace(" ", "") + "Console"
	console.action_id = action_id
	console.prompt_text = label_text
	console.position = position_value
	console.collision_layer = 0
	console.collision_mask = 0
	add_child(console)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.35, 1.2, 1.45)
	collision.shape = shape
	console.add_child(collision)
	LabGeometry.add_box_visual(console, "ConsoleBody", Vector3(2.35, 1.2, 1.45), color, true, 1.8)
	LabGeometry.add_label(console, "ConsoleLabel", label_text, Vector3(0.0, 0.92, 0.0), 14, Color.WHITE)
	return console


func handle_vfx_lab_action(action_id: String) -> Dictionary:
	match action_id:
		"intensity":
			intensity_index = (intensity_index + 1) % intensity_steps.size()
			update_control_readout()
			return make_action_result("Intensity set to " + str(snapped(get_intensity(), 0.01)) + ".")
		"toggle_auto":
			auto_replay_enabled = not auto_replay_enabled
			update_control_readout()
			return make_action_result("Automatic replay " + ("enabled." if auto_replay_enabled else "paused."))
		"slow_motion":
			slow_motion_enabled = not slow_motion_enabled
			Engine.time_scale = 0.22 if slow_motion_enabled else 1.0
			update_control_readout()
			return make_action_result("Time scale set to " + str(snapped(Engine.time_scale, 0.01)) + ".")
		"reset":
			reset_target()
			return make_action_result(element_name + " laboratory reset.")
		_:
			return handle_element_action(action_id)


func handle_element_action(action_id: String) -> Dictionary:
	return make_action_result("Unhandled " + element_name + " action: " + action_id)


func get_intensity() -> float:
	if intensity_steps.is_empty():
		return 1.0
	return intensity_steps[clampi(intensity_index, 0, intensity_steps.size() - 1)]


func set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


func update_control_readout() -> void:
	if control_label == null:
		return
	control_label.text = (
		"INTENSITY " + str(snapped(get_intensity(), 0.01))
		+ "  •  AUTO " + ("ON" if auto_replay_enabled else "OFF")
		+ "  •  TIME " + str(snapped(Engine.time_scale, 0.01))
	)


func make_action_result(message: String) -> Dictionary:
	return {
		"message": message,
		"objective": "Inspect the generated effect and its live state readout.",
	}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		reset_target()


func reset_target() -> void:
	intensity_index = 1
	auto_replay_enabled = true
	slow_motion_enabled = false
	Engine.time_scale = 1.0
	update_control_readout()


func get_debug_data() -> Dictionary:
	return {
		"single_element_vfx_lab": true,
		"element": element_name,
		"intensity": get_intensity(),
		"auto_replay": auto_replay_enabled,
		"slow_motion": slow_motion_enabled,
		"time_scale": Engine.time_scale,
	}
