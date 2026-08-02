extends RigidBody3D
class_name EngineeringBuildInstance

signal build_activated(build_id: String, activation: String)
signal build_destroyed(build_id: String, reason: String)
signal build_interaction_discovered(
	build_id: String,
	interaction_id: String,
	data: Dictionary
)

var build_id: String = ""
var definition: Dictionary = {}
var source_actor: Node3D
var source_manager: Node
var body_size: Vector3 = Vector3.ONE
var spawned_at_msec: int = 0
var detonation_started: bool = false
var activation_count: int = 0
var spring_trigger: Area3D
var conductive_contact_area: Area3D
var visual_root: Node3D

var wet_remaining: float = 0.0
var frozen_progress: float = 0.0
var energized_remaining: float = 0.0
var overcharge_remaining: float = 0.0
var overcharge_charges: int = 0
var durability: float = 10.0
var buoyancy_ratio: float = 0.0
var submerged_fraction: float = 0.0
var active_fluid_volume: FluidForceVolume
var contact_cooldowns: Dictionary = {}
var discovered_interactions: Dictionary = {}
var last_interaction_id: String = "none"


func configure(
	new_definition: Dictionary,
	new_source_actor: Node3D = null,
	new_source_manager: Node = null
) -> void:
	definition = new_definition.duplicate(true)
	build_id = str(definition.get("id", "engineering_build"))
	source_actor = new_source_actor
	source_manager = new_source_manager
	body_size = definition.get("size", Vector3.ONE) as Vector3
	spawned_at_msec = Time.get_ticks_msec()
	name = "Engineering" + build_id.to_pascal_case()
	mass = maxf(float(definition.get("mass", 10.0)), 0.1)
	collision_layer = 1
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 12
	continuous_cd = true
	freeze = str(definition.get("body_mode", "anchored")) != "dynamic"
	if freeze:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		lock_rotation = true
	_configure_behavior_profile()
	_build_collision()
	_build_visuals()
	if build_id == "launch_tower":
		_build_spring_trigger()
	if build_id == "conductive_raft":
		_build_conductive_contact_area()
	add_to_group("engineering_build")
	add_to_group("engineering_build_" + build_id)
	add_to_group("elemental_receiver")
	add_to_group("freezable_receiver")
	add_to_group("debuggable")
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	wet_remaining = maxf(wet_remaining - safe_delta, 0.0)
	energized_remaining = maxf(energized_remaining - safe_delta, 0.0)
	overcharge_remaining = maxf(overcharge_remaining - safe_delta, 0.0)
	if overcharge_remaining <= 0.0:
		overcharge_charges = 0
	if frozen_progress > 0.0:
		frozen_progress = move_toward(frozen_progress, 0.0, safe_delta * 0.012)
	_update_contact_cooldowns(safe_delta)
	if build_id == "conductive_raft":
		_apply_raft_buoyancy()
	_refresh_visual_state()


func _configure_behavior_profile() -> void:
	match build_id:
		"bridge_frame":
			durability = 18.0
		"launch_tower":
			durability = 15.0
			add_to_group("conductive_receiver")
		"blast_cart":
			durability = 7.0
			add_to_group("burnable_receiver")
		"conductive_raft":
			durability = 16.0
			buoyancy_ratio = 1.35
			add_to_group("conductive_receiver")
			add_to_group("buoyant_engineering_build")
		_:
			durability = 10.0


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "BuildCollision"
	var shape := BoxShape3D.new()
	shape.size = body_size
	collision.shape = shape
	add_child(collision)


func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "BuildVisuals"
	add_child(visual_root)
	match build_id:
		"bridge_frame":
			_build_bridge_frame_visuals()
		"launch_tower":
			_build_launch_tower_visuals()
		"blast_cart":
			_build_blast_cart_visuals()
		"conductive_raft":
			_build_conductive_raft_visuals()
		_:
			_add_box_visual(
				"GenericBuild",
				body_size,
				Vector3.ZERO,
				definition.get("color", Color(0.5, 0.7, 0.9, 1.0)) as Color
			)


func _build_bridge_frame_visuals() -> void:
	var support_color := Color(0.58, 0.34, 0.17, 1.0)
	var deck_color := Color(0.28, 0.68, 0.94, 1.0)
	for x_offset: float in [-2.05, 2.05]:
		_add_box_visual(
			"RecordedSupport",
			Vector3(1.25, 1.45, 1.75),
			Vector3(x_offset, -0.12, 0.0),
			support_color
		)
	_add_box_visual(
		"BridgeDeck",
		Vector3(5.45, 0.38, 2.3),
		Vector3(0.0, 0.69, 0.0),
		deck_color
	)
	for x_offset: float in [-2.45, 2.45]:
		_add_box_visual(
			"Rail",
			Vector3(0.16, 0.72, 2.2),
			Vector3(x_offset, 1.0, 0.0),
			Color(0.18, 0.36, 0.52, 1.0)
		)


func _build_launch_tower_visuals() -> void:
	var frame_color := Color(0.26, 0.54, 0.42, 1.0)
	var deck_color := Color(0.34, 0.88, 0.54, 1.0)
	_add_box_visual(
		"TowerBase",
		Vector3(2.5, 0.45, 2.5),
		Vector3(0.0, -1.35, 0.0),
		frame_color
	)
	for x_offset: float in [-1.05, 1.05]:
		for z_offset: float in [-1.05, 1.05]:
			_add_box_visual(
				"TowerPost",
				Vector3(0.2, 2.65, 0.2),
				Vector3(x_offset, -0.15, z_offset),
				frame_color
			)
	_add_box_visual(
		"TowerDeck",
		Vector3(3.0, 0.34, 3.0),
		Vector3(0.0, 1.13, 0.0),
		deck_color
	)
	_add_box_visual(
		"SpringCore",
		Vector3(1.45, 0.52, 1.45),
		Vector3(0.0, 1.48, 0.0),
		Color(0.7, 1.0, 0.72, 1.0)
	)


func _build_blast_cart_visuals() -> void:
	_add_box_visual(
		"CartChassis",
		Vector3(2.4, 0.62, 1.65),
		Vector3(0.0, -0.45, 0.0),
		Color(0.45, 0.25, 0.12, 1.0)
	)
	_add_cylinder_visual(
		"BlastPayload",
		0.62,
		1.45,
		Vector3(0.15, 0.42, 0.0),
		Vector3(0.0, 0.0, 90.0),
		Color(0.96, 0.3, 0.12, 1.0)
	)
	for x_offset: float in [-0.82, 0.82]:
		for z_offset: float in [-0.78, 0.78]:
			_add_cylinder_visual(
				"CartWheel",
				0.32,
				0.18,
				Vector3(x_offset, -0.7, z_offset),
				Vector3(90.0, 0.0, 0.0),
				Color(0.12, 0.11, 0.1, 1.0)
			)


func _build_conductive_raft_visuals() -> void:
	for x_offset: float in [-1.35, 1.35]:
		_add_box_visual(
			"BuoyantPontoon",
			Vector3(1.15, 0.82, 2.75),
			Vector3(x_offset, -0.14, 0.0),
			Color(0.5, 0.32, 0.16, 1.0)
		)
	_add_box_visual(
		"ConductiveDeck",
		Vector3(4.0, 0.32, 2.9),
		Vector3(0.0, 0.44, 0.0),
		Color(0.18, 0.72, 0.9, 1.0)
	)
	for z_offset: float in [-1.15, 1.15]:
		_add_box_visual(
			"DeckConductor",
			Vector3(3.6, 0.08, 0.12),
			Vector3(0.0, 0.64, z_offset),
			Color(0.82, 0.94, 1.0, 1.0)
		)


func _add_box_visual(
	part_name: String,
	size: Vector3,
	position: Vector3,
	color: Color
) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.material_override = _make_material(color)
	visual_root.add_child(part)
	return part


func _add_cylinder_visual(
	part_name: String,
	radius: float,
	height: float,
	position: Vector3,
	rotation_degrees_value: Vector3,
	color: Color
) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	part.mesh = mesh
	part.position = position
	part.rotation_degrees = rotation_degrees_value
	part.material_override = _make_material(color)
	visual_root.add_child(part)
	return part


func _build_spring_trigger() -> void:
	spring_trigger = Area3D.new()
	spring_trigger.name = "LaunchTowerTrigger"
	spring_trigger.position.y = body_size.y * 0.5 + 0.32
	spring_trigger.collision_layer = 0
	spring_trigger.collision_mask = 1
	spring_trigger.monitoring = true
	spring_trigger.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.1, 0.72, 2.1)
	collision.shape = shape
	spring_trigger.add_child(collision)
	add_child(spring_trigger)
	spring_trigger.body_entered.connect(_on_launch_body_entered)


func _build_conductive_contact_area() -> void:
	conductive_contact_area = Area3D.new()
	conductive_contact_area.name = "RaftConductiveContact"
	conductive_contact_area.position.y = 0.68
	conductive_contact_area.collision_layer = 0
	conductive_contact_area.collision_mask = 1
	conductive_contact_area.monitoring = true
	conductive_contact_area.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 0.42, 2.85)
	collision.shape = shape
	conductive_contact_area.add_child(collision)
	add_child(conductive_contact_area)
	conductive_contact_area.body_entered.connect(_on_conductive_body_entered)


func _on_launch_body_entered(body: Node3D) -> void:
	if body == null or body == self:
		return
	var launch_speed: float = maxf(float(definition.get("launch_speed", 14.0)), 1.0)
	var boosted: bool = overcharge_charges > 0 and overcharge_remaining > 0.0
	if boosted:
		launch_speed *= 1.55
	if body is CharacterBody3D:
		var character := body as CharacterBody3D
		character.velocity.y = maxf(character.velocity.y, launch_speed)
	elif body is RigidBody3D:
		var rigid := body as RigidBody3D
		rigid.apply_central_impulse(Vector3.UP * rigid.mass * launch_speed)
	else:
		return
	activation_count += 1
	if boosted:
		overcharge_charges = maxi(overcharge_charges - 1, 0)
		_record_interaction("overcharged_launch", {
			"launch_speed": launch_speed,
			"charges_remaining": overcharge_charges,
		})
	build_activated.emit(build_id, "launch")


func _on_conductive_body_entered(body: Node3D) -> void:
	if energized_remaining <= 0.0 or body == null or body == self:
		return
	var body_id: int = body.get_instance_id()
	if float(contact_cooldowns.get(body_id, 0.0)) > 0.0:
		return
	contact_cooldowns[body_id] = 0.9
	var receiver: Node = _find_payload_receiver(body)
	if receiver == null:
		return
	var payload := DamagePayload.new()
	payload.amount = 1
	payload.stance_damage = 1
	payload.element = "lightning"
	payload.source_name = "Conductive Raft"
	payload.hit_type = "environment"
	payload.tags = ["engineering_build", "electrical", "conductive_contact"]
	receiver.call("receive_damage_payload", payload)
	_record_interaction("raft_conductive_contact", {"target": body.name})


func receive_damage_payload(payload: DamagePayload) -> void:
	if payload == null or detonation_started:
		return
	var element: String = payload.element.to_lower().strip_edges()
	var tags: Array[String] = []
	for raw_tag: String in payload.tags:
		tags.append(raw_tag.to_lower().strip_edges())
	var intensity: float = maxf(
		maxf(absf(float(payload.amount)), absf(payload.status_strength)),
		1.0
	)
	var force_like: bool = (
		payload.knockback_strength > 0.0
		or tags.has("heavy")
		or tags.has("force")
		or tags.has("impact")
		or tags.has("explosion")
	)
	if element == "water" or tags.has("water") or tags.has("douse"):
		wet_remaining = maxf(wet_remaining, 8.0 + intensity)
		_record_interaction("build_doused", {"source": payload.source_name})
		return
	if element == "ice" or tags.has("ice") or tags.has("freeze") or tags.has("cold"):
		var wet_bonus: float = 1.4 if wet_remaining > 0.0 else 1.0
		frozen_progress = clampf(
			frozen_progress + intensity * 0.2 * wet_bonus,
			0.0,
			1.0
		)
		if frozen_progress >= 0.65:
			_record_interaction("build_frozen", {
				"source": payload.source_name,
				"wet_bonus": wet_bonus > 1.0,
			})
		return
	if element == "lightning" or tags.has("lightning") or tags.has("electrical"):
		if build_id == "launch_tower":
			overcharge_remaining = 18.0
			overcharge_charges = 3
			energized_remaining = 8.0
			_record_interaction("launch_tower_overcharged", {
				"source": payload.source_name,
				"charges": overcharge_charges,
			})
		elif build_id == "conductive_raft":
			energized_remaining = 10.0
			_record_interaction("conductive_raft_energized", {
				"source": payload.source_name,
			})
		elif build_id == "blast_cart":
			if wet_remaining > 0.0:
				_record_interaction("blast_cart_dampened", {
					"source": payload.source_name,
				})
			else:
				detonate("Lightning")
		return
	if element == "fire" or tags.has("fire") or tags.has("ignite"):
		if build_id == "blast_cart":
			if wet_remaining > 0.0:
				_record_interaction("blast_cart_dampened", {
					"source": payload.source_name,
				})
			else:
				detonate("Fire")
		return
	if force_like:
		if frozen_progress >= 0.55:
			durability = maxf(
				durability - intensity * 0.8 - payload.knockback_strength * 0.2,
				0.0
			)
			if durability <= 0.0 or frozen_progress >= 0.95:
				shatter(payload.source_name)
				return
		if build_id == "blast_cart" and wet_remaining <= 0.0:
			detonate("Force")
		elif not freeze and payload.knockback_strength > 0.0:
			var direction: Vector3 = payload.knockback_direction
			if direction.length_squared() <= 0.01:
				direction = -global_transform.basis.z
			apply_central_impulse(
				direction.normalized() * payload.knockback_strength * mass
			)


func detonate(source_name: String = "Interaction") -> void:
	if detonation_started or build_id != "blast_cart":
		return
	if wet_remaining > 0.0:
		_record_interaction("blast_cart_dampened", {"source": source_name})
		return
	detonation_started = true
	activation_count += 1
	var radius: float = maxf(float(definition.get("blast_radius", 6.0)), 0.5)
	var damage: int = maxi(int(definition.get("blast_damage", 5)), 0)
	var force: float = maxf(float(definition.get("blast_force", 11.0)), 0.0)
	_record_interaction("blast_cart_detonated", {
		"source": source_name,
		"radius": radius,
	})
	_apply_blast(radius, damage, force)
	_spawn_blast_visual(radius)
	build_activated.emit(build_id, "detonate")
	build_destroyed.emit(build_id, "detonation")
	queue_free()


func shatter(source_name: String = "Force") -> void:
	_record_interaction("frozen_build_shatter", {
		"source": source_name,
		"frozen_progress": frozen_progress,
	})
	build_activated.emit(build_id, "shatter")
	build_destroyed.emit(build_id, "frozen_shatter")
	queue_free()


func interact() -> Dictionary:
	if build_id == "blast_cart":
		if wet_remaining > 0.0:
			return {
				"message": "The Blast Cart is waterlogged and temporarily inert.",
				"objective": "Let it dry before attempting demolition.",
			}
		detonate("Interaction")
		return {
			"message": "The Blast Cart ruptures in a reproduced demolition burst.",
			"objective": "",
		}
	return {
		"message": (
			str(definition.get("display_name", build_id.capitalize()))
			+ " is active."
		),
		"objective": str(definition.get("test_prompt", "Test the construction.")),
	}


func _apply_blast(radius: float, damage: int, force: float) -> void:
	if get_world_3d() == null:
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
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(
		query,
		64
	)
	var delivered: Dictionary = {}
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider == null or not collider is Node:
			continue
		var node := collider as Node
		var receiver: Node = _find_payload_receiver(node)
		if receiver != null and not delivered.has(receiver.get_instance_id()):
			delivered[receiver.get_instance_id()] = true
			var payload := DamagePayload.new()
			payload.amount = damage
			payload.stance_damage = damage
			payload.element = "fire"
			payload.source_name = "Blast Cart"
			payload.hit_type = "reaction_burst"
			payload.tags = ["engineering_build", "explosive", "explosion"]
			payload.knockback_strength = force
			payload.knockback_up_strength = force * 0.45
			receiver.call("receive_damage_payload", payload)
		if node is Node3D:
			var direction: Vector3 = (node as Node3D).global_position - global_position
			direction.y = maxf(direction.y, 0.35)
			if direction.length_squared() <= 0.01:
				direction = Vector3.UP
			if node is RigidBody3D:
				var rigid := node as RigidBody3D
				rigid.apply_central_impulse(direction.normalized() * force * rigid.mass)
			elif node is CharacterBody3D:
				var character := node as CharacterBody3D
				character.velocity += direction.normalized() * force


func _apply_raft_buoyancy() -> void:
	submerged_fraction = 0.0
	active_fluid_volume = null
	if freeze or get_tree() == null:
		return
	var best_priority: int = -2147483648
	for node: Node in get_tree().get_nodes_in_group("fluid_force_volumes"):
		var volume := node as FluidForceVolume
		if volume == null or not is_instance_valid(volume):
			continue
		var fraction: float = volume.get_submerged_fraction(
			global_position,
			body_size.y,
			0.1
		)
		if fraction <= 0.0:
			continue
		if volume.priority > best_priority or fraction > submerged_fraction:
			active_fluid_volume = volume
			submerged_fraction = fraction
			best_priority = volume.priority
	if active_fluid_volume == null:
		return
	wet_remaining = maxf(wet_remaining, 1.2)
	var gravity_value: float = maxf(
		float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)),
		0.1
	)
	apply_central_force(
		Vector3.UP * mass * gravity_value * buoyancy_ratio * submerged_fraction
	)
	var flow: Vector3 = active_fluid_volume.get_flow_velocity_at(global_position)
	var drag: Vector3 = -(linear_velocity - flow) * mass * submerged_fraction * 1.2
	apply_central_force(drag)
	angular_velocity *= maxf(1.0 - submerged_fraction * 0.035, 0.82)
	if last_interaction_id != "conductive_raft_afloat":
		_record_interaction("conductive_raft_afloat", {
			"submerged_fraction": submerged_fraction,
		})


func _find_payload_receiver(start: Node) -> Node:
	var current: Node = start
	for _index: int in range(5):
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


func _record_interaction(
	interaction_id: String,
	data: Dictionary = {}
) -> void:
	if interaction_id == "":
		return
	last_interaction_id = interaction_id
	var payload: Dictionary = data.duplicate(true)
	payload["build_id"] = build_id
	payload["interaction_id"] = interaction_id
	build_interaction_discovered.emit(build_id, interaction_id, payload)
	if discovered_interactions.has(interaction_id):
		return
	discovered_interactions[interaction_id] = true
	var tracker: Node = get_node_or_null(
		"/root/FullMenuDirector/ProgressionTracker"
	)
	if tracker != null and tracker.has_method("record_discovery"):
		tracker.call(
			"record_discovery",
			"build_reaction",
			build_id + "_" + interaction_id,
			{
				"source": "engineering_build",
				"build_id": build_id,
				"interaction_id": interaction_id,
				"display_name": (
					str(definition.get("display_name", build_id.capitalize()))
					+ " • "
					+ interaction_id.replace("_", " ").capitalize()
				),
			}
		)


func _refresh_visual_state() -> void:
	if visual_root == null:
		return
	for child: Node in visual_root.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh := child as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		var base_color: Color = material.get_meta("base_color", material.albedo_color) as Color
		var color: Color = base_color
		if wet_remaining > 0.0:
			color = color.lerp(Color(0.12, 0.4, 0.72, 1.0), 0.28)
		if frozen_progress > 0.0:
			color = color.lerp(
				Color(0.56, 0.92, 1.0, 1.0),
				clampf(frozen_progress * 0.72, 0.0, 0.72)
			)
		if energized_remaining > 0.0 or overcharge_charges > 0:
			color = color.lerp(Color(1.0, 0.9, 0.22, 1.0), 0.48)
		material.albedo_color = color
		material.emission = color.darkened(
			0.2 if energized_remaining > 0.0 or overcharge_charges > 0 else 0.58
		)
		material.emission_energy_multiplier = (
			1.15 if energized_remaining > 0.0 or overcharge_charges > 0 else 0.35
		)


func _update_contact_cooldowns(delta: float) -> void:
	for raw_id: Variant in contact_cooldowns.keys():
		var remaining: float = maxf(
			float(contact_cooldowns[raw_id]) - delta,
			0.0
		)
		if remaining <= 0.0:
			contact_cooldowns.erase(raw_id)
		else:
			contact_cooldowns[raw_id] = remaining


func _spawn_blast_visual(radius: float) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var pulse := MeshInstance3D.new()
	pulse.name = "EngineeringBlastPulse"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	pulse.mesh = sphere
	pulse.material_override = _make_transparent_material(
		Color(1.0, 0.42, 0.08, 0.72)
	)
	scene_root.add_child(pulse)
	pulse.global_position = global_position
	pulse.scale = Vector3.ONE * 0.2
	var tween := pulse.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector3.ONE * radius * 2.0, 0.34)
	tween.tween_property(pulse, "transparency", 1.0, 0.34)
	tween.chain().tween_callback(pulse.queue_free)


func get_debug_data() -> Dictionary:
	return {
		"build_id": build_id,
		"family": str(definition.get("family", "")),
		"behavior": str(definition.get("behavior", "")),
		"body_mode": str(definition.get("body_mode", "")),
		"frozen_body": freeze,
		"size": body_size,
		"mass": mass,
		"activation_count": activation_count,
		"detonation_started": detonation_started,
		"has_spring_trigger": spring_trigger != null,
		"has_conductive_contact": conductive_contact_area != null,
		"wet_remaining": snapped(wet_remaining, 0.01),
		"frozen_progress": snapped(frozen_progress, 0.01),
		"energized_remaining": snapped(energized_remaining, 0.01),
		"overcharge_charges": overcharge_charges,
		"durability": snapped(durability, 0.01),
		"submerged_fraction": snapped(submerged_fraction, 0.01),
		"active_fluid": (
			active_fluid_volume.name
			if active_fluid_volume != null and is_instance_valid(active_fluid_volume)
			else "none"
		),
		"last_interaction": last_interaction_id,
		"discoveries": discovered_interactions.keys(),
		"age_seconds": float(Time.get_ticks_msec() - spawned_at_msec) / 1000.0,
	}


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.3
	material.roughness = 0.52
	material.emission_enabled = true
	material.emission = color.darkened(0.58)
	material.emission_energy_multiplier = 0.35
	material.set_meta("base_color", color)
	return material


func _make_transparent_material(color: Color) -> StandardMaterial3D:
	var material := _make_material(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material
