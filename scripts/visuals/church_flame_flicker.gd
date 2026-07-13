extends Node3D
class_name ChurchFlameFlicker

@export var base_light_energy: float = 2.4
@export var energy_variation: float = 0.45
@export var flicker_speed: float = 7.0
@export var flame_scale_variation: float = 0.08

@onready var flame_root: Node3D = get_node_or_null("FlameRoot") as Node3D
@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D") as OmniLight3D

var elapsed: float = 0.0
var phase_offset: float = 0.0


func _ready() -> void:
	phase_offset = global_position.x * 0.73 + global_position.z * 0.41


func _process(delta: float) -> void:
	elapsed += delta
	var primary_wave: float = sin(elapsed * flicker_speed + phase_offset)
	var secondary_wave: float = sin(elapsed * flicker_speed * 1.73 + phase_offset * 0.6)
	var flicker: float = primary_wave * 0.65 + secondary_wave * 0.35

	if omni_light != null:
		omni_light.light_energy = base_light_energy + flicker * energy_variation

	if flame_root != null:
		var y_scale: float = 1.0 + flicker * flame_scale_variation
		flame_root.scale = Vector3(1.0 - flicker * 0.025, y_scale, 1.0 - flicker * 0.025)
