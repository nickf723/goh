extends CharacterBody3D
class_name FieldResponsiveBody

@export var body_label: String = "Field Responsive Body"
@export var material_profile: PhysicalMaterialProfile
@export var mass_override_kg: float = 0.0
@export var angular_inertia: float = 1.0
@export var gravity_strength: float = 20.0
@export var resettable: bool = true

@onready var force_receiver: ForceReceiver = get_node_or_null("ForceReceiver") as ForceReceiver
@onready var field_receiver: PhysicalFieldReceiver = get_node_or_null("PhysicalFieldReceiver") as PhysicalFieldReceiver
@onready var soul_manipulable: SoulManipulable = get_node_or_null("SoulManipulable") as SoulManipulable
@onready var airflow_response: AirflowResponse = get_node_or_null("AirflowResponse") as AirflowResponse

var initial_transform: Transform3D
# This is the body's persistent vertical velocity. Continuous vertical forces
# and gravity are integrated together here rather than as two separately capped
# velocity streams, allowing a sustained updraft to genuinely counter gravity.
var gravity_velocity: float = 0.0
var contact_normals: Array[Vector3] = []
var last_vertical_force: float = 0.0
var last_vertical_acceleration: float = 0.0


func _ready() -> void:
	initial_transform = transform
	add_to_group("debuggable")
	if resettable:
		add_to_group("lab_resettable")
	if field_receiver != null and field_receiver.material_profile == null:
		field_receiver.material_profile = material_profile


func _physics_process(delta: float) -> void:
	if soul_manipulable != null and soul_manipulable.is_being_manipulated():
		update_soul_manipulation(delta)
		return

	var effective_mass: float = maxf(get_effective_mass(), 0.01)
	if airflow_response != null and force_receiver != null:
		airflow_response.update_force_response(self, force_receiver, effective_mass)
	if field_receiver != null and force_receiver != null:
		field_receiver.update_field_response(self, force_receiver, delta)

	var impulse_velocity: Vector3 = Vector3.ZERO
	var continuous_motion: Dictionary = {
		"linear_velocity": Vector3.ZERO,
		"angular_velocity": Vector3.ZERO,
		"force": Vector3.ZERO,
	}
	if force_receiver != null:
		# Horizontal continuous motion keeps the shared damped velocity model.
		# Vertical force is integrated below with gravity, so stale vertical
		# continuous velocity must never survive from the older split model.
		force_receiver.continuous_velocity.y = 0.0
		impulse_velocity = force_receiver.consume_external_velocity(delta)
		continuous_motion = force_receiver.integrate_continuous_motion(
			delta,
			effective_mass,
			max(angular_inertia, 0.01)
		)

	var field_velocity: Vector3 = continuous_motion.get(
		"linear_velocity",
		Vector3.ZERO
	) as Vector3
	if force_receiver != null:
		field_velocity = force_receiver.constrain_continuous_velocity(contact_normals)
		force_receiver.continuous_velocity.y = 0.0
	field_velocity.y = 0.0
	velocity.x = impulse_velocity.x + field_velocity.x
	velocity.z = impulse_velocity.z + field_velocity.z

	var total_force: Vector3 = continuous_motion.get(
		"force",
		Vector3.ZERO
	) as Vector3
	last_vertical_force = total_force.y
	last_vertical_acceleration = (
		total_force.y / effective_mass - gravity_strength
	)
	var upward_impulse: bool = impulse_velocity.y > 0.001
	if (
		is_on_floor()
		and last_vertical_acceleration <= 0.0
		and not upward_impulse
	):
		gravity_velocity = 0.0
	else:
		gravity_velocity += last_vertical_acceleration * delta
		var maximum_upward_speed: float = (
			maxf(force_receiver.max_continuous_speed, 1.0)
			if force_receiver != null
			else 30.0
		)
		var maximum_fall_speed: float = maxf(
			gravity_strength * 2.0,
			maximum_upward_speed
		)
		gravity_velocity = clampf(
			gravity_velocity,
			-maximum_fall_speed,
			maximum_upward_speed
		)
	velocity.y = impulse_velocity.y + gravity_velocity

	var angular_velocity: Vector3 = continuous_motion.get(
		"angular_velocity",
		Vector3.ZERO
	) as Vector3
	if angular_velocity.length() > 0.0001:
		rotate(angular_velocity.normalized(), angular_velocity.length() * delta)

	move_and_slide()
	if is_on_floor() and gravity_velocity < 0.0:
		gravity_velocity = 0.0
	if is_on_ceiling() and gravity_velocity > 0.0:
		gravity_velocity = 0.0
	refresh_contact_normals()
	if force_receiver != null:
		force_receiver.constrain_continuous_velocity(contact_normals)


func update_soul_manipulation(delta: float) -> void:
	gravity_velocity = 0.0
	last_vertical_force = 0.0
	last_vertical_acceleration = 0.0
	velocity = soul_manipulable.get_commanded_velocity(
		velocity,
		get_effective_mass(),
		delta
	)
	move_and_slide()
	soul_manipulable.apply_rotation_step(delta)
	refresh_contact_normals()

	# Do not let old spell impacts or field forces accumulate invisibly while held.
	if force_receiver != null:
		force_receiver.consume_external_velocity(delta)
		force_receiver.continuous_velocity.y = 0.0
		force_receiver.constrain_continuous_velocity(contact_normals)
	if airflow_response != null:
		airflow_response.clear_force_response(force_receiver)


func refresh_contact_normals() -> void:
	contact_normals.clear()
	for collision_index: int in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(collision_index)
		if collision == null:
			continue
		var normal: Vector3 = collision.get_normal()
		if normal.length() <= 0.001:
			continue
		var duplicate: bool = false
		for existing_normal: Vector3 in contact_normals:
			if existing_normal.normalized().dot(normal.normalized()) > 0.995:
				duplicate = true
				break
		if not duplicate:
			contact_normals.append(normal.normalized())


func get_effective_mass() -> float:
	if material_profile != null:
		return material_profile.get_effective_mass(mass_override_kg)
	if mass_override_kg > 0.0:
		return mass_override_kg
	return 1.0


func get_mechanism_mass_kg() -> float:
	return get_effective_mass()


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(payload)
	return {
		"message": body_label + " receives a payload, but its receiver is missing.",
		"objective": "",
	}


func reset_body() -> void:
	if soul_manipulable != null:
		soul_manipulable.end_manipulation()
	transform = initial_transform
	velocity = Vector3.ZERO
	gravity_velocity = 0.0
	last_vertical_force = 0.0
	last_vertical_acceleration = 0.0
	contact_normals.clear()
	if airflow_response != null:
		airflow_response.clear_force_response(force_receiver)
	if force_receiver != null:
		force_receiver.reset_forces()
	if field_receiver != null:
		field_receiver.reset_field_response(force_receiver)


func reset_target() -> void:
	reset_body()


func interact() -> Dictionary:
	var material_name: String = "unprofiled"
	if material_profile != null:
		material_name = material_profile.display_name
	return {
		"message": body_label + " | " + material_name + " | responds to physical fields, airflow, and Soul Grip.",
		"objective": "Use the object's material and mass as part of the puzzle.",
	}


func get_debug_data() -> Dictionary:
	return {
		"physical_body": body_label,
		"material": material_profile.get_debug_data() if material_profile != null else {},
		"mass_kg": snapped(get_effective_mass(), 0.01),
		"position": global_position,
		"velocity": velocity,
		"vertical_velocity": snappedf(gravity_velocity, 0.01),
		"vertical_force": snappedf(last_vertical_force, 0.01),
		"vertical_acceleration": snappedf(last_vertical_acceleration, 0.01),
		"contact_normals": contact_normals.duplicate(),
		"force": force_receiver.get_debug_data() if force_receiver != null else {},
		"field_response": field_receiver.get_debug_data() if field_receiver != null else {},
		"airflow": airflow_response.get_debug_data() if airflow_response != null else {},
		"soul": soul_manipulable.get_debug_data() if soul_manipulable != null else {},
	}
