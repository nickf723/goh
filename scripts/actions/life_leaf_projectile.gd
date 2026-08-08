extends "res://scripts/actions/generic_projectile_safe.gd"
class_name LifeLeafProjectile

@export_group("Leaf Flight")
@export_range(10.0, 50.0, 0.5) var leaf_speed: float = 27.0
@export_range(0.5, 5.0, 0.05) var leaf_lifetime: float = 2.15
@export_range(0.1, 20.0, 0.1) var homing_turn_rate: float = 8.5
@export_range(0.0, 2.0, 0.05) var target_wake_lead_strength: float = 0.82
@export_range(0.0, 0.8, 0.01) var maximum_lead_time: float = 0.34
@export_range(0.0, 1.0, 0.01) var flutter_strength: float = 0.075
@export_range(1.0, 30.0, 0.5) var flutter_frequency: float = 15.0

@export_group("Leaf Pelt")
@export_range(0.1, 4.0, 0.05) var pelt_duration: float = 1.05
@export_range(0.001, 0.05, 0.001) var slow_per_leaf: float = 0.008
@export_range(0.85, 1.0, 0.001) var minimum_pelt_multiplier: float = 0.976

@export_group("Deterioration")
@export_range(0.0, 1.0, 0.01) var amber_start_ratio: float = 0.48
@export_range(0.0, 1.0, 0.01) var crumble_start_ratio: float = 0.74
@export_range(0.02, 0.5, 0.01) var crumble_interval: float = 0.09

var homing_target: Node3D = null
var leaf_root: Node3D = null
var leaf_material: StandardMaterial3D = null
var vein_material: StandardMaterial3D = null
var crumble_timer: float = 0.0
var last_target_wake_velocity: Vector3 = Vector3.ZERO
var launch_phase: float = 0.0

const LEAF_GREEN: Color = Color(0.16, 0.72, 0.12, 1.0)
const LEAF_AMBER: Color = Color(0.92, 0.56, 0.08, 1.0)
const LEAF_BROWN: Color = Color(0.58, 0.22, 0.055, 1.0)


func _ready() -> void:
	speed = leaf_speed
	max_lifetime = leaf_lifetime
	respond_to_airflow = true
	aerodynamic_mass_kg = 0.045
	aerodynamic_drag_coefficient = 1.08
	aerodynamic_cross_section_area = 0.075
	aerodynamic_force_scale = 3.15
	maximum_airflow_acceleration = 20.0
	trail_interval = 0.055
	show_miss_feedback = false
	launch_phase = float(get_instance_id() % 31) * 0.37
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	if is_queued_for_deletion():
		return
	_update_leaf_deterioration(delta)


func configure_element_visual() -> void:
	if not is_node_ready() or element_visual_root == null:
		return
	for child: Node in element_visual_root.get_children():
		child.queue_free()

	leaf_root = Node3D.new()
	leaf_root.name = "LeafBlade"
	element_visual_root.add_child(leaf_root)

	leaf_material = _make_leaf_material(LEAF_GREEN, 0.9)
	vein_material = _make_leaf_material(Color(0.09, 0.42, 0.055, 1.0), 0.35)

	for rotation_value: float in [0.0, 90.0]:
		var blade := MeshInstance3D.new()
		blade.name = "LeafPlane"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.34, 0.62)
		blade.mesh = quad
		blade.material_override = leaf_material
		blade.rotation_degrees.z = 18.0
		blade.rotation_degrees.y = rotation_value
		leaf_root.add_child(blade)

	var vein := MeshInstance3D.new()
	vein.name = "LeafVein"
	var vein_mesh := BoxMesh.new()
	vein_mesh.size = Vector3(0.025, 0.34, 0.018)
	vein.mesh = vein_mesh
	vein.material_override = vein_material
	vein.rotation_degrees.z = 18.0
	leaf_root.add_child(vein)

	configured_element = "life"


func set_homing_target(target: Node3D) -> void:
	homing_target = target if target != null and is_instance_valid(target) else null


func update_airflow_motion(delta: float) -> void:
	if motion_velocity.length_squared() <= 0.0001:
		motion_velocity = direction * speed

	last_target_wake_velocity = Vector3.ZERO
	if homing_target != null and is_instance_valid(homing_target) and homing_target.is_inside_tree():
		var target_point: Vector3 = _get_target_aim_point(homing_target)
		var target_velocity: Vector3 = _get_target_velocity(homing_target)
		last_target_wake_velocity = target_velocity
		var distance: float = global_position.distance_to(target_point)
		var lead_time: float = minf(
			maximum_lead_time,
			distance / maxf(motion_velocity.length(), speed, 0.01)
		)
		var wake_point: Vector3 = (
			target_point
			+ target_velocity * lead_time * target_wake_lead_strength
		)
		var desired: Vector3 = wake_point - global_position
		if desired.length_squared() > 0.0001:
			desired = desired.normalized()
			var current: Vector3 = motion_velocity.normalized()
			var blend: float = clampf(homing_turn_rate * maxf(delta, 0.0), 0.0, 1.0)
			var steered: Vector3 = current.slerp(desired, blend).normalized()
			var lateral: Vector3 = steered.cross(Vector3.UP)
			if lateral.length_squared() > 0.0001:
				steered = (
					steered
					+ lateral.normalized()
					* sin(elapsed * flutter_frequency + launch_phase)
					* flutter_strength
				).normalized()
			motion_velocity = steered * maxf(motion_velocity.length(), speed)

	super.update_airflow_motion(delta)


func try_hit(raw_target: Node) -> void:
	var target: Node = find_payload_target(raw_target)
	if target == null:
		return
	var target_id: int = target.get_instance_id()
	var was_already_hit: bool = hit_targets.has(target_id)
	super.try_hit(raw_target)
	if not was_already_hit and hit_targets.has(target_id):
		apply_leaf_pelt_to_target(target)


func apply_leaf_pelt_to_target(target: Node) -> void:
	if target == null:
		return
	var receiver: Node = target.get_node_or_null("StatusReceiver")
	if receiver == null or not receiver.has_method("apply_status"):
		return

	var current_multiplier: float = 1.0
	if receiver.has_method("get_status_strength"):
		var current_strength: float = float(receiver.call("get_status_strength", "leaf_pelted"))
		if current_strength > 0.0:
			current_multiplier = current_strength
	var next_multiplier: float = maxf(
		minimum_pelt_multiplier,
		current_multiplier - slow_per_leaf
	)
	receiver.call(
		"apply_status",
		"leaf_pelted",
		pelt_duration,
		next_multiplier,
		"Leaf Volley"
	)


func _get_target_aim_point(target: Node3D) -> Vector3:
	if source_actor != null:
		var assist: Node = source_actor.get_node_or_null("CombatTargetingAssist")
		if assist != null and assist.has_method("get_target_aim_point"):
			var aim_value: Variant = assist.call("get_target_aim_point", target)
			if aim_value is Vector3:
				return aim_value as Vector3
	if target.has_method("get_targeting_aim_point"):
		var custom_value: Variant = target.call("get_targeting_aim_point")
		if custom_value is Vector3:
			return custom_value as Vector3
	return target.global_position + Vector3.UP * 0.65


func _get_target_velocity(target: Node3D) -> Vector3:
	if target is CharacterBody3D:
		return (target as CharacterBody3D).velocity
	if target is RigidBody3D:
		return (target as RigidBody3D).linear_velocity
	var velocity_value: Variant = target.get("velocity")
	return velocity_value as Vector3 if velocity_value is Vector3 else Vector3.ZERO


func _update_leaf_deterioration(delta: float) -> void:
	if leaf_material == null or leaf_root == null:
		return
	var age_ratio: float = clampf(
		elapsed / maxf(max_lifetime, 0.01),
		0.0,
		1.0
	)
	var color: Color = get_leaf_age_color(age_ratio)
	leaf_material.albedo_color = color
	leaf_material.emission = Color(color.r, color.g, color.b, 1.0)
	leaf_root.rotation.z += maxf(delta, 0.0) * (4.0 + age_ratio * 8.0)
	leaf_root.rotation.x = sin(elapsed * 17.0 + launch_phase) * (0.1 + age_ratio * 0.28)

	if age_ratio < crumble_start_ratio:
		return
	var crumble_ratio: float = inverse_lerp(crumble_start_ratio, 1.0, age_ratio)
	leaf_root.scale = Vector3.ONE * lerpf(1.0, 0.48, crumble_ratio)
	crumble_timer -= maxf(delta, 0.0)
	if crumble_timer <= 0.0:
		crumble_timer = crumble_interval
		_spawn_crumble_fragment(color)


func get_leaf_age_color(age_ratio: float) -> Color:
	var ratio: float = clampf(age_ratio, 0.0, 1.0)
	if ratio <= amber_start_ratio:
		return LEAF_GREEN
	if ratio <= crumble_start_ratio:
		return LEAF_GREEN.lerp(
			LEAF_AMBER,
			inverse_lerp(amber_start_ratio, crumble_start_ratio, ratio)
		)
	return LEAF_AMBER.lerp(
		LEAF_BROWN,
		inverse_lerp(crumble_start_ratio, 1.0, ratio)
	)


func _spawn_crumble_fragment(color: Color) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var fragment := MeshInstance3D.new()
	fragment.name = "LeafCrumb"
	fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.045, 0.018, 0.06)
	fragment.mesh = mesh
	fragment.material_override = _make_leaf_material(color, 0.25)
	get_tree().current_scene.add_child(fragment)
	fragment.global_position = global_position
	fragment.rotation = Vector3(
		sin(elapsed * 9.0) * 0.8,
		cos(elapsed * 7.0) * 1.1,
		elapsed * 2.0
	)
	var drift: Vector3 = Vector3(
		sin(elapsed * 11.0 + launch_phase) * 0.18,
		-0.34,
		cos(elapsed * 13.0 + launch_phase) * 0.18
	)
	var tween := fragment.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fragment, "global_position", fragment.global_position + drift, 0.28)
	tween.tween_property(fragment, "scale", Vector3.ZERO, 0.28)
	tween.set_parallel(false)
	tween.tween_callback(Callable(fragment, "queue_free"))


func _make_leaf_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.68
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func get_leaf_debug_data() -> Dictionary:
	return {
		"target": homing_target.name if homing_target != null and is_instance_valid(homing_target) else "none",
		"speed": motion_velocity.length(),
		"wake_velocity": last_target_wake_velocity,
		"age_ratio": clampf(elapsed / maxf(max_lifetime, 0.01), 0.0, 1.0),
		"airflow": get_airflow_debug_data(),
	}
