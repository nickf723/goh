extends AirflowField3D
class_name WindWell

signal well_started(ground_position: Vector3, duration: float)
signal target_lifted(target: Node, lift_strength: float)
signal well_finished(target_count: int)

const AirflowManagerScript = preload(
	"res://scripts/airflow/airflow_manager.gd"
)

@export_group("Lifetime")
@export_range(0.25, 30.0, 0.05) var duration_seconds: float = 6.0
@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.35

@export_group("Direct Character Lift")
@export_flags_3d_physics var collision_mask: int = 1
@export_range(0.0, 20.0, 0.1) var character_target_up_speed: float = 7.2
@export_range(0.0, 100.0, 0.5) var character_lift_acceleration: float = 42.0
@export_range(0.0, 500.0, 1.0) var rigid_lift_force_newtons: float = 70.0
@export_range(0.1, 200.0, 0.1) var reference_mass_kg: float = 12.0
@export_range(0.05, 2.0, 0.05) var minimum_mass_multiplier: float = 0.55
@export_range(0.05, 3.0, 0.05) var maximum_mass_multiplier: float = 1.65
@export_range(0.0, 1.0, 0.05) var boss_lift_multiplier: float = 0.25
@export_range(0.0, 1.0, 0.05) var top_fade_fraction: float = 0.18
@export_range(0.0, 1.0, 0.05) var below_ground_fade_meters: float = 0.35

@export_group("Presentation")
@export_range(3, 12, 1) var ring_count: int = 6
@export_range(4, 20, 1) var wisp_count: int = 10
@export_range(0.0, 10.0, 0.1) var ring_rise_speed: float = 2.2
@export_range(0.0, 10.0, 0.1) var spiral_speed: float = 1.8
@export var show_debug_messages: bool = false

var source_actor: Node3D
var runtime_payload: DamagePayload
var well_running: bool = false
var duration_remaining: float = 0.0
var ground_position: Vector3 = Vector3.ZERO
var lifted_target_ids: Dictionary = {}
var lifted_target_names: Array[String] = []
var direct_lift_steps: int = 0

var visual_root: Node3D
var base_disc: MeshInstance3D
var column_core: MeshInstance3D
var well_light: OmniLight3D
var lift_rings: Array[MeshInstance3D] = []
var wind_wisps: Array[MeshInstance3D] = []


func _init() -> void:
	field_id = "wind_well"
	active = false
	field_kind = FieldKind.UPDRAFT
	volume_shape = VolumeShape.CYLINDER
	local_axis = Vector3.UP
	radius = 2.8
	cylinder_height = 9.0
	strength = 10.5
	edge_fade_fraction = 0.28
	falloff_exponent = 1.1
	turbulence_strength = 0.16
	turbulence_spatial_frequency = 0.72
	turbulence_time_frequency = 1.45


func _ready() -> void:
	active = false
	add_to_group("wind_well_effects")
	add_to_group("spell_fields")
	_build_visuals()
	super._ready()
	set_process(false)
	set_physics_process(false)


func _process(delta: float) -> void:
	advance_well(delta)


func _physics_process(delta: float) -> void:
	if well_running and active:
		_apply_direct_lift(maxf(delta, 0.0))


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = (
			(new_payload as DamagePayload).duplicate(true)
			as DamagePayload
		)


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func configure_visual() -> void:
	_layout_visuals()


func begin_well() -> void:
	if well_running:
		return
	ground_position = global_position
	_ensure_airflow_manager()
	elapsed = 0.0
	duration_remaining = maxf(duration_seconds, 0.25)
	lifted_target_ids.clear()
	lifted_target_names.clear()
	direct_lift_steps = 0
	well_running = true
	active = true
	if visual_root != null:
		visual_root.visible = true
	_update_visuals()
	set_process(true)
	set_physics_process(true)
	well_started.emit(ground_position, duration_remaining)


func advance_well(delta: float) -> bool:
	if not well_running:
		return false
	var safe_delta: float = maxf(delta, 0.0)
	elapsed += safe_delta
	duration_remaining = maxf(duration_remaining - safe_delta, 0.0)
	_update_visuals()
	if duration_remaining <= 0.0:
		finish_well()
		return false
	return true


func finish_well() -> void:
	if not well_running:
		return
	well_running = false
	active = false
	set_process(false)
	set_physics_process(false)
	if visual_root != null:
		visual_root.visible = false
	well_finished.emit(lifted_target_ids.size())
	queue_free()


# Wind Well is anchored at the selected ground point. The shared airflow field
# uses a centered cylinder, so this override makes the volume begin at the
# ground and fade only near its radial edge and upper lip.
func get_volume_weight(local_position: Vector3) -> float:
	var safe_radius: float = maxf(radius, 0.01)
	var safe_height: float = maxf(cylinder_height, 0.01)
	var radial_distance: float = (
		Vector2(local_position.x, local_position.z).length()
		/ safe_radius
	)
	if radial_distance >= 1.0:
		return 0.0

	var radial_weight: float = _edge_weight(
		radial_distance,
		edge_fade_fraction,
		falloff_exponent
	)
	var lower_fade: float = maxf(below_ground_fade_meters, 0.0)
	if local_position.y < -lower_fade or local_position.y > safe_height:
		return 0.0

	var vertical_weight: float = 1.0
	if local_position.y < 0.0 and lower_fade > 0.001:
		vertical_weight = smoothstep(
			-lower_fade,
			0.0,
			local_position.y
		)
	var top_fraction: float = clampf(top_fade_fraction, 0.0, 1.0)
	if top_fraction > 0.001:
		var top_fade_start: float = safe_height * (1.0 - top_fraction)
		if local_position.y > top_fade_start:
			vertical_weight *= 1.0 - smoothstep(
				top_fade_start,
				safe_height,
				local_position.y
			)
	return radial_weight * clampf(vertical_weight, 0.0, 1.0)


func _edge_weight(
	normalized_distance: float,
	fade_fraction: float,
	exponent: float
) -> float:
	var safe_fade: float = clampf(fade_fraction, 0.0, 1.0)
	if safe_fade <= 0.001:
		return 1.0
	var fade_start: float = 1.0 - safe_fade
	if normalized_distance <= fade_start:
		return 1.0
	var raw_weight: float = clampf(
		(1.0 - normalized_distance) / safe_fade,
		0.0,
		1.0
	)
	var smooth_weight: float = raw_weight * raw_weight * (3.0 - 2.0 * raw_weight)
	return pow(smooth_weight, maxf(exponent, 0.1))


func _ensure_airflow_manager() -> Node:
	var manager: Node = get_tree().get_first_node_in_group("airflow_manager")
	var scene_root: Node = get_tree().current_scene
	if manager == null and scene_root != null:
		manager = scene_root.get_node_or_null("AirflowManager")
	if manager == null:
		manager = AirflowManagerScript.new()
		manager.name = "AirflowManager"
		if scene_root != null:
			scene_root.add_child(manager)
		elif get_parent() != null:
			get_parent().add_child(manager)
	airflow_manager = manager
	if manager != null and manager.has_method("register_field"):
		manager.call("register_field", self)
	return manager


func _apply_direct_lift(delta: float) -> void:
	var world: World3D = get_world_3d()
	if world == null or delta <= 0.0:
		return
	var shape := CylinderShape3D.new()
	shape.radius = maxf(radius, 0.1)
	shape.height = maxf(cylinder_height, 0.2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		global_transform.basis,
		global_position + Vector3.UP * shape.height * 0.5
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var seen_targets: Dictionary = {}
	for result: Dictionary in world.direct_space_state.intersect_shape(query, 96):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_lift_target(collider_value as Node)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true
		var weight: float = get_volume_weight(
			to_local(_get_target_position(target))
		)
		if weight <= 0.001:
			continue
		apply_lift_step_to_target(target, delta, weight)


func apply_lift_step_to_target(
	target: Node,
	delta: float,
	weight_override: float = -1.0
) -> bool:
	if target == null or not is_instance_valid(target) or delta <= 0.0:
		return false
	if target is StaticBody3D or target is AnimatableBody3D:
		return false
	if bool(target.get_meta("wind_well_immune", false)):
		return false

	var weight: float = weight_override
	if weight < 0.0:
		weight = get_volume_weight(to_local(_get_target_position(target)))
	weight = clampf(weight, 0.0, 1.0)
	if weight <= 0.001:
		return false

	var airflow_response: AirflowResponse = target.get_node_or_null(
		"AirflowResponse"
	) as AirflowResponse
	var is_player: bool = target.is_in_group("player")
	if airflow_response != null and not is_player:
		_record_lift_target(target, strength * weight)
		return true

	if target.has_method("receive_updraft"):
		target.call(
			"receive_updraft",
			Vector3.UP,
			character_lift_acceleration * weight,
			delta,
			self
		)
		_record_lift_target(
			target,
			character_lift_acceleration * weight
		)
		return true

	if target is RigidBody3D:
		var rigid_body := target as RigidBody3D
		var rigid_multiplier: float = _get_authored_lift_multiplier(target)
		rigid_body.apply_central_force(
			Vector3.UP
			* rigid_lift_force_newtons
			* weight
			* rigid_multiplier
		)
		_record_lift_target(
			target,
			rigid_lift_force_newtons * weight * rigid_multiplier
		)
		return true

	if target is CharacterBody3D:
		var character := target as CharacterBody3D
		var mass_multiplier: float = _get_character_mass_multiplier(target)
		if is_player:
			mass_multiplier = maxf(mass_multiplier, 0.9)
		var target_speed: float = (
			character_target_up_speed
			* mass_multiplier
			* weight
		)
		var acceleration: float = (
			character_lift_acceleration
			* mass_multiplier
			* weight
		)
		character.velocity.y = move_toward(
			character.velocity.y,
			target_speed,
			acceleration * delta
		)
		direct_lift_steps += 1
		_record_lift_target(target, acceleration)
		return true

	return false


func _resolve_lift_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if _is_lift_target(current):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_lift_target(node: Node) -> bool:
	if node == null or node is StaticBody3D or node is AnimatableBody3D:
		return false
	return (
		node is CharacterBody3D
		or node is RigidBody3D
		or node.get_node_or_null("AirflowResponse") != null
		or node.get_node_or_null("ForceReceiver") != null
		or node.has_method("receive_updraft")
	)


func _get_character_mass_multiplier(target: Node) -> float:
	var mass_kg: float = _resolve_target_mass_kg(target)
	var multiplier: float = clampf(
		sqrt(maxf(reference_mass_kg, 0.01) / maxf(mass_kg, 0.01)),
		minimum_mass_multiplier,
		maximum_mass_multiplier
	)
	multiplier *= _get_authored_lift_multiplier(target)
	return maxf(multiplier, 0.0)


func _get_authored_lift_multiplier(target: Node) -> float:
	var multiplier: float = 1.0
	if target.is_in_group("boss"):
		multiplier *= boss_lift_multiplier
	if target.has_meta("wind_well_lift_multiplier"):
		multiplier *= maxf(
			float(target.get_meta("wind_well_lift_multiplier")),
			0.0
		)
	return multiplier


func _resolve_target_mass_kg(target: Node) -> float:
	if target is RigidBody3D:
		return maxf((target as RigidBody3D).mass, 0.01)
	if target.has_method("get_effective_mass"):
		return maxf(float(target.call("get_effective_mass")), 0.01)
	if target.has_method("get_mechanism_mass_kg"):
		return maxf(float(target.call("get_mechanism_mass_kg")), 0.01)
	if target.has_meta("wind_well_mass_kg"):
		return maxf(float(target.get_meta("wind_well_mass_kg")), 0.01)
	if target.has_meta("mechanism_mass_kg"):
		return maxf(float(target.get_meta("mechanism_mass_kg")), 0.01)
	if target.is_in_group("player"):
		return 65.0
	if target.is_in_group("generic_animals"):
		return 35.0
	if target.is_in_group("enemy"):
		return 70.0
	return reference_mass_kg


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	return (
		(parent as Node3D).global_position
		if parent is Node3D
		else global_position
	)


func _record_lift_target(target: Node, lift_strength: float) -> void:
	var target_id: int = target.get_instance_id()
	if lifted_target_ids.has(target_id):
		return
	lifted_target_ids[target_id] = true
	lifted_target_names.append(str(target.name))
	target_lifted.emit(target, lift_strength)
	if show_debug_messages:
		print(
			"WIND_WELL lifts ",
			target.name,
			" with ",
			snappedf(lift_strength, 0.01)
		)


func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 0
	fallback.stance_damage = 0
	fallback.element = "air"
	fallback.source_name = "Wind Well"
	fallback.hit_type = "updraft_field"
	fallback.tags = [
		"air",
		"magic",
		"ground_targeted",
		"field",
		"updraft",
		"lift",
		"traversal",
		"control",
		"non_damage",
	]
	fallback.suppress_reactions = true
	return fallback


func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "WindWellVisualRoot"
	visual_root.visible = false
	add_child(visual_root)

	base_disc = _create_cylinder_visual(
		"WindWellBase",
		radius,
		0.055,
		Color(0.95, 0.42, 0.74, 0.28),
		2.2
	)
	visual_root.add_child(base_disc)

	column_core = _create_cylinder_visual(
		"WindWellCore",
		maxf(radius * 0.32, 0.2),
		cylinder_height,
		Color(0.78, 0.72, 1.0, 0.1),
		1.6
	)
	column_core.position.y = cylinder_height * 0.5
	visual_root.add_child(column_core)

	for index: int in range(maxi(ring_count, 3)):
		var ring := MeshInstance3D.new()
		ring.name = "LiftRing" + str(index + 1)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var torus := TorusMesh.new()
		torus.inner_radius = maxf(radius * 0.7, 0.1)
		torus.outer_radius = maxf(radius * 0.76, 0.15)
		torus.rings = 28
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = _make_wind_material(
			Color(0.98, 0.72, 0.92, 0.48),
			3.0
		)
		visual_root.add_child(ring)
		lift_rings.append(ring)

	for index: int in range(maxi(wisp_count, 4)):
		var wisp := MeshInstance3D.new()
		wisp.name = "WindWisp" + str(index + 1)
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var wisp_mesh := BoxMesh.new()
		wisp_mesh.size = Vector3(0.09, 2.1, 0.09)
		wisp.mesh = wisp_mesh
		wisp.material_override = _make_wind_material(
			Color(0.7, 0.88, 1.0, 0.42),
			2.8
		)
		visual_root.add_child(wisp)
		wind_wisps.append(wisp)

	well_light = OmniLight3D.new()
	well_light.name = "WindWellLight"
	well_light.position = Vector3(0.0, 1.8, 0.0)
	well_light.light_color = Color(0.94, 0.5, 0.82)
	well_light.light_energy = 1.7
	well_light.omni_range = maxf(radius * 2.3, 5.0)
	well_light.shadow_enabled = false
	visual_root.add_child(well_light)
	_layout_visuals()


func _layout_visuals() -> void:
	if base_disc != null:
		base_disc.scale = Vector3.ONE
	if column_core != null:
		column_core.position.y = cylinder_height * 0.5
	for index: int in range(lift_rings.size()):
		var ring: MeshInstance3D = lift_rings[index]
		ring.position.y = (
			cylinder_height
			* float(index + 1)
			/ float(lift_rings.size() + 1)
		)


func _create_cylinder_visual(
	node_name: String,
	visual_radius: float,
	height: float,
	color: Color,
	emission_energy: float
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = maxf(visual_radius, 0.05)
	mesh.bottom_radius = maxf(visual_radius, 0.05)
	mesh.height = maxf(height, 0.02)
	mesh.radial_segments = 32
	visual.mesh = mesh
	visual.material_override = _make_wind_material(color, emission_energy)
	return visual


func _make_wind_material(
	color: Color,
	emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = emission_energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _update_visuals() -> void:
	if visual_root == null:
		return
	var fade: float = 1.0
	if duration_remaining < maxf(fade_seconds, 0.05):
		fade = clampf(
			duration_remaining / maxf(fade_seconds, 0.05),
			0.0,
			1.0
		)
	var base_pulse: float = 1.0 + sin(elapsed * 6.2) * 0.045
	if base_disc != null:
		base_disc.scale = Vector3(base_pulse, 1.0, base_pulse)
		base_disc.transparency = 1.0 - fade
	if column_core != null:
		column_core.transparency = 1.0 - fade * 0.8

	var safe_height: float = maxf(cylinder_height, 0.1)
	for index: int in range(lift_rings.size()):
		var ring: MeshInstance3D = lift_rings[index]
		var phase: float = (
			float(index) / float(maxi(lift_rings.size(), 1))
		)
		var rise: float = fmod(
			phase * safe_height + elapsed * ring_rise_speed,
			safe_height
		)
		ring.position.y = rise
		ring.rotation.y = elapsed * spiral_speed + phase * TAU
		var ring_scale: float = 0.72 + (rise / safe_height) * 0.28
		ring.scale = Vector3(ring_scale, 1.0, ring_scale)
		ring.transparency = 1.0 - fade * (0.55 + 0.45 * (1.0 - rise / safe_height))

	for index: int in range(wind_wisps.size()):
		var wisp: MeshInstance3D = wind_wisps[index]
		var phase: float = float(index) / float(maxi(wind_wisps.size(), 1))
		var angle: float = phase * TAU + elapsed * spiral_speed * (0.8 + phase * 0.35)
		var orbit_radius: float = radius * (0.28 + 0.58 * phase)
		var rise: float = fmod(
			phase * safe_height + elapsed * ring_rise_speed * 1.35,
			safe_height
		)
		wisp.position = Vector3(
			cos(angle) * orbit_radius,
			rise,
			sin(angle) * orbit_radius
		)
		wisp.rotation = Vector3(0.0, -angle, sin(angle * 1.7) * 0.22)
		var wisp_scale: float = 0.72 + sin(elapsed * 5.0 + phase * TAU) * 0.16
		wisp.scale = Vector3(wisp_scale, 0.8 + fade * 0.2, wisp_scale)
		wisp.transparency = 1.0 - fade * 0.72

	if well_light != null:
		well_light.light_energy = fade * (1.45 + sin(elapsed * 7.0) * 0.2)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["wind_well"] = true
	data["running"] = well_running
	data["duration_remaining"] = snappedf(duration_remaining, 0.01)
	data["ground_position"] = ground_position
	data["field_height"] = cylinder_height
	data["field_radius"] = radius
	data["target_count"] = lifted_target_ids.size()
	data["targets"] = lifted_target_names.duplicate()
	data["direct_lift_steps"] = direct_lift_steps
	data["payload_amount"] = get_payload().amount
	data["payload_stance_damage"] = get_payload().stance_damage
	data["zero_damage"] = (
		get_payload().amount == 0
		and get_payload().stance_damage == 0
	)
	return data
