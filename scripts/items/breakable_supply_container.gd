extends StaticBody3D
class_name BreakableSupplyContainer

@export var resettable_in_lab: bool = true

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var hit_receiver: Node = get_node_or_null("HitReceiver")
@onready var loot_dropper: LootDropper = get_node_or_null("LootDropper") as LootDropper
@onready var label: Label3D = get_node_or_null("Label3D") as Label3D

var broken: bool = false


func _ready() -> void:
	add_to_group("breakable_supply_container")
	add_to_group("debuggable")
	if resettable_in_lab:
		add_to_group("lab_resettable")
	if hit_receiver != null and hit_receiver.has_signal("health_depleted"):
		var callback: Callable = Callable(self, "_on_health_depleted")
		if not hit_receiver.is_connected("health_depleted", callback):
			hit_receiver.connect("health_depleted", callback)
	reset_container()


func _on_health_depleted() -> void:
	if broken:
		return
	broken = true
	if loot_dropper != null:
		loot_dropper.drop_now()
	if mesh_instance != null:
		mesh_instance.visible = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if label != null:
		label.text = "SUPPLIES RELEASED"
	spawn_break_burst()


func reset_container() -> void:
	broken = false
	if mesh_instance != null:
		mesh_instance.visible = true
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if label != null:
		label.text = "SUPPLY CRATE"
	if hit_receiver != null:
		if hit_receiver.has_method("reset_health"):
			hit_receiver.call("reset_health")
		if hit_receiver.has_method("reset_stance"):
			hit_receiver.call("reset_stance")
	if loot_dropper != null:
		loot_dropper.reset_dropper()


func spawn_break_burst() -> void:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = 14
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0.0, -8.0, 0.0)
	var fragment_mesh: BoxMesh = BoxMesh.new()
	fragment_mesh.size = Vector3(0.12, 0.12, 0.12)
	var fragment_material: StandardMaterial3D = StandardMaterial3D.new()
	fragment_material.albedo_color = Color(0.34, 0.18, 0.07)
	fragment_material.roughness = 0.86
	fragment_mesh.material = fragment_material
	particles.mesh = fragment_mesh
	var world_parent: Node = get_tree().current_scene
	world_parent.add_child(particles)
	particles.global_position = global_position + Vector3.UP * 0.65
	particles.emitting = true
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)


func get_debug_data() -> Dictionary:
	return {
		"broken": broken,
		"loot_table": loot_dropper.loot_table.display_name if loot_dropper != null and loot_dropper.loot_table != null else "none",
		"dropped": loot_dropper.has_dropped if loot_dropper != null else false,
	}
