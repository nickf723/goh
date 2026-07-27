extends "res://scripts/environment/modular_environment_piece.gd"
class_name ModularEnvironmentStairs


func _build_stone_stairs() -> void:
	var step_count: int = 6
	var step_run: float = 0.62
	var step_rise: float = 0.25
	var step_depth: float = step_run + 0.04
	var first_step_z: float = -1.55
	var final_step_z: float = first_step_z + step_run * float(step_count - 1)
	var total_rise: float = step_rise * float(step_count)

	for index: int in range(step_count):
		var height: float = step_rise * float(index + 1)
		var z_value: float = first_step_z + step_run * float(index)
		_add_visual_box(
			"Step%02d" % index,
			Vector3(4.0, height, step_depth),
			Vector3(0.0, height * 0.5, z_value),
			WET_STONE_MATERIAL
		)
		_add_visual_box(
			"RiserTrim%02d" % index,
			Vector3(4.12, 0.09, 0.07),
			Vector3(0.0, height - 0.045, z_value - step_run * 0.46),
			TRIM_STONE_MATERIAL
		)

	var ramp_start_z: float = first_step_z - step_depth * 0.5 - step_run
	var ramp_end_z: float = final_step_z - step_depth * 0.5
	var ramp_run: float = ramp_end_z - ramp_start_z
	var ramp_angle: float = atan2(total_rise, ramp_run)
	var ramp_length: float = sqrt(ramp_run * ramp_run + total_rise * total_rise)
	var ramp_thickness: float = 0.14
	var ramp_center_y: float = total_rise * 0.5 - cos(ramp_angle) * ramp_thickness * 0.5
	var ramp_center_z: float = (ramp_start_z + ramp_end_z) * 0.5 + sin(ramp_angle) * ramp_thickness * 0.5
	var walk_ramp: StaticBody3D = _add_static_box(
		"WalkRamp",
		Vector3(3.86, ramp_thickness, ramp_length),
		Vector3(0.0, ramp_center_y, ramp_center_z),
		WET_STONE_MATERIAL,
		Vector3(-ramp_angle, 0.0, 0.0),
		false
	)
	walk_ramp.set_meta("walkable_ramp", true)
	walk_ramp.set_meta("maximum_rise", total_rise)

	var top_landing: StaticBody3D = _add_static_box(
		"TopLanding",
		Vector3(3.86, 0.14, step_depth),
		Vector3(0.0, total_rise - 0.07, final_step_z),
		WET_STONE_MATERIAL,
		Vector3.ZERO,
		false
	)
	top_landing.set_meta("walkable_landing", true)

	for side: float in [-1.0, 1.0]:
		_add_visual_box(
			"Cheek_%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.3, 1.65, 3.95),
			Vector3(side * 2.08, 0.82, -0.02),
			TRIM_STONE_MATERIAL,
			Vector3(-0.17, 0.0, 0.0)
		)
	_add_visual_box(
		"StairMoss",
		Vector3(0.62, 0.035, 1.1),
		Vector3(-1.55, 1.53, 1.22),
		MOSS_MATERIAL,
		Vector3(0.0, 0.18, 0.0)
	)
