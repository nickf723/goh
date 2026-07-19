extends Area3D
class_name MotorDirectionConsole

@export var prompt_text: String = "Reverse motor direction"

var motor: ElectricMotorComponent


func _ready() -> void:
	add_to_group("debuggable")


func configure(next_motor: ElectricMotorComponent) -> void:
	motor = next_motor


func interact() -> Dictionary:
	if motor == null:
		return {
			"message": "Motor direction control is disconnected.",
			"objective": "",
		}
	motor.reverse_winding()
	return {
		"message": "Motor direction reversed.",
		"objective": "Observe the motor shaft and conveyor reverse while source power remains unchanged.",
	}


func get_debug_data() -> Dictionary:
	return {
		"motor_direction_console": true,
		"connected": motor != null,
		"direction_sign": motor.winding_sign if motor != null else 0,
	}
