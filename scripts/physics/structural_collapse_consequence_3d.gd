extends Node3D
class_name StructuralCollapseConsequence3D

signal collapse_consequence_emitted(
	world_position: Vector3,
	display_name: String,
	affected_targets: int
)

@export_range(0.5, 40.0, 0.5) var sound_loudness: float = 22.0
@export_range(0.5, 12.0, 0.25) var impact_radius: float = 4.5
@export_range(0, 100, 1) var impact_damage: int = 4
@export_range(0, 100, 1) var impact_stance_damage: int = 7
@export_range(0.1, 5.0, 0.1) var stimulus_duration: float = 1.6
@export_range(1, 128, 1) var dust_particle_count: int = 32


func _ready() -> void:
	add_to_group("structural_collapse_consequences")
	add_to_group("debuggable")


func trigger_collapse(
	world_position: Vector3,
	display_name: String = "Structural collapse"
) -> int:
	emit_collapse_stimulus(world_position, display_name)
	var affected_targets: int = apply_collapse_payload(world_position, display_name)
	spawn_dust_burst(world_position)
	collapse_consequence_emitted.emit(
		world_position,
		display_name,
		affected_targets
	)
	return affected_targets


func emit_collapse_stimulus(
	world_position: Vector3,
	display_name: String
) -> void:
	var manager: PerceptionStimulusManager = get_tree().get_first_node_in_group(
		"perception_stimulus_manager"
	) as PerceptionStimulusManager
	if manager == null:
		return
	manager.emit_stimulus(
		world_position,
		sound_loudness,
		"collapse",
		stimulus_duration,
		self,
		display_name,
		1.8,
		["impact", "structural", "collapse", "hazard"]
	)


func apply_collapse_payload(
	world_position: Vector3,
	display_name: String
) -> int:
	var payload: DamagePayload = DamagePayload.new()
	payload.amount = impact_damage
	payload.stance_damage = impact_stance_damage
	payload.element = "neutral"
	payload.source_name = display_name
	payload.hit_type = "environment"
	payload.tags = ["physical", "force", "heavy", "collapse", "environment"]
	payload.knockback_strength = 8.0
	payload.knockback_up_strength = 3.0

	var affected_targets: int = 0
	for enemy_value: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Node3D = enemy_value as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(world_position) > impact_radius:
			continue
		var receiver: Node = enemy.get_node_or_null("PayloadReceiver")
		if receiver == null or not receiver.has_method("receive_payload"):
			continue
		receiver.call("receive_payload", payload)
		affected_targets += 1
	return affected_targets


func spawn_dust_burst(world_position: Vector3) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "CollapseDustBurst"
	particles.position = to_local(world_position)
	particles.amount = dust_particle_count
	particles.lifetime = 1.7
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.randomness = 0.72

	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 72.0
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 4.8
	process.gravity = Vector3(0.0, -2.5, 0.0)
	process.scale_min = 0.35
	process.scale_max = 1.2
	process.color = Color(0.42, 0.32, 0.22, 0.78)
	particles.process_material = process

	var dust_mesh: SphereMesh = SphereMesh.new()
	dust_mesh.radius = 0.16
	dust_mesh.height = 0.32
	var dust_material: StandardMaterial3D = StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.42, 0.32, 0.22, 0.72)
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mesh.material = dust_material
	particles.draw_pass_1 = dust_mesh

	add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func get_debug_data() -> Dictionary:
	return {
		"structural_collapse_consequence": true,
		"sound_loudness": sound_loudness,
		"impact_radius": impact_radius,
		"impact_damage": impact_damage,
		"impact_stance_damage": impact_stance_damage,
	}
