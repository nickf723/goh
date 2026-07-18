extends Node

const IronProfile: PhysicalMaterialProfile = preload("res://data/materials/iron_physical_profile.tres")
const MagnetProfile: PhysicalMaterialProfile = preload("res://data/materials/permanent_magnet_physical_profile.tres")
const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	test_material_profiles()
	test_field_polarity_reversal()
	test_force_mass_and_torque_integration()
	test_contact_constraints()
	test_material_specific_magnetic_response()

	if failures.is_empty():
		print("PHYSICAL_INTERACTION_FOUNDATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("PHYSICAL_INTERACTION_FOUNDATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func test_material_profiles() -> void:
	if not CopperProfile.is_conductive(0.9):
		failures.append("copper should be classified as highly conductive")
	if CopperProfile.is_magnetically_responsive(0.05):
		failures.append("copper should remain effectively nonmagnetic in v1")
	if not IronProfile.is_magnetically_responsive(0.5):
		failures.append("iron should be strongly magnetically responsive")
	if MagnetProfile.permanent_magnetic_strength <= 0.0:
		failures.append("permanent magnet profile should expose a permanent moment")


func test_field_polarity_reversal() -> void:
	var field := MagneticDipoleField.new()
	field.field_id = "test_dipole"
	field.base_strength = 6.0
	field.maximum_distance = 10.0
	field.minimum_distance = 0.5
	field.falloff_power = 2.0
	add_child(field)
	await get_tree().process_frame

	var sample_position := Vector3(0.0, 0.0, 3.0)
	var before: Vector3 = field.sample_field(sample_position).get("vector", Vector3.ZERO)
	field.reverse_polarity()
	var after: Vector3 = field.sample_field(sample_position).get("vector", Vector3.ZERO)
	if before.length() <= 0.0 or after.length() <= 0.0:
		failures.append("magnetic dipole should produce a nonzero field inside range")
	elif before.normalized().dot(after.normalized()) > -0.99:
		failures.append("reversing polarity should reverse the sampled field vector")

	field.queue_free()


func test_force_mass_and_torque_integration() -> void:
	var receiver := ForceReceiver.new()
	receiver.continuous_linear_damping = 0.0
	receiver.continuous_angular_damping = 0.0
	add_child(receiver)
	await get_tree().process_frame

	receiver.set_continuous_force("test_force", Vector3(10.0, 0.0, 0.0))
	var light_motion: Dictionary = receiver.integrate_continuous_motion(0.5, 1.0, 1.0)
	var light_velocity: Vector3 = light_motion.get("linear_velocity", Vector3.ZERO)

	receiver.reset_forces()
	receiver.set_continuous_force("test_force", Vector3(10.0, 0.0, 0.0))
	var heavy_motion: Dictionary = receiver.integrate_continuous_motion(0.5, 5.0, 1.0)
	var heavy_velocity: Vector3 = heavy_motion.get("linear_velocity", Vector3.ZERO)
	if light_velocity.x <= heavy_velocity.x:
		failures.append("equal continuous force should accelerate a lighter body more")

	receiver.reset_forces()
	receiver.set_continuous_torque("test_torque", Vector3(0.0, 4.0, 0.0))
	var torque_motion: Dictionary = receiver.integrate_continuous_motion(0.5, 1.0, 2.0)
	var angular_velocity: Vector3 = torque_motion.get("angular_velocity", Vector3.ZERO)
	if angular_velocity.y <= 0.0:
		failures.append("continuous torque should produce angular velocity")

	receiver.queue_free()


func test_contact_constraints() -> void:
	var receiver := ForceReceiver.new()
	add_child(receiver)
	await get_tree().process_frame

	receiver.continuous_velocity = Vector3(-2.0, 0.0, 1.0)
	var constrained: Vector3 = receiver.constrain_continuous_velocity([Vector3.RIGHT])
	if absf(constrained.x) > 0.0001:
		failures.append("contact constraints should remove inward field velocity")
	if not is_equal_approx(constrained.z, 1.0):
		failures.append("contact constraints should preserve tangential field motion")

	receiver.continuous_velocity = Vector3(2.0, 0.0, 0.0)
	var separating: Vector3 = receiver.constrain_continuous_velocity([Vector3.RIGHT])
	if not is_equal_approx(separating.x, 2.0):
		failures.append("contact constraints should allow motion away from a surface")

	receiver.queue_free()


func test_material_specific_magnetic_response() -> void:
	var field := MagneticDipoleField.new()
	field.field_id = "response_dipole"
	field.base_strength = 8.0
	field.maximum_distance = 10.0
	field.minimum_distance = 0.5
	field.falloff_power = 2.0
	add_child(field)

	var magnet_result: Dictionary = await sample_body_response(
		"PermanentMagnet",
		MagnetProfile,
		Vector3(0.0, 0.0, 3.0),
		Basis(Vector3.UP, PI * 0.5)
	)
	var iron_result: Dictionary = await sample_body_response(
		"IronSlug",
		IronProfile,
		Vector3(3.0, 0.0, 0.0),
		Basis.IDENTITY
	)
	var copper_result: Dictionary = await sample_body_response(
		"CopperBlock",
		CopperProfile,
		Vector3(-3.0, 0.0, 0.0),
		Basis.IDENTITY
	)

	var magnet_torque: Vector3 = magnet_result.get("torque", Vector3.ZERO)
	var iron_force: Vector3 = iron_result.get("force", Vector3.ZERO)
	var copper_force: Vector3 = copper_result.get("force", Vector3.ZERO)
	if magnet_torque.length() <= 0.001:
		failures.append("misaligned permanent magnet should receive magnetic torque")
	if iron_force.length() <= 0.001:
		failures.append("iron should receive attraction toward a magnetic field gradient")
	if iron_force.length() <= copper_force.length() * 20.0:
		failures.append("iron response should greatly exceed conductive nonmagnetic copper")

	field.queue_free()


func sample_body_response(
	body_name: String,
	profile: PhysicalMaterialProfile,
	world_position: Vector3,
	basis: Basis
) -> Dictionary:
	var body := Node3D.new()
	body.name = body_name
	body.position = world_position
	body.basis = basis
	add_child(body)

	var force_receiver := ForceReceiver.new()
	force_receiver.name = "ForceReceiver"
	body.add_child(force_receiver)

	var field_receiver := PhysicalFieldReceiver.new()
	field_receiver.name = "PhysicalFieldReceiver"
	field_receiver.material_profile = profile
	field_receiver.field_force_scale = 6.0
	field_receiver.field_torque_scale = 4.0
	body.add_child(field_receiver)
	await get_tree().process_frame

	field_receiver.update_field_response(body, force_receiver, 0.1)
	var result := {
		"force": field_receiver.last_total_force,
		"torque": field_receiver.last_total_torque,
		"induced": field_receiver.induced_magnetization,
	}
	body.queue_free()
	return result
