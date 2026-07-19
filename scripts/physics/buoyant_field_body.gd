extends FieldResponsiveBody
class_name BuoyantFieldBody


func _ready() -> void:
	super._ready()
	add_to_group("physical_bodies")


func _physics_process(delta: float) -> void:
	if field_receiver != null and force_receiver != null:
		field_receiver.update_field_response(self, force_receiver, delta)

	var vertical_acceleration: float = -gravity_strength
	if buoyancy_receiver == null:
		buoyancy_receiver = get_node_or_null("BuoyancyReceiver") as BuoyancyReceiver
	if buoyancy_receiver != null:
		vertical_acceleration = buoyancy_receiver.update_fluid_response(
			self,
			force_receiver,
			delta
		)

	var impulse_velocity: Vector3 = Vector3.ZERO
	var continuous_motion: Dictionary = {
		"linear_velocity": Vector3.ZERO,
		"angular_velocity": Vector3.ZERO,
	}
	if force_receiver != null:
		impulse_velocity = force_receiver.consume_external_velocity(delta)
		continuous_motion = force_receiver.integrate_continuous_motion(
			delta,
			get_effective_mass(),
			max(angular_inertia, 0.01)
		)

	var continuous_velocity: Vector3 = continuous_motion.get(
		"linear_velocity",
		Vector3.ZERO
	) as Vector3
	if force_receiver != null:
		continuous_velocity = force_receiver.constrain_continuous_velocity(contact_normals)
	velocity.x = impulse_velocity.x + continuous_velocity.x
	velocity.z = impulse_velocity.z + continuous_velocity.z

	if is_on_floor() and vertical_acceleration <= 0.0:
		gravity_velocity = 0.0
	else:
		gravity_velocity += vertical_acceleration * delta
	velocity.y = impulse_velocity.y + continuous_velocity.y + gravity_velocity

	var continuous_angular_velocity: Vector3 = continuous_motion.get(
		"angular_velocity",
		Vector3.ZERO
	) as Vector3
	if continuous_angular_velocity.length() > 0.0001:
		rotate(
			continuous_angular_velocity.normalized(),
			continuous_angular_velocity.length() * delta
		)

	move_and_slide()
	refresh_contact_normals()
	if force_receiver != null:
		force_receiver.constrain_continuous_velocity(contact_normals)


func reset_body() -> void:
	super.reset_body()
	if buoyancy_receiver == null:
		buoyancy_receiver = get_node_or_null("BuoyancyReceiver") as BuoyancyReceiver
	if buoyancy_receiver != null:
		buoyancy_receiver.reset_target()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["buoyant_body"] = true
	data["buoyancy"] = buoyancy_receiver.get_debug_data() if buoyancy_receiver != null else {}
	return data
