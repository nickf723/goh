extends RigidBody3D
class_name ArtificerContraptionInstance

signal contraption_activated(build_id: String, activation: String)
signal contraption_destroyed(build_id: String, reason: String)
signal contraption_interaction_discovered(
	build_id: String,
	interaction_id: String,
	data: Dictionary
)

const PartCatalog = preload(
	"res://scripts/builds/engineering_part_catalog.gd"
)

var build_id: String = ""
var definition: Dictionary = {}
var source_actor: Node3D
var source_manager: Node
var parts: Array[Dictionary] = []
var features: Dictionary = {}
var body_size: Vector3 = Vector3.ONE
var visual_root: Node3D
var spring_triggers: Array[Area3D] = []
var conductor_area: Area3D

var wet_remaining: float = 0.0
var frozen_progress: float = 0.0
var energized_remaining: float = 0.0
var overcharge_remaining: float = 0.0
var overcharge_charges: int = 0
var submerged_fraction: float = 0.0
var active_fluid_volume: FluidForceVolume
var detonation_started: bool = false
var durability: float = 10.0
var contact_cooldowns: Dictionary = {}
var discovered_interactions: Dictionary = {}
var last_interaction_id: String = "none"


func configure(
	new_definition: Dictionary,
	new_source_actor: Node3D = null,
	new_source_manager: Node = null
) -> void:
	definition = new_definition.duplicate(true)
	build_id = str(definition.get("id", "artificer_contraption"))
	source_actor = new_source_actor
	source_manager = new_source_manager
	parts = []
	for value: Variant in definition.get("parts", []):
		if value is Dictionary:
			parts.append((value as Dictionary).duplicate(true))
	features = (definition.get("features", {}) as Dictionary).duplicate(true)
	body_size = definition.get("size", Vector3.ONE) as Vector3
	name = "Artificer" + build_id.to_pascal_case()
	mass = maxf(float(definition.get("mass", _calculate_mass())), 0.5)
	collision_layer = 1
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 16
	continuous_cd = true
	freeze = str(definition.get("body_mode", "anchored")) != "dynamic"
	if freeze:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		lock_rotation = true
	else:
		linear_damp = 0.55 if int(features.get("wheels", 0)) >= 2 else 0.9
		angular_damp = 1.4
	durability = maxf(6.0 + parts.size() * 1.5, 8.0)
	_build_parts()
	_build_mechanisms()
	add_to_group("engineering_build")
	add_to_group("artificer_contraption")
	add_to_group("engineering_build_" + build_id)
	add_to_group("elemental_receiver")
	add_to_group("freezable_receiver")
	if int(features.get("blast_cores", 0)) > 0:
		add_to_group("burnable_receiver")
	if int(features.get("conductors", 0)) > 0 or int(features.get("springs", 0)) > 0:
		add_to_group("conductive_receiver")
	if int(features.get("floats", 0)) > 0:
		add_to_group("buoyant_engineering_build")
	add_to_group("debuggable")
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	wet_remaining = maxf(wet_remaining - safe_delta, 0.0)
	frozen_progress = move_toward(frozen_progress, 0.0, safe_delta * 0.012)
	energized_remaining = maxf(energized_remaining - safe_delta, 0.0)
	overcharge_remaining = maxf(overcharge_remaining - safe_delta, 0.0)
	if overcharge_remaining <= 0.0:
		overcharge_charges = 0
	_update_contact_cooldowns(safe_delta)
	_apply_buoyancy()
	_refresh_visual_state()


func _calculate_mass() -> float:
	var total: float = 0.0
	for part: Dictionary in parts:
		total += PartCatalog.get_part_mass(str(part.get("part_id", "")))
	return maxf(total, 1.0)


func _build_parts() -> void:
	visual_root = Node3D.new()
	visual_root.name = "ContraptionParts"
	add_child(visual_root)
	for index: int in range(parts.size()):
		var part: Dictionary = parts[index]
		var part_id: String = str(part.get("part_id", ""))
		var part_definition: Dictionary = PartCatalog.get_definition(part_id)
		if part_definition.is_empty():
			continue
		var position: Vector3 = part.get("position", Vector3.ZERO) as Vector3
		var yaw_degrees: float = float(part.get("yaw_degrees", 0.0))
		var part_root := Node3D.new()
		part_root.name = part_id.to_pascal_case() + str(index + 1)
		part_root.position = position
		part_root.rotation_degrees.y = yaw_degrees
		visual_root.add_child(part_root)
		_build_part_visual(part_root, part_id, part_definition)
		_build_part_collision(part_id, part_definition, position, yaw_degrees)


func _build_part_visual(
	part_root: Node3D,
	part_id: String,
	part_definition: Dictionary
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PartVisual"
	var size: Vector3 = part_definition.get("size", Vector3.ONE) as Vector3
	var shape_id: String = str(part_definition.get("shape", "box"))
	if shape_id == "cylinder":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = maxf(size.x * 0.5, 0.05)
		cylinder.bottom_radius = maxf(size.z * 0.5, 0.05)
		cylinder.height = maxf(size.y, 0.05)
		cylinder.radial_segments = 18
		mesh_instance.mesh = cylinder
		if part_id == "wheel":
			mesh_instance.rotation_degrees.z = 90.0
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
	mesh_instance.material_override = _make_material(
		part_definition.get("color", Color(0.5, 0.7, 0.9, 1.0)) as Color
	)
	part_root.add_child(mesh_instance)


func _build_part_collision(
	part_id: String,
	part_definition: Dictionary,
	position: Vector3,
	yaw_degrees: float
) -> void:
	var collision := CollisionShape3D.new()
	collision.name = part_id.to_pascal_case() + "Collision"
	collision.position = position
	collision.rotation_degrees.y = yaw_degrees
	var size: Vector3 = part_definition.get("size", Vector3.ONE) as Vector3
	if str(part_definition.get("shape", "box")) == "cylinder":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = maxf(size.x * 0.48, 0.05)
		cylinder.height = maxf(size.y * 0.92, 0.05)
		collision.shape = cylinder
		if part_id == "wheel":
			collision.rotation_degrees.z = 90.0
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(
			maxf(size.x * 0.94, 0.05),
			maxf(size.y * 0.94, 0.05),
			maxf(size.z * 0.94, 0.05)
		)
		collision.shape = box
	add_child(collision)


func _build_mechanisms() -> void:
	for part: Dictionary in parts:
		var part_id: String = str(part.get("part_id", ""))
		if part_id == "spring_unit":
			_build_spring_trigger(part)
	if int(features.get("conductors", 0)) > 0:
		_build_conductor_area()


func _build_spring_trigger(part: Dictionary) -> void:
	var part_definition: Dictionary = PartCatalog.get_definition("spring_unit")
	var size: Vector3 = part_definition.get("size", Vector3.ONE) as Vector3
	var area := Area3D.new()
	area.name = "SpringTrigger" + str(spring_triggers.size() + 1)
	area.position = (
		(part.get("position", Vector3.ZERO) as Vector3)
		+ Vector3.UP * (size.y * 0.5 + 0.28)
	)
	area.rotation_degrees.y = float(part.get("yaw_degrees", 0.0))
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x * 0.9, 0.58, size.z * 0.9)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_on_spring_body_entered.bind(part_definition))
	spring_triggers.append(area)


func _build_conductor_area() -> void:
	conductor_area = Area3D.new()
	conductor_area.name = "ContraptionConductiveContact"
	conductor_area.position = Vector3(0.0, body_size.y * 0.5, 0.0)
	conductor_area.collision_layer = 0
	conductor_area.collision_mask = 1
	conductor_area.monitoring = true
	conductor_area.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = body_size + Vector3(0.25, 0.35, 0.25)
	collision.shape = shape
	conductor_area.add_child(collision)
	add_child(conductor_area)
	conductor_area.body_entered.connect(_on_conductive_body_entered)


func _on_spring_body_entered(
	body: Node3D,
	part_definition: Dictionary
) -> void:
	if body == null or body == self:
		return
	var launch_speed: float = maxf(
		float(part_definition.get("launch_speed", 13.0)),
		1.0
	)
	var boosted: bool = overcharge_charges > 0 and overcharge_remaining > 0.0
	if boosted:
		launch_speed *= 1.6
	if body is CharacterBody3D:
		var character := body as CharacterBody3D
		character.velocity.y = maxf(character.velocity.y, launch_speed)
	elif body is RigidBody3D:
		var rigid := body as RigidBody3D
		rigid.apply_central_impulse(Vector3.UP * rigid.mass * launch_speed)
	else:
		return
	if boosted:
		overcharge_charges = maxi(overcharge_charges - 1, 0)
		_record_interaction("overcharged_launch", {
			"launch_speed": launch_speed,
			"charges_remaining": overcharge_charges,
		})
	contraption_activated.emit(build_id, "launch")


func _on_conductive_body_entered(body: Node3D) -> void:
	if energized_remaining <= 0.0 or body == null or body == self:
		return
	var body_id: int = body.get_instance_id()
	if float(contact_cooldowns.get(body_id, 0.0)) > 0.0:
		return
	contact_cooldowns[body_id] = 0.8
	var receiver: Node = _find_payload_receiver(body)
	if receiver == null:
		return
	var payload := DamagePayload.new()
	payload.amount = 1
	payload.stance_damage = 1
	payload.element = "lightning"
	payload.source_name = str(definition.get("display_name", "Artificer Contraption"))
	payload.hit_type = "environment"
	payload.tags = ["engineering_build", "electrical", "conductive_contact"]
	receiver.call("receive_damage_payload", payload)
	_record_interaction("conductive_contact", {"target": body.name})


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null or detonation_started:
		return {"message": "", "objective": "", "handled": false}
	var element: String = payload.element.to_lower().strip_edges()
	var tags: Array[String] = []
	for value: Variant in payload.tags:
		tags.append(str(value).to_lower().strip_edges())
	var intensity: float = maxf(
		maxf(absf(float(payload.amount)), absf(payload.status_strength)),
		1.0
	)
	var force_like: bool = (
		payload.knockback_strength > 0.0
		or tags.has("heavy")
		or tags.has("force")
		or tags.has("impact")
		or tags.has("explosive")
		or tags.has("explosion")
	)

	if element == "water" or tags.has("water") or tags.has("douse"):
		wet_remaining = maxf(wet_remaining, 7.0 + intensity * 0.6)
		_record_interaction("contraption_doused", {"source": payload.source_name})
		return _handled_result()

	if element == "ice" or tags.has("ice") or tags.has("freeze"):
		frozen_progress = clampf(
			frozen_progress + intensity * (0.3 if wet_remaining > 0.0 else 0.2),
			0.0,
			1.0
		)
		if frozen_progress >= 0.65:
			_record_interaction("contraption_frozen", {"source": payload.source_name})
		return _handled_result()

	if element == "lightning" or tags.has("lightning") or tags.has("electrical"):
		if int(features.get("conductors", 0)) > 0 or int(features.get("springs", 0)) > 0:
			energized_remaining = maxf(energized_remaining, 6.0 + intensity)
		if int(features.get("springs", 0)) > 0:
			overcharge_remaining = maxf(overcharge_remaining, 16.0)
			overcharge_charges = maxi(overcharge_charges, 3)
			_record_interaction("springs_overcharged", {
				"charges": overcharge_charges,
				"source": payload.source_name,
			})
		if int(features.get("blast_cores", 0)) > 0:
			if wet_remaining > 0.0:
				_record_interaction("dampened_blast_core", {"source": payload.source_name})
			else:
				detonate()
		return _handled_result()

	if element == "fire" or tags.has("fire") or tags.has("ignite") or tags.has("heat"):
		if int(features.get("blast_cores", 0)) > 0:
			if wet_remaining > 0.0:
				_record_interaction("dampened_blast_core", {"source": payload.source_name})
			else:
				detonate()
		return _handled_result()

	if force_like:
		if frozen_progress >= 0.65:
			durability = maxf(
				durability - intensity * 0.7 - payload.knockback_strength * 0.15,
				0.0
			)
			if durability <= 0.0:
				_destroy_contraption("frozen_shatter")
				return _handled_result()
		if int(features.get("blast_cores", 0)) > 0 and (
			payload.knockback_strength >= 4.0
			or tags.has("explosive")
			or tags.has("explosion")
		):
			detonate()
			return _handled_result()
		if not freeze and payload.knockback_strength > 0.0:
			var direction: Vector3 = _get_knockback_direction(payload)
			apply_central_impulse(
				direction * payload.knockback_strength * mass
			)
		return _handled_result()

	return _handled_result()


func detonate() -> void:
	if detonation_started or int(features.get("blast_cores", 0)) <= 0:
		return
	if wet_remaining > 0.0:
		_record_interaction("dampened_blast_core", {"source": "detonation request"})
		return
	detonation_started = true
	var core_definition: Dictionary = PartCatalog.get_definition("blast_core")
	var core_count: int = maxi(int(features.get("blast_cores", 1)), 1)
	var radius: float = float(core_definition.get("blast_radius", 5.5)) + (core_count - 1) * 0.7
	var damage: int = int(core_definition.get("blast_damage", 5)) + core_count - 1
	var force: float = float(core_definition.get("blast_force", 10.0)) + (core_count - 1) * 1.5
	var origin: Vector3 = global_position + Vector3.UP * body_size.y * 0.45
	_record_interaction("contraption_detonated", {
		"radius": radius,
		"core_count": core_count,
	})
	_spawn_blast_visual(origin, radius)
	contraption_activated.emit(build_id, "detonate")
	collision_layer = 0
	collision_mask = 0
	freeze = true
	visible = false
	set_physics_process(false)
	call_deferred("_resolve_deferred_blast", origin, radius, damage, force)


func _resolve_deferred_blast(
	origin: Vector3,
	radius: float,
	damage: int,
	force: float
) -> void:
	if not is_inside_tree() or get_world_3d() == null:
		queue_free()
		return
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [get_rid()]
	var seen: Dictionary = {}
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var collider: Object = hit.get("collider")
		if not collider is Node:
			continue
		var node := collider as Node
		if node == self or not is_instance_valid(node):
			continue
		var other: ArtificerContraptionInstance = _find_contraption_root(node)
		if other != null and other != self and int(other.features.get("blast_cores", 0)) > 0:
			other.call_deferred("detonate")
		var receiver: Node = _find_payload_receiver(node)
		if receiver != null and not seen.has(receiver.get_instance_id()):
			seen[receiver.get_instance_id()] = true
			var payload := DamagePayload.new()
			payload.amount = damage
			payload.stance_damage = damage
			payload.element = "fire"
			payload.source_name = str(definition.get("display_name", "Artificer Contraption"))
			payload.hit_type = "reaction_burst"
			payload.tags = ["engineering_build", "explosive", "explosion", "combustion"]
			payload.knockback_strength = force
			payload.knockback_up_strength = force * 0.45
			payload.suppress_reactions = true
			receiver.call("receive_damage_payload", payload)
		var body: Node3D = _find_pushable_body(node)
		if body == null:
			continue
		var direction: Vector3 = body.global_position - origin
		direction.y = maxf(direction.y, 0.35)
		if direction.length_squared() <= 0.01:
			direction = Vector3.UP
		if body is RigidBody3D:
			var rigid := body as RigidBody3D
			rigid.apply_central_impulse(direction.normalized() * force * rigid.mass)
		elif body is CharacterBody3D:
			(body as CharacterBody3D).velocity += direction.normalized() * force
	queue_free()


func interact() -> Dictionary:
	return {
		"message": (
			str(definition.get("display_name", "Artificer contraption"))
			+ " contains "
			+ str(parts.size())
			+ " reproduced engineering parts."
		),
		"objective": "Use its mechanisms, elements, and physics together.",
	}


func _apply_buoyancy() -> void:
	submerged_fraction = 0.0
	active_fluid_volume = null
	var float_count: int = int(features.get("floats", 0))
	if freeze or float_count <= 0 or get_tree() == null:
		return
	var best_priority: int = -2147483648
	for node: Node in get_tree().get_nodes_in_group("fluid_force_volumes"):
		var volume := node as FluidForceVolume
		if volume == null or not is_instance_valid(volume):
			continue
		var fraction: float = volume.get_submerged_fraction(
			global_position + Vector3.UP * body_size.y * 0.5,
			body_size.y,
			0.05
		)
		if fraction <= 0.0:
			continue
		if volume.priority > best_priority or fraction > submerged_fraction:
			active_fluid_volume = volume
			submerged_fraction = fraction
			best_priority = volume.priority
	if active_fluid_volume == null or submerged_fraction <= 0.0:
		return
	wet_remaining = maxf(wet_remaining, 1.2)
	var gravity_value: float = maxf(float(ProjectSettings.get_setting(
		"physics/3d/default_gravity",
		9.8
	)), 0.1)
	var ratio: float = clampf(0.75 + float_count * 0.28, 0.9, 1.75)
	apply_central_force(
		Vector3.UP * mass * gravity_value * ratio * submerged_fraction
	)
	var flow: Vector3 = active_fluid_volume.get_flow_velocity(global_position)
	apply_central_force((flow - linear_velocity) * mass * submerged_fraction * 1.4)
	linear_velocity *= 0.992
	angular_velocity *= 0.965


func _refresh_visual_state() -> void:
	if visual_root == null:
		return
	var tint := Color(1.0, 1.0, 1.0, 1.0)
	if frozen_progress >= 0.65:
		tint = Color(0.62, 0.92, 1.0, 1.0)
	elif energized_remaining > 0.0:
		tint = Color(0.82, 0.86, 1.0, 1.0)
	elif wet_remaining > 0.0:
		tint = Color(0.72, 0.84, 1.0, 1.0)
	for mesh: Node in visual_root.find_children("PartVisual", "MeshInstance3D", true, false):
		if mesh is MeshInstance3D:
			(mesh as MeshInstance3D).modulate = tint


func _record_interaction(interaction_id: String, data: Dictionary = {}) -> void:
	last_interaction_id = interaction_id
	if discovered_interactions.has(interaction_id):
		return
	discovered_interactions[interaction_id] = true
	contraption_interaction_discovered.emit(build_id, interaction_id, data)
	var tracker: Node = get_tree().root.get_node_or_null(
		"FullMenuDirector/ProgressionTracker"
	)
	if tracker != null and tracker.has_method("record_discovery"):
		tracker.call("record_discovery", "build_reaction", build_id + "::" + interaction_id, {
			"build_id": build_id,
			"interaction_id": interaction_id,
			"display_name": str(definition.get("display_name", build_id.capitalize())),
			"data": data.duplicate(true),
		})


func _destroy_contraption(reason: String) -> void:
	contraption_destroyed.emit(build_id, reason)
	queue_free()


func _handled_result() -> Dictionary:
	return {"message": "", "objective": "", "handled": true}


func _get_knockback_direction(payload: DamagePayload) -> Vector3:
	var direction: Vector3 = payload.knockback_direction
	if direction.length_squared() > 0.01:
		return direction.normalized()
	if source_actor != null and is_instance_valid(source_actor):
		direction = global_position - source_actor.global_position
	else:
		direction = Vector3.FORWARD
	direction.y = maxf(direction.y, 0.2)
	return direction.normalized()


func _find_payload_receiver(start: Node) -> Node:
	var current: Node = start
	for _index: int in range(8):
		if current == null:
			break
		if current != self and current.has_method("receive_damage_payload"):
			return current
		var direct: Node = current.get_node_or_null("PayloadReceiver")
		if direct != null and direct.has_method("receive_damage_payload"):
			return direct
		var hit_receiver: Node = current.get_node_or_null("HitReceiver")
		if hit_receiver != null and hit_receiver.has_method("receive_damage_payload"):
			return hit_receiver
		current = current.get_parent()
	return null


func _find_contraption_root(start: Node) -> ArtificerContraptionInstance:
	var current: Node = start
	for _index: int in range(8):
		if current == null:
			break
		if current is ArtificerContraptionInstance:
			return current as ArtificerContraptionInstance
		current = current.get_parent()
	return null


func _find_pushable_body(start: Node) -> Node3D:
	var current: Node = start
	for _index: int in range(6):
		if current == null:
			break
		if current is RigidBody3D or current is CharacterBody3D:
			return current as Node3D
		current = current.get_parent()
	return null


func _update_contact_cooldowns(delta: float) -> void:
	for key: Variant in contact_cooldowns.keys():
		var remaining: float = maxf(float(contact_cooldowns[key]) - delta, 0.0)
		if remaining <= 0.0:
			contact_cooldowns.erase(key)
		else:
			contact_cooldowns[key] = remaining


func _spawn_blast_visual(origin: Vector3, radius: float) -> void:
	if get_tree().current_scene == null:
		return
	var pulse := MeshInstance3D.new()
	pulse.name = "ArtificerBlastPulse"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	pulse.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.34, 0.08, 0.42)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.22, 0.04, 1.0)
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse.material_override = material
	get_tree().current_scene.add_child(pulse)
	pulse.global_position = origin
	pulse.scale = Vector3.ONE * 0.2
	var tween: Tween = pulse.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector3.ONE * radius * 2.0, 0.28)
	tween.tween_property(
		material,
		"albedo_color",
		Color(1.0, 0.34, 0.08, 0.0),
		0.28
	)
	tween.set_parallel(false)
	tween.tween_callback(Callable(pulse, "queue_free"))


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.58
	return material


func get_debug_data() -> Dictionary:
	return {
		"build_id": build_id,
		"part_count": parts.size(),
		"features": features.duplicate(true),
		"body_mode": "anchored" if freeze else "dynamic",
		"wet_remaining": wet_remaining,
		"frozen_progress": frozen_progress,
		"energized_remaining": energized_remaining,
		"overcharge_charges": overcharge_charges,
		"submerged_fraction": submerged_fraction,
		"detonation_started": detonation_started,
		"last_interaction_id": last_interaction_id,
	}
