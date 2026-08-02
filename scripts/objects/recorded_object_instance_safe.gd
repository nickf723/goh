extends "res://scripts/objects/recorded_object_instance.gd"
class_name RecordedObjectInstanceSafe

# Blast chains used to resolve every payload synchronously while the initiating
# barrel was still iterating the physics overlap result. In a live encounter,
# receivers can trigger more reactions and more barrels, producing a deep
# nested call tree in one frame. Mark the barrel spent immediately, then resolve
# one blast on the next idle turn so chain reactions remain dramatic but finite.
func detonate() -> void:
	if detonation_started:
		return
	if blueprint_id == "blast_barrel" and wet_remaining > 0.0:
		_record_interaction("dampened_fuse", {
			"source": "detonation request",
			"remaining": wet_remaining,
		})
		return

	detonation_started = true
	activation_count += 1
	var blast_radius: float = maxf(
		float(definition.get("blast_radius", 4.5)),
		0.5
	)
	var blast_damage: int = maxi(
		int(definition.get("blast_damage", 3)),
		0
	)
	var blast_force: float = maxf(
		float(definition.get("blast_force", 8.0)),
		0.0
	)
	var blast_origin: Vector3 = global_position

	_record_interaction("barrel_detonated", {
		"radius": blast_radius,
		"force": blast_force,
	})
	_spawn_blast_visual(blast_radius)
	object_detonated.emit(blueprint_id)
	object_activated.emit(blueprint_id, "detonate")

	collision_layer = 0
	collision_mask = 0
	freeze = true
	visible = false
	set_physics_process(false)
	call_deferred(
		"_resolve_deferred_blast",
		blast_origin,
		blast_radius,
		blast_damage,
		blast_force
	)


func _resolve_deferred_blast(
	blast_origin: Vector3,
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
	query.transform = Transform3D(Basis.IDENTITY, blast_origin)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [get_rid()]
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(
		query,
		64
	)

	var damaged_nodes: Dictionary = {}
	var pushed_nodes: Dictionary = {}
	var chained_objects: Dictionary = {}
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider == null or not collider is Node:
			continue
		var node := collider as Node
		if node == self or not is_instance_valid(node):
			continue

		# Recorded objects are their own payload receivers, but physics overlap may
		# report either their root body or one of their children. Resolve the root
		# explicitly so a nearby barrel always gets one safe deferred detonation.
		var recorded_root: RecordedObjectInstance = _find_recorded_object_root(node)
		if (
			recorded_root != null
			and recorded_root != self
			and not chained_objects.has(recorded_root.get_instance_id())
		):
			chained_objects[recorded_root.get_instance_id()] = true
			if (
				recorded_root.blueprint_id == "blast_barrel"
				and recorded_root.wet_remaining <= 0.0
			):
				recorded_root.call_deferred("detonate")
			else:
				_deliver_blast_payload(recorded_root, damage, force)
		else:
			var receiver: Node = _find_payload_receiver(node)
			if (
				receiver != null
				and is_instance_valid(receiver)
				and not receiver.is_queued_for_deletion()
				and not damaged_nodes.has(receiver.get_instance_id())
			):
				damaged_nodes[receiver.get_instance_id()] = true
				_deliver_blast_payload(receiver, damage, force)

		var body: Node3D = _find_pushable_body(node)
		if body == null or pushed_nodes.has(body.get_instance_id()):
			continue
		pushed_nodes[body.get_instance_id()] = true
		var direction: Vector3 = body.global_position - blast_origin
		direction.y = maxf(direction.y, 0.32)
		if direction.length_squared() <= 0.01:
			direction = Vector3.UP
		if body is RigidBody3D:
			var rigid := body as RigidBody3D
			rigid.apply_central_impulse(
				direction.normalized() * force * rigid.mass
			)
		elif body is CharacterBody3D:
			var character := body as CharacterBody3D
			character.velocity += direction.normalized() * force

	queue_free()


func _deliver_blast_payload(
	receiver: Node,
	damage: int,
	force: float
) -> void:
	if (
		receiver == null
		or not is_instance_valid(receiver)
		or receiver.is_queued_for_deletion()
		or not receiver.has_method("receive_damage_payload")
	):
		return
	var payload := DamagePayload.new()
	payload.amount = damage
	payload.stance_damage = damage
	payload.element = "fire"
	payload.source_name = str(
		definition.get("display_name", "Recorded Blast Barrel")
	)
	payload.hit_type = "reaction_burst"
	payload.tags = [
		"recorded_object",
		"explosive",
		"explosion",
		"combustion",
	]
	payload.knockback_strength = force
	payload.knockback_up_strength = force * 0.45
	payload.suppress_reactions = true
	receiver.call("receive_damage_payload", payload)


func _find_recorded_object_root(start: Node) -> RecordedObjectInstance:
	var current: Node = start
	for _index: int in range(8):
		if current == null:
			break
		if current is RecordedObjectInstance:
			return current as RecordedObjectInstance
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
