extends RigidBody3D
class_name RecordedObjectInstance

signal object_detonated(blueprint_id: String)
signal object_activated(blueprint_id: String, activation: String)

var blueprint_id: String = ""
var definition: Dictionary = {}
var source_actor: Node3D
var source_manager: Node
var spawned_at_msec: int = 0
var detonation_started: bool = false
var activation_count: int = 0
var body_size: Vector3 = Vector3.ONE
var spring_trigger: Area3D
var primary_mesh: MeshInstance3D


func configure(
	new_definition: Dictionary,
	new_source_actor: Node3D = null,
	new_source_manager: Node = null
) -> void:
	definition = new_definition.duplicate(true)
	blueprint_id = str(definition.get("id", "recorded_object"))
	source_actor = new_source_actor
	source_manager = new_source_manager
	spawned_at_msec = Time.get_ticks_msec()
	name = "Recorded" + blueprint_id.to_pascal_case()
	add_to_group("recorded_object")
	add_to_group("recorded_object_" + blueprint_id)
	add_to_group("debuggable")
	body_size = definition.get("size", Vector3.ONE) as Vector3
	mass = maxf(float(definition.get("mass", 1.0)), 0.1)
	collision_layer = 1
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true
	var body_mode: String = str(definition.get("body_mode", "dynamic"))
	freeze = body_mode != "dynamic"
	if freeze:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		lock_rotation = true
	_build_collision()
	_build_visual()
	if str(definition.get("behavior", "")) == "spring":
		_build_spring_trigger()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "ObjectCollision"
	var shape := BoxShape3D.new()
	shape.size = body_size
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	primary_mesh = MeshInstance3D.new()
	primary_mesh.name = "ObjectVisual"
	var behavior: String = str(definition.get("behavior", "crate"))
	if behavior == "blast_barrel":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = body_size.x * 0.48
		cylinder.bottom_radius = body_size.x * 0.5
		cylinder.height = body_size.y
		cylinder.radial_segments = 18
		primary_mesh.mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = body_size
		primary_mesh.mesh = box
	primary_mesh.material_override = _make_material(
		definition.get("color", Color(0.55, 0.72, 0.9, 1.0)) as Color
	)
	add_child(primary_mesh)
	if behavior == "spring":
		var plate := MeshInstance3D.new()
		plate.name = "SpringPlate"
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(body_size.x * 0.82, 0.12, body_size.z * 0.82)
		plate.mesh = plate_mesh
		plate.position.y = body_size.y * 0.62
		plate.material_override = _make_material(Color(0.66, 1.0, 0.72, 1.0))
		add_child(plate)
	elif behavior == "blast_barrel":
		for y_offset: float in [-body_size.y * 0.28, body_size.y * 0.28]:
			var band := MeshInstance3D.new()
			var band_mesh := TorusMesh.new()
			band_mesh.inner_radius = body_size.x * 0.47
			band_mesh.outer_radius = body_size.x * 0.55
			band_mesh.rings = 18
			band_mesh.ring_segments = 8
			band.mesh = band_mesh
			band.position.y = y_offset
			band.rotation_degrees.x = 90.0
			band.material_override = _make_material(Color(0.18, 0.12, 0.08, 1.0))
			add_child(band)


func _build_spring_trigger() -> void:
	spring_trigger = Area3D.new()
	spring_trigger.name = "SpringTrigger"
	spring_trigger.collision_layer = 0
	spring_trigger.collision_mask = 1
	spring_trigger.monitoring = true
	spring_trigger.monitorable = false
	spring_trigger.position.y = body_size.y * 0.5 + 0.34
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(body_size.x * 0.9, 0.62, body_size.z * 0.9)
	collision.shape = shape
	spring_trigger.add_child(collision)
	add_child(spring_trigger)
	spring_trigger.body_entered.connect(_on_spring_body_entered)


func _on_spring_body_entered(body: Node3D) -> void:
	if body == self or body == null:
		return
	var launch_speed: float = maxf(float(definition.get("launch_speed", 10.0)), 1.0)
	if body is CharacterBody3D:
		var character := body as CharacterBody3D
		character.velocity.y = maxf(character.velocity.y, launch_speed)
	elif body is RigidBody3D:
		var rigid := body as RigidBody3D
		rigid.apply_central_impulse(Vector3.UP * rigid.mass * launch_speed)
	else:
		return
	activation_count += 1
	object_activated.emit(blueprint_id, "launch")


func receive_damage_payload(payload: DamagePayload) -> void:
	if payload == null or detonation_started:
		return
	if str(definition.get("behavior", "")) == "blast_barrel":
		var should_detonate: bool = payload.element == "fire"
		for tag: String in payload.tags:
			if tag in ["heavy", "force", "explosive", "explosion", "combustion"]:
				should_detonate = true
		if should_detonate:
			detonate()
			return
	if not freeze and payload.knockback_strength > 0.0:
		var direction: Vector3 = global_position - (
			source_actor.global_position if source_actor != null else Vector3.ZERO
		)
		direction.y = 0.2
		if direction.length_squared() <= 0.01:
			direction = Vector3.FORWARD
		apply_central_impulse(direction.normalized() * payload.knockback_strength * mass)


func interact() -> Dictionary:
	if str(definition.get("behavior", "")) == "blast_barrel":
		detonate()
		return {
			"message": "The recorded barrel ruptures in a burst of reproduced force.",
			"objective": "",
		}
	return {
		"message": str(definition.get("display_name", "Recorded object")) + " is stable.",
		"objective": "",
	}


func detonate() -> void:
	if detonation_started:
		return
	detonation_started = true
	activation_count += 1
	var blast_radius: float = maxf(float(definition.get("blast_radius", 4.5)), 0.5)
	var blast_damage: int = maxi(int(definition.get("blast_damage", 3)), 0)
	var blast_force: float = maxf(float(definition.get("blast_force", 8.0)), 0.0)
	_apply_blast(blast_radius, blast_damage, blast_force)
	_spawn_blast_visual(blast_radius)
	object_detonated.emit(blueprint_id)
	object_activated.emit(blueprint_id, "detonate")
	queue_free()


func _apply_blast(radius: float, damage: int, force: float) -> void:
	var world := get_world_3d()
	if world == null:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [get_rid()]
	var hits: Array[Dictionary] = world.direct_space_state.intersect_shape(query, 64)
	var damaged_nodes: Dictionary = {}
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider == null or not collider is Node:
			continue
		var node := collider as Node
		var receiver: Node = _find_payload_receiver(node)
		if receiver != null and not damaged_nodes.has(receiver.get_instance_id()):
			damaged_nodes[receiver.get_instance_id()] = true
			var payload := DamagePayload.new()
			payload.amount = damage
			payload.stance_damage = damage
			payload.element = "fire"
			payload.source_name = str(definition.get("display_name", "Recorded Blast Barrel"))
			payload.hit_type = "reaction_burst"
			payload.tags = ["recorded_object", "explosive", "explosion", "combustion"]
			payload.knockback_strength = force
			payload.knockback_up_strength = force * 0.45
			receiver.call("receive_damage_payload", payload)
		if node is Node3D:
			var direction: Vector3 = (node as Node3D).global_position - global_position
			direction.y = maxf(direction.y, 0.32)
			if direction.length_squared() <= 0.01:
				direction = Vector3.UP
			if node is RigidBody3D:
				var rigid := node as RigidBody3D
				rigid.apply_central_impulse(direction.normalized() * force * rigid.mass)
			elif node is CharacterBody3D:
				var character := node as CharacterBody3D
				character.velocity += direction.normalized() * force


func _find_payload_receiver(start: Node) -> Node:
	var current: Node = start
	for _index: int in range(4):
		if current == null:
			break
		if current.has_method("receive_damage_payload") and current != self:
			return current
		var direct: Node = current.get_node_or_null("PayloadReceiver")
		if direct != null and direct.has_method("receive_damage_payload"):
			return direct
		var hit_receiver: Node = current.get_node_or_null("HitReceiver")
		if hit_receiver != null and hit_receiver.has_method("receive_damage_payload"):
			return hit_receiver
		current = current.get_parent()
	return null


func _spawn_blast_visual(radius: float) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var pulse := MeshInstance3D.new()
	pulse.name = "RecordedBlastPulse"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	pulse.mesh = sphere
	pulse.material_override = _make_transparent_material(Color(1.0, 0.38, 0.08, 0.72))
	scene_root.add_child(pulse)
	pulse.global_position = global_position
	pulse.scale = Vector3.ONE * 0.2
	pulse.transparency = 0.0
	var tween := pulse.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector3.ONE * radius * 2.0, 0.32)
	tween.tween_property(pulse, "transparency", 1.0, 0.32)
	tween.chain().tween_callback(pulse.queue_free)


func get_debug_data() -> Dictionary:
	return {
		"blueprint_id": blueprint_id,
		"behavior": str(definition.get("behavior", "")),
		"body_mode": str(definition.get("body_mode", "dynamic")),
		"frozen": freeze,
		"size": body_size,
		"mass": mass,
		"activation_count": activation_count,
		"detonation_started": detonation_started,
		"age_seconds": float(Time.get_ticks_msec() - spawned_at_msec) / 1000.0,
		"has_spring_trigger": spring_trigger != null,
	}


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.22
	material.roughness = 0.58
	material.emission_enabled = true
	material.emission = color.darkened(0.62)
	material.emission_energy_multiplier = 0.35
	return material


func _make_transparent_material(color: Color) -> StandardMaterial3D:
	var material := _make_material(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material
