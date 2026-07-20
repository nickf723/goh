extends "res://scripts/levels/single_element_vfx_lab.gd"
class_name SingleElementVfxLabRuntime

const RuntimeConsoleScript = preload("res://scripts/levels/element_vfx_lab_console.gd")
const RuntimeGeometry = preload("res://scripts/levels/thermal_lab_geometry.gd")


func add_global_console(action_id: String, label_text: String, position_value: Vector3, color: Color) -> Area3D:
	var console := RuntimeConsoleScript.new() as Area3D
	console.name = label_text.replace(" ", "") + "Console"
	console.action_id = action_id
	console.prompt_text = label_text
	console.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.35, 1.2, 1.45)
	collision.shape = shape
	console.add_child(collision)
	RuntimeGeometry.add_box_visual(console, "ConsoleBody", Vector3(2.35, 1.2, 1.45), color, true, 1.8)
	RuntimeGeometry.add_label(console, "ConsoleLabel", label_text, Vector3(0.0, 0.92, 0.0), 14, Color.WHITE)
	add_child(console)
	return console
