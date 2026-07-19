extends RefCounted
class_name ThermalPressureStation

const WaterProfile: PhysicalMaterialProfile = preload("res://data/materials/water_physical_profile.tres")


static func build(host: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "ThermalPressureMachine"
	host.add_child(root)

	var reservoir := PressureReservoir.new()
	reservoir.name = "PressureReservoir"
	reservoir.maximum_pressure = 100.0
	reservoir.starting_pressure = 0.0
	reservoir.leak_enabled = true
	reservoir.leak_per_second = 0.8
	root.add_child(reservoir)

	var water := ThermalWaterVolume.new()
	water.name = "BoilerWater"
	water.component_id = "thermal_pressure_boiler_water"
	water.material_profile = WaterProfile
	water.volume_size = Vector3(3.4, 1.2, 2.2)
	water.position = Vector3(-3.5, 0.85, 1.3)
	water.starts_filled = true
	water.starting_water_temperature_c = 20.0
	water.water_heat_capacity_j_per_c = 8.0
	water.water_ambient_conductance = 0.015
	water.ensure_thermal_state()
	add_spell_capture(water)
	root.add_child(water)
	add_boiler_frame(root, water.position)

	var adapter := ThermalPressureAdapter.new()
	adapter.name = "ThermalPressureAdapter"
	adapter.base_output_per_second = 18.0
	adapter.output_per_superheat_c = 0.55
	adapter.maximum_output_per_second = 42.0
	adapter.condensation_per_second = 28.0
	adapter.configure(water.thermal_state, reservoir)
	root.add_child(adapter)

	var platform := AnimatableBody3D.new()
	platform.name = "LiftPlatform"
	platform.position = Vector3(3.5, 0.22, 1.4)
	root.add_child(platform)
	var platform_collision := CollisionShape3D.new()
	var platform_shape := BoxShape3D.new()
	platform_shape.size = Vector3(2.8, 0.4, 2.8)
	platform_collision.shape = platform_shape
	platform.add_child(platform_collision)
	ThermalLabGeometry.add_box_visual(
		platform,
		"PlatformMesh",
		Vector3(2.8, 0.4, 2.8),
		Color(0.22, 0.28, 0.36, 1.0),
		true,
		1.0
	)
	add_lift_supports(root)

	var actuator := MechanicalActuator.new()
	actuator.name = "MechanicalActuator"
	actuator.reservoir_path = NodePath("../PressureReservoir")
	actuator.moving_node_path = NodePath("../LiftPlatform")
	actuator.activation_pressure = 55.0
	actuator.deactivation_pressure = 20.0
	actuator.travel_offset = Vector3(0.0, 3.0, 0.0)
	actuator.move_duration = 0.9
	actuator.latch_when_activated = false
	root.add_child(actuator)

	var valve := PressureReliefValve.new()
	valve.name = "ReliefValve"
	valve.position = Vector3(0.0, 0.95, 0.7)
	valve.automatic_threshold_ratio = 0.9
	valve.automatic_vent_per_second = 36.0
	valve.manual_vent_amount = 1000.0
	valve.configure(reservoir)
	add_valve_shape(valve)
	root.add_child(valve)

	var gauge_pivot := Node3D.new()
	gauge_pivot.name = "GaugeNeedle"
	gauge_pivot.position = Vector3(0.0, 2.4, 1.05)
	root.add_child(gauge_pivot)
	var needle := ThermalLabGeometry.add_box_visual(
		gauge_pivot,
		"NeedleMesh",
		Vector3(0.12, 1.35, 0.12),
		Color(1.0, 0.35, 0.08, 1.0),
		true,
		2.4
	)
	needle.position = Vector3(0.0, 0.58, 0.0)
	ThermalLabGeometry.add_box_visual(
		root,
		"GaugePanel",
		Vector3(3.0, 2.1, 0.24),
		Color(0.08, 0.1, 0.15, 1.0)
	).position = Vector3(0.0, 2.35, 1.22)

	var readout := ThermalLabGeometry.add_label(
		host,
		"PressureReadout",
		"BOILER PRESSURE",
		Vector3(0.0, 4.25, 2.8),
		24,
		Color(1.0, 0.82, 0.52, 1.0)
	)

	return {
		"root": root,
		"water": water,
		"reservoir": reservoir,
		"adapter": adapter,
		"valve": valve,
		"actuator": actuator,
		"platform": platform,
		"gauge_needle": gauge_pivot,
		"readout": readout,
	}


static func add_spell_capture(water: ThermalWaterVolume) -> void:
	var area := Area3D.new()
	area.name = "SpellCaptureArea"
	area.monitoring = false
	area.monitorable = true
	var collision := CollisionShape3D.new()
	collision.position = Vector3(0.0, 1.0, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.2, 3.2, 3.0)
	collision.shape = shape
	area.add_child(collision)
	water.add_child(area)


static func add_boiler_frame(root: Node3D, center: Vector3) -> void:
	var frame_color := Color(0.32, 0.36, 0.42, 1.0)
	var post_index: int = 0
	for x_offset: float in [-1.95, 1.95]:
		for z_offset: float in [-1.35, 1.35]:
			var post := ThermalLabGeometry.add_box_visual(
				root,
				"BoilerPost" + str(post_index),
				Vector3(0.16, 2.2, 0.16),
				frame_color,
				true,
				0.8
			)
			post.position = center + Vector3(x_offset, 0.15, z_offset)
			post_index += 1
	var top := ThermalLabGeometry.add_box_visual(
		root,
		"BoilerTop",
		Vector3(4.1, 0.18, 2.9),
		frame_color
	)
	top.position = center + Vector3(0.0, 1.3, 0.0)


static func add_valve_shape(valve: PressureReliefValve) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 1.8, 1.5)
	collision.shape = shape
	valve.add_child(collision)
	ThermalLabGeometry.add_box_visual(
		valve,
		"ValveBody",
		Vector3(1.1, 1.1, 1.1),
		Color(0.62, 0.12, 0.08, 1.0),
		true,
		1.8
	)
	var handle := ThermalLabGeometry.add_box_visual(
		valve,
		"ValveHandle",
		Vector3(1.7, 0.16, 0.24),
		Color(0.95, 0.44, 0.12, 1.0),
		true,
		2.0
	)
	handle.position = Vector3(0.0, 0.75, 0.0)


static func add_lift_supports(root: Node3D) -> void:
	var support_index: int = 0
	for x_offset: float in [-1.65, 1.65]:
		var support := ThermalLabGeometry.add_box_visual(
			root,
			"LiftSupport" + str(support_index),
			Vector3(0.18, 4.2, 0.18),
			Color(0.16, 0.2, 0.28, 1.0)
		)
		support.position = Vector3(3.5 + x_offset, 1.8, 1.4)
		support_index += 1
