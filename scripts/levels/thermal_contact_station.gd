extends RefCounted
class_name ThermalContactStation

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")


static func build(host: Node3D) -> Dictionary:
	ThermalLabGeometry.add_label(
		host,
		"ContactTitle",
		"CONTACT HEAT TRANSFER",
		Vector3(-5.2, 3.0, 3.0),
		27,
		Color(1.0, 0.74, 0.48, 1.0)
	)
	var first: Dictionary = build_target(
		host,
		"DrivenCopperBlock",
		"CAST TARGET",
		Vector3(-6.1, 0.8, 1.6),
		Color(0.72, 0.28, 0.08, 1.0)
	)
	var second: Dictionary = build_target(
		host,
		"ContactCopperBlock",
		"CONTACT BLOCK",
		Vector3(-4.35, 0.8, 1.6),
		Color(0.58, 0.24, 0.08, 1.0)
	)
	var contact_link := ThermalContactLink.new()
	contact_link.name = "CopperContactLink"
	contact_link.conductance_j_per_second_c = 0.7
	contact_link.maximum_transfer_j_per_second = 120.0
	host.add_child(contact_link)
	contact_link.configure(first["state"] as ThermalState, second["state"] as ThermalState)
	ThermalLabGeometry.add_label(
		host,
		"ContactHint",
		"HEAT OR COOL EITHER BLOCK\nTHE TEMPERATURE DIFFERENCE DECAYS THROUGH CONTACT",
		Vector3(-5.2, 2.1, 3.15),
		18,
		Color(0.94, 0.82, 0.68, 1.0)
	)
	return {
		"targets": [first, second],
		"contact_link": contact_link,
	}


static func build_target(
	host: Node3D,
	node_name: String,
	display_name: String,
	position_value: Vector3,
	base_color: Color
) -> Dictionary:
	var target := Area3D.new()
	target.name = node_name
	target.position = position_value
	target.monitoring = true
	target.monitorable = true
	host.add_child(target)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.55, 1.25, 1.4)
	collision.shape = shape
	target.add_child(collision)

	var mesh := ThermalLabGeometry.add_box_visual(
		target,
		"Body",
		shape.size,
		base_color,
		true,
		1.2
	)
	var payload_receiver := PayloadReceiver.new()
	payload_receiver.name = "PayloadReceiver"
	target.add_child(payload_receiver)

	var state := ThermalState.new()
	state.name = "ThermalState"
	state.material_profile = CopperProfile
	state.starting_temperature_c = 20.0
	state.ambient_temperature_c = 20.0
	state.heat_capacity_override_j_per_c = 8.0
	state.ambient_conductance_j_per_second_c = 0.025
	state.fire_energy_j_per_intensity = 180.0
	state.ice_energy_j_per_intensity = 180.0
	target.add_child(state)

	var label: Label3D = ThermalLabGeometry.add_label(
		target,
		"StateLabel",
		display_name,
		Vector3(0.0, 1.25, 0.0),
		22,
		Color.WHITE
	)
	return {
		"name": display_name,
		"state": state,
		"mesh": mesh,
		"label": label,
	}
