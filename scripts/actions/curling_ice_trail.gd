extends Node3D
class_name CurlingIceTrail

signal segment_added(
	cast_serial: int,
	segment_index: int,
	world_position: Vector3,
	support_kind: String
)
signal trail_drawing_finished(
	cast_serial: int,
	segment_count: int,
	water_segment_count: int,
	reason: String
)
signal trail_dissipated(cast_serial: int, reason: String)
signal body_glided(body: Node3D, cast_serial: int)

const SlipperySurfaceScript = preload(
	"res://scripts/surfaces/slippery_surface_area.gd"
)
const FrozenBridgeScript = preload(
	"res://scripts/water/frozen_water_bridge_area.gd"
)

@export_group("Trail Geometry")
@export_range(0.6, 3.0, 0.05) var trail_width: float = 1.45
@export_range(0.03, 0.3, 0.01) var trail_thickness: float = 0.10
@export_range(0.2, 1.5, 0.05) var segment_spacing: float = 0.46
@export_range(8, 128, 1) var maximum_segments: int = 56
@export_range(0.0, 0.5, 0.01) var segment_overlap: float = 0.18
@export_range(0.0, 0.2, 0.005) var surface_clearance: float = 0.025

@export_group("Surface Sampling")
@export_range(0.5, 8.0, 0.1) var ground_probe_above: float = 3.0
@export_range(0.5, 12.0, 0.1) var ground_probe_below: float = 5.5
@export_range(0.0, 1.0, 0.01) var water_priority_height: float = 0.12
@export_flags_3d_physics var collision_query_mask: int = 1

@export_group("Lifetime")
@export_range(0.5, 30.0, 0.1) var linger_seconds: float = 9.0
@export_range(0.1, 4.0, 0.05) var fade_seconds: float = 1.0

@export_group("Traction")
@export_range(0.01, 1.0, 0.01) var acceleration_multiplier: float = 0.34
@export_range(0.01, 1.0, 0.01) var braking_multiplier: float = 0.08
@export_range(0.01, 1.0, 0.01) var turn_multiplier: float = 0.18
@export_range(0.01, 1.0, 0.01) var reversal_multiplier: float = 0.12
@export_range(0.0, 2.0, 0.01) var rigid_linear_damp: float = 0.04
@export_range(0.0, 2.0, 0.01) var rigid_angular_damp: float = 0.035

var source_actor: Node3D = null
var source_puck: Node3D = null
var cast_serial: int = 0
var drawing_active: bool = true
var dissipating: bool = false
var finish_reason: String = "drawing"
var linger_remaining: float = 0.0
var fade_elapsed: float = 0.0
var segment_positions: Array[Vector3] = []
var segment_normals: Array[Vector3] = []
var segment_kinds: Array[String] = []
var segment_lengths: Array[float] = []
var water_segment_count: int = 0
var ground_segment_count: int = 0
var rejected_sample_count: int = 0
var support_sample_count: int = 0
var body_glide_count: int = 0
var last_gliding_body_name: String = "none"

var static_body: StaticBody3D = null
var slippery_area: SlipperySurfaceArea = null
var frozen_bridge_area: FrozenWaterBridgeArea = null
var trail_visual: MultiMeshInstance3D = null
var trail_multimesh: MultiMesh = null
var trail_mesh: BoxMesh = null
var trail_material: StandardMaterial3D = null
var ice_physics_material: PhysicsMaterial = null


func _ready() -> void:
	global_transform = Transform3D.IDENTITY
	add_to_group("curling_ice_trails")
	add_to_group("slippery_ice_surfaces")
	add_to_group("spell_effects")
	add_to_group("persistent_spell_effects")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	_build_runtime_nodes()
	set_process(false)


func configure(
	new_source_actor: Node3D,
	new_cast_serial: int,
	new_source_puck: Node3D = null
) -> void:
	source_actor = new_source_actor
	cast_serial = new_cast_serial
	source_puck = new_source_puck
	name = "CurlingIceTrail_" + str(cast_serial)
	set_meta("curling_puck_cast_serial", cast_serial)
	set_meta(
		"curling_puck_source_id",
		source_actor.get_instance_id() if source_actor != null else 0
	)


func belongs_to_source(candidate: Node) -> bool:
	return source_actor != null and source_actor == candidate


func add_path_between(
	start_position: Vector3,
	end_position: Vector3,
	direction_hint: Vector3 = Vector3.ZERO
) -> int:
	if not drawing_active or dissipating:
		return 0
	var distance: float = start_position.distance_to(end_position)
	var step_count: int = maxi(
		1,
		ceili(distance / maxf(segment_spacing, 0.05))
	)
	var added_count: int = 0
	for step_index: int in range(1, step_count + 1):
		var ratio: float = float(step_index) / float(step_count)
		var sample_position: Vector3 = start_position.lerp(
			end_position,
			ratio
		)
		if add_sample(sample_position, direction_hint):
			added_count += 1
	return added_count


func add_sample(
	world_position: Vector3,
	direction_hint: Vector3 = Vector3.ZERO
) -> bool:
	if (
		not drawing_active
		or dissipating
		or segment_positions.size() >= maximum_segments
	):
		return false
	var support: Dictionary = resolve_surface_sample(
		world_position,
		source_puck
	)
	if not bool(support.get("found", false)):
		rejected_sample_count += 1
		return false
	support_sample_count += 1
	var surface_position: Vector3 = support.get(
		"position",
		world_position
	) as Vector3
	var surface_normal: Vector3 = support.get(
		"normal",
		Vector3.UP
	) as Vector3
	if surface_normal.length_squared() <= 0.0001:
		surface_normal = Vector3.UP
	surface_normal = surface_normal.normalized()

	if not segment_positions.is_empty():
		var previous_position: Vector3 = segment_positions.back()
		if (
			previous_position.distance_to(surface_position)
			< segment_spacing * 0.52
		):
			return false

	var tangent: Vector3 = direction_hint
	var segment_length: float = segment_spacing + segment_overlap
	if not segment_positions.is_empty():
		var previous_position: Vector3 = segment_positions.back()
		tangent = surface_position - previous_position
		segment_length = maxf(
			previous_position.distance_to(surface_position) + segment_overlap,
			segment_spacing + segment_overlap
		)
	tangent = tangent.slide(surface_normal)
	if tangent.length_squared() <= 0.0001:
		tangent = Vector3.FORWARD.slide(surface_normal)
	if tangent.length_squared() <= 0.0001:
		tangent = Vector3.RIGHT
	tangent = tangent.normalized()

	var support_kind: String = str(
		support.get("support_kind", "ground")
	)
	var segment_center: Vector3 = (
		surface_position
		+ surface_normal * (
			trail_thickness * 0.5 + surface_clearance
		)
	)
	var segment_basis: Basis = _basis_for_surface(
		tangent,
		surface_normal
	)
	_add_collision_segment(
		static_body,
		segment_center,
		segment_basis,
		segment_length
	)
	_add_collision_segment(
		slippery_area,
		segment_center,
		segment_basis,
		segment_length
	)
	if support_kind == "water":
		_add_collision_segment(
			frozen_bridge_area,
			segment_center,
			segment_basis,
			segment_length
		)
		water_segment_count += 1
	else:
		ground_segment_count += 1

	var segment_index: int = segment_positions.size()
	segment_positions.append(segment_center)
	segment_normals.append(surface_normal)
	segment_kinds.append(support_kind)
	segment_lengths.append(segment_length)
	_update_visual_segment(
		segment_index,
		segment_center,
		segment_basis,
		segment_length
	)
	trail_multimesh.visible_instance_count = segment_positions.size()
	segment_added.emit(
		cast_serial,
		segment_index,
		segment_center,
		support_kind
	)
	return true


func resolve_surface_sample(
	world_position: Vector3,
	requester: Node3D = null
) -> Dictionary:
	var water_sample: Dictionary = _find_water_surface_sample(world_position)
	var ground_sample: Dictionary = _find_ground_surface_sample(
		world_position,
		requester
	)
	if bool(water_sample.get("found", false)):
		var water_y: float = float(water_sample.get("surface_y", -INF))
		var ground_y: float = -INF
		if bool(ground_sample.get("found", false)):
			var ground_position: Vector3 = ground_sample.get(
				"position",
				Vector3.ZERO
			) as Vector3
			ground_y = ground_position.y
		if (
			not bool(ground_sample.get("found", false))
			or water_y >= ground_y + water_priority_height
		):
			return water_sample
	if bool(ground_sample.get("found", false)):
		return ground_sample
	return {
		"found": false,
		"position": world_position,
		"normal": Vector3.UP,
		"support_kind": "none",
	}


func finish_drawing(reason: String = "puck_finished") -> void:
	if not drawing_active:
		return
	drawing_active = false
	finish_reason = reason
	linger_remaining = maxf(linger_seconds, 0.0)
	fade_elapsed = 0.0
	trail_drawing_finished.emit(
		cast_serial,
		segment_positions.size(),
		water_segment_count,
		reason
	)
	if segment_positions.is_empty() or linger_remaining <= 0.0:
		force_dissipate("empty_trail")
		return
	set_process(true)


func force_dissipate(reason: String = "forced_cleanup") -> void:
	if dissipating:
		return
	dissipating = true
	drawing_active = false
	finish_reason = reason
	set_process(false)
	if slippery_area != null:
		slippery_area.clear_registered_bodies()
	if frozen_bridge_area != null:
		frozen_bridge_area.clear_supported_bodies()
	trail_dissipated.emit(cast_serial, reason)
	queue_free()


func reset_target() -> void:
	force_dissipate("trial_reset")


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {"message": "The ice trail receives an empty payload."}
	var is_fire: bool = payload.element.strip_edges().to_lower() == "fire"
	if is_fire:
		drawing_active = false
		linger_remaining = minf(
			linger_remaining if linger_remaining > 0.0 else fade_seconds,
			maxf(fade_seconds, 0.1)
		)
		finish_reason = "melted_by_fire"
		set_process(true)
		return {
			"message": "Fire races through the curling ice trail.",
			"melted": true,
			"cast_serial": cast_serial,
		}
	return {
		"message": "The curling ice trail holds.",
		"melted": false,
		"cast_serial": cast_serial,
	}


func _process(delta: float) -> void:
	if drawing_active or dissipating:
		return
	linger_remaining = maxf(linger_remaining - maxf(delta, 0.0), 0.0)
	var fade_duration: float = maxf(fade_seconds, 0.01)
	if linger_remaining <= fade_duration:
		fade_elapsed = fade_duration - linger_remaining
		var fade_ratio: float = clampf(
			fade_elapsed / fade_duration,
			0.0,
			1.0
		)
		_set_visual_fade(fade_ratio)
	if linger_remaining <= 0.0:
		force_dissipate(finish_reason)


func _find_water_surface_sample(world_position: Vector3) -> Dictionary:
	var best_sample: Dictionary = {}
	var best_surface_y: float = -INF
	for volume: Node in get_tree().get_nodes_in_group(
		"freezable_water_volume"
	):
		if (
			volume == null
			or not is_instance_valid(volume)
			or not volume.has_method("get_frozen_surface_sample")
		):
			continue
		var sample_value: Variant = volume.call(
			"get_frozen_surface_sample",
			world_position,
			trail_width * 0.08
		)
		if not sample_value is Dictionary:
			continue
		var sample: Dictionary = sample_value as Dictionary
		if not bool(sample.get("found", false)):
			continue
		var surface_y: float = float(sample.get("surface_y", -INF))
		if surface_y > best_surface_y:
			best_surface_y = surface_y
			best_sample = sample.duplicate(true)
	return best_sample


func _find_ground_surface_sample(
	world_position: Vector3,
	requester: Node3D
) -> Dictionary:
	var world: World3D = get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		world_position + Vector3.UP * ground_probe_above,
		world_position + Vector3.DOWN * ground_probe_below,
		collision_query_mask
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclusions: Array[RID] = []
	_collect_collision_rids(static_body, exclusions)
	_collect_collision_rids(source_actor, exclusions)
	_collect_collision_rids(requester, exclusions)
	query.exclude = exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var position_value: Variant = hit.get("position")
	var normal_value: Variant = hit.get("normal")
	if not position_value is Vector3:
		return {}
	var normal: Vector3 = (
		normal_value as Vector3
		if normal_value is Vector3
		else Vector3.UP
	)
	if normal.length_squared() <= 0.0001:
		normal = Vector3.UP
	return {
		"found": true,
		"position": position_value as Vector3,
		"normal": normal.normalized(),
		"support_kind": "ground",
		"collider": hit.get("collider"),
	}


func _add_collision_segment(
	parent: CollisionObject3D,
	world_position: Vector3,
	world_basis: Basis,
	segment_length: float
) -> void:
	if parent == null:
		return
	var collision := CollisionShape3D.new()
	collision.name = "IceSegmentCollision" + str(segment_positions.size())
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		trail_width,
		trail_thickness,
		maxf(segment_length, 0.08)
	)
	collision.shape = shape
	collision.global_transform = Transform3D(world_basis, world_position)
	parent.add_child(collision)
	collision.global_transform = Transform3D(world_basis, world_position)


func _update_visual_segment(
	segment_index: int,
	world_position: Vector3,
	world_basis: Basis,
	segment_length: float
) -> void:
	if trail_multimesh == null or segment_index >= trail_multimesh.instance_count:
		return
	var length_scale: float = (
		segment_length / maxf(segment_spacing + segment_overlap, 0.05)
	)
	var scaled_basis: Basis = world_basis.scaled(
		Vector3(1.0, 1.0, length_scale)
	)
	trail_multimesh.set_instance_transform(
		segment_index,
		Transform3D(scaled_basis, world_position)
	)
	var water_tint: float = (
		1.0 if segment_kinds.size() <= segment_index else 0.0
	)
	trail_multimesh.set_instance_color(
		segment_index,
		Color(0.72, 0.94, 1.0, 0.78 + water_tint * 0.06)
	)


func _basis_for_surface(
	forward_value: Vector3,
	normal_value: Vector3
) -> Basis:
	var normal: Vector3 = normal_value.normalized()
	var forward: Vector3 = forward_value.slide(normal)
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD.slide(normal)
	if forward.length_squared() <= 0.0001:
		forward = Vector3.RIGHT
	forward = forward.normalized()
	var right: Vector3 = normal.cross(forward)
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	forward = right.cross(normal).normalized()
	return Basis(right, normal, forward).orthonormalized()


func _build_runtime_nodes() -> void:
	static_body = StaticBody3D.new()
	static_body.name = "IceTrailStaticBody"
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	static_body.add_to_group("slippery_ice_surface")
	static_body.add_to_group("frozen_water_bridge")
	ice_physics_material = PhysicsMaterial.new()
	ice_physics_material.friction = 0.02
	ice_physics_material.rough = false
	ice_physics_material.bounce = 0.0
	static_body.physics_material_override = ice_physics_material
	add_child(static_body)

	slippery_area = SlipperySurfaceScript.new() as SlipperySurfaceArea
	slippery_area.name = "IceTrailSlipperyArea"
	slippery_area.surface_label = "Curling Ice Trail"
	slippery_area.surface_kind = "curling_ice"
	slippery_area.acceleration_multiplier = acceleration_multiplier
	slippery_area.braking_multiplier = braking_multiplier
	slippery_area.turn_multiplier = turn_multiplier
	slippery_area.reversal_multiplier = reversal_multiplier
	slippery_area.rigid_linear_damp = rigid_linear_damp
	slippery_area.rigid_angular_damp = rigid_angular_damp
	add_child(slippery_area)
	slippery_area.body_registered.connect(_on_slippery_body_registered)

	frozen_bridge_area = FrozenBridgeScript.new() as FrozenWaterBridgeArea
	frozen_bridge_area.name = "FrozenWaterBridgeArea"
	frozen_bridge_area.bridge_label = "Curling Puck Frozen Path"
	add_child(frozen_bridge_area)

	trail_mesh = BoxMesh.new()
	trail_mesh.size = Vector3(
		trail_width,
		trail_thickness * 0.68,
		segment_spacing + segment_overlap
	)
	trail_material = StandardMaterial3D.new()
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.vertex_color_use_as_albedo = true
	trail_material.albedo_color = Color(0.54, 0.88, 1.0, 0.78)
	trail_material.emission_enabled = true
	trail_material.emission = Color(0.18, 0.62, 1.0)
	trail_material.emission_energy_multiplier = 1.75

	trail_multimesh = MultiMesh.new()
	trail_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	trail_multimesh.use_colors = true
	trail_multimesh.mesh = trail_mesh
	trail_multimesh.instance_count = maximum_segments
	trail_multimesh.visible_instance_count = 0
	trail_visual = MultiMeshInstance3D.new()
	trail_visual.name = "CurlingIceTrailMultiMesh"
	trail_visual.multimesh = trail_multimesh
	trail_visual.material_override = trail_material
	trail_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail_visual)


func _set_visual_fade(ratio: float) -> void:
	if trail_material == null:
		return
	var color: Color = trail_material.albedo_color
	color.a = lerpf(0.78, 0.0, clampf(ratio, 0.0, 1.0))
	trail_material.albedo_color = color
	trail_material.emission_energy_multiplier = lerpf(
		1.75,
		0.0,
		clampf(ratio, 0.0, 1.0)
	)


func _on_slippery_body_registered(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	body_glide_count += 1
	last_gliding_body_name = str(body.name)
	body.set_meta("ice_curl_last_trail_serial_contact", cast_serial)
	body.set_meta("ice_curl_last_trail_name", name)
	body_glided.emit(body, cast_serial)


func _collect_collision_rids(
	node: Node,
	target: Array[RID]
) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func get_segment_positions() -> Array[Vector3]:
	return segment_positions.duplicate()


func get_segment_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for segment_index: int in range(segment_positions.size()):
		rows.append({
			"index": segment_index,
			"position": segment_positions[segment_index],
			"normal": segment_normals[segment_index],
			"kind": segment_kinds[segment_index],
			"length": segment_lengths[segment_index],
		})
	return rows


func get_static_body() -> StaticBody3D:
	return static_body


func get_slippery_area() -> SlipperySurfaceArea:
	return slippery_area


func get_frozen_bridge_area() -> FrozenWaterBridgeArea:
	return frozen_bridge_area


func get_debug_data() -> Dictionary:
	return {
		"curling_ice_trail": true,
		"cast_serial": cast_serial,
		"drawing_active": drawing_active,
		"dissipating": dissipating,
		"finish_reason": finish_reason,
		"segments": segment_positions.size(),
		"maximum_segments": maximum_segments,
		"water_segments": water_segment_count,
		"ground_segments": ground_segment_count,
		"support_samples": support_sample_count,
		"rejected_samples": rejected_sample_count,
		"linger_remaining": snappedf(linger_remaining, 0.01),
		"body_glides": body_glide_count,
		"last_gliding_body": last_gliding_body_name,
		"multimeshes": 1,
		"per_segment_process_nodes": 0,
		"static_collision_shapes": (
			static_body.get_child_count() if static_body != null else 0
		),
		"slippery_collision_shapes": (
			slippery_area.get_child_count() if slippery_area != null else 0
		),
		"bridge_collision_shapes": (
			frozen_bridge_area.get_child_count()
			if frozen_bridge_area != null
			else 0
		),
		"slippery": (
			slippery_area.get_debug_data() if slippery_area != null else {}
		),
		"frozen_bridge": (
			frozen_bridge_area.get_debug_data()
			if frozen_bridge_area != null
			else {}
		),
	}
