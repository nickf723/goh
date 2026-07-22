extends RefCounted
class_name AirflowMath


static func compute_drag_force(
	hair_velocity: Vector3,
	body_velocity: Vector3,
	mass_kg: float,
	drag_coefficient: float,
	cross_section_area: float,
	air_density: float = 1.225,
	gameplay_force_scale: float = 1.0,
	maximum_acceleration: float = 40.0
) -> Vector3:
	var relative_velocity: Vector3 = air_velocity - body_velocity
	var relative_speed: float = relative_velocity.length()
	if relative_speed <= 0.001:
		return Vector3.ZERO

	var safe_mass: float = max(mass_kg, 0.01)
	var force_magnitude: float = (
		0.5
		* max(air_density, 0.0)
		* max(drag_coefficient, 0.0)
		* max(cross_section_area, 0.0)
		* relative_speed
		* relative_speed
		* max(gameplay_force_scale, 0.0)
	)
	var maximum_force: float = max(maximum_acceleration, 0.0) * safe_mass
	if maximum_force > 0.0:
		force_magnitude = min(force_magnitude, maximum_force)
	return relative_velocity.normalized() * force_magnitude


static func compute_drag_acceleration(
	hair_velocity: Vector3,
	body_velocity: Vector3,
	mass_kg: float,
	drag_coefficient: float,
	cross_section_area: float,
	air_density: float = 1.225,
	gameplay_force_scale: float = 1.0,
	maximum_acceleration: float = 40.0
) -> Vector3:
	var safe_mass: float = max(mass_kg, 0.01)
	return compute_drag_force(
		air_velocity,
		body_velocity,
		safe_mass,
		drag_coefficient,
		cross_section_area,
		air_density,
		gameplay_force_scale,
		maximum_acceleration
	) / safe_mass
