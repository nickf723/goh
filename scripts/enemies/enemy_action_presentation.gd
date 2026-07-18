extends Resource
class_name EnemyActionPresentation

@export var windup_scale: Vector3 = Vector3(1.18, 1.18, 1.18)
@export var active_scale: Vector3 = Vector3(1.04, 0.96, 1.04)

@export var windup_flash_color: Color = Color(1.0, 0.25, 0.15, 1.0)
@export var active_flash_color: Color = Color(1.0, 0.88, 0.3, 1.0)
@export_range(0.0, 1.0, 0.05) var flash_strength: float = 0.58
@export_range(0.0, 1.0, 0.05) var active_flash_strength: float = 0.72

@export var windup_pulse_time: float = 0.12
@export var active_snap_time: float = 0.05
@export var recover_time: float = 0.18


func apply_to(telegraph: Node) -> void:
	if telegraph == null:
		return

	telegraph.set("windup_scale", windup_scale)
	telegraph.set("active_scale", active_scale)
	telegraph.set("windup_flash_color", windup_flash_color)
	telegraph.set("active_flash_color", active_flash_color)
	telegraph.set("flash_strength", flash_strength)
	telegraph.set("active_flash_strength", active_flash_strength)
	telegraph.set("windup_pulse_time", windup_pulse_time)
	telegraph.set("active_snap_time", active_snap_time)
	telegraph.set("recover_time", recover_time)
