extends Node3D
class_name ThrownQuickItem

var source_actor: Node3D
var item_definition: QuickItemDefinition
var velocity: Vector3 = Vector3.ZERO
var remaining_lifetime: float = 0.0
var launched: bool = false


func _ready() -> void:
	add_to_group("quick_item_delivery")
	add_to_group("debuggable")


func launch(actor: Node3D, item: QuickItemDefinition, direction: Vector3) -> bool:
	if actor == null or item == null or item.impact_scene == null:
		return false
	source_actor = actor
	item_definition = item
	var throw_direction: Vector3 = direction.normalized()
	if throw_direction.length() <= 0.01:
		throw_direction = -actor.global_transform.basis.z
	global_position = actor.global_position + Vector3.UP * 1.0 + throw_direction * 0.55
	velocity = throw_direction * item.throw_speed + Vector3.UP * item.throw_vertical_boost
	remaining_lifetime = maxf(item.delivery_lifetime, 0.2)
	create_visual()
	launched = true
	return true


func _physics_process(delta: float) -> void:
	if not launched or item_definition == null:
		return
	remaining_lifetime -= delta
	var next_position: Vector3 = global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if source_actor is CollisionObject3D:
		query.exclude = [(source_actor as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spawn_impact(hit.get("position", next_position), hit.get("normal", Vector3.UP))
		return
	global_position = next_position
	velocity.y -= item_definition.throw_gravity * delta
	rotate_x(delta * 7.0)
	rotate_z(delta * 4.5)
	if remaining_lifetime <= 0.0:
		spawn_impact(global_position, Vector3.UP)


func spawn_impact(position: Vector3, normal: Vector3) -> void:
	if item_definition == null or item_definition.impact_scene == null:
		queue_free()
		return
	var impact: Node = item_definition.impact_scene.instantiate()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	scene_root.add_child(impact)
	if impact is Node3D:
		var impact_3d := impact as Node3D
		impact_3d.global_position = position + normal * 0.03
		impact_3d.scale = Vector3.ONE * item_definition.impact_scale
	if "lifetime" in impact and item_definition.impact_lifetime > 0.0:
		impact.set("lifetime", item_definition.impact_lifetime)
	if impact.has_method("activate_quick_item_impact"):
		impact.call("activate_quick_item_impact", source_actor, item_definition)
	queue_free()


func create_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = item_definition.use_visual_color
	material.metallic = 0.35
	material.roughness = 0.24
	material.emission_enabled = true
	material.emission = item_definition.use_visual_color.darkened(0.35)
	material.emission_energy_multiplier = 1.15
	mesh_instance.material_override = material
	add_child(mesh_instance)


func get_debug_data() -> Dictionary:
	return {
		"item": item_definition.item_id if item_definition != null else "none",
		"velocity": velocity,
		"lifetime": snapped(remaining_lifetime, 0.01),
		"launched": launched,
	}
