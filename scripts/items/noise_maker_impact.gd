extends Node3D
class_name NoiseMakerImpact

const StimulusManagerScript: Script = preload("res://scripts/perception/perception_stimulus_manager.gd")

@export_range(1.0, 40.0, 0.5) var loudness: float = 16.0
@export_range(0.1, 5.0, 0.1) var stimulus_duration: float = 1.8
@export_range(0.1, 4.0, 0.1) var stimulus_priority: float = 1.4
@export_range(0.2, 6.0, 0.1) var lifetime: float = 2.2

var elapsed: float = 0.0
var emitted: bool = false
var pulse_mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("quick_item_impact")
	add_to_group("debuggable")
	create_visual()
	call_deferred("emit_noise")


func _process(delta: float) -> void:
	elapsed += delta
	if pulse_mesh != null:
		var progress: float = clampf(elapsed / maxf(lifetime, 0.01), 0.0, 1.0)
		pulse_mesh.scale = Vector3.ONE * lerpf(0.25, 6.0, progress)
		var material := pulse_mesh.material_override as StandardMaterial3D
		if material != null:
			var color := material.albedo_color
			color.a = 1.0 - progress
			material.albedo_color = color
	if elapsed >= lifetime:
		queue_free()


func activate_quick_item_impact(_source: Node3D, _item: QuickItemDefinition) -> void:
	if not emitted:
		emit_noise()


func emit_noise() -> void:
	if emitted:
		return
	var manager := get_tree().get_first_node_in_group("perception_stimulus_manager") as PerceptionStimulusManager
	if manager == null:
		manager = StimulusManagerScript.new() as PerceptionStimulusManager
		manager.name = "RuntimePerceptionStimulusManager"
		var scene_root := get_tree().current_scene
		if scene_root == null:
			scene_root = get_parent()
		scene_root.add_child(manager)
	manager.emit_stimulus(
		global_position,
		loudness,
		"distraction",
		stimulus_duration,
		self,
		"Thrown Noise Maker",
		stimulus_priority,
		["distraction", "quick_item", "thrown"]
	)
	emitted = true


func create_visual() -> void:
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.11
	core_mesh.height = 0.22
	core.mesh = core_mesh
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color(1.0, 0.64, 0.12, 1.0)
	core_material.metallic = 0.75
	core_material.emission_enabled = true
	core_material.emission = Color(0.8, 0.22, 0.03)
	core_material.emission_energy_multiplier = 1.4
	core.material_override = core_material
	add_child(core)

	pulse_mesh = MeshInstance3D.new()
	var pulse := TorusMesh.new()
	pulse.inner_radius = 0.22
	pulse.outer_radius = 0.27
	pulse.rings = 24
	pulse.ring_segments = 8
	pulse_mesh.mesh = pulse
	pulse_mesh.rotation_degrees.x = 90.0
	var pulse_material := StandardMaterial3D.new()
	pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse_material.albedo_color = Color(1.0, 0.74, 0.24, 0.9)
	pulse_material.emission_enabled = true
	pulse_material.emission = Color(1.0, 0.35, 0.05)
	pulse_material.emission_energy_multiplier = 1.3
	pulse_mesh.material_override = pulse_material
	add_child(pulse_mesh)


func get_debug_data() -> Dictionary:
	return {
		"noise_maker": true,
		"emitted": emitted,
		"loudness": loudness,
		"remaining": snapped(maxf(lifetime - elapsed, 0.0), 0.01),
	}
