extends Node3D
class_name LightningArcVisual

signal expired(visual: LightningArcVisual)

var duration_seconds: float = 0.18
var flicker_frequency: float = 34.0
var age: float = 0.0
var seed_phase: float = 0.0
var light: OmniLight3D
var base_light_energy: float = 0.0
var mesh_nodes: Array[MeshInstance3D] = []


func configure(duration: float, frequency: float, seed: int) -> void:
	duration_seconds = clampf(duration, 0.04, 2.5)
	flicker_frequency = clampf(frequency, 1.0, 120.0)
	seed_phase = float(abs(seed % 997)) * 0.017


func register_mesh(mesh: MeshInstance3D) -> void:
	if mesh != null:
		mesh_nodes.append(mesh)


func register_light(next_light: OmniLight3D) -> void:
	light = next_light
	if light != null:
		base_light_energy = light.light_energy


func _process(delta: float) -> void:
	age += max(delta, 0.0)
	var progress: float = clampf(age / max(duration_seconds, 0.001), 0.0, 1.0)
	var pulse: float = 0.56 + 0.44 * absf(sin(age * flicker_frequency + seed_phase))
	var dropout: bool = sin(age * flicker_frequency * 0.47 + seed_phase * 1.7) < -0.82
	var fade: float = pow(1.0 - progress, 0.6)
	for mesh: MeshInstance3D in mesh_nodes:
		if mesh == null or not is_instance_valid(mesh):
			continue
		mesh.visible = not dropout
		mesh.transparency = clampf(1.0 - pulse * fade, 0.0, 0.96)
	if light != null and is_instance_valid(light):
		light.light_energy = base_light_energy * pulse * fade
	if age >= duration_seconds:
		expired.emit(self)
		queue_free()
