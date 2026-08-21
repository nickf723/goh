extends Node3D
class_name LifeGrove

signal restoration_pulsed(heal_count: int, growth_count: int)
signal target_restored(target: Node, amount: int)
signal growth_pulsed(target: Node)
signal grove_finished(total_healing: int, total_growth_pulses: int)

@export_group("Placement")
@export_range(1.0, 16.0, 0.25) var placement_distance: float = 4.8
@export_range(0.0, 2.0, 0.05) var ground_offset: float = 0.08
@export_range(1.0, 12.0, 0.25) var ground_probe_height: float = 4.0
@export_range(1.0, 20.0, 0.25) var ground_probe_depth: float = 8.0
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Restoration")
@export_range(0.25, 30.0, 0.05) var duration_seconds: float = 8.0
@export_range(1.0, 10.0, 0.1) var radius: float = 4.2
@export_range(0.2, 5.0, 0.05) var pulse_interval: float = 1.0
@export_range(1, 20, 1) var heal_per_pulse: int = 1
@export var heal_player: bool = true
@export var heal_friendlies: bool = true
@export var pulse_growth_hooks: bool = true
@export var exclude_enemies_from_healing: bool = true

@export_group("Presentation")
@export_range(4, 18, 1) var plant_count: int = 10
@export_range(2, 10, 1) var ring_segment_count: int = 7
@export_range(0.0, 4.0, 0.1) var sway_speed: float = 1.35

var source_actor: Node3D
var active: bool = false
var duration_remaining: float = 0.0
var pulse_timer: float = 0.0
var elapsed: float = 0.0
var pulse_count: int = 0
var total_healing: int = 0
var total_growth_pulses: int = 0
var restored_target_names: Array[String] = []
var growth_target_names: Array[String] = []

var visual_root: Node3D
var ground_disc: MeshInstance3D
var life_rings: Array[MeshInstance3D] = []
var plant_stems: Array[MeshInstance3D] = []
var plant_blooms: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("life_groves")
	add_to_group("spell_fields")
	add_to_group("debuggable")
	_build_visuals()
	set_process(false)
	set_physics_process(false)


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += maxf(delta, 0.0)
	_update_visuals(maxf(delta, 0.0))


func _physics_process(delta: float) -> void:
	if not active:
		return
	var safe_delta: float = maxf(delta, 0.0)
	duration_remaining = maxf(duration_remaining - safe_delta, 0.0)
	pulse_timer -= safe_delta
	if pulse_timer <= 0.0:
		pulse_timer += maxf(pulse_interval, 0.2)
		_pulse_grove()
	if duration_remaining <= 0.0:
		_finish_grove()


func set_payload(_new_payload: Resource) -> void:
	# Life Grove restores and grows; it does not own a damage payload.
	pass


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func execute(player: Node3D, requested_direction: Vector3) -> void:
	if player != null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	var direction: Vector3 = requested_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = -source_actor.global_transform.basis.z
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var proposed_position: Vector3 = source_actor.global_position + direction * placement_distance
	global_position = _resolve_ground_position(proposed_position)
	duration_remaining = maxf(duration_seconds, 0.25)
	pulse_timer = 0.0
	elapsed = 0.0
	pulse_count = 0
	total_healing = 0
	total_growth_pulses = 0
	restored_target_names.clear()
	growth_target_names.clear()
	active = true
	if visual_root != null:
		visual_root.visible = true
	_update_visuals(0.0)
	set_process(true)
	set_physics_process(true)
	_pulse_grove()


func _resolve_ground_position(proposed_position: Vector3) -> Vector3:
	var world: World3D = get_world_3d()
	if world == null:
		return proposed_position + Vector3.UP * ground_offset
	var query := PhysicsRayQueryParameters3D.create(
		proposed_position + Vector3.UP * ground_probe_height,
		proposed_position - Vector3.UP * ground_probe_depth
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var exclusions: Array[RID] = []
	if source_actor != null:
		_collect_collision_rids(source_actor, exclusions)
	query.exclude = exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var position_value: Variant = hit.get("position")
	if position_value is Vector3:
		return (position_value as Vector3) + Vector3.UP * ground_offset
	return proposed_position + Vector3.UP * ground_offset


func _pulse_grove() -> void:
	var world: World3D = get_world_3d()
	if world == null:
		return
	var shape := SphereShape3D.new()
	shape.radius = maxf(radius, 0.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * minf(radius * 0.35, 1.2))
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var healed_ids: Dictionary = {}
	var grown_ids: Dictionary = {}
	var heal_count: int = 0
	var growth_count: int = 0
	for result: Dictionary in world.direct_space_state.intersect_shape(query, 128):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var raw_node := collider_value as Node

		var heal_target: Node = _resolve_heal_target(raw_node)
		if heal_target != null:
			var heal_id: int = heal_target.get_instance_id()
			if not healed_ids.has(heal_id):
				healed_ids[heal_id] = true
				var healed_amount: int = _heal_target(heal_target)
				if healed_amount > 0:
					heal_count += 1
					total_healing += healed_amount
					if not restored_target_names.has(str(heal_target.name)):
						restored_target_names.append(str(heal_target.name))
					target_restored.emit(heal_target, healed_amount)

		if pulse_growth_hooks:
			var growth_target: Node = _resolve_growth_target(raw_node)
			if growth_target != null:
				var growth_id: int = growth_target.get_instance_id()
				if not grown_ids.has(growth_id):
					grown_ids[growth_id] = true
					_apply_growth_pulse(growth_target)
					growth_count += 1
					total_growth_pulses += 1
					if not growth_target_names.has(str(growth_target.name)):
						growth_target_names.append(str(growth_target.name))
					growth_pulsed.emit(growth_target)

	pulse_count += 1
	restoration_pulsed.emit(heal_count, growth_count)


func _resolve_heal_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if exclude_enemies_from_healing and current.is_in_group("enemy"):
			return null
		if heal_player and current.is_in_group("player"):
			return current
		if heal_friendlies and (
			current.is_in_group("ally")
			or current.is_in_group("friendly")
			or current.has_method("receive_heal")
		):
			return current
		if get_tree() != null and current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _heal_target(target: Node) -> int:
	if target == null or heal_per_pulse <= 0:
		return 0
	if target.is_in_group("player"):
		GameState.heal(heal_per_pulse)
		return heal_per_pulse
	if target.has_method("receive_heal"):
		var result: Variant = target.call("receive_heal", heal_per_pulse, self)
		if result is int:
			return maxi(int(result), 0)
		if result is float:
			return maxi(roundi(float(result)), 0)
		return heal_per_pulse
	if target.has_method("heal"):
		target.call("heal", heal_per_pulse)
		return heal_per_pulse
	return 0


func _resolve_growth_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if (
			current.has_method("receive_growth_pulse")
			or current.has_method("receive_life_grove_pulse")
		):
			return current
		if get_tree() != null and current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _apply_growth_pulse(target: Node) -> void:
	if target.has_method("receive_growth_pulse"):
		target.call("receive_growth_pulse", 1.0, self)
		return
	if target.has_method("receive_life_grove_pulse"):
		target.call("receive_life_grove_pulse", 1.0, self)


func _finish_grove() -> void:
	if not active:
		return
	active = false
	set_process(false)
	set_physics_process(false)
	if visual_root != null:
		visual_root.visible = false
	grove_finished.emit(total_healing, total_growth_pulses)
	queue_free()


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "LifeGroveVisuals"
	add_child(visual_root)

	ground_disc = MeshInstance3D.new()
	ground_disc.name = "GroveGroundDisc"
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.035
	disc.radial_segments = 40
	ground_disc.mesh = disc
	ground_disc.material_override = _make_life_material(
		Color(0.12, 0.58, 0.22, 0.18),
		Color(0.18, 0.8, 0.28, 1.0),
		0.45
	)
	visual_root.add_child(ground_disc)

	life_rings.clear()
	for index: int in range(2):
		var ring := MeshInstance3D.new()
		ring.name = "LifeRing" + str(index + 1)
		var torus := TorusMesh.new()
		var ring_radius: float = radius * (0.48 + float(index) * 0.32)
		torus.inner_radius = ring_radius - 0.025
		torus.outer_radius = ring_radius + 0.025
		torus.rings = 36
		torus.ring_segments = ring_segment_count
		ring.mesh = torus
		ring.position.y = 0.04 + float(index) * 0.025
		ring.material_override = _make_life_material(
			Color(0.34, 0.95, 0.32, 0.48),
			Color(0.48, 1.0, 0.42, 1.0),
			1.8
		)
		visual_root.add_child(ring)
		life_rings.append(ring)

	plant_stems.clear()
	plant_blooms.clear()
	for index: int in range(plant_count):
		var phase: float = TAU * float(index) / maxf(float(plant_count), 1.0)
		var distance: float = radius * (0.35 + 0.5 * float((index * 37) % 100) / 100.0)
		var position_2d := Vector2(cos(phase), sin(phase)) * distance

		var stem := MeshInstance3D.new()
		stem.name = "GroveStem" + str(index + 1)
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius = 0.025
		stem_mesh.bottom_radius = 0.045
		stem_mesh.height = 0.55 + float(index % 4) * 0.08
		stem_mesh.radial_segments = 7
		stem.mesh = stem_mesh
		stem.position = Vector3(position_2d.x, stem_mesh.height * 0.5, position_2d.y)
		stem.material_override = _make_life_material(
			Color(0.08, 0.46, 0.13, 0.92),
			Color(0.16, 0.62, 0.2, 1.0),
			0.35
		)
		visual_root.add_child(stem)
		plant_stems.append(stem)

		var bloom := MeshInstance3D.new()
		bloom.name = "GroveBloom" + str(index + 1)
		var bloom_mesh := SphereMesh.new()
		bloom_mesh.radius = 0.09 + float(index % 3) * 0.018
		bloom_mesh.height = bloom_mesh.radius * 2.0
		bloom_mesh.radial_segments = 8
		bloom_mesh.rings = 4
		bloom.mesh = bloom_mesh
		bloom.position = stem.position + Vector3.UP * (stem_mesh.height * 0.5 + 0.07)
		bloom.material_override = _make_life_material(
			Color(0.42, 0.96, 0.38, 0.9),
			Color(0.62, 1.0, 0.5, 1.0),
			2.1
		)
		visual_root.add_child(bloom)
		plant_blooms.append(bloom)

	visual_root.visible = false


func _update_visuals(delta: float) -> void:
	for index: int in range(life_rings.size()):
		var ring: MeshInstance3D = life_rings[index]
		var direction: float = 1.0 if index % 2 == 0 else -1.0
		ring.rotation.y += direction * delta * 0.35
	for index: int in range(plant_stems.size()):
		var stem: MeshInstance3D = plant_stems[index]
		var bloom: MeshInstance3D = plant_blooms[index]
		var sway: float = sin(elapsed * sway_speed + float(index) * 0.7) * 0.055
		stem.rotation.z = sway
		bloom.position.x += sin(elapsed * 0.7 + float(index)) * delta * 0.008


func _make_life_material(
	albedo: Color,
	emission: Color,
	emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = emission_energy
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.58
	return material


func get_debug_data() -> Dictionary:
	return {
		"spell": "life_grove",
		"restorative_growth_contract": true,
		"direct_damage": false,
		"active": active,
		"duration_remaining": snappedf(duration_remaining, 0.01),
		"radius": radius,
		"pulse_count": pulse_count,
		"total_healing": total_healing,
		"total_growth_pulses": total_growth_pulses,
		"restored_targets": restored_target_names.duplicate(),
		"growth_targets": growth_target_names.duplicate(),
	}
