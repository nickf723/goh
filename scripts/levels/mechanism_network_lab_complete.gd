extends "res://scripts/levels/mechanism_network_lab.gd"
class_name MechanismNetworkLabComplete


func _ready() -> void:
	super._ready()
	_build_xor_extension()
	call_deferred("_refresh_all_presentations")


func _build_xor_extension() -> void:
	var lever: Node = get_node_or_null("Mechanisms/OrLever")
	var sensor: Node = get_node_or_null("Mechanisms/OrFireSensor")
	if lever == null or sensor == null:
		return
	var xor_logic: MechanismLogicNode = _create_logic(
		"LeverXorFire",
		"lever_xor_fire",
		"LEVER XOR FIRE",
		MechanismLogicNode.Operation.XOR,
		[lever, sensor]
	)
	_create_logic_label(xor_logic, Vector3(0.0, 3.2, 47.2))
	var indicator: MechanismIndicator = _spawn_indicator(
		"XorIndicator",
		"XOR OUTPUT",
		Vector3(0.0, 0.0, 47.0)
	)
	_wire_output("XorIndicatorOutput", xor_logic, indicator)
	station_states["xor"] = {
		"logic": xor_logic,
		"inputs": [lever, sensor],
		"outputs": [indicator],
	}
