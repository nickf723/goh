extends "res://scripts/actions/generic_projectile_safe.gd"
class_name IceLanceProjectile

signal lance_launched(direction: Vector3, pierce_capacity: int)
signal target_pierced(target: Node, pierce_index: int, result: Dictionary)
signal lance_lodged(position: Vector3, surface_name: String, duration: float)
signal lance_shattered(position: Vector3, reason: String)

const IceLanceElementVisuals = preload(
	"res://scripts/visuals/element_visuals.gd"
)
const IceLanceSpellModifiers = preload(
	"res://scripts/abilities/spell_modifier_registry.gd"
)

@export_group("Physical Lance")
@export_range(1.0, 8.0, 0.1) var lance_length: float = 3.8
@export_range(0.05, 1.0, 0.01) var shaft_radius: float = 0.18
@export_range(1, 12, 1) var base_pierce_capacity: int = 3
@export_range(0.1, 1.0, 0.01) var pierce_damage_retention: float = 0.76
@export_range(0.1, 1.0, 0.01) var pierce_stance_retention: float = 0.82
@export_range(0.0, 2.0, 0.01) var launch_clearance: float = 0.28
@export_range(0.0, 1.0, 0.01) var collision_probe_margin: float = 0.07
@export_flags_3d_physics var travel_collision_mask: int = 1

@export_group("Lodged Lance")
@export var lodge_in_static_surfaces: bool = true
@export_range(0.25, 30.0, 0.1) var lodged_duration_seconds: float = 8.0
@export_range(0.0, 1.0, 0.01) var embed_depth: float = 0.16
@export_range(0.2, 1.5, 0.05) var lodged_collision_width: float = 0.65
@export_range(0.08, 0.8, 0.02) var lodged_collision_height: float = 0.22
@export_range(0.05, 2.0, 0.05) var lodged_fade_seconds: float = 0.55

@export_group("Presentation")
@export_range(0.0, 12.0, 0.1) var flight_roll_speed: float = 2.2
@export_range(0.0, 12.0, 0.1) var lodged_pulse_speed: float = 4.8
@export var show_lance_debug_messages: bool = false

var launched_once: bool = false
var initial_body_sweep_pending: bool = false
var lodged: bool = false
var lodged_remaining: float = 0.0
var lodged_surface_name: String = "none"
var shattered: bool = false
var ray_exclusions: Array[RID] = []
var pierced_target_names: Array[String] = []
var resolved_damage_retention: float = 0.76
var resolved_stance_retention: float = 0.82
var resolved_lodged_duration: float = 8.0
var modifier_pierce_capacity: int = 0

var lance_visual_root: Node3D
var lance_meshes: Array[MeshInstance3D] = []
var lance_light: OmniLight3D
var lodged_body: StaticBody3D
var lodged_collision_shape: CollisionShape3D


func _ready() -> void:
	_build_lance_visual()
	_build_lodged_collision()
	hit_limit = maxi(hit_limit, base_pierce_capacity)
	resolved_damage_retention = pierce_damage_retention
	resolved_stance_retention = pierce_stance_retention
	resolved_lodged_duration = lodged_duration_seconds
	super._ready()
	add_to_group("ice_lance_projectiles")
	add_to_group("spell_projectiles")
	add_to_group("debuggable")
	set_process(false)


func configure_element_visual() -> void:
	configured_element = "ice"
	if lance_visual_root != null:
		lance_visual_root.visible = true


func apply_projectile_modifier(modifier: Dictionary) -> void:
	super.apply_projectile_modifier(modifier)
	if modifier.has("damage_retention"):
		resolved_damage_retention = maxf(
			resolved_damage_retention,
			float(modifier.get("damage_retention", resolved_damage_retention))
		)
	if modifier.has("stance_retention"):
		resolved_stance_retention = maxf(
			resolved_stance_retention,
			float(modifier.get("stance_retention", resolved_stance_retention))
		)
	if modifier.has("lodge_duration_bonus"):
		resolved_lodged_duration += maxf(
			float(modifier.get("lodge_duration_bonus", 0.0)),
			0.0
		)
	modifier_pierce_capacity = maxi(modifier_pierce_capacity, hit_limit)


func launch(cast_direction: Vector3) -> void:
	if launched_once or shattered:
		return
	launched_once = true
	direction = (
		cast_direction.normalized()
		if cast_direction.length_squared() > 0.0001
		else Vector3.FORWARD
	)
	motion_velocity = direction * speed
	is_launched = true
	lodged = false
	lifetime_timer = max_lifetime
	ignore_timer = ignore_source_for_seconds
	hit_count = 0
	hit_targets.clear()
	pierced_target_names.clear()
	ray_exclusions.clear()
	_collect_collision_rids(source_actor, ray_exclusions)

	# The projectile root represents the lance center. Shift it forward so the
	# rear of the fully formed spear begins just ahead of Grace, then sweep the
	# complete body on the first frame so close targets are not skipped.
	global_position += direction * (
		lance_length * 0.5 + maxf(launch_clearance, 0.0)
	)
	_orient_to_direction()
	initial_body_sweep_pending = true
	set_process(true)
	lance_launched.emit(direction, hit_limit)


func _process(delta: float) -> void:
	advance_lance(delta)


func advance_lance(delta: float) -> bool:
	if shattered:
		return false
	var safe_delta: float = maxf(delta, 0.0)
	elapsed += safe_delta
	_update_lance_visual(safe_delta)

	if lodged:
		lodged_remaining = maxf(lodged_remaining - safe_delta, 0.0)
		if lodged_remaining <= 0.0:
			shatter_lance("lodged_duration_complete")
			return false
		return true

	if not is_launched:
		return false
	if ignore_timer > 0.0:
		ignore_timer = maxf(ignore_timer - safe_delta, 0.0)
	lifetime_timer = maxf(lifetime_timer - safe_delta, 0.0)
	if lifetime_timer <= 0.0:
		shatter_lance("maximum_range")
		return false

	if initial_body_sweep_pending:
		initial_body_sweep_pending = false
		var tail_position: Vector3 = get_tail_position() - direction * 0.04
		if _trace_lance_segment(tail_position, get_tip_position()):
			return not shattered

	update_airflow_motion(safe_delta)
	var current_tip: Vector3 = get_tip_position()
	var next_root_position: Vector3 = global_position + motion_velocity * safe_delta
	var next_tip: Vector3 = (
		next_root_position + direction * lance_length * 0.5
	)
	if _trace_lance_segment(current_tip, next_tip):
		return not shattered

	global_position = next_root_position
	update_element_trail(safe_delta)
	return true


func get_tip_position() -> Vector3:
	return global_position + direction * lance_length * 0.5


func get_tail_position() -> Vector3:
	return global_position - direction * lance_length * 0.5


func _trace_lance_segment(from_position: Vector3, to_position: Vector3) -> bool:
	var segment: Vector3 = to_position - from_position
	if segment.length_squared() <= 0.000001:
		return false
	var segment_direction: Vector3 = segment.normalized()
	var query_start: Vector3 = from_position
	var maximum_iterations: int = 24

	for _iteration: int in range(maximum_iterations):
		if query_start.distance_squared_to(to_position) <= 0.0001:
			return false
		var world: World3D = get_world_3d()
		if world == null:
			return false
		var query := PhysicsRayQueryParameters3D.create(
			query_start,
			to_position
		)
		query.collision_mask = travel_collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.exclude = ray_exclusions
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return false

		var collider_value: Variant = hit.get("collider")
		var hit_position_value: Variant = hit.get("position")
		var hit_normal_value: Variant = hit.get("normal")
		if not collider_value is Node or not hit_position_value is Vector3:
			return false
		var collider: Node = collider_value as Node
		var hit_position: Vector3 = hit_position_value as Vector3
		var hit_normal: Vector3 = (
			hit_normal_value as Vector3
			if hit_normal_value is Vector3
			else -segment_direction
		)
		var target: Node = find_payload_target(collider)

		if target != null and not should_ignore_target(target):
			var target_id: int = target.get_instance_id()
			if hit_targets.has(target_id):
				_collect_collision_rids(target, ray_exclusions)
				query_start = hit_position + segment_direction * collision_probe_margin
				continue
			if hit_count >= hit_limit:
				_set_center_from_tip(hit_position, 0.0)
				shatter_lance("pierce_capacity_exhausted")
				return true
			pierce_target(target, hit_position)
			_collect_collision_rids(target, ray_exclusions)
			query_start = hit_position + segment_direction * collision_probe_margin
			continue

		if source_actor != null and (
			collider == source_actor
			or source_actor.is_ancestor_of(collider)
		):
			_collect_collision_rids(collider, ray_exclusions)
			query_start = hit_position + segment_direction * collision_probe_margin
			continue

		# Non-payload Area3D nodes are usually triggers rather than physical
		# surfaces. Pass through them and let an actual body stop the lance.
		if collider is Area3D:
			_collect_collision_rids(collider, ray_exclusions)
			query_start = hit_position + segment_direction * collision_probe_margin
			continue

		if _can_lodge_in_surface(collider):
			lodge_lance(hit_position, hit_normal, collider)
		else:
			_set_center_from_tip(hit_position, 0.0)
			shatter_lance("solid_impact")
		return true

	return false


func pierce_target(target: Node, impact_position: Vector3) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {}
	var target_id: int = target.get_instance_id()
	if hit_targets.has(target_id):
		return {}

	var pierce_index: int = hit_count
	var hit_payload: DamagePayload = _make_pierce_payload(pierce_index)
	hit_targets[target_id] = true
	var result: Dictionary = send_payload_to_target(target, hit_payload)
	IceLanceElementVisuals.spawn_impact(
		get_tree(),
		impact_position,
		"ice",
		get_impact_radius() * (1.0 + float(pierce_index) * 0.08)
	)
	var effect_messages: Array[String] = IceLanceSpellModifiers.apply_on_hit_effects(
		self,
		target,
		hit_payload,
		impact_position,
		direction,
		hit_targets
	)
	var messages: Array[String] = []
	if str(result.get("message", "")) != "":
		messages.append(str(result.get("message", "")))
	for effect_message: String in effect_messages:
		if effect_message != "":
			messages.append(effect_message)
	if not messages.is_empty():
		show_message("\n".join(messages))

	hit_count += 1
	pierced_target_names.append(str(target.name))
	target_pierced.emit(target, hit_count, result)
	if show_lance_debug_messages:
		print(
			"ICE_LANCE pierces ",
			target.name,
			" [",
			hit_count,
			"/",
			hit_limit,
			"]"
		)
	return result


func _make_pierce_payload(pierce_index: int) -> DamagePayload:
	var source_payload: DamagePayload = get_payload()
	var duplicate_value: Resource = source_payload.duplicate(true)
	var hit_payload: DamagePayload = (
		duplicate_value as DamagePayload
		if duplicate_value is DamagePayload
		else source_payload
	)
	var damage_multiplier: float = pow(
		clampf(resolved_damage_retention, 0.1, 1.0),
		float(maxi(pierce_index, 0))
	)
	var stance_multiplier: float = pow(
		clampf(resolved_stance_retention, 0.1, 1.0),
		float(maxi(pierce_index, 0))
	)
	if hit_payload.amount > 0:
		hit_payload.amount = maxi(
			1,
			int(round(float(hit_payload.amount) * damage_multiplier))
		)
	if hit_payload.stance_damage > 0:
		hit_payload.stance_damage = maxi(
			1,
			int(round(float(hit_payload.stance_damage) * stance_multiplier))
		)
	hit_payload.knockback_direction = direction
	_append_payload_tags(
		hit_payload,
		[
			"ice_lance",
			"physical_lance",
			"line_pierce",
			"force",
			"heavy_impact",
		]
	)
	return hit_payload


func _append_payload_tags(
	active_payload: DamagePayload,
	tags_to_add: Array[String]
) -> void:
	if active_payload == null:
		return
	var next_tags: Array[String] = []
	for existing_tag: String in active_payload.tags:
		if existing_tag != "" and not next_tags.has(existing_tag):
			next_tags.append(existing_tag)
	for tag: String in tags_to_add:
		if tag != "" and not next_tags.has(tag):
			next_tags.append(tag)
	active_payload.tags = next_tags


func _can_lodge_in_surface(collider: Node) -> bool:
	if collider == null or not lodge_in_static_surfaces:
		return false
	if bool(collider.get_meta("ice_lance_reject_lodge", false)):
		return false
	if bool(collider.get_meta("ice_lance_anchor", false)):
		return true
	return collider is StaticBody3D or collider is AnimatableBody3D


func lodge_lance(
	impact_position: Vector3,
	_surface_normal: Vector3,
	collider: Node
) -> void:
	if lodged or shattered:
		return
	is_launched = false
	lodged = true
	motion_velocity = Vector3.ZERO
	lodged_remaining = maxf(resolved_lodged_duration, 0.25)
	lodged_surface_name = str(collider.name) if collider != null else "surface"
	_set_center_from_tip(impact_position, embed_depth)
	_orient_to_direction()
	_enable_lodged_collision(true)
	add_to_group("ice_lance_lodged")
	set_meta("ice_lance_lodge_surface", lodged_surface_name)
	set_meta("ice_lance_lodged", true)
	IceLanceElementVisuals.spawn_impact(
		get_tree(),
		impact_position,
		"ice",
		get_impact_radius() * 1.18
	)
	lance_lodged.emit(
		impact_position,
		lodged_surface_name,
		lodged_remaining
	)
	if show_lance_debug_messages:
		print(
			"ICE_LANCE lodged in ",
			lodged_surface_name,
			" for ",
			lodged_remaining,
			" seconds"
		)


func _set_center_from_tip(
	tip_position: Vector3,
	additional_embed_depth: float
) -> void:
	global_position = (
		tip_position
		- direction * (
			lance_length * 0.5
			- maxf(additional_embed_depth, 0.0)
		)
	)


func shatter_lance(reason: String = "shattered") -> void:
	if shattered:
		return
	shattered = true
	is_launched = false
	lodged = false
	motion_velocity = Vector3.ZERO
	_enable_lodged_collision(false)
	IceLanceElementVisuals.spawn_impact(
		get_tree(),
		get_tip_position(),
		"ice",
		get_impact_radius() * 1.32
	)
	lance_shattered.emit(global_position, reason)
	if show_lance_debug_messages:
		print("ICE_LANCE shatters: ", reason)
	queue_free()


func _collect_collision_rids(node: Node, destination: Array[RID]) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not destination.has(rid):
			destination.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, destination)


func _orient_to_direction() -> void:
	if direction.length_squared() <= 0.0001:
		return
	look_at(global_position + direction, Vector3.UP)


func _build_lance_visual() -> void:
	if lance_visual_root != null:
		return
	lance_visual_root = Node3D.new()
	lance_visual_root.name = "LanceVisualRoot"
	add_child(lance_visual_root)

	var tip_length: float = minf(0.8, lance_length * 0.28)
	var shaft_length: float = maxf(lance_length - tip_length, 0.4)
	var ice_material: StandardMaterial3D = _make_ice_material(
		Color(0.56, 0.9, 1.0, 0.9),
		Color(0.45, 0.9, 1.0),
		3.4
	)
	var core_material: StandardMaterial3D = _make_ice_material(
		Color(0.88, 0.98, 1.0, 0.92),
		Color(0.72, 0.96, 1.0),
		4.8
	)

	var shaft := MeshInstance3D.new()
	shaft.name = "IceLanceShaft"
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = maxf(shaft_radius * 0.72, 0.03)
	shaft_mesh.bottom_radius = maxf(shaft_radius, 0.04)
	shaft_mesh.height = shaft_length
	shaft_mesh.radial_segments = 8
	shaft.mesh = shaft_mesh
	shaft.rotation.x = -PI * 0.5
	shaft.position.z = tip_length * 0.5
	shaft.material_override = ice_material
	lance_visual_root.add_child(shaft)
	lance_meshes.append(shaft)

	var tip := MeshInstance3D.new()
	tip.name = "IceLancePoint"
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = maxf(shaft_radius * 1.45, 0.08)
	tip_mesh.height = tip_length
	tip_mesh.radial_segments = 8
	tip.mesh = tip_mesh
	tip.rotation.x = -PI * 0.5
	tip.position.z = -lance_length * 0.5 + tip_length * 0.5
	tip.material_override = core_material
	lance_visual_root.add_child(tip)
	lance_meshes.append(tip)

	var core := MeshInstance3D.new()
	core.name = "IceLanceCore"
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(
		maxf(shaft_radius * 0.45, 0.04),
		maxf(shaft_radius * 0.45, 0.04),
		shaft_length * 0.9
	)
	core.mesh = core_mesh
	core.position.z = tip_length * 0.45
	core.rotation.z = PI * 0.25
	core.material_override = core_material
	lance_visual_root.add_child(core)
	lance_meshes.append(core)

	for fin_index: int in range(4):
		var fin := MeshInstance3D.new()
		fin.name = "CrystalFin" + str(fin_index + 1)
		fin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(
			shaft_radius * 0.12,
			shaft_radius * 0.72,
			shaft_length * 0.62
		)
		fin.mesh = fin_mesh
		fin.position.z = tip_length * 0.62
		fin.rotation.z = float(fin_index) * PI * 0.5
		fin.material_override = ice_material
		lance_visual_root.add_child(fin)
		lance_meshes.append(fin)

	lance_light = OmniLight3D.new()
	lance_light.name = "IceLanceLight"
	lance_light.light_color = Color(0.55, 0.9, 1.0)
	lance_light.light_energy = 1.35
	lance_light.omni_range = 4.5
	lance_light.shadow_enabled = false
	lance_visual_root.add_child(lance_light)


func _build_lodged_collision() -> void:
	lodged_body = StaticBody3D.new()
	lodged_body.name = "LodgedIceLanceBody"
	lodged_body.collision_layer = 1
	lodged_body.collision_mask = 1
	lodged_body.set_meta("ice_lance_temporary_geometry", true)
	add_child(lodged_body)

	lodged_collision_shape = CollisionShape3D.new()
	lodged_collision_shape.name = "LodgedCollisionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(lodged_collision_width, 0.2),
		maxf(lodged_collision_height, 0.08),
		maxf(lance_length - 0.12, 0.4)
	)
	lodged_collision_shape.shape = shape
	lodged_collision_shape.disabled = true
	lodged_body.add_child(lodged_collision_shape)


func _enable_lodged_collision(enabled: bool) -> void:
	if lodged_collision_shape == null:
		return
	lodged_collision_shape.disabled = not enabled
	lodged_collision_shape.set_deferred("disabled", not enabled)
	if lodged_body != null:
		lodged_body.collision_layer = 1 if enabled else 0
		lodged_body.collision_mask = 1 if enabled else 0
		lodged_body.set_deferred("collision_layer", lodged_body.collision_layer)
		lodged_body.set_deferred("collision_mask", lodged_body.collision_mask)


func _make_ice_material(
	albedo: Color,
	emission_color: Color,
	emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = albedo
	material.metallic = 0.08
	material.roughness = 0.18
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = emission_energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _update_lance_visual(delta: float) -> void:
	if lance_visual_root == null:
		return
	if is_launched:
		lance_visual_root.rotation.z += flight_roll_speed * delta
	elif lodged:
		var pulse: float = 1.0 + sin(elapsed * lodged_pulse_speed) * 0.025
		lance_visual_root.scale = Vector3(pulse, pulse, 1.0)

	var fade: float = 1.0
	if lodged and lodged_remaining < maxf(lodged_fade_seconds, 0.05):
		fade = clampf(
			lodged_remaining / maxf(lodged_fade_seconds, 0.05),
			0.0,
			1.0
		)
	for mesh: MeshInstance3D in lance_meshes:
		if mesh != null and is_instance_valid(mesh):
			mesh.transparency = 1.0 - fade
	if lance_light != null:
		lance_light.light_energy = fade * (
			1.15 + absf(sin(elapsed * 8.0)) * 0.35
		)


func get_debug_data() -> Dictionary:
	return {
		"ice_lance_projectile": true,
		"launched": launched_once,
		"flying": is_launched,
		"lodged": lodged,
		"shattered": shattered,
		"speed": snappedf(speed, 0.01),
		"lance_length": snappedf(lance_length, 0.01),
		"pierce_count": hit_count,
		"pierce_capacity": hit_limit,
		"pierced_targets": pierced_target_names.duplicate(),
		"damage_retention": snappedf(resolved_damage_retention, 0.01),
		"stance_retention": snappedf(resolved_stance_retention, 0.01),
		"lodged_remaining": snappedf(lodged_remaining, 0.01),
		"lodged_surface": lodged_surface_name,
		"temporary_collision_enabled": (
			lodged_collision_shape != null
			and not lodged_collision_shape.disabled
		),
		"modifier_pierce_capacity": modifier_pierce_capacity,
		"airflow": get_airflow_debug_data(),
	}
