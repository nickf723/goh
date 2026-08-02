extends RigidBody3D
class_name RecordedObjectInstance

signal object_detonated(blueprint_id: String)
signal object_activated(blueprint_id: String, activation: String)
signal object_interaction_triggered(
	blueprint_id: String,
	interaction_id: String,
	data: Dictionary
)
signal object_destroyed(blueprint_id: String, reason: String)

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

# Shared recorded-object interoperability state.
var base_visual_color: Color = Color(0.55, 0.72, 0.9, 1.0)
var wet_remaining: float = 0.0
var wet_strength: float = 0.0
var frozen_progress: float = 0.0
var electrified_remaining: float = 0.0
var overcharge_remaining: float = 0.0
var overcharge_charges: int = 0
var burning_remaining: float = 0.0
var durability: float = 1.0
var maximum_durability: float = 1.0
var conductivity: float = 0.0
var buoyancy_ratio: float = 0.0
var buoyancy_state: String = "air"
var buoyancy_submerged_fraction: float = 0.0
var active_fluid_volume: FluidForceVolume
var contact_area: Area3D
var contact_cooldowns: Dictionary = {}
var discovered_interactions: Dictionary = {}
var last_interaction_id: String = "none"
var previous_submerged_fraction: float = 0.0


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
	add_to_group("elemental_receiver")
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
	_configure_interoperability_profile()
	_build_collision()
	_build_visual()
	if str(definition.get("behavior", "")) == "spring":
		_build_spring_trigger()
	if conductivity >= 0.1:
		_build_contact_area()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	step_interoperability(delta)


func step_interoperability(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	wet_remaining = maxf(wet_remaining - safe_delta, 0.0)
	if wet_remaining <= 0.0:
		wet_strength = move_toward(wet_strength, 0.0, safe_delta * 0.35)
	electrified_remaining = maxf(electrified_remaining - safe_delta, 0.0)
	overcharge_remaining = maxf(overcharge_remaining - safe_delta, 0.0)
	if overcharge_remaining <= 0.0:
		overcharge_charges = 0
	if burning_remaining > 0.0:
		if wet_remaining > 0.0:
			burning_remaining = 0.0
			_record_interaction("water_extinguish", {
				"wet_strength": wet_strength,
			})
		else:
			burning_remaining = maxf(burning_remaining - safe_delta, 0.0)
			if burning_remaining <= 0.0 and blueprint_id == "crate":
				_destroy_recorded_object("burned_out")
				return
	if burning_remaining > 0.0:
		frozen_progress = move_toward(frozen_progress, 0.0, safe_delta * 0.42)
	elif frozen_progress > 0.0:
		frozen_progress = move_toward(frozen_progress, 0.0, safe_delta * 0.018)
	_update_contact_cooldowns(safe_delta)
	_apply_simple_buoyancy(safe_delta)
	_refresh_interaction_visual()


func _configure_interoperability_profile() -> void:
	match blueprint_id:
		"crate":
			maximum_durability = 5.0
			conductivity = 0.04
			buoyancy_ratio = 1.38
			add_to_group("burnable_receiver")
			add_to_group("buoyant_recorded_object")
		"platform":
			maximum_durability = 9.0
			conductivity = 0.82
			buoyancy_ratio = 0.0
			add_to_group("conductive_receiver")
		"spring":
			maximum_durability = 7.0
			conductivity = 0.94
			buoyancy_ratio = 0.0
			add_to_group("conductive_receiver")
		"blast_barrel":
			maximum_durability = 3.0
			conductivity = 0.34
			buoyancy_ratio = 0.92
			add_to_group("burnable_receiver")
			add_to_group("conductive_receiver")
			add_to_group("buoyant_recorded_object")
		_:
			maximum_durability = 4.0
			conductivity = 0.0
			buoyancy_ratio = 0.0
	durability = maximum_durability
	add_to_group("freezable_receiver")


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
	base_visual_color = definition.get(
		"color",
		Color(0.55, 0.72, 0.9, 1.0)
	) as Color
	primary_mesh.material_override = _make_material(base_visual_color)
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


func _build_contact_area() -> void:
	contact_area = Area3D.new()
	contact_area.name = "ConductiveContactArea"
	contact_area.collision_layer = 0
	contact_area.collision_mask = 1
	contact_area.monitoring = true
	contact_area.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = body_size + Vector3(0.18, 0.24, 0.18)
	collision.shape = shape
	contact_area.add_child(collision)
	add_child(contact_area)
	contact_area.body_entered.connect(_on_conductive_body_entered)


func _on_spring_body_entered(body: Node3D) -> void:
	if body == self or body == null:
		return
	var base_launch_speed: float = maxf(
		float(definition.get("launch_speed", 10.0)),
		1.0
	)
	var launch_speed: float = base_launch_speed
	var used_overcharge: bool = overcharge_charges > 0 and overcharge_remaining > 0.0
	if used_overcharge:
		launch_speed *= 1.65
	if body is CharacterBody3D:
		var character := body as CharacterBody3D
		character.velocity.y = maxf(character.velocity.y, launch_speed)
	elif body is RigidBody3D:
		var rigid := body as RigidBody3D
		rigid.apply_central_impulse(Vector3.UP * rigid.mass * launch_speed)
	else:
		return
	activation_count += 1
	if used_overcharge:
		overcharge_charges = maxi(overcharge_charges - 1, 0)
		_record_interaction("overcharged_launch", {
			"launch_speed": launch_speed,
			"charges_remaining": overcharge_charges,
		})
	object_activated.emit(blueprint_id, "launch")


func _on_conductive_body_entered(body: Node3D) -> void:
	if electrified_remaining <= 0.0 or body == null or body == self:
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
	payload.source_name = str(definition.get("display_name", "Energized object"))
	payload.hit_type = "environment"
	payload.tags = ["recorded_object", "electrical", "conductive_contact"]
	receiver.call("receive_damage_payload", payload)
	_record_interaction("electrified_contact", {
		"target": body.name,
	})


func receive_damage_payload(payload: DamagePayload) -> void:
	if payload == null or detonation_started:
		return
	var element: String = payload.element.to_lower().strip_edges()
	var tags: Array[String] = []
	for raw_tag: String in payload.tags:
		tags.append(raw_tag.to_lower().strip_edges())
	var intensity: float = maxf(
		absf(float(payload.amount)),
		absf(payload.status_strength),
		1.0
	)
	var force_like: bool = (
		payload.knockback_strength > 0.0
		or "heavy" in tags
		or "force" in tags
		or "impact" in tags
		or "explosive" in tags
		or "explosion" in tags
	)

	if element == "water" or "water" in tags or "douse" in tags:
		_apply_water_payload(intensity, payload.source_name)
		if force_like and not freeze:
			super.receive_damage_payload(payload)
		return

	if element == "ice" or "ice" in tags or "freeze" in tags or "cold" in tags:
		_apply_ice_payload(intensity, payload.source_name)
		return

	if element == "lightning" or "lightning" in tags or "electrical" in tags:
		var conducted: bool = _apply_lightning_payload(intensity, payload.source_name)
		if blueprint_id == "blast_barrel" and conducted:
			if wet_remaining > 0.0:
				_record_interaction("dampened_fuse", {
					"source": payload.source_name,
					"remaining": wet_remaining,
				})
			else:
				_record_interaction("lightning_detonation", {
					"source": payload.source_name,
				})
				detonate()
		return

	if element == "fire" or "fire" in tags or "heat" in tags or "ignite" in tags:
		if frozen_progress > 0.0:
			var previous_frozen: float = frozen_progress
			frozen_progress = maxf(frozen_progress - intensity * 0.32, 0.0)
			if previous_frozen >= 0.65 and frozen_progress < 0.65:
				_record_interaction("thermal_thaw", {
					"source": payload.source_name,
				})
		if blueprint_id == "blast_barrel":
			if wet_remaining > 0.0:
				_record_interaction("dampened_fuse", {
					"source": payload.source_name,
					"remaining": wet_remaining,
				})
				return
			_record_interaction("fire_detonation", {
				"source": payload.source_name,
			})
			super.receive_damage_payload(payload)
			return
		if blueprint_id == "crate":
			burning_remaining = maxf(burning_remaining, 7.5 + intensity * 0.5)
			_record_interaction("crate_ignited", {
				"source": payload.source_name,
				"burn_seconds": burning_remaining,
			})
		return

	if force_like:
		if frozen_progress >= 0.55:
			var fracture_damage: float = maxf(
				intensity * 0.7 + payload.knockback_strength * 0.16,
				0.65
			)
			durability = maxf(durability - fracture_damage, 0.0)
			if durability <= 0.0 or (
				frozen_progress >= 0.95 and fracture_damage >= 1.2
			):
				_shatter(payload.source_name)
				return
		super.receive_damage_payload(payload)
		return

	super.receive_damage_payload(payload)


func _apply_water_payload(intensity: float, source_name: String) -> void:
	var was_burning: bool = burning_remaining > 0.0
	var was_wet: bool = wet_remaining > 0.0
	wet_strength = clampf(maxf(wet_strength, intensity * 0.22), 0.0, 1.0)
	wet_remaining = maxf(wet_remaining, 7.0 + intensity * 0.7)
	burning_remaining = 0.0
	if was_burning:
		_record_interaction("water_extinguish", {
			"source": source_name,
		})
	elif not was_wet:
		_record_interaction("object_doused", {
			"source": source_name,
		})
	if blueprint_id == "blast_barrel":
		_record_interaction("barrel_dampened", {
			"source": source_name,
			"duration": wet_remaining,
		})


func _apply_ice_payload(intensity: float, source_name: String) -> void:
	var previous: float = frozen_progress
	var wet_bonus: float = 1.35 if wet_remaining > 0.0 else 1.0
	frozen_progress = clampf(
		frozen_progress + intensity * 0.24 * wet_bonus,
		0.0,
		1.0
	)
	if previous < 0.65 and frozen_progress >= 0.65:
		_record_interaction("object_frozen", {
			"source": source_name,
			"wet_bonus": wet_bonus > 1.0,
		})
	if frozen_progress >= 0.95:
		linear_velocity *= 0.42
		angular_velocity *= 0.25


func _apply_lightning_payload(intensity: float, source_name: String) -> bool:
	var effective_conductivity: float = conductivity
	if wet_remaining > 0.0:
		effective_conductivity = maxf(effective_conductivity, 0.72)
	if effective_conductivity < 0.1:
		return false
	electrified_remaining = maxf(
		electrified_remaining,
		4.0 + intensity * effective_conductivity
	)
	match blueprint_id:
		"spring":
			overcharge_remaining = maxf(overcharge_remaining, 15.0)
			overcharge_charges = maxi(overcharge_charges, 3)
			_record_interaction("spring_overcharged", {
				"source": source_name,
				"charges": overcharge_charges,
			})
		"platform":
			_record_interaction("platform_energized", {
				"source": source_name,
				"duration": electrified_remaining,
			})
		"crate":
			if wet_remaining > 0.0:
				_record_interaction("wet_crate_conduction", {
					"source": source_name,
				})
		"blast_barrel":
			pass
	return true


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
	var blast_radius: float = maxf(float(definition.get("blast_radius", 4.5)), 0.5)
	var blast_damage: int = maxi(int(definition.get("blast_damage", 3)), 0)
	var blast_force: float = maxf(float(definition.get("blast_force", 8.0)), 0.0)
	_record_interaction("barrel_detonated", {
		"radius": blast_radius,
		"force": blast_force,
	})
	_apply_blast(blast_radius, blast_damage, blast_force)
	_spawn_blast_visual(blast_radius)
	object_detonated.emit(blueprint_id)
	object_activated.emit(blueprint_id, "detonate")
	queue_free()


func interact() -> Dictionary:
	if str(definition.get("behavior", "")) == "blast_barrel":
		if wet_remaining > 0.0:
			_record_interaction("dampened_fuse", {
				"source": "interaction",
				"remaining": wet_remaining,
			})
			return {
				"message": "The recorded barrel is too damp to ignite.",
				"objective": "Dry it or use it as a temporary inert obstacle.",
			}
		detonate()
		return {
			"message": "The recorded barrel ruptures in a burst of reproduced force.",
			"objective": "",
		}
	return {
		"message": (
			str(definition.get("display_name", "Recorded object"))
			+ " is "
			+ _get_interaction_state_summary()
			+ "."
		),
		"objective": "Use elemental state and physical placement together.",
	}


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


func _apply_simple_buoyancy(_delta: float) -> void:
	previous_submerged_fraction = buoyancy_submerged_fraction
	buoyancy_submerged_fraction = 0.0
	active_fluid_volume = null
	if freeze or buoyancy_ratio <= 0.0 or get_tree() == null:
		buoyancy_state = "anchored" if freeze else "air"
		return
	var best_fraction: float = 0.0
	var best_priority: int = -2147483648
	for node: Node in get_tree().get_nodes_in_group("fluid_force_volumes"):
		var volume := node as FluidForceVolume
		if volume == null or not is_instance_valid(volume):
			continue
		var fraction: float = volume.get_submerged_fraction(
			global_position,
			body_size.y,
			0.05
		)
		if fraction <= 0.0:
			continue
		if volume.priority > best_priority or (
			volume.priority == best_priority and fraction > best_fraction
		):
			active_fluid_volume = volume
			best_fraction = fraction
			best_priority = volume.priority
	buoyancy_submerged_fraction = best_fraction
	if active_fluid_volume == null or best_fraction <= 0.0:
		buoyancy_state = "air"
		return
	wet_remaining = maxf(wet_remaining, 1.2)
	wet_strength = maxf(wet_strength, clampf(best_fraction, 0.0, 1.0))
	var gravity_value: float = maxf(
		ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float,
		0.1
	)
	var lift_force: float = mass * gravity_value * buoyancy_ratio * best_fraction
	apply_central_force(Vector3.UP * lift_force)
	var flow: Vector3 = active_fluid_volume.get_flow_velocity_at(global_position)
	var relative_velocity: Vector3 = linear_velocity - flow
	var drag_force: Vector3 = (
		-relative_velocity
		* mass
		* best_fraction
		* 1.35
	)
	apply_central_force(drag_force)
	angular_velocity *= maxf(1.0 - best_fraction * 0.035, 0.82)
	if linear_velocity.y > 0.25:
		buoyancy_state = "rising"
	elif buoyancy_ratio >= 1.0 and absf(linear_velocity.y) <= 0.45:
		buoyancy_state = "floating"
	else:
		buoyancy_state = "submerged"
	if previous_submerged_fraction <= 0.02 and best_fraction > 0.08:
		active_fluid_volume.spawn_ripple(global_position, 1.0 + mass * 0.08)
		if blueprint_id == "crate":
			_record_interaction("crate_floats", {
				"submerged_fraction": best_fraction,
			})
		elif blueprint_id == "blast_barrel":
			_record_interaction("barrel_waterlogged", {
				"submerged_fraction": best_fraction,
			})


func _shatter(source_name: String) -> void:
	_record_interaction("frozen_shatter", {
		"source": source_name,
		"frozen_progress": frozen_progress,
	})
	_spawn_shatter_visual()
	_destroy_recorded_object("frozen_shatter")


func _destroy_recorded_object(reason: String) -> void:
	if is_queued_for_deletion():
		return
	object_destroyed.emit(blueprint_id, reason)
	object_activated.emit(blueprint_id, reason)
	queue_free()


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


func _spawn_shatter_visual() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for index: int in range(6):
		var shard := MeshInstance3D.new()
		shard.name = "RecordedIceShard"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.16, 0.34, 0.12)
		shard.mesh = mesh
		shard.material_override = _make_transparent_material(
			Color(0.58, 0.92, 1.0, 0.82)
		)
		scene_root.add_child(shard)
		shard.global_position = global_position + Vector3(
			cos(float(index) * TAU / 6.0) * 0.35,
			0.25 + float(index % 2) * 0.2,
			sin(float(index) * TAU / 6.0) * 0.35
		)
		var outward: Vector3 = Vector3(
			cos(float(index) * TAU / 6.0),
			0.8,
			sin(float(index) * TAU / 6.0)
		).normalized()
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(
			shard,
			"global_position",
			shard.global_position + outward * 1.4,
			0.42
		)
		tween.tween_property(shard, "transparency", 1.0, 0.42)
		tween.chain().tween_callback(shard.queue_free)


func _refresh_interaction_visual() -> void:
	if primary_mesh == null or not is_instance_valid(primary_mesh):
		return
	var material := primary_mesh.material_override as StandardMaterial3D
	if material == null:
		return
	var color: Color = base_visual_color
	if wet_remaining > 0.0:
		color = color.lerp(Color(0.16, 0.42, 0.72, 1.0), 0.32 * wet_strength)
	if frozen_progress > 0.0:
		color = color.lerp(
			Color(0.56, 0.92, 1.0, 1.0),
			clampf(frozen_progress * 0.78, 0.0, 0.78)
		)
	if burning_remaining > 0.0:
		color = color.lerp(Color(1.0, 0.28, 0.06, 1.0), 0.58)
	if electrified_remaining > 0.0:
		color = color.lerp(Color(1.0, 0.88, 0.22, 1.0), 0.48)
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color.darkened(
		0.18 if burning_remaining > 0.0 or electrified_remaining > 0.0 else 0.58
	)
	material.emission_energy_multiplier = (
		1.15
		if burning_remaining > 0.0 or electrified_remaining > 0.0
		else 0.35
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


func _record_interaction(
	interaction_id: String,
	data: Dictionary = {}
) -> void:
	if interaction_id == "":
		return
	last_interaction_id = interaction_id
	var payload: Dictionary = data.duplicate(true)
	payload["blueprint_id"] = blueprint_id
	payload["interaction_id"] = interaction_id
	object_interaction_triggered.emit(blueprint_id, interaction_id, payload)
	if discovered_interactions.has(interaction_id):
		return
	discovered_interactions[interaction_id] = true
	var tracker: Node = get_node_or_null(
		"/root/FullMenuDirector/ProgressionTracker"
	)
	if tracker != null and tracker.has_method("record_discovery"):
		tracker.call(
			"record_discovery",
			"object_reaction",
			blueprint_id + "_" + interaction_id,
			{
				"source": "recorded_object_interoperability",
				"blueprint_id": blueprint_id,
				"interaction_id": interaction_id,
				"display_name": (
					str(definition.get("display_name", blueprint_id.capitalize()))
					+ " • "
					+ interaction_id.replace("_", " ").capitalize()
				),
			}
		)


func _get_interaction_state_summary() -> String:
	var states: Array[String] = []
	if wet_remaining > 0.0:
		states.append("wet")
	if frozen_progress >= 0.65:
		states.append("frozen")
	if burning_remaining > 0.0:
		states.append("burning")
	if electrified_remaining > 0.0:
		states.append("energized")
	if overcharge_charges > 0:
		states.append("overcharged")
	if states.is_empty():
		return "stable"
	return ", ".join(states)


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
		"interoperability": {
			"wet_remaining": snapped(wet_remaining, 0.01),
			"wet_strength": snapped(wet_strength, 0.01),
			"frozen_progress": snapped(frozen_progress, 0.01),
			"electrified_remaining": snapped(electrified_remaining, 0.01),
			"overcharge_remaining": snapped(overcharge_remaining, 0.01),
			"overcharge_charges": overcharge_charges,
			"burning_remaining": snapped(burning_remaining, 0.01),
			"durability": snapped(durability, 0.01),
			"maximum_durability": maximum_durability,
			"conductivity": conductivity,
			"buoyancy_ratio": buoyancy_ratio,
			"buoyancy_state": buoyancy_state,
			"submerged_fraction": snapped(buoyancy_submerged_fraction, 0.01),
			"active_fluid": (
				active_fluid_volume.name
				if active_fluid_volume != null and is_instance_valid(active_fluid_volume)
				else "none"
			),
			"last_interaction": last_interaction_id,
			"discoveries": discovered_interactions.keys(),
		},
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
